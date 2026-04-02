fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Job Center v2 - Public jobs with XP progression + Boss-managed RP job listings'
version '2.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    'config.lua',
    -- Add new public job definitions here:
    'shared/jobs/pizza_delivery.lua',
    'shared/jobs/taxi_driver.lua',
    'shared/jobs/bus_driver.lua',
    'shared/jobs/trash_collector.lua',
    'shared/jobs/mining.lua',
    'shared/jobs/newspaper_delivery.lua',
}

client_scripts {
    'client/main.lua',
    'client/publicjobs.lua',       -- Framework (load before job files)
    -- Add new public job client handlers here:
    'client/jobs/pizza_delivery.lua',
    'client/jobs/taxi_driver.lua',
    'client/jobs/bus_driver.lua',
    'client/jobs/trash_collector.lua',
    'client/jobs/mining.lua',
    'client/jobs/newspaper_delivery.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/publicjobs.lua',       -- Framework (load before job files)
    -- Add new public job server handlers here:
    'server/jobs/pizza_delivery.lua',
    'server/jobs/taxi_driver.lua',
    'server/jobs/bus_driver.lua',
    'server/jobs/trash_collector.lua',
    'server/jobs/mining.lua',
    'server/jobs/newspaper_delivery.lua',
}

dependencies {
    'sb_core',
    'sb_target',
    'sb_notify',
    'sb_progressbar',
    'sb_minigame',
    'sb_phone',
    'oxmysql'
}
