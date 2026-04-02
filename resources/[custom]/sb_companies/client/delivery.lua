-- sb_companies | Client: Delivery
-- Company drivers claim and deliver orders to mechanic shops
-- Server spawns the van (CreateVehicleServerSetter + SetEntityOrphanMode)
-- Client manages blips, proximity checks, and completion

local SB = exports['sb_core']:GetCoreObject()

-- State
local isDelivering = false
local deliveryVan = nil          -- entity handle
local deliveryBlip = nil         -- GPS blip to dropoff
local deliveryData = nil         -- { orderId, shopId, companyId, dropoff }
local proximityThread = nil      -- thread tracking flag

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearDeliveryBlip()
    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
    end
    deliveryBlip = nil
end

local function DeleteDeliveryVan()
    if deliveryVan and DoesEntityExist(deliveryVan) then
        -- Request network control before deleting
        local netId = NetworkGetNetworkIdFromEntity(deliveryVan)
        NetworkRequestControlOfEntity(deliveryVan)
        local timeout = 0
        while not NetworkHasControlOfEntity(deliveryVan) do
            Wait(100)
            timeout = timeout + 100
            if timeout > 3000 then break end
        end
        SetEntityAsMissionEntity(deliveryVan, true, true)
        DeleteVehicle(deliveryVan)
    end
    deliveryVan = nil
end

local function CleanupDelivery()
    ClearDeliveryBlip()
    DeleteDeliveryVan()
    isDelivering = false
    deliveryData = nil
    proximityThread = nil
end

local function CreateDropoffBlip(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 477)  -- delivery box icon
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 5)    -- yellow
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Delivery Dropoff')
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
    return blip
end

-- ============================================================================
-- EVENT: Open Delivery Pickup
-- ============================================================================

RegisterNetEvent('sb_companies:openDeliveryPickup', function(companyId)
    if isDelivering then
        exports['sb_notify']:Notify('You are already on a delivery', 'error', 3000)
        return
    end
    if not companyId then return end

    -- Validate employee status
    if not IsCompanyEmployee(companyId, {'driver', 'manager'}) then
        exports['sb_notify']:Notify('You are not authorized for deliveries', 'error', 3000)
        return
    end

    exports['sb_notify']:Notify('Checking delivery queue...', 'info', 2000)

    SB.Functions.TriggerCallback('sb_companies:getDeliveryQueue', function(deliveries)
        if not deliveries or #deliveries == 0 then
            exports['sb_notify']:Notify('No deliveries available right now', 'info', 3000)
            return
        end

        -- Grab first available delivery (MVP: no selection UI)
        local delivery = deliveries[1]

        exports['sb_notify']:Notify('Claiming delivery...', 'info', 2000)

        SB.Functions.TriggerCallback('sb_companies:claimDelivery', function(result)
            if not result or not result.success then
                exports['sb_notify']:Notify(result and result.message or 'Failed to claim delivery', 'error', 3000)
                return
            end

            isDelivering = true

            -- Store delivery info
            deliveryData = {
                orderId = result.orderId,
                shopId = result.shopId,
                companyId = companyId,
                dropoff = result.dropoff,
            }

            -- The server spawns the van and sends back the netId
            -- We wait for the server event with the van entity
            exports['sb_notify']:Notify('Delivery claimed! Van is being prepared...', 'success', 4000)

        end, companyId, delivery.id)
    end, companyId)
end)

-- ============================================================================
-- EVENT: Van Spawned (from server after claim)
-- Server spawns van using CreateVehicleServerSetter + SetEntityOrphanMode
-- ============================================================================

RegisterNetEvent('sb_companies:client:vanSpawned', function(netId, dropoffCoords, shopLabel)
    if not isDelivering or not deliveryData then return end

    -- Wait for entity to exist on client
    local timeout = 0
    while not NetworkDoesNetworkIdExist(netId) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then
            exports['sb_notify']:Notify('Failed to receive delivery van', 'error', 4000)
            CleanupDelivery()
            return
        end
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then
        exports['sb_notify']:Notify('Failed to locate delivery van', 'error', 4000)
        CleanupDelivery()
        return
    end

    deliveryVan = vehicle

    -- Parse dropoff coordinates
    local dropoff = dropoffCoords
    if type(dropoffCoords) == 'table' and not dropoffCoords.x then
        dropoff = vector3(dropoffCoords[1] or dropoffCoords.x, dropoffCoords[2] or dropoffCoords.y, dropoffCoords[3] or dropoffCoords.z)
    end
    deliveryData.dropoff = dropoff

    -- Create blip to dropoff
    ClearDeliveryBlip()
    deliveryBlip = CreateDropoffBlip(dropoff, 'Deliver to ' .. (shopLabel or 'Shop'))

    exports['sb_notify']:Notify('Van loaded! Deliver to ' .. (shopLabel or 'the shop') .. '. Follow the GPS.', 'success', 6000)

    -- Start proximity check thread
    if not proximityThread then
        proximityThread = true
        CreateThread(function()
            while isDelivering and deliveryData and deliveryData.dropoff do
                Wait(1000)

                if not isDelivering then break end

                local ped = PlayerPedId()
                local playerCoords = GetEntityCoords(ped)
                local dropoffPos = deliveryData.dropoff
                local dist = #(playerCoords - vector3(dropoffPos.x, dropoffPos.y, dropoffPos.z))

                -- Check if player is near dropoff and in the delivery van
                if dist < 15.0 and deliveryVan and DoesEntityExist(deliveryVan) then
                    if IsPedInVehicle(ped, deliveryVan, false) then
                        local speed = GetEntitySpeed(deliveryVan)
                        if speed < 2.0 and dist < 8.0 then
                            -- Arrived at dropoff
                            CompleteDelivery()
                            break
                        elseif dist < 15.0 then
                            -- Close but still moving
                            exports['sb_notify']:Notify('Slow down near the dropoff point', 'info', 2000)
                        end
                    end
                end
            end
            proximityThread = nil
        end)
    end
end)

-- ============================================================================
-- COMPLETE DELIVERY
-- ============================================================================

function CompleteDelivery()
    if not isDelivering or not deliveryData then return end

    -- Disable further proximity checks
    local orderId = deliveryData.orderId

    exports['sb_progressbar']:Show(3000, 'Unloading delivery...')
    Wait(3000)

    SB.Functions.TriggerCallback('sb_companies:completeDelivery', function(result)
        if result and result.success then
            local payment = result.payment or Config.Delivery.driverPayment
            exports['sb_notify']:Notify('Delivery complete! You earned $' .. payment, 'success', 5000)
        else
            exports['sb_notify']:Notify(result and result.message or 'Delivery failed', 'error', 3000)
        end

        -- Tell server to clean up the van (server-owned entity)
        TriggerServerEvent('sb_companies:server:cleanupVan', deliveryVan and NetworkGetNetworkIdFromEntity(deliveryVan) or nil)

        CleanupDelivery()
    end, orderId)
end

-- ============================================================================
-- EVENT: Delivery Cancelled (from server, e.g. timeout)
-- ============================================================================

RegisterNetEvent('sb_companies:client:deliveryCancelled', function(reason)
    if not isDelivering then return end

    exports['sb_notify']:Notify(reason or 'Delivery cancelled', 'error', 5000)

    -- Tell server to clean up the van
    TriggerServerEvent('sb_companies:server:cleanupVan', deliveryVan and NetworkGetNetworkIdFromEntity(deliveryVan) or nil)

    CleanupDelivery()
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isDelivering then
        CleanupDelivery()
    end
end)
