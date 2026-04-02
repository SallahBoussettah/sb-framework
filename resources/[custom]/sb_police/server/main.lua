-- =============================================
-- SB_POLICE - Server Main
-- React UI Integration
-- =============================================

local SB = nil
local onDutyOfficers = {}
local escortPairs = {}  -- [escortedId] = officerId
local vehicleSirenStates = {}  -- [netId] = { lightsOn, sirenTone, hornOn }
local gsrTracking = {}  -- [serverId] = os.time() of last weapon fire

-- Wait for sb_core
CreateThread(function()
    while not exports['sb_core'] do Wait(100) end
    SB = exports['sb_core']:GetCoreObject()
    print('^2[sb_police]^7 Server initialized')

    -- Ensure DB tables exist (Sprint 8)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_citations (
            id INT(11) NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            citizen_name VARCHAR(100) NOT NULL,
            offense VARCHAR(255) NOT NULL,
            fine INT(11) NOT NULL DEFAULT 0,
            notes TEXT,
            vehicle_plate VARCHAR(20),
            location VARCHAR(255),
            officer_id VARCHAR(50) NOT NULL,
            officer_name VARCHAR(100) NOT NULL,
            paid TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_citizenid (citizenid),
            INDEX idx_paid (paid)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_citizen_notes (
            id INT(11) NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            note TEXT NOT NULL,
            officer_id VARCHAR(50) NOT NULL,
            officer_name VARCHAR(100) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_citizenid (citizenid)
        )
    ]])

    -- Add amount_paid column to criminal_records if not exists
    MySQL.query([[
        SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'sb_police_criminal_records' AND COLUMN_NAME = 'amount_paid'
    ]], {}, function(results)
        if results and results[1] and results[1].cnt == 0 then
            MySQL.query('ALTER TABLE sb_police_criminal_records ADD COLUMN amount_paid INT(11) DEFAULT 0')
            print('^2[sb_police]^7 Added amount_paid column to criminal_records')
        end
    end)

    -- Restore duty state from DB (handles resource restarts)
    -- Officers with clock_out IS NULL were on duty when the resource stopped
    Wait(2000) -- Give players time to fully load after resource restart
    RestoreDutyState()

    -- Register radar_gun as useable item (inventory double-click / quickslot)
    SB.Functions.CreateUseableItem('radar_gun', function(source, item)
        local Player = SB.Functions.GetPlayer(source)
        if not Player then return end
        if Player.PlayerData.job.name ~= Config.PoliceJob then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Police only', 'error', 3000)
            return
        end
        if not onDutyOfficers[source] then
            TriggerClientEvent('sb_notify:client:Notify', source, 'You must be on duty', 'error', 3000)
            return
        end
        TriggerClientEvent('sb_police:client:useRadarGun', source)
    end)

    -- Register flashlight as useable item (toggle on/off)
    SB.Functions.CreateUseableItem('flashlight', function(source, item)
        local Player = SB.Functions.GetPlayer(source)
        if not Player then return end
        if Player.PlayerData.job.name ~= Config.PoliceJob then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Police only', 'error', 3000)
            return
        end
        if not onDutyOfficers[source] then
            TriggerClientEvent('sb_notify:client:Notify', source, 'You must be on duty', 'error', 3000)
            return
        end
        TriggerClientEvent('sb_police:client:useFlashlight', source)
    end)

    -- NOTE: weapon_nightstick, weapon_stungun, weapon_flashlight, weapon_combatpistol, etc.
    -- are handled by sb_weapons (EquipWeapon) since they're category='weapon' items.
    -- Only police-category equipment items need CreateUseableItem here.

    -- Register armor as useable item (apply body armor, consumed on use)
    SB.Functions.CreateUseableItem('armor', function(source, item)
        local Player = SB.Functions.GetPlayer(source)
        if not Player then return end
        if Player.PlayerData.job.name ~= Config.PoliceJob then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Police only', 'error', 3000)
            return
        end
        -- Remove from inventory (consumed)
        local removed = exports['sb_inventory']:RemoveItem(source, 'armor', 1)
        if not removed then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Failed to use armor', 'error', 3000)
            return
        end
        TriggerClientEvent('sb_police:client:useArmor', source)
    end)

    -- Register firstaid as useable item (heal player, consumed on use)
    SB.Functions.CreateUseableItem('firstaid', function(source, item)
        local Player = SB.Functions.GetPlayer(source)
        if not Player then return end
        if Player.PlayerData.job.name ~= Config.PoliceJob then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Police only', 'error', 3000)
            return
        end
        -- Remove from inventory (consumed)
        local removed = exports['sb_inventory']:RemoveItem(source, 'firstaid', 1)
        if not removed then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Failed to use first aid', 'error', 3000)
            return
        end
        TriggerClientEvent('sb_police:client:useFirstAid', source)
    end)

    -- Register radio as useable item (placeholder)
    SB.Functions.CreateUseableItem('radio', function(source, item)
        local Player = SB.Functions.GetPlayer(source)
        if not Player then return end
        if Player.PlayerData.job.name ~= Config.PoliceJob then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Police only', 'error', 3000)
            return
        end
        TriggerClientEvent('sb_notify:client:Notify', source, 'Radio active on channel 1', 'info', 3000)
    end)
end)

-- Return item to officer (for cancelled progress bars)
RegisterNetEvent('sb_police:server:returnItem', function(itemName, amount)
    local src = source
    if not IsValidOfficer(src) then return end
    -- Only allow returning specific items
    local allowed = { armor = true, firstaid = true }
    if not allowed[itemName] then return end
    exports['sb_inventory']:AddItem(src, itemName, amount or 1)
end)

-- =============================================
-- Duty Restore (resource restart persistence)
-- =============================================

function RestoreDutyState()
    local openRecords = MySQL.query.await(
        'SELECT officer_id, officer_name, UNIX_TIMESTAMP(clock_in) as clock_in_unix FROM sb_police_duty_clock WHERE clock_out IS NULL'
    )

    if not openRecords or #openRecords == 0 then
        print('^2[sb_police]^7 Duty restore: no open records found')
        return
    end

    local restoredCount = 0
    local closedCount = 0

    for _, record in ipairs(openRecords) do
        local Player = SB.Functions.GetPlayerByCitizenId(record.officer_id)

        if Player then
            local src = Player.PlayerData.source
            local playerData = Player.PlayerData

            -- Only restore if they still have the police job
            if playerData.job.name == Config.PoliceJob then
                onDutyOfficers[src] = {
                    source = src,
                    citizenid = record.officer_id,
                    name = record.officer_name,
                    rank = playerData.job.grade.name or 'Officer',
                    grade = playerData.job.grade.level or 0,
                    clockIn = record.clock_in_unix,
                    status = 'available'
                }

                -- Sync duty with sb_core
                Player.Functions.SetJobDuty(true)

                -- Notify client with original clock-in time so timer continues
                TriggerClientEvent('sb_police:client:updateDuty', src, true, record.clock_in_unix)

                restoredCount = restoredCount + 1
                print(('[sb_police] ^2Restored duty for %s (src %d), shift started %d min ago^7'):format(
                    record.officer_name, src, math.floor((os.time() - record.clock_in_unix) / 60)
                ))
            else
                -- Player changed jobs since last on duty, close the record
                local duration = math.floor((os.time() - record.clock_in_unix) / 60)
                MySQL.update('UPDATE sb_police_duty_clock SET clock_out = NOW(), duration_minutes = ? WHERE officer_id = ? AND clock_out IS NULL ORDER BY id DESC LIMIT 1', {
                    duration, record.officer_id
                })
                closedCount = closedCount + 1
            end
        else
            -- Player is offline, close the stale record
            local duration = math.floor((os.time() - record.clock_in_unix) / 60)
            MySQL.update('UPDATE sb_police_duty_clock SET clock_out = NOW(), duration_minutes = ? WHERE officer_id = ? AND clock_out IS NULL ORDER BY id DESC LIMIT 1', {
                duration, record.officer_id
            })
            closedCount = closedCount + 1
        end
    end

    if restoredCount > 0 then
        BroadcastOfficerList()
    end

    print(('[sb_police] ^2Duty restore: %d officers restored, %d stale records closed^7'):format(restoredCount, closedCount))
end

-- =============================================
-- Job Data
-- =============================================

RegisterNetEvent('sb_police:server:requestJobData', function()
    local src = source

    -- Wait for SB to be ready
    local attempts = 0
    while not SB and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end

    if not SB then
        print(('[sb_police] ^1Failed to get SB object for player %d^7'):format(src))
        return
    end

    -- Try to get player data with retries (player might not be fully loaded)
    local Player = nil
    attempts = 0
    while not Player and attempts < 30 do
        Player = SB.Functions.GetPlayer(src)
        if not Player then
            Wait(200)
            attempts = attempts + 1
        end
    end

    if Player and Player.PlayerData and Player.PlayerData.job then
        TriggerClientEvent('sb_police:client:setJobData', src, Player.PlayerData.job)
        print(('[sb_police] ^2Sent job data to player %d:^7 %s'):format(src, Player.PlayerData.job.name or 'unknown'))
    else
        print(('[sb_police] ^3Could not get job data for player %d after %d attempts^7'):format(src, attempts))
    end
end)

-- =============================================
-- Duty System
-- =============================================

-- Shared helper: clock an officer in (avoids duplicate code)
function ClockOfficerIn(src, playerData)
    -- Guard: already on duty? Skip to prevent duplicate clock entries
    if onDutyOfficers[src] then
        print(('[sb_police] %s (%s) already on duty, skipping clock-in'):format(playerData.charinfo.firstname, src))
        return false
    end

    onDutyOfficers[src] = {
        source = src,
        citizenid = playerData.citizenid,
        name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
        rank = playerData.job.grade.name or 'Officer',
        grade = playerData.job.grade.level or 0,
        clockIn = os.time(),
        status = 'available'
    }

    MySQL.insert('INSERT INTO sb_police_duty_clock (officer_id, officer_name, clock_in) VALUES (?, ?, NOW())', {
        playerData.citizenid,
        playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname
    })

    print(('[sb_police] %s (%s) clocked in'):format(playerData.charinfo.firstname, src))
    return true
end

-- Shared helper: clock an officer out
function ClockOfficerOut(src, playerData)
    if not onDutyOfficers[src] then
        print(('[sb_police] %s (%s) not on duty, skipping clock-out'):format(playerData.charinfo.firstname, src))
        return false
    end

    local clockIn = onDutyOfficers[src].clockIn
    local duration = math.floor((os.time() - clockIn) / 60)

    MySQL.update('UPDATE sb_police_duty_clock SET clock_out = NOW(), duration_minutes = ? WHERE officer_id = ? AND clock_out IS NULL ORDER BY id DESC LIMIT 1', {
        duration,
        playerData.citizenid
    })

    onDutyOfficers[src] = nil
    print(('[sb_police] %s (%s) clocked out after %d minutes'):format(playerData.charinfo.firstname, src, duration))
    return true
end

-- Sync duty from sb_core /duty command
AddEventHandler('sb_police:server:syncDutyFromCore', function(playerSource, goOnDuty)
    local src = playerSource
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local playerData = Player.PlayerData
    if playerData.job.name ~= Config.PoliceJob then return end

    if goOnDuty then
        ClockOfficerIn(src, playerData)
    else
        ClockOfficerOut(src, playerData)
    end

    TriggerClientEvent('sb_police:client:updateDuty', src, goOnDuty)
    BroadcastOfficerList()
end)

RegisterNetEvent('sb_police:server:toggleDuty', function(goOnDuty)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local playerData = Player.PlayerData
    if playerData.job.name ~= Config.PoliceJob then return end

    -- Sync with sb_core so paycheck system works
    Player.Functions.SetJobDuty(goOnDuty)

    if goOnDuty then
        ClockOfficerIn(src, playerData)
    else
        ClockOfficerOut(src, playerData)
    end

    TriggerClientEvent('sb_police:client:updateDuty', src, goOnDuty)
    BroadcastOfficerList()
end)

function BroadcastOfficerList()
    local officers = {}

    for src, data in pairs(onDutyOfficers) do
        table.insert(officers, {
            source = src,
            name = data.name,
            rank = data.rank,
            status = data.status,
            onDuty = true
        })
    end

    for src, _ in pairs(onDutyOfficers) do
        TriggerClientEvent('sb_police:client:updateOfficers', src, officers)
    end
end

-- =============================================
-- Data Requests
-- =============================================

RegisterNetEvent('sb_police:server:getOnDutyOfficers', function()
    local src = source
    local officers = {}

    for s, data in pairs(onDutyOfficers) do
        table.insert(officers, {
            source = s,
            name = data.name,
            rank = data.rank,
            status = data.status,
            onDuty = true
        })
    end

    TriggerClientEvent('sb_police:client:updateOfficers', src, officers)
end)

RegisterNetEvent('sb_police:server:getAlerts', function()
    local src = source
    -- Pull active police alerts from sb_alerts system
    local rawAlerts = {}
    local ok, result = pcall(function()
        return exports['sb_alerts']:GetActiveAlerts('police')
    end)
    if ok and result then rawAlerts = result end

    -- Format for MDT (GetActiveAlerts returns limited fields, map priority numbers to strings)
    local mdtAlerts = {}
    for _, a in ipairs(rawAlerts) do
        local pri = 'medium'
        if a.priority == 1 then pri = 'high'
        elseif a.priority == 3 then pri = 'low' end

        mdtAlerts[#mdtAlerts + 1] = {
            id = a.id,
            title = a.title or 'Alert',
            location = a.location or 'Unknown',
            coords = a.coords or nil,
            priority = pri,
            caller = a.caller or 'Dispatch',
            type = a.type or nil,
            time = a.timestamp and os.date('%H:%M', a.timestamp) or os.date('%H:%M'),
            timestamp = a.timestamp or os.time(),
            responderCount = a.responderCount or 0,
        }
    end

    TriggerClientEvent('sb_police:client:updateAlerts', src, mdtAlerts)
end)

RegisterNetEvent('sb_police:server:getPenalCode', function()
    local src = source

    MySQL.query('SELECT * FROM sb_police_penal_code ORDER BY category, title', {}, function(results)
        if results and #results > 0 then
            TriggerClientEvent('sb_police:client:penalCode', src, results)
        else
            LoadDefaultPenalCode(src)
        end
    end)
end)

function LoadDefaultPenalCode(src)
    local codes = {}

    for i, code in ipairs(PenalCode) do
        table.insert(codes, {
            id = i,
            category = code.category,
            title = code.title,
            description = code.description,
            fine = code.fine,
            jail_time = code.jail_time
        })

        MySQL.insert('INSERT INTO sb_police_penal_code (title, description, fine, jail_time, category) VALUES (?, ?, ?, ?, ?)', {
            code.title,
            code.description,
            code.fine,
            code.jail_time,
            code.category
        })
    end

    TriggerClientEvent('sb_police:client:penalCode', src, codes)
end

-- =============================================
-- Search Functions
-- =============================================

RegisterNetEvent('sb_police:server:searchCitizens', function(query)
    local src = source

    if not query or query == '' then
        TriggerClientEvent('sb_police:client:searchResults', src, 'citizens', {})
        return
    end

    MySQL.query([[
        SELECT citizenid, charinfo
        FROM players
        WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
           OR citizenid LIKE ?
        LIMIT 20
    ]], {
        '%' .. query .. '%',
        '%' .. query .. '%',
        '%' .. query .. '%'
    }, function(results)
        local formatted = {}
        if results then
            -- Collect citizenids to check warrants
            local citizenIds = {}
            for _, row in ipairs(results) do
                table.insert(citizenIds, row.citizenid)
            end

            -- Batch check warrants
            if #citizenIds > 0 then
                local placeholders = {}
                for _ = 1, #citizenIds do table.insert(placeholders, '?') end
                local inClause = table.concat(placeholders, ',')

                MySQL.query('SELECT citizenid, COUNT(*) as cnt FROM sb_police_warrants WHERE citizenid IN (' .. inClause .. ') AND status = \'active\' GROUP BY citizenid', citizenIds, function(warrantResults)
                    local warrantMap = {}
                    if warrantResults then
                        for _, w in ipairs(warrantResults) do
                            warrantMap[w.citizenid] = w.cnt
                        end
                    end

                    for _, row in ipairs(results) do
                        local charinfo = json.decode(row.charinfo) or {}
                        table.insert(formatted, {
                            id = row.citizenid,
                            citizenid = row.citizenid,
                            firstname = charinfo.firstname or 'Unknown',
                            lastname = charinfo.lastname or 'Unknown',
                            wanted = (warrantMap[row.citizenid] or 0) > 0
                        })
                    end
                    TriggerClientEvent('sb_police:client:searchResults', src, 'citizens', formatted)
                end)
            else
                TriggerClientEvent('sb_police:client:searchResults', src, 'citizens', formatted)
            end
        else
            TriggerClientEvent('sb_police:client:searchResults', src, 'citizens', formatted)
        end
    end)
end)

RegisterNetEvent('sb_police:server:searchVehicles', function(query)
    local src = source

    if not query or query == '' then
        TriggerClientEvent('sb_police:client:searchResults', src, 'vehicles', {})
        return
    end

    local searchQuery = '%' .. query:upper() .. '%'
    local formatted = {}

    -- Search player_vehicles
    MySQL.query([[
        SELECT v.plate, v.vehicle, v.citizenid, p.charinfo, 'owned' as vehicle_type
        FROM player_vehicles v
        LEFT JOIN players p ON v.citizenid COLLATE utf8mb4_unicode_ci = p.citizenid COLLATE utf8mb4_unicode_ci
        WHERE UPPER(v.plate) LIKE ?
        LIMIT 10
    ]], { searchQuery }, function(ownedResults)
        if ownedResults then
            for _, v in ipairs(ownedResults) do
                local charinfo = v.charinfo and json.decode(v.charinfo) or {}
                local ownerName = charinfo.firstname and (charinfo.firstname .. ' ' .. charinfo.lastname) or 'Unknown'
                table.insert(formatted, {
                    id = v.plate,
                    plate = v.plate,
                    vehicle = v.vehicle or 'Unknown',
                    owner = ownerName,
                    vehicleType = 'owned',
                    wanted = false
                })
            end
        end

        -- Search rental vehicles
        MySQL.query([[
            SELECT r.plate, r.vehicle, r.vehicle_label, r.citizenid, r.status, p.charinfo
            FROM vehicle_rentals r
            LEFT JOIN players p ON r.citizenid COLLATE utf8mb4_unicode_ci = p.citizenid COLLATE utf8mb4_unicode_ci
            WHERE UPPER(r.plate) LIKE ? AND r.status IN ('active', 'late', 'stolen')
            LIMIT 10
        ]], { searchQuery }, function(rentalResults)
            if rentalResults then
                for _, v in ipairs(rentalResults) do
                    local charinfo = v.charinfo and json.decode(v.charinfo) or {}
                    local ownerName = charinfo.firstname and (charinfo.firstname .. ' ' .. charinfo.lastname) or 'Unknown'
                    table.insert(formatted, {
                        id = v.plate,
                        plate = v.plate,
                        vehicle = v.vehicle_label or v.vehicle or 'Rental Vehicle',
                        owner = ownerName .. ' (Renter)',
                        vehicleType = 'rental',
                        rentalStatus = v.status,
                        wanted = v.status == 'stolen'
                    })
                end
            end

            TriggerClientEvent('sb_police:client:searchResults', src, 'vehicles', formatted)
        end)
    end)
end)

-- =============================================
-- Citizen Details
-- =============================================

RegisterNetEvent('sb_police:server:getCitizenDetails', function(citizenId)
    local src = source

    MySQL.query('SELECT * FROM players WHERE citizenid = ?', { citizenId }, function(results)
        if not results or #results == 0 then
            TriggerClientEvent('sb_police:client:citizenDetails', src, nil)
            return
        end

        local player = results[1]
        local charinfo = json.decode(player.charinfo) or {}
        local job = json.decode(player.job) or {}
        local money = json.decode(player.money) or {}
        local metadata = json.decode(player.metadata) or {}

        -- Get criminal records
        MySQL.query('SELECT * FROM sb_police_criminal_records WHERE citizenid = ? ORDER BY created_at DESC', { citizenId }, function(records)
            local criminalRecords = {}
            if records then
                for _, r in ipairs(records) do
                    table.insert(criminalRecords, {
                        id = r.id,
                        citizenid = r.citizenid,
                        charges = r.charges,
                        fine = r.fine,
                        jailTime = r.jail_time,
                        officerId = r.officer_id,
                        officerName = r.officer_name,
                        paid = r.paid == 1,
                        amountPaid = r.amount_paid or 0,
                        served = r.served == 1,
                        createdAt = r.created_at
                    })
                end
            end

            -- Get citations
            MySQL.query('SELECT * FROM sb_police_citations WHERE citizenid = ? ORDER BY created_at DESC', { citizenId }, function(citationResults)
                local citations = {}
                if citationResults then
                    for _, c in ipairs(citationResults) do
                        table.insert(citations, {
                            id = c.id,
                            citizenid = c.citizenid,
                            citizenName = c.citizen_name,
                            offense = c.offense,
                            fine = c.fine,
                            notes = c.notes,
                            vehiclePlate = c.vehicle_plate,
                            location = c.location,
                            officerId = c.officer_id,
                            officerName = c.officer_name,
                            paid = c.paid == 1,
                            createdAt = c.created_at
                        })
                    end
                end

                -- Get citizen notes
                MySQL.query('SELECT * FROM sb_police_citizen_notes WHERE citizenid = ? ORDER BY created_at DESC', { citizenId }, function(noteResults)
                    local notes = {}
                    if noteResults then
                        for _, n in ipairs(noteResults) do
                            table.insert(notes, {
                                id = n.id,
                                note = n.note,
                                officerId = n.officer_id,
                                officerName = n.officer_name,
                                createdAt = n.created_at
                            })
                        end
                    end

                    -- Calculate outstanding fines (criminal records + citations)
                    MySQL.query('SELECT COALESCE(SUM(fine - COALESCE(amount_paid, 0)), 0) as total FROM sb_police_criminal_records WHERE citizenid = ? AND paid = 0', { citizenId }, function(fineResult)
                        local outstandingFines = fineResult and fineResult[1] and fineResult[1].total or 0

                        -- Add unpaid citations
                        MySQL.query('SELECT COALESCE(SUM(fine), 0) as total FROM sb_police_citations WHERE citizenid = ? AND paid = 0', { citizenId }, function(citationFineResult)
                            outstandingFines = outstandingFines + (citationFineResult and citationFineResult[1] and citationFineResult[1].total or 0)

                            -- Check active warrants
                            MySQL.query('SELECT COUNT(*) as cnt FROM sb_police_warrants WHERE citizenid = ? AND status = ?', { citizenId, 'active' }, function(warrantResult)
                                local activeWarrants = warrantResult and warrantResult[1] and warrantResult[1].cnt or 0

                                -- Fetch latest mugshot from booking records
                                MySQL.query('SELECT mugshot, mugshot_side FROM sb_prison_bookings WHERE citizenid = ? ORDER BY booking_time DESC LIMIT 1', { citizenId }, function(mugshotResult)
                                    local mugshot = nil
                                    local mugshotSide = nil
                                    if mugshotResult and mugshotResult[1] then
                                        mugshot = mugshotResult[1].mugshot
                                        mugshotSide = mugshotResult[1].mugshot_side
                                    end

                                    local citizen = {
                                        id = citizenId,
                                        citizenid = citizenId,
                                        firstname = charinfo.firstname or 'Unknown',
                                        lastname = charinfo.lastname or 'Unknown',
                                        dob = charinfo.birthdate or nil,
                                        gender = charinfo.gender == 0 and 'Male' or 'Female',
                                        phone = charinfo.phone or nil,
                                        nationality = charinfo.nationality or 'Unknown',
                                        job = job.label or 'Unemployed',
                                        jobGrade = job.grade and job.grade.name or nil,
                                        licenses = metadata.licences or { driver = false, weapon = false },
                                        bank = money.bank or 0,
                                        wanted = activeWarrants > 0,
                                        activeWarrants = activeWarrants,
                                        criminalRecords = criminalRecords,
                                        citations = citations,
                                        notes = notes,
                                        outstandingFines = outstandingFines,
                                        mugshot = mugshot,
                                        mugshotSide = mugshotSide
                                    }

                                    TriggerClientEvent('sb_police:client:citizenDetails', src, citizen)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)

-- =============================================
-- Vehicle Details
-- =============================================

RegisterNetEvent('sb_police:server:getVehicleDetails', function(plate)
    local src = source

    -- First try player_vehicles
    MySQL.query([[
        SELECT v.*, p.charinfo
        FROM player_vehicles v
        LEFT JOIN players p ON v.citizenid COLLATE utf8mb4_unicode_ci = p.citizenid COLLATE utf8mb4_unicode_ci
        WHERE v.plate = ?
    ]], { plate }, function(ownedResults)
        if ownedResults and #ownedResults > 0 then
            -- Found in owned vehicles
            local v = ownedResults[1]
            local charinfo = v.charinfo and json.decode(v.charinfo) or {}
            local ownerName = charinfo.firstname and (charinfo.firstname .. ' ' .. charinfo.lastname) or 'Unknown'

            GetVehicleFlagsAndSend(src, plate, v.vehicle or 'Unknown', ownerName, v.citizenid, 'owned', v.created_at, nil)
        else
            -- Try rental vehicles
            MySQL.query([[
                SELECT r.*, p.charinfo
                FROM vehicle_rentals r
                LEFT JOIN players p ON r.citizenid COLLATE utf8mb4_unicode_ci = p.citizenid COLLATE utf8mb4_unicode_ci
                WHERE r.plate = ?
                ORDER BY r.id DESC LIMIT 1
            ]], { plate }, function(rentalResults)
                if rentalResults and #rentalResults > 0 then
                    local r = rentalResults[1]
                    local charinfo = r.charinfo and json.decode(r.charinfo) or {}
                    local ownerName = charinfo.firstname and (charinfo.firstname .. ' ' .. charinfo.lastname) or 'Unknown'

                    GetVehicleFlagsAndSend(src, plate, r.vehicle_label or r.vehicle or 'Rental Vehicle', ownerName .. ' (Renter)', r.citizenid, 'rental', r.rental_start, r)
                else
                    TriggerClientEvent('sb_police:client:vehicleDetails', src, nil)
                end
            end)
        end
    end)
end)

-- Helper function to get flags and send vehicle details
function GetVehicleFlagsAndSend(src, plate, vehicleName, ownerName, ownerId, vehicleType, registeredDate, rentalData)
    MySQL.query('SELECT * FROM sb_police_vehicle_flags WHERE plate = ?', { plate }, function(flagResults)
        local flags = {}
        if flagResults then
            for _, f in ipairs(flagResults) do
                table.insert(flags, {
                    type = f.flag_type,
                    note = f.note,
                    addedBy = f.added_by,
                    addedAt = f.created_at
                })
            end
        end

        -- Add rental stolen flag if applicable
        if rentalData and rentalData.status == 'stolen' then
            table.insert(flags, {
                type = 'stolen',
                note = 'Rental vehicle reported stolen',
                addedBy = 'System',
                addedAt = rentalData.updated_at
            })
        end

        local vehicle = {
            id = plate,
            plate = plate,
            vehicle = vehicleName,
            owner = ownerName,
            ownerId = ownerId,
            class = vehicleType == 'rental' and 'Rental' or 'Unknown',
            registration = 'valid',
            insurance = vehicleType == 'rental' and 'Rental Coverage' or 'valid',
            registeredDate = registeredDate or nil,
            vehicleType = vehicleType,
            flags = flags
        }

        -- Add rental-specific info
        if rentalData then
            vehicle.rentalInfo = {
                rentalId = rentalData.rental_id,
                status = rentalData.status,
                rentalEnd = rentalData.rental_end,
                location = rentalData.location_id
            }
        end

        TriggerClientEvent('sb_police:client:vehicleDetails', src, vehicle)
    end)
end

-- =============================================
-- Apply Charges (with money deduction)
-- =============================================

RegisterNetEvent('sb_police:server:applyCharges', function(citizenId, charges, totalFine, totalJail)
    local src = source
    if not SB then return end

    -- Duty enforcement
    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local playerData = Player.PlayerData
    local officerName = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname

    -- Build charges string
    local chargeNames = {}
    for _, charge in ipairs(charges) do
        table.insert(chargeNames, charge.title)
    end
    local chargesStr = table.concat(chargeNames, ', ')

    -- Try to deduct money from the target citizen
    local TargetPlayer = SB.Functions.GetPlayerByCitizenId(citizenId)
    local amountPaid = 0
    local paid = 0

    if TargetPlayer then
        -- ONLINE: deduct from cash first, then bank
        local cash = TargetPlayer.Functions.GetMoney('cash')
        local bank = TargetPlayer.Functions.GetMoney('bank')
        local remaining = totalFine

        if cash >= remaining then
            TargetPlayer.Functions.RemoveMoney('cash', remaining, 'police-fine')
            amountPaid = remaining
            remaining = 0
        elseif cash > 0 then
            TargetPlayer.Functions.RemoveMoney('cash', cash, 'police-fine')
            amountPaid = cash
            remaining = remaining - cash
        end

        if remaining > 0 and bank >= remaining then
            TargetPlayer.Functions.RemoveMoney('bank', remaining, 'police-fine')
            amountPaid = amountPaid + remaining
            remaining = 0
        elseif remaining > 0 and bank > 0 then
            TargetPlayer.Functions.RemoveMoney('bank', bank, 'police-fine')
            amountPaid = amountPaid + bank
            remaining = remaining - bank
        end

        paid = remaining == 0 and 1 or 0

        -- Notify citizen
        local targetSrc = TargetPlayer.PlayerData.source
        if remaining == 0 then
            TriggerClientEvent('sb_notify:client:Notify', targetSrc, 'You have been fined $' .. totalFine .. ' for: ' .. chargesStr, 'error', 8000)
        else
            TriggerClientEvent('sb_notify:client:Notify', targetSrc, 'You have been fined $' .. totalFine .. '. $' .. amountPaid .. ' collected, $' .. remaining .. ' outstanding.', 'error', 8000)
        end
    else
        -- OFFLINE: deduct from DB
        MySQL.query('SELECT money FROM players WHERE citizenid = ?', { citizenId }, function(results)
            if results and #results > 0 then
                local money = json.decode(results[1].money) or {}
                local bank = money.bank or 0
                local remaining = totalFine

                if bank >= remaining then
                    money.bank = bank - remaining
                    amountPaid = remaining
                    remaining = 0
                else
                    amountPaid = bank
                    money.bank = 0
                    remaining = remaining - bank
                end

                MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {
                    json.encode(money), citizenId
                })
            end
        end)

        -- For offline, set paid optimistically (will be corrected by the async query)
        paid = 0
    end

    -- Insert criminal record
    MySQL.insert('INSERT INTO sb_police_criminal_records (citizenid, charges, fine, jail_time, officer_id, officer_name, paid, amount_paid) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        citizenId,
        chargesStr,
        totalFine,
        totalJail,
        playerData.citizenid,
        officerName,
        paid,
        amountPaid
    }, function(id)
        if id then
            local msg = ('Charges applied. $%d collected'):format(amountPaid)
            if amountPaid < totalFine then
                msg = msg .. (', $%d outstanding'):format(totalFine - amountPaid)
            end
            TriggerClientEvent('sb_notify:client:Notify', src, msg, 'success', 5000)
            TriggerClientEvent('sb_police:client:chargesApplied', src, true, citizenId)
            print(('[sb_police] %s applied charges to %s: %s ($%d fine, $%d paid, %d months)'):format(officerName, citizenId, chargesStr, totalFine, amountPaid, totalJail))
        else
            TriggerClientEvent('sb_police:client:chargesApplied', src, false, citizenId)
        end
    end)
end)

-- =============================================
-- Vehicle Flags
-- =============================================

RegisterNetEvent('sb_police:server:markVehicleStolen', function(plate)
    local src = source
    if not SB then return end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Clean plate: remove spaces and uppercase
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Check if already marked as stolen
    MySQL.query('SELECT id FROM sb_police_vehicle_flags WHERE plate = ? AND flag_type = ?',
        { cleanPlate, 'stolen' },
        function(results)
            if results and #results > 0 then
                TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle is already marked as stolen', 'error', 3000)
                return
            end

            local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

            MySQL.insert('INSERT INTO sb_police_vehicle_flags (plate, flag_type, note, added_by) VALUES (?, ?, ?, ?)', {
                cleanPlate, 'stolen', 'Marked as stolen via MDT', officerName
            }, function(id)
                if id then
                    TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle marked as stolen', 'success', 3000)
                    -- Trigger all police clients to clear cache for this plate
                    TriggerClientEvent('sb_police:client:clearALPRCache', -1, cleanPlate)
                end
            end)
        end)
end)

RegisterNetEvent('sb_police:server:addVehicleBOLO', function(plate)
    local src = source
    if not SB then return end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Clean plate: remove spaces and uppercase
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Check if BOLO already exists for this plate
    MySQL.query('SELECT id FROM sb_police_vehicle_flags WHERE plate = ? AND flag_type = ?',
        { cleanPlate, 'bolo' },
        function(results)
            if results and #results > 0 then
                TriggerClientEvent('sb_notify:client:Notify', src, 'BOLO already exists for this vehicle', 'error', 3000)
                return
            end

            local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

            MySQL.insert('INSERT INTO sb_police_vehicle_flags (plate, flag_type, note, added_by) VALUES (?, ?, ?, ?)', {
                cleanPlate, 'bolo', 'BOLO added via MDT', officerName
            }, function(id)
                if id then
                    TriggerClientEvent('sb_notify:client:Notify', src, 'BOLO added to vehicle', 'success', 3000)
                    -- Trigger all police clients to clear cache for this plate
                    TriggerClientEvent('sb_police:client:clearALPRCache', -1, cleanPlate)
                end
            end)
        end)
end)

RegisterNetEvent('sb_police:server:removeVehicleFlag', function(plate, flagType)
    local src = source
    if not SB then return end

    -- Clean plate
    local cleanPlate = plate:gsub('%s+', ''):upper()

    MySQL.query('DELETE FROM sb_police_vehicle_flags WHERE plate = ? AND flag_type = ?',
        { cleanPlate, flagType },
        function(result)
            if result.affectedRows > 0 then
                TriggerClientEvent('sb_notify:client:Notify', src, 'Flag removed from vehicle', 'success', 3000)
                -- Clear ALPR cache for all clients
                TriggerClientEvent('sb_police:client:clearALPRCache', -1, cleanPlate)
            else
                TriggerClientEvent('sb_notify:client:Notify', src, 'No flag found to remove', 'error', 3000)
            end
        end)
end)

-- =============================================
-- Reports
-- =============================================

RegisterNetEvent('sb_police:server:filterReports', function(filter)
    local src = source

    local query = 'SELECT * FROM sb_police_reports'
    if filter == 'open' then
        query = query .. " WHERE status = 'open'"
    elseif filter == 'closed' then
        query = query .. " WHERE status = 'closed'"
    end
    query = query .. ' ORDER BY created_at DESC LIMIT 50'

    MySQL.query(query, {}, function(results)
        local reports = {}
        if results then
            for _, r in ipairs(results) do
                local function safeDecode(str)
                    if not str or str == '' then return {} end
                    local ok, result = pcall(json.decode, str)
                    if ok and type(result) == 'table' then return result end
                    return {}
                end

                table.insert(reports, {
                    id = r.id,
                    title = r.title,
                    description = r.description,
                    location = r.location,
                    authorId = r.author_id,
                    authorName = r.author_name,
                    officers = safeDecode(r.officers),
                    suspects = safeDecode(r.suspects),
                    victims = safeDecode(r.victims),
                    vehicles = safeDecode(r.vehicles),
                    evidence = safeDecode(r.evidence),
                    tags = safeDecode(r.tags),
                    status = r.status or 'open',
                    createdAt = r.created_at,
                    updatedAt = r.updated_at
                })
            end
        end
        TriggerClientEvent('sb_police:client:reportsList', src, reports)
    end)
end)

RegisterNetEvent('sb_police:server:createReport', function()
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local playerData = Player.PlayerData
    local name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname

    MySQL.insert('INSERT INTO sb_police_reports (title, author_id, author_name) VALUES (?, ?, ?)', {
        'New Report',
        playerData.citizenid,
        name
    }, function(id)
        if id then
            TriggerClientEvent('sb_police:client:reportCreated', src, id)
        end
    end)
end)

RegisterNetEvent('sb_police:server:updateReport', function(reportId, title, description)
    local src = source

    MySQL.update('UPDATE sb_police_reports SET title = ?, description = ?, updated_at = NOW() WHERE id = ?', {
        title, description, reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Report updated', 'success', 3000)
        end
    end)
end)

-- =============================================
-- Warrants
-- =============================================

RegisterNetEvent('sb_police:server:getWarrants', function()
    local src = source

    MySQL.query('SELECT * FROM sb_police_warrants WHERE status = ? ORDER BY created_at DESC', { 'active' }, function(results)
        local warrants = {}
        if results then
            for _, r in ipairs(results) do
                table.insert(warrants, {
                    id = r.id,
                    citizenid = r.citizenid,
                    citizenName = r.citizen_name,
                    charges = r.charges,
                    reason = r.reason,
                    priority = r.priority,
                    status = r.status,
                    issuedBy = r.issued_by,
                    issuedById = r.issued_by_id,
                    closedBy = r.closed_by,
                    closedReason = r.closed_reason,
                    createdAt = r.created_at,
                    updatedAt = r.updated_at
                })
            end
        end
        TriggerClientEvent('sb_police:client:warrantsList', src, warrants)
    end)
end)

RegisterNetEvent('sb_police:server:createWarrant', function(citizenId, citizenName, charges, reason, priority)
    local src = source
    if not SB then return end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    MySQL.insert('INSERT INTO sb_police_warrants (citizenid, citizen_name, charges, reason, priority, issued_by, issued_by_id) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        citizenId, citizenName, charges, reason or '', priority or 'medium', officerName, Player.PlayerData.citizenid
    }, function(id)
        if id then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Warrant issued for ' .. citizenName, 'success', 3000)
            -- Notify all on-duty officers
            for officerSrc, _ in pairs(onDutyOfficers) do
                if officerSrc ~= src then
                    TriggerClientEvent('sb_notify:client:Notify', officerSrc, 'New warrant issued for ' .. citizenName, 'info', 5000)
                end
            end
            -- Refresh warrants list for requesting officer
            TriggerServerEvent('sb_police:server:getWarrants')
        end
    end)
end)

RegisterNetEvent('sb_police:server:closeWarrant', function(warrantId, closedReason)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    MySQL.update('UPDATE sb_police_warrants SET status = ?, closed_by = ?, closed_reason = ? WHERE id = ?', {
        'closed', officerName, closedReason or '', warrantId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Warrant closed', 'success', 3000)
        end
    end)
end)

-- =============================================
-- BOLOs (Person)
-- =============================================

RegisterNetEvent('sb_police:server:getBOLOs', function()
    local src = source

    MySQL.query('SELECT * FROM sb_police_bolos WHERE status = ? ORDER BY created_at DESC', { 'active' }, function(results)
        local bolos = {}
        if results then
            for _, r in ipairs(results) do
                table.insert(bolos, {
                    id = r.id,
                    personName = r.person_name,
                    description = r.description,
                    reason = r.reason,
                    lastSeen = r.last_seen,
                    priority = r.priority,
                    status = r.status,
                    issuedBy = r.issued_by,
                    issuedById = r.issued_by_id,
                    closedBy = r.closed_by,
                    closedReason = r.closed_reason,
                    createdAt = r.created_at,
                    updatedAt = r.updated_at
                })
            end
        end
        TriggerClientEvent('sb_police:client:bolosList', src, bolos)
    end)
end)

RegisterNetEvent('sb_police:server:createBOLO', function(personName, description, reason, lastSeen, priority)
    local src = source
    if not SB then return end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    MySQL.insert('INSERT INTO sb_police_bolos (person_name, description, reason, last_seen, priority, issued_by, issued_by_id) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        personName, description, reason, lastSeen or '', priority or 'medium', officerName, Player.PlayerData.citizenid
    }, function(id)
        if id then
            TriggerClientEvent('sb_notify:client:Notify', src, 'BOLO created for ' .. personName, 'success', 3000)
            for officerSrc, _ in pairs(onDutyOfficers) do
                if officerSrc ~= src then
                    TriggerClientEvent('sb_notify:client:Notify', officerSrc, 'New BOLO: ' .. personName, 'info', 5000)
                end
            end
        end
    end)
end)

RegisterNetEvent('sb_police:server:closeBOLO', function(boloId, closedReason)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    MySQL.update('UPDATE sb_police_bolos SET status = ?, closed_by = ?, closed_reason = ? WHERE id = ?', {
        'closed', officerName, closedReason or '', boloId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'BOLO closed', 'success', 3000)
        end
    end)
end)

-- Get all vehicle flags (for Warrants page Vehicle Flags tab)
RegisterNetEvent('sb_police:server:getAllVehicleFlags', function()
    local src = source

    MySQL.query('SELECT * FROM sb_police_vehicle_flags ORDER BY created_at DESC', {}, function(results)
        local flags = {}
        if results then
            for _, f in ipairs(results) do
                table.insert(flags, {
                    type = f.flag_type,
                    plate = f.plate,
                    note = f.note,
                    addedBy = f.added_by,
                    addedAt = f.created_at
                })
            end
        end
        TriggerClientEvent('sb_police:client:vehicleFlagsList', src, flags)
    end)
end)

-- =============================================
-- Officer Roster
-- =============================================

RegisterNetEvent('sb_police:server:getOfficerRoster', function()
    local src = source
    if not SB then return end

    MySQL.query('SELECT citizenid, charinfo, job FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, \'$.name\')) = ?', { Config.PoliceJob }, function(results)
        local roster = {}
        if results then
            for _, row in ipairs(results) do
                local charinfo = json.decode(row.charinfo) or {}
                local job = json.decode(row.job) or {}
                local name = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Unknown')
                local grade = job.grade and job.grade.level or 0
                local rankName = Config.Ranks[grade + 1] and Config.Ranks[grade + 1].name or 'Unknown'

                -- Check if online
                local isOnline = false
                local isOnDuty = false
                local playerSource = nil
                local status = nil

                -- Find online player by citizenid
                local players = SB.Functions.GetPlayers()
                for _, pSrc in ipairs(players) do
                    local p = SB.Functions.GetPlayer(pSrc)
                    if p and p.PlayerData.citizenid == row.citizenid then
                        isOnline = true
                        playerSource = pSrc
                        if onDutyOfficers[pSrc] then
                            isOnDuty = true
                            status = onDutyOfficers[pSrc].status
                        end
                        break
                    end
                end

                table.insert(roster, {
                    citizenid = row.citizenid,
                    name = name,
                    rank = rankName,
                    grade = grade,
                    isOnline = isOnline,
                    isOnDuty = isOnDuty,
                    source = playerSource,
                    status = status
                })
            end
        end

        -- Sort by grade descending
        table.sort(roster, function(a, b) return a.grade > b.grade end)

        TriggerClientEvent('sb_police:client:officerRoster', src, roster)
    end)
end)

RegisterNetEvent('sb_police:server:updateOfficerStatus', function(status)
    local src = source
    if not onDutyOfficers[src] then return end

    local validStatuses = { available = true, busy = true, responding = true, unavailable = true }
    if not validStatuses[status] then return end

    onDutyOfficers[src].status = status
    BroadcastOfficerList()
end)

RegisterNetEvent('sb_police:server:setOfficerGradeByCitizenId', function(citizenid, grade)
    local src = source
    if not SB then return end

    -- Check if requester has boss permissions (grade >= 5)
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.PoliceJob then return end
    local requesterGrade = Player.PlayerData.job.grade.level or 0
    if requesterGrade < 5 then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Insufficient rank', 'error', 3000)
        return
    end

    grade = math.max(0, math.min(grade, #Config.Ranks - 1))
    local rankName = Config.Ranks[grade + 1] and Config.Ranks[grade + 1].name or 'Unknown'

    -- Check if target is online
    local targetSrc = nil
    local players = SB.Functions.GetPlayers()
    for _, pSrc in ipairs(players) do
        local p = SB.Functions.GetPlayer(pSrc)
        if p and p.PlayerData.citizenid == citizenid then
            targetSrc = pSrc
            break
        end
    end

    if targetSrc then
        -- Online: use SetJob
        local targetPlayer = SB.Functions.GetPlayer(targetSrc)
        targetPlayer.Functions.SetJob(Config.PoliceJob, grade)
        TriggerClientEvent('sb_notify:client:Notify', targetSrc, 'Your rank has been set to ' .. rankName, 'info', 5000)
    else
        -- Offline: update DB directly
        local jobData = json.encode({
            name = Config.PoliceJob,
            label = 'Police',
            payment = Config.Ranks[grade + 1] and Config.Ranks[grade + 1].salary or 0,
            onduty = false,
            isboss = grade >= 9,
            grade = {
                name = rankName,
                level = grade
            }
        })
        MySQL.update('UPDATE players SET job = ? WHERE citizenid = ?', { jobData, citizenid })
    end

    TriggerClientEvent('sb_notify:client:Notify', src, 'Rank updated to ' .. rankName, 'success', 3000)
    print(('[sb_police] Officer %d set citizenid %s to grade %d (%s)'):format(src, citizenid, grade, rankName))
end)

RegisterNetEvent('sb_police:server:fireOfficerByCitizenId', function(citizenid)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.PoliceJob then return end
    local requesterGrade = Player.PlayerData.job.grade.level or 0
    if requesterGrade < 5 then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Insufficient rank', 'error', 3000)
        return
    end

    -- Check if target is online
    local targetSrc = nil
    local players = SB.Functions.GetPlayers()
    for _, pSrc in ipairs(players) do
        local p = SB.Functions.GetPlayer(pSrc)
        if p and p.PlayerData.citizenid == citizenid then
            targetSrc = pSrc
            break
        end
    end

    if targetSrc then
        local targetPlayer = SB.Functions.GetPlayer(targetSrc)
        targetPlayer.Functions.SetJob('unemployed', 0)
        TriggerClientEvent('sb_notify:client:Notify', targetSrc, 'You have been fired from the Police Department', 'error', 5000)

        -- Clock out if on duty
        if onDutyOfficers[targetSrc] then
            onDutyOfficers[targetSrc] = nil
            TriggerClientEvent('sb_police:client:updateDuty', targetSrc, false)
            BroadcastOfficerList()
        end
    else
        local jobData = json.encode({
            name = 'unemployed',
            label = 'Unemployed',
            payment = 0,
            onduty = false,
            isboss = false,
            grade = { name = 'Unemployed', level = 0 }
        })
        MySQL.update('UPDATE players SET job = ? WHERE citizenid = ?', { jobData, citizenid })
    end

    TriggerClientEvent('sb_notify:client:Notify', src, 'Officer has been fired', 'success', 3000)
    print(('[sb_police] Officer %d fired citizenid %s'):format(src, citizenid))
end)

-- =============================================
-- Duty Stats / Time Clock
-- =============================================

RegisterNetEvent('sb_police:server:getDutyStats', function()
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Get week total
    MySQL.query('SELECT COALESCE(SUM(duration_minutes), 0) as total FROM sb_police_duty_clock WHERE officer_id = ? AND clock_in >= DATE_SUB(NOW(), INTERVAL 7 DAY)', { citizenid }, function(weekResult)
        local totalWeek = weekResult and weekResult[1] and weekResult[1].total or 0

        -- Get month total
        MySQL.query('SELECT COALESCE(SUM(duration_minutes), 0) as total FROM sb_police_duty_clock WHERE officer_id = ? AND clock_in >= DATE_SUB(NOW(), INTERVAL 30 DAY)', { citizenid }, function(monthResult)
            local totalMonth = monthResult and monthResult[1] and monthResult[1].total or 0

            -- Calculate current shift
            local currentShift = 0
            if onDutyOfficers[src] then
                currentShift = math.floor((os.time() - onDutyOfficers[src].clockIn) / 60)
            end

            -- Get recent 20 records
            MySQL.query('SELECT * FROM sb_police_duty_clock WHERE officer_id = ? ORDER BY clock_in DESC LIMIT 20', { citizenid }, function(records)
                local dutyRecords = {}
                if records then
                    for _, r in ipairs(records) do
                        table.insert(dutyRecords, {
                            id = r.id,
                            officerId = r.officer_id,
                            officerName = r.officer_name,
                            clockIn = r.clock_in,
                            clockOut = r.clock_out,
                            durationMinutes = r.duration_minutes or 0
                        })
                    end
                end

                TriggerClientEvent('sb_police:client:dutyStats', src, {
                    totalMinutesWeek = totalWeek,
                    totalMinutesMonth = totalMonth,
                    currentShiftMinutes = currentShift,
                    records = dutyRecords
                })
            end)
        end)
    end)
end)

RegisterNetEvent('sb_police:server:getAllOfficersDuty', function()
    local src = source
    if not SB then return end

    -- Boss check (grade >= 5)
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= Config.PoliceJob then return end
    if (Player.PlayerData.job.grade.level or 0) < 5 then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Insufficient rank', 'error', 3000)
        return
    end

    MySQL.query('SELECT officer_name, clock_in, clock_out, duration_minutes FROM sb_police_duty_clock WHERE clock_in >= DATE_SUB(NOW(), INTERVAL 7 DAY) ORDER BY officer_name, clock_in DESC', {}, function(results)
        local grouped = {}
        local lookup = {}

        if results then
            for _, r in ipairs(results) do
                if not lookup[r.officer_name] then
                    lookup[r.officer_name] = { officerName = r.officer_name, totalMinutes = 0, records = {} }
                    table.insert(grouped, lookup[r.officer_name])
                end
                local entry = lookup[r.officer_name]
                entry.totalMinutes = entry.totalMinutes + (r.duration_minutes or 0)
                table.insert(entry.records, {
                    clockIn = r.clock_in,
                    clockOut = r.clock_out,
                    durationMinutes = r.duration_minutes or 0
                })
            end
        end

        -- Sort by total minutes descending
        table.sort(grouped, function(a, b) return a.totalMinutes > b.totalMinutes end)

        TriggerClientEvent('sb_police:client:allOfficersDuty', src, grouped)
    end)
end)

-- =============================================
-- Report Improvements (add/remove items, status)
-- =============================================

local function UpdateReportJsonField(src, reportId, fieldName, updateFn)
    -- Validate field name
    local validFields = { suspects = true, victims = true, vehicles = true, evidence = true, officers = true }
    if not validFields[fieldName] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Invalid field', 'error', 3000)
        return
    end

    MySQL.query('SELECT ' .. fieldName .. ' FROM sb_police_reports WHERE id = ?', { reportId }, function(results)
        if not results or #results == 0 then return end

        local raw = results[1][fieldName]
        local ok, decoded = pcall(json.decode, raw or '[]')
        local items = (ok and type(decoded) == 'table') and decoded or {}
        local updatedItems = updateFn(items)
        if not updatedItems then return end

        MySQL.update('UPDATE sb_police_reports SET ' .. fieldName .. ' = ?, updated_at = NOW() WHERE id = ?', {
            json.encode(updatedItems), reportId
        }, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('sb_police:client:reportUpdated', src, reportId, fieldName, updatedItems)
            end
        end)
    end)
end

RegisterNetEvent('sb_police:server:addReportSuspect', function(reportId, citizenId, citizenName)
    local src = source
    UpdateReportJsonField(src, reportId, 'suspects', function(items)
        table.insert(items, citizenName)
        return items
    end)
end)

RegisterNetEvent('sb_police:server:addReportVictim', function(reportId, citizenName)
    local src = source
    UpdateReportJsonField(src, reportId, 'victims', function(items)
        table.insert(items, citizenName)
        return items
    end)
end)

RegisterNetEvent('sb_police:server:addReportVehicle', function(reportId, plate)
    local src = source
    UpdateReportJsonField(src, reportId, 'vehicles', function(items)
        table.insert(items, plate)
        return items
    end)
end)

RegisterNetEvent('sb_police:server:addReportEvidence', function(reportId, text)
    local src = source
    UpdateReportJsonField(src, reportId, 'evidence', function(items)
        table.insert(items, text)
        return items
    end)
end)

RegisterNetEvent('sb_police:server:addReportOfficer', function(reportId, officerName)
    local src = source
    UpdateReportJsonField(src, reportId, 'officers', function(items)
        table.insert(items, officerName)
        return items
    end)
end)

RegisterNetEvent('sb_police:server:removeReportItem', function(reportId, fieldName, index)
    local src = source
    UpdateReportJsonField(src, reportId, fieldName, function(items)
        if index >= 1 and index <= #items then
            table.remove(items, index)
            return items
        end
        return nil
    end)
end)

RegisterNetEvent('sb_police:server:updateReportStatus', function(reportId, status)
    local src = source

    local validStatuses = { open = true, pending = true, closed = true }
    if not validStatuses[status] then return end

    MySQL.update('UPDATE sb_police_reports SET status = ?, updated_at = NOW() WHERE id = ?', {
        status, reportId
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('sb_police:client:reportStatusUpdated', src, reportId, status)
            TriggerClientEvent('sb_notify:client:Notify', src, 'Report status updated to ' .. status, 'success', 3000)
        end
    end)
end)

-- =============================================
-- Citations System
-- =============================================

RegisterNetEvent('sb_police:server:createCitation', function(targetSource, offense, fine, notes, vehiclePlate, location)
    local src = source
    if not SB then return end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    -- Resolve target citizen info
    local citizenId = nil
    local citizenName = 'Unknown'

    if targetSource and type(targetSource) == 'number' then
        local TargetPlayer = SB.Functions.GetPlayer(targetSource)
        if TargetPlayer then
            citizenId = TargetPlayer.PlayerData.citizenid
            citizenName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
        end
    elseif targetSource and type(targetSource) == 'string' then
        -- citizenId passed directly (from MDT)
        citizenId = targetSource
        MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', { citizenId }, function(results)
            if results and #results > 0 then
                local charinfo = json.decode(results[1].charinfo) or {}
                citizenName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Unknown')
            end
        end)
    end

    if not citizenId then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Invalid target', 'error', 3000)
        return
    end

    fine = tonumber(fine) or 0
    offense = tostring(offense or 'Traffic Violation')

    MySQL.insert('INSERT INTO sb_police_citations (citizenid, citizen_name, offense, fine, notes, vehicle_plate, location, officer_id, officer_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        citizenId,
        citizenName,
        offense,
        fine,
        notes or '',
        vehiclePlate or '',
        location or '',
        Player.PlayerData.citizenid,
        officerName
    }, function(id)
        if id then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Citation issued to ' .. citizenName, 'success', 3000)
            -- Notify the citizen if online
            if targetSource and type(targetSource) == 'number' then
                TriggerClientEvent('sb_notify:client:Notify', targetSource, 'You received a citation: ' .. offense .. ' ($' .. fine .. ')', 'error', 8000)
            end
            TriggerClientEvent('sb_police:client:citationCreated', src, id, citizenId)
            print(('[sb_police] %s issued citation to %s: %s ($%d)'):format(officerName, citizenName, offense, fine))
        end
    end)
end)

-- =============================================
-- Citizen Notes
-- =============================================

RegisterNetEvent('sb_police:server:addCitizenNote', function(citizenId, note)
    local src = source
    if not SB then return end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if not note or note == '' then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Note cannot be empty', 'error', 3000)
        return
    end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    MySQL.insert('INSERT INTO sb_police_citizen_notes (citizenid, note, officer_id, officer_name) VALUES (?, ?, ?, ?)', {
        citizenId,
        note,
        Player.PlayerData.citizenid,
        officerName
    }, function(id)
        if id then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Note added', 'success', 3000)
            -- Return updated notes
            MySQL.query('SELECT * FROM sb_police_citizen_notes WHERE citizenid = ? ORDER BY created_at DESC', { citizenId }, function(noteResults)
                local notes = {}
                if noteResults then
                    for _, n in ipairs(noteResults) do
                        table.insert(notes, {
                            id = n.id,
                            note = n.note,
                            officerId = n.officer_id,
                            officerName = n.officer_name,
                            createdAt = n.created_at
                        })
                    end
                end
                TriggerClientEvent('sb_police:client:citizenNotes', src, citizenId, notes)
            end)
        end
    end)
end)

RegisterNetEvent('sb_police:server:deleteCitizenNote', function(noteId, citizenId)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local officerCid = Player.PlayerData.citizenid
    local grade = Player.PlayerData.job.grade.level or 0

    -- Only own notes or boss (grade >= 5) can delete
    MySQL.query('SELECT officer_id FROM sb_police_citizen_notes WHERE id = ?', { noteId }, function(results)
        if not results or #results == 0 then return end

        if results[1].officer_id ~= officerCid and grade < 5 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Can only delete your own notes', 'error', 3000)
            return
        end

        MySQL.query('DELETE FROM sb_police_citizen_notes WHERE id = ?', { noteId }, function()
            TriggerClientEvent('sb_notify:client:Notify', src, 'Note deleted', 'success', 3000)
            -- Return updated notes
            MySQL.query('SELECT * FROM sb_police_citizen_notes WHERE citizenid = ? ORDER BY created_at DESC', { citizenId }, function(noteResults)
                local notes = {}
                if noteResults then
                    for _, n in ipairs(noteResults) do
                        table.insert(notes, {
                            id = n.id,
                            note = n.note,
                            officerId = n.officer_id,
                            officerName = n.officer_name,
                            createdAt = n.created_at
                        })
                    end
                end
                TriggerClientEvent('sb_police:client:citizenNotes', src, citizenId, notes)
            end)
        end)
    end)
end)

-- =============================================
-- Fine Payment (Courthouse)
-- =============================================

RegisterNetEvent('sb_police:server:payFines', function()
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenId = Player.PlayerData.citizenid

    -- Get unpaid criminal records
    MySQL.query('SELECT id, fine, COALESCE(amount_paid, 0) as amount_paid FROM sb_police_criminal_records WHERE citizenid = ? AND paid = 0', { citizenId }, function(records)
        -- Get unpaid citations
        MySQL.query('SELECT id, fine FROM sb_police_citations WHERE citizenid = ? AND paid = 0', { citizenId }, function(citations)
            local totalOwed = 0
            local unpaidRecords = {}
            local unpaidCitations = {}

            if records then
                for _, r in ipairs(records) do
                    local remaining = r.fine - r.amount_paid
                    if remaining > 0 then
                        totalOwed = totalOwed + remaining
                        table.insert(unpaidRecords, { id = r.id, remaining = remaining })
                    end
                end
            end

            if citations then
                for _, c in ipairs(citations) do
                    totalOwed = totalOwed + c.fine
                    table.insert(unpaidCitations, { id = c.id, fine = c.fine })
                end
            end

            if totalOwed == 0 then
                TriggerClientEvent('sb_notify:client:Notify', src, 'You have no outstanding fines', 'info', 3000)
                return
            end

            -- Try to pay
            local cash = Player.Functions.GetMoney('cash')
            local bank = Player.Functions.GetMoney('bank')
            local canPay = cash + bank
            local toPay = math.min(totalOwed, canPay)

            if toPay == 0 then
                TriggerClientEvent('sb_notify:client:Notify', src, 'You don\'t have enough money to pay fines ($' .. totalOwed .. ' owed)', 'error', 5000)
                return
            end

            -- Deduct money
            local remaining = toPay
            if cash >= remaining then
                Player.Functions.RemoveMoney('cash', remaining, 'fine-payment')
                remaining = 0
            elseif cash > 0 then
                Player.Functions.RemoveMoney('cash', cash, 'fine-payment')
                remaining = remaining - cash
            end
            if remaining > 0 then
                Player.Functions.RemoveMoney('bank', remaining, 'fine-payment')
            end

            -- Mark records as paid
            for _, rec in ipairs(unpaidRecords) do
                MySQL.update('UPDATE sb_police_criminal_records SET paid = 1, amount_paid = fine WHERE id = ?', { rec.id })
            end
            for _, cit in ipairs(unpaidCitations) do
                MySQL.update('UPDATE sb_police_citations SET paid = 1 WHERE id = ?', { cit.id })
            end

            if toPay >= totalOwed then
                TriggerClientEvent('sb_notify:client:Notify', src, 'All fines paid ($' .. totalOwed .. ')', 'success', 5000)
            else
                TriggerClientEvent('sb_notify:client:Notify', src, '$' .. toPay .. ' paid. $' .. (totalOwed - toPay) .. ' still outstanding.', 'info', 5000)
            end

            print(('[sb_police] %s paid $%d in fines (owed $%d)'):format(citizenId, toPay, totalOwed))
        end)
    end)
end)

-- =============================================
-- Alert System (delegates to sb_alerts)
-- =============================================
-- sb_police no longer tracks alerts internally.
-- All alerts come from sb_alerts via client events (sb_alerts:client:newAlert/removeAlert/updateResponders).
-- The MDT dispatch page gets real-time updates directly on the client side.

-- =============================================
-- GSR Tracking (Sprint 9)
-- Track when players fire weapons for GSR test
-- =============================================

RegisterNetEvent('sb_police:server:weaponFired', function()
    local src = source
    gsrTracking[src] = os.time()
end)

-- =============================================
-- Player Disconnect (consolidated handler)
-- =============================================

AddEventHandler('playerDropped', function()
    local src = source

    -- Handle duty clock out
    if onDutyOfficers[src] then
        local data = onDutyOfficers[src]
        local clockIn = data.clockIn
        local duration = math.floor((os.time() - clockIn) / 60)

        MySQL.update('UPDATE sb_police_duty_clock SET clock_out = NOW(), duration_minutes = ? WHERE officer_id = ? AND clock_out IS NULL ORDER BY id DESC LIMIT 1', {
            duration,
            data.citizenid
        })

        onDutyOfficers[src] = nil
        print(('[sb_police] %s disconnected while on duty (after %d minutes)'):format(data.name, duration))

        BroadcastOfficerList()
    end

    -- Handle escort cleanup - if this player was escorting someone, release them
    for targetId, officerId in pairs(escortPairs) do
        if officerId == src then
            escortPairs[targetId] = nil
            Player(targetId).state:set('escortedBy', nil, true)
            TriggerClientEvent('sb_police:client:escortReleased', targetId)
        end
    end

    -- If this player was being escorted, clean up
    if escortPairs[src] then
        local officerId = escortPairs[src]
        escortPairs[src] = nil
        TriggerClientEvent('sb_police:client:escortStopped', officerId)
    end

    -- Clear cuff/escort state (StateBag auto-cleans, but belt and suspenders)
    Player(src).state:set('cuffed', nil, true)
    Player(src).state:set('escortedBy', nil, true)

    -- Clear GSR tracking
    gsrTracking[src] = nil
end)

-- =============================================
-- Exports
-- =============================================

exports('GetOnDutyOfficers', function()
    return onDutyOfficers
end)

exports('GetOnDutyCount', function()
    local count = 0
    for _ in pairs(onDutyOfficers) do
        count = count + 1
    end
    return count
end)

exports('IsOfficerOnDuty', function(src)
    return onDutyOfficers[src] ~= nil
end)

exports('AddAlert', function(alertData)
    -- Forward to sb_alerts system for proper dispatch routing
    local ok, _ = pcall(function()
        exports['sb_alerts']:SendAlert('police', {
            type = alertData.type or 'general',
            title = alertData.title or 'Alert',
            location = alertData.location or 'Unknown',
            coords = alertData.coords,
            caller = alertData.caller or 'Dispatch',
            priority = alertData.priority == 'high' and 1 or (alertData.priority == 'low' and 3 or 2),
        })
    end)
    if not ok then
        print('^1[sb_police]^7 Failed to forward alert to sb_alerts')
    end
end)

-- =============================================
-- Field Actions: Cuffing, Escort, Transport, Search
-- =============================================

-- Helper: Validate officer is on duty
local function IsValidOfficer(src)
    if not SB then return false end
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return false end
    if Player.PlayerData.job.name ~= Config.PoliceJob then return false end
    return onDutyOfficers[src] ~= nil
end

-- Cuff player
-- Play paired cuff animation on target (triggered at START of cuff, before progress bar)
RegisterNetEvent('sb_police:server:startCuffAnim', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end
    if not SB.Functions.GetPlayer(targetId) then return end
    -- Tell target to play the being-cuffed animation now
    TriggerClientEvent('sb_police:client:playCuffAnim', targetId, src)
end)

-- Cancel cuff animation on target (if officer cancels progress bar)
RegisterNetEvent('sb_police:server:cancelCuffAnim', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end
    TriggerClientEvent('sb_police:client:cancelCuffAnim', targetId)
end)

RegisterNetEvent('sb_police:server:cuffPlayer', function(targetId, cuffType)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Check if already cuffed
    local currentState = Player(targetId).state.cuffed
    if currentState then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Target is already cuffed', 'error', 3000)
        return
    end

    -- Check if officer has handcuffs in inventory
    if not exports['sb_inventory']:HasItem(src, 'handcuffs', 1) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You need handcuffs', 'error', 3000)
        return
    end

    -- Remove handcuffs from officer inventory
    local removed = exports['sb_inventory']:RemoveItem(src, 'handcuffs', 1)
    if not removed then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Failed to use handcuffs', 'error', 3000)
        return
    end

    -- Set cuffed state via StateBag (syncs to all clients)
    Player(targetId).state:set('cuffed', cuffType, true)

    -- Track which officer cuffed the target (for returning handcuffs on uncuff)
    Player(targetId).state:set('cuffedBy', src, true)

    -- Trigger client event for immediate effects (pass officer ID for paired animation)
    TriggerClientEvent('sb_police:client:applyCuffs', targetId, cuffType, src)

    -- Notify officer
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('sb_notify:client:Notify', src, 'Cuffed ' .. targetName, 'success', 3000)

    print(('[sb_police] Officer %d cuffed player %d (%s cuffs)'):format(src, targetId, cuffType))
end)

-- Uncuff player
RegisterNetEvent('sb_police:server:uncuffPlayer', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Check if actually cuffed
    local currentState = Player(targetId).state.cuffed
    if not currentState then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Target is not cuffed', 'error', 3000)
        return
    end

    -- Return handcuffs to the officer performing the uncuff
    exports['sb_inventory']:AddItem(src, 'handcuffs', 1)

    -- Clear cuffed state
    Player(targetId).state:set('cuffed', nil, true)
    Player(targetId).state:set('cuffedBy', nil, true)

    -- If being escorted, release escort too
    if escortPairs[targetId] then
        local officerId = escortPairs[targetId]
        escortPairs[targetId] = nil
        TriggerClientEvent('sb_police:client:escortStopped', officerId)
        TriggerClientEvent('sb_police:client:escortReleased', targetId)
    end

    -- Trigger client event
    TriggerClientEvent('sb_police:client:removeCuffs', targetId)

    -- Notify officer
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('sb_notify:client:Notify', src, 'Uncuffed ' .. targetName, 'success', 3000)

    print(('[sb_police] Officer %d uncuffed player %d'):format(src, targetId))
end)

-- Start escorting
RegisterNetEvent('sb_police:server:startEscort', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Check if target is cuffed
    local cuffState = Player(targetId).state.cuffed
    if not cuffState then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Target must be cuffed first', 'error', 3000)
        return
    end

    -- Check if already being escorted
    if escortPairs[targetId] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Target is already being escorted', 'error', 3000)
        return
    end

    -- Set escort relationship
    escortPairs[targetId] = src
    Player(targetId).state:set('escortedBy', src, true)

    -- Notify both parties
    TriggerClientEvent('sb_police:client:escortStarted', src, targetId)
    TriggerClientEvent('sb_police:client:beingEscorted', targetId, src)

    print(('[sb_police] Officer %d started escorting player %d'):format(src, targetId))
end)

-- Stop escorting
RegisterNetEvent('sb_police:server:stopEscort', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end

    -- Verify this officer is actually escorting this target
    if escortPairs[targetId] ~= src then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You are not escorting this person', 'error', 3000)
        return
    end

    -- Clear escort relationship
    escortPairs[targetId] = nil
    Player(targetId).state:set('escortedBy', nil, true)

    -- Notify both parties
    TriggerClientEvent('sb_police:client:escortStopped', src)
    TriggerClientEvent('sb_police:client:escortReleased', targetId)

    print(('[sb_police] Officer %d stopped escorting player %d'):format(src, targetId))
end)

-- Put in vehicle
RegisterNetEvent('sb_police:server:putInVehicle', function(targetId, vehicleNetId, seat)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Check if target is cuffed
    local cuffState = Player(targetId).state.cuffed
    if not cuffState then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Target must be cuffed', 'error', 3000)
        return
    end

    -- Clear escort if being escorted
    if escortPairs[targetId] then
        escortPairs[targetId] = nil
        Player(targetId).state:set('escortedBy', nil, true)
    end

    -- Trigger client to warp into vehicle
    TriggerClientEvent('sb_police:client:putInVehicle', targetId, vehicleNetId, seat)

    print(('[sb_police] Officer %d put player %d in vehicle (seat %d)'):format(src, targetId, seat))
end)

-- Take out of vehicle
RegisterNetEvent('sb_police:server:takeOutOfVehicle', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Check if target is cuffed
    local cuffState = Player(targetId).state.cuffed
    if not cuffState then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Target must be cuffed', 'error', 3000)
        return
    end

    -- Trigger client to exit vehicle
    TriggerClientEvent('sb_police:client:takeOutOfVehicle', targetId)

    print(('[sb_police] Officer %d took player %d out of vehicle'):format(src, targetId))
end)

-- =============================================
-- Tackle System
-- =============================================

RegisterNetEvent('sb_police:server:tacklePlayer', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Relay to target client
    TriggerClientEvent('sb_police:client:getTackled', targetId, src)

    print(('[sb_police] Officer %d tackled player %d'):format(src, targetId))
end)

-- Notify player they hit spike strips
RegisterNetEvent('sb_police:server:notifySpikeHit', function(targetId)
    TriggerClientEvent('sb_police:client:spikeHitNotify', targetId)
end)

-- Search player
RegisterNetEvent('sb_police:server:searchPlayer', function(targetId)
    local src = source
    if not IsValidOfficer(src) then return end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then return end

    -- Open target's inventory for the officer
    -- This depends on sb_inventory having this export
    local success = false
    if exports['sb_inventory'] and exports['sb_inventory'].OpenPlayerInventory then
        success = exports['sb_inventory']:OpenPlayerInventory(src, targetId)
    end

    if success then
        TriggerClientEvent('sb_notify:client:Notify', targetId, 'You are being searched', 'info', 3000)
        print(('[sb_police] Officer %d searched player %d'):format(src, targetId))
    else
        -- Fallback: just notify that search happened
        TriggerClientEvent('sb_notify:client:Notify', src, 'Search complete - nothing found', 'info', 3000)
        TriggerClientEvent('sb_notify:client:Notify', targetId, 'You were searched', 'info', 3000)
    end
end)

-- =============================================
-- Test Dummy Stash Setup
-- =============================================

RegisterNetEvent('sb_police:server:setupDummyStash', function(stashId)
    local src = source

    -- Random items the suspect might have (use items that exist in sb_items)
    local possibleItems = {
        { name = 'phone', label = 'Phone', chance = 90 },
        { name = 'water', label = 'Water Bottle', chance = 60 },
        { name = 'sandwich', label = 'Sandwich', chance = 50 },
        { name = 'lockpick', label = 'Lockpick', chance = 30 },
        { name = 'bandage', label = 'Bandage', chance = 40 },
        { name = 'radio', label = 'Radio', chance = 20 }
    }

    -- Build items table
    local dummyItems = {}
    local slot = 1
    for _, item in ipairs(possibleItems) do
        if math.random(100) <= item.chance then
            dummyItems[tostring(slot)] = {
                name = item.name,
                label = item.label,
                amount = math.random(1, 3),
                slot = slot,
                metadata = {}
            }
            slot = slot + 1
        end
    end

    -- Check if stash exists, update or insert
    MySQL.single('SELECT identifier FROM sb_inventory_stashes WHERE identifier = ?', { stashId }, function(result)
        local itemsJson = json.encode(dummyItems)

        if result then
            -- Update existing stash with new random items
            MySQL.update('UPDATE sb_inventory_stashes SET items = ? WHERE identifier = ?', {
                itemsJson,
                stashId
            })
        else
            -- Create new stash
            MySQL.insert('INSERT INTO sb_inventory_stashes (identifier, label, type, slots, items) VALUES (?, ?, ?, ?, ?)', {
                stashId,
                'Suspect Pockets',
                'shared',
                20,
                itemsJson
            })
        end

        print(('[sb_police] ^2Dummy stash "%s" setup^7 with %d items'):format(stashId, slot - 1))
    end)
end)

-- =============================================
-- Station: Armory System (stash-based via sb_inventory)
-- =============================================

RegisterNetEvent('sb_police:server:openArmory', function(grade)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Police only', 'error', 3000)
        return
    end

    if not onDutyOfficers[src] then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You must be on duty', 'error', 3000)
        return
    end

    -- Validate grade from server (don't trust client)
    -- job.grade is a table { name = '...', level = N } — extract numeric level
    local serverGrade = (Player.PlayerData.job.grade and Player.PlayerData.job.grade.level) or 0

    -- Load/create the armory stash via sb_inventory export
    local stashId = 'police_armory'
    local magazines = Config.Armory.magazines or {}
    local totalSlots = #Config.Armory.weapons + #Config.Armory.items + #Config.Armory.ammo + #magazines
    -- Round up to nearest 5 for clean grid
    totalSlots = math.ceil(totalSlots / 5) * 5
    if totalSlots < 20 then totalSlots = 20 end

    -- Ensure stash exists in sb_inventory (creates if needed)
    exports['sb_inventory']:LoadStash(stashId, {
        slots = totalSlots,
        label = 'Armory',
        job = Config.PoliceJob
    })

    -- Build items table locally, then push to sb_inventory in one call
    local items = {}
    local slot = 1

    -- Add weapons (grade-locked ones excluded)
    for _, weapon in ipairs(Config.Armory.weapons) do
        if serverGrade >= (weapon.grade or 0) then
            items[slot] = {
                name = weapon.name,
                amount = 1,
                slot = slot,
                metadata = { serial = 'PD-' .. math.random(1000, 9999), durability = 100 }
            }
            slot = slot + 1
        end
    end

    -- Add equipment items
    for _, item in ipairs(Config.Armory.items) do
        items[slot] = {
            name = item.name,
            amount = item.amount or 1,
            slot = slot,
            metadata = {}
        }
        slot = slot + 1
    end

    -- Magazine capacities (must match sb_weapons/config.lua)
    local magCapacities = {
        ['p_quick_mag'] = 7,
        ['p_stand_mag'] = 10,
        ['p_extended_mag'] = 15,
    }

    -- Add magazines (pre-loaded to full capacity)
    for _, mag in ipairs(magazines) do
        local loaded = magCapacities[mag.name] or 10
        items[slot] = {
            name = mag.name,
            amount = mag.amount or 1,
            slot = slot,
            metadata = { loaded = loaded }
        }
        slot = slot + 1
    end

    -- Add ammo
    for _, ammoItem in ipairs(Config.Armory.ammo) do
        items[slot] = {
            name = ammoItem.name,
            amount = ammoItem.amount or 1,
            slot = slot,
            metadata = {}
        }
        slot = slot + 1
    end

    -- Push items directly into sb_inventory's memory (exports copy tables, so we use SetStashItems)
    exports['sb_inventory']:SetStashItems(stashId, items)

    print(('[sb_police] Armory filled: %d items in %d slots for officer %d (grade %d)'):format(slot - 1, totalSlots, src, serverGrade))

    -- Tell client to open the stash through sb_inventory
    TriggerClientEvent('sb_police:client:openArmoryStash', src, stashId, totalSlots)
end)

-- =============================================
-- Station: Boss Menu (Rank 9 only)
-- =============================================

local function IsBossRank(src)
    if not SB then return false end
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return false end
    if Player.PlayerData.job.name ~= Config.PoliceJob then return false end
    return (Player.PlayerData.job.grade.level or 0) >= 9
end

RegisterNetEvent('sb_police:server:hirePlayer', function(targetId)
    local src = source
    if not IsBossRank(src) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You need rank 9 to do this', 'error', 3000)
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player not found', 'error', 3000)
        return
    end

    -- Set job to police (grade 0 = Cadet)
    targetPlayer.Functions.SetJob(Config.PoliceJob, 0)

    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('sb_notify:client:Notify', src, 'Hired: ' .. targetName, 'success', 3000)
    TriggerClientEvent('sb_notify:client:Notify', targetId, 'You have been hired as a Police Cadet', 'success', 5000)

    print(('[sb_police] Boss %d hired player %d as police'):format(src, targetId))
end)

RegisterNetEvent('sb_police:server:firePlayer', function(targetId)
    local src = source
    if not IsBossRank(src) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You need rank 9 to do this', 'error', 3000)
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player not found', 'error', 3000)
        return
    end

    if targetPlayer.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player is not a police officer', 'error', 3000)
        return
    end

    -- Set job to unemployed
    targetPlayer.Functions.SetJob('unemployed', 0)

    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('sb_notify:client:Notify', src, 'Fired: ' .. targetName, 'success', 3000)
    TriggerClientEvent('sb_notify:client:Notify', targetId, 'You have been fired from the Police Department', 'error', 5000)

    -- If on duty, clock them out
    if onDutyOfficers[targetId] then
        onDutyOfficers[targetId] = nil
        TriggerClientEvent('sb_police:client:updateDuty', targetId, false)
        BroadcastOfficerList()
    end

    print(('[sb_police] Boss %d fired player %d from police'):format(src, targetId))
end)

RegisterNetEvent('sb_police:server:promotePlayer', function(targetId)
    local src = source
    if not IsBossRank(src) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You need rank 9 to do this', 'error', 3000)
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player not found', 'error', 3000)
        return
    end

    if targetPlayer.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player is not a police officer', 'error', 3000)
        return
    end

    local currentGrade = targetPlayer.PlayerData.job.grade.level or 0
    local newGrade = math.min(currentGrade + 1, #Config.Ranks - 1)

    if newGrade == currentGrade then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player is at maximum rank', 'error', 3000)
        return
    end

    targetPlayer.Functions.SetJob(Config.PoliceJob, newGrade)

    local rankName = Config.Ranks[newGrade + 1] and Config.Ranks[newGrade + 1].name or 'Unknown'
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname

    TriggerClientEvent('sb_notify:client:Notify', src, 'Promoted ' .. targetName .. ' to ' .. rankName, 'success', 3000)
    TriggerClientEvent('sb_notify:client:Notify', targetId, 'You have been promoted to ' .. rankName, 'success', 5000)

    print(('[sb_police] Boss %d promoted player %d to grade %d'):format(src, targetId, newGrade))
end)

RegisterNetEvent('sb_police:server:demotePlayer', function(targetId)
    local src = source
    if not IsBossRank(src) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You need rank 9 to do this', 'error', 3000)
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player not found', 'error', 3000)
        return
    end

    if targetPlayer.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player is not a police officer', 'error', 3000)
        return
    end

    local currentGrade = targetPlayer.PlayerData.job.grade.level or 0
    local newGrade = math.max(currentGrade - 1, 0)

    if newGrade == currentGrade then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player is at minimum rank', 'error', 3000)
        return
    end

    targetPlayer.Functions.SetJob(Config.PoliceJob, newGrade)

    local rankName = Config.Ranks[newGrade + 1] and Config.Ranks[newGrade + 1].name or 'Unknown'
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname

    TriggerClientEvent('sb_notify:client:Notify', src, 'Demoted ' .. targetName .. ' to ' .. rankName, 'success', 3000)
    TriggerClientEvent('sb_notify:client:Notify', targetId, 'You have been demoted to ' .. rankName, 'warning', 5000)

    print(('[sb_police] Boss %d demoted player %d to grade %d'):format(src, targetId, newGrade))
end)

RegisterNetEvent('sb_police:server:setPlayerGrade', function(targetId, grade)
    local src = source
    if not IsBossRank(src) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'You need rank 9 to do this', 'error', 3000)
        return
    end

    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player not found', 'error', 3000)
        return
    end

    if targetPlayer.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Player is not a police officer', 'error', 3000)
        return
    end

    grade = math.max(0, math.min(grade, #Config.Ranks - 1))
    targetPlayer.Functions.SetJob(Config.PoliceJob, grade)

    local rankName = Config.Ranks[grade + 1] and Config.Ranks[grade + 1].name or 'Unknown'
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname

    TriggerClientEvent('sb_notify:client:Notify', src, 'Set ' .. targetName .. ' to ' .. rankName, 'success', 3000)
    TriggerClientEvent('sb_notify:client:Notify', targetId, 'Your rank has been set to ' .. rankName, 'info', 5000)

    print(('[sb_police] Boss %d set player %d grade to %d'):format(src, targetId, grade))
end)

-- =============================================
-- Station: Uniform System
-- =============================================

-- Police uniform components (customize these for your server)
local PoliceUniforms = {
    male = {
        [3] = { drawable = 0, texture = 0 },   -- Arms/torso
        [4] = { drawable = 35, texture = 0 },  -- Pants
        [6] = { drawable = 25, texture = 0 },  -- Shoes
        [8] = { drawable = 58, texture = 0 },  -- Shirt
        [11] = { drawable = 55, texture = 0 }, -- Jacket
    },
    female = {
        [3] = { drawable = 0, texture = 0 },
        [4] = { drawable = 34, texture = 0 },
        [6] = { drawable = 25, texture = 0 },
        [8] = { drawable = 35, texture = 0 },
        [11] = { drawable = 48, texture = 0 },
    }
}

RegisterNetEvent('sb_police:server:applyUniform', function()
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Police only', 'error', 3000)
        return
    end

    local gender = Player.PlayerData.charinfo.gender == 0 and 'male' or 'female'
    local uniform = PoliceUniforms[gender]

    TriggerClientEvent('sb_police:client:applyUniformComponents', src, uniform)
    TriggerClientEvent('sb_police:client:uniformApplied', src)

    print(('[sb_police] %s equipped police uniform'):format(Player.PlayerData.charinfo.firstname))
end)

RegisterNetEvent('sb_police:server:applyCivilian', function()
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Police only', 'error', 3000)
        return
    end

    -- Restore saved civilian clothes (if sb_clothing saves them)
    -- For now, just notify - this would integrate with sb_clothing
    TriggerClientEvent('sb_police:client:restoreCivilianClothes', src)
    TriggerClientEvent('sb_police:client:civilianApplied', src)

    print(('[sb_police] %s changed to civilian clothes'):format(Player.PlayerData.charinfo.firstname))
end)

-- =============================================
-- Station: Impound System
-- =============================================

RegisterNetEvent('sb_police:server:impoundVehicle', function(plate)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Police only', 'error', 3000)
        return
    end

    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    -- Update vehicle in database (mark as impounded)
    MySQL.update('UPDATE owned_vehicles SET state = 2, impound_reason = ?, impounded_by = ? WHERE plate = ?', {
        'Police Impound',
        officerName,
        plate
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle impounded: ' .. plate, 'success', 3000)
            print(('[sb_police] %s impounded vehicle: %s'):format(officerName, plate))
        else
            TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle not found in database', 'error', 3000)
        end
    end)
end)

-- Release impounded vehicle
RegisterNetEvent('sb_police:server:releaseImpoundedVehicle', function(plate, coords, heading)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.PoliceJob then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Police only', 'error', 3000)
        return
    end

    -- Get vehicle data from database
    MySQL.query('SELECT vehicle FROM owned_vehicles WHERE plate = ? AND state = 2', { plate }, function(results)
        if not results or #results == 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle not found in impound', 'error', 3000)
            return
        end

        local vehicleModel = results[1].vehicle

        -- Update database - mark as released (state = 0)
        MySQL.update('UPDATE owned_vehicles SET state = 0, impound_reason = NULL, impounded_by = NULL WHERE plate = ?', { plate }, function(affectedRows)
            if affectedRows > 0 then
                -- Tell client to spawn the vehicle
                TriggerClientEvent('sb_police:client:spawnImpoundedVehicle', src, vehicleModel, plate, coords, heading)

                local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
                print(('[sb_police] %s released impounded vehicle: %s'):format(officerName, plate))
            else
                TriggerClientEvent('sb_notify:client:Notify', src, 'Failed to release vehicle', 'error', 3000)
            end
        end)
    end)
end)

-- =============================================
-- Vehicle Keys for Police Garage
-- =============================================

-- Give vehicle keys (as inventory item with plate metadata)
RegisterNetEvent('sb_police:server:giveVehicleKeys', function(plate, vehicleLabel)
    local src = source
    if not SB then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= Config.PoliceJob then return end

    -- Create key metadata matching sb_vehicleshop format
    local keyMetadata = {
        plate = plate,
        label = vehicleLabel or 'Police Vehicle',
        description = 'Keys for ' .. (vehicleLabel or plate)
    }

    -- Add car_keys item to player inventory
    local success = exports['sb_inventory']:AddItem(src, 'car_keys', 1, keyMetadata)

    if success then
        print(('[sb_police] Gave keys for %s to %s'):format(plate, Player.PlayerData.charinfo.firstname))
    else
        -- Fallback notification if inventory fails
        TriggerClientEvent('sb_notify:client:Notify', src, 'Keys added to inventory', 'success', 3000)
    end
end)

-- Remove vehicle keys when storing vehicle
RegisterNetEvent('sb_police:server:removeVehicleKeys', function(plate)
    local src = source
    if not SB then
        print('[sb_police] ^1DEBUG: removeVehicleKeys - SB is nil^7')
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then
        print('[sb_police] ^1DEBUG: removeVehicleKeys - Player not found^7')
        return
    end

    print(('[sb_police] ^3DEBUG: removeVehicleKeys called - plate: %s^7'):format(plate))

    -- Get all car_keys from player inventory
    local keys = exports['sb_inventory']:GetItemsByName(src, 'car_keys')
    print(('[sb_police] ^3DEBUG: Found %d car_keys in inventory^7'):format(keys and #keys or 0))

    if not keys or #keys == 0 then
        print('[sb_police] ^1DEBUG: No car_keys found in inventory^7')
        return
    end

    -- Find and remove the key with matching plate (check both metadata and info)
    local plateClean = plate:gsub('%s+', ''):upper()
    for i, keyItem in ipairs(keys) do
        print(('[sb_police] ^3DEBUG: Checking key %d - slot: %s^7'):format(i, tostring(keyItem.slot)))

        -- Check metadata field (sb_inventory uses metadata)
        local keyPlate = nil
        if keyItem.metadata and keyItem.metadata.plate then
            keyPlate = keyItem.metadata.plate
        elseif keyItem.info and keyItem.info.plate then
            keyPlate = keyItem.info.plate
        end

        if keyPlate then
            local keyPlateClean = keyPlate:gsub('%s+', ''):upper()
            print(('[sb_police] ^3DEBUG: Key plate: %s, Looking for: %s^7'):format(keyPlateClean, plateClean))

            if keyPlateClean == plateClean then
                local removed = exports['sb_inventory']:RemoveItem(src, 'car_keys', 1, keyItem.slot)
                print(('[sb_police] ^2Removed keys for %s from %s (slot %s, success: %s)^7'):format(plate, Player.PlayerData.charinfo.firstname, tostring(keyItem.slot), tostring(removed)))
                return
            end
        else
            print(('[sb_police] ^3DEBUG: Key %d has no plate in metadata^7'):format(i))
        end
    end

    print(('[sb_police] ^1DEBUG: No matching key found for plate %s^7'):format(plate))
end)

-- =============================================
-- Sirens Network Sync
-- =============================================

RegisterNetEvent('sb_police:server:sirenState', function(netId, lightsOn, sirenTone, hornOn)
    local src = source

    -- Store state
    vehicleSirenStates[netId] = {
        lightsOn = lightsOn,
        sirenTone = sirenTone,
        hornOn = hornOn or false
    }

    -- Broadcast to all clients
    TriggerClientEvent('sb_police:client:sirenStateSync', -1, netId, lightsOn, sirenTone, hornOn)
end)

RegisterNetEvent('sb_police:server:hornState', function(netId, hornOn)
    local src = source

    -- Update horn state
    vehicleSirenStates[netId] = vehicleSirenStates[netId] or {}
    vehicleSirenStates[netId].hornOn = hornOn

    -- Broadcast to all clients
    TriggerClientEvent('sb_police:client:hornStateSync', -1, netId, hornOn)
end)

-- Cleanup stale siren states periodically
CreateThread(function()
    while true do
        Wait(30000)  -- Every 30 seconds
        local currentTime = os.time()
        -- Note: We rely on client-side cleanup for destroyed vehicles
        -- Server just maintains the state for network sync
    end
end)

-- =============================================
-- Startup
-- =============================================

CreateThread(function()
    -- Wait for SB to be ready
    while not SB do Wait(100) end
    Wait(500)  -- Extra wait for stability

    -- Create tables if not exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_penal_code (
            id INT(11) NOT NULL AUTO_INCREMENT,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            fine INT(11) NOT NULL DEFAULT 0,
            jail_time INT(11) NOT NULL DEFAULT 0,
            category VARCHAR(50) DEFAULT 'Misdemeanor',
            PRIMARY KEY (id)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_duty_clock (
            id INT(11) NOT NULL AUTO_INCREMENT,
            officer_id VARCHAR(50) NOT NULL,
            officer_name VARCHAR(100) NOT NULL,
            clock_in TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            clock_out TIMESTAMP NULL DEFAULT NULL,
            duration_minutes INT(11) DEFAULT 0,
            PRIMARY KEY (id)
        )
    ]])

    MySQL.query("ALTER TABLE sb_police_duty_clock MODIFY COLUMN officer_id VARCHAR(50) NOT NULL", {}, function() end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_reports (
            id INT(11) NOT NULL AUTO_INCREMENT,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            location VARCHAR(255),
            author_id VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL,
            officers JSON DEFAULT '[]',
            suspects JSON DEFAULT '[]',
            victims JSON DEFAULT '[]',
            vehicles JSON DEFAULT '[]',
            evidence JSON DEFAULT '[]',
            tags JSON DEFAULT '["Open Case"]',
            status VARCHAR(50) DEFAULT 'open',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        )
    ]])

    -- Ensure reports table has correct column types and all JSON columns (may differ on older tables)
    MySQL.query("ALTER TABLE sb_police_reports MODIFY COLUMN `author_id` VARCHAR(50) NOT NULL")
    local reportCols = { 'officers', 'suspects', 'victims', 'vehicles', 'evidence' }
    for _, col in ipairs(reportCols) do
        MySQL.query(("ALTER TABLE sb_police_reports ADD COLUMN IF NOT EXISTS `%s` JSON DEFAULT '[]'"):format(col))
    end

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_criminal_records (
            id INT(11) NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            charges TEXT NOT NULL,
            fine INT(11) NOT NULL DEFAULT 0,
            jail_time INT(11) NOT NULL DEFAULT 0,
            officer_id VARCHAR(50) NOT NULL,
            officer_name VARCHAR(100) NOT NULL,
            paid TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_citizenid (citizenid)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_vehicle_flags (
            id INT(11) NOT NULL AUTO_INCREMENT,
            plate VARCHAR(20) NOT NULL,
            flag_type VARCHAR(50) NOT NULL,
            note TEXT,
            added_by VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_plate (plate)
        )
    ]])

    -- Warrants table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_warrants (
            id INT(11) NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            citizen_name VARCHAR(100) NOT NULL,
            charges TEXT NOT NULL,
            reason TEXT,
            priority VARCHAR(20) DEFAULT 'medium',
            status VARCHAR(20) DEFAULT 'active',
            issued_by VARCHAR(100) NOT NULL,
            issued_by_id VARCHAR(50) NOT NULL,
            closed_by VARCHAR(100),
            closed_reason TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_citizenid (citizenid),
            INDEX idx_status (status)
        )
    ]])

    -- BOLOs table (person BOLOs, separate from vehicle flags)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS sb_police_bolos (
            id INT(11) NOT NULL AUTO_INCREMENT,
            person_name VARCHAR(100) NOT NULL,
            description TEXT NOT NULL,
            reason TEXT NOT NULL,
            last_seen VARCHAR(255),
            priority VARCHAR(20) DEFAULT 'medium',
            status VARCHAR(20) DEFAULT 'active',
            issued_by VARCHAR(100) NOT NULL,
            issued_by_id VARCHAR(50) NOT NULL,
            closed_by VARCHAR(100),
            closed_reason TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_status (status)
        )
    ]])

    -- Create owned_vehicles table for impound system
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS owned_vehicles (
            id INT(11) NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            plate VARCHAR(20) NOT NULL,
            vehicle VARCHAR(100) NOT NULL,
            mods TEXT,
            state TINYINT(1) DEFAULT 0,
            impound_reason TEXT,
            impounded_by VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_plate (plate),
            INDEX idx_citizenid (citizenid)
        )
    ]])

    -- Register callback for impounded vehicles
    SB.Functions.CreateCallback('sb_police:server:getImpoundedVehicles', function(source, cb)
        MySQL.query('SELECT plate, vehicle FROM owned_vehicles WHERE state = 2 ORDER BY id DESC LIMIT 20', {}, function(results)
            local vehicles = {}
            if results then
                for _, row in ipairs(results) do
                    table.insert(vehicles, {
                        plate = row.plate,
                        vehicle = row.vehicle
                    })
                end
            end
            cb(vehicles)
        end)
    end)

    -- Register callback for ALPR plate check
    SB.Functions.CreateCallback('sb_police:server:checkPlateALPR', function(source, cb, plate)
        if not plate or plate == '' then
            cb({})
            return
        end

        MySQL.query('SELECT * FROM sb_police_vehicle_flags WHERE plate = ?',
            { plate },
            function(results)
                local flags = {}
                if results then
                    for _, row in ipairs(results) do
                        table.insert(flags, {
                            type = row.flag_type,
                            note = row.note,
                            addedBy = row.added_by
                        })
                    end
                end
                cb(flags)
            end)
    end)

    -- Register callback for K9 search
    SB.Functions.CreateCallback('sb_police:server:K9Search', function(source, cb, targets)
        local result = { found = false, targetType = nil }

        -- Check players for illegal items
        if targets.players and #targets.players > 0 then
            for _, playerId in ipairs(targets.players) do
                local targetPlayer = SB.Functions.GetPlayer(playerId)
                if targetPlayer then
                    -- Check player inventory for illegal items
                    for itemName, _ in pairs(Config.K9.IllegalItems) do
                        local hasItem = exports['sb_inventory']:HasItem(playerId, itemName)
                        if hasItem then
                            result.found = true
                            result.targetType = 'player'
                            result.targetId = playerId
                            result.item = itemName
                            print(('[sb_police] K9 detected %s on player %d'):format(itemName, playerId))
                            cb(result)
                            return
                        end
                    end
                end
            end
        end

        -- Check vehicles for illegal items (trunk/glovebox stashes)
        if targets.vehicles and #targets.vehicles > 0 then
            for _, plate in ipairs(targets.vehicles) do
                -- Check trunk stash
                local trunkStashId = 'trunk_' .. plate
                local trunkItems = exports['sb_inventory']:GetStashItems(trunkStashId)

                if trunkItems then
                    for slot, item in pairs(trunkItems) do
                        if item and item.name and Config.K9.IllegalItems[item.name] then
                            result.found = true
                            result.targetType = 'vehicle'
                            result.plate = plate
                            result.item = item.name
                            print(('[sb_police] K9 detected %s in vehicle %s (trunk)'):format(item.name, plate))
                            cb(result)
                            return
                        end
                    end
                end

                -- Check glovebox stash
                local gloveboxStashId = 'glovebox_' .. plate
                local gloveboxItems = exports['sb_inventory']:GetStashItems(gloveboxStashId)

                if gloveboxItems then
                    for slot, item in pairs(gloveboxItems) do
                        if item and item.name and Config.K9.IllegalItems[item.name] then
                            result.found = true
                            result.targetType = 'vehicle'
                            result.plate = plate
                            result.item = item.name
                            print(('[sb_police] K9 detected %s in vehicle %s (glovebox)'):format(item.name, plate))
                            cb(result)
                            return
                        end
                    end
                end
            end
        end

        -- Nothing found
        cb(result)
    end)

    -- Register callback for radar item check (Sprint 9)
    SB.Functions.CreateCallback('sb_police:server:hasRadarItem', function(source, cb)
        local itemName = Config.Radar and Config.Radar.Item or 'radar_gun'
        local hasItem = exports['sb_inventory']:HasItem(source, itemName)
        cb(hasItem and true or false)
    end)

    -- Register callback for GSR test (Sprint 9)
    SB.Functions.CreateCallback('sb_police:server:gsrTest', function(source, cb, targetId)
        if not IsValidOfficer(source) then
            cb(false)
            return
        end

        if not targetId then
            cb(false)
            return
        end

        -- Check if target fired a weapon recently
        local lastFired = gsrTracking[targetId]
        if lastFired then
            local elapsed = os.time() - lastFired
            if elapsed <= (Config.GSR and Config.GSR.PositiveWindow or 600) then
                cb(true)  -- Positive
                return
            end
        end

        cb(false)  -- Negative
    end)

    print('[sb_police] ^2Server startup complete - tables and callbacks registered^7')
end)
