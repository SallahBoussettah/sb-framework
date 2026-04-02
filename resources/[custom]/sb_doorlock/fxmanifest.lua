fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Salah Eddine Boussettah'
description 'Door Lock System - Job-based door access control'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify'
}
