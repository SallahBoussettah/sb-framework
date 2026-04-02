Config = {}

-- Admin permission (same as sb_admin)
Config.AcePerm = 'command.sb_admin'

-- Default weather on server start
Config.DefaultWeather = 'CLEAR'

-- How often to re-sync weather to all clients (ms)
-- Catches late joiners and keeps everyone in sync
Config.SyncInterval = 10000 -- 10 seconds

-- Valid weather types
Config.WeatherTypes = {
    'EXTRASUNNY',
    'CLEAR',
    'CLEARING',
    'CLOUDS',
    'OVERCAST',
    'SMOG',
    'FOGGY',
    'NEUTRAL',
    'RAIN',
    'THUNDER',
    'SNOW',
    'SNOWLIGHT',
    'BLIZZARD',
    'XMAS',
    'HALLOWEEN'
}
