-- ========================================================================
-- Everyday Chaos RP - Fuel System Database Items
-- Author: Salah Eddine Boussettah
-- Run this to add fuel items to existing sb_items table
-- ========================================================================

-- FUEL & VEHICLE MAINTENANCE ITEMS
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('jerrycan', 'Jerry Can', 'item', 'tool', 'jerrycan.png', 1, 3, 1, 1, 'Portable fuel container (20L capacity)'),
('syphon_kit', 'Syphon Kit', 'item', 'tool', 'syphon_kit.png', 1, 1, 0, 0, 'Kit for syphoning fuel from vehicles')
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`),
    `category` = VALUES(`category`),
    `image` = VALUES(`image`),
    `stackable` = VALUES(`stackable`),
    `max_stack` = VALUES(`max_stack`),
    `useable` = VALUES(`useable`),
    `shouldClose` = VALUES(`shouldClose`),
    `description` = VALUES(`description`);
