Config = {}

-- Position: 'top-right', 'top-left', 'top-center', 'bottom-right', 'bottom-left', 'bottom-center'
Config.Position = 'top-right'

-- Default duration in milliseconds
Config.DefaultDuration = 5000

-- Maximum notifications on screen at once
Config.MaxNotifications = 3

-- Animation duration in ms
Config.AnimationDuration = 300

-- Sound effects
Config.EnableSounds = true
Config.Sounds = {
    success = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    error = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    warning = { name = 'NAV_UP_DOWN', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    info = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    primary = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
}
