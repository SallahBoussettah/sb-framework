fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'MMA Arena Betting System'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify',
    'oxmysql'
}
