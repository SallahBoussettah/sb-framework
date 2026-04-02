-- sb_mechanic_v2 | Configuration
-- Degradation rates, symptom thresholds, XP config, telemetry intervals

Config = {}

-- ===== TELEMETRY =====
Config.TelemetryInterval = 2000       -- ms, how often client sends telemetry to server
Config.TelemetrySampleRate = 500      -- ms, how often client samples vehicle data
Config.SymptomTickRate = 200          -- ms (5Hz), how often symptoms are applied

-- ===== DATABASE =====
Config.DBSaveInterval = 30            -- seconds, auto-save dirty conditions to DB

-- ===== DEGRADATION RATES =====
-- All rates are "per unit" (per km, per second, per event)
-- Values represent how much condition is LOST (subtracted from 100)

Config.Degradation = {
    -- Per kilometer driven
    distance = {
        oil_quality   = 0.015,
        oil_level     = 0.005,   -- oil is consumed as you drive (was missing!)
        air_filter    = 0.012,
        spark_plugs   = 0.010,
        tire_fl       = 0.008,
        tire_fr       = 0.008,
        tire_rl       = 0.007,
        tire_rr       = 0.007,
        brake_pads_front = 0.006,
        brake_pads_rear  = 0.005,
        coolant_level = 0.004,
        trans_fluid   = 0.003,
        brake_fluid   = 0.002,
        wheel_bearings = 0.003,
    },

    -- Per second at high RPM (>0.8 normalized)
    highRPM = {
        engine_block  = 0.008,
        clutch        = 0.012,
        transmission  = 0.006,
        oil_quality   = 0.010,
        oil_level     = 0.004,   -- high RPM burns more oil
        turbo         = 0.005,
        coolant_level = 0.007,
    },

    -- Per hard braking event (>30 km/h speed drop)
    hardBrake = {
        brake_pads_front = 0.25,
        brake_pads_rear  = 0.20,
        brake_rotors     = 0.10,
        brake_fluid      = 0.05,
    },

    -- Per second driving off-road
    offroad = {
        shocks_front   = 0.020,
        shocks_rear    = 0.020,
        springs        = 0.015,
        tire_fl        = 0.018,
        tire_fr        = 0.018,
        tire_rl        = 0.016,
        tire_rr        = 0.016,
        alignment      = 0.025,
        body_panels    = 0.008,
        wheel_bearings = 0.010,
    },

    -- Crash damage is now handled by native health sync (see degradation.lua)
    -- Native-synced components (engine_block, body_panels, tires, windshield) are
    -- read directly from GTA. Splash damage (radiator, headlights, etc.) is
    -- calculated from native health deltas on the client side.
}

-- ===== COLLISION SETTINGS =====
-- Inspired by T1GER and RealisticVehicleFailure
Config.Collision = {
    MinImpactSpeed = 35,         -- km/h minimum speed before collision damage registers
    CooldownMs = 4000,           -- ms between collision damage events (prevents wall-scrape spam)
    SplashAmplification = 1.2,   -- multiplier on splash damage to related components

    -- Velocity-based crash detection (works on ALL vehicles including custom cars)
    -- Detects crashes by sudden speed loss, independent of GTA's native health system
    -- This ensures custom cars with low fCollisionDamageMult still take real damage
    VelocityCrash = {
        MinSpeedDrop = 40,       -- km/h speed loss in one tick to count as a crash
        MaxDamage = 15,          -- max % condition lost on a single velocity crash (stacks with native sync)
        ScaleSpeed = 200,        -- speed (km/h) at which MaxDamage is reached
        -- This is a BACKUP system for custom cars with low fCollisionDamageMult
        -- Native health sync already handles most crash damage, so this is lower
        -- Example: 80 km/h drop → (80/200)*15 = 6% damage to engine_block + body_panels
        -- Example: 200 km/h drop → (200/200)*15 = 15% damage
    },
}

-- ===== ENGINE DEGRADATION THRESHOLDS =====
-- Once engine health drops below these thresholds, it self-degrades over time
-- Inspired by RealisticVehicleFailure's degrading/cascading failure system
Config.EngineDegradation = {
    -- Engine NO LONGER self-degrades. Damage is stable until fluids cascade into it.
    -- Only bad oil, coolant, etc. gradually worsen the engine (see Config.Cascading).

    -- Limp mode: engine never goes below this value (prevents instant death)
    safeguardFloor = 5,             -- engine_block will never drop below 5%
    -- Power in limp mode is controlled by fInitialDriveForce in symptoms.lua (15% of original)

    -- Symptom thresholds (used by symptoms.lua for power tiers)
    cascadingThreshold = 20,        -- below this: 65% power
}

-- ===== VEHICLE CLASS MULTIPLIERS =====
-- Scales ALL degradation rates (wear, collision splash, cascading) per GTA vehicle class
-- Higher = degrades faster, Lower = more durable
-- Matches GetVehicleClass() indices 0-22
Config.VehicleClassMultiplier = {
    [0]  = 1.2,   -- Compacts         (small, fragile)
    [1]  = 1.0,   -- Sedans           (baseline)
    [2]  = 0.9,   -- SUVs             (built tough)
    [3]  = 1.1,   -- Coupes           (sporty, normal wear)
    [4]  = 1.0,   -- Muscle           (heavy, standard)
    [5]  = 1.3,   -- Sports Classics  (old parts, fragile)
    [6]  = 1.2,   -- Sports           (high-stress driving)
    [7]  = 1.4,   -- Super            (extreme stress, expensive parts)
    [8]  = 0.4,   -- Motorcycles      (less body damage)
    [9]  = 0.7,   -- Off-Road         (built for abuse)
    [10] = 0.3,   -- Industrial       (tanks, basically)
    [11] = 1.0,   -- Utility
    [12] = 1.0,   -- Vans
    [13] = 1.0,   -- Cycles           (bicycles, minimal)
    [14] = 0.5,   -- Boats
    [15] = 0.5,   -- Helicopters
    [16] = 0.5,   -- Planes
    [17] = 0.8,   -- Service
    [18] = 0.6,   -- Emergency        (reinforced)
    [19] = 0.4,   -- Military         (armored)
    [20] = 1.0,   -- Commercial
    [21] = 1.0,   -- Trains
    [22] = 1.5,   -- Open Wheel       (F1 style, very fragile)
}

-- ===== CASCADING DAMAGE =====
-- When a source component falls below threshold, it damages target components per second
Config.Cascading = {
    { source = 'oil_quality',   threshold = 30, targets = { engine_block = 0.010, wheel_bearings = 0.008 } },
    { source = 'oil_level',     threshold = 25, targets = { engine_block = 0.015, turbo = 0.010 } },
    { source = 'coolant_level', threshold = 25, targets = { engine_block = 0.012, radiator = 0.008 } },
    { source = 'alternator',    threshold = 30, targets = { battery = 0.020 } },
    { source = 'trans_fluid',   threshold = 30, targets = { transmission = 0.012, clutch = 0.008 } },
    { source = 'brake_fluid',   threshold = 20, targets = { brake_pads_front = 0.005, brake_pads_rear = 0.005 } },
    { source = 'wiring',        threshold = 25, targets = { ecu = 0.008, alternator = 0.008 } },
}

-- ===== SYMPTOM THRESHOLDS =====
-- Below these values, symptoms activate
Config.Symptoms = {
    spark_plugs   = { threshold = 30, effect = 'stall' },         -- random engine stalls
    oil_level     = { threshold = 20, effect = 'power_loss' },    -- reduced power
    oil_quality   = { threshold = 25, effect = 'power_loss' },    -- reduced power (less severe)
    coolant_level = { threshold = 20, effect = 'overheat' },      -- steam + stall risk
    battery       = { threshold = 15, effect = 'hard_start' },    -- dim lights
    brake_pads_front = { threshold = 20, effect = 'weak_brakes' },
    brake_pads_rear  = { threshold = 20, effect = 'weak_brakes' },
    brake_fluid   = { threshold = 15, effect = 'severe_brake_loss' },
    shocks_front  = { threshold = 30, effect = 'body_roll' },
    shocks_rear   = { threshold = 30, effect = 'body_roll' },
    alignment     = { threshold = 30, effect = 'steering_pull' },
    clutch        = { threshold = 25, effect = 'gear_slip' },
    tire_fl       = { threshold = 20, effect = 'tire_blowout', wheel = 0 },
    tire_fr       = { threshold = 20, effect = 'tire_blowout', wheel = 1 },
    tire_rl       = { threshold = 20, effect = 'tire_blowout', wheel = 2 },
    tire_rr       = { threshold = 20, effect = 'tire_blowout', wheel = 3 },
    alternator    = { threshold = 20, effect = 'battery_drain' },
    wiring        = { threshold = 30, effect = 'electrical_flicker' },
    engine_block  = { threshold = 15, effect = 'engine_failure' },
}

-- ===== STALL SETTINGS =====
Config.Stall = {
    minInterval = 8,    -- seconds minimum between stalls
    maxInterval = 25,   -- seconds maximum between stalls
    duration = 1.5,     -- seconds engine stays off
}

-- ===== XP / SKILLS =====
Config.XP = {
    -- Level thresholds
    levels = {
        [1] = 0,
        [2] = 500,
        [3] = 1500,
        [4] = 3500,
        [5] = 7000,
    },

    -- XP categories (match DB columns)
    categories = {
        'xp_engine', 'xp_transmission', 'xp_brakes', 'xp_suspension',
        'xp_body', 'xp_electrical', 'xp_paint', 'xp_wheels',
        'xp_crafting', 'xp_diagnostics',
    },
}

-- ===== JOB =====
-- All mechanic job names that can use diagnostics, crafting, supplier, elevator, etc.
-- Add new shop jobs here as you create more MLOs (e.g. 'ls-mechanic', 'docks-mechanic')
Config.MechanicJobs = {
    ['bn-mechanic'] = true,  -- Benny's Original Motorworks
    ['mechanic']    = true,  -- Los Santos Customs
}

-- Helper: check if a job name is a mechanic job
function Config.IsMechanicJob(jobName)
    return Config.MechanicJobs[jobName] == true
end

-- ===== CRAFTING / SUPPLIER REMOVED =====
-- Crafting stations, supplier terminal, and raw material prices
-- have been moved to sb_companies (supply chain system).
-- Mechanics now order parts via sb_companies order terminal
-- and grab them from sb_companies shop dispensers.

-- ===== QUALITY TIERS =====
-- Part quality based on crafter's skill level
Config.QualityTiers = {
    [1] = { name = 'poor',      label = 'Poor',      color = '#888888', maxRestore = 70,  degradeMult = 1.3 },
    [2] = { name = 'standard',  label = 'Standard',  color = '#cccccc', maxRestore = 85,  degradeMult = 1.0 },
    [3] = { name = 'good',      label = 'Good',      color = '#2ed573', maxRestore = 95,  degradeMult = 0.9 },
    [4] = { name = 'excellent', label = 'Excellent', color = '#4a9eff', maxRestore = 100, degradeMult = 0.8 },
    [5] = { name = 'superior',  label = 'Superior',  color = '#a855f7', maxRestore = 100, degradeMult = 0.7 },
}

-- ===== TOOL DURABILITY =====
-- Default durability per tool (uses when crafted without metadata)
Config.ToolDurability = {
    tool_wrench_set      = 50,
    tool_torque_wrench   = 75,
    tool_jack            = 100,
    tool_multimeter      = 100,
    tool_welding_kit     = 30,
    tool_brake_bleeder   = 60,
    tool_alignment_gauge = 80,
}

-- ===== MOBILE REPAIR =====
-- Repairs done outside the workshop are capped at this max restore value
Config.MobileRepair = {
    maxRestore = 80,  -- cap outside workshop (80%)
}

-- ===== REPAIR COOLDOWN =====
Config.RepairCooldown = 3  -- seconds between repairs (anti-spam)

-- ===== WORKSHOP ZONE =====
-- Players must be inside this zone for workshop-only repairs
Config.WorkshopZone = {
    coords = vector3(-224.0, -1335.0, 18.5),  -- workshop floor center (lower level)
    radius = 25.0,
}

-- ===== DEBUG =====
Config.Debug = false

-- ===== MAP BLIP =====
Config.Blip = {
    enabled = true,
    coords = vector3(-205.0, -1310.0, 30.0),
    sprite = 446,       -- Benny's wrench icon
    color = 0,          -- White
    scale = 0.8,
    label = "Benny's Original Motorworks",
}

-- ===== ELEVATOR =====
Config.Elevators = {
    {
        id = 'bennys_main',

        -- Wall-mounted controls (outside elevator, on each floor)
        controlUp = vector3(-230.7967, -1336.4927, 30.9028),
        controlDown = vector3(-229.9368, -1336.5186, 18.4634),

        -- Cabin controls (inside elevator, on each floor)
        controlCabinUp = vector3(-228.4496, -1340.6349, 30.8932),
        controlCabinDown = vector3(-228.9453, -1340.9337, 18.5232),

        -- Platform positions (where the elevator prop sits)
        posUp = vector3(-224.9193, -1338.261, 31.28919),
        posDown = vector3(-224.9193, -1338.261, 18.8292),

        -- Spawn offset (prop visual offset of -1.396 on Z)
        spawnOffsetZ = -1.396,

        -- Elevation height (posUp.z - posDown.z)
        elevationHeight = 31.28919 - 18.8292,

        -- Elevator platform prop
        elevatorProp = 'patoche_elevatorb',
        elevatorHeading = 90.0,
        elevatorRotation = vector3(0.0, 0.0, 0.0),

        -- Door props and positions
        doorProp = 'patoche_elevatorb_door',
        doorHeading = 90.0,

        doorDownClosed = vector3(-229.3393, -1338.831, 17.53319),
        doorDownOpen = vector3(-229.3393, -1338.831, 20.05319),

        doorUpClosed = vector3(-229.3393, -1338.831, 30.00321),
        doorUpOpen = vector3(-229.3393, -1338.831, 32.48326),

        -- Interaction distances
        controlDistance = 1.0,
        cabinDistance = 0.7,
        spawnDistance = 30.0,

        -- Vehicle detection radius on platform
        vehicleDetectRadius = 5.0,

        -- Door animation steps (250 steps * 0.01 = 2.5 units vertical travel)
        doorSteps = 250,
        doorStepSize = 0.01,

        -- Elevator movement (step-based, 6 sub-steps per server sequence)
        moveStepSize = 0.01,
        moveStepWait = 5,
        fastMoveStepSize = 0.01,
        fastMoveStepWait = 1,

        -- Timings
        doorCloseWait = 3950,
        stepPhaseWait = 2500,
        arrivalDoorDelay = 500,
        arrivalUnlockDelay = 2500,
        autoCloseDelay = 35000,

        -- Queue system
        dwellTime = 10000,  -- ms to wait at floor before processing next queue item

        -- Default state
        startsUp = true,
    },
}
