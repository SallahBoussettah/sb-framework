--[[
    Everyday Chaos RP - Core Framework Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- SERVER IDENTITY
-- ============================================================================
Config.ServerName = "Everyday Chaos RP"
Config.Discord = "discord.gg/everydaychaos"  -- Update with your Discord

-- ============================================================================
-- CHARACTER SETTINGS
-- ============================================================================
Config.MaxCharacters = 5                    -- Max characters per player
Config.EnableMulticharacter = true          -- Enable character selection

-- ============================================================================
-- STARTING VALUES
-- ============================================================================
Config.DefaultMoney = {
    cash = 500,
    bank = 0,
    crypto = 0
}

Config.DefaultSpawn = vector4(-269.4, -955.3, 31.2, 205.8)  -- Legion Square

Config.DefaultJob = {
    name = "unemployed",
    label = "Unemployed",
    payment = 0,
    onduty = false,
    isboss = false,
    grade = {
        name = "freelancer",
        level = 0
    }
}

Config.DefaultGang = {
    name = "none",
    label = "No Gang",
    isboss = false,
    grade = {
        name = "none",
        level = 0
    }
}

Config.DefaultMetadata = {
    hunger = 100,
    thirst = 100,
    stress = 0,
    armor = 0,
    isdead = false,
    ishandcuffed = false,
    injail = 0,
    jailitems = {},
    tracker = false,
    bloodtype = "Unknown",
    fingerprint = "",
    walletid = "",
    criminalrecord = {
        hasRecord = false
    },
    licenses = {
        driver = false,
        weapon = false,
        business = false
    },
    gym = {
        strength = 20,
        stamina = 20,
        lung = 10,
        lastWorkout = 0
    }
}

-- ============================================================================
-- SURVIVAL SETTINGS
-- ============================================================================
Config.EnableHunger = true
Config.EnableThirst = true
Config.HungerRate = 4.2                     -- Decrease per minute
Config.ThirstRate = 3.8                     -- Decrease per minute

-- ============================================================================
-- DEATH SYSTEM
-- ============================================================================
-- Death system is handled by sb_deaths resource

-- ============================================================================
-- GAMEPLAY SETTINGS
-- ============================================================================
Config.EnablePVP = true                     -- Allow player damage
Config.EnableWantedLevel = false            -- GTA wanted system (disable for RP)

-- ============================================================================
-- NOTIFICATION SETTINGS
-- ============================================================================
Config.NotifyPosition = "top-right"         -- top, top-left, top-right, bottom, etc.
Config.NotifyDuration = 5000                -- Default duration in ms

-- ============================================================================
-- IDENTIFIER PRIORITY
-- ============================================================================
-- Order of preference for player identification
Config.IdentifierTypes = {
    "license",      -- Rockstar license (most reliable)
    "discord",      -- Discord ID
    "fivem",        -- Cfx.re account
    "steam"         -- Steam ID
}

-- ============================================================================
-- PLAYER SLOTS (Custom allocations)
-- ============================================================================
-- Override max characters for specific players (VIP, staff, etc.)
Config.PlayerSlots = {
    -- ["license:abc123"] = 10,  -- Example: this player gets 10 slots
}

-- ============================================================================
-- DEBUG
-- ============================================================================
Config.Debug = false                        -- Enable debug prints
