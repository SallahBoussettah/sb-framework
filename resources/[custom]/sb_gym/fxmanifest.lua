fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Gym & Fitness System - Skills, Equipment Workouts, Free Exercises, Passive Gains'
version '1.0.0'

dependencies {
    'sb_core',
    'sb_target',
    'sb_progressbar',
    'sb_notify',
    'sb_inventory'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/skills.lua',
    'client/exercises.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
