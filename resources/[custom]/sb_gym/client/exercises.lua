--[[
    Everyday Chaos RP - Exercise System
    Author: Salah Eddine Boussettah

    Handles equipment workouts and free exercises with animations
]]

local isExercising = false
local lastWorkoutTime = 0

-- ============================================================================
-- EXERCISE HELPERS
-- ============================================================================

-- Check if player can start a workout
local function CanStartWorkout()
    if isExercising then
        exports['sb_notify']:Notify('You are already exercising!', 'warning', 3000)
        return false
    end

    local now = GetGameTimer()
    if now - lastWorkoutTime < Config.WorkoutCooldown then
        exports['sb_notify']:Notify('Take a short break between exercises!', 'warning', 3000)
        return false
    end

    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        exports['sb_notify']:Notify('You cannot exercise while dead!', 'error', 3000)
        return false
    end

    if IsPedInAnyVehicle(ped, false) then
        exports['sb_notify']:Notify('Exit the vehicle first!', 'error', 3000)
        return false
    end

    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
        exports['sb_notify']:Notify('You cannot exercise while swimming!', 'error', 3000)
        return false
    end

    return true
end

-- Play exercise animation with progress bar
local function DoExercise(exerciseData, exerciseId, isEquipment)
    if not CanStartWorkout() then return end

    isExercising = true

    -- Request animation dictionary
    local animDict = exerciseData.animation.dict
    local animName = exerciseData.animation.anim
    local animFlag = exerciseData.animation.flag or 1

    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 2000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasAnimDictLoaded(animDict) then
        exports['sb_notify']:Notify('Animation failed to load', 'error', 3000)
        isExercising = false
        return
    end

    local ped = PlayerPedId()

    -- Start animation
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, animFlag, 0, false, false, false)

    -- Start progress bar
    local success = exports['sb_progressbar']:Start({
        label = exerciseData.label,
        duration = exerciseData.duration,
        icon = 'dumbbell',
        canCancel = true,
        disableMovement = true,
        disableCombat = true,
        onComplete = function()
            -- Stop animation
            StopAnimTask(ped, animDict, animName, 1.0)
            RemoveAnimDict(animDict)

            -- Request skill gain from server
            TriggerServerEvent('sb_gym:server:completeWorkout', exerciseId, isEquipment)

            isExercising = false
            lastWorkoutTime = GetGameTimer()
        end,
        onCancel = function()
            -- Stop animation
            StopAnimTask(ped, animDict, animName, 1.0)
            RemoveAnimDict(animDict)

            exports['sb_notify']:Notify('Exercise cancelled', 'warning', 3000)
            isExercising = false
        end
    })

    if not success then
        StopAnimTask(ped, animDict, animName, 1.0)
        RemoveAnimDict(animDict)
        isExercising = false
    end
end

-- ============================================================================
-- EQUIPMENT WORKOUT (via sb_target)
-- ============================================================================

function StartEquipmentWorkout(entity, equipmentId)
    local equipment = Config.Equipment[equipmentId]
    if not equipment then
        exports['sb_notify']:Notify('Unknown equipment', 'error', 3000)
        return
    end

    DoExercise(equipment, equipmentId, true)
end

-- ============================================================================
-- FREE EXERCISE (via menu)
-- ============================================================================

function StartFreeExercise(exerciseId)
    local exercise = Config.FreeExercises[exerciseId]
    if not exercise then
        exports['sb_notify']:Notify('Unknown exercise', 'error', 3000)
        return
    end

    DoExercise(exercise, exerciseId, false)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('StartEquipmentWorkout', StartEquipmentWorkout)
exports('StartFreeExercise', StartFreeExercise)
exports('IsExercising', function() return isExercising end)
