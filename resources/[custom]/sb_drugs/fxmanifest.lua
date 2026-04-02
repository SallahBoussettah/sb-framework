fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Everyday Chaos RP - Drug Manufacturing & Distribution System'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/effects.lua',
    'client/selling.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/selling.lua'
}

dependencies {
    'sb_core',
    'sb_inventory',
    'sb_target',
    'sb_notify',
    'sb_progressbar',
    'sb_alerts',
    'bob74_ipl'
}
