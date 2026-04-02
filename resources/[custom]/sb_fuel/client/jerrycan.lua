--[[
    Everyday Chaos RP - Fuel System (Jerry Can & Syphoning)
    Author: Salah Eddine Boussettah

    Handles: Jerry can usage, syphoning fuel from vehicles
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local isPouringFuel = false
local isSyphoning = false
local jerryCanProp = nil

-- Debug helper
local function DebugLog(msg)
    print('[sb_fuel:jerrycan] ' .. msg)
end

-- Helper: clean up jerry can prop
local function CleanupProp()
    if jerryCanProp and DoesEntityExist(jerryCanProp) then
        DeleteObject(jerryCanProp)
        jerryCanProp = nil
    end
end

-- ============================================================================
-- JERRY CAN - USE FROM INVENTORY
-- ============================================================================

-- Register inventory use callback
RegisterNetEvent('sb_fuel:client:useJerryCan', function(itemData)
    if isPouringFuel or isSyphoning then
        exports['sb_notify']:Notify('Already busy', 'error', 2000)
        return
    end

    local playerPed = PlayerPedId()

    -- Must be near a vehicle
    local vehicle = GetClosestVehicle(GetEntityCoords(playerPed), 3.0, 0, 70)
    if not vehicle or vehicle == 0 then
        exports['sb_notify']:Notify('No vehicle nearby', 'error', 3000)
        return
    end

    -- Check jerry can fuel amount
    local fuelAmount = (itemData.metadata and itemData.metadata.fuel) or 0
    if fuelAmount <= 0 then
        exports['sb_notify']:Notify('Jerry can is empty', 'error', 3000)
        return
    end

    -- Check vehicle fuel level
    local vehicleFuel = exports['sb_fuel']:GetFuel(vehicle)
    if vehicleFuel >= 99.0 then
        exports['sb_notify']:Notify('Vehicle tank is full', 'info', 3000)
        return
    end

    -- Start pouring
    PourJerryCan(vehicle, itemData, fuelAmount)
end)

-- Pour fuel from jerry can into vehicle
function PourJerryCan(vehicle, itemData, fuelAmount)
    local playerPed = PlayerPedId()
    isPouringFuel = true

    -- Calculate how much can be added
    local vehicleFuel = exports['sb_fuel']:GetFuel(vehicle)
    local canAdd = math.min(fuelAmount, 100.0 - vehicleFuel)

    if canAdd <= 0 then
        exports['sb_notify']:Notify('Vehicle tank is full', 'info', 3000)
        isPouringFuel = false
        return
    end

    -- Calculate duration based on pour rate
    local duration = (canAdd / Config.JerryCan.pourRate) * 1000

    -- Create jerry can prop
    local propHash = GetHashKey(Config.JerryCan.prop)
    RequestModel(propHash)
    while not HasModelLoaded(propHash) do
        Wait(10)
    end

    local coords = GetEntityCoords(playerPed)
    jerryCanProp = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, true)

    -- Attach to hand (tilted forward for pouring)
    AttachEntityToEntity(
        jerryCanProp,
        playerPed,
        GetPedBoneIndex(playerPed, 57005), -- Right hand
        0.13, 0.05, 0.0,
        -90.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    -- Face vehicle
    TaskTurnPedToFaceEntity(playerPed, vehicle, 1000)
    Wait(1000)

    -- Progress bar with animation
    exports['sb_progressbar']:Start({
        duration = math.floor(duration),
        label = string.format('Pouring fuel (%.1fL)...', canAdd),
        canCancel = true,
        anim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
            flag = 1
        },
        onComplete = function()
            CleanupProp()

            -- Add fuel to vehicle
            local newFuel = vehicleFuel + canAdd
            exports['sb_fuel']:SetFuel(vehicle, newFuel)

            -- Update jerry can fuel amount
            local remainingFuel = fuelAmount - canAdd
            TriggerServerEvent('sb_fuel:server:updateJerryCan', itemData.slot, remainingFuel)

            exports['sb_notify']:Notify(string.format('Poured %.1fL into vehicle', canAdd), 'success', 3000)
            isPouringFuel = false
            DebugLog('Pour complete, isPouringFuel=false')
        end,
        onCancel = function()
            CleanupProp()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
            isPouringFuel = false
            DebugLog('Pour cancelled, isPouringFuel=false')
        end
    })
end

-- ============================================================================
-- JERRY CAN TARGET OPTION (Use jerry can on vehicle)
-- ============================================================================
CreateThread(function()
    Wait(2000) -- Wait for sb_target

    exports['sb_target']:AddGlobalVehicle({
        {
            name = 'use_jerrycan',
            label = 'Use Jerry Can',
            icon = 'fa-gas-pump',
            distance = 3.0,
            canInteract = function(entity)
                -- Not in vehicle and not busy
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    return false
                end
                if isPouringFuel or isSyphoning then
                    DebugLog('Jerry can target BLOCKED: isPouringFuel=' .. tostring(isPouringFuel) .. ' isSyphoning=' .. tostring(isSyphoning))
                    return false
                end
                -- Check if player has a jerry can with fuel
                local Player = SB.Functions.GetPlayerData()
                if not Player or not Player.items then return false end
                local hasJerryCan = false
                for _, item in pairs(Player.items) do
                    if item and item.name == 'jerrycan' then
                        local fuel = (item.metadata and item.metadata.fuel) or 0
                        if fuel > 0 then
                            hasJerryCan = true
                            break
                        end
                    end
                end
                if not hasJerryCan then return false end
                -- Vehicle not full
                local fuel = exports['sb_fuel']:GetFuel(entity)
                return fuel < 99.0
            end,
            action = function(entity)
                UseJerryCanOnVehicle(entity)
            end
        }
    })
end)

-- Use jerry can via target
function UseJerryCanOnVehicle(vehicle)
    if isPouringFuel or isSyphoning then
        exports['sb_notify']:Notify('Already busy', 'error', 2000)
        return
    end

    -- Request jerry can info from server
    SB.Functions.TriggerCallback('sb_fuel:server:getJerryCanInfo', function(jerryCanInfo)
        if not jerryCanInfo then
            exports['sb_notify']:Notify('No jerry can in inventory', 'error', 3000)
            return
        end

        local fuelAmount = jerryCanInfo.fuel or 0
        if fuelAmount <= 0 then
            exports['sb_notify']:Notify('Jerry can is empty', 'error', 3000)
            return
        end

        -- Check vehicle fuel level
        local vehicleFuel = exports['sb_fuel']:GetFuel(vehicle)
        if vehicleFuel >= 99.0 then
            exports['sb_notify']:Notify('Vehicle tank is full', 'info', 3000)
            return
        end

        -- Start pouring
        PourJerryCanFromTarget(vehicle, jerryCanInfo.slot, fuelAmount)
    end)
end

-- Pour fuel (called from target, uses slot instead of itemData)
function PourJerryCanFromTarget(vehicle, jerrySlot, fuelAmount)
    local playerPed = PlayerPedId()
    isPouringFuel = true

    -- Calculate how much can be added
    local vehicleFuel = exports['sb_fuel']:GetFuel(vehicle)
    local canAdd = math.min(fuelAmount, 100.0 - vehicleFuel)

    if canAdd <= 0 then
        exports['sb_notify']:Notify('Vehicle tank is full', 'info', 3000)
        isPouringFuel = false
        return
    end

    -- Calculate duration based on pour rate
    local duration = (canAdd / Config.JerryCan.pourRate) * 1000

    -- Create jerry can prop
    local propHash = GetHashKey(Config.JerryCan.prop)
    RequestModel(propHash)
    while not HasModelLoaded(propHash) do
        Wait(10)
    end

    local coords = GetEntityCoords(playerPed)
    jerryCanProp = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, true)

    -- Attach to hand
    AttachEntityToEntity(
        jerryCanProp,
        playerPed,
        GetPedBoneIndex(playerPed, 57005),
        0.12, 0.0, -0.22,
        90.0, 180.0, 0.0,
        true, true, false, true, 1, true
    )

    -- Face vehicle
    TaskTurnPedToFaceEntity(playerPed, vehicle, 1000)
    Wait(1000)

    -- Progress bar with animation
    exports['sb_progressbar']:Start({
        duration = math.floor(duration),
        label = string.format('Pouring fuel (%.1fL)...', canAdd),
        canCancel = true,
        anim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
            flag = 1
        },
        onComplete = function()
            CleanupProp()

            -- Add fuel to vehicle
            local newFuel = vehicleFuel + canAdd
            exports['sb_fuel']:SetFuel(vehicle, newFuel)

            -- Update jerry can fuel amount
            local remainingFuel = fuelAmount - canAdd
            TriggerServerEvent('sb_fuel:server:updateJerryCan', jerrySlot, remainingFuel)

            exports['sb_notify']:Notify(string.format('Poured %.1fL into vehicle', canAdd), 'success', 3000)
            isPouringFuel = false
            DebugLog('Pour (target) complete, isPouringFuel=false')
        end,
        onCancel = function()
            CleanupProp()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
            isPouringFuel = false
            DebugLog('Pour (target) cancelled, isPouringFuel=false')
        end
    })
end

-- ============================================================================
-- SYPHONING FUEL
-- ============================================================================

-- Add syphon target to vehicles
CreateThread(function()
    if not Config.Syphon.enabled then return end

    Wait(2500) -- Wait for sb_target (after jerry can target)

    exports['sb_target']:AddGlobalVehicle({
        {
            name = 'syphon_fuel',
            label = 'Syphon Fuel',
            icon = 'fa-droplet',
            distance = 2.5,
            canInteract = function(entity)
                -- Not in vehicle
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    return false
                end

                -- Check if vehicle has fuel
                local fuel = exports['sb_fuel']:GetFuel(entity)
                if fuel <= 5 then
                    return false
                end

                -- Check if occupied by a real player (NPCs are fine to syphon from)
                if not Config.Syphon.canSyphonOccupied then
                    for i = -1, GetVehicleMaxNumberOfPassengers(entity) - 1 do
                        if not IsVehicleSeatFree(entity, i) then
                            local ped = GetPedInVehicleSeat(entity, i)
                            if ped and IsPedAPlayer(ped) then
                                return false
                            end
                        end
                    end
                end

                -- Check if player-owned
                if not Config.Syphon.canSyphonOwned then
                    local state = Entity(entity).state
                    if state and state.sb_owned then
                        return false
                    end
                end

                -- Not currently syphoning
                return not isSyphoning
            end,
            action = function(entity)
                StartSyphoning(entity)
            end
        }
    })
end)

-- Generate weighted random syphon amount (1.5L - 20L, lower chance for higher)
local function GetRandomSyphonAmount()
    -- Roll 1-100, higher rolls = rarer = more fuel
    local roll = math.random(1, 100)

    if roll <= 40 then
        -- 40% chance: 1.5L - 4.0L (bad luck)
        return 1.5 + math.random() * 2.5
    elseif roll <= 70 then
        -- 30% chance: 4.0L - 8.0L (decent)
        return 4.0 + math.random() * 4.0
    elseif roll <= 88 then
        -- 18% chance: 8.0L - 13.0L (good)
        return 8.0 + math.random() * 5.0
    elseif roll <= 97 then
        -- 9% chance: 13.0L - 17.0L (great)
        return 13.0 + math.random() * 4.0
    else
        -- 3% chance: 17.0L - 20.0L (jackpot)
        return 17.0 + math.random() * 3.0
    end
end

-- Syphon fuel from vehicle
function StartSyphoning(vehicle)
    DebugLog('StartSyphoning called, isSyphoning=' .. tostring(isSyphoning))
    if isSyphoning then return end

    local playerPed = PlayerPedId()

    -- Check vehicle fuel first (client-side check is fine)
    local vehicleFuel = exports['sb_fuel']:GetFuel(vehicle)
    DebugLog('Vehicle fuel: ' .. tostring(vehicleFuel))

    if vehicleFuel <= 5 then
        exports['sb_notify']:Notify('Not enough fuel to syphon', 'error', 3000)
        return
    end

    -- Set flag early to prevent double-clicks during callback
    isSyphoning = true
    DebugLog('isSyphoning set to TRUE (pre-callback)')

    -- Check for syphon kit and jerry can via server callback
    SB.Functions.TriggerCallback('sb_fuel:server:canSyphon', function(result)
        DebugLog('canSyphon callback received, result=' .. tostring(result ~= nil))

        if not result then
            exports['sb_notify']:Notify('Need a syphon kit and jerry can', 'error', 3000)
            DebugLog('No result, resetting isSyphoning')
            isSyphoning = false
            return
        end

        DebugLog('hasJerryCan=' .. tostring(result.hasJerryCan) .. ' hasSyphonKit=' .. tostring(result.hasSyphonKit) .. ' jerryFuel=' .. tostring(result.jerryFuel) .. ' jerrySlot=' .. tostring(result.jerrySlot))

        if not result.hasJerryCan then
            exports['sb_notify']:Notify('Need a jerry can to store fuel', 'error', 3000)
            isSyphoning = false
            return
        end

        if result.hasSyphonKit == false then
            exports['sb_notify']:Notify('Need a syphon kit', 'error', 3000)
            isSyphoning = false
            return
        end

        local currentJerryFuel = result.jerryFuel or 0
        local jerrySpace = Config.JerryCan.maxCapacity - currentJerryFuel
        DebugLog('jerryFuel=' .. tostring(currentJerryFuel) .. ' jerrySpace=' .. tostring(jerrySpace))

        if jerrySpace <= 0 then
            exports['sb_notify']:Notify('Jerry can is full', 'error', 3000)
            isSyphoning = false
            return
        end

        -- Random syphon amount (weighted: low amounts more common)
        local randomAmount = GetRandomSyphonAmount()
        local canTake = math.min(randomAmount, vehicleFuel - 5)

        -- Limit to jerry can capacity
        local actualTake = math.min(canTake, jerrySpace)
        DebugLog('randomAmount=' .. string.format('%.1f', randomAmount) .. ' canTake=' .. string.format('%.1f', canTake) .. ' actualTake=' .. string.format('%.1f', actualTake))

        if actualTake <= 0 then
            exports['sb_notify']:Notify('Not enough fuel to syphon', 'error', 3000)
            isSyphoning = false
            return
        end

        -- Round to 1 decimal
        actualTake = math.floor(actualTake * 10 + 0.5) / 10

        -- Run in its own thread (progress bar needs proper coroutine context)
        CreateThread(function()
            -- Face vehicle
            TaskTurnPedToFaceEntity(playerPed, vehicle, 1000)
            Wait(1000)

            DebugLog('Starting progress bar, duration=' .. tostring(Config.Syphon.duration))

            -- Progress bar
            exports['sb_progressbar']:Start({
                duration = Config.Syphon.duration,
                label = string.format('Syphoning fuel (%.1fL)...', actualTake),
                canCancel = true,
                anim = {
                    dict = 'mini@repair',
                    clip = 'fixing_a_ped',
                    flag = 49
                },
                onComplete = function()
                    DebugLog('Syphon progress COMPLETE')

                    -- Remove fuel from vehicle
                    local newVehicleFuel = vehicleFuel - actualTake
                    exports['sb_fuel']:SetFuel(vehicle, newVehicleFuel)

                    -- Add fuel to jerry can via server
                    local newJerryFuel = currentJerryFuel + actualTake
                    TriggerServerEvent('sb_fuel:server:updateJerryCan', result.jerrySlot, newJerryFuel)
                    DebugLog('Syphon complete: took ' .. string.format('%.1f', actualTake) .. 'L, jerry now ' .. string.format('%.1f', newJerryFuel) .. 'L')

                    exports['sb_notify']:Notify(string.format('Syphoned %.1fL of fuel', actualTake), 'success', 3000)
                    isSyphoning = false
                    DebugLog('isSyphoning set to FALSE (complete)')
                end,
                onCancel = function()
                    DebugLog('Syphon progress CANCELLED')
                    exports['sb_notify']:Notify('Cancelled', 'info', 2000)
                    isSyphoning = false
                    DebugLog('isSyphoning set to FALSE (cancelled)')
                end
            })
        end)
    end)
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CleanupProp()
    ClearPedTasks(PlayerPedId())
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsPouringFuel', function()
    return isPouringFuel
end)

exports('IsSyphoning', function()
    return isSyphoning
end)
