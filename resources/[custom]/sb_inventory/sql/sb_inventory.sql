-- Active: 1763755673348@@127.0.0.1@3306@everdaychaos
-- ========================================================================
-- Everyday Chaos RP - Inventory Database Schema
-- Author: Salah Eddine Boussettah
-- System: Capacity-based (slots only, no weight)
-- ========================================================================

-- ========================================================================
-- ITEMS TABLE (all item definitions - source of truth)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `sb_items` (
    `name` VARCHAR(50) NOT NULL PRIMARY KEY,         -- Internal name (lowercase, no spaces)
    `label` VARCHAR(100) NOT NULL,                   -- Display name
    `type` ENUM('item', 'weapon') NOT NULL DEFAULT 'item',
    `category` VARCHAR(30) NOT NULL DEFAULT 'misc',  -- food, drink, medical, tool, weapon, ammo, material, drug, vehicle, jewelry, electronics, police, misc
    `image` VARCHAR(100) DEFAULT NULL,               -- Image filename (e.g., 'water.png')
    `stackable` TINYINT(1) NOT NULL DEFAULT 1,       -- Can stack (1=yes, 0=no/unique)
    `max_stack` INT NOT NULL DEFAULT 50,             -- Max stack size per slot
    `useable` TINYINT(1) NOT NULL DEFAULT 0,         -- Can be used/consumed
    `shouldClose` TINYINT(1) NOT NULL DEFAULT 1,     -- Close inventory on use
    `description` VARCHAR(255) DEFAULT NULL,          -- Item description
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_category` (`category`),
    KEY `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ========================================================================
-- PLAYER INVENTORY (stored per character)
-- ========================================================================
-- Player inventory is stored in the `players` table as JSON `inventory` column
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `inventory` LONGTEXT DEFAULT NULL;

-- ========================================================================
-- INVENTORY STASHES (personal lockers, shared stashes, job storage)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `sb_inventory_stashes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL,
    `label` VARCHAR(100) DEFAULT 'Stash',
    `type` ENUM('personal', 'shared', 'job') NOT NULL DEFAULT 'personal',
    `owner` VARCHAR(60) DEFAULT NULL,
    `job` VARCHAR(50) DEFAULT NULL,
    `slots` INT NOT NULL DEFAULT 50,
    `items` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_stash` (`identifier`, `owner`),
    KEY `idx_owner` (`owner`),
    KEY `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ========================================================================
-- VEHICLE INVENTORY (trunk & glovebox - capacity only)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `sb_inventory_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(10) NOT NULL,
    `trunk` LONGTEXT DEFAULT NULL,
    `trunk_slots` INT NOT NULL DEFAULT 30,
    `glovebox` LONGTEXT DEFAULT NULL,
    `glovebox_slots` INT NOT NULL DEFAULT 5,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ========================================================================
-- WORLD DROPS (items dropped on ground)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `sb_inventory_drops` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `drop_id` VARCHAR(50) NOT NULL UNIQUE,
    `items` LONGTEXT NOT NULL,
    `coords` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_drop_id` (`drop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ========================================================================
-- ITEM LOG (audit trail)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `sb_inventory_log` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `action` ENUM('add', 'remove', 'transfer', 'use', 'drop', 'pickup', 'purchase', 'sell') NOT NULL,
    `source` VARCHAR(60) DEFAULT NULL,
    `target` VARCHAR(100) DEFAULT NULL,
    `item` VARCHAR(100) NOT NULL,
    `amount` INT NOT NULL DEFAULT 1,
    `metadata` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_source` (`source`),
    KEY `idx_item` (`item`),
    KEY `idx_action` (`action`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ========================================================================
-- INSERT ALL ITEMS (clear old data first)
-- ========================================================================
DELETE FROM `sb_items`;

-- FOOD (15 items)
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('apple', 'Apple', 'item', 'food', 'apple.png', 1, 20, 1, 1, 'A fresh juicy apple'),
('banana', 'Banana', 'item', 'food', 'banana.png', 1, 20, 1, 1, 'A ripe banana'),
('burger', 'Burger', 'item', 'food', 'burger.png', 1, 20, 1, 1, 'A delicious burger'),
('bread', 'Bread', 'item', 'food', 'bread.png', 1, 20, 1, 1, 'A loaf of fresh bread'),
('bacon', 'Bacon', 'item', 'food', 'bacon.png', 1, 20, 1, 1, 'Crispy fried bacon'),
('chips', 'Chips', 'item', 'food', 'chips.png', 1, 30, 1, 1, 'A bag of crispy chips'),
('cookie', 'Cookie', 'item', 'food', 'cookie.png', 1, 30, 1, 1, 'A chocolate chip cookie'),
('croissant', 'Croissant', 'item', 'food', 'croissant.png', 1, 20, 1, 1, 'A buttery croissant'),
('donut', 'Donut', 'item', 'food', 'donut.png', 1, 20, 1, 1, 'A glazed donut'),
('hotdog', 'Hot Dog', 'item', 'food', 'hotdog.png', 1, 20, 1, 1, 'A classic hot dog'),
('pizza', 'Pizza Slice', 'item', 'food', 'pizza.png', 1, 20, 1, 1, 'A cheesy slice of pizza'),
('fries', 'Fries', 'item', 'food', 'fries.png', 1, 20, 1, 1, 'Golden french fries'),
('muffin', 'Muffin', 'item', 'food', 'muffin.png', 1, 20, 1, 1, 'A blueberry muffin'),
('bagel', 'Bagel', 'item', 'food', 'bagel.png', 1, 20, 1, 1, 'A fresh bagel'),
('brownie', 'Brownie', 'item', 'food', 'brownie.png', 1, 20, 1, 1, 'A chocolate brownie');

-- DRINKS (10 items)
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('water_bottle', 'Water Bottle', 'item', 'drink', 'water_bottle.png', 1, 20, 1, 1, 'Fresh water to quench your thirst'),
('cola', 'Cola', 'item', 'drink', 'cola.png', 1, 20, 1, 1, 'A refreshing cola'),
('coffee', 'Coffee', 'item', 'drink', 'coffee.png', 1, 10, 1, 1, 'Hot coffee to start your day'),
('juice', 'Juice', 'item', 'drink', 'juice.png', 1, 20, 1, 1, 'A fresh fruit juice'),
('beer', 'Beer', 'item', 'drink', 'beer.png', 1, 10, 1, 1, 'A cold beer'),
('milk', 'Milk', 'item', 'drink', 'milk.png', 1, 10, 1, 1, 'A glass of cold milk'),
('sprite', 'Sprite', 'item', 'drink', 'sprite.png', 1, 20, 1, 1, 'A lemon-lime soda'),
('redbull', 'Red Bull', 'item', 'drink', 'redbull.png', 1, 10, 1, 1, 'An energy drink that gives you wings'),
('pepsi', 'Pepsi', 'item', 'drink', 'pepsi.png', 1, 20, 1, 1, 'A refreshing Pepsi'),
('monster', 'Monster Energy', 'item', 'drink', 'monster.png', 1, 10, 1, 1, 'A powerful energy drink');

-- WEAPONS (1 pistol for testing)
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weapon_pistol', 'Pistol', 'weapon', 'weapon', 'pistol.png', 0, 1, 1, 1, 'A standard 9mm pistol');

-- AMMO
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('pistol_ammo', '9mm Round', 'item', 'ammo', 'pistol_ammo.png', 1, 24, 0, 0, 'A single 9mm round'),
('p_ammobox', 'Ammo Box', 'item', 'ammo', 'p_ammobox.png', 0, 1, 0, 0, '9mm ammo box (holds up to 100 rounds)');

-- MAGAZINES
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('p_quick_mag', 'Quick Mag', 'item', 'magazine', 'p_quick_mag.png', 1, 5, 1, 1, '7-round pistol magazine (fast reload)'),
('p_stand_mag', 'Standard Mag', 'item', 'magazine', 'p_stand_mag.png', 1, 5, 1, 1, '10-round pistol magazine'),
('p_extended_mag', 'Extended Mag', 'item', 'magazine', 'p_extended_mag.png', 1, 5, 1, 1, '15-round extended pistol magazine (slow reload)');

-- BANKING
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('creditcard', 'Credit Card', 'item', 'misc', 'creditcard.png', 0, 1, 0, 0, 'A Maze Bank credit card for ATM access');

-- DOCUMENTS & LICENSES
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('id_card', 'ID Card', 'item', 'document', 'id_card.png', 0, 1, 1, 1, 'Government-issued identification card'),
('car_license', 'Driver''s License', 'item', 'document', 'car_license.png', 0, 1, 1, 1, 'Class C driver''s license - required to purchase vehicles'),
('dmv_theory_cert', 'Theory Exam Certificate', 'item', 'document', 'dmv_theory_cert.png', 0, 1, 0, 0, 'DMV theory exam passed - required for parking test'),
('dmv_parking_cert', 'Parking Test Certificate', 'item', 'document', 'dmv_parking_cert.png', 0, 1, 0, 0, 'DMV parking test passed - required for driving test');

-- VEHICLE ITEMS
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('car_keys', 'Car Keys', 'item', 'vehicle', 'car_keys.png', 0, 1, 1, 1, 'Keys to your vehicle');

-- GYM & FITNESS
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('protein_shake', 'Protein Shake', 'item', 'consumable', 'protein_shake.png', 1, 10, 1, 1, 'A high-protein shake that doubles gym XP for 5 minutes');

-- ========================================================================
-- PACIFIC HEIST - TOOLS
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('heist_drill', 'Thermal Drill', 'item', 'heist', 'heist_drill.png', 0, 1, 0, 0, 'Professional-grade laser thermal drill for vault doors'),
('heist_bag', 'Heist Bag', 'item', 'heist', 'heist_bag.png', 0, 1, 0, 0, 'Tactical duffel bag for carrying loot'),
('glass_cutter', 'Glass Cutter', 'item', 'heist', 'glass_cutter.png', 0, 1, 0, 0, 'Precision glass cutting tool with diamond tip'),
('c4_explosive', 'C4 Explosive', 'item', 'heist', 'c4_explosive.png', 1, 10, 0, 0, 'Military-grade plastic explosive with detonator'),
('thermite_charge', 'Thermite Charge', 'item', 'heist', 'thermite_charge.png', 1, 10, 0, 0, 'Incendiary charge for melting through metal'),
('hacking_laptop', 'Hacking Laptop', 'item', 'heist', 'hacking_laptop.png', 0, 1, 0, 0, 'Portable hacking workstation'),
('trojan_usb', 'Trojan USB', 'item', 'heist', 'trojan_usb.png', 1, 5, 0, 0, 'USB drive loaded with malware'),
('switchblade', 'Switchblade', 'item', 'heist', 'switchblade.png', 0, 1, 0, 0, 'Sharp folding knife for cutting paintings');

-- ========================================================================
-- PACIFIC HEIST - LOOT (VALUABLES)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('gold_bar', 'Gold Bar', 'item', 'valuable', 'gold_bar.png', 1, 50, 0, 0, 'Solid gold bullion bar'),
('diamond_pouch', 'Diamond Pouch', 'item', 'valuable', 'diamond_pouch.png', 1, 20, 0, 0, 'Small pouch containing loose diamonds'),
('cocaine_brick', 'Cocaine Brick', 'item', 'contraband', 'cocaine_brick.png', 1, 10, 0, 0, 'Wrapped brick of cocaine'),
('panther_statue', 'Panther Statue', 'item', 'valuable', 'panther_statue.png', 0, 1, 0, 0, 'Black onyx panther figurine'),
('diamond_necklace', 'Diamond Necklace', 'item', 'valuable', 'diamond_necklace.png', 0, 1, 0, 0, 'Elegant platinum diamond necklace'),
('vintage_wine', 'Vintage Wine', 'item', 'valuable', 'vintage_wine.png', 0, 1, 0, 0, 'Rare vintage wine bottle'),
('vault_painting', 'Vault Painting', 'item', 'valuable', 'vault_painting.png', 0, 1, 0, 0, 'Rolled canvas painting from the vault'),
('rare_watch', 'Rare Watch', 'item', 'valuable', 'rare_watch.png', 0, 1, 0, 0, 'Luxury gold timepiece');

-- ========================================================================
-- FUEL & VEHICLE MAINTENANCE
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('jerrycan', 'Jerry Can', 'item', 'tool', 'jerrycan.png', 0, 1, 0, 0, 'Portable fuel container (20L capacity)'),
('syphon_kit', 'Syphon Kit', 'item', 'tool', 'syphon_kit.png', 1, 1, 0, 0, 'Kit for syphoning fuel from vehicles');

-- ========================================================================
-- VEHICLE RENTAL
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('rental_license', 'Rental License', 'item', 'document', 'rental_license.png', 0, 1, 1, 1, 'Vehicle rental agreement - show to police if stopped');

-- ========================================================================
-- MECHANIC PARTS - ENGINE (8 components)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_engine_block', 'Engine Block', 'item', 'mechanic', 'part_engine_block.png', 1, 5, 0, 0, 'Remanufactured engine block assembly'),
('part_spark_plugs', 'Spark Plugs', 'item', 'mechanic', 'part_spark_plugs.png', 1, 20, 0, 0, 'Set of iridium spark plugs'),
('part_air_filter', 'Air Filter', 'item', 'mechanic', 'part_air_filter.png', 1, 20, 0, 0, 'High-flow engine air filter'),
('part_radiator', 'Radiator', 'item', 'mechanic', 'part_radiator.png', 1, 5, 0, 0, 'Aluminum radiator with cooling fans'),
('part_turbo', 'Turbocharger', 'item', 'mechanic', 'part_turbo.png', 1, 3, 0, 0, 'Twin-scroll turbocharger unit'),
('part_alternator', 'Alternator', 'item', 'mechanic', 'part_alternator.png', 1, 5, 0, 0, 'High-output alternator'),
('part_battery', 'Car Battery', 'item', 'mechanic', 'part_battery.png', 1, 5, 0, 0, '12V automotive battery'),
('part_ecu', 'ECU Module', 'item', 'mechanic', 'part_ecu.png', 1, 3, 0, 0, 'Engine control unit replacement module');

-- ========================================================================
-- MECHANIC PARTS - TRANSMISSION (3 components)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_clutch', 'Clutch Kit', 'item', 'mechanic', 'part_clutch.png', 1, 5, 0, 0, 'Clutch disc, pressure plate, and throw-out bearing'),
('part_transmission', 'Transmission', 'item', 'mechanic', 'part_transmission.png', 1, 3, 0, 0, 'Remanufactured transmission assembly'),
('part_wiring', 'Wiring Harness', 'item', 'mechanic', 'part_wiring.png', 1, 10, 0, 0, 'Vehicle electrical wiring harness');

-- ========================================================================
-- MECHANIC PARTS - BRAKES (3 components)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_brake_pads', 'Brake Pads', 'item', 'mechanic', 'part_brake_pads.png', 1, 20, 0, 0, 'Ceramic brake pad set (front or rear)'),
('part_brake_rotors', 'Brake Rotors', 'item', 'mechanic', 'part_brake_rotors.png', 1, 10, 0, 0, 'Drilled and slotted brake rotors'),
('part_windshield', 'Windshield', 'item', 'mechanic', 'part_windshield.png', 1, 3, 0, 0, 'Laminated safety glass windshield');

-- ========================================================================
-- MECHANIC PARTS - SUSPENSION (4 components)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_shocks', 'Shock Absorbers', 'item', 'mechanic', 'part_shocks.png', 1, 10, 0, 0, 'Gas-charged shock absorber pair'),
('part_springs', 'Coil Springs', 'item', 'mechanic', 'part_springs.png', 1, 10, 0, 0, 'Progressive rate coil spring set'),
('part_wheel_bearings', 'Wheel Bearings', 'item', 'mechanic', 'part_wheel_bearings.png', 1, 10, 0, 0, 'Sealed wheel bearing assembly'),
('part_headlights', 'Headlight Assembly', 'item', 'mechanic', 'part_headlights.png', 1, 5, 0, 0, 'Complete headlight unit with housing and lens');

-- ========================================================================
-- MECHANIC PARTS - BODY & LIGHTS
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_body_panel', 'Body Panel', 'item', 'mechanic', 'part_body_panel.png', 1, 10, 0, 0, 'Sheet metal body panel for dent and damage repair'),
('part_taillights', 'Taillight Assembly', 'item', 'mechanic', 'part_taillights.png', 1, 5, 0, 0, 'Complete taillight unit with housing and lens');

-- ========================================================================
-- MECHANIC PARTS - WHEELS & TIRES
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_tire', 'Tire', 'item', 'mechanic', 'part_tire.png', 1, 10, 0, 0, 'All-season radial tire'),
('part_tire_performance', 'Performance Tire', 'item', 'mechanic', 'part_tire_performance.png', 1, 10, 0, 0, 'High-grip performance tire for sports vehicles'),
('part_tire_offroad', 'Off-Road Tire', 'item', 'mechanic', 'part_tire_offroad.png', 1, 10, 0, 0, 'Mud-terrain tire for off-road vehicles');

-- ========================================================================
-- MECHANIC FLUIDS & CONSUMABLES
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('fluid_motor_oil', 'Motor Oil', 'item', 'mechanic', 'fluid_motor_oil.png', 1, 20, 0, 0, '5W-30 full synthetic motor oil (5L)'),
('fluid_coolant', 'Coolant', 'item', 'mechanic', 'fluid_coolant.png', 1, 20, 0, 0, 'Engine coolant / antifreeze (4L)'),
('fluid_brake', 'Brake Fluid', 'item', 'mechanic', 'fluid_brake.png', 1, 20, 0, 0, 'DOT 4 brake fluid (1L)'),
('fluid_trans', 'Transmission Fluid', 'item', 'mechanic', 'fluid_trans.png', 1, 20, 0, 0, 'ATF transmission fluid (1L)');

-- ========================================================================
-- MECHANIC TOOLS
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('tool_diagnostic', 'Diagnostic Scanner', 'item', 'mechanic', 'tool_diagnostic.png', 0, 1, 0, 0, 'OBD2 diagnostic scanner for reading vehicle codes'),
('tool_wrench_set', 'Wrench Set', 'item', 'mechanic', 'tool_wrench_set.png', 0, 1, 0, 0, 'Professional mechanic wrench and socket set'),
('tool_jack', 'Hydraulic Jack', 'item', 'mechanic', 'tool_jack.png', 0, 1, 0, 0, 'Heavy-duty hydraulic floor jack'),
('tool_torque_wrench', 'Torque Wrench', 'item', 'mechanic', 'tool_torque_wrench.png', 0, 1, 0, 0, 'Calibrated torque wrench for precision tightening'),
('tool_multimeter', 'Multimeter', 'item', 'mechanic', 'tool_multimeter.png', 0, 1, 0, 0, 'Digital multimeter for electrical diagnostics'),
('tool_paint_gun', 'Paint Gun', 'item', 'mechanic', 'tool_paint_gun.png', 0, 1, 0, 0, 'HVLP spray gun for automotive painting');

-- ========================================================================
-- MECHANIC MISC (kept from v1 for backwards compat)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('upgrade_kit', 'Upgrade Kit', 'item', 'mechanic', 'upgrade_kit.png', 1, 10, 0, 0, 'Performance upgrade components for vehicles'),
('paint_supplies', 'Paint Supplies', 'item', 'mechanic', 'paint_supplies.png', 1, 10, 0, 0, 'Automotive paint, primer, and clear coat'),
('wash_supplies', 'Wash Supplies', 'item', 'mechanic', 'wash_supplies.png', 1, 20, 0, 0, 'Soap, wax, and detailing supplies');

-- ========================================================================
-- MINING TOOLS
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('mining_pickaxe', 'Mining Pickaxe', 'item', 'tool', 'mining_pickaxe.png', 0, 1, 0, 0, 'Heavy-duty pickaxe for mining ore');

-- ========================================================================
-- POLICE EQUIPMENT
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('radio', 'Radio', 'item', 'police', 'radio.png', 0, 1, 1, 1, 'Police radio for department communications'),
('handcuffs', 'Handcuffs', 'item', 'police', 'handcuffs.png', 0, 1, 1, 1, 'Standard-issue steel handcuffs'),
('armor', 'Body Armor', 'item', 'police', 'armor.png', 0, 1, 1, 1, 'Ballistic body armor vest'),
('firstaid', 'First Aid Kit', 'item', 'police', 'firstaid.png', 0, 5, 1, 1, 'Emergency first aid supplies'),
('radar_gun', 'Radar Gun', 'item', 'police', 'radar_gun.png', 0, 1, 1, 1, 'Handheld speed radar gun for traffic enforcement'),
('flashlight', 'Flashlight', 'item', 'police', 'weapon_flashlight.png', 0, 1, 1, 1, 'Tactical flashlight for low-light operations');

-- ========================================================================
-- POLICE WEAPONS
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weapon_combatpistol', 'Combat Pistol', 'weapon', 'weapon', 'weapon_combatpistol.png', 0, 1, 1, 1, 'Compact polymer combat pistol'),
('weapon_stungun', 'Taser', 'weapon', 'weapon', 'weapon_stungun.png', 0, 1, 1, 1, 'Non-lethal taser for suspect apprehension'),
('weapon_nightstick', 'Nightstick', 'weapon', 'weapon', 'weapon_nightstick.png', 0, 1, 1, 1, 'Police side-handle baton'),
('weapon_pumpshotgun', 'Pump Shotgun', 'weapon', 'weapon', 'weapon_pumpshotgun.png', 0, 1, 1, 1, 'Police-issue pump-action shotgun'),
('weapon_smg', 'SMG', 'weapon', 'weapon', 'weapon_smg.png', 0, 1, 1, 1, 'Compact submachine gun'),
('weapon_carbinerifle', 'Carbine Rifle', 'weapon', 'weapon', 'weapon_carbinerifle.png', 0, 1, 1, 1, 'M4-style patrol carbine rifle');

-- ========================================================================
-- POLICE AMMO
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('smg_ammo', '9mm SMG Round', 'item', 'ammo', 'smg_ammo.png', 1, 999, 0, 0, 'A single 9mm submachine gun round'),
('shotgun_ammo', '12ga Shell', 'item', 'ammo', 'shotgun_ammo.png', 1, 999, 0, 0, 'A 12-gauge shotgun shell'),
('rifle_ammo', '5.56mm Round', 'item', 'ammo', 'rifle_ammo.png', 1, 999, 0, 0, 'A single 5.56mm rifle round');

-- ========================================================================
-- DRUGS - ACCESS CARDS (3)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('access_card_weed', 'Weed Farm Access Card', 'item', 'drug', 'access_card_weed.png', 0, 1, 0, 0, 'Access card for the weed farm'),
('access_card_coke', 'Cocaine Lab Access Card', 'item', 'drug', 'access_card_coke.png', 0, 1, 0, 0, 'Access card for the cocaine lockup'),
('access_card_meth', 'Meth Lab Access Card', 'item', 'drug', 'access_card_meth.png', 0, 1, 0, 0, 'Access card for the meth lab');

-- ========================================================================
-- DRUGS - RAW MATERIALS (8)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weed_bud', 'Weed Bud', 'item', 'drug', 'weed_bud.png', 1, 50, 0, 0, 'Raw marijuana bud, needs cleaning'),
('coca_leaf', 'Coca Leaf', 'item', 'drug', 'coca_leaf.png', 1, 50, 0, 0, 'Fresh coca leaf from the field'),
('poppy_flower', 'Poppy Flower', 'item', 'drug', 'poppy_flower.png', 1, 50, 0, 0, 'Opium poppy flower for processing'),
('mushroom_raw', 'Raw Mushroom', 'item', 'drug', 'mushroom_raw.png', 1, 30, 0, 0, 'Raw psilocybin mushroom'),
('peyote_raw', 'Raw Peyote', 'item', 'drug', 'peyote_raw.png', 1, 30, 0, 0, 'Raw peyote cactus button'),
('meth_acid', 'Acid Canister', 'item', 'drug', 'meth_acid.png', 1, 10, 0, 0, 'Canister filled with acid for cooking'),
('meth_acid_empty', 'Empty Acid Can', 'item', 'drug', 'meth_acid_empty.png', 1, 10, 0, 0, 'Empty canister, needs filling at chemical source'),
('ammonia', 'Ammonia', 'item', 'drug', 'ammonia.png', 1, 20, 0, 0, 'Chemical ammonia for drug processing');

-- ========================================================================
-- DRUGS - TOOLS (8)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('scissors', 'Scissors', 'item', 'drug', 'scissors.png', 0, 1, 0, 0, 'Garden scissors for trimming plants'),
('trowel', 'Trowel', 'item', 'drug', 'trowel.png', 0, 1, 0, 0, 'Garden trowel for harvesting'),
('hammer', 'Hammer', 'item', 'drug', 'hammer.png', 0, 1, 0, 0, 'Hammer for crushing crystals'),
('glue', 'Glue', 'item', 'drug', 'glue.png', 1, 10, 0, 0, 'Adhesive glue'),
('empty_bag', 'Empty Bag', 'item', 'drug', 'empty_bag.png', 1, 50, 0, 0, 'Empty plastic bag for packaging'),
('rolling_papers', 'Rolling Papers', 'item', 'drug', 'rolling_papers.png', 1, 50, 1, 1, 'Papers for rolling joints'),
('blunt_wrap', 'Blunt Wrap', 'item', 'drug', 'blunt_wrap.png', 1, 50, 1, 1, 'Tobacco leaf wrap for blunts'),
('empty_figure', 'Action Figure (Empty)', 'item', 'drug', 'empty_figure.png', 1, 20, 0, 0, 'Hollow action figure for hiding product');

-- ========================================================================
-- DRUGS - INTERMEDIATE (7)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weed_clean', 'Cleaned Weed', 'item', 'drug', 'weed_clean.png', 1, 50, 0, 0, 'Cleaned marijuana ready for packaging'),
('coca_paste', 'Coca Paste', 'item', 'drug', 'coca_paste.png', 1, 30, 0, 0, 'Processed coca paste'),
('coca_raw', 'Raw Cocaine', 'item', 'drug', 'coca_raw.png', 1, 30, 0, 0, 'Unrefined cocaine extract'),
('coca_pure', 'Pure Cocaine', 'item', 'drug', 'coca_pure.png', 1, 20, 1, 1, 'Purified cocaine powder'),
('meth_liquid', 'Meth Liquid', 'item', 'drug', 'meth_liquid.png', 1, 10, 0, 0, 'Liquid methamphetamine before crystallization'),
('meth_crystal', 'Meth Crystal', 'item', 'drug', 'meth_crystal.png', 1, 10, 0, 0, 'Crystallized methamphetamine shard'),
('syringe', 'Empty Syringe', 'item', 'drug', 'syringe.png', 1, 20, 1, 1, 'Use to fill with heroin or meth');

-- ========================================================================
-- DRUGS - FINISHED PRODUCTS (10)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weed_bag', 'Weed Bag', 'item', 'drug', 'weed_bag.png', 1, 20, 0, 0, 'Packaged marijuana ready for sale'),
('meth_bag', 'Meth Bag', 'item', 'drug', 'meth_bag.png', 1, 20, 1, 1, 'Packaged methamphetamine'),
('cocaine_figure', 'Cocaine Figure', 'item', 'drug', 'cocaine_figure.png', 1, 10, 0, 0, 'Action figure filled with cocaine'),
('heroin_dose', 'Heroin Dose', 'item', 'drug', 'heroin_dose.png', 1, 20, 0, 0, 'Packaged heroin dose'),
('crack_rock', 'Crack Rock', 'item', 'drug', 'crack_rock.png', 1, 20, 1, 1, 'Cooked crack cocaine rock'),
('weed_joint', 'Weed Joint', 'item', 'drug', 'weed_joint.png', 1, 20, 1, 1, 'Rolled marijuana joint'),
('weed_blunt', 'Weed Blunt', 'item', 'drug', 'weed_blunt.png', 1, 20, 1, 1, 'Rolled marijuana blunt'),
('mushroom_dried', 'Dried Mushroom', 'item', 'drug', 'mushroom_dried.png', 1, 20, 1, 1, 'Dried psilocybin mushroom'),
('peyote_dried', 'Dried Peyote', 'item', 'drug', 'peyote_dried.png', 1, 20, 1, 1, 'Dried peyote cactus button'),
('pipe', 'Smoking Pipe', 'item', 'drug', 'pipe.png', 0, 1, 0, 0, 'Glass pipe for smoking');

-- ========================================================================
-- DRUGS - CONSUMABLE PREPARATIONS (6)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('lsd_tab', 'LSD Tab', 'item', 'drug', 'lsd_tab.png', 1, 20, 1, 1, 'Lysergic acid diethylamide blotter tab'),
('ecstasy_pill', 'Ecstasy Pill', 'item', 'drug', 'ecstasy_pill.png', 1, 20, 1, 1, 'MDMA pressed pill'),
('xanax_pill', 'Xanax Pill', 'item', 'drug', 'xanax_pill.png', 1, 20, 1, 1, 'Alprazolam anti-anxiety pill'),
('heroin_syringe', 'Heroin Syringe', 'item', 'drug', 'heroin_syringe.png', 1, 10, 1, 1, 'Syringe loaded with heroin'),
('meth_syringe', 'Meth Syringe', 'item', 'drug', 'meth_syringe.png', 1, 10, 1, 1, 'Syringe loaded with methamphetamine'),
('cocaine_line', 'Cocaine Line', 'item', 'drug', 'cocaine_line.png', 1, 20, 1, 1, 'Prepared line of cocaine powder');

-- ========================================================================
-- DRUGS - MISC INGREDIENTS
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('baking_soda', 'Baking Soda', 'item', 'drug', 'baking_soda.png', 1, 30, 0, 0, 'Sodium bicarbonate for crack production');