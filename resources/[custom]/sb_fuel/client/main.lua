--[[
    Everyday Chaos RP - Fuel System (Main Client)
    Author: Salah Eddine Boussettah

    Handles: Fuel consumption, low fuel warnings, engine stalling
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local isLoggedIn = false
local currentVehicle = nil
local currentFuel = 100.0
local isEngineStalled = false
local lastWarningTime = 0
local vehicleFuelCache = {}  -- Cache fuel levels for vehicles

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Check if vehicle is electric
local function IsElectricVehicle(vehicle)
    local model = GetEntityModel(vehicle)
    for _, electricModel in ipairs(Config.ElectricVehicles) do
        if model == GetHashKey(electricModel) then
            return true
        end
    end
    return false
end

-- Get vehicle class multiplier
local function GetClassMultiplier(vehicle)
    local class = GetVehicleClass(vehicle)
    return Config.ClassMultipliers[class] or 1.0
end

-- Get cached or current fuel level
local function GetVehicleFuel(vehicle)
    local netId = VehToNet(vehicle)
    if vehicleFuelCache[netId] then
        return vehicleFuelCache[netId]
    end
    return GetVehicleFuelLevel(vehicle)
end

-- Set fuel level (local + native)
local function SetVehicleFuel(vehicle, level)
    level = math.max(0.0, math.min(100.0, level))
    local netId = VehToNet(vehicle)
    vehicleFuelCache[netId] = level
    SetVehicleFuelLevel(vehicle, level + 0.0)

    -- Sync to server for persistence
    TriggerServerEvent('sb_fuel:server:syncFuel', netId, level)
end

-- Play sound
local function PlayFuelSound(sound)
    if sound and sound.name then
        if sound.set then
            PlaySoundFrontend(-1, sound.name, sound.set, true)
        else
            PlaySoundFrontend(-1, sound.name, nil, true)
        end
    end
end

-- ============================================================================
-- FUEL CONSUMPTION LOOP
-- ============================================================================
CreateThread(function()
    while true do
        Wait(100)
        if SB.Functions.IsLoggedIn() then
            isLoggedIn = true
            break
        end
    end

    while isLoggedIn do
        Wait(Config.ConsumptionInterval)

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            -- Player is driver
            currentVehicle = vehicle

            -- Skip if bicycle or electric (and electric disabled)
            local vehClass = GetVehicleClass(vehicle)
            if vehClass == 13 then
                -- Bicycle - no fuel needed
                goto continue
            end

            if IsElectricVehicle(vehicle) and not Config.Electric.enabled then
                -- Electric vehicle, charging not implemented
                goto continue
            end

            -- Get current fuel
            currentFuel = GetVehicleFuel(vehicle)

            -- Check if engine is running
            local engineRunning = GetIsVehicleEngineRunning(vehicle)

            if engineRunning and currentFuel > 0 then
                -- Calculate consumption
                local rpm = GetVehicleCurrentRpm(vehicle)
                local classMultiplier = GetClassMultiplier(vehicle)

                -- Base consumption modified by RPM and class
                local consumption = Config.IdleConsumption
                if rpm > 0.2 then
                    -- Engine under load
                    consumption = Config.BaseConsumption * rpm * classMultiplier
                end

                -- Per-vehicle fuel multiplier (state bag override, e.g. buses)
                local vehFuelMult = Entity(vehicle).state.sb_fuel_multiplier
                if vehFuelMult and vehFuelMult > 0 then
                    consumption = consumption * vehFuelMult
                end

                -- Apply consumption (per interval)
                local intervalSeconds = Config.ConsumptionInterval / 1000
                local fuelUsed = consumption * intervalSeconds

                local newFuel = currentFuel - fuelUsed
                SetVehicleFuel(vehicle, newFuel)
                currentFuel = newFuel

                -- Reset stall state if we have fuel
                if isEngineStalled and currentFuel > Config.EngineStallThreshold then
                    isEngineStalled = false
                end
            end

            -- Low fuel warning
            local now = GetGameTimer()
            if currentFuel <= Config.CriticalFuelWarning and now - lastWarningTime > 30000 then
                lastWarningTime = now
                PlayFuelSound(Config.Sounds.lowFuel)
                exports['sb_notify']:Notify('Critical: Almost out of fuel!', 'error', 5000)
            elseif currentFuel <= Config.LowFuelWarning and currentFuel > Config.CriticalFuelWarning and now - lastWarningTime > 60000 then
                lastWarningTime = now
                PlayFuelSound(Config.Sounds.lowFuel)
                exports['sb_notify']:Notify('Low fuel - find a gas station', 'warning', 4000)
            end

            -- Engine stall when out of fuel
            if currentFuel <= Config.EngineStallThreshold and not isEngineStalled then
                isEngineStalled = true
                SetVehicleEngineOn(vehicle, false, true, true)
                SetVehicleUndriveable(vehicle, true)
                PlayFuelSound(Config.Sounds.engineStall)
                exports['sb_notify']:Notify('Out of fuel! Engine stalled.', 'error', 5000)
            end
        else
            -- Not in vehicle
            if currentVehicle ~= 0 and currentVehicle ~= nil then
                -- Just exited vehicle - sync final fuel
                if DoesEntityExist(currentVehicle) then
                    local netId = VehToNet(currentVehicle)
                    local fuel = GetVehicleFuel(currentVehicle)
                    TriggerServerEvent('sb_fuel:server:syncFuel', netId, fuel)
                end
            end
            currentVehicle = nil
            isEngineStalled = false
        end

        ::continue::
    end
end)

-- ============================================================================
-- BLOCK ENGINE START WHEN OUT OF FUEL
-- ============================================================================
CreateThread(function()
    while not isLoggedIn do
        Wait(500)
    end

    while true do
        Wait(0)

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            local fuel = GetVehicleFuel(vehicle)

            if fuel <= Config.EngineStallThreshold then
                -- Prevent engine start
                if IsControlJustPressed(0, 71) or IsControlJustPressed(0, 72) then -- W or G
                    SetVehicleEngineOn(vehicle, false, true, true)
                    SetVehicleUndriveable(vehicle, true)
                end

                -- Keep engine off
                if GetIsVehicleEngineRunning(vehicle) then
                    SetVehicleEngineOn(vehicle, false, true, true)
                end
            else
                -- Has fuel - ensure vehicle is driveable
                if IsVehicleDriveable(vehicle, false) == false then
                    SetVehicleUndriveable(vehicle, false)
                end
            end
        end
    end
end)

-- ============================================================================
-- SYNC FUEL ON VEHICLE ENTER
-- ============================================================================
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkPlayerEnteredVehicle' then
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 then
            -- Request fuel from server
            local plate = GetVehicleNumberPlateText(vehicle)
            TriggerServerEvent('sb_fuel:server:requestFuel', VehToNet(vehicle), plate)
        end
    end
end)

-- Receive fuel level from server (direct request response)
RegisterNetEvent('sb_fuel:client:setFuel', function(netId, fuel)
    local vehicle = NetToVeh(netId)
    if DoesEntityExist(vehicle) then
        vehicleFuelCache[netId] = fuel
        SetVehicleFuelLevel(vehicle, fuel + 0.0)
        currentFuel = fuel

        -- Check if stalled
        if fuel <= Config.EngineStallThreshold then
            isEngineStalled = true
            SetVehicleEngineOn(vehicle, false, true, true)
            SetVehicleUndriveable(vehicle, true)
        end
    end
end)

-- Receive broadcast fuel update (from any player refueling)
-- This ensures passengers and nearby players see correct fuel levels
RegisterNetEvent('sb_fuel:client:syncFuelBroadcast', function(netId, fuel)
    local vehicle = NetToVeh(netId)
    if not DoesEntityExist(vehicle) then return end

    -- Update cache
    vehicleFuelCache[netId] = fuel
    SetVehicleFuelLevel(vehicle, fuel + 0.0)

    -- If we're in this vehicle, update our current fuel display
    local playerPed = PlayerPedId()
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    if playerVehicle ~= 0 and playerVehicle == vehicle then
        currentFuel = fuel

        -- Update stall state
        if fuel <= Config.EngineStallThreshold then
            isEngineStalled = true
            SetVehicleEngineOn(vehicle, false, true, true)
            SetVehicleUndriveable(vehicle, true)
        elseif isEngineStalled and fuel > Config.EngineStallThreshold then
            isEngineStalled = false
            SetVehicleUndriveable(vehicle, false)
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Get fuel level for a vehicle
exports('GetFuel', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return 100.0
    end
    return GetVehicleFuel(vehicle)
end)

-- Set fuel level for a vehicle
exports('SetFuel', function(vehicle, level)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    SetVehicleFuel(vehicle, level)
    return true
end)

-- Add fuel to a vehicle
exports('AddFuel', function(vehicle, amount)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    local current = GetVehicleFuel(vehicle)
    SetVehicleFuel(vehicle, current + amount)
    return true
end)

-- Check if vehicle is out of fuel
exports('IsOutOfFuel', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    return GetVehicleFuel(vehicle) <= Config.EngineStallThreshold
end)

-- Get current vehicle fuel (for HUD integration)
exports('GetCurrentVehicleFuel', function()
    return currentFuel
end)

-- ============================================================================
-- ADMIN SET FUEL
-- ============================================================================

RegisterNetEvent('sb_fuel:client:adminSetFuel', function(amount)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle ~= 0 then
        SetVehicleFuel(vehicle, amount)
        exports['sb_notify']:Notify(string.format('Fuel set to %d%%', amount), 'success', 3000)
    else
        exports['sb_notify']:Notify('Must be in a vehicle', 'error', 3000)
    end
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Clean up any spawned props, etc.
    vehicleFuelCache = {}
end)

-- Reset on player logout
RegisterNetEvent('SB:Client:OnPlayerUnload', function()
    isLoggedIn = false
    currentVehicle = nil
    currentFuel = 100.0
    isEngineStalled = false
    vehicleFuelCache = {}
end)

RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    isLoggedIn = true
end)
