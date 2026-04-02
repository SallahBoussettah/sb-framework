fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Pacific Standard Bank Heist'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/animations.lua',
    'client/drilling.lua',
    'client/laptop.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify',
    'sb_progressbar',
    'sb_inventory',
    'sb_doorlock'
}
