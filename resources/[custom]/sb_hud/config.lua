Config = {}

-- HUD Position
Config.Position = 'bottom-left' -- 'bottom-left', 'bottom-right'

-- Status icons offset (adjust if circles overlap minimap on your resolution)
-- Use /hudpos in-game to enter edit mode and adjust with arrow keys
Config.StatusIconsOffset = { x = 0, y = 0 }

-- Update intervals (ms)
Config.UpdateInterval = 200      -- How often to update HUD values
Config.MoneyFadeDelay = 5000     -- How long money stays visible after change

-- Keybinds
Config.CinematicKey = 'Z'        -- Key to toggle cinematic mode (hide HUD)

-- Status thresholds (when to show warning colors)
Config.LowHealth = 25
Config.LowArmor = 25
Config.LowHunger = 25
Config.LowThirst = 25
Config.HighStress = 75

-- Show/hide specific elements
Config.ShowHealth = true
Config.ShowArmor = true
Config.ShowHunger = true
Config.ShowThirst = true
Config.ShowStamina = true
Config.ShowStress = true
Config.ShowMoney = true
Config.ShowJob = true
Config.ShowVoice = true

-- Vehicle Dashboard
Config.SpeedUnit = 'KM/H'       -- 'KM/H' or 'MPH'
Config.SpeedMultiplier = 3.6     -- 3.6 for km/h, 2.236936 for mph
Config.MaxSpeed = 260            -- Max speed on gauge (in configured unit)

-- Motorcycle classes (for bike dashboard)
Config.MotorcycleClasses = { [8] = true }   -- Class 8 = Motorcycles
Config.BicycleClasses = { [13] = true }     -- Class 13 = Bicycles

-- Voice indicator (matches pma-voice native audio distances)
Config.VoiceRanges = {
    { range = 1.5, label = 'Whisper', color = '#9ca3af' },
    { range = 3.0, label = 'Normal', color = '#22c55e' },
    { range = 6.0, label = 'Shout', color = '#f97316' }
}
Config.DefaultVoiceRange = 2 -- Index of default range (1-3)

-- Colors (customize your theme)
Config.Colors = {
    health = '#ef4444',
    healthLow = '#ef4444',
    armor = '#3b82f6',
    hunger = '#f97316',
    thirst = '#06b6d4',
    stamina = '#eab308',
    stress = '#a855f7',
    money = '#22c55e',
    bank = '#3b82f6',
    accent = '#f97316'
}
