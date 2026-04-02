Config = {}

-- ============================================================================
-- NPC / BLIP
-- ============================================================================

Config.NPCModel = 'a_m_y_business_03'
Config.InteractDistance = 2.5

Config.Location = {
    coords = vector4(-551.33, -190.58, 37.67, 205.0),
    label = 'Job Center',
    blip = {
        sprite = 408,
        color = 17,
        scale = 0.7,
        label = 'Job Center'
    }
}

-- System phone number for SMS to bosses
Config.SystemPhone = '(555) 100-0099'

-- ============================================================================
-- PUBLIC JOBS (populated by shared/jobs/*.lua files)
-- ============================================================================

Config.PublicJobs = {}

-- ============================================================================
-- ROLEPLAY JOBS (boss-managed listings)
-- ============================================================================

Config.RPJobs = {
    {
        id = 'police',
        label = 'Los Santos Police Department',
        description = 'Serve and protect the citizens of Los Santos. Respond to emergency calls, patrol the streets, investigate crimes, and maintain public order.',
        category = 'emergency',
        icon = 'fa-shield-halved',
        pay = { type = 'hourly', min = 450, max = 1200 },
    },
    {
        id = 'ambulance',
        label = 'Emergency Medical Services',
        description = 'Save lives as a first responder. Provide emergency medical care, transport patients to Pillbox Medical Center, and respond to critical incidents.',
        category = 'emergency',
        icon = 'fa-truck-medical',
        pay = { type = 'hourly', min = 400, max = 1100 },
    },
    {
        id = 'mechanic',
        label = 'Los Santos Customs',
        description = 'Repair, maintain, and upgrade vehicles at Los Santos Customs. Diagnose mechanical issues, perform engine repairs, bodywork, and custom modifications.',
        category = 'trade',
        icon = 'fa-wrench',
        pay = { type = 'hourly', min = 300, max = 800 },
    },
    {
        id = 'bn-mechanic',
        label = "Benny's Original Motorworks",
        description = "Work at Benny's, the premier custom auto shop in Los Santos. Specialize in high-end modifications, lowriders, and performance tuning.",
        category = 'trade',
        icon = 'fa-car-side',
        pay = { type = 'hourly', min = 350, max = 900 },
    },
    {
        id = 'burgershot',
        label = 'Burger Shot',
        description = 'Join the Burger Shot team! Prepare food, serve customers, and keep the restaurant running smoothly. Great entry-level position with flexible hours.',
        category = 'food',
        icon = 'fa-burger',
        pay = { type = 'hourly', min = 200, max = 500 },
    },
    {
        id = 'taxi',
        label = 'Downtown Cab Co.',
        description = 'Drive passengers across Los Santos and Blaine County. Navigate the city streets, provide excellent customer service, and earn tips.',
        category = 'transport',
        icon = 'fa-taxi',
        pay = { type = 'per job', min = 150, max = 600 },
    },
    {
        id = 'trucker',
        label = 'Trucking Co.',
        description = 'Haul cargo across San Andreas. Pick up shipments and deliver them around the map. Long routes pay more.',
        category = 'transport',
        icon = 'fa-truck',
        pay = { type = 'per delivery', min = 500, max = 2000 },
    },
    {
        id = 'realestate',
        label = 'Dynasty 8 Real Estate',
        description = 'Sell properties across Los Santos as a licensed real estate agent. Show houses, negotiate deals, and earn commission.',
        category = 'business',
        icon = 'fa-house',
        pay = { type = 'commission', min = 1000, max = 5000 },
    },
    {
        id = 'cardealer',
        label = 'Premium Deluxe Motorsport',
        description = 'Sell vehicles at the premier dealership in Los Santos. Assist customers in finding their dream car and earn commission.',
        category = 'business',
        icon = 'fa-car',
        pay = { type = 'commission', min = 800, max = 3000 },
    },
}

-- Category metadata for RP jobs in the UI
Config.Categories = {
    emergency  = { label = 'Emergency Services', color = '#ef4444' },
    trade      = { label = 'Trade & Labor',      color = '#3b82f6' },
    food       = { label = 'Food & Service',     color = '#eab308' },
    transport  = { label = 'Transport',          color = '#a855f7' },
    business   = { label = 'Business',           color = '#22c55e' },
}
