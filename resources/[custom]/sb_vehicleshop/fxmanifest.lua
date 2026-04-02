fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Vehicle Dealership System - Buy vehicles with license requirement'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'
