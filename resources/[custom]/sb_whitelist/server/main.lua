--[[
    sb_whitelist - Server Main
    Author: Salah Eddine Boussettah
    Everyday Chaos RP

    Provides whitelist exports (called by sb_core during connection)
    and admin commands for managing whitelist.

    Commands:
      /whitelist add [id]                 - Whitelist an online player
      /whitelist remove [id]              - Remove whitelist from online player
      /whitelist addlicense [license]     - Whitelist by license (offline)
      /whitelist removelicense [license]  - Remove by license (offline)
      /whitelist check [id]              - Check player whitelist status
      /whitelist on                       - Enable whitelist
      /whitelist off                      - Disable whitelist
      /whitelist list                     - List all whitelisted players
      /whitelist password [newpass]       - Change server password
]]

-- ============================================================================
-- EXPORTS (called by sb_core during playerConnecting)
-- ============================================================================

-- Check if whitelist system is enabled
exports('IsEnabled', function()
    return Config.WhitelistEnabled
end)

-- Get the server password
exports('GetPassword', function()
    return Config.ServerPassword or ""
end)

-- Check if an identifier is an admin (bypasses whitelist)
exports('IsAdminIdentifier', function(identifiers)
    if not identifiers then return false end
    for _, id in pairs(identifiers) do
        for _, adminId in pairs(Config.AdminIdentifiers) do
            if id == adminId then
                return true
            end
        end
    end
    return false
end)

-- ============================================================================
-- HELPER: Get license identifier from source
-- ============================================================================
local function GetLicense(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return nil
end

-- ============================================================================
-- HELPER: Check if source is admin
-- ============================================================================
local function IsAdmin(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        for _, adminId in pairs(Config.AdminIdentifiers) do
            if id == adminId then
                return true
            end
        end
    end
    return IsPlayerAceAllowed(source, 'command')
end

-- ============================================================================
-- HELPER: Send message to source or console
-- ============================================================================
local function SendMessage(source, msg)
    if source == 0 then
        print('[SB_WHITELIST] ' .. msg)
    else
        TriggerClientEvent('chat:addMessage', source, { args = { 'WHITELIST', msg } })
    end
end

-- ============================================================================
-- ADMIN COMMAND: /whitelist
-- ============================================================================
RegisterCommand('whitelist', function(source, args, rawCommand)
    if source ~= 0 and not IsAdmin(source) then
        SendMessage(source, 'You do not have permission to use this command.')
        return
    end

    local action = args[1]

    if not action then
        SendMessage(source, 'Usage: /whitelist [add|remove|addlicense|removelicense|check|on|off|list|password]')
        return
    end

    action = string.lower(action)

    -- /whitelist on
    if action == 'on' then
        Config.WhitelistEnabled = true
        print('^2[SB_WHITELIST]^7 Whitelist ENABLED')
        if source > 0 then SendMessage(source, 'Whitelist has been ^2ENABLED^7.') end
        return
    end

    -- /whitelist off
    if action == 'off' then
        Config.WhitelistEnabled = false
        print('^3[SB_WHITELIST]^7 Whitelist DISABLED')
        if source > 0 then SendMessage(source, 'Whitelist has been ^1DISABLED^7.') end
        return
    end

    -- /whitelist password [newpass]
    if action == 'password' then
        local newPass = args[2]
        if not newPass then
            SendMessage(source, 'Current password: ' .. (Config.ServerPassword or '(none)'))
            SendMessage(source, 'Usage: /whitelist password [newpassword]')
            return
        end
        Config.ServerPassword = newPass
        print('^2[SB_WHITELIST]^7 Password changed to: ' .. newPass)
        if source > 0 then SendMessage(source, 'Server password changed.') end
        return
    end

    -- /whitelist list
    if action == 'list' then
        local results = MySQL.query.await('SELECT license, name, discord FROM users WHERE is_whitelisted = 1')
        if results and #results > 0 then
            SendMessage(source, 'Whitelisted players (' .. #results .. '):')
            for _, row in pairs(results) do
                SendMessage(source, '- ' .. (row.name or 'Unknown') .. ' | ' .. row.license .. (row.discord and (' | ' .. row.discord) or ''))
            end
        else
            SendMessage(source, 'No whitelisted players found.')
        end
        return
    end

    -- /whitelist add [serverid]
    if action == 'add' then
        local targetId = tonumber(args[2])
        if not targetId then
            SendMessage(source, 'Usage: /whitelist add [server id]')
            return
        end

        local targetName = GetPlayerName(targetId)
        if not targetName then
            SendMessage(source, 'Player not found with ID: ' .. targetId)
            return
        end

        local license = GetLicense(targetId)
        if not license then
            SendMessage(source, 'Could not get license for player ' .. targetId)
            return
        end

        MySQL.update.await('UPDATE users SET is_whitelisted = 1 WHERE license = ?', { license })
        local msg = targetName .. ' (' .. license .. ') has been whitelisted.'
        print('^2[SB_WHITELIST]^7 ' .. msg)
        if source > 0 then SendMessage(source, msg) end
        return
    end

    -- /whitelist remove [serverid]
    if action == 'remove' then
        local targetId = tonumber(args[2])
        if not targetId then
            SendMessage(source, 'Usage: /whitelist remove [server id]')
            return
        end

        local targetName = GetPlayerName(targetId)
        if not targetName then
            SendMessage(source, 'Player not found with ID: ' .. targetId)
            return
        end

        local license = GetLicense(targetId)
        if not license then
            SendMessage(source, 'Could not get license for player ' .. targetId)
            return
        end

        MySQL.update.await('UPDATE users SET is_whitelisted = 0 WHERE license = ?', { license })
        local msg = targetName .. ' whitelist has been removed.'
        print('^3[SB_WHITELIST]^7 ' .. msg)
        if source > 0 then SendMessage(source, msg) end
        return
    end

    -- /whitelist addlicense [license:xxxxx]
    if action == 'addlicense' then
        local license = args[2]
        if not license then
            SendMessage(source, 'Usage: /whitelist addlicense [license:xxxxx]')
            return
        end

        local result = MySQL.update.await('UPDATE users SET is_whitelisted = 1 WHERE license = ?', { license })
        if result and result > 0 then
            local msg = 'License ' .. license .. ' has been whitelisted.'
            print('^2[SB_WHITELIST]^7 ' .. msg)
            if source > 0 then SendMessage(source, msg) end
        else
            SendMessage(source, 'No user found with license: ' .. license)
        end
        return
    end

    -- /whitelist removelicense [license:xxxxx]
    if action == 'removelicense' then
        local license = args[2]
        if not license then
            SendMessage(source, 'Usage: /whitelist removelicense [license:xxxxx]')
            return
        end

        local result = MySQL.update.await('UPDATE users SET is_whitelisted = 0 WHERE license = ?', { license })
        if result and result > 0 then
            local msg = 'License ' .. license .. ' whitelist removed.'
            print('^3[SB_WHITELIST]^7 ' .. msg)
            if source > 0 then SendMessage(source, msg) end
        else
            SendMessage(source, 'No user found with license: ' .. license)
        end
        return
    end

    -- /whitelist check [serverid]
    if action == 'check' then
        local targetId = tonumber(args[2])
        if not targetId then
            SendMessage(source, 'Usage: /whitelist check [server id]')
            return
        end

        local targetName = GetPlayerName(targetId)
        if not targetName then
            SendMessage(source, 'Player not found with ID: ' .. targetId)
            return
        end

        local license = GetLicense(targetId)
        local result = MySQL.single.await('SELECT is_whitelisted FROM users WHERE license = ?', { license })
        local status = (result and result.is_whitelisted == 1) and '^2WHITELISTED^7' or '^1NOT WHITELISTED^7'
        SendMessage(source, targetName .. ' (ID: ' .. targetId .. ') - ' .. status)
        return
    end

    SendMessage(source, 'Unknown action. Use: add, remove, addlicense, removelicense, check, on, off, list, password')
end, true)

-- ============================================================================
-- STARTUP
-- ============================================================================
CreateThread(function()
    if Config.WhitelistEnabled then
        print('^2[SB_WHITELIST]^7 Whitelist system loaded and ^2ENABLED^7 | Password: ' .. (Config.ServerPassword or '(none)'))
    else
        print('^3[SB_WHITELIST]^7 Whitelist system loaded but ^3DISABLED^7')
    end
end)
