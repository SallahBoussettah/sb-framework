-- sb_companies | Database Schema
-- Run once to create all tables + seed data

-- ===================================================================
-- COMPANIES TABLE
-- ===================================================================
CREATE TABLE IF NOT EXISTS `companies` (
    `id` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `type` VARCHAR(50) NOT NULL DEFAULT 'manufacturing',
    `owner_citizenid` VARCHAR(50) DEFAULT NULL,
    `balance` INT NOT NULL DEFAULT 50000,
    `purchase_price` INT NOT NULL DEFAULT 500000,
    `tax_rate` FLOAT NOT NULL DEFAULT 0.05,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- COMPANY EMPLOYEES
-- ===================================================================
CREATE TABLE IF NOT EXISTS `company_employees` (
    `id` INT AUTO_INCREMENT,
    `company_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` ENUM('worker','driver','manager') NOT NULL DEFAULT 'worker',
    `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_company_citizen` (`company_id`, `citizenid`),
    KEY `idx_citizenid` (`citizenid`),
    CONSTRAINT `fk_emp_company` FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- COMPANY STOCK (raw materials + finished parts at company)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `company_stock` (
    `id` INT AUTO_INCREMENT,
    `company_id` VARCHAR(50) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_company_item` (`company_id`, `item_name`),
    CONSTRAINT `fk_stock_company` FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- COMPANY CATALOG (what each company sells + adjustable prices)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `company_catalog` (
    `id` INT AUTO_INCREMENT,
    `company_id` VARCHAR(50) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `base_price` INT NOT NULL DEFAULT 100,
    `current_price` INT NOT NULL DEFAULT 100,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_catalog_item` (`company_id`, `item_name`),
    CONSTRAINT `fk_catalog_company` FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- ORDERS (mechanic purchase orders)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `orders` (
    `id` INT AUTO_INCREMENT,
    `shop_id` VARCHAR(50) NOT NULL,
    `company_id` VARCHAR(50) NOT NULL,
    `ordered_by` VARCHAR(50) NOT NULL,
    `status` ENUM('pending','processing','ready','in_transit','delivered','cancelled') NOT NULL DEFAULT 'pending',
    `total_cost` INT NOT NULL DEFAULT 0,
    `payment_source` VARCHAR(20) NOT NULL DEFAULT 'bank',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_shop` (`shop_id`),
    KEY `idx_company` (`company_id`),
    KEY `idx_status` (`status`),
    CONSTRAINT `fk_order_company` FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- ORDER ITEMS (line items per order)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `order_items` (
    `id` INT AUTO_INCREMENT,
    `order_id` INT NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `unit_price` INT NOT NULL DEFAULT 0,
    `quality` VARCHAR(20) NOT NULL DEFAULT 'standard',
    PRIMARY KEY (`id`),
    KEY `idx_order` (`order_id`),
    CONSTRAINT `fk_oi_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- DELIVERY QUEUE
-- ===================================================================
CREATE TABLE IF NOT EXISTS `delivery_queue` (
    `id` INT AUTO_INCREMENT,
    `order_id` INT NOT NULL,
    `status` ENUM('waiting','claimed','in_transit','completed','npc_dispatched') NOT NULL DEFAULT 'waiting',
    `claimed_by` VARCHAR(50) DEFAULT NULL,
    `claimed_at` TIMESTAMP NULL DEFAULT NULL,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    `npc_arrive_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_delivery_order` (`order_id`),
    KEY `idx_status` (`status`),
    CONSTRAINT `fk_del_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- SHOP STORAGE (parts available at mechanic workshop)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `shop_storage` (
    `id` INT AUTO_INCREMENT,
    `shop_id` VARCHAR(50) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `quality` VARCHAR(20) NOT NULL DEFAULT 'standard',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_shop_item_quality` (`shop_id`, `item_name`, `quality`),
    KEY `idx_shop` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- COMPANY TRANSACTIONS (financial audit log)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `company_transactions` (
    `id` INT AUTO_INCREMENT,
    `company_id` VARCHAR(50) NOT NULL,
    `type` ENUM('sale','purchase','salary','delivery_fee','raw_purchase','tax','owner_withdraw','owner_deposit') NOT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `description` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_company` (`company_id`),
    KEY `idx_type` (`type`),
    CONSTRAINT `fk_tx_company` FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- MINING NODES (server-side depletion for open-world spots)
-- ===================================================================
CREATE TABLE IF NOT EXISTS `mining_nodes` (
    `id` INT AUTO_INCREMENT,
    `node_id` VARCHAR(50) NOT NULL,
    `depleted_at` TIMESTAMP NULL DEFAULT NULL,
    `respawn_minutes` INT NOT NULL DEFAULT 10,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_node` (`node_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===================================================================
-- SEED DATA: 3 Companies
-- ===================================================================
INSERT INTO `companies` (`id`, `label`, `type`, `owner_citizenid`, `balance`, `purchase_price`, `tax_rate`) VALUES
('santos_metal',   'Santos Metal Works',        'heavy_manufacturing', NULL, 100000, 750000,  0.05),
('pacific_chem',   'Pacific Chemical Solutions', 'fluids_rubber',       NULL, 80000,  500000,  0.05),
('ls_electronics', 'LS Electronics Corp',       'electronics',         NULL, 90000,  600000,  0.05)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- ===================================================================
-- SEED DATA: Company Catalogs
-- ===================================================================

-- Santos Metal Works — heavy parts
INSERT INTO `company_catalog` (`company_id`, `item_name`, `base_price`, `current_price`) VALUES
-- Engine
('santos_metal', 'part_engine_block',   2500, 2500),
('santos_metal', 'part_spark_plugs',    120,  120),
('santos_metal', 'part_air_filter',     80,   80),
('santos_metal', 'part_radiator',       450,  450),
('santos_metal', 'part_turbo',          1800, 1800),
('santos_metal', 'part_oil_pump',       350,  350),
('santos_metal', 'part_water_pump',     280,  280),
('santos_metal', 'part_fuel_pump',      320,  320),
('santos_metal', 'part_exhaust',        500,  500),
('santos_metal', 'part_intake',         400,  400),
('santos_metal', 'part_timing_belt',    200,  200),
-- Transmission
('santos_metal', 'part_clutch',         600,  600),
('santos_metal', 'part_transmission',   2200, 2200),
-- Brakes
('santos_metal', 'part_brake_pads',     150,  150),
('santos_metal', 'part_brake_rotors',   300,  300),
('santos_metal', 'part_brake_caliper',  500,  500),
-- Suspension
('santos_metal', 'part_shocks',         350,  350),
('santos_metal', 'part_springs',        250,  250),
('santos_metal', 'part_wheel_bearings', 200,  200),
('santos_metal', 'part_cv_joint',       300,  300),
('santos_metal', 'part_tie_rod',        180,  180),
('santos_metal', 'part_ball_joint',     220,  220),
('santos_metal', 'part_control_arm',    350,  350),
-- Body
('santos_metal', 'part_body_panel',     400,  400),
('santos_metal', 'part_fender',         300,  300),
('santos_metal', 'part_windshield',     350,  350)
ON DUPLICATE KEY UPDATE `base_price` = VALUES(`base_price`);

-- Pacific Chemical Solutions — fluids, rubber, tires, paint
INSERT INTO `company_catalog` (`company_id`, `item_name`, `base_price`, `current_price`) VALUES
('pacific_chem', 'fluid_motor_oil',        50,   50),
('pacific_chem', 'fluid_coolant',          45,   45),
('pacific_chem', 'fluid_brake',            55,   55),
('pacific_chem', 'fluid_trans',            60,   60),
('pacific_chem', 'fluid_power_steering',   40,   40),
('pacific_chem', 'part_tire',              200,  200),
('pacific_chem', 'part_tire_performance',  500,  500),
('pacific_chem', 'part_tire_offroad',      350,  350)
ON DUPLICATE KEY UPDATE `base_price` = VALUES(`base_price`);

-- LS Electronics Corp — electrical, ECU, wiring, lights
INSERT INTO `company_catalog` (`company_id`, `item_name`, `base_price`, `current_price`) VALUES
('ls_electronics', 'part_ecu',            1500, 1500),
('ls_electronics', 'part_wiring',         400,  400),
('ls_electronics', 'part_battery',        200,  200),
('ls_electronics', 'part_alternator',     550,  550),
('ls_electronics', 'part_starter',        450,  450),
('ls_electronics', 'part_headlights',     250,  250),
('ls_electronics', 'part_taillights',     200,  200),
-- Tools
('ls_electronics', 'tool_diagnostic',     800,  800),
('ls_electronics', 'tool_multimeter',     400,  400),
-- Upgrade kits (cross-company premium)
('ls_electronics', 'upgrade_ecu',         3500, 3500)
ON DUPLICATE KEY UPDATE `base_price` = VALUES(`base_price`);

-- Cross-company upgrade kits at Santos Metal
INSERT INTO `company_catalog` (`company_id`, `item_name`, `base_price`, `current_price`) VALUES
('santos_metal', 'upgrade_engine',       5000, 5000),
('santos_metal', 'upgrade_transmission', 4500, 4500),
('santos_metal', 'upgrade_brakes',       3000, 3000),
('santos_metal', 'upgrade_suspension',   3000, 3000),
('santos_metal', 'upgrade_turbo',        5500, 5500),
('santos_metal', 'upgrade_exhaust',      2500, 2500),
('santos_metal', 'upgrade_intake',       2000, 2000),
-- Tools
('santos_metal', 'tool_wrench_set',      200,  200),
('santos_metal', 'tool_torque_wrench',   350,  350),
('santos_metal', 'tool_jack',            300,  300),
('santos_metal', 'tool_welding_kit',     500,  500),
('santos_metal', 'tool_alignment_gauge', 400,  400),
('santos_metal', 'tool_brake_bleeder',   250,  250),
('santos_metal', 'tool_tire_machine',    150,  150),
('santos_metal', 'tool_paint_gun',       350,  350),
('santos_metal', 'tool_compression_tester', 350, 350)
ON DUPLICATE KEY UPDATE `base_price` = VALUES(`base_price`);

-- ===================================================================
-- SEED DATA: Initial Raw Material Stock at Companies
-- ===================================================================

-- Santos Metal Works raw stock
INSERT INTO `company_stock` (`company_id`, `item_name`, `quantity`) VALUES
('santos_metal', 'raw_steel', 200),
('santos_metal', 'raw_aluminum', 150),
('santos_metal', 'raw_copper', 100),
('santos_metal', 'raw_iron', 150),
('santos_metal', 'raw_chrome', 50),
('santos_metal', 'raw_bearing_steel', 80),
('santos_metal', 'raw_rubber', 80),
('santos_metal', 'raw_fiberglass', 40),
('santos_metal', 'raw_glass', 60),
('santos_metal', 'raw_friction_material', 60),
('santos_metal', 'raw_gasket_material', 50),
('santos_metal', 'raw_adhesive', 40),
('santos_metal', 'raw_sandpaper', 40),
('santos_metal', 'raw_paint_base', 30)
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);

-- Pacific Chemical Solutions raw stock
INSERT INTO `company_stock` (`company_id`, `item_name`, `quantity`) VALUES
('pacific_chem', 'raw_oil', 300),
('pacific_chem', 'raw_rubber', 200),
('pacific_chem', 'raw_glycol', 150),
('pacific_chem', 'raw_brake_fluid', 100),
('pacific_chem', 'raw_additive', 100),
('pacific_chem', 'raw_dye', 80),
('pacific_chem', 'raw_kevlar', 30),
('pacific_chem', 'raw_carbon', 20)
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);

-- LS Electronics Corp raw stock
INSERT INTO `company_stock` (`company_id`, `item_name`, `quantity`) VALUES
('ls_electronics', 'raw_copper', 150),
('ls_electronics', 'raw_silicon', 100),
('ls_electronics', 'raw_circuit_board', 80),
('ls_electronics', 'raw_magnet', 60),
('ls_electronics', 'raw_solder', 100),
('ls_electronics', 'raw_plastic', 80),
('ls_electronics', 'raw_glass', 40),
('ls_electronics', 'raw_lead', 50)
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);
