local DataStoreService = game:GetService("DataStoreService")
local UpgradesDataStore = DataStoreService:GetDataStore("UpgradesDataStore")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function clearData(userId)
    local success, err = pcall(function()
        UpgradesDataStore:RemoveAsync(userId)
    end)
    if success then
        print("Данные для пользователя " .. userId .. " успешно удалены.")
    else
        warn("Ошибка при удалении данных: " .. err)
    end
end

-- Укажите UserId игрока, чьи данные нужно удалить
local userId = 12345678 -- Замените на ваш UserId
clearData(userId)

-- Создаем RemoteEvent для очистки данных
local ClearDataEvent = Instance.new("RemoteEvent")
ClearDataEvent.Name = "ClearDataEvent"
ClearDataEvent.Parent = ReplicatedStorage

ClearDataEvent.OnServerEvent:Connect(function(player)
    local success, err = pcall(function()
        UpgradesDataStore:RemoveAsync(player.UserId)
    end)
    if success then
        print("Данные для пользователя " .. player.UserId .. " успешно удалены.")
    else
        warn("Ошибка при удалении данных: " .. err)
    end
end)