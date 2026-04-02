--[[
    Everyday Chaos RP - Shop Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

Config.ShopNPCModel = 's_m_y_ammucity_01'
Config.ShopDistance = 2.5

Config.Blip = {
    sprite = 52,
    color = 2,
    scale = 0.8
}

Config.Shops = {
    { coords = vector4(24.47, -1346.62, 29.50, 271.0), label = "24/7" },
    { coords = vector4(-3039.54, 584.38, 7.91, 17.0), label = "24/7" },
    { coords = vector4(-3242.6274, 999.9471, 12.8307, 357), label = "24/7" },
    { coords = vector4(1727.9384, 6415.5342, 35.0372, 243.0), label = "24/7" },
    { coords = vector4(1959.6302, 3740.0039, 32.3437, 301.0), label = "24/7" },
    { coords = vector4(549.13, 2670.85, 42.16, 99.0), label = "24/7" },
    { coords = vector4(2557.46, 380.84, 108.62, 356.0), label = "24/7" },
    { coords = vector4(-1222.1261, -908.5334, 12.3264, 34.2968), label = "24/7" },
    { coords = vector4(-46.7694, -1758.1138, 29.4210, 50.8306), label = "24/7" },
    { coords = vector4(-706.0298, -914.2067, 19.2156, 85.2344), label = "24/7" },
}

Config.Categories = {
    { id = 'food', label = 'Food', icon = 'fa-utensils' },
    { id = 'drinks', label = 'Drinks', icon = 'fa-glass-water' },
    { id = 'electronics', label = 'Electronics', icon = 'fa-mobile-screen' },
}

Config.Items = {
    -- Food
    { name = 'apple', category = 'food', price = 5 },
    { name = 'banana', category = 'food', price = 5 },
    { name = 'bread', category = 'food', price = 8 },
    { name = 'chips', category = 'food', price = 4 },
    { name = 'cookie', category = 'food', price = 3 },
    { name = 'croissant', category = 'food', price = 7 },
    { name = 'donut', category = 'food', price = 5 },
    { name = 'muffin', category = 'food', price = 6 },
    { name = 'bagel', category = 'food', price = 7 },
    { name = 'brownie', category = 'food', price = 4 },
    { name = 'hotdog', category = 'food', price = 12 },
    { name = 'pizza', category = 'food', price = 20 },
    { name = 'bacon', category = 'food', price = 10 },
    -- Drinks
    { name = 'water_bottle', category = 'drinks', price = 3 },
    { name = 'cola', category = 'drinks', price = 5 },
    { name = 'sprite', category = 'drinks', price = 5 },
    { name = 'pepsi', category = 'drinks', price = 5 },
    { name = 'juice', category = 'drinks', price = 6 },
    { name = 'coffee', category = 'drinks', price = 7 },
    { name = 'milk', category = 'drinks', price = 4 },
    { name = 'redbull', category = 'drinks', price = 10 },
    { name = 'monster', category = 'drinks', price = 10 },
    { name = 'beer', category = 'drinks', price = 8 },
    -- Electronics
    { name = 'phone', category = 'electronics', price = 500 },
}
