-- ========================================================================
-- Everyday Chaos RP - Mechanic Phase 2: Crafting Items
-- Author: Salah Eddine Boussettah
-- NOTE: Run AFTER sb_inventory.sql — these INSERT IGNORE to avoid dupes
-- ========================================================================

-- ========================================================================
-- RAW MATERIALS - METALS (9 items)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('raw_steel', 'Steel Stock', 'item', 'mechanic', 'raw_steel.png', 1, 50, 0, 0, 'Raw steel stock for metalworking'),
('raw_aluminum', 'Aluminum Ingot', 'item', 'mechanic', 'raw_aluminum.png', 1, 50, 0, 0, 'Raw aluminum for lightweight parts'),
('raw_copper', 'Copper Rod', 'item', 'mechanic', 'raw_copper.png', 1, 50, 0, 0, 'Raw copper for electrical components'),
('raw_iron', 'Cast Iron Block', 'item', 'mechanic', 'raw_iron.png', 1, 50, 0, 0, 'Heavy cast iron for engine blocks'),
('raw_titanium', 'Titanium Bar', 'item', 'mechanic', 'raw_titanium.png', 1, 30, 0, 0, 'Premium titanium for high-end parts'),
('raw_chrome', 'Chrome Stock', 'item', 'mechanic', 'raw_chrome.png', 1, 40, 0, 0, 'Chrome plating material'),
('raw_zinc', 'Zinc Ingot', 'item', 'mechanic', 'raw_zinc.png', 1, 50, 0, 0, 'Zinc for galvanizing and alloys'),
('raw_lead', 'Lead Block', 'item', 'mechanic', 'raw_lead.png', 1, 30, 0, 0, 'Dense lead for batteries and weights'),
('raw_bearing_steel', 'Bearing Steel', 'item', 'mechanic', 'raw_bearing_steel.png', 1, 40, 0, 0, 'Precision steel for bearing races');

-- ========================================================================
-- RAW MATERIALS - NON-METALS (7 items)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('raw_rubber', 'Rubber Compound', 'item', 'mechanic', 'raw_rubber.png', 1, 50, 0, 0, 'Raw rubber compound for tires and seals'),
('raw_plastic', 'ABS Plastic Pellets', 'item', 'mechanic', 'raw_plastic.png', 1, 50, 0, 0, 'Engineering plastic for housings'),
('raw_glass', 'Glass Blank', 'item', 'mechanic', 'raw_glass.png', 1, 30, 0, 0, 'Automotive glass sheet'),
('raw_ceramic', 'Ceramic Compound', 'item', 'mechanic', 'raw_ceramic.png', 1, 50, 0, 0, 'High-temp ceramic for spark plugs'),
('raw_carbon', 'Carbon Fiber Sheet', 'item', 'mechanic', 'raw_carbon.png', 1, 20, 0, 0, 'Lightweight carbon fiber weave'),
('raw_fiberglass', 'Fiberglass Mat', 'item', 'mechanic', 'raw_fiberglass.png', 1, 30, 0, 0, 'Fiberglass for body repair'),
('raw_kevlar', 'Kevlar Fabric', 'item', 'mechanic', 'raw_kevlar.png', 1, 20, 0, 0, 'Reinforcement fabric for brake pads');

-- ========================================================================
-- RAW MATERIALS - ELECTRICAL (5 items)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('raw_electrode', 'Electrode Wire', 'item', 'mechanic', 'raw_electrode.png', 1, 50, 0, 0, 'Electrode material for spark plugs'),
('raw_silicon', 'Silicon Wafer', 'item', 'mechanic', 'raw_silicon.png', 1, 30, 0, 0, 'Silicon for circuit boards'),
('raw_circuit_board', 'Blank PCB', 'item', 'mechanic', 'raw_circuit_board.png', 1, 30, 0, 0, 'Blank printed circuit board'),
('raw_magnet', 'Rare Earth Magnet', 'item', 'mechanic', 'raw_magnet.png', 1, 40, 0, 0, 'Strong magnets for alternators'),
('raw_solder', 'Solder Wire', 'item', 'mechanic', 'raw_solder.png', 1, 50, 0, 0, 'Lead-free solder for electronics');

-- ========================================================================
-- RAW MATERIALS - CHEMICAL / FLUID BASE (5 items)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('raw_oil', 'Base Oil', 'item', 'mechanic', 'raw_oil.png', 1, 50, 0, 0, 'Unrefined base oil stock'),
('raw_glycol', 'Ethylene Glycol', 'item', 'mechanic', 'raw_glycol.png', 1, 50, 0, 0, 'Coolant base chemical'),
('raw_brake_fluid', 'DOT4 Fluid Base', 'item', 'mechanic', 'raw_brake_fluid.png', 1, 50, 0, 0, 'Brake fluid base stock'),
('raw_additive', 'Oil Additive Pack', 'item', 'mechanic', 'raw_additive.png', 1, 50, 0, 0, 'Performance oil additives'),
('raw_dye', 'UV Dye Concentrate', 'item', 'mechanic', 'raw_dye.png', 1, 50, 0, 0, 'UV tracking dye for fluids');

-- ========================================================================
-- RAW MATERIALS - CONSUMABLE CRAFT (6 items)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('raw_filter_media', 'Filter Media', 'item', 'mechanic', 'raw_filter_media.png', 1, 50, 0, 0, 'Pleated filter paper material'),
('raw_friction_material', 'Friction Material', 'item', 'mechanic', 'raw_friction_material.png', 1, 50, 0, 0, 'Brake pad friction compound'),
('raw_gasket_material', 'Gasket Sheet', 'item', 'mechanic', 'raw_gasket_material.png', 1, 50, 0, 0, 'Cork-rubber gasket material'),
('raw_adhesive', 'Industrial Adhesive', 'item', 'mechanic', 'raw_adhesive.png', 1, 50, 0, 0, 'High-temp epoxy adhesive'),
('raw_sandpaper', 'Abrasive Paper Pack', 'item', 'mechanic', 'raw_sandpaper.png', 1, 50, 0, 0, 'Multi-grit sandpaper sheets'),
('raw_paint_base', 'Paint Base', 'item', 'mechanic', 'raw_paint_base.png', 1, 50, 0, 0, 'Automotive paint base coat');

-- ========================================================================
-- REFINED MATERIALS (13 items)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('steel_plate', 'Steel Plate', 'item', 'mechanic', 'steel_plate.png', 1, 30, 0, 0, 'Precision-cut steel plate'),
('aluminum_sheet', 'Aluminum Sheet', 'item', 'mechanic', 'aluminum_sheet.png', 1, 30, 0, 0, 'Formed aluminum sheet'),
('copper_wire', 'Copper Wiring', 'item', 'mechanic', 'copper_wire.png', 1, 30, 0, 0, 'Insulated copper wire bundle'),
('rubber_sheet', 'Rubber Sheet', 'item', 'mechanic', 'rubber_sheet.png', 1, 30, 0, 0, 'Vulcanized rubber sheet'),
('plastic_housing', 'Plastic Housing', 'item', 'mechanic', 'plastic_housing.png', 1, 30, 0, 0, 'Molded ABS plastic housing'),
('glass_panel', 'Tempered Glass', 'item', 'mechanic', 'glass_panel.png', 1, 20, 0, 0, 'Heat-treated safety glass'),
('carbon_panel', 'Carbon Panel', 'item', 'mechanic', 'carbon_panel.png', 1, 15, 0, 0, 'Cured carbon fiber panel'),
('friction_pad', 'Friction Pad', 'item', 'mechanic', 'friction_pad.png', 1, 30, 0, 0, 'Formed brake friction pad'),
('gasket_set', 'Gasket Set', 'item', 'mechanic', 'gasket_set.png', 1, 20, 0, 0, 'Cut gasket set for assembly'),
('bearing_set', 'Bearing Set', 'item', 'mechanic', 'bearing_set.png', 1, 20, 0, 0, 'Precision bearing assembly'),
('circuit_assembly', 'Circuit Assembly', 'item', 'mechanic', 'circuit_assembly.png', 1, 20, 0, 0, 'Assembled PCB with components'),
('chrome_finish', 'Chrome Finish', 'item', 'mechanic', 'chrome_finish.png', 1, 20, 0, 0, 'Chrome plating finish kit'),
('wire_harness', 'Wire Harness', 'item', 'mechanic', 'wire_harness.png', 1, 15, 0, 0, 'Pre-wired harness assembly');

-- ========================================================================
-- ADDITIONAL FINISHED PARTS (13 items — parts NOT already in sb_inventory.sql)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('part_oil_pump', 'Oil Pump', 'item', 'mechanic', 'part_oil_pump.png', 1, 5, 0, 0, 'High-pressure oil pump'),
('part_water_pump', 'Water Pump', 'item', 'mechanic', 'part_water_pump.png', 1, 5, 0, 0, 'Coolant circulation pump'),
('part_fuel_pump', 'Fuel Pump', 'item', 'mechanic', 'part_fuel_pump.png', 1, 5, 0, 0, 'Electric fuel injection pump'),
('part_exhaust', 'Exhaust System', 'item', 'mechanic', 'part_exhaust.png', 1, 3, 0, 0, 'Stainless steel exhaust system'),
('part_intake', 'Intake Manifold', 'item', 'mechanic', 'part_intake.png', 1, 5, 0, 0, 'Cold air intake manifold'),
('part_timing_belt', 'Timing Belt Kit', 'item', 'mechanic', 'part_timing_belt.png', 1, 5, 0, 0, 'Timing belt with tensioner'),
('part_starter', 'Starter Motor', 'item', 'mechanic', 'part_starter.png', 1, 5, 0, 0, 'High-torque starter motor'),
('part_cv_joint', 'CV Joint', 'item', 'mechanic', 'part_cv_joint.png', 1, 10, 0, 0, 'Constant velocity joint'),
('part_tie_rod', 'Tie Rod End', 'item', 'mechanic', 'part_tie_rod.png', 1, 10, 0, 0, 'Steering tie rod end'),
('part_ball_joint', 'Ball Joint', 'item', 'mechanic', 'part_ball_joint.png', 1, 10, 0, 0, 'Lower ball joint assembly'),
('part_control_arm', 'Control Arm', 'item', 'mechanic', 'part_control_arm.png', 1, 5, 0, 0, 'Front lower control arm'),
('part_brake_caliper', 'Brake Caliper', 'item', 'mechanic', 'part_brake_caliper.png', 1, 5, 0, 0, 'Rebuilt brake caliper'),
('part_fender', 'Fender Panel', 'item', 'mechanic', 'part_fender.png', 1, 5, 0, 0, 'Steel fender panel');

-- ========================================================================
-- ADDITIONAL FLUIDS (1 item — power steering not in Phase 1)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('fluid_power_steering', 'Power Steering Fluid', 'item', 'mechanic', 'fluid_power_steering.png', 1, 20, 0, 0, 'Power steering hydraulic fluid');

-- ========================================================================
-- ADDITIONAL TOOLS (5 items — not in Phase 1)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('tool_welding_kit', 'Welding Kit', 'item', 'mechanic', 'tool_welding_kit.png', 0, 1, 0, 0, 'MIG welding kit'),
('tool_alignment_gauge', 'Alignment Gauge', 'item', 'mechanic', 'tool_alignment_gauge.png', 0, 1, 0, 0, 'Laser alignment gauge'),
('tool_compression_tester', 'Compression Tester', 'item', 'mechanic', 'tool_compression_tester.png', 0, 1, 0, 0, 'Engine compression test kit'),
('tool_brake_bleeder', 'Brake Bleeder', 'item', 'mechanic', 'tool_brake_bleeder.png', 0, 1, 0, 0, 'Vacuum brake bleeder kit'),
('tool_tire_machine', 'Tire Iron Set', 'item', 'mechanic', 'tool_tire_machine.png', 0, 1, 0, 0, 'Heavy-duty tire iron set');

-- ========================================================================
-- UPGRADE KITS (8 items — replacing generic upgrade_kit)
-- ========================================================================
INSERT IGNORE INTO `sb_items` (`name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`) VALUES
('upgrade_engine', 'Engine Upgrade Kit', 'item', 'mechanic', 'upgrade_engine.png', 0, 1, 0, 0, 'Performance engine internals kit'),
('upgrade_transmission', 'Trans Upgrade Kit', 'item', 'mechanic', 'upgrade_transmission.png', 0, 1, 0, 0, 'Short-throw transmission kit'),
('upgrade_brakes', 'Brake Upgrade Kit', 'item', 'mechanic', 'upgrade_brakes.png', 0, 1, 0, 0, 'Big brake kit upgrade'),
('upgrade_suspension', 'Suspension Upgrade Kit', 'item', 'mechanic', 'upgrade_suspension.png', 0, 1, 0, 0, 'Coilover suspension upgrade'),
('upgrade_turbo', 'Turbo Upgrade Kit', 'item', 'mechanic', 'upgrade_turbo.png', 0, 1, 0, 0, 'Twin-scroll turbo upgrade'),
('upgrade_exhaust', 'Exhaust Upgrade Kit', 'item', 'mechanic', 'upgrade_exhaust.png', 0, 1, 0, 0, 'Cat-back exhaust system'),
('upgrade_intake', 'Intake Upgrade Kit', 'item', 'mechanic', 'upgrade_intake.png', 0, 1, 0, 0, 'Cold air intake upgrade'),
('upgrade_ecu', 'ECU Tune Kit', 'item', 'mechanic', 'upgrade_ecu.png', 0, 1, 0, 0, 'Performance ECU flash kit');
