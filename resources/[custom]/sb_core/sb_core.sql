-- ============================================================================
-- EVERYDAY CHAOS RP - DATABASE SCHEMA
-- Author: Salah Eddine Boussettah
-- ============================================================================

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS `everdaychaos` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE everdaychaos;

-- ============================================================================
-- USERS TABLE - Account-level data (one per real player)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(255) NOT NULL COMMENT 'Rockstar license (unique identifier)',
    `steam` VARCHAR(255) DEFAULT NULL COMMENT 'Steam hex identifier',
    `discord` VARCHAR(255) DEFAULT NULL COMMENT 'Discord ID',
    `xbox` VARCHAR(255) DEFAULT NULL,
    `live` VARCHAR(255) DEFAULT NULL,
    `fivem` VARCHAR(255) DEFAULT NULL COMMENT 'FiveM account ID',
    `name` VARCHAR(255) NOT NULL COMMENT 'Display name (Steam/Discord)',
    `role` VARCHAR(50) DEFAULT 'user' COMMENT 'Primary role: user, vip, moderator, admin, superadmin',
    `permissions` TEXT DEFAULT NULL COMMENT 'JSON: additional custom permissions',
    `playtime` INT(11) DEFAULT 0 COMMENT 'Total playtime in minutes',
    `character_slots` INT(11) DEFAULT 3 COMMENT 'Max character slots for this user',
    `is_whitelisted` TINYINT(1) DEFAULT 0 COMMENT 'Whitelist status',
    `is_banned` TINYINT(1) DEFAULT 0 COMMENT 'Quick ban check flag',
    `vip_level` INT(11) DEFAULT 0 COMMENT '0=none, 1=bronze, 2=silver, 3=gold, 4=platinum',
    `vip_expires` TIMESTAMP NULL DEFAULT NULL COMMENT 'VIP expiration date',
    `priority` INT(11) DEFAULT 0 COMMENT 'Queue priority (higher = faster)',
    `notes` TEXT DEFAULT NULL COMMENT 'Admin notes about this user',
    `first_join` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `license` (`license`),
    KEY `discord` (`discord`),
    KEY `role` (`role`),
    KEY `vip_level` (`vip_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- ROLES TABLE - Role definitions with permissions
-- ============================================================================
CREATE TABLE IF NOT EXISTS `roles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL COMMENT 'Role identifier: user, vip, moderator, admin, superadmin',
    `label` VARCHAR(100) NOT NULL COMMENT 'Display name',
    `priority` INT(11) DEFAULT 0 COMMENT 'Role priority (higher = more authority)',
    `permissions` TEXT NOT NULL COMMENT 'JSON: array of permission strings',
    `color` VARCHAR(10) DEFAULT '#ffffff' COMMENT 'Role color for UI',
    `icon` VARCHAR(50) DEFAULT NULL COMMENT 'Icon name for UI',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default roles
INSERT INTO `roles` (`name`, `label`, `priority`, `permissions`, `color`, `icon`) VALUES
('user', 'Player', 0, '["play"]', '#ffffff', 'user'),
('vip', 'VIP', 10, '["play", "vip.priority", "vip.extras"]', '#ffd700', 'star'),
('moderator', 'Moderator', 50, '["play", "mod.kick", "mod.warn", "mod.spectate", "mod.teleport"]', '#00bfff', 'shield'),
('admin', 'Admin', 80, '["play", "admin.*", "mod.*"]', '#ff6b35', 'shield-check'),
('superadmin', 'Super Admin', 100, '["*"]', '#ff0000', 'crown')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- ============================================================================
-- PERMISSIONS LOG TABLE - Track permission changes
-- ============================================================================
CREATE TABLE IF NOT EXISTS `permission_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(255) NOT NULL,
    `action` VARCHAR(50) NOT NULL COMMENT 'grant, revoke, role_change',
    `permission` VARCHAR(100) DEFAULT NULL,
    `old_value` VARCHAR(100) DEFAULT NULL,
    `new_value` VARCHAR(100) DEFAULT NULL,
    `admin_license` VARCHAR(255) DEFAULT NULL COMMENT 'Who made the change',
    `reason` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PLAYERS TABLE - Character data (multiple per user)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `players` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `cid` INT(11) DEFAULT NULL COMMENT 'Character slot (1-5)',
    `license` VARCHAR(255) NOT NULL COMMENT 'Rockstar license',
    `name` VARCHAR(255) NOT NULL COMMENT 'Steam/Discord display name',
    `money` TEXT NOT NULL COMMENT 'JSON: {cash, bank, crypto}',
    `charinfo` TEXT DEFAULT NULL COMMENT 'JSON: {firstname, lastname, birthdate, gender, nationality, phone, account}',
    `job` TEXT NOT NULL COMMENT 'JSON: {name, label, payment, onduty, isboss, grade}',
    `gang` TEXT DEFAULT NULL COMMENT 'JSON: {name, label, isboss, grade}',
    `position` TEXT NOT NULL COMMENT 'JSON: {x, y, z, w}',
    `metadata` TEXT NOT NULL COMMENT 'JSON: {hunger, thirst, stress, licenses, etc}',
    `inventory` LONGTEXT DEFAULT NULL COMMENT 'JSON: inventory items',
    `skin` LONGTEXT DEFAULT NULL COMMENT 'JSON: character appearance',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    KEY `id` (`id`),
    KEY `license` (`license`),
    KEY `cid` (`cid`),
    KEY `last_updated` (`last_updated`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PLAYER VEHICLES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `vehicle` VARCHAR(50) NOT NULL COMMENT 'Model name',
    `plate` VARCHAR(12) NOT NULL,
    `mods` LONGTEXT DEFAULT NULL COMMENT 'JSON: vehicle modifications',
    `garage` VARCHAR(50) DEFAULT 'legion' COMMENT 'Current garage',
    `fuel` INT(11) DEFAULT 100,
    `engine` FLOAT DEFAULT 1000.0,
    `body` FLOAT DEFAULT 1000.0,
    `state` TINYINT(1) DEFAULT 1 COMMENT '0=out, 1=garaged, 2=impounded',
    `depotprice` INT(11) DEFAULT 0,
    `balance` INT(11) DEFAULT 0 COMMENT 'Finance balance',
    `paymentamount` INT(11) DEFAULT 0,
    `paymentsleft` INT(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `plate` (`plate`),
    UNIQUE KEY `plate_unique` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- BANS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS `bans` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) DEFAULT NULL,
    `license` VARCHAR(255) NOT NULL,
    `discord` VARCHAR(255) DEFAULT NULL,
    `ip` VARCHAR(255) DEFAULT NULL,
    `reason` TEXT NOT NULL,
    `expire` INT(11) DEFAULT NULL COMMENT 'Unix timestamp, NULL = permanent',
    `bannedby` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PLAYER HOUSES TABLE (Future)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `player_houses` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `house` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `keyholders` TEXT DEFAULT NULL COMMENT 'JSON: array of citizenids',
    `decorations` TEXT DEFAULT NULL COMMENT 'JSON: furniture/decorations',
    `stash` TEXT DEFAULT NULL COMMENT 'JSON: stash items',
    `logout` TEXT DEFAULT NULL COMMENT 'JSON: logout position',
    PRIMARY KEY (`id`),
    UNIQUE KEY `house` (`house`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- BANK ACCOUNTS TABLE (Shared/Society)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `account_name` VARCHAR(50) NOT NULL,
    `account_type` VARCHAR(20) DEFAULT 'personal' COMMENT 'personal, shared, job, gang',
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `balance` BIGINT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `account_name` (`account_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
