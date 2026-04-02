Config = {}

-- ============================================================================
-- TIME CONVERSION
-- ============================================================================
Config.MonthToSeconds = 30          -- 1 penal code month = 30 real seconds
Config.ShortSentenceThreshold = 900 -- < 15min real time = MRPD cells, >= 15min = Bolingbroke

-- ============================================================================
-- BOOKING TERMINAL (MRPD) — PC + Holding Area
-- ============================================================================

-- The PC the officer interacts with to open the dashboard
Config.BookingPC = {
    coords = vector3(474.02, -1010.76, 22.34),
    width = 2.5,
    length = 2.5,
    height = 2.0,
    heading = 90.189,
}

-- The holding area — covers the entire booking room
-- Any cuffed player/NPC inside this radius is detected as the suspect
Config.HoldingArea = {
    coords = vector3(476.1765, -1009.7428, 21.9497),
    radius = 8.0,   -- covers the full booking room
}

-- ON HOLD HUD text (displayed for prisoners awaiting transport)
Config.OnHoldHUD = {
    x = 0.5,
    y = 0.06,
    scale = 0.6,
    font = 4,
    color = { r = 255, g = 165, b = 0, a = 255 },
    text = '~o~ON HOLD ~w~- Awaiting Transport',
}

-- ============================================================================
-- MUGSHOT CAMERA STATION — Fixed camera, rotate + zoom only
-- ============================================================================

-- Where the officer interacts to open the camera (prop/spot near height board)
Config.MugshotStation = {
    coords = vector3(474.41, -1009.62, 23.72),
    width = 2.5,
    length = 2.5,
    height = 2.0,
    heading = 270.85,
}

-- The fixed camera position + initial rotation
Config.MugshotCam = {
    camPos = vector3(474.41, -1009.62, 22.72),
    initialRot = vector3(-5.0, 0.0, 270.85),   -- slight down pitch, facing same heading as prop

    -- Rotation limits
    rotSpeed = 0.5,             -- degrees per frame (slower = more precise)
    minPitch = -30.0,           -- max look down
    maxPitch = 15.0,            -- max look up
    headingRange = 90.0,        -- +/- 90 degrees from initial heading (total 180)

    -- Zoom
    defaultFov = 50.0,
    minFov = 15.0,
    maxFov = 80.0,
    zoomStep = 2.0,
}

-- ============================================================================
-- MRPD CELLS
-- ============================================================================
Config.MRPD = {
    -- Cell spawn positions (used for reconnect placement only)
    cellSpawns = {
        vector4(488.7525, -995.6929, 21.1494, 0.0),
        vector4(495.6721, -995.8752, 21.1494, 0.0),
        vector4(502.73, -999.14, 21.15, 180.0),
        vector4(504.78, -1005.53, 21.15, 180.0),
        vector4(501.96, -1012.01, 21.15, 270.0),
        vector4(495.19, -1015.23, 21.15, 270.0),
        vector4(488.61, -1014.91, 21.15, 90.0),
    },
    -- Release point (front door of MRPD)
    releasePoint = vector4(431.39, -981.14, 30.71, 180.0),
}

-- ============================================================================
-- BOLINGBROKE PENITENTIARY
-- ============================================================================
Config.Bolingbroke = {
    -- Arrival/entrance zone (where transport vehicle arrives)
    entrance = {
        coords = vector3(1695.87, 2588.21, 45.92),
        radius = 5.0,  -- Check-in zone near intake NPC
    },
    -- Yard spawn (where prisoners go after intake completes)
    yardSpawn = vector4(1696.727, 2565.864, 45.564, 170.0),
    -- Release gate
    releasePoint = vector4(1833.82, 2584.97, 45.89, 271.249),
    -- Map blip
    blip = {
        coords = vector3(1696.727, 2565.864, 45.564),
        sprite = 188,
        color = 1,
        scale = 0.8,
        label = 'Bolingbroke Penitentiary'
    },
    -- Check-in NPC (officer interacts to register prisoner)
    checkinNpc = {
        model = 's_m_m_prisguard_01',
        coords = vector4(1687.36, 2587.64, 45.36, 277.79),
        label = 'Intake Officer',
        sit = { model = 0x05C617D3, coords = vector3(1687.36, 2587.64, 45.36) },
    },
    -- Check-in holding area — cuffed prisoner stands here while officer talks to NPC
    checkinArea = {
        coords = vector3(1695.87, 2588.21, 45.92),
        radius = 8.0,
    },
    -- Intake process steps (prisoner walks through each after check-in)
    intake = {
        triggerDist = 1.5,  -- Distance to trigger each step
        markerType = 1,     -- Cylinder marker
        markerScale = vector3(1.0, 1.0, 0.5),
        markerColor = { r = 255, g = 200, b = 0, a = 120 },  -- Yellow
        steps = {
            {   -- Step 1: Deposit items
                coords = vector3(1687.62, 2579.98, 45.92),
                heading = 0.0,
                hudText = '~y~INTAKE ~w~- Go to ~y~Deposit Area',
                actionText = 'Depositing items...',
                actionDuration = 5000,
            },
            {   -- Step 2: Shower
                coords = vector3(1698.29, 2576.56, 45.92),
                heading = 90.34,
                hudText = '~y~INTAKE ~w~- Go to ~y~Shower',
                actionText = 'Showering...',
                actionDuration = 5000,
            },
            {   -- Step 3: Prison outfit
                coords = vector3(1692.94, 2570.62, 45.56),
                heading = 0.0,
                hudText = '~y~INTAKE ~w~- Get ~y~Prison Uniform',
                actionText = 'Getting dressed...',
                actionDuration = 3000,
            },
            {   -- Step 4: Enter yard
                coords = vector3(1691.62, 2566.16, 45.56),
                heading = 200.61,
                hudText = '~y~INTAKE ~w~- Enter the ~y~Yard',
                actionText = 'Entering yard...',
                actionDuration = 2000,
            },
        },
    },
    -- Release process steps (reverse of intake — prisoner walks out)
    release = {
        triggerDist = 1.5,
        markerType = 1,
        markerScale = vector3(1.0, 1.0, 0.5),
        markerColor = { r = 0, g = 200, b = 0, a = 120 },  -- Green
        steps = {
            {   -- Step 1: Remove prison outfit → strip to underwear
                coords = vector3(1692.94, 2570.62, 45.56),
                heading = 0.0,
                hudText = '~g~RELEASE ~w~- Remove ~g~Prison Uniform',
                actionText = 'Removing uniform...',
                actionDuration = 4000,
            },
            {   -- Step 2: Change into civilian clothes + collect belongings
                coords = vector3(1687.62, 2579.98, 45.92),
                heading = 0.0,
                hudText = '~g~RELEASE ~w~- Change & Collect ~g~Belongings',
                actionText = 'Getting dressed & collecting belongings...',
                actionDuration = 5000,
            },
            {   -- Step 3: Walk to exit (instant — no progress bar)
                coords = vector3(1690.8075, 2591.0481, 45.9186),
                heading = 0.0,
                hudText = '~g~RELEASE ~w~- Walk to ~g~Exit',
                actionText = '',
                actionDuration = 0,
            },
        },
    },
    -- Static guard NPCs
    -- sit = { chairModel, chairCoords } makes the NPC sit on that chair prop
    guards = {
        {
            model = 's_m_m_prisguard_01',
            coords = vector4(1837.89, 2582.12, 45.33, 267.1221),
            label = 'Lobby Guard',  -- Visitor registration area
            sit = { model = 0x1FF3CC2E, coords = vector3(1837.71, 2582.09, 45.43) },
        },
        {
            model = 's_m_m_prisguard_01',
            coords = vector4(1768.02, 2577.09, 45.51, 180.0),
            label = 'Warden',
            sit = { model = 0xCB7260E0, coords = vector3(1768.02, 2577.09, 45.51) },
        },
        {
            model = 's_m_m_prisguard_01',
            coords = vector4(1780.6899, 2554.73, 44.7794, 181.6926),
            label = 'Job Manager',
        },
    },
    -- Prison perimeter boundary polygon (point-in-polygon check)
    -- Tower-to-tower boundary covering full Bolingbroke facility
    perimeter = {
        vector2(1537.27, 2468.40),
        vector2(1658.59, 2390.90),
        vector2(1762.87, 2406.77),
        vector2(1828.31, 2473.88),
        vector2(1852.65, 2699.90),
        vector2(1774.37, 2766.94),
        vector2(1647.65, 2761.92),
        vector2(1566.30, 2682.60),
        vector2(1531.12, 2585.55),
    },
}

-- ============================================================================
-- PRISONER OUTFIT (orange jumpsuit — Heist DLC prison outfit + MPW retextures)
-- ============================================================================
-- Uses DLC collection-based lookup so indices auto-resolve regardless of clothing packs.
-- The Heist DLC prison outfit is built into GTA V (Prison Break heist).
-- MPW retextures make it look nicer (plain orange or corrections circles).
--
-- How it works:
--   1. dlcComponents: resolved at runtime by scanning for DLC collection + local index
--   2. staticComponents: vanilla indices that never shift (shoes, accessories, etc.)
--   3. Torso (component 3) is NOT set manually — GTA auto-sets it when the top is applied
--
-- MPW textures: 0 = corrections circles, 1 = plain orange
-- If MPW resource is not loaded, the base Heist DLC textures still look prison-like.
Config.PrisonerOutfit = {
    male = {
        -- 2 outfit variants — randomly picked per prisoner (50/50)
        -- Collection names are CASE-SENSITIVE (from GetPedCollectionNameFromDrawable)
        -- Texture 1 = plain orange (MPW retexture)
        variants = {
            {   -- Variant A: short-sleeve jumpsuit
                dlcComponents = {
                    { componentId = 11, collection = 'Male_Heist', localIndex = 12, texture = 1 },
                    { componentId = 4,  collection = 'Male_Heist', localIndex = 5,  texture = 1 },
                },
            },
            {   -- Variant B: long-sleeve jumpsuit
                dlcComponents = {
                    { componentId = 11, collection = 'Male_Heist', localIndex = 13, texture = 1 },
                    { componentId = 4,  collection = 'Male_Heist', localIndex = 6,  texture = 1 },
                },
            },
        },
        -- Static/vanilla components shared by all variants (these indices never change)
        staticComponents = {
            [1]  = { 0, 0 },     -- Mask: none
            [5]  = { 0, 0 },     -- Bags: none
            [6]  = { 12, 6 },    -- Shoes: white sneakers
            [7]  = { 0, 0 },     -- Accessories: none
            [8]  = { 15, 0 },    -- Undershirt: invisible
            [9]  = { 0, 0 },     -- Body armor: none
            [10] = { 0, 0 },     -- Decals: none
        },
    },
    female = {
        variants = {
            {
                dlcComponents = {
                    { componentId = 11, collection = 'Female_Heist', localIndex = 13, texture = 1 },
                    { componentId = 4,  collection = 'Female_Heist', localIndex = 6,  texture = 1 },
                },
            },
            {
                dlcComponents = {
                    { componentId = 11, collection = 'Female_Heist', localIndex = 14, texture = 1 },
                    { componentId = 4,  collection = 'Female_Heist', localIndex = 7,  texture = 1 },
                },
            },
        },
        staticComponents = {
            [1]  = { 0, 0 },
            [5]  = { 0, 0 },
            [6]  = { 12, 6 },
            [7]  = { 0, 0 },
            [8]  = { 15, 0 },
            [9]  = { 0, 0 },
            [10] = { 0, 0 },
        },
    },
}

-- Shower particle effect
Config.ShowerPtfx = {
    dict = 'core',
    name = 'ent_sht_water',
    offsetZ = 2.5,    -- above player head
    scale = 3.0,
}

-- Underwear appearance (strip to this at intake step 1)
Config.UnderwearOutfit = {
    male = {
        [1]  = { 0, 0 },     -- Mask: none
        [3]  = { 15, 0 },    -- Torso: bare
        [4]  = { 14, 0 },    -- Legs: boxers
        [5]  = { 0, 0 },     -- Bags: none
        [6]  = { 34, 0 },    -- Shoes: bare feet
        [7]  = { 0, 0 },     -- Accessories: none
        [8]  = { 15, 0 },    -- Undershirt: none
        [9]  = { 0, 0 },     -- Armor: none
        [10] = { 0, 0 },     -- Decals: none
        [11] = { 15, 0 },    -- Top: none (bare torso)
    },
    female = {
        [1]  = { 0, 0 },
        [3]  = { 15, 0 },
        [4]  = { 15, 0 },
        [5]  = { 0, 0 },
        [6]  = { 35, 0 },
        [7]  = { 0, 0 },
        [8]  = { 15, 0 },
        [9]  = { 0, 0 },
        [10] = { 0, 0 },
        [11] = { 15, 0 },
    },
}

-- Movement clipset for prisoners (nil = normal walk, prisoners can use fists)
Config.PrisonerClipset = nil

-- ============================================================================
-- TIMER HUD DISPLAY
-- ============================================================================
Config.Timer = {
    x = 0.5,           -- Screen position X (center)
    y = 0.06,          -- Screen position Y (near top)
    scale = 0.6,       -- Text scale
    font = 4,          -- Font (Pricedown)
}

-- ============================================================================
-- UPLOAD CONFIG (reuse sb_phone's fivemanager token)
-- ============================================================================
Config.UploadMethod = 'fivemanager'
Config.ScreenshotQuality = 0.85

-- ============================================================================
-- ADMIN/DEBUG
-- ============================================================================
Config.AdminOnly = true             -- /jail and /unjail require admin
Config.Debug = false                -- Set true for debug prints in F8

-- ============================================================================
-- CREDITS ECONOMY (Phase 2)
-- ============================================================================
Config.Credits = {
    startingBalance = 0,
    maxBalance = 9999,
}
Config.CreditsHUD = {
    x = 0.5,
    y = 0.095,          -- Below sentence timer (timer is at y=0.06)
    scale = 0.45,
    font = 4,
    color = { r = 255, g = 220, b = 50, a = 255 },  -- Gold
}

-- ============================================================================
-- PRISON JOBS (Phase 2 — laundry first, more in Phase 2b)
-- ============================================================================
Config.PrisonJobs = {
    laundry = {
        id = 'laundry',
        label = 'Laundry Room',
        credits = 15,
        timeReduction = 10,    -- seconds shaved off sentence
        cooldown = 30,         -- seconds between uses

        -- Entry zone (sb_target to start the shift — at sorting bins)
        entryZone = {
            coords = vector3(1592.81, 2542.87, 45.83),
            width = 3.0, length = 3.0, height = 2.0, heading = 0.0,
        },
        targetIcon = 'fa-shirt',
        targetLabel = 'Start Laundry Shift',
        targetDistance = 2.5,

        -- Multi-step flow (prisoner walks between stations)
        triggerDist = 1.5,
        markerType = 1,
        markerScale = vector3(0.8, 0.8, 0.4),
        markerColor = { r = 255, g = 220, b = 50, a = 120 },  -- Gold

        steps = {
            {   -- Step 1: Pick up dirty laundry from sorting bins (random bin each cycle)
                coords = {
                    vector3(1591.18, 2543.02, 45.95),
                    vector3(1592.81, 2542.87, 45.83),
                    vector3(1594.26, 2542.89, 45.83),
                },
                hudText = '~y~LAUNDRY ~w~- Pick up ~y~Dirty Laundry',
                progressLabel = 'Sorting dirty laundry...',
                progressDuration = 3000,
                animation = { dict = 'amb@prop_human_bum_bin@idle_a', anim = 'idle_a', duration = 3000, flag = 49 },
            },
            {   -- Step 2: Load washing machine (random machine, minigame)
                coords = {
                    vector3(1596.76, 2538.41, 45.63),
                    vector3(1596.78, 2540.49, 45.63),
                    vector3(1588.77, 2540.50, 45.63),
                    vector3(1588.74, 2538.46, 45.63),
                },
                hudText = '~y~LAUNDRY ~w~- Load the ~y~Washing Machine',
                progressLabel = 'Loading washer...',
                progressDuration = 5000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 5000, flag = 49 },
                minigame = { type = 'timing', difficulty = 2, rounds = 3, label = 'Load Washer' },
            },
            {   -- Step 3: Fold clean laundry at tables (random table)
                coords = {
                    vector3(1591.96, 2539.92, 45.63),
                    vector3(1593.90, 2539.69, 45.63),
                },
                hudText = '~y~LAUNDRY ~w~- Fold ~y~Clean Laundry',
                progressLabel = 'Folding laundry...',
                progressDuration = 4000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 4000, flag = 49 },
            },
            {   -- Step 4: Deliver to hanging rack
                coords = vector3(1593.35, 2546.22, 45.63),
                hudText = '~y~LAUNDRY ~w~- Deliver to ~y~Hanging Rack',
                progressLabel = 'Hanging laundry...',
                progressDuration = 3000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 3000, flag = 49 },
            },
        },
    },

    woodwork = {
        id = 'woodwork',
        label = 'Woodwork Shop',
        credits = 15,
        timeReduction = 10,
        cooldown = 30,

        -- Entry zone at lumber storage
        entryZone = {
            coords = vector3(1567.13, 2547.89, 45.63),
            width = 3.0, length = 3.0, height = 2.0, heading = 0.0,
        },
        targetIcon = 'fa-hammer',
        targetLabel = 'Start Woodwork Shift',
        targetDistance = 2.5,

        triggerDist = 1.5,
        markerType = 1,
        markerScale = vector3(0.8, 0.8, 0.4),
        markerColor = { r = 180, g = 120, b = 60, a = 120 },  -- Wood brown

        steps = {
            {   -- Step 1: Pick up raw lumber from storage
                coords = vector3(1567.13, 2547.89, 45.63),
                hudText = '~y~WOODWORK ~w~- Pick up ~y~Raw Lumber',
                progressLabel = 'Grabbing lumber...',
                progressDuration = 3000,
                animation = { dict = 'amb@prop_human_bum_bin@idle_a', anim = 'idle_a', duration = 3000, flag = 49 },
            },
            {   -- Step 2: Cut & shape at workbench (random bench, minigame)
                coords = {
                    vector3(1570.86, 2549.34, 45.64),
                    vector3(1574.78, 2549.33, 45.64),
                    vector3(1578.29, 2549.20, 45.64),
                    vector3(1581.95, 2549.15, 45.64),
                    vector3(1582.11, 2546.66, 45.64),
                    vector3(1578.33, 2546.92, 45.64),
                    vector3(1574.68, 2546.80, 45.64),
                    vector3(1570.81, 2546.80, 45.64),
                },
                hudText = '~y~WOODWORK ~w~- Cut & Shape at ~y~Workbench',
                progressLabel = 'Cutting & shaping wood...',
                progressDuration = 6000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 6000, flag = 49 },
                minigame = { type = 'timing', difficulty = 2, rounds = 3, label = 'Cut Wood' },
            },
            {   -- Step 3: Deliver finished piece to storage room
                coords = vector3(1579.49, 2553.74, 45.63),
                hudText = '~y~WOODWORK ~w~- Deliver to ~y~Storage',
                progressLabel = 'Storing finished piece...',
                progressDuration = 3000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 3000, flag = 49 },
            },
        },
    },

    metalwork = {
        id = 'metalwork',
        label = 'Metalwork Shop',
        credits = 20,
        timeReduction = 15,
        cooldown = 35,

        -- Entry zone at scrap pile
        entryZone = {
            coords = vector3(1585.04, 2558.46, 45.63),
            width = 3.0, length = 3.0, height = 2.0, heading = 0.0,
        },
        targetIcon = 'fa-gears',
        targetLabel = 'Start Metalwork Shift',
        targetDistance = 2.5,

        triggerDist = 1.5,
        markerType = 1,
        markerScale = vector3(0.8, 0.8, 0.4),
        markerColor = { r = 200, g = 80, b = 30, a = 120 },  -- Hot orange

        steps = {
            {   -- Step 1: Pick up scrap metal from ground piles
                coords = {
                    vector3(1585.04, 2558.46, 45.63),
                    vector3(1585.12, 2562.43, 45.63),
                },
                hudText = '~o~METALWORK ~w~- Pick up ~o~Scrap Metal',
                progressLabel = 'Gathering scrap...',
                progressDuration = 3000,
                animation = { dict = 'amb@prop_human_bum_bin@idle_a', anim = 'idle_a', duration = 3000, flag = 49 },
            },
            {   -- Step 2: Grind & shape at machine (random machine, timing minigame)
                coords = {
                    vector3(1591.50, 2562.11, 45.64),
                    vector3(1593.14, 2562.32, 45.64),
                    vector3(1594.59, 2562.34, 45.64),
                    vector3(1596.30, 2562.21, 45.64),
                    vector3(1596.18, 2558.42, 45.64),
                    vector3(1594.53, 2558.42, 45.64),
                    vector3(1593.10, 2558.42, 45.64),
                    vector3(1591.58, 2558.94, 45.63),
                },
                hudText = '~o~METALWORK ~w~- Grind at ~o~Machine',
                progressLabel = 'Grinding metal...',
                progressDuration = 5000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 5000, flag = 49 },
                minigame = { type = 'timing', difficulty = 3, rounds = 3, label = 'Grind Metal' },
            },
            {   -- Step 3: Drill & cut at press (random press, precision minigame)
                coords = {
                    vector3(1588.68, 2563.36, 45.64),
                    vector3(1586.01, 2563.23, 45.63),
                    vector3(1589.73, 2558.49, 45.63),
                },
                hudText = '~o~METALWORK ~w~- Cut at ~o~Drill Press',
                progressLabel = 'Cutting metal...',
                progressDuration = 5000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 5000, flag = 49 },
                minigame = { type = 'precision', difficulty = 2, rounds = 3, label = 'Cut Metal' },
            },
            {   -- Step 4: Deliver to storage room
                coords = vector3(1581.32, 2558.87, 45.63),
                hudText = '~o~METALWORK ~w~- Deliver to ~o~Storage',
                progressLabel = 'Storing finished piece...',
                progressDuration = 3000,
                animation = { dict = 'mini@repair', anim = 'fixing_a_player', duration = 3000, flag = 49 },
            },
        },
    },
}

-- ============================================================================
-- CANTEEN (Phase 2)
-- ============================================================================
Config.CanteenItems = {
    { id = 'prison_bread',  label = 'Bread',       price = 5,  hungerRestore = 20, thirstRestore = 0,  icon = 'fa-bread-slice' },
    { id = 'prison_apple',  label = 'Apple',        price = 3,  hungerRestore = 15, thirstRestore = 5,  icon = 'fa-apple-whole' },
    { id = 'prison_meal',   label = 'Prison Meal',  price = 12, hungerRestore = 45, thirstRestore = 10, icon = 'fa-utensils' },
    { id = 'prison_water',  label = 'Water Cup',    price = 3,  hungerRestore = 0,  thirstRestore = 30, icon = 'fa-glass-water' },
    { id = 'prison_juice',  label = 'Juice Box',    price = 5,  hungerRestore = 5,  thirstRestore = 25, icon = 'fa-mug-hot' },
    { id = 'prison_coffee', label = 'Coffee',       price = 4,  hungerRestore = 0,  thirstRestore = 20, icon = 'fa-mug-saucer' },
}
Config.CanteenNPC = {
    model = 's_m_m_prisguard_01',
    coords = vector4(1736.57, 2589.47, 44.42, 183.10),
    targetRadius = 3.0,   -- big interaction radius as requested
}
