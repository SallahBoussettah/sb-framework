fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Third-Eye Targeting System'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/targets.lua',
    'client/zones.lua',
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
