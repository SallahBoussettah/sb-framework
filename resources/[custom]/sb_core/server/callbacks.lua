--[[
    Everyday Chaos RP - Server Callbacks
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- CALLBACK EVENT HANDLER
-- ============================================================================

-- Handle incoming callback requests from clients
RegisterNetEvent('SB:Server:TriggerCallback', function(name, ...)
    local src = source
    local cb = SB.ServerCallbacks[name]

    if not cb then
        print('^1[SB_CORE]^7 Callback not found: ' .. name)
        return
    end

    cb(src, function(...)
        TriggerClientEvent('SB:Client:TriggerCallback', src, name, ...)
    end, ...)
end)

-- Handle client callback responses
RegisterNetEvent('SB:Server:TriggerClientCallbackResponse', function(requestId, ...)
    if SB.ClientCallbacks[requestId] then
        SB.ClientCallbacks[requestId](...)
        SB.ClientCallbacks[requestId] = nil
    end
end)

-- ============================================================================
-- BUILT-IN CALLBACKS
-- ============================================================================

-- Get player data
SB.Functions.CreateCallback('sb_core:server:GetPlayerData', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if Player then
        cb(Player.PlayerData)
    else
        cb(nil)
    end
end)

-- Get all characters for a player (multicharacter)
SB.Functions.CreateCallback('sb_core:server:GetCharacters', function(source, cb)
    local license = SB.Functions.GetIdentifier(source, 'license')

    local result = MySQL.query.await([[
        SELECT citizenid, cid, charinfo, money, job FROM players WHERE license = ?
    ]], { license })

    local characters = {}
    for _, row in pairs(result or {}) do
        characters[row.cid] = {
            citizenid = row.citizenid,
            cid = row.cid,
            charinfo = json.decode(row.charinfo),
            money = json.decode(row.money),
            job = json.decode(row.job)
        }
    end

    cb(characters)
end)

-- Get character count
SB.Functions.CreateCallback('sb_core:server:GetCharacterCount', function(source, cb)
    local license = SB.Functions.GetIdentifier(source, 'license')

    local result = MySQL.scalar.await([[
        SELECT COUNT(*) FROM players WHERE license = ?
    ]], { license })

    cb(result or 0)
end)

-- Check if citizen ID exists
SB.Functions.CreateCallback('sb_core:server:CheckCitizenId', function(source, cb, citizenid)
    local result = MySQL.scalar.await([[
        SELECT citizenid FROM players WHERE citizenid = ?
    ]], { citizenid })

    cb(result ~= nil)
end)

-- Get max character slots for player
SB.Functions.CreateCallback('sb_core:server:GetMaxSlots', function(source, cb)
    local license = SB.Functions.GetIdentifier(source, 'license')

    -- Check for custom allocation
    if Config.PlayerSlots[license] then
        cb(Config.PlayerSlots[license])
        return
    end

    cb(Config.MaxCharacters)
end)

-- Validate job
SB.Functions.CreateCallback('sb_core:server:ValidateJob', function(source, cb, jobName, grade)
    local job = SBShared.Jobs[jobName]
    if not job then
        cb(false, 'Invalid job')
        return
    end

    grade = tostring(grade or 0)
    if not job.grades[grade] then
        cb(false, 'Invalid grade')
        return
    end

    cb(true, job)
end)

-- Validate gang
SB.Functions.CreateCallback('sb_core:server:ValidateGang', function(source, cb, gangName, grade)
    local gang = SBShared.Gangs[gangName]
    if not gang then
        cb(false, 'Invalid gang')
        return
    end

    grade = tostring(grade or 0)
    if not gang.grades[grade] then
        cb(false, 'Invalid grade')
        return
    end

    cb(true, gang)
end)

-- Get shared data
SB.Functions.CreateCallback('sb_core:server:GetSharedData', function(source, cb, dataType)
    if dataType == 'items' then
        cb(SBShared.Items)
    elseif dataType == 'jobs' then
        cb(SBShared.Jobs)
    elseif dataType == 'gangs' then
        cb(SBShared.Gangs)
    elseif dataType == 'vehicles' then
        cb(SBShared.Vehicles)
    else
        cb(nil)
    end
end)
