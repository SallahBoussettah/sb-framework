Config = {}

-- ============================================================================
-- HEIST SETTINGS
-- ============================================================================
Config.RequiredPoliceCount = 0          -- Required police on duty to start heist (0 for testing)
Config.HeistCooldown = 7200             -- Seconds between heists (2 hours)
Config.BlackMoney = false               -- If true, cash rewards become 'dirty_money' item instead

-- ============================================================================
-- REQUIRED ITEMS (items needed to perform heist actions)
-- ============================================================================
Config.RequiredItems = {
    drill = 'heist_drill',              -- For laser drill minigame
    bag = 'heist_bag',                  -- For grabbing loot
    cutter = 'glass_cutter',            -- For glass cutting & paintings
    c4 = 'c4_explosive',                -- For cell gates
    thermite = 'thermite_charge',       -- For door melting
    laptop = 'hacking_laptop',          -- For laptop hacking
    usb = 'trojan_usb',                 -- For keypad hacking
    switchblade = 'switchblade'          -- For painting theft (item)
}

-- ============================================================================
-- REWARD ITEMS (loot from vault)
-- ============================================================================
Config.RewardItems = {
    { name = 'gold_bar',        sellPrice = 2500 },     -- Gold bars
    { name = 'diamond_pouch',   sellPrice = 3500 },     -- Diamonds
    { name = 'cocaine_brick',   sellPrice = 1500 },     -- Cocaine
}

Config.GlassCuttingRewards = {
    { item = 'panther_statue',   model = 'h4_prop_h4_art_pant_01a',   price = 15000, displayModel = nil },
    { item = 'diamond_necklace', model = 'h4_prop_h4_necklace_01a',   price = 12000, displayModel = 'h4_prop_h4_neck_disp_01a' },
    { item = 'vintage_wine',     model = 'h4_prop_h4_t_bottle_02b',   price = 8000,  displayModel = nil },
    { item = 'rare_watch',       model = 'vw_prop_vw_pogo_gold_01a',  price = 10000, displayModel = nil },
}

Config.PaintingRewards = {
    { item = 'vault_painting',   price = 20000 },
}

-- Stack Rewards
Config.StackRewards = {
    gold = 25,          -- Gold bars per gold stack
    cash = 250000       -- Cash per cash stack
}

Config.TrolleyMoneyReward = 5000        -- Cash per trolley grab
Config.DrillRewardCount = 5             -- Items from drill boxes

-- ============================================================================
-- LOCATIONS
-- ============================================================================
Config.HeistStart = {
    pos = vector3(253.0, 217.0, 106.28),    -- Near main entrance inside bank lobby
    heading = 160.0,
    blip = {
        sprite = 500,
        color = 1,
        label = 'Pacific Standard Bank'
    }
}

Config.BuyerLocation = {
    pos = vector3(-1228.0, -662.41, 39.3575),
    vehicleModel = 'baller',
    blip = {
        sprite = 500,
        color = 2,
        label = 'Buyer'
    }
}

-- Security Guard NPCs at heist start
Config.SecurityGuards = {
    { pos = vector3(251.50, 217.50, 106.28), heading = 340.0, model = 's_m_m_highsec_01' },
    { pos = vector3(254.50, 217.00, 106.28), heading = 340.0, model = 's_m_m_highsec_02' },
}

-- ============================================================================
-- VAULT DOORS (thermite required)
-- ============================================================================
Config.FreezeDoors = {
    -- Pacific entrance doors
    {
        model = -222270721,
        pos = vector3(257.10, 220.30, 106.28),
        heading = 340.0,
        action = 'thermite',
        scene = { pos = vector3(257.40, 220.20, 106.35), rot = vector3(0.0, 0.0, 336.48), ptfx = vector3(257.39, 221.20, 106.29) },
        swapFrom = 'hei_v_ilev_bk_gate_pris',
        swapTo = 'hei_v_ilev_bk_gate_molten'
    },
    {
        model = 746855201,
        pos = vector3(261.87, 221.69, 106.65),  -- Fixed target position on the door
        heading = 250.0,
        action = 'thermite',
        scene = { pos = vector3(261.75, 221.420, 106.35), rot = vector3(0.0, 0.0, 255.48), ptfx = vector3(261.80, 222.470, 106.283) },
        swapFrom = 'hei_v_ilev_bk_gate2_pris',
        swapTo = 'hei_v_ilev_bk_gate2_molten'
    },
    -- Main vault gates
    {
        model = -1508355822,
        pos = vector3(252.72, 220.95, 101.68),
        heading = 160.0,
        action = 'thermite',
        scene = { pos = vector3(252.95, 220.70, 101.76), rot = vector3(0.0, 0.0, 160.0), ptfx = vector3(252.985, 221.70, 101.72) },
        swapFrom = 'hei_v_ilev_bk_safegate_pris',
        swapTo = 'hei_v_ilev_bk_safegate_molten'
    },
    {
        model = -1508355822,
        pos = vector3(261.01, 215.01, 101.68),
        heading = 250.0,
        action = 'c4',
        scene = { pos = vector3(261.65, 215.60, 101.76), rot = vector3(0.0, 0.0, 252.0), ptfx = vector3(261.68, 216.63, 101.75) },
        swapFrom = 'hei_v_ilev_bk_safegate_pris',
        swapTo = 'hei_v_ilev_bk_safegate_molten',
        successMsg = 'Gate destroyed!'
    },
    -- Safe door (hexagonal pattern) - extended vault area
    {
        model = 0x24ACA5B5,  -- Safe door found via inspector
        pos = vector3(255.36, 229.38, 101.77),
        heading = 160.0,
        action = 'c4',
        scene = { pos = vector3(255.1959, 228.6486, 101.6832), rot = vector3(0.0, 0.0, 341.2872), ptfx = vector3(255.36, 230.38, 101.77) },
        successMsg = 'Lock broke!'
    },
}

-- ============================================================================
-- VAULT INTERACTION POINTS
-- ============================================================================
Config.LaptopHack = {
    model = 0x3B67F4C5,  -- Terminal to hack
    pos = vector3(257.64, 228.11, 102.14),  -- Terminal position
    scenePos = vector3(257.62, 228.25, 102.1834),  -- Where player stands
    sceneHeading = 340  -- Player facing direction
}

Config.LaserDrill = {
    model = 2774049745,
    pos = vector3(256.764, 241.272, 101.693),
    heading = 160.0,
    scene = { pos = vector3(257.35, 240.312, 102.0), rot = vector3(0.0, 0.0, 340.0) }
}

Config.MainVault = {
    doorPos = vector3(253.92, 224.56, 101.88),
    doorModel = 'v_ilev_bk_vaultdoor',
    openHeading = 75.0,
    closeHeading = 160.0
}

Config.ExtendedVault = {
    doorPos = vector3(256.518, 240.101, 101.701),
    doorModel = 'ch_prop_ch_vaultdoor01x',
    openHeading = 250.0,
    closeHeading = 160.0
}

-- Inner Vault Door (requires laptop hack THEN C4)
Config.InnerVaultDoor = {
    -- The door itself
    doorModel = 0x3C1E7DED,
    doorPos = vector3(263.60, 258.03, 102.17),

    -- Laptop hack (must be done first)
    laptop = {
        model = 0x3B67F4C5,
        pos = vector3(261.56, 258.31, 102.13),
        scenePos = vector3(261.3049, 257.7807, 101.6913),
        sceneHeading = 340.1198
    },

    -- C4 placement (only available after laptop hack)
    c4 = {
        scenePos = vector3(262.7211, 257.6381, 101.6913),
        sceneRot = vector3(0.0, 0.0, 343.6977),
        explosionPos = vector3(263.60, 258.03, 102.17)
    }
}

-- ============================================================================
-- LOOT SPAWNS
-- ============================================================================
Config.MainStack = {
    model = 'h4_prop_h4_cash_stack_01a',
    pos = vector3(264.265, 213.735, 101.531),
    heading = 250.0
}

Config.Trolleys = {
    -- Extended vault trolleys (first 4)
    { model = 'ch_prop_diamond_trolly_01c', pos = vector3(266.334, 255.849, 101.691), rewardType = 'diamond' },
    { model = 'ch_prop_diamond_trolly_01c', pos = vector3(269.230, 254.744, 101.691), rewardType = 'diamond' },
    { model = 'ch_prop_diamond_trolly_01c', pos = vector3(268.085, 251.274, 101.723), rewardType = 'diamond' },
    { model = 'ch_prop_diamond_trolly_01c', pos = vector3(266.076, 252.015, 101.691), rewardType = 'diamond' },
    -- Main vault trolleys
    { model = 'ch_prop_ch_cash_trolly_01b',  pos = vector3(266.351, 215.192, 100.683), heading = 115.0, rewardType = 'cash' },
    { model = 'ch_prop_gold_trolly_01a',     pos = vector3(265.107, 211.960, 100.683), heading = 35.0,  rewardType = 'gold' },
    { model = 'imp_prop_impexp_coke_trolly', pos = vector3(261.623, 213.510, 100.683), heading = 300.0, rewardType = 'cocaine' },
    { model = 'ch_prop_diamond_trolly_01c',  pos = vector3(262.819, 216.429, 100.683), heading = 200.0, rewardType = 'diamond' },
}

Config.Stacks = {
    { model = 'h4_prop_h4_cash_stack_01a', pos = vector3(265.812, 241.233, 101.581), heading = 250.0, type = 'cash' },
    { model = 'h4_prop_h4_cash_stack_01a', pos = vector3(268.112, 247.533, 101.581), heading = 250.0, type = 'cash' },
    { model = 'h4_prop_h4_cash_stack_01a', pos = vector3(254.062, 258.454, 101.581), heading = 70.0,  type = 'cash' },
    { model = 'h4_prop_h4_gold_stack_01a', pos = vector3(250.019, 247.602, 101.581), heading = 70.0,  type = 'gold' },
    { model = 'h4_prop_h4_gold_stack_01a', pos = vector3(251.988, 252.979, 101.581), heading = 70.0,  type = 'gold' },
}

Config.DrillBoxes = {
    { pos = vector3(258.267, 213.848, 101.883), rotation = vector3(0.0, 0.0, 160.0) },
    { pos = vector3(259.682, 218.327, 101.883), rotation = vector3(0.0, 0.0, 350.0) },
}

Config.CellGates = {
    { pos = vector3(260.399, 242.955, 101.801), rot = vector3(0.0, 0.0, 250.0) },
    { pos = vector3(262.399, 248.455, 101.801), rot = vector3(0.0, 0.0, 250.0) },
    { pos = vector3(264.409, 254.055, 101.801), rot = vector3(0.0, 0.0, 250.0) },
    { pos = vector3(255.205, 244.726, 101.801), rot = vector3(0.0, 0.0, 70.0) },
    { pos = vector3(257.205, 250.276, 101.801), rot = vector3(0.0, 0.0, 70.0) },
    { pos = vector3(259.225, 255.886, 101.801), rot = vector3(0.0, 0.0, 70.0) },
}

Config.GlassCutting = {
    displayPos = vector3(263.925, 260.656, 100.633),
    displayHeading = 340.0,
    rewardPos = vector3(263.925, 260.656, 101.6721),
    rewardRot = vector3(360.0, 0.0, 70.0)
}

Config.Paintings = {
    {
        scenePos = vector3(266.575, 259.565, 101.663),
        sceneRot = vector3(0.0, 0.0, 250.0),
        model = 'h4_prop_h4_painting_01e',
        objectPos = vector3(267.025, 259.545, 101.853),
        heading = 250.0
    },
    {
        scenePos = vector3(261.302, 261.792, 101.663),
        sceneRot = vector3(0.0, 0.0, 70.0),
        model = 'h4_prop_h4_painting_01f',
        objectPos = vector3(260.842, 261.932, 101.853),
        heading = 70.85
    },
}

-- ============================================================================
-- STRINGS / MESSAGES
-- ============================================================================
Config.Strings = {
    heistStarted = 'Pacific Standard Bank heist has started! Head to the bank.',
    requiredItems = 'Required: Drill, Bag, Cutter, C4, Thermite, Laptop, USB',
    needPolice = 'Not enough police in the city to start the heist.',
    cooldownActive = 'Bank is on lockdown. Try again in %d minutes.',
    needItem = 'You need: %s',
    needSwitchblade = 'You need a switchblade for this.',
    deliverToBuyer = 'Deliver the loot to the buyer. Check your GPS.',
    totalMoney = 'You received: $%s',
    policeAlert = 'ALERT: Pacific Standard Bank robbery in progress!',
    heistReset = 'Pacific Standard heist has been reset.',
}

-- ============================================================================
-- ANIMATION DICTIONARIES
-- ============================================================================
Config.AnimDicts = {
    thermal = 'anim@heists@ornate_bank@thermal_charge',
    hack = 'anim@heists@ornate_bank@hack',
    grabCash = 'anim@scripted@heist@ig1_table_grab@cash@male@',
    grabGold = 'anim@scripted@heist@ig1_table_grab@gold@male@',
    laserDrill = 'anim_heist@hs3f@ig9_vault_drill@laser_drill@',
    safeDrill = 'anim@heists@fleeca_bank@drilling',  -- Fleeca bank drilling animation
    glassCut = 'anim@scripted@heist@ig16_glass_cut@male@',
    painting = 'anim_heist@hs3f@ig11_steal_painting@male@',
    keypad = 'anim_heist@hs3f@ig1_hack_keypad@arcade@male@',
    trolley = 'anim@heists@ornate_bank@grab_cash',
}

-- Cover eyes distance (only cover eyes if within this distance of thermite)
Config.ThermiteCoverDistance = 5.0
