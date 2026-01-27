local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomassUpdate = remotesFolder:WaitForChild("BiomassUpdate")
local inventoryUpdate = remotesFolder:WaitForChild("InventoryUpdate")
local inventoryAction = remotesFolder:WaitForChild("InventoryAction")
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
local inventoryButton = Instance.new("TextButton")
inventoryButton.Name = "InventoryButton"
inventoryButton.Text = "Inventory"
inventoryButton.Size = UDim2.new(0, 100, 0, 24)
inventoryButton.Position = UDim2.new(1, -110, 0, 40)
inventoryButton.TextColor3 = Color3.new(1,1,1)
inventoryButton.BackgroundColor3 = Color3.new(0,0,0)
inventoryButton.Parent = screenGui

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryFrame"
inventoryFrame.Visible = false
inventoryFrame.Size = UDim2.new(0, 340, 0, 380)
inventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
inventoryFrame.Position = UDim2.new(0.5, -0, 0.5, -0)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
inventoryFrame.BorderSizePixel = 0
inventoryFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Name = "InventoryTitle"
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(15,15,15)
title.BorderSizePixel = 0
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1,1,1)
title.Text = "Zombie Inventory"
title.TextSize = 18
title.Parent = inventoryFrame

local slotsContainer = Instance.new("Frame")
slotsContainer.Name = "SlotsContainer"
slotsContainer.Size = UDim2.new(1, -20, 0, 40)
slotsContainer.Position = UDim2.new(0, 10, 0, 35)
slotsContainer.BackgroundTransparency = 1
slotsContainer.Parent = inventoryFrame

local slotsLayout = Instance.new("UIListLayout")
slotsLayout.FillDirection = Enum.FillDirection.Horizontal
slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
slotsLayout.Padding = UDim.new(0,10)
slotsLayout.Parent = slotsContainer

local activeSlots = {}
for i=1,3 do
	local slot = Instance.new("TextLabel")
	slot.Name = "ActiveSlot"..i
	slot.Size = UDim2.new(0, 100, 1, 0)
	slot.BackgroundColor3 = Color3.fromRGB(50,50,50)
	slot.TextColor3 = Color3.new(1,1,1)
	slot.Font = Enum.Font.Gotham
	slot.Text = "Empty"
	slot.BorderSizePixel = 0
	slot.Parent = slotsContainer
	table.insert(activeSlots, slot)
end

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -100)
scrollFrame.Position = UDim2.new(0, 10, 0, 80)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 6
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = inventoryFrame

local zombiesList = Instance.new("UIListLayout")
zombiesList.Parent = scrollFrame
zombiesList.SortOrder = Enum.SortOrder.LayoutOrder
zombiesList.Padding = UDim.new(0,5)

local function toggleInventory()
	inventoryFrame.Visible = not inventoryFrame.Visible
end

inventoryButton.MouseButton1Click:Connect(toggleInventory)

local function createZombieEntry(zombie, index)
	local entry = Instance.new("TextButton")
	entry.Name = "Zombie_"..zombie.id
	entry.Size = UDim2.new(1, 0, 0, 30)
	entry.LayoutOrder = index
	entry.AutoButtonColor = true
	entry.TextColor3 = Color3.new(1,1,1)
	entry.Font = Enum.Font.SourceSans
	entry.Text = zombie.rarity.." ("..zombie.pps.." PPS)"
	entry.BackgroundColor3 = Color3.fromRGB(60,60,60)
	entry.Parent = scrollFrame

	local buttons = Instance.new("Frame")
	buttons.Size = UDim2.new(0,120,0,30)
	buttons.Position = UDim2.new(1,-120,0,0)
	buttons.BackgroundTransparency = 1
	buttons.Parent = entry

	local equip = Instance.new("TextButton")
	equip.Name = "EquipButton"
	equip.Size = UDim2.new(0,60,1,0)
	equip.Position = UDim2.new(0,0,0,0)
	equip.Text = "Equip"
	equip.BackgroundColor3 = Color3.fromRGB(100,100,100)
	equip.TextColor3 = Color3.new(1,1,1)
	equip.Parent = buttons

	local sell = Instance.new("TextButton")
	sell.Name = "SellButton"
	sell.Size = UDim2.new(0,60,1,0)
	sell.Position = UDim2.new(0,65,0,0)
	sell.Text = "Sell"
	sell.BackgroundColor3 = Color3.fromRGB(150,30,30)
	sell.TextColor3 = Color3.new(1,1,1)
	sell.Parent = buttons

	return entry, equip, sell
end

local function updateInventory(zombies)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i,zombie in ipairs(zombies or {}) do
		local entry,equip,sell = createZombieEntry(zombie,i)
		sell.MouseButton1Click:Connect(function()
			inventoryAction:FireServer("SellZombie", zombie.id)
		end)
		-- equip placeholder
	end
	scrollFrame.CanvasSize = UDim2.new(0,0,0, (zombies and #zombies*35) or 0)
end

inventoryUpdate.OnClientEvent:Connect(function(zombies)
	updateInventory(zombies)
end)

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
