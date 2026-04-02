-- sb_apartments v2 Database Schema
-- Run this SQL to create/update necessary tables

-- Active rentals
CREATE TABLE IF NOT EXISTS `sb_apartment_rentals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `unit_id` VARCHAR(50) NOT NULL,
    `building_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `rent_amount` INT NOT NULL,
    `deposit_paid` INT NOT NULL,
    `shell_variant` VARCHAR(50) DEFAULT NULL,
    `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `next_payment` TIMESTAMP NOT NULL,
    `missed_payments` INT DEFAULT 0,
    `grace_notified` TINYINT DEFAULT 0,
    `pending_payment` TINYINT DEFAULT 0,
    `status` ENUM('active', 'ended', 'evicted') DEFAULT 'active',
    `ended_at` TIMESTAMP NULL,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_status` (`status`),
    INDEX `idx_next_payment` (`next_payment`),
    INDEX `idx_unit_status` (`unit_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Key holders
CREATE TABLE IF NOT EXISTS `sb_apartment_keys` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `unit_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `granted_by` VARCHAR(50) NOT NULL,
    `granted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_key` (`unit_id`, `citizenid`),
    INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Apartment stash storage
CREATE TABLE IF NOT EXISTS `sb_apartment_stash` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `unit_id` VARCHAR(50) NOT NULL,
    `stash_id` VARCHAR(100) UNIQUE NOT NULL,
    `items` LONGTEXT,
    `slots` INT DEFAULT 50,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_unit_id` (`unit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Activity log
CREATE TABLE IF NOT EXISTS `sb_apartment_log` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `unit_id` VARCHAR(50) NOT NULL,
    `action` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50),
    `details` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_unit_id` (`unit_id`),
    INDEX `idx_action` (`action`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migration for existing tables (run if upgrading from v1)
-- ALTER TABLE `sb_apartment_rentals` ADD COLUMN `shell_variant` VARCHAR(50) DEFAULT NULL AFTER `deposit_paid`;
-- ALTER TABLE `sb_apartment_rentals` ADD COLUMN `grace_notified` TINYINT DEFAULT 0 AFTER `missed_payments`;
-- ALTER TABLE `sb_apartment_rentals` ADD COLUMN `pending_payment` TINYINT DEFAULT 0 AFTER `grace_notified`;
