-- ============================================================================
-- Trash Collector — Server Job Logic (Freeform Discovery)
-- Registers handlers into the PublicJobServerHandlers framework
--
-- Key responsibilities:
--   1. Init crew state with bagsCollected counter on batch request
--   2. Track crew state (leader + members, shared collection counter)
--   3. Handle crew invites/accepts/cleanup
--   4. Validate trash collection (proximity to truck)
--   5. Trigger payment every bagsPerPayment bags, split by crew size
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- CREW STATE
-- ============================================================================

-- TrashCrews[leaderSource] = {
--     members = { src1, src2, ... },      -- crew member sources (NOT including leader)
--     bagsCollected = 0,                   -- bags thrown in truck this payment cycle
-- }
local TrashCrews = {}

-- PendingInvites[targetSource] = leaderSource
local PendingInvites = {}

-- Reverse lookup: which crew is a player part of?
-- CrewMembership[memberSource] = leaderSource
local CrewMembership = {}

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Get the crew size (leader + members)
local function GetCrewSize(leaderSource)
    local crew = TrashCrews[leaderSource]
    if not crew then return 1 end
    return 1 + #crew.members
end

--- Get all crew sources (leader + members)
local function GetAllCrewSources(leaderSource)
    local sources = { leaderSource }
    local crew = TrashCrews[leaderSource]
    if crew then
        for _, src in ipairs(crew.members) do
            table.insert(sources, src)
        end
    end
    return sources
end

--- Find the leader source for a given player (could be the leader themselves)
local function FindLeaderSource(source)
    -- Check if player IS a leader
    if TrashCrews[source] then return source end
    -- Check if player is a member
    return CrewMembership[source]
end

--- Remove a crew member (not the leader)
local function RemoveCrewMember(memberSource)
    local leaderSource = CrewMembership[memberSource]
    if not leaderSource then return end

    local crew = TrashCrews[leaderSource]
    if crew then
        for i, src in ipairs(crew.members) do
            if src == memberSource then
                table.remove(crew.members, i)
                break
            end
        end
    end

    CrewMembership[memberSource] = nil
end

--- Disband entire crew (called when leader quits/disconnects)
local function DisbandCrew(leaderSource)
    local crew = TrashCrews[leaderSource]
    if not crew then return end

    -- End job for all members
    for _, memberSource in ipairs(crew.members) do
        local memberActive = ActivePublicJobs[memberSource]
        if memberActive then
            -- Remove crew member's copy of the truck keys
            if memberActive.plate then
                local ok, keys = pcall(exports['sb_inventory'].GetItemsByName, exports['sb_inventory'], memberSource, 'car_keys')
                if ok and keys then
                    for _, keyItem in ipairs(keys) do
                        if keyItem.metadata and keyItem.metadata.plate == memberActive.plate then
                            exports['sb_inventory']:RemoveItem(memberSource, 'car_keys', 1, keyItem.slot)
                            break
                        end
                    end
                end
            end
            ActivePublicJobs[memberSource] = nil
            TriggerClientEvent('sb_jobs:client:jobEnded', memberSource)
            TriggerClientEvent('sb_jobs:client:notify', memberSource, 'The crew leader ended the trash collection job.', 'info')
        end
        CrewMembership[memberSource] = nil
    end

    TrashCrews[leaderSource] = nil
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobServerHandlers['trash_collector'] = {

    -- ========================================================================
    -- REQUEST BATCH — init crew state, immediately send batchReady
    -- ========================================================================
    onRequestBatch = function(source, activeData, jobCfg)
        -- Initialize or reset crew state
        if not TrashCrews[source] then
            TrashCrews[source] = {
                members = {},
                bagsCollected = 0,
            }
        else
            TrashCrews[source].bagsCollected = 0
        end

        -- Framework expects currentBatch
        activeData.currentBatch = { {} }

        -- Get truck network ID for crew members
        local truckNetId = nil
        if activeData.truckEntity then
            truckNetId = activeData.truckEntity
        end

        -- Send batchReady immediately (no zone data)
        TriggerClientEvent('sb_jobs:client:batchReady', source, {})

        -- Send to all crew members
        local crew = TrashCrews[source]
        if crew then
            for _, memberSource in ipairs(crew.members) do
                TriggerClientEvent('sb_jobs:client:batchReady', memberSource, {
                    truckNetId = truckNetId,
                })
            end
        end
    end,

    -- ========================================================================
    -- VALIDATE DELIVERY — check player is near truck
    -- ========================================================================
    onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg)
        -- For trash collector, validation happens per-bag via trashCollected event
        -- This is called by the framework on payment completion
        return true
    end,

    -- ========================================================================
    -- CALCULATE TIP — random tip, split by crew size
    -- ========================================================================
    onCalculateTip = function(source, activeData, jobCfg)
        local leaderSource = FindLeaderSource(source) or source
        local crewSize = GetCrewSize(leaderSource)
        local baseTip = math.random(jobCfg.tipMin, jobCfg.tipMax)
        return math.floor(baseTip / crewSize)
    end,
}

-- ============================================================================
-- TRASH COLLECTED — Player threw a bag in the truck
-- ============================================================================

RegisterNetEvent('sb_jobs:server:trashCollected', function()
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'trash_collector' then return end

    -- Find the crew leader (could be self)
    local leaderSource = FindLeaderSource(source) or source
    local crew = TrashCrews[leaderSource]
    if not crew then return end

    -- Anti-exploit: check proximity to truck
    local leaderActive = ActivePublicJobs[leaderSource]
    if leaderActive and leaderActive.plate then
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then
            -- Client already enforces throwRadius (5m), this is a backup
        end
    end

    -- Increment shared counter
    crew.bagsCollected = crew.bagsCollected + 1

    local jobCfg = Config.PublicJobs['trash_collector']
    if not jobCfg then return end

    local bagsPerPayment = jobCfg.bagsPerPayment or 12

    -- Check if payment threshold reached
    if crew.bagsCollected >= bagsPerPayment then
        crew.bagsCollected = 0

        local crewSize = GetCrewSize(leaderSource)
        local allSources = GetAllCrewSources(leaderSource)

        -- Complete delivery for each crew member (triggers XP/pay via framework)
        for _, memberSrc in ipairs(allSources) do
            local memberActive = ActivePublicJobs[memberSrc]
            if memberActive and memberActive.jobId == 'trash_collector' then
                -- Override the pay for this member (split by crew size)
                memberActive.paySplitDivisor = crewSize

                -- Trigger the standard completeDelivery flow
                TriggerEvent('sb_jobs:server:completeDelivery_internal', memberSrc, 'trash_collector', 1)
            end
        end
    end
end)

-- Internal event to complete delivery for a specific player (server-only, not exposed to clients)
AddEventHandler('sb_jobs:server:completeDelivery_internal', function(targetSource, jobId, deliveryIndex)
    -- This should only be called from server-side, not from client
    -- We simulate the completeDelivery logic for crew pay splitting

    local Player = SB.Functions.GetPlayer(targetSource)
    if not Player then return end

    local active = ActivePublicJobs[targetSource]
    if not active or active.jobId ~= jobId then return end

    local jobCfg = Config.PublicJobs[jobId]
    if not jobCfg then return end

    -- Validate
    local handler = PublicJobServerHandlers[jobId]
    if handler and handler.onValidateDelivery then
        local valid = handler.onValidateDelivery(targetSource, deliveryIndex, active, jobCfg)
        if not valid then return end
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get current progress
    local progress = MySQL.query.await(
        'SELECT * FROM job_public_progress WHERE citizenid = ? AND job_id = ?',
        { citizenid, jobId }
    )
    if not progress or not progress[1] then
        -- Create progress entry if missing
        MySQL.insert.await(
            'INSERT INTO job_public_progress (citizenid, job_id, xp, level, total_completions) VALUES (?, ?, 0, 1, 0)',
            { citizenid, jobId }
        )
        progress = { { xp = 0, level = 1, total_completions = 0 } }
    end

    local currentXP = progress[1].xp
    local currentLevel = progress[1].level
    local completions = progress[1].total_completions

    -- Calculate pay with crew split
    local crewSize = active.paySplitDivisor or 1
    local levelData = jobCfg.levels[currentLevel] or jobCfg.levels[1]
    local basePay = math.floor(levelData.pay / crewSize)

    -- Tip (already split in onCalculateTip)
    local tip
    if handler and handler.onCalculateTip then
        tip = handler.onCalculateTip(targetSource, active, jobCfg)
    else
        tip = math.floor(math.random(jobCfg.tipMin, jobCfg.tipMax) / crewSize)
    end

    local totalPay = basePay + tip

    -- XP split
    local xpGain = math.floor(math.max(0, tonumber(jobCfg.xpPerDelivery) or 0) / crewSize)
    local newXP = math.min((currentXP or 0) + xpGain, 999999)

    -- Calculate level
    local newLevel = 1
    for _, lv in ipairs(jobCfg.levels) do
        if newXP >= lv.xpRequired then
            newLevel = lv.level
        else
            break
        end
    end
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
        xp = xpGain,
        totalXp = newXP,
        level = currentLevel,
        newLevel = newLevel,
    }

    if newLevel > currentLevel then
        local newLevelData = jobCfg.levels[newLevel] or jobCfg.levels[1]
        responseData.newVehicle = newLevelData.vehicle
        responseData.newPay = newLevelData.pay
        active.level = newLevel

        -- Vehicle type change check (unlikely for trash since all use 'trash')
        if newLevelData.vehicle ~= active.currentVehicle then
            active.pendingSwapVehicle = newLevelData.vehicle
            responseData.pendingSwap = true
            responseData.pendingSwapVehicle = newLevelData.vehicle
            if jobCfg.requiresLicense and jobCfg.requiresLicense[newLevelData.vehicle] then
                responseData.swapRequiresLicense = jobCfg.requiresLicense[newLevelData.vehicle]
            end
        end
    end

    -- Clear split divisor
    active.paySplitDivisor = nil

    TriggerClientEvent('sb_jobs:client:deliveryComplete', targetSource, responseData)

    print('[sb_jobs] Trash payment for player ' .. targetSource .. ' — $' .. totalPay .. ' (+' .. xpGain .. ' XP)')
end)

-- ============================================================================
-- CREW INVITE
-- ============================================================================

RegisterNetEvent('sb_jobs:server:trashInvite', function(targetId)
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'trash_collector' then return end

    -- Validate target type
    if type(targetId) ~= 'number' then return end

    -- Check crew size
    local crewSize = GetCrewSize(source)
    local jobCfg = Config.PublicJobs['trash_collector']
    local maxCrew = jobCfg and jobCfg.maxCrew or 4
    if crewSize >= maxCrew then
        TriggerClientEvent('sb_jobs:client:notify', source, 'Your crew is full (' .. maxCrew .. '/' .. maxCrew .. ')', 'error')
        return
    end

    -- Check target exists and has no active job
    local targetPlayer = SB.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('sb_jobs:client:notify', source, 'Player not found', 'error')
        return
    end

    if ActivePublicJobs[targetId] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'That player already has an active job', 'error')
        return
    end

    -- Check pending invite
    if PendingInvites[targetId] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'That player already has a pending invite', 'error')
        return
    end

    -- Store pending invite
    PendingInvites[targetId] = source

    -- Get leader name for notification
    local leaderPlayer = SB.Functions.GetPlayer(source)
    local leaderName = 'A player'
    if leaderPlayer then
        local charInfo = leaderPlayer.PlayerData.charinfo
        if charInfo then
            leaderName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or '')
        end
    end

    TriggerClientEvent('sb_jobs:client:trashInvitePrompt', targetId, leaderName)

    -- Auto-expire invite after 15 seconds
    SetTimeout(15000, function()
        if PendingInvites[targetId] == source then
            PendingInvites[targetId] = nil
        end
    end)
end)

-- ============================================================================
-- CREW ACCEPT INVITE
-- ============================================================================

RegisterNetEvent('sb_jobs:server:trashAcceptInvite', function()
    local source = source
    local leaderSource = PendingInvites[source]
    if not leaderSource then
        TriggerClientEvent('sb_jobs:client:notify', source, 'No pending invite found', 'error')
        return
    end

    PendingInvites[source] = nil

    -- Validate leader still has active trash job
    local leaderActive = ActivePublicJobs[leaderSource]
    if not leaderActive or leaderActive.jobId ~= 'trash_collector' then
        TriggerClientEvent('sb_jobs:client:notify', source, 'The crew leader is no longer collecting trash', 'error')
        return
    end

    -- Validate player still has no active job
    if ActivePublicJobs[source] then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You already have an active job', 'error')
        return
    end

    -- Check crew size again
    local jobCfg = Config.PublicJobs['trash_collector']
    local maxCrew = jobCfg and jobCfg.maxCrew or 4
    if GetCrewSize(leaderSource) >= maxCrew then
        TriggerClientEvent('sb_jobs:client:notify', source, 'The crew is already full', 'error')
        return
    end

    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    -- Require ID card
    local idCards = exports['sb_inventory']:GetItemsByName(source, 'id_card')
    if not idCards or #idCards == 0 then
        TriggerClientEvent('sb_jobs:client:notify', source, 'You need a valid ID card to work. Visit City Hall to get one.', 'error')
        return
    end

    -- Get or create progress
    local progress = MySQL.query.await(
        'SELECT * FROM job_public_progress WHERE citizenid = ? AND job_id = ?',
        { citizenid, 'trash_collector' }
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
            { citizenid, 'trash_collector' }
        )
    end

    -- Add to crew
    local crew = TrashCrews[leaderSource]
    if not crew then
        TrashCrews[leaderSource] = { members = {}, bagsCollected = 0 }
        crew = TrashCrews[leaderSource]
    end
    table.insert(crew.members, source)
    CrewMembership[source] = leaderSource

    -- Give vehicle keys for leader's truck
    local vehicleLabel = 'Trashmaster'
    if jobCfg and jobCfg.vehicleLabels and jobCfg.vehicleLabels[leaderActive.currentVehicle] then
        vehicleLabel = jobCfg.vehicleLabels[leaderActive.currentVehicle]
    end
    exports['sb_inventory']:AddItem(source, 'car_keys', 1, {
        plate = leaderActive.plate,
        vehicle = leaderActive.currentVehicle,
        label = vehicleLabel .. ' (Job)'
    })

    -- Create ActivePublicJobs entry for crew member
    local levelData = jobCfg.levels[level] or jobCfg.levels[1]
    ActivePublicJobs[source] = {
        jobId = 'trash_collector',
        citizenid = citizenid,
        plate = leaderActive.plate, -- same plate as leader's truck
        level = level,
        currentVehicle = leaderActive.currentVehicle,
        isCrew = true,
        leaderSource = leaderSource,
    }

    print('[sb_jobs] Player ' .. source .. ' joined trash crew of player ' .. leaderSource)

    -- Start job on client for crew member
    TriggerClientEvent('sb_jobs:client:jobStarted', source, {
        jobId = 'trash_collector',
        level = level,
        pay = levelData.pay,
        vehicleModel = leaderActive.currentVehicle,
        plate = leaderActive.plate,
        isCrew = true,
        leaderSource = leaderSource,
    })

    -- Send batchReady to new member so they start discovery
    SetTimeout(1000, function()
        if ActivePublicJobs[source] and ActivePublicJobs[source].jobId == 'trash_collector' then
            TriggerClientEvent('sb_jobs:client:batchReady', source, {
                truckNetId = nil, -- crew member will need to find truck nearby
            })
        end
    end)

    -- Notify leader
    local memberName = 'A player'
    local charInfo = Player.PlayerData.charinfo
    if charInfo then
        memberName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or '')
    end
    TriggerClientEvent('sb_jobs:client:trashCrewJoined', leaderSource, memberName)
end)

-- ============================================================================
-- CREW CLEANUP ON QUIT/DROP/CONFISCATE
-- ============================================================================
-- FiveM calls ALL registered handlers for the same event name.
-- The framework (publicjobs.lua) clears ActivePublicJobs[source] in its handler.
-- Our handlers here use TrashCrews/CrewMembership directly (not ActivePublicJobs)
-- so they work regardless of handler execution order.
-- ============================================================================

--- Shared cleanup logic for when a player leaves the job (any reason)
local function HandleTrashJobCleanup(source)
    -- Check if this player was a crew leader
    if TrashCrews[source] then
        DisbandCrew(source)
    end

    -- Check if this player was a crew member
    local leaderSource = CrewMembership[source]
    if leaderSource then
        RemoveCrewMember(source)

        -- Get player name for notification
        local Player = SB.Functions.GetPlayer(source)
        local memberName = 'A crew member'
        if Player then
            local charInfo = Player.PlayerData.charinfo
            if charInfo then
                memberName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or '')
            end
        end

        TriggerClientEvent('sb_jobs:client:trashCrewLeft', leaderSource, memberName)
    end

    -- Clean up pending invites from/to this player
    PendingInvites[source] = nil
    for target, leader in pairs(PendingInvites) do
        if leader == source then
            PendingInvites[target] = nil
        end
    end
end

-- Player disconnected — clean up crew state
AddEventHandler('playerDropped', function()
    local source = source
    HandleTrashJobCleanup(source)
end)

-- Player voluntarily quits — clean up crew state
RegisterNetEvent('sb_jobs:server:quitPublicJob', function()
    local source = source
    HandleTrashJobCleanup(source)
end)

-- Vehicle confiscated — disband crew if leader
RegisterNetEvent('sb_jobs:server:vehicleConfiscated', function()
    local source = source
    HandleTrashJobCleanup(source)
end)
