--[[
    sb_whitelist - Whitelist System
    Author: Salah Eddine Boussettah
    Everyday Chaos RP
]]

fx_version 'cerulean'
game 'gta5'

description 'Everyday Chaos RP - Whitelist System'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql'
}
