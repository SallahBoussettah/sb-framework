fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Status Circles + Vehicle Dashboard HUD for Everyday Chaos RP'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'sb_core'
}

lua54 'yes'
