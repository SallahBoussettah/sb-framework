-- sb_mechanic_v2 | Shared Components
-- 32-component vehicle condition model

Components = {}

-- Component definitions: name, category, default value, display label
Components.List = {
    -- ENGINE (8)
    { name = 'engine_block',  category = 'engine',       default = 100.0, label = 'Engine Block' },
    { name = 'spark_plugs',   category = 'engine',       default = 100.0, label = 'Spark Plugs' },
    { name = 'air_filter',    category = 'engine',       default = 100.0, label = 'Air Filter' },
    { name = 'oil_level',     category = 'engine',       default = 100.0, label = 'Oil Level' },
    { name = 'oil_quality',   category = 'engine',       default = 100.0, label = 'Oil Quality' },
    { name = 'coolant_level', category = 'engine',       default = 100.0, label = 'Coolant Level' },
    { name = 'radiator',      category = 'engine',       default = 100.0, label = 'Radiator' },
    { name = 'turbo',         category = 'engine',       default = 100.0, label = 'Turbo' },

    -- TRANSMISSION (3)
    { name = 'clutch',        category = 'transmission', default = 100.0, label = 'Clutch' },
    { name = 'transmission',  category = 'transmission', default = 100.0, label = 'Transmission' },
    { name = 'trans_fluid',   category = 'transmission', default = 100.0, label = 'Transmission Fluid' },

    -- BRAKES (4)
    { name = 'brake_pads_front', category = 'brakes',    default = 100.0, label = 'Front Brake Pads' },
    { name = 'brake_pads_rear',  category = 'brakes',    default = 100.0, label = 'Rear Brake Pads' },
    { name = 'brake_rotors',     category = 'brakes',    default = 100.0, label = 'Brake Rotors' },
    { name = 'brake_fluid',      category = 'brakes',    default = 100.0, label = 'Brake Fluid' },

    -- SUSPENSION (4)
    { name = 'shocks_front',    category = 'suspension', default = 100.0, label = 'Front Shocks' },
    { name = 'shocks_rear',     category = 'suspension', default = 100.0, label = 'Rear Shocks' },
    { name = 'springs',         category = 'suspension', default = 100.0, label = 'Springs' },
    { name = 'wheel_bearings',  category = 'suspension', default = 100.0, label = 'Wheel Bearings' },

    -- WHEELS/ALIGNMENT (5)
    { name = 'alignment',  category = 'wheels', default = 100.0, label = 'Alignment' },
    { name = 'tire_fl',    category = 'wheels', default = 100.0, label = 'Tire (FL)' },
    { name = 'tire_fr',    category = 'wheels', default = 100.0, label = 'Tire (FR)' },
    { name = 'tire_rl',    category = 'wheels', default = 100.0, label = 'Tire (RL)' },
    { name = 'tire_rr',    category = 'wheels', default = 100.0, label = 'Tire (RR)' },

    -- BODY (4)
    { name = 'body_panels',  category = 'body', default = 100.0, label = 'Body Panels' },
    { name = 'windshield',   category = 'body', default = 100.0, label = 'Windshield' },
    { name = 'headlights',   category = 'body', default = 100.0, label = 'Headlights' },
    { name = 'taillights',   category = 'body', default = 100.0, label = 'Taillights' },

    -- ELECTRICAL (4)
    { name = 'alternator', category = 'electrical', default = 100.0, label = 'Alternator' },
    { name = 'battery',    category = 'electrical', default = 100.0, label = 'Battery' },
    { name = 'ecu',        category = 'electrical', default = 100.0, label = 'ECU' },
    { name = 'wiring',     category = 'electrical', default = 100.0, label = 'Wiring' },
}

-- Quick lookup: name -> index
Components.Index = {}
for i, comp in ipairs(Components.List) do
    Components.Index[comp.name] = i
end

-- Get all component names as flat list
Components.Names = {}
for _, comp in ipairs(Components.List) do
    Components.Names[#Components.Names + 1] = comp.name
end

-- Get components by category
Components.ByCategory = {}
for _, comp in ipairs(Components.List) do
    if not Components.ByCategory[comp.category] then
        Components.ByCategory[comp.category] = {}
    end
    Components.ByCategory[comp.category][#Components.ByCategory[comp.category] + 1] = comp.name
end

-- Create a default condition table (all 100%)
function Components.GetDefaults()
    local t = {}
    for _, comp in ipairs(Components.List) do
        t[comp.name] = comp.default
    end
    t.total_km = 0.0
    t.last_oil_change_km = 0.0
    t.last_service_km = 0.0
    return t
end

-- Category to skill XP mapping
Components.CategoryToSkill = {
    engine       = 'xp_engine',
    transmission = 'xp_transmission',
    brakes       = 'xp_brakes',
    suspension   = 'xp_suspension',
    body         = 'xp_body',
    electrical   = 'xp_electrical',
    wheels       = 'xp_wheels',
}
