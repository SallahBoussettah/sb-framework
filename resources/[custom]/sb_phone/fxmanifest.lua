fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Smartphone V2 - React + Tailwind UI - calls, messages, contacts, bank, social, camera'
version '2.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    -- Audio files
    'html/audio/ringing.mp3',
    'html/audio/beep.mp3',
    'html/audio/unavailable.mp3',
    'html/audio/busy.mp3',
    'html/audio/invalid.mp3',
    -- Ringtones
    'html/audio/ringtones/default.mp3',
    'html/audio/ringtones/harp.mp3',
    'html/audio/ringtones/apex.mp3',
    'html/audio/ringtones/radar.mp3',
    'html/audio/ringtones/sencha.mp3',
    'html/audio/ringtones/silk.mp3',
    'html/audio/ringtones/summit.mp3',
    -- SFX overrides
    'html/audio/sfx/*.mp3'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/calls.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/notifications.lua'
}

dependencies {
    'sb_core',
    'sb_inventory',
    'sb_notify',
    'sb_banking'
}
