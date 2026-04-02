--[[
    Everyday Chaos RP - Gym Main Client
    Author: Salah Eddine Boussettah

    Handles blips, sb_target setup, NUI, protein buff, and keybinds
]]

local SBCore = nil
local isUIOpen = false
local hasProteinBuff = false
local proteinBuffEndTime = 0

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Wait for core
    while not SBCore do
        SBCore = exports['sb_core']:GetCoreObject()
        Wait(500)
    end

    -- Wait a bit for player to be ready
    Wait(2000)

    -- Create gym blips
    for _, gym in ipairs(Config.GymLocations) do
        local blip = AddBlipForCoord(gym.coords.x, gym.coords.y, gym.coords.z)
        SetBlipSprite(blip, Config.BlipSprite)
        SetBlipScale(blip, Config.BlipScale)
        SetBlipColour(blip, Config.BlipColor)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(gym.label)
        EndTextCommandSetBlipName(blip)
    end

    -- Setup sb_target for gym equipment
    SetupEquipmentTargets()
end)

-- ============================================================================
-- SB_TARGET SETUP
-- ============================================================================

function SetupEquipmentTargets()
    -- Collect all equipment models
    local models = {}
    for model, _ in pairs(Config.Equipment) do
        models[#models + 1] = model
    end

    -- Add target for each equipment type
    for model, equipment in pairs(Config.Equipment) do
        exports['sb_target']:AddTargetModel(model, {
            {
                name = 'gym_use_' .. model,
                label = equipment.label,
                icon = 'fa-dumbbell',
                distance = 2.0,
                action = function(entity)
                    StartEquipmentWorkout(entity, model)
                end,
                canInteract = function(entity)
                    return not exports['sb_gym']:IsExercising()
                end
            }
        })
    end
end

-- ============================================================================
-- KEYBINDS & COMMANDS
-- ============================================================================

-- Free exercise menu command
RegisterCommand('sb_gym_free', function()
    -- Don't open menu if in vehicle (G is used for engine toggle)
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        return
    end

    if isUIOpen then
        CloseUI()
    elseif not exports['sb_gym']:IsExercising() then
        OpenExerciseMenu()
    end
end, false)

-- Skills panel command
RegisterCommand('sb_gym_skills', function()
    -- Don't open if in vehicle (K is used for K9 in police vehicles)
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        return
    end

    -- Don't open if K9 is deployed (sb_police uses K for K9 menu)
    local success, k9Deployed = pcall(function()
        return exports['sb_police']:HasK9Deployed()
    end)
    if success and k9Deployed then
        return
    end

    if isUIOpen then
        CloseUI()
    else
        OpenSkillsPanel()
    end
end, false)

-- Register keybinds
RegisterKeyMapping('sb_gym_free', 'Open Exercise Menu', 'keyboard', Config.ExerciseKey)
RegisterKeyMapping('sb_gym_skills', 'View Gym Skills', 'keyboard', Config.SkillsKey)

-- ============================================================================
-- NUI MANAGEMENT
-- ============================================================================

function OpenExerciseMenu()
    isUIOpen = true
    SetNuiFocus(true, true)

    -- Build exercise list from config
    local exercises = {}
    for id, ex in pairs(Config.FreeExercises) do
        exercises[#exercises + 1] = {
            id = id,
            label = ex.label,
            skill = ex.skill,
            duration = ex.duration
        }
    end

    SendNUIMessage({
        action = 'openExerciseMenu',
        exercises = exercises
    })
end

function CloseExerciseMenu()
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function OpenSkillsPanel()
    isUIOpen = true
    SetNuiFocus(true, true)

    local skills = exports['sb_gym']:GetAllSkills()

    SendNUIMessage({
        action = 'openSkillsPanel',
        skills = skills,
        hasBuff = hasProteinBuff,
        buffTimeLeft = hasProteinBuff and math.max(0, proteinBuffEndTime - GetGameTimer()) or 0
    })
end

function CloseUI()
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(_, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('startExercise', function(data, cb)
    CloseExerciseMenu()

    -- Small delay before starting exercise
    SetTimeout(100, function()
        StartFreeExercise(data.exerciseId)
    end)

    cb('ok')
end)

-- ============================================================================
-- PROTEIN BUFF
-- ============================================================================

RegisterNetEvent('sb_gym:client:proteinBuff', function(duration)
    hasProteinBuff = true
    proteinBuffEndTime = GetGameTimer() + duration

    exports['sb_notify']:Notify('Protein Buff Active! 2x XP for 5 minutes!', 'success', 5000)

    -- Auto-expire buff
    SetTimeout(duration, function()
        if hasProteinBuff then
            hasProteinBuff = false
            proteinBuffEndTime = 0
            exports['sb_notify']:Notify('Protein buff has expired', 'info', 3000)
        end
    end)
end)

-- Export for checking buff status
exports('HasProteinBuff', function()
    return hasProteinBuff
end)

-- ============================================================================
-- EVENTS
-- ============================================================================

RegisterNetEvent('sb_gym:client:workoutComplete', function(skillName, gained, newValue)
    local skillLabel = skillName:gsub("^%l", string.upper)  -- Capitalize first letter
    exports['sb_notify']:Notify(skillLabel .. ' +' .. string.format('%.1f', gained) .. ' (Now: ' .. math.floor(newValue) .. ')', 'success', 4000)
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if isUIOpen then
            SetNuiFocus(false, false)
        end

        -- Remove all equipment targets
        for model, _ in pairs(Config.Equipment) do
            exports['sb_target']:RemoveTargetModel(model, 'gym_use_' .. model)
        end
    end
end)
