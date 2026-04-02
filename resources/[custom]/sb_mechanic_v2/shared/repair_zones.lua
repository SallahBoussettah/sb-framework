-- sb_mechanic_v2 | Repair Zones
-- Zone definitions, bone-to-zone map, approach offsets, animations, prop models

RepairZones = {}

-- ===== ZONE DEFINITIONS =====
-- Each zone defines where the player goes and what they do when repairing
RepairZones.Definitions = {
    engine = {
        label = 'Engine Bay',
        approachBone = 'bonnet',
        approachOffset = vector3(0.0, 1.0, 0.0),   -- in front of hood
        setup = {
            openHood = true,
            groundProps = {
                { model = 'prop_tool_bench02', offset = vector3(-0.8, 0.5, -0.9), rot = vector3(0.0, 0.0, 0.0) },
            },
        },
        workAnim = { dict = 'mini@repair', anim = 'fixing_a_ped', flag = 1 },
        cleanup = { closeHood = true },
        requiresLift = false,
    },

    wheel_fl = {
        label = 'Front-Left Wheel',
        approachBone = 'wheel_lf',
        approachOffset = vector3(-0.8, 0.0, 0.0),  -- left side, at wheel
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
        cleanup = {},
        requiresLift = true,  -- jack or elevator
    },

    wheel_fr = {
        label = 'Front-Right Wheel',
        approachBone = 'wheel_rf',
        approachOffset = vector3(0.8, 0.0, 0.0),   -- right side, at wheel
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
        cleanup = {},
        requiresLift = true,
    },

    wheel_rl = {
        label = 'Rear-Left Wheel',
        approachBone = 'wheel_lr',
        approachOffset = vector3(-0.8, 0.0, 0.0),
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
        cleanup = {},
        requiresLift = true,
    },

    wheel_rr = {
        label = 'Rear-Right Wheel',
        approachBone = 'wheel_rr',
        approachOffset = vector3(0.8, 0.0, 0.0),
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
        cleanup = {},
        requiresLift = true,
    },

    undercarriage = {
        label = 'Undercarriage',
        approachBone = nil,  -- use vehicle center
        approachOffset = vector3(-1.2, 0.0, 0.0),  -- side of car
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
        cleanup = {},
        requiresLift = true,  -- MUST be lifted (jack or elevator)
    },

    front = {
        label = 'Front',
        approachBone = 'bonnet',
        approachOffset = vector3(0.0, 1.5, 0.0),   -- in front of car
        setup = {
            groundProps = {
                { model = 'prop_tool_bench02', offset = vector3(-0.8, 1.0, -0.9), rot = vector3(0.0, 0.0, 0.0) },
            },
        },
        workAnim = { dict = 'mini@repair', anim = 'fixing_a_ped', flag = 1 },
        cleanup = {},
        requiresLift = false,
    },

    rear = {
        label = 'Rear',
        approachBone = 'taillight_l',
        approachOffset = vector3(0.0, -1.2, 0.0),  -- behind car
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'mini@repair', anim = 'fixing_a_ped', flag = 1 },
        cleanup = {},
        requiresLift = false,
    },

    body_left = {
        label = 'Driver-Side Body',
        approachBone = 'door_dside_f',
        approachOffset = vector3(-0.8, 0.0, 0.0),  -- left side
        setup = {
            groundProps = {},
        },
        workAnim = { dict = 'mini@repair', anim = 'fixing_a_ped', flag = 1 },
        cleanup = {},
        requiresLift = false,
    },
}

-- ===== BONE TO ZONE MAPPING =====
-- Maps GTA bone names (from Repairs.Definitions) to repair zones
RepairZones.BoneToZone = {
    bonnet       = 'engine',
    wheel_lf     = 'wheel_fl',
    wheel_rf     = 'wheel_fr',
    wheel_lr     = 'wheel_rl',
    wheel_rr     = 'wheel_rr',
    door_dside_f = 'body_left',
    windscreen   = 'front',
    headlight_l  = 'front',
    taillight_l  = 'rear',
    -- nil bone = undercarriage (handled in code)
}

-- ===== DEFAULT HAND PROP MAPPING =====
-- Used when a repair definition doesn't specify repairVisuals.handProp
RepairZones.DefaultHandProps = {
    tool_wrench_set      = 'prop_tool_spanner01',
    tool_torque_wrench   = 'prop_tool_wrench',
    tool_jack            = 'prop_tool_spanner01',
    tool_welding_kit     = 'prop_weld_torch',
    tool_multimeter      = 'prop_cs_tablet',
    tool_brake_bleeder   = 'prop_tool_spanner01',
    tool_alignment_gauge = 'prop_tool_spanner01',
}

-- ===== FLUID HAND PROP =====
RepairZones.FluidHandProp = 'prop_jerrycan_01a'

-- ===== HELPER: Get zone for a repair key =====
function RepairZones.GetZoneForRepair(repairKey)
    local def = Repairs.Definitions[repairKey]
    if not def then return nil end

    if def.bone then
        local zoneName = RepairZones.BoneToZone[def.bone]
        if zoneName then
            return RepairZones.Definitions[zoneName], zoneName
        end
    end

    -- No bone = undercarriage
    return RepairZones.Definitions['undercarriage'], 'undercarriage'
end

-- ===== HELPER: Get hand prop model for a repair =====
function RepairZones.GetHandProp(repairKey)
    local def = Repairs.Definitions[repairKey]
    if not def then return nil end

    -- Check repairVisuals first
    if def.repairVisuals and def.repairVisuals.handProp then
        return def.repairVisuals.handProp
    end

    -- Fluids get jerry can
    if def.isFluid then
        return RepairZones.FluidHandProp
    end

    -- Default based on tool
    if def.tool and RepairZones.DefaultHandProps[def.tool] then
        return RepairZones.DefaultHandProps[def.tool]
    end

    return 'prop_tool_spanner01'  -- ultimate fallback
end

-- ===== HELPER: Get particle effect key for a repair =====
function RepairZones.GetParticles(repairKey)
    local def = Repairs.Definitions[repairKey]
    if not def then return nil end

    if def.repairVisuals and def.repairVisuals.particles then
        return def.repairVisuals.particles
    end

    return nil
end
