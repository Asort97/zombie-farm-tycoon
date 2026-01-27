local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local DEFAULT_PPS = PlayerState.DEFAULT_PPS or 10

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local biomassUpdate = remotesFolder:FindFirstChild("BiomassUpdate")
if not biomassUpdate then
	biomassUpdate = Instance.new("RemoteEvent")
	biomassUpdate.Name = "BiomassUpdate"
	biomassUpdate.Parent = remotesFolder
end

local offlineEarningsEvent = remotesFolder:FindFirstChild("OfflineEarnings")
if not offlineEarningsEvent then
	offlineEarningsEvent = Instance.new("RemoteEvent")
	offlineEarningsEvent.Name = "OfflineEarnings"
	offlineEarningsEvent.Parent = remotesFolder
end

local dataLoadedEvent = ServerScriptService:FindFirstChild("PlayerDataLoaded")
if not dataLoadedEvent then
	dataLoadedEvent = Instance.new("BindableEvent")
	dataLoadedEvent.Name = "PlayerDataLoaded"
	dataLoadedEvent.Parent = ServerScriptService
end

local LEADERBOARD_INTERVAL = 10
local leaderboardValues = {}
local leaderboardTimers = {}

local function ensureLeaderboard(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local biomassStat = leaderstats:FindFirstChild("Biomass")
	if not biomassStat then
		biomassStat = Instance.new("IntValue")
		biomassStat.Name = "Biomass"
		biomassStat.Value = 0
		biomassStat.Parent = leaderstats
	end

	leaderboardValues[player] = biomassStat
	leaderboardTimers[player] = os.clock()
end

local function updateLeaderboard(player)
	local stat = leaderboardValues[player]
	local state = PlayerState.Get(player)
	if stat and state then
		stat.Value = math.floor(state.Biomass)
	end
	leaderboardTimers[player] = os.clock()
end

local DATASTORE_NAME = "PlayerStateV1"
local SAVE_INTERVAL = 90
local SAVE_DEBOUNCE = 15
local MAX_OFFLINE_SECONDS = 6 * 60 * 60
local RETRY_COUNT = 5
local RETRY_BASE_DELAY = 0.5

local DATASTORE_ENABLED = game.GameId ~= 0
local playerStore = nil
if DATASTORE_ENABLED then
	playerStore = DataStoreService:GetDataStore(DATASTORE_NAME)
end
local saveInFlight = {}
local lastSaveTime = {}

local function runWithRetries(callback)
	local lastError
	for attempt = 1, RETRY_COUNT do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(RETRY_BASE_DELAY * (2 ^ (attempt - 1)))
	end
	return false, lastError
end

local function serializeState(state)
	return {
		Biomass = state.Biomass,
		PPS = state.PPS,
		OwnedUpgrades = state.OwnedUpgrades,
		lastSeen = os.time(),
	}
end

local function loadPlayerData(player)
	local key = tostring(player.UserId)
	if not DATASTORE_ENABLED then
		return 0
	end

	local success, data = runWithRetries(function()
		return playerStore:GetAsync(key)
	end)

	if not success or type(data) ~= "table" then
		local state = PlayerState.GetOrCreate(player)
		state.PPS = DEFAULT_PPS
		return 0
	end

	local state = PlayerState.GetOrCreate(player)
	state.Biomass = tonumber(data.Biomass) or 0
	state.PPS = math.max(DEFAULT_PPS, tonumber(data.PPS) or DEFAULT_PPS)
	state.OwnedUpgrades = type(data.OwnedUpgrades) == "table" and data.OwnedUpgrades or {}
	state.lastSeen = tonumber(data.lastSeen) or 0
	if state.Plot and state.PPS == 0 then
		state.PPS = DEFAULT_PPS
	end

	local now = os.time()
	local offlineSeconds = math.clamp(now - state.lastSeen, 0, MAX_OFFLINE_SECONDS)
	local bonus = 0
	if offlineSeconds > 0 and state.PPS > 0 then
		bonus = math.floor(offlineSeconds * state.PPS)
		state.Biomass += bonus
	end
	state.lastSeen = now

	return bonus
end

local function savePlayerData(player, force)
	local state = PlayerState.Get(player)
	if not state then
		return
	end
	if not DATASTORE_ENABLED then
		return
	end

	local now = os.clock()
	if saveInFlight[player] then
		return
	end
	if not force and lastSaveTime[player] and (now - lastSaveTime[player] < SAVE_DEBOUNCE) then
		return
	end

	saveInFlight[player] = true
	local key = tostring(player.UserId)
	local payload = serializeState(state)

	local success = runWithRetries(function()
		playerStore:SetAsync(key, payload)
	end)

	saveInFlight[player] = nil
	if success then
		lastSaveTime[player] = now
	end
end

local function ensureState(player)
	PlayerState.GetOrCreate(player)
	ensureLeaderboard(player)
	task.spawn(function()
		local bonus = loadPlayerData(player)
		local state = PlayerState.Get(player)
		if not state or not player.Parent then
			return
		end
		print("[Economy] State for", player.Name, "PPS", state.PPS, "Biomass", state.Biomass)
		biomassUpdate:FireClient(player, math.floor(state.Biomass))
		updateLeaderboard(player)
		if bonus > 0 then
			offlineEarningsEvent:FireClient(player, bonus)
		end
		dataLoadedEvent:Fire(player)
	end)
end

local function removeState(player)
	savePlayerData(player, true)
	PlayerState.Remove(player)
	leaderboardValues[player] = nil
	leaderboardTimers[player] = nil
end

Players.PlayerAdded:Connect(ensureState)
Players.PlayerRemoving:Connect(removeState)

for _, player in ipairs(Players:GetPlayers()) do
	ensureState(player)
end

task.spawn(function()
	local lastTick = os.clock()
	while true do
		task.wait(0.5)
		local now = os.clock()
		local dt = now - lastTick
		lastTick = now

		for player, state in pairs(PlayerState.GetAll()) do
			if player.Parent then
				state.Biomass += (state.PPS or 0) * dt
				biomassUpdate:FireClient(player, math.floor(state.Biomass))
				local lastUpdate = leaderboardTimers[player] or 0
				if os.clock() - lastUpdate >= LEADERBOARD_INTERVAL then
					updateLeaderboard(player)
				end
				-- debug: show ticking
				-- print("[EconomyTick]", player.Name, "PPS", state.PPS, "Biomass", state.Biomass)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)
		if not DATASTORE_ENABLED then
			continue
		end
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player, false)
		end
	end
end)

game:BindToClose(function()
	if not DATASTORE_ENABLED then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player, true)
	end
	task.wait(2)
end)
