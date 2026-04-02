-- Everyday Chaos RP - Impound System Database Setup
-- Author: Salah Eddine Boussettah
-- Run this AFTER sb_core and sb_vehicleshop are installed

-- Add impound columns to player_vehicles if not exists
ALTER TABLE `player_vehicles`
ADD COLUMN IF NOT EXISTS `impound_reason` VARCHAR(255) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `impound_time` TIMESTAMP NULL DEFAULT NULL;

-- Create key removal tracking table
-- This tracks keys that need to be removed from offline players
CREATE TABLE IF NOT EXISTS `impound_key_removals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `plate` VARCHAR(20) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_removal` (`citizenid`, `plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vehicle states reference:
-- 0 = out (in world)
-- 1 = stored (garage)
-- 2 = impounded
-- 3 = destroyed (impounded but needs repair fee)
