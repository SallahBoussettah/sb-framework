-- ============================================================================
-- Newspaper Delivery — Job Definition
-- Loaded as shared script, registers into Config.PublicJobs
--
-- Player rides through neighborhoods throwing newspapers (WEAPON_ACIDPACKAGE)
-- at marked doorsteps. Areas are level-gated:
--   Low level  = close areas (Mirror Park, Little Seoul)
--   High level = farther areas (Grove Street, Beach)
-- Server picks a random eligible area per batch (avoids repeats).
-- ============================================================================

Config.PublicJobs['newspaper_delivery'] = {
    id = 'newspaper_delivery',
    label = 'Newspaper Delivery',
    description = 'Deliver newspapers across Los Santos by throwing them at doorsteps. Ride through neighborhoods, aim, and toss! Earn XP to unlock faster vehicles and higher pay.',
    icon = 'fa-newspaper',
    xpPerDelivery = 40,
    tipMin = 5,
    tipMax = 20,

    -- Vehicle spawn slots OUTSIDE the Job Center (shared parking spots)
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

    -- Weapon used for throwing newspapers
    weaponName = 'WEAPON_ACIDPACKAGE',

    -- Projectile detection radius (meters)
    throwRadius = 3.0,

    -- Marker drawing distance (meters)
    markerDrawDistance = 30.0,

    -- ========================================================================
    -- DELIVERY AREAS — level-gated, each with its own delivery zone
    -- ========================================================================
    areas = {
        -- ==============================================================
        -- LEVEL 1+ : Close neighborhoods (bicycle-friendly)
        -- ==============================================================
        {
            id = 'mirror_park',
            label = 'Mirror Park',
            minLevel = 1,
            locations = {
                vector3(1223.03, -696.92, 60.8),
                vector3(1229.6, -725.48, 60.95),
                vector3(1264.76, -702.82, 64.91),
                vector3(1270.91, -683.36, 66.03),
                vector3(1265.47, -647.9, 67.92),
                vector3(1240.56, -601.61, 69.78),
                vector3(1303.11, -527.98, 71.46),
                vector3(1301.16, -574.13, 71.73),
                vector3(1348.26, -547.11, 73.89),
                vector3(1388.88, -569.62, 74.5),
                vector3(1367.37, -606.3, 74.71),
                vector3(999.65, -593.97, 59.64),
            },
        },
        {
            id = 'little_seoul',
            label = 'Little Seoul',
            minLevel = 1,
            locations = {
                vector3(-668.41, -971.42, 22.35),
                vector3(-741.53, -982.28, 17.44),
                vector3(-766.38, -916.99, 21.3),
                vector3(-728.57, -879.93, 22.71),
                vector3(-716.42, -864.61, 23.2),
            },
        },

        -- ==============================================================
        -- LEVEL 3+ : Medium distance areas
        -- ==============================================================
        {
            id = 'grove_street',
            label = 'Grove Street',
            minLevel = 3,
            locations = {
                vector3(-20.61, -1858.66, 25.41),
                vector3(46.04, -1864.3, 23.28),
                vector3(56.45, -1922.61, 21.91),
                vector3(85.26, -1958.87, 21.12),
                vector3(114.14, -1960.96, 21.33),
                vector3(103.96, -1885.28, 24.32),
                vector3(170.2, -1871.74, 24.4),
            },
        },
        {
            id = 'beach_area',
            label = 'Vespucci Beach',
            minLevel = 3,
            locations = {
                vector3(-1246.52, -1182.79, 7.66),
                vector3(-1285.27, -1253.32, 4.52),
                vector3(-1225.62, -1208.05, 8.27),
                vector3(-1087.14, -1277.54, 5.84),
                vector3(-1084.37, -1559.32, 4.78),
                vector3(-988.85, -1575.71, 5.23),
            },
        },
    },

    -- Level progression (starts with Scorcher bicycle)
    -- XP per batch = 40 × area size (200-480 per batch)
    levels = {
        { level = 1,  xpRequired = 0,     pay = 60,   vehicle = 'scorcher' },
        { level = 2,  xpRequired = 300,   pay = 70,   vehicle = 'scorcher' },
        { level = 3,  xpRequired = 900,   pay = 80,   vehicle = 'bmx' },
        { level = 4,  xpRequired = 1800,  pay = 92,   vehicle = 'bmx' },
        { level = 5,  xpRequired = 3000,  pay = 105,  vehicle = 'faggio' },
        { level = 6,  xpRequired = 4500,  pay = 118,  vehicle = 'faggio' },
        { level = 7,  xpRequired = 6300,  pay = 130,  vehicle = 'faggio3' },
        { level = 8,  xpRequired = 8400,  pay = 142,  vehicle = 'faggio3' },
        { level = 9,  xpRequired = 10800, pay = 155,  vehicle = 'pcj' },
        { level = 10, xpRequired = 13500, pay = 170,  vehicle = 'pcj' },
    },

    -- Vehicle labels for UI
    vehicleLabels = {
        ['scorcher'] = 'Scorcher Bicycle',
        ['bmx']      = 'BMX',
        ['faggio']   = 'Faggio Scooter',
        ['faggio3']  = 'Faggio Sport',
        ['pcj']      = 'PCJ-600',
    },

    -- No license required — all bikes/scooters/light motorcycles
    requiresLicense = {},
}
