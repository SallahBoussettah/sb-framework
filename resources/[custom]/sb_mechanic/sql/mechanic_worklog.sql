-- ========================================================================
-- sb_mechanic - Worklog Table
-- Auto-tracks all repair/upgrade work done per vehicle plate
-- ========================================================================

CREATE TABLE IF NOT EXISTS `mechanic_worklog` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(10) NOT NULL,
    `service_type` VARCHAR(50) NOT NULL,
    `service_label` VARCHAR(100) NOT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `mechanic_cid` VARCHAR(50) NOT NULL,
    `mechanic_name` VARCHAR(100) DEFAULT NULL,
    `paid` TINYINT(1) DEFAULT 0,
    `invoice_id` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_paid` (`paid`),
    INDEX `idx_mechanic` (`mechanic_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
