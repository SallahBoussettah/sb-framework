-- sb_banking Database Schema

CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) UNIQUE NOT NULL,
    `pin` VARCHAR(255) NOT NULL,
    `card_id` VARCHAR(16) NOT NULL,
    `card_locked` TINYINT DEFAULT 0,
    `pin_attempts` INT DEFAULT 0,
    `savings` BIGINT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `type` ENUM('deposit', 'withdraw', 'transfer_in', 'transfer_out', 'account_open', 'card_replace', 'atm_withdraw', 'savings_deposit', 'savings_withdraw', 'card_request') NOT NULL,
    `amount` INT NOT NULL,
    `balance_after` INT NOT NULL,
    `description` VARCHAR(255) DEFAULT NULL,
    `target_citizenid` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
