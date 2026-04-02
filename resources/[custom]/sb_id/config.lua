Config = {}

-- City Hall NPC
Config.NPCModel = 's_f_y_scrubs_01'  -- Female office worker
Config.InteractDistance = 2.5
Config.IDCost = 50
Config.ExpiryDays = 7  -- Real-world days until ID expires
Config.ShowDistance = 3.0  -- Max distance to show ID to another player
Config.AutoCloseTime = 10  -- Seconds before auto-closing shown ID

-- City Hall location (Los Santos City Hall - Rockford Hills)
Config.Location = {
    coords = vector4(-553.65, -191.87, 37.72, 190),  -- At the desk chair
    label = 'City Hall',
    blip = {
        sprite = 590,
        color = 3,
        scale = 0.7,
        label = 'City Hall'
    }
}

-- Blood type options (for display only - pulled from player metadata)
Config.BloodTypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' }
