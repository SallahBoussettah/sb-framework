fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Realistic vehicle condition system - 32 component damage model, degradation, symptoms, repairs'
version '2.1.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/components.lua',
    'shared/dtc_codes.lua',
    'shared/items_registry.lua',
    -- recipes.lua moved to sb_companies/shared/recipes.lua
    'shared/repairs.lua',
    'shared/repair_zones.lua',
}

client_scripts {
    'client/main.lua',
    'client/degradation.lua',
    'client/symptoms.lua',
    'client/diagnostics.lua',
    -- crafting.lua + supplier.lua removed: replaced by sb_companies order/dispenser system
    'client/elevator.lua',
    'client/repair_props.lua',
    'client/repair_vfx.lua',
    'client/car_jack.lua',
    'client/repair.lua',
    'client/repair_targets.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/skills.lua',
    'server/condition.lua',
    'server/diagnostics.lua',
    -- crafting.lua + supplier.lua removed: replaced by sb_companies production system
    'server/elevator.lua',
    'server/repair.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/diagnostics.css',
    'html/diagnostics.js',
    -- crafting.css + crafting.js removed: replaced by sb_companies NUI
}

dependencies {
    'sb_core',
    'sb_notify',
    'sb_target',
    'sb_progressbar',
    'sb_inventory',
    'sb_minigame',
}
