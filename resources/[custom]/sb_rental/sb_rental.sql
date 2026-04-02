-- sb_rental Database Schema
-- Vehicle Rental System for Everyday Chaos RP

CREATE TABLE IF NOT EXISTS `vehicle_rentals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `rental_id` VARCHAR(10) NOT NULL UNIQUE,          -- R-XXXXX format
    `citizenid` VARCHAR(50) NOT NULL,                 -- Renter citizen ID
    `vehicle` VARCHAR(50) NOT NULL,                   -- Model name
    `vehicle_label` VARCHAR(100) NOT NULL,            -- Display name
    `plate` VARCHAR(8) NOT NULL,                      -- Generated plate (RNT XXX)
    `category` VARCHAR(20) NOT NULL,                  -- 'bicycle', 'scooter', 'car'
    `location_id` VARCHAR(50) NOT NULL,               -- Where rented from
    `daily_rate` INT NOT NULL,                        -- Price per day
    `days_rented` INT NOT NULL,                       -- 1-7 days
    `total_cost` INT NOT NULL,                        -- daily_rate × days
    `deposit` INT NOT NULL DEFAULT 0,                 -- Optional deposit
    `rental_start` DATETIME NOT NULL,                 -- Real timestamp
    `rental_end` DATETIME NOT NULL,                   -- Expected return
    `actual_return` DATETIME DEFAULT NULL,            -- When actually returned
    `late_fees` INT DEFAULT 0,                        -- Accumulated late fees
    `damage_fees` INT DEFAULT 0,                      -- Damage charges
    `status` ENUM('active', 'returned', 'late', 'stolen', 'despawned') DEFAULT 'active',
    `vehicle_state` LONGTEXT DEFAULT NULL,            -- JSON: last known props
    `blacklist_until` DATETIME DEFAULT NULL,          -- Rental ban expiry
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_plate` (`plate`),
    INDEX `idx_status` (`status`),
    INDEX `idx_rental_end` (`rental_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES 
('rental_license', 'Rental License', 'item', 'document', 'rental_license.png', 0, 1, 1, 1, 'Vehicle rental agreement - show to police if stopped');
