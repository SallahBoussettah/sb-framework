fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'MLO-direct Apartment Rental System with door locking'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependencies {
    'oxmysql',
    'sb_core',
    'sb_notify',
    'sb_target',
    'sb_inventory',
    'sb_clothing',
    'sb_progressbar',
    'sb_doorlock'
}
