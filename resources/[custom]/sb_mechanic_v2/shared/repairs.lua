-- sb_mechanic_v2 | Phase 3: Repair Definitions
-- Maps each component to required part, tool, bone, location, skill, XP, minigame, animation

Repairs = {}

-- ===== REPAIR DEFINITIONS =====
-- Each entry: component name -> { label, part, tool, bone, location, skillCategory, skillReq, xpReward, minigame, animation }
-- location: 'workshop' = must be in Config.WorkshopZone, 'any' = anywhere
-- bone: GTA bone name for sb_target (nil = global vehicle target)
-- tool: item name from CraftItems (nil = no tool needed, e.g. fluids)
-- part: item name (nil = tool-only repair, e.g. alignment)

Repairs.Definitions = {
    -- ===== ENGINE =====
    spark_plugs = {
        label = 'Replace Spark Plugs',
        part = 'part_spark_plugs',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_engine',
        skillReq = 1,
        xpReward = 15,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 8000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    air_filter = {
        label = 'Replace Air Filter',
        part = 'part_air_filter',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_engine',
        skillReq = 1,
        xpReward = 8,
        bone = 'bonnet',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    engine_block = {
        label = 'Rebuild Engine Block',
        part = 'part_engine_block',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_engine',
        skillReq = 5,
        xpReward = 80,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 3, rounds = 3 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 15000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },
    radiator = {
        label = 'Replace Radiator',
        part = 'part_radiator',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_engine',
        skillReq = 3,
        xpReward = 40,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    turbo = {
        label = 'Replace Turbocharger',
        part = 'part_turbo',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_engine',
        skillReq = 5,
        xpReward = 70,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 3, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 12000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },

    -- Oil change: fixes BOTH oil_level AND oil_quality with one fluid_motor_oil
    oil_change = {
        label = 'Change Oil',
        part = 'fluid_motor_oil',
        tool = nil,
        skillCategory = 'xp_engine',
        skillReq = 1,
        xpReward = 10,
        bone = 'bonnet',
        location = 'any',
        minigame = nil,  -- progress bar only
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 8000 },
        isFluid = true,
        -- Special: restores both oil_level and oil_quality
        components = { 'oil_level', 'oil_quality' },
        repairVisuals = { handProp = 'prop_jerrycan_01a', particles = 'fluid_pour' },
    },
    coolant_level = {
        label = 'Top Up Coolant',
        part = 'fluid_coolant',
        tool = nil,
        skillCategory = 'xp_engine',
        skillReq = 1,
        xpReward = 8,
        bone = 'bonnet',
        location = 'any',
        minigame = nil,  -- progress bar only
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        isFluid = true,
        repairVisuals = { handProp = 'prop_jerrycan_01a', particles = 'fluid_pour' },
    },

    -- ===== TRANSMISSION =====
    clutch = {
        label = 'Replace Clutch',
        part = 'part_clutch',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_transmission',
        skillReq = 3,
        xpReward = 50,
        bone = nil,  -- chassis = global vehicle target
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 12000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },
    transmission = {
        label = 'Rebuild Transmission',
        part = 'part_transmission',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_transmission',
        skillReq = 4,
        xpReward = 60,
        bone = nil,  -- chassis = global vehicle target
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 3, rounds = 3 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 15000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },
    trans_fluid = {
        label = 'Replace Transmission Fluid',
        part = 'fluid_trans',
        tool = nil,
        skillCategory = 'xp_transmission',
        skillReq = 1,
        xpReward = 12,
        bone = nil,  -- chassis = global vehicle target
        location = 'workshop',
        minigame = nil,  -- progress bar only
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 8000 },
        isFluid = true,
        repairVisuals = { handProp = 'prop_jerrycan_01a', particles = 'fluid_pour' },
    },

    -- ===== BRAKES =====
    brake_pads_front = {
        label = 'Replace Front Brake Pads',
        part = 'part_brake_pads',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_brakes',
        skillReq = 2,
        xpReward = 20,
        bone = 'wheel_lf',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 8000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },
    brake_pads_rear = {
        label = 'Replace Rear Brake Pads',
        part = 'part_brake_pads',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_brakes',
        skillReq = 2,
        xpReward = 20,
        bone = 'wheel_lr',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 8000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },
    brake_rotors = {
        label = 'Replace Brake Rotors',
        part = 'part_brake_rotors',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_brakes',
        skillReq = 3,
        xpReward = 35,
        bone = 'wheel_lf',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },
    brake_fluid = {
        label = 'Bleed Brake Fluid',
        part = 'fluid_brake',
        tool = 'tool_brake_bleeder',
        skillCategory = 'xp_brakes',
        skillReq = 1,
        xpReward = 10,
        bone = 'wheel_lf',
        location = 'workshop',
        minigame = nil,  -- progress bar only (fluid)
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 8000 },
        isFluid = true,
        repairVisuals = { handProp = 'prop_jerrycan_01a', particles = 'fluid_pour' },
    },

    -- ===== SUSPENSION =====
    shocks_front = {
        label = 'Replace Front Shocks',
        part = 'part_shocks',
        tool = 'tool_jack',
        skillCategory = 'xp_suspension',
        skillReq = 3,
        xpReward = 30,
        bone = 'wheel_lf',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    shocks_rear = {
        label = 'Replace Rear Shocks',
        part = 'part_shocks',
        tool = 'tool_jack',
        skillCategory = 'xp_suspension',
        skillReq = 3,
        xpReward = 30,
        bone = 'wheel_lr',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    springs = {
        label = 'Replace Springs',
        part = 'part_springs',
        tool = 'tool_jack',
        skillCategory = 'xp_suspension',
        skillReq = 3,
        xpReward = 35,
        bone = 'wheel_lf',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    wheel_bearings = {
        label = 'Replace Wheel Bearings',
        part = 'part_wheel_bearings',
        tool = 'tool_torque_wrench',
        skillCategory = 'xp_suspension',
        skillReq = 2,
        xpReward = 25,
        bone = 'wheel_lf',
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_wrench', particles = nil },
    },

    -- ===== ALIGNMENT (tool-only, no part) =====
    alignment = {
        label = 'Align Wheels',
        part = nil,
        tool = 'tool_alignment_gauge',
        skillCategory = 'xp_suspension',
        skillReq = 2,
        xpReward = 20,
        bone = 'wheel_lf',
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        isToolOnly = true,  -- no part consumed, restore based on skill
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },

    -- ===== WHEELS/TIRES =====
    tire_fl = {
        label = 'Replace Tire (FL)',
        part = 'part_tire',
        tool = 'tool_jack',
        skillCategory = 'xp_wheels',
        skillReq = 1,
        xpReward = 10,
        bone = 'wheel_lf',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    tire_fr = {
        label = 'Replace Tire (FR)',
        part = 'part_tire',
        tool = 'tool_jack',
        skillCategory = 'xp_wheels',
        skillReq = 1,
        xpReward = 10,
        bone = 'wheel_rf',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    tire_rl = {
        label = 'Replace Tire (RL)',
        part = 'part_tire',
        tool = 'tool_jack',
        skillCategory = 'xp_wheels',
        skillReq = 1,
        xpReward = 10,
        bone = 'wheel_lr',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    tire_rr = {
        label = 'Replace Tire (RR)',
        part = 'part_tire',
        tool = 'tool_jack',
        skillCategory = 'xp_wheels',
        skillReq = 1,
        xpReward = 10,
        bone = 'wheel_rr',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },

    -- ===== BODY =====
    body_panels = {
        label = 'Repair Body Panels',
        part = 'part_body_panel',
        tool = 'tool_welding_kit',
        skillCategory = 'xp_body',
        skillReq = 2,
        xpReward = 25,
        bone = 'door_dside_f',
        location = 'workshop',
        minigame = { type = 'timing', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_weld_torch', particles = 'welding_sparks' },
    },
    windshield = {
        label = 'Replace Windshield',
        part = 'part_windshield',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_body',
        skillReq = 3,
        xpReward = 30,
        bone = 'windscreen',
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 2, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    headlights = {
        label = 'Replace Headlights',
        part = 'part_headlights',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_body',
        skillReq = 2,
        xpReward = 15,
        bone = 'headlight_l',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },
    taillights = {
        label = 'Replace Taillights',
        part = 'part_taillights',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_body',
        skillReq = 2,
        xpReward = 15,
        bone = 'taillight_l',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = nil },
    },

    -- ===== ELECTRICAL =====
    alternator = {
        label = 'Replace Alternator',
        part = 'part_alternator',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_electrical',
        skillReq = 3,
        xpReward = 45,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'precision', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_tool_spanner01', particles = 'electrical_spark' },
    },
    battery = {
        label = 'Replace Battery',
        part = 'part_battery',
        tool = 'tool_wrench_set',
        skillCategory = 'xp_electrical',
        skillReq = 1,
        xpReward = 10,
        bone = 'bonnet',
        location = 'any',
        minigame = { type = 'timing', difficulty = 1, rounds = 1 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 6000 },
        repairVisuals = { handProp = 'prop_car_battery_01', particles = nil },
    },
    ecu = {
        label = 'Replace ECU Module',
        part = 'part_ecu',
        tool = 'tool_multimeter',
        skillCategory = 'xp_electrical',
        skillReq = 5,
        xpReward = 60,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'sequence', difficulty = 3, rounds = 3 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 12000 },
        repairVisuals = { handProp = 'prop_cs_tablet', particles = 'electrical_spark' },
    },
    wiring = {
        label = 'Rewire Vehicle',
        part = 'part_wiring',
        tool = 'tool_multimeter',
        skillCategory = 'xp_electrical',
        skillReq = 2,
        xpReward = 25,
        bone = 'bonnet',
        location = 'workshop',
        minigame = { type = 'sequence', difficulty = 2, rounds = 2 },
        animation = { dict = 'mini@repair', anim = 'fixing_a_ped', duration = 10000 },
        repairVisuals = { handProp = 'prop_cs_tablet', particles = 'electrical_spark' },
    },
}

-- ===== BUILD BONE GROUPS =====
-- Group repairs by bone for target registration (avoids duplicate targets per bone)
Repairs.BoneGroups = {}   -- bone -> { repairKey1, repairKey2, ... }
Repairs.GlobalRepairs = {} -- repairs with no bone (chassis = global vehicle target)

for key, def in pairs(Repairs.Definitions) do
    if def.bone then
        if not Repairs.BoneGroups[def.bone] then
            Repairs.BoneGroups[def.bone] = {}
        end
        table.insert(Repairs.BoneGroups[def.bone], key)
    else
        table.insert(Repairs.GlobalRepairs, key)
    end
end

-- ===== REVERSE LOOKUP: Component -> Repair Key =====
-- Most components map 1:1 (repair key = component name)
-- Oil is special: oil_level and oil_quality both map to 'oil_change'
Repairs.ComponentToRepair = {}

for key, def in pairs(Repairs.Definitions) do
    if def.components then
        -- Multi-component repair (e.g. oil_change -> oil_level, oil_quality)
        for _, comp in ipairs(def.components) do
            Repairs.ComponentToRepair[comp] = key
        end
    else
        -- 1:1 mapping (repair key = component name)
        Repairs.ComponentToRepair[key] = key
    end
end

-- ===== HELPER: Get component name(s) for a repair key =====
-- Oil change is special — restores oil_level + oil_quality
-- All others: repair key = component name
function Repairs.GetComponents(repairKey)
    local def = Repairs.Definitions[repairKey]
    if not def then return {} end
    if def.components then
        return def.components
    end
    return { repairKey }
end

-- ===== HELPER: Get repair definition for a component name =====
-- Uses reverse lookup to handle oil_level -> oil_change etc.
function Repairs.GetRepairForComponent(componentName)
    local repairKey = Repairs.ComponentToRepair[componentName]
    if not repairKey then return nil, nil end
    return Repairs.Definitions[repairKey], repairKey
end

-- ===== REVERSE LOOKUP: Part Item -> Repair Key(s) =====
-- Maps part item names to repair keys for ALT-click target registration
-- One part may be used by multiple repairs (e.g. part_brake_pads -> brake_pads_front, brake_pads_rear)
Repairs.PartToRepairs = {}

for key, def in pairs(Repairs.Definitions) do
    if def.part then
        if not Repairs.PartToRepairs[def.part] then
            Repairs.PartToRepairs[def.part] = {}
        end
        table.insert(Repairs.PartToRepairs[def.part], {
            repairKey = key,
            bone = def.bone,
            tool = def.tool,
            label = def.label,
            location = def.location,
        })
    end
    -- Tool-only repairs (alignment) — map by tool
    if def.isToolOnly and def.tool then
        local toolKey = '__tool__' .. def.tool
        if not Repairs.PartToRepairs[toolKey] then
            Repairs.PartToRepairs[toolKey] = {}
        end
        table.insert(Repairs.PartToRepairs[toolKey], {
            repairKey = key,
            bone = def.bone,
            tool = def.tool,
            label = def.label,
            location = def.location,
        })
    end
end
