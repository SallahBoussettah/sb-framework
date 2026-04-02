--[[
    Everyday Chaos RP - Core Framework
    Author: Salah Eddine Boussettah
]]

fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Everyday Chaos RP - Core Framework'
version '1.0.0'

-- Shared scripts (loaded first, on both client and server)
shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'shared/main.lua',
    'shared/items.lua',
    'shared/jobs.lua',
    'shared/gangs.lua',
    'shared/vehicles.lua',
    'locale/en.lua'
}

-- Server scripts
server_scripts {
    'server/main.lua',
    'server/player.lua',
    'server/functions.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/commands.lua'
}

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/functions.lua',
    'client/events.lua'
}

-- Dependencies
dependencies {
    'oxmysql'
}

-- Lua 5.4
lua54 'yes'

-- Provide exports
provides {
    'sb_core'
}
