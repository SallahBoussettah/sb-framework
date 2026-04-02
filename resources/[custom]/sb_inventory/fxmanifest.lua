fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Everyday Chaos RP - Inventory System'
version '1.0.0'

dependencies {
    'sb_core',
    'sb_target',
    'oxmysql'
}

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
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}
