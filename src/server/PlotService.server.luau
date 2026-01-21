local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
print("SUCK")
local PlotsFolder = Workspace:WaitForChild("Plots")

local assignedPlots = {}

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
		player.RespawnLocation = nil
		print("Released plot for", player.Name)
	end
end

Players.PlayerAdded:Connect(assignPlot)
Players.PlayerRemoving:Connect(releasePlot)

print("PlotService loaded")
