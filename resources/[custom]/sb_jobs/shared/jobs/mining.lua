-- ============================================================================
-- Mining — Job Definition
-- Loaded as shared script, registers into Config.PublicJobs
--
-- Solo public job: player drives to mining sites across San Andreas and
-- mines raw materials from rock/ore nodes. Materials are sold at company
-- receiving docks (sb_companies) for cash.
-- Mining uses sb_minigame (timing type) with difficulty scaling by tier.
-- ============================================================================

Config.PublicJobs['mining'] = {
    id = 'mining',
    label = 'Miner',
    description = 'Mine raw materials from sites across San Andreas and sell them to companies. Earn XP to unlock rarer resources and higher-paying sites.',
    icon = 'fa-gem',
    xpPerDelivery = 50,
    tipMin = 10,
    tipMax = 30,
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
    -- MINING CONFIG
    -- ========================================================================

    -- How many nodes to assign per batch (site visit)
    nodesPerBatch = 15,

    -- Interaction radius for mining nodes
    interactRadius = 2.0,

    -- Mining animation
    miningAnim = { dict = 'melee@large_wpn@streamed_core', anim = 'ground_attack_on_spot' },
    miningDuration = 6000,      -- ms, progress bar duration per node

    -- Minigame config (timing type from sb_minigame)
    minigame = {
        type = 'timing',
        -- Difficulty scales per resource tier (1-3)
        difficulties = {
            [1] = { speed = 1.0, zones = 3, targetSize = 0.25 },   -- Easy (tier 1 ores)
            [2] = { speed = 1.4, zones = 4, targetSize = 0.20 },   -- Medium (tier 2 ores)
            [3] = { speed = 1.8, zones = 5, targetSize = 0.15 },   -- Hard (tier 3 rare ores)
        },
    },

    -- Node outline color (orange glow)
    nodeOutlineColor = { r = 255, g = 165, b = 0, a = 200 },

    -- Ore carry prop (attached to back/hand)
    oreCarryProp = 'prop_rock_1_a',

    -- Anti-abuse
    offRouteDistance = 600.0,
    offRouteWarnTime = 30.0,
    offRouteConfiscateTime = 60.0,

    -- ========================================================================
    -- RESOURCE TIERS
    -- Tier determines: minigame difficulty, required level, sell value
    -- ========================================================================
    resourceTiers = {
        -- Tier 1: Common metals & basics (Level 1+)
        raw_iron            = { tier = 1, label = 'Iron Ore',           yield = {2, 4}, sellPrice = 35 },
        raw_steel           = { tier = 1, label = 'Steel Scrap',        yield = {2, 4}, sellPrice = 30 },
        raw_lead            = { tier = 1, label = 'Lead Ore',           yield = {2, 3}, sellPrice = 18 },
        raw_zinc            = { tier = 1, label = 'Zinc Ore',           yield = {2, 3}, sellPrice = 22 },
        raw_rubber          = { tier = 1, label = 'Raw Rubber',         yield = {2, 3}, sellPrice = 22 },
        raw_oil             = { tier = 1, label = 'Crude Oil',          yield = {3, 5}, sellPrice = 15 },
        raw_plastic         = { tier = 1, label = 'Plastic Scrap',      yield = {2, 4}, sellPrice = 15 },
        raw_sandpaper       = { tier = 1, label = 'Sandpaper Grit',     yield = {2, 3}, sellPrice = 10 },

        -- Tier 2: Refined metals & specialty (Level 3+)
        raw_copper          = { tier = 2, label = 'Copper Ore',         yield = {1, 3}, sellPrice = 50 },
        raw_aluminum        = { tier = 2, label = 'Aluminum Ore',       yield = {1, 3}, sellPrice = 40 },
        raw_chrome          = { tier = 2, label = 'Chrome Ore',         yield = {1, 2}, sellPrice = 65 },
        raw_bearing_steel   = { tier = 2, label = 'Bearing Steel',      yield = {1, 2}, sellPrice = 55 },
        raw_glass           = { tier = 2, label = 'Raw Silica Glass',   yield = {1, 3}, sellPrice = 35 },
        raw_electrode       = { tier = 2, label = 'Electrode Rods',     yield = {1, 2}, sellPrice = 28 },
        raw_friction_material = { tier = 2, label = 'Friction Material', yield = {1, 2}, sellPrice = 32 },
        raw_gasket_material = { tier = 2, label = 'Gasket Material',    yield = {1, 2}, sellPrice = 25 },
        raw_glycol          = { tier = 2, label = 'Ethylene Glycol',    yield = {1, 3}, sellPrice = 18 },
        raw_filter_media    = { tier = 2, label = 'Filter Media',       yield = {1, 3}, sellPrice = 18 },

        -- Tier 3: Rare & high-value (Level 5+)
        raw_titanium        = { tier = 3, label = 'Titanium Ore',       yield = {1, 1}, sellPrice = 200 },
        raw_carbon          = { tier = 3, label = 'Carbon Fiber',       yield = {1, 1}, sellPrice = 150 },
        raw_kevlar          = { tier = 3, label = 'Kevlar Thread',      yield = {1, 1}, sellPrice = 170 },
        raw_silicon         = { tier = 3, label = 'Raw Silicon',        yield = {1, 2}, sellPrice = 75 },
        raw_circuit_board   = { tier = 3, label = 'Circuit Board Scrap', yield = {1, 2}, sellPrice = 85 },
        raw_magnet          = { tier = 3, label = 'Rare Earth Magnets', yield = {1, 1}, sellPrice = 65 },
        raw_ceramic         = { tier = 3, label = 'Raw Ceramic',        yield = {1, 2}, sellPrice = 40 },
    },

    -- ========================================================================
    -- MINING SITES — 5 sites with node layouts
    -- Each site has a center, radius, and a table of resources available there
    -- Nodes are spawned procedurally within the radius using random placement
    -- ========================================================================
    sites = {
        -- Site 1: Davis Quartz Quarry (Level 1+) — Open quarry, basic metals
        {
            id = 'davis_quarry',
            label = 'Davis Quartz Quarry',
            center = vector3(2954.17, 2774.34, 39.12),
            radius = 80.0,
            requiredLevel = 1,
            resources = { 'raw_iron', 'raw_steel', 'raw_lead', 'raw_zinc', 'raw_sandpaper' },
            nodeProp = 'prop_rock_4_a',
        },

        -- Site 2: El Burro Scrapyard (Level 1+) — Junkyard, rubber/plastic/oil
        {
            id = 'elburro_scrap',
            label = 'El Burro Scrapyard',
            center = vector3(1646.52, -1537.23, 87.96),
            radius = 60.0,
            requiredLevel = 1,
            resources = { 'raw_rubber', 'raw_plastic', 'raw_oil', 'raw_iron', 'raw_steel' },
            nodeProp = 'prop_rub_pile_03',
        },

        -- Site 3: Raton Canyon Mine (Level 3+) — Mountain mine, medium metals
        {
            id = 'raton_mine',
            label = 'Raton Canyon Mine',
            center = vector3(-560.12, 4434.56, 96.23),
            radius = 90.0,
            requiredLevel = 3,
            resources = { 'raw_copper', 'raw_aluminum', 'raw_chrome', 'raw_bearing_steel', 'raw_glass', 'raw_electrode' },
            nodeProp = 'prop_rock_4_b',
        },

        -- Site 4: Paleto Chemical Works (Level 3+) — Chemical plant area
        {
            id = 'paleto_chem',
            label = 'Paleto Chemical Works',
            center = vector3(-278.34, 6226.78, 31.49),
            radius = 70.0,
            requiredLevel = 3,
            resources = { 'raw_glycol', 'raw_filter_media', 'raw_friction_material', 'raw_gasket_material', 'raw_electrode' },
            nodeProp = 'prop_barrel_03a',
        },

        -- Site 5: Mount Chiliad Deep Mine (Level 5+) — Rare materials
        {
            id = 'chiliad_deep',
            label = 'Mt. Chiliad Deep Mine',
            center = vector3(501.87, 5604.12, 798.23),
            radius = 100.0,
            requiredLevel = 5,
            resources = { 'raw_titanium', 'raw_carbon', 'raw_kevlar', 'raw_silicon', 'raw_circuit_board', 'raw_magnet', 'raw_ceramic' },
            nodeProp = 'prop_rock_4_c',
        },
    },

    -- ========================================================================
    -- LEVEL PROGRESSION
    -- ========================================================================
    -- All levels use Bison (utility van). Pay is per-node bonus on top of
    -- the ore's sell value. XP per node = 50.
    levels = {
        { level = 1,  xpRequired = 0,      pay = 30,  vehicle = 'bison' },
        { level = 2,  xpRequired = 500,    pay = 40,  vehicle = 'bison' },
        { level = 3,  xpRequired = 1500,   pay = 55,  vehicle = 'bison' },
        { level = 4,  xpRequired = 3500,   pay = 70,  vehicle = 'bison' },
        { level = 5,  xpRequired = 7000,   pay = 85,  vehicle = 'bison' },
        { level = 6,  xpRequired = 12000,  pay = 105, vehicle = 'bison' },
        { level = 7,  xpRequired = 18000,  pay = 130, vehicle = 'bison' },
    },

    -- Vehicle labels for UI
    vehicleLabels = {
        ['bison'] = 'Bison',
    },

    -- Bison requires car license
    requiresLicense = {
        ['bison'] = 'car_license',
    },
}
