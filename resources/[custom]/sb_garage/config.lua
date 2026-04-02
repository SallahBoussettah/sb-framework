--[[
    Everyday Chaos RP - Garage System Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- DEBUG
-- ============================================================================

Config.Debug = false                    -- Enable debug prints

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

Config.NPCModel = 's_m_y_valet_01'      -- Valet/parking attendant
Config.MaxVehiclesPerGarage = 10        -- Max vehicles stored at each location
Config.TransferFee = 500                -- Fee to retrieve from different garage ($)
Config.StoreCooldown = 3000             -- ms between operations
Config.RecentExitTime = 30000           -- ms window to store vehicle after exiting
Config.InteractDistance = 2.5           -- Distance to interact with NPC

-- Car keys settings
Config.KeysItem = 'car_keys'            -- Item name for car keys
Config.TakeKeysOnStore = true           -- Remove keys when storing vehicle
Config.GiveKeysOnRetrieve = true        -- Give keys back when retrieving

-- ============================================================================
-- GARAGE LOCATIONS
-- ============================================================================

Config.Garages = {
    ['legion'] = {
        label = 'Legion Square Parking',
        type = 'car',
        npcPos = vector4(215.83, -810.16, 30.73, 340.0),
        spawnPoints = {
            vector4(228.84, -800.41, 30.13, 157.0),
            vector4(232.89, -798.09, 30.12, 157.0),
            vector4(237.01, -795.81, 30.12, 157.0),
            vector4(222.54, -798.79, 30.13, 67.0),
            vector4(218.97, -802.65, 30.13, 67.0),
        },
        storeZone = {
            center = vector3(225.0, -805.0, 30.0),
            radius = 20.0,
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = 'Public Parking'
        },
    },

    ['pillbox'] = {
        label = 'Pillbox Hill Parking',
        type = 'car',
        npcPos = vector4(274.37, -343.83, 44.92, 340.0),
        spawnPoints = {
            vector4(280.28, -339.19, 44.92, 161.0),
            vector4(283.78, -337.08, 44.92, 161.0),
            vector4(287.27, -334.89, 44.92, 161.0),
            vector4(277.07, -341.06, 44.92, 161.0),
        },
        storeZone = {
            center = vector3(280.0, -340.0, 45.0),
            radius = 20.0,
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = 'Public Parking'
        },
    },

    ['airport'] = {
        label = 'Airport Parking',
        type = 'car',
        npcPos = vector4(-796.26, -2023.54, 9.4, 54.0),
        spawnPoints = {
            vector4(-802.78, -2028.66, 8.97, 228.0),
            vector4(-798.45, -2024.51, 8.97, 228.0),
            vector4(-807.08, -2032.85, 8.97, 228.0),
            vector4(-811.42, -2036.98, 8.97, 228.0),
        },
        storeZone = {
            center = vector3(-805.0, -2030.0, 9.0),
            radius = 25.0,
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = 'Airport Parking'
        },
    },

    ['sandy'] = {
        label = 'Sandy Shores Garage',
        type = 'car',
        npcPos = vector4(1878.41, 3760.75, 33.03, 213.0),
        spawnPoints = {
            vector4(1872.03, 3756.41, 33.03, 30.0),
            vector4(1867.48, 3754.21, 33.03, 30.0),
            vector4(1862.83, 3751.88, 33.03, 30.0),
        },
        storeZone = {
            center = vector3(1870.0, 3755.0, 33.0),
            radius = 15.0,
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = 'Sandy Shores Parking'
        },
    },

    ['paleto'] = {
        label = 'Paleto Bay Garage',
        type = 'car',
        npcPos = vector4(110.37, 6612.38, 31.86, 180.0),
        spawnPoints = {
            vector4(106.72, 6617.62, 31.79, 0.0),
            vector4(102.42, 6617.62, 31.79, 0.0),
            vector4(98.12, 6617.62, 31.79, 0.0),
        },
        storeZone = {
            center = vector3(105.0, 6615.0, 32.0),
            radius = 15.0,
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = 'Paleto Bay Parking'
        },
    },
}

-- ============================================================================
-- VEHICLE TYPES (for filtering)
-- ============================================================================

Config.VehicleTypes = {
    car = { 'car', 'suv', 'sedan', 'coupe', 'muscle', 'sport', 'super', 'compact', 'van' },
    boat = { 'boat' },
    aircraft = { 'helicopter', 'plane' },
    motorcycle = { 'motorcycle' },
}
