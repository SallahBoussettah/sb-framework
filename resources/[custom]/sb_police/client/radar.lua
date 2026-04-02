-- =============================================
-- SB_POLICE - Radar Gun System (ProLaser 4)
-- Inventory-based with streamed LIDAR weapon model
-- Use from inventory → WEAPON_PROLASER4 → right-click to aim & scan, left-click to lock/unlock
-- Requires: [standalone]/LidarGun streaming resource
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

-- State variables
local radarActive = false       -- Radar mode toggled on (weapon in hand)
local radarAiming = false       -- Player currently holding right-click
local radarLocked = false
local lockedSpeed = 0
local lockedDirection = ''
local lockedPlate = ''
local lockedRange = 0
local isOnDuty = false

-- Current reading
local currentSpeed = 0
local currentDirection = ''
local currentPlate = ''
local currentVehicleModel = ''
local currentRange = 0

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

local function CanUseRadar()
    if not Config.Radar.Enabled then return false end
    if not IsPoliceJob() then return false end
    local onDuty = exports['sb_police']:IsOnDuty()
    return onDuty
end

local function GetSpeedConverted(speedMPS)
    if Config.Radar.SpeedUnit == 'kmh' then
        return math.floor(speedMPS * Config.Radar.MPS_TO_KMH)
    end
    return math.floor(speedMPS * Config.Radar.MPS_TO_MPH)
end

local function GetSpeedLabel()
    if Config.Radar.SpeedUnit == 'kmh' then return 'KM/H' end
    return 'MPH'
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

-- =============================================
-- Weapon Management (WEAPON_VINTAGEPISTOL = ProLaser 4)
-- =============================================

local function EquipRadarWeapon()
    local ped = PlayerPedId()
    local hash = Config.Radar.WeaponHash

    -- Force-holster any sb_weapons weapon first
    pcall(function()
        exports['sb_weapons']:ForceHolster()
    end)
    Wait(100)

    -- Give the custom WEAPON_PROLASER4 (FireType=NONE, ClipSize=0, NonViolent flag)
    GiveWeaponToPed(ped, hash, 0, false, false)
    SetCurrentPedWeapon(ped, hash)

    return true
end

local function HolsterRadarWeapon()
    local ped = PlayerPedId()
    local hash = Config.Radar.WeaponHash
    RemoveWeaponFromPed(ped, hash)
end

-- =============================================
-- Scanning Logic (raycast-based)
-- Only scans when player is holding right-click
-- =============================================

local function ScanForVehicle()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)

    -- Use camera position as raycast origin (matches crosshair perfectly)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local radX = math.rad(camRot.x)
    local radZ = math.rad(camRot.z)

    local dirX = -math.sin(radZ) * math.abs(math.cos(radX))
    local dirY = math.cos(radZ) * math.abs(math.cos(radX))
    local dirZ = math.sin(radX)

    local startCoords = camCoords
    local endCoords = startCoords + vector3(dirX, dirY, dirZ) * Config.Radar.ScanDistance

    -- Raycast from camera toward where player is aiming (wider capsule for reliable hits)
    local rayHandle = StartShapeTestCapsule(
        startCoords.x, startCoords.y, startCoords.z,
        endCoords.x, endCoords.y, endCoords.z,
        5.0, 10, playerPed, 7
    )
    local _, hit, _, _, hitEntity = GetShapeTestResult(rayHandle)

    if hit and hitEntity and DoesEntityExist(hitEntity) and IsEntityAVehicle(hitEntity) then
        -- Don't scan our own vehicle
        if hitEntity == playerVehicle then return nil end

        local speed = GetEntitySpeed(hitEntity)
        local convertedSpeed = GetSpeedConverted(speed)

        -- Filter out stationary vehicles
        if convertedSpeed < Config.Radar.MinSpeed then return nil end

        -- Calculate direction (approaching or receding) relative to player position
        local targetCoords = GetEntityCoords(hitEntity)
        local targetVelocity = GetEntityVelocity(hitEntity)

        -- Vector from target to player
        local toPlayer = playerCoords - targetCoords
        local toPlayerNorm = toPlayer / #toPlayer

        -- Dot product of velocity and direction to player
        local dot = targetVelocity.x * toPlayerNorm.x + targetVelocity.y * toPlayerNorm.y
        local direction = dot > 0.5 and 'APPROACHING' or (dot < -0.5 and 'RECEDING' or 'CROSSING')

        -- Distance from player to target in feet
        local distance = #(playerCoords - targetCoords)
        local rangeFeet = math.floor(distance * 3.28084)

        local plate = GetVehicleNumberPlateText(hitEntity)
        if plate then
            plate = plate:gsub('%s+', ''):upper()
        else
            plate = 'UNKNOWN'
        end

        return {
            speed = convertedSpeed,
            direction = direction,
            plate = plate,
            model = GetVehicleDisplayName(hitEntity),
            entity = hitEntity,
            range = rangeFeet
        }
    end

    return nil
end

-- =============================================
-- Lock/Unlock Speed (must be declared before StartRadarLoop for left-click)
-- =============================================

local function ToggleLock()
    if not radarActive then return end

    if radarLocked then
        -- Unlock
        radarLocked = false
        exports['sb_notify']:Notify('Radar unlocked', 'info', 2000)

        -- If not aiming, hide HUD
        if not radarAiming then
            SendNUIMessage({ type = 'radarHide' })
        else
            SendNUIMessage({
                type = 'radarUpdate',
                speed = 0,
                direction = '',
                plate = '',
                model = '',
                range = 0,
                locked = false,
                unit = GetSpeedLabel()
            })
        end
    else
        -- Lock current reading
        if currentSpeed > 0 then
            radarLocked = true
            lockedSpeed = currentSpeed
            lockedDirection = currentDirection
            lockedPlate = currentPlate
            lockedRange = currentRange

            -- Make sure HUD stays visible with locked data
            SendNUIMessage({ type = 'radarShow' })
            SendNUIMessage({
                type = 'radarUpdate',
                speed = lockedSpeed,
                direction = lockedDirection,
                plate = lockedPlate,
                model = currentVehicleModel,
                range = lockedRange,
                locked = true,
                unit = GetSpeedLabel()
            })

            exports['sb_notify']:Notify(
                string.format('Speed locked: %d %s (%s) - Plate: %s - Range: %dft',
                    lockedSpeed, GetSpeedLabel(), lockedDirection, lockedPlate, lockedRange),
                'success', 5000
            )
        else
            exports['sb_notify']:Notify('No target to lock — aim at a vehicle first', 'warning', 2000)
        end
    end
end

-- =============================================
-- Radar Main Loop
-- Right-click (control 25) to aim and scan
-- Left-click to lock/unlock while aiming
-- =============================================

local function StartRadarLoop()
    CreateThread(function()
        local hash = Config.Radar.WeaponHash
        local ped = PlayerPedId()
        local lastScanTime = 0

        while radarActive do
            ped = PlayerPedId()

            -- Force weapon to stay selected (prevent GTA auto-switch)
            SetCurrentPedWeapon(ped, hash)

            -- Prevent firing at engine level (not just control level)
            DisablePlayerFiring(ped, true)

            -- Disable controls for fire/melee/reload
            DisableControlAction(0, 24, true)   -- INPUT_ATTACK (fire / left-click)
            DisableControlAction(0, 45, true)   -- INPUT_RELOAD (prevents pistol whip)
            DisableControlAction(0, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE

            -- Detect if player is holding right-click (aiming the LIDAR gun)
            local isAiming = IsControlPressed(0, 25)

            if isAiming then
                if not radarAiming then
                    -- Just started aiming — show HUD
                    radarAiming = true
                    SendNUIMessage({ type = 'radarShow' })
                end

                -- Left-click to lock/unlock while aiming (control 24 is disabled, so use Disabled variant)
                if IsDisabledControlJustPressed(0, 24) then
                    ToggleLock()
                end

                -- Scan at configured interval (not every frame — raycast is expensive)
                local now = GetGameTimer()
                if not radarLocked and (now - lastScanTime) >= Config.Radar.ScanInterval then
                    lastScanTime = now
                    local result = ScanForVehicle()

                    if result then
                        currentSpeed = result.speed
                        currentDirection = result.direction
                        currentPlate = result.plate
                        currentVehicleModel = result.model
                        currentRange = result.range

                        SendNUIMessage({
                            type = 'radarUpdate',
                            speed = currentSpeed,
                            direction = currentDirection,
                            plate = currentPlate,
                            model = currentVehicleModel,
                            range = currentRange,
                            locked = false,
                            unit = GetSpeedLabel()
                        })
                    else
                        currentSpeed = 0
                        currentDirection = ''
                        currentPlate = ''
                        currentVehicleModel = ''
                        currentRange = 0

                        SendNUIMessage({
                            type = 'radarUpdate',
                            speed = 0,
                            direction = '',
                            plate = '',
                            model = '',
                            range = 0,
                            locked = false,
                            unit = GetSpeedLabel()
                        })
                    end
                end
            else
                if radarAiming then
                    -- Stopped aiming
                    radarAiming = false

                    -- If locked, keep showing HUD with locked reading
                    if not radarLocked then
                        SendNUIMessage({ type = 'radarHide' })
                        -- Clear current reading
                        currentSpeed = 0
                        currentDirection = ''
                        currentPlate = ''
                        currentVehicleModel = ''
                        currentRange = 0
                    end
                end
            end

            Wait(0) -- Every frame — controls MUST be disabled per-frame
        end

        -- Cleanup when loop exits
        radarAiming = false
        SendNUIMessage({ type = 'radarHide' })
    end)
end

-- =============================================
-- Toggle Radar (triggered from inventory use)
-- =============================================

local function ToggleRadar()
    if not CanUseRadar() then
        exports['sb_notify']:Notify('You must be on duty to use the radar', 'error', 3000)
        return
    end

    if radarActive then
        -- Turn off — remove weapon, stop loop
        radarActive = false
        radarAiming = false
        radarLocked = false
        lockedSpeed = 0
        lockedDirection = ''
        lockedPlate = ''
        lockedRange = 0
        SendNUIMessage({ type = 'radarHide' })
        HolsterRadarWeapon()
        exports['sb_notify']:Notify('LIDAR gun holstered', 'info', 3000)
        return
    end

    -- Turn on — equip weapon, start scan loop
    local equipped = EquipRadarWeapon()
    if not equipped then
        exports['sb_notify']:Notify('Failed to equip LIDAR gun', 'error', 3000)
        return
    end

    radarActive = true
    radarLocked = false
    lockedSpeed = 0
    lockedDirection = ''
    lockedPlate = ''
    lockedRange = 0
    currentSpeed = 0
    currentDirection = ''
    currentPlate = ''
    currentVehicleModel = ''
    currentRange = 0

    exports['sb_notify']:Notify('LIDAR gun equipped — hold RIGHT-CLICK to scan', 'success', 5000)
    StartRadarLoop()
end

-- =============================================
-- Event: Use radar gun from inventory
-- =============================================

RegisterNetEvent('sb_police:client:useRadarGun', function()
    ToggleRadar()
end)

-- =============================================
-- Commands (debug only — left-click replaces /radarlock)
-- =============================================

RegisterCommand('radartest', function()
    print('[sb_police:radar] ========== RADAR STATE ==========')
    print('  Active:', radarActive)
    print('  Aiming:', radarAiming)
    print('  Locked:', radarLocked)
    print('  Current Speed:', currentSpeed)
    print('  Current Direction:', currentDirection)
    print('  Current Plate:', currentPlate)
    print('  Locked Speed:', lockedSpeed)
    print('  Locked Direction:', lockedDirection)
    print('  Locked Plate:', lockedPlate)
    print('[sb_police:radar] ==================================')

    exports['sb_notify']:Notify(
        string.format('Radar: %s | Aiming: %s | Speed: %d %s | Locked: %s',
            radarActive and 'ON' or 'OFF',
            tostring(radarAiming),
            radarLocked and lockedSpeed or currentSpeed,
            GetSpeedLabel(),
            tostring(radarLocked)),
        'info', 5000
    )
end, false)

-- =============================================
-- Duty Tracking
-- =============================================

RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    isOnDuty = onDuty

    -- Auto-disable radar when going off duty
    if not onDuty and radarActive then
        radarActive = false
        radarAiming = false
        radarLocked = false
        lockedRange = 0
        currentRange = 0
        SendNUIMessage({ type = 'radarHide' })
        HolsterRadarWeapon()
    end
end)

-- =============================================
-- Exports
-- =============================================

exports('IsRadarActive', function() return radarActive end)
exports('IsRadarLocked', function() return radarLocked end)
exports('GetLockedSpeed', function() return lockedSpeed end)
exports('GetLockedPlate', function() return lockedPlate end)
exports('GetLockedRange', function() return lockedRange end)

-- =============================================
-- Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if radarActive then
        radarActive = false
        radarAiming = false
        SendNUIMessage({ type = 'radarHide' })
        HolsterRadarWeapon()
    end
end)

-- Replace weapon hash label in game UI
AddTextEntry('WT_PROLASER4', 'ProLaser 4')

print('[sb_police:radar] ^2ProLaser 4 LIDAR system loaded (WEAPON_PROLASER4 custom weapon)^7')
