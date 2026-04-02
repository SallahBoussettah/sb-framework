-- ============================================================================
-- Pizza Delivery — Job Definition
-- Loaded as shared script, registers into Config.PublicJobs
--
-- Restaurants are level-gated:
--   Low level  = close restaurants (BMX-friendly, short flat rides)
--   High level = farther restaurants (motorcycle/car territory)
-- Each restaurant has its own pool of delivery locations in its area.
-- Server picks a random eligible restaurant per batch (avoids repeats).
-- ============================================================================

Config.PublicJobs['pizza_delivery'] = {
    id = 'pizza_delivery',
    label = 'Pizza Delivery',
    description = 'Pick up and deliver pizzas across Los Santos. Earn XP to unlock better vehicles and higher pay. Work at your own pace — keep your roleplay job while delivering on the side.',
    icon = 'fa-pizza-slice',
    xpPerDelivery = 50,
    tipMin = 10,
    tipMax = 50,
    batchSize = 10,

    -- Vehicle spawn slots OUTSIDE the Job Center (9 parking spots)
    -- PJ_SpawnJobVehicle picks the first clear slot
    vehicleSpawnSlots = {
        vector4(-532.5786, -270.9348, 35.2038, 286.1009),
        vector4(-526.5956, -268.3959, 35.2670, 292.3243),
        vector4(-521.0956, -266.1043, 35.3266, 295.4604),
        vector4(-515.6613, -263.9114, 35.4050, 295.0045),
        vector4(-510.2374, -261.6139, 35.4623, 290.8585),
        vector4(-504.8155, -259.4850, 35.5404, 292.7511),
        vector4(-499.5295, -257.2903, 35.5666, 293.6094),
        vector4(-494.1220, -255.0322, 35.6224, 290.9791),
        vector4(-488.5063, -252.8035, 35.6794, 294.4307),
    },
    vehicleSpawn = vector4(-515.6613, -263.9114, 35.4050, 295.0045), -- fallback/default

    -- Return point to end shift (same area as vehicle spawn, near Job Center)
    returnPoint = vector3(-515.5671, -263.9014, 35.4064),
    returnRadius = 8.0,

    -- ========================================================================
    -- RESTAURANTS — level-gated, each with its own delivery zone
    -- ========================================================================
    restaurants = {
        -- ==============================================================
        -- LEVEL 1+ : Close to Job Center, flat terrain (BMX-friendly)
        -- ==============================================================
        {
            id = 'little_seoul_noodle',
            label = 'Little Seoul Noodle House',
            coords = vector4(-756.98, -753.68, 26.34, 122.0),
            minLevel = 1,
            deliveries = {
                vector3(-656.92, -854.54, 24.49),     -- Little Seoul
                vector3(-753.22, -925.16, 18.45),      -- Little Seoul south
                vector3(-604.13, -950.68, 22.46),      -- Little Seoul east
                vector3(-810.56, -634.22, 27.78),      -- Little Seoul north
                vector3(-935.62, -735.13, 19.58),      -- Richards area
                vector3(-582.85, -680.12, 32.59),      -- Little Seoul central
                vector3(-715.34, -519.58, 33.29),      -- Korean BBQ area
                vector3(-485.22, -697.45, 32.84),      -- Near hospital
                vector3(-868.93, -863.44, 20.13),      -- Southwest Little Seoul
                vector3(-478.16, -814.75, 30.09),      -- Little Seoul border
                vector3(-548.12, -577.43, 34.21),      -- North Little Seoul
                vector3(-681.45, -948.23, 21.36),      -- Little Seoul docks area
            },
        },
        {
            id = 'bean_machine_downtown',
            label = 'Bean Machine Downtown',
            coords = vector4(113.2460, -1038.0659, 29.3309, 70.3858),
            minLevel = 1,
            deliveries = {
                vector3(142.69, -1058.45, 29.36),      -- Downtown LS
                vector3(-41.73, -584.21, 38.40),        -- Textile City
                vector3(368.10, -1025.83, 29.34),       -- Pillbox area
                vector3(310.67, -928.65, 29.25),        -- Alta
                vector3(78.14, -810.43, 31.38),         -- Downtown south
                vector3(205.18, -736.52, 34.46),        -- Near hospital
                vector3(-100.22, -920.14, 28.78),       -- Mission Row
                vector3(425.58, -816.29, 29.31),        -- Pillbox Hill
                vector3(18.73, -691.52, 31.62),         -- Downtown central
                vector3(264.42, -579.68, 42.86),        -- Hawick
                vector3(-185.57, -456.21, 35.62),       -- Burton east
                vector3(154.83, -895.24, 30.17),        -- Alta south
            },
        },

        -- ==============================================================
        -- LEVEL 3+ : Medium distance (scooter territory)
        -- ==============================================================
        {
            id = 'pizza_stack_vespucci',
            label = 'Pizza Stack',
            coords = vector4(-1570.1901, -908.2363, 9.3902, 33.0677),
            minLevel = 3,
            deliveries = {
                vector3(-1222.39, -1079.71, 8.11),     -- Del Perro apt
                vector3(-1362.15, -474.81, 33.16),      -- Morningwood
                vector3(-1527.49, -385.33, 40.16),      -- Pacific Bluffs
                vector3(-1193.60, -1560.85, 4.36),      -- Vespucci canals
                vector3(-1388.92, -946.38, 11.34),      -- Del Perro pier area
                vector3(-1169.43, -1248.86, 6.95),      -- Del Perro south
                vector3(-1490.22, -684.65, 28.34),      -- Pacific Bluffs east
                vector3(-1283.81, -616.42, 26.73),      -- Morningwood south
                vector3(-1618.34, -1049.26, 13.12),     -- Vespucci beach south
                vector3(-1093.46, -1506.78, 4.67),      -- Vespucci canals east
                vector3(-1334.17, -1296.52, 4.83),      -- Del Perro beach
                vector3(-1478.63, -536.14, 34.72),      -- Pacific Bluffs south
            },
        },
        {
            id = 'bite_davis',
            label = 'Bite! Davis',
            coords = vector4(8.2229, -1610.0060, 29.2971, 141.8121),
            minLevel = 3,
            deliveries = {
                vector3(-228.68, -1613.72, 34.89),     -- South LS apartment
                vector3(266.35, -1899.01, 25.74),       -- Strawberry house
                vector3(-33.98, -1456.16, 31.52),       -- Davis motel
                vector3(-432.53, -1694.60, 19.07),      -- South central
                vector3(115.42, -1766.38, 30.12),       -- Davis east
                vector3(-178.35, -1762.29, 30.58),      -- Davis south
                vector3(352.18, -1659.42, 30.84),       -- Strawberry north
                vector3(55.67, -1528.93, 29.15),        -- Davis central
                vector3(-307.84, -1521.46, 27.89),      -- South central east
                vector3(425.93, -1743.52, 29.34),       -- Rancho
                vector3(180.26, -1975.42, 18.79),       -- Strawberry south
                vector3(-125.43, -1639.85, 32.46),      -- Davis west
            },
        },

        -- ==============================================================
        -- LEVEL 5+ : Farther out (motorcycle / car territory)
        -- ==============================================================
        {
            id = 'lucky_plucker_mirror_park',
            label = 'Lucky Plucker Mirror Park',
            coords = vector4(1089.0261, -775.2006, 58.2846, 1.2834),
            minLevel = 5,
            deliveries = {
                vector3(984.39, -1802.12, 31.12),      -- El Burro Heights
                vector3(1159.38, -464.25, 66.73),       -- Mirror Park north
                vector3(1085.62, -682.35, 57.96),       -- Mirror Park central
                vector3(886.45, -1025.18, 32.17),       -- La Mesa
                vector3(1248.73, -542.86, 69.34),       -- Mirror Park east
                vector3(946.58, -138.42, 74.56),        -- East Vinewood
                vector3(1137.24, -975.63, 46.29),       -- Murieta Heights
                vector3(780.36, -889.14, 25.73),        -- La Mesa west
                vector3(1023.67, -427.85, 64.92),       -- Mirror Park south
                vector3(1302.41, -655.78, 67.43),       -- Mirror Park far east
                vector3(854.92, -575.24, 57.18),        -- East Vinewood south
                vector3(1178.85, -1168.42, 35.46),      -- Murieta Heights south
            },
        },
    },

    -- Level progression (starts with BMX bicycle)
    -- XP per batch cycle = 500 (50 XP × 10 deliveries)
    -- Level N requires N-1 cycles from previous level
    levels = {
        { level = 1,  xpRequired = 0,      pay = 80,   vehicle = 'bmx' },      -- start
        { level = 2,  xpRequired = 500,    pay = 100,  vehicle = 'bmx' },      -- 1 cycle
        { level = 3,  xpRequired = 1500,   pay = 120,  vehicle = 'faggio' },   -- +2 cycles
        { level = 4,  xpRequired = 3000,   pay = 150,  vehicle = 'faggio' },   -- +3 cycles
        { level = 5,  xpRequired = 5000,   pay = 180,  vehicle = 'faggio3' },  -- +4 cycles
        { level = 6,  xpRequired = 7500,   pay = 220,  vehicle = 'faggio3' },  -- +5 cycles
        { level = 7,  xpRequired = 10500,  pay = 270,  vehicle = 'pcj' },      -- +6 cycles
        { level = 8,  xpRequired = 14000,  pay = 320,  vehicle = 'pcj' },      -- +7 cycles
        { level = 9,  xpRequired = 18000,  pay = 380,  vehicle = 'blista2' },  -- +8 cycles
        { level = 10, xpRequired = 22500,  pay = 450,  vehicle = 'sultan' },   -- +9 cycles
    },

    -- Vehicle labels for UI
    vehicleLabels = {
        ['bmx']     = 'BMX Bicycle',
        ['faggio']  = 'Faggio Scooter',
        ['faggio3'] = 'Faggio Sport',
        ['pcj']     = 'PCJ-600',
        ['blista2'] = 'Blista Compact',
        ['sultan']  = 'Sultan',
    },

    -- Vehicles that require a license item to use (car-class only)
    -- BMX and bikes/scooters don't need a license
    requiresLicense = {
        ['blista2'] = 'car_license',
        ['sultan']  = 'car_license',
    },
}
