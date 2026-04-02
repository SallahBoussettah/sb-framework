Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================
Config.Debug = false

-- ============================================================================
-- MAP BLIP
-- ============================================================================
Config.Blip = {
    coords = vector3(-45.88, -1289.88, 29.49),
    sprite = 311,       -- Boxing gloves
    color = 27,         -- Orange
    scale = 0.8,
    label = 'Fight Club'
}

-- ============================================================================
-- TIMERS (milliseconds)
-- ============================================================================
Config.Timers = {
    Betting = 60000,        -- 60s betting window
    MaxFight = 45000,       -- 45s max fight duration
    Cooldown = 120000,      -- 120s between fights
}

-- ============================================================================
-- SCHEDULE - In-game hours when fights auto-start
-- ============================================================================
Config.Schedule = { 20, 22, 0, 2 }

-- ============================================================================
-- BET LIMITS
-- ============================================================================
Config.MinBet = 50
Config.MaxBet = 50000
Config.MaxPayoutMultiplier = 10     -- Cap pari-mutuel odds at 10x

-- ============================================================================
-- BOOKMAKER NPCs
-- ============================================================================
Config.Bookmakers = {
    -- Inside fight club, near ring
    {
        coords = vector4(-53.6436, -1292.4198, 30.9064, 9.2169),
        model = 'a_m_y_smartcaspat_01',
        label = 'Bookmaker',
        icon = 'fa-hand-holding-dollar',
        distance = 2.5,
    },
}

-- ============================================================================
-- FIGHTER CONFIGURATION
-- ============================================================================
Config.Fighters = {
    -- Fighter Slot 1 (Red Corner)
    [1] = {
        position = vector4(-69.8278, -1270.4259, 22.8128, 315.3055),
        health = 200,
        models = {
            'a_m_y_mexthug_01',
            'g_m_y_lost_01',
            'g_m_y_mexgoon_01',
            'a_m_m_golfer_01',
            'a_m_y_beachvesp_01',
        },
        names = {
            'Iron Mike', 'El Diablo', 'The Crusher', 'Knuckles',
            'Mad Dog', 'Tombstone', 'Viper', 'Bone Breaker',
            'The Butcher', 'Thunder', 'Reaper', 'Sledgehammer',
            'Ghost', 'Savage', 'War Machine',
        },
    },
    -- Fighter Slot 2 (Blue Corner)
    [2] = {
        position = vector4(-66.0010, -1266.1418, 22.8128, 142.2840),
        health = 200,
        models = {
            'g_m_y_azteca_01',
            'g_m_y_ballaeast_01',
            'a_m_y_beach_03',
            'g_m_y_famca_01',
            'a_m_m_ktown_01',
        },
        names = {
            'Snake Eyes', 'Pitbull', 'The Mauler', 'Brick Wall',
            'Jackhammer', 'Razor', 'Bulldozer', 'Chainsaw',
            'Nightmare', 'Stone Cold', 'Havoc', 'Wrecking Ball',
            'Fury', 'Beast', 'Demolition',
        },
    },
}

-- ============================================================================
-- FIGHT AREA
-- ============================================================================
Config.CageCenter = vector3(-68.17, -1268.07, 22.81)
Config.CageRadius = 5.0

-- ============================================================================
-- ADMIN COMMAND
-- ============================================================================
Config.AdminCommand = 'mma'     -- /mma start|stop|status
