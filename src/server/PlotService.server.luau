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
local biomassUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BiomassUpdate")
local ClearDataEvent = ReplicatedStorage:WaitForChild("ClearDataEvent")
local templatesRoot = ServerStorage:FindFirstChild("UpgradeVisualTemplates")
if not templatesRoot then
	templatesRoot = Instance.new("Folder")
	templatesRoot.Name = "UpgradeVisualTemplates"
	templatesRoot.Parent = ServerStorage
end

local assignedPlots = {}
local buttonDebounce = {}

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
end

local function releasePlot(player)
	local plot = assignedPlots[player.UserId]
	if plot then
		plot:SetAttribute("OwnerUserId", nil)
		assignedPlots[player.UserId] = nil
		PlayerState.ReleasePlot(player)
		player.RespawnLocation = nil
		print("Released plot for", player.Name)
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
		state.PPS = (state.PPS + (upgrade.addPps or 0)) * (upgrade.addMult or 1)
		state.OwnedUpgrades[upgrade.id] = true
		print("Purchased", upgrade.id, "new PPS", state.PPS, "biomass", state.Biomass)
		biomassUpdate:FireClient(player, math.floor(state.Biomass))
		applyVisualUpgrade(plot, upgrade.id)

		local emitter = button:FindFirstChildWhichIsA("ParticleEmitter")
		if emitter then
			emitter.Enabled = true
			task.delay(0.6, function()
				if emitter then
					emitter.Enabled = false
				end
			end)
		end

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
end

dataLoadedEvent.Event:Connect(function(player)
	local plot = assignedPlots[player.UserId]
	if plot then
		applyVisualsForPlayerPlot(player, plot)
	end
end)

ClearDataEvent.OnServerEvent:Connect(function(player)
	local state = PlayerState.Get(player)
	if state then
		state.Biomass = 0
		state.OwnedUpgrades = {}
		state.PPS = PlayerState.DEFAULT_PPS or 10

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

print("PlotService loaded")
