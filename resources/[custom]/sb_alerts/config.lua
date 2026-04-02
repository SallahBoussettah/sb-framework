--[[
    Everyday Chaos RP - Alert System Config
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

Config.Debug = false

-- Max alerts stored in memory at once
Config.MaxAlerts = 50

-- Alert auto-expires after this many seconds
Config.AlertExpiry = 300

-- Max alerts visible on screen at once
Config.MaxVisible = 3

-- How long the toast stays visible before sliding out (seconds)
Config.ToastDuration = 15

-- Default blip duration in seconds (0 = until dismissed)
Config.DefaultBlipDuration = 120

-- ============================================================================
-- KEYBINDS
-- ============================================================================
Config.GPSKey = 'H'           -- Set GPS to alert location
Config.AcceptKey = 'Y'        -- Accept/respond to alert

-- ============================================================================
-- ALERT TYPES
-- ============================================================================

Config.AlertTypes = {
    ['police'] = {
        icon = 'shield',
        header = '911 Emergency',
        color = '#3b82f6',       -- Blue
        sound = { name = 'POLICE_SCANNER_CALL', set = 'DLC_HEIST_FLEECA_SOUNDSET' }
    },
    ['ems'] = {
        icon = 'heart-pulse',
        header = 'Medical Emergency',
        color = '#ef4444',       -- Red
        sound = { name = 'POLICE_SCANNER_CALL', set = 'DLC_HEIST_FLEECA_SOUNDSET' }
    },
    ['mechanic'] = {
        icon = 'wrench',
        header = 'Service Request',
        color = '#f97316',       -- Orange (accent)
        sound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
    },
    ['panic'] = {
        icon = 'alert-triangle',
        header = 'PANIC BUTTON',
        color = '#ef4444',       -- Red
        isPanic = true,          -- Special glow styling
        sound = { name = 'TIMER_STOP', set = 'HUD_MINI_GAME_SOUNDSET' }
    },
    ['general'] = {
        icon = 'bell',
        header = 'Dispatch',
        color = '#f97316',       -- Orange
        sound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
    }
}

-- ============================================================================
-- JOB TYPE ROUTING
-- ============================================================================
-- Map job types to alert types. When sending an alert to type 'leo',
-- it reaches all jobs with type='leo' (police, sheriff, etc.)

Config.JobTypeMapping = {
    ['leo']      = 'police',     -- police, sheriff → police alert style
    ['ems']      = 'ems',        -- ambulance → ems alert style
    ['mechanic'] = 'mechanic',   -- mechanic → mechanic alert style
}

-- ============================================================================
-- COOLDOWNS
-- ============================================================================
-- Per-source cooldowns to prevent alert spam (in seconds)

Config.SourceCooldowns = {
    ['sb_robbery']       = 120,
    ['sb_deaths']        = 30,
    ['sb_pacificheist']  = 300,
    ['sb_drugs']         = 10,
    ['911_call']         = 15,
    ['panic']            = 10,
    ['default']          = 5,
}

-- ============================================================================
-- BLIP DEFAULTS
-- ============================================================================

Config.DefaultBlip = {
    sprite = 161,       -- Standard alert blip
    color = 1,          -- Red
    scale = 1.0,
    flash = false,
    route = false,       -- GPS route (set on accept)
    duration = 120,      -- Seconds before blip disappears
}

-- Blip presets per alert type
Config.BlipPresets = {
    ['police'] = {
        sprite = 161,   -- Circle with star
        color = 38,     -- Blue
        scale = 1.2,
        flash = true,
    },
    ['ems'] = {
        sprite = 153,   -- Hospital cross
        color = 1,      -- Red
        scale = 1.2,
        flash = true,
    },
    ['mechanic'] = {
        sprite = 446,   -- Wrench
        color = 47,     -- Orange
        scale = 1.0,
        flash = false,
    },
    ['panic'] = {
        sprite = 526,   -- Dead player
        color = 1,      -- Red
        scale = 1.5,
        flash = true,
    },
    ['general'] = {
        sprite = 480,   -- Radar
        color = 47,     -- Orange
        scale = 1.0,
        flash = false,
    },
}
