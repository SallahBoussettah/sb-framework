--[[
    Everyday Chaos RP - Item Definitions
    Author: Salah Eddine Boussettah

    NOTE: The database (sb_items) is the source of truth for item definitions.
    This file is a Lua-side cache for quick lookups without DB queries.
    Keep this in sync with sb_inventory.sql.

    Categories: food, drink, weapon, ammo
]]

SBShared.Items = {

    -- ========================================================================
    -- FOOD (15 items)
    -- ========================================================================
    ['apple'] = { name = 'apple', label = 'Apple', type = 'item', image = 'apple.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A fresh juicy apple' },
    ['banana'] = { name = 'banana', label = 'Banana', type = 'item', image = 'banana.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A ripe banana' },
    ['burger'] = { name = 'burger', label = 'Burger', type = 'item', image = 'burger.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A delicious burger' },
    ['bread'] = { name = 'bread', label = 'Bread', type = 'item', image = 'bread.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A loaf of fresh bread' },
    ['bacon'] = { name = 'bacon', label = 'Bacon', type = 'item', image = 'bacon.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'Crispy fried bacon' },
    ['chips'] = { name = 'chips', label = 'Chips', type = 'item', image = 'chips.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A bag of crispy chips' },
    ['cookie'] = { name = 'cookie', label = 'Cookie', type = 'item', image = 'cookie.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A chocolate chip cookie' },
    ['croissant'] = { name = 'croissant', label = 'Croissant', type = 'item', image = 'croissant.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A buttery croissant' },
    ['donut'] = { name = 'donut', label = 'Donut', type = 'item', image = 'donut.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A glazed donut' },
    ['hotdog'] = { name = 'hotdog', label = 'Hot Dog', type = 'item', image = 'hotdog.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A classic hot dog' },
    ['pizza'] = { name = 'pizza', label = 'Pizza Slice', type = 'item', image = 'pizza.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A cheesy slice of pizza' },
    ['fries'] = { name = 'fries', label = 'Fries', type = 'item', image = 'fries.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'Golden french fries' },
    ['muffin'] = { name = 'muffin', label = 'Muffin', type = 'item', image = 'muffin.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A blueberry muffin' },
    ['bagel'] = { name = 'bagel', label = 'Bagel', type = 'item', image = 'bagel.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A fresh bagel' },
    ['brownie'] = { name = 'brownie', label = 'Brownie', type = 'item', image = 'brownie.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A chocolate brownie' },

    -- ========================================================================
    -- DRINKS (10 items)
    -- ========================================================================
    ['water_bottle'] = { name = 'water_bottle', label = 'Water Bottle', type = 'item', image = 'water_bottle.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'Fresh water to quench your thirst' },
    ['cola'] = { name = 'cola', label = 'Cola', type = 'item', image = 'cola.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A refreshing cola' },
    ['coffee'] = { name = 'coffee', label = 'Coffee', type = 'item', image = 'coffee.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'Hot coffee to start your day' },
    ['juice'] = { name = 'juice', label = 'Juice', type = 'item', image = 'juice.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A fresh fruit juice' },
    ['beer'] = { name = 'beer', label = 'Beer', type = 'item', image = 'beer.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A cold beer' },
    ['milk'] = { name = 'milk', label = 'Milk', type = 'item', image = 'milk.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A glass of cold milk' },
    ['sprite'] = { name = 'sprite', label = 'Sprite', type = 'item', image = 'sprite.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A lemon-lime soda' },
    ['redbull'] = { name = 'redbull', label = 'Red Bull', type = 'item', image = 'redbull.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'An energy drink that gives you wings' },
    ['pepsi'] = { name = 'pepsi', label = 'Pepsi', type = 'item', image = 'pepsi.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A refreshing Pepsi' },
    ['monster'] = { name = 'monster', label = 'Monster Energy', type = 'item', image = 'monster.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A powerful energy drink' },

    -- ========================================================================
    -- WEAPONS (add more as they get registered in sb_weapons/config.lua)
    -- ========================================================================
    ['weapon_pistol'] = { name = 'weapon_pistol', label = 'Pistol', type = 'weapon', image = 'pistol.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'A standard 9mm pistol' },

    -- ========================================================================
    -- AMMO
    -- ========================================================================
    ['pistol_ammo'] = { name = 'pistol_ammo', label = '9mm Round', type = 'item', image = 'pistol_ammo.png', unique = false, useable = false, shouldClose = false, category = 'ammo', description = 'A single 9mm round' },
    ['p_ammobox'] = { name = 'p_ammobox', label = 'Ammo Box', type = 'item', image = 'p_ammobox.png', unique = true, useable = false, shouldClose = false, category = 'ammo', description = '9mm ammo box (holds up to 100 rounds)' },

    -- ========================================================================
    -- MAGAZINES
    -- ========================================================================
    ['p_quick_mag'] = { name = 'p_quick_mag', label = 'Quick Mag', type = 'item', image = 'p_quick_mag.png', unique = false, useable = true, shouldClose = true, category = 'magazine', description = '7-round pistol magazine (fast reload)' },
    ['p_stand_mag'] = { name = 'p_stand_mag', label = 'Standard Mag', type = 'item', image = 'p_stand_mag.png', unique = false, useable = true, shouldClose = true, category = 'magazine', description = '10-round pistol magazine' },
    ['p_extended_mag'] = { name = 'p_extended_mag', label = 'Extended Mag', type = 'item', image = 'p_extended_mag.png', unique = false, useable = true, shouldClose = true, category = 'magazine', description = '15-round extended pistol magazine (slow reload)' },

    -- ========================================================================
    -- BANKING
    -- ========================================================================
    ['creditcard'] = { name = 'creditcard', label = 'Credit Card', type = 'item', image = 'creditcard.png', unique = true, useable = false, shouldClose = false, category = 'misc', description = 'A Maze Bank credit card for ATM access' },

    -- ========================================================================
    -- DOCUMENTS & LICENSES
    -- ========================================================================
    ['id_card'] = { name = 'id_card', label = 'ID Card', type = 'item', image = 'id_card.png', unique = true, useable = true, shouldClose = true, category = 'document', description = 'Government-issued identification card' },
    ['car_license'] = { name = 'car_license', label = 'Driver\'s License', type = 'item', image = 'car_license.png', unique = true, useable = true, shouldClose = true, category = 'document', description = 'Class C driver\'s license - required to purchase vehicles' },
    ['dmv_theory_cert'] = { name = 'dmv_theory_cert', label = 'Theory Exam Certificate', type = 'item', image = 'dmv_theory_cert.png', unique = true, useable = false, shouldClose = false, category = 'document', description = 'DMV theory exam passed - required for parking test' },
    ['dmv_parking_cert'] = { name = 'dmv_parking_cert', label = 'Parking Test Certificate', type = 'item', image = 'dmv_parking_cert.png', unique = true, useable = false, shouldClose = false, category = 'document', description = 'DMV parking test passed - required for driving test' },

    -- ========================================================================
    -- VEHICLE ITEMS
    -- ========================================================================
    ['car_keys'] = { name = 'car_keys', label = 'Car Keys', type = 'item', image = 'car_keys.png', unique = true, useable = true, shouldClose = true, category = 'misc', description = 'Keys to your vehicle' },

    -- ========================================================================
    -- GYM & FITNESS
    -- ========================================================================
    ['protein_shake'] = { name = 'protein_shake', label = 'Protein Shake', type = 'item', image = 'protein_shake.png', unique = false, useable = true, shouldClose = true, category = 'consumable', description = 'A high-protein shake that doubles gym XP for 5 minutes' },

    -- ========================================================================
    -- PACIFIC HEIST - TOOLS
    -- ========================================================================
    ['heist_drill'] = { name = 'heist_drill', label = 'Thermal Drill', type = 'item', image = 'heist_drill.png', unique = true, useable = false, shouldClose = false, category = 'heist', description = 'Professional-grade laser thermal drill for vault doors' },
    ['heist_bag'] = { name = 'heist_bag', label = 'Heist Bag', type = 'item', image = 'heist_bag.png', unique = true, useable = false, shouldClose = false, category = 'heist', description = 'Tactical duffel bag for carrying loot' },
    ['glass_cutter'] = { name = 'glass_cutter', label = 'Glass Cutter', type = 'item', image = 'glass_cutter.png', unique = true, useable = false, shouldClose = false, category = 'heist', description = 'Precision glass cutting tool with diamond tip' },
    ['c4_explosive'] = { name = 'c4_explosive', label = 'C4 Explosive', type = 'item', image = 'c4_explosive.png', unique = false, useable = false, shouldClose = false, category = 'heist', description = 'Military-grade plastic explosive with detonator' },
    ['thermite_charge'] = { name = 'thermite_charge', label = 'Thermite Charge', type = 'item', image = 'thermite_charge.png', unique = false, useable = false, shouldClose = false, category = 'heist', description = 'Incendiary charge for melting through metal' },
    ['hacking_laptop'] = { name = 'hacking_laptop', label = 'Hacking Laptop', type = 'item', image = 'hacking_laptop.png', unique = true, useable = false, shouldClose = false, category = 'heist', description = 'Portable hacking workstation' },
    ['trojan_usb'] = { name = 'trojan_usb', label = 'Trojan USB', type = 'item', image = 'trojan_usb.png', unique = false, useable = false, shouldClose = false, category = 'heist', description = 'USB drive loaded with malware' },
    ['switchblade'] = { name = 'switchblade', label = 'Switchblade', type = 'item', image = 'switchblade.png', unique = true, useable = false, shouldClose = false, category = 'heist', description = 'Sharp folding knife for cutting paintings' },
    
    -- ========================================================================
    -- PACIFIC HEIST - LOOT
    -- ========================================================================
    ['gold_bar'] = { name = 'gold_bar', label = 'Gold Bar', type = 'item', image = 'gold_bar.png', unique = false, useable = false, shouldClose = false, category = 'valuable', description = 'Solid gold bullion bar' },
    ['diamond_pouch'] = { name = 'diamond_pouch', label = 'Diamond Pouch', type = 'item', image = 'diamond_pouch.png', unique = false, useable = false, shouldClose = false, category = 'valuable', description = 'Small pouch containing loose diamonds' },
    ['cocaine_brick'] = { name = 'cocaine_brick', label = 'Cocaine Brick', type = 'item', image = 'cocaine_brick.png', unique = false, useable = false, shouldClose = false, category = 'contraband', description = 'Wrapped brick of cocaine' },
    ['panther_statue'] = { name = 'panther_statue', label = 'Panther Statue', type = 'item', image = 'panther_statue.png', unique = true, useable = false, shouldClose = false, category = 'valuable', description = 'Black onyx panther figurine' },
    ['diamond_necklace'] = { name = 'diamond_necklace', label = 'Diamond Necklace', type = 'item', image = 'diamond_necklace.png', unique = true, useable = false, shouldClose = false, category = 'valuable', description = 'Elegant platinum diamond necklace' },
    ['vintage_wine'] = { name = 'vintage_wine', label = 'Vintage Wine', type = 'item', image = 'vintage_wine.png', unique = true, useable = false, shouldClose = false, category = 'valuable', description = 'Rare vintage wine bottle' },
    ['vault_painting'] = { name = 'vault_painting', label = 'Vault Painting', type = 'item', image = 'vault_painting.png', unique = true, useable = false, shouldClose = false, category = 'valuable', description = 'Rolled canvas painting from the vault' },
    ['rare_watch'] = { name = 'rare_watch', label = 'Rare Watch', type = 'item', image = 'rare_watch.png', unique = true, useable = false, shouldClose = false, category = 'valuable', description = 'Luxury gold timepiece' },

    -- ========================================================================
    -- BURGER SHOT - INGREDIENTS
    -- ========================================================================
    ['bs_raw_patty'] = { name = 'bs_raw_patty', label = 'Raw Patty', type = 'item', image = 'bs_raw_patty.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'A raw beef patty, needs grilling' },
    ['bs_cooked_patty'] = { name = 'bs_cooked_patty', label = 'Cooked Patty', type = 'item', image = 'bs_cooked_patty.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'A freshly grilled beef patty' },
    ['bs_bun'] = { name = 'bs_bun', label = 'Burger Bun', type = 'item', image = 'bs_bun.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'A sesame seed burger bun' },
    ['bs_cheese'] = { name = 'bs_cheese', label = 'Cheese Slice', type = 'item', image = 'bs_cheese.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'A slice of American cheese' },
    ['bs_lettuce'] = { name = 'bs_lettuce', label = 'Lettuce', type = 'item', image = 'bs_lettuce.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'Fresh shredded lettuce' },
    ['bs_tomato'] = { name = 'bs_tomato', label = 'Tomato Slice', type = 'item', image = 'bs_tomato.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'A ripe tomato slice' },
    ['bs_potato'] = { name = 'bs_potato', label = 'Raw Potato', type = 'item', image = 'bs_potato.png', unique = false, useable = false, shouldClose = false, category = 'food_ingredient', description = 'A raw potato, ready for frying' },

    -- ========================================================================
    -- BURGER SHOT - FINISHED FOOD
    -- ========================================================================
    ['bs_fries'] = { name = 'bs_fries', label = 'Fries', type = 'item', image = 'bs_fries.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'Golden crispy fries from Burger Shot' },
    ['bs_burger'] = { name = 'bs_burger', label = 'Bleeder Burger', type = 'item', image = 'bs_burger.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'The famous Bleeder Burger with all the fixings' },
    ['bs_cola'] = { name = 'bs_cola', label = 'eCola', type = 'item', image = 'bs_cola.png', unique = false, useable = true, shouldClose = true, category = 'drink', description = 'A refreshing ice-cold eCola' },
    ['bs_meal'] = { name = 'bs_meal', label = 'Murder Meal Box', type = 'item', image = 'bs_meal.png', unique = false, useable = true, shouldClose = true, category = 'food', description = 'A complete Murder Meal: burger, fries, and eCola' },

    -- ========================================================================
    -- FUEL & VEHICLE MAINTENANCE
    -- ========================================================================
    ['jerrycan'] = { name = 'jerrycan', label = 'Jerry Can', type = 'item', image = 'jerrycan.png', unique = false, useable = true, shouldClose = true, category = 'tool', description = 'Portable fuel container (20L capacity)' },
    ['syphon_kit'] = { name = 'syphon_kit', label = 'Syphon Kit', type = 'item', image = 'syphon_kit.png', unique = false, useable = false, shouldClose = false, category = 'tool', description = 'Kit for syphoning fuel from vehicles' },

    -- ========================================================================
    -- VEHICLE RENTAL
    -- ========================================================================
    ['rental_license'] = { name = 'rental_license', label = 'Rental License', type = 'item', image = 'rental_license.png', unique = true, useable = true, shouldClose = true, category = 'document', description = 'Vehicle rental agreement - show to police if stopped' },

    -- ========================================================================
    -- MECHANIC PARTS
    -- ========================================================================
    ['engine_parts'] = { name = 'engine_parts', label = 'Engine Parts', type = 'item', image = 'engine_parts.png', unique = false, useable = false, shouldClose = false, category = 'mechanic', description = 'Replacement engine components for vehicle repair' },
    ['body_panel'] = { name = 'body_panel', label = 'Body Panel', type = 'item', image = 'body_panel.png', unique = false, useable = false, shouldClose = false, category = 'mechanic', description = 'Sheet metal body panels for dent and damage repair' },
    ['tire_kit'] = { name = 'tire_kit', label = 'Tire Kit', type = 'item', image = 'tire_kit.png', unique = false, useable = false, shouldClose = false, category = 'mechanic', description = 'Tire repair and replacement kit' },
    ['upgrade_kit'] = { name = 'upgrade_kit', label = 'Upgrade Kit', type = 'item', image = 'upgrade_kit.png', unique = false, useable = false, shouldClose = false, category = 'mechanic', description = 'Performance upgrade components for vehicles' },
    ['paint_supplies'] = { name = 'paint_supplies', label = 'Paint Supplies', type = 'item', image = 'paint_supplies.png', unique = false, useable = false, shouldClose = false, category = 'mechanic', description = 'Automotive paint, primer, and clear coat' },
    ['wash_supplies'] = { name = 'wash_supplies', label = 'Wash Supplies', type = 'item', image = 'wash_supplies.png', unique = false, useable = false, shouldClose = false, category = 'mechanic', description = 'Soap, wax, and detailing supplies' },

    -- ========================================================================
    -- POLICE EQUIPMENT
    -- ========================================================================
    ['radio'] = { name = 'radio', label = 'Radio', type = 'item', image = 'radio.png', unique = true, useable = true, shouldClose = true, category = 'police', description = 'Police radio for department communications' },
    ['handcuffs'] = { name = 'handcuffs', label = 'Handcuffs', type = 'item', image = 'handcuffs.png', unique = true, useable = true, shouldClose = true, category = 'police', description = 'Standard-issue steel handcuffs' },
    ['armor'] = { name = 'armor', label = 'Body Armor', type = 'item', image = 'armor.png', unique = true, useable = true, shouldClose = true, category = 'police', description = 'Ballistic body armor vest' },
    ['firstaid'] = { name = 'firstaid', label = 'First Aid Kit', type = 'item', image = 'firstaid.png', unique = false, useable = true, shouldClose = true, category = 'police', description = 'Emergency first aid supplies' },
    ['radar_gun'] = { name = 'radar_gun', label = 'Radar Gun', type = 'item', image = 'radar_gun.png', unique = true, useable = true, shouldClose = true, category = 'police', description = 'Handheld speed radar gun for traffic enforcement' },
    ['flashlight'] = { name = 'flashlight', label = 'Flashlight', type = 'item', image = 'weapon_flashlight.png', unique = true, useable = true, shouldClose = true, category = 'police', description = 'Tactical flashlight for low-light operations' },

    -- ========================================================================
    -- POLICE WEAPONS (require sb_weapons registration to fire — melee/taser work standalone)
    -- ========================================================================
    ['weapon_combatpistol'] = { name = 'weapon_combatpistol', label = 'Combat Pistol', type = 'weapon', image = 'weapon_combatpistol.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'Compact polymer combat pistol' },
    ['weapon_stungun'] = { name = 'weapon_stungun', label = 'Taser', type = 'weapon', image = 'weapon_stungun.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'Non-lethal taser for suspect apprehension' },
    ['weapon_nightstick'] = { name = 'weapon_nightstick', label = 'Nightstick', type = 'weapon', image = 'weapon_nightstick.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'Police side-handle baton' },
    ['weapon_pumpshotgun'] = { name = 'weapon_pumpshotgun', label = 'Pump Shotgun', type = 'weapon', image = 'weapon_pumpshotgun.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'Police-issue pump-action shotgun' },
    ['weapon_smg'] = { name = 'weapon_smg', label = 'SMG', type = 'weapon', image = 'weapon_smg.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'Compact submachine gun' },
    ['weapon_carbinerifle'] = { name = 'weapon_carbinerifle', label = 'Carbine Rifle', type = 'weapon', image = 'weapon_carbinerifle.png', unique = true, useable = true, shouldClose = true, category = 'weapon', description = 'M4-style patrol carbine rifle' },

    -- ========================================================================
    -- POLICE AMMO (for future weapons)
    -- ========================================================================
    ['smg_ammo'] = { name = 'smg_ammo', label = '9mm SMG Round', type = 'item', image = 'smg_ammo.png', unique = false, useable = false, shouldClose = false, category = 'ammo', description = 'A single 9mm submachine gun round' },
    ['shotgun_ammo'] = { name = 'shotgun_ammo', label = '12ga Shell', type = 'item', image = 'shotgun_ammo.png', unique = false, useable = false, shouldClose = false, category = 'ammo', description = 'A 12-gauge shotgun shell' },
    ['rifle_ammo'] = { name = 'rifle_ammo', label = '5.56mm Round', type = 'item', image = 'rifle_ammo.png', unique = false, useable = false, shouldClose = false, category = 'ammo', description = 'A single 5.56mm rifle round' },

    -- ========================================================================
    -- DRUGS - ACCESS CARDS (3)
    -- ========================================================================
    ['access_card_weed'] = { name = 'access_card_weed', label = 'Weed Farm Access Card', type = 'item', image = 'access_card_weed.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Access card for the weed farm' },
    ['access_card_coke'] = { name = 'access_card_coke', label = 'Cocaine Lab Access Card', type = 'item', image = 'access_card_coke.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Access card for the cocaine lockup' },
    ['access_card_meth'] = { name = 'access_card_meth', label = 'Meth Lab Access Card', type = 'item', image = 'access_card_meth.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Access card for the meth lab' },

    -- ========================================================================
    -- DRUGS - RAW MATERIALS (8)
    -- ========================================================================
    ['weed_bud'] = { name = 'weed_bud', label = 'Weed Bud', type = 'item', image = 'weed_bud.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Raw marijuana bud, needs cleaning' },
    ['coca_leaf'] = { name = 'coca_leaf', label = 'Coca Leaf', type = 'item', image = 'coca_leaf.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Fresh coca leaf from the field' },
    ['poppy_flower'] = { name = 'poppy_flower', label = 'Poppy Flower', type = 'item', image = 'poppy_flower.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Opium poppy flower for processing' },
    ['mushroom_raw'] = { name = 'mushroom_raw', label = 'Raw Mushroom', type = 'item', image = 'mushroom_raw.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Raw psilocybin mushroom' },
    ['peyote_raw'] = { name = 'peyote_raw', label = 'Raw Peyote', type = 'item', image = 'peyote_raw.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Raw peyote cactus button' },
    ['meth_acid'] = { name = 'meth_acid', label = 'Acid Canister', type = 'item', image = 'meth_acid.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Canister filled with acid for cooking' },
    ['meth_acid_empty'] = { name = 'meth_acid_empty', label = 'Empty Acid Can', type = 'item', image = 'meth_acid_empty.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Empty canister, needs filling at chemical source' },
    ['ammonia'] = { name = 'ammonia', label = 'Ammonia', type = 'item', image = 'ammonia.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Chemical ammonia for drug processing' },

    -- ========================================================================
    -- DRUGS - TOOLS (8)
    -- ========================================================================
    ['scissors'] = { name = 'scissors', label = 'Scissors', type = 'item', image = 'scissors.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Garden scissors for trimming plants' },
    ['trowel'] = { name = 'trowel', label = 'Trowel', type = 'item', image = 'trowel.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Garden trowel for harvesting' },
    ['hammer'] = { name = 'hammer', label = 'Hammer', type = 'item', image = 'hammer.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Hammer for crushing crystals' },
    ['glue'] = { name = 'glue', label = 'Glue', type = 'item', image = 'glue.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Adhesive glue' },
    ['empty_bag'] = { name = 'empty_bag', label = 'Empty Bag', type = 'item', image = 'empty_bag.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Empty plastic bag for packaging' },
    ['rolling_papers'] = { name = 'rolling_papers', label = 'Rolling Papers', type = 'item', image = 'rolling_papers.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Papers for rolling joints' },
    ['blunt_wrap'] = { name = 'blunt_wrap', label = 'Blunt Wrap', type = 'item', image = 'blunt_wrap.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Tobacco leaf wrap for blunts' },
    ['empty_figure'] = { name = 'empty_figure', label = 'Action Figure (Empty)', type = 'item', image = 'empty_figure.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Hollow action figure for hiding product' },

    -- ========================================================================
    -- DRUGS - INTERMEDIATE (7)
    -- ========================================================================
    ['weed_clean'] = { name = 'weed_clean', label = 'Cleaned Weed', type = 'item', image = 'weed_clean.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Cleaned marijuana ready for packaging' },
    ['coca_paste'] = { name = 'coca_paste', label = 'Coca Paste', type = 'item', image = 'coca_paste.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Processed coca paste' },
    ['coca_raw'] = { name = 'coca_raw', label = 'Raw Cocaine', type = 'item', image = 'coca_raw.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Unrefined cocaine extract' },
    ['coca_pure'] = { name = 'coca_pure', label = 'Pure Cocaine', type = 'item', image = 'coca_pure.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Purified cocaine powder' },
    ['meth_liquid'] = { name = 'meth_liquid', label = 'Meth Liquid', type = 'item', image = 'meth_liquid.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Liquid methamphetamine before crystallization' },
    ['meth_crystal'] = { name = 'meth_crystal', label = 'Meth Crystal', type = 'item', image = 'meth_crystal.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Crystallized methamphetamine shard' },
    ['syringe'] = { name = 'syringe', label = 'Empty Syringe', type = 'item', image = 'syringe.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Use to fill with heroin or meth' },

    -- ========================================================================
    -- DRUGS - FINISHED PRODUCTS (10)
    -- ========================================================================
    ['weed_bag'] = { name = 'weed_bag', label = 'Weed Bag', type = 'item', image = 'weed_bag.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Packaged marijuana ready for sale' },
    ['meth_bag'] = { name = 'meth_bag', label = 'Meth Bag', type = 'item', image = 'meth_bag.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Packaged methamphetamine' },
    ['cocaine_figure'] = { name = 'cocaine_figure', label = 'Cocaine Figure', type = 'item', image = 'cocaine_figure.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Action figure filled with cocaine' },
    ['heroin_dose'] = { name = 'heroin_dose', label = 'Heroin Dose', type = 'item', image = 'heroin_dose.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Packaged heroin dose' },
    ['crack_rock'] = { name = 'crack_rock', label = 'Crack Rock', type = 'item', image = 'crack_rock.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Cooked crack cocaine rock' },
    ['weed_joint'] = { name = 'weed_joint', label = 'Weed Joint', type = 'item', image = 'weed_joint.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Rolled marijuana joint' },
    ['weed_blunt'] = { name = 'weed_blunt', label = 'Weed Blunt', type = 'item', image = 'weed_blunt.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Rolled marijuana blunt' },
    ['mushroom_dried'] = { name = 'mushroom_dried', label = 'Dried Mushroom', type = 'item', image = 'mushroom_dried.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Dried psilocybin mushroom' },
    ['peyote_dried'] = { name = 'peyote_dried', label = 'Dried Peyote', type = 'item', image = 'peyote_dried.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Dried peyote cactus button' },
    ['pipe'] = { name = 'pipe', label = 'Smoking Pipe', type = 'item', image = 'pipe.png', unique = true, useable = false, shouldClose = false, category = 'drug', description = 'Glass pipe for smoking' },

    -- ========================================================================
    -- DRUGS - CONSUMABLE PREPARATIONS (6)
    -- ========================================================================
    ['lsd_tab'] = { name = 'lsd_tab', label = 'LSD Tab', type = 'item', image = 'lsd_tab.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Lysergic acid diethylamide blotter tab' },
    ['ecstasy_pill'] = { name = 'ecstasy_pill', label = 'Ecstasy Pill', type = 'item', image = 'ecstasy_pill.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'MDMA pressed pill' },
    ['xanax_pill'] = { name = 'xanax_pill', label = 'Xanax Pill', type = 'item', image = 'xanax_pill.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Alprazolam anti-anxiety pill' },
    ['heroin_syringe'] = { name = 'heroin_syringe', label = 'Heroin Syringe', type = 'item', image = 'heroin_syringe.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Syringe loaded with heroin' },
    ['meth_syringe'] = { name = 'meth_syringe', label = 'Meth Syringe', type = 'item', image = 'meth_syringe.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Syringe loaded with methamphetamine' },
    ['cocaine_line'] = { name = 'cocaine_line', label = 'Cocaine Line', type = 'item', image = 'cocaine_line.png', unique = false, useable = true, shouldClose = true, category = 'drug', description = 'Prepared line of cocaine powder' },

    -- ========================================================================
    -- DRUGS - MISC INGREDIENTS
    -- ========================================================================
    ['baking_soda'] = { name = 'baking_soda', label = 'Baking Soda', type = 'item', image = 'baking_soda.png', unique = false, useable = false, shouldClose = false, category = 'drug', description = 'Sodium bicarbonate for crack production' },
}
