local QBCore = exports['qb-core']:GetCoreObject()

local startNPCLocation = Config.StartNPCLocation
local deliveryBlip = nil
local deliveryLocation = nil
local deliveryVehicle = nil
local packageProp = nil
local isHoldingPackage = false
local startNPCBlip = nil
local deliveriesCompleted = 0

-- Create Start NPC
Citizen.CreateThread(function()
    local pedModel = Config.DeliveryNPCModel
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(0)
    end
    local npc = CreatePed(4, pedModel, startNPCLocation.x, startNPCLocation.y, startNPCLocation.z - 1, startNPCLocation.w, false, true)
    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    -- Create blip for start NPC
    startNPCBlip = AddBlipForCoord(startNPCLocation.x, startNPCLocation.y, startNPCLocation.z)
    SetBlipSprite(startNPCBlip, 67)
    SetBlipColour(startNPCBlip, 5)
    SetBlipScale(startNPCBlip, 0.7)
    SetBlipAsShortRange(startNPCBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Job")
    EndTextCommandSetBlipName(startNPCBlip)
end)

-- Create interaction zone
Citizen.CreateThread(function()
    exports['qb-target']:AddBoxZone("delivery_start_npc", vector3(startNPCLocation.x, startNPCLocation.y, startNPCLocation.z), 1.0, 1.0, {
        name = "delivery_start_npc",
        heading = startNPCLocation.w,
        debugPoly = false,
    }, {
        options = {
            {
                type = "client",
                event = "eh-deliveries:client:OpenDeliveryMenu",
                icon = "fas fa-box",
                label = "Talk to Delivery Manager",
                job = "delivery",
            },
        },
        distance = 2.5
    })
end)

-- Open delivery menu
RegisterNetEvent('eh-deliveries:client:OpenDeliveryMenu')
AddEventHandler('eh-deliveries:client:OpenDeliveryMenu', function()
    lib.showContext('delivery_menu')
end)

-- Create ox_lib context menu
lib.registerContext({
    id = 'delivery_menu',
    title = 'Delivery Manager',
    options = {
        {
            title = 'Start Delivery Job',
            description = 'Begin a new delivery mission',
            onSelect = function()
                TriggerEvent('eh-deliveries:client:StartDeliveryJob')
            end,
        },
        {
            title = 'Cancel Delivery',
            description = 'Cancel the current delivery mission',
            onSelect = function()
                TriggerEvent('eh-deliveries:client:CancelDelivery')
            end,
        },
        {
            title = 'Close',
            description = 'Close Menu',
            onSelect = function() end,
        }
    }
})

-- Start delivery job
RegisterNetEvent('eh-deliveries:client:StartDeliveryJob')
AddEventHandler('eh-deliveries:client:StartDeliveryJob', function()
    deliveriesCompleted = 0
    TriggerServerEvent('eh-deliveries:server:StartDelivery')
end)

-- Start delivery mission
RegisterNetEvent('eh-deliveries:client:StartDelivery')
AddEventHandler('eh-deliveries:client:StartDelivery', function(location)
    deliveryLocation = location
    QBCore.Functions.Notify('Delivery location has been marked on your GPS', 'success')
    
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    deliveryBlip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 5)

    if not DoesEntityExist(deliveryVehicle) then
        SpawnDeliveryVehicle()
    end
    CreateDeliveryZone(location)
end)

-- Spawn delivery vehicle
function SpawnDeliveryVehicle()
    local vehicleModel = Config.VehicleSpawn.model
    local spawnCoords = Config.VehicleSpawn.coords

    QBCore.Functions.SpawnVehicle(vehicleModel, function(vehicle)
        SetEntityHeading(vehicle, spawnCoords.w)
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(vehicle))
        SetVehicleEngineOn(vehicle, true, true)
        deliveryVehicle = vehicle
        
        -- Add target to vehicle trunk
        exports['qb-target']:AddTargetEntity(vehicle, {
            options = {
                {
                    type = "client",
                    event = "eh-deliveries:client:TakePackage",
                    icon = "fas fa-box",
                    label = "Take Package",
                    job = "delivery",
                },
            },
            distance = 2.5
        })
    end, spawnCoords, true)
end

-- Cancel delivery
RegisterNetEvent('eh-deliveries:client:CancelDelivery')
AddEventHandler('eh-deliveries:client:CancelDelivery', function()
    if deliveryLocation then
        if deliveryBlip then
            RemoveBlip(deliveryBlip)
        end
        if packageProp then
            DeleteObject(packageProp)
        end
        if DoesEntityExist(deliveryVehicle) then
            DeleteVehicle(deliveryVehicle)
        end
        
        deliveryLocation = nil
        isHoldingPackage = false
        deliveriesCompleted = 0
        
        exports.ox_target:removeZone('delivery_zone')
        
        QBCore.Functions.Notify('Delivery mission canceled', 'info')
    else
        QBCore.Functions.Notify('You don\'t have an active delivery to cancel', 'error')
    end
end)

-- Take package from vehicle
RegisterNetEvent('eh-deliveries:client:TakePackage')
AddEventHandler('eh-deliveries:client:TakePackage', function()
    if not isHoldingPackage then
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
        
        if vehicle ~= 0 and vehicle == deliveryVehicle then
            RequestAnimDict(Config.DeliveryAnimDict)
            while not HasAnimDictLoaded(Config.DeliveryAnimDict) do
                Citizen.Wait(0)
            end
            
            TaskPlayAnim(playerPed, Config.DeliveryAnimDict, Config.DeliveryAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
            
            RequestModel(Config.PackageProp)
            while not HasModelLoaded(Config.PackageProp) do
                Citizen.Wait(0)
            end
            
            packageProp = CreateObject(Config.PackageProp, coords.x, coords.y, coords.z, true, true, true)
            AttachEntityToEntity(packageProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            
            isHoldingPackage = true
            QBCore.Functions.Notify('You have taken the cardboard box. Deliver it to the marked location.', 'success')
        end
    else
        QBCore.Functions.Notify('You are already holding a package!', 'error')
    end
end)

-- Deliver package
RegisterNetEvent('eh-deliveries:client:DeliverPackage')
AddEventHandler('eh-deliveries:client:DeliverPackage', function()
    if isHoldingPackage then
        local playerPed = PlayerPedId()
        
        -- Start the progressbar
        if lib.progressCircle({
            duration = 5000,
            position = 'bottom',
            label = 'Delivering package...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
            },
            anim = {
                dict = 'mp_common',
                clip = 'givetake1_a'
            },
        }) then
            -- Progressbar finished successfully
            ClearPedTasks(playerPed)
            DeleteObject(packageProp)
            
            isHoldingPackage = false
            
            TriggerServerEvent('eh-deliveries:server:CompleteDelivery')
            RemoveBlip(deliveryBlip)
            exports.ox_target:removeZone('delivery_zone')
            deliveryLocation = nil
            
            deliveriesCompleted = deliveriesCompleted + 1
            
            if deliveriesCompleted >= Config.MaxDeliveries then
                QBCore.Functions.Notify('You have completed all deliveries. Return to the start location.', 'success')
                SetNewWaypoint(startNPCLocation.x, startNPCLocation.y)
            else
                TriggerServerEvent('eh-deliveries:server:StartDelivery')
            end
            
            QBCore.Functions.Notify('Delivery completed!', 'success')
        else
            -- Progressbar was cancelled
            QBCore.Functions.Notify('Delivery cancelled', 'error')
        end
    else
        QBCore.Functions.Notify('You are not holding a package!', 'error')
    end
end)

-- Text UI thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if deliveryLocation and isHoldingPackage then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - vector3(deliveryLocation.x, deliveryLocation.y, deliveryLocation.z))
            
            if distance < 1.5 then
                lib.showTextUI('[E] Deliver Package', {
                    position = "top-center",
                    icon = 'box',
                    style = {
                        borderRadius = 0,
                        backgroundColor = '#48BB78',
                        color = 'white'
                    }
                })
                
                if IsControlJustReleased(0, 38) then -- 'E' key
                    TriggerEvent('eh-deliveries:client:DeliverPackage')
                end
            else
                lib.hideTextUI()
            end
        else
            lib.hideTextUI()
            Citizen.Wait(1000)
        end
    end
end)

