--[[
    Everyday Chaos RP - Vehicle Definitions
    Author: Salah Eddine Boussettah

    Vehicle Structure:
    {
        name = 'model_name',
        brand = 'Brand Name',
        model = 'model_name',
        price = 50000,
        category = 'category',     -- super, sports, muscle, sedan, suv, etc.
        type = 'automobile',       -- automobile, bike, boat, plane, heli
        shop = 'shop_name'         -- Which dealership sells it
    }
]]

SBShared.Vehicles = {
    -- ========================================================================
    -- SUPER CARS
    -- ========================================================================
    ['adder'] = {
        name = 'adder',
        brand = 'Truffade',
        model = 'adder',
        price = 1000000,
        category = 'super',
        type = 'automobile',
        shop = 'luxury'
    },
    ['zentorno'] = {
        name = 'zentorno',
        brand = 'Pegassi',
        model = 'zentorno',
        price = 725000,
        category = 'super',
        type = 'automobile',
        shop = 'luxury'
    },
    ['t20'] = {
        name = 't20',
        brand = 'Progen',
        model = 't20',
        price = 2200000,
        category = 'super',
        type = 'automobile',
        shop = 'luxury'
    },
    ['turismor'] = {
        name = 'turismor',
        brand = 'Grotti',
        model = 'turismor',
        price = 500000,
        category = 'super',
        type = 'automobile',
        shop = 'luxury'
    },

    -- ========================================================================
    -- SPORTS CARS
    -- ========================================================================
    ['elegy2'] = {
        name = 'elegy2',
        brand = 'Annis',
        model = 'elegy2',
        price = 95000,
        category = 'sports',
        type = 'automobile',
        shop = 'pdm'
    },
    ['comet2'] = {
        name = 'comet2',
        brand = 'Pfister',
        model = 'comet2',
        price = 100000,
        category = 'sports',
        type = 'automobile',
        shop = 'pdm'
    },
    ['jester'] = {
        name = 'jester',
        brand = 'Dinka',
        model = 'jester',
        price = 240000,
        category = 'sports',
        type = 'automobile',
        shop = 'pdm'
    },

    -- ========================================================================
    -- MUSCLE CARS
    -- ========================================================================
    ['dominator'] = {
        name = 'dominator',
        brand = 'Vapid',
        model = 'dominator',
        price = 35000,
        category = 'muscle',
        type = 'automobile',
        shop = 'pdm'
    },
    ['gauntlet'] = {
        name = 'gauntlet',
        brand = 'Bravado',
        model = 'gauntlet',
        price = 32000,
        category = 'muscle',
        type = 'automobile',
        shop = 'pdm'
    },
    ['buffalo'] = {
        name = 'buffalo',
        brand = 'Bravado',
        model = 'buffalo',
        price = 35000,
        category = 'muscle',
        type = 'automobile',
        shop = 'pdm'
    },

    -- ========================================================================
    -- SEDANS
    -- ========================================================================
    ['sultan'] = {
        name = 'sultan',
        brand = 'Karin',
        model = 'sultan',
        price = 12000,
        category = 'sedan',
        type = 'automobile',
        shop = 'pdm'
    },
    ['primo'] = {
        name = 'primo',
        brand = 'Albany',
        model = 'primo',
        price = 9000,
        category = 'sedan',
        type = 'automobile',
        shop = 'pdm'
    },
    ['tailgater'] = {
        name = 'tailgater',
        brand = 'Obey',
        model = 'tailgater',
        price = 55000,
        category = 'sedan',
        type = 'automobile',
        shop = 'pdm'
    },

    -- ========================================================================
    -- SUVs
    -- ========================================================================
    ['baller'] = {
        name = 'baller',
        brand = 'Gallivanter',
        model = 'baller',
        price = 90000,
        category = 'suv',
        type = 'automobile',
        shop = 'pdm'
    },
    ['cavalcade'] = {
        name = 'cavalcade',
        brand = 'Albany',
        model = 'cavalcade',
        price = 60000,
        category = 'suv',
        type = 'automobile',
        shop = 'pdm'
    },

    -- ========================================================================
    -- MOTORCYCLES
    -- ========================================================================
    ['bati'] = {
        name = 'bati',
        brand = 'Pegassi',
        model = 'bati',
        price = 15000,
        category = 'motorcycle',
        type = 'bike',
        shop = 'pdm'
    },
    ['akuma'] = {
        name = 'akuma',
        brand = 'Dinka',
        model = 'akuma',
        price = 9000,
        category = 'motorcycle',
        type = 'bike',
        shop = 'pdm'
    },
    ['sanchez'] = {
        name = 'sanchez',
        brand = 'Maibatsu',
        model = 'sanchez',
        price = 7000,
        category = 'motorcycle',
        type = 'bike',
        shop = 'pdm'
    },

    -- ========================================================================
    -- COMPACTS
    -- ========================================================================
    ['blista'] = {
        name = 'blista',
        brand = 'Dinka',
        model = 'blista',
        price = 8000,
        category = 'compact',
        type = 'automobile',
        shop = 'pdm'
    },
    ['issi2'] = {
        name = 'issi2',
        brand = 'Weeny',
        model = 'issi2',
        price = 18000,
        category = 'compact',
        type = 'automobile',
        shop = 'pdm'
    },
}
