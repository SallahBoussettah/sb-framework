-- ============================================================================
-- SB_PRISON - Prison Jobs & Canteen (Phase 2)
-- Job completion validation, time reduction, canteen purchases
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- In-memory cooldown tracker: jobCooldowns[citizenid][jobId] = os.time() of last completion
local jobCooldowns = {}

-- ============================================================================
-- JOB COMPLETION (client → server)
-- ============================================================================

RegisterNetEvent('sb_prison:server:completeJob', function(jobId)
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    -- Validate: must be serving at bolingbroke
    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'serving' or sentence.location ~= 'bolingbroke' then
        NotifyPlayer(src, 'You cannot do prison jobs right now', 'error')
        return
    end

    -- Validate: job exists in config
    local jobCfg = Config.PrisonJobs[jobId]
    if not jobCfg then
        print('[sb_prison] Invalid job ID: ' .. tostring(jobId))
        return
    end

    -- Validate: cooldown
    local now = os.time()
    if jobCooldowns[citizenid] and jobCooldowns[citizenid][jobId] then
        local elapsed = now - jobCooldowns[citizenid][jobId]
        if elapsed < jobCfg.cooldown then
            NotifyPlayer(src, 'You need to wait before doing this again', 'error')
            return
        end
    end

    -- Record cooldown
    if not jobCooldowns[citizenid] then jobCooldowns[citizenid] = {} end
    jobCooldowns[citizenid][jobId] = now

    -- Add credits
    AddCredits(citizenid, jobCfg.credits, 'job:' .. jobId)

    -- Reduce sentence time
    local reduction = jobCfg.timeReduction or 0
    if reduction > 0 and sentence.releaseTime then
        sentence.releaseTime = sentence.releaseTime - reduction
        local remaining = math.max(0, sentence.releaseTime - now)
        sentence.timeRemaining = remaining

        MySQL.query.await(
            'UPDATE sb_prison_sentences SET release_time = ?, time_remaining = ? WHERE id = ?',
            { sentence.releaseTime, remaining, sentence.id }
        )
    end

    -- Send completion to client
    local newCredits = GetCredits(citizenid)
    local newRemaining = sentence.releaseTime and math.max(0, sentence.releaseTime - now) or sentence.timeRemaining
    TriggerClientEvent('sb_prison:client:jobComplete', src, {
        jobId = jobId,
        credits = newCredits,
        creditsEarned = jobCfg.credits,
        timeReduction = reduction,
        timeRemaining = newRemaining,
    })

    if Config.Debug then
        print(string.format('[sb_prison] %s completed job "%s" — +%d credits, -%ds time', citizenid, jobId, jobCfg.credits, reduction))
    end
end)

-- ============================================================================
-- CANTEEN PURCHASE (client → server)
-- ============================================================================

RegisterNetEvent('sb_prison:server:buyCanteenItem', function(itemIndex)
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if not citizenid then return end

    -- Validate: must be serving at bolingbroke
    local sentence = activeSentences[citizenid]
    if not sentence or sentence.status ~= 'serving' or sentence.location ~= 'bolingbroke' then
        NotifyPlayer(src, 'You cannot use the canteen right now', 'error')
        return
    end

    -- Validate: item index
    local item = Config.CanteenItems[itemIndex]
    if not item then
        print('[sb_prison] Invalid canteen item index: ' .. tostring(itemIndex))
        return
    end

    -- Validate: enough credits
    local balance = GetCredits(citizenid)
    if balance < item.price then
        NotifyPlayer(src, 'Not enough credits (need ' .. item.price .. ', have ' .. balance .. ')', 'error')
        return
    end

    -- Deduct credits
    local success = RemoveCredits(citizenid, item.price, 'canteen:' .. item.id)
    if not success then
        NotifyPlayer(src, 'Transaction failed', 'error')
        return
    end

    -- Apply hunger/thirst restoration via Player metadata
    local Player = SB.Functions.GetPlayer(src)
    if Player then
        if item.hungerRestore > 0 then
            local currentHunger = Player.PlayerData.metadata.hunger or 0
            Player.Functions.SetMetaData('hunger', math.min(100, currentHunger + item.hungerRestore))
        end
        if item.thirstRestore > 0 then
            local currentThirst = Player.PlayerData.metadata.thirst or 0
            Player.Functions.SetMetaData('thirst', math.min(100, currentThirst + item.thirstRestore))
        end
    end

    local newBalance = GetCredits(citizenid)
    NotifyPlayer(src, item.label .. ' purchased (-' .. item.price .. ' credits)', 'success')

    if Config.Debug then
        print(string.format('[sb_prison] %s bought %s for %d credits (balance: %d)', citizenid, item.id, item.price, newBalance))
    end
end)

-- ============================================================================
-- COOLDOWN CLEANUP ON DISCONNECT
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    if citizenid and jobCooldowns[citizenid] then
        jobCooldowns[citizenid] = nil
    end
end)
