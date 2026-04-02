Config = {}

-- NPC Settings
Config.NPCModel = 's_m_m_cntrybar_01'  -- Casual clerk model

-- Time Settings (GTA V default: 48 real minutes = 1 in-game day)
Config.GameDayMinutes = 48              -- 48 real minutes = 1 in-game day
Config.MaxRentalDays = 7
Config.GracePeriodMinutes = 10           -- 10 minutes grace before late fees

-- Penalty Settings
Config.LateMultiplier = 2               -- Late fee = daily rate × 2 per day late
Config.StolenThresholdDays = 3          -- Marked stolen after 3 days late
Config.DespawnThresholdDays = 7         -- Auto-despawn after 7 days late
Config.BlacklistHours = 24              -- Rental ban duration after despawn

-- Damage Settings
Config.DamageThreshold = 200            -- Body damage below 800 = charged
Config.DamageRate = 2                   -- $2 per damage point

-- Lost Keys Fee
Config.LostKeysFee = 150                -- Fee if keys are not returned with vehicle

-- Rental plate format
Config.PlatePrefix = 'RNT'

-- Vehicles available for rent
Config.Vehicles = {
    bicycle = {
        { model = 'bmx', label = 'BMX', daily = 25, image = 'bmx.png' },
        { model = 'cruiser', label = 'Cruiser', daily = 30, image = 'cruiser.png' },
        { model = 'scorcher', label = 'Scorcher', daily = 35, image = 'scorcher.png' },
    },
    scooter = {
        { model = 'faggio', label = 'Faggio', daily = 75, image = 'faggio.png' },
        { model = 'faggio2', label = 'Faggio Sport', daily = 100, image = 'faggio2.png' },
    },
    car = {
        { model = 'issi2', label = 'Issi', daily = 150, image = 'issi2.png' },
        { model = 'asea', label = 'Asea', daily = 175, image = 'asea.png' },
        { model = 'emperor', label = 'Emperor', daily = 200, image = 'emperor.png' },
    }
}

-- Rental locations
Config.Locations = {
    ['mirrorpark'] = {
        label = 'Mirror Park Rentals',
        npcPos = vector4(1033.48, -763.95, 57.99, 270.0),
        spawnPoints = {
            vector4(1028.0, -766.0, 57.5, 90.0),
            vector4(1028.0, -770.0, 57.5, 90.0),
            vector4(1028.0, -774.0, 57.5, 90.0),
        },
        returnZone = { center = vector3(1030.0, -768.0, 57.5), radius = 15.0 },
        categories = { 'bicycle', 'scooter', 'car' },
        blip = { sprite = 225, color = 46, scale = 0.7, label = 'Vehicle Rentals' }
    },
    ['airport'] = {
        label = 'Airport Rentals',
        npcPos = vector4(-1037.34, -2733.82, 20.17, 240.0),
        spawnPoints = {
            vector4(-1040.0, -2738.0, 20.0, 60.0),
            vector4(-1044.0, -2740.0, 20.0, 60.0),
            vector4(-1048.0, -2742.0, 20.0, 60.0),
        },
        returnZone = { center = vector3(-1042.0, -2739.0, 20.0), radius = 20.0 },
        categories = { 'car' },
        blip = { sprite = 225, color = 46, scale = 0.7, label = 'Airport Rentals' }
    },
    ['busstation'] = {
        label = 'Bus Depot Rentals',
        npcPos = vector4(462.0, -605.0, 28.5, 90.0),
        spawnPoints = {
            vector4(458.0, -608.0, 28.0, 270.0),
            vector4(458.0, -612.0, 28.0, 270.0),
            vector4(458.0, -616.0, 28.0, 270.0),
        },
        returnZone = { center = vector3(460.0, -610.0, 28.0), radius = 15.0 },
        categories = { 'bicycle', 'scooter' },
        blip = { sprite = 225, color = 46, scale = 0.7, label = 'Bus Depot Rentals' }
    },
}

-- Category display names
Config.CategoryLabels = {
    bicycle = 'Bicycles',
    scooter = 'Scooters',
    car = 'Cars'
}
