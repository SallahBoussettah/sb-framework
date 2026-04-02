fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Clothing Store System - Browse, preview, and purchase clothing'
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

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify'
}
