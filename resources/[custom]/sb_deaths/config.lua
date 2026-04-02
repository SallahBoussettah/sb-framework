--[[
    Everyday Chaos RP - Death System Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- Timer before respawn button appears (seconds)
Config.BleedoutTime = 30            -- 30s for testing, set to 300 (5 min) for production

-- Hospital bill for respawning
Config.HospitalBill = 500

-- Cash loss percentage on death (on top of hospital bill)
Config.CashLossPercent = 0

-- Respawn location (Pillbox Hill Medical Center)
Config.RespawnCoords = vector4(299.3590, -574.2596, 43.2608, 106.1657)

-- Disable controls while dead (can't shoot, punch, sprint, etc.)
Config.DisabledControls = {
    21,   -- Sprint
    24,   -- Attack
    25,   -- Aim
    47,   -- Weapon
    58,   -- Weapon
    263,  -- Melee
    264,  -- Melee
    257,  -- Melee
    140,  -- Melee
    141,  -- Melee
    142,  -- Melee
    143,  -- Melee
    73,   -- Vehicle Exit
}

-- Timecycle modifier for death visual
Config.DeathTimecycle = "DeathFailOut"
Config.DeathTimecycleStrength = 0.6

-- UI Text
Config.Text = {
    Title = "YOU ARE DYING",
    Subtitle = "BLEEDOUT IMMINENT",
    KilledBy = "KILLED BY",
    CallEmergency = "CALL EMERGENCY",
    Unknown = "Unknown",
    Suicide = "Suicide",
}
