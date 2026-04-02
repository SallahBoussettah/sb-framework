-- ============================================================================
-- Everyday Chaos RP - Gym & Fitness SQL
-- Author: Salah Eddine Boussettah
--
-- Run this SQL to add the protein_shake item to your database.
-- The gym skills are stored in player metadata (no separate tables needed).
-- ============================================================================

-- Add protein shake item to sb_items table
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`)
VALUES ('protein_shake', 'Protein Shake', 'item', 'consumable', 'protein_shake.png', 1, 10, 1, 1, 'A high-protein shake that doubles gym XP for 5 minutes')
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`),
    `description` = VALUES(`description`);
