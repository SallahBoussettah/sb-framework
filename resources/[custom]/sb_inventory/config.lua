--[[
    Everyday Chaos RP - Inventory Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ========================================================================
-- GENERAL SETTINGS
-- ========================================================================
Config.OpenKey = 'I'                     -- Key to open inventory
Config.MaxSlots = 40                     -- Default player inventory slots
Config.HotbarSlots = 5                   -- Number of hotbar slots (keys 1-5)

-- ========================================================================
-- INVENTORY TYPES (capacity = number of slots)
-- ========================================================================
Config.InventoryTypes = {
    ['player'] = { slots = 40 },
    ['stash'] = { slots = 50 },
    ['trunk'] = { slots = 30 },          -- default, overridden by class
    ['glovebox'] = { slots = 5 },
    ['drop'] = { slots = 30 },
    ['shop'] = { slots = 50 },
}

-- ========================================================================
-- VEHICLE TRUNK CAPACITIES (by vehicle class - slots only)
-- ========================================================================
Config.VehicleClasses = {
    [0]  = { slots = 25 },   -- Compacts
    [1]  = { slots = 35 },   -- Sedans
    [2]  = { slots = 45 },   -- SUVs
    [3]  = { slots = 25 },   -- Coupes
    [4]  = { slots = 30 },   -- Muscle
    [5]  = { slots = 20 },   -- Sports Classics
    [6]  = { slots = 20 },   -- Sports
    [7]  = { slots = 15 },   -- Super
    [8]  = { slots = 10 },   -- Motorcycles
    [9]  = { slots = 35 },   -- Off-Road
    [10] = { slots = 50 },   -- Industrial
    [11] = { slots = 50 },   -- Utility
    [12] = { slots = 50 },   -- Vans
    [13] = { slots = 5 },    -- Cycles
    [14] = { slots = 30 },   -- Boats
    [15] = { slots = 30 },   -- Helicopters
    [16] = { slots = 30 },   -- Planes
    [17] = { slots = 15 },   -- Service
    [18] = { slots = 35 },   -- Emergency
    [19] = { slots = 20 },   -- Military
    [20] = { slots = 20 },   -- Commercial
}

-- Glovebox is the same for all vehicles
Config.GloveboxDefault = { slots = 5 }

-- ========================================================================
-- DROP SETTINGS
-- ========================================================================
Config.Drops = {
    model = 'prop_med_bag_01b',          -- Prop model for dropped items
    despawnTime = 300,                    -- Seconds before drop disappears (5 min)
    maxDistance = 100.0,                  -- Max render distance for drop props
}

-- ========================================================================
-- INTERACTION DISTANCES
-- ========================================================================
Config.Distances = {
    give = 3.0,                          -- Distance to give items to players
    drop = 2.0,                          -- Distance to pick up drops
    trunk = 3.0,                         -- Distance to access trunk
    glovebox = 1.5,                      -- Distance to access glovebox (must be in vehicle)
    stash = 2.0,                         -- Distance to access stash
}

-- ========================================================================
-- UI SETTINGS
-- ========================================================================
Config.UI = {
    blur = false,                        -- Screen blur when inventory open
    animation = true,                    -- Enable UI animations
    hotbarTimeout = 3000,                -- Hide hotbar HUD after X ms
}

-- ========================================================================
-- ITEM USE ANIMATIONS
-- ========================================================================
Config.UseAnimations = {
    ['food'] = {
        dict = 'mp_player_inteat@burger',
        clip = 'mp_player_int_eat_burger',
        duration = 2500,
        prop = nil,
    },
    ['drink'] = {
        dict = 'mp_player_intdrink',
        clip = 'loop_bottle',
        duration = 2000,
        prop = nil,
    },
    ['medical'] = {
        dict = 'anim@heists@narcotics@funding@  briefcase',
        clip = 'open_briefcase',
        duration = 3000,
        prop = nil,
    },
    -- 'drug' category: no animation here, sb_drugs handles its own per-drug animations
}

-- ========================================================================
-- WEAPON AMMO MAPPING
-- ========================================================================
Config.WeaponAmmo = {
    -- Pistols
    ['weapon_pistol'] = 'pistol_ammo',
    ['weapon_pistol_mk2'] = 'pistol_ammo',
    ['weapon_combatpistol'] = 'pistol_ammo',
    ['weapon_appistol'] = 'pistol_ammo',
    ['weapon_pistol50'] = 'pistol_ammo',
    ['weapon_snspistol'] = 'pistol_ammo',
    ['weapon_heavypistol'] = 'pistol_ammo',
    ['weapon_revolver'] = 'pistol_ammo',
    ['weapon_revolver_mk2'] = 'pistol_ammo',
    ['weapon_doubleaction'] = 'pistol_ammo',
    ['weapon_ceramicpistol'] = 'pistol_ammo',
    ['weapon_navyrevolver'] = 'pistol_ammo',
    -- SMGs
    ['weapon_microsmg'] = 'smg_ammo',
    ['weapon_smg'] = 'smg_ammo',
    ['weapon_smg_mk2'] = 'smg_ammo',
    ['weapon_assaultsmg'] = 'smg_ammo',
    ['weapon_combatpdw'] = 'smg_ammo',
    ['weapon_machinepistol'] = 'smg_ammo',
    ['weapon_minismg'] = 'smg_ammo',
    -- Shotguns
    ['weapon_pumpshotgun'] = 'shotgun_ammo',
    ['weapon_sawnoffshotgun'] = 'shotgun_ammo',
    ['weapon_assaultshotgun'] = 'shotgun_ammo',
    ['weapon_bullpupshotgun'] = 'shotgun_ammo',
    ['weapon_heavyshotgun'] = 'shotgun_ammo',
    ['weapon_dbshotgun'] = 'shotgun_ammo',
    ['weapon_combatshotgun'] = 'shotgun_ammo',
    -- Rifles
    ['weapon_assaultrifle'] = 'rifle_ammo',
    ['weapon_assaultrifle_mk2'] = 'rifle_ammo',
    ['weapon_carbinerifle'] = 'rifle_ammo',
    ['weapon_carbinerifle_mk2'] = 'rifle_ammo',
    ['weapon_advancedrifle'] = 'rifle_ammo',
    ['weapon_specialcarbine'] = 'rifle_ammo',
    ['weapon_bullpuprifle'] = 'rifle_ammo',
    ['weapon_compactrifle'] = 'rifle_ammo',
    ['weapon_militaryrifle'] = 'rifle_ammo',
    -- Machine Guns
    ['weapon_mg'] = 'mg_ammo',
    ['weapon_combatmg'] = 'mg_ammo',
    ['weapon_combatmg_mk2'] = 'mg_ammo',
    ['weapon_gusenberg'] = 'mg_ammo',
    -- Snipers
    ['weapon_sniperrifle'] = 'snp_ammo',
    ['weapon_heavysniper'] = 'snp_ammo',
    ['weapon_heavysniper_mk2'] = 'snp_ammo',
    ['weapon_marksmanrifle'] = 'snp_ammo',
    ['weapon_marksmanrifle_mk2'] = 'snp_ammo',
}
