local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- PUBLIC JOB SERVER FRAMEWORK
-- Job-specific files register handlers into PublicJobServerHandlers[jobId]
-- ============================================================================

PublicJobServerHandlers = {}
-- PublicJobServerHandlers['pizza_delivery'] = {
--     onRequestBatch     = function(source, activeData, jobCfg) end,
--     onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg) return true end,
-- }

-- ============================================================================
-- IN-MEMORY TRACKING
-- ============================================================================

ActivePublicJobs = {}
-- ActivePublicJobs[source] = { jobId, citizenid, ... (job-specific state set by handlers) }

-- ============================================================================
-- GENERIC HELPERS
-- ============================================================================

local function GetLevelForXP(jobCfg, xp)
    local currentLevel = 1
    for _, lv in ipairs(jobCfg.levels) do
        if xp >= lv.xpRequired then
            currentLevel = lv.level
        else
            break
        end
    end
    return currentLevel
end

local function GetLevelData(jobCfg, level)
    return jobCfg.levels[level] or jobCfg.levels[1]
end

--- Remove job vehicle keys matching a specific plate from a player's inventory
---@param source number Player server ID
---@param plate string The plate text to match
---@return boolean removed Whether a key was found and removed
local function RemoveJobKeys(source, plate)
    if not plate then return false end
    local ok, keys = pcall(exports['sb_inventory'].GetItemsByName, exports['sb_inventory'], source, 'car_keys')
    if not ok or not keys then return false end
    for _, keyItem in ipairs(keys) do
        if keyItem.metadata and keyItem.metadata.plate == plate then
            exports['sb_inventory']:RemoveItem(source, 'car_keys', 1, keyItem.slot)
            return true
        end
    end
    return false
end

-- ============================================================================
-- START PUBLIC JOB
-- ============================================================================

RegisterNetEvent('sb_jobs:server:startPublicJob', function(jobId)
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    -- Validate jobId is a string
    if type(jobId) ~= 'string' then return end

    if ActivePublicJobs[source] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You already have an active public job', 'error')
        return
    end

    local jobCfg = Config.PublicJobs[jobId]
    if not jobCfg then
        TriggerClientEvent('sb_jobs:client:notify', source, 'Invalid job', 'error')
        return
    end

    -- Require ID card
    local idCards = exports['sb_inventory']:GetItemsByName(source, 'id_card')
    if not idCards or #idCards == 0 then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You need a valid ID card to work. Visit City Hall to get one.', 'error')
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get or create progress
    local progress = MySQL.query.await(
        'SELECT * FROM job_public_progress WHERE citizenid = ? AND job_id = ?',
        { citizenid, jobId }
    )

    local xp, level
    if progress and progress[1] then
        xp = progress[1].xp
        level = progress[1].level
    else
        xp = 0
        level = 1
        MySQL.insert(
            'INSERT INTO job_public_progress (citizenid, job_id, xp, level, total_completions) VALUES (?, ?, 0, 1, 0)',
            { citizenid, jobId }
        )
    end

    local levelData = GetLevelData(jobCfg, level)

    -- Check if starting vehicle requires a license
    if jobCfg.requiresLicense and jobCfg.requiresLicense[levelData.vehicle] then
        local licenseItem = jobCfg.requiresLicense[levelData.vehicle]
        local licenses = exports['sb_inventory']:GetItemsByName(source, licenseItem)
        if not licenses or #licenses == 0 then
            local vehicleLabel = (jobCfg.vehicleLabels and jobCfg.vehicleLabels[levelData.vehicle]) or levelData.vehicle
            TriggerClientEvent('sb_jobs:client:notify', source, 'You need a driver\'s license to operate the ' .. vehicleLabel .. '. Visit City Hall to get one.', 'error')
            return
        end
    end

    -- Generate a job plate for keys
    local plate = 'DLVR' .. math.random(1000, 9999)

    -- Give vehicle keys
    local vehicleLabel = (jobCfg.vehicleLabels and jobCfg.vehicleLabels[levelData.vehicle]) or levelData.vehicle
    exports['sb_inventory']:AddItem(source, 'car_keys', 1, {
        plate = plate,
        vehicle = levelData.vehicle,
        label = vehicleLabel .. ' (Job)'
    })

    -- Track active job (job-specific handlers can add fields to this table)
    ActivePublicJobs[source] = {
        jobId = jobId,
        citizenid = citizenid,
        plate = plate,
        level = level,
        currentVehicle = levelData.vehicle,
    }

    print('[sb_jobs] Player ' .. source .. ' started ' .. jobId .. ' (Level ' .. level .. ', Plate: ' .. plate .. ')')

    TriggerClientEvent('sb_jobs:client:jobStarted', source, {
        jobId = jobId,
        level = level,
        pay = levelData.pay,
        vehicleModel = levelData.vehicle,
        plate = plate,
    })
end)

-- ============================================================================
-- REQUEST BATCH — delegates to job-specific handler
-- ============================================================================

RegisterNetEvent('sb_jobs:server:requestBatch', function(jobId)
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= jobId then return end

    local jobCfg = Config.PublicJobs[jobId]
    if not jobCfg then return end

    local handler = PublicJobServerHandlers[jobId]
    if handler and handler.onRequestBatch then
        handler.onRequestBatch(source, active, jobCfg)
    end
end)

-- ============================================================================
-- COMPLETE DELIVERY — generic XP/pay + job-specific validation
-- ============================================================================

RegisterNetEvent('sb_jobs:server:completeDelivery', function(jobId, deliveryIndex)
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= jobId then return end

    local jobCfg = Config.PublicJobs[jobId]
    if not jobCfg then return end

    -- Job-specific validation (distance check, batch bounds, etc.)
    local handler = PublicJobServerHandlers[jobId]
    if handler and handler.onValidateDelivery then
        local valid = handler.onValidateDelivery(source, deliveryIndex, active, jobCfg)
        if not valid then return end
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get current progress
    local progress = MySQL.query.await(
        'SELECT * FROM job_public_progress WHERE citizenid = ? AND job_id = ?',
        { citizenid, jobId }
    )
    if not progress or not progress[1] then return end

    local currentXP = progress[1].xp
    local currentLevel = progress[1].level
    local completions = progress[1].total_completions

    -- Calculate pay
    local levelData = GetLevelData(jobCfg, currentLevel)
    local basePay = levelData.pay

    -- Allow job-specific tip calculation (e.g., quality-based tips for taxi)
    local tip
    local handler = PublicJobServerHandlers[jobId]
    if handler and handler.onCalculateTip then
        tip = handler.onCalculateTip(source, active, jobCfg)
    else
        tip = math.random(jobCfg.tipMin, jobCfg.tipMax)
    end

    local totalPay = basePay + tip

    -- Add XP (bounded to prevent overflow)
    local xpGain = math.max(0, tonumber(jobCfg.xpPerDelivery) or 0)
    local newXP = math.min((currentXP or 0) + xpGain, 999999)
    local newLevel = GetLevelForXP(jobCfg, newXP)
    local maxLevel = #jobCfg.levels
    if newLevel > maxLevel then newLevel = maxLevel end
    local newCompletions = (completions or 0) + 1

    -- Update DB
    MySQL.query('UPDATE job_public_progress SET xp = ?, level = ?, total_completions = ? WHERE citizenid = ? AND job_id = ?',
        { newXP, newLevel, newCompletions, citizenid, jobId })

    -- Pay player
    Player.Functions.AddMoney('cash', totalPay, jobId)

    -- Build response
    local responseData = {
        index = deliveryIndex,
        pay = basePay,
        tip = tip,
        xp = jobCfg.xpPerDelivery,
        totalXp = newXP,
        level = currentLevel,
        newLevel = newLevel
    }

    if newLevel > currentLevel then
        local newLevelData = GetLevelData(jobCfg, newLevel)
        responseData.newVehicle = newLevelData.vehicle
        responseData.newPay = newLevelData.pay
        -- Update level in active tracking so restaurant selection can use it
        active.level = newLevel

        -- Check if vehicle type changes — set pending swap
        if newLevelData.vehicle ~= active.currentVehicle then
            active.pendingSwapVehicle = newLevelData.vehicle
            responseData.pendingSwap = true
            responseData.pendingSwapVehicle = newLevelData.vehicle

            -- Check if new vehicle requires a license
            if jobCfg.requiresLicense and jobCfg.requiresLicense[newLevelData.vehicle] then
                responseData.swapRequiresLicense = jobCfg.requiresLicense[newLevelData.vehicle]
            end
        end
    end

    TriggerClientEvent('sb_jobs:client:deliveryComplete', source, responseData)
end)

-- ============================================================================
-- SWAP VEHICLE (player returned to Job Center to swap after level-up)
-- ============================================================================

RegisterNetEvent('sb_jobs:server:swapVehicle', function()
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    local active = ActivePublicJobs[source]
    if not active then return end

    local newVehicle = active.pendingSwapVehicle
    if not newVehicle then
        TriggerClientEvent('sb_jobs:client:notify', source, 'No vehicle swap pending', 'error')
        return
    end

    local jobCfg = Config.PublicJobs[active.jobId]
    if not jobCfg then return end

    -- Check license requirement for the new vehicle
    if jobCfg.requiresLicense and jobCfg.requiresLicense[newVehicle] then
        local licenseItem = jobCfg.requiresLicense[newVehicle]
        local licenses = exports['sb_inventory']:GetItemsByName(source, licenseItem)
        if not licenses or #licenses == 0 then
            local vehicleLabel = (jobCfg.vehicleLabels and jobCfg.vehicleLabels[newVehicle]) or newVehicle
            -- Clear pending swap so player can continue working
            active.pendingSwapVehicle = nil
            TriggerClientEvent('sb_jobs:client:swapResult', source, {
                success = false,
                reason = 'You need a driver\'s license to operate the ' .. vehicleLabel .. '. Visit City Hall to get one.'
            })
            return
        end
    end

    -- Remove old vehicle keys
    RemoveJobKeys(source, active.plate)

    -- Generate new plate and give new keys
    local newPlate = 'DLVR' .. math.random(1000, 9999)
    local vehicleLabel = (jobCfg.vehicleLabels and jobCfg.vehicleLabels[newVehicle]) or newVehicle
    exports['sb_inventory']:AddItem(source, 'car_keys', 1, {
        plate = newPlate,
        vehicle = newVehicle,
        label = vehicleLabel .. ' (Job)'
    })

    -- Update active tracking
    active.plate = newPlate
    active.currentVehicle = newVehicle
    active.pendingSwapVehicle = nil

    TriggerClientEvent('sb_jobs:client:swapResult', source, {
        success = true,
        vehicleModel = newVehicle,
        plate = newPlate,
        vehicleLabel = vehicleLabel,
    })
end)

-- ============================================================================
-- REPORT QUALITY SCORE (used by taxi and similar quality-based jobs)
-- ============================================================================

RegisterNetEvent('sb_jobs:server:reportQuality', function(qualityScore)
    local source = source
    local active = ActivePublicJobs[source]
    if not active then return end
    active.qualityScore = qualityScore
end)

-- ============================================================================
-- QUIT PUBLIC JOB
-- ============================================================================

RegisterNetEvent('sb_jobs:server:quitPublicJob', function()
    local source = source
    local active = ActivePublicJobs[source]
    if not active then return end

    -- Job-specific server cleanup
    local handler = PublicJobServerHandlers[active.jobId]
    if handler and handler.onEnd then
        handler.onEnd(source, active)
    end

    RemoveJobKeys(source, active.plate)

    ActivePublicJobs[source] = nil
    TriggerClientEvent('sb_jobs:client:jobEnded', source)
end)

-- ============================================================================
-- PLAYER DROPPED
-- ============================================================================

-- ============================================================================
-- VEHICLE CONFISCATED (player went off-route)
-- ============================================================================

RegisterNetEvent('sb_jobs:server:vehicleConfiscated', function()
    local source = source
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    local active = ActivePublicJobs[source]
    if not active then return end

    -- Job-specific server cleanup
    local handler = PublicJobServerHandlers[active.jobId]
    if handler and handler.onEnd then
        handler.onEnd(source, active)
    end

    -- Fine $100 (cash first, then bank)
    local cash = Player.PlayerData.money and Player.PlayerData.money['cash'] or 0
    if cash >= 100 then
        Player.Functions.RemoveMoney('cash', 100, 'job-vehicle-misuse')
    else
        Player.Functions.RemoveMoney('bank', 100, 'job-vehicle-misuse')
    end

    RemoveJobKeys(source, active.plate)

    ActivePublicJobs[source] = nil
    TriggerClientEvent('sb_jobs:client:jobEnded', source)
    TriggerClientEvent('sb_jobs:client:notify', source, 'Your job vehicle was confiscated for going off-route. $100 fine deducted.', 'error')
end)

-- ============================================================================
-- PLAYER DROPPED
-- ============================================================================

AddEventHandler('playerDropped', function()
    local source = source
    local active = ActivePublicJobs[source]
    if active then
        -- Job-specific server cleanup
        local handler = PublicJobServerHandlers[active.jobId]
        if handler and handler.onEnd then
            handler.onEnd(source, active)
        end

        if active.plate then
            RemoveJobKeys(source, active.plate)
        end
        print('[sb_jobs] Cleaned up active job for dropped player ' .. source .. ' (job: ' .. (active.jobId or '?') .. ')')
    end
    ActivePublicJobs[source] = nil
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

--- /jobforceend [id] — Force-end a player's active public job
RegisterCommand('jobforceend', function(source, args)
    if source > 0 and not exports['sb_admin']:IsAdmin() then return end

    local targetId = tonumber(args[1])
    if not targetId then
        if source == 0 then
            print('[sb_jobs] Usage: jobforceend <player_id>')
        else
            TriggerClientEvent('sb_jobs:client:notify', source, 'Usage: /jobforceend <player_id>', 'error')
        end
        return
    end

    local active = ActivePublicJobs[targetId]
    if not active then
        local msg = 'Player ' .. targetId .. ' has no active public job'
        if source == 0 then print('[sb_jobs] ' .. msg) else TriggerClientEvent('sb_jobs:client:notify', source, msg, 'error') end
        return
    end

    -- Job-specific server cleanup
    local handler = PublicJobServerHandlers[active.jobId]
    if handler and handler.onEnd then
        handler.onEnd(targetId, active)
    end

    RemoveJobKeys(targetId, active.plate)
    ActivePublicJobs[targetId] = nil
    TriggerClientEvent('sb_jobs:client:jobEnded', targetId)

    local msg = 'Force-ended ' .. active.jobId .. ' job for player ' .. targetId
    print('[sb_jobs] ' .. msg)
    if source > 0 then
        TriggerClientEvent('sb_jobs:client:notify', source, msg, 'success')
    end
end, false)

--- /jobresetprogress [id] [job_id] — Reset a player's XP/level for a specific job
RegisterCommand('jobresetprogress', function(source, args)
    if source > 0 and not exports['sb_admin']:IsAdmin() then return end

    local targetId = tonumber(args[1])
    local jobId = args[2]
    if not targetId or not jobId then
        local msg = 'Usage: jobresetprogress <player_id> <job_id> (taxi_driver, pizza_delivery, bus_driver)'
        if source == 0 then print('[sb_jobs] ' .. msg) else TriggerClientEvent('sb_jobs:client:notify', source, msg, 'error') end
        return
    end

    if not Config.PublicJobs[jobId] then
        local msg = 'Invalid job: ' .. jobId
        if source == 0 then print('[sb_jobs] ' .. msg) else TriggerClientEvent('sb_jobs:client:notify', source, msg, 'error') end
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        local msg = 'Player ' .. targetId .. ' not found'
        if source == 0 then print('[sb_jobs] ' .. msg) else TriggerClientEvent('sb_jobs:client:notify', source, msg, 'error') end
        return
    end

    local citizenid = Player.PlayerData.citizenid
    MySQL.query.await('UPDATE job_public_progress SET xp = 0, level = 1, total_completions = 0 WHERE citizenid = ? AND job_id = ?',
        { citizenid, jobId })

    local msg = 'Reset ' .. jobId .. ' progress for player ' .. targetId .. ' (' .. citizenid .. ')'
    print('[sb_jobs] ' .. msg)
    if source > 0 then
        TriggerClientEvent('sb_jobs:client:notify', source, msg, 'success')
    end
end, false)

--- /jobactivelist — Show all players with active public jobs
RegisterCommand('jobactivelist', function(source)
    if source > 0 and not exports['sb_admin']:IsAdmin() then return end

    local count = 0
    for playerId, active in pairs(ActivePublicJobs) do
        count = count + 1
        local msg = '  [' .. playerId .. '] ' .. active.jobId .. ' (Level ' .. (active.level or '?') .. ', Plate: ' .. (active.plate or '?') .. ')'
        if source == 0 then print(msg) else TriggerClientEvent('sb_jobs:client:notify', source, msg, 'info') end
    end

    local summary = count > 0 and (count .. ' active public jobs') or 'No active public jobs'
    if source == 0 then print('[sb_jobs] ' .. summary) else TriggerClientEvent('sb_jobs:client:notify', source, summary, 'info') end
end, false)
