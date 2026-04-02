-- sb_mechanic_v2 | Server Diagnostics
-- OBD scanner and physical inspection callbacks
-- Skill level affects detection accuracy and detail

local SB = SBMechanic.SB

-- ===== SKILL-BASED DETECTION CONFIG =====
local DetectionRates = {
    [1] = 0.40,  -- Level 1: 40% chance to detect each DTC
    [2] = 0.60,  -- Level 2: 60%
    [3] = 0.80,  -- Level 3: 80%
    [4] = 0.90,  -- Level 4: 90%
    [5] = 1.00,  -- Level 5: 100% detection
}

-- Components where severe damage is visually obvious (any mechanic can see a flat tire)
-- If condition is at or below this threshold, bypass detection rate — always detected
local OBVIOUS_DAMAGE_THRESHOLD = 5.0
local ObviousDamageComponents = {
    tire_fl = true,
    tire_fr = true,
    tire_rl = true,
    tire_rr = true,
    windshield = true,
    body_panels = true,
    headlights = true,
    taillights = true,
}

-- ===== ANTI-EXPLOIT: COOLDOWNS =====
-- Per-player cooldowns keyed by citizenid
-- Scan: 60s per plate, Inspect: 30s per plate+zone
local SCAN_COOLDOWN = 60        -- seconds between XP-earning scans on same plate
local INSPECT_COOLDOWN = 30     -- seconds between XP-earning inspections on same plate+zone
local ScanCooldowns = {}        -- citizenid -> { plate -> timestamp }
local InspectCooldowns = {}     -- citizenid -> { plate:zone -> timestamp }

local function CanEarnScanXP(citizenid, plate)
    local now = os.time()
    if not ScanCooldowns[citizenid] then ScanCooldowns[citizenid] = {} end
    local last = ScanCooldowns[citizenid][plate]
    if last and (now - last) < SCAN_COOLDOWN then
        return false
    end
    ScanCooldowns[citizenid][plate] = now
    return true
end

local function CanEarnInspectXP(citizenid, plate, zone)
    local now = os.time()
    local key = plate .. ':' .. zone
    if not InspectCooldowns[citizenid] then InspectCooldowns[citizenid] = {} end
    local last = InspectCooldowns[citizenid][key]
    if last and (now - last) < INSPECT_COOLDOWN then
        return false
    end
    InspectCooldowns[citizenid][key] = now
    return true
end

-- Cleanup cooldowns when player drops
AddEventHandler('playerDropped', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    if citizenid then
        ScanCooldowns[citizenid] = nil
        InspectCooldowns[citizenid] = nil
    end
end)

-- ===== OBD SCANNER CALLBACK =====
-- Returns array of DTC results based on vehicle condition and mechanic skill
SB.Functions.CreateCallback('sb_mechanic_v2:scanVehicle', function(source, cb, plate)
    local src = source
    if not plate or type(plate) ~= 'string' or #plate == 0 then return cb({}) end

    -- Verify player is a mechanic
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb({}) end
    local job = Player.PlayerData.job
    if not job or not Config.IsMechanicJob(job.name) then return cb({}) end

    local citizenid = Player.PlayerData.citizenid

    -- Load condition and skills
    local cond = LoadCondition(plate)
    if not cond then return cb({}) end

    local skills = LoadSkills(citizenid)
    local diagLevel = GetLevel(citizenid, 'xp_diagnostics')
    local detectionRate = DetectionRates[diagLevel] or 0.40

    -- Debug: log scan parameters and key component values
    print(('[sb_mechanic_v2] scanVehicle plate=%s diagLevel=%d detectionRate=%.0f%%'):format(plate, diagLevel, detectionRate * 100))
    local debugComps = { 'tire_fl', 'tire_fr', 'tire_rl', 'tire_rr', 'windshield', 'body_panels', 'engine_block' }
    for _, comp in ipairs(debugComps) do
        if cond[comp] then
            print(('[sb_mechanic_v2]   %s = %.1f'):format(comp, cond[comp]))
        end
    end

    -- Scan all DTC codes against condition
    local results = {}
    for _, dtc in ipairs(DTCCodes.List) do
        local compValue = cond[dtc.component]
        if compValue and compValue < dtc.threshold then
            -- Check if damage is visually obvious (e.g. flat tire, smashed windshield)
            -- Any mechanic can see these with their eyes — bypass detection rate
            local isObvious = ObviousDamageComponents[dtc.component] and compValue <= OBVIOUS_DAMAGE_THRESHOLD
            local detected = isObvious or (math.random() <= detectionRate)
            if detected then
                local entry = {
                    code = dtc.code,
                    component = dtc.component,
                    severity = dtc.severity,
                }

                if diagLevel >= 3 then
                    entry.label = dtc.label
                else
                    entry.label = DTCCodes.VagueLabels[dtc.component] or 'Issue detected'
                end

                if diagLevel >= 4 then
                    entry.showSeverity = true
                else
                    entry.showSeverity = false
                    entry.severity = nil
                end

                if diagLevel >= 5 then
                    entry.conditionPct = math.floor(compValue + 0.5)
                end

                -- Required parts/tools from Repairs.Definitions (skill-gated)
                -- Uses reverse lookup to handle components like oil_level -> oil_change
                local repairDef = Repairs and Repairs.GetRepairForComponent and Repairs.GetRepairForComponent(dtc.component)
                if repairDef then
                    -- Level 1+: show what part is needed
                    if repairDef.part then
                        local partItem = CraftItems and CraftItems.ByName and CraftItems.ByName[repairDef.part]
                        entry.requiredPart = partItem and partItem.label or repairDef.part
                        entry.requiredPartName = repairDef.part
                    end
                    -- Level 2+: show what tool is needed
                    if diagLevel >= 2 then
                        if repairDef.tool then
                            local toolItem = CraftItems and CraftItems.ByName and CraftItems.ByName[repairDef.tool]
                            entry.requiredTool = toolItem and toolItem.label or repairDef.tool
                            entry.requiredToolName = repairDef.tool
                        end
                    end
                    -- Level 3+: show skill requirement and location
                    if diagLevel >= 3 then
                        entry.repairSkillReq = repairDef.skillReq
                        entry.repairLocation = repairDef.location
                    end
                end

                results[#results + 1] = entry
            end
        end
    end

    -- Award XP only if cooldown has passed for this plate
    local xpGain = 0
    if CanEarnScanXP(citizenid, plate) then
        xpGain = math.random(15, 25)
        AddXP(citizenid, 'xp_diagnostics', xpGain)
    end

    -- Update successful diagnoses counter
    if skills then
        skills.successful_diagnoses = (skills.successful_diagnoses or 0) + 1
    end

    cb(results, diagLevel, xpGain)
end)

-- ===== PHYSICAL INSPECTION CALLBACK =====
-- Returns descriptive text array for a specific inspection zone
SB.Functions.CreateCallback('sb_mechanic_v2:inspectZone', function(source, cb, plate, zone)
    local src = source
    if not plate or not zone then return cb({}) end
    if type(plate) ~= 'string' or #plate == 0 then return cb({}) end

    -- Verify player is a mechanic
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb({}) end
    local job = Player.PlayerData.job
    if not job or not Config.IsMechanicJob(job.name) then return cb({}) end

    local citizenid = Player.PlayerData.citizenid

    -- Validate zone
    local zoneData = DTCCodes.InspectionZones[zone]
    if not zoneData then return cb({}) end

    -- Load condition
    local cond = LoadCondition(plate)
    if not cond then return cb({}) end

    -- Determine skill level for this zone's category
    local skillCategory = zoneData.xpCategory or 'xp_diagnostics'
    local level = GetLevel(citizenid, skillCategory)

    -- Generate inspection text for each component in this zone
    local texts = {}
    for _, compName in ipairs(zoneData.components) do
        local value = cond[compName]
        if value then
            local text = GenerateInspectionText(compName, value, level, zone)
            if text then
                texts[#texts + 1] = text
            end
        end
    end

    -- If nothing notable, add an all-clear message
    if #texts == 0 then
        if level >= 3 then
            texts[#texts + 1] = 'All components in this area look good.'
        else
            texts[#texts + 1] = 'Nothing obvious stands out.'
        end
    end

    -- Award XP only if cooldown has passed for this plate+zone
    local xpGain = 0
    if CanEarnInspectXP(citizenid, plate, zone) then
        xpGain = math.random(5, 10)
        AddXP(citizenid, skillCategory, xpGain)
    end

    cb(texts, xpGain)
end)

-- ===== INSPECTION TEXT GENERATION =====
-- Generates descriptive text based on component condition and mechanic skill level
function GenerateInspectionText(component, value, level, zone)
    -- Don't report components that are fine
    if value >= 80 then return nil end

    -- Component-specific descriptions at different skill levels
    local descriptions = GetComponentDescriptions(component, value, level)
    if not descriptions then return nil end

    return descriptions
end

-- ===== COMPONENT DESCRIPTION LOOKUP =====
function GetComponentDescriptions(component, value, level)
    -- Determine condition tier
    local tier
    if value >= 60 then tier = 'mild'
    elseif value >= 35 then tier = 'moderate'
    elseif value >= 15 then tier = 'severe'
    else tier = 'critical' end

    -- Low skill (1-2): vague sensory descriptions
    -- Mid skill (3): specific component + general state
    -- High skill (4-5): component + exact assessment

    local desc = ComponentTexts[component]
    if not desc then return nil end

    local tierText = desc[tier]
    if not tierText then return nil end

    if level <= 2 then
        return tierText.low
    elseif level == 3 then
        return tierText.mid
    else
        -- Level 4-5: precise text
        local text = tierText.high
        if level >= 5 then
            text = text .. string.format(' (~%d%%)', math.floor(value + 0.5))
        end
        return text
    end
end

-- ===== COMPONENT INSPECTION TEXTS =====
-- Each component has 4 tiers (mild/moderate/severe/critical) x 3 skill levels (low/mid/high)
ComponentTexts = {
    engine_block = {
        mild     = { low = 'The engine sounds a bit rough.',           mid = 'Engine has minor wear.',              high = 'Engine block showing early wear patterns.' },
        moderate = { low = 'The engine is running rough.',              mid = 'Engine has significant wear.',        high = 'Engine block has notable scoring and wear.' },
        severe   = { low = 'The engine sounds terrible.',              mid = 'Engine is in poor condition.',         high = 'Engine block has severe scoring, needs rebuild.' },
        critical = { low = 'The engine is barely running.',            mid = 'Engine is failing.',                   high = 'Engine block critically damaged, imminent failure.' },
    },
    spark_plugs = {
        mild     = { low = 'Something sounds off in the engine.',      mid = 'Spark plugs look worn.',              high = 'Spark plugs show electrode erosion.' },
        moderate = { low = 'Engine misfires sometimes.',               mid = 'Spark plugs need replacing.',         high = 'Spark plugs heavily fouled, causing misfires.' },
        severe   = { low = 'Engine misfires a lot.',                   mid = 'Spark plugs are shot.',               high = 'Spark plugs severely degraded, carbon buildup.' },
        critical = { low = 'Engine barely fires.',                     mid = 'Spark plugs are done.',               high = 'Spark plugs non-functional, replace immediately.' },
    },
    air_filter = {
        mild     = { low = 'Airflow feels a bit restricted.',          mid = 'Air filter is getting dirty.',        high = 'Air filter has moderate particulate buildup.' },
        moderate = { low = 'Engine seems starved for air.',            mid = 'Air filter needs replacing.',          high = 'Air filter heavily clogged, restricting airflow.' },
        severe   = { low = 'Definitely an airflow problem.',           mid = 'Air filter is very clogged.',         high = 'Air filter severely restricted, affecting mixture.' },
        critical = { low = 'Something is really wrong with intake.',   mid = 'Air filter is completely blocked.',   high = 'Air filter completely blocked, engine running rich.' },
    },
    oil_level = {
        mild     = { low = 'Something might be leaking.',              mid = 'Oil level is a bit low.',             high = 'Oil level below optimal, top-up recommended.' },
        moderate = { low = 'There is a fluid leak somewhere.',         mid = 'Oil level is getting low.',           high = 'Oil level significantly low, top-up needed.' },
        severe   = { low = 'Major fluid leak detected.',               mid = 'Oil level is dangerously low.',       high = 'Oil level critically low, engine damage risk.' },
        critical = { low = 'Fluid levels are very bad.',               mid = 'Almost no oil left.',                  high = 'Oil level near empty, immediate top-up required.' },
    },
    oil_quality = {
        mild     = { low = 'The oil looks a bit dark.',                mid = 'Oil is getting old.',                  high = 'Oil quality degraded, change interval approaching.' },
        moderate = { low = 'Oil is looking bad.',                      mid = 'Oil needs changing.',                  high = 'Oil heavily contaminated, change overdue.' },
        severe   = { low = 'Oil is really dirty.',                     mid = 'Oil is breaking down.',                high = 'Oil viscosity breakdown, bearing damage risk.' },
        critical = { low = 'Oil is basically sludge.',                 mid = 'Oil is destroyed.',                    high = 'Oil completely degraded, sludge formation present.' },
    },
    coolant_level = {
        mild     = { low = 'Something feels warm.',                    mid = 'Coolant is a bit low.',                high = 'Coolant level below minimum, top-up needed.' },
        moderate = { low = 'Engine is running hot.',                   mid = 'Coolant level is low.',                high = 'Coolant significantly low, overheating risk.' },
        severe   = { low = 'Engine is overheating.',                   mid = 'Coolant level critical.',              high = 'Coolant critically low, head gasket at risk.' },
        critical = { low = 'Engine is dangerously hot.',               mid = 'Almost no coolant.',                   high = 'Coolant near empty, engine will overheat.' },
    },
    radiator = {
        mild     = { low = 'Cooling seems a bit off.',                 mid = 'Radiator has minor damage.',           high = 'Radiator fins bent, reduced cooling efficiency.' },
        moderate = { low = 'Cooling system not working well.',         mid = 'Radiator is damaged.',                 high = 'Radiator has significant damage, leaking slowly.' },
        severe   = { low = 'Definitely a cooling problem.',            mid = 'Radiator is badly damaged.',           high = 'Radiator core compromised, major leak.' },
        critical = { low = 'Cooling is completely broken.',            mid = 'Radiator is destroyed.',               high = 'Radiator non-functional, replace immediately.' },
    },
    turbo = {
        mild     = { low = 'Sounds a bit whiny up top.',               mid = 'Turbo sounds off.',                    high = 'Turbo showing early shaft play.' },
        moderate = { low = 'Strange whistling from engine.',           mid = 'Turbo is wearing out.',                high = 'Turbo has excessive shaft play, oil seeping.' },
        severe   = { low = 'Loud whining from engine bay.',            mid = 'Turbo is failing.',                    high = 'Turbo seal failure, oil burning through exhaust.' },
        critical = { low = 'Something is very wrong in the engine.',   mid = 'Turbo is destroyed.',                  high = 'Turbo catastrophic failure, replace immediately.' },
    },
    clutch = {
        mild     = { low = 'Shifting feels a bit off.',                mid = 'Clutch is wearing.',                   high = 'Clutch plate showing wear, engagement point shifting.' },
        moderate = { low = 'Gears are hard to engage.',                mid = 'Clutch needs replacing.',              high = 'Clutch worn significantly, slipping under load.' },
        severe   = { low = 'Transmission slips a lot.',                mid = 'Clutch is almost gone.',               high = 'Clutch severely worn, slipping in all gears.' },
        critical = { low = 'Can barely get into gear.',                mid = 'Clutch is done.',                      high = 'Clutch plate glazed, no grip remaining.' },
    },
    transmission = {
        mild     = { low = 'Something clunks when shifting.',          mid = 'Transmission has minor issues.',       high = 'Transmission shows early synchro wear.' },
        moderate = { low = 'Shifting is getting rough.',               mid = 'Transmission is wearing.',             high = 'Transmission synchros worn, grinding on shifts.' },
        severe   = { low = 'Transmission is really struggling.',       mid = 'Transmission is failing.',             high = 'Transmission gear teeth worn, jumping out of gear.' },
        critical = { low = 'Transmission barely works.',               mid = 'Transmission is shot.',                high = 'Transmission internal failure, rebuild required.' },
    },
    trans_fluid = {
        mild     = { low = 'Something smells burnt.',                  mid = 'Transmission fluid is dark.',          high = 'Trans fluid discolored, change recommended.' },
        moderate = { low = 'Burnt smell from drivetrain.',             mid = 'Trans fluid needs changing.',          high = 'Trans fluid burnt, metal particles visible.' },
        severe   = { low = 'Strong burning smell.',                    mid = 'Trans fluid is shot.',                 high = 'Trans fluid severely degraded, no lubrication.' },
        critical = { low = 'Terrible smell from underneath.',          mid = 'No usable trans fluid.',               high = 'Trans fluid destroyed, gear damage occurring.' },
    },
    brake_pads_front = {
        mild     = { low = 'Brakes sound a bit off.',                  mid = 'Front brake pads wearing.',            high = 'Front brake pads at 60% life remaining.' },
        moderate = { low = 'Brakes are squealing.',                    mid = 'Front pads need replacing.',           high = 'Front brake pads worn past service limit.' },
        severe   = { low = 'Brakes are grinding.',                     mid = 'Front pads are almost gone.',          high = 'Front brake pads metal-on-metal, rotor damage.' },
        critical = { low = 'Brakes barely work.',                      mid = 'No front brake pads left.',            high = 'Front brake pads completely gone, dangerous.' },
    },
    brake_pads_rear = {
        mild     = { low = 'Brakes sound a bit off.',                  mid = 'Rear brake pads wearing.',             high = 'Rear brake pads at 60% life remaining.' },
        moderate = { low = 'Brakes are squealing.',                    mid = 'Rear pads need replacing.',            high = 'Rear brake pads worn past service limit.' },
        severe   = { low = 'Brakes are grinding in the back.',         mid = 'Rear pads are almost gone.',           high = 'Rear brake pads metal-on-metal, rotor damage.' },
        critical = { low = 'Rear brakes barely work.',                 mid = 'No rear brake pads left.',             high = 'Rear brake pads completely gone, dangerous.' },
    },
    brake_rotors = {
        mild     = { low = 'Brakes feel a bit rough.',                 mid = 'Brake rotors have minor wear.',        high = 'Brake rotors showing scoring marks.' },
        moderate = { low = 'Brakes vibrate when stopping.',            mid = 'Brake rotors are worn.',               high = 'Brake rotors warped, causing vibration.' },
        severe   = { low = 'Brakes vibrate badly.',                    mid = 'Brake rotors are badly worn.',         high = 'Brake rotors below minimum thickness.' },
        critical = { low = 'Stopping is dangerous.',                   mid = 'Brake rotors are destroyed.',          high = 'Brake rotors cracked, replace immediately.' },
    },
    brake_fluid = {
        mild     = { low = 'Pedal feels a bit soft.',                  mid = 'Brake fluid level low.',               high = 'Brake fluid below minimum, air ingress risk.' },
        moderate = { low = 'Brake pedal is spongy.',                   mid = 'Brake fluid needs topping.',           high = 'Brake fluid significantly low, pedal spongy.' },
        severe   = { low = 'Brake pedal goes to floor.',               mid = 'Brake fluid critically low.',          high = 'Brake fluid near empty, system has air.' },
        critical = { low = 'Brakes are failing.',                      mid = 'Almost no brake fluid.',               high = 'Brake fluid depleted, brake failure imminent.' },
    },
    shocks_front = {
        mild     = { low = 'Front end feels bouncy.',                  mid = 'Front shocks wearing.',                high = 'Front shock absorbers losing damping.' },
        moderate = { low = 'Front end bounces a lot.',                 mid = 'Front shocks need replacing.',         high = 'Front shocks leaking, poor damping.' },
        severe   = { low = 'Front end is all over the place.',         mid = 'Front shocks are shot.',               high = 'Front shocks blown, no damping control.' },
        critical = { low = 'Front end is completely unstable.',        mid = 'Front shocks destroyed.',              high = 'Front shocks completely failed, dangerous.' },
    },
    shocks_rear = {
        mild     = { low = 'Rear feels bouncy.',                       mid = 'Rear shocks wearing.',                 high = 'Rear shock absorbers losing damping.' },
        moderate = { low = 'Back end bounces a lot.',                  mid = 'Rear shocks need replacing.',          high = 'Rear shocks leaking, poor damping.' },
        severe   = { low = 'Rear end is all over the place.',          mid = 'Rear shocks are shot.',                high = 'Rear shocks blown, no damping control.' },
        critical = { low = 'Rear end is completely unstable.',         mid = 'Rear shocks destroyed.',               high = 'Rear shocks completely failed, dangerous.' },
    },
    springs = {
        mild     = { low = 'Ride feels a bit stiff.',                  mid = 'Springs showing wear.',                high = 'Springs losing tension, ride height dropping.' },
        moderate = { low = 'Ride is getting rough.',                   mid = 'Springs need attention.',               high = 'Springs sagging noticeably, affecting handling.' },
        severe   = { low = 'Something is wrong with the ride.',        mid = 'Springs are failing.',                  high = 'Springs critically weakened, bottoming out.' },
        critical = { low = 'Ride is terrible.',                        mid = 'Springs are broken.',                   high = 'Spring failure, vehicle sitting unevenly.' },
    },
    alignment = {
        mild     = { low = 'Steering feels a bit off.',                mid = 'Alignment is slightly off.',            high = 'Alignment out by minor amount, tire wear uneven.' },
        moderate = { low = 'Car pulls to one side.',                   mid = 'Alignment is off.',                     high = 'Alignment significantly off, accelerated tire wear.' },
        severe   = { low = 'Car pulls hard to one side.',              mid = 'Alignment is way off.',                 high = 'Alignment severely off, dangerous at speed.' },
        critical = { low = 'Steering is dangerous.',                   mid = 'Alignment is completely off.',          high = 'Alignment catastrophically off, unsafe to drive.' },
    },
    wheel_bearings = {
        mild     = { low = 'Something hums at speed.',                 mid = 'Wheel bearings have some noise.',       high = 'Wheel bearings showing early wear, faint hum.' },
        moderate = { low = 'Humming noise from wheels.',               mid = 'Wheel bearings need checking.',         high = 'Wheel bearings worn, noticeable vibration.' },
        severe   = { low = 'Loud grinding from wheels.',               mid = 'Wheel bearings are going.',             high = 'Wheel bearings severely worn, loud grinding.' },
        critical = { low = 'Wheels feel like they could fall off.',     mid = 'Wheel bearings are shot.',              high = 'Wheel bearing failure imminent, replace now.' },
    },
    body_panels = {
        mild     = { low = 'Some dents visible.',                      mid = 'Body panels have minor dents.',         high = 'Body panels show cosmetic dents and scratches.' },
        moderate = { low = 'Body is pretty beat up.',                  mid = 'Body panels need repair.',              high = 'Body panels have structural dents, gaps visible.' },
        severe   = { low = 'Body is badly damaged.',                   mid = 'Body panels are crushed.',              high = 'Body panels severely compromised, rust forming.' },
        critical = { low = 'Body is destroyed.',                       mid = 'Body panels are wrecked.',              high = 'Body panels structurally failed, safety risk.' },
    },
    windshield = {
        mild     = { low = 'Glass has some chips.',                    mid = 'Windshield has chips.',                  high = 'Windshield has stress cracks forming from chips.' },
        moderate = { low = 'Windshield is cracked.',                   mid = 'Windshield has cracks.',                 high = 'Windshield cracked across field of vision.' },
        severe   = { low = 'Windshield is really cracked.',            mid = 'Windshield is badly cracked.',           high = 'Windshield web-cracked, structural integrity low.' },
        critical = { low = 'Can barely see through windshield.',       mid = 'Windshield is shattered.',               high = 'Windshield shattered, replace immediately.' },
    },
    headlights = {
        mild     = { low = 'Lights seem dim.',                         mid = 'Headlights are dimming.',                high = 'Headlight lenses hazed, output reduced 30%.' },
        moderate = { low = 'One light might be out.',                  mid = 'Headlights need attention.',              high = 'Headlight bulbs degraded, uneven beam pattern.' },
        severe   = { low = 'Headlights barely work.',                  mid = 'Headlights are failing.',                high = 'Headlight assemblies damaged, poor visibility.' },
        critical = { low = 'No headlights.',                           mid = 'Headlights are dead.',                   high = 'Headlight assemblies destroyed, no illumination.' },
    },
    taillights = {
        mild     = { low = 'Rear lights look dim.',                    mid = 'Taillights dimming.',                    high = 'Taillight lenses cracked, moisture ingress.' },
        moderate = { low = 'Rear lights have issues.',                 mid = 'Taillights need replacing.',             high = 'Taillight bulbs degraded, brake visibility poor.' },
        severe   = { low = 'Rear lights barely work.',                 mid = 'Taillights are failing.',                high = 'Taillight assemblies damaged, safety hazard.' },
        critical = { low = 'No rear lights.',                          mid = 'Taillights are dead.',                   high = 'Taillight assemblies destroyed, no visibility.' },
    },
    alternator = {
        mild     = { low = 'Electrical seems off.',                    mid = 'Alternator output low.',                 high = 'Alternator output dropping below spec.' },
        moderate = { low = 'Battery light might be on.',               mid = 'Alternator needs attention.',             high = 'Alternator bearing noise, reduced charging.' },
        severe   = { low = 'Electrical system struggling.',            mid = 'Alternator is failing.',                  high = 'Alternator brushes worn, intermittent charging.' },
        critical = { low = 'Electrical is dying.',                     mid = 'Alternator is dead.',                     high = 'Alternator seized, no charging output.' },
    },
    battery = {
        mild     = { low = 'Starts a bit slow.',                       mid = 'Battery is weak.',                       high = 'Battery voltage low, slow cranking observed.' },
        moderate = { low = 'Hard to start sometimes.',                 mid = 'Battery needs replacing.',                high = 'Battery cells degraded, insufficient CCA.' },
        severe   = { low = 'Really struggles to start.',               mid = 'Battery is almost dead.',                 high = 'Battery sulfated, barely holds charge.' },
        critical = { low = 'Might not start again.',                   mid = 'Battery is dead.',                        high = 'Battery completely dead, no voltage output.' },
    },
    ecu = {
        mild     = { low = 'Something feels glitchy.',                 mid = 'ECU has minor faults.',                   high = 'ECU reporting intermittent sensor errors.' },
        moderate = { low = 'Electronics are acting up.',               mid = 'ECU has issues.',                          high = 'ECU memory corruption, erratic behavior.' },
        severe   = { low = 'Electronics are really glitchy.',          mid = 'ECU is failing.',                          high = 'ECU processor degraded, multiple system faults.' },
        critical = { low = 'Nothing works right.',                     mid = 'ECU is dead.',                             high = 'ECU non-responsive, complete module failure.' },
    },
    wiring = {
        mild     = { low = 'Some flickering noticed.',                 mid = 'Wiring has some issues.',                  high = 'Wiring harness has corroded terminals.' },
        moderate = { low = 'Things flicker on and off.',               mid = 'Wiring needs repair.',                     high = 'Wiring insulation cracked, intermittent shorts.' },
        severe   = { low = 'Electrical is very unreliable.',           mid = 'Wiring is bad.',                           high = 'Wiring harness degraded, multiple open circuits.' },
        critical = { low = 'Electrical is completely unreliable.',     mid = 'Wiring is destroyed.',                     high = 'Wiring harness failed, fire risk present.' },
    },
    tire_fl = {
        mild     = { low = 'Front left tire looks worn.',              mid = 'FL tire tread wearing.',                   high = 'Front left tire at 60% tread depth.' },
        moderate = { low = 'Front left tire is low.',                  mid = 'FL tire needs replacing.',                 high = 'Front left tire tread below safe limit.' },
        severe   = { low = 'Front left tire is bad.',                  mid = 'FL tire is dangerous.',                    high = 'Front left tire showing cord, replace now.' },
        critical = { low = 'Front left tire is flat.',                 mid = 'FL tire is destroyed.',                    high = 'Front left tire structural failure.' },
    },
    tire_fr = {
        mild     = { low = 'Front right tire looks worn.',             mid = 'FR tire tread wearing.',                   high = 'Front right tire at 60% tread depth.' },
        moderate = { low = 'Front right tire is low.',                 mid = 'FR tire needs replacing.',                 high = 'Front right tire tread below safe limit.' },
        severe   = { low = 'Front right tire is bad.',                 mid = 'FR tire is dangerous.',                    high = 'Front right tire showing cord, replace now.' },
        critical = { low = 'Front right tire is flat.',                mid = 'FR tire is destroyed.',                    high = 'Front right tire structural failure.' },
    },
    tire_rl = {
        mild     = { low = 'Rear left tire looks worn.',               mid = 'RL tire tread wearing.',                   high = 'Rear left tire at 60% tread depth.' },
        moderate = { low = 'Rear left tire is low.',                   mid = 'RL tire needs replacing.',                 high = 'Rear left tire tread below safe limit.' },
        severe   = { low = 'Rear left tire is bad.',                   mid = 'RL tire is dangerous.',                    high = 'Rear left tire showing cord, replace now.' },
        critical = { low = 'Rear left tire is flat.',                  mid = 'RL tire is destroyed.',                    high = 'Rear left tire structural failure.' },
    },
    tire_rr = {
        mild     = { low = 'Rear right tire looks worn.',              mid = 'RR tire tread wearing.',                   high = 'Rear right tire at 60% tread depth.' },
        moderate = { low = 'Rear right tire is low.',                  mid = 'RR tire needs replacing.',                 high = 'Rear right tire tread below safe limit.' },
        severe   = { low = 'Rear right tire is bad.',                  mid = 'RR tire is dangerous.',                    high = 'Rear right tire showing cord, replace now.' },
        critical = { low = 'Rear right tire is flat.',                 mid = 'RR tire is destroyed.',                    high = 'Rear right tire structural failure.' },
    },
}
