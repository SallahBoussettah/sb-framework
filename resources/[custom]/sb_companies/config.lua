-- sb_companies | Configuration
-- Company definitions, locations, delivery config, shop storage

Config = {}

-- ===================================================================
-- COMPANY DEFINITIONS
-- ===================================================================
Config.Companies = {
    {
        id = 'santos_metal',
        label = 'Santos Metal Works',
        type = 'heavy_manufacturing',
        -- La Mesa industrial area
        location = vector3(714.28, -965.42, 30.41),
        heading = 90.0,
        blip = { sprite = 566, color = 47, scale = 0.75, label = 'Santos Metal Works' },

        -- NPC interaction points inside the company
        receivingDock = vector3(718.52, -972.18, 30.41),  -- Miners sell raw materials here
        productionArea = vector3(710.34, -958.62, 30.41), -- Workers craft here
        loadingDock = vector3(722.15, -960.87, 30.41),    -- Drivers pick up deliveries here
        managementDesk = vector3(706.48, -968.34, 30.41), -- Owner/manager dashboard

        -- Van spawn for deliveries
        vanSpawn = vector4(726.83, -955.21, 30.41, 180.0),

        -- Raw materials this company buys from miners
        buysMaterials = {
            'raw_steel', 'raw_aluminum', 'raw_copper', 'raw_iron',
            'raw_chrome', 'raw_bearing_steel', 'raw_rubber', 'raw_fiberglass',
            'raw_glass', 'raw_friction_material', 'raw_gasket_material',
            'raw_adhesive', 'raw_sandpaper', 'raw_paint_base',
            'raw_ceramic', 'raw_electrode', 'raw_titanium', 'raw_zinc',
            'raw_carbon', 'raw_kevlar',
        },
    },
    {
        id = 'pacific_chem',
        label = 'Pacific Chemical Solutions',
        type = 'fluids_rubber',
        -- Elysian Island / Port area
        location = vector3(-233.52, -2438.64, 7.61),
        heading = 315.0,
        blip = { sprite = 473, color = 27, scale = 0.75, label = 'Pacific Chemical Solutions' },

        receivingDock = vector3(-237.18, -2444.32, 7.61),
        productionArea = vector3(-229.45, -2432.78, 7.61),
        loadingDock = vector3(-225.87, -2441.15, 7.61),
        managementDesk = vector3(-236.72, -2430.56, 7.61),

        vanSpawn = vector4(-221.34, -2445.67, 7.61, 45.0),

        buysMaterials = {
            'raw_oil', 'raw_rubber', 'raw_glycol', 'raw_brake_fluid',
            'raw_additive', 'raw_dye', 'raw_kevlar', 'raw_carbon',
            'raw_steel', 'raw_gasket_material',
        },
    },
    {
        id = 'ls_electronics',
        label = 'LS Electronics Corp',
        type = 'electronics',
        -- Cypress Flats area
        location = vector3(897.45, -1058.32, 32.23),
        heading = 0.0,
        blip = { sprite = 521, color = 26, scale = 0.75, label = 'LS Electronics Corp' },

        receivingDock = vector3(901.23, -1064.87, 32.23),
        productionArea = vector3(893.67, -1052.45, 32.23),
        loadingDock = vector3(905.12, -1055.34, 32.23),
        managementDesk = vector3(890.34, -1060.78, 32.23),

        vanSpawn = vector4(909.56, -1050.23, 32.23, 270.0),

        buysMaterials = {
            'raw_copper', 'raw_silicon', 'raw_circuit_board', 'raw_magnet',
            'raw_solder', 'raw_plastic', 'raw_glass', 'raw_lead',
            'raw_electrode',
        },
    },
}

-- Quick lookup by company id
Config.CompanyById = {}
for _, company in ipairs(Config.Companies) do
    Config.CompanyById[company.id] = company
end

-- ===================================================================
-- SHOP DEFINITIONS (mechanic workshops)
-- ===================================================================
Config.Shops = {
    {
        id = 'bennys',
        label = "Benny's Original Motorworks",
        -- Order terminal (PC at workshop)
        orderTerminal = vector3(-197.83, -1339.77, 34.84),
        orderTerminalRadius = 2.0,

        -- Parts dispensers at workshop
        dispensers = {
            { id = 'parts_engine',  coords = vector3(-197.56, -1320.97, 31.05), categories = {'engine', 'transmission'}, label = 'Engine & Transmission Parts' },
            { id = 'parts_brakes',  coords = vector3(-242.10, -1338.67, 31.23), categories = {'brakes', 'suspension'},   label = 'Brakes & Suspension Parts' },
            { id = 'parts_elec',    coords = vector3(-242.04, -1329.67, 30.88), categories = {'electrical', 'body'},     label = 'Electrical & Body Parts' },
            { id = 'fluid_disp',    coords = vector3(-240.09, -1313.72, 31.29), categories = {'fluids'},                 label = 'Fluids Dispenser' },
            { id = 'tire_rack',     coords = vector3(-240.61, -1315.73, 18.47), categories = {'wheels'},                 label = 'Tire Rack' },
        },

        -- Delivery dropoff point (where drivers drop cargo)
        deliveryDropoff = vector3(-195.42, -1310.56, 30.89),
        deliveryDropoffRadius = 5.0,
    },
    -- Add more shops here as you create MLOs (e.g. LS Customs)
}

-- Quick lookup by shop id
Config.ShopById = {}
for _, shop in ipairs(Config.Shops) do
    Config.ShopById[shop.id] = shop
end

-- ===================================================================
-- RAW MATERIAL BUY PRICES (what companies pay miners)
-- ===================================================================
Config.RawMaterialPrices = {
    -- Metals
    raw_steel           = 30,
    raw_aluminum        = 40,
    raw_copper          = 50,
    raw_iron            = 35,
    raw_titanium        = 200,
    raw_chrome          = 65,
    raw_zinc            = 22,
    raw_lead            = 18,
    raw_bearing_steel   = 55,
    -- Non-metals
    raw_rubber          = 22,
    raw_plastic         = 15,
    raw_glass           = 35,
    raw_ceramic         = 40,
    raw_carbon          = 150,
    raw_fiberglass      = 45,
    raw_kevlar          = 170,
    -- Electrical
    raw_electrode       = 28,
    raw_silicon         = 75,
    raw_circuit_board   = 85,
    raw_magnet          = 65,
    raw_solder          = 18,
    -- Chemical / Fluid base
    raw_oil             = 15,
    raw_glycol          = 18,
    raw_brake_fluid     = 22,
    raw_additive        = 28,
    raw_dye             = 10,
    -- Consumables
    raw_filter_media    = 18,
    raw_friction_material = 32,
    raw_gasket_material = 25,
    raw_adhesive        = 22,
    raw_sandpaper       = 10,
    raw_paint_base      = 38,
}

-- NPC-owned companies pay 1.5x for auto-restocking raw materials
Config.NPCRestockMarkup = 1.5

-- ===================================================================
-- DELIVERY SETTINGS
-- ===================================================================
Config.Delivery = {
    vanModel = 'speedo',        -- Delivery van model
    driverPayment = 200,        -- $ paid to player driver per delivery
    npcSurcharge = 250,         -- $ surcharge when NPC delivers (money lost)
    npcWaitTime = 10,           -- Minutes before NPC auto-dispatches
    npcDriveTimeMin = 15,       -- Min minutes for simulated NPC drive
    npcDriveTimeMax = 30,       -- Max minutes for simulated NPC drive
    npcQualityCap = 85,         -- Max restore % for NPC-delivered parts
    npcDegradeMult = 1.0,       -- Degrade multiplier for NPC parts
    claimTimeout = 30,          -- Minutes before uncompleted claim expires
}

-- ===================================================================
-- NPC PRODUCTION SETTINGS
-- ===================================================================
Config.Production = {
    npcDelay = 300,             -- Seconds (5 min) before NPC auto-production kicks in
    npcQuality = 'standard',    -- NPC always produces standard quality
    npcSpeedMultiplier = 2.0,   -- NPC takes 2x longer than recipe craft time
    npcMaxRestore = 85,         -- NPC parts capped at 85% restore
    npcDegradeMult = 1.0,       -- NPC parts always 1.0 degrade mult
}

-- ===================================================================
-- COMPANY JOB ROLES
-- ===================================================================
Config.Roles = {
    worker  = { label = 'Worker',  canCraft = true,  canDrive = false, canManage = false },
    driver  = { label = 'Driver',  canCraft = false, canDrive = true,  canManage = false },
    manager = { label = 'Manager', canCraft = true,  canDrive = true,  canManage = true },
}

-- ===================================================================
-- ITEM CATEGORY MAPPING
-- Maps item names to dispenser categories for the shop storage system
-- ===================================================================
Config.ItemCategories = {
    -- Engine
    part_engine_block = 'engine', part_spark_plugs = 'engine', part_air_filter = 'engine',
    part_radiator = 'engine', part_turbo = 'engine', part_oil_pump = 'engine',
    part_water_pump = 'engine', part_fuel_pump = 'engine', part_exhaust = 'engine',
    part_intake = 'engine', part_timing_belt = 'engine',
    -- Transmission
    part_clutch = 'transmission', part_transmission = 'transmission',
    -- Brakes
    part_brake_pads = 'brakes', part_brake_rotors = 'brakes', part_brake_caliper = 'brakes',
    -- Suspension
    part_shocks = 'suspension', part_springs = 'suspension', part_wheel_bearings = 'suspension',
    part_cv_joint = 'suspension', part_tie_rod = 'suspension', part_ball_joint = 'suspension',
    part_control_arm = 'suspension',
    -- Body
    part_body_panel = 'body', part_fender = 'body', part_windshield = 'body',
    part_headlights = 'body', part_taillights = 'body',
    -- Electrical
    part_ecu = 'electrical', part_wiring = 'electrical', part_battery = 'electrical',
    part_alternator = 'electrical', part_starter = 'electrical',
    -- Fluids
    fluid_motor_oil = 'fluids', fluid_coolant = 'fluids', fluid_brake = 'fluids',
    fluid_trans = 'fluids', fluid_power_steering = 'fluids',
    -- Wheels
    part_tire = 'wheels', part_tire_performance = 'wheels', part_tire_offroad = 'wheels',
    -- Tools
    tool_wrench_set = 'engine', tool_torque_wrench = 'engine', tool_jack = 'suspension',
    tool_diagnostic = 'electrical', tool_multimeter = 'electrical',
    tool_welding_kit = 'body', tool_alignment_gauge = 'suspension',
    tool_brake_bleeder = 'brakes', tool_tire_machine = 'wheels',
    tool_paint_gun = 'body', tool_compression_tester = 'engine',
    -- Upgrades
    upgrade_engine = 'engine', upgrade_transmission = 'transmission',
    upgrade_brakes = 'brakes', upgrade_suspension = 'suspension',
    upgrade_turbo = 'engine', upgrade_exhaust = 'engine',
    upgrade_intake = 'engine', upgrade_ecu = 'electrical',
}

-- ===================================================================
-- OPEN-WORLD MINING SPOTS
-- ===================================================================
Config.OpenWorldMining = {
    respawnMinutes = 10,        -- Default respawn time for open-world nodes
    interactRadius = 1.5,       -- sb_target interaction radius
    miningDuration = 8000,      -- ms, progress bar duration

    -- Scattered nodes anyone can mine (no job required)
    nodes = {
        -- Quarry area (Sandy Shores)
        { id = 'ow_quarry_1',  coords = vector3(2954.17, 2774.34, 39.12), resource = 'raw_iron',    yield = {1, 2}, prop = 'prop_rock_4_a',     respawn = 10 },
        { id = 'ow_quarry_2',  coords = vector3(2961.45, 2781.22, 39.56), resource = 'raw_steel',   yield = {1, 2}, prop = 'prop_rock_4_b',     respawn = 10 },
        { id = 'ow_quarry_3',  coords = vector3(2948.83, 2768.91, 38.87), resource = 'raw_aluminum', yield = {1, 1}, prop = 'prop_rock_4_c',    respawn = 12 },

        -- Construction site (LS)
        { id = 'ow_construct_1', coords = vector3(-146.23, -963.45, 29.23), resource = 'raw_steel',  yield = {1, 2}, prop = 'prop_barrel_pile_01', respawn = 8 },
        { id = 'ow_construct_2', coords = vector3(-152.67, -970.12, 29.15), resource = 'raw_copper', yield = {1, 1}, prop = 'prop_barrel_pile_01', respawn = 10 },

        -- Scrapyard (La Puerta)
        { id = 'ow_scrap_1',  coords = vector3(-572.34, -1778.23, 22.45), resource = 'raw_iron',    yield = {1, 3}, prop = 'prop_rub_pile_03',  respawn = 8 },
        { id = 'ow_scrap_2',  coords = vector3(-578.56, -1773.89, 22.31), resource = 'raw_lead',    yield = {1, 2}, prop = 'prop_rub_pile_03',  respawn = 10 },
        { id = 'ow_scrap_3',  coords = vector3(-565.12, -1782.67, 22.58), resource = 'raw_rubber',  yield = {1, 2}, prop = 'prop_rub_pile_03',  respawn = 8 },

        -- Oil field (near refinery)
        { id = 'ow_oil_1',    coords = vector3(549.23, -2142.56, 6.12),   resource = 'raw_oil',     yield = {2, 4}, prop = 'prop_barrel_01a',   respawn = 6 },
        { id = 'ow_oil_2',    coords = vector3(555.67, -2148.34, 6.08),   resource = 'raw_oil',     yield = {2, 3}, prop = 'prop_barrel_01a',   respawn = 6 },

        -- Chemical plant area
        { id = 'ow_chem_1',   coords = vector3(1085.23, -1972.45, 31.12), resource = 'raw_glycol',  yield = {1, 2}, prop = 'prop_barrel_03a',   respawn = 12 },
        { id = 'ow_chem_2',   coords = vector3(1091.56, -1978.23, 31.08), resource = 'raw_additive', yield = {1, 2}, prop = 'prop_barrel_03a',  respawn = 12 },
    },
}

-- ===================================================================
-- DEBUG
-- ===================================================================
Config.Debug = false
