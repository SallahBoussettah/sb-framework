fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Vehicle Rental System - Bicycles, Scooters, Cars'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/rental.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/enforcement.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/images/*.webp'
}

dependencies {
    'oxmysql',
    'sb_core',
    'sb_target',
    'sb_notify',
    'sb_inventory'
}
