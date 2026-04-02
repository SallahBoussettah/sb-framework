--[[
    Everyday Chaos RP - Vehicle Shop Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

-- Require driver's license to purchase vehicles
Config.RequireLicense = true
Config.LicenseItem = 'car_license'

-- Give car keys on purchase
Config.GiveKeys = true
Config.KeysItem = 'car_keys'

-- Test drive settings
Config.TestDrive = {
    enabled = true,
    duration = 600, -- seconds (10 minutes)
    returnRadius = 50.0, -- Must return within this distance
}

-- ============================================================================
-- DEALERSHIP LOCATIONS
-- ============================================================================

Config.Dealerships = {
    ['pdm'] = {
        label = 'Premium Deluxe Motorsport',
        type = 'car',
        npcModel = 's_m_m_autoshop_02',
        location = vector4(-54.2078, -1104.7158, 26.4373, 143.5315),
        spawnPoint = vector4(-47.9197, -1116.5314, 26.4341, 358.9735),
        testDriveSpawn = vector4(-47.9197, -1116.5314, 26.4341, 358.9735),
        testDriveReturn = vector4(-47.9197, -1116.5314, 26.4341, 358.9735),
        blip = {
            sprite = 326,
            color = 3,
            scale = 0.8,
            label = 'Vehicle Dealership'
        },
    },
}

-- ============================================================================
-- VEHICLES FOR SALE (3 test vehicles - native GTA cars)
-- ============================================================================

Config.Vehicles = {
    -- Compact car (cheap)
    ['blista'] = {
        label = 'Blista',
        brand = 'Dinka',
        price = 15000,
        category = 'compact',
        class = 'Compact',
        dealerships = {'pdm'},
        description = 'A reliable compact car perfect for city driving.',
    },

    -- Sedan (mid-range)
    ['sultan'] = {
        label = 'Sultan',
        brand = 'Karin',
        price = 35000,
        category = 'sedan',
        class = 'Sports',
        dealerships = {'pdm'},
        description = 'A sporty sedan with good performance and handling.',
    },

    -- Sports car (expensive)
    ['elegy2'] = {
        label = 'Elegy RH8',
        brand = 'Annis',
        price = 95000,
        category = 'sports',
        class = 'Sports',
        dealerships = {'pdm'},
        description = 'A high-performance sports car for those who demand speed.',
    },
}

-- ============================================================================
-- VEHICLE CATEGORIES
-- ============================================================================

Config.Categories = {
    { id = 'compact', label = 'Compact', icon = 'fa-car-side' },
    { id = 'sedan', label = 'Sedan', icon = 'fa-car' },
    { id = 'sports', label = 'Sports', icon = 'fa-flag-checkered' },
}

-- ============================================================================
-- PLATE GENERATION
-- ============================================================================

Config.PlateFormat = 'XXXX 000' -- X = letter, 0 = number
Config.PlatePrefix = '' -- Optional prefix like 'EC '

-- ============================================================================
-- INTERACTION
-- ============================================================================

Config.InteractDistance = 2.5
