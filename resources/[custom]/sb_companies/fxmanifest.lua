fx_version 'cerulean'
game 'gta5'

author 'Salah Eddine Boussettah'
description 'Company management, ordering, production, delivery, shop storage - supply chain economy'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/enums.lua',
    'shared/catalog.lua',
    'shared/recipes.lua',
}

client_scripts {
    'client/main.lua',
    'client/shop_storage.lua',
    'client/order_terminal.lua',
    'client/company_crafting.lua',
    'client/delivery.lua',
    'client/company_management.lua',
    'client/npc_sell.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/storage.lua',
    'server/orders.lua',
    'server/production.lua',
    'server/delivery.lua',
    'server/economy.lua',
    'server/management.lua',
    'server/npc_fallback.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/order_terminal.js',
    'html/order_terminal.css',
    'html/storage.js',
    'html/storage.css',
    'html/company_mgmt.js',
    'html/company_mgmt.css',
    'html/production.js',
    'html/production.css',
}

dependencies {
    'sb_core',
    'sb_notify',
    'sb_target',
    'sb_progressbar',
    'sb_inventory',
    'sb_minigame',
    'sb_mechanic_v2',
}
