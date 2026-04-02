--[[
    Everyday Chaos RP - Server Functions
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- PLAYER RETRIEVAL FUNCTIONS
-- ============================================================================

-- Get player by source
function SB.Functions.GetPlayer(source)
    if not source or source == 0 then
        return nil
    end
    return SB.Players[source]
end

-- Get player by citizen ID
function SB.Functions.GetPlayerByCitizenId(citizenid)
    if not citizenid then return nil end

    for _, Player in pairs(SB.Players) do
        if Player.PlayerData.citizenid == citizenid then
            return Player
        end
    end
    return nil
end

-- Get player by phone number
function SB.Functions.GetPlayerByPhone(phone)
    if not phone then return nil end

    for _, Player in pairs(SB.Players) do
        if Player.PlayerData.charinfo and Player.PlayerData.charinfo.phone == phone then
            return Player
        end
    end
    return nil
end

-- Get player by license
function SB.Functions.GetPlayerByLicense(license)
    if not license then return nil end

    for _, Player in pairs(SB.Players) do
        if Player.PlayerData.license == license then
            return Player
        end
    end
    return nil
end

-- Get all player sources
function SB.Functions.GetPlayers()
    local sources = {}
    for src, _ in pairs(SB.Players) do
        sources[#sources + 1] = src
    end
    return sources
end

-- Get all player objects
function SB.Functions.GetSBPlayers()
    return SB.Players
end

-- Get players on duty for a job
function SB.Functions.GetPlayersOnDuty(jobName)
    local players = {}
    local count = 0

    for _, Player in pairs(SB.Players) do
        if Player.PlayerData.job.name == jobName and Player.PlayerData.job.onduty then
            count = count + 1
            players[#players + 1] = Player
        end
    end

    return players, count
end

-- Get duty count for a job
function SB.Functions.GetDutyCount(jobName)
    local count = 0

    for _, Player in pairs(SB.Players) do
        if Player.PlayerData.job.name == jobName and Player.PlayerData.job.onduty then
            count = count + 1
        end
    end

    return count
end

-- ============================================================================
-- IDENTIFIER FUNCTIONS
-- ============================================================================

-- Get player identifier by type
function SB.Functions.GetIdentifier(source, idType)
    idType = idType or 'license'
    local id = GetPlayerIdentifierByType(source, idType)
    -- Dev fallback: if no Rockstar license, generate one from fivem identifier
    if not id and idType == 'license' then
        local fivem = GetPlayerIdentifierByType(source, 'fivem')
        if fivem then
            id = 'license:lan_' .. fivem:gsub('fivem:', '')
        end
    end
    return id
end

-- Get all identifiers for a player
function SB.Functions.GetIdentifiers(source)
    local identifiers = {}
    local playerIdents = GetPlayerIdentifiers(source)

    for _, ident in pairs(playerIdents) do
        local colonPos = string.find(ident, ':')
        if colonPos then
            local identType = string.sub(ident, 1, colonPos - 1)
            identifiers[identType] = ident
        end
    end

    return identifiers
end

-- Get source from identifier
function SB.Functions.GetSource(identifier)
    for src, _ in pairs(SB.Players) do
        local identifiers = SB.Functions.GetIdentifiers(src)
        for _, ident in pairs(identifiers) do
            if ident == identifier then
                return src
            end
        end
    end
    return nil
end

-- ============================================================================
-- CITIZEN ID FUNCTIONS
-- ============================================================================

-- Generate unique citizen ID
function SB.Functions.CreateCitizenId()
    local citizenid = SBShared.RandomStr(8)

    local result = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', { citizenid })

    if result then
        return SB.Functions.CreateCitizenId()
    end

    return citizenid
end

-- Generate phone number (format: (XXX) XXX-XXXX)
function SB.Functions.CreatePhoneNumber()
    local prefixes = { '555', '310', '213', '323', '818' }
    local prefix = prefixes[math.random(#prefixes)]
    local mid = string.format('%03d', math.random(0, 999))
    local last = string.format('%04d', math.random(0, 9999))
    local phone = '(' .. prefix .. ') ' .. mid .. '-' .. last

    local result = MySQL.scalar.await([[
        SELECT citizenid FROM players WHERE JSON_EXTRACT(charinfo, '$.phone') = ?
    ]], { phone })

    if result then
        return SB.Functions.CreatePhoneNumber()
    end

    return phone
end

-- Generate account number
function SB.Functions.CreateAccountNumber()
    return 'EC' .. SBShared.RandomInt(10)
end

-- ============================================================================
-- BAN FUNCTIONS
-- ============================================================================

-- Check if player is banned
function SB.Functions.IsPlayerBanned(source)
    local license = SB.Functions.GetIdentifier(source, 'license')
    local discord = SB.Functions.GetIdentifier(source, 'discord')
    local ip = SB.Functions.GetIdentifier(source, 'ip')

    local result = MySQL.single.await([[
        SELECT * FROM bans WHERE license = ? OR discord = ? OR ip = ?
    ]], { license, discord or '', ip or '' })

    if result then
        -- Check if ban expired
        if result.expire and result.expire > 0 and os.time() > result.expire then
            -- Ban expired, remove it
            MySQL.update.await('DELETE FROM bans WHERE id = ?', { result.id })
            return false, nil
        end

        return true, result
    end

    return false, nil
end

-- Ban a player
function SB.Functions.BanPlayer(source, reason, expire, bannedBy)
    local license = SB.Functions.GetIdentifier(source, 'license')
    local discord = SB.Functions.GetIdentifier(source, 'discord')
    local ip = SB.Functions.GetIdentifier(source, 'ip')
    local name = GetPlayerName(source)

    MySQL.insert.await([[
        INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        name,
        license,
        discord or '',
        ip or '',
        reason,
        expire or nil,
        bannedBy
    })

    DropPlayer(source, 'You have been banned: ' .. reason)

    SBShared.Debug('Banned player: ' .. name .. ' | Reason: ' .. reason)
end

-- ============================================================================
-- USEABLE ITEMS
-- ============================================================================

-- Register a useable item
function SB.Functions.CreateUseableItem(item, cb)
    SB.UsableItems[item] = cb
end

-- Check if item is useable
function SB.Functions.CanUseItem(item)
    return SB.UsableItems[item] ~= nil
end

-- Use an item
function SB.Functions.UseItem(source, item)
    if SB.UsableItems[item] then
        SB.UsableItems[item](source, item)
        return true
    end
    return false
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get coordinates from player source
function SB.Functions.GetCoords(source)
    local ped = GetPlayerPed(source)
    if ped and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        return vector4(coords.x, coords.y, coords.z, heading)
    end
    return nil
end

-- Notify a player
function SB.Functions.Notify(source, message, type, duration)
    TriggerClientEvent('SB:Client:Notify', source, message, type or 'primary', duration or Config.NotifyDuration)
end

-- Notify all players
function SB.Functions.NotifyAll(message, type, duration)
    TriggerClientEvent('SB:Client:Notify', -1, message, type or 'primary', duration or Config.NotifyDuration)
end

-- Kick a player
function SB.Functions.Kick(source, reason)
    reason = reason or 'No reason provided'

    local Player = SB.Functions.GetPlayer(source)
    if Player then
        Player.Functions.Save()
        SB.Players[source] = nil
    end

    DropPlayer(source, reason)
end

-- ============================================================================
-- CALLBACK FUNCTIONS
-- ============================================================================

-- Create a server callback
function SB.Functions.CreateCallback(name, cb)
    SB.ServerCallbacks[name] = cb
end

-- Trigger a client callback
function SB.Functions.TriggerClientCallback(name, source, cb, ...)
    local requestId = SBShared.RandomStr(10)
    SB.ClientCallbacks[requestId] = cb

    TriggerClientEvent('SB:Client:TriggerCallback', source, name, requestId, ...)
end

-- ============================================================================
-- OFFLINE PLAYER FUNCTIONS
-- ============================================================================

-- Get offline player by citizen ID
function SB.Functions.GetOfflinePlayer(citizenid)
    local result = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { citizenid })

    if result then
        return {
            citizenid = result.citizenid,
            license = result.license,
            name = result.name,
            money = json.decode(result.money),
            charinfo = json.decode(result.charinfo),
            job = json.decode(result.job),
            gang = json.decode(result.gang),
            position = json.decode(result.position),
            metadata = json.decode(result.metadata)
        }
    end

    return nil
end

-- Save offline player data
function SB.Functions.SaveOfflinePlayer(citizenid, data)
    MySQL.update.await([[
        UPDATE players SET
            money = ?,
            job = ?,
            gang = ?,
            metadata = ?
        WHERE citizenid = ?
    ]], {
        json.encode(data.money),
        json.encode(data.job),
        json.encode(data.gang),
        json.encode(data.metadata),
        citizenid
    })
end

-- ============================================================================
-- USER FUNCTIONS (Account-level, not character-level)
-- ============================================================================

-- Get or create user by license
function SB.Functions.GetUser(source)
    local license = SB.Functions.GetIdentifier(source, 'license')
    if not license then return nil end

    local user = MySQL.single.await('SELECT * FROM users WHERE license = ?', { license })

    if user then
        -- Parse JSON permissions
        user.permissions = user.permissions and json.decode(user.permissions) or {}
        return user
    end

    return nil
end

-- Create new user on first join
function SB.Functions.CreateUser(source)
    local identifiers = SB.Functions.GetIdentifiers(source)
    local license = identifiers.license
    local name = GetPlayerName(source)

    if not license then return nil end

    -- Check if user already exists
    local existing = MySQL.scalar.await('SELECT id FROM users WHERE license = ?', { license })
    if existing then
        -- Update last seen and name
        MySQL.update.await('UPDATE users SET name = ?, last_seen = NOW() WHERE license = ?', { name, license })
        return SB.Functions.GetUser(source)
    end

    -- Create new user
    MySQL.insert.await([[
        INSERT INTO users (license, steam, discord, xbox, live, fivem, name, role, character_slots)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'user', ?)
    ]], {
        license,
        identifiers.steam or nil,
        identifiers.discord or nil,
        identifiers.xbox or nil,
        identifiers.live or nil,
        identifiers.fivem or nil,
        name,
        Config.MaxCharacters
    })

    SBShared.Debug('New user created: ' .. name .. ' (' .. license .. ')')

    return SB.Functions.GetUser(source)
end

-- Get user by license (offline)
function SB.Functions.GetUserByLicense(license)
    local user = MySQL.single.await('SELECT * FROM users WHERE license = ?', { license })

    if user then
        user.permissions = user.permissions and json.decode(user.permissions) or {}
        return user
    end

    return nil
end

-- Update user role
function SB.Functions.SetUserRole(license, role, adminLicense, reason)
    local oldUser = SB.Functions.GetUserByLicense(license)
    local oldRole = oldUser and oldUser.role or 'user'

    MySQL.update.await('UPDATE users SET role = ? WHERE license = ?', { role, license })

    -- Log the change
    MySQL.insert.await([[
        INSERT INTO permission_logs (license, action, old_value, new_value, admin_license, reason)
        VALUES (?, 'role_change', ?, ?, ?, ?)
    ]], { license, oldRole, role, adminLicense, reason })

    SBShared.Debug('Role changed for ' .. license .. ': ' .. oldRole .. ' -> ' .. role)
end

-- Check if user has permission
function SB.Functions.HasPermission(source, permission)
    local user = SB.Functions.GetUser(source)
    if not user then return false end

    -- Get role permissions
    local role = MySQL.single.await('SELECT permissions, priority FROM roles WHERE name = ?', { user.role })
    if not role then return false end

    local rolePerms = json.decode(role.permissions) or {}

    -- Superadmin wildcard
    if SBShared.TableContains(rolePerms, '*') then
        return true
    end

    -- Check exact permission
    if SBShared.TableContains(rolePerms, permission) then
        return true
    end

    -- Check wildcard (e.g., "admin.*" matches "admin.kick")
    local permCategory = string.match(permission, '([^.]+)%.')
    if permCategory and SBShared.TableContains(rolePerms, permCategory .. '.*') then
        return true
    end

    -- Check user-specific permissions
    if user.permissions and SBShared.TableContains(user.permissions, permission) then
        return true
    end

    return false
end

-- Grant permission to user
function SB.Functions.GrantPermission(license, permission, adminLicense, reason)
    local user = SB.Functions.GetUserByLicense(license)
    if not user then return false end

    local perms = user.permissions or {}
    if not SBShared.TableContains(perms, permission) then
        table.insert(perms, permission)
    end

    MySQL.update.await('UPDATE users SET permissions = ? WHERE license = ?', {
        json.encode(perms), license
    })

    -- Log
    MySQL.insert.await([[
        INSERT INTO permission_logs (license, action, permission, admin_license, reason)
        VALUES (?, 'grant', ?, ?, ?)
    ]], { license, permission, adminLicense, reason })

    return true
end

-- Revoke permission from user
function SB.Functions.RevokePermission(license, permission, adminLicense, reason)
    local user = SB.Functions.GetUserByLicense(license)
    if not user then return false end

    local perms = user.permissions or {}
    for i, perm in ipairs(perms) do
        if perm == permission then
            table.remove(perms, i)
            break
        end
    end

    MySQL.update.await('UPDATE users SET permissions = ? WHERE license = ?', {
        json.encode(perms), license
    })

    -- Log
    MySQL.insert.await([[
        INSERT INTO permission_logs (license, action, permission, admin_license, reason)
        VALUES (?, 'revoke', ?, ?, ?)
    ]], { license, permission, adminLicense, reason })

    return true
end

-- Get character slots for user
function SB.Functions.GetCharacterSlots(source)
    local user = SB.Functions.GetUser(source)
    if user then
        return user.character_slots or Config.MaxCharacters
    end
    return Config.MaxCharacters
end

-- Update user playtime
function SB.Functions.UpdatePlaytime(source, minutes)
    local license = SB.Functions.GetIdentifier(source, 'license')
    if not license then return end

    MySQL.update.await([[
        UPDATE users SET playtime = playtime + ?, last_seen = NOW() WHERE license = ?
    ]], { minutes, license })
end

-- Check VIP status
function SB.Functions.IsVIP(source)
    local user = SB.Functions.GetUser(source)
    if not user then return false, 0 end

    if user.vip_level > 0 then
        -- Check if VIP expired
        if user.vip_expires then
            local expireTime = MySQL.scalar.await([[
                SELECT UNIX_TIMESTAMP(vip_expires) FROM users WHERE license = ?
            ]], { user.license })

            if expireTime and os.time() > expireTime then
                -- VIP expired
                MySQL.update.await('UPDATE users SET vip_level = 0, vip_expires = NULL WHERE license = ?', { user.license })
                return false, 0
            end
        end

        return true, user.vip_level
    end

    return false, 0
end

-- Set VIP status
function SB.Functions.SetVIP(license, level, days)
    local expireDate = days and ('DATE_ADD(NOW(), INTERVAL ' .. days .. ' DAY)') or 'NULL'

    MySQL.update.await([[
        UPDATE users SET vip_level = ?, vip_expires = ]] .. expireDate .. [[ WHERE license = ?
    ]], { level, license })

    SBShared.Debug('VIP set for ' .. license .. ': Level ' .. level .. (days and (' for ' .. days .. ' days') or ' (permanent)'))
end

-- Get all roles
function SB.Functions.GetRoles()
    return MySQL.query.await('SELECT * FROM roles ORDER BY priority DESC')
end
