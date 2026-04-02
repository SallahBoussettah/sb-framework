--[[
    Everyday Chaos RP - Server Main
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- CORE OBJECT INITIALIZATION
-- ============================================================================
SB = {}
SB.Config = Config
SB.Shared = SBShared
SB.Players = {}                     -- Active player objects by source (characters)
SB.Users = {}                       -- Active user objects by source (accounts)
SB.ServerCallbacks = {}             -- Registered server callbacks
SB.ClientCallbacks = {}             -- For server->client callbacks
SB.UsableItems = {}                 -- Registered usable items
SB.Functions = {}                   -- Will be populated by functions.lua
SB.Player = {}                      -- Will be populated by player.lua

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local resourceStarted = false

CreateThread(function()
    -- Wait for oxmysql to be ready
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end

    -- Initialize database tables if needed
    SB.Functions.InitializeDatabase()

    resourceStarted = true
    print('^2[SB_CORE]^7 Core framework initialized successfully!')
    print('^2[SB_CORE]^7 Server: ' .. Config.ServerName)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Get the core object (main way for other resources to access the framework)
exports('GetCoreObject', function()
    return SB
end)

-- Shorthand exports
exports('GetPlayer', function(source)
    return SB.Functions.GetPlayer(source)
end)

exports('GetPlayerByCitizenId', function(citizenid)
    return SB.Functions.GetPlayerByCitizenId(citizenid)
end)

exports('GetPlayers', function()
    return SB.Functions.GetPlayers()
end)

exports('CreateCallback', function(name, cb)
    SB.Functions.CreateCallback(name, cb)
end)

exports('CreateUseableItem', function(item, cb)
    SB.Functions.CreateUseableItem(item, cb)
end)

-- User exports
exports('GetUser', function(source)
    return SB.Functions.GetUser(source)
end)

exports('HasPermission', function(source, permission)
    return SB.Functions.HasPermission(source, permission)
end)

exports('IsVIP', function(source)
    return SB.Functions.IsVIP(source)
end)

exports('GetCharacterSlots', function(source)
    return SB.Functions.GetCharacterSlots(source)
end)

-- ============================================================================
-- DATABASE INITIALIZATION
-- ============================================================================
function SB.Functions.InitializeDatabase()
    print('^3[SB_CORE]^7 Checking database tables...')

    -- Create users table (account-level)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `users` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(255) NOT NULL,
            `steam` VARCHAR(255) DEFAULT NULL,
            `discord` VARCHAR(255) DEFAULT NULL,
            `xbox` VARCHAR(255) DEFAULT NULL,
            `live` VARCHAR(255) DEFAULT NULL,
            `fivem` VARCHAR(255) DEFAULT NULL,
            `name` VARCHAR(255) NOT NULL,
            `role` VARCHAR(50) DEFAULT 'user',
            `permissions` TEXT DEFAULT NULL,
            `playtime` INT(11) DEFAULT 0,
            `character_slots` INT(11) DEFAULT 3,
            `is_whitelisted` TINYINT(1) DEFAULT 0,
            `is_banned` TINYINT(1) DEFAULT 0,
            `vip_level` INT(11) DEFAULT 0,
            `vip_expires` TIMESTAMP NULL DEFAULT NULL,
            `priority` INT(11) DEFAULT 0,
            `notes` TEXT DEFAULT NULL,
            `first_join` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `license` (`license`),
            KEY `discord` (`discord`),
            KEY `role` (`role`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Create roles table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `roles` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(50) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `priority` INT(11) DEFAULT 0,
            `permissions` TEXT NOT NULL,
            `color` VARCHAR(10) DEFAULT '#ffffff',
            `icon` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Insert default roles if empty
    local roleCount = MySQL.scalar.await('SELECT COUNT(*) FROM roles')
    if roleCount == 0 then
        MySQL.query.await([[
            INSERT INTO `roles` (`name`, `label`, `priority`, `permissions`, `color`, `icon`) VALUES
            ('user', 'Player', 0, '["play"]', '#ffffff', 'user'),
            ('vip', 'VIP', 10, '["play", "vip.priority", "vip.extras"]', '#ffd700', 'star'),
            ('moderator', 'Moderator', 50, '["play", "mod.kick", "mod.warn", "mod.spectate", "mod.teleport"]', '#00bfff', 'shield'),
            ('admin', 'Admin', 80, '["play", "admin.*", "mod.*"]', '#ff6b35', 'shield-check'),
            ('superadmin', 'Super Admin', 100, '["*"]', '#ff0000', 'crown')
        ]])
        print('^2[SB_CORE]^7 Default roles created.')
    end

    -- Create permission_logs table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `permission_logs` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(255) NOT NULL,
            `action` VARCHAR(50) NOT NULL,
            `permission` VARCHAR(100) DEFAULT NULL,
            `old_value` VARCHAR(100) DEFAULT NULL,
            `new_value` VARCHAR(100) DEFAULT NULL,
            `admin_license` VARCHAR(255) DEFAULT NULL,
            `reason` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Create players table (character-level)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `players` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `cid` INT(11) DEFAULT NULL,
            `license` VARCHAR(255) NOT NULL,
            `name` VARCHAR(255) NOT NULL,
            `money` TEXT NOT NULL,
            `charinfo` TEXT DEFAULT NULL,
            `job` TEXT NOT NULL,
            `gang` TEXT DEFAULT NULL,
            `position` TEXT NOT NULL,
            `metadata` TEXT NOT NULL,
            `inventory` LONGTEXT DEFAULT NULL,
            `skin` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`),
            KEY `id` (`id`),
            KEY `license` (`license`),
            KEY `cid` (`cid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Create bans table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bans` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(255) DEFAULT NULL,
            `license` VARCHAR(255) NOT NULL,
            `discord` VARCHAR(255) DEFAULT NULL,
            `ip` VARCHAR(255) DEFAULT NULL,
            `reason` TEXT NOT NULL,
            `expire` INT(11) DEFAULT NULL,
            `bannedby` VARCHAR(255) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Create player_vehicles table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `player_vehicles` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `vehicle` VARCHAR(50) NOT NULL,
            `plate` VARCHAR(12) NOT NULL,
            `mods` LONGTEXT DEFAULT NULL,
            `garage` VARCHAR(50) DEFAULT 'legion',
            `fuel` INT(11) DEFAULT 100,
            `engine` FLOAT DEFAULT 1000.0,
            `body` FLOAT DEFAULT 1000.0,
            `state` TINYINT(1) DEFAULT 1,
            `depotprice` INT(11) DEFAULT 0,
            `balance` INT(11) DEFAULT 0,
            `paymentamount` INT(11) DEFAULT 0,
            `paymentsleft` INT(11) DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `plate` (`plate`),
            UNIQUE KEY `plate_unique` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    print('^2[SB_CORE]^7 Database tables ready!')
end

-- ============================================================================
-- RESOURCE EVENTS
-- ============================================================================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Framework started
    SBShared.Debug('SB_CORE resource started')

    -- Auto-reconnect players who were already logged in (after resource restart)
    SetTimeout(1000, function()
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local src = tonumber(playerId)
            local playerState = Player(src).state
            local citizenid = playerState.citizenid

            if citizenid and citizenid ~= '' then
                -- Player was logged in before restart, re-login them
                print('^3[SB_CORE]^7 Auto-reconnecting player ' .. src .. ' (citizenid: ' .. citizenid .. ')')

                local Player = SB.Player.Login(src, citizenid, nil)
                if Player then
                    print('^2[SB_CORE]^7 Successfully reconnected: ' .. Player.Functions.GetName())
                    TriggerClientEvent('SB:Client:OnPlayerLoaded', src, Player.PlayerData)
                else
                    print('^1[SB_CORE]^7 Failed to reconnect player ' .. src)
                end
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Save all players before stopping
    for src, Player in pairs(SB.Players) do
        if Player then
            Player.Functions.Save()
        end
    end

    print('^3[SB_CORE]^7 All players saved. Resource stopping.')
end)
