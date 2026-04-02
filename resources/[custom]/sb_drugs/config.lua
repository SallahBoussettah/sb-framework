--[[
    Everyday Chaos RP - Drug System Configuration
    Author: Salah Eddine Boussettah

    All drug definitions, production chains, shops, selling locations, and effects
    are data-driven from this single config file.
]]

Config = {}

-- ========================================================================
-- GENERAL SETTINGS
-- ========================================================================
Config.Debug = false
Config.ProductionCooldown = 5       -- seconds between production actions per player
Config.SellCooldown = 120           -- seconds between NPC sells per player
Config.PoliceAlertChance = {
    harvest = 15,                   -- % chance per field pickup
    process = 10,                   -- % chance per lab craft
    sell = 20,                      -- % chance per NPC sale
}

Config.PlantGrowth = {
    stageTime = 45,         -- seconds per growth stage (small -> medium, medium -> grown = 90s total)
}

-- ========================================================================
-- LAB LOCATIONS (bob74_ipl interiors)
-- ========================================================================
Config.Labs = {
    weed = {
        name = 'Weed Farm',
        interiorId = 247297,
        requiredCard = 'access_card_weed',
        -- Surface entrance (Grapeseed farm area)
        surfaceEnter = vector3(2855.56, 4447.03, 48.88),
        surfaceExit  = vector3(2855.99, 4445.97, 47.54),
        -- Underground interior (bob74_ipl)
        labEnter = vector3(1066.12, -3183.43, -40.16),
        labExit  = vector3(1066.57, -3183.46, -38.96),
        blip = { sprite = 469, color = 2, scale = 0.7 },
        stations = {
            clean   = { coords = vector3(1038.67, -3205.93, -38.3), heading = 90.0,  label = 'Clean Weed' },     -- trimming table
            package = { coords = vector3(1036.35, -3203.13, -38.24), heading = 0.0,  label = 'Package Weed' },   -- packaging table
        },
    },
    coke = {
        name = 'Cocaine Lockup',
        interiorId = 247553,
        requiredCard = 'access_card_coke',
        -- Surface entrance (Elysian Island)
        surfaceEnter = vector3(1242.16, -3113.78, 6.01),
        surfaceExit  = vector3(1242.16, -3113.78, 6.01),
        -- Underground interior (bob74_ipl)
        labEnter = vector3(1088.76, -3187.68, -39.99),
        labExit  = vector3(1088.66, -3187.51, -38.83),
        blip = { sprite = 469, color = 1, scale = 0.7 },
        stations = {
            process  = { coords = vector3(1101.8, -3193.06, -38.98), heading = 90.0,  label = 'Process Leaves' },   -- leaf processing box
            extract  = { coords = vector3(1093.04, -3196.36, -39.15), heading = 0.0,  label = 'Extract Cocaine' },  -- purification table
            purify   = { coords = vector3(1095.39, -3196.3, -39.15), heading = 0.0,   label = 'Purify Cocaine' },   -- purification table
            package  = { coords = vector3(1100.43, -3199.39, -39.26), heading = 180.0, label = 'Package Figures' }, -- figure packaging
        },
    },
    meth = {
        name = 'Meth Lab',
        interiorId = 247041,
        requiredCard = 'access_card_meth',
        -- Surface entrance (Mirror Park)
        surfaceEnter = vector3(762.93, -1092.78, 22.58),
        surfaceExit  = vector3(763.09, -1092.92, 21.22),
        -- Underground interior (bob74_ipl)
        labEnter = vector3(996.99, -3200.7, -37.39),
        labExit  = vector3(996.49, -3200.62, -36.32),
        blip = { sprite = 469, color = 5, scale = 0.7 },
        stations = {
            cook        = { coords = vector3(1005.76, -3200.91, -38.1), heading = 180.0, label = 'Cook Meth' },       -- pouring/cooking station
            crystallize = { coords = vector3(1007.84, -3201.51, -38.53), heading = 188.0, label = 'Crystallize' },     -- crystallization area
            crush       = { coords = vector3(1016.47, -3194.15, -39.01), heading = 180.0, label = 'Crush & Package' }, -- crush/break table
        },
    },
}

-- ========================================================================
-- WEED GROUPS (9 bob74_ipl plant zones, each independently harvestable)
-- Each group maps 1:1 to bob74_ipl Plant1-Plant9 entity sets.
-- coords = center of plant group (for sb_target BoxZone)
-- yield = weed_bud items given per harvest
-- NOTE: Coords are estimated — verify in-game with F7 by setting each
--       group to 'small' one at a time to see which area changes.
-- ========================================================================
Config.WeedGroups = {
    { bob74Index = 1, coords = vector3(1057.5, -3189.8, -39.80), width = 3.0, length = 4.0, yield = 5 },
    { bob74Index = 2, coords = vector3(1055.5, -3190.0, -39.83), width = 3.0, length = 4.0, yield = 5 },
    { bob74Index = 3, coords = vector3(1053.0, -3189.5, -39.80), width = 3.0, length = 4.0, yield = 5 },
    { bob74Index = 4, coords = vector3(1053.0, -3194.0, -39.80), width = 3.0, length = 4.0, yield = 5 },
    { bob74Index = 5, coords = vector3(1053.0, -3199.0, -39.86), width = 3.0, length = 4.0, yield = 5 },
    { bob74Index = 6, coords = vector3(1051.0, -3189.8, -39.86), width = 3.0, length = 4.0, yield = 5 },
    { bob74Index = 7, coords = vector3(1050.0, -3196.0, -39.85), width = 3.0, length = 6.0, yield = 5 },
    { bob74Index = 8, coords = vector3(1063.0, -3193.0, -39.84), width = 4.0, length = 5.0, yield = 5 },
    { bob74Index = 9, coords = vector3(1062.5, -3198.5, -39.85), width = 4.0, length = 5.0, yield = 5 },
}

-- ========================================================================
-- FIELD LOCATIONS (outdoor harvesting)
-- ========================================================================
Config.Fields = {
    coca = {
        label = 'Coca Field',
        coords = vector3(2416.583, 4994.1064, 46.229),
        radius = 30.0,
        blip = { sprite = 469, color = 1, scale = 0.6 },
    },
    poppy = {
        label = 'Poppy Field',
        coords = vector3(2220.0, 5577.0, 54.0),
        radius = 30.0,
        blip = { sprite = 469, color = 6, scale = 0.6 },
    },
    mushroom = {
        label = 'Mushroom Forest',
        coords = vector3(-1039.0, 4919.0, 209.0),
        radius = 25.0,
        blip = { sprite = 469, color = 4, scale = 0.6 },
    },
    peyote = {
        label = 'Peyote Desert',
        coords = vector3(2570.0, 3880.0, 39.0),
        radius = 25.0,
        blip = { sprite = 469, color = 17, scale = 0.6 },
    },
    acid = {
        label = 'Chemical Source',
        coords = vector3(2718.76, 1558.05, 21.4),
        radius = 5.0,
        blip = nil,
    },
}

-- ========================================================================
-- PRODUCTION CHAINS (data-driven, generic ProcessStep handles all)
--
-- Each step: {
--   id          = unique step name
--   label       = display text
--   location    = 'lab:weed:pick' or 'field:coca' (type:key:station)
--   inputs      = { {item, amount, consumed} }  -- consumed=false for tools
--   outputs     = { {item, amount} }
--   duration    = seconds for progress bar
--   anim        = { dict, clip }
--   minigame    = nil or 'timing' or 'precision'
-- }
-- ========================================================================
Config.ProductionChains = {

    -- ============================
    -- WEED (3 steps)
    -- ============================
    weed_pick = {
        id = 'weed_pick',
        label = 'Harvest Weed Buds',
        location = 'plants:weed',
        inputs = { { item = 'scissors', amount = 1, consumed = false } },
        outputs = { { item = 'weed_bud', amount = 5 } },
        duration = 5,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
        alertChance = 0,
    },
    weed_clean = {
        id = 'weed_clean',
        label = 'Clean Weed Buds',
        location = 'lab:weed:clean',
        inputs = { { item = 'weed_bud', amount = 3, consumed = true } },
        outputs = { { item = 'weed_clean', amount = 1 } },
        duration = 8,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },
    weed_package = {
        id = 'weed_package',
        label = 'Package Weed',
        location = 'lab:weed:package',
        inputs = {
            { item = 'weed_clean', amount = 5, consumed = true },
            { item = 'empty_bag', amount = 1, consumed = true },
        },
        outputs = { { item = 'weed_bag', amount = 1 } },
        duration = 6,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },

    -- ============================
    -- COCAINE (4 lab steps + 1 field)
    -- ============================
    coca_pick = {
        id = 'coca_pick',
        label = 'Pick Coca Leaves',
        location = 'field:coca',
        inputs = { { item = 'trowel', amount = 1, consumed = false } },
        outputs = { { item = 'coca_leaf', amount = 1 } },
        duration = 5,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
        alertChance = 30,
    },
    coke_process = {
        id = 'coke_process',
        label = 'Process Coca Leaves',
        location = 'lab:coke:process',
        inputs = { { item = 'coca_leaf', amount = 2, consumed = true } },
        outputs = { { item = 'coca_paste', amount = 1 } },
        duration = 10,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },
    coke_extract = {
        id = 'coke_extract',
        label = 'Extract Cocaine',
        location = 'lab:coke:extract',
        inputs = { { item = 'coca_paste', amount = 1, consumed = true } },
        outputs = { { item = 'coca_raw', amount = 3 } },
        duration = 8,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },
    coke_purify = {
        id = 'coke_purify',
        label = 'Purify Cocaine',
        location = 'lab:coke:purify',
        inputs = { { item = 'coca_raw', amount = 2, consumed = true } },
        outputs = { { item = 'coca_pure', amount = 1 } },
        duration = 10,
        anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'youraddgoeshere' },
        alertChance = 10,
    },
    coke_package = {
        id = 'coke_package',
        label = 'Package Cocaine Figure',
        location = 'lab:coke:package',
        inputs = {
            { item = 'coca_pure', amount = 5, consumed = true },
            { item = 'empty_figure', amount = 1, consumed = true },
        },
        outputs = { { item = 'cocaine_figure', amount = 1 } },
        duration = 8,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },

    -- ============================
    -- METH (3 lab steps + 1 field)
    -- ============================
    acid_fill = {
        id = 'acid_fill',
        label = 'Fill Acid Canister',
        location = 'field:acid',
        inputs = { { item = 'meth_acid_empty', amount = 1, consumed = true } },
        outputs = { { item = 'meth_acid', amount = 1 } },
        duration = 5,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 0,
    },
    meth_cook = {
        id = 'meth_cook',
        label = 'Cook Meth',
        location = 'lab:meth:cook',
        inputs = {
            { item = 'ammonia', amount = 1, consumed = true },
            { item = 'meth_acid', amount = 1, consumed = true },
        },
        outputs = { { item = 'meth_liquid', amount = 1 } },
        duration = 15,
        anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'youraddgoeshere' },
        minigame = 'timing',
        alertChance = 10,
    },
    meth_crystallize = {
        id = 'meth_crystallize',
        label = 'Crystallize Meth',
        location = 'lab:meth:crystallize',
        inputs = { { item = 'meth_liquid', amount = 1, consumed = true } },
        outputs = { { item = 'meth_crystal', amount = 1 } },
        duration = 20,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },
    meth_crush = {
        id = 'meth_crush',
        label = 'Crush & Package Meth',
        location = 'lab:meth:crush',
        inputs = {
            { item = 'meth_crystal', amount = 1, consumed = true },
            { item = 'hammer', amount = 1, consumed = false },
        },
        outputs = { { item = 'meth_bag', amount = 2 } },
        duration = 8,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 10,
    },

    -- ============================
    -- HEROIN (1 field + 1 process)
    -- ============================
    poppy_pick = {
        id = 'poppy_pick',
        label = 'Pick Poppies',
        location = 'field:poppy',
        inputs = { { item = 'trowel', amount = 1, consumed = false } },
        outputs = { { item = 'poppy_flower', amount = 1 } },
        duration = 5,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
        alertChance = 15,
    },
    heroin_process = {
        id = 'heroin_process',
        label = 'Process Heroin',
        location = 'field:poppy',
        inputs = {
            { item = 'poppy_flower', amount = 3, consumed = true },
            { item = 'ammonia', amount = 1, consumed = true },
            { item = 'empty_bag', amount = 1, consumed = true },
        },
        outputs = { { item = 'heroin_dose', amount = 1 } },
        duration = 15,
        anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'youraddgoeshere' },
        alertChance = 15,
    },

    -- ============================
    -- CRACK (1 step, uses coke)
    -- ============================
    crack_cook = {
        id = 'crack_cook',
        label = 'Cook Crack',
        location = 'field:poppy',  -- outdoor processing at any field
        inputs = {
            { item = 'coca_pure', amount = 2, consumed = true },
            { item = 'baking_soda', amount = 1, consumed = true },
        },
        outputs = { { item = 'crack_rock', amount = 2 } },
        duration = 30,
        anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'youraddgoeshere' },
        alertChance = 20,
    },

    -- ============================
    -- MUSHROOMS & PEYOTE (simple pickup)
    -- ============================
    mushroom_pick = {
        id = 'mushroom_pick',
        label = 'Pick Mushrooms',
        location = 'field:mushroom',
        inputs = {},
        outputs = { { item = 'mushroom_dried', amount = 1 } },
        duration = 5,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
        alertChance = 5,
    },
    peyote_pick = {
        id = 'peyote_pick',
        label = 'Pick Peyote',
        location = 'field:peyote',
        inputs = {},
        outputs = { { item = 'peyote_dried', amount = 1 } },
        duration = 5,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
        alertChance = 5,
    },

    -- ============================
    -- CONSUMABLE ROLLING (anywhere)
    -- ============================
    roll_joint = {
        id = 'roll_joint',
        label = 'Roll Joint',
        location = 'anywhere',
        inputs = {
            { item = 'weed_clean', amount = 1, consumed = true },
            { item = 'rolling_papers', amount = 1, consumed = true },
        },
        outputs = { { item = 'weed_joint', amount = 1 } },
        duration = 4,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 0,
    },
    roll_blunt = {
        id = 'roll_blunt',
        label = 'Roll Blunt',
        location = 'anywhere',
        inputs = {
            { item = 'weed_clean', amount = 1, consumed = true },
            { item = 'blunt_wrap', amount = 1, consumed = true },
        },
        outputs = { { item = 'weed_blunt', amount = 1 } },
        duration = 4,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 0,
    },
    fill_syringe_heroin = {
        id = 'fill_syringe_heroin',
        label = 'Fill Heroin Syringe',
        location = 'anywhere',
        inputs = {
            { item = 'heroin_dose', amount = 1, consumed = true },
            { item = 'syringe', amount = 1, consumed = true },
        },
        outputs = { { item = 'heroin_syringe', amount = 1 } },
        duration = 3,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 0,
    },
    fill_syringe_meth = {
        id = 'fill_syringe_meth',
        label = 'Fill Meth Syringe',
        location = 'anywhere',
        inputs = {
            { item = 'meth_bag', amount = 1, consumed = true },
            { item = 'syringe', amount = 1, consumed = true },
        },
        outputs = { { item = 'meth_syringe', amount = 1 } },
        duration = 3,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 0,
    },
    prep_cocaine_line = {
        id = 'prep_cocaine_line',
        label = 'Prepare Cocaine Line',
        location = 'anywhere',
        inputs = {
            { item = 'coca_pure', amount = 1, consumed = true },
        },
        outputs = { { item = 'cocaine_line', amount = 2 } },
        duration = 3,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
        alertChance = 0,
    },
}

-- ========================================================================
-- NPC SHOPS
-- ========================================================================
Config.Shops = {
    {
        name = 'Weed Dealer',
        model = 's_m_y_dealer_01',
        coords = vector4(-1301.9567, -775.5922, 19.4695, 134.2899),
        blip = { sprite = 140, color = 2, scale = 0.7 },
        icon = 'fa-cannabis',
        items = {
            { item = 'access_card_weed', price = 5000,  label = 'Weed Access Card' },
            { item = 'empty_bag',        price = 50,    label = 'Empty Bag' },
            { item = 'rolling_papers',   price = 20,    label = 'Rolling Papers' },
            { item = 'blunt_wrap',       price = 40,    label = 'Blunt Wrap' },
        },
    },
    {
        name = 'Pharmacist',
        model = 's_m_m_doctor_01',
        coords = vector4(75.76, -1622.35, 30.9, 236.13),
        blip = { sprite = 403, color = 3, scale = 0.7 },
        icon = 'fa-prescription-bottle',
        items = {
            { item = 'meth_acid_empty', price = 350,  label = 'Empty Acid Can' },
            { item = 'ammonia',         price = 200,   label = 'Ammonia' },
            { item = 'syringe',         price = 100,   label = 'Syringe' },
            { item = 'pipe',            price = 75,    label = 'Pipe' },
        },
    },
    {
        name = 'Comic Shop',
        model = 'u_m_y_imporage',
        coords = vector4(-143.4897, 229.5289, 94.9352, 1.8309),
        blip = { sprite = 59, color = 5, scale = 0.7 },
        icon = 'fa-mask',
        items = {
            { item = 'empty_figure', price = 150, label = 'Action Figure (Empty)' },
        },
    },
    {
        name = 'Flower Shop',
        model = 's_m_m_gardener_01',
        coords = vector4(307.8704, -1286.4707, 30.5306, 165.26),
        blip = { sprite = 78, color = 4, scale = 0.7 },
        icon = 'fa-seedling',
        items = {
            { item = 'scissors',     price = 80,  label = 'Scissors' },
            { item = 'trowel',       price = 60,  label = 'Trowel' },
            { item = 'hammer',       price = 100, label = 'Hammer' },
            { item = 'glue',         price = 40,  label = 'Glue' },
            { item = 'baking_soda',  price = 25,  label = 'Baking Soda' },
        },
    },
    {
        name = 'Medicament Dealer',
        model = 's_m_y_dealer_01',
        coords = vector4(819.5451, -2348.8757, 30.3346, 268.1301),
        blip = { sprite = 403, color = 6, scale = 0.7 },
        icon = 'fa-pills',
        items = {
            { item = 'lsd_tab',      price = 300, label = 'LSD Tab' },
            { item = 'ecstasy_pill', price = 250, label = 'Ecstasy Pill' },
            { item = 'xanax_pill',   price = 200, label = 'Xanax Pill' },
        },
    },
}

-- ========================================================================
-- ACCESS CARD PROGRESSION (trade NPCs)
-- ========================================================================
Config.TradeNPCs = {
    {
        name = 'Gerald',
        model = 'a_m_y_stbla_02',
        coords = vector4(-59.6473, -1530.3413, 34.2352, 47.7889),
        blip = { sprite = 480, color = 1, scale = 0.7 },
        trade = {
            requiredItem = 'weed_bag',
            requiredAmount = 20,
            rewardItem = 'access_card_coke',
            label = 'Trade 20x Weed Bags for Cocaine Access Card',
        },
    },
    {
        name = 'Madrazo',
        model = 'g_m_m_mexboss_01',
        coords = vector4(-1033.0369, 685.9722, 161.3028, 95.1929),
        blip = { sprite = 480, color = 5, scale = 0.7 },
        trade = {
            requiredItem = 'cocaine_figure',
            requiredAmount = 5,
            rewardItem = 'access_card_meth',
            label = 'Trade 5x Cocaine Figures for Meth Access Card',
        },
    },
}

-- ========================================================================
-- NPC SELLING (phone booths)
-- ========================================================================
Config.Selling = {
    moneyType = 'cash',             -- 'cash' or 'bank'
    maxSellAmount = 5,              -- max items per sale
    negotiateSuccessChance = 30,    -- % chance negotiate works
    negotiateFailWalkChance = 30,   -- % chance NPC walks away on fail
    attackChance = 10,              -- % chance NPC attacks
    policeAlertChance = 20,         -- % chance police get alerted

    -- Sellable drugs with price ranges
    drugs = {
        weed_bag        = { label = 'Weed Bag',        minPrice = 200,  maxPrice = 400 },
        meth_bag        = { label = 'Meth Bag',        minPrice = 500,  maxPrice = 1000 },
        cocaine_figure  = { label = 'Cocaine Figure',  minPrice = 800,  maxPrice = 1500 },
        heroin_dose     = { label = 'Heroin Dose',     minPrice = 400,  maxPrice = 800 },
        crack_rock      = { label = 'Crack Rock',      minPrice = 300,  maxPrice = 600 },
    },
}

-- Phone booth model hashes (GTA prop models)
Config.PhoneBoothHashes = {
    -429560270,
    -1559354806,
    -78626473,
    295857659,
    -2103798695,
    1158960338,
    1511539537,
    1281992692,
}

-- 66 buyer NPC spawn locations near phone booths
Config.SellLocations = {
    vector4(130.2, -1274.99, 28.24, 0.0),
    vector4(162.11, -1268.32, 28.24, 160.62),
    vector4(161.79, -1286.42, 28.23, 110.34),
    vector4(339.17, -1263.60, 30.96, 74.82),
    vector4(306.83, -1246.18, 28.57, 8.58),
    vector4(343.40, -1190.28, 28.31, 164.21),
    vector4(109.19, -1804.54, 25.50, 179.38),
    vector4(524.42, -1831.14, 27.28, 249.49),
    vector4(959.98, -2373.81, 29.50, 0.0),
    vector4(1062.27, -2408.46, 28.97, 92.5),
    vector4(1140.85, -2332.80, 30.34, 166.0),
    vector4(1126.36, -2096.35, 30.08, 278.05),
    vector4(990.39, -1791.78, 30.63, 181.86),
    vector4(1010.55, -1778.92, 30.42, 83.75),
    vector4(977.90, -1708.98, 29.09, 87.52),
    vector4(990.39, -1660.08, 28.44, 0.0),
    vector4(980.86, -1383.56, 30.54, 29.47),
    vector4(935.19, -1520.58, 30.06, 0.0),
    vector4(998.07, -1489.55, 30.41, 278.1),
    vector4(925.84, -1483.28, 29.11, 50.98),
    vector4(886.78, -1516.57, 29.18, 223.01),
    vector4(886.59, -1584.52, 29.95, 261.39),
    vector4(536.46, -1650.18, 28.26, 259.47),
    vector4(491.19, -1705.30, 28.35, 325.47),
    vector4(353.25, -1850.11, 26.71, 217.45),
    vector4(201.78, -2002.96, 17.86, 234.0),
    vector4(-592.01, -1767.25, 22.18, 235.15),
    vector4(-1110.98, -1046.5, 1.153, 214.28),
    vector4(1064.63, -2407.89, 28.98, 106.59),
    vector4(1078.87, -2443.25, 28.44, 89.69),
    vector4(953.97, -2529.31, 27.30, 171.31),
    vector4(402.26, -2188.63, 4.917, 243.06),
    vector4(-353.99, -1490.89, 29.26, 142.04),
    vector4(-312.45, -1342.49, 30.32, 42.24),
    vector4(-342.67, -899.03, 30.07, 210.86),
    vector4(-317.44, -772.25, 32.96, 28.59),
    vector4(-241.84, -785.30, 29.45, 71.82),
    vector4(-203.62, -758.88, 29.45, 196.89),
    vector4(-222.69, -641.03, 32.39, 142.0),
    vector4(66.48, -266.27, 47.18, 214.91),
    vector4(117.78, -265.57, 45.33, 114.95),
    vector4(133.96, -258.22, 45.33, 118.89),
    vector4(169.79, -279.18, 49.27, 297.43),
    vector4(475.16, -105.43, 62.15, 190.25),
    vector4(741.29, 140.41, 79.76, 188.99),
    vector4(777.54, 210.96, 82.64, 158.28),
    vector4(955.28, -194.77, 72.20, 229.43),
    vector4(960.85, -210.85, 72.21, 37.49),
    vector4(974.39, -192.00, 72.20, 37.49),
    vector4(966.46, -203.89, 75.25, 249.08),
    vector4(955.76, -195.02, 78.29, 143.23),
    vector4(791.53, -102.66, 81.03, 335.53),
    vector4(820.06, -124.38, 79.22, 296.63),
    vector4(501.94, -612.38, 23.75, 280.33),
    vector4(460.75, -698.17, 26.42, 41.48),
    vector4(367.92, -776.74, 28.26, 95.15),
    vector4(378.51, -900.16, 28.41, 197.58),
    vector4(-3.72, -1086.34, 25.67, 65.54),
    vector4(-17.60, -1037.06, 27.90, 0.0),
    vector4(45.53, -1011.18, 28.52, 109.67),
    vector4(2.23, -1024.41, 27.96, 103.56),
    vector4(-771.69, -1028.13, 13.13, 254.41),
    vector4(-661.76, -710.01, 25.89, 193.05),
    vector4(-617.15, -683.27, 20.23, 222.4),
    vector4(-584.07, -698.28, 30.23, 176.97),
    vector4(-577.70, -676.53, 35.28, 125.32),
}

-- Buyer NPC models (random selection)
Config.BuyerModels = {
    'a_m_m_afriamer_01', 's_m_y_ammucity_01', 'g_m_m_armboss_01',
    'a_m_m_bevhills_01', 'a_m_m_business_01', 'a_m_y_downtown_01',
    'a_m_y_hipster_01', 'a_m_y_methhead_01', 'a_m_y_stwhi_02',
    'a_f_y_hipster_01', 'a_f_y_tourist_01', 'a_m_y_genstreet_01',
    'a_m_y_latino_01', 'a_m_m_tramp_01', 'a_m_y_skater_01',
    'a_m_y_vinewood_01', 'a_f_m_downtown_01', 'a_m_m_farmer_01',
}

-- ========================================================================
-- DRUG EFFECTS (consumption)
-- ========================================================================
Config.DrugEffects = {
    weed_joint = {
        label = 'Weed Joint',
        screenEffect = 'CamPushInMichael',
        movementClipset = 'move_m@drunk@slightlydrunk',
        speedMultiplier = 1.0,
        duration = 30,
        stressRelief = 25,
        healthBoost = 0,
        armorBoost = 0,
        anim = { dict = 'amb@world_human_smoking@male@male_a@enter', clip = 'enter' },
        prop = { model = 'prop_cs_joint_01', bone = 47419, pos = vector3(0.015, -0.009, 0.003), rot = vector3(55.0, 0.0, 110.0) },
    },
    weed_blunt = {
        label = 'Weed Blunt',
        screenEffect = 'CamPushInMichael',
        movementClipset = 'move_m@drunk@slightlydrunk',
        speedMultiplier = 1.0,
        duration = 40,
        stressRelief = 30,
        healthBoost = 0,
        armorBoost = 0,
        anim = { dict = 'amb@world_human_smoking@male@male_a@enter', clip = 'enter' },
        prop = { model = 'prop_cs_joint_01', bone = 47419, pos = vector3(0.015, -0.009, 0.003), rot = vector3(55.0, 0.0, 110.0) },
    },
    meth_bag = {
        label = 'Meth (Smoked)',
        screenEffect = 'DrugsMichaelAliensFightIn',
        movementClipset = nil,
        speedMultiplier = 1.6,
        duration = 45,
        stressRelief = 40,
        healthBoost = 30,
        armorBoost = 50,
        anim = { dict = 'mp_suicide', clip = 'pill' },
    },
    cocaine_line = {
        label = 'Cocaine Line',
        screenEffect = 'BeastLaunch',
        movementClipset = nil,
        speedMultiplier = 1.15,
        duration = 40,
        stressRelief = 30,
        healthBoost = 30,
        armorBoost = 50,
        anim = { dict = 'switch@trevor@trev_take_pill', clip = 'trev_take_pill_loop' },
    },
    heroin_syringe = {
        label = 'Heroin Injection',
        screenEffect = 'DeathFailOut',
        movementClipset = 'move_m@drunk@verydrunk',
        speedMultiplier = 0.8,
        duration = 60,
        stressRelief = 50,
        healthBoost = 50,
        armorBoost = 10,
        anim = { dict = 'anim@heists@narcotics@funding@gang_idle', clip = 'gang_chatting_idle01' },
        prop = { model = 'prop_syringe_01', bone = 57005, pos = vector3(0.11, 0.02, 0.05), rot = vector3(-100.0, 0.0, 0.0) },
        propRemoveAfterAnim = true,
    },
    meth_syringe = {
        label = 'Meth Injection',
        screenEffect = 'DrugsMichaelAliensFightIn',
        movementClipset = nil,
        speedMultiplier = 1.6,
        duration = 45,
        stressRelief = 40,
        healthBoost = 30,
        armorBoost = 50,
        anim = { dict = 'anim@heists@narcotics@funding@gang_idle', clip = 'gang_chatting_idle01' },
        prop = { model = 'prop_syringe_01', bone = 57005, pos = vector3(0.11, 0.02, 0.05), rot = vector3(-100.0, 0.0, 0.0) },
        propRemoveAfterAnim = true,
    },
    crack_rock = {
        label = 'Crack Rock',
        screenEffect = 'DrugsMichaelAliensFightIn',
        movementClipset = 'move_m@drunk@a',
        speedMultiplier = 1.4,
        duration = 30,
        stressRelief = 35,
        healthBoost = 30,
        armorBoost = 50,
        anim = { dict = 'mp_suicide', clip = 'pill' },
    },
    lsd_tab = {
        label = 'LSD Tab',
        screenEffect = 'DMT_flight',
        movementClipset = nil,
        speedMultiplier = 1.0,
        duration = 60,
        stressRelief = 20,
        healthBoost = 10,
        armorBoost = 0,
        anim = { dict = 'mp_suicide', clip = 'pill' },
    },
    ecstasy_pill = {
        label = 'Ecstasy Pill',
        screenEffect = 'DrugsMichaelAliensFightIn',
        movementClipset = nil,
        speedMultiplier = 1.2,
        duration = 45,
        stressRelief = 30,
        healthBoost = 30,
        armorBoost = 0,
        anim = { dict = 'mp_suicide', clip = 'pill' },
    },
    xanax_pill = {
        label = 'Xanax Pill',
        screenEffect = 'DeathFailMichaelIn',
        movementClipset = 'move_m@drunk@moderatedrunk',
        speedMultiplier = 0.9,
        duration = 40,
        stressRelief = 45,
        healthBoost = 5,
        armorBoost = 15,
        anim = { dict = 'mp_suicide', clip = 'pill' },
    },
    mushroom_dried = {
        label = 'Magic Mushroom',
        screenEffect = 'DMT_flight',
        movementClipset = 'move_m@drunk@moderatedrunk',
        speedMultiplier = 1.0,
        duration = 50,
        stressRelief = 25,
        healthBoost = 30,
        armorBoost = 0,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
    },
    peyote_dried = {
        label = 'Peyote',
        screenEffect = 'DMT_flight',
        movementClipset = nil,
        speedMultiplier = 1.0,
        duration = 45,
        stressRelief = 20,
        healthBoost = 30,
        armorBoost = 0,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
    },
}

-- ========================================================================
-- CONSUMABLE ITEMS (maps useable items → DrugEffects key)
-- ========================================================================
Config.ConsumableItems = {
    'weed_joint', 'weed_blunt', 'meth_bag', 'cocaine_line',
    'heroin_syringe', 'meth_syringe', 'crack_rock',
    'lsd_tab', 'ecstasy_pill', 'xanax_pill',
    'mushroom_dried', 'peyote_dried',
}

-- Items that can be crafted anywhere (right-click use)
Config.AnywhereCrafts = {
    'roll_joint', 'roll_blunt', 'fill_syringe_heroin',
    'fill_syringe_meth', 'prep_cocaine_line',
}
