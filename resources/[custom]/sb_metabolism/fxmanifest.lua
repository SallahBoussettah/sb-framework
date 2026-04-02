fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Metabolism System - Hunger & Thirst'
version '1.0.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'sb_core',
    'sb_inventory'
}
