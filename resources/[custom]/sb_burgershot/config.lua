--[[
    Everyday Chaos RP - Burger Shot Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ============================================================================
-- GENERAL
-- ============================================================================
Config.Job = 'burgershot'

-- ============================================================================
-- BLIP
-- ============================================================================
Config.Blip = {
    coords = vector3(-1184.02, -884.52, 13.13),
    sprite = 106,       -- Burger icon
    color = 46,         -- Orange
    scale = 0.7,
    shortRange = true,
    label = 'Burger Shot'
}

-- ============================================================================
-- CLOCK IN / DUTY
-- ============================================================================
Config.ClockIn = {
    coords = vector3(-1192.3638, -898.0878, 13.9742),
    heading = 117.8464,
    model = 's_f_y_sweatshop_01',    -- NPC model
    label = 'Clock In/Out',
    icon = 'fa-clock'
}

-- ============================================================================
-- SUPPLY FRIDGE (Employee buys raw ingredients)
-- ============================================================================
Config.SupplyFridge = {
    coords = vector3(-1201.9807, -900.6702, 15.2151),
    label = 'Supply Fridge',
    icon = 'fa-box',
    distance = 2.0,
    items = {
        { name = 'bs_raw_patty', label = 'Raw Patty',     price = 5 },
        { name = 'bs_bun',       label = 'Burger Bun',    price = 3 },
        { name = 'bs_cheese',    label = 'Cheese Slice',  price = 2 },
        { name = 'bs_lettuce',   label = 'Lettuce',       price = 2 },
        { name = 'bs_tomato',    label = 'Tomato Slice',  price = 2 },
        { name = 'bs_potato',    label = 'Raw Potato',    price = 3 },
    }
}

-- ============================================================================
-- COOKING STATIONS
-- ============================================================================
Config.Stations = {
    {
        id = 'fry_station',
        label = 'Fry Station',
        icon = 'fa-fire',
        coords = vector3(-1200.8806, -896.7407, 14.8176),
        distance = 1.5,
        recipe = {
            inputs = { { name = 'bs_potato', amount = 1 } },
            output = { name = 'bs_fries', amount = 1 },
            duration = 8000,
            animation = { dict = 'amb@prop_human_bbq@male@idle_a', anim = 'idle_b', flag = 1 },
            label = 'Frying Potatoes...'
        }
    },
    {
        id = 'grill_station',
        label = 'Grill Station',
        icon = 'fa-fire-burner',
        coords = vector3(-1198.2487, -895.1503, 14.8829),
        distance = 1.5,
        recipe = {
            inputs = { { name = 'bs_raw_patty', amount = 1 } },
            output = { name = 'bs_cooked_patty', amount = 1 },
            duration = 10000,
            animation = { dict = 'amb@prop_human_bbq@male@idle_a', anim = 'idle_b', flag = 1 },
            label = 'Grilling Patty...'
        }
    },
    {
        id = 'burger_assembly',
        label = 'Burger Assembly',
        icon = 'fa-burger',
        coords = vector3(-1197.2905, -898.1119, 14.9123),
        distance = 1.5,
        recipe = {
            inputs = {
                { name = 'bs_cooked_patty', amount = 1 },
                { name = 'bs_bun', amount = 1 },
                { name = 'bs_cheese', amount = 1 },
                { name = 'bs_lettuce', amount = 1 },
                { name = 'bs_tomato', amount = 1 },
            },
            output = { name = 'bs_burger', amount = 1 },
            duration = 6000,
            animation = { dict = 'mini@repair', anim = 'fixing_a_player', flag = 1 },
            label = 'Assembling Burger...'
        }
    },
    {
        id = 'drink_station',
        label = 'Drink Station',
        icon = 'fa-cup-straw',
        coords = vector3(-1197.0042, -895.0590, 14.4314),
        distance = 1.5,
        recipe = {
            inputs = {},  -- Free to pour (fountain drink)
            output = { name = 'bs_cola', amount = 1 },
            duration = 4000,
            animation = { dict = 'mini@repair', anim = 'fixing_a_player', flag = 1 },
            label = 'Pouring Drink...'
        }
    },
    {
        id = 'meal_packing',
        label = 'Meal Packing',
        icon = 'fa-box-open',
        coords = vector3(-1196.3810, -899.1322, 14.8288),
        distance = 1.5,
        recipe = {
            inputs = {
                { name = 'bs_burger', amount = 1 },
                { name = 'bs_fries', amount = 1 },
                { name = 'bs_cola', amount = 1 },
            },
            output = { name = 'bs_meal', amount = 1 },
            duration = 5000,
            animation = { dict = 'mini@repair', anim = 'fixing_a_player', flag = 1 },
            label = 'Packing Meal...'
        }
    },
}

-- ============================================================================
-- CUSTOMER COUNTER (Sell finished items to public)
-- ============================================================================
Config.Counter = {
    coords = vector3(-1194.1671, -894.8373, 15.1662),
    distance = 1.5,
    label = 'Service Counter',
    icon = 'fa-cash-register',
    -- Prices customers pay
    prices = {
        ['bs_fries']  = 25,
        ['bs_burger'] = 50,
        ['bs_cola']   = 15,
        ['bs_meal']   = 80,
    }
}
