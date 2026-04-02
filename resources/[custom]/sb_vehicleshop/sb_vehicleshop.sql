-- Active: 1763755673348@@127.0.0.1@3306@everdaychaos
-- ========================================================================
-- Everyday Chaos RP - Vehicle Shop Database Schema
-- Author: Salah Eddine Boussettah
-- ========================================================================

CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `plate` VARCHAR(8) NOT NULL UNIQUE,
    `vehicle` VARCHAR(50) NOT NULL,
    `vehicle_label` VARCHAR(100) DEFAULT NULL,
    `state` TINYINT NOT NULL DEFAULT 1,
    `garage` VARCHAR(50) DEFAULT 'legion',
    `parking_spot` VARCHAR(100) DEFAULT NULL,
    `fuel` INT NOT NULL DEFAULT 100,
    `body` FLOAT NOT NULL DEFAULT 1000.0,
    `engine` FLOAT NOT NULL DEFAULT 1000.0,
    `mileage` INT NOT NULL DEFAULT 0,
    `degradation` VARCHAR(20) DEFAULT 'new',
    `financed` TINYINT(1) DEFAULT 0,
    `loan_amount` INT DEFAULT 0,
    `loan_remaining` INT DEFAULT 0,
    `loan_payments_missed` INT DEFAULT 0,
    `original_owner` VARCHAR(50) DEFAULT NULL,
    `purchase_price` INT DEFAULT 0,
    `purchase_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `accident_count` INT DEFAULT 0,
    `mods` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_plate` (`plate`),
    INDEX `idx_state` (`state`),
    INDEX `idx_garage` (`garage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `vehicle_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(8) NOT NULL,
    `event_type` VARCHAR(50) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `actor_citizenid` VARCHAR(50) DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_event` (`event_type`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


SELECT license, name, is_whitelisted FROM users;