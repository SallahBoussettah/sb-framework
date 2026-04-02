-- sb_mechanic_v2 | DTC Code Definitions
-- Maps OBD-II style trouble codes to vehicle components
-- Prefixes: P (powertrain), C (chassis), B (body), U (network)

DTCCodes = {}

-- Each entry: { code, component, threshold, label, severity }
-- code: OBD-II style code
-- component: matches Components.List name
-- threshold: condition % below which this code triggers
-- label: human-readable description
-- severity: 'info', 'warning', 'critical'

DTCCodes.List = {
    -- ===== POWERTRAIN (P) =====
    { code = 'P0300', component = 'spark_plugs',   threshold = 50, label = 'Random Misfire Detected',              severity = 'warning' },
    { code = 'P0301', component = 'spark_plugs',   threshold = 25, label = 'Cylinder 1 Misfire Detected',          severity = 'critical' },
    { code = 'P0171', component = 'air_filter',     threshold = 40, label = 'System Too Lean (Bank 1)',             severity = 'warning' },
    { code = 'P0172', component = 'air_filter',     threshold = 20, label = 'System Too Rich (Bank 1)',             severity = 'critical' },
    { code = 'P0217', component = 'coolant_level',  threshold = 30, label = 'Engine Overtemperature Condition',     severity = 'critical' },
    { code = 'P0118', component = 'coolant_level',  threshold = 50, label = 'Coolant Temp Sensor High',            severity = 'warning' },
    { code = 'P0520', component = 'oil_level',      threshold = 30, label = 'Oil Pressure Sensor Circuit',         severity = 'critical' },
    { code = 'P0521', component = 'oil_level',      threshold = 50, label = 'Oil Pressure Range/Performance',      severity = 'warning' },
    { code = 'P0524', component = 'oil_quality',    threshold = 35, label = 'Oil Pressure Too Low',                severity = 'warning' },
    { code = 'P0526', component = 'oil_quality',    threshold = 15, label = 'Oil Quality Critically Degraded',     severity = 'critical' },
    { code = 'P0700', component = 'transmission',   threshold = 40, label = 'Transmission Control System Fault',   severity = 'warning' },
    { code = 'P0701', component = 'transmission',   threshold = 20, label = 'Transmission Control System Range',   severity = 'critical' },
    { code = 'P0730', component = 'clutch',          threshold = 35, label = 'Incorrect Gear Ratio Detected',      severity = 'warning' },
    { code = 'P0735', component = 'clutch',          threshold = 15, label = 'Gear Ratio Malfunction',             severity = 'critical' },
    { code = 'P0562', component = 'battery',         threshold = 25, label = 'System Voltage Low',                 severity = 'warning' },
    { code = 'P0563', component = 'battery',         threshold = 10, label = 'System Voltage High (Unstable)',     severity = 'critical' },
    { code = 'P0622', component = 'alternator',      threshold = 35, label = 'Generator Field Control Circuit',    severity = 'warning' },
    { code = 'P0620', component = 'alternator',      threshold = 15, label = 'Generator Control Circuit Failure',  severity = 'critical' },
    { code = 'P0125', component = 'radiator',        threshold = 40, label = 'Insufficient Coolant for Closed Loop', severity = 'warning' },
    { code = 'P0128', component = 'radiator',        threshold = 20, label = 'Thermostat Rationality Check Failed', severity = 'critical' },
    { code = 'P0234', component = 'turbo',           threshold = 35, label = 'Turbo Overboost Condition',          severity = 'warning' },
    { code = 'P0299', component = 'turbo',           threshold = 20, label = 'Turbo Underboost Condition',         severity = 'critical' },
    { code = 'P0218', component = 'trans_fluid',     threshold = 35, label = 'Transmission Fluid Over Temperature', severity = 'warning' },
    { code = 'P0710', component = 'trans_fluid',     threshold = 20, label = 'Transmission Fluid Temp Sensor',     severity = 'critical' },
    { code = 'P0219', component = 'engine_block',    threshold = 30, label = 'Engine Overspeed Condition',         severity = 'critical' },
    { code = 'P0220', component = 'engine_block',    threshold = 50, label = 'Throttle Position Sensor Fault',     severity = 'warning' },

    -- ===== CHASSIS (C) =====
    { code = 'C0035', component = 'shocks_front',    threshold = 40, label = 'Front Suspension Position Fault',    severity = 'warning' },
    { code = 'C0036', component = 'shocks_front',    threshold = 20, label = 'Front Damper Failure',               severity = 'critical' },
    { code = 'C0040', component = 'shocks_rear',     threshold = 40, label = 'Rear Suspension Position Fault',     severity = 'warning' },
    { code = 'C0041', component = 'shocks_rear',     threshold = 20, label = 'Rear Damper Failure',                severity = 'critical' },
    { code = 'C0045', component = 'springs',          threshold = 35, label = 'Spring Rate Deviation Detected',    severity = 'warning' },
    { code = 'C0050', component = 'alignment',        threshold = 40, label = 'Steering Alignment Fault',          severity = 'warning' },
    { code = 'C0051', component = 'alignment',        threshold = 20, label = 'Steering Angle Sensor Failure',     severity = 'critical' },
    { code = 'C0110', component = 'brake_pads_front', threshold = 35, label = 'Front Brake Pad Wear Indicator',    severity = 'warning' },
    { code = 'C0111', component = 'brake_pads_front', threshold = 15, label = 'Front Brake Pad Critical Wear',     severity = 'critical' },
    { code = 'C0120', component = 'brake_pads_rear',  threshold = 35, label = 'Rear Brake Pad Wear Indicator',     severity = 'warning' },
    { code = 'C0121', component = 'brake_pads_rear',  threshold = 15, label = 'Rear Brake Pad Critical Wear',      severity = 'critical' },
    { code = 'C0130', component = 'brake_fluid',      threshold = 25, label = 'Brake Fluid Level Low',             severity = 'warning' },
    { code = 'C0131', component = 'brake_fluid',      threshold = 10, label = 'Brake Fluid Critically Low',        severity = 'critical' },
    { code = 'C0140', component = 'brake_rotors',     threshold = 35, label = 'Brake Disc Wear Detected',          severity = 'warning' },
    { code = 'C0141', component = 'brake_rotors',     threshold = 15, label = 'Brake Disc Below Minimum',          severity = 'critical' },
    { code = 'C0200', component = 'wheel_bearings',   threshold = 35, label = 'Wheel Bearing Noise Detected',      severity = 'warning' },
    { code = 'C0201', component = 'wheel_bearings',   threshold = 15, label = 'Wheel Bearing Failure Imminent',    severity = 'critical' },

    -- ===== BODY (B) =====
    { code = 'B0100', component = 'windshield',   threshold = 50, label = 'Windshield Integrity Compromised',      severity = 'warning' },
    { code = 'B0101', component = 'windshield',   threshold = 20, label = 'Windshield Structural Failure',         severity = 'critical' },
    { code = 'B0110', component = 'headlights',   threshold = 40, label = 'Headlight Malfunction',                 severity = 'warning' },
    { code = 'B0111', component = 'headlights',   threshold = 15, label = 'Headlight Circuit Open',                severity = 'critical' },
    { code = 'B0115', component = 'taillights',   threshold = 40, label = 'Taillight Malfunction',                 severity = 'warning' },
    { code = 'B0116', component = 'taillights',   threshold = 15, label = 'Taillight Circuit Open',                severity = 'critical' },
    { code = 'B0120', component = 'body_panels',  threshold = 40, label = 'Body Panel Damage Detected',            severity = 'warning' },
    { code = 'B0121', component = 'body_panels',  threshold = 15, label = 'Structural Integrity Compromised',      severity = 'critical' },

    -- ===== NETWORK/ELECTRICAL (U) =====
    { code = 'U0100', component = 'ecu',      threshold = 35, label = 'Lost Communication with ECM/PCM',           severity = 'warning' },
    { code = 'U0101', component = 'ecu',      threshold = 15, label = 'ECU Module Failure',                        severity = 'critical' },
    { code = 'U0110', component = 'wiring',   threshold = 40, label = 'Electrical System Fault Detected',          severity = 'warning' },
    { code = 'U0111', component = 'wiring',   threshold = 20, label = 'CAN Bus Communication Failure',             severity = 'critical' },

    -- ===== TIRE CODES (C-series) =====
    { code = 'C0300', component = 'tire_fl', threshold = 40, label = 'Front Left Tire Pressure Low',               severity = 'warning' },
    { code = 'C0301', component = 'tire_fl', threshold = 15, label = 'Front Left Tire Condition Critical',          severity = 'critical' },
    { code = 'C0310', component = 'tire_fr', threshold = 40, label = 'Front Right Tire Pressure Low',              severity = 'warning' },
    { code = 'C0311', component = 'tire_fr', threshold = 15, label = 'Front Right Tire Condition Critical',         severity = 'critical' },
    { code = 'C0320', component = 'tire_rl', threshold = 40, label = 'Rear Left Tire Pressure Low',                severity = 'warning' },
    { code = 'C0321', component = 'tire_rl', threshold = 15, label = 'Rear Left Tire Condition Critical',          severity = 'critical' },
    { code = 'C0330', component = 'tire_rr', threshold = 40, label = 'Rear Right Tire Pressure Low',               severity = 'warning' },
    { code = 'C0331', component = 'tire_rr', threshold = 15, label = 'Rear Right Tire Condition Critical',         severity = 'critical' },
}

-- Quick lookup: component -> list of DTCs that reference it
DTCCodes.ByComponent = {}
for _, dtc in ipairs(DTCCodes.List) do
    if not DTCCodes.ByComponent[dtc.component] then
        DTCCodes.ByComponent[dtc.component] = {}
    end
    DTCCodes.ByComponent[dtc.component][#DTCCodes.ByComponent[dtc.component] + 1] = dtc
end

-- Zone -> component mappings for physical inspection
DTCCodes.InspectionZones = {
    engine = {
        components = { 'engine_block', 'spark_plugs', 'air_filter', 'oil_level', 'oil_quality', 'coolant_level', 'radiator', 'turbo' },
        xpCategory = 'xp_engine',
    },
    exhaust = {
        components = { 'oil_quality', 'coolant_level', 'turbo', 'engine_block' },
        xpCategory = 'xp_engine',
    },
    undercarriage = {
        components = { 'oil_level', 'coolant_level', 'trans_fluid', 'brake_fluid' },
        xpCategory = 'xp_engine',
    },
    body = {
        components = { 'body_panels', 'windshield', 'headlights', 'taillights' },
        xpCategory = 'xp_body',
    },
    brakes = {
        components = { 'brake_pads_front', 'brake_pads_rear', 'brake_rotors', 'brake_fluid' },
        xpCategory = 'xp_brakes',
    },
    suspension = {
        components = { 'shocks_front', 'shocks_rear', 'springs', 'alignment', 'wheel_bearings' },
        xpCategory = 'xp_suspension',
    },
    tires = {
        components = { 'tire_fl', 'tire_fr', 'tire_rl', 'tire_rr', 'wheel_bearings' },
        xpCategory = 'xp_wheels',
    },
}

-- Vague labels for low-skill mechanics (maps component category to generic description)
DTCCodes.VagueLabels = {
    engine_block  = 'Engine issue detected',
    spark_plugs   = 'Engine issue detected',
    air_filter    = 'Engine issue detected',
    oil_level     = 'Fluid level issue',
    oil_quality   = 'Fluid quality issue',
    coolant_level = 'Cooling system issue',
    radiator      = 'Cooling system issue',
    turbo         = 'Engine performance issue',
    clutch        = 'Drivetrain issue detected',
    transmission  = 'Drivetrain issue detected',
    trans_fluid   = 'Drivetrain fluid issue',
    brake_pads_front = 'Brake system issue',
    brake_pads_rear  = 'Brake system issue',
    brake_rotors  = 'Brake system issue',
    brake_fluid   = 'Brake fluid issue',
    shocks_front  = 'Suspension issue detected',
    shocks_rear   = 'Suspension issue detected',
    springs       = 'Suspension issue detected',
    wheel_bearings = 'Wheel issue detected',
    alignment     = 'Steering issue detected',
    tire_fl       = 'Tire issue detected',
    tire_fr       = 'Tire issue detected',
    tire_rl       = 'Tire issue detected',
    tire_rr       = 'Tire issue detected',
    body_panels   = 'Body damage detected',
    windshield    = 'Glass damage detected',
    headlights    = 'Lighting issue detected',
    taillights    = 'Lighting issue detected',
    alternator    = 'Electrical issue detected',
    battery       = 'Electrical issue detected',
    ecu           = 'Computer system issue',
    wiring        = 'Electrical wiring issue',
}
