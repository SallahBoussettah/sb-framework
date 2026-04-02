-- ========================================================================
-- Everyday Chaos RP - Drug System Database
-- Author: Salah Eddine Boussettah
-- Run this ONCE to add drug items to the sb_items table
-- ========================================================================

-- ========================================================================
-- DRUG ITEMS (42 items)
-- ========================================================================

-- ACCESS CARDS (3)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('access_card_weed', 'Weed Farm Access Card', 'item', 'drug', 'access_card_weed.png', 0, 1, 0, 0, 'Access card for the weed farm'),
('access_card_coke', 'Cocaine Lab Access Card', 'item', 'drug', 'access_card_coke.png', 0, 1, 0, 0, 'Access card for the cocaine lockup'),
('access_card_meth', 'Meth Lab Access Card', 'item', 'drug', 'access_card_meth.png', 0, 1, 0, 0, 'Access card for the meth lab');

-- RAW MATERIALS (8)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weed_bud', 'Weed Bud', 'item', 'drug', 'weed_bud.png', 1, 50, 0, 0, 'Raw marijuana bud, needs cleaning'),
('coca_leaf', 'Coca Leaf', 'item', 'drug', 'coca_leaf.png', 1, 50, 0, 0, 'Fresh coca leaf from the field'),
('poppy_flower', 'Poppy Flower', 'item', 'drug', 'poppy_flower.png', 1, 50, 0, 0, 'Opium poppy flower for processing'),
('mushroom_raw', 'Raw Mushroom', 'item', 'drug', 'mushroom_raw.png', 1, 30, 0, 0, 'Raw psilocybin mushroom'),
('peyote_raw', 'Raw Peyote', 'item', 'drug', 'peyote_raw.png', 1, 30, 0, 0, 'Raw peyote cactus button'),
('meth_acid', 'Acid Canister', 'item', 'drug', 'meth_acid.png', 1, 10, 0, 0, 'Canister filled with acid for cooking'),
('meth_acid_empty', 'Empty Acid Can', 'item', 'drug', 'meth_acid_empty.png', 1, 10, 0, 0, 'Empty canister, needs filling at chemical source'),
('ammonia', 'Ammonia', 'item', 'drug', 'ammonia.png', 1, 20, 0, 0, 'Chemical ammonia for drug processing');

-- TOOLS (8)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('scissors', 'Scissors', 'item', 'drug', 'scissors.png', 0, 1, 0, 0, 'Garden scissors for trimming plants'),
('trowel', 'Trowel', 'item', 'drug', 'trowel.png', 0, 1, 0, 0, 'Garden trowel for harvesting'),
('hammer', 'Hammer', 'item', 'drug', 'hammer.png', 0, 1, 0, 0, 'Hammer for crushing crystals'),
('glue', 'Glue', 'item', 'drug', 'glue.png', 1, 10, 0, 0, 'Adhesive glue'),
('empty_bag', 'Empty Bag', 'item', 'drug', 'empty_bag.png', 1, 50, 0, 0, 'Empty plastic bag for packaging'),
('rolling_papers', 'Rolling Papers', 'item', 'drug', 'rolling_papers.png', 1, 50, 1, 1, 'Papers for rolling joints'),
('blunt_wrap', 'Blunt Wrap', 'item', 'drug', 'blunt_wrap.png', 1, 50, 1, 1, 'Tobacco leaf wrap for blunts'),
('empty_figure', 'Action Figure (Empty)', 'item', 'drug', 'empty_figure.png', 1, 20, 0, 0, 'Hollow action figure for hiding product');

-- INTERMEDIATE PRODUCTS (7)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weed_clean', 'Cleaned Weed', 'item', 'drug', 'weed_clean.png', 1, 50, 0, 0, 'Cleaned marijuana ready for packaging'),
('coca_paste', 'Coca Paste', 'item', 'drug', 'coca_paste.png', 1, 30, 0, 0, 'Processed coca paste'),
('coca_raw', 'Raw Cocaine', 'item', 'drug', 'coca_raw.png', 1, 30, 0, 0, 'Unrefined cocaine extract'),
('coca_pure', 'Pure Cocaine', 'item', 'drug', 'coca_pure.png', 1, 20, 1, 1, 'Purified cocaine powder'),
('meth_liquid', 'Meth Liquid', 'item', 'drug', 'meth_liquid.png', 1, 10, 0, 0, 'Liquid methamphetamine before crystallization'),
('meth_crystal', 'Meth Crystal', 'item', 'drug', 'meth_crystal.png', 1, 10, 0, 0, 'Crystallized methamphetamine shard'),
('syringe', 'Empty Syringe', 'item', 'drug', 'syringe.png', 1, 20, 1, 1, 'Use to fill with heroin or meth');

-- FINISHED PRODUCTS (10)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('weed_bag', 'Weed Bag', 'item', 'drug', 'weed_bag.png', 1, 20, 0, 0, 'Packaged marijuana ready for sale'),
('meth_bag', 'Meth Bag', 'item', 'drug', 'meth_bag.png', 1, 20, 1, 1, 'Packaged methamphetamine'),
('cocaine_figure', 'Cocaine Figure', 'item', 'drug', 'cocaine_figure.png', 1, 10, 0, 0, 'Action figure filled with cocaine'),
('heroin_dose', 'Heroin Dose', 'item', 'drug', 'heroin_dose.png', 1, 20, 0, 0, 'Packaged heroin dose'),
('crack_rock', 'Crack Rock', 'item', 'drug', 'crack_rock.png', 1, 20, 1, 1, 'Cooked crack cocaine rock'),
('weed_joint', 'Weed Joint', 'item', 'drug', 'weed_joint.png', 1, 20, 1, 1, 'Rolled marijuana joint'),
('weed_blunt', 'Weed Blunt', 'item', 'drug', 'weed_blunt.png', 1, 20, 1, 1, 'Rolled marijuana blunt'),
('mushroom_dried', 'Dried Mushroom', 'item', 'drug', 'mushroom_dried.png', 1, 20, 1, 1, 'Dried psilocybin mushroom'),
('peyote_dried', 'Dried Peyote', 'item', 'drug', 'peyote_dried.png', 1, 20, 1, 1, 'Dried peyote cactus button'),
('pipe', 'Smoking Pipe', 'item', 'drug', 'pipe.png', 0, 1, 0, 0, 'Glass pipe for smoking');

-- CONSUMABLE PREPARATIONS (6)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('lsd_tab', 'LSD Tab', 'item', 'drug', 'lsd_tab.png', 1, 20, 1, 1, 'Lysergic acid diethylamide blotter tab'),
('ecstasy_pill', 'Ecstasy Pill', 'item', 'drug', 'ecstasy_pill.png', 1, 20, 1, 1, 'MDMA pressed pill'),
('xanax_pill', 'Xanax Pill', 'item', 'drug', 'xanax_pill.png', 1, 20, 1, 1, 'Alprazolam anti-anxiety pill'),
('heroin_syringe', 'Heroin Syringe', 'item', 'drug', 'heroin_syringe.png', 1, 10, 1, 1, 'Syringe loaded with heroin'),
('meth_syringe', 'Meth Syringe', 'item', 'drug', 'meth_syringe.png', 1, 10, 1, 1, 'Syringe loaded with methamphetamine'),
('cocaine_line', 'Cocaine Line', 'item', 'drug', 'cocaine_line.png', 1, 20, 1, 1, 'Prepared line of cocaine powder');

-- BAKING SODA (tool/ingredient)
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('baking_soda', 'Baking Soda', 'item', 'drug', 'baking_soda.png', 1, 30, 0, 0, 'Sodium bicarbonate for crack production');

-- ========================================================================
-- DRUG PROGRESSION TABLE (tracks player card ownership for persistence)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `sb_drug_progression` (
    `citizenid` VARCHAR(50) NOT NULL,
    `access_card_weed` TINYINT(1) NOT NULL DEFAULT 0,
    `access_card_coke` TINYINT(1) NOT NULL DEFAULT 0,
    `access_card_meth` TINYINT(1) NOT NULL DEFAULT 0,
    `total_sold` INT NOT NULL DEFAULT 0,
    `total_earned` BIGINT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
