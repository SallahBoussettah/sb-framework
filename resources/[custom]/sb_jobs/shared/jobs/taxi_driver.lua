-- ============================================================================
-- Taxi Driver — Job Definition
-- Loaded as shared script, registers into Config.PublicJobs
--
-- One passenger at a time: pick up at random location, drive to destination,
-- get paid based on driving quality. Quality score affects tip multiplier.
-- ============================================================================

Config.PublicJobs['taxi_driver'] = {
    id = 'taxi_driver',
    label = 'Taxi Driver',
    description = 'Pick up passengers across Los Santos and drive them to their destinations. Earn XP to unlock better vehicles and higher fares. Drive carefully — your tip depends on it!',
    icon = 'fa-taxi',
    xpPerDelivery = 50,
    tipMin = 10,
    tipMax = 60,
    batchSize = 1,

    -- Vehicle spawn slots OUTSIDE the Job Center (shared with other jobs)
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
    vehicleSpawn = vector4(-515.6613, -263.9114, 35.4050, 295.0045),

    -- Return point to end shift (Job Center area)
    returnPoint = vector3(-515.5671, -263.9014, 35.4064),
    returnRadius = 8.0,

    -- ========================================================================
    -- PICKUP LOCATIONS — places where passengers hail a cab
    -- ========================================================================
    pickupLocations = {
        -- Hotels & Tourism
        vector4(-1810.84, -634.73, 10.96, 310.34),    -- Del Perro Pier area
        vector4(292.44, -227.50, 53.98, 150.89),       -- Vinewood hotel area
        vector4(-811.81, -2314.23, 13.30, 306.74),     -- LSIA terminal
        vector4(-1031.50, -2728.45, 13.76, 328.62),    -- LSIA south terminal
        vector4(-265.5968, -882.7437, 31.1781, 350.7223),       -- Maze Bank Tower area

        -- Hospitals
        vector4(312.24, -1381.63, 31.92, 55.72),       -- Pillbox Hill Medical
        vector4(1808.4830, 3677.7959, 34.2768, 32.9264),      -- Sandy Shores Medical
        vector4(-233.3791, 6318.0518, 31.4957, 215.4851),      -- Paleto Bay Medical

        -- Bars & Entertainment
        vector4(100.7599, -1321.9449, 29.2915, 151.4751),      -- Vanilla Unicorn area
        vector4(-564.70, 270.67, 83.02, 175.75),       -- Tequi-la-la
        vector4(-1391.3718, -585.1375, 30.2315, 46.8919),     -- Del Perro club
        vector4(243.0729, -1069.0751, 29.2738, 1.0338),       -- Downtown bar

        -- Shopping & Commercial
        vector4(-718.3737, -161.5239, 37.0042, 140.8011),      -- Rockford Plaza
        vector4(234.8775, -952.2609, 29.3084, 254.9022),       -- Legion Square
        vector4(-1231.9620, -901.2388, 12.1517, 37.0213),      -- Del Perro mall
        vector4(28.5648, -1353.8043, 29.3430, 176.9431),         -- Strawberry Ave shops

        -- Residential — Vinewood / Hills
        vector4(-178.4662, 503.9752, 136.8604, 11.7268),      -- Vinewood Hills
        vector4(-846.8197, 461.6397, 87.5272, 100.4522),        -- Richman
        vector4(340.2875, 162.5209, 103.2977, 168.4911),       -- Vinewood Blvd
        vector4(-1432.7695, 175.6676, 56.4212, 236.3912),      -- Pacific Bluffs

        -- Residential — East LS
        vector4(1179.0243, -442.3003, 66.8231, 261.3148),      -- Mirror Park
        vector4(953.62, -643.98, 58.11, 0.0),         -- Mirror Park south
        vector4(423.3279, -1622.0186, 29.2916, 309.7077),      -- Strawberry
        vector4(493.3819, -1880.8464, 26.2055, 294.4678),      -- Davis

        -- Residential — South LS
        vector4(-175.6666, -1674.4828, 33.2631, 88.3581),       -- South LS
        vector4(-65.1825, -1776.4664, 28.8073, 119.0902),      -- Davis
        vector4(104.5276, -1953.4425, 20.6298, 356.5610),      -- Rancho
        vector4(-1122.2732, -1516.2644, 4.3847, 117.6331),     -- Vespucci Canals

        -- Transit & Misc
        vector4(430.0788, -667.6937, 29.1993, 183.1758),       -- Bus station area
        vector4(-500.1555, -644.8113, 33.0267, 183.8855),      -- Little Seoul transit
        vector4(-256.5119, -685.2901, 33.4916, 349.8284),      -- Textile City
        vector4(237.0647, -1210.1024, 29.3251, 98.4772),      -- Alta St

        -- Blaine County
        vector4(1681.6937, 4940.4463, 42.1720, 58.4090),       -- Grapeseed
        vector4(1853.2180, 3745.8774, 33.0647, 127.0898),      -- Sandy Shores
        vector4(-320.9814, 6071.8760, 31.3251, 227.4696),      -- Paleto Bay
        vector4(2562.3789, 385.1136, 108.6204, 273.4290),      -- Tataviam Mountains
        vector4(1718.0598, 6415.4282, 33.5469, 149.2306),      -- Mount Chiliad area
        vector4(-3155.9165, 1095.7487, 20.8546, 248.9831),     -- Chumash
        vector4(-1107.2599, 2688.1221, 18.8107, 228.5920),     -- Route 68
        vector4(2684.7222, 3280.3958, 55.2406, 228.1885),      -- Sandy Shores east
    },

    -- ========================================================================
    -- DESTINATION LOCATIONS — where passengers want to go
    -- ========================================================================
    destinationLocations = {
        -- Downtown & Commercial
        vector3(-62.16, -780.99, 44.23),               -- Downtown LS
        vector3(145.4275, -1029.5757, 29.3473),              -- Legion Square south
        vector3(-716.0610, -825.0290, 23.4670),              -- Little Seoul
        vector3(-1053.2964, -1018.9998, 2.0774),             -- Del Perro Beach
        vector3(370.1589, -838.1113, 29.2917),               -- Pillbox Hill
        vector3(-465.7609, -359.8814, 34.0304),              -- Burton
        vector3(89.2320, -1941.9895, 20.7067),               -- Rancho
        vector3(-1327.9657, -1288.0413, 5.0489),             -- Del Perro pier south

        -- Vinewood & Hills
        vector3(97.7869, -189.5022, 54.8222),                -- Vinewood
        vector3(-643.4210, 64.6464, 46.2420),                -- West Vinewood
        vector3(350.3038, 325.9463, 104.2614),               -- Vinewood Hills
        vector3(-1890.0062, -569.9620, 11.8034),             -- Pacific Bluffs
        vector3(-861.2691, 699.8000, 148.9803),              -- Richman Glen
        vector3(592.1459, 72.1022, 93.2972),                 -- East Vinewood

        -- East & South LS
        vector3(900.0406, -1078.9490, 31.9189),              -- La Mesa
        vector3(1162.2953, -616.6609, 64.8780),              -- Mirror Park
        vector3(413.9077, -1728.3081, 30.1887),              -- Strawberry
        vector3(-178.0644, -1580.7544, 37.1817),             -- South LS
        vector3(288.3372, -2024.7428, 21.3351),              -- Rancho south
        vector3(-46.7997, -1456.1556, 33.5650),              -- Davis

        -- Vespucci & Beach
        vector3(-1446.4617, -943.7803, 9.8544),             -- Del Perro
        vector3(-1189.1154, -1518.6267, 5.5023),             -- Vespucci Canals
        vector3(-1589.9250, -392.2272, 44.8290),             -- Pacific Bluffs
        vector3(-1605.2267, -944.1537, 15.0179),            -- Vespucci Beach south

        -- Airport area
        vector3(-1076.2719, -2569.3354, 22.6849),             -- LSIA area
        vector3(-865.2308, -2260.1790, 9.1477),            -- LSIA north

        -- Blaine County
        vector3(1667.5226, 4794.6099, 43.1872),              -- Grapeseed
        vector3(1984.7700, 3840.3552, 34.3004),              -- Sandy Shores
        vector3(-290.43, 6204.15, 31.49),              -- Paleto Bay
        vector3(2490.0435, 4109.3340, 39.2198),              -- Sandy Shores east
        vector3(-2223.7346, 4261.3188, 47.8978),             -- North Chumash
        vector3(1698.3625, 4937.0215, 43.2272),              -- Grapeseed main
        vector3(-1093.7019, 2699.8596, 20.7393),             -- Route 68
        vector3(-3031.8318, 582.5610, 8.6883),               -- Chumash beach
        vector3(2676.9065, 3458.5823, 57.1437),              -- Sandy Shores north
        vector3(1404.1835, 3596.9846, 35.7271),              -- Sandy Shores south

        -- Misc LS
        vector3(819.5994, -201.5064, 73.7217),               -- Hawick
        vector3(-210.2987, -382.5736, 33.5398),              -- Burton north
        vector3(1203.8513, -1768.7556, 41.6065),             -- El Burro Heights
        vector3(-1654.6241, -315.3766, 51.5506),             -- Pacific Bluffs north
    },

    -- Minimum distance between pickup and destination (meters)
    minFareDistance = 500,

    -- ========================================================================
    -- QUALITY THRESHOLDS — driving quality affects tip multiplier
    -- ========================================================================
    qualityThresholds = {
        { min = 90, multiplier = 1.0 },    -- Excellent driving: full tip
        { min = 70, multiplier = 0.6 },    -- Good driving: 60% tip
        { min = 50, multiplier = 0.3 },    -- Rough driving: 30% tip
        { min = 0,  multiplier = 0.0 },    -- Terrible driving: no tip
    },

    -- ========================================================================
    -- LEVEL PROGRESSION
    -- ========================================================================
    -- XP per fare = 50. Taxi fares are individual (not batches of 10).
    -- Pay is lower per-task than pizza since fares are faster.
    levels = {
        { level = 1,  xpRequired = 0,      pay = 40,   vehicle = 'taxi' },
        { level = 2,  xpRequired = 500,    pay = 48,   vehicle = 'taxi' },
        { level = 3,  xpRequired = 1500,   pay = 56,   vehicle = 'taxi' },
        { level = 4,  xpRequired = 3000,   pay = 65,   vehicle = 'taxi' },
        { level = 5,  xpRequired = 5000,   pay = 75,   vehicle = 'emperor2' },
        { level = 6,  xpRequired = 7500,   pay = 86,   vehicle = 'emperor2' },
        { level = 7,  xpRequired = 10500,  pay = 98,   vehicle = 'emperor2' },
        { level = 8,  xpRequired = 14000,  pay = 112,  vehicle = 'schafter2' },
        { level = 9,  xpRequired = 18000,  pay = 128,  vehicle = 'schafter2' },
        { level = 10, xpRequired = 22500,  pay = 145,  vehicle = 'schafter2' },
    },

    -- Vehicle labels for UI
    vehicleLabels = {
        ['taxi']      = 'Taxi',
        ['emperor2']  = 'Emperor',
        ['schafter2'] = 'Schafter',
    },

    -- All taxi vehicles are cars — require a driver's license
    requiresLicense = {
        ['taxi']      = 'car_license',
        ['emperor2']  = 'car_license',
        ['schafter2'] = 'car_license',
    },

    -- NPC passenger models
    passengerModels = {
        'a_m_y_business_01',
        'a_f_y_tourist_01',
        'a_m_m_afriamer_01',
        'a_f_y_hipster_01',
        'a_m_y_hipster_01',
        'a_f_m_bevhills_01',
        'a_m_m_bevhills_01',
        'a_f_y_vinewood_01',
        'a_m_y_vinewood_01',
        'a_f_y_business_01',
    },
}
