--[[
    Everyday Chaos RP - Drug Effects (Client)
    Author: Salah Eddine Boussettah

    Handles: drug consumption effects — screen effects, movement clipsets,
    speed multipliers, prop attachment, health/armor boosts, stress relief.
    Includes stacking prevention, death cleanup, and auto-clear timers.
]]

-- State
local activeEffect = nil       -- { drugName, endTime, prop, clipset, screenEffect }
local effectThread = nil
local originalSpeed = nil

-- ========================================================================
-- HELPERS
-- ========================================================================

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

local function AttachProp(ped, propData)
    if not propData or not propData.model then return nil end

    local hash = GetHashKey(propData.model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then return nil end
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, propData.bone),
        propData.pos.x, propData.pos.y, propData.pos.z,
        propData.rot.x, propData.rot.y, propData.rot.z,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function DeletePropSafe(prop)
    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
    end
end

local function CleanupEffect()
    local ped = PlayerPedId()

    if activeEffect then
        -- Remove screen effect
        if activeEffect.screenEffect then
            StopScreenEffect(activeEffect.screenEffect)
        end

        -- Remove movement clipset
        if activeEffect.clipset then
            ResetPedMovementClipset(ped, 0.3)
        end

        -- Reset speed
        if originalSpeed then
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            originalSpeed = nil
        end

        -- Delete prop (if still attached)
        DeletePropSafe(activeEffect.prop)

        -- Clear any lingering animation
        ClearPedTasks(ped)

        activeEffect = nil
    end

    -- Always ensure clean state
    ClearTimecycleModifier()
end

-- ========================================================================
-- CONSUME DRUG (triggered by server after item removal)
-- ========================================================================

RegisterNetEvent('sb_drugs:client:useConsumable', function(drugName)
    local effectConfig = Config.DrugEffects[drugName]
    if not effectConfig then
        exports['sb_notify']:Notify('Unknown drug effect', 'error', 3000)
        return
    end

    -- Stacking prevention
    if activeEffect and activeEffect.drugName == drugName then
        exports['sb_notify']:Notify('Already under this effect', 'error', 3000)
        return
    end

    -- Clean up previous effect if different drug
    if activeEffect then
        CleanupEffect()
    end

    local ped = PlayerPedId()

    -- Attach prop BEFORE animation (so it's visible during the anim)
    local attachedProp = nil
    if effectConfig.prop then
        attachedProp = AttachProp(ped, effectConfig.prop)
    end

    -- Play use animation
    if effectConfig.anim and effectConfig.anim.dict then
        if LoadAnimDict(effectConfig.anim.dict) then
            TaskPlayAnim(ped, effectConfig.anim.dict, effectConfig.anim.clip, 8.0, -8.0, 3000, 49, 0, false, false, false)
            Wait(5000) -- longer wait so smoking/injection feels natural
            ClearPedTasks(ped)
        end
    end

    -- For syringes: remove prop after the injection animation
    if attachedProp and effectConfig.propRemoveAfterAnim then
        DeletePropSafe(attachedProp)
        attachedProp = nil
    end

    -- Apply effect
    activeEffect = {
        drugName = drugName,
        endTime = GetGameTimer() + (effectConfig.duration * 1000),
        screenEffect = effectConfig.screenEffect,
        clipset = effectConfig.movementClipset,
        prop = attachedProp, -- nil for syringes (already deleted), entity for joints
    }

    -- Screen effect
    if effectConfig.screenEffect then
        StartScreenEffect(effectConfig.screenEffect, 0, true)
    end

    -- Movement clipset
    if effectConfig.movementClipset then
        RequestClipSet(effectConfig.movementClipset)
        local timeout = GetGameTimer() + 3000
        while not HasClipSetLoaded(effectConfig.movementClipset) do
            Wait(10)
            if GetGameTimer() > timeout then break end
        end
        SetPedMovementClipset(ped, effectConfig.movementClipset, 0.3)
    end

    -- Speed multiplier
    if effectConfig.speedMultiplier and effectConfig.speedMultiplier ~= 1.0 then
        originalSpeed = 1.0
        SetRunSprintMultiplierForPlayer(PlayerId(), effectConfig.speedMultiplier)
    end

    -- Health boost
    if effectConfig.healthBoost and effectConfig.healthBoost > 0 then
        local health = GetEntityHealth(ped)
        local maxHealth = GetEntityMaxHealth(ped)
        SetEntityHealth(ped, math.min(health + effectConfig.healthBoost, maxHealth))
    end

    -- Armor boost
    if effectConfig.armorBoost and effectConfig.armorBoost > 0 then
        local armor = GetPedArmour(ped)
        SetPedArmour(ped, math.min(armor + effectConfig.armorBoost, 100))
    end

    -- Stress relief (reduce stress metadata if available)
    if effectConfig.stressRelief and effectConfig.stressRelief > 0 then
        TriggerServerEvent('sb_drugs:server:stressRelief', effectConfig.stressRelief)
    end

    exports['sb_notify']:Notify('Used: ' .. effectConfig.label, 'success', 3000)

    -- Start effect timer thread
    if effectThread then return end -- already running
    effectThread = true

    CreateThread(function()
        while activeEffect do
            Wait(500)

            -- Capture locally to prevent nil race condition
            local effect = activeEffect
            if not effect then break end

            -- Check if effect expired
            if GetGameTimer() >= effect.endTime then
                CleanupEffect()
                exports['sb_notify']:Notify('Drug effect wore off', 'info', 3000)
                break
            end

            -- Check if player died
            if IsEntityDead(PlayerPedId()) then
                CleanupEffect()
                break
            end
        end
        effectThread = nil
    end)
end)

-- ========================================================================
-- STRESS RELIEF (server handler)
-- ========================================================================
-- Note: This event is handled on server side to modify player metadata
-- If no stress system exists, it's a no-op

-- ========================================================================
-- DEATH / RESOURCE CLEANUP
-- ========================================================================

CreateThread(function()
    while true do
        Wait(2000)
        if activeEffect and IsEntityDead(PlayerPedId()) then
            CleanupEffect()
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CleanupEffect()
end)
