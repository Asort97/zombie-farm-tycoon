local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local UpgradesConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradesConfig"))
local PlotsFolder = Workspace:FindFirstChild("Plots")
if not PlotsFolder then
	PlotsFolder = Instance.new("Folder")
	PlotsFolder.Name = "Plots"
	PlotsFolder.Parent = Workspace
	print("[PlotService] Created missing Plots folder in Workspace")
end
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomassUpdate = remotesFolder:WaitForChild("BiomassUpdate")
local inventoryUpdate = remotesFolder:FindFirstChild("InventoryUpdate")
if not inventoryUpdate then
	inventoryUpdate = Instance.new("RemoteEvent")
	inventoryUpdate.Name = "InventoryUpdate"
	inventoryUpdate.Parent = remotesFolder
end
local inventoryAction = remotesFolder:FindFirstChild("InventoryAction")
if not inventoryAction then
	inventoryAction = Instance.new("RemoteEvent")
	inventoryAction.Name = "InventoryAction"
	inventoryAction.Parent = remotesFolder
end
local function sendInventory(player)
	local state = PlayerState.Get(player)
	if state then
		inventoryUpdate:FireClient(player, state.Zombies or {})
	end
end
local ClearDataEvent = ReplicatedStorage:WaitForChild("ClearDataEvent")
local templatesRoot = ServerStorage:FindFirstChild("UpgradeVisualTemplates")
if not templatesRoot then
	templatesRoot = Instance.new("Folder")
	templatesRoot.Name = "UpgradeVisualTemplates"
	templatesRoot.Parent = ServerStorage
end

local assignedPlots = {}
local buttonDebounce = {}
local effectsFolder = Workspace:FindFirstChild("UpgradeEffects")
math.randomseed(os.clock())
if not effectsFolder then
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "UpgradeEffects"
	effectsFolder.Parent = Workspace
end

local function spawnPurchaseEffect(button)
	local emitters = {}
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant:Clone())
		end
	end

	if #emitters == 0 then
		return
	end

	local host = Instance.new("Part")
	host.Name = button.Name .. "_Effect"
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.Transparency = 1
	host.Size = Vector3.new(1, 1, 1)
	host.CFrame = button.CFrame
	host.Parent = effectsFolder

	for _, emitter in ipairs(emitters) do
		emitter.Enabled = true
		emitter.Parent = host
	end

	task.delay(0.8, function()
		for _, emitter in ipairs(emitters) do
			if emitter then
				emitter.Enabled = false
			end
		end
	end)

	task.delay(1.2, function()
		if host then
			host:Destroy()
		end
	end)
end

local dataLoadedEvent = ServerScriptService:FindFirstChild("PlayerDataLoaded")
if not dataLoadedEvent then
	dataLoadedEvent = Instance.new("BindableEvent")
	dataLoadedEvent.Name = "PlayerDataLoaded"
	dataLoadedEvent.Parent = ServerScriptService
end

local function hasRequirements(state, upgrade)
	for _, requiredId in ipairs(upgrade.requires or {}) do
		if not state.OwnedUpgrades[requiredId] then
			return false
		end
	end
	return true
end

local function ensurePlotVisualsFolder(plot)
	local visuals = plot:FindFirstChild("Visuals")
	if not visuals then
		visuals = Instance.new("Folder")
		visuals.Name = "Visuals"
		visuals.Parent = plot
	end
	return visuals
end

local function getUpgradeTemplate(plotName, upgradeName)
	local plotTemplate = templatesRoot:FindFirstChild(plotName)
	if not plotTemplate then
		return nil
	end
	return plotTemplate:FindFirstChild(upgradeName)
end

local upgradeIndexById = {}
local upgradeNameById = {}
for index, upgrade in ipairs(UpgradesConfig) do
	upgradeIndexById[upgrade.id] = index
	upgradeNameById[upgrade.id] = "Upgrade" .. tostring(index)
end

local function updatePlotSign(plot, player)
	if not plot then
		return
	end

	local sign = plot:FindFirstChild("PlotSignOwner1")
	if not sign then
		return
	end

	local label = sign:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		return
	end

	if player then
		label.Text = string.upper(player.Name) .. "'S PLOT"
	else
		label.Text = "EMPTY"
	end
end

local HATCH_COST = 1000
local HATCH_DEBOUNCE = 1
local hatchCooldowns = {}

local ZOMBIE_RARITIES = {
	{name = "Common", chance = 60, pps = 2, color = Color3.fromRGB(145, 145, 145)},
	{name = "Uncommon", chance = 25, pps = 5, color = Color3.fromRGB(0, 205, 0)},
	{name = "Rare", chance = 10, pps = 12, color = Color3.fromRGB(0, 128, 255)},
	{name = "Epic", chance = 4, pps = 30, color = Color3.fromRGB(170, 85, 255)},
	{name = "Legendary", chance = 1, pps = 80, color = Color3.fromRGB(255, 200, 0)},
}

local function rollZombieRarity()
	local roll = math.random(1, 100)
	local sum = 0
	for _, rarity in ipairs(ZOMBIE_RARITIES) do
		sum += rarity.chance
		if roll <= sum then
			return rarity
		end
	end
	return ZOMBIE_RARITIES[#ZOMBIE_RARITIES]
end

local function ensureTemplateFolder(plot)
	local plotTemplate = templatesRoot:FindFirstChild(plot.Name)
	if not plotTemplate then
		plotTemplate = Instance.new("Folder")
		plotTemplate.Name = plot.Name
		plotTemplate.Parent = templatesRoot
	end
	return plotTemplate
end

local function collectVisualTemplates()
	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		local visuals = plot:FindFirstChild("Visuals")
		if visuals then
			local plotTemplate = ensureTemplateFolder(plot)
			for _, child in ipairs(visuals:GetChildren()) do
				if child:IsA("Folder") then
					local clone = child:Clone()
					clone.Parent = plotTemplate
				end
				child:Destroy()
			end
		end
	end
end

collectVisualTemplates()

local function spawnVisualForUpgrade(plot, upgradeId)
	local upgradeName = upgradeNameById[upgradeId]
	if not upgradeName then
		return
	end
	local template = getUpgradeTemplate(plot.Name, upgradeName)
	if not template then
		return
	end

	local visuals = ensurePlotVisualsFolder(plot)
	local existing = visuals:FindFirstChild(upgradeName)
	if existing then
		existing:Destroy()
	end

	template:Clone().Parent = visuals
end

local function applyVisualsForPlayerPlot(player, plot)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	local visuals = ensurePlotVisualsFolder(plot)
	for _, child in ipairs(visuals:GetChildren()) do
		child:Destroy()
	end

	for upgradeId, owned in pairs(state.OwnedUpgrades) do
		if owned then
			spawnVisualForUpgrade(plot, upgradeId)
		end
	end
end

local function applyVisualUpgrade(plot, upgradeId)
	spawnVisualForUpgrade(plot, upgradeId)
end

local function getPlotSpawn(plot)
	local spawnLocation = plot:FindFirstChildWhichIsA("SpawnLocation")
	if spawnLocation then
		return spawnLocation
	end

	local spawnPart = plot:FindFirstChild("Spawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart
	end

	return nil
end

local function harvestLoosePlots()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			local hasButton = child:FindFirstChild("Button_Upgrade1")
			if hasButton then
				child.Parent = PlotsFolder
				print("[PlotService] Moved plot into Plots folder:", child.Name)
			end
		end
	end
end

local function getFreePlot()
	if #PlotsFolder:GetChildren() == 0 then
		harvestLoosePlots()
	end
	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		if not plot:GetAttribute("OwnerUserId") then
			return plot
		end
	end
	return nil
end

local function assignPlot(player)
	local plot = getFreePlot()
	if not plot then
		warn("[PlotService] No free plots for", player.Name)
		return
	end

	plot:SetAttribute("OwnerUserId", player.UserId)
	assignedPlots[player.UserId] = plot
	PlayerState.AssignPlot(player, plot)
	applyVisualsForPlayerPlot(player, plot)

	local spawn = getPlotSpawn(plot)
	if spawn then
		if spawn:IsA("SpawnLocation") then
			player.RespawnLocation = spawn
		end

		player.CharacterAdded:Connect(function(character)
			task.wait()
			character:MoveTo(spawn.Position + Vector3.new(0, 3, 0))
		end)

		if player.Character then
			player.Character:MoveTo(spawn.Position + Vector3.new(0, 3, 0))
		end
	else
		warn("No spawn found in plot", plot.Name)
	end

	print("Assigned", player.Name, "to", plot.Name)
	updatePlotSign(plot, player)
end

local function releasePlot(player)
	local plot = assignedPlots[player.UserId]
	if plot then
		plot:SetAttribute("OwnerUserId", nil)
		assignedPlots[player.UserId] = nil
		PlayerState.ReleasePlot(player)
		player.RespawnLocation = nil
		print("Released plot for", player.Name)
		updatePlotSign(plot, nil)
	end
end

Players.PlayerAdded:Connect(assignPlot)
Players.PlayerRemoving:Connect(releasePlot)

for _, player in ipairs(Players:GetPlayers()) do
	assignPlot(player)
end

local function setupUpgradeButton(plot, button, upgrade)
	if not button or not button:IsA("BasePart") then
		return
	end

	button.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		print("[PlotService] Button touched:", button.Name, "by", player.Name)

		if buttonDebounce[button] then
			return
		end

		local ownerId = plot:GetAttribute("OwnerUserId")
		if ownerId ~= player.UserId then
			print("[PlotService] Wrong owner:", plot.Name, "owner", ownerId, "player", player.UserId)
			return
		end

		local state = PlayerState.Get(player)
		if not state or state.Plot ~= plot then
			print("[PlotService] State mismatch for", player.Name, "state plot", state and state.Plot and state.Plot.Name, "wanted", plot.Name)
			return
		end

		if state.OwnedUpgrades[upgrade.id] then
			print("Upgrade already owned", upgrade.id)
			return
		end

		if not hasRequirements(state, upgrade) then
			print("Requirements not met for", upgrade.id)
			return
		end

		if state.Biomass < upgrade.price then
			print("Not enough biomass for", upgrade.id, "have", state.Biomass, "need", upgrade.price)
			return
		end

		buttonDebounce[button] = true
		state.Biomass -= upgrade.price
		state.InfraPPS = (state.InfraPPS + (upgrade.addPps or 0)) * (upgrade.addMult or 1)
		state.OwnedUpgrades[upgrade.id] = true
		local totalPPS = PlayerState.GetTotalPPS(state)
		print("Purchased", upgrade.id, "new InfraPPS", state.InfraPPS, "total PPS", totalPPS, "biomass", state.Biomass)
		biomassUpdate:FireClient(player, math.floor(state.Biomass))
		applyVisualUpgrade(plot, upgrade.id)

		spawnPurchaseEffect(button)

	button.CanTouch = false
	button.CanQuery = false
	button.Transparency = 1
	task.delay(0.6, function()
		if button then
			buttonDebounce[button] = nil
			button:Destroy()
		end
	end)
	end)
end

local function canHatch(player)
	local now = os.clock()
	local last = hatchCooldowns[player]
	if last and now - last < HATCH_DEBOUNCE then
		return false
	end
	hatchCooldowns[player] = now
	return true
end

local function setupHatchButton(plot, button)
	if not button or not button:IsA("BasePart") then
		return
	end

	print("[PlotService] Hatch button hooked on", plot.Name)

	local baseCost = HATCH_COST
	button.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		print("[PlotService] Hatch touched by", player.Name)

		if not canHatch(player) then
			return
		end

		local ownerId = plot:GetAttribute("OwnerUserId")
		if ownerId ~= player.UserId then
			print("[PlotService] Hatch rejected wrong owner", ownerId, player.UserId)
			return
		end

		local state = PlayerState.Get(player)
		if not state or state.Plot ~= plot then
			return
		end

		if state.Biomass < baseCost then
			return
		end

		state.Biomass -= baseCost
		local rarity = rollZombieRarity()
		local zombieId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
		local zombieRecord = {id = zombieId, rarity = rarity.name, pps = rarity.pps, color = rarity.color}
		PlayerState.AddZombie(player, zombieRecord)

		local totalPPS = PlayerState.GetTotalPPS(state)
		print("[PlotService] Hatched", rarity.name, "zombie for", player.Name, "total PPS", totalPPS)
		biomassUpdate:FireClient(player, math.floor(state.Biomass))
		spawnPurchaseEffect(button)
		sendInventory(player)
	end)
end

for _, plot in ipairs(PlotsFolder:GetChildren()) do
	for index, upgrade in ipairs(UpgradesConfig) do
		local buttonName = "Button_Upgrade" .. tostring(index)
		local button = plot:FindFirstChild(buttonName)
		if button then
			setupUpgradeButton(plot, button, upgrade)
		else
			print("[PlotService] Missing", buttonName, "in plot", plot.Name)
		end
	end
	local hatchButton = plot:FindFirstChild("Button_HatchZombie")
	if hatchButton then
		setupHatchButton(plot, hatchButton)
	else
		print("[PlotService] Missing Button_HatchZombie in plot", plot.Name)
	end
end

dataLoadedEvent.Event:Connect(function(player)
	local plot = assignedPlots[player.UserId]
	if plot then
		applyVisualsForPlayerPlot(player, plot)
		updatePlotSign(plot, player)
		local state = PlayerState.Get(player)
		if state then
			sendInventory(player)
		end
	end
end)

ClearDataEvent.OnServerEvent:Connect(function(player)
	local state = PlayerState.Get(player)
	if state then
		state.Biomass = 0
		state.OwnedUpgrades = {}
		state.InfraPPS = PlayerState.DEFAULT_INFRA_PPS or 10
		state.Multiplier = PlayerState.DEFAULT_MULTIPLIER or 1
		PlayerState.RebuildZombies(player, {})

		local plot = state.Plot
		if plot then
			local visuals = plot:FindFirstChild("Visuals")
			if visuals then
				for _, child in ipairs(visuals:GetChildren()) do
					child:Destroy()
				end
			end
		end

		biomassUpdate:FireClient(player, state.Biomass)
	end
end)

inventoryAction.OnServerEvent:Connect(function(player, action, targetId)
	local state = PlayerState.Get(player)
	if not state then
		return
	end
	if action == "SellZombie" and targetId then
		local indexToRemove
		for i,zombie in ipairs(state.Zombies) do
			if zombie.id == targetId then
				indexToRemove = i
				break
			end
		end
		if indexToRemove then
			local zombie = table.remove(state.Zombies, indexToRemove)
			state.Biomass += (zombie.pps or 0) * 100
			PlayerState.RebuildZombies(player, state.Zombies)
			if state.Plot then
			end
			biomassUpdate:FireClient(player, math.floor(state.Biomass))
			sendInventory(player)
		end
		sendInventory(player)
	end
end)

print("PlotService loaded")
