fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Everyday Chaos RP - Shop System'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'sb_core',
    'sb_inventory',
    'sb_target',
    'sb_notify'
}
