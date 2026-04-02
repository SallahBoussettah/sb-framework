local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- DATABASE MIGRATIONS
-- ============================================================================

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS job_public_progress (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            job_id VARCHAR(50) NOT NULL,
            xp INT DEFAULT 0,
            level INT DEFAULT 1,
            total_completions INT DEFAULT 0,
            UNIQUE KEY (citizenid, job_id)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS job_listings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            job_name VARCHAR(50) NOT NULL,
            poster_citizenid VARCHAR(50) NOT NULL,
            poster_name VARCHAR(100) NOT NULL,
            poster_phone VARCHAR(20) NOT NULL,
            active TINYINT(1) DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS job_applications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            listing_id INT NOT NULL,
            applicant_citizenid VARCHAR(50) NOT NULL,
            applicant_name VARCHAR(100) NOT NULL,
            applicant_phone VARCHAR(20) NOT NULL,
            status ENUM('pending','interviewing','accepted','rejected') DEFAULT 'pending',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (listing_id) REFERENCES job_listings(id) ON DELETE CASCADE
        )
    ]])

    -- Migrate status ENUM to include 'interviewing' (safe to run multiple times)
    pcall(function()
        MySQL.query.await([[
            ALTER TABLE job_applications MODIFY COLUMN status ENUM('pending','interviewing','accepted','rejected') DEFAULT 'pending'
        ]])
    end)

    print('[sb_jobs] Database tables verified')
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

-- Phone number cache: citizenid -> { phone, timestamp }
local PhoneCache = {}
local PHONE_CACHE_TTL = 300 -- 5 minutes

local function GetPlayerPhone(Player)
    local citizenid = Player.PlayerData.citizenid

    -- Check cache first
    local cached = PhoneCache[citizenid]
    if cached and (os.time() - cached.timestamp) < PHONE_CACHE_TTL then
        return cached.phone
    end

    local result = MySQL.query.await(
        'SELECT phone_number FROM phone_serials WHERE owner_citizenid = ? LIMIT 1',
        { citizenid }
    )
    local phone = nil
    if result and result[1] and result[1].phone_number then
        phone = result[1].phone_number
    end

    -- Cache the result (even nil, to avoid repeated DB hits)
    PhoneCache[citizenid] = { phone = phone, timestamp = os.time() }
    return phone
end

-- Rate limiting: source -> timestamp of last application
local ApplicationCooldowns = {}
local APPLICATION_COOLDOWN = 30 -- seconds between applications

local function GetPlayerFullName(Player)
    local charinfo = Player.PlayerData.charinfo
    if charinfo then
        return (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    end
    return 'Unknown'
end

local function GetRPJobConfig(jobName)
    for _, job in ipairs(Config.RPJobs) do
        if job.id == jobName then
            return job
        end
    end
    return nil
end

-- ============================================================================
-- CALLBACK: Browse Job Center Data
-- ============================================================================

SB.Functions.CreateCallback('sb_jobs:server:getJobCenterData', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    local citizenid = Player.PlayerData.citizenid
    local job = Player.PlayerData.job

    -- Current RP job info
    local currentJob = {
        name = job.name or 'unemployed',
        label = job.label or 'Unemployed',
        grade = job.grade and job.grade.level or 0,
        gradeLabel = job.grade and job.grade.name or 'None'
    }

    -- Public job progress for this player
    local progressRows = MySQL.query.await('SELECT * FROM job_public_progress WHERE citizenid = ?', { citizenid })
    local progressMap = {}
    if progressRows then
        for _, row in ipairs(progressRows) do
            progressMap[row.job_id] = {
                xp = row.xp,
                level = row.level,
                totalCompletions = row.total_completions
            }
        end
    end

    -- Build public jobs data with player's progress
    local publicJobs = {}
    for jobId, jobCfg in pairs(Config.PublicJobs) do
        local progress = progressMap[jobId] or { xp = 0, level = 1, totalCompletions = 0 }
        local levelData = jobCfg.levels[progress.level] or jobCfg.levels[1]
        local nextLevel = jobCfg.levels[progress.level + 1]

        table.insert(publicJobs, {
            id = jobCfg.id,
            label = jobCfg.label,
            description = jobCfg.description,
            icon = jobCfg.icon,
            level = progress.level,
            maxLevel = #jobCfg.levels,
            xp = progress.xp,
            xpRequired = nextLevel and nextLevel.xpRequired or levelData.xpRequired,
            xpForCurrentLevel = levelData.xpRequired,
            pay = levelData.pay,
            vehicle = jobCfg.vehicleLabels[levelData.vehicle] or levelData.vehicle,
            totalCompletions = progress.totalCompletions,
            levels = {}
        })

        -- Include level milestones for detail panel
        local lastEntry = publicJobs[#publicJobs]
        for _, lv in ipairs(jobCfg.levels) do
            table.insert(lastEntry.levels, {
                level = lv.level,
                xpRequired = lv.xpRequired,
                pay = lv.pay,
                vehicle = jobCfg.vehicleLabels[lv.vehicle] or lv.vehicle
            })
        end
    end

    -- Active RP job listings (active = 1)
    local listings = MySQL.query.await([[
        SELECT id, job_name, poster_name, created_at
        FROM job_listings WHERE active = 1
        ORDER BY created_at DESC
    ]])

    local rpListings = {}
    if listings then
        for _, listing in ipairs(listings) do
            local rpCfg = GetRPJobConfig(listing.job_name)
            if rpCfg then
                table.insert(rpListings, {
                    listingId = listing.id,
                    jobId = rpCfg.id,
                    label = rpCfg.label,
                    description = rpCfg.description,
                    icon = rpCfg.icon,
                    category = rpCfg.category,
                    pay = rpCfg.pay,
                    posterName = listing.poster_name,
                    createdAt = listing.created_at
                })
            end
        end
    end

    -- Check if player has an active public job
    local activePublicJob = nil
    if ActivePublicJobs and ActivePublicJobs[source] then
        activePublicJob = ActivePublicJobs[source].jobId
    end

    -- Get listing IDs the player has already applied to
    local appliedListings = {}
    local apps = MySQL.query.await(
        'SELECT listing_id FROM job_applications WHERE applicant_citizenid = ?',
        { citizenid }
    )
    if apps then
        for _, app in ipairs(apps) do
            appliedListings[tostring(app.listing_id)] = true
        end
    end

    -- Check player requirements
    local idCards = exports['sb_inventory']:GetItemsByName(source, 'id_card')
    local hasIdCard = idCards and #idCards > 0
    local phone = GetPlayerPhone(Player)
    local hasPhone = phone ~= nil

    cb({
        currentJob = currentJob,
        publicJobs = publicJobs,
        rpListings = rpListings,
        activePublicJob = activePublicJob,
        appliedListings = appliedListings,
        hasIdCard = hasIdCard,
        hasPhone = hasPhone
    })
end)

-- ============================================================================
-- CALLBACK: Boss Management Data
-- ============================================================================

SB.Functions.CreateCallback('sb_jobs:server:getBossData', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    local job = Player.PlayerData.job
    if not job.isboss then
        cb(nil)
        return
    end

    local jobName = job.name
    local rpCfg = GetRPJobConfig(jobName)

    -- Get current listing for this job (prioritize active, then most recent)
    local listing = MySQL.query.await([[
        SELECT * FROM job_listings
        WHERE job_name = ? AND poster_citizenid = ?
        ORDER BY active DESC, created_at DESC LIMIT 1
    ]], { jobName, Player.PlayerData.citizenid })

    local listingData = nil
    local applications = {}

    if listing and listing[1] then
        local row = listing[1]
        local isActive = (row.active == 1 or row.active == true or tonumber(row.active) == 1)
        listingData = {
            id = row.id,
            active = isActive,
            createdAt = row.created_at
        }

        -- Get applications for this listing
        if isActive then
            local apps = MySQL.query.await([[
                SELECT * FROM job_applications
                WHERE listing_id = ?
                ORDER BY created_at DESC
            ]], { row.id })

            if apps then
                for _, app in ipairs(apps) do
                    table.insert(applications, {
                        id = app.id,
                        name = app.applicant_name,
                        phone = app.applicant_phone,
                        status = app.status,
                        createdAt = app.created_at
                    })
                end
            end
        end
    end

    local phone = GetPlayerPhone(Player)

    cb({
        jobName = jobName,
        jobLabel = rpCfg and rpCfg.label or job.label,
        jobIcon = rpCfg and rpCfg.icon or 'fa-briefcase',
        listing = listingData,
        applications = applications,
        hasPhone = phone ~= nil
    })
end)

-- ============================================================================
-- EVENT: Toggle Hiring Listing
-- ============================================================================

RegisterNetEvent('sb_jobs:server:toggleListing', function(active)
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    local job = Player.PlayerData.job
    if not job.isboss then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You are not a boss', 'error')
        return
    end

    local jobName = job.name
    local citizenid = Player.PlayerData.citizenid
    local fullName = GetPlayerFullName(Player)
    local phone = GetPlayerPhone(Player)

    if not phone then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You need an activated phone to manage job listings', 'error')
        return
    end

    if active then
        -- Check if an active listing already exists for this job by this boss
        local existing = MySQL.query.await(
            'SELECT id FROM job_listings WHERE job_name = ? AND poster_citizenid = ? AND active = 1 LIMIT 1',
            { jobName, citizenid }
        )

        if existing and existing[1] then
            -- Already active, nothing to do
            TriggerClientEvent('sb_jobs:client:notify', source, 'Hiring listing is already active', 'info')
            return
        end

        -- Create new active listing
        MySQL.insert('INSERT INTO job_listings (job_name, poster_citizenid, poster_name, poster_phone, active) VALUES (?, ?, ?, ?, 1)',
            { jobName, citizenid, fullName, phone or '' })

        TriggerClientEvent('sb_jobs:client:notify', source, 'Hiring listing posted! Players can now apply at the Job Center.', 'success')
    else
        -- Deactivate all listings for this job by this boss
        MySQL.query('UPDATE job_listings SET active = 0 WHERE job_name = ? AND poster_citizenid = ? AND active = 1',
            { jobName, citizenid })

        TriggerClientEvent('sb_jobs:client:notify', source, 'Hiring listing removed.', 'info')
    end
end)

-- ============================================================================
-- EVENT: Apply for RP Job
-- ============================================================================

RegisterNetEvent('sb_jobs:server:applyRPJob', function(listingId)
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    -- Rate limiting
    local now = os.time()
    if ApplicationCooldowns[source] and (now - ApplicationCooldowns[source]) < APPLICATION_COOLDOWN then
        local remaining = APPLICATION_COOLDOWN - (now - ApplicationCooldowns[source])
        TriggerClientEvent('sb_jobs:client:notify', source, 'Please wait ' .. remaining .. 's before applying again', 'error')
        return
    end

    -- Validate listingId type
    if type(listingId) ~= 'number' then return end

    local citizenid = Player.PlayerData.citizenid
    local fullName = GetPlayerFullName(Player)
    local phone = GetPlayerPhone(Player)

    if not phone then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You need a phone to apply for jobs', 'error')
        return
    end

    -- Validate listing exists and is active
    local listing = MySQL.query.await('SELECT * FROM job_listings WHERE id = ? AND active = 1', { listingId })
    if not listing or not listing[1] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'This listing is no longer available', 'error')
        return
    end
    listing = listing[1]

    -- Check if already applied
    local existing = MySQL.query.await(
        'SELECT id FROM job_applications WHERE listing_id = ? AND applicant_citizenid = ?',
        { listingId, citizenid }
    )
    if existing and existing[1] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You have already applied for this position', 'error')
        return
    end

    -- Insert application
    MySQL.insert('INSERT INTO job_applications (listing_id, applicant_citizenid, applicant_name, applicant_phone, status) VALUES (?, ?, ?, ?, ?)',
        { listingId, citizenid, fullName, phone, 'pending' })

    -- Set cooldown
    ApplicationCooldowns[source] = os.time()

    TriggerClientEvent('sb_jobs:client:notify', source, 'Application submitted! The employer will be notified.', 'success')

    -- Send SMS to boss via sb_phone
    local bossPhone = listing.poster_phone
    if bossPhone and bossPhone ~= '' then
        local rpCfg = GetRPJobConfig(listing.job_name)
        local jobLabel = rpCfg and rpCfg.label or listing.job_name
        local smsText = 'JOB APPLICATION: ' .. fullName .. ' has applied for ' .. jobLabel .. '. Phone: ' .. phone

        -- Insert message into phone_messages table
        MySQL.insert('INSERT INTO phone_messages (sender_number, receiver_number, message, is_read, created_at) VALUES (?, ?, ?, 0, NOW())',
            { Config.SystemPhone, bossPhone, smsText })

        -- If boss is online, notify them
        local BossPlayer = SB.Functions.GetPlayerByCitizenId(listing.poster_citizenid)
        if BossPlayer then
            local bossSource = BossPlayer.PlayerData.source
            TriggerClientEvent('sb_phone:client:newMessage', bossSource, {
                senderNumber = Config.SystemPhone,
                senderName = 'Job Center',
                message = smsText
            })
        end
    end
end)

-- ============================================================================
-- EVENT: Update Application Status
-- ============================================================================

RegisterNetEvent('sb_jobs:server:updateAppStatus', function(appId, newStatus)
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    -- Validate parameter types
    if type(appId) ~= 'number' or type(newStatus) ~= 'string' then return end

    local job = Player.PlayerData.job
    if not job.isboss then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You are not a boss', 'error')
        return
    end

    local validStatuses = { interviewing = true, accepted = true, rejected = true }
    if not validStatuses[newStatus] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'Invalid status', 'error')
        return
    end

    -- Verify this application belongs to a listing owned by this boss
    local result = MySQL.query.await([[
        SELECT ja.id, jl.poster_citizenid FROM job_applications ja
        JOIN job_listings jl ON ja.listing_id = jl.id
        WHERE ja.id = ? AND jl.poster_citizenid = ?
    ]], { appId, Player.PlayerData.citizenid })

    if not result or not result[1] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'Application not found', 'error')
        return
    end

    MySQL.query('UPDATE job_applications SET status = ? WHERE id = ?', { newStatus, appId })

    local statusLabels = { interviewing = 'Interviewing', accepted = 'Accepted', rejected = 'Rejected' }
    TriggerClientEvent('sb_jobs:client:notify', source, 'Application marked as ' .. statusLabels[newStatus], 'success')
end)

-- ============================================================================
-- CLEANUP THREAD: Old applications + stale listings
-- Runs every 6 hours
-- ============================================================================

CreateThread(function()
    -- Wait for DB to be ready
    Wait(10000)

    while true do
        -- Delete applications older than 30 days
        local deleted = MySQL.query.await(
            'DELETE FROM job_applications WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)'
        )
        if deleted and deleted.affectedRows and deleted.affectedRows > 0 then
            print('[sb_jobs] Cleaned up ' .. deleted.affectedRows .. ' old applications (>30 days)')
        end

        -- Deactivate listings older than 14 days
        local deactivated = MySQL.query.await(
            'UPDATE job_listings SET active = 0 WHERE active = 1 AND created_at < DATE_SUB(NOW(), INTERVAL 14 DAY)'
        )
        if deactivated and deactivated.affectedRows and deactivated.affectedRows > 0 then
            print('[sb_jobs] Deactivated ' .. deactivated.affectedRows .. ' stale listings (>14 days)')
        end

        -- Clear stale cooldown entries
        local now = os.time()
        for src, ts in pairs(ApplicationCooldowns) do
            if (now - ts) > APPLICATION_COOLDOWN then
                ApplicationCooldowns[src] = nil
            end
        end

        -- Clear stale phone cache entries
        for cid, cached in pairs(PhoneCache) do
            if (now - cached.timestamp) > PHONE_CACHE_TTL then
                PhoneCache[cid] = nil
            end
        end

        Wait(6 * 60 * 60 * 1000) -- 6 hours
    end
end)

-- Clean up cooldowns on player drop
AddEventHandler('playerDropped', function()
    local source = source
    ApplicationCooldowns[source] = nil
end)
