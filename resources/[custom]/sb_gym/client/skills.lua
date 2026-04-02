--[[
    Everyday Chaos RP - Gym Skills System
    Author: Salah Eddine Boussettah

    Handles GTA stat synchronization and passive gains tracking
]]

local SBCore = nil
local PlayerSkills = {
    strength = 20,
    stamina = 20,
    lung = 10
}

-- Passive gain trackers
local lastRunCheck = 0
local lastSwimCheck = 0
local lastMeleeCheck = 0
local wasRunning = false
local wasSwimming = false
local wasMeleeing = false

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Load skills from player metadata
function LoadPlayerSkills()
    SBCore = exports['sb_core']:GetCoreObject()
    if not SBCore then return end

    local player = SBCore.Functions.GetPlayerData()
    if player and player.metadata and player.metadata.gym then
        PlayerSkills = {
            strength = player.metadata.gym.strength or Config.DefaultSkills.strength,
            stamina = player.metadata.gym.stamina or Config.DefaultSkills.stamina,
            lung = player.metadata.gym.lung or Config.DefaultSkills.lung
        }
    else
        PlayerSkills = {
            strength = Config.DefaultSkills.strength,
            stamina = Config.DefaultSkills.stamina,
            lung = Config.DefaultSkills.lung
        }
    end

    -- Sync to GTA stats
    SyncAllStats()
end

-- ============================================================================
-- GTA STAT SYNCHRONIZATION
-- ============================================================================

-- Convert skill level (0-100) to GTA stat value (0-100)
local function SkillToStat(skillLevel)
    return math.floor(math.max(0, math.min(100, skillLevel)))
end

-- Sync a single skill to GTA native stat
function SyncStat(skillName)
    local statName = Config.StatNames[skillName]
    if not statName then return end

    local statHash = joaat(statName)
    local value = SkillToStat(PlayerSkills[skillName] or 0)

    StatSetInt(statHash, value, true)
end

-- Sync all skills to GTA stats
function SyncAllStats()
    for skillName, _ in pairs(Config.StatNames) do
        SyncStat(skillName)
    end
end

-- ============================================================================
-- SKILL GETTERS/SETTERS
-- ============================================================================

function GetSkill(skillName)
    return PlayerSkills[skillName] or 0
end

function GetAllSkills()
    return PlayerSkills
end

function UpdateSkill(skillName, newValue)
    if not PlayerSkills[skillName] then return end

    PlayerSkills[skillName] = math.max(Config.MinSkillLevel, math.min(Config.MaxSkillLevel, newValue))
    SyncStat(skillName)
end

-- ============================================================================
-- PASSIVE GAINS TRACKING
-- ============================================================================

CreateThread(function()
    -- Wait for player to load
    while not SBCore do
        Wait(1000)
        SBCore = exports['sb_core']:GetCoreObject()
    end

    while true do
        Wait(1000)  -- Check every second

        local ped = PlayerPedId()
        local now = GetGameTimer()

        -- Skip if dead or in vehicle
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
            wasRunning = false
            wasSwimming = false
            goto continue
        end

        -- Running/Sprinting check
        local speed = GetEntitySpeed(ped)
        local isRunning = speed >= Config.RunningSpeedThreshold and IsPedSprinting(ped)

        if isRunning then
            if not wasRunning then
                wasRunning = true
                lastRunCheck = now
            elseif now - lastRunCheck >= Config.PassiveGains.running.interval then
                -- Gain stamina XP from running
                TriggerServerEvent('sb_gym:server:passiveGain', 'running')
                lastRunCheck = now
            end
        else
            wasRunning = false
        end

        -- Swimming check
        local isSwimming = IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)

        if isSwimming then
            if not wasSwimming then
                wasSwimming = true
                lastSwimCheck = now
            elseif now - lastSwimCheck >= Config.PassiveGains.swimming.interval then
                -- Gain lung capacity XP from swimming
                TriggerServerEvent('sb_gym:server:passiveGain', 'swimming')
                lastSwimCheck = now
            end
        else
            wasSwimming = false
        end

        ::continue::
    end
end)

-- Melee combat detection
CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()

        -- Check if player is in melee combat
        if IsPedInMeleeCombat(ped) then
            if not wasMeleeing then
                wasMeleeing = true
                lastMeleeCheck = GetGameTimer()
            end
        else
            if wasMeleeing then
                local now = GetGameTimer()
                if now - lastMeleeCheck >= Config.PassiveGains.melee.interval then
                    -- Gain strength XP from melee
                    TriggerServerEvent('sb_gym:server:passiveGain', 'melee')
                end
                wasMeleeing = false
            end
            Wait(500)  -- Sleep when not in combat
        end
    end
end)

-- ============================================================================
-- EVENTS
-- ============================================================================

-- Update skills from server
RegisterNetEvent('sb_gym:client:updateSkills', function(skills)
    if skills then
        PlayerSkills = skills
        SyncAllStats()
    end
end)

-- Single skill update
RegisterNetEvent('sb_gym:client:skillGain', function(skillName, newValue)
    if PlayerSkills[skillName] then
        PlayerSkills[skillName] = newValue
        SyncStat(skillName)
    end
end)

-- Player loaded event
RegisterNetEvent('SB:Client:PlayerLoaded', function()
    Wait(1000)  -- Small delay for data to be ready
    LoadPlayerSkills()
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetSkill', GetSkill)
exports('GetAllSkills', GetAllSkills)
exports('SyncAllStats', SyncAllStats)
