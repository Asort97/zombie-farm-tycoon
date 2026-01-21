local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomassUpdate = remotesFolder:WaitForChild("BiomassUpdate")
local offlineEarnings = remotesFolder:WaitForChild("OfflineEarnings")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BiomassUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "BiomassLabel"
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = false
label.TextSize = 18
label.Font = Enum.Font.Arial
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Size = UDim2.new(0, 200, 0, 24)
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -8, 0, 8)
label.Text = "Biomass: 0"
label.Parent = screenGui

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "OfflineEarningsLabel"
messageLabel.BackgroundTransparency = 0.3
messageLabel.BackgroundColor3 = Color3.new(0, 0, 0)
messageLabel.TextColor3 = Color3.new(1, 1, 1)
messageLabel.TextScaled = false
messageLabel.TextSize = 18
messageLabel.Font = Enum.Font.Arial
messageLabel.TextXAlignment = Enum.TextXAlignment.Center
messageLabel.TextYAlignment = Enum.TextYAlignment.Center
messageLabel.Size = UDim2.new(0, 320, 0, 36)
messageLabel.AnchorPoint = Vector2.new(0.5, 0)
messageLabel.Position = UDim2.new(0.5, 0, 0, 40)
messageLabel.Visible = false
messageLabel.Text = ""
messageLabel.Parent = screenGui

local messageToken = 0

biomassUpdate.OnClientEvent:Connect(function(value)
	label.Text = "Biomass: " .. tostring(value)
end)

offlineEarnings.OnClientEvent:Connect(function(amount)
	messageToken += 1
	local currentToken = messageToken
	messageLabel.Text = "Offline earnings: +" .. tostring(amount) .. " Biomass"
	messageLabel.Visible = true
	task.delay(5, function()
		if currentToken == messageToken then
			messageLabel.Visible = false
		end
	end)
end)
