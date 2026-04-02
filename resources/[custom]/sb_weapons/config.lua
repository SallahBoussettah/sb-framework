--[[
    Everyday Chaos RP - Weapons Configuration (V2 Magazine System)
    Author: Salah Eddine Boussettah
]]

Config = {}

-- Weapon definitions
Config.Weapons = {
    -- ============================
    -- PISTOLS (magazine-based)
    -- ============================
    ['weapon_pistol'] = {
        hash = `WEAPON_PISTOL`,
        label = 'Pistol',
        weaponType = 'pistol',
        ammoItem = 'pistol_ammo',
        compatibleMags = {'p_quick_mag', 'p_stand_mag', 'p_extended_mag'},
        extendedClipComponent = 'COMPONENT_PISTOL_CLIP_02',
        nativeClipSize = 12,
        drawTime = 800,
        holsterTime = 600,
    },
    ['weapon_combatpistol'] = {
        hash = `WEAPON_COMBATPISTOL`,
        label = 'Combat Pistol',
        weaponType = 'pistol',
        ammoItem = 'pistol_ammo',
        compatibleMags = {'p_quick_mag', 'p_stand_mag', 'p_extended_mag'},
        extendedClipComponent = 'COMPONENT_COMBATPISTOL_CLIP_02',
        nativeClipSize = 12,
        drawTime = 800,
        holsterTime = 600,
    },

    -- ============================
    -- LONGARMS (magazine-based)
    -- ============================
    ['weapon_pumpshotgun'] = {
        hash = `WEAPON_PUMPSHOTGUN`,
        label = 'Pump Shotgun',
        weaponType = 'shotgun',
        ammoItem = 'shotgun_ammo',
        compatibleMags = {'sg_stand_mag'},
        nativeClipSize = 8,
        drawTime = 1000,
        holsterTime = 800,
        noMagazine = true,  -- Shotgun loads shells directly, no magazine swap
        nativeAmmo = 8,     -- Give 8 shells on equip
    },
    ['weapon_smg'] = {
        hash = `WEAPON_SMG`,
        label = 'SMG',
        weaponType = 'smg',
        ammoItem = 'smg_ammo',
        compatibleMags = {'smg_stand_mag'},
        extendedClipComponent = 'COMPONENT_SMG_CLIP_02',
        nativeClipSize = 30,
        drawTime = 800,
        holsterTime = 600,
        noMagazine = true,  -- TODO: add SMG magazines later
        nativeAmmo = 30,
    },
    ['weapon_carbinerifle'] = {
        hash = `WEAPON_CARBINERIFLE`,
        label = 'Carbine Rifle',
        weaponType = 'rifle',
        ammoItem = 'rifle_ammo',
        compatibleMags = {'r_stand_mag'},
        extendedClipComponent = 'COMPONENT_CARBINERIFLE_CLIP_02',
        nativeClipSize = 30,
        drawTime = 1000,
        holsterTime = 800,
        noMagazine = true,  -- TODO: add rifle magazines later
        nativeAmmo = 30,
    },

    -- ============================
    -- MELEE & NON-LETHAL (no ammo/magazine)
    -- ============================
    ['weapon_stungun'] = {
        hash = `WEAPON_STUNGUN`,
        label = 'Taser',
        weaponType = 'taser',
        noMagazine = true,
        nativeAmmo = 4,     -- Taser cartridges
        drawTime = 600,
        holsterTime = 400,
    },
    ['weapon_nightstick'] = {
        hash = `WEAPON_NIGHTSTICK`,
        label = 'Nightstick',
        weaponType = 'melee',
        noMagazine = true,
        nativeAmmo = 0,
        drawTime = 500,
        holsterTime = 400,
    },
    ['weapon_flashlight'] = {
        hash = `WEAPON_FLASHLIGHT`,
        label = 'Flashlight',
        weaponType = 'melee',
        noMagazine = true,
        nativeAmmo = 0,
        drawTime = 500,
        holsterTime = 400,
    },
}

-- Magazine definitions
Config.Magazines = {
    ['p_quick_mag'] = { capacity = 7, reloadTime = 1000, weaponType = 'pistol', label = 'Quick' },
    ['p_stand_mag'] = { capacity = 10, reloadTime = 1800, weaponType = 'pistol', label = 'Standard' },
    ['p_extended_mag'] = { capacity = 15, reloadTime = 2500, weaponType = 'pistol', label = 'Extended' },
}

-- Ammo box config
Config.AmmoBox = {
    item = 'p_ammobox',
    capacity = 100,
    ammoItem = 'pistol_ammo',
}

-- Default durability for new weapons
Config.DefaultDurability = 100.0

-- How often to check ammo count changes (ms)
Config.AmmoSyncInterval = 500

-- Disable weapon wheel controls
Config.DisableWeaponWheel = true

-- Admin command moved to sb_admin
