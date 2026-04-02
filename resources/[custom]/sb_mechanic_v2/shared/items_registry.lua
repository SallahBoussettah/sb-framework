-- sb_mechanic_v2 | Phase 2: Crafting Item Registry
-- All ~110 item definitions for the crafting system
-- Used for SQL registration and reference data

CraftItems = {}

CraftItems.List = {
    -- ===================================================================
    -- RAW MATERIALS (32 items)
    -- ===================================================================

    -- Metals
    { name = 'raw_steel',           label = 'Steel Stock',              type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Raw steel stock for metalworking' },
    { name = 'raw_aluminum',        label = 'Aluminum Ingot',           type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Raw aluminum for lightweight parts' },
    { name = 'raw_copper',          label = 'Copper Rod',               type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Raw copper for electrical components' },
    { name = 'raw_iron',            label = 'Cast Iron Block',          type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Heavy cast iron for engine blocks' },
    { name = 'raw_titanium',        label = 'Titanium Bar',             type = 'material', category = 'raw', stackable = true, max_stack = 30, description = 'Premium titanium for high-end parts' },
    { name = 'raw_chrome',          label = 'Chrome Stock',             type = 'material', category = 'raw', stackable = true, max_stack = 40, description = 'Chrome plating material' },
    { name = 'raw_zinc',            label = 'Zinc Ingot',               type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Zinc for galvanizing and alloys' },
    { name = 'raw_lead',            label = 'Lead Block',               type = 'material', category = 'raw', stackable = true, max_stack = 30, description = 'Dense lead for batteries and weights' },
    { name = 'raw_bearing_steel',   label = 'Bearing Steel',            type = 'material', category = 'raw', stackable = true, max_stack = 40, description = 'Precision steel for bearing races' },

    -- Non-metals
    { name = 'raw_rubber',          label = 'Rubber Compound',          type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Raw rubber compound for tires and seals' },
    { name = 'raw_plastic',         label = 'ABS Plastic Pellets',      type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Engineering plastic for housings' },
    { name = 'raw_glass',           label = 'Glass Blank',              type = 'material', category = 'raw', stackable = true, max_stack = 30, description = 'Automotive glass sheet' },
    { name = 'raw_ceramic',         label = 'Ceramic Compound',         type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'High-temp ceramic for spark plugs' },
    { name = 'raw_carbon',          label = 'Carbon Fiber Sheet',       type = 'material', category = 'raw', stackable = true, max_stack = 20, description = 'Lightweight carbon fiber weave' },
    { name = 'raw_fiberglass',      label = 'Fiberglass Mat',           type = 'material', category = 'raw', stackable = true, max_stack = 30, description = 'Fiberglass for body repair' },
    { name = 'raw_kevlar',          label = 'Kevlar Fabric',            type = 'material', category = 'raw', stackable = true, max_stack = 20, description = 'Reinforcement fabric for brake pads' },

    -- Electrical
    { name = 'raw_electrode',       label = 'Electrode Wire',           type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Electrode material for spark plugs' },
    { name = 'raw_silicon',         label = 'Silicon Wafer',            type = 'material', category = 'raw', stackable = true, max_stack = 30, description = 'Silicon for circuit boards' },
    { name = 'raw_circuit_board',   label = 'Blank PCB',               type = 'material', category = 'raw', stackable = true, max_stack = 30, description = 'Blank printed circuit board' },
    { name = 'raw_magnet',          label = 'Rare Earth Magnet',        type = 'material', category = 'raw', stackable = true, max_stack = 40, description = 'Strong magnets for alternators' },
    { name = 'raw_solder',          label = 'Solder Wire',              type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Lead-free solder for electronics' },

    -- Chemical / Fluid base
    { name = 'raw_oil',             label = 'Base Oil',                 type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Unrefined base oil stock' },
    { name = 'raw_glycol',          label = 'Ethylene Glycol',          type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Coolant base chemical' },
    { name = 'raw_brake_fluid',     label = 'DOT4 Fluid Base',         type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Brake fluid base stock' },
    { name = 'raw_additive',        label = 'Oil Additive Pack',        type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Performance oil additives' },
    { name = 'raw_dye',             label = 'UV Dye Concentrate',       type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'UV tracking dye for fluids' },

    -- Consumable craft materials
    { name = 'raw_filter_media',    label = 'Filter Media',             type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Pleated filter paper material' },
    { name = 'raw_friction_material', label = 'Friction Material',      type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Brake pad friction compound' },
    { name = 'raw_gasket_material', label = 'Gasket Sheet',             type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Cork-rubber gasket material' },
    { name = 'raw_adhesive',        label = 'Industrial Adhesive',      type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'High-temp epoxy adhesive' },
    { name = 'raw_sandpaper',       label = 'Abrasive Paper Pack',      type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Multi-grit sandpaper sheets' },
    { name = 'raw_paint_base',      label = 'Paint Base',               type = 'material', category = 'raw', stackable = true, max_stack = 50, description = 'Automotive paint base coat' },

    -- ===================================================================
    -- REFINED MATERIALS (13 items)
    -- ===================================================================
    { name = 'steel_plate',         label = 'Steel Plate',              type = 'material', category = 'refined', stackable = true, max_stack = 30, description = 'Precision-cut steel plate' },
    { name = 'aluminum_sheet',      label = 'Aluminum Sheet',           type = 'material', category = 'refined', stackable = true, max_stack = 30, description = 'Formed aluminum sheet' },
    { name = 'copper_wire',         label = 'Copper Wiring',            type = 'material', category = 'refined', stackable = true, max_stack = 30, description = 'Insulated copper wire bundle' },
    { name = 'rubber_sheet',        label = 'Rubber Sheet',             type = 'material', category = 'refined', stackable = true, max_stack = 30, description = 'Vulcanized rubber sheet' },
    { name = 'plastic_housing',     label = 'Plastic Housing',          type = 'material', category = 'refined', stackable = true, max_stack = 30, description = 'Molded ABS plastic housing' },
    { name = 'glass_panel',         label = 'Tempered Glass',           type = 'material', category = 'refined', stackable = true, max_stack = 20, description = 'Heat-treated safety glass' },
    { name = 'carbon_panel',        label = 'Carbon Panel',             type = 'material', category = 'refined', stackable = true, max_stack = 15, description = 'Cured carbon fiber panel' },
    { name = 'friction_pad',        label = 'Friction Pad',             type = 'material', category = 'refined', stackable = true, max_stack = 30, description = 'Formed brake friction pad' },
    { name = 'gasket_set',          label = 'Gasket Set',               type = 'material', category = 'refined', stackable = true, max_stack = 20, description = 'Cut gasket set for assembly' },
    { name = 'bearing_set',         label = 'Bearing Set',              type = 'material', category = 'refined', stackable = true, max_stack = 20, description = 'Precision bearing assembly' },
    { name = 'circuit_assembly',    label = 'Circuit Assembly',         type = 'material', category = 'refined', stackable = true, max_stack = 20, description = 'Assembled PCB with components' },
    { name = 'chrome_finish',       label = 'Chrome Finish',            type = 'material', category = 'refined', stackable = true, max_stack = 20, description = 'Chrome plating finish kit' },
    { name = 'wire_harness',        label = 'Wire Harness',             type = 'material', category = 'refined', stackable = true, max_stack = 15, description = 'Pre-wired harness assembly' },

    -- ===================================================================
    -- FINISHED PARTS - ENGINE (8 items)
    -- ===================================================================
    { name = 'part_engine_block',   label = 'Engine Block',             type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Rebuilt engine block assembly' },
    { name = 'part_spark_plugs',    label = 'Spark Plug Set',           type = 'part', category = 'engine',       stackable = true,  max_stack = 5, description = 'Iridium spark plug set' },
    { name = 'part_air_filter',     label = 'Air Filter',               type = 'part', category = 'engine',       stackable = true,  max_stack = 5, description = 'High-flow air filter' },
    { name = 'part_radiator',       label = 'Radiator',                 type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Aluminum core radiator' },
    { name = 'part_turbo',          label = 'Turbocharger',             type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Ball-bearing turbocharger' },
    { name = 'part_alternator',     label = 'Alternator',               type = 'part', category = 'electrical',   stackable = false, max_stack = 1, description = 'High-output alternator' },
    { name = 'part_battery',        label = 'Battery',                  type = 'part', category = 'electrical',   stackable = false, max_stack = 1, description = 'AGM automotive battery' },
    { name = 'part_ecu',            label = 'ECU Module',               type = 'part', category = 'electrical',   stackable = false, max_stack = 1, description = 'Engine control unit' },

    -- ===================================================================
    -- FINISHED PARTS - TRANSMISSION (3 items)
    -- ===================================================================
    { name = 'part_clutch',         label = 'Clutch Kit',               type = 'part', category = 'transmission', stackable = false, max_stack = 1, description = 'Complete clutch kit' },
    { name = 'part_transmission',   label = 'Transmission',             type = 'part', category = 'transmission', stackable = false, max_stack = 1, description = 'Rebuilt transmission assembly' },
    { name = 'part_wiring',         label = 'Wiring Harness',           type = 'part', category = 'electrical',   stackable = false, max_stack = 1, description = 'Complete wiring harness' },

    -- ===================================================================
    -- FINISHED PARTS - BRAKES (3 items)
    -- ===================================================================
    { name = 'part_brake_pads',     label = 'Brake Pad Set',            type = 'part', category = 'brakes', stackable = true,  max_stack = 5, description = 'Performance brake pads' },
    { name = 'part_brake_rotors',   label = 'Brake Rotor Set',          type = 'part', category = 'brakes', stackable = true,  max_stack = 3, description = 'Drilled brake rotors' },

    -- ===================================================================
    -- FINISHED PARTS - SUSPENSION (4 items)
    -- ===================================================================
    { name = 'part_shocks',         label = 'Shock Absorbers',          type = 'part', category = 'suspension', stackable = false, max_stack = 1, description = 'Gas-charged shock absorbers' },
    { name = 'part_springs',        label = 'Coil Springs',             type = 'part', category = 'suspension', stackable = false, max_stack = 1, description = 'Progressive rate coil springs' },
    { name = 'part_wheel_bearings', label = 'Wheel Bearing Kit',        type = 'part', category = 'suspension', stackable = true,  max_stack = 5, description = 'Sealed wheel bearing kit' },
    { name = 'part_headlights',     label = 'Headlight Assembly',       type = 'part', category = 'body',       stackable = false, max_stack = 1, description = 'Projector headlight assembly' },

    -- ===================================================================
    -- FINISHED PARTS - BODY & LIGHTS (3 items)
    -- ===================================================================
    { name = 'part_body_panel',     label = 'Body Panel',               type = 'part', category = 'body', stackable = false, max_stack = 1, description = 'Stamped steel body panel' },
    { name = 'part_taillights',     label = 'Taillight Assembly',       type = 'part', category = 'body', stackable = false, max_stack = 1, description = 'LED taillight assembly' },
    { name = 'part_windshield',     label = 'Windshield',               type = 'part', category = 'body', stackable = false, max_stack = 1, description = 'Laminated safety windshield' },

    -- ===================================================================
    -- FINISHED PARTS - WHEELS & TIRES (3 items)
    -- ===================================================================
    { name = 'part_tire',           label = 'Standard Tire',            type = 'part', category = 'wheels', stackable = true, max_stack = 4, description = 'All-season standard tire' },
    { name = 'part_tire_performance', label = 'Performance Tire',       type = 'part', category = 'wheels', stackable = true, max_stack = 4, description = 'Low-profile sport tire' },
    { name = 'part_tire_offroad',   label = 'Off-Road Tire',            type = 'part', category = 'wheels', stackable = true, max_stack = 4, description = 'Mud-terrain off-road tire' },

    -- ===================================================================
    -- FINISHED PARTS - ADDITIONAL (13 items to reach 40+)
    -- ===================================================================
    { name = 'part_oil_pump',       label = 'Oil Pump',                 type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'High-pressure oil pump' },
    { name = 'part_water_pump',     label = 'Water Pump',               type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Coolant circulation pump' },
    { name = 'part_fuel_pump',      label = 'Fuel Pump',                type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Electric fuel injection pump' },
    { name = 'part_exhaust',        label = 'Exhaust System',           type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Stainless steel exhaust system' },
    { name = 'part_intake',         label = 'Intake Manifold',          type = 'part', category = 'engine',       stackable = false, max_stack = 1, description = 'Cold air intake manifold' },
    { name = 'part_timing_belt',    label = 'Timing Belt Kit',          type = 'part', category = 'engine',       stackable = true,  max_stack = 3, description = 'Timing belt with tensioner' },
    { name = 'part_starter',        label = 'Starter Motor',            type = 'part', category = 'electrical',   stackable = false, max_stack = 1, description = 'High-torque starter motor' },
    { name = 'part_cv_joint',       label = 'CV Joint',                 type = 'part', category = 'suspension',   stackable = true,  max_stack = 4, description = 'Constant velocity joint' },
    { name = 'part_tie_rod',        label = 'Tie Rod End',              type = 'part', category = 'suspension',   stackable = true,  max_stack = 4, description = 'Steering tie rod end' },
    { name = 'part_ball_joint',     label = 'Ball Joint',               type = 'part', category = 'suspension',   stackable = true,  max_stack = 4, description = 'Lower ball joint assembly' },
    { name = 'part_control_arm',    label = 'Control Arm',              type = 'part', category = 'suspension',   stackable = false, max_stack = 1, description = 'Front lower control arm' },
    { name = 'part_brake_caliper',  label = 'Brake Caliper',            type = 'part', category = 'brakes',       stackable = false, max_stack = 1, description = 'Rebuilt brake caliper' },
    { name = 'part_fender',         label = 'Fender Panel',             type = 'part', category = 'body',         stackable = false, max_stack = 1, description = 'Steel fender panel' },

    -- ===================================================================
    -- FLUIDS (5 items)
    -- ===================================================================
    { name = 'fluid_motor_oil',     label = 'Motor Oil (5W-30)',        type = 'fluid', category = 'fluids', stackable = true, max_stack = 10, description = 'Synthetic motor oil 5W-30' },
    { name = 'fluid_coolant',       label = 'Coolant',                  type = 'fluid', category = 'fluids', stackable = true, max_stack = 10, description = 'Premixed engine coolant' },
    { name = 'fluid_brake',         label = 'Brake Fluid',              type = 'fluid', category = 'fluids', stackable = true, max_stack = 10, description = 'DOT4 brake fluid' },
    { name = 'fluid_trans',         label = 'Transmission Fluid',       type = 'fluid', category = 'fluids', stackable = true, max_stack = 10, description = 'ATF transmission fluid' },
    { name = 'fluid_power_steering', label = 'Power Steering Fluid',   type = 'fluid', category = 'fluids', stackable = true, max_stack = 10, description = 'Power steering hydraulic fluid' },

    -- ===================================================================
    -- TOOLS (11 items)
    -- ===================================================================
    { name = 'tool_diagnostic',     label = 'OBD2 Scanner',             type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Handheld diagnostic scanner' },
    { name = 'tool_wrench_set',     label = 'Wrench Set',               type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Complete mechanics wrench set' },
    { name = 'tool_jack',           label = 'Hydraulic Jack',           type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Heavy-duty floor jack' },
    { name = 'tool_torque_wrench',  label = 'Torque Wrench',            type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Digital torque wrench' },
    { name = 'tool_multimeter',     label = 'Multimeter',               type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Automotive digital multimeter' },
    { name = 'tool_paint_gun',      label = 'Paint Spray Gun',          type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'HVLP paint spray gun' },
    { name = 'tool_welding_kit',    label = 'Welding Kit',              type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'MIG welding kit' },
    { name = 'tool_alignment_gauge', label = 'Alignment Gauge',         type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Laser alignment gauge' },
    { name = 'tool_compression_tester', label = 'Compression Tester',   type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Engine compression test kit' },
    { name = 'tool_brake_bleeder',  label = 'Brake Bleeder',            type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Vacuum brake bleeder kit' },
    { name = 'tool_tire_machine',   label = 'Tire Iron Set',            type = 'tool', category = 'tools', stackable = false, max_stack = 1, description = 'Heavy-duty tire iron set' },
    -- ===================================================================
    -- UPGRADE KITS (8 items)
    -- ===================================================================
    { name = 'upgrade_engine',      label = 'Engine Upgrade Kit',       type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Performance engine internals kit' },
    { name = 'upgrade_transmission', label = 'Trans Upgrade Kit',       type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Short-throw transmission kit' },
    { name = 'upgrade_brakes',      label = 'Brake Upgrade Kit',        type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Big brake kit upgrade' },
    { name = 'upgrade_suspension',  label = 'Suspension Upgrade Kit',   type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Coilover suspension upgrade' },
    { name = 'upgrade_turbo',       label = 'Turbo Upgrade Kit',        type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Twin-scroll turbo upgrade' },
    { name = 'upgrade_exhaust',     label = 'Exhaust Upgrade Kit',      type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Cat-back exhaust system' },
    { name = 'upgrade_intake',      label = 'Intake Upgrade Kit',       type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Cold air intake upgrade' },
    { name = 'upgrade_ecu',         label = 'ECU Tune Kit',             type = 'upgrade', category = 'upgrades', stackable = false, max_stack = 1, description = 'Performance ECU flash kit' },

    -- ===================================================================
    -- PHASE 1 LEGACY ITEMS (already in sb_inventory.sql, registry only)
    -- ===================================================================
    { name = 'upgrade_kit',        label = 'Upgrade Kit',              type = 'part',   category = 'upgrades', stackable = false, max_stack = 1, description = 'Generic vehicle upgrade kit' },
    { name = 'paint_supplies',     label = 'Paint Supplies',           type = 'part',   category = 'body',     stackable = true,  max_stack = 5, description = 'Automotive paint supply kit' },
    { name = 'wash_supplies',      label = 'Wash Supplies',            type = 'part',   category = 'body',     stackable = true,  max_stack = 5, description = 'Vehicle wash supply kit' },
}

-- Build lookup tables
CraftItems.ByName = {}
CraftItems.ByCategory = {}

for _, item in ipairs(CraftItems.List) do
    CraftItems.ByName[item.name] = item

    if not CraftItems.ByCategory[item.category] then
        CraftItems.ByCategory[item.category] = {}
    end
    table.insert(CraftItems.ByCategory[item.category], item)
end

-- Register all items in sb_items table (INSERT IGNORE)
-- Called on server resource start
function CraftItems.RegisterAll()
    local count = 0
    for _, item in ipairs(CraftItems.List) do
        -- DB uses 'item' type and 'mechanic' category to match sb_inventory schema
        -- Internal type/category fields are kept for crafting logic only
        MySQL.insert.await([[
            INSERT IGNORE INTO sb_items (name, label, type, category, image, stackable, max_stack, useable, shouldClose, description)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            item.name,
            item.label,
            'item',
            'mechanic',
            item.name .. '.png',
            item.stackable and 1 or 0,
            item.max_stack or 1,
            0,
            0,
            item.description or ''
        })
        count = count + 1
    end
    print(('[sb_mechanic_v2] Registered %d crafting items in sb_items'):format(count))
end
