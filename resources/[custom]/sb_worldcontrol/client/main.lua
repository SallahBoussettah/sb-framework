-- ========================================================================
-- sb_worldcontrol | Client
-- RP World Management: vehicle locking, density, police, cleanup
-- ========================================================================

-- ========================================================================
-- ONE-TIME SETUP
-- ========================================================================
local function InitWorldControl()
    local playerId = PlayerId()
    local ped = PlayerPedId()

    if Config.DisableCops then
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
    else
        SetCreateRandomCops(true)
        SetCreateRandomCopsNotOnScenarios(true)
        SetCreateRandomCopsOnScenarios(true)
    end

    NetworkSetFriendlyFireOption(true)
    SetCanAttackFriendly(ped, true, false)

    if Config.DisableAmbientSirens then
        DistantCopCarSirens(false)
    end

    if Config.DisableWantedSystem then
        SetMaxWantedLevel(0)
    end

    if Config.DisableDispatch then
        for i = 1, 15 do
            EnableDispatchService(i, false)
        end
    end

    if Config.DisableHealthRegen then
        SetPlayerHealthRechargeMultiplier(playerId, 0.0)
    end
end

AddEventHandler('playerSpawned', function()
    InitWorldControl()
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    InitWorldControl()
end)

-- ========================================================================
-- THREAD 1: Per-Frame (density + idle cam)
-- ========================================================================
local disableIdleCam = Config.DisableIdleCamera -- cache config lookup

CreateThread(function()
    local playerId = PlayerId()
    while true do
        SetPedDensityMultiplierThisFrame(Config.PedDensity)
        SetVehicleDensityMultiplierThisFrame(Config.VehicleDensity)
        SetParkedVehicleDensityMultiplierThisFrame(Config.ParkedVehicleDensity)
        SetScenarioPedDensityMultiplierThisFrame(Config.ScenarioPedDensity, Config.ScenarioPedDensity)
        DisablePlayerVehicleRewards(playerId)

        if disableIdleCam then
            InvalidateIdleCam()
        end

        Wait(0)
    end
end)

-- ========================================================================
-- THREAD 2: Slow Tick (1 second) - Police, wanted, events
-- ========================================================================
CreateThread(function()
    while true do
        local playerId = PlayerId()
        local ped = PlayerPedId()

        if Config.DisableWantedSystem then
            if GetPlayerWantedLevel(playerId) > 0 then
                ClearPlayerWantedLevel(playerId)
            end
            SetMaxWantedLevel(0)
        end

        if Config.PoliceIgnorePlayer then
            SetPoliceIgnorePlayer(ped, true)
        end

        if Config.DisableDispatch then
            for i = 1, 15 do
                EnableDispatchService(i, false)
            end
        end

        if Config.DisableRandomEvents then
            SetRandomEventFlag(false)
        end

        if Config.DisableStuntJumps then
            CancelStuntJump()
        end

        if Config.DisableAutoWeaponSwap then
            SetPedDropsWeaponsWhenDead(ped, false)
        end

        Wait(1000)
    end
end)

-- ========================================================================
-- THREAD 3: NPC Vehicle Locking
-- Lock state 2 = VEHICLELOCK_LOCKED (native "try door handle" animation)
-- Prevents window smash (task 121) so player can't break in.
-- ========================================================================
local myVehicles = {}       -- [vehicle] = true, vehicles local player has used
local ownedVehicles = {}    -- [vehicle] = true, vehicles flagged via state bag

if Config.LockNPCVehicles then
    DecorRegister('sb_owned', 2)

    -- Event-driven state bag listener (no polling needed)
    AddStateBagChangeHandler('sb_owned', nil, function(bagName, key, value)
        local entity = GetEntityFromStateBagName(bagName)
        if entity ~= 0 and DoesEntityExist(entity) then
            if value then
                ownedVehicles[entity] = true
                if GetVehicleDoorLockStatus(entity) == 2 then
                    SetVehicleDoorsLocked(entity, 1)
                end
            else
                ownedVehicles[entity] = nil
            end
        end
    end)

    -- Rental vehicles should be treated like owned (unlockable by renter)
    AddStateBagChangeHandler('sb_rental', nil, function(bagName, key, value)
        local entity = GetEntityFromStateBagName(bagName)
        if entity ~= 0 and DoesEntityExist(entity) then
            if value then
                ownedVehicles[entity] = true
                if GetVehicleDoorLockStatus(entity) == 2 then
                    SetVehicleDoorsLocked(entity, 1)
                end
            else
                ownedVehicles[entity] = nil
            end
        end
    end)

    -- Track when local player enters a vehicle
    CreateThread(function()
        local lastVeh = 0
        while true do
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)

            if veh ~= 0 and veh ~= lastVeh then
                myVehicles[veh] = true
                if GetVehicleDoorLockStatus(veh) == 2 then
                    SetVehicleDoorsLocked(veh, 1)
                end
                lastVeh = veh
            elseif veh == 0 then
                lastVeh = 0
            end

            Wait(500)
        end
    end)

    -- Lock NPC vehicles (spread across frames to prevent spikes)
    local BATCH_SIZE = 10  -- vehicles processed per frame
    CreateThread(function()
        while true do
            local vehicles = GetGamePool('CVehicle')
            local count = #vehicles

            if count > 0 then
                -- Pre-compute player vehicles ONCE per cycle
                local playerVehicleSet = {}
                local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
                if playerVeh ~= 0 then playerVehicleSet[playerVeh] = true end
                local players = GetActivePlayers()
                for j = 1, #players do
                    local pPed = GetPlayerPed(players[j])
                    if pPed ~= 0 then
                        local cv = GetVehiclePedIsIn(pPed, false)
                        if cv ~= 0 then playerVehicleSet[cv] = true end
                        local lv = GetVehiclePedIsIn(pPed, true)
                        if lv ~= 0 then playerVehicleSet[lv] = true end
                    end
                end

                -- Process in batches, yielding between each batch
                for i = 1, count, BATCH_SIZE do
                    local batchEnd = i + BATCH_SIZE - 1
                    if batchEnd > count then batchEnd = count end

                    for j = i, batchEnd do
                        local vehicle = vehicles[j]
                        if DoesEntityExist(vehicle)
                            and not playerVehicleSet[vehicle]
                            and not myVehicles[vehicle]
                            and not ownedVehicles[vehicle]
                            and GetVehicleDoorLockStatus(vehicle) ~= 2
                        then
                            if not DecorExistOn(vehicle, 'sb_owned') then
                                SetVehicleDoorsLocked(vehicle, 2)
                            end
                        end
                    end

                    if batchEnd < count then
                        Wait(0) -- yield to next frame before processing next batch
                    end
                end
            end

            Wait(2000) -- wait before starting next full cycle
        end
    end)

    -- Cleanup tables (remove deleted entities)
    CreateThread(function()
        while true do
            Wait(60000)
            for vehicle in pairs(myVehicles) do
                if not DoesEntityExist(vehicle) then
                    myVehicles[vehicle] = nil
                end
            end
            for vehicle in pairs(ownedVehicles) do
                if not DoesEntityExist(vehicle) then
                    ownedVehicles[vehicle] = nil
                end
            end
        end
    end)

    -- Prevent window smash + show notification
    local lastNotify = 0

    CreateThread(function()
        while true do
            local ped = PlayerPedId()

            if GetIsTaskActive(ped, 121) then
                ClearPedTasksImmediately(ped)

                local now = GetGameTimer()
                if now - lastNotify > 3000 then
                    lastNotify = now
                    TriggerEvent('SB:Client:Notify', Config.LockNotifyMessage, 'error', 3000)
                end
            end

            Wait(200)
        end
    end)
end

-- ========================================================================
-- RESOURCE CLEANUP
-- ========================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Unlock all vehicles we locked
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        if GetVehicleDoorLockStatus(vehicles[i]) == 2 then
            SetVehicleDoorsLocked(vehicles[i], 1)
        end
    end
    myVehicles = {}

    local playerId = PlayerId()
    SetMaxWantedLevel(5)
    SetPlayerHealthRechargeMultiplier(playerId, 1.0)
    SetPoliceIgnorePlayer(PlayerPedId(), false)
    SetCreateRandomCops(true)
    SetCreateRandomCopsNotOnScenarios(true)
    SetCreateRandomCopsOnScenarios(true)
    for i = 1, 15 do
        EnableDispatchService(i, true)
    end
    DistantCopCarSirens(true)
    NetworkSetFriendlyFireOption(false)
end)
