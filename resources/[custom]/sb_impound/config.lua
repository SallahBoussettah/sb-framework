Config = {}

-- Timing
Config.DisconnectTimeout = 60     -- 10 minutes in seconds
Config.CheckInterval = 30           -- Check abandoned vehicles every 30 seconds

-- Fees
Config.ImpoundFee = 500             -- Base impound fee
Config.DestroyedFee = 2000          -- Additional fee if vehicle was destroyed
Config.DailyStorageFee = 100        -- Per real hour storage fee (simulates daily)
Config.MaxStorageHours = 168        -- 7 days (168 hours) - after this, extra fees

-- NPC Model
Config.NPCModel = 's_m_y_armymech_01'

-- Impound Locations
Config.Locations = {
    ['lspd'] = {
        label = 'LSPD Impound Lot',
        npcPos = vector4(409.69, -1623.0, 29.29, 230.0),
        spawnPoints = {
            vector4(403.22, -1631.87, 29.29, 140.0),
            vector4(406.87, -1634.72, 29.29, 140.0),
            vector4(410.52, -1637.57, 29.29, 140.0),
            vector4(414.17, -1640.42, 29.29, 140.0),
        },
        blip = {
            sprite = 524,
            color = 1,
            scale = 0.8,
            label = 'LSPD Impound'
        }
    },
    ['sandy'] = {
        label = 'Sandy Shores Impound',
        npcPos = vector4(1880.98, 3692.21, 33.59, 210.0),
        spawnPoints = {
            vector4(1874.0, 3685.0, 33.59, 30.0),
            vector4(1878.0, 3682.0, 33.59, 30.0),
            vector4(1882.0, 3679.0, 33.59, 30.0),
        },
        blip = {
            sprite = 524,
            color = 1,
            scale = 0.8,
            label = 'Sandy Impound'
        }
    }
}

-- Vehicle state values (for reference)
-- 0 = out (in world)
-- 1 = stored (garage)
-- 2 = impounded
-- 3 = destroyed (impounded but needs repair fee)
