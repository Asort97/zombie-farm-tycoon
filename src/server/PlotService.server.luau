local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local UpgradesConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradesConfig"))
local PlotsFolder = Workspace:WaitForChild("Plots")
local biomassUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BiomassUpdate")

local assignedPlots = {}
local buttonDebounce = {}

local function hasRequirements(state, upgrade)
	for _, requiredId in ipairs(upgrade.requires or {}) do
		if not state.OwnedUpgrades[requiredId] then
			return false
		end
	end
	return true
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

local function getFreePlot()
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
		warn("No free plots for", player.Name)
		return
	end

	plot:SetAttribute("OwnerUserId", player.UserId)
	assignedPlots[player.UserId] = plot
	PlayerState.AssignPlot(player, plot)

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

		if buttonDebounce[button] then
			return
		end

		if plot:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end

		local state = PlayerState.Get(player)
		if not state or state.Plot ~= plot then
			return
		end

		if state.OwnedUpgrades[upgrade.id] then
			return
		end

		if not hasRequirements(state, upgrade) then
			return
		end

		if state.Biomass < upgrade.price then
			return
		end

		buttonDebounce[button] = true
		state.Biomass -= upgrade.price
		state.PPS = (state.PPS + (upgrade.addPps or 0)) * (upgrade.addMult or 1)
		state.OwnedUpgrades[upgrade.id] = true
		biomassUpdate:FireClient(player, math.floor(state.Biomass))
		button:Destroy()
	end)
end

for _, plot in ipairs(PlotsFolder:GetChildren()) do
	for index, upgrade in ipairs(UpgradesConfig) do
		local buttonName = "Button_Upgrade" .. tostring(index)
		local button = plot:FindFirstChild(buttonName)
		if button then
			setupUpgradeButton(plot, button, upgrade)
		end
	end
end

print("PlotService loaded")
