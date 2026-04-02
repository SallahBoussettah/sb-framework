Config = {}

-- Costs & Cooldowns
Config.TestCost = 500               -- Fee to take the theory exam
Config.ReissueCost = 1000           -- Fee to reissue a lost license
Config.TheoryCooldown = 300          -- 5 min cooldown on theory fail
Config.PracticalCooldown = 600       -- 10 min cooldown on practical fail
Config.TheoryValidDuration = 86400   -- Theory pass valid for 24 hours
Config.PassingScore = 7              -- Out of 10 questions
Config.MaxPenaltyPoints = 30         -- Practical fail threshold
Config.TestVehicle = 'asea'          -- Basic sedan for driving test

-- Penalty points
Config.Penalties = {
    speeding = 5,
    stopSign = 10,
    trafficLight = 10,
    damage = 3,
    missedCheckpoint = 15,
    fullStop = 10,          -- Ran through a mandatory full-stop checkpoint
    seatbelt = 10           -- Driving without seatbelt
}

-- Speed limiter (cruise control locked to road speed limit)
Config.SpeedLimiterKey = 'X'        -- Key to toggle speed limiter
Config.SeatbeltSpeedThreshold = 15  -- km/h — penalty if no seatbelt above this speed

-- Auto-detection settings (stop signs & traffic lights detected from world props)
Config.AutoDetect = {
    stopSignRadius = 20.0,          -- Scan radius for stop sign props
    trafficLightRadius = 25.0,      -- Scan radius for traffic light props
    stopRequiredTime = 1.5,         -- Seconds player must stop at a stop sign
    stopRequiredSpeed = 1.0,        -- km/h below which counts as "stopped"
    npcCheckRadius = 30.0,          -- Radius to check NPC vehicles for red light heuristic
    npcStoppedThreshold = 2,        -- Minimum stopped NPCs to consider light as red
}

-- Speed limits by road density (from GetVehicleNodeProperties)
-- GTA V road nodes have density values: lower = rural, higher = urban
Config.SpeedLimits = {
    highway = 120,      -- density 0-2 (freeways, rural highways)
    mainRoad = 80,      -- density 3-5 (main roads, boulevards)
    cityStreet = 60,    -- density 6-8 (city streets)
    residential = 40,   -- density 9+ (residential, dense urban)
}
Config.SpeedGrace = 8   -- km/h grace over limit before penalty

-- Receptionist NPC (theory exam)
-- The MLO ambient ped at this location is deleted and replaced with our own
Config.Receptionist = {
    model = 'a_m_y_business_02',
    coords = vector4(-1101.28, -1269.76, 5.21, 318.3884),
    scenario = 'PROP_HUMAN_SEAT_CHAIR',
    ambientDeleteRadius = 2.0,  -- Delete any ambient peds within this radius on spawn
    blip = {
        sprite = 408,
        color = 47,
        scale = 0.7,
        label = 'DMV - Driving School'
    }
}

-- School desks (seats where players sit to take the theory exam)
-- Each desk: vector4(x, y, z, heading) — heading = direction player faces while seated
-- Player walks up and presses E to sit. Occupied desks are detected.
Config.Desks = {
    vector4(-1099.0663, -1265.3862, 6.3006, 121.2802),  -- Desk 1
    -- PLACEHOLDER: Add more desks as you get coords
    -- vector4(0.0, 0.0, 0.0, 0.0),  -- Desk 2
    -- vector4(0.0, 0.0, 0.0, 0.0),  -- Desk 3
    -- vector4(0.0, 0.0, 0.0, 0.0),  -- Desk 4
    -- vector4(0.0, 0.0, 0.0, 0.0),  -- Desk 5
    -- vector4(0.0, 0.0, 0.0, 0.0),  -- Desk 6
}
Config.DeskInteractDistance = 1.5  -- How close to press E

-- Instructor NPC (practical test)
Config.Instructor = {
    model = 's_m_y_cop_01',
    coords = vector4(-1087.1641, -1260.5798, 5.3454, 30.2993),  -- PLACEHOLDER: Set to your DMV parking lot
}

-- Test vehicle spawn point
Config.TestVehicleSpawn = vector4(-1090.9725, -1259.4838, 5.3454, 300.1357)

-- Parking zones (Test 2 - Parking Test) — player must park at each zone in sequence
Config.ParkingZones = {
    { center = vector3(-1073.4984, -1244.7782, 5.4346), heading = 118.1445, headingTolerance = 15.0, radius = 3.0 },
    { center = vector3(-1033.8107, -1332.0242, 5.4452), heading = 255.7488, headingTolerance = 15.0, radius = 3.0 },
    { center = vector3(-1047.1047, -1332.9620, 5.4275), heading = 255.5858, headingTolerance = 15.0, radius = 3.0 },
    { center = vector3(-1173.5389, -1387.4209, 4.8743), heading = 307.8216, headingTolerance = 15.0, radius = 3.0 },
    { center = vector3(-1207.6130, -1309.0741, 4.7805), heading = 204.2646, headingTolerance = 15.0, radius = 3.0 },
    { center = vector3(-1160.0360, -1246.4285, 6.7651), heading = 288.6290, headingTolerance = 15.0, radius = 3.0 },
    { center = vector3(-1069.2739, -1250.8942, 5.7556), heading = 115.6607, headingTolerance = 15.0, radius = 3.0 },
}

-- Route checkpoints (Test 3 - Driving Test) - PLACEHOLDER coords
Config.RouteCheckpoints = {
    vector3(-1090.6760, -1259.4474, 4.6281), -- Garage can be removed cuz first checkpoint is the second one
    vector3(-1062.8834, -1265.1442, 5.3323),
    vector3(-961.6688, -1240.2837, 4.6293),
    vector3(-787.6324, -1135.3031, 9.8693),
    vector3(-635.6353, -975.8796, 20.6738),
    vector3(-634.5300, -860.2646, 24.1727),
    vector3(-629.6322, -682.7266, 30.5297),
    vector3(-624.8570, -572.6356, 34.2171),
    vector3(-631.5218, -397.1760, 34.0961),
    vector3(-776.2614, -318.9673, 36.1623),
    vector3(-888.0245, -263.7073, 39.7336),
    vector3(-962.8281, -230.9074, 37.1573),
    vector3(-1042.4720, -251.0751, 37.0954),
    vector3(-1142.6235, -276.4148, 37.0878), -- FULL STOP SIGN
    vector3(-1163.8893, -268.8167, 37.0390), -- ANOTHER FULL STOP SIGN
    vector3(-1280.0408, -328.6853, 36.0633),
    vector3(-1364.5413, -372.7196, 36.0431),
    vector3(-1446.5061, -424.6312, 35.0548),
    vector3(-1554.8136, -492.2228, 34.9209),
    vector3(-1638.3518, -561.6813, 32.7500), -- FULL STOP SIGN
    vector3(-1559.4912, -660.5532, 28.3210),
    vector3(-1461.0065, -741.8127, 23.3480),
    vector3(-1400.3231, -791.5430, 19.1791),
    vector3(-1311.3088, -887.2282, 11.3118),
    vector3(-1258.4049, -1048.7914, 7.7553),
    vector3(-1222.6259, -1135.5078, 7.1184),
    vector3(-1208.0222, -1231.4528, 6.3398), -- FULL STOP SIGN
    vector3(-1165.1290, -1321.5701, 4.3874),
    vector3(-1099.2175, -1313.7773, 4.6480),
    vector3(-1091.2261, -1259.8097, 4.6291), -- Garage Last where the player will exit
}

-- Checkpoints that REQUIRE a full stop (index into RouteCheckpoints)
-- Player must come to a complete stop before passing through, or they get a penalty
Config.FullStopCheckpoints = {14, 15, 20, 27}
Config.FullStopDetectRadius = 25.0   -- Start tracking when within this distance
Config.FullStopRequiredTime = 1.5    -- Seconds the player must be stopped
Config.FullStopRequiredSpeed = 1.0   -- km/h below which counts as "stopped"

-- Speed zones and stop signs are now auto-detected from world props
-- See Config.AutoDetect and Config.SpeedLimits above

-- Interact distance
Config.InteractDistance = 2.5

-- ============================================================================
-- THEORY EXAM QUESTIONS (25+ pool, 10 randomly selected per test)
-- correct = index of correct answer (1-4)
-- answers are stripped before sending to client
-- ============================================================================

Config.Questions = {
    {
        question = "What does a solid yellow line on your side of the road mean?",
        options = { "You may pass freely", "No passing allowed", "Road is under construction", "Speed limit ahead" },
        correct = 2
    },
    {
        question = "When approaching a stop sign, you must:",
        options = { "Slow down and proceed if clear", "Come to a complete stop", "Honk and proceed", "Flash your lights" },
        correct = 2
    },
    {
        question = "What is the speed limit in a residential area unless otherwise posted?",
        options = { "25 mph", "35 mph", "45 mph", "55 mph" },
        correct = 1
    },
    {
        question = "When should you use your turn signal?",
        options = { "Only on highways", "When you feel like it", "At least 100 feet before turning", "Only at night" },
        correct = 3
    },
    {
        question = "What does a flashing red traffic light mean?",
        options = { "Slow down", "Proceed with caution", "Stop, then proceed when safe", "Road closed ahead" },
        correct = 3
    },
    {
        question = "When driving in fog, you should use:",
        options = { "High beams", "Low beams", "Hazard lights", "No lights" },
        correct = 2
    },
    {
        question = "What is the proper following distance in normal conditions?",
        options = { "1 second", "2-3 seconds", "5 seconds", "As close as possible" },
        correct = 2
    },
    {
        question = "Who has the right of way at an uncontrolled intersection?",
        options = { "The faster vehicle", "The vehicle on the left", "The vehicle on the right", "The larger vehicle" },
        correct = 3
    },
    {
        question = "What should you do when an emergency vehicle approaches with sirens?",
        options = { "Speed up to get out of the way", "Pull over to the right and stop", "Continue driving normally", "Stop in your lane" },
        correct = 2
    },
    {
        question = "When parking uphill with a curb, your wheels should be turned:",
        options = { "Toward the curb", "Away from the curb", "Straight ahead", "It doesn't matter" },
        correct = 2
    },
    {
        question = "A broken white line on the road means:",
        options = { "No passing allowed", "Lane change or passing is permitted", "Road is ending", "Pedestrian crossing ahead" },
        correct = 2
    },
    {
        question = "What does a yield sign mean?",
        options = { "Stop completely", "Speed up", "Slow down and give way to other traffic", "Road closed" },
        correct = 3
    },
    {
        question = "When is it legal to drive in the oncoming traffic lane?",
        options = { "When passing with a broken yellow line and clear road", "Never", "Only at night", "When in a hurry" },
        correct = 1
    },
    {
        question = "What should you do if your brakes fail?",
        options = { "Turn off the engine immediately", "Pump the brakes and downshift", "Jump out of the car", "Close your eyes" },
        correct = 2
    },
    {
        question = "At what blood alcohol concentration (BAC) is it illegal to drive?",
        options = { "0.05%", "0.08%", "0.10%", "0.15%" },
        correct = 2
    },
    {
        question = "What does a green arrow traffic signal mean?",
        options = { "Go in any direction", "Turn only in the direction of the arrow", "Caution - slow down", "Pedestrians may cross" },
        correct = 2
    },
    {
        question = "When changing lanes, you should always:",
        options = { "Speed up quickly", "Check mirrors and blind spot", "Honk your horn", "Flash your lights" },
        correct = 2
    },
    {
        question = "What is the purpose of anti-lock brakes (ABS)?",
        options = { "Make the car go faster", "Prevent wheels from locking during braking", "Reduce fuel consumption", "Make the car quieter" },
        correct = 2
    },
    {
        question = "When driving at night, you should switch to low beams when:",
        options = { "You feel tired", "An oncoming vehicle is within 500 feet", "You are on a highway", "Never" },
        correct = 2
    },
    {
        question = "What should you do at a railroad crossing with flashing lights?",
        options = { "Speed up to cross quickly", "Stop and wait until lights stop flashing", "Slow down and proceed with caution", "Honk and proceed" },
        correct = 2
    },
    {
        question = "A pedestrian in a crosswalk always has:",
        options = { "No special rights", "The right of way", "To wait for cars", "To run across" },
        correct = 2
    },
    {
        question = "What is the minimum safe following distance in bad weather?",
        options = { "1 second", "2 seconds", "4-6 seconds", "Same as normal" },
        correct = 3
    },
    {
        question = "When can you legally make a U-turn?",
        options = { "Anywhere on any road", "Only where permitted and safe", "Only on highways", "Never" },
        correct = 2
    },
    {
        question = "What does a double solid yellow line mean?",
        options = { "Passing allowed in both directions", "No passing in either direction", "Lane is closing", "Speed limit change ahead" },
        correct = 2
    },
    {
        question = "Before entering a roundabout, you should:",
        options = { "Speed up to merge quickly", "Yield to traffic already in the roundabout", "Stop completely", "Honk to alert other drivers" },
        correct = 2
    },
    {
        question = "What is the first thing you should do after getting into a vehicle?",
        options = { "Start the engine", "Adjust mirrors and fasten seatbelt", "Check the radio", "Put the car in gear" },
        correct = 2
    },
    {
        question = "When driving through a school zone, you must:",
        options = { "Maintain highway speed", "Reduce speed to the posted school zone limit", "Only slow down if you see children", "Honk to alert children" },
        correct = 2
    },
    {
        question = "What does hydroplaning mean?",
        options = { "Driving on ice", "Tires lose contact with road due to water", "Engine overheating", "Brake failure" },
        correct = 2
    },
}
