fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Developer Admin Utility Menu'
version '1.0.0'

dependencies {
    'sb_core',
    'sb_weapons',
    'sb_inventory'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/inspector.lua',
    'client/noclip.lua',
    'client/tools.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
