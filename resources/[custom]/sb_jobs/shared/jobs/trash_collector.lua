-- ============================================================================
-- Trash Collector — Job Definition
-- Loaded as shared script, registers into Config.PublicJobs
--
-- Crew-based public job: 1-4 players collect trash bags freely across
-- Los Santos and throw them into a Trashmaster garbage truck.
-- Freeform discovery: a proximity thread scans nearby (~40m) for bin props,
-- spawns trash bags on the ground near them. No zones, no outlines.
-- Every 12 bags → payment. Shift continues until player returns truck.
-- ============================================================================

Config.PublicJobs['trash_collector'] = {
    id = 'trash_collector',
    label = 'Trash Collector',
    description = 'Drive around Los Santos collecting trash bags near bins and toss them into a Trashmaster. Team up with friends for crew-based collection! Earn XP to unlock higher pay.',
    icon = 'fa-trash',
    xpPerDelivery = 60,
    tipMin = 15,
    tipMax = 40,
    batchSize = 1,

    -- Vehicle spawn slots OUTSIDE the Job Center (shared with other jobs)
    vehicleSpawnSlots = {
        vector4(-532.5786, -270.9348, 35.2038, 286.1009),
        vector4(-526.5956, -268.3959, 35.2670, 292.3243),
        vector4(-521.0956, -266.1043, 35.3266, 295.4604),
        vector4(-515.6613, -263.9114, 35.4050, 295.0045),
        vector4(-510.2374, -261.6139, 35.4623, 290.8585),
        vector4(-504.8155, -259.4850, 35.5404, 292.7511),
        vector4(-499.5295, -257.2903, 35.5666, 293.6094),
        vector4(-494.1220, -255.0322, 35.6224, 290.9791),
        vector4(-488.5063, -252.8035, 35.6794, 294.4307),
    },
    vehicleSpawn = vector4(-515.6613, -263.9114, 35.4050, 295.0045),

    -- Return point to end shift (Job Center area)
    returnPoint = vector3(-515.5671, -263.9014, 35.4064),
    returnRadius = 8.0,

    -- ========================================================================
    -- TRASH COLLECTOR CONFIG
    -- ========================================================================

    -- Crew settings
    maxCrew = 4,
    inviteRadius = 10.0,

    -- Freeform discovery settings
    bagsPerPayment = 12,      -- bags before getting paid
    discoveryRadius = 40.0,   -- how far to scan for bins (within streaming range)
    maxActiveBags = 5,        -- max uncollected bags spawned at once

    -- Collection settings
    bagSpawnOffset = 1.5,     -- how far from the bin to place the bag on the ground
    throwRadius = 5.0,

    -- Trash bag prop (carried by player + spawned on ground)
    trashBagProp = 'prop_cs_rub_binbag_01',

    -- Bone to attach bag to (right hand)
    attachBone = 57005,
    -- Attach offsets: x, y, z, rotX, rotY, rotZ
    attachOffset = { x = 0.12, y = 0.0, z = -0.05, rotX = 20.0, rotY = 0.0, rotZ = 0.0 },

    -- Bin models to scan for in the world
    binModels = {
        'prop_bin_01a',
        'prop_bin_02a',
        'prop_bin_05a',
        'prop_bin_06a',
        'prop_bin_07a',
        'prop_bin_10b',
        'prop_bin_11a',
        'prop_bin_13a',
        'prop_bin_14a',
    },

    -- Pickup animation (bending down to pick up bag)
    pickupAnim = { dict = 'pickup_object', anim = 'pickup_low' },
    pickupDuration = 2000,

    -- Throw animation
    throwAnim = { dict = 'anim@heists@ornate_bank@grab_cash', anim = 'grab' },
    throwDuration = 2000,

    -- Movement clipset while carrying
    carryClipset = 'anim@heists@box_carry@',

    -- Anti-abuse
    offRouteDistance = 500.0,
    offRouteWarnTime = 30.0,
    offRouteConfiscateTime = 60.0,

    -- ========================================================================
    -- LEVEL PROGRESSION
    -- ========================================================================
    -- All levels use Trashmaster (trash) — pay-focused progression.
    -- XP per zone = 60. Pay scales up with level.
    levels = {
        { level = 1,  xpRequired = 0,      pay = 70,   vehicle = 'trash' },
        { level = 2,  xpRequired = 600,    pay = 90,   vehicle = 'trash' },
        { level = 3,  xpRequired = 1800,   pay = 110,  vehicle = 'trash' },
        { level = 4,  xpRequired = 3600,   pay = 135,  vehicle = 'trash' },
        { level = 5,  xpRequired = 6000,   pay = 160,  vehicle = 'trash' },
        { level = 6,  xpRequired = 9000,   pay = 190,  vehicle = 'trash' },
        { level = 7,  xpRequired = 12600,  pay = 225,  vehicle = 'trash' },
        { level = 8,  xpRequired = 16800,  pay = 260,  vehicle = 'trash' },
        { level = 9,  xpRequired = 21600,  pay = 300,  vehicle = 'trash' },
        { level = 10, xpRequired = 27000,  pay = 350,  vehicle = 'trash' },
    },

    -- Vehicle labels for UI
    vehicleLabels = {
        ['trash'] = 'Trashmaster',
    },

    -- Trashmaster requires car license (it's a big truck)
    requiresLicense = {
        ['trash'] = 'car_license',
    },
}
