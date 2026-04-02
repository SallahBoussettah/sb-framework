-- sb_admin/server/main.lua
-- All admin commands centralized here
-- Dependencies: sb_core (SB global), sb_weapons (GiveWeaponKit), sb_inventory (AddItem)

local SB = nil

-- Wait for sb_core to be available
CreateThread(function()
    while not exports['sb_core'] do Wait(100) end
    SB = exports['sb_core']:GetCoreObject()
    print('^2[sb_admin]^7 Admin commands loaded')
end)

-- Helper: notify player or print to console
local function AdminNotify(src, msg, msgType)
    if src == 0 then
        print('[sb_admin] ' .. msg)
    else
        TriggerClientEvent('sb_notify:client:notify', src, msg, msgType or 'info', 3000)
    end
end

-- Helper: check admin permission
local function HasPermission(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.AcePerm)
end

-- ============================================================================
-- PERMISSION CHECK (for NUI menu)
-- ============================================================================

RegisterNetEvent('sb_admin:requestPermission', function()
    local src = source
    local allowed = IsPlayerAceAllowed(src, Config.AcePerm)
    TriggerClientEvent('sb_admin:permissionResult', src, allowed)
    if allowed then
        print(('[sb_admin] Player %s (ID: %d) granted admin access'):format(GetPlayerName(src), src))
    end
end)

-- ============================================================================
-- GIVE COMMANDS
-- ============================================================================

-- /givemoney [id] [cash/bank/crypto] [amount]
RegisterCommand('givemoney', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local moneyType = args[2]
    local amount = tonumber(args[3])

    if not targetId or not moneyType or not amount then
        AdminNotify(src, 'Usage: /givemoney [id] [cash/bank/crypto] [amount]', 'error')
        return
    end

    if not SB then
        AdminNotify(src, 'Core not ready', 'error')
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        AdminNotify(src, 'Player not found or not logged in', 'error')
        return
    end

    if Player.Functions.AddMoney(moneyType, amount, 'Admin gave money') then
        AdminNotify(src, ('Gave $%s %s to player %d'):format(tostring(amount), moneyType, targetId), 'success')
        AdminNotify(targetId, ('Admin gave you $%s %s'):format(tostring(amount), moneyType), 'success')
        print(('[sb_admin] %s gave %d %s to player %d'):format(src == 0 and 'Console' or GetPlayerName(src), amount, moneyType, targetId))
    else
        AdminNotify(src, 'Failed - invalid money type (use cash/bank/crypto)', 'error')
    end
end, false)

-- /giveitem [id] [item] [amount]
RegisterCommand('giveitem', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount = tonumber(args[3]) or 1

    if not targetId or not itemName then
        AdminNotify(src, 'Usage: /giveitem [id] [item] [amount]', 'error')
        return
    end

    if amount < 1 or amount > 999 then
        AdminNotify(src, 'Amount must be 1-999', 'error')
        return
    end

    if GetPlayerPed(targetId) == 0 then
        AdminNotify(src, 'Player not found', 'error')
        return
    end

    local success = exports['sb_inventory']:AddItem(targetId, itemName, amount, nil, nil, true)
    if success then
        AdminNotify(src, ('Gave %dx %s to player %d'):format(amount, itemName, targetId), 'success')
        print(('[sb_admin] %s gave %dx %s to player %d'):format(src == 0 and 'Console' or GetPlayerName(src), amount, itemName, targetId))
    else
        AdminNotify(src, ('Failed to give %s - invalid item or inventory full'):format(itemName), 'error')
    end
end, false)

-- /giveweapon [id] [weapon]
RegisterCommand('giveweapon', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local weaponName = args[2]

    if not targetId then
        if src ~= 0 then
            targetId = src
            weaponName = args[1] or 'weapon_pistol'
        else
            AdminNotify(src, 'Usage: /giveweapon [id] [weapon]', 'error')
            return
        end
    end

    weaponName = weaponName or 'weapon_pistol'

    if GetPlayerPed(targetId) == 0 then
        AdminNotify(src, 'Player not found', 'error')
        return
    end

    local success, result = exports['sb_weapons']:GiveWeaponKit(targetId, weaponName)
    if success then
        AdminNotify(src, ('Gave %s kit to player %d (weapon + 3 mags + ammo box)'):format(result, targetId), 'success')
        AdminNotify(targetId, ('You received a %s kit'):format(result), 'success')
        print(('[sb_admin] %s gave %s kit to player %d'):format(src == 0 and 'Console' or GetPlayerName(src), result, targetId))
    else
        AdminNotify(src, result or 'Failed to give weapon', 'error')
    end
end, false)

-- ============================================================================
-- JOB/GANG COMMANDS
-- ============================================================================

-- NOTE: /setjob is registered below in JOB MANAGEMENT section (line ~616)

-- /setgang [id] [gang] [grade]
RegisterCommand('setgang', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local gangName = args[2]
    local grade = tonumber(args[3]) or 0

    if not targetId or not gangName then
        AdminNotify(src, 'Usage: /setgang [id] [gang] [grade]', 'error')
        return
    end

    if not SB then
        AdminNotify(src, 'Core not ready', 'error')
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        AdminNotify(src, 'Player not found or not logged in', 'error')
        return
    end

    if Player.Functions.SetGang(gangName, grade) then
        AdminNotify(src, ('Set player %d gang to %s (grade %d)'):format(targetId, gangName, grade), 'success')
        AdminNotify(targetId, ('Your gang has been set to %s'):format(gangName), 'success')
    else
        AdminNotify(src, 'Invalid gang or grade', 'error')
    end
end, false)

-- ============================================================================
-- MODERATION COMMANDS
-- ============================================================================

-- /kick [id] [reason]
RegisterCommand('kick', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    if not targetId then
        AdminNotify(src, 'Usage: /kick [id] [reason]', 'error')
        return
    end

    if not SB then
        AdminNotify(src, 'Core not ready', 'error')
        return
    end

    table.remove(args, 1)
    local reason = #args > 0 and table.concat(args, ' ') or 'No reason provided'

    local targetName = GetPlayerName(targetId) or 'Unknown'
    SB.Functions.Kick(targetId, reason)

    AdminNotify(src, ('Kicked %s: %s'):format(targetName, reason), 'success')
    print(('[sb_admin] %s kicked %s | Reason: %s'):format(src == 0 and 'Console' or GetPlayerName(src), targetName, reason))
end, false)

-- /ban [id] [hours] [reason]
RegisterCommand('ban', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local duration = tonumber(args[2]) or 0

    if not targetId then
        AdminNotify(src, 'Usage: /ban [id] [hours, 0=permanent] [reason]', 'error')
        return
    end

    if not SB then
        AdminNotify(src, 'Core not ready', 'error')
        return
    end

    table.remove(args, 1)
    table.remove(args, 1)
    local reason = #args > 0 and table.concat(args, ' ') or 'No reason provided'

    local expire = duration > 0 and (os.time() + (duration * 3600)) or nil
    local adminName = src == 0 and 'Console' or GetPlayerName(src)

    SB.Functions.BanPlayer(targetId, reason, expire, adminName)

    local durText = duration > 0 and (duration .. ' hours') or 'permanently'
    AdminNotify(src, ('Banned player %d %s: %s'):format(targetId, durText, reason), 'success')
    print(('[sb_admin] %s banned player %d %s | Reason: %s'):format(adminName, targetId, durText, reason))
end, false)

-- /revive [id]
RegisterCommand('revive', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])

    -- If no target and in-game, revive self
    if not targetId and src ~= 0 then
        targetId = src
    end

    if not targetId then
        AdminNotify(src, 'Usage: /revive [id]', 'error')
        return
    end

    if not GetPlayerName(targetId) then
        AdminNotify(src, 'Player not connected', 'error')
        return
    end

    -- Clear death metadata on server
    if SB then
        local Player = SB.Functions.GetPlayer(targetId)
        if Player then
            Player.Functions.SetMetaData('isdead', false)
        end
    end

    -- Trigger client revive
    TriggerClientEvent('SB:Client:Revive', targetId)

    if targetId == src then
        AdminNotify(src, 'You have been revived', 'success')
    else
        AdminNotify(targetId, 'You have been revived by an admin', 'success')
        AdminNotify(src, ('Revived player %d'):format(targetId), 'success')
    end
end, false)

-- /heal [id] - Full heal: health, hunger, thirst, stress + revive if dead
RegisterCommand('heal', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])

    -- If no target and in-game, heal self
    if not targetId and src ~= 0 then
        targetId = src
    end

    if not targetId then
        AdminNotify(src, 'Usage: /heal [id]', 'error')
        return
    end

    if not GetPlayerName(targetId) then
        AdminNotify(src, 'Player not connected', 'error')
        return
    end

    if not SB then
        AdminNotify(src, 'Core not ready', 'error')
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        AdminNotify(src, 'Player not logged in', 'error')
        return
    end

    -- Check if player is dead and revive first
    local wasDead = Player.PlayerData.metadata.isdead
    if wasDead then
        Player.Functions.SetMetaData('isdead', false)
        TriggerClientEvent('SB:Client:Revive', targetId)
    end

    -- Set hunger, thirst, stress
    Player.Functions.SetMetaData('hunger', 100)
    Player.Functions.SetMetaData('thirst', 100)
    Player.Functions.SetMetaData('stress', 0)

    -- Heal health on client
    TriggerClientEvent('sb_admin:heal', targetId)

    if targetId == src then
        AdminNotify(src, 'You have been fully healed', 'success')
    else
        AdminNotify(targetId, 'You have been fully healed by an admin', 'success')
        AdminNotify(src, ('Fully healed player %d'):format(targetId), 'success')
    end

    print(('[sb_admin] %s healed player %d'):format(src == 0 and 'Console' or GetPlayerName(src), targetId))
end, false)

-- ============================================================================
-- TELEPORT COMMANDS
-- ============================================================================

-- /goto [id]
RegisterCommand('goto', function(source, args)
    local src = source
    if src == 0 then print('[sb_admin] Must be used in-game') return end
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    if not targetId then
        AdminNotify(src, 'Usage: /goto [id]', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed == 0 then
        AdminNotify(src, 'Player not found', 'error')
        return
    end

    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('sb_admin:teleport', src, coords)
    AdminNotify(src, ('Teleported to player %d'):format(targetId), 'success')
end, false)

-- /bring [id]
RegisterCommand('bring', function(source, args)
    local src = source
    if src == 0 then print('[sb_admin] Must be used in-game') return end
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    if not targetId then
        AdminNotify(src, 'Usage: /bring [id]', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed == 0 then
        AdminNotify(src, 'Player not found', 'error')
        return
    end

    local srcPed = GetPlayerPed(src)
    local coords = GetEntityCoords(srcPed)
    TriggerClientEvent('sb_admin:teleport', targetId, coords)
    AdminNotify(src, ('Brought player %d'):format(targetId), 'success')
end, false)

-- ============================================================================
-- WORLD COMMANDS
-- ============================================================================

-- /time [hour] [minute]
RegisterCommand('time', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local hour = tonumber(args[1])
    local minute = tonumber(args[2]) or 0

    if not hour or hour < 0 or hour > 23 then
        AdminNotify(src, 'Usage: /time [0-23] [0-59]', 'error')
        return
    end

    minute = math.max(0, math.min(59, minute))

    -- Broadcast to all clients
    TriggerClientEvent('sb_admin:setTime', -1, hour, minute)
    AdminNotify(src, ('Time set to %02d:%02d'):format(hour, minute), 'success')
end, false)

-- /freezetime - Toggle time freeze
RegisterCommand('freezetime', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    TriggerClientEvent('sb_admin:toggleFreezeTime', -1)
end, false)

-- ============================================================================
-- NUI PANEL: Give Item (gives to self)
-- ============================================================================

-- ============================================================================
-- VEHICLE SPAWN (Give Keys)
-- ============================================================================

RegisterNetEvent('sb_admin:giveCarKeys', function(plate, model)
    local src = source
    if not HasPermission(src) then return end

    local keyMetadata = {
        plate = plate,
        vehicle = model,
        label = model:upper()
    }

    local success = exports['sb_inventory']:AddItem(src, 'car_keys', 1, keyMetadata)
    if success then
        print(('[sb_admin] Gave car keys for %s (plate: %s) to player %d'):format(model, plate, src))
    end
end)

RegisterNetEvent('sb_admin:removeCarKeys', function(plate)
    local src = source
    if not HasPermission(src) then return end

    if not plate or plate == '' then return end

    -- Trim whitespace from target plate
    local targetPlate = plate:gsub("%s+", "")

    -- Get all car_keys from player inventory
    local keys = exports['sb_inventory']:GetItemsByName(src, 'car_keys')
    if not keys or #keys == 0 then return end

    for _, keyItem in pairs(keys) do
        if keyItem.metadata and keyItem.metadata.plate then
            local itemPlate = keyItem.metadata.plate:gsub("%s+", "")
            if itemPlate == targetPlate then
                exports['sb_inventory']:RemoveItem(src, 'car_keys', 1, keyItem.slot)
                print(('[sb_admin] Removed car keys for plate %s from player %d'):format(plate, src))
                AdminNotify(src, 'Car keys removed', 'info')
                return
            end
        end
    end
end)

-- ============================================================================
-- NUI PANEL: Give Item (gives to self)
-- ============================================================================

RegisterNetEvent('sb_admin:giveItem', function(itemName, amount)
    local src = source
    if not HasPermission(src) then return end

    if not itemName or itemName == '' then
        AdminNotify(src, 'Invalid item name', 'error')
        return
    end

    amount = tonumber(amount) or 1
    if amount < 1 or amount > 999 then
        AdminNotify(src, 'Amount must be 1-999', 'error')
        return
    end

    local success = exports['sb_inventory']:AddItem(src, itemName, amount)
    if success then
        AdminNotify(src, ('Gave %dx %s'):format(amount, itemName), 'success')
    else
        AdminNotify(src, ('Failed to give %s'):format(itemName), 'error')
    end
end)

-- ============================================================================
-- ADMIN MANAGEMENT
-- ============================================================================

-- /setadmin [id] - Grant admin access to a player (runtime, resets on server restart)
RegisterCommand('setadmin', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    if not targetId then
        AdminNotify(src, 'Usage: /setadmin [id]', 'error')
        return
    end

    local targetName = GetPlayerName(targetId)
    if not targetName then
        AdminNotify(src, 'Player not found', 'error')
        return
    end

    -- Get all identifiers and add each one to group.admin
    local added = false
    for i = 0, GetNumPlayerIdentifiers(targetId) - 1 do
        local identifier = GetPlayerIdentifier(targetId, i)
        if identifier then
            ExecuteCommand(('add_principal identifier.%s group.admin'):format(identifier))
            added = true
        end
    end

    if added then
        -- Tell the target client to re-check permissions so F5/commands work immediately
        TriggerClientEvent('sb_admin:permissionResult', targetId, true)
        AdminNotify(src, ('Granted admin to %s (ID: %d)'):format(targetName, targetId), 'success')
        AdminNotify(targetId, 'You have been granted admin access', 'success')
        print(('[sb_admin] %s granted admin to %s (ID: %d)'):format(src == 0 and 'Console' or GetPlayerName(src), targetName, targetId))
    else
        AdminNotify(src, 'Failed to get player identifiers', 'error')
    end
end, false)

-- /removeadmin [id] - Revoke admin access from a player
RegisterCommand('removeadmin', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    if not targetId then
        AdminNotify(src, 'Usage: /removeadmin [id]', 'error')
        return
    end

    local targetName = GetPlayerName(targetId)
    if not targetName then
        AdminNotify(src, 'Player not found', 'error')
        return
    end

    for i = 0, GetNumPlayerIdentifiers(targetId) - 1 do
        local identifier = GetPlayerIdentifier(targetId, i)
        if identifier then
            ExecuteCommand(('remove_principal identifier.%s group.admin'):format(identifier))
        end
    end

    TriggerClientEvent('sb_admin:permissionResult', targetId, false)
    AdminNotify(src, ('Removed admin from %s (ID: %d)'):format(targetName, targetId), 'success')
    AdminNotify(targetId, 'Your admin access has been revoked', 'info')
    print(('[sb_admin] %s removed admin from %s (ID: %d)'):format(src == 0 and 'Console' or GetPlayerName(src), targetName, targetId))
end, false)

-- ============================================================================
-- JOB MANAGEMENT
-- ============================================================================

-- /setjob [id] [job] [grade]
RegisterCommand('setjob', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0

    if not targetId or not jobName then
        AdminNotify(src, 'Usage: /setjob [id] [job] [grade]', 'error')
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        AdminNotify(src, 'Player not found or not loaded', 'error')
        return
    end

    local jobData = SB.Shared.Jobs[jobName]
    if not jobData then
        -- List available jobs for convenience
        local available = {}
        for k, _ in pairs(SB.Shared.Jobs) do
            available[#available + 1] = k
        end
        AdminNotify(src, 'Invalid job. Available: ' .. table.concat(available, ', '), 'error')
        return
    end

    if not jobData.grades[tostring(grade)] then
        local maxGrade = 0
        for k, _ in pairs(jobData.grades) do
            local g = tonumber(k)
            if g and g > maxGrade then maxGrade = g end
        end
        AdminNotify(src, ('Invalid grade. %s has grades 0-%d'):format(jobName, maxGrade), 'error')
        return
    end

    local success = Player.Functions.SetJob(jobName, grade)
    if success then
        local gradeName = jobData.grades[tostring(grade)].name
        AdminNotify(src, ('Set %s (ID: %d) to %s - %s (Grade %d)'):format(
            GetPlayerName(targetId), targetId, jobData.label, gradeName, grade
        ), 'success')
        print(('[sb_admin] %s set job for %s (ID: %d) to %s grade %d'):format(
            src == 0 and 'Console' or GetPlayerName(src), GetPlayerName(targetId), targetId, jobName, grade
        ))
    else
        AdminNotify(src, 'Failed to set job', 'error')
    end
end, false)

-- /listjobs - List all available jobs with grades
RegisterCommand('listjobs', function(source)
    local src = source
    if not HasPermission(src) then return end

    for name, job in pairs(SB.Shared.Jobs) do
        local maxGrade = 0
        for k, _ in pairs(job.grades) do
            local g = tonumber(k)
            if g and g > maxGrade then maxGrade = g end
        end
        AdminNotify(src, ('%s — %s (grades 0-%d)'):format(name, job.label, maxGrade), 'info')
    end
end, false)

-- /duty - Toggle own duty status on/off
RegisterCommand('duty', function(source)
    local src = source
    if src == 0 then return print('[sb_admin] Cannot use /duty from console') end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return AdminNotify(src, 'Player data not found.', 'error') end

    local job = Player.PlayerData.job
    if not job or job.name == 'unemployed' then
        return AdminNotify(src, 'You need a job to go on duty.', 'error')
    end

    local newDuty = not job.onduty
    Player.Functions.SetJobDuty(newDuty)

    -- Sync with sb_police if player is police
    if job.name == 'police' and GetResourceState('sb_police') == 'started' then
        TriggerEvent('sb_police:server:syncDutyFromCore', src, newDuty)
    end

    if newDuty then
        AdminNotify(src, 'You are now ON DUTY as ' .. (job.label or job.name), 'success')
    else
        AdminNotify(src, 'You are now OFF DUTY.', 'info')
    end
end, false)

-- /setduty [id] [on/off] - Admin: set another player's duty status
RegisterCommand('setduty', function(source, args)
    local src = source
    if not HasPermission(src) then return end

    local targetId = tonumber(args[1])
    local dutyStr = args[2]

    if not targetId or not dutyStr then
        return AdminNotify(src, 'Usage: /setduty [id] [on/off]', 'error')
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        return AdminNotify(src, 'Player not found or not logged in.', 'error')
    end

    local job = Player.PlayerData.job
    if not job or job.name == 'unemployed' then
        return AdminNotify(src, 'That player has no job.', 'error')
    end

    local onDuty = (dutyStr == 'on' or dutyStr == '1' or dutyStr == 'true')
    Player.Functions.SetJobDuty(onDuty)

    -- Sync with sb_police if target is police
    if job.name == 'police' and GetResourceState('sb_police') == 'started' then
        TriggerEvent('sb_police:server:syncDutyFromCore', targetId, onDuty)
    end

    local status = onDuty and 'ON DUTY' or 'OFF DUTY'
    AdminNotify(src, ('Set %s (%s) to %s'):format(GetPlayerName(targetId), job.label or job.name, status), 'success')
    AdminNotify(targetId, ('You are now %s as %s'):format(status, job.label or job.name), onDuty and 'success' or 'info')
end, false)
