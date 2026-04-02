fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Burger Shot Job - Food preparation and sales'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'images/bs_raw_patty.png',
    'images/bs_cooked_patty.png',
    'images/bs_bun.png',
    'images/bs_cheese.png',
    'images/bs_lettuce.png',
    'images/bs_tomato.png',
    'images/bs_potato.png',
    'images/bs_fries.png',
    'images/bs_burger.png',
    'images/bs_cola.png',
    'images/bs_meal.png',
}

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
    'sb_target',
    'sb_notify',
    'sb_progressbar',
    'sb_inventory'
}
