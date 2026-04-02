Config = {}

-- Store Locations (vector4: x, y, z, heading)
-- changingSpot: where player stands to change clothes
-- cameraPos: where the camera is positioned
Config.Stores = {
    -- Ponsonbys (Luxury)
    {
        coords = vector4(-708.72, -152.13, 37.42, 120.0),
        type = 'ponsonbys',
        label = 'Ponsonbys - Rockford Hills',
        changingSpot = vector4(-705.7484, -151.4947, 36.4151, 242.4896),
        cameraPos = vector3(-703.2437, -152.1453, 37.9151),
    },
    {
        coords = vector4(-165.12, -302.94, 39.73, 251.0),
        type = 'ponsonbys',
        label = 'Ponsonbys - Burton',
        changingSpot = vector4(-167.5014, -300.6716, 38.7333, 9.4198),
        cameraPos = vector3(-168.3298, -298.3987, 40.3),
    },

    -- Suburban (Mid-range)
    {
        coords = vector4(127.02, -223.69, 54.56, 68.0),
        type = 'suburban',
        label = 'Suburban - Vinewood',
        changingSpot = vector4(118.3689, -224.8440, 53.5578, 180.2838),
        cameraPos = vector3(118.8530, -227.6219, 54.9578),
    },
    {
        coords = vector4(-1193.6481, -766.7231, 17.3162, 219.4181),
        type = 'suburban',
        label = 'Suburban - Del Perro',
        changingSpot = vector4(-1186.4131, -771.1270, 16.3306, 330.3205),
        cameraPos = vector3(-1185.6923, -768.4418, 17.8),
    },
    {
        coords = vector4(612.8331, 2762.8970, 42.0882, 277.3344),
        type = 'suburban',
        label = 'Suburban - Harmony',
        changingSpot = vector4(620.5638, 2766.8491, 41.0881, 34.01),
        cameraPos = vector3(618.753, 2768.9284, 42.4881),
    },

    -- Binco (Budget)
    {
        coords = vector4(78.5048, -1387.5775, 29.3761, 185.3854),
        type = 'binco',
        label = 'Binco - Strawberry',
        changingSpot = vector4(71.2085, -1387.2662, 28.3761, 178.0456),
        cameraPos = vector3(71.2100, -1390.4064, 29.9950),
    },
    {
        coords = vector4(-816.3330, -1073.4755, 11.3281, 119.4411),
        type = 'binco',
        label = 'Binco - Vespucci',
        changingSpot = vector4(-819.5828, -1067.0928, 10.3281, 120.4013),
        cameraPos = vector3(-822.3654, -1068.8058, 11.9501),
    },

    -- Discount Store
    {
        coords = vector4(422.8859, -811.5464, 29.4911, 3.4959),
        type = 'discount',
        label = 'Discount - La Mesa',
        changingSpot = vector4(429.7918, -811.6898, 28.4911, 1.8159),
        cameraPos = vector3(429.7116, -809.0652, 30.0433),
    },
    -- {
    --     coords = vector4(75.39, -1707.87, 29.29, 140.0),
    --     type = 'discount',
    --     label = 'Discount - Davis',
    --     changingSpot = nil,
    --     cameraPos = nil,
    -- },
}

-- Price Multipliers by Store Type
Config.PriceMultiplier = {
    ponsonbys = 2.0,
    suburban = 1.0,
    binco = 0.5,
    discount = 0.3,
}

-- Store Display Names
Config.StoreNames = {
    ponsonbys = 'Ponsonbys',
    suburban = 'Suburban',
    binco = 'Binco',
    discount = 'Discount Store',
}

-- NPC Model
Config.NPCModel = 's_f_y_shop_mid'

-- Blip Settings
Config.Blip = {
    sprite = 73,
    color = 47,
    scale = 0.8,
    label = 'Clothing Store',
}

-- Interaction Distance
Config.InteractDistance = 2.5

-- Base Prices by Component Type
Config.BasePrices = {
    -- Components
    [1]  = 150,   -- Masks
    [3]  = 250,   -- Torso/Upper
    [4]  = 200,   -- Legs/Pants
    [5]  = 100,   -- Bags/Parachute
    [6]  = 180,   -- Shoes
    [7]  = 80,    -- Accessories
    [8]  = 120,   -- Undershirts
    [9]  = 350,   -- Body Armor
    [10] = 50,    -- Decals
    [11] = 280,   -- Tops/Jackets

    -- Props (stored as strings for lookup)
    ['prop_0'] = 120,  -- Hats
    ['prop_1'] = 100,  -- Glasses
    ['prop_2'] = 60,   -- Ears
    ['prop_6'] = 200,  -- Watches
    ['prop_7'] = 80,   -- Bracelets
}

-- Clothing Categories (for UI tabs)
Config.Categories = {
    { id = 'tops', label = 'Tops', icon = 'fa-shirt', components = {11, 8} },
    { id = 'torso', label = 'Torso', icon = 'fa-vest', components = {3}, free = true }, -- Free for clipping fixes
    { id = 'pants', label = 'Pants', icon = 'fa-socks', components = {4} },
    { id = 'shoes', label = 'Shoes', icon = 'fa-shoe-prints', components = {6} },
    { id = 'accessories', label = 'Accessories', icon = 'fa-gem', components = {7, 5, 10} },
    { id = 'masks', label = 'Masks', icon = 'fa-mask', components = {1} },
    { id = 'armor', label = 'Armor', icon = 'fa-shield-halved', components = {9} },
    { id = 'hats', label = 'Hats', icon = 'fa-hat-cowboy', props = {0} },
    { id = 'glasses', label = 'Glasses', icon = 'fa-glasses', props = {1} },
    { id = 'watches', label = 'Watches', icon = 'fa-clock', props = {6} },
    { id = 'extras', label = 'Extras', icon = 'fa-star', props = {2} },  -- Removed 7 (bracelets) due to corrupted addon file
}

-- Free components (no charge - for fixing clipping issues)
Config.FreeComponents = {
    [3] = true, -- Torso is always free
}

-- Component Names (for display)
Config.ComponentNames = {
    [1]  = 'Mask',
    [3]  = 'Torso',
    [4]  = 'Pants',
    [5]  = 'Bag',
    [6]  = 'Shoes',
    [7]  = 'Accessory',
    [8]  = 'Undershirt',
    [9]  = 'Body Armor',
    [10] = 'Decal',
    [11] = 'Top',
}

-- Prop Names (for display)
Config.PropNames = {
    [0] = 'Hat',
    [1] = 'Glasses',
    [2] = 'Earpiece',
    [6] = 'Watch',
    [7] = 'Bracelet',
}

-- Saved Outfits
Config.MaxSavedOutfits = 5

-- ============================================================================
-- CUSTOM CLOTHING SETTINGS
-- ============================================================================
-- Set to true to ONLY show addon/custom clothing (hide vanilla GTA clothes)
-- NOTE: If your addon pack has items in wrong slots, some items may appear in wrong categories
Config.HideVanillaClothing = true

-- ============================================================================
-- HOW TO FIND YOUR EXACT VANILLA COUNTS:
-- ============================================================================
-- The values below are ESTIMATES for Game Build 3258. To get exact values:
--
-- 1. In server.cfg, COMMENT OUT the [clothing] ensures:
--    # ensure xsnb_male_part_a
--    # ensure xsnb_male_part_b
--    etc...
--
-- 2. Restart server and join as male character
-- 3. Open F8 console and type: clothingdebug
-- 4. Copy the printed COMPONENTS and PROPS values
-- 5. Join as female character and repeat step 3-4
-- 6. Update the values below with your exact counts
-- 7. Uncomment the [clothing] ensures and restart
-- ============================================================================

-- Vanilla drawable counts per component (YOUR ACTUAL COUNTS)
-- Addon clothing starts AFTER these indices
-- Set to 0 to show ALL (vanilla + addon) for that component
Config.VanillaDrawables = {
    male = {
        [1]  = 244,  -- Masks
        [3]  = 0,    -- Torso (keep at 0 - needed for body)
        [4]  = 202,  -- Pants
        [5]  = 111,  -- Bags
        [6]  = 151,  -- Shoes
        [7]  = 192,  -- Accessories
        [8]  = 213,  -- Undershirts
        [9]  = 62,   -- Body Armor
        [10] = 207,  -- Decals
        [11] = 544,  -- Tops
    },
    female = {
        [1]  = 245,  -- Masks
        [3]  = 0,    -- Torso (keep at 0 - needed for body)
        [4]  = 217,  -- Pants
        [5]  = 111,  -- Bags
        [6]  = 159,  -- Shoes
        [7]  = 162,  -- Accessories
        [8]  = 259,  -- Undershirts
        [9]  = 62,   -- Body Armor
        [10] = 223,  -- Decals
        [11] = 588,  -- Tops
    }
}

-- Vanilla prop counts
Config.VanillaProps = {
    male = {
        [0] = 221,   -- Hats
        [1] = 59,    -- Glasses
        [2] = 42,    -- Ears
        [6] = 49,    -- Watches
        [7] = 16,    -- Bracelets
    },
    female = {
        [0] = 220,   -- Hats
        [1] = 61,    -- Glasses
        [2] = 23,    -- Ears
        [6] = 38,    -- Watches
        [7] = 23,    -- Bracelets
    }
}

-- Camera Settings
Config.Camera = {
    defaultFov = 50.0,
    minFov = 20.0,
    maxFov = 70.0,
    rotateSpeed = 3.0,
    zoomSpeed = 2.0,
    defaultOffset = vector3(0.0, 2.5, 0.3),
    minHeight = -0.5,
    maxHeight = 1.0,
}
