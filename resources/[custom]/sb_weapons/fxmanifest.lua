fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Weapon equip/holster system with magazine-based reload'
version '2.0.0'

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
    'sb_hud'
}
