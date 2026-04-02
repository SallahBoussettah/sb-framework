--[[
    Everyday Chaos RP - Gym & Fitness Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- SKILL SETTINGS
-- ============================================================================
Config.DefaultSkills = {
    strength = 20,   -- 0-100, affects melee damage & GTA STRENGTH stat
    stamina = 20,    -- 0-100, affects sprint duration & GTA STAMINA stat
    lung = 10        -- 0-100, affects underwater time & GTA LUNG_CAPACITY stat
}

Config.MaxSkillLevel = 100
Config.MinSkillLevel = 0

-- GTA Native stat names (for SetStatInt)
Config.StatNames = {
    strength = 'MP0_STRENGTH',
    stamina = 'MP0_STAMINA',
    lung = 'MP0_LUNG_CAPACITY'
}

-- ============================================================================
-- GYM LOCATIONS (for blips)
-- ============================================================================
-- Muscle Sands Beach has vanilla GTA gym props (benches, chin-up bars)
-- Other locations are for blips only - equipment depends on your MLOs
Config.GymLocations = {
    { coords = vector3(-1203.0, -1560.0, 4.6), label = 'Muscle Sands Beach' }  -- Vanilla outdoor gym
    -- Add more locations if you have gym MLOs installed
}

Config.BlipSprite = 311  -- Weight/gym icon
Config.BlipColor = 27    -- Orange
Config.BlipScale = 0.8

-- ============================================================================
-- EQUIPMENT WORKOUTS (sb_target on props)
-- ============================================================================
Config.Equipment = {
    -- Bench Press variations
    ['prop_muscle_bench_01'] = {
        label = 'Bench Press',
        skill = 'strength',
        gain = 0.8,
        duration = 8000,
        animation = { dict = 'amb@world_human_muscle_free_weights@male@barbell@base', anim = 'base' }
    },
    ['prop_muscle_bench_02'] = {
        label = 'Flat Bench',
        skill = 'strength',
        gain = 0.7,
        duration = 7000,
        animation = { dict = 'amb@world_human_muscle_free_weights@male@barbell@base', anim = 'base' }
    },
    ['prop_muscle_bench_03'] = {
        label = 'Incline Bench',
        skill = 'strength',
        gain = 0.9,
        duration = 9000,
        animation = { dict = 'amb@world_human_muscle_free_weights@male@barbell@base', anim = 'base' }
    },
    -- Chin-up bar
    ['prop_muscle_bench_05'] = {
        label = 'Pull-Up Bar',
        skill = 'strength',
        gain = 1.0,
        duration = 10000,
        animation = { dict = 'amb@prop_human_muscle_chin_ups@male@base', anim = 'base' }
    },
    ['prop_muscle_bench_06'] = {
        label = 'Chin-Up Bar',
        skill = 'strength',
        gain = 1.0,
        duration = 10000,
        animation = { dict = 'amb@prop_human_muscle_chin_ups@male@base', anim = 'base' }
    }
}

-- ============================================================================
-- FREE EXERCISES (anywhere, press J)
-- ============================================================================
Config.FreeExerciseKey = 'J'  -- Key to open exercise menu

Config.FreeExercises = {
    pushups = {
        label = 'Push-Ups',
        skill = 'strength',
        gain = 0.3,
        duration = 12000,
        animation = { dict = 'amb@world_human_push_ups@male@base', anim = 'base', flag = 1 }
    },
    situps = {
        label = 'Sit-Ups',
        skill = 'stamina',
        gain = 0.3,
        duration = 12000,
        animation = { dict = 'amb@world_human_sit_ups@male@base', anim = 'base', flag = 1 }
    },
    yoga = {
        label = 'Yoga',
        skill = 'lung',
        gain = 0.2,
        duration = 15000,
        animation = { dict = 'amb@world_human_yoga@male@base', anim = 'base_a', flag = 1 }
    }
}

-- ============================================================================
-- PASSIVE GAINS (automatic while playing)
-- ============================================================================
Config.PassiveGains = {
    running = {
        skill = 'stamina',
        amount = 0.05,
        interval = 30000  -- Check every 30 seconds
    },
    swimming = {
        skill = 'lung',
        amount = 0.1,
        interval = 20000  -- Check every 20 seconds
    },
    melee = {
        skill = 'strength',
        amount = 0.1,
        interval = 10000  -- After melee hits
    }
}

-- Minimum speed to count as running (m/s)
Config.RunningSpeedThreshold = 5.0

-- ============================================================================
-- PROTEIN BUFF
-- ============================================================================
Config.ProteinItem = 'protein_shake'
Config.ProteinBuffDuration = 300000  -- 5 minutes in ms
Config.ProteinBuffMultiplier = 2.0   -- 2x XP gain

-- ============================================================================
-- COOLDOWNS
-- ============================================================================
Config.WorkoutCooldown = 5000  -- 5 seconds between workouts
Config.SkillDecay = false      -- Disabled by default (skills don't decrease)

-- ============================================================================
-- UI / KEYBINDS
-- ============================================================================
Config.ExerciseKey = 'J'  -- Key to open free exercise menu (command: /sb_gym_free) -- Changed from G (G is used for police tackle)
Config.SkillsKey = 'K'    -- Key to view skills panel (command: /sb_gym_skills)
