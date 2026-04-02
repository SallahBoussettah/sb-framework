-- sb_mechanic_v2 | Phase 2: Crafting Recipes
-- All recipe definitions organized by bench type

Recipes = {}

-- ===================================================================
-- BENCH DEFINITIONS
-- ===================================================================
Recipes.Benches = {
    metal_bench       = { label = 'Metal Workbench',     icon = 'hammer' },
    engine_bench      = { label = 'Engine Bench',        icon = 'engine' },
    electronics_bench = { label = 'Electronics Bench',   icon = 'circuit' },
    fluid_station     = { label = 'Fluid Station',       icon = 'droplet' },
    tire_machine      = { label = 'Tire Machine',        icon = 'wheel' },
}

-- ===================================================================
-- RAW -> REFINED MATERIAL RECIPES (13 recipes)
-- ===================================================================
Recipes.RawToRefined = {
    {
        id = 'craft_steel_plate', label = 'Steel Plate', bench = 'metal_bench',
        result = 'steel_plate', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 4000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_steel', amount = 3 } },
        xpReward = 5,
    },
    {
        id = 'craft_aluminum_sheet', label = 'Aluminum Sheet', bench = 'metal_bench',
        result = 'aluminum_sheet', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 4000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_aluminum', amount = 3 } },
        xpReward = 5,
    },
    {
        id = 'craft_copper_wire', label = 'Copper Wiring', bench = 'electronics_bench',
        result = 'copper_wire', resultAmount = 3,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = { type = 'precision', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_copper', amount = 2 } },
        xpReward = 5,
    },
    {
        id = 'craft_rubber_sheet', label = 'Rubber Sheet', bench = 'metal_bench',
        result = 'rubber_sheet', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3500,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_rubber', amount = 3 } },
        xpReward = 5,
    },
    {
        id = 'craft_plastic_housing', label = 'Plastic Housing', bench = 'metal_bench',
        result = 'plastic_housing', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_plastic', amount = 3 } },
        xpReward = 5,
    },
    {
        id = 'craft_glass_panel', label = 'Tempered Glass', bench = 'metal_bench',
        result = 'glass_panel', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 5000,
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'raw_glass', amount = 2 } },
        xpReward = 8,
    },
    {
        id = 'craft_carbon_panel', label = 'Carbon Panel', bench = 'metal_bench',
        result = 'carbon_panel', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'raw_carbon', amount = 2 }, { item = 'raw_adhesive', amount = 1 } },
        xpReward = 15,
    },
    {
        id = 'craft_friction_pad', label = 'Friction Pad', bench = 'metal_bench',
        result = 'friction_pad', resultAmount = 4,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 4000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_friction_material', amount = 2 }, { item = 'raw_steel', amount = 1 } },
        xpReward = 5,
    },
    {
        id = 'craft_gasket_set', label = 'Gasket Set', bench = 'metal_bench',
        result = 'gasket_set', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_gasket_material', amount = 2 } },
        xpReward = 5,
    },
    {
        id = 'craft_bearing_set', label = 'Bearing Set', bench = 'metal_bench',
        result = 'bearing_set', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 5000,
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'raw_bearing_steel', amount = 2 }, { item = 'raw_steel', amount = 1 } },
        xpReward = 8,
    },
    {
        id = 'craft_circuit_assembly', label = 'Circuit Assembly', bench = 'electronics_bench',
        result = 'circuit_assembly', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'sequence', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'raw_circuit_board', amount = 1 }, { item = 'raw_silicon', amount = 1 }, { item = 'raw_solder', amount = 2 } },
        xpReward = 10,
    },
    {
        id = 'craft_chrome_finish', label = 'Chrome Finish', bench = 'metal_bench',
        result = 'chrome_finish', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 5000,
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'raw_chrome', amount = 2 }, { item = 'raw_zinc', amount = 1 }, { item = 'raw_adhesive', amount = 1 } },
        xpReward = 8,
    },
    {
        id = 'craft_wire_harness', label = 'Wire Harness', bench = 'electronics_bench',
        result = 'wire_harness', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'sequence', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'copper_wire', amount = 3 }, { item = 'raw_plastic', amount = 1 } },
        xpReward = 10,
    },
}

-- ===================================================================
-- REFINED -> FINISHED PARTS RECIPES (40+ recipes)
-- ===================================================================
Recipes.RefinedToParts = {
    -- ENGINE PARTS
    {
        id = 'craft_spark_plugs', label = 'Spark Plug Set', bench = 'engine_bench',
        result = 'part_spark_plugs', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 5000,
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'raw_ceramic', amount = 4 }, { item = 'raw_electrode', amount = 2 }, { item = 'copper_wire', amount = 1 } },
        xpReward = 10,
    },
    {
        id = 'craft_air_filter', label = 'Air Filter', bench = 'engine_bench',
        result = 'part_air_filter', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'raw_filter_media', amount = 3 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 8,
    },
    {
        id = 'craft_radiator', label = 'Radiator', bench = 'engine_bench',
        result = 'part_radiator', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'aluminum_sheet', amount = 4 }, { item = 'copper_wire', amount = 2 }, { item = 'plastic_housing', amount = 2 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 25,
    },
    {
        id = 'craft_turbo', label = 'Turbocharger', bench = 'engine_bench',
        result = 'part_turbo', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 4, craftTime = 15000,
        minigame = { type = 'precision', difficulty = 4, rounds = 3 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'aluminum_sheet', amount = 2 }, { item = 'bearing_set', amount = 2 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 40,
    },
    {
        id = 'craft_engine_block', label = 'Engine Block', bench = 'engine_bench',
        result = 'part_engine_block', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 5, craftTime = 20000,
        minigame = { type = 'precision', difficulty = 5, rounds = 3 },
        ingredients = { { item = 'raw_iron', amount = 4 }, { item = 'steel_plate', amount = 4 }, { item = 'aluminum_sheet', amount = 4 }, { item = 'gasket_set', amount = 3 }, { item = 'bearing_set', amount = 2 }, { item = 'copper_wire', amount = 2 } },
        xpReward = 60,
    },
    {
        id = 'craft_oil_pump', label = 'Oil Pump', bench = 'engine_bench',
        result = 'part_oil_pump', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 2 }, { item = 'gasket_set', amount = 1 }, { item = 'bearing_set', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_water_pump', label = 'Water Pump', bench = 'engine_bench',
        result = 'part_water_pump', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 7000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'aluminum_sheet', amount = 2 }, { item = 'gasket_set', amount = 1 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 15,
    },
    {
        id = 'craft_fuel_pump', label = 'Fuel Pump', bench = 'engine_bench',
        result = 'part_fuel_pump', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 1 }, { item = 'copper_wire', amount = 2 }, { item = 'plastic_housing', amount = 1 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_exhaust', label = 'Exhaust System', bench = 'metal_bench',
        result = 'part_exhaust', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'timing', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 4 }, { item = 'aluminum_sheet', amount = 2 }, { item = 'gasket_set', amount = 2 } },
        xpReward = 25,
    },
    {
        id = 'craft_intake', label = 'Intake Manifold', bench = 'engine_bench',
        result = 'part_intake', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'aluminum_sheet', amount = 3 }, { item = 'rubber_sheet', amount = 2 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_timing_belt', label = 'Timing Belt Kit', bench = 'engine_bench',
        result = 'part_timing_belt', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'timing', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'rubber_sheet', amount = 2 }, { item = 'steel_plate', amount = 1 }, { item = 'bearing_set', amount = 1 } },
        xpReward = 12,
    },

    -- TRANSMISSION PARTS
    {
        id = 'craft_clutch', label = 'Clutch Kit', bench = 'engine_bench',
        result = 'part_clutch', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'friction_pad', amount = 4 }, { item = 'bearing_set', amount = 1 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 25,
    },
    {
        id = 'craft_transmission', label = 'Transmission', bench = 'engine_bench',
        result = 'part_transmission', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 5, craftTime = 20000,
        minigame = { type = 'precision', difficulty = 5, rounds = 3 },
        ingredients = { { item = 'steel_plate', amount = 5 }, { item = 'aluminum_sheet', amount = 3 }, { item = 'bearing_set', amount = 3 }, { item = 'gasket_set', amount = 2 } },
        xpReward = 55,
    },

    -- ELECTRICAL PARTS
    {
        id = 'craft_alternator', label = 'Alternator', bench = 'electronics_bench',
        result = 'part_alternator', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'sequence', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'copper_wire', amount = 4 }, { item = 'raw_magnet', amount = 2 }, { item = 'steel_plate', amount = 1 }, { item = 'bearing_set', amount = 1 } },
        xpReward = 22,
    },
    {
        id = 'craft_battery', label = 'Battery', bench = 'electronics_bench',
        result = 'part_battery', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'sequence', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'raw_lead', amount = 3 }, { item = 'plastic_housing', amount = 2 }, { item = 'copper_wire', amount = 1 } },
        xpReward = 12,
    },
    {
        id = 'craft_ecu', label = 'ECU Module', bench = 'electronics_bench',
        result = 'part_ecu', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 4, craftTime = 12000,
        minigame = { type = 'sequence', difficulty = 4, rounds = 3 },
        ingredients = { { item = 'circuit_assembly', amount = 2 }, { item = 'copper_wire', amount = 3 }, { item = 'plastic_housing', amount = 1 } },
        xpReward = 35,
    },
    {
        id = 'craft_wiring', label = 'Wiring Harness', bench = 'electronics_bench',
        result = 'part_wiring', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'sequence', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'wire_harness', amount = 2 }, { item = 'copper_wire', amount = 2 }, { item = 'plastic_housing', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_starter', label = 'Starter Motor', bench = 'electronics_bench',
        result = 'part_starter', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'sequence', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'copper_wire', amount = 3 }, { item = 'raw_magnet', amount = 2 }, { item = 'steel_plate', amount = 1 }, { item = 'plastic_housing', amount = 1 } },
        xpReward = 22,
    },

    -- BRAKE PARTS
    {
        id = 'craft_brake_pads', label = 'Brake Pad Set', bench = 'metal_bench',
        result = 'part_brake_pads', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 5000,
        minigame = { type = 'timing', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'friction_pad', amount = 4 }, { item = 'steel_plate', amount = 1 } },
        xpReward = 10,
    },
    {
        id = 'craft_brake_rotors', label = 'Brake Rotor Set', bench = 'metal_bench',
        result = 'part_brake_rotors', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'raw_iron', amount = 3 }, { item = 'steel_plate', amount = 2 }, { item = 'raw_steel', amount = 2 } },
        xpReward = 18,
    },
    {
        id = 'craft_brake_caliper', label = 'Brake Caliper', bench = 'metal_bench',
        result = 'part_brake_caliper', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'aluminum_sheet', amount = 3 }, { item = 'steel_plate', amount = 2 }, { item = 'rubber_sheet', amount = 1 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 25,
    },

    -- SUSPENSION PARTS
    {
        id = 'craft_shocks', label = 'Shock Absorbers', bench = 'metal_bench',
        result = 'part_shocks', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'rubber_sheet', amount = 2 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 18,
    },
    {
        id = 'craft_springs', label = 'Coil Springs', bench = 'metal_bench',
        result = 'part_springs', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 7000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'raw_steel', amount = 4 }, { item = 'steel_plate', amount = 2 } },
        xpReward = 15,
    },
    {
        id = 'craft_wheel_bearings', label = 'Wheel Bearing Kit', bench = 'metal_bench',
        result = 'part_wheel_bearings', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'bearing_set', amount = 2 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 12,
    },
    {
        id = 'craft_cv_joint', label = 'CV Joint', bench = 'metal_bench',
        result = 'part_cv_joint', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 2 }, { item = 'bearing_set', amount = 1 }, { item = 'rubber_sheet', amount = 2 } },
        xpReward = 20,
    },
    {
        id = 'craft_tie_rod', label = 'Tie Rod End', bench = 'metal_bench',
        result = 'part_tie_rod', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 5000,
        minigame = { type = 'timing', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'steel_plate', amount = 2 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 10,
    },
    {
        id = 'craft_ball_joint', label = 'Ball Joint', bench = 'metal_bench',
        result = 'part_ball_joint', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'steel_plate', amount = 2 }, { item = 'bearing_set', amount = 1 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 12,
    },
    {
        id = 'craft_control_arm', label = 'Control Arm', bench = 'metal_bench',
        result = 'part_control_arm', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'timing', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'rubber_sheet', amount = 2 }, { item = 'bearing_set', amount = 1 } },
        xpReward = 20,
    },

    -- BODY PARTS
    {
        id = 'craft_body_panel', label = 'Body Panel', bench = 'metal_bench',
        result = 'part_body_panel', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 8000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 4 }, { item = 'raw_fiberglass', amount = 2 }, { item = 'raw_sandpaper', amount = 2 } },
        xpReward = 15,
    },
    {
        id = 'craft_fender', label = 'Fender Panel', bench = 'metal_bench',
        result = 'part_fender', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 7000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'raw_paint_base', amount = 1 }, { item = 'raw_sandpaper', amount = 1 } },
        xpReward = 12,
    },
    {
        id = 'craft_windshield', label = 'Windshield', bench = 'metal_bench',
        result = 'part_windshield', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'glass_panel', amount = 2 }, { item = 'rubber_sheet', amount = 2 }, { item = 'raw_adhesive', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_headlights', label = 'Headlight Assembly', bench = 'electronics_bench',
        result = 'part_headlights', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 7000,
        minigame = { type = 'sequence', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'glass_panel', amount = 1 }, { item = 'plastic_housing', amount = 1 }, { item = 'copper_wire', amount = 2 }, { item = 'chrome_finish', amount = 1 } },
        xpReward = 15,
    },
    {
        id = 'craft_taillights', label = 'Taillight Assembly', bench = 'electronics_bench',
        result = 'part_taillights', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'sequence', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'plastic_housing', amount = 2 }, { item = 'copper_wire', amount = 1 }, { item = 'circuit_assembly', amount = 1 } },
        xpReward = 12,
    },

    -- TIRE/WHEEL PARTS
    {
        id = 'craft_tire', label = 'Standard Tire', bench = 'tire_machine',
        result = 'part_tire', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 6000,
        minigame = { type = 'timing', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'rubber_sheet', amount = 4 }, { item = 'raw_steel', amount = 1 } },
        xpReward = 10,
    },
    {
        id = 'craft_tire_performance', label = 'Performance Tire', bench = 'tire_machine',
        result = 'part_tire_performance', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'rubber_sheet', amount = 4 }, { item = 'raw_carbon', amount = 1 }, { item = 'raw_steel', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_tire_offroad', label = 'Off-Road Tire', bench = 'tire_machine',
        result = 'part_tire_offroad', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 7000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'rubber_sheet', amount = 5 }, { item = 'raw_kevlar', amount = 1 }, { item = 'raw_steel', amount = 1 } },
        xpReward = 15,
    },
}

-- ===================================================================
-- FLUID RECIPES (5 recipes — no minigame, just progress bar)
-- ===================================================================
Recipes.Fluids = {
    {
        id = 'craft_motor_oil', label = 'Motor Oil (5W-30)', bench = 'fluid_station',
        result = 'fluid_motor_oil', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = nil, -- fluid station = no minigame, just progress bar
        ingredients = { { item = 'raw_oil', amount = 3 }, { item = 'raw_additive', amount = 1 } },
        xpReward = 3,
    },
    {
        id = 'craft_coolant', label = 'Coolant', bench = 'fluid_station',
        result = 'fluid_coolant', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = nil,
        ingredients = { { item = 'raw_glycol', amount = 3 }, { item = 'raw_dye', amount = 1 } },
        xpReward = 3,
    },
    {
        id = 'craft_brake_fluid', label = 'Brake Fluid', bench = 'fluid_station',
        result = 'fluid_brake', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = nil,
        ingredients = { { item = 'raw_brake_fluid', amount = 3 } },
        xpReward = 3,
    },
    {
        id = 'craft_trans_fluid', label = 'Transmission Fluid', bench = 'fluid_station',
        result = 'fluid_trans', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = nil,
        ingredients = { { item = 'raw_oil', amount = 2 }, { item = 'raw_additive', amount = 2 } },
        xpReward = 3,
    },
    {
        id = 'craft_power_steering', label = 'Power Steering Fluid', bench = 'fluid_station',
        result = 'fluid_power_steering', resultAmount = 2,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 3000,
        minigame = nil,
        ingredients = { { item = 'raw_oil', amount = 2 }, { item = 'raw_additive', amount = 1 } },
        xpReward = 3,
    },
}

-- ===================================================================
-- TOOL RECIPES (11 recipes)
-- ===================================================================
Recipes.Tools = {
    {
        id = 'craft_wrench_set', label = 'Wrench Set', bench = 'metal_bench',
        result = 'tool_wrench_set', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 8000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 4 }, { item = 'chrome_finish', amount = 1 } },
        xpReward = 15,
    },
    {
        id = 'craft_torque_wrench', label = 'Torque Wrench', bench = 'metal_bench',
        result = 'tool_torque_wrench', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'chrome_finish', amount = 1 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_jack', label = 'Hydraulic Jack', bench = 'metal_bench',
        result = 'tool_jack', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 8000,
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 5 }, { item = 'rubber_sheet', amount = 2 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 15,
    },
    {
        id = 'craft_diagnostic', label = 'OBD2 Scanner', bench = 'electronics_bench',
        result = 'tool_diagnostic', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 4, craftTime = 12000,
        minigame = { type = 'sequence', difficulty = 4, rounds = 3 },
        ingredients = { { item = 'circuit_assembly', amount = 2 }, { item = 'plastic_housing', amount = 1 }, { item = 'copper_wire', amount = 2 } },
        xpReward = 35,
    },
    {
        id = 'craft_multimeter', label = 'Multimeter', bench = 'electronics_bench',
        result = 'tool_multimeter', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'sequence', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'circuit_assembly', amount = 1 }, { item = 'plastic_housing', amount = 1 }, { item = 'copper_wire', amount = 2 } },
        xpReward = 20,
    },
    {
        id = 'craft_welding_kit', label = 'Welding Kit', bench = 'metal_bench',
        result = 'tool_welding_kit', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'timing', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'copper_wire', amount = 3 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 22,
    },
    {
        id = 'craft_alignment_gauge', label = 'Alignment Gauge', bench = 'electronics_bench',
        result = 'tool_alignment_gauge', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'circuit_assembly', amount = 1 }, { item = 'aluminum_sheet', amount = 2 }, { item = 'glass_panel', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_compression_tester', label = 'Compression Tester', bench = 'metal_bench',
        result = 'tool_compression_tester', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'steel_plate', amount = 2 }, { item = 'rubber_sheet', amount = 2 }, { item = 'gasket_set', amount = 1 } },
        xpReward = 20,
    },
    {
        id = 'craft_brake_bleeder', label = 'Brake Bleeder', bench = 'metal_bench',
        result = 'tool_brake_bleeder', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 2, craftTime = 6000,
        minigame = { type = 'timing', difficulty = 2, rounds = 1 },
        ingredients = { { item = 'plastic_housing', amount = 2 }, { item = 'rubber_sheet', amount = 2 } },
        xpReward = 10,
    },
    {
        id = 'craft_tire_iron', label = 'Tire Iron Set', bench = 'metal_bench',
        result = 'tool_tire_machine', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 1, craftTime = 5000,
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        ingredients = { { item = 'steel_plate', amount = 3 }, { item = 'chrome_finish', amount = 1 } },
        xpReward = 8,
    },
    {
        id = 'craft_paint_gun', label = 'Paint Spray Gun', bench = 'metal_bench',
        result = 'tool_paint_gun', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 8000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'aluminum_sheet', amount = 2 }, { item = 'chrome_finish', amount = 1 }, { item = 'rubber_sheet', amount = 1 } },
        xpReward = 20,
    },
}

-- ===================================================================
-- UPGRADE KIT RECIPES (8 recipes)
-- ===================================================================
Recipes.Upgrades = {
    {
        id = 'craft_upgrade_engine', label = 'Engine Upgrade Kit', bench = 'engine_bench',
        result = 'upgrade_engine', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 5, craftTime = 20000,
        minigame = { type = 'precision', difficulty = 5, rounds = 3 },
        ingredients = { { item = 'part_engine_block', amount = 1 }, { item = 'carbon_panel', amount = 2 }, { item = 'steel_plate', amount = 4 } },
        xpReward = 60,
    },
    {
        id = 'craft_upgrade_transmission', label = 'Trans Upgrade Kit', bench = 'engine_bench',
        result = 'upgrade_transmission', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 5, craftTime = 18000,
        minigame = { type = 'precision', difficulty = 5, rounds = 3 },
        ingredients = { { item = 'part_transmission', amount = 1 }, { item = 'carbon_panel', amount = 1 }, { item = 'bearing_set', amount = 3 } },
        xpReward = 55,
    },
    {
        id = 'craft_upgrade_brakes', label = 'Brake Upgrade Kit', bench = 'metal_bench',
        result = 'upgrade_brakes', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 4, craftTime = 12000,
        minigame = { type = 'precision', difficulty = 4, rounds = 2 },
        ingredients = { { item = 'part_brake_rotors', amount = 2 }, { item = 'part_brake_caliper', amount = 2 }, { item = 'carbon_panel', amount = 1 } },
        xpReward = 40,
    },
    {
        id = 'craft_upgrade_suspension', label = 'Suspension Upgrade Kit', bench = 'metal_bench',
        result = 'upgrade_suspension', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 4, craftTime = 12000,
        minigame = { type = 'precision', difficulty = 4, rounds = 2 },
        ingredients = { { item = 'part_shocks', amount = 2 }, { item = 'part_springs', amount = 2 }, { item = 'steel_plate', amount = 3 } },
        xpReward = 40,
    },
    {
        id = 'craft_upgrade_turbo', label = 'Turbo Upgrade Kit', bench = 'engine_bench',
        result = 'upgrade_turbo', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 5, craftTime = 18000,
        minigame = { type = 'precision', difficulty = 5, rounds = 3 },
        ingredients = { { item = 'part_turbo', amount = 1 }, { item = 'raw_titanium', amount = 2 }, { item = 'carbon_panel', amount = 2 }, { item = 'aluminum_sheet', amount = 3 } },
        xpReward = 55,
    },
    {
        id = 'craft_upgrade_exhaust', label = 'Exhaust Upgrade Kit', bench = 'metal_bench',
        result = 'upgrade_exhaust', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'timing', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'part_exhaust', amount = 1 }, { item = 'raw_titanium', amount = 1 }, { item = 'steel_plate', amount = 3 }, { item = 'chrome_finish', amount = 2 } },
        xpReward = 25,
    },
    {
        id = 'craft_upgrade_intake', label = 'Intake Upgrade Kit', bench = 'engine_bench',
        result = 'upgrade_intake', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 3, craftTime = 10000,
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        ingredients = { { item = 'part_intake', amount = 1 }, { item = 'carbon_panel', amount = 1 }, { item = 'aluminum_sheet', amount = 2 } },
        xpReward = 25,
    },
    {
        id = 'craft_upgrade_ecu', label = 'ECU Tune Kit', bench = 'electronics_bench',
        result = 'upgrade_ecu', resultAmount = 1,
        skillCategory = 'xp_crafting', skillReq = 5, craftTime = 15000,
        minigame = { type = 'sequence', difficulty = 5, rounds = 3 },
        ingredients = { { item = 'part_ecu', amount = 1 }, { item = 'circuit_assembly', amount = 3 }, { item = 'copper_wire', amount = 2 } },
        xpReward = 50,
    },
}

-- ===================================================================
-- LOOKUP TABLES (built at load time)
-- ===================================================================

-- Flat lookup by recipe id
Recipes.All = {}

-- Grouped by bench id
Recipes.ByBench = {}

-- Initialize bench groups
for benchId, _ in pairs(Recipes.Benches) do
    Recipes.ByBench[benchId] = {}
end

-- Merge all recipe groups into flat + bench lookups
local function RegisterRecipes(group)
    for _, recipe in ipairs(group) do
        Recipes.All[recipe.id] = recipe
        if Recipes.ByBench[recipe.bench] then
            table.insert(Recipes.ByBench[recipe.bench], recipe)
        end
    end
end

RegisterRecipes(Recipes.RawToRefined)
RegisterRecipes(Recipes.RefinedToParts)
RegisterRecipes(Recipes.Fluids)
RegisterRecipes(Recipes.Tools)
RegisterRecipes(Recipes.Upgrades)

--- Get recipes available to a player at a specific bench
--- @param benchId string The bench type
--- @param craftingLevel number The player's crafting level (1-5)
--- @return table Filtered recipes the player can see
function Recipes.GetAvailable(benchId, craftingLevel)
    local benchRecipes = Recipes.ByBench[benchId]
    if not benchRecipes then return {} end

    local available = {}
    for _, recipe in ipairs(benchRecipes) do
        if craftingLevel >= recipe.skillReq then
            table.insert(available, recipe)
        end
    end
    return available
end
