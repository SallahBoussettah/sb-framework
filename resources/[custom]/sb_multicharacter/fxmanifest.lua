--[[
    Everyday Chaos RP - Multicharacter System
    Author: Salah Eddine Boussettah
]]

fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Character selection and creation system for Everyday Chaos RP'
version '1.0.0'

shared_scripts {
    '@sb_core/config.lua',
    '@sb_core/shared/main.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/camera.lua',
    'client/ped.lua',
    'client/nui.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'sb_core',
    'oxmysql'
}

lua54 'yes'
