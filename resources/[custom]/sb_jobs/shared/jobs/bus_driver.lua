-- ============================================================================
-- Bus Driver — Job Definition
-- Loaded as shared script, registers into Config.PublicJobs
--
-- Players drive bus routes with 8-12 sequential stops, picking up and
-- dropping off real NPC passengers. Pay includes base + per-passenger bonus
-- + on-time bonus + random tip.
-- ============================================================================

Config.PublicJobs['bus_driver'] = {
    id = 'bus_driver',
    label = 'Bus Driver',
    description = 'Drive bus routes across Los Santos, picking up and dropping off passengers at each stop. Earn XP to unlock bigger coaches and higher fares!',
    icon = 'fa-bus',
    xpPerDelivery = 50,
    tipMin = 5,
    tipMax = 25,
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
    -- BUS-SPECIFIC CONFIG
    -- ========================================================================

    -- Per-passenger bonus added to tip
    perPassengerBonus = 8,

    -- On-time bonus per passenger (if route completed under par time)
    onTimeBonus = 5,

    -- Stop proximity radius (meters)
    stopRadius = 12.0,

    -- Speed threshold to consider "stopped" (m/s)
    speedThreshold = 1.5,

    -- Passengers per stop range
    minPassengersPerStop = 1,
    maxPassengersPerStop = 4,

    -- Chance of an empty stop (0.0 to 1.0)
    emptyStopChance = 0.30,

    -- NPC spawn distance from stop (meters)
    npcSpawnDistance = 15.0,

    -- NPC board timeout before fallback teleport (ms)
    boardTimeout = 15000,

    -- NPC walk-away distance after exiting (meters)
    npcWalkAwayDistance = 25.0,

    -- NPC delete delay after walking away (ms)
    npcDeleteDelay = 5000,

    -- Fuel: bus starts full, consumes fuel 40% slower than normal
    startFuel = 100.0,
    fuelMultiplier = 0.4, -- applied via Entity state bag to sb_fuel

    -- Shift cycle: after this many routes, must return and cooldown
    maxRoutesPerCycle = 10,
    cooldownSeconds = 600, -- 10 minutes

    -- Anti-abuse: off-route distance and timers
    offRouteDistance = 400.0,
    offRouteWarnTime = 30.0,
    offRouteConfiscateTime = 60.0,

    -- Usable seat indices per vehicle type
    vehicleSeats = {
        ['bus']      = { 1, 2, 3, 4, 5, 6, 7, 8 },
        ['coach']    = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
    },

    -- ========================================================================
    -- ROUTES — 6 routes with 8-12 stops each
    -- All coordinates are PLACEHOLDERS — fill in with real coords later
    -- ========================================================================
    routes = {
        -- Route 1: Downtown Loop (8 stops)
        {
            id = 'downtown_loop',
            label = 'Downtown Loop',
            parTime = 480, -- seconds
            stops = {
                { label = 'Legion Square',           coords = vector4(244.2069, -944.4742, 29.2474, 0) },
                { label = 'Pillbox Hill',             coords = vector4(371.4265, -841.5422, 29.1565, 0) },
                { label = 'Alta Street',              coords = vector4(237.0, -1210.0, 29.0, 100.0) },
                { label = 'Textile City',             coords = vector4(-256.0, -685.0, 33.0, 350.0) },
                { label = 'Burton',                   coords = vector4(-465.0, -360.0, 34.0, 170.0) },
                { label = 'Little Seoul',             coords = vector4(-716.0, -825.0, 23.0, 180.0) },
                { label = 'Strawberry Ave',           coords = vector4(28.0, -1354.0, 29.0, 177.0) },
                { label = 'Legion Square (Return)',   coords = vector4(244.2069, -944.4742, 29.2474, 0) },
            },
        },

        -- Route 2: Vinewood Express (10 stops)
        {
            id = 'vinewood_express',
            label = 'Vinewood Express',
            parTime = 540, -- seconds
            stops = {
                { label = 'Downtown LS',              coords = vector4(-62.0, -781.0, 44.0, 310.0) },
                { label = 'Hawick',                   coords = vector4(819.0, -201.0, 74.0, 322.0) },
                { label = 'East Vinewood',            coords = vector4(592.0, 72.0, 93.0, 164.0) },
                { label = 'Vinewood Blvd',            coords = vector4(340.0, 163.0, 103.0, 168.0) },
                { label = 'West Vinewood',            coords = vector4(-643.0, 65.0, 46.0, 76.0) },
                { label = 'Burton',                   coords = vector4(-465.0, -360.0, 34.0, 170.0) },
                { label = 'Rockford Plaza',           coords = vector4(-718.0, -162.0, 37.0, 141.0) },
                { label = 'Del Perro',                coords = vector4(-1446.0, -944.0, 10.0, 236.0) },
                { label = 'Little Seoul',             coords = vector4(-500.0, -645.0, 33.0, 184.0) },
                { label = 'Downtown LS (Return)',     coords = vector4(-62.0, -781.0, 44.0, 310.0) },
            },
        },

        -- Route 3: Airport Shuttle (8 stops)
        {
            id = 'airport_shuttle',
            label = 'Airport Shuttle',
            parTime = 480, -- seconds
            stops = {
                { label = 'LSIA Terminal',            coords = vector4(-812.0, -2314.0, 13.0, 307.0) },
                { label = 'LSIA South',               coords = vector4(-1032.0, -2728.0, 14.0, 329.0) },
                { label = 'LSIA North Parking',       coords = vector4(-865.0, -2260.0, 9.0, 319.0) },
                { label = 'Vespucci Canals',          coords = vector4(-1122.0, -1516.0, 4.0, 118.0) },
                { label = 'Del Perro Pier',           coords = vector4(-1811.0, -635.0, 11.0, 310.0) },
                { label = 'Little Seoul Transit',     coords = vector4(-500.0, -645.0, 33.0, 184.0) },
                { label = 'Strawberry',               coords = vector4(423.0, -1622.0, 29.0, 310.0) },
                { label = 'LSIA Terminal (Return)',   coords = vector4(-812.0, -2314.0, 13.0, 307.0) },
            },
        },

        -- Route 4: East Side Line (10 stops)
        {
            id = 'east_side_line',
            label = 'East Side Line',
            parTime = 600, -- seconds
            stops = {
                { label = 'Pillbox Hill',             coords = vector4(312.0, -1382.0, 32.0, 56.0) },
                { label = 'La Mesa',                  coords = vector4(900.0, -1079.0, 32.0, 179.0) },
                { label = 'Mirror Park',              coords = vector4(1179.0, -442.0, 67.0, 261.0) },
                { label = 'Mirror Park South',        coords = vector4(954.0, -644.0, 58.0, 0.0) },
                { label = 'El Burro Heights',         coords = vector4(1204.0, -1769.0, 42.0, 351.0) },
                { label = 'Rancho',                   coords = vector4(104.0, -1953.0, 21.0, 357.0) },
                { label = 'Davis',                    coords = vector4(493.0, -1881.0, 26.0, 294.0) },
                { label = 'Strawberry',               coords = vector4(413.0, -1728.0, 30.0, 51.0) },
                { label = 'South LS',                 coords = vector4(-176.0, -1674.0, 33.0, 88.0) },
                { label = 'Pillbox Hill (Return)',    coords = vector4(312.0, -1382.0, 32.0, 56.0) },
            },
        },

        -- Route 5: Beach & Coast (12 stops)
        {
            id = 'beach_coast',
            label = 'Beach & Coast',
            parTime = 660, -- seconds
            stops = {
                { label = 'Del Perro Pier',           coords = vector4(-1811.0, -635.0, 11.0, 310.0) },
                { label = 'Pacific Bluffs',           coords = vector4(-1433.0, 176.0, 56.0, 236.0) },
                { label = 'Pacific Bluffs North',     coords = vector4(-1655.0, -315.0, 52.0, 213.0) },
                { label = 'Richman',                  coords = vector4(-847.0, 462.0, 88.0, 100.0) },
                { label = 'Vinewood Hills',           coords = vector4(-178.0, 504.0, 137.0, 12.0) },
                { label = 'West Vinewood',            coords = vector4(-643.0, 65.0, 46.0, 76.0) },
                { label = 'Rockford Plaza',           coords = vector4(-718.0, -162.0, 37.0, 141.0) },
                { label = 'Del Perro Mall',           coords = vector4(-1232.0, -901.0, 12.0, 37.0) },
                { label = 'Vespucci Beach',           coords = vector4(-1605.0, -944.0, 15.0, 260.0) },
                { label = 'Vespucci Canals',          coords = vector4(-1189.0, -1519.0, 6.0, 251.0) },
                { label = 'Del Perro Club',           coords = vector4(-1391.0, -585.0, 30.0, 47.0) },
                { label = 'Del Perro Pier (Return)',  coords = vector4(-1811.0, -635.0, 11.0, 310.0) },
            },
        },

        -- Route 6: Blaine County Express (10 stops)
        {
            id = 'blaine_county',
            label = 'Blaine County Express',
            parTime = 720, -- seconds
            stops = {
                { label = 'Downtown LS',              coords = vector4(-62.0, -781.0, 44.0, 310.0) },
                { label = 'Hawick',                   coords = vector4(819.0, -201.0, 74.0, 322.0) },
                { label = 'Tataviam Mountains',       coords = vector4(2562.0, 385.0, 109.0, 273.0) },
                { label = 'Sandy Shores South',       coords = vector4(1404.0, 3597.0, 36.0, 207.0) },
                { label = 'Sandy Shores',             coords = vector4(1853.0, 3746.0, 33.0, 127.0) },
                { label = 'Sandy Shores East',        coords = vector4(2685.0, 3280.0, 55.0, 228.0) },
                { label = 'Grapeseed',                coords = vector4(1682.0, 4940.0, 42.0, 58.0) },
                { label = 'Paleto Bay',               coords = vector4(-321.0, 6072.0, 31.0, 227.0) },
                { label = 'Chumash',                  coords = vector4(-3156.0, 1096.0, 21.0, 249.0) },
                { label = 'Downtown LS (Return)',     coords = vector4(-62.0, -781.0, 44.0, 310.0) },
            },
        },
    },

    -- ========================================================================
    -- LEVEL PROGRESSION
    -- ========================================================================
    -- XP per route = 50. Bus (L1-5), Coach (L6-10).
    -- Pay is base salary per route; passenger bonuses are added as tip.
    levels = {
        { level = 1,  xpRequired = 0,      pay = 60,   vehicle = 'bus' },
        { level = 2,  xpRequired = 500,    pay = 75,   vehicle = 'bus' },
        { level = 3,  xpRequired = 1500,   pay = 90,   vehicle = 'bus' },
        { level = 4,  xpRequired = 3000,   pay = 105,  vehicle = 'bus' },
        { level = 5,  xpRequired = 5000,   pay = 115,  vehicle = 'bus' },
        { level = 6,  xpRequired = 7500,   pay = 140,  vehicle = 'coach' },
        { level = 7,  xpRequired = 10500,  pay = 165,  vehicle = 'coach' },
        { level = 8,  xpRequired = 14000,  pay = 190,  vehicle = 'coach' },
        { level = 9,  xpRequired = 18000,  pay = 220,  vehicle = 'coach' },
        { level = 10, xpRequired = 22500,  pay = 245,  vehicle = 'coach' },
    },

    -- Vehicle labels for UI
    vehicleLabels = {
        ['bus']   = 'City Bus',
        ['coach'] = 'Coach',
    },

    -- All bus vehicles require a driver's license
    requiresLicense = {
        ['bus']   = 'car_license',
        ['coach'] = 'car_license',
    },

    -- NPC passenger models (taxi's 10 + 4 more for variety)
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
        'a_m_y_soucent_01',
        'a_f_y_soucent_01',
        'a_m_m_eastsa_01',
        'a_f_m_fatwhite_01',
    },
}
