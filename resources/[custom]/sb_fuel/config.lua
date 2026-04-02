--[[
    Everyday Chaos RP - Fuel System Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================
Config.FuelPrice = 3.50                 -- Price per liter
Config.DefaultFuel = 100.0              -- Default fuel for new/spawned vehicles (percentage)
Config.RefuelRate = 2.0                 -- Liters per second when refueling
Config.LowFuelWarning = 20              -- Percentage to show low fuel warning
Config.CriticalFuelWarning = 10         -- Percentage for critical warning
Config.EngineStallThreshold = 1         -- Below this percentage, engine stalls

-- ============================================================================
-- FUEL CONSUMPTION (Base consumption per second at max RPM)
-- ============================================================================
Config.BaseConsumption = 0.15           -- Base fuel consumption per second at max RPM
Config.IdleConsumption = 0.02           -- Fuel consumption when idle (engine on, not moving)
Config.ConsumptionInterval = 1000       -- How often to calculate consumption (ms)

-- Vehicle class consumption multipliers (0 = no fuel use, 2 = double consumption)
-- Classes: https://docs.fivem.net/natives/?_0x29439776AAA00A62
Config.ClassMultipliers = {
    [0]  = 0.8,   -- Compacts
    [1]  = 0.9,   -- Sedans
    [2]  = 1.2,   -- SUVs
    [3]  = 1.0,   -- Coupes
    [4]  = 1.3,   -- Muscle
    [5]  = 1.1,   -- Sports Classics
    [6]  = 1.4,   -- Sports
    [7]  = 1.6,   -- Super
    [8]  = 0.6,   -- Motorcycles
    [9]  = 1.5,   -- Off-road
    [10] = 1.2,   -- Industrial
    [11] = 1.0,   -- Utility
    [12] = 1.3,   -- Vans
    [13] = 0.0,   -- Cycles (no fuel)
    [14] = 1.8,   -- Boats
    [15] = 2.5,   -- Helicopters
    [16] = 3.0,   -- Planes
    [17] = 1.0,   -- Service
    [18] = 1.1,   -- Emergency
    [19] = 1.2,   -- Military
    [20] = 1.5,   -- Commercial
    [21] = 0.0,   -- Trains (no fuel script control)
}

-- ============================================================================
-- JERRY CAN SETTINGS
-- ============================================================================
Config.JerryCan = {
    item = 'jerrycan',              -- Item name in inventory
    maxCapacity = 20,               -- Max liters a jerry can holds
    pourRate = 1.5,                 -- Liters per second when pouring
    refillPrice = 2.50,             -- Price per liter to refill jerry can (cheaper than pump)
    prop = 'prop_jerrycan_01a',     -- Jerry can prop model
    pourAnim = {
        dict = 'weapon@w_sp_jerrycan',
        anim = 'fire',
        flag = 1
    }
}

-- ============================================================================
-- SYPHON SETTINGS
-- ============================================================================
Config.Syphon = {
    enabled = true,                 -- Allow syphoning from vehicles
    item = 'syphon_kit',            -- Required item (nil = no item needed)
    duration = 15000,               -- Time to syphon (ms)
    -- Amount is randomized (1.5L-20L weighted: low amounts much more common)
    canSyphonOwned = false,         -- Can syphon player-owned vehicles?
    canSyphonOccupied = false,      -- Can syphon vehicles with people inside?
}

-- ============================================================================
-- NOZZLE & PUMP SETTINGS
-- ============================================================================
Config.Nozzle = {
    prop = 'prop_cs_fuel_nozle',    -- Fuel nozzle prop
    bone = 57005,                   -- Right hand bone
    offset = vector3(0.12, 0.04, -0.01),
    rotation = vector3(-90.0, 0.0, 0.0),
    maxDistance = 8.0,              -- Max distance from pump before nozzle drops
    attachDistance = 5.0,           -- Distance to detect vehicle for refueling (increased for easier use)
}

-- Pump prop models (for targeting)
Config.PumpModels = {
    'prop_gas_pump_1a',
    'prop_gas_pump_1b',
    'prop_gas_pump_1c',
    'prop_gas_pump_1d',
    'prop_gas_pump_old2',
    'prop_gas_pump_old3',
    'prop_vintage_pump',
    'prop_gas_pump_1d_short',  -- Added for some custom maps
}

-- ============================================================================
-- GAS STATION LOCATIONS
-- ============================================================================
Config.Stations = {
    -- Los Santos
    {
        id = 'lsa_01',
        label = 'Fuel Station',
        coords = vector3(-526.02, -1211.0, 18.18),
        blip = true,
        type = 'gas'  -- 'gas' or 'electric'
    },
    {
        id = 'lsa_02',
        label = 'Fuel Station',
        coords = vector3(-70.21, -1761.79, 29.53),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_03',
        label = 'Fuel Station',
        coords = vector3(265.65, -1261.53, 29.29),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_04',
        label = 'Fuel Station',
        coords = vector3(1208.51, -1402.57, 35.22),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_05',
        label = 'Fuel Station',
        coords = vector3(818.99, -1027.89, 26.4),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_06',
        label = 'Fuel Station',
        coords = vector3(1181.38, -330.85, 69.32),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_07',
        label = 'Fuel Station',
        coords = vector3(618.27, 269.13, 103.09),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_08',
        label = 'Fuel Station',
        coords = vector3(-1437.62, -276.75, 46.21),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_09',
        label = 'Fuel Station',
        coords = vector3(-2096.71, -319.29, 13.16),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_10',
        label = 'Fuel Station',
        coords = vector3(-1799.71, 802.13, 138.59),
        blip = true,
        type = 'gas'
    },
    {
        id = 'lsa_11',
        label = 'Fuel Station',
        coords = vector3(-2554.99, 2334.4, 33.08),
        blip = true,
        type = 'gas'
    },
    -- Blaine County
    {
        id = 'bc_01',
        label = 'Fuel Station',
        coords = vector3(-3172.13, 1088.85, 20.84),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_02',
        label = 'Fuel Station',
        coords = vector3(-3031.07, 590.66, 7.91),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_03',
        label = 'Fuel Station',
        coords = vector3(263.89, 2607.51, 44.98),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_04',
        label = 'Fuel Station',
        coords = vector3(2679.86, 3264.74, 55.24),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_05',
        label = 'Fuel Station',
        coords = vector3(1701.9, 6416.03, 32.76),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_06',
        label = 'Fuel Station',
        coords = vector3(1687.16, 4929.39, 42.08),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_07',
        label = 'Fuel Station',
        coords = vector3(180.86, 6603.23, 31.87),
        blip = true,
        type = 'gas'
    },
    {
        id = 'bc_08',
        label = 'Fuel Station',
        coords = vector3(-93.76, 6419.59, 31.49),
        blip = true,
        type = 'gas'
    },
    -- Airport / Industrial
    {
        id = 'ind_02',
        label = 'Fuel Station',
        coords = vector3(175.12, -1546.14, 29.26),
        blip = true,
        type = 'gas'
    },
    {
        id = 'ind_03',
        label = 'Fuel Station',
        coords = vector3(-724.62, -935.16, 19.21),
        blip = true,
        type = 'gas'
    },
}

-- ============================================================================
-- BLIP SETTINGS
-- ============================================================================
Config.Blip = {
    sprite = 361,       -- Gas pump icon
    color = 1,          -- Red
    scale = 0.7,
    shortRange = true,
    label = 'Gas Station'
}

-- ============================================================================
-- SOUNDS
-- ============================================================================
Config.Sounds = {
    nozzlePickup = { name = 'PICKUP_WEAPON_BALL', set = 'HUD_FRONTEND_WEAPONS_PICKUPS_SOUNDSET' },
    nozzleDrop = { name = 'DROP_WEAPON', set = 'HUD_FRONTEND_WEAPONS_PICKUPS_SOUNDSET' },
    fuelStart = { name = 'FLIGHT_SCHOOL_LESSON_PASSED', set = 'HUD_AWARDS' },
    fuelLoop = { name = 'Refuel_loop', set = nil },  -- Custom sound (optional)
    fuelStop = { name = 'NAV_UP_DOWN', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    lowFuel = { name = 'Beep_Red', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    payment = { name = 'PURCHASE', set = 'HUD_LIQUOR_STORE_SOUNDSET' },
    engineStall = { name = 'HACKING_CLICK', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

-- ============================================================================
-- ELECTRIC VEHICLES (Future support)
-- ============================================================================
Config.ElectricVehicles = {
    'voltic',
    'voltic2',
    'raiden',
    'tezeract',
    'neon',
    'cyclone',
    'imorgon',
    'dilettante',
    'surge',
    'khamelion',
    'caddy',
    'caddy2',
    'caddy3',
    'airtug',
}

Config.Electric = {
    enabled = false,                -- Electric charging not implemented yet
    chargeRate = 0.5,               -- Slower than gas
    pricePerKwh = 0.50,             -- Price per kWh
    chargerModels = {
        'prop_elect_panel_ld',      -- Placeholder
    }
}
