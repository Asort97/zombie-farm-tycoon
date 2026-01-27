local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClearDataEvent = ReplicatedStorage:WaitForChild("ClearDataEvent")

local player = Players.LocalPlayer

-- Создаем UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClearDataUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(0.5, -100, 0.9, -25)
button.Text = "Очистить сохранения"
button.BackgroundColor3 = Color3.new(1, 0, 0)
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = screenGui

-- Обработчик нажатия
button.MouseButton1Click:Connect(function()
    ClearDataEvent:FireServer()
end)