--[[
    Everyday Chaos RP - Multicharacter Config
    Author: Salah Eddine Boussettah
]]

Config = Config or {}

-- ============================================================================
-- SERVER BRANDING
-- ============================================================================
Config.ServerName = 'EVERYDAY CHAOS RP'
Config.ServerTagline = 'Your chaos, your story'

-- ============================================================================
-- CHARACTER SETTINGS
-- ============================================================================
Config.DefaultSlots = 3                    -- Default character slots (can be overridden by user.character_slots)
Config.AllowDelete = true                  -- Allow character deletion
Config.DeleteConfirmText = 'DELETE'        -- Text player must type to confirm deletion

-- Character creation restrictions
Config.MinAge = 18
Config.MaxAge = 80
Config.MinNameLength = 2
Config.MaxNameLength = 20

-- ============================================================================
-- SPAWN LOCATIONS
-- ============================================================================
Config.SpawnLocations = {
    {
        id = 'alta',
        name = 'Alta Street Apartments',
        description = 'Downtown Los Santos',
        coords = vector4(-270.52, -955.98, 31.22, 205.53),
        icon = 'building'
    },
    {
        id = 'integrity',
        name = 'Integrity Way',
        description = 'Pillbox Hill',
        coords = vector4(-47.52, -585.89, 37.95, 70.0),
        icon = 'building'
    },
    {
        id = 'delperro',
        name = 'Del Perro Heights',
        description = 'Del Perro Beach',
        coords = vector4(-1447.06, -537.96, 34.74, 205.0),
        icon = 'building'
    },
    {
        id = 'last',
        name = 'Last Location',
        description = 'Continue where you left off',
        coords = nil,
        useSaved = true,
        icon = 'map-pin'
    }
}

-- Default spawn for new characters
Config.NewCharacterSpawn = vector4(-270.52, -955.98, 31.22, 205.53)

-- ============================================================================
-- PREVIEW INTERIOR SETTINGS
-- ============================================================================
-- Using a simple interior for character preview
Config.PreviewLocation = {
    pedCoords = vector4(402.82, -996.37, -99.0, 180.0),      -- Where preview ped stands
    camCoords = vector4(402.82, -994.0, -98.5, 0.0),         -- Default camera position
    playerHide = vector4(402.82, -1000.0, -99.0, 0.0)        -- Where to hide real player
}

-- ============================================================================
-- CAMERA SETTINGS
-- ============================================================================
Config.CameraPositions = {
    fullBody = {
        offset = vector3(0.0, 2.2, 0.1),
        fov = 50.0,
        pointOffset = vector3(0.0, 0.0, 0.0)
    },
    face = {
        offset = vector3(0.0, 0.65, 0.6),
        fov = 30.0,
        pointOffset = vector3(0.0, 0.0, 0.65)
    },
    torso = {
        offset = vector3(0.0, 1.0, 0.2),
        fov = 40.0,
        pointOffset = vector3(0.0, 0.0, 0.2)
    },
    legs = {
        offset = vector3(0.0, 1.2, -0.4),
        fov = 45.0,
        pointOffset = vector3(0.0, 0.0, -0.4)
    },
    feet = {
        offset = vector3(0.0, 0.9, -0.8),
        fov = 40.0,
        pointOffset = vector3(0.0, 0.0, -0.9)
    }
}

Config.CameraTransitionTime = 500          -- Camera transition duration in ms
Config.CameraRotationSpeed = 2.0           -- Mouse rotation sensitivity

-- ============================================================================
-- HERITAGE/PARENTS (46 faces total)
-- ============================================================================
Config.Parents = {
    -- Male faces (0-20)
    male = {
        { id = 0, name = 'Benjamin' },
        { id = 1, name = 'Daniel' },
        { id = 2, name = 'Joshua' },
        { id = 3, name = 'Noah' },
        { id = 4, name = 'Andrew' },
        { id = 5, name = 'Juan' },
        { id = 6, name = 'Alex' },
        { id = 7, name = 'Isaac' },
        { id = 8, name = 'Evan' },
        { id = 9, name = 'Ethan' },
        { id = 10, name = 'Vincent' },
        { id = 11, name = 'Angel' },
        { id = 12, name = 'Diego' },
        { id = 13, name = 'Adrian' },
        { id = 14, name = 'Gabriel' },
        { id = 15, name = 'Michael' },
        { id = 16, name = 'Santiago' },
        { id = 17, name = 'Kevin' },
        { id = 18, name = 'Louis' },
        { id = 19, name = 'Samuel' },
        { id = 20, name = 'Anthony' }
    },
    -- Female faces (21-41)
    female = {
        { id = 21, name = 'Hannah' },
        { id = 22, name = 'Audrey' },
        { id = 23, name = 'Jasmine' },
        { id = 24, name = 'Giselle' },
        { id = 25, name = 'Amelia' },
        { id = 26, name = 'Isabella' },
        { id = 27, name = 'Zoe' },
        { id = 28, name = 'Ava' },
        { id = 29, name = 'Camila' },
        { id = 30, name = 'Violet' },
        { id = 31, name = 'Sophia' },
        { id = 32, name = 'Evelyn' },
        { id = 33, name = 'Nicole' },
        { id = 34, name = 'Ashley' },
        { id = 35, name = 'Grace' },
        { id = 36, name = 'Brianna' },
        { id = 37, name = 'Natalie' },
        { id = 38, name = 'Olivia' },
        { id = 39, name = 'Elizabeth' },
        { id = 40, name = 'Charlotte' },
        { id = 41, name = 'Emma' }
    },
    -- Special faces (42-45)
    special = {
        { id = 42, name = 'Claude' },
        { id = 43, name = 'Niko' },
        { id = 44, name = 'John' },
        { id = 45, name = 'Misty' }
    }
}

-- ============================================================================
-- FACE FEATURES (20 sliders)
-- ============================================================================
Config.FaceFeatures = {
    { id = 0, name = 'Nose Width', min = -1.0, max = 1.0 },
    { id = 1, name = 'Nose Peak Height', min = -1.0, max = 1.0 },
    { id = 2, name = 'Nose Peak Length', min = -1.0, max = 1.0 },
    { id = 3, name = 'Nose Bone Height', min = -1.0, max = 1.0 },
    { id = 4, name = 'Nose Peak Lower', min = -1.0, max = 1.0 },
    { id = 5, name = 'Nose Bone Twist', min = -1.0, max = 1.0 },
    { id = 6, name = 'Eyebrow Height', min = -1.0, max = 1.0 },
    { id = 7, name = 'Eyebrow Depth', min = -1.0, max = 1.0 },
    { id = 8, name = 'Cheekbone Height', min = -1.0, max = 1.0 },
    { id = 9, name = 'Cheekbone Width', min = -1.0, max = 1.0 },
    { id = 10, name = 'Cheek Width', min = -1.0, max = 1.0 },
    { id = 11, name = 'Eye Opening', min = -1.0, max = 1.0 },
    { id = 12, name = 'Lip Thickness', min = -1.0, max = 1.0 },
    { id = 13, name = 'Jaw Bone Width', min = -1.0, max = 1.0 },
    { id = 14, name = 'Jaw Bone Depth', min = -1.0, max = 1.0 },
    { id = 15, name = 'Chin Height', min = -1.0, max = 1.0 },
    { id = 16, name = 'Chin Depth', min = -1.0, max = 1.0 },
    { id = 17, name = 'Chin Width', min = -1.0, max = 1.0 },
    { id = 18, name = 'Chin Hole Size', min = -1.0, max = 1.0 },
    { id = 19, name = 'Neck Thickness', min = -1.0, max = 1.0 }
}

-- ============================================================================
-- HEAD OVERLAYS (13 total)
-- ============================================================================
Config.HeadOverlays = {
    { id = 0, name = 'Blemishes', hasColor = false, maxStyle = 23 },
    { id = 1, name = 'Facial Hair', hasColor = true, colorType = 1, maxStyle = 28 },
    { id = 2, name = 'Eyebrows', hasColor = true, colorType = 1, maxStyle = 33 },
    { id = 3, name = 'Ageing', hasColor = false, maxStyle = 14 },
    { id = 4, name = 'Makeup', hasColor = true, colorType = 2, maxStyle = 74 },
    { id = 5, name = 'Blush', hasColor = true, colorType = 2, maxStyle = 6 },
    { id = 6, name = 'Complexion', hasColor = false, maxStyle = 11 },
    { id = 7, name = 'Sun Damage', hasColor = false, maxStyle = 10 },
    { id = 8, name = 'Lipstick', hasColor = true, colorType = 2, maxStyle = 9 },
    { id = 9, name = 'Moles/Freckles', hasColor = false, maxStyle = 17 },
    { id = 10, name = 'Chest Hair', hasColor = true, colorType = 1, maxStyle = 16 },
    { id = 11, name = 'Body Blemishes', hasColor = false, maxStyle = 11 },
    { id = 12, name = 'Extra Blemishes', hasColor = false, maxStyle = 1 }
}

-- ============================================================================
-- CLOTHING COMPONENTS (12 total)
-- ============================================================================
Config.ClothingComponents = {
    { id = 0, name = 'Face', category = 'face' },
    { id = 1, name = 'Masks', category = 'accessories' },
    { id = 2, name = 'Hair', category = 'hair' },
    { id = 3, name = 'Torso', category = 'tops' },
    { id = 4, name = 'Legs', category = 'pants' },
    { id = 5, name = 'Bags', category = 'accessories' },
    { id = 6, name = 'Shoes', category = 'shoes' },
    { id = 7, name = 'Accessories', category = 'accessories' },
    { id = 8, name = 'Undershirts', category = 'tops' },
    { id = 9, name = 'Body Armor', category = 'accessories' },
    { id = 10, name = 'Decals', category = 'accessories' },
    { id = 11, name = 'Tops', category = 'tops' }
}

-- ============================================================================
-- PROPS (5 total)
-- ============================================================================
Config.Props = {
    { id = 0, name = 'Hats', category = 'hats' },
    { id = 1, name = 'Glasses', category = 'glasses' },
    { id = 2, name = 'Ears', category = 'accessories' },
    { id = 6, name = 'Watches', category = 'accessories' },
    { id = 7, name = 'Bracelets', category = 'accessories' }
}

-- ============================================================================
-- EYE COLORS (32 total)
-- ============================================================================
Config.EyeColors = {
    { id = 0, name = 'Green' },
    { id = 1, name = 'Emerald' },
    { id = 2, name = 'Light Blue' },
    { id = 3, name = 'Ocean Blue' },
    { id = 4, name = 'Light Brown' },
    { id = 5, name = 'Dark Brown' },
    { id = 6, name = 'Hazel' },
    { id = 7, name = 'Dark Gray' },
    { id = 8, name = 'Light Gray' },
    { id = 9, name = 'Pink' },
    { id = 10, name = 'Yellow' },
    { id = 11, name = 'Purple' },
    { id = 12, name = 'Blackout' },
    { id = 13, name = 'Shades of Gray' },
    { id = 14, name = 'Tequila Sunrise' },
    { id = 15, name = 'Atomic' },
    { id = 16, name = 'Warp' },
    { id = 17, name = 'ECola' },
    { id = 18, name = 'Space Ranger' },
    { id = 19, name = 'Ying Yang' },
    { id = 20, name = 'Bullseye' },
    { id = 21, name = 'Lizard' },
    { id = 22, name = 'Dragon' },
    { id = 23, name = 'Extra 1' },
    { id = 24, name = 'Extra 2' },
    { id = 25, name = 'Extra 3' },
    { id = 26, name = 'Extra 4' },
    { id = 27, name = 'Extra 5' },
    { id = 28, name = 'Extra 6' },
    { id = 29, name = 'Extra 7' },
    { id = 30, name = 'Extra 8' },
    { id = 31, name = 'Extra 9' }
}

-- ============================================================================
-- NATIONALITIES
-- ============================================================================
Config.Nationalities = {
    'American',
    'British',
    'Canadian',
    'Mexican',
    'Brazilian',
    'German',
    'French',
    'Italian',
    'Spanish',
    'Japanese',
    'Chinese',
    'Korean',
    'Australian',
    'Russian',
    'Indian',
    'Other'
}

-- ============================================================================
-- DEFAULT APPEARANCE
-- ============================================================================
Config.DefaultAppearance = {
    male = {
        model = 'mp_m_freemode_01',
        headBlend = {
            shapeFirst = 0,
            shapeSecond = 0,
            shapeMix = 0.5,
            skinFirst = 0,
            skinSecond = 0,
            skinMix = 0.5
        },
        faceFeatures = {},
        hair = { style = 0, color = 0, highlight = 0 },
        eyeColor = 0,
        overlays = {},
        components = {
            [0] = { drawable = 0, texture = 0 },
            [1] = { drawable = 0, texture = 0 },
            [2] = { drawable = 0, texture = 0 },
            [3] = { drawable = 0, texture = 0 },
            [4] = { drawable = 0, texture = 0 },
            [5] = { drawable = 0, texture = 0 },
            [6] = { drawable = 1, texture = 0 },
            [7] = { drawable = 0, texture = 0 },
            [8] = { drawable = 15, texture = 0 },
            [9] = { drawable = 0, texture = 0 },
            [10] = { drawable = 0, texture = 0 },
            [11] = { drawable = 15, texture = 0 }
        },
        props = {
            [0] = { drawable = -1, texture = 0 },
            [1] = { drawable = -1, texture = 0 },
            [2] = { drawable = -1, texture = 0 },
            [6] = { drawable = -1, texture = 0 },
            [7] = { drawable = -1, texture = 0 }
        }
    },
    female = {
        model = 'mp_f_freemode_01',
        headBlend = {
            shapeFirst = 21,
            shapeSecond = 0,
            shapeMix = 0.5,
            skinFirst = 21,
            skinSecond = 0,
            skinMix = 0.5
        },
        faceFeatures = {},
        hair = { style = 0, color = 0, highlight = 0 },
        eyeColor = 0,
        overlays = {},
        components = {
            [0] = { drawable = 0, texture = 0 },
            [1] = { drawable = 0, texture = 0 },
            [2] = { drawable = 0, texture = 0 },
            [3] = { drawable = 0, texture = 0 },
            [4] = { drawable = 0, texture = 0 },
            [5] = { drawable = 0, texture = 0 },
            [6] = { drawable = 1, texture = 0 },
            [7] = { drawable = 0, texture = 0 },
            [8] = { drawable = 15, texture = 0 },
            [9] = { drawable = 0, texture = 0 },
            [10] = { drawable = 0, texture = 0 },
            [11] = { drawable = 15, texture = 0 }
        },
        props = {
            [0] = { drawable = -1, texture = 0 },
            [1] = { drawable = -1, texture = 0 },
            [2] = { drawable = -1, texture = 0 },
            [6] = { drawable = -1, texture = 0 },
            [7] = { drawable = -1, texture = 0 }
        }
    }
}

-- ============================================================================
-- ANIMATIONS
-- ============================================================================
Config.IdleAnimation = {
    dict = 'anim@heists@heist_corona@single_team',
    anim = 'single_team_loop_boss'
}

Config.PreviewPoses = {
    { name = 'Arms Crossed',  dict = 'anim@heists@heist_corona@single_team', anim = 'single_team_loop_boss' },
    { name = 'Relaxed',       dict = 'amb@world_human_hang_out_street@male_b@idle_a', anim = 'idle_b' },
    { name = 'Confident',     dict = 'anim@mp_celebration@idles@male', anim = 'celebration_idle_m_a' },
    -- { name = 'Casual',        dict = 'amb@world_human_hang_out_street@female_hold_arm@idle_a', anim = 'idle_a' },
    { name = 'Leaning',       dict = 'amb@world_human_smoking@male@male_a@idle_a', anim = 'idle_a' },
    { name = 'Hands Behind',  dict = 'anim@heists@heist_corona@team_idles@male_a', anim = 'idle' },
    { name = 'Hip',           dict = 'amb@world_human_cop_idles@female@idle_a', anim = 'idle_b' },
    { name = 'Default',       dict = nil, anim = nil },
}

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
-- 1. In server.cfg, COMMENT OUT the [clothing] ensures
-- 2. Restart server and join as male character
-- 3. Open F8 console and type: clothingdebug
-- 4. Copy the printed COMPONENTS and PROPS values
-- 5. Join as female character and repeat step 3-4
-- 6. Update the values below with your exact counts
-- 7. Uncomment the [clothing] ensures and restart
-- ============================================================================

-- Vanilla drawable counts per component (YOUR ACTUAL COUNTS)
-- Set to 0 to show ALL (vanilla + addon) for that component
Config.VanillaDrawables = {
    male = {
        [1]  = 244,  -- Masks
        [3]  = 0,    -- Torso (keep at 0 - needed for body clipping)
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
        [3]  = 0,    -- Torso (keep at 0 - needed for body clipping)
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
