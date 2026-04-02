-- =============================================
-- SB_POLICE - Sirens & Lights System
-- Network-synced emergency vehicle controls
-- L = Toggle lights, ; = Cycle siren, E = Air horn
-- =============================================

local sirenStates = {}  -- [netId] = { lights, sirenTone, hornOn, sirenSoundId, hornSoundId }
local hornPressed = false
local lastVehicle = nil
local lastNetId = nil

-- =============================================
-- Utility Functions
-- =============================================

local function IsEmergencyVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)
    for vehName, _ in pairs(Config.Sirens.Vehicles) do
        if model == GetHashKey(vehName) then
            return true
        end
    end
    return false
end

local function GetVehicleNetId(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    if not NetworkGetEntityIsNetworked(vehicle) then return nil end
    return VehToNet(vehicle)
end

local function IsPlayerDriver(vehicle)
    local playerPed = PlayerPedId()
    return GetPedInVehicleSeat(vehicle, -1) == playerPed
end

-- =============================================
-- Sound System
-- Supports both native GTA sounds and custom NUI audio
-- =============================================

local activeSirenSoundId = nil
local activeHornSoundId = nil

-- Get the sounds array based on mode
local function GetSounds()
    if Config.Sirens.SoundMode == 'custom' then
        return Config.Sirens.CustomSounds
    else
        return Config.Sirens.NativeSounds
    end
end

local function GetHornSound()
    if Config.Sirens.SoundMode == 'custom' then
        return Config.Sirens.CustomHorn
    else
        return Config.Sirens.NativeHorn
    end
end

-- Stop siren sound (defined first so PlaySirenSound can call it)
local function StopSirenSound()
    if Config.Sirens.SoundMode == 'custom' then
        SendNUIMessage({ type = 'sirenStop' })
    else
        if activeSirenSoundId then
            StopSound(activeSirenSoundId)
            ReleaseSoundId(activeSirenSoundId)
            activeSirenSoundId = nil
            print('[sb_police:sirens] ^2Native: Stopped siren^7')
        end
    end
end

-- Play siren sound
local function PlaySirenSound(sirenIndex, vehicle)
    -- Stop any existing siren first
    StopSirenSound()

    if Config.Sirens.SoundMode == 'custom' then
        -- NUI custom audio
        SendNUIMessage({
            type = 'sirenPlay',
            sirenIndex = sirenIndex
        })
        print(('[sb_police:sirens] ^2NUI: Playing siren %d^7'):format(sirenIndex))
    else
        -- Native GTA sounds (like Origen)
        local sounds = GetSounds()
        if sounds[sirenIndex] and DoesEntityExist(vehicle) then
            activeSirenSoundId = GetSoundId()
            -- Use exact same params as Origen: soundId, soundName, entity, 0, 0, 0
            PlaySoundFromEntity(activeSirenSoundId, sounds[sirenIndex], vehicle, 0, 0, 0)
            print(('[sb_police:sirens] ^2Native: Playing %s (ID: %d)^7'):format(sounds[sirenIndex], activeSirenSoundId))
        end
    end
end

-- Play horn sound
local function PlayHornSound(vehicle)
    if Config.Sirens.SoundMode == 'custom' then
        SendNUIMessage({ type = 'hornPlay' })
    else
        if DoesEntityExist(vehicle) then
            activeHornSoundId = GetSoundId()
            PlaySoundFromEntity(activeHornSoundId, GetHornSound(), vehicle, 0, 0, 0)
        end
    end
end

-- Stop horn sound
local function StopHornSound()
    if Config.Sirens.SoundMode == 'custom' then
        SendNUIMessage({ type = 'hornStop' })
    else
        if activeHornSoundId then
            StopSound(activeHornSoundId)
            ReleaseSoundId(activeHornSoundId)
            activeHornSoundId = nil
        end
    end
end

-- Stop all sounds
local function StopAllSounds()
    StopSirenSound()
    StopHornSound()
end

-- =============================================
-- Light Control (Q Key)
-- =============================================

local function ToggleLights()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if not DoesEntityExist(vehicle) then return end
    if not IsPlayerDriver(vehicle) then return end
    if not IsEmergencyVehicle(vehicle) then
        exports['sb_notify']:Notify('Not an emergency vehicle', 'error', 2000)
        return
    end

    local netId = GetVehicleNetId(vehicle)
    if not netId then return end

    -- Toggle lights
    local lightsOn = IsVehicleSirenOn(vehicle)
    SetVehicleSiren(vehicle, not lightsOn)

    -- If turning lights off, also turn off siren
    if lightsOn then
        -- Turning off - mute everything
        SetVehicleHasMutedSirens(vehicle, true)
        TriggerServerEvent('sb_police:server:sirenState', netId, false, 0, false)
        exports['sb_notify']:Notify('Lights OFF', 'info', 1500)
    else
        -- Turning on - start with just lights (muted siren)
        SetVehicleHasMutedSirens(vehicle, true)
        TriggerServerEvent('sb_police:server:sirenState', netId, true, 0, false)
        exports['sb_notify']:Notify('Lights ON', 'info', 1500)
    end
end

RegisterCommand('police_lights', function()
    if not Config.Sirens.Enabled then return end
    ToggleLights()
end, false)
RegisterKeyMapping('police_lights', 'Toggle Emergency Lights', 'keyboard', Config.Sirens.LightsKey)

-- =============================================
-- Siren Tone Control (Comma Key)
-- =============================================

local function CycleSiren()
    print('[sb_police:sirens] ^3CycleSiren called^7')

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if not DoesEntityExist(vehicle) then
        print('[sb_police:sirens] ^1No vehicle^7')
        return
    end
    if not IsPlayerDriver(vehicle) then
        print('[sb_police:sirens] ^1Not driver^7')
        return
    end
    if not IsEmergencyVehicle(vehicle) then
        print('[sb_police:sirens] ^1Not emergency vehicle^7')
        return
    end

    -- Check if lights are on
    if not IsVehicleSirenOn(vehicle) then
        exports['sb_notify']:Notify('Turn on lights first (L)', 'error', 2000)
        return
    end

    local netId = GetVehicleNetId(vehicle)
    if not netId then
        print('[sb_police:sirens] ^1No netId^7')
        return
    end

    -- Get current state
    local currentState = sirenStates[netId] or { sirenTone = 0 }
    local newTone = (currentState.sirenTone or 0) + 1

    -- Cycle through tones (0 = off, 1 = tone1, 2 = tone2, etc.)
    local sounds = GetSounds()
    if newTone > #sounds then
        newTone = 0  -- Turn siren off but keep lights
    end

    print(('[sb_police:sirens] ^3Cycling siren: %d -> %d (max: %d, mode: %s)^7'):format(
        currentState.sirenTone or 0, newTone, #sounds, Config.Sirens.SoundMode))

    TriggerServerEvent('sb_police:server:sirenState', netId, true, newTone, false)

    if newTone == 0 then
        exports['sb_notify']:Notify('Siren OFF', 'info', 1500)
    else
        local soundName = sounds[newTone] or ('Siren ' .. newTone)
        exports['sb_notify']:Notify('Siren ' .. newTone .. ': ' .. soundName, 'info', 1500)
    end
end

RegisterCommand('police_siren', function()
    print('[sb_police:sirens] ^3police_siren command executed^7')
    if not Config.Sirens.Enabled then return end
    CycleSiren()
end, false)
RegisterKeyMapping('police_siren', 'Cycle Siren Tones', 'keyboard', Config.Sirens.SirenKey)

-- =============================================
-- Air Horn (E Key - Hold, replaces native horn)
-- Disables native horn and plays custom police horn
-- =============================================

CreateThread(function()
    while true do
        Wait(0)

        if not Config.Sirens.Enabled then goto continue end

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if DoesEntityExist(vehicle) and IsPlayerDriver(vehicle) and IsEmergencyVehicle(vehicle) then
            local netId = GetVehicleNetId(vehicle)
            local lightsOn = IsVehicleSirenOn(vehicle)

            -- Always disable native horn on emergency vehicles to prevent
            -- GTA from toggling lights/siren via E key (we use L for lights)
            DisableControlAction(0, 86, true)  -- INPUT_VEH_HORN

            if lightsOn then
                -- Lights on - E plays custom air horn
                if netId then
                    if IsDisabledControlPressed(0, 86) then
                        if not hornPressed then
                            hornPressed = true
                            TriggerServerEvent('sb_police:server:hornState', netId, true)
                        end
                    else
                        if hornPressed then
                            hornPressed = false
                            TriggerServerEvent('sb_police:server:hornState', netId, false)
                        end
                    end
                end
            else
                -- Lights off - E plays regular vehicle horn sound (no light toggle)
                if IsDisabledControlPressed(0, 86) then
                    if not hornPressed then
                        hornPressed = true
                        StartVehicleHorn(vehicle, 0, GetHashKey('NORMAL'), false)
                    end
                else
                    if hornPressed then
                        hornPressed = false
                    end
                end
            end
        else
            if hornPressed then
                hornPressed = false
                -- Clear horn state if we exited vehicle while horn was pressed
                if lastNetId then
                    TriggerServerEvent('sb_police:server:hornState', lastNetId, false)
                end
            end
        end

        ::continue::
    end
end)

-- =============================================
-- Network Sync - Receive State Updates
-- =============================================

RegisterNetEvent('sb_police:client:sirenStateSync', function(netId, lightsOn, sirenTone, hornOn)
    print(('[sb_police:sirens] ^2sirenStateSync received: netId=%s, lights=%s, tone=%s^7'):format(
        tostring(netId), tostring(lightsOn), tostring(sirenTone)))

    sirenStates[netId] = sirenStates[netId] or {}
    local state = sirenStates[netId]

    local vehicle = NetToVeh(netId)
    if not DoesEntityExist(vehicle) then
        print('[sb_police:sirens] ^1Vehicle not found for netId^7')
        return
    end

    -- Update lights visual
    local currentLights = IsVehicleSirenOn(vehicle)
    if currentLights ~= lightsOn then
        SetVehicleSiren(vehicle, lightsOn)
    end

    -- Always keep native siren muted (we control sounds ourselves)
    SetVehicleHasMutedSirens(vehicle, true)

    -- Handle siren sound change
    if state.sirenTone ~= sirenTone then
        print(('[sb_police:sirens] ^3Siren tone changed: %s -> %s^7'):format(
            tostring(state.sirenTone), tostring(sirenTone)))

        local sounds = GetSounds()
        if sirenTone > 0 and sirenTone <= #sounds then
            PlaySirenSound(sirenTone, vehicle)
        else
            StopSirenSound()
        end

        state.sirenTone = sirenTone
    end

    state.lightsOn = lightsOn
end)

RegisterNetEvent('sb_police:client:hornStateSync', function(netId, hornOn)
    sirenStates[netId] = sirenStates[netId] or {}
    local state = sirenStates[netId]

    local vehicle = NetToVeh(netId)
    if not DoesEntityExist(vehicle) then return end

    -- Handle horn sound
    if hornOn and not state.hornOn then
        PlayHornSound(vehicle)
    elseif not hornOn and state.hornOn then
        StopHornSound()
    end

    state.hornOn = hornOn
end)

-- =============================================
-- Cleanup on Vehicle Exit/Destroy
-- =============================================

CreateThread(function()
    while true do
        Wait(500)

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        -- Player exited vehicle
        if lastVehicle and (not vehicle or vehicle ~= lastVehicle) then
            if lastNetId then
                -- Turn off siren when exiting (only if we were the driver)
                TriggerServerEvent('sb_police:server:sirenState', lastNetId, false, 0, false)
                TriggerServerEvent('sb_police:server:hornState', lastNetId, false)
            end
            lastVehicle = nil
            lastNetId = nil
        end

        -- Track current vehicle
        if vehicle and DoesEntityExist(vehicle) and IsPlayerDriver(vehicle) then
            if vehicle ~= lastVehicle then
                lastVehicle = vehicle
                lastNetId = GetVehicleNetId(vehicle)

                -- Mute native siren when entering emergency vehicle
                if IsEmergencyVehicle(vehicle) then
                    SetVehicleHasMutedSirens(vehicle, true)
                end
            end
        end
    end
end)

-- Cleanup stale states (vehicle destroyed)
CreateThread(function()
    while true do
        Wait(5000)

        for netId, state in pairs(sirenStates) do
            local vehicle = NetToVeh(netId)
            if not DoesEntityExist(vehicle) then
                -- Cleanup sounds via NUI
                StopAllSounds()
                sirenStates[netId] = nil
            end
        end
    end
end)

-- =============================================
-- Commands for Manual Control
-- =============================================

RegisterCommand('sirenoff', function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not DoesEntityExist(vehicle) then return end

    local netId = GetVehicleNetId(vehicle)
    if netId then
        SetVehicleSiren(vehicle, false)
        TriggerServerEvent('sb_police:server:sirenState', netId, false, 0, false)
        TriggerServerEvent('sb_police:server:hornState', netId, false)
        exports['sb_notify']:Notify('Sirens OFF', 'info', 2000)
    end
end, false)

-- Debug command to check siren state
RegisterCommand('sirenstate', function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if not DoesEntityExist(vehicle) then
        print('[sb_police:sirens] Not in vehicle')
        return
    end

    local netId = GetVehicleNetId(vehicle)
    local state = sirenStates[netId] or {}

    print(('[sb_police:sirens] Vehicle NetID: %s'):format(tostring(netId)))
    print(('[sb_police:sirens] Is Emergency: %s'):format(tostring(IsEmergencyVehicle(vehicle))))
    print(('[sb_police:sirens] Lights On: %s'):format(tostring(IsVehicleSirenOn(vehicle))))
    print(('[sb_police:sirens] Sound Mode: %s'):format(Config.Sirens.SoundMode))
    print(('[sb_police:sirens] Siren Tone: %s'):format(tostring(state.sirenTone or 0)))
    print(('[sb_police:sirens] Active Siren ID: %s'):format(tostring(activeSirenSoundId)))
    print(('[sb_police:sirens] Horn On: %s'):format(tostring(state.hornOn or false)))
end, false)

-- Test command to manually trigger siren cycle
RegisterCommand('testsiren', function()
    print('[sb_police:sirens] ^3testsiren command^7')
    CycleSiren()
end, false)

-- =============================================
-- Initialization
-- =============================================

CreateThread(function()
    -- Keep native siren muted so we control the sounds
    while true do
        Wait(0)

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if DoesEntityExist(vehicle) and IsEmergencyVehicle(vehicle) then
            -- Keep siren muted (we play our own sounds)
            SetVehicleHasMutedSirens(vehicle, true)
            -- Horn control (86) disabled in horn thread to prevent native light toggles
        end
    end
end)

print('[sb_police:sirens] ^2Siren system initialized^7')
print(('[sb_police:sirens] ^3Sound Mode: %s^7'):format(Config.Sirens.SoundMode))
print('[sb_police:sirens] ^3Controls: L = Lights, ; = Siren, E = Air Horn (hold)^7')
print('[sb_police:sirens] ^3Debug: /testsiren, /sirenstate^7')
