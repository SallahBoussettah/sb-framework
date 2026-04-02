--[[
    Everyday Chaos RP - Death System (Client)
    Author: Salah Eddine Boussettah

    Flow:
    1. Player health reaches 0 -> enters downed state
    2. NUI death screen with vignette + timer
    3. Timer expires -> "Respawn" button appears ($500 bill)
    4. Player clicks Respawn -> pays bill and spawns at hospital
    5. "Call Emergency" -> alert EMS players (future)
    6. Admin /revive bypasses everything
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- STATE
-- ============================================================================

local isDead = false
local isRespawning = false
local deathTime = 0
local killerName = nil

-- ============================================================================
-- DEATH DETECTION
-- ============================================================================

CreateThread(function()
    while true do
        Wait(500)

        if not SB.Functions.IsLoggedIn() then goto continue end

        local ped = PlayerPedId()

        if IsEntityDead(ped) and not isDead and not isRespawning then
            OnPlayerDeath()
        end

        ::continue::
    end
end)

-- ============================================================================
-- RECONNECT WHILE DEAD
-- ============================================================================

RegisterNetEvent('SB:Client:OnPlayerLoaded', function(PlayerData)
    if PlayerData and PlayerData.metadata and PlayerData.metadata.isdead then
        Wait(2000)

        isDead = true
        deathTime = GetGameTimer()

        -- Apply visual
        SetTimecycleModifier(Config.DeathTimecycle)
        SetTimecycleModifierStrength(Config.DeathTimecycleStrength)

        -- Show NUI immediately with 0 timer (can respawn right away)
        ShowDeathUI(Config.Text.Unknown, 0)

        -- Start death control loop
        CreateThread(DeathControlLoop)

        SB.Functions.Notify("You were downed before disconnecting.", "warning", 5000)
    end
end)

-- ============================================================================
-- DEATH HANDLER
-- ============================================================================

function OnPlayerDeath()
    if isDead then return end

    isDead = true
    isRespawning = false
    deathTime = GetGameTimer()

    local ped = PlayerPedId()

    -- Check if player was in a vehicle - auto impound destroyed vehicles
    local vehicle = GetVehiclePedIsIn(ped, true) -- true = include last vehicle
    if vehicle and vehicle ~= 0 then
        local isOwned = Entity(vehicle).state.sb_owned
        if isOwned then
            local engineHealth = GetVehicleEngineHealth(vehicle)
            local isDestroyed = engineHealth < 100

            if isDestroyed then
                -- Get vehicle data before impounding
                local plate = GetVehicleNumberPlateText(vehicle)
                local cleanPlate = plate:gsub('%s+', ''):upper()
                local props = nil

                -- Try to get props if sb_garage is available
                if GetResourceState('sb_garage') == 'started' then
                    props = exports['sb_garage']:GetVehicleProperties(vehicle)
                end

                -- Send to impound as destroyed
                TriggerServerEvent('sb_impound:server:confirmSendToImpound', cleanPlate, props, true)

                -- Delete the destroyed vehicle
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)

                -- Notify player (delayed so they see it after death screen)
                SetTimeout(3000, function()
                    exports['sb_notify']:Notify('Your destroyed vehicle was sent to impound', 'warning', 6000)
                end)
            end
        end
    end

    -- Identify killer
    killerName = GetKillerName(ped)

    -- Notify server (sets metadata.isdead = true)
    TriggerServerEvent('sb_deaths:server:onDeath')

    -- Apply death visual
    SetTimecycleModifier(Config.DeathTimecycle)
    SetTimecycleModifierStrength(Config.DeathTimecycleStrength)

    -- Show NUI death screen
    ShowDeathUI(killerName, Config.BleedoutTime)

    -- Start death control loop
    CreateThread(DeathControlLoop)
end

-- ============================================================================
-- KILLER IDENTIFICATION
-- ============================================================================

function GetKillerName(ped)
    local killerPed = GetPedSourceOfDeath(ped)

    if killerPed == ped then
        return Config.Text.Suicide
    end

    -- Check if killer is in a vehicle
    if IsEntityAVehicle(killerPed) then
        local driver = GetPedInVehicleSeat(killerPed, -1)
        if driver and IsPedAPlayer(driver) then
            killerPed = driver
        else
            return Config.Text.Unknown
        end
    end

    -- Check if killer is a player
    local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
    if killerPlayerId and killerPlayerId ~= -1 then
        -- Request RP name from server
        TriggerServerEvent('sb_deaths:server:getKillerName', GetPlayerServerId(killerPlayerId))
        return nil -- Will be updated via event
    end

    return Config.Text.Unknown
end

-- Receive killer RP name from server
RegisterNetEvent('sb_deaths:client:setKillerName', function(name)
    SendNUIMessage({
        action = 'setKiller',
        killer = name
    })
end)

-- ============================================================================
-- DEATH CONTROL LOOP (ragdoll, disable controls)
-- ============================================================================

function DeathControlLoop()
    while isDead do
        Wait(0)

        local ped = PlayerPedId()

        -- Keep ragdoll
        if not IsPedRagdoll(ped) and not isRespawning then
            SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
        end

        -- Disable controls
        for _, control in ipairs(Config.DisabledControls) do
            DisableControlAction(0, control, true)
        end
    end
end

-- ============================================================================
-- NUI COMMUNICATION
-- ============================================================================

function ShowDeathUI(killer, timer)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'show',
        killer = killer or Config.Text.Unknown,
        timer = timer,
        texts = Config.Text
    })
end

function HideDeathUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

-- Player clicks "Call Emergency"
RegisterNUICallback('callEmergency', function(data, cb)
    cb('ok')
    -- Notify nearby EMS players (future: integrate with EMS job)
    TriggerServerEvent('sb_deaths:server:callEmergency')
    SB.Functions.Notify("Emergency call sent. Wait for EMS.", "info", 5000)
end)

-- Timer expired (NUI shows respawn button)
RegisterNUICallback('timerExpired', function(data, cb)
    cb('ok')
end)

-- Player clicked Respawn button
RegisterNUICallback('respawn', function(data, cb)
    cb('ok')
    RespawnPlayer()
end)

-- ============================================================================
-- RESPAWN
-- ============================================================================

function RespawnPlayer()
    if not isDead or isRespawning then return end

    isRespawning = true

    -- Hide NUI
    HideDeathUI()

    local ped = PlayerPedId()
    local pos = Config.RespawnCoords

    -- Fade out
    DoScreenFadeOut(1000)
    Wait(1500)

    -- Clear death visual
    ClearTimecycleModifier()

    -- Resurrect at hospital
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.w, true, false)

    ped = PlayerPedId()
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, true)
    SetEntityHeading(ped, pos.w)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetPlayerInvincible(PlayerId(), false)

    -- Reset state
    isDead = false
    isRespawning = false
    killerName = nil

    -- Fade in
    Wait(500)
    DoScreenFadeIn(1000)

    -- Server handles bill deduction and metadata
    TriggerServerEvent('sb_deaths:server:onRespawn')
end

-- ============================================================================
-- REVIVE (Admin command or EMS)
-- ============================================================================

RegisterNetEvent('SB:Client:Revive', function()
    local ped = PlayerPedId()

    -- Reset state
    isDead = false
    isRespawning = false
    killerName = nil

    -- Hide NUI
    HideDeathUI()

    -- Clear visual
    ClearTimecycleModifier()

    -- Resurrect in place
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)

    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedTasksImmediately(ped)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)

    if not IsScreenFadedIn() then
        DoScreenFadeIn(500)
    end

    SB.Functions.Notify("You have been revived!", "success", 5000)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsPlayerDead', function()
    return isDead
end)

exports('RevivePlayer', function()
    TriggerEvent('SB:Client:Revive')
end)
