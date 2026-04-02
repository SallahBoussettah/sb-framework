-- sb_rental Client Main
-- NPC Spawning, Blips, NUI Control

local SB = exports['sb_core']:GetCoreObject()
local spawnedNPCs = {}
local blips = {}
local currentLocation = nil
local nuiOpen = false

-- Spawn NPCs at all rental locations
function SpawnRentalNPCs()
    local modelHash = GetHashKey(Config.NPCModel)

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end

    for locationId, location in pairs(Config.Locations) do
        local ped = CreatePed(4, modelHash, location.npcPos.x, location.npcPos.y, location.npcPos.z - 1.0, location.npcPos.w, false, true)

        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanPlayAmbientAnims(ped, true)
        SetPedCanRagdollFromPlayerImpact(ped, false)

        spawnedNPCs[locationId] = ped
    end

    SetModelAsNoLongerNeeded(modelHash)
end

-- Create map blips
function CreateBlips()
    for locationId, location in pairs(Config.Locations) do
        local blip = AddBlipForCoord(location.npcPos.x, location.npcPos.y, location.npcPos.z)
        SetBlipSprite(blip, location.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, location.blip.scale)
        SetBlipColour(blip, location.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(location.blip.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- Setup sb_target interactions
function SetupTargets()
    for locationId, location in pairs(Config.Locations) do
        -- NPC target for renting
        exports['sb_target']:AddTargetEntity(spawnedNPCs[locationId], {
            {
                name = 'rental_browse_' .. locationId,
                label = 'Rent Vehicle',
                icon = 'fa-key',
                distance = 2.5,
                action = function(entity)
                    OpenRentalMenu(locationId)
                end
            },
            {
                name = 'rental_return_' .. locationId,
                label = 'Return Rental',
                icon = 'fa-undo',
                distance = 2.5,
                action = function(entity)
                    AttemptReturn(locationId)
                end
            },
            {
                name = 'rental_status_' .. locationId,
                label = 'Check Rental Status',
                icon = 'fa-info-circle',
                distance = 2.5,
                action = function(entity)
                    CheckRentalStatus()
                end
            }
        })
    end
end

-- Open rental menu
function OpenRentalMenu(locationId)
    currentLocation = locationId
    local location = Config.Locations[locationId]

    if not location then
        exports['sb_notify']:Notify('Invalid rental location', 'error', 3000)
        return
    end

    -- Check if player is blacklisted
    SB.Functions.TriggerCallback('sb_rental:server:checkBlacklist', function(blacklisted, until_time)
        if blacklisted then
            exports['sb_notify']:Notify('You are banned from renting vehicles until ' .. until_time, 'error', 5000)
            return
        end

        -- Check if player already has an active rental
        SB.Functions.TriggerCallback('sb_rental:server:hasActiveRental', function(hasRental)
            if hasRental then
                exports['sb_notify']:Notify('You already have an active rental. Return it first.', 'error', 4000)
                return
            end

            -- Build vehicle data for this location
            local vehicles = {}
            for _, category in ipairs(location.categories) do
                if Config.Vehicles[category] then
                    for _, vehicle in ipairs(Config.Vehicles[category]) do
                        table.insert(vehicles, {
                            model = vehicle.model,
                            label = vehicle.label,
                            daily = vehicle.daily,
                            image = vehicle.image,
                            category = category
                        })
                    end
                end
            end

            -- Open NUI
            SetNuiFocus(true, true)
            nuiOpen = true

            SendNUIMessage({
                action = 'open',
                locationLabel = location.label,
                categories = location.categories,
                categoryLabels = Config.CategoryLabels,
                vehicles = vehicles,
                maxDays = Config.MaxRentalDays
            })
        end)
    end)
end

-- Close NUI
function CloseRentalMenu()
    SetNuiFocus(false, false)
    nuiOpen = false
    SendNUIMessage({ action = 'close' })
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    CloseRentalMenu()
    cb('ok')
end)

RegisterNUICallback('rent', function(data, cb)
    local vehicle = data.vehicle
    local days = data.days
    local locationId = currentLocation

    if not vehicle or not days or not locationId then
        cb({ success = false, message = 'Invalid rental data' })
        return
    end

    -- Process rental on server
    SB.Functions.TriggerCallback('sb_rental:server:rentVehicle', function(success, result)
        if success then
            CloseRentalMenu()

            -- Spawn the vehicle
            SpawnRentalVehicle(result.vehicle, result.plate, result.rentalId, locationId)

            exports['sb_notify']:Notify('Vehicle rented! Return by ' .. result.returnBy, 'success', 5000)
            cb({ success = true })
        else
            exports['sb_notify']:Notify(result or 'Failed to rent vehicle', 'error', 4000)
            cb({ success = false, message = result })
        end
    end, vehicle, days, locationId)
end)

-- Attempt to return rental
function AttemptReturn(locationId)
    local location = Config.Locations[locationId]
    if not location then return end

    -- Check if player has active rental
    SB.Functions.TriggerCallback('sb_rental:server:getActiveRental', function(rental)
        if not rental then
            exports['sb_notify']:Notify('You have no active rental to return', 'error', 3000)
            return
        end

        -- Check if vehicle is nearby
        local playerCoords = GetEntityCoords(PlayerPedId())
        local returnCenter = location.returnZone.center
        local returnRadius = location.returnZone.radius

        -- Find rental vehicle nearby
        local rentalVehicle = nil
        local vehicles = GetGamePool('CVehicle')

        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehCoords = GetEntityCoords(veh)
                local dist = #(returnCenter - vehCoords)

                if dist < returnRadius then
                    local plate = GetVehicleNumberPlateText(veh)
                    if string.gsub(plate, ' ', '') == string.gsub(rental.plate, ' ', '') then
                        rentalVehicle = veh
                        break
                    end
                end
            end
        end

        if not rentalVehicle then
            exports['sb_notify']:Notify('Bring your rental vehicle to the return zone', 'error', 4000)
            return
        end

        -- Get vehicle damage
        local bodyHealth = GetVehicleBodyHealth(rentalVehicle)

        -- Process return
        SB.Functions.TriggerCallback('sb_rental:server:returnVehicle', function(success, result)
            if success then
                -- Unregister from sb_impound before deleting
                local plate = GetVehicleNumberPlateText(rentalVehicle)
                TriggerServerEvent('sb_impound:server:vehicleStored', plate)

                -- Delete vehicle
                DeleteEntity(rentalVehicle)

                -- Show receipt
                local msg = 'Rental returned!'
                if result.refund and result.refund > 0 then
                    msg = msg .. ' Refund: $' .. result.refund
                end
                if result.lateFees and result.lateFees > 0 then
                    msg = msg .. ' | Late fees: $' .. result.lateFees
                end
                if result.damageFees and result.damageFees > 0 then
                    msg = msg .. ' | Damage: $' .. result.damageFees
                end
                if result.lostKeysFee and result.lostKeysFee > 0 then
                    msg = msg .. ' | Lost keys: $' .. result.lostKeysFee
                end

                exports['sb_notify']:Notify(msg, 'success', 6000)
            else
                exports['sb_notify']:Notify(result or 'Failed to return rental', 'error', 4000)
            end
        end, rental.rental_id, bodyHealth)
    end)
end

-- Check rental status
function CheckRentalStatus()
    SB.Functions.TriggerCallback('sb_rental:server:getActiveRental', function(rental)
        if not rental then
            exports['sb_notify']:Notify('You have no active rental', 'info', 3000)
            return
        end

        local status = rental.status
        local statusText = 'Active'
        if status == 'late' then
            statusText = 'OVERDUE - Return immediately!'
        elseif status == 'stolen' then
            statusText = 'MARKED STOLEN'
        end

        -- Use formatted date from server, fallback to raw value
        local returnBy = rental.rental_end_formatted or rental.rental_end or 'N/A'

        exports['sb_notify']:Notify(string.format('Rental: %s (%s) - %s | Return by: %s',
            rental.vehicle_label,
            rental.plate,
            statusText,
            returnBy
        ), 'info', 8000)
    end)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsRentalMenuOpen', function()
    return nuiOpen
end)

exports('GetCurrentLocation', function()
    return currentLocation
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateBlips()
    SpawnRentalNPCs()
    SetupTargets()
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove NPCs
    for _, ped in pairs(spawnedNPCs) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end

    -- Remove blips
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    -- Close NUI
    if nuiOpen then
        CloseRentalMenu()
    end
end)
