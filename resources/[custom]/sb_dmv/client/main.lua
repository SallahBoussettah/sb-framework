local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- STATE
-- ============================================================================

local receptionistNPC = nil
local instructorNPC = nil
local isNUIOpen = false
local pendingBase64 = nil
local mugshotHandle = nil
local mugshotTxd = nil

-- Player DMV status (refreshed on approach)
local playerDmvStatus = 'unknown'  -- 'theory', 'parking', 'driving', 'done'
local playerHasRecord = false       -- Has ever earned a license (DB record)
local lastStatusCheck = 0

local function RefreshDmvStatus()
    local now = GetGameTimer()
    if now - lastStatusCheck < 3000 then return end
    lastStatusCheck = now
    SB.Functions.TriggerCallback('sb_dmv:server:getProgress', function(result)
        playerDmvStatus = result.nextTest or 'unknown'
        playerHasRecord = result.hasRecord or false
    end)
end

-- Theory exam state
local theoryActive = false
local theoryQuestions = nil
local theorySubmitted = false

-- Practical test state
local testActive = false
local testType = nil         -- 'parking' or 'driving'
local testPhase = nil        -- 'parking_zones', 'driving', 'returning'
local testVehicle = nil
local testInstructor = nil
local testBlips = {}
local currentParkingZone = 0
local currentCheckpoint = 0
local penaltyPoints = 0
local lastDamage = 0
local exitedVehicleTime = 0

-- Speed limiter state
local speedLimiterActive = false
local currentSpeedLimit = 0      -- Current road speed limit in km/h

-- Seatbelt check state
local seatbeltChecked = false    -- Only penalize once per test

-- ============================================================================
-- NPC SPAWN
-- ============================================================================

local function SpawnNPC(model, coords, scenario)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(100)
    end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanPlayAmbientAnims(ped, false)
    SetModelAsNoLongerNeeded(hash)

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    return ped
end

local function DeleteAmbientPedsNear(coords, radius)
    local handle, ped = FindFirstPed()
    local success = true
    while success do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(pedCoords - vector3(coords.x, coords.y, coords.z))
            if dist < radius then
                DeleteEntity(ped)
            end
        end
        success, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
end

local function SpawnReceptionist()
    local cfg = Config.Receptionist

    DeleteAmbientPedsNear(cfg.coords, cfg.ambientDeleteRadius or 2.0)
    Wait(200)

    receptionistNPC = SpawnNPC(cfg.model, cfg.coords, cfg.scenario)

    exports['sb_target']:AddTargetEntity(receptionistNPC, {
        {
            name = 'dmv_theory',
            label = 'Take Theory Exam ($' .. Config.TestCost .. ')',
            icon = 'fa-file-alt',
            distance = Config.InteractDistance,
            canInteract = function()
                RefreshDmvStatus()
                -- Only show if they haven't earned a license yet
                return not theoryActive and not theorySubmitted and not testActive
                    and playerDmvStatus ~= 'done' and not playerHasRecord
            end,
            action = function()
                StartTheoryExam()
            end
        },
        {
            name = 'dmv_reissue',
            label = 'Reissue Lost License ($' .. Config.ReissueCost .. ')',
            icon = 'fa-id-card',
            distance = Config.InteractDistance,
            canInteract = function()
                RefreshDmvStatus()
                -- Only show if they earned a license before but don't have it now
                return not theoryActive and not theorySubmitted and not testActive
                    and playerHasRecord and playerDmvStatus ~= 'done'
            end,
            action = function()
                RequestLicenseReissue()
            end
        }
    })
end

local function SpawnInstructor()
    local cfg = Config.Instructor
    instructorNPC = SpawnNPC(cfg.model, cfg.coords, nil)

    exports['sb_target']:AddTargetEntity(instructorNPC, {
        {
            name = 'dmv_next_test',
            label = 'Take Next Test',
            icon = 'fa-car',
            distance = Config.InteractDistance,
            canInteract = function()
                RefreshDmvStatus()
                -- Only show if they still need practical tests
                return not testActive and not theoryActive
                    and playerDmvStatus ~= 'done' and not playerHasRecord
            end,
            action = function()
                StartNextPracticalTest()
            end
        }
    })
end

-- ============================================================================
-- BLIP
-- ============================================================================

local function CreateBlip()
    local cfg = Config.Receptionist
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, cfg.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.blip.scale)
    SetBlipColour(blip, cfg.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.blip.label)
    EndTextCommandSetBlipName(blip)
end

-- ============================================================================
-- HEADSHOT CAPTURE (sb_id pattern)
-- ============================================================================

local function ClearHeadshots()
    for i = 1, 32 do
        if IsPedheadshotValid(i) then
            UnregisterPedheadshot(i)
        end
    end
end

local function CaptureHeadshot(cb)
    ClearHeadshots()
    local ped = PlayerPedId()
    local handle = RegisterPedheadshotTransparent(ped)

    local timeout = 50
    while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end

    if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
        local txd = GetPedheadshotTxdString(handle)
        local url = string.format('https://nui-img/%s/%s', txd, txd)
        mugshotHandle = handle
        mugshotTxd = txd
        cb(url, handle)
    else
        UnregisterPedheadshot(handle)
        cb(nil, nil)
    end
end

RegisterNUICallback('base64Result', function(data, cb)
    if data.base64 and data.base64 ~= '' then
        pendingBase64 = data.base64
    else
        pendingBase64 = false
    end

    if data.handle then
        UnregisterPedheadshot(data.handle)
        if mugshotHandle == data.handle then
            mugshotHandle = nil
            mugshotTxd = nil
        end
    end

    cb('ok')
end)

local function ReleaseMugshot()
    if mugshotHandle then
        UnregisterPedheadshot(mugshotHandle)
        mugshotHandle = nil
        mugshotTxd = nil
    end
end

-- ============================================================================
-- NUI CONTROL
-- ============================================================================

local function OpenNUI(focus)
    isNUIOpen = true
    if focus == nil then focus = true end
    SetNuiFocus(focus, focus)
    if focus then
        TriggerEvent('sb_hud:setVisible', false)
    end
end

local function CloseNUI()
    isNUIOpen = false
    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'close' })
    ReleaseMugshot()
end

RegisterNUICallback('close', function(data, cb)
    CloseNUI()

    if theoryActive then
        theoryActive = false
        theoryQuestions = nil
    end

    cb('ok')
end)

-- ============================================================================
-- THEORY EXAM (Test 1)
-- ============================================================================

function StartTheoryExam()
    if theoryActive or theorySubmitted then return end

    SB.Functions.TriggerCallback('sb_dmv:server:checkTheoryEligibility', function(result)
        if not result.eligible then
            exports['sb_notify']:Notify(result.reason, 'error', 5000)
            return
        end

        theoryQuestions = result.questions
        theoryActive = true

        OpenNUI(true)
        SendNUIMessage({
            action = 'openExam',
            questions = theoryQuestions
        })
    end)
end

RegisterNUICallback('submitAnswers', function(data, cb)
    CloseNUI()
    cb('ok')

    if not data.answers or type(data.answers) ~= 'table' then
        theoryActive = false
        theoryQuestions = nil
        return
    end

    local answers = data.answers

    theorySubmitted = true
    theoryActive = false
    TriggerServerEvent('sb_dmv:server:submitTheoryAnswers', answers)

    exports['sb_progressbar']:Start({
        duration = 10000,
        label = 'Grading your exam...',
        canCancel = false,
        anim = {
            dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a',
            clip = 'idle_a',
            flag = 49
        },
        onComplete = function() end,
        onCancel = function() end
    })
end)

-- ============================================================================
-- LICENSE REISSUE
-- ============================================================================

function RequestLicenseReissue()
    SB.Functions.TriggerCallback('sb_dmv:server:checkReissueEligibility', function(result)
        if not result.eligible then
            exports['sb_notify']:Notify(result.reason, 'error', 5000)
            return
        end

        exports['sb_notify']:Notify('Reissuing your license...', 'info', 3000)

        exports['sb_progressbar']:Start({
            duration = 5000,
            label = 'Processing license reissue...',
            canCancel = false,
            anim = {
                dict = 'mp_common',
                clip = 'givetake1_a',
                flag = 49
            },
            onComplete = function()
                TriggerServerEvent('sb_dmv:server:reissueLicense')
            end,
            onCancel = function() end
        })
    end)
end

-- ============================================================================
-- THEORY RESULT
-- ============================================================================

RegisterNetEvent('sb_dmv:client:theoryResult', function(passed, score)
    theoryActive = false
    theoryQuestions = nil
    theorySubmitted = false

    OpenNUI(true)
    SendNUIMessage({
        action = 'showResult',
        resultType = 'theory',
        passed = passed,
        score = score
    })
end)

-- ============================================================================
-- INSTRUCTOR — CHECK PROGRESS & START NEXT TEST
-- ============================================================================

function StartNextPracticalTest()
    SB.Functions.TriggerCallback('sb_dmv:server:getProgress', function(result)
        if result.nextTest == 'done' then
            exports['sb_notify']:Notify(result.message, 'info', 5000)
        elseif result.nextTest == 'theory' then
            exports['sb_notify']:Notify('You need to pass the theory exam first. Talk to the receptionist.', 'error', 5000)
        elseif result.nextTest == 'parking' then
            StartParkingTest()
        elseif result.nextTest == 'driving' then
            StartDrivingTest()
        end
    end)
end

-- ============================================================================
-- SHARED: SPAWN TEST VEHICLE + INSTRUCTOR
-- ============================================================================

local function SpawnTestVehicle(cb)
    local spawnCoords = Config.TestVehicleSpawn
    local vehicleHash = GetHashKey(Config.TestVehicle)

    RequestModel(vehicleHash)
    while not HasModelLoaded(vehicleHash) do
        Wait(100)
    end

    testVehicle = CreateVehicle(vehicleHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    SetVehicleNumberPlateText(testVehicle, 'DMV TEST')
    SetEntityAsMissionEntity(testVehicle, true, true)
    SetVehicleDoorsLocked(testVehicle, 0)
    SetVehicleEngineOn(testVehicle, true, true, false)
    SetModelAsNoLongerNeeded(vehicleHash)

    Entity(testVehicle).state.sb_owned = true

    -- Fill fuel tank
    pcall(function()
        exports['sb_fuel']:SetFuel(testVehicle, 100.0)
    end)

    -- Spawn instructor in passenger seat
    local instrModel = GetHashKey(Config.Instructor.model)
    RequestModel(instrModel)
    while not HasModelLoaded(instrModel) do
        Wait(100)
    end

    testInstructor = CreatePed(4, instrModel, spawnCoords.x + 1.0, spawnCoords.y, spawnCoords.z, spawnCoords.w, false, true)
    SetEntityInvincible(testInstructor, true)
    SetBlockingOfNonTemporaryEvents(testInstructor, true)
    SetPedFleeAttributes(testInstructor, 0, false)
    SetPedCombatAttributes(testInstructor, 46, true)
    SetPedConfigFlag(testInstructor, 184, true)
    SetPedConfigFlag(testInstructor, 32, false)
    FreezeEntityPosition(testInstructor, false)
    TaskWarpPedIntoVehicle(testInstructor, testVehicle, 0)
    SetPedCanBeDraggedOut(testInstructor, false)
    SetModelAsNoLongerNeeded(instrModel)

    lastDamage = GetVehicleBodyHealth(testVehicle)

    exports['sb_notify']:Notify('Get in the driver\'s seat to begin. You have 30 seconds.', 'info', 8000)

    -- Wait for player to enter
    CreateThread(function()
        local timeout = 300
        while testActive and timeout > 0 do
            Wait(100)
            timeout = timeout - 1
            local ped = PlayerPedId()
            if IsPedInVehicle(ped, testVehicle, false) and GetPedInVehicleSeat(testVehicle, -1) == ped then
                if cb then cb() end
                return
            end
        end

        if testActive then
            exports['sb_notify']:Notify('You didn\'t enter the vehicle in time. Test cancelled.', 'error', 5000)
            CancelTest()
        end
    end)
end

-- ============================================================================
-- PARKING TEST (Test 2) — Sequential parking at 7 zones
-- ============================================================================

function StartParkingTest()
    SB.Functions.TriggerCallback('sb_dmv:server:checkParkingEligibility', function(result)
        if not result.eligible then
            exports['sb_notify']:Notify(result.reason, 'error', 5000)
            return
        end

        TriggerServerEvent('sb_dmv:server:startPractical', 'parking')

        testActive = true
        testType = 'parking'
        penaltyPoints = 0
        currentParkingZone = 0

        SpawnTestVehicle(function()
            StartParkingZones()
        end)
    end)
end

function StartParkingZones()
    testPhase = 'parking_zones'
    currentParkingZone = 1

    exports['sb_notify']:Notify('PARKING TEST: Drive to each zone and park correctly. (' .. #Config.ParkingZones .. ' spots)', 'info', 6000)

    -- Show driving HUD
    SendNUIMessage({
        action = 'showDrivingHUD',
        phase = 'PARKING',
        penalties = penaltyPoints,
        maxPenalties = Config.MaxPenaltyPoints,
        checkpoint = 1,
        totalCheckpoints = #Config.ParkingZones,
        speedLimit = 0,
        speed = 0
    })
    OpenNUI(false)

    -- Create first blip
    CreateParkingBlip(currentParkingZone)

    -- Draw parking marker every frame (DrawMarker only lasts 1 frame)
    CreateThread(function()
        while testActive and testPhase == 'parking_zones' do
            Wait(0)
            local zone = Config.ParkingZones[currentParkingZone]
            if zone then
                DrawMarker(1, zone.center.x, zone.center.y, zone.center.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, zone.heading,
                    zone.radius * 2, zone.radius * 2, 0.5,
                    255, 165, 0, 100, false, true, 2, false, nil, nil, false)
            end
        end
    end)

    -- Monitor parking logic (doesn't need every frame)
    CreateThread(function()
        while testActive and testPhase == 'parking_zones' do
            Wait(100)

            local ped = PlayerPedId()

            if not IsPedInVehicle(ped, testVehicle, false) then
                HandleVehicleExit()
                if not testActive then return end
            end

            CheckDamage()

            if not testVehicle or not DoesEntityExist(testVehicle) then
                CancelTest()
                return
            end

            local zone = Config.ParkingZones[currentParkingZone]
            if not zone then
                -- All zones done, return to DMV
                StartReturnPhase()
                return
            end

            local vehCoords = GetEntityCoords(testVehicle)
            local dist = #(vehCoords - zone.center)
            local speed = GetEntitySpeed(testVehicle) * 3.6
            local vehHeading = GetEntityHeading(testVehicle)

            -- Check parking
            if dist <= zone.radius and speed < 1.0 then
                local headingDiff = math.abs(vehHeading - zone.heading) % 360
                if headingDiff > 180 then headingDiff = 360 - headingDiff end

                if headingDiff <= zone.headingTolerance then
                    -- Parked correctly
                    exports['sb_notify']:Notify('Spot ' .. currentParkingZone .. '/' .. #Config.ParkingZones .. ' - Correct!', 'success', 2000)
                    currentParkingZone = currentParkingZone + 1
                    ClearTestBlips()

                    if currentParkingZone <= #Config.ParkingZones then
                        CreateParkingBlip(currentParkingZone)
                    end

                    Wait(1500)
                elseif headingDiff > 90 then
                    -- Facing the wrong way (180° off)
                    exports['sb_notify']:Notify('You\'re facing the wrong direction! Rotate the vehicle.', 'error', 3000)
                    Wait(3000)
                end
            end

            -- Update HUD
            SendNUIMessage({
                action = 'updateHUD',
                speed = math.floor(speed),
                speedLimit = 0,
                penalties = penaltyPoints,
                checkpoint = currentParkingZone,
                totalCheckpoints = #Config.ParkingZones,
                phase = 'PARKING'
            })
        end
    end)
end

function CreateParkingBlip(index)
    if index > #Config.ParkingZones then return end
    local zone = Config.ParkingZones[index]
    local blip = AddBlipForCoord(zone.center.x, zone.center.y, zone.center.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Parking Spot ' .. index)
    EndTextCommandSetBlipName(blip)
    testBlips[#testBlips + 1] = blip
end

-- ============================================================================
-- DRIVING TEST (Test 3) — Route with auto-detection
-- ============================================================================

-- Stop sign prop hashes
local stopSignHashes = {
    GetHashKey('prop_sign_road_01a'),
    GetHashKey('prop_sign_road_stop'),
}

-- Traffic light prop hashes
local trafficLightHashes = {
    GetHashKey('prop_traffic_01a'),
    GetHashKey('prop_traffic_01b'),
    GetHashKey('prop_traffic_01d'),
    GetHashKey('prop_traffic_02a'),
    GetHashKey('prop_traffic_02b'),
    GetHashKey('prop_traffic_03a'),
    GetHashKey('prop_traffic_03b'),
}

local function GetRoadSpeedLimit()
    local coords = GetEntityCoords(PlayerPedId())
    local retval, density, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    if not retval then return Config.SpeedLimits.cityStreet end

    if density <= 2 then return Config.SpeedLimits.highway end
    if density <= 5 then return Config.SpeedLimits.mainRoad end
    if density <= 8 then return Config.SpeedLimits.cityStreet end
    return Config.SpeedLimits.residential
end

local function GetNearestStopSign(coords, radius)
    for _, hash in ipairs(stopSignHashes) do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius, hash, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            return obj, GetEntityCoords(obj)
        end
    end
    return nil, nil
end

local function GetNearestTrafficLight(coords, radius)
    for _, hash in ipairs(trafficLightHashes) do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius, hash, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            return obj, GetEntityCoords(obj)
        end
    end
    return nil, nil
end

local function IsTrafficLightLikelyRed(lightCoords)
    local handle, vehicle = FindFirstVehicle()
    local success = true
    local stoppedCount = 0
    local nearbyCount = 0
    local checkRadius = Config.AutoDetect.npcCheckRadius

    while success do
        if DoesEntityExist(vehicle) and vehicle ~= testVehicle then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver ~= 0 and not IsPedAPlayer(driver) then
                local vehCoords = GetEntityCoords(vehicle)
                local dist = #(vehCoords - lightCoords)
                if dist < checkRadius then
                    nearbyCount = nearbyCount + 1
                    local vehSpeed = GetEntitySpeed(vehicle) * 3.6
                    if vehSpeed < 2.0 then
                        stoppedCount = stoppedCount + 1
                    end
                end
            end
        end
        success, vehicle = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)

    return nearbyCount >= Config.AutoDetect.npcStoppedThreshold
        and stoppedCount >= Config.AutoDetect.npcStoppedThreshold
end

-- Auto-detection state
local activeStopSign = nil
local stopSignStopTime = 0
local stopSignViolated = false
local activeTrafficLight = nil
local trafficLightChecked = false

-- Full stop checkpoint state
local fullStopLookup = {}           -- [checkpointIndex] = true (built from config)
local fullStopTracking = false      -- Are we near a full-stop checkpoint?
local fullStopTrackingIndex = 0     -- Which checkpoint we're tracking
local fullStopAccumulated = 0       -- Seconds stopped so far
local fullStopSatisfied = false     -- Did they stop long enough?
local fullStopReached = false       -- Did they enter the checkpoint zone?
local fullStopClosestDist = 999.0   -- Track closest distance to detect driving away

-- ============================================================================
-- SPEED LIMITER (toggle with X during driving test)
-- ============================================================================

RegisterCommand('dmv_speedlimit', function()
    if not testActive or testPhase ~= 'driving' then return end
    if not testVehicle or not DoesEntityExist(testVehicle) then return end

    speedLimiterActive = not speedLimiterActive

    if speedLimiterActive then
        local limit = GetRoadSpeedLimit()
        SetEntityMaxSpeed(testVehicle, limit / 3.6)
        exports['sb_notify']:Notify('Speed limiter ON — Locked to ' .. limit .. ' km/h', 'success', 3000)
    else
        SetEntityMaxSpeed(testVehicle, 500.0)
        exports['sb_notify']:Notify('Speed limiter OFF', 'info', 2000)
    end
end, false)
RegisterKeyMapping('dmv_speedlimit', 'DMV Speed Limiter', 'keyboard', Config.SpeedLimiterKey or 'X')

function StartDrivingTest()
    SB.Functions.TriggerCallback('sb_dmv:server:checkDrivingEligibility', function(result)
        if not result.eligible then
            exports['sb_notify']:Notify(result.reason, 'error', 5000)
            return
        end

        TriggerServerEvent('sb_dmv:server:startPractical', 'driving')

        testActive = true
        testType = 'driving'
        penaltyPoints = 0
        currentCheckpoint = 0

        SpawnTestVehicle(function()
            StartDrivingPhase()
        end)
    end)
end

function StartDrivingPhase()
    testPhase = 'driving'
    currentCheckpoint = 1

    activeStopSign = nil
    stopSignStopTime = 0
    stopSignViolated = false
    activeTrafficLight = nil
    trafficLightChecked = false
    speedLimiterActive = false
    seatbeltChecked = false

    -- Build full-stop lookup from config
    fullStopLookup = {}
    for _, idx in ipairs(Config.FullStopCheckpoints or {}) do
        fullStopLookup[idx] = true
    end
    fullStopTracking = false
    fullStopTrackingIndex = 0
    fullStopAccumulated = 0
    fullStopSatisfied = false
    fullStopReached = false
    fullStopClosestDist = 999.0

    ClearTestBlips()

    exports['sb_notify']:Notify('DRIVING TEST: Follow the route. Obey speed limits, stop signs, and traffic lights.', 'info', 5000)

    -- Show HUD
    SendNUIMessage({
        action = 'showDrivingHUD',
        phase = 'DRIVING',
        penalties = penaltyPoints,
        maxPenalties = Config.MaxPenaltyPoints,
        checkpoint = 1,
        totalCheckpoints = #Config.RouteCheckpoints,
        speedLimit = 0,
        speed = 0
    })
    OpenNUI(false)

    CreateCheckpointBlip(currentCheckpoint)

    CreateThread(function()
        while testActive and testPhase == 'driving' do
            Wait(100)

            local ped = PlayerPedId()

            if not IsPedInVehicle(ped, testVehicle, false) then
                HandleVehicleExit()
                if not testActive then return end
            end

            if not testVehicle or not DoesEntityExist(testVehicle) then
                CancelTest()
                return
            end

            local vehCoords = GetEntityCoords(testVehicle)
            local speed = GetEntitySpeed(testVehicle) * 3.6

            CheckDamage()

            -- Seatbelt check — penalize once if driving above threshold without seatbelt
            if not seatbeltChecked and speed >= (Config.SeatbeltSpeedThreshold or 15) then
                local ok, hasSeatbelt = pcall(function()
                    return exports['sb_hud']:IsSeatbeltOn()
                end)
                if ok and not hasSeatbelt then
                    ReportPenalty('seatbelt')
                end
                seatbeltChecked = true
            end

            -- Auto speed limit
            local currentLimit = GetRoadSpeedLimit()
            currentSpeedLimit = currentLimit

            -- Update speed limiter cap when road limit changes
            if speedLimiterActive and testVehicle and DoesEntityExist(testVehicle) then
                SetEntityMaxSpeed(testVehicle, currentLimit / 3.6)
            end
            if speed > currentLimit + Config.SpeedGrace then
                ReportPenalty('speeding')
            end

            -- Checkpoint detection + full stop logic
            if currentCheckpoint <= #Config.RouteCheckpoints then
                local cpCoords = Config.RouteCheckpoints[currentCheckpoint]
                local cpDist = #(vehCoords - cpCoords)
                local isFullStop = fullStopLookup[currentCheckpoint]

                if isFullStop then
                    -- FULL STOP CHECKPOINT: player must stop before it advances
                    if cpDist <= (Config.FullStopDetectRadius or 25.0) then
                        -- Init tracking for this checkpoint
                        if not fullStopTracking or fullStopTrackingIndex ~= currentCheckpoint then
                            fullStopTracking = true
                            fullStopTrackingIndex = currentCheckpoint
                            fullStopAccumulated = 0
                            fullStopSatisfied = false
                            fullStopReached = false
                            fullStopClosestDist = cpDist
                        end

                        -- Track closest approach
                        if cpDist < fullStopClosestDist then
                            fullStopClosestDist = cpDist
                        end

                        -- Mark as reached once within 10m
                        if cpDist <= 10.0 then
                            fullStopReached = true
                        end

                        -- Accumulate stop time
                        if speed < (Config.FullStopRequiredSpeed or 1.0) then
                            fullStopAccumulated = fullStopAccumulated + 0.1
                            if fullStopAccumulated >= (Config.FullStopRequiredTime or 1.5) and not fullStopSatisfied then
                                fullStopSatisfied = true
                                exports['sb_notify']:Notify('Full stop — Good!', 'success', 2000)
                            end
                        end

                        -- Advance conditions:
                        -- 1. Stopped successfully and within 10m → advance
                        -- 2. Reached the zone and now driving away without stopping → penalty + advance
                        local drivingAway = fullStopReached and cpDist > fullStopClosestDist + 5.0

                        if fullStopSatisfied and cpDist <= 10.0 then
                            -- Good stop, advance
                            goto advanceCheckpoint
                        elseif drivingAway and not fullStopSatisfied then
                            -- Drove through without stopping
                            ReportPenalty('fullStop')
                            goto advanceCheckpoint
                        elseif fullStopSatisfied and drivingAway then
                            -- Stopped then drove away, advance
                            goto advanceCheckpoint
                        end
                    elseif fullStopTracking and fullStopTrackingIndex == currentCheckpoint then
                        -- Left the 25m zone entirely — they passed it
                        if not fullStopSatisfied then
                            ReportPenalty('fullStop')
                        end
                        goto advanceCheckpoint
                    end
                else
                    -- NORMAL CHECKPOINT: advance when within 10m
                    if cpDist <= 10.0 then
                        goto advanceCheckpoint
                    end
                end

                goto skipAdvance

                ::advanceCheckpoint::
                -- Reset full stop state
                fullStopTracking = false
                fullStopTrackingIndex = 0
                fullStopAccumulated = 0
                fullStopSatisfied = false
                fullStopReached = false
                fullStopClosestDist = 999.0

                currentCheckpoint = currentCheckpoint + 1
                ClearTestBlips()

                if currentCheckpoint <= #Config.RouteCheckpoints then
                    CreateCheckpointBlip(currentCheckpoint)
                    exports['sb_notify']:Notify('Checkpoint ' .. (currentCheckpoint - 1) .. '/' .. #Config.RouteCheckpoints, 'info', 2000)
                else
                    StartReturnPhase()
                    return
                end

                ::skipAdvance::
            end

            -- Update HUD
            SendNUIMessage({
                action = 'updateHUD',
                speed = math.floor(speed),
                speedLimit = currentLimit,
                penalties = penaltyPoints,
                checkpoint = currentCheckpoint,
                totalCheckpoints = #Config.RouteCheckpoints,
                phase = 'DRIVING'
            })
        end
    end)
end

-- ============================================================================
-- RETURN TO DMV (shared by parking and driving tests)
-- ============================================================================

function StartReturnPhase()
    testPhase = 'returning'
    ClearTestBlips()

    exports['sb_notify']:Notify('Test complete! Return to the DMV.', 'success', 5000)

    local returnCoords = Config.Instructor.coords
    local returnBlip = AddBlipForCoord(returnCoords.x, returnCoords.y, returnCoords.z)
    SetBlipSprite(returnBlip, 1)
    SetBlipColour(returnBlip, 2)
    SetBlipScale(returnBlip, 0.9)
    SetBlipRoute(returnBlip, true)
    testBlips[#testBlips + 1] = returnBlip

    CreateThread(function()
        while testActive and testPhase == 'returning' do
            Wait(200)

            local ped = PlayerPedId()

            if not IsPedInVehicle(ped, testVehicle, false) then
                HandleVehicleExit()
                if not testActive then return end
            end

            CheckDamage()

            if testVehicle and DoesEntityExist(testVehicle) then
                local vehCoords = GetEntityCoords(testVehicle)
                local dist = #(vehCoords - vector3(returnCoords.x, returnCoords.y, returnCoords.z))
                local speed = GetEntitySpeed(testVehicle) * 3.6

                SendNUIMessage({
                    action = 'updateHUD',
                    speed = math.floor(speed),
                    speedLimit = 0,
                    penalties = penaltyPoints,
                    phase = 'RETURN'
                })

                if dist <= 15.0 and speed < 5.0 then
                    CompletePractical()
                    return
                end
            end
        end
    end)
end

-- ============================================================================
-- TEST HELPERS
-- ============================================================================

local lastPenaltyTime = {}

function ReportPenalty(penaltyType)
    local now = GetGameTimer()
    if lastPenaltyTime[penaltyType] and now - lastPenaltyTime[penaltyType] < 5000 then
        return
    end
    lastPenaltyTime[penaltyType] = now

    local pts = Config.Penalties[penaltyType] or 0
    penaltyPoints = penaltyPoints + pts

    local labels = {
        speeding = 'SPEEDING',
        stopSign = 'STOP SIGN VIOLATION',
        trafficLight = 'RED LIGHT VIOLATION',
        damage = 'VEHICLE DAMAGE',
        missedCheckpoint = 'MISSED CHECKPOINT',
        fullStop = 'FAILED TO STOP AT STOP SIGN',
        seatbelt = 'NO SEATBELT'
    }

    exports['sb_notify']:Notify(labels[penaltyType] .. ' (+' .. pts .. ' penalty points)', 'error', 3000)

    TriggerServerEvent('sb_dmv:server:reportPenalty', penaltyType, pts)
end

function CheckDamage()
    if not testVehicle or not DoesEntityExist(testVehicle) then return end

    local currentHealth = GetVehicleBodyHealth(testVehicle)
    local delta = lastDamage - currentHealth

    if delta > 50 then
        ReportPenalty('damage')
        lastDamage = currentHealth
    end
end

function HandleVehicleExit()
    if not testActive then return end

    exitedVehicleTime = GetGameTimer()
    exports['sb_notify']:Notify('Get back in the vehicle! You have 5 seconds.', 'error', 3000)

    while testActive do
        Wait(100)
        local ped = PlayerPedId()
        if IsPedInVehicle(ped, testVehicle, false) then
            return
        end
        if GetGameTimer() - exitedVehicleTime > 5000 then
            exports['sb_notify']:Notify('You left the vehicle. Test cancelled.', 'error', 5000)
            CancelTest()
            return
        end
    end
end

function CreateCheckpointBlip(index)
    if index > #Config.RouteCheckpoints then return end
    local coords = Config.RouteCheckpoints[index]
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Checkpoint ' .. index)
    EndTextCommandSetBlipName(blip)
    testBlips[#testBlips + 1] = blip
end

function ClearTestBlips()
    for _, blip in ipairs(testBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    testBlips = {}
end

function CompletePractical()
    testActive = false
    testPhase = nil

    SendNUIMessage({ action = 'hideDrivingHUD' })

    TriggerServerEvent('sb_dmv:server:completePractical')
    CleanupTest()
end

function CancelTest()
    if not testActive then return end
    testActive = false
    testPhase = nil

    SendNUIMessage({ action = 'hideDrivingHUD' })

    TriggerServerEvent('sb_dmv:server:cancelPractical')
    CleanupTest()
end

function CleanupTest()
    ClearTestBlips()

    if testVehicle and DoesEntityExist(testVehicle) then
        DeleteEntity(testVehicle)
        testVehicle = nil
    end

    if testInstructor and DoesEntityExist(testInstructor) then
        DeleteEntity(testInstructor)
        testInstructor = nil
    end

    lastPenaltyTime = {}
    penaltyPoints = 0
    currentCheckpoint = 0
    currentParkingZone = 0
    testPhase = nil
    testType = nil
    speedLimiterActive = false
    currentSpeedLimit = 0
    seatbeltChecked = false
    fullStopReached = false
    fullStopClosestDist = 999.0
end

-- ============================================================================
-- PRACTICAL TEST RESULT (from server)
-- ============================================================================

RegisterNetEvent('sb_dmv:client:practicalResult', function(passed, penalties, resultTestType)
    CleanupTest()

    local resultType = 'practical'
    local message = ''

    if resultTestType == 'parking' then
        if passed then
            message = 'Parking test passed! You can now take the driving test.'
        else
            message = 'Too many penalty points. Please wait before retrying.'
        end
    elseif resultTestType == 'driving' then
        if passed then
            message = 'Congratulations! Your driver\'s license has been issued. Check your inventory.'
        else
            message = 'Too many penalty points. Please wait before retrying.'
        end
    end

    OpenNUI(true)
    SendNUIMessage({
        action = 'showResult',
        resultType = resultType,
        passed = passed,
        penalties = penalties,
        maxPenalties = Config.MaxPenaltyPoints,
        customMessage = message
    })
end)

RegisterNetEvent('sb_dmv:client:penaltyUpdate', function(serverPenalties, penaltyType, points)
    penaltyPoints = serverPenalties
end)

-- ============================================================================
-- LICENSE CARD VIEW (from inventory use)
-- ============================================================================

RegisterNetEvent('sb_dmv:client:viewLicense', function(metadata)
    if isNUIOpen then return end

    local playerData = SB.Functions.GetPlayerData()
    local isOwner = playerData.citizenid == metadata.citizenid

    if isOwner then
        CaptureHeadshot(function(liveUrl, handle)
            OpenNUI(true)
            SendNUIMessage({
                action = 'showLicense',
                data = metadata,
                liveMugshotUrl = liveUrl or '',
                mugshot = metadata.mugshot or ''
            })
        end)
    else
        OpenNUI(true)
        SendNUIMessage({
            action = 'showLicense',
            data = metadata,
            liveMugshotUrl = '',
            mugshot = metadata.mugshot or ''
        })
    end
end)

-- ============================================================================
-- DEATH DETECTION
-- ============================================================================

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then
            if testActive then
                CancelTest()
            end
            if theoryActive then
                theoryActive = false
                theoryQuestions = nil
                theorySubmitted = false
                if isNUIOpen then CloseNUI() end
            end
        end
    end
end)

-- ============================================================================
-- AMBIENT PED CLEANUP
-- ============================================================================

CreateThread(function()
    while true do
        Wait(10000)
        if receptionistNPC and DoesEntityExist(receptionistNPC) then
            local cfg = Config.Receptionist
            local handle, ped = FindFirstPed()
            local success = true
            while success do
                if DoesEntityExist(ped) and not IsPedAPlayer(ped) and ped ~= receptionistNPC then
                    local pedCoords = GetEntityCoords(ped)
                    local dist = #(pedCoords - vector3(cfg.coords.x, cfg.coords.y, cfg.coords.z))
                    if dist < (cfg.ambientDeleteRadius or 2.0) then
                        DeleteEntity(ped)
                    end
                end
                success, ped = FindNextPed(handle)
            end
            EndFindPed(handle)
        end
    end
end)

-- ============================================================================
-- INIT
-- ============================================================================

CreateThread(function()
    SpawnReceptionist()
    SpawnInstructor()
    CreateBlip()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if receptionistNPC and DoesEntityExist(receptionistNPC) then
        DeleteEntity(receptionistNPC)
    end
    if instructorNPC and DoesEntityExist(instructorNPC) then
        DeleteEntity(instructorNPC)
    end

    CleanupTest()
    ReleaseMugshot()

    if theoryActive then
        theoryActive = false
        theoryQuestions = nil
        theorySubmitted = false
    end

    if isNUIOpen then
        CloseNUI()
    end
end)
