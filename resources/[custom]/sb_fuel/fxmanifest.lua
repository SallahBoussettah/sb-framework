fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Immersive Fuel System - Gas stations, jerry cans, syphoning'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/stations.lua',
    'client/jerrycan.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify',
    'sb_progressbar',
    'sb_inventory'
}
