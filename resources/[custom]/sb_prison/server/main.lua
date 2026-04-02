-- ============================================================================
-- SB_PRISON - Server
-- Booking, sentencing, jail management, release
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- In-memory cache of active sentences: activeSentences[citizenid] = { ... }
-- Global so server/credits.lua and server/jobs.lua can access it
activeSentences = {}

-- ============================================================================
-- DATABASE AUTO-CREATE
-- ============================================================================

MySQL.ready(function()
    -- Sentence records
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sb_prison_sentences (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            jail_months INT NOT NULL DEFAULT 0,
            jail_seconds INT NOT NULL DEFAULT 0,
            start_time BIGINT DEFAULT NULL,
            release_time BIGINT DEFAULT NULL,
            time_remaining INT NOT NULL DEFAULT 0,
            charges TEXT,
            location ENUM('mrpd','bolingbroke') NOT NULL DEFAULT 'bolingbroke',
            status ENUM('booked','transporting','serving','released','escaped') NOT NULL DEFAULT 'booked',
            officer_citizenid VARCHAR(50),
            officer_name VARCHAR(100),
            mugshot_url TEXT DEFAULT NULL,
            released_by VARCHAR(100) DEFAULT NULL,
            released_at BIGINT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_cid (citizenid),
            INDEX idx_status (status)
        )
    ]])

    -- Confiscated items + appearance
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sb_prison_confiscated (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            items LONGTEXT NOT NULL,
            appearance LONGTEXT,
            stored_at BIGINT NOT NULL,
            returned TINYINT(1) DEFAULT 0,
            INDEX idx_cid (citizenid)
        )
    ]])

    -- Booking records (permanent history)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sb_prison_bookings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            citizen_name VARCHAR(100),
            mugshot TEXT DEFAULT NULL,
            mugshot_side TEXT DEFAULT NULL,
            charges TEXT,
            sentence_months INT DEFAULT 0,
            location ENUM('mrpd','bolingbroke') NOT NULL,
            officer_citizenid VARCHAR(50),
            officer_name VARCHAR(100),
            booking_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_cid (citizenid)
        )
    ]])

    -- Mugshot photos (taken at camera station, linked to suspect)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sb_prison_mugshots (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            url TEXT NOT NULL,
            officer_citizenid VARCHAR(50),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_cid (citizenid)
        )
    ]])

    -- Add 'served' column to sb_police_criminal_records if missing (tracks jail served status)
    local servedCol = MySQL.query.await(
        "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'sb_police_criminal_records' AND COLUMN_NAME = 'served'"
    )
    if not servedCol or #servedCol == 0 then
        MySQL.query.await('ALTER TABLE sb_police_criminal_records ADD COLUMN served TINYINT(1) DEFAULT 0')
        print('[sb_prison] Added "served" column to sb_police_criminal_records')
    end

    -- Add 'on_hold' to status ENUM on sb_prison_sentences (for dashboard booking)
    local statusCol = MySQL.query.await(
        "SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'sb_prison_sentences' AND COLUMN_NAME = 'status'"
    )
    if statusCol and statusCol[1] and not string.find(statusCol[1].COLUMN_TYPE, 'on_hold') then
        MySQL.query.await("ALTER TABLE sb_prison_sentences MODIFY COLUMN status ENUM('booked','on_hold','transporting','serving','releasing','released','escaped') NOT NULL DEFAULT 'booked'")
        print('[sb_prison] Added "on_hold" to status ENUM')
    end

    -- Add 'releasing' to ENUM if missing (release exit flow)
    if statusCol and statusCol[1] and not string.find(statusCol[1].COLUMN_TYPE, 'releasing') then
        MySQL.query.await("ALTER TABLE sb_prison_sentences MODIFY COLUMN status ENUM('booked','on_hold','transporting','serving','releasing','released','escaped') NOT NULL DEFAULT 'booked'")
        print('[sb_prison] Added "releasing" to status ENUM')
    end

    -- Load active sentences into cache
    local rows = MySQL.query.await(
        "SELECT * FROM sb_prison_sentences WHERE status IN ('booked','on_hold','transporting','serving','releasing')"
    )
    if rows then
        local now = os.time()
        for _, row in ipairs(rows) do
            if row.status == 'serving' and row.release_time and now >= row.release_time then
                -- Expired while server was off - release
                ReleasePlayerOffline(row.citizenid, 'time_served')
            else
                -- Still active
                if row.status == 'serving' and row.release_time then
                    row.time_remaining = math.max(0, row.release_time - now)
                end
                activeSentences[row.citizenid] = {
                    id = row.id,
                    citizenid = row.citizenid,
                    months = row.jail_months,
                    seconds = row.jail_seconds,
                    startTime = row.start_time,
                    releaseTime = row.release_time,
                    timeRemaining = row.time_remaining,
                    charges = row.charges,
                    location = row.location,
                    status = row.status,
                    officerCid = row.officer_citizenid,
                    officerName = row.officer_name,
                    mugshotUrl = row.mugshot_url,
                }
            end
        end
    end

    print('^2[sb_prison]^7 Database tables ready, loaded ' .. TableCount(activeSentences) .. ' active sentences')
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

function TableCount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function GetPlayerCitizenId(source)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return nil end
    return Player.PlayerData.citizenid
end

function GetPlayerName(source)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return 'Unknown' end
    local charinfo = Player.PlayerData.charinfo
    return (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')
end

function IsAdmin(source)
    return IsPlayerAceAllowed(source, 'command.sb_admin')
end

function NotifyPlayer(source, msg, type, duration)
    TriggerClientEvent('sb_prison:client:notify', source, msg, type, duration or 5000)
end

function GetSourceByCitizenId(citizenid)
    local Player = SB.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        return Player.PlayerData.source
    end
    return nil
end

-- ============================================================================
-- UPLOAD CONFIG (reuse sb_phone's fivemanager token for mugshots)
-- ============================================================================

SB.Functions.CreateCallback('sb_prison:server:getUploadConfig', function(source, cb)
    local method = Config.UploadMethod or 'fivemanager'
    if method == 'fivemanager' then
        local token = GetConvar('sb_phone_fivemanager_token', '')
        if token ~= '' then
            cb({
                url = 'https://api.fivemanage.com/api/image',
                field = 'file',
                headers = { ['Authorization'] = token },
                encoding = 'jpg',
                quality = Config.ScreenshotQuality or 0.85
            })
            return
        end
    end
    cb(nil)
end)

-- ============================================================================
-- MUGSHOT: SAVE PHOTO (from camera station)
-- ============================================================================

-- Save photo (generic — linked to officer, not suspect)
RegisterNetEvent('sb_prison:server:saveMugshot', function(url)
    local officerSrc = source
    local officerPlayer = SB.Functions.GetPlayer(officerSrc)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end
    if not url or url == '' then return end

    local officerCid = officerPlayer.PlayerData.citizenid

    MySQL.insert('INSERT INTO sb_prison_mugshots (citizenid, url, officer_citizenid) VALUES (?, ?, ?)',
        { '', url, officerCid }
    )
end)

-- Fetch recent photos for the officer to browse in the dashboard picker
RegisterNetEvent('sb_prison:server:getMugshots', function()
    local src = source
    local officerPlayer = SB.Functions.GetPlayer(src)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end

    local rows = MySQL.query.await(
        'SELECT id, url, created_at FROM sb_prison_mugshots ORDER BY id DESC LIMIT 20'
    ) or {}

    local photos = {}
    for _, row in ipairs(rows) do
        table.insert(photos, {
            id = row.id,
            url = row.url,
            createdAt = tostring(row.created_at or ''),
        })
    end

    TriggerClientEvent('sb_prison:client:nui:mugshotList', src, photos)
end)

-- ============================================================================
-- BOOKING
-- ============================================================================

RegisterNetEvent('sb_prison:server:bookPlayer', function(targetSrc, mugshotUrl, mugshotSideUrl)
    local officerSrc = source
    local officerPlayer = SB.Functions.GetPlayer(officerSrc)
    local targetPlayer = SB.Functions.GetPlayer(targetSrc)

    if not officerPlayer or not targetPlayer then
        NotifyPlayer(officerSrc, 'Invalid player', 'error')
        return
    end

    -- Verify officer is police and on duty
    if officerPlayer.PlayerData.job.name ~= 'police' then return end

    local targetCid = targetPlayer.PlayerData.citizenid
    local targetCharinfo = targetPlayer.PlayerData.charinfo
    local targetName = (targetCharinfo.firstname or 'Unknown') .. ' ' .. (targetCharinfo.lastname or '')
    local officerCid = officerPlayer.PlayerData.citizenid
    local officerName = GetPlayerName(officerSrc)

    -- Check if already jailed
    if activeSentences[targetCid] then
        NotifyPlayer(officerSrc, 'Suspect is already serving a sentence', 'error')
        return
    end

    -- Get pending jail time from criminal records (sum of unserved jail_time)
    local records = MySQL.query.await(
        'SELECT charges, jail_time FROM sb_police_criminal_records WHERE citizenid = ? AND jail_time > 0 AND (served = 0 OR served IS NULL)',
        { targetCid }
    )

    local totalMonths = 0
    local chargesList = {}
    if records then
        for _, rec in ipairs(records) do
            totalMonths = totalMonths + (rec.jail_time or 0)
            table.insert(chargesList, (rec.charges or 'Unknown charge') .. ' (' .. (rec.jail_time or 0) .. 'mo)')
        end
    end

    if totalMonths <= 0 then
        -- Self-booking (dummy test mode): use 5 months as test sentence
        if officerSrc == targetSrc then
            totalMonths = 5
            chargesList = { 'Test booking (5mo)' }
            print('[sb_prison] Dummy test mode: officer self-booking with 5 test months')
        else
            NotifyPlayer(officerSrc, 'No pending jail time for this suspect', 'error')
            return
        end
    end

    local totalSeconds = totalMonths * Config.MonthToSeconds
    local location = totalSeconds < Config.ShortSentenceThreshold and 'mrpd' or 'bolingbroke'
    local chargesText = table.concat(chargesList, ', ')

    -- Create booking record
    MySQL.insert.await(
        'INSERT INTO sb_prison_bookings (citizenid, citizen_name, mugshot, mugshot_side, charges, sentence_months, location, officer_citizenid, officer_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { targetCid, targetName, mugshotUrl, mugshotSideUrl, chargesText, totalMonths, location, officerCid, officerName }
    )

    -- Create sentence record
    local sentenceId
    if location == 'mrpd' then
        -- MRPD: timer starts immediately after booking
        local now = os.time()
        sentenceId = MySQL.insert.await(
            'INSERT INTO sb_prison_sentences (citizenid, jail_months, jail_seconds, start_time, release_time, time_remaining, charges, location, status, officer_citizenid, officer_name, mugshot_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { targetCid, totalMonths, totalSeconds, now, now + totalSeconds, totalSeconds, chargesText, location, 'serving', officerCid, officerName, mugshotUrl }
        )
    else
        -- Bolingbroke: timer starts on arrival (status = 'booked' for now)
        sentenceId = MySQL.insert.await(
            'INSERT INTO sb_prison_sentences (citizenid, jail_months, jail_seconds, time_remaining, charges, location, status, officer_citizenid, officer_name, mugshot_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { targetCid, totalMonths, totalSeconds, totalSeconds, chargesText, location, 'booked', officerCid, officerName, mugshotUrl }
        )
    end

    -- Mark criminal records as served
    MySQL.query.await(
        'UPDATE sb_police_criminal_records SET served = 1 WHERE citizenid = ? AND jail_time > 0 AND (served = 0 OR served IS NULL)',
        { targetCid }
    )

    -- Cache
    activeSentences[targetCid] = {
        id = sentenceId,
        citizenid = targetCid,
        months = totalMonths,
        seconds = totalSeconds,
        startTime = location == 'mrpd' and os.time() or nil,
        releaseTime = location == 'mrpd' and (os.time() + totalSeconds) or nil,
        timeRemaining = totalSeconds,
        charges = chargesText,
        location = location,
        status = location == 'mrpd' and 'serving' or 'booked',
        officerCid = officerCid,
        officerName = officerName,
        mugshotUrl = mugshotUrl,
    }

    -- Initialize prison credits
    InitCredits(targetCid)

    -- Confiscate inventory + save appearance
    -- MRPD: confiscate now. Bolingbroke: deferred to intake step 1
    if location == 'mrpd' then
        ConfiscateAndOutfit(targetSrc, targetCid)
    else
        TriggerClientEvent('sb_prison:client:removeAllWeapons', targetSrc)
    end

    -- Tell client booking is done (NO teleport — officer escorts them manually)
    if location == 'mrpd' then
        TriggerClientEvent('sb_prison:client:bookingComplete', targetSrc, {
            location = 'mrpd',
            timeRemaining = totalSeconds,
            months = totalMonths,
            charges = chargesText,
        })
        NotifyPlayer(officerSrc, targetName .. ' booked — escort to MRPD cell (' .. totalMonths .. ' months)', 'success')
    else
        TriggerClientEvent('sb_prison:client:bookingComplete', targetSrc, {
            location = 'bolingbroke',
            timeRemaining = totalSeconds,
            months = totalMonths,
            charges = chargesText,
        })
        NotifyPlayer(officerSrc, targetName .. ' booked — transport to Bolingbroke required (' .. totalMonths .. ' months)', 'info')
        NotifyPlayer(targetSrc, 'You have been booked. Awaiting transport to Bolingbroke Penitentiary.', 'info')
    end
end)

-- ============================================================================
-- CONFISCATE INVENTORY & SAVE APPEARANCE
-- ============================================================================

-- skipAppearance: true when client already saved appearance (intake flow)
function ConfiscateAndOutfit(src, citizenid, skipAppearance)
    -- sb_inventory stores items in its own Inventories table, NOT in PlayerData.items
    -- Read from DB (players.inventory column) to get full item list
    local result = MySQL.single.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local savedItems = {}

    if result and result.inventory then
        local items = json.decode(result.inventory)
        if items then
            for slot, item in pairs(items) do
                local slotNum = tonumber(slot)
                if item and item.name then
                    table.insert(savedItems, {
                        name = item.name,
                        amount = item.amount or 1,
                        metadata = item.metadata or item.info,
                        slot = slotNum or 1
                    })
                    -- Remove via export (updates in-memory Inventories + client UI)
                    exports['sb_inventory']:RemoveItem(src, item.name, item.amount or 1, slotNum)
                end
            end
        end
    end

    -- Remove all weapons
    TriggerClientEvent('sb_prison:client:removeAllWeapons', src)

    -- Save appearance (client will send it back)
    -- Skip when client already saved appearance before stripping (intake Step 1)
    if not skipAppearance then
        TriggerClientEvent('sb_prison:client:saveAppearance', src)
    end

    -- Save confiscated items to DB
    MySQL.insert.await(
        'INSERT INTO sb_prison_confiscated (citizenid, items, stored_at) VALUES (?, ?, ?)',
        { citizenid, json.encode(savedItems), os.time() }
    )
end

-- Client sends appearance data back
RegisterNetEvent('sb_prison:server:saveAppearance', function(appearance)
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    -- Update the most recent confiscated record with appearance
    MySQL.query.await(
        'UPDATE sb_prison_confiscated SET appearance = ? WHERE citizenid = ? AND returned = 0 ORDER BY id DESC LIMIT 1',
        { json.encode(appearance), citizenid }
    )
end)

-- ============================================================================
-- BOLINGBROKE ARRIVAL (officer checks in prisoner → intake starts)
-- ============================================================================

RegisterNetEvent('sb_prison:server:prisonerArrived', function(prisonerSrc)
    local officerSrc = source
    local officerPlayer = SB.Functions.GetPlayer(officerSrc)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end

    local prisonerCid = GetPlayerCitizenId(prisonerSrc)
    if not prisonerCid then
        NotifyPlayer(officerSrc, 'Invalid prisoner', 'error')
        return
    end

    local sentence = activeSentences[prisonerCid]
    if not sentence then
        NotifyPlayer(officerSrc, 'No active sentence found', 'error')
        return
    end

    if sentence.status ~= 'booked' and sentence.status ~= 'on_hold' and sentence.status ~= 'transporting' then
        NotifyPlayer(officerSrc, 'Prisoner is already checked in', 'error')
        return
    end

    -- Mark as transporting (intake in progress, timer not started yet)
    sentence.status = 'transporting'
    MySQL.query.await(
        'UPDATE sb_prison_sentences SET status = ? WHERE id = ?',
        { 'transporting', sentence.id }
    )

    -- Tell prisoner client to start the intake process (no timer yet)
    TriggerClientEvent('sb_prison:client:startSentence', prisonerSrc, {
        location = 'bolingbroke',
        timeRemaining = sentence.timeRemaining or sentence.seconds,
        months = sentence.months,
        charges = sentence.charges,
    })

    local prisonerName = GetPlayerName(prisonerSrc)
    NotifyPlayer(officerSrc, prisonerName .. ' registered — intake process started.', 'success')
    NotifyPlayer(prisonerSrc, 'Follow the intake steps to enter Bolingbroke.', 'info')
end)

-- ============================================================================
-- INTAKE STEP 1: DEPOSIT (prisoner reached deposit area)
-- ============================================================================

RegisterNetEvent('sb_prison:server:intakeDeposit', function(appearanceData)
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'transporting' then return end

    -- Confiscate inventory (skip appearance trigger — we save it directly below)
    ConfiscateAndOutfit(src, citizenid, true)

    -- Save appearance directly into the confiscated record (no race condition)
    if appearanceData then
        MySQL.query.await(
            'UPDATE sb_prison_confiscated SET appearance = ? WHERE citizenid = ? AND returned = 0 ORDER BY id DESC LIMIT 1',
            { json.encode(appearanceData), citizenid }
        )
    end
end)

-- ============================================================================
-- INTAKE STEP 4: COMPLETE (prisoner entered the yard)
-- ============================================================================

RegisterNetEvent('sb_prison:server:intakeComplete', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'transporting' then return end

    -- Start the timer NOW
    local now = os.time()
    local timeRemaining = sentence.timeRemaining or sentence.seconds
    sentence.startTime = now
    sentence.releaseTime = now + timeRemaining
    sentence.status = 'serving'

    -- Update DB
    MySQL.query.await(
        'UPDATE sb_prison_sentences SET start_time = ?, release_time = ?, status = ? WHERE id = ?',
        { now, now + timeRemaining, 'serving', sentence.id }
    )
end)

-- ============================================================================
-- RELEASE EXIT PROCESS (Bolingbroke 3-step walkout)
-- ============================================================================

-- Step 1: Restore civilian clothes (no returned filter — appearance restore is idempotent)
RegisterNetEvent('sb_prison:server:releaseClothes', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'releasing' then return end

    local confiscated = MySQL.single.await(
        'SELECT * FROM sb_prison_confiscated WHERE citizenid = ? ORDER BY id DESC LIMIT 1',
        { citizenid }
    )
    if confiscated and confiscated.appearance then
        local appearance = json.decode(confiscated.appearance)
        if appearance then
            TriggerClientEvent('sb_prison:client:restoreAppearance', src, appearance)
        end
    end
end)

-- Step 2: Restore personal items (mark returned FIRST to prevent duplication on reconnect)
RegisterNetEvent('sb_prison:server:releaseItems', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'releasing' then return end

    local confiscated = MySQL.single.await(
        'SELECT * FROM sb_prison_confiscated WHERE citizenid = ? AND returned = 0 ORDER BY id DESC LIMIT 1',
        { citizenid }
    )
    if confiscated then
        -- Mark returned IMMEDIATELY to prevent duplication if player disconnects
        MySQL.query.await(
            'UPDATE sb_prison_confiscated SET returned = 1 WHERE id = ?',
            { confiscated.id }
        )
        -- Now give items back
        if confiscated.items then
            local items = json.decode(confiscated.items) or {}
            for _, item in ipairs(items) do
                exports['sb_inventory']:AddItem(src, item.name, item.amount, item.metadata, nil, true)
            end
        end
    end
end)

-- Step 3: Confirm release (finalize DB, clear cache)
RegisterNetEvent('sb_prison:server:releaseConfirm', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'releasing' then return end

    -- Mark sentence as released
    MySQL.query.await(
        'UPDATE sb_prison_sentences SET status = ?, released_by = ?, released_at = ?, time_remaining = 0 WHERE id = ?',
        { 'released', 'time_served', os.time(), sentence.id }
    )

    -- Items already marked returned in releaseItems step

    -- Delete prison credits
    DeleteCredits(citizenid)

    -- Clear cache
    activeSentences[citizenid] = nil

    print('[sb_prison] Released ' .. citizenid .. ' via exit process')
end)

-- ============================================================================
-- RELEASE (instant — MRPD, admin, offline)
-- ============================================================================

function ReleasePlayer(citizenid, releasedBy)
    local sentence = activeSentences[citizenid]
    if not sentence then return false end

    -- Update DB
    MySQL.query.await(
        'UPDATE sb_prison_sentences SET status = ?, released_by = ?, released_at = ?, time_remaining = 0 WHERE id = ?',
        { 'released', releasedBy or 'time_served', os.time(), sentence.id }
    )

    -- Restore inventory
    RestoreInventory(citizenid)

    -- Delete prison credits
    DeleteCredits(citizenid)

    -- Remove from cache
    activeSentences[citizenid] = nil

    -- If player is online, trigger release
    local src = GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('sb_prison:client:release', src, sentence.location)
        NotifyPlayer(src, 'You have been released from prison', 'success')
    end

    return true
end

-- For offline release (server was off when sentence expired)
function ReleasePlayerOffline(citizenid, releasedBy)
    MySQL.query.await(
        "UPDATE sb_prison_sentences SET status = 'released', released_by = ?, released_at = ?, time_remaining = 0 WHERE citizenid = ? AND status IN ('booked','on_hold','transporting','serving','releasing')",
        { releasedBy or 'time_served', os.time(), citizenid }
    )
    RestoreInventory(citizenid)
    DeleteCredits(citizenid)
    activeSentences[citizenid] = nil
end

-- ============================================================================
-- RESTORE INVENTORY & APPEARANCE
-- ============================================================================

function RestoreInventory(citizenid)
    local confiscated = MySQL.single.await(
        'SELECT * FROM sb_prison_confiscated WHERE citizenid = ? AND returned = 0 ORDER BY id DESC LIMIT 1',
        { citizenid }
    )
    if not confiscated then return end

    local src = GetSourceByCitizenId(citizenid)
    if src then
        -- Restore items
        local items = json.decode(confiscated.items) or {}
        for _, item in ipairs(items) do
            exports['sb_inventory']:AddItem(src, item.name, item.amount, item.metadata, nil, true)
        end

        -- Restore appearance
        if confiscated.appearance then
            local appearance = json.decode(confiscated.appearance)
            if appearance then
                TriggerClientEvent('sb_prison:client:restoreAppearance', src, appearance)
            end
        end
    end

    -- Mark as returned
    MySQL.query.await(
        'UPDATE sb_prison_confiscated SET returned = 1 WHERE id = ?',
        { confiscated.id }
    )
end

-- ============================================================================
-- RELEASE LOOP (every 10 seconds)
-- ============================================================================

CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for citizenid, sentence in pairs(activeSentences) do
            if sentence.status == 'serving' and sentence.releaseTime and now >= sentence.releaseTime then
                local src = GetSourceByCitizenId(citizenid)
                if sentence.location == 'bolingbroke' and src then
                    -- Bolingbroke online: start release exit process
                    print('[sb_prison] Starting release process for ' .. citizenid)
                    sentence.status = 'releasing'
                    MySQL.query.await(
                        'UPDATE sb_prison_sentences SET status = ? WHERE id = ?',
                        { 'releasing', sentence.id }
                    )
                    TriggerClientEvent('sb_prison:client:startRelease', src)
                    NotifyPlayer(src, 'Your sentence is complete. Follow the release steps.', 'success')
                else
                    -- MRPD or offline: instant release
                    print('[sb_prison] Auto-releasing ' .. citizenid .. ' (time served)')
                    ReleasePlayer(citizenid, 'time_served')
                end
            end
        end
    end
end)

-- ============================================================================
-- RECONNECT HANDLING
-- ============================================================================

AddEventHandler('SB:Server:OnPlayerLoaded', function(source, PlayerObj)
    local citizenid = PlayerObj.PlayerData.citizenid
    local sentence = activeSentences[citizenid]

    if not sentence then return end

    Wait(3000) -- Let client fully load

    local now = os.time()

    if sentence.status == 'serving' and sentence.releaseTime then
        if now >= sentence.releaseTime then
            -- Sentence expired while offline
            ReleasePlayer(citizenid, 'time_served')
            return
        end

        -- Still serving, re-jail with remaining time
        local remaining = sentence.releaseTime - now
        sentence.timeRemaining = remaining

        -- Re-confiscate (they reconnected with clean state)
        ConfiscateAndOutfit(source, citizenid)

        TriggerClientEvent('sb_prison:client:startSentence', source, {
            location = sentence.location,
            timeRemaining = remaining,
            months = sentence.months,
            charges = sentence.charges,
            reconnect = true,
        })

        -- Sync prison credits on reconnect
        local credits = GetCredits(citizenid)
        TriggerClientEvent('sb_prison:client:syncCredits', source, credits)
    elseif sentence.status == 'releasing' then
        -- Was mid-release — check how far they got
        local confiscated = MySQL.single.await(
            'SELECT returned, appearance FROM sb_prison_confiscated WHERE citizenid = ? ORDER BY id DESC LIMIT 1',
            { citizenid }
        )
        local itemsReturned = confiscated and confiscated.returned == 1

        if itemsReturned then
            -- Items already given back — skip to exit step (3), restore appearance
            if confiscated and confiscated.appearance then
                local appearance = json.decode(confiscated.appearance)
                if appearance then
                    TriggerClientEvent('sb_prison:client:restoreAppearance', source, appearance)
                end
            end
            TriggerClientEvent('sb_prison:client:startRelease', source, true, 3)
        else
            -- Items not returned yet — restart full release from step 1
            TriggerClientEvent('sb_prison:client:startRelease', source, true, 1)
        end
        NotifyPlayer(source, 'Complete the release process to exit.', 'info')

    elseif sentence.status == 'booked' or sentence.status == 'on_hold' or sentence.status == 'transporting' then
        -- Was booked/on_hold/mid-intake but never completed — reset to on_hold
        if sentence.status == 'transporting' then
            sentence.status = 'on_hold'
            MySQL.query.await(
                'UPDATE sb_prison_sentences SET status = ? WHERE id = ?',
                { 'on_hold', sentence.id }
            )
        end
        -- Only remove weapons for bolingbroke on_hold (items confiscated at intake)
        if sentence.location == 'bolingbroke' then
            TriggerClientEvent('sb_prison:client:removeAllWeapons', source)
        else
            ConfiscateAndOutfit(source, citizenid)
        end
        TriggerClientEvent('sb_prison:client:awaitTransport', source, {
            location = sentence.location,
            timeRemaining = sentence.timeRemaining,
            months = sentence.months,
            charges = sentence.charges,
            reconnect = true,
        })
    end
end)

-- ============================================================================
-- PLAYER DROPPED - save remaining time
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence then return end

    if sentence.status == 'serving' and sentence.releaseTime then
        local remaining = math.max(0, sentence.releaseTime - os.time())
        sentence.timeRemaining = remaining
        MySQL.query(
            'UPDATE sb_prison_sentences SET time_remaining = ? WHERE id = ?',
            { remaining, sentence.id }
        )
    end
end)

-- ============================================================================
-- ADMIN/TEST COMMANDS
-- ============================================================================

-- /jail [id] [months] [reason] — bypass booking, teleport directly
RegisterCommand('jail', function(source, args)
    local src = source

    if Config.AdminOnly and not IsAdmin(src) then
        NotifyPlayer(src, 'Admin only command', 'error')
        return
    end

    local targetSrc = tonumber(args[1])
    local months = tonumber(args[2])
    local reason = args[3] or 'Admin jail'

    if not targetSrc or not months or months <= 0 then
        NotifyPlayer(src, 'Usage: /jail [serverid] [months] [reason]', 'error')
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetSrc)
    if not targetPlayer then
        NotifyPlayer(src, 'Player not found', 'error')
        return
    end

    local targetCid = targetPlayer.PlayerData.citizenid
    local targetName = GetPlayerName(targetSrc)

    -- Check if already jailed
    if activeSentences[targetCid] then
        NotifyPlayer(src, 'Player is already jailed', 'error')
        return
    end

    local totalSeconds = months * Config.MonthToSeconds
    local location = totalSeconds < Config.ShortSentenceThreshold and 'mrpd' or 'bolingbroke'
    local now = os.time()
    local officerName = src == 0 and 'Console' or GetPlayerName(src)
    local officerCid = src == 0 and 'console' or GetPlayerCitizenId(src)

    -- Create sentence record (start immediately)
    local sentenceId = MySQL.insert.await(
        'INSERT INTO sb_prison_sentences (citizenid, jail_months, jail_seconds, start_time, release_time, time_remaining, charges, location, status, officer_citizenid, officer_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { targetCid, months, totalSeconds, now, now + totalSeconds, totalSeconds, reason, location, 'serving', officerCid, officerName }
    )

    -- Cache
    activeSentences[targetCid] = {
        id = sentenceId,
        citizenid = targetCid,
        months = months,
        seconds = totalSeconds,
        startTime = now,
        releaseTime = now + totalSeconds,
        timeRemaining = totalSeconds,
        charges = reason,
        location = location,
        status = 'serving',
        officerCid = officerCid,
        officerName = officerName,
    }

    -- Initialize prison credits
    InitCredits(targetCid)

    -- Confiscate
    ConfiscateAndOutfit(targetSrc, targetCid)

    -- Tell client (bypass mode - teleport directly)
    TriggerClientEvent('sb_prison:client:startSentence', targetSrc, {
        location = location,
        timeRemaining = totalSeconds,
        months = months,
        charges = reason,
        bypass = true, -- signals direct teleport
    })

    NotifyPlayer(targetSrc, 'You have been jailed for ' .. months .. ' months: ' .. reason, 'error')
    if src ~= 0 then
        NotifyPlayer(src, 'Jailed ' .. targetName .. ' for ' .. months .. ' months at ' .. location, 'success')
    end
    print('[sb_prison] ' .. officerName .. ' jailed ' .. targetName .. ' (' .. targetCid .. ') for ' .. months .. ' months at ' .. location)
end, false)

-- /unjail [id] — admin release (restores items + appearance properly)
RegisterCommand('unjail', function(source, args)
    local src = source

    if Config.AdminOnly and not IsAdmin(src) then
        NotifyPlayer(src, 'Admin only command', 'error')
        return
    end

    local targetSrc = tonumber(args[1])
    if not targetSrc then
        NotifyPlayer(src, 'Usage: /unjail [serverid]', 'error')
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetSrc)
    if not targetPlayer then
        NotifyPlayer(src, 'Player not found', 'error')
        return
    end

    local targetCid = targetPlayer.PlayerData.citizenid
    local sentence = activeSentences[targetCid]
    if not sentence then
        NotifyPlayer(src, 'Player is not jailed', 'error')
        return
    end

    local releasedBy = src == 0 and 'Console' or GetPlayerName(src)
    local targetName = GetPlayerName(targetSrc)

    -- For Bolingbroke serving/releasing: start the release walkout process
    if sentence.location == 'bolingbroke' and (sentence.status == 'serving' or sentence.status == 'releasing') then
        sentence.status = 'releasing'
        MySQL.query.await(
            'UPDATE sb_prison_sentences SET status = ? WHERE id = ?',
            { 'releasing', sentence.id }
        )
        TriggerClientEvent('sb_prison:client:startRelease', targetSrc)
        NotifyPlayer(targetSrc, 'You are being released. Follow the exit steps.', 'success')
        if src ~= 0 then
            NotifyPlayer(src, 'Release process started for ' .. targetName, 'success')
        end
    else
        -- MRPD, on_hold, transporting: instant release (no items to walk through)
        ReleasePlayer(targetCid, releasedBy)
        NotifyPlayer(targetSrc, 'You have been released from prison', 'success')
        if src ~= 0 then
            NotifyPlayer(src, 'Released ' .. targetName, 'success')
        end
    end

    print('[sb_prison] ' .. releasedBy .. ' released ' .. targetName .. ' from prison')
end, false)

-- /prisontest — debug info
RegisterCommand('prisontest', function(source, args)
    local src = source
    if Config.AdminOnly and not IsAdmin(src) then return end

    local citizenid = GetPlayerCitizenId(src)
    local sentence = activeSentences[citizenid]

    if sentence then
        local remaining = 0
        if sentence.releaseTime then
            remaining = math.max(0, sentence.releaseTime - os.time())
        end
        NotifyPlayer(src, string.format('Jailed: %s | Location: %s | Status: %s | Remaining: %ds | Months: %d',
            sentence.citizenid, sentence.location, sentence.status, remaining, sentence.months), 'info', 10000)
    else
        NotifyPlayer(src, 'Not jailed. Active sentences: ' .. TableCount(activeSentences), 'info')
    end
end, false)

-- ============================================================================
-- DASHBOARD: SEARCH SUSPECT
-- ============================================================================

RegisterNetEvent('sb_prison:server:searchSuspect', function(query)
    local src = source
    local officerPlayer = SB.Functions.GetPlayer(src)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end

    if not query or #query < 2 then
        TriggerClientEvent('sb_prison:client:nui:searchResults', src, {})
        return
    end

    -- Search by citizenid or by name in charinfo JSON
    local likeQuery = '%' .. query .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo FROM players
        WHERE citizenid LIKE ?
        OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
        OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
        OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
        LIMIT 10
    ]], { likeQuery, likeQuery, likeQuery, likeQuery })

    local results = {}
    if rows then
        for _, row in ipairs(rows) do
            local charinfo = json.decode(row.charinfo) or {}
            table.insert(results, {
                citizenid = row.citizenid,
                firstname = charinfo.firstname or 'Unknown',
                lastname = charinfo.lastname or '',
                dob = charinfo.birthdate or 'N/A',
                gender = charinfo.gender or 'male',
            })
        end
    end

    TriggerClientEvent('sb_prison:client:nui:searchResults', src, results)
end)

-- ============================================================================
-- DASHBOARD: GET SUSPECT PROFILE
-- ============================================================================

RegisterNetEvent('sb_prison:server:getSuspectProfile', function(citizenid)
    local src = source
    local officerPlayer = SB.Functions.GetPlayer(src)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end

    if not citizenid then
        TriggerClientEvent('sb_prison:client:nui:suspectProfile', src, nil)
        return
    end

    -- Get player data
    local playerRow = MySQL.single.await('SELECT charinfo, job FROM players WHERE citizenid = ?', { citizenid })
    if not playerRow then
        TriggerClientEvent('sb_prison:client:nui:suspectProfile', src, nil)
        return
    end

    local charinfo = json.decode(playerRow.charinfo) or {}
    local jobData = json.decode(playerRow.job) or {}

    -- Get criminal records
    local records = MySQL.query.await(
        'SELECT id, charges, jail_time, fine, officer_name, created_at, served FROM sb_police_criminal_records WHERE citizenid = ? ORDER BY id DESC',
        { citizenid }
    ) or {}

    local profile = {
        citizenid = citizenid,
        firstname = charinfo.firstname or 'Unknown',
        lastname = charinfo.lastname or '',
        dob = charinfo.birthdate or 'N/A',
        gender = charinfo.gender or 'male',
        phone = charinfo.phone or '',
        job = jobData.label or 'Unemployed',
        records = {},
    }

    for _, rec in ipairs(records) do
        table.insert(profile.records, {
            id = rec.id,
            charges = rec.charges or 'Unknown',
            jail_time = rec.jail_time or 0,
            fine = rec.fine or 0,
            officer_name = rec.officer_name or 'Unknown',
            created_at = tostring(rec.created_at or ''),
            served = (rec.served == 1),
        })
    end

    TriggerClientEvent('sb_prison:client:nui:suspectProfile', src, profile)
end)

-- ============================================================================
-- DASHBOARD: REGISTER BOOKING
-- ============================================================================

RegisterNetEvent('sb_prison:server:bookPlayerFromDashboard', function(data)
    local officerSrc = source
    local officerPlayer = SB.Functions.GetPlayer(officerSrc)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end

    local citizenid = data.citizenid
    local totalMonths = tonumber(data.totalMonths) or 0
    local totalSeconds = tonumber(data.totalSeconds) or 0
    local location = data.location or 'mrpd'
    local charges = data.charges or ''
    local recordIds = data.recordIds or {}
    local mugshotFront = data.mugshotFront
    local mugshotSide = data.mugshotSide

    if totalMonths <= 0 then
        NotifyPlayer(officerSrc, 'Invalid sentence', 'error')
        return
    end

    -- Check if already jailed
    if activeSentences[citizenid] then
        NotifyPlayer(officerSrc, 'Suspect is already serving a sentence', 'error')
        return
    end

    local officerCid = officerPlayer.PlayerData.citizenid
    local officerName = GetPlayerName(officerSrc)

    -- Get target source (may be online or offline)
    local targetSrc = GetSourceByCitizenId(citizenid)

    -- Get suspect name
    local playerRow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    local targetName = 'Unknown'
    if playerRow and playerRow.charinfo then
        local charinfo = json.decode(playerRow.charinfo) or {}
        targetName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')
    end

    -- Create booking record
    MySQL.insert.await(
        'INSERT INTO sb_prison_bookings (citizenid, citizen_name, mugshot, mugshot_side, charges, sentence_months, location, officer_citizenid, officer_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { citizenid, targetName, mugshotFront, mugshotSide, charges, totalMonths, location, officerCid, officerName }
    )

    -- Create sentence record
    local sentenceId
    local status
    if location == 'mrpd' then
        -- MRPD: timer starts immediately
        local now = os.time()
        sentenceId = MySQL.insert.await(
            'INSERT INTO sb_prison_sentences (citizenid, jail_months, jail_seconds, start_time, release_time, time_remaining, charges, location, status, officer_citizenid, officer_name, mugshot_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { citizenid, totalMonths, totalSeconds, now, now + totalSeconds, totalSeconds, charges, location, 'serving', officerCid, officerName, mugshotFront }
        )
        status = 'serving'
    else
        -- Bolingbroke: ON HOLD until transport
        sentenceId = MySQL.insert.await(
            'INSERT INTO sb_prison_sentences (citizenid, jail_months, jail_seconds, time_remaining, charges, location, status, officer_citizenid, officer_name, mugshot_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { citizenid, totalMonths, totalSeconds, totalSeconds, charges, location, 'on_hold', officerCid, officerName, mugshotFront }
        )
        status = 'on_hold'
    end

    -- Mark criminal records as served
    if #recordIds > 0 then
        local placeholders = {}
        for _ in ipairs(recordIds) do table.insert(placeholders, '?') end
        local params = {}
        for _, id in ipairs(recordIds) do table.insert(params, id) end
        MySQL.query.await(
            'UPDATE sb_police_criminal_records SET served = 1 WHERE id IN (' .. table.concat(placeholders, ',') .. ')',
            params
        )
    end

    -- Cache
    activeSentences[citizenid] = {
        id = sentenceId,
        citizenid = citizenid,
        months = totalMonths,
        seconds = totalSeconds,
        startTime = location == 'mrpd' and os.time() or nil,
        releaseTime = location == 'mrpd' and (os.time() + totalSeconds) or nil,
        timeRemaining = totalSeconds,
        charges = charges,
        location = location,
        status = status,
        officerCid = officerCid,
        officerName = officerName,
        mugshotUrl = mugshotFront,
    }

    -- Initialize prison credits
    InitCredits(citizenid)

    -- Confiscate inventory + save appearance
    -- MRPD: confiscate now (no intake process)
    -- Bolingbroke: only remove weapons now, inventory confiscation deferred to intake step 1
    if targetSrc then
        if location == 'mrpd' then
            ConfiscateAndOutfit(targetSrc, citizenid)
        else
            -- Just remove weapons for transport safety
            TriggerClientEvent('sb_prison:client:removeAllWeapons', targetSrc)
        end
    end

    -- Tell client to start jail / on hold (NO teleport — officer escorts manually)
    if targetSrc then
        if location == 'mrpd' then
            TriggerClientEvent('sb_prison:client:bookingComplete', targetSrc, {
                location = 'mrpd',
                timeRemaining = totalSeconds,
                months = totalMonths,
                charges = charges,
            })
        else
            TriggerClientEvent('sb_prison:client:awaitTransport', targetSrc, {
                location = 'bolingbroke',
                timeRemaining = totalSeconds,
                months = totalMonths,
                charges = charges,
            })
        end
    end

    -- Send confirmation to officer NUI
    TriggerClientEvent('sb_prison:client:nui:bookingComplete', officerSrc, {
        sentenceId = sentenceId,
        suspectName = targetName,
        citizenid = citizenid,
        totalMonths = totalMonths,
        totalSeconds = totalSeconds,
        location = location,
        charges = charges,
        mugshotFront = mugshotFront,
        mugshotSide = mugshotSide,
    })

    if location == 'mrpd' then
        NotifyPlayer(officerSrc, targetName .. ' booked — ' .. totalMonths .. ' months. Escort suspect to an MRPD cell.', 'success', 8000)
    else
        NotifyPlayer(officerSrc, targetName .. ' booked — ' .. totalMonths .. ' months. Transport suspect to Bolingbroke.', 'info', 8000)
    end
    print('[sb_prison] Dashboard booking: ' .. officerName .. ' booked ' .. targetName .. ' (' .. citizenid .. ') for ' .. totalMonths .. ' months at ' .. location)
end)

-- ============================================================================
-- FIELD JAIL (from sb_police "Send to Jail" target)
-- ============================================================================

RegisterNetEvent('sb_prison:server:jailFromField', function(targetSrc)
    local officerSrc = source
    local officerPlayer = SB.Functions.GetPlayer(officerSrc)
    if not officerPlayer or officerPlayer.PlayerData.job.name ~= 'police' then return end

    local targetPlayer = SB.Functions.GetPlayer(targetSrc)
    if not targetPlayer then
        NotifyPlayer(officerSrc, 'Player not found', 'error')
        return
    end

    local targetCid = targetPlayer.PlayerData.citizenid

    -- Check if already jailed
    if activeSentences[targetCid] then
        NotifyPlayer(officerSrc, 'Suspect is already serving a sentence', 'error')
        return
    end

    -- Check if there are pending charges with jail time
    local records = MySQL.query.await(
        'SELECT SUM(jail_time) as total FROM sb_police_criminal_records WHERE citizenid = ? AND jail_time > 0 AND (served = 0 OR served IS NULL)',
        { targetCid }
    )

    local totalMonths = records and records[1] and records[1].total or 0
    if totalMonths <= 0 then
        NotifyPlayer(officerSrc, 'No pending jail time. Apply charges first via MDT.', 'error')
        return
    end

    -- Trigger booking process on the officer's client
    TriggerClientEvent('sb_prison:client:startBooking', officerSrc, targetSrc, totalMonths)
end)

-- ============================================================================
-- DUMMY BOOKING RECORD (visual test — just saves to DB, no jail)
-- ============================================================================

RegisterNetEvent('sb_prison:server:dummyBookRecord', function(mugshotUrl, mugshotSideUrl)
    local src = source
    if not IsAdmin(src) then return end

    local officerCid = GetPlayerCitizenId(src) or 'unknown'
    local officerName = GetPlayerName(src)

    MySQL.insert('INSERT INTO sb_prison_bookings (citizenid, citizen_name, mugshot, mugshot_side, charges, sentence_months, location, officer_citizenid, officer_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { 'DUMMY_TEST', 'Test Dummy', mugshotUrl, mugshotSideUrl, 'Dummy test booking', 5, 'mrpd', officerCid, officerName }
    )
    print('[sb_prison] Dummy booking record saved by ' .. officerName)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsPlayerJailed', function(citizenid)
    return activeSentences[citizenid] ~= nil
end)

exports('GetSentence', function(citizenid)
    return activeSentences[citizenid]
end)

exports('GetBookingRecord', function(citizenid)
    return MySQL.single.await(
        'SELECT * FROM sb_prison_bookings WHERE citizenid = ? ORDER BY id DESC LIMIT 1',
        { citizenid }
    )
end)

-- ============================================================================
-- RESOURCE RESTART RE-SYNC
-- When sb_prison restarts while players are jailed, clients lose state.
-- Each client calls this on startup to check if they're still serving.
-- ============================================================================

RegisterNetEvent('sb_prison:server:requestJailSync', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    local sentence = activeSentences[citizenid]
    if not sentence then return end

    local now = os.time()

    if sentence.status == 'serving' and sentence.releaseTime then
        if now >= sentence.releaseTime then
            ReleasePlayer(citizenid, 'time_served')
            return
        end

        local remaining = sentence.releaseTime - now
        sentence.timeRemaining = remaining

        -- Re-outfit (client lost ped state on restart)
        ConfiscateAndOutfit(src, citizenid)

        TriggerClientEvent('sb_prison:client:startSentence', src, {
            location = sentence.location,
            timeRemaining = remaining,
            months = sentence.months,
            charges = sentence.charges,
            reconnect = true,
        })

        -- Sync credits
        local credits = GetCredits(citizenid)
        TriggerClientEvent('sb_prison:client:syncCredits', src, credits)

    elseif sentence.status == 'releasing' then
        local confiscated = MySQL.single.await(
            'SELECT returned, appearance FROM sb_prison_confiscated WHERE citizenid = ? ORDER BY id DESC LIMIT 1',
            { citizenid }
        )
        local itemsReturned = confiscated and confiscated.returned == 1
        if itemsReturned then
            if confiscated and confiscated.appearance then
                local appearance = json.decode(confiscated.appearance)
                if appearance then
                    TriggerClientEvent('sb_prison:client:restoreAppearance', src, appearance)
                end
            end
            TriggerClientEvent('sb_prison:client:startRelease', src, true, 3)
        else
            TriggerClientEvent('sb_prison:client:startRelease', src, true, 1)
        end

    elseif sentence.status == 'booked' or sentence.status == 'on_hold' or sentence.status == 'transporting' then
        if sentence.location == 'bolingbroke' then
            TriggerClientEvent('sb_prison:client:removeAllWeapons', src)
        else
            ConfiscateAndOutfit(src, citizenid)
        end
        TriggerClientEvent('sb_prison:client:awaitTransport', src, {
            location = sentence.location,
            timeRemaining = sentence.timeRemaining,
            months = sentence.months,
            charges = sentence.charges,
            reconnect = true,
        })
    end
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Save all active sentence times
    for citizenid, sentence in pairs(activeSentences) do
        if sentence.status == 'serving' and sentence.releaseTime then
            local remaining = math.max(0, sentence.releaseTime - os.time())
            MySQL.query(
                'UPDATE sb_prison_sentences SET time_remaining = ? WHERE id = ?',
                { remaining, sentence.id }
            )
        end
    end
end)
