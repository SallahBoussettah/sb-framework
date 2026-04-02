-- =============================================
-- SB_POLICE - ALPR System (Automatic License Plate Reader)
-- Sprint 6 Implementation
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

-- State variables
local alprActive = false
local alprLocked = false
local lockedPlate = nil
local frontVehicle = nil
local rearVehicle = nil
local lastFrontPlate = nil
local lastRearPlate = nil
local frontFlags = {}
local rearFlags = {}
local isOnDuty = false

-- Cache for plate checks (avoid spamming server)
local plateCache = {}
local CACHE_DURATION = 30000  -- 30 seconds

-- Track plates that already triggered an alert (prevents sound spam)
local alertedPlates = {}

-- Refresh SB object when sb_core restarts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- =============================================
-- Helper Functions
-- =============================================

local function GetPlayerJob()
    if SB and SB.Functions and SB.Functions.GetPlayerData then
        local playerData = SB.Functions.GetPlayerData()
        if playerData and playerData.job then
            return playerData.job
        end
    end
    if SB and SB.PlayerData and SB.PlayerData.job then
        return SB.PlayerData.job
    end
    return nil
end

local function IsPoliceJob()
    local job = GetPlayerJob()
    if not job then return false end
    return job.name == Config.PoliceJob
end

local function CanUseALPR()
    if not Config.ALPR.Enabled then return false end
    if not IsPoliceJob() then return false end
    local onDuty = exports['sb_police']:IsOnDuty()
    return onDuty
end

local function IsALPRVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)

    for vehModel, enabled in pairs(Config.ALPR.Vehicles) do
        if enabled and GetHashKey(vehModel) == model then
            return true
        end
    end
    return false
end

local function GetVehicleDisplayName(vehicle)
    if not DoesEntityExist(vehicle) then return 'Unknown' end
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local labelText = GetLabelText(displayName)
    if labelText and labelText ~= 'NULL' then
        return labelText
    end
    return displayName or 'Unknown'
end

local function GetVehicleSpeedMPH(vehicle)
    if not DoesEntityExist(vehicle) then return 0 end
    local speed = GetEntitySpeed(vehicle)
    return math.floor(speed * 2.236936)  -- m/s to mph
end

local function CheckPlateFlags(plate, callback)
    if not plate then
        callback({})
        return
    end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    local now = GetGameTimer()

    -- Check cache first
    if plateCache[cleanPlate] and (now - plateCache[cleanPlate].time) < CACHE_DURATION then
        callback(plateCache[cleanPlate].flags)
        return
    end

    -- Query server
    SB.Functions.TriggerCallback('sb_police:server:checkPlateALPR', function(flags)
        plateCache[cleanPlate] = {
            flags = flags or {},
            time = now
        }
        callback(flags or {})
    end, cleanPlate)
end

-- =============================================
-- Scanning Logic
-- =============================================

local function ScanVehicles()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil, nil
    end

    local front = nil
    local rear = nil

    -- Front scan - raycast from front of vehicle
    local coordA = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.5, 0.5)
    local coordB = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, Config.ALPR.ScanDistance, 0.5)

    local rayHandle = StartShapeTestCapsule(coordA.x, coordA.y, coordA.z, coordB.x, coordB.y, coordB.z, 2.5, 10, vehicle, 7)
    local _, hitFront, _, _, frontEntity = GetShapeTestResult(rayHandle)

    if hitFront and frontEntity and DoesEntityExist(frontEntity) and IsEntityAVehicle(frontEntity) then
        local plate = GetVehicleNumberPlateText(frontEntity)
        if plate then
            front = {
                entity = frontEntity,
                plate = plate:gsub('%s+', ''):upper(),
                name = GetVehicleDisplayName(frontEntity),
                speed = GetVehicleSpeedMPH(frontEntity),
                plateIndex = GetVehicleNumberPlateTextIndex(frontEntity)
            }
        end
    end

    -- Rear scan - raycast from rear of vehicle
    local coordC = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.5)
    local coordD = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -Config.ALPR.ScanDistance, 0.5)

    local rayHandle2 = StartShapeTestCapsule(coordC.x, coordC.y, coordC.z, coordD.x, coordD.y, coordD.z, 2.5, 10, vehicle, 7)
    local _, hitRear, _, _, rearEntity = GetShapeTestResult(rayHandle2)

    if hitRear and rearEntity and DoesEntityExist(rearEntity) and IsEntityAVehicle(rearEntity) then
        local plate = GetVehicleNumberPlateText(rearEntity)
        if plate then
            rear = {
                entity = rearEntity,
                plate = plate:gsub('%s+', ''):upper(),
                name = GetVehicleDisplayName(rearEntity),
                speed = GetVehicleSpeedMPH(rearEntity),
                plateIndex = GetVehicleNumberPlateTextIndex(rearEntity)
            }
        end
    end

    return front, rear
end

-- =============================================
-- NUI Communication
-- =============================================

local function ShowALPR()
    SendNUIMessage({ type = 'alprShow' })
end

local function HideALPR()
    SendNUIMessage({ type = 'alprHide' })
end

local function UpdateALPRHUD()
    local frontData = nil
    local rearData = nil

    if frontVehicle then
        frontData = {
            plate = frontVehicle.plate,
            name = frontVehicle.name,
            speed = frontVehicle.speed,
            flags = frontFlags or {},
            plateIndex = frontVehicle.plateIndex or 0
        }
    end

    if rearVehicle then
        rearData = {
            plate = rearVehicle.plate,
            name = rearVehicle.name,
            speed = rearVehicle.speed,
            flags = rearFlags or {},
            plateIndex = rearVehicle.plateIndex or 0
        }
    end

    SendNUIMessage({
        type = 'alprUpdate',
        front = frontData,
        rear = rearData,
        locked = alprLocked,
        lockedPlate = lockedPlate
    })
end

-- =============================================
-- ALPR Toggle
-- =============================================

local function ToggleALPR()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Check if in ALPR-equipped vehicle
    if vehicle == 0 then
        exports['sb_notify']:Notify('You must be in a vehicle', 'error', 3000)
        return
    end

    if not IsALPRVehicle(vehicle) then
        exports['sb_notify']:Notify('This vehicle has no ALPR system', 'error', 3000)
        return
    end

    if not CanUseALPR() then
        exports['sb_notify']:Notify('You must be on duty to use ALPR', 'error', 3000)
        return
    end

    alprActive = not alprActive

    if alprActive then
        ShowALPR()
        exports['sb_notify']:Notify('ALPR Activated', 'success', 2000)
        print('[sb_police] ALPR activated')

        -- Start scanning thread
        CreateThread(function()
            while alprActive do
                local playerPed = PlayerPedId()
                local currentVehicle = GetVehiclePedIsIn(playerPed, false)

                -- Auto-disable if left vehicle
                if currentVehicle == 0 then
                    alprActive = false
                    alprLocked = false
                    lockedPlate = nil
                    frontVehicle = nil
                    rearVehicle = nil
                    frontFlags = {}
                    rearFlags = {}
                    alertedPlates = {}
                    HideALPR()
                    exports['sb_notify']:Notify('ALPR Deactivated', 'info', 2000)
                    print('[sb_police] ALPR auto-disabled - exited vehicle')
                    return
                end

                -- Scan for vehicles
                local front, rear = ScanVehicles()

                -- Update front vehicle
                if front then
                    frontVehicle = front

                    -- Check flags if plate changed
                    if front.plate ~= lastFrontPlate then
                        lastFrontPlate = front.plate
                        CheckPlateFlags(front.plate, function(flags)
                            frontFlags = flags
                            if #flags > 0 and not alertedPlates[front.plate] then
                                alertedPlates[front.plate] = true
                                PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                                for _, flag in ipairs(flags) do
                                    exports['sb_notify']:Notify('ALPR ALERT: ' .. flag.type:upper() .. ' - ' .. front.plate, 'warning', 5000)
                                end
                            end
                            UpdateALPRHUD()
                        end)
                    else
                        -- Update speed
                        frontVehicle.speed = GetVehicleSpeedMPH(front.entity)
                        UpdateALPRHUD()
                    end
                else
                    if not alprLocked or (lockedPlate and frontVehicle and lockedPlate ~= frontVehicle.plate) then
                        frontVehicle = nil
                        frontFlags = {}
                        lastFrontPlate = nil
                    end
                    UpdateALPRHUD()
                end

                -- Update rear vehicle
                if rear then
                    rearVehicle = rear

                    -- Check flags if plate changed
                    if rear.plate ~= lastRearPlate then
                        lastRearPlate = rear.plate
                        CheckPlateFlags(rear.plate, function(flags)
                            rearFlags = flags
                            if #flags > 0 and not alertedPlates[rear.plate] then
                                alertedPlates[rear.plate] = true
                                PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                                for _, flag in ipairs(flags) do
                                    exports['sb_notify']:Notify('ALPR ALERT: ' .. flag.type:upper() .. ' - ' .. rear.plate, 'warning', 5000)
                                end
                            end
                            UpdateALPRHUD()
                        end)
                    else
                        -- Update speed
                        rearVehicle.speed = GetVehicleSpeedMPH(rear.entity)
                        UpdateALPRHUD()
                    end
                else
                    if not alprLocked or (lockedPlate and rearVehicle and lockedPlate ~= rearVehicle.plate) then
                        rearVehicle = nil
                        rearFlags = {}
                        lastRearPlate = nil
                    end
                    UpdateALPRHUD()
                end

                Wait(Config.ALPR.ScanInterval)
            end
        end)
    else
        alprLocked = false
        lockedPlate = nil
        frontVehicle = nil
        rearVehicle = nil
        frontFlags = {}
        rearFlags = {}
        alertedPlates = {}
        lastFrontPlate = nil
        lastRearPlate = nil
        HideALPR()
        exports['sb_notify']:Notify('ALPR Deactivated', 'info', 2000)
        print('[sb_police] ALPR deactivated')
    end
end

local function LockPlate()
    if not alprActive then
        exports['sb_notify']:Notify('ALPR is not active', 'error', 3000)
        return
    end

    if alprLocked then
        -- Unlock
        alprLocked = false
        lockedPlate = nil
        exports['sb_notify']:Notify('ALPR Unlocked', 'info', 2000)
        print('[sb_police] ALPR plate unlocked')
    else
        -- Lock to front or rear plate (prefer front)
        local plateToLock = nil
        if frontVehicle and frontVehicle.plate then
            plateToLock = frontVehicle.plate
        elseif rearVehicle and rearVehicle.plate then
            plateToLock = rearVehicle.plate
        end

        if plateToLock then
            alprLocked = true
            lockedPlate = plateToLock
            exports['sb_notify']:Notify('ALPR Locked: ' .. plateToLock, 'success', 3000)
            print('[sb_police] ALPR plate locked: ' .. plateToLock)
        else
            exports['sb_notify']:Notify('No plate to lock', 'error', 3000)
        end
    end

    UpdateALPRHUD()
end

-- =============================================
-- Real-time Flag Updates
-- =============================================

RegisterNetEvent('sb_police:client:clearALPRCache', function(plate)
    if not plate then return end

    -- Clear cache and alert state for this plate (new flag added, allow fresh alert)
    plateCache[plate] = nil
    alertedPlates[plate] = nil

    -- If ALPR is active and we're currently scanning this plate, re-check it immediately
    if alprActive then
        if frontVehicle and frontVehicle.plate == plate then
            CheckPlateFlags(plate, function(flags)
                frontFlags = flags
                if #flags > 0 and not alertedPlates[plate] then
                    alertedPlates[plate] = true
                    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                    for _, flag in ipairs(flags) do
                        exports['sb_notify']:Notify('ALPR ALERT: ' .. flag.type:upper() .. ' - ' .. plate, 'warning', 5000)
                    end
                end
                UpdateALPRHUD()
            end)
        end

        if rearVehicle and rearVehicle.plate == plate then
            CheckPlateFlags(plate, function(flags)
                rearFlags = flags
                if #flags > 0 and not alertedPlates[plate] then
                    alertedPlates[plate] = true
                    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                    for _, flag in ipairs(flags) do
                        exports['sb_notify']:Notify('ALPR ALERT: ' .. flag.type:upper() .. ' - ' .. plate, 'warning', 5000)
                    end
                end
                UpdateALPRHUD()
            end)
        end
    end
end)

-- =============================================
-- Duty Sync
-- =============================================

RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    local wasOnDuty = isOnDuty
    isOnDuty = onDuty

    -- Disable ALPR when going off duty
    if wasOnDuty and not onDuty then
        if alprActive then
            alprActive = false
            alprLocked = false
            lockedPlate = nil
            frontVehicle = nil
            rearVehicle = nil
            frontFlags = {}
            rearFlags = {}
            alertedPlates = {}
            HideALPR()
            exports['sb_notify']:Notify('ALPR disabled - off duty', 'info', 3000)
        end
    end
end)

-- =============================================
-- Commands & Keybinds
-- =============================================

RegisterCommand('alpr', function()
    if not CanUseALPR() then
        if not IsPoliceJob() then
            exports['sb_notify']:Notify('Police only', 'error', 3000)
        else
            exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        end
        return
    end
    ToggleALPR()
end, false)

RegisterCommand('alprlock', function()
    if not CanUseALPR() then return end
    LockPlate()
end, false)

RegisterCommand('alprstop', function()
    if alprActive then
        alprActive = false
        alprLocked = false
        lockedPlate = nil
        frontVehicle = nil
        rearVehicle = nil
        frontFlags = {}
        rearFlags = {}
        alertedPlates = {}
        HideALPR()
        exports['sb_notify']:Notify('ALPR Force Stopped', 'info', 2000)
    end
end, false)

RegisterCommand('alprtest', function()
    print('[sb_police] ========== ALPR DEBUG ==========')
    print('ALPR Active:', alprActive)
    print('ALPR Locked:', alprLocked)
    print('Locked Plate:', lockedPlate or 'none')
    print('Front Vehicle:', frontVehicle and frontVehicle.plate or 'none')
    print('Rear Vehicle:', rearVehicle and rearVehicle.plate or 'none')
    print('Front Flags:', #frontFlags)
    print('Rear Flags:', #rearFlags)
    print('Is On Duty:', exports['sb_police']:IsOnDuty())
    print('[sb_police] ==================================')

    local msg = ('ALPR: %s | Locked: %s | Front: %s | Rear: %s'):format(
        alprActive and 'ON' or 'OFF',
        alprLocked and lockedPlate or 'No',
        frontVehicle and frontVehicle.plate or '---',
        rearVehicle and rearVehicle.plate or '---'
    )
    exports['sb_notify']:Notify(msg, 'info', 5000)
end, false)

-- Remove stolen flag (for testing)
RegisterCommand('clearstolen', function(_, args)
    if not CanUseALPR() then
        exports['sb_notify']:Notify('Police only', 'error', 3000)
        return
    end

    local plate = args[1]
    if not plate then
        exports['sb_notify']:Notify('Usage: /clearstolen [plate]', 'error', 3000)
        return
    end

    TriggerServerEvent('sb_police:server:removeVehicleFlag', plate, 'stolen')
end, false)

-- Remove BOLO flag (for testing)
RegisterCommand('clearbolo', function(_, args)
    if not CanUseALPR() then
        exports['sb_notify']:Notify('Police only', 'error', 3000)
        return
    end

    local plate = args[1]
    if not plate then
        exports['sb_notify']:Notify('Usage: /clearbolo [plate]', 'error', 3000)
        return
    end

    TriggerServerEvent('sb_police:server:removeVehicleFlag', plate, 'bolo')
end, false)

-- Register keybinds (only if key is configured)
if Config.ALPR.Key and Config.ALPR.Key ~= '' then
    RegisterKeyMapping('alpr', 'Toggle ALPR', 'keyboard', Config.ALPR.Key)
end
if Config.ALPR.LockKey and Config.ALPR.LockKey ~= '' then
    RegisterKeyMapping('alprlock', 'Lock ALPR Plate', 'keyboard', Config.ALPR.LockKey)
end

-- =============================================
-- Resource Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if alprActive then
            HideALPR()
        end
    end
end)

-- =============================================
-- Exports
-- =============================================

exports('IsALPRActive', function()
    return alprActive
end)

exports('GetALPRData', function()
    return {
        active = alprActive,
        locked = alprLocked,
        lockedPlate = lockedPlate,
        front = frontVehicle,
        rear = rearVehicle
    }
end)

print('[sb_police] ^2ALPR module loaded^7')
