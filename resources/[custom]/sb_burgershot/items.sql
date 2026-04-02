-- Burger Shot Items - Run this in your database to add items to sb_inventory
-- Database: everdaychaos

-- Raw ingredients (not useable, stackable)
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('bs_raw_patty', 'Raw Patty', 'item', 'food_ingredient', 'bs_raw_patty.png', 1, 20, 0, 0, 'A raw beef patty, needs grilling'),
('bs_cooked_patty', 'Cooked Patty', 'item', 'food_ingredient', 'bs_cooked_patty.png', 1, 20, 0, 0, 'A freshly grilled beef patty'),
('bs_bun', 'Burger Bun', 'item', 'food_ingredient', 'bs_bun.png', 1, 20, 0, 0, 'A sesame seed burger bun'),
('bs_cheese', 'Cheese Slice', 'item', 'food_ingredient', 'bs_cheese.png', 1, 20, 0, 0, 'A slice of American cheese'),
('bs_lettuce', 'Lettuce', 'item', 'food_ingredient', 'bs_lettuce.png', 1, 20, 0, 0, 'Fresh shredded lettuce'),
('bs_tomato', 'Tomato Slice', 'item', 'food_ingredient', 'bs_tomato.png', 1, 20, 0, 0, 'A ripe tomato slice'),
('bs_potato', 'Raw Potato', 'item', 'food_ingredient', 'bs_potato.png', 1, 20, 0, 0, 'A raw potato, ready for frying');

-- Finished food items (useable, stackable)
INSERT INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('bs_fries', 'Fries', 'item', 'food', 'bs_fries.png', 1, 20, 1, 1, 'Golden crispy fries from Burger Shot'),
('bs_burger', 'Bleeder Burger', 'item', 'food', 'bs_burger.png', 1, 20, 1, 1, 'The famous Bleeder Burger with all the fixings'),
('bs_cola', 'eCola', 'item', 'drink', 'bs_cola.png', 1, 20, 1, 1, 'A refreshing ice-cold eCola'),
('bs_meal', 'Murder Meal Box', 'item', 'food', 'bs_meal.png', 1, 10, 1, 1, 'A complete Murder Meal: burger, fries, and eCola');
