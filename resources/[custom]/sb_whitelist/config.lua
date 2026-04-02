Config = {}

-- Master toggle: set to false to disable whitelist (open server)
Config.WhitelistEnabled = true

-- Server password (required for non-whitelisted players to register)
-- Set to nil or "" to disable password requirement
Config.ServerPassword = "changeme"

-- Admins who can always join (by FiveM license identifier)
-- These bypass whitelist + password entirely
-- TESTING: Admin bypass disabled so you can test the full flow
-- Re-enable after testing:  "fivem:16735299",    -- Gold_Town (SatoSan)
Config.AdminIdentifiers = {
}
