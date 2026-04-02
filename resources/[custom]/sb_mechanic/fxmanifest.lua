fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Everyday Chaos RP - Mechanic & Benny\'s Elevator System'
version '2.0.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/duty.lua',
    'client/stations.lua',
    'client/mobile.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/duty.lua',
    'server/invoice.lua',
    'server/stations.lua',
    'server/mobile.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify',
    'sb_progressbar',
    'sb_inventory',
    'sb_alerts',
    'sb_garage'
}
