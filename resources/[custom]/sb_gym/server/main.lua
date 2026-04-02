--[[
    Everyday Chaos RP - Gym Server
    Author: Salah Eddine Boussettah

    Handles skill persistence, validation, and protein buff
]]

local SBCore = nil
local PlayerBuffs = {}  -- [source] = { hasProtein = bool, expireTime = timestamp }

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    SBCore = exports['sb_core']:GetCoreObject()
end)

-- ============================================================================
-- SKILL HELPERS
-- ============================================================================

-- Get player's gym metadata
local function GetPlayerGymData(source)
    local player = SBCore.Functions.GetPlayer(source)
    if not player then return nil end

    local gym = player.PlayerData.metadata.gym
    if not gym then
        -- Initialize with defaults
        gym = {
            strength = Config.DefaultSkills.strength,
            stamina = Config.DefaultSkills.stamina,
            lung = Config.DefaultSkills.lung,
            lastWorkout = 0
        }
        player.Functions.SetMetaData('gym', gym)
    end

    return gym, player
end

-- Save gym data to player metadata
local function SaveGymData(player, gym)
    player.Functions.SetMetaData('gym', gym)
end

-- Calculate skill gain with buff multiplier
local function CalculateGain(source, baseGain)
    local multiplier = 1.0

    -- Check protein buff
    if PlayerBuffs[source] and PlayerBuffs[source].hasProtein then
        if GetGameTimer() < PlayerBuffs[source].expireTime then
            multiplier = Config.ProteinBuffMultiplier
        else
            -- Buff expired
            PlayerBuffs[source] = nil
        end
    end

    return baseGain * multiplier
end

-- ============================================================================
-- WORKOUT COMPLETION
-- ============================================================================

RegisterNetEvent('sb_gym:server:completeWorkout', function(exerciseId, isEquipment)
    local source = source
    local gym, player = GetPlayerGymData(source)
    if not gym or not player then return end

    -- Get exercise data
    local exerciseData
    if isEquipment then
        exerciseData = Config.Equipment[exerciseId]
    else
        exerciseData = Config.FreeExercises[exerciseId]
    end

    if not exerciseData then
        print('[sb_gym] Invalid exercise ID: ' .. tostring(exerciseId))
        return
    end

    local skillName = exerciseData.skill
    local baseGain = exerciseData.gain
    local gain = CalculateGain(source, baseGain)

    -- Apply gain
    local currentValue = gym[skillName] or Config.DefaultSkills[skillName]
    local newValue = math.min(Config.MaxSkillLevel, currentValue + gain)

    gym[skillName] = newValue
    gym.lastWorkout = os.time()

    -- Save to metadata
    SaveGymData(player, gym)

    -- Notify client
    TriggerClientEvent('sb_gym:client:skillGain', source, skillName, newValue)
    TriggerClientEvent('sb_gym:client:workoutComplete', source, skillName, gain, newValue)
end)

-- ============================================================================
-- PASSIVE GAINS
-- ============================================================================

RegisterNetEvent('sb_gym:server:passiveGain', function(activityType)
    local source = source
    local gym, player = GetPlayerGymData(source)
    if not gym or not player then return end

    local passiveData = Config.PassiveGains[activityType]
    if not passiveData then return end

    local skillName = passiveData.skill
    local baseGain = passiveData.amount
    local gain = CalculateGain(source, baseGain)

    -- Apply gain
    local currentValue = gym[skillName] or Config.DefaultSkills[skillName]
    local newValue = math.min(Config.MaxSkillLevel, currentValue + gain)

    gym[skillName] = newValue

    -- Save to metadata (silently, no notification for passive gains)
    SaveGymData(player, gym)

    -- Update client
    TriggerClientEvent('sb_gym:client:skillGain', source, skillName, newValue)
end)

-- ============================================================================
-- PROTEIN BUFF
-- ============================================================================

-- Listen for item usage from sb_inventory
AddEventHandler('sb_inventory:server:itemUsed', function(source, itemName, amount, metadata, category)
    if itemName ~= Config.ProteinItem then return end

    -- Check if already buffed
    if PlayerBuffs[source] and PlayerBuffs[source].hasProtein then
        local timeLeft = PlayerBuffs[source].expireTime - GetGameTimer()
        if timeLeft > 0 then
            local minutes = math.ceil(timeLeft / 60000)
            TriggerClientEvent('SB:Client:Notify', source, 'Protein buff already active! ' .. minutes .. ' min left', 'warning', 3000)
            return
        end
    end

    -- Apply buff (item is already consumed by sb_inventory)
    PlayerBuffs[source] = {
        hasProtein = true,
        expireTime = GetGameTimer() + Config.ProteinBuffDuration
    }

    -- Notify client
    TriggerClientEvent('sb_gym:client:proteinBuff', source, Config.ProteinBuffDuration)
end)

-- ============================================================================
-- PLAYER EVENTS
-- ============================================================================

-- Clear buff on disconnect
AddEventHandler('playerDropped', function()
    local source = source
    PlayerBuffs[source] = nil
end)

-- Send skills to client on load
RegisterNetEvent('SB:Server:PlayerLoaded', function()
    local source = source
    local gym, _ = GetPlayerGymData(source)
    if gym then
        TriggerClientEvent('sb_gym:client:updateSkills', source, {
            strength = gym.strength,
            stamina = gym.stamina,
            lung = gym.lung
        })
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetPlayerSkill', function(source, skillName)
    local gym, _ = GetPlayerGymData(source)
    if gym then
        return gym[skillName] or 0
    end
    return 0
end)

exports('GetPlayerSkills', function(source)
    local gym, _ = GetPlayerGymData(source)
    if gym then
        return {
            strength = gym.strength,
            stamina = gym.stamina,
            lung = gym.lung
        }
    end
    return nil
end)

exports('SetPlayerSkill', function(source, skillName, value)
    local gym, player = GetPlayerGymData(source)
    if not gym or not player then return false end

    if gym[skillName] ~= nil then
        gym[skillName] = math.max(Config.MinSkillLevel, math.min(Config.MaxSkillLevel, value))
        SaveGymData(player, gym)
        TriggerClientEvent('sb_gym:client:skillGain', source, skillName, gym[skillName])
        return true
    end
    return false
end)

exports('HasProteinBuff', function(source)
    if PlayerBuffs[source] and PlayerBuffs[source].hasProtein then
        return GetGameTimer() < PlayerBuffs[source].expireTime
    end
    return false
end)

-- ============================================================================
-- COMMANDS (Admin/Debug)
-- ============================================================================

RegisterCommand('setskill', function(source, args, rawCommand)
    if source == 0 then return end  -- Console only

    local targetId = tonumber(args[1])
    local skillName = args[2]
    local value = tonumber(args[3])

    if not targetId or not skillName or not value then
        TriggerClientEvent('SB:Client:Notify', source, 'Usage: /setskill [id] [strength/stamina/lung] [value]', 'error', 3000)
        return
    end

    local success = exports['sb_gym']:SetPlayerSkill(targetId, skillName, value)
    if success then
        TriggerClientEvent('SB:Client:Notify', source, 'Set ' .. skillName .. ' to ' .. value .. ' for player ' .. targetId, 'success', 3000)
    else
        TriggerClientEvent('SB:Client:Notify', source, 'Failed to set skill', 'error', 3000)
    end
end, true)  -- Restricted to admins

RegisterCommand('givebuff', function(source, args, rawCommand)
    if source == 0 then return end

    local targetId = tonumber(args[1]) or source

    PlayerBuffs[targetId] = {
        hasProtein = true,
        expireTime = GetGameTimer() + Config.ProteinBuffDuration
    }

    TriggerClientEvent('sb_gym:client:proteinBuff', targetId, Config.ProteinBuffDuration)
    TriggerClientEvent('SB:Client:Notify', source, 'Gave protein buff to player ' .. targetId, 'success', 3000)
end, true)  -- Restricted to admins
