local QBCore = exports['qb-core']:GetCoreObject()

-- Start a delivery mission
RegisterNetEvent('eh-deliveries:server:StartDelivery')
AddEventHandler('eh-deliveries:server:StartDelivery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "delivery" then
        local randomLocation = Config.DeliveryLocations[math.random(#Config.DeliveryLocations)]
        TriggerClientEvent('eh-deliveries:client:StartDelivery', src, randomLocation)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You are not a delivery driver!', 'error')
    end
end)

-- Complete a delivery
RegisterNetEvent('eh-deliveries:server:CompleteDelivery')
AddEventHandler('eh-deliveries:server:CompleteDelivery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "delivery" then
        local payment = math.random(Config.DeliveryPaymentMin, Config.DeliveryPaymentMax)
        Player.Functions.AddMoney('cash', payment, 'Delivery payment')
        TriggerClientEvent('QBCore:Notify', src, 'Delivery completed! You earned $' .. payment, 'success')
    end
end)

