--[[
    Everyday Chaos RP - Metabolism Client
    Author: Salah Eddine Boussettah

    Handles damage effects when hunger/thirst is critically low.
    Handles stress detection (shooting, getting shot, speeding, police chase, low health, falling).
    Provides stress-based screen shake and stamina multiplier.
    HUD display is handled by sb_hud reading PlayerData.metadata.
]]

local SBCore = exports['sb_core']:GetCoreObject()
local isDamaging = false

-- Stress tracking
local currentStress = 0
local lastShootCheck = 0
local lastHitCheck = 0
local lastSpeedCheck = 0
local lastChaseCheck = 0
local lastHealthCheck = 0
local lastNeedsCheck = 0
local lastFallCheck = 0
local wasFalling = false
local lastFallHealth = 0

-- Refresh core object if sb_core restarts
AddEventHandler('onResourceStart', function(resource)
    if resource == 'sb_core' then
        SBCore = exports['sb_core']:GetCoreObject()
    end
end)

-- ========================================================================
-- DAMAGE TICK (triggered by server when values are critical)
-- ========================================================================
RegisterNetEvent('sb_metabolism:client:startDamage', function(hunger, thirst)
    if isDamaging then return end
    isDamaging = true

    CreateThread(function()
        while isDamaging do
            Wait(Config.DamageInterval)

            local PlayerData = SBCore.Functions.GetPlayerData()
            if not PlayerData or not PlayerData.metadata then
                isDamaging = false
                break
            end

            local h = PlayerData.metadata.hunger or 100
            local t = PlayerData.metadata.thirst or 100

            -- Stop if values recovered
            if h > Config.DamageThreshold and t > Config.DamageThreshold then
                isDamaging = false
                break
            end

            -- Apply damage
            local ped = PlayerPedId()
            local currentHealth = GetEntityHealth(ped)

            if h <= Config.DamageThreshold then
                SetEntityHealth(ped, math.max(0, currentHealth - Config.DamageAmount))
            end
            if t <= Config.DamageThreshold then
                SetEntityHealth(ped, math.max(0, currentHealth - Config.DamageAmount))
            end
        end
    end)
end)

-- ========================================================================
-- STRESS DETECTION LOOP
-- ========================================================================
CreateThread(function()
    while not SBCore.Functions.IsLoggedIn() do Wait(500) end

    while true do
        Wait(200) -- Base tick rate (matches shooting interval)

        local PlayerData = SBCore.Functions.GetPlayerData()
        if not PlayerData or not PlayerData.metadata then goto continue end

        currentStress = PlayerData.metadata.stress or 0
        local ped = PlayerPedId()
        local now = GetGameTimer()

        -- SHOOTING: +3 per shot
        if now - lastShootCheck >= Config.StressCheckIntervals.shooting then
            if IsPedShooting(ped) then
                TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.shooting)
                lastShootCheck = now
            end
        end

        -- GETTING SHOT: +5 per hit
        if now - lastHitCheck >= Config.StressCheckIntervals.gettingShot then
            if HasEntityBeenDamagedByAnyPed(ped) then
                TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.gettingShot)
                ClearEntityLastDamageEntity(ped)
                lastHitCheck = now
            end
        end

        -- SPEEDING: +0.5 per tick when >120 km/h
        if now - lastSpeedCheck >= Config.StressCheckIntervals.speeding then
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                local speed = GetEntitySpeed(vehicle) * 3.6 -- m/s to km/h
                if speed > 120 then
                    TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.speeding)
                end
            end
            lastSpeedCheck = now
        end

        -- POLICE CHASE: +2 per tick when wanted
        if now - lastChaseCheck >= Config.StressCheckIntervals.policeChase then
            if GetPlayerWantedLevel(PlayerId()) > 0 then
                TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.policeChase)
            end
            lastChaseCheck = now
        end

        -- LOW HEALTH: +1 per tick when health <25%
        if now - lastHealthCheck >= Config.StressCheckIntervals.lowHealth then
            local health = GetEntityHealth(ped) - 100
            if health < 25 and health > 0 then
                TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.lowHealth)
            end
            lastHealthCheck = now
        end

        -- CRITICAL NEEDS: +0.5 per tick when hunger/thirst <10%
        if now - lastNeedsCheck >= Config.StressCheckIntervals.criticalNeeds then
            local hunger = PlayerData.metadata.hunger or 100
            local thirst = PlayerData.metadata.thirst or 100
            if hunger < 10 or thirst < 10 then
                TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.criticalNeeds)
            end
            lastNeedsCheck = now
        end

        -- FALLING: +4 per fall with damage
        if now - lastFallCheck >= Config.StressCheckIntervals.falling then
            local isFalling = IsPedFalling(ped) or GetEntityHeightAboveGround(ped) > 5.0
            if isFalling and not wasFalling then
                lastFallHealth = GetEntityHealth(ped)
            elseif not isFalling and wasFalling then
                local healthAfter = GetEntityHealth(ped)
                if healthAfter < lastFallHealth then
                    TriggerServerEvent('sb_metabolism:server:addStress', Config.StressGain.falling)
                end
            end
            wasFalling = isFalling
            lastFallCheck = now
        end

        ::continue::
    end
end)

-- ========================================================================
-- STRESS EFFECTS (screen shake when stress > threshold)
-- ========================================================================
CreateThread(function()
    while not SBCore.Functions.IsLoggedIn() do Wait(500) end

    while true do
        Wait(2000) -- Check every 2 seconds

        if currentStress >= Config.StressEffectThreshold then
            local intensity = Config.StressShakeIntensity
            if currentStress >= Config.StressHighThreshold then
                intensity = Config.StressShakeHighIntensity
            end
            ShakeGameplayCam('HAND_SHAKE', intensity)
        else
            StopGameplayCamShaking(true)
        end
    end
end)

-- ========================================================================
-- EXPORTS
-- ========================================================================

-- Returns the stamina multiplier based on current stress level
-- Used by sb_hud to increase stamina drain when stressed
exports('GetStressStaminaMultiplier', function()
    if currentStress >= Config.StressEffectThreshold then
        return Config.StressStaminaMultiplier
    end
    return 1.0
end)

exports('GetStress', function()
    return currentStress
end)

-- ========================================================================
-- CLEANUP
-- ========================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    isDamaging = false
    StopGameplayCamShaking(true)
end)

print('[sb_metabolism] Client-side loaded successfully')
