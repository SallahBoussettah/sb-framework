Config = {}

Config.Debug = false
Config.JobName = 'bn-mechanic'

-- ============================================================================
-- BLIP
-- ============================================================================

Config.Blip = {
    enabled = true,
    coords = vector3(-205.0, -1310.0, 30.0),
    sprite = 446,       -- Benny's wrench icon
    color = 0,          -- White
    scale = 0.8,
    label = "Benny's Original Motorworks"
}

-- ============================================================================
-- ELEVATOR (existing)
-- ============================================================================

Config.Elevators = {
    {
        id = 'bennys_main',

        -- Wall-mounted controls (outside elevator, on each floor)
        controlUp = vector3(-230.7967, -1336.4927, 30.9028),
        controlDown = vector3(-229.9368, -1336.5186, 18.4634),

        -- Cabin controls (inside elevator, on each floor)
        controlCabinUp = vector3(-228.4496, -1340.6349, 30.8932),
        controlCabinDown = vector3(-228.9453, -1340.9337, 18.5232),

        -- Platform positions (where the elevator prop sits)
        posUp = vector3(-224.9193, -1338.261, 31.28919),
        posDown = vector3(-224.9193, -1338.261, 18.8292),

        -- Spawn offset (prop visual offset of -1.396 on Z)
        spawnOffsetZ = -1.396,

        -- Elevation height (posUp.z - posDown.z)
        elevationHeight = 31.28919 - 18.8292,

        -- Elevator platform prop
        elevatorProp = 'patoche_elevatorb',
        elevatorHeading = 90.0,
        elevatorRotation = vector3(0.0, 0.0, 0.0),

        -- Door props and positions
        doorProp = 'patoche_elevatorb_door',
        doorHeading = 90.0,

        doorDownClosed = vector3(-229.3393, -1338.831, 17.53319),
        doorDownOpen = vector3(-229.3393, -1338.831, 20.05319),

        doorUpClosed = vector3(-229.3393, -1338.831, 30.00321),
        doorUpOpen = vector3(-229.3393, -1338.831, 32.48326),

        -- Interaction distances
        controlDistance = 1.0,
        cabinDistance = 0.7,
        spawnDistance = 30.0,

        -- Vehicle detection radius on platform
        vehicleDetectRadius = 5.0,

        -- Door animation steps (250 steps * 0.01 = 2.5 units vertical travel)
        doorSteps = 250,
        doorStepSize = 0.01,

        -- Elevator movement (step-based, 6 sub-steps per server sequence)
        moveStepSize = 0.01,
        moveStepWait = 5,      -- ms per step (stepped movement)
        fastMoveStepSize = 0.01,
        fastMoveStepWait = 1,  -- ms per step (fast call movement)

        -- Timings
        doorCloseWait = 3950,       -- ms to wait for door close animation
        stepPhaseWait = 2500,       -- ms per step phase on server
        arrivalDoorDelay = 500,     -- ms after arrival before opening door
        arrivalUnlockDelay = 2500,  -- ms after door open before unlocking
        autoCloseDelay = 35000,     -- ms before auto-closing door

        -- Default state
        startsUp = true,
    }
}

-- ============================================================================
-- DUTY NPC
-- ============================================================================

Config.DutyNPC = {
    model = 's_m_m_autoshop_01',
    coords = vector3(-210.4032, -1309.1689, 31.2926),
    heading = 5.9464,
    label = 'Clock In / Out',
    icon = 'fa-clipboard-check',
    distance = 2.0,
}

-- ============================================================================
-- WORK CLOTHES (locker room / changing spot)
-- ============================================================================

Config.WorkClothes = {
    -- PLACEHOLDER coords — update with real location in MLO
    coords = vector3(-203.6549, -1331.643, 23.2049), -- Near cloakroom door (lower floor)
    radius = 1.5,
    distance = 2.0,
    -- Components to apply when wearing work clothes (only these change, rest stays)
    -- Male outfit (autoshop jumpsuit style)
    male = {
        [3]  = { drawable = 11, texture = 0 },  -- Torso
        [4]  = { drawable = 98, texture = 0 },  -- Pants (cargo work pants)
        [6]  = { drawable = 25, texture = 0 },  -- Shoes (work boots)
        [8]  = { drawable = 59, texture = 0 },  -- Undershirt (tank top)
        [11] = { drawable = 251, texture = 0 }, -- Top (mechanic jumpsuit)
    },
    -- Female outfit
    female = {
        [3]  = { drawable = 3, texture = 0 },   -- Torso
        [4]  = { drawable = 57, texture = 0 },   -- Pants
        [6]  = { drawable = 25, texture = 0 },   -- Shoes
        [8]  = { drawable = 35, texture = 0 },   -- Undershirt
        [11] = { drawable = 230, texture = 0 },  -- Top
    },
}

-- ============================================================================
-- PARTS SHELF NPC
-- ============================================================================

Config.PartsShelf = {
    -- Uses sb_target on existing MLO prop at this location
    coords = vector3(-196.4526, -1314.2019, 32.3104),
    heading = 172.9084,
    label = 'Buy Parts',
    icon = 'fa-toolbox',
    distance = 2.5,
    useExistingProp = true,  -- Don't spawn a prop, target nearest object
    items = {
        { name = 'engine_parts',   label = 'Engine Parts',   price = 500 },
        { name = 'body_panel',     label = 'Body Panel',     price = 350 },
        { name = 'tire_kit',       label = 'Tire Kit',       price = 200 },
        { name = 'upgrade_kit',    label = 'Upgrade Kit',    price = 750 },
        { name = 'paint_supplies', label = 'Paint Supplies', price = 400 },
        { name = 'wash_supplies',  label = 'Wash Supplies',  price = 100 },
    }
}

-- ============================================================================
-- WORKSHOP AREA (for vehicle detection)
-- ============================================================================

Config.Workshop = {
    center = vector3(-215.5281, -1324.4028, 30.9068),
    radius = 35.0,  -- Large radius to cover both floors of the MLO
}

-- ============================================================================
-- STATIONS (4 physical locations in MLO)
-- ============================================================================

Config.Stations = {
    {
        id = 'engine',
        label = 'Engine Bay',
        icon = 'fa-engine',
        -- Target an existing MLO object model instead of sphere zone
        targetModel = 0x0DD75614,
        targetModelCoords = vector3(-242.18, -1338.64, 30.93),
        coords = vector3(-242.18, -1338.64, 30.93),  -- fallback
        radius = 1.5,
        distance = 2.5,
        requiredGrade = 0,
        -- 2 vehicle spots for engine bay
        vehicleSpots = {
            vector3(-238.4966, -1338.4095, 30.1857),
            vector3(-235.0114, -1338.1964, 30.1855),
        },
        vehicleDetectRadius = 4.0,
        -- Camera: front-quarter view, hood/engine visible, car on the right
        camera = {
            offset = vector3(1.7, 3.8, 0.5),
            pointOffset = vector3(0.0, 0.0, 0.0),
        },
    },
    {
        id = 'body',
        label = 'Body & Paint',
        icon = 'fa-spray-can',
        coords = vector3(-203.95, -1328.05, 30.97),
        radius = 1.5,
        distance = 2.0,
        requiredGrade = 0,
        vehicleSpots = {
            vector3(-201.82, -1324.82, 30.77),
        },
        vehicleDetectRadius = 5.0,
        -- Default camera (used on initial open)
        camera = {
            offset = vector3(-5.0, 3.0, 1.5),
            pointOffset = vector3(0.5, 0.0, 0.2),
        },
        -- Per-subtab cameras for body/paint station
        subCameras = {
            primary = {
                offset = vector3(-5.0, 3.0, 1.5),
                pointOffset = vector3(0.5, 0.0, 0.2),
            },
            secondary = {
                offset = vector3(5.0, 3.0, 1.5),
                pointOffset = vector3(0.5, 0.0, 0.2),
            },
            pearlescent = {
                offset = vector3(3.5, 4.5, 1.0),
                pointOffset = vector3(0.5, 0.0, 0.1),
            },
            livery = {
                offset = vector3(-6.0, 0.0, 1.8),
                pointOffset = vector3(0.5, 0.0, 0.2),
            },
        },
    },
    {
        id = 'wheels',
        label = 'Wheels & Tires',
        icon = 'fa-tire',
        coords = vector3(-240.50, -1315.60, 18.47),
        radius = 1.5,
        distance = 2.0,
        requiredGrade = 0,
        vehicleSpots = {
            vector3(-237.1338, -1315.2527, 18.4620),
        },
        vehicleDetectRadius = 4.0,
        -- Camera: low rear-quarter view, wheels visible
        camera = {
            offset = vector3(-3.5, -3.0, 0.4),
            pointOffset = vector3(0.5, 0.0, -0.2),
        },
    },
    {
        id = 'cosmetic',
        label = 'Cosmetic Shop',
        icon = 'fa-palette',
        coords = vector3(-235.12, -1306.85, 18.34),
        radius = 1.5,
        distance = 2.0,
        requiredGrade = 0,
        vehicleSpots = {
            vector3(-229.0441, -1309.0569, 18.4620),
        },
        vehicleDetectRadius = 5.0,
        -- Camera: wide 3/4 view, full car visible for cosmetic changes
        camera = {
            offset = vector3(4.0, -5.0, 1.8),
            pointOffset = vector3(0.5, 0.0, 0.3),
        },
    },
}

-- ============================================================================
-- PRICING
-- ============================================================================

Config.Pricing = {
    -- Engine Bay
    engineRepair = 800,
    bodyRepair = 600,
    engineUpgrade = 1500,   -- per level
    turbo = 5000,
    brakes = 1200,          -- per level
    transmission = 1200,    -- per level
    suspension = 1000,      -- per level
    armor = 2000,           -- per level

    -- Body & Paint
    primaryColor = 500,
    secondaryColor = 400,
    pearlescentColor = 600,
    customRGB = 1000,
    livery = 800,

    -- Wheels & Tires
    tireRepair = 150,       -- per tire
    wheelSet = 1500,
    wheelStyle = 800,

    -- Cosmetic
    neonKit = 2500,
    neonColor = 500,
    windowTint = 600,
    xenonLights = 1500,
    xenonColor = 400,
    horn = 300,
    plateStyle = 250,
    extras = 200,           -- per toggle
    interiorColor = 300,
    dashboardColor = 300,
    wash = 50,

    -- Mobile Repair
    mobileEngine = 400,
    mobileBody = 300,
    mobileTire = 100,
}

-- ============================================================================
-- REQUIRED ITEMS (consumed on service)
-- ============================================================================

Config.RequiredItems = {
    engineRepair     = { name = 'engine_parts',   count = 1 },
    bodyRepair       = { name = 'body_panel',     count = 1 },
    engineUpgrade    = { name = 'upgrade_kit',    count = 1 },
    turbo            = { name = 'upgrade_kit',    count = 1 },
    brakes           = { name = 'upgrade_kit',    count = 1 },
    transmission     = { name = 'upgrade_kit',    count = 1 },
    suspension       = { name = 'upgrade_kit',    count = 1 },
    armor            = { name = 'upgrade_kit',    count = 1 },
    paint            = { name = 'paint_supplies', count = 1 },
    tireRepair       = { name = 'tire_kit',       count = 1 },
    wheelSet         = { name = 'tire_kit',       count = 1 },
    wash             = { name = 'wash_supplies',  count = 1 },
    mobileEngine     = { name = 'engine_parts',   count = 1 },
    mobileBody       = { name = 'body_panel',     count = 1 },
    mobileTire       = { name = 'tire_kit',       count = 1 },
}

-- ============================================================================
-- BILLING LAPTOP (for sending invoices)
-- ============================================================================

Config.BillingLaptop = {
    model = 'prop_laptop_lester2',  -- Laptop prop
    coords = vector3(-211.5, -1312.0, 31.29),  -- PLACEHOLDER — update with real MLO location
    heading = 270.0,
    distance = 2.0,
    label = 'Open Billing',
    icon = 'fa-laptop',
}

-- ============================================================================
-- MOBILE REPAIR
-- ============================================================================

Config.MobileRepair = {
    maxEngineHealth = 800,  -- vs 1000 at workshop
    maxBodyHealth = 800,
    distance = 3.0,         -- how close to vehicle
}

-- ============================================================================
-- SERVICE ANIMATIONS (used by both station and mobile repair)
-- ============================================================================

Config.ServiceAnimations = {
    engine = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49,
        prop = { model = 'prop_tool_wrench', bone = 57005 },
        duration = 10000,
        label = 'Repairing Engine...',
        openHood = true,
    },
    body = {
        dict = 'amb@world_human_welding@male@base',
        anim = 'base',
        flag = 49,
        prop = { model = 'prop_weld_torch', bone = 57005 },
        duration = 10000,
        label = 'Repairing Body...',
    },
    upgrade = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49,
        prop = { model = 'prop_tool_wrench', bone = 57005 },
        duration = 12000,
        label = 'Installing Upgrade...',
        openHood = true,
    },
    paint = {
        dict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flag = 49,
        prop = { model = 'prop_cs_spray_can', bone = 57005 },
        duration = 8000,
        label = 'Applying Paint...',
    },
    tire = {
        dict = 'amb@world_human_vehicle_mechanic@male@base',
        anim = 'base',
        flag = 49,
        prop = { model = 'prop_tool_wrench', bone = 57005 },
        duration = 8000,
        label = 'Fixing Tire...',
    },
    wheels = {
        dict = 'amb@world_human_vehicle_mechanic@male@base',
        anim = 'base',
        flag = 49,
        prop = { model = 'prop_tool_wrench', bone = 57005 },
        duration = 12000,
        label = 'Changing Wheels...',
    },
    cosmetic = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49,
        prop = { model = 'prop_tool_wrench', bone = 57005 },
        duration = 8000,
        label = 'Installing...',
    },
    neon = {
        dict = 'amb@world_human_vehicle_mechanic@male@base',
        anim = 'base',
        flag = 49,
        prop = { model = 'prop_cs_hand_torch', bone = 57005 },
        duration = 10000,
        label = 'Installing Neon...',
    },
    xenon = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49,
        prop = { model = 'prop_tool_wrench', bone = 57005 },
        duration = 8000,
        label = 'Installing Xenon Lights...',
        openHood = true,
    },
    wash = {
        dict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flag = 49,
        duration = 6000,
        label = 'Washing Vehicle...',
    },
}

-- ============================================================================
-- MOD LABELS (for NUI display)
-- ============================================================================

Config.ModLabels = {
    [11] = { label = 'Engine',       icon = 'fa-engine' },
    [12] = { label = 'Brakes',       icon = 'fa-brake-disc' },
    [13] = { label = 'Transmission', icon = 'fa-gears' },
    [15] = { label = 'Suspension',   icon = 'fa-car-side' },
    [16] = { label = 'Armor',        icon = 'fa-shield' },
}

-- ============================================================================
-- WHEEL TYPES
-- ============================================================================

Config.WheelTypes = {
    { id = 0,  label = 'Sport' },
    { id = 1,  label = 'Muscle' },
    { id = 2,  label = 'Lowrider' },
    { id = 3,  label = 'SUV' },
    { id = 4,  label = 'Offroad' },
    { id = 5,  label = 'Tuner' },
    { id = 6,  label = 'Biker' },
    { id = 7,  label = 'High End' },
    { id = 8,  label = 'Benny\'s Originals' },
    { id = 9,  label = 'Benny\'s Bespoke' },
    { id = 10, label = 'Open Wheel' },
    { id = 11, label = 'Street' },
    { id = 12, label = 'Track' },
}

-- ============================================================================
-- GTA PRESET COLORS (index -> hex for NUI display)
-- ============================================================================

Config.GtaColors = {
    -- Metallics
    { id = 0,   label = 'Black',            hex = '#0d1116' },
    { id = 1,   label = 'Graphite',         hex = '#1c1d21' },
    { id = 2,   label = 'Black Steel',      hex = '#32383d' },
    { id = 3,   label = 'Dark Silver',      hex = '#454b4f' },
    { id = 4,   label = 'Silver',           hex = '#969a97' },
    { id = 5,   label = 'Blue Silver',      hex = '#c2c4c6' },
    { id = 6,   label = 'Rolled Steel',     hex = '#979a97' },
    { id = 7,   label = 'Shadow Silver',    hex = '#637380' },
    { id = 8,   label = 'Stone Silver',     hex = '#63625c' },
    { id = 9,   label = 'Midnight Silver',  hex = '#3e3e42' },
    { id = 10,  label = 'Cast Iron Silver', hex = '#4a4f54' },
    { id = 11,  label = 'Anthracite Black', hex = '#1d2129' },
    -- Reds
    { id = 27,  label = 'Red',              hex = '#c00e1a' },
    { id = 28,  label = 'Torino Red',       hex = '#da1918' },
    { id = 29,  label = 'Formula Red',      hex = '#b6111b' },
    { id = 30,  label = 'Lava Red',         hex = '#a51e23' },
    { id = 31,  label = 'Blaze Red',        hex = '#a5282c' },
    { id = 32,  label = 'Grace Red',        hex = '#7b1a22' },
    { id = 33,  label = 'Garnet Red',       hex = '#8b1a1f' },
    { id = 34,  label = 'Sunset Red',       hex = '#6f1b1e' },
    { id = 35,  label = 'Cabernet Red',     hex = '#49111d' },
    { id = 143, label = 'Candy Red',        hex = '#b4191e' },
    -- Oranges
    { id = 36,  label = 'Orange',           hex = '#d66b15' },
    { id = 38,  label = 'Gold',             hex = '#c2944e' },
    { id = 99,  label = 'Bronze',           hex = '#5c3a2e' },
    -- Yellows
    { id = 42,  label = 'Yellow',           hex = '#fce620' },
    { id = 88,  label = 'Race Yellow',      hex = '#d7a935' },
    { id = 89,  label = 'Bronze',           hex = '#917347' },
    -- Greens
    { id = 49,  label = 'Green',            hex = '#418843' },
    { id = 50,  label = 'Racing Green',     hex = '#24362a' },
    { id = 51,  label = 'Sea Green',        hex = '#2b5944' },
    { id = 52,  label = 'Olive Green',      hex = '#3b4a30' },
    { id = 53,  label = 'Bright Green',     hex = '#47783c' },
    { id = 54,  label = 'Gasoline Green',   hex = '#3e5c40' },
    -- Blues
    { id = 61,  label = 'Galaxy Blue',      hex = '#2b3a5a' },
    { id = 62,  label = 'Dark Blue',        hex = '#1e2852' },
    { id = 63,  label = 'Saxon Blue',       hex = '#1f3071' },
    { id = 64,  label = 'Blue',             hex = '#253aa7' },
    { id = 65,  label = 'Mariner Blue',     hex = '#1c3551' },
    { id = 66,  label = 'Harbor Blue',      hex = '#2c5089' },
    { id = 67,  label = 'Diamond Blue',     hex = '#6ea3c6' },
    { id = 68,  label = 'Surf Blue',        hex = '#7ec6c5' },
    { id = 69,  label = 'Nautical Blue',    hex = '#2f3f4f' },
    { id = 73,  label = 'Ultra Blue',       hex = '#0b4d8e' },
    { id = 74,  label = 'Light Blue',       hex = '#6fb0d8' },
    -- Purples
    { id = 71,  label = 'Bright Purple',    hex = '#6b1f7f' },
    { id = 72,  label = 'Purple',           hex = '#3b1570' },
    { id = 142, label = 'Midnight Purple',  hex = '#281e32' },
    -- Whites
    { id = 111, label = 'White',            hex = '#f0f0f0' },
    { id = 112, label = 'Frost White',      hex = '#dfe0e2' },
    -- Browns
    { id = 90,  label = 'Light Brown',      hex = '#7e543b' },
    { id = 95,  label = 'Dark Brown',       hex = '#402e2a' },
    { id = 96,  label = 'Straw Brown',      hex = '#6b5e4f' },
    -- Matte Colors
    { id = 12,  label = 'Matte Black',      hex = '#151921' },
    { id = 13,  label = 'Matte Gray',       hex = '#3c3f47' },
    { id = 14,  label = 'Matte Light Gray', hex = '#8a8e91' },
    { id = 39,  label = 'Matte Red',        hex = '#c21e23' },
    { id = 40,  label = 'Matte Dark Red',   hex = '#6c1d20' },
    { id = 41,  label = 'Matte Orange',     hex = '#d95821' },
    { id = 42,  label = 'Matte Yellow',     hex = '#f4e82d' },
    { id = 55,  label = 'Matte Lime',       hex = '#58a840' },
    { id = 128, label = 'Matte Green',      hex = '#3a6247' },
    { id = 129, label = 'Matte Forest',     hex = '#3a5c38' },
    { id = 140, label = 'Matte Blue',       hex = '#243b67' },
    { id = 141, label = 'Matte Midnight',   hex = '#0f1c3f' },
    { id = 145, label = 'Matte Purple',     hex = '#460b54' },
    { id = 146, label = 'Matte Dark Purple',hex = '#2a0f39' },
    -- Chrome
    { id = 120, label = 'Chrome',           hex = '#dfdfdf' },
}

-- ============================================================================
-- WINDOW TINT OPTIONS
-- ============================================================================

Config.WindowTints = {
    { id = 0, label = 'None' },
    { id = 1, label = 'Pure Black' },
    { id = 2, label = 'Dark Smoke' },
    { id = 3, label = 'Light Smoke' },
    { id = 4, label = 'Stock' },
    { id = 5, label = 'Limo' },
    { id = 6, label = 'Green' },
}

-- ============================================================================
-- XENON COLOR OPTIONS
-- ============================================================================

Config.XenonColors = {
    { id = -1, label = 'Default White' },
    { id = 0,  label = 'White' },
    { id = 1,  label = 'Blue' },
    { id = 2,  label = 'Electric Blue' },
    { id = 3,  label = 'Mint Green' },
    { id = 4,  label = 'Lime Green' },
    { id = 5,  label = 'Yellow' },
    { id = 6,  label = 'Golden Shower' },
    { id = 7,  label = 'Orange' },
    { id = 8,  label = 'Red' },
    { id = 9,  label = 'Pony Pink' },
    { id = 10, label = 'Hot Pink' },
    { id = 11, label = 'Purple' },
    { id = 12, label = 'Blacklight' },
}

-- ============================================================================
-- HORN OPTIONS
-- ============================================================================

Config.Horns = {
    { id = -1, label = 'Stock Horn' },
    { id = 0,  label = 'Truck Horn' },
    { id = 1,  label = 'Cop Horn' },
    { id = 2,  label = 'Clown Horn' },
    { id = 3,  label = 'Musical Horn 1' },
    { id = 4,  label = 'Musical Horn 2' },
    { id = 5,  label = 'Musical Horn 3' },
    { id = 6,  label = 'Musical Horn 4' },
    { id = 7,  label = 'Musical Horn 5' },
    { id = 8,  label = 'Sad Trombone' },
    { id = 9,  label = 'Classical Horn 1' },
    { id = 10, label = 'Classical Horn 2' },
    { id = 11, label = 'Classical Horn 3' },
    { id = 12, label = 'Classical Horn 4' },
    { id = 13, label = 'Classical Horn 5' },
    { id = 14, label = 'Classical Horn 6' },
    { id = 15, label = 'Classical Horn 7' },
}

-- ============================================================================
-- PLATE STYLE OPTIONS
-- ============================================================================

Config.PlateStyles = {
    { id = 0, label = 'Blue on White 1' },
    { id = 1, label = 'Yellow on Black' },
    { id = 2, label = 'Yellow on Blue' },
    { id = 3, label = 'Blue on White 2' },
    { id = 4, label = 'Blue on White 3' },
    { id = 5, label = 'Yankton' },
}
