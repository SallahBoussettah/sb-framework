--[[
    Everyday Chaos RP - Fuel System (Gas Stations)
    Author: Salah Eddine Boussettah

    Handles: Gas station blips, pump targeting, nozzle interaction, refueling
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local isHoldingNozzle = false
local nozzleObject = nil
local currentPump = nil
local currentPumpCoords = nil
local isRefueling = false
local targetVehicle = nil
local refuelThread = nil
local totalLitersAdded = 0
local totalCost = 0

-- Animation state
local isPlayingAnim = false

-- ============================================================================
-- BLIP CREATION
-- ============================================================================
CreateThread(function()
    for _, station in ipairs(Config.Stations) do
        if station.blip then
            local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipAsShortRange(blip, Config.Blip.shortRange)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(station.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ============================================================================
-- PUMP TARGETING (sb_target integration)
-- ============================================================================
CreateThread(function()
    Wait(2000) -- Wait for sb_target to initialize

    -- Add target to all pump models
    for _, model in ipairs(Config.PumpModels) do
        exports['sb_target']:AddTargetModel(model, {
            {
                name = 'grab_nozzle',
                label = 'Grab Fuel Nozzle',
                icon = 'fa-gas-pump',
                distance = 2.0,
                canInteract = function(entity)
                    return not isHoldingNozzle and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                action = function(entity)
                    GrabNozzle(entity)
                end
            },
            {
                name = 'return_nozzle',
                label = 'Return Nozzle',
                icon = 'fa-hand-holding',
                distance = 2.0,
                canInteract = function(entity)
                    return isHoldingNozzle and not isRefueling and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                action = function(entity)
                    ReturnNozzle()
                end
            },
            {
                name = 'refill_jerrycan',
                label = 'Refill Jerry Can',
                icon = 'fa-fill-drip',
                distance = 2.0,
                canInteract = function(entity)
                    -- Basic check - detailed item check happens in action
                    return not isHoldingNozzle and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                action = function(entity)
                    RefillJerryCan(entity)
                end
            }
        })
    end
end)

-- ============================================================================
-- NOZZLE FUNCTIONS
-- ============================================================================

-- Play animation helper
local function PlayAnim(dict, anim, flag, duration)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 1000 do
        Wait(10)
        timeout = timeout + 10
    end

    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration or -1, flag or 0, 0, false, false, false)
        isPlayingAnim = true
    end
end

-- Stop animation
local function StopAnim()
    if isPlayingAnim then
        ClearPedTasks(PlayerPedId())
        isPlayingAnim = false
    end
end

-- Grab nozzle from pump
function GrabNozzle(pumpEntity)
    if isHoldingNozzle then return end

    local playerPed = PlayerPedId()
    currentPump = pumpEntity
    currentPumpCoords = GetEntityCoords(pumpEntity)

    -- Face the pump
    TaskTurnPedToFaceEntity(playerPed, pumpEntity, 1000)
    Wait(1000)

    -- Play grab animation
    PlayAnim('anim@am_hold_up@male', 'shoplift_high', 48, 1500)
    Wait(500)

    -- Create nozzle prop
    local propHash = GetHashKey(Config.Nozzle.prop)
    RequestModel(propHash)
    while not HasModelLoaded(propHash) do
        Wait(10)
    end

    local coords = GetEntityCoords(playerPed)
    nozzleObject = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, true)

    -- Attach to hand
    AttachEntityToEntity(
        nozzleObject,
        playerPed,
        GetPedBoneIndex(playerPed, Config.Nozzle.bone),
        Config.Nozzle.offset.x, Config.Nozzle.offset.y, Config.Nozzle.offset.z,
        Config.Nozzle.rotation.x, Config.Nozzle.rotation.y, Config.Nozzle.rotation.z,
        true, true, false, true, 1, true
    )

    isHoldingNozzle = true
    PlayFuelSound(Config.Sounds.nozzlePickup)

    Wait(1000)
    StopAnim()

    exports['sb_notify']:Notify('Approach your vehicle and press E to refuel', 'info', 4000)

    -- Start nozzle management thread
    CreateThread(NozzleThread)
end

-- Reset all refueling state (helper function)
local function ResetRefuelingState()
    isRefueling = false
    if isAuthorized then
        TriggerServerEvent('sb_fuel:server:cancelFuelAuth')
        isAuthorized = false
        authorizedAmount = 0
    end
    targetVehicle = nil
end

-- Return nozzle to pump (proper return)
function ReturnNozzle()
    if not isHoldingNozzle then return end

    -- Stop refueling if active
    if isRefueling then
        StopRefueling()
    else
        -- Even if not refueling, ensure state is clean
        ResetRefuelingState()
    end

    local playerPed = PlayerPedId()

    -- Play return animation
    PlayAnim('anim@am_hold_up@male', 'shoplift_high', 48, 1500)
    Wait(800)

    -- Delete nozzle prop
    if nozzleObject and DoesEntityExist(nozzleObject) then
        DetachEntity(nozzleObject, true, true)
        DeleteObject(nozzleObject)
    end

    nozzleObject = nil
    isHoldingNozzle = false
    currentPump = nil
    currentPumpCoords = nil

    PlayFuelSound(Config.Sounds.nozzleDrop)
    Wait(500)
    StopAnim()

    exports['sb_notify']:Notify('Nozzle returned', 'info', 2000)

    -- Show receipt if any fuel was added
    if totalLitersAdded > 0 then
        exports['sb_notify']:Notify(string.format('Total: %.1fL - $%.2f', totalLitersAdded, totalCost), 'success', 5000)
        totalLitersAdded = 0
        totalCost = 0
    end
end

-- Drop nozzle (when walking away or entering vehicle)
function DropNozzle()
    if not isHoldingNozzle then return end

    -- Stop refueling if active
    if isRefueling then
        StopRefueling()
    else
        -- Even if not refueling, ensure state is clean
        ResetRefuelingState()
    end

    -- Play drop animation
    PlayAnim('anim@am_hold_up@male', 'shoplift_high', 48, 1000)
    Wait(500)

    -- Delete nozzle prop
    if nozzleObject and DoesEntityExist(nozzleObject) then
        DetachEntity(nozzleObject, true, true)
        DeleteObject(nozzleObject)
    end

    nozzleObject = nil
    isHoldingNozzle = false
    currentPump = nil
    currentPumpCoords = nil

    PlayFuelSound(Config.Sounds.nozzleDrop)
    StopAnim()

    -- Show receipt if any fuel was added
    if totalLitersAdded > 0 then
        exports['sb_notify']:Notify(string.format('Refueled %.1fL - Total: $%.2f', totalLitersAdded, totalCost), 'success', 5000)
        totalLitersAdded = 0
        totalCost = 0
    end
end

-- Debug helper
local debugEnabled = true
local function FuelDebug(...)
    if debugEnabled then
        print('[sb_fuel:DEBUG]', ...)
    end
end

-- Nozzle management thread
function NozzleThread()
    local lastDistanceCheck = 0
    local lastVehicleDebug = 0

    FuelDebug('NozzleThread started')

    while isHoldingNozzle do
        Wait(0) -- Per-frame for responsive key detection

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local currentTime = GetGameTimer()

        -- Check distance from pump (every 500ms to save performance)
        if currentTime - lastDistanceCheck > 500 then
            lastDistanceCheck = currentTime
            if currentPumpCoords then
                local distance = #(playerCoords - currentPumpCoords)
                if distance > Config.Nozzle.maxDistance then
                    exports['sb_notify']:Notify('You walked too far - nozzle dropped', 'warning', 3000)
                    if isRefueling then
                        StopRefueling()
                    end
                    DropNozzle()
                    break
                end
            end
        end

        -- Different behavior based on refueling state
        if isRefueling then
            -- While refueling, show stop prompt (progress bar handles the visual)
            -- X key to stop and drop nozzle
            if IsControlJustPressed(0, 73) then -- X key
                StopRefueling()
                DropNozzle()
                break
            end
        else
            -- Not refueling - check for vehicle nearby
            -- First try GetClosestVehicle
            local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, Config.Nozzle.attachDistance, 0, 70)

            -- If GetClosestVehicle fails, manually scan (fixes occupied vehicle detection)
            if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
                local closestDist = Config.Nozzle.attachDistance
                local vehicles = GetGamePool('CVehicle')
                for _, veh in ipairs(vehicles) do
                    if DoesEntityExist(veh) then
                        local vehCoords = GetEntityCoords(veh)
                        local dist = #(playerCoords - vehCoords)
                        if dist < closestDist then
                            closestDist = dist
                            vehicle = veh
                        end
                    end
                end
            end

            -- Debug vehicle detection every 2 seconds
            if currentTime - lastVehicleDebug > 2000 then
                lastVehicleDebug = currentTime
                FuelDebug('--- Vehicle Check ---')
                FuelDebug('attachDistance:', Config.Nozzle.attachDistance)

                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    FuelDebug('Vehicle FOUND!')
                    FuelDebug('Vehicle model:', GetEntityModel(vehicle))
                    FuelDebug('Vehicle plate:', GetVehicleNumberPlateText(vehicle))

                    -- Check occupants
                    local driver = GetPedInVehicleSeat(vehicle, -1)
                    local passenger = GetPedInVehicleSeat(vehicle, 0)
                    FuelDebug('Driver ped:', driver, 'exists:', driver ~= 0 and DoesEntityExist(driver))
                    FuelDebug('Passenger ped:', passenger, 'exists:', passenger ~= 0 and DoesEntityExist(passenger))

                    -- Distance to vehicle
                    local vehCoords = GetEntityCoords(vehicle)
                    local dist = #(playerCoords - vehCoords)
                    FuelDebug('Distance to vehicle:', dist)
                else
                    FuelDebug('No vehicle found nearby')

                    -- Scan all nearby vehicles for debug
                    local vehicles = GetGamePool('CVehicle')
                    FuelDebug('Total vehicles in pool:', #vehicles)
                    for _, veh in ipairs(vehicles) do
                        if DoesEntityExist(veh) then
                            local vehCoords = GetEntityCoords(veh)
                            local dist = #(playerCoords - vehCoords)
                            if dist < 10.0 then
                                local hasDriver = GetPedInVehicleSeat(veh, -1) ~= 0
                                FuelDebug('Nearby vehicle:', GetVehicleNumberPlateText(veh), 'dist:', dist, 'hasDriver:', hasDriver)
                            end
                        end
                    end
                end
            end

            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                -- Show prompt
                DisplayHelpText('Press ~INPUT_CONTEXT~ to start refueling')

                if IsControlJustPressed(0, 38) then -- E key
                    FuelDebug('E pressed, starting refuel on vehicle:', GetVehicleNumberPlateText(vehicle))
                    StartRefueling(vehicle)
                end
            else
                DisplayHelpText('Walk to vehicle and press ~INPUT_CONTEXT~ | ~INPUT_VEH_DUCK~ to drop nozzle')
            end

            -- Cancel with X when not refueling
            if IsControlJustPressed(0, 73) then -- X key
                DropNozzle()
                break
            end
        end
    end

    FuelDebug('NozzleThread ended')
end

-- Get vehicle in front of player
function GetVehicleInFront(ped)
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local endCoords = coords + forward * 3.0

    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        coords.x, coords.y, coords.z,
        endCoords.x, endCoords.y, endCoords.z,
        2, -- Vehicles
        ped,
        0
    )

    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

    if hit and IsEntityAVehicle(entityHit) then
        return entityHit
    end

    -- Also check nearby vehicles
    local closestVeh = GetClosestVehicle(coords.x, coords.y, coords.z, Config.Nozzle.attachDistance, 0, 70)
    if closestVeh and closestVeh ~= 0 then
        return closestVeh
    end

    return nil
end

-- Display help text
function DisplayHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Play sound helper
function PlayFuelSound(sound)
    if sound and sound.name then
        if sound.set then
            PlaySoundFrontend(-1, sound.name, sound.set, true)
        end
    end
end

-- ============================================================================
-- REFUELING (FIX-005: Pre-authorization system)
-- ============================================================================

-- Track authorization state
local authorizedAmount = 0
local isAuthorized = false

function StartRefueling(vehicle)
    if isRefueling then
        exports['sb_notify']:Notify('Already refueling', 'error', 2000)
        return
    end
    if not isHoldingNozzle then return end

    local playerPed = PlayerPedId()
    targetVehicle = vehicle

    -- Check current fuel
    local currentFuel = exports['sb_fuel']:GetFuel(vehicle)
    if currentFuel >= 99.0 then
        exports['sb_notify']:Notify('Tank is already full', 'info', 3000)
        return
    end

    -- Calculate estimated cost
    local fuelNeeded = 100.0 - currentFuel
    local estimatedCost = math.floor(fuelNeeded * Config.FuelPrice * 100 + 0.5) / 100

    -- PRE-AUTHORIZE payment on server before starting
    -- This reserves the money so player can't spend it elsewhere during refueling
    exports['sb_notify']:Notify('Authorizing payment...', 'info', 1500)

    -- Clear any stale authorization before requesting new one
    TriggerServerEvent('sb_fuel:server:clearStaleAuth')

    SB.Functions.TriggerCallback('sb_fuel:server:authorizeFuel', function(success, authAmount, message)
        if not success then
            exports['sb_notify']:Notify(message or 'Cannot authorize payment', 'error', 3000)
            return
        end

        -- Store authorization
        authorizedAmount = authAmount
        isAuthorized = true

        -- Calculate duration based on authorized amount (might be less than full tank)
        local maxFuelCanBuy = authAmount / Config.FuelPrice
        local fuelToAdd = math.min(fuelNeeded, maxFuelCanBuy)
        local duration = (fuelToAdd / Config.RefuelRate) * 1000

        isRefueling = true
        local fuelAtStart = currentFuel

        PlayFuelSound(Config.Sounds.fuelStart)

        -- Start fuel update thread (runs alongside progress bar)
        -- No per-tick charging - money already reserved
        refuelThread = CreateThread(function()
            local lastUpdate = GetGameTimer()

            while isRefueling do
                Wait(100)

                if not targetVehicle or not DoesEntityExist(targetVehicle) then
                    break
                end

                local now = GetGameTimer()
                local elapsed = (now - lastUpdate) / 1000
                lastUpdate = now

                local currentFuel = exports['sb_fuel']:GetFuel(targetVehicle)

                -- Calculate fuel to add
                local fuelToAdd = Config.RefuelRate * elapsed
                local newFuel = math.min(100.0, currentFuel + fuelToAdd)
                local actualAdded = newFuel - currentFuel

                if actualAdded > 0.001 then
                    -- Check if we've hit our authorized limit
                    local currentCost = (newFuel - fuelAtStart) * Config.FuelPrice
                    if currentCost > authorizedAmount then
                        -- Cap at authorized amount
                        local maxFuel = fuelAtStart + (authorizedAmount / Config.FuelPrice)
                        newFuel = math.min(newFuel, maxFuel)
                        exports['sb_fuel']:SetFuel(targetVehicle, newFuel)
                        isRefueling = false
                        exports['sb_notify']:Notify('Reached payment limit', 'info', 2000)
                        break
                    end

                    -- Apply fuel (no money charge here - already authorized)
                    exports['sb_fuel']:SetFuel(targetVehicle, newFuel)

                    -- Track totals for display
                    totalLitersAdded = newFuel - fuelAtStart
                    totalCost = totalLitersAdded * Config.FuelPrice
                end

                -- Stop if tank is full
                if newFuel >= 100.0 then
                    isRefueling = false
                    break
                end
            end
        end)

        -- Use progress bar for visual feedback
        exports['sb_progressbar']:Start({
            duration = math.floor(duration),
            label = string.format('Refueling... (Authorized $%.0f)', authAmount),
            canCancel = true,
            anim = {
                dict = 'timetable@gardener@filling_can',
                clip = 'gar_ig_5_filling_can',
                flag = 49
            }
        }, function(completed)
            -- Stop the fuel update thread
            isRefueling = false

            PlayFuelSound(Config.Sounds.fuelStop)

            -- Calculate actual cost and finalize
            local finalFuel = 0
            local fuelAdded = 0
            local actualCost = 0

            if targetVehicle and DoesEntityExist(targetVehicle) then
                finalFuel = exports['sb_fuel']:GetFuel(targetVehicle)
                local netId = VehToNet(targetVehicle)
                TriggerServerEvent('sb_fuel:server:syncFuel', netId, finalFuel)

                fuelAdded = finalFuel - fuelAtStart
                actualCost = math.floor(fuelAdded * Config.FuelPrice * 100 + 0.5) / 100
            end

            -- Finalize payment on server (deducts actual, refunds unused)
            -- Only process if authorization wasn't already handled by StopRefueling()
            if isAuthorized then
                if actualCost > 0 then
                    TriggerServerEvent('sb_fuel:server:finalizeFuel', actualCost)
                    exports['sb_notify']:Notify(
                        string.format('Added %.1fL fuel - $%.2f', fuelAdded, actualCost),
                        'success', 4000
                    )
                else
                    -- No fuel added - cancel authorization (full refund)
                    TriggerServerEvent('sb_fuel:server:cancelFuelAuth')
                    exports['sb_notify']:Notify('Refueling cancelled - payment refunded', 'info', 3000)
                end
                isAuthorized = false
                authorizedAmount = 0

                if completed then
                    exports['sb_notify']:Notify('Tank is full!', 'success', 3000)
                end
            end

            targetVehicle = nil
        end)
    end, estimatedCost)
end

function StopRefueling()
    if not isRefueling then return end

    isRefueling = false

    -- Cancel progress bar if running
    exports['sb_progressbar']:Cancel()

    StopAnim()
    PlayFuelSound(Config.Sounds.fuelStop)

    -- Sync final fuel level and handle authorization
    if targetVehicle and DoesEntityExist(targetVehicle) then
        local finalFuel = exports['sb_fuel']:GetFuel(targetVehicle)
        local netId = VehToNet(targetVehicle)
        TriggerServerEvent('sb_fuel:server:syncFuel', netId, finalFuel)
    end

    -- IMPORTANT: Clear authorization if still active (fixes "already refueling" bug)
    -- This handles the case where StopRefueling is called via X key or walking away
    -- before the progress bar callback runs
    if isAuthorized then
        -- Calculate actual cost based on fuel added
        local actualCost = totalCost
        if actualCost > 0 then
            TriggerServerEvent('sb_fuel:server:finalizeFuel', actualCost)
        else
            TriggerServerEvent('sb_fuel:server:cancelFuelAuth')
        end
        isAuthorized = false
        authorizedAmount = 0
    end

    targetVehicle = nil
end

-- ============================================================================
-- JERRY CAN REFILL AT PUMP
-- ============================================================================

function RefillJerryCan(pumpEntity)
    local playerPed = PlayerPedId()

    -- Request jerry can info from server via callback
    SB.Functions.TriggerCallback('sb_fuel:server:getJerryCanInfo', function(jerryCanInfo)
        if not jerryCanInfo then
            exports['sb_notify']:Notify('No jerry can found', 'error', 3000)
            return
        end

        local currentAmount = jerryCanInfo.fuel or 0
        local toFill = Config.JerryCan.maxCapacity - currentAmount

        if toFill <= 0 then
            exports['sb_notify']:Notify('Jerry can is already full', 'info', 3000)
            return
        end

        -- Round cost to 2 decimal places
        local cost = math.floor(toFill * Config.JerryCan.refillPrice * 100 + 0.5) / 100

        -- Check money
        local PlayerData = SB.Functions.GetPlayerData()
        local playerCash = PlayerData.money.cash or 0

        if playerCash < cost then
            exports['sb_notify']:Notify(string.format('Need $%.2f to fill jerry can', cost), 'error', 3000)
            return
        end

        -- Face pump
        TaskTurnPedToFaceEntity(playerPed, pumpEntity, 1000)
        Wait(1000)

        -- Progress bar
        local duration = (toFill / Config.RefuelRate) * 1000

        exports['sb_progressbar']:Start({
            duration = math.floor(duration),
            label = 'Filling Jerry Can...',
            canCancel = true,
            anim = {
                dict = 'timetable@gardener@filling_can',
                clip = 'gar_ig_5_filling_can',
                flag = 49
            }
        }, function(completed)
            if completed then
                -- Charge player and fill jerry can
                TriggerServerEvent('sb_fuel:server:fillJerryCan', cost, Config.JerryCan.maxCapacity)
                exports['sb_notify']:Notify(string.format('Jerry can filled - $%.2f', cost), 'success', 3000)
                PlayFuelSound(Config.Sounds.payment)
            else
                exports['sb_notify']:Notify('Cancelled', 'info', 2000)
            end
        end)
    end)
end

-- ============================================================================
-- VEHICLE FUEL CAP POSITION (for nozzle attachment visual)
-- ============================================================================

-- Get approximate fuel cap position based on vehicle model
local function GetFuelCapPosition(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)

    -- Fuel cap is typically on rear quarter panel, passenger side
    local offset = vector3(
        (max.x - min.x) * 0.35,  -- Passenger side
        (max.y - min.y) * -0.25, -- Rear quarter
        (max.z - min.z) * 0.3    -- Mid height
    )

    return GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Clean up nozzle
    if nozzleObject and DoesEntityExist(nozzleObject) then
        DeleteObject(nozzleObject)
    end

    -- Clear animations
    ClearPedTasks(PlayerPedId())
end)

-- Drop nozzle if player enters vehicle
CreateThread(function()
    while true do
        Wait(500)

        if isHoldingNozzle and IsPedInAnyVehicle(PlayerPedId(), false) then
            exports['sb_notify']:Notify('Dropped fuel nozzle', 'warning', 2000)
            DropNozzle()
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsHoldingNozzle', function()
    return isHoldingNozzle
end)

exports('IsRefueling', function()
    return isRefueling
end)

exports('DropNozzle', function()
    DropNozzle()
end)

exports('ReturnNozzle', function()
    ReturnNozzle()
end)

-- Force reset refueling state (for fixing stuck states)
exports('ForceResetRefueling', function()
    isRefueling = false
    isAuthorized = false
    authorizedAmount = 0
    targetVehicle = nil
    totalLitersAdded = 0
    totalCost = 0
    TriggerServerEvent('sb_fuel:server:cancelFuelAuth')
end)

-- Debug command to reset stuck refueling state
RegisterCommand('resetfuel', function()
    isRefueling = false
    isAuthorized = false
    authorizedAmount = 0
    targetVehicle = nil
    totalLitersAdded = 0
    totalCost = 0
    TriggerServerEvent('sb_fuel:server:cancelFuelAuth')
    exports['sb_notify']:Notify('Fuel state reset', 'info', 2000)
end, false)
