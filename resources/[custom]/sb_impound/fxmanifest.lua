fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Vehicle Impound System - Disconnect persistence, impound lots'
version '1.0.0'

dependencies {
    'oxmysql',
    'sb_core',
    'sb_notify',
    'sb_target',
    'sb_inventory',
    'sb_garage',
    'sb_banking'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/persistence.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
