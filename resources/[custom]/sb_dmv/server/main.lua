local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- DATABASE: Create table to track who has earned a license (for reissue)
-- ============================================================================

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `dmv_licenses` (
            `citizenid` VARCHAR(50) NOT NULL,
            `license_number` VARCHAR(20) NOT NULL,
            `firstname` VARCHAR(50) NOT NULL,
            `lastname` VARCHAR(50) NOT NULL,
            `dob` VARCHAR(20) NOT NULL,
            `issued` DATE NOT NULL,
            `class` VARCHAR(5) DEFAULT 'C',
            PRIMARY KEY (`citizenid`)
        )
    ]])
end)

-- ============================================================================
-- STATE TRACKING (in-memory, only for active tests — progress persists via items)
-- ============================================================================

local dmvSessions = {}  -- [citizenid] = { selectedQuestions, correctAnswers, theoryCooldown, practicalCooldown, penaltyPoints, practicalActive, practicalType }
local penaltyRateLimits = {}  -- [citizenid] = { [penaltyType] = lastTime }

local function GetSession(citizenid)
    if not dmvSessions[citizenid] then
        dmvSessions[citizenid] = {
            theoryCooldown = 0,
            practicalCooldown = 0,
            selectedQuestions = {},
            correctAnswers = {},
            penaltyPoints = 0,
            practicalActive = false,
            practicalType = nil  -- 'parking' or 'driving'
        }
    end
    return dmvSessions[citizenid]
end

local function GenerateLicenseNumber()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local num = 'LS-'
    for i = 1, 5 do
        local idx = math.random(1, #chars)
        num = num .. chars:sub(idx, idx)
    end
    return num
end

-- Remove DMV test keys from player
local function RemoveTestKeys(src)
    local keys = exports['sb_inventory']:GetItemsByName(src, 'car_keys')
    if keys then
        for _, keyItem in ipairs(keys) do
            if keyItem.metadata and keyItem.metadata.plate then
                local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                if keyPlate == 'DMVTEST' then
                    exports['sb_inventory']:RemoveItem(src, 'car_keys', 1, keyItem.slot)
                    break
                end
            end
        end
    end
end

-- Remove a specific DMV cert item
local function RemoveCert(src, itemName)
    local items = exports['sb_inventory']:GetItemsByName(src, itemName)
    if items and #items > 0 then
        exports['sb_inventory']:RemoveItem(src, itemName, 1, items[1].slot)
        return true
    end
    return false
end

-- Check if player has THEIR OWN license (not someone else's)
local function HasOwnLicense(src, citizenid)
    local items = exports['sb_inventory']:GetItemsByName(src, 'car_license')
    if items then
        for _, item in ipairs(items) do
            if item.metadata and item.metadata.citizenid == citizenid then
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Check what test the player needs next
SB.Functions.CreateCallback('sb_dmv:server:getProgress', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({ nextTest = 'none' }) return end

    local citizenid = Player.PlayerData.citizenid
    local hasLicense = HasOwnLicense(source, citizenid)

    -- Check if they ever earned a license (for reissue visibility)
    local dbRecord = MySQL.single.await('SELECT citizenid FROM dmv_licenses WHERE citizenid = ?', { citizenid })
    local hasRecord = dbRecord ~= nil

    if hasLicense then
        cb({ nextTest = 'done', hasRecord = true, message = 'You already have a driver\'s license' })
        return
    end

    local hasTheoryCert = exports['sb_inventory']:HasItem(source, 'dmv_theory_cert', 1)
    local hasParkingCert = exports['sb_inventory']:HasItem(source, 'dmv_parking_cert', 1)

    if hasParkingCert then
        cb({ nextTest = 'driving', hasRecord = hasRecord })
    elseif hasTheoryCert then
        cb({ nextTest = 'parking', hasRecord = hasRecord })
    else
        cb({ nextTest = 'theory', hasRecord = hasRecord })
    end
end)

-- Check if player can take theory exam
SB.Functions.CreateCallback('sb_dmv:server:checkTheoryEligibility', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({ eligible = false, reason = 'Player not found' }) return end

    local citizenid = Player.PlayerData.citizenid

    -- Check if already has their own license
    local hasLicense = HasOwnLicense(source, citizenid)
    if hasLicense then
        cb({ eligible = false, reason = 'You already have a driver\'s license' })
        return
    end

    -- Check if already has theory cert
    local hasTheoryCert = exports['sb_inventory']:HasItem(source, 'dmv_theory_cert', 1)
    if hasTheoryCert then
        cb({ eligible = false, reason = 'You already passed the theory exam. Proceed to the parking test.' })
        return
    end

    -- Check if already has parking cert (skip to driving)
    local hasParkingCert = exports['sb_inventory']:HasItem(source, 'dmv_parking_cert', 1)
    if hasParkingCert then
        cb({ eligible = false, reason = 'You already passed the parking test. Proceed to the driving test.' })
        return
    end

    -- Check cooldown
    local session = GetSession(citizenid)
    if session.theoryCooldown > os.time() then
        local remaining = session.theoryCooldown - os.time()
        local mins = math.ceil(remaining / 60)
        cb({ eligible = false, reason = 'Please wait ' .. mins .. ' minute(s) before retrying the theory exam' })
        return
    end

    -- Check money
    local cash = Player.PlayerData.money['cash'] or 0
    if cash < Config.TestCost then
        cb({ eligible = false, reason = 'Not enough cash. Exam costs $' .. Config.TestCost })
        return
    end

    -- Select 10 random questions
    local pool = {}
    for i = 1, #Config.Questions do
        pool[#pool + 1] = i
    end

    -- Shuffle
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local questions = {}
    local correctAnswers = {}
    for i = 1, math.min(10, #pool) do
        local idx = pool[i]
        local q = Config.Questions[idx]
        questions[#questions + 1] = {
            question = q.question,
            options = q.options
        }
        correctAnswers[#correctAnswers + 1] = q.correct
    end

    session.selectedQuestions = questions
    session.correctAnswers = correctAnswers

    cb({ eligible = true, questions = questions })
end)

-- Check if player can take parking test
SB.Functions.CreateCallback('sb_dmv:server:checkParkingEligibility', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({ eligible = false, reason = 'Player not found' }) return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    local hasLicense = HasOwnLicense(source, citizenid)
    if hasLicense then
        cb({ eligible = false, reason = 'You already have a driver\'s license' })
        return
    end

    local hasTheoryCert = exports['sb_inventory']:HasItem(source, 'dmv_theory_cert', 1)
    if not hasTheoryCert then
        cb({ eligible = false, reason = 'You must pass the theory exam first' })
        return
    end

    if session.practicalCooldown > os.time() then
        local remaining = session.practicalCooldown - os.time()
        local mins = math.ceil(remaining / 60)
        cb({ eligible = false, reason = 'Please wait ' .. mins .. ' minute(s) before retrying' })
        return
    end

    if session.practicalActive then
        cb({ eligible = false, reason = 'You are already in a test' })
        return
    end

    cb({ eligible = true })
end)

-- Check if player can take driving test
SB.Functions.CreateCallback('sb_dmv:server:checkDrivingEligibility', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({ eligible = false, reason = 'Player not found' }) return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    local hasLicense = HasOwnLicense(source, citizenid)
    if hasLicense then
        cb({ eligible = false, reason = 'You already have a driver\'s license' })
        return
    end

    local hasParkingCert = exports['sb_inventory']:HasItem(source, 'dmv_parking_cert', 1)
    if not hasParkingCert then
        cb({ eligible = false, reason = 'You must pass the parking test first' })
        return
    end

    if session.practicalCooldown > os.time() then
        local remaining = session.practicalCooldown - os.time()
        local mins = math.ceil(remaining / 60)
        cb({ eligible = false, reason = 'Please wait ' .. mins .. ' minute(s) before retrying' })
        return
    end

    if session.practicalActive then
        cb({ eligible = false, reason = 'You are already in a test' })
        return
    end

    cb({ eligible = true })
end)

-- ============================================================================
-- EVENTS
-- ============================================================================

-- Submit theory answers
RegisterNetEvent('sb_dmv:server:submitTheoryAnswers', function(answers)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    if not answers or type(answers) ~= 'table' or #answers ~= 10 then
        TriggerClientEvent('sb_notify', src, 'Invalid submission', 'error', 3000)
        return
    end

    if not session.correctAnswers or #session.correctAnswers ~= 10 then
        TriggerClientEvent('sb_notify', src, 'No active exam session', 'error', 3000)
        return
    end

    -- Deduct money
    local cash = Player.PlayerData.money['cash'] or 0
    if cash < Config.TestCost then
        TriggerClientEvent('sb_notify', src, 'Not enough cash', 'error', 3000)
        return
    end
    Player.Functions.RemoveMoney('cash', Config.TestCost, 'dmv-theory-exam')

    -- Calculate score
    local score = 0
    for i = 1, 10 do
        if tonumber(answers[i]) == session.correctAnswers[i] then
            score = score + 1
        end
    end

    local passed = score >= Config.PassingScore

    session.selectedQuestions = {}
    session.correctAnswers = {}

    -- Delay result by 10 seconds
    SetTimeout(10000, function()
        if passed then
            -- Give theory certificate
            exports['sb_inventory']:AddItem(src, 'dmv_theory_cert', 1, {}, nil, true)
            TriggerClientEvent('sb_dmv:client:theoryResult', src, true, score)
            TriggerClientEvent('sb_notify', src, 'Theory exam passed! Score: ' .. score .. '/10. You can now take the parking test.', 'success', 5000)
        else
            session.theoryCooldown = os.time() + Config.TheoryCooldown
            TriggerClientEvent('sb_dmv:client:theoryResult', src, false, score)
            TriggerClientEvent('sb_notify', src, 'Theory exam failed. Score: ' .. score .. '/10. Try again later.', 'error', 5000)
        end
    end)
end)

-- Start practical test (parking or driving)
RegisterNetEvent('sb_dmv:server:startPractical', function(testType)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    if session.practicalActive then return end

    -- Validate test type
    if testType ~= 'parking' and testType ~= 'driving' then return end

    session.practicalActive = true
    session.practicalType = testType
    session.penaltyPoints = 0
    penaltyRateLimits[citizenid] = {}

    -- Give test vehicle keys
    local keyMetadata = {
        plate = 'DMV TEST',
        vehicle = Config.TestVehicle,
        label = 'DMV Test Vehicle'
    }
    exports['sb_inventory']:AddItem(src, 'car_keys', 1, keyMetadata, nil, true)
end)

-- Report penalty from client (rate-limited)
RegisterNetEvent('sb_dmv:server:reportPenalty', function(penaltyType, points)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    if not session.practicalActive then return end

    local validTypes = { speeding = true, stopSign = true, trafficLight = true, damage = true, missedCheckpoint = true, fullStop = true, seatbelt = true }
    if not validTypes[penaltyType] then return end

    if not penaltyRateLimits[citizenid] then penaltyRateLimits[citizenid] = {} end
    local lastTime = penaltyRateLimits[citizenid][penaltyType] or 0
    if os.time() - lastTime < 5 then return end
    penaltyRateLimits[citizenid][penaltyType] = os.time()

    local serverPoints = Config.Penalties[penaltyType] or 0
    session.penaltyPoints = session.penaltyPoints + serverPoints

    TriggerClientEvent('sb_dmv:client:penaltyUpdate', src, session.penaltyPoints, penaltyType, serverPoints)

    -- Auto-fail if over max
    if session.penaltyPoints > Config.MaxPenaltyPoints then
        session.practicalActive = false
        session.practicalCooldown = os.time() + Config.PracticalCooldown
        penaltyRateLimits[citizenid] = nil
        RemoveTestKeys(src)
        TriggerClientEvent('sb_dmv:client:practicalResult', src, false, session.penaltyPoints, session.practicalType)
        TriggerClientEvent('sb_notify', src, 'Test FAILED - Too many penalties (' .. session.penaltyPoints .. ' points)', 'error', 5000)
        session.practicalType = nil
    end
end)

-- Complete practical test
RegisterNetEvent('sb_dmv:server:completePractical', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    if not session.practicalActive then return end

    local testType = session.practicalType
    session.practicalActive = false
    session.practicalType = nil
    penaltyRateLimits[citizenid] = nil

    -- Remove test vehicle keys
    RemoveTestKeys(src)

    if session.penaltyPoints <= Config.MaxPenaltyPoints then
        -- PASS
        if testType == 'parking' then
            -- Remove theory cert, give parking cert
            RemoveCert(src, 'dmv_theory_cert')
            exports['sb_inventory']:AddItem(src, 'dmv_parking_cert', 1, {}, nil, true)
            TriggerClientEvent('sb_dmv:client:practicalResult', src, true, session.penaltyPoints, 'parking')
            TriggerClientEvent('sb_notify', src, 'Parking test passed! You can now take the driving test.', 'success', 5000)

        elseif testType == 'driving' then
            -- Remove parking cert, give driver's license
            RemoveCert(src, 'dmv_parking_cert')

            local charinfo = Player.PlayerData.charinfo
            local metadata = {
                citizenid = citizenid,
                firstname = charinfo.firstname or 'Unknown',
                lastname = charinfo.lastname or 'Unknown',
                license_number = GenerateLicenseNumber(),
                issued = os.date('%Y-%m-%d'),
                class = 'C',
                dob = charinfo.birthdate or '01/01/2000',
                ownerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Unknown')
            }

            local success = exports['sb_inventory']:AddItem(src, 'car_license', 1, metadata)
            if success then
                -- Store in DB for reissue
                MySQL.insert('INSERT INTO dmv_licenses (citizenid, license_number, firstname, lastname, dob, issued, class) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE license_number = VALUES(license_number), issued = VALUES(issued)', {
                    citizenid,
                    metadata.license_number,
                    metadata.firstname,
                    metadata.lastname,
                    metadata.dob,
                    metadata.issued,
                    metadata.class
                })
                TriggerClientEvent('sb_dmv:client:practicalResult', src, true, session.penaltyPoints, 'driving')
                TriggerClientEvent('sb_notify', src, 'Congratulations! You passed! Driver\'s license issued!', 'success', 5000)
            else
                TriggerClientEvent('sb_notify', src, 'Failed to issue license. Please try again.', 'error', 3000)
            end
        end
    else
        -- FAIL
        session.practicalCooldown = os.time() + Config.PracticalCooldown
        TriggerClientEvent('sb_dmv:client:practicalResult', src, false, session.penaltyPoints, testType)
        TriggerClientEvent('sb_notify', src, 'Test failed. Penalty points: ' .. session.penaltyPoints, 'error', 5000)
    end
end)

-- Cancel practical test
RegisterNetEvent('sb_dmv:server:cancelPractical', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local session = GetSession(citizenid)

    if session.practicalActive then
        session.practicalActive = false
        session.practicalType = nil
        penaltyRateLimits[citizenid] = nil
        RemoveTestKeys(src)
        TriggerClientEvent('sb_notify', src, 'Test cancelled', 'info', 3000)
    end
end)

-- ============================================================================
-- LICENSE REISSUE
-- ============================================================================

SB.Functions.CreateCallback('sb_dmv:server:checkReissueEligibility', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({ eligible = false, reason = 'Player not found' }) return end

    local citizenid = Player.PlayerData.citizenid

    -- Check if they already have their own license
    local hasLicense = HasOwnLicense(source, citizenid)
    if hasLicense then
        cb({ eligible = false, reason = 'You already have a driver\'s license' })
        return
    end

    -- Check if they ever earned one
    local result = MySQL.single.await('SELECT * FROM dmv_licenses WHERE citizenid = ?', { citizenid })
    if not result then
        cb({ eligible = false, reason = 'No license on record. You need to pass all tests first.' })
        return
    end

    -- Check money
    local cash = Player.PlayerData.money['cash'] or 0
    if cash < Config.ReissueCost then
        cb({ eligible = false, reason = 'Not enough cash. Reissue costs $' .. Config.ReissueCost })
        return
    end

    cb({ eligible = true, record = result })
end)

RegisterNetEvent('sb_dmv:server:reissueLicense', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Double-check eligibility
    local hasLicense = HasOwnLicense(src, citizenid)
    if hasLicense then
        TriggerClientEvent('sb_notify', src, 'You already have a driver\'s license', 'error', 3000)
        return
    end

    local record = MySQL.single.await('SELECT * FROM dmv_licenses WHERE citizenid = ?', { citizenid })
    if not record then
        TriggerClientEvent('sb_notify', src, 'No license on record', 'error', 3000)
        return
    end

    local cash = Player.PlayerData.money['cash'] or 0
    if cash < Config.ReissueCost then
        TriggerClientEvent('sb_notify', src, 'Not enough cash. Reissue costs $' .. Config.ReissueCost, 'error', 3000)
        return
    end

    Player.Functions.RemoveMoney('cash', Config.ReissueCost, 'dmv-license-reissue')

    local metadata = {
        citizenid = citizenid,
        firstname = record.firstname,
        lastname = record.lastname,
        license_number = record.license_number,
        issued = os.date('%Y-%m-%d'),
        class = record.class,
        dob = record.dob,
        ownerName = record.firstname .. ' ' .. record.lastname
    }

    local success = exports['sb_inventory']:AddItem(src, 'car_license', 1, metadata)
    if success then
        TriggerClientEvent('sb_notify', src, 'License reissued! $' .. Config.ReissueCost .. ' charged.', 'success', 5000)
    else
        -- Refund
        Player.Functions.AddMoney('cash', Config.ReissueCost, 'dmv-reissue-refund')
        TriggerClientEvent('sb_notify', src, 'Failed to reissue license. Money refunded.', 'error', 3000)
    end
end)

-- ============================================================================
-- LICENSE CARD DISPLAY (item usage)
-- ============================================================================

AddEventHandler('sb_inventory:server:itemUsed', function(source, itemName, amount, metadata, category)
    if itemName ~= 'car_license' then return end

    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    if not metadata then
        TriggerClientEvent('sb_notify', source, 'This license is damaged', 'error', 3000)
        return
    end

    TriggerClientEvent('sb_dmv:client:viewLicense', source, metadata)
end)

-- ============================================================================
-- CLEANUP ON DISCONNECT
-- ============================================================================

AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    if dmvSessions[citizenid] then
        if dmvSessions[citizenid].practicalActive then
            RemoveTestKeys(src)
        end
        dmvSessions[citizenid].practicalActive = false
        dmvSessions[citizenid].practicalType = nil
    end
    penaltyRateLimits[citizenid] = nil
end)
