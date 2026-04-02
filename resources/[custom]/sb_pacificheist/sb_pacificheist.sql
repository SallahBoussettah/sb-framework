-- ========================================================================
-- Pacific Heist Items for sb_inventory database
-- Run this SQL to add heist items to your database
-- Author: Salah Eddine Boussettah
-- ========================================================================

-- ========================================================================
-- PACIFIC HEIST - TOOLS (Required to perform heist)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('heist_drill', 'Thermal Drill', 'item', 'heist', 'heist_drill.png', 0, 1, 0, 0, 'Professional-grade laser thermal drill for vault doors'),
('heist_bag', 'Heist Bag', 'item', 'heist', 'heist_bag.png', 0, 1, 0, 0, 'Tactical duffel bag for carrying loot'),
('glass_cutter', 'Glass Cutter', 'item', 'heist', 'glass_cutter.png', 0, 1, 0, 0, 'Precision glass cutting tool with diamond tip'),
('c4_explosive', 'C4 Explosive', 'item', 'heist', 'c4_explosive.png', 1, 10, 0, 0, 'Military-grade plastic explosive with detonator'),
('thermite_charge', 'Thermite Charge', 'item', 'heist', 'thermite_charge.png', 1, 10, 0, 0, 'Incendiary charge for melting through metal'),
('hacking_laptop', 'Hacking Laptop', 'item', 'heist', 'hacking_laptop.png', 0, 1, 0, 0, 'Portable hacking workstation'),
('trojan_usb', 'Trojan USB', 'item', 'heist', 'trojan_usb.png', 1, 5, 0, 0, 'USB drive loaded with malware')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `description` = VALUES(`description`);

-- ========================================================================
-- PACIFIC HEIST - LOOT (Rewards from vault)
-- ========================================================================
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('gold_bar', 'Gold Bar', 'item', 'valuable', 'gold_bar.png', 1, 50, 0, 0, 'Solid gold bullion bar'),
('diamond_pouch', 'Diamond Pouch', 'item', 'valuable', 'diamond_pouch.png', 1, 20, 0, 0, 'Small pouch containing loose diamonds'),
('cocaine_brick', 'Cocaine Brick', 'item', 'contraband', 'cocaine_brick.png', 1, 10, 0, 0, 'Wrapped brick of cocaine'),
('panther_statue', 'Panther Statue', 'item', 'valuable', 'panther_statue.png', 0, 1, 0, 0, 'Black onyx panther figurine'),
('diamond_necklace', 'Diamond Necklace', 'item', 'valuable', 'diamond_necklace.png', 0, 1, 0, 0, 'Elegant platinum diamond necklace'),
('vintage_wine', 'Vintage Wine', 'item', 'valuable', 'vintage_wine.png', 0, 1, 0, 0, 'Rare vintage wine bottle'),
('vault_painting', 'Vault Painting', 'item', 'valuable', 'vault_painting.png', 0, 1, 0, 0, 'Rolled canvas painting from the vault'),
('rare_watch', 'Rare Watch', 'item', 'valuable', 'rare_watch.png', 0, 1, 0, 0, 'Luxury gold timepiece')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `description` = VALUES(`description`);

-- ========================================================================
-- ITEM DETAILS FOR IMAGE CREATION
-- ========================================================================
--
-- HEIST TOOLS (7 items):
-- | Item Name        | Image File           | Description                                    |
-- |------------------|----------------------|------------------------------------------------|
-- | heist_drill      | heist_drill.png      | Laser thermal drill with orange glowing tip    |
-- | heist_bag        | heist_bag.png        | Black tactical duffel bag with cash inside     |
-- | glass_cutter     | glass_cutter.png     | Diamond-tipped glass cutting tool              |
-- | c4_explosive     | c4_explosive.png     | C4 brick with detonator and wires              |
-- | thermite_charge  | thermite_charge.png  | Red thermite canister with warning labels      |
-- | hacking_laptop   | hacking_laptop.png   | Black laptop with green matrix code screen     |
-- | trojan_usb       | trojan_usb.png       | Black USB drive with red LED                   |
--
-- LOOT ITEMS (8 items):
-- | Item Name        | Image File           | Description                                    |
-- |------------------|----------------------|------------------------------------------------|
-- | gold_bar         | gold_bar.png         | Shiny gold bullion bar                         |
-- | diamond_pouch    | diamond_pouch.png    | Black velvet pouch with diamonds spilling      |
-- | cocaine_brick    | cocaine_brick.png    | White powder brick in plastic wrap             |
-- | panther_statue   | panther_statue.png   | Black onyx panther figurine                    |
-- | diamond_necklace | diamond_necklace.png | Platinum necklace with diamonds                |
-- | vintage_wine     | vintage_wine.png     | Old wine bottle with dusty label               |
-- | vault_painting   | vault_painting.png   | Rolled canvas with gold frame edge             |
-- | rare_watch       | rare_watch.png       | Gold luxury watch with leather strap           |
--
-- Place all images in: sb_inventory/html/images/
-- Image size: 128x128 PNG with transparent background
