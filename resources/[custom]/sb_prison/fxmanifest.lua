fx_version 'cerulean'
game 'gta5'

description 'SB Prison - Booking dashboard, sentencing & jail system'
author 'Salah Eddine Boussettah'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/credits.lua',
    'server/jobs.lua',
}

client_scripts {
    'client/nui.lua',
    'client/main.lua',
    'client/jobs.lua',
    'client/canteen.lua',
}

dependencies {
    'oxmysql',
    'sb_core',
    'sb_notify',
    'sb_target',
    'sb_progressbar',
    'sb_inventory',
    'sb_clothing',
    'sb_police',
    'sb_minigame',
}
