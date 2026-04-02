fx_version 'cerulean'
game 'gta5'

name 'sb_police'
description 'Police System - MDT, Interactions, Evidence (React + Tailwind UI)'
author 'Salah Eddine Boussettah'
version '3.0.0'  -- Sprint 9: Radar Gun, GSR, Breathalyzer, Vehicle Search

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/fonts/*',
    'html/img/*',
    'html/img/plates/*',
    'html/sounds/*.ogg',
    'html/sounds/*.mp3',
    'html/radar/*'
}

shared_scripts {
    'config.lua',
    'shared/*.lua'
}

client_scripts {
    'client/field.lua',         -- Field actions (cuff, escort, transport, search, tackle)
    'client/props.lua',         -- Scene management (cones, barriers, spike strips, flares)
    'client/station.lua',       -- Station interactions (duty, armory, locker, garage, boss)
    'client/sirens.lua',        -- Siren & lights system (L, semicolon, E keys)
    'client/k9.lua',            -- K9 Unit (K key, commands)
    'client/alpr.lua',          -- ALPR system (automatic license plate reader)
    'client/radar.lua',         -- Radar gun system (speed detection, Sprint 9)
    'client/interactions.lua',  -- sb_target registrations (depends on field.lua)
    'client/main.lua'           -- MDT and core functionality
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'oxmysql',
    'sb_core',
    'sb_notify',
    'sb_target',
    'sb_progressbar',
    'sb_inventory'
}
