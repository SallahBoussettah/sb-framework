-- ============================================================================
-- SB_DOORLOCK - Server Main
-- Door authorization and state management
-- ============================================================================

local SBCore = exports['sb_core']:GetCoreObject()

-- Current door states (runtime)
local DoorStates = {}
local BypassedDoors = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Initialize door states from config
    for _, door in ipairs(Config.Doors) do
        DoorStates[door.id] = door.locked
    end
    print('[sb_doorlock] Server initialized with ' .. #Config.Doors .. ' doors')
end)

-- ============================================================================
-- AUTHORIZATION CHECKING
-- ============================================================================

local function IsAuthorized(source, door)
    local player = SBCore.Functions.GetPlayer(source)
    if not player then return false, 'Player not found' end

    -- Check if door is bypassed (destroyed)
    if BypassedDoors[door.id] then
        return false, 'Door has been destroyed'
    end

    -- Admin bypass
    if Config.AdminAccess and IsPlayerAceAllowed(source, Config.AdminPermission) then
        return true, 'Admin access'
    end

    -- All authorized (public door)
    if door.allAuthorized then
        return true, 'Public access'
    end

    -- Job authorization
    if door.authorizedJobs then
        local playerJob = player.PlayerData.job
        if playerJob then
            local requiredGrade = door.authorizedJobs[playerJob.name]
            if requiredGrade ~= nil then
                if playerJob.grade.level >= requiredGrade then
                    return true, 'Job authorized'
                else
                    return false, 'Insufficient job rank'
                end
            end
        end
    end

    -- Gang authorization
    if door.authorizedGangs then
        local playerGang = player.PlayerData.gang
        if playerGang then
            local requiredGrade = door.authorizedGangs[playerGang.name]
            if requiredGrade ~= nil then
                if playerGang.grade.level >= requiredGrade then
                    return true, 'Gang authorized'
                end
            end
        end
    end

    -- CitizenID authorization
    if door.authorizedCitizenIDs then
        local citizenid = player.PlayerData.citizenid
        for _, id in ipairs(door.authorizedCitizenIDs) do
            if id == citizenid then
                return true, 'CitizenID authorized'
            end
        end
    end

    -- Item authorization
    if door.items then
        local hasAllItems = true
        for _, itemName in ipairs(door.items) do
            local item = player.Functions.GetItemByName(itemName)
            if not item or item.amount < 1 then
                hasAllItems = false
                break
            end
        end
        if hasAllItems then
            return true, 'Item authorized'
        end
    end

    -- Check if door has NO authorization set (vault doors)
    if not door.allAuthorized and
       (not door.authorizedJobs or next(door.authorizedJobs) == nil) and
       (not door.authorizedGangs or next(door.authorizedGangs) == nil) and
       (not door.authorizedCitizenIDs or #door.authorizedCitizenIDs == 0) and
       (not door.items or #door.items == 0) then
        return false, 'This door cannot be opened normally'
    end

    return false, 'Access denied'
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

SBCore.Functions.CreateCallback('sb_doorlock:checkAccess', function(source, cb, doorId)
    local door = Config.GetDoorById(doorId)
    if not door then
        cb(false, 'Door not found')
        return
    end

    local authorized, reason = IsAuthorized(source, door)
    cb(authorized, reason)
end)

-- ============================================================================
-- EVENTS
-- ============================================================================

-- Update door state
RegisterNetEvent('sb_doorlock:updateState', function(doorId, locked)
    local src = source
    local door = Config.GetDoorById(doorId)

    print(('[sb_doorlock] ^3Server: updateState called | doorId=%s | locked=%s | src=%d^7'):format(doorId, tostring(locked), src))

    if not door then
        print(('[sb_doorlock] ^1Server: Door not found: %s^7'):format(doorId))
        return
    end

    -- Verify authorization server-side
    local authorized, reason = IsAuthorized(src, door)
    if not authorized then
        print(('[sb_doorlock] ^1Server: Not authorized: %s | reason=%s^7'):format(doorId, reason))
        TriggerClientEvent('sb_notify:client:Notify', src, reason, 'error', 3000)
        return
    end

    -- Update state
    DoorStates[doorId] = locked
    print(('[sb_doorlock] ^2Server: State updated | doorId=%s | locked=%s^7'):format(doorId, tostring(locked)))

    -- Broadcast to all clients
    TriggerClientEvent('sb_doorlock:setState', -1, doorId, locked)
    print(('[sb_doorlock] ^2Server: Broadcasted setState to all clients^7'))

    -- Handle auto-lock
    if door.autoLock and not locked then
        SetTimeout(door.autoLock, function()
            if not DoorStates[doorId] then -- Still unlocked
                DoorStates[doorId] = true
                TriggerClientEvent('sb_doorlock:setState', -1, doorId, true)
            end
        end)
    end

    -- Log
    local player = SBCore.Functions.GetPlayer(src)
    if player then
        print(('[sb_doorlock] %s %s door: %s'):format(
            player.PlayerData.name,
            locked and 'CLOSED/LOCKED' or 'OPENED/UNLOCKED',
            doorId
        ))
    end
end)

-- Player requests current states (on join/resource start)
RegisterNetEvent('sb_doorlock:requestStates', function()
    local src = source
    TriggerClientEvent('sb_doorlock:syncAllStates', src, DoorStates)
end)

-- ============================================================================
-- HEIST BYPASS SYSTEM
-- ============================================================================

-- Bypass door (called by sb_pacificheist)
RegisterNetEvent('sb_doorlock:bypassDoor', function(doorId)
    local src = source
    local door = Config.GetDoorById(doorId)

    if not door then return end

    -- Only allow if door has heistBypass flag
    if not door.heistBypass then
        print(('[sb_doorlock] WARNING: Attempted to bypass non-bypassable door: %s'):format(doorId))
        return
    end

    BypassedDoors[doorId] = true
    DoorStates[doorId] = false

    -- Broadcast to all clients
    TriggerClientEvent('sb_doorlock:bypassDoor', -1, doorId)

    print(('[sb_doorlock] Door bypassed (heist): %s'):format(doorId))
end)

-- Reset bypass (called when heist resets)
RegisterNetEvent('sb_doorlock:resetBypass', function(doorId)
    if doorId then
        BypassedDoors[doorId] = nil
        local door = Config.GetDoorById(doorId)
        if door then
            DoorStates[doorId] = door.locked
        end
        TriggerClientEvent('sb_doorlock:resetBypass', -1, doorId)
    else
        -- Reset all bypassed doors
        for id, _ in pairs(BypassedDoors) do
            BypassedDoors[id] = nil
            local door = Config.GetDoorById(id)
            if door then
                DoorStates[id] = door.locked
            end
        end
        TriggerClientEvent('sb_doorlock:resetBypass', -1, nil)
    end
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

RegisterCommand('doorlock', function(source, args)
    local src = source
    if src == 0 then return end -- Console

    if not IsPlayerAceAllowed(src, Config.AdminPermission) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'No permission!', 'error', 3000)
        return
    end

    local doorId = args[1]
    if not doorId then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Usage: /doorlock [door_id]', 'info', 3000)
        return
    end

    local door = Config.GetDoorById(doorId)
    if not door then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Door not found: ' .. doorId, 'error', 3000)
        return
    end

    DoorStates[doorId] = true
    TriggerClientEvent('sb_doorlock:setState', -1, doorId, true)
    TriggerClientEvent('sb_notify:client:Notify', src, 'Door locked: ' .. doorId, 'success', 3000)
end, false)

RegisterCommand('doorunlock', function(source, args)
    local src = source
    if src == 0 then return end

    if not IsPlayerAceAllowed(src, Config.AdminPermission) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'No permission!', 'error', 3000)
        return
    end

    local doorId = args[1]
    if not doorId then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Usage: /doorunlock [door_id]', 'info', 3000)
        return
    end

    local door = Config.GetDoorById(doorId)
    if not door then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Door not found: ' .. doorId, 'error', 3000)
        return
    end

    DoorStates[doorId] = false
    BypassedDoors[doorId] = nil
    TriggerClientEvent('sb_doorlock:setState', -1, doorId, false)
    TriggerClientEvent('sb_notify:client:Notify', src, 'Door unlocked: ' .. doorId, 'success', 3000)
end, false)

RegisterCommand('doorlist', function(source, args)
    local src = source
    if src == 0 then
        -- Console output
        print('=== Door List ===')
        for _, door in ipairs(Config.Doors) do
            local state = DoorStates[door.id] and 'LOCKED' or 'UNLOCKED'
            if BypassedDoors[door.id] then state = 'BYPASSED' end
            print(('  %s: %s (%s)'):format(door.id, door.label or 'No label', state))
        end
        return
    end

    if not IsPlayerAceAllowed(src, Config.AdminPermission) then
        TriggerClientEvent('sb_notify:client:Notify', src, 'No permission!', 'error', 3000)
        return
    end

    TriggerClientEvent('sb_notify:client:Notify', src, 'Door list printed to F8 console', 'info', 3000)
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2[sb_doorlock]', 'Check F8 console for door list' }
    })
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetDoorState', function(doorId)
    return DoorStates[doorId]
end)

exports('SetDoorState', function(doorId, locked)
    local door = Config.GetDoorById(doorId)
    if door then
        DoorStates[doorId] = locked
        TriggerClientEvent('sb_doorlock:setState', -1, doorId, locked)
    end
end)

exports('BypassDoor', function(doorId)
    TriggerEvent('sb_doorlock:bypassDoor', doorId)
end)

exports('ResetBypass', function(doorId)
    TriggerEvent('sb_doorlock:resetBypass', doorId)
end)

exports('IsAuthorized', function(source, doorId)
    local door = Config.GetDoorById(doorId)
    if door then
        return IsAuthorized(source, door)
    end
    return false, 'Door not found'
end)

-- ============================================================================
-- CHAT SUGGESTIONS
-- ============================================================================

TriggerEvent('chat:addSuggestion', '/doorlock', 'Lock a door (Admin)', {{ name = 'door_id', help = 'Door ID' }})
TriggerEvent('chat:addSuggestion', '/doorunlock', 'Unlock a door (Admin)', {{ name = 'door_id', help = 'Door ID' }})
TriggerEvent('chat:addSuggestion', '/doorlist', 'List all doors (Admin)', {})

print('[sb_doorlock] Server loaded')
