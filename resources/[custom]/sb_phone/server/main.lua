-- ============================================================================
-- SB Phone V2 — Server
-- Author: Salah Eddine Boussettah
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- Forward declarations (used before their section)
local activeCalls = {}
local playerAirplaneMode = {}

-- ============================================================================
-- DATABASE MIGRATIONS
-- ============================================================================

CreateThread(function()
    MySQL.update.await([[
        ALTER TABLE phone_contacts ADD COLUMN IF NOT EXISTS favorite TINYINT(1) DEFAULT 0
    ]])

    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS phone_serials (
            serial VARCHAR(20) NOT NULL PRIMARY KEY,
            owner_citizenid VARCHAR(50) NOT NULL,
            owner_name VARCHAR(100) NOT NULL DEFAULT '',
            phone_number VARCHAR(20) NOT NULL,
            activated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_owner (owner_citizenid)
        )
    ]])

    MySQL.update.await([[
        ALTER TABLE phone_messages ADD COLUMN IF NOT EXISTS status VARCHAR(10) DEFAULT 'delivered'
    ]])

    MySQL.insert.await([[
        INSERT IGNORE INTO sb_items (name, label, type, category, stackable, max_stack, useable, shouldClose, description)
        VALUES ('phone', 'Phone', 'item', 'electronics', 0, 1, 1, 1, 'A smartphone for calls, messages, and apps')
    ]])

    -- Instapic migrations
    MySQL.update.await([[
        ALTER TABLE phone_social_posts ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT NULL
    ]])
    MySQL.update.await([[
        ALTER TABLE phone_social_posts ADD COLUMN IF NOT EXISTS comment_count INT DEFAULT 0
    ]])
    MySQL.update.await([[
        ALTER TABLE phone_social_stories ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT NULL
    ]])

    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS phone_social_profiles (
            citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
            username VARCHAR(100) NOT NULL DEFAULT '',
            bio VARCHAR(300) DEFAULT '',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS phone_social_follows (
            id INT AUTO_INCREMENT PRIMARY KEY,
            follower_citizenid VARCHAR(50) NOT NULL,
            following_citizenid VARCHAR(50) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_follow (follower_citizenid, following_citizenid),
            INDEX idx_follower (follower_citizenid),
            INDEX idx_following (following_citizenid)
        )
    ]])

    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS phone_social_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            post_id INT NOT NULL,
            author_citizenid VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL DEFAULT '',
            content TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_post (post_id)
        )
    ]])

    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS phone_social_dms (
            id INT AUTO_INCREMENT PRIMARY KEY,
            sender_citizenid VARCHAR(50) NOT NULL,
            receiver_citizenid VARCHAR(50) NOT NULL,
            message TEXT NOT NULL,
            is_read TINYINT(1) DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_sender (sender_citizenid),
            INDEX idx_receiver (receiver_citizenid)
        )
    ]])

    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS phone_social_story_views (
            id INT AUTO_INCREMENT PRIMARY KEY,
            story_id INT NOT NULL,
            viewer_citizenid VARCHAR(50) NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_view (story_id, viewer_citizenid)
        )
    ]])

    -- Migrate old phone numbers
    local players = MySQL.query.await('SELECT citizenid, charinfo FROM players')
    if players then
        for _, row in ipairs(players) do
            local ok, charinfo = pcall(json.decode, row.charinfo)
            if ok and charinfo and charinfo.phone then
                local phone = charinfo.phone
                local newPhone = Config.FormatPhoneNumber(phone)
                if newPhone ~= phone then
                    charinfo.phone = newPhone
                    MySQL.update.await('UPDATE players SET charinfo = ? WHERE citizenid = ?', { json.encode(charinfo), row.citizenid })
                    print('^3[sb_phone]^7 Migrated phone number for ' .. row.citizenid .. ': ' .. phone .. ' -> ' .. newPhone)
                end
            end
        end
    end
end)

-- ============================================================================
-- PERIODIC CLEANUP — old messages, expired stories, old story views
-- ============================================================================

CreateThread(function()
    Wait(60000) -- Wait 1 min after start before first cleanup
    while true do
        local deletedMsgs = MySQL.update.await(
            'DELETE FROM phone_messages WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)'
        ) or 0
        local deletedStories = MySQL.update.await(
            'DELETE FROM phone_social_stories WHERE expires_at < DATE_SUB(NOW(), INTERVAL 7 DAY)'
        ) or 0
        local deletedViews = MySQL.update.await(
            'DELETE FROM phone_social_story_views WHERE story_id NOT IN (SELECT id FROM phone_social_stories)'
        ) or 0
        if deletedMsgs > 0 or deletedStories > 0 or deletedViews > 0 then
            print('^3[sb_phone]^7 Cleanup: ' .. deletedMsgs .. ' old messages, ' .. deletedStories .. ' expired stories, ' .. deletedViews .. ' orphan views removed')
        end
        Wait(6 * 60 * 60 * 1000) -- Run every 6 hours
    end
end)

-- ============================================================================
-- UPLOAD CONFIG (read tokens from server convars, never expose in source)
-- ============================================================================

local function GetUploadConfigServer()
    local method = Config.CameraUploadMethod or 'fivemanager'
    if method == 'fivemanager' then
        local token = GetConvar('sb_phone_fivemanager_token', '')
        if token ~= '' then
            return {
                url = 'https://api.fivemanage.com/api/image',
                field = 'file',
                headers = { ['Authorization'] = token },
                encoding = 'jpg',
                quality = Config.ScreenshotQuality or 0.85
            }
        end
    elseif method == 'imgur' then
        local clientId = GetConvar('sb_phone_imgur_clientid', '')
        if clientId ~= '' then
            return {
                url = 'https://api.imgur.com/3/image',
                field = 'image',
                headers = { ['Authorization'] = 'Client-ID ' .. clientId },
                encoding = 'jpg',
                quality = Config.ScreenshotQuality or 0.85
            }
        end
    elseif method == 'discord' then
        local webhook = GetConvar('sb_phone_discord_webhook', '')
        if webhook ~= '' then
            return {
                url = webhook,
                field = 'files[]',
                headers = {},
                encoding = 'jpg',
                quality = Config.ScreenshotQuality or 0.85
            }
        end
    elseif method == 'custom' then
        local customUrl = GetConvar('sb_phone_custom_upload_url', '')
        if customUrl ~= '' then
            return {
                url = customUrl,
                field = Config.CustomUploadField or 'file',
                headers = {},
                encoding = 'jpg',
                quality = Config.ScreenshotQuality or 0.85
            }
        end
    end
    return nil
end

SB.Functions.CreateCallback('sb_phone:server:getUploadConfig', function(source, cb)
    local config = GetUploadConfigServer()
    cb(config)
end)

-- ============================================================================
-- SERIAL NUMBER HELPERS
-- ============================================================================

local function GenerateSerial()
    return 'SB-' .. string.format('%04X', math.random(0, 65535)) .. '-'
        .. string.format('%04X', math.random(0, 65535)) .. '-'
        .. string.format('%04X', math.random(0, 65535))
end

local function GetPhoneBySerial(serial)
    return MySQL.single.await(
        'SELECT serial, owner_citizenid, owner_name, phone_number FROM phone_serials WHERE serial = ?',
        { serial }
    )
end

local function ActivatePhone(serial, citizenid, ownerName, phoneNumber)
    MySQL.insert.await(
        'INSERT INTO phone_serials (serial, owner_citizenid, owner_name, phone_number) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE owner_citizenid = VALUES(owner_citizenid), owner_name = VALUES(owner_name), phone_number = VALUES(phone_number)',
        { serial, citizenid, ownerName, phoneNumber }
    )
end

-- ============================================================================
-- ITEM USE HANDLER
-- ============================================================================

AddEventHandler('sb_inventory:server:itemUsed', function(source, itemName, amount, metadata, category)
    if itemName ~= Config.ItemName then return end

    metadata = metadata or {}
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    local charinfo = Player.PlayerData.charinfo or {}
    local citizenid = Player.PlayerData.citizenid
    local ownerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')
    local phoneNumber = charinfo.phone

    local formatted = Config.FormatPhoneNumber(phoneNumber)
    if formatted ~= phoneNumber then
        phoneNumber = formatted
        charinfo.phone = phoneNumber
        Player.PlayerData.charinfo = charinfo
        MySQL.update('UPDATE players SET charinfo = ? WHERE citizenid = ?', { json.encode(charinfo), citizenid })
    end

    if not metadata.serial or metadata.serial == '' then
        metadata.serial = GenerateSerial()
    end

    local phoneRecord = GetPhoneBySerial(metadata.serial)

    if not phoneRecord then
        local activeCid = citizenid
        local activeName = ownerName
        local activePhone = phoneNumber

        if metadata.ownerCitizenid and metadata.ownerCitizenid ~= '' then
            activeCid = metadata.ownerCitizenid
            activeName = metadata.ownerName or ownerName
            activePhone = metadata.phoneNumber or phoneNumber
        end

        if not activePhone or activePhone == '' then
            activePhone = Config.FormatPhoneNumber(nil)
        end

        ActivatePhone(metadata.serial, activeCid, activeName, activePhone)

        metadata.ownerCitizenid = activeCid
        metadata.ownerName = activeName
        metadata.phoneNumber = activePhone

        local items = exports['sb_inventory']:GetItemsByName(source, Config.ItemName)
        if items then
            for _, item in ipairs(items) do
                if item.metadata and item.metadata.serial == metadata.serial then
                    exports['sb_inventory']:SetItemMetadata(source, item.slot, metadata)
                    break
                end
            end
        end

        if activeCid ~= citizenid then
            TriggerClientEvent('sb_notify:client:Notify', source, 'This phone is locked to ' .. activeName, 'error', 4000)
            return
        end

        TriggerClientEvent('sb_notify:client:Notify', source, 'Phone activated', 'success', 3000)
    else
        if phoneRecord.owner_citizenid ~= citizenid then
            TriggerClientEvent('sb_notify:client:Notify', source, 'This phone is locked to ' .. phoneRecord.owner_name, 'error', 4000)
            return
        end

        metadata.ownerCitizenid = phoneRecord.owner_citizenid
        metadata.ownerName = phoneRecord.owner_name
        metadata.phoneNumber = phoneRecord.phone_number
    end

    TriggerClientEvent('sb_phone:client:openPhone', source, metadata)
end)

-- ============================================================================
-- EXPORT: createPhone
-- ============================================================================

local function createPhone(source)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return false end

    local charinfo = Player.PlayerData.charinfo or {}
    local citizenid = Player.PlayerData.citizenid
    local ownerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')
    local phone = Config.FormatPhoneNumber(charinfo.phone)

    local serial = GenerateSerial()
    ActivatePhone(serial, citizenid, ownerName, phone)

    local metadata = { serial = serial, ownerCitizenid = citizenid, ownerName = ownerName, phoneNumber = phone }
    local success = exports['sb_inventory']:AddItem(source, Config.ItemName, 1, metadata)
    if success then
        TriggerClientEvent('sb_notify:client:Notify', source, 'Phone added to inventory', 'success', 3000)
    end
    return success
end

exports('createPhone', createPhone)

-- ============================================================================
-- AUTO-GIVE PHONE
-- ============================================================================

AddEventHandler('SB:Server:OnPlayerLoaded', function(src, playerObj)
    -- Initialize immediately to prevent race condition with incoming calls during load
    playerAirplaneMode[src] = false

    SetTimeout(3000, function()
        local Player = SB.Functions.GetPlayer(src)
        if not Player then return end

        local hasPhone = exports['sb_inventory']:HasItem(src, Config.ItemName)
        if not hasPhone then createPhone(src) end

        local citizenid = Player.PlayerData.citizenid
        local settings = MySQL.single.await(
            'SELECT airplane_mode FROM phone_settings WHERE owner_citizenid = ?',
            { citizenid }
        )
        if settings then
            playerAirplaneMode[src] = (settings.airplane_mode or 0) == 1
        end
    end)
end)

-- ============================================================================
-- KEYBIND OPEN
-- ============================================================================

RegisterNetEvent('sb_phone:server:openByKeybind', function()
    local src = source
    local items = exports['sb_inventory']:GetItemsByName(src, Config.ItemName)
    if items and #items > 0 then
        TriggerEvent('sb_inventory:server:itemUsed', src, Config.ItemName, 1, items[1].metadata or {}, 'electronics')
    end
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetSourceByPhone(phoneNumber)
    local players = SB.Functions.GetPlayers()
    for _, src in ipairs(players) do
        local Player = SB.Functions.GetPlayer(src)
        if Player then
            local charinfo = Player.PlayerData.charinfo or {}
            if charinfo.phone == phoneNumber then return src end
        end
    end
    return nil
end

local function GetCitizenidByPhone(phoneNumber)
    local result = MySQL.single.await(
        'SELECT citizenid FROM players WHERE JSON_EXTRACT(charinfo, "$.phone") = ?',
        { phoneNumber }
    )
    return result and result.citizenid or nil
end

-- ============================================================================
-- CALLBACK: Get all phone data
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getPhoneData', function(source, cb, ownerCitizenid, phoneNumber)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    local currentCitizenid = Player.PlayerData.citizenid
    local isOwner = (currentCitizenid == ownerCitizenid)

    local contacts = MySQL.query.await(
        'SELECT id, name, number, IFNULL(favorite, 0) as favorite FROM phone_contacts WHERE owner_citizenid = ? ORDER BY name ASC',
        { ownerCitizenid }
    ) or {}
    for _, c in ipairs(contacts) do c.favorite = c.favorite == 1 end

    local messages = MySQL.query.await(
        'SELECT id, sender_number, receiver_number, message, is_read, created_at FROM phone_messages WHERE sender_number = ? OR receiver_number = ? ORDER BY created_at ASC',
        { phoneNumber, phoneNumber }
    ) or {}

    local calls = MySQL.query.await(
        'SELECT id, caller_number, receiver_number, type, duration, created_at FROM phone_calls WHERE caller_number = ? OR receiver_number = ? ORDER BY created_at DESC LIMIT 50',
        { phoneNumber, phoneNumber }
    ) or {}

    local ownerPlayer = SB.Functions.GetPlayerByCitizenId(ownerCitizenid)
    local bankData = { cash = 0, bank = 0 }
    if ownerPlayer then
        bankData.cash = ownerPlayer.PlayerData.money['cash'] or 0
        bankData.bank = ownerPlayer.PlayerData.money['bank'] or 0
    else
        local moneyResult = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { ownerCitizenid })
        if moneyResult then
            local money = json.decode(moneyResult.money)
            bankData.cash = money.cash or 0
            bankData.bank = money.bank or 0
        end
    end

    local jobData = { title = 'Unemployed', rank = 'None', onDuty = false, badge = '', department = '' }
    if ownerPlayer then
        local job = ownerPlayer.PlayerData.job or {}
        jobData.title = job.label or 'Unemployed'
        jobData.rank = job.grade and job.grade.name or 'None'
        jobData.onDuty = job.onduty or false
        jobData.badge = '#' .. tostring(math.random(1000, 9999))
        jobData.department = job.label or ''
    end

    local settings = MySQL.single.await(
        'SELECT wallpaper, ringtone, airplane_mode, passkey FROM phone_settings WHERE owner_citizenid = ?',
        { ownerCitizenid }
    )
    if not settings then
        MySQL.insert.await('INSERT IGNORE INTO phone_settings (owner_citizenid) VALUES (?)', { ownerCitizenid })
        settings = { wallpaper = 'default', ringtone = 'default', airplane_mode = 0, passkey = nil }
    end

    local gallery = MySQL.query.await(
        'SELECT id, image_url, created_at FROM phone_gallery WHERE owner_citizenid = ? ORDER BY created_at DESC',
        { ownerCitizenid }
    ) or {}

    -- Instapic profile
    local profile = MySQL.single.await('SELECT citizenid, username, bio FROM phone_social_profiles WHERE citizenid = ?', { currentCitizenid })
    if not profile then
        local charinfo2 = Player and Player.PlayerData.charinfo or {}
        local uname = (charinfo2.firstname or 'user') .. '.' .. (charinfo2.lastname or math.random(1000, 9999))
        uname = uname:lower():gsub('%s+', '')
        MySQL.insert.await('INSERT IGNORE INTO phone_social_profiles (citizenid, username, bio) VALUES (?, ?, ?)', { currentCitizenid, uname, '' })
        profile = { citizenid = currentCitizenid, username = uname, bio = '' }
    end
    local followerCount = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_follows WHERE following_citizenid = ?', { currentCitizenid }) or 0
    local followingCount = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_follows WHERE follower_citizenid = ?', { currentCitizenid }) or 0
    local postCount = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_posts WHERE author_citizenid = ?', { currentCitizenid }) or 0
    profile.follower_count = followerCount
    profile.following_count = followingCount
    profile.post_count = postCount

    cb({
        contacts = contacts,
        messages = messages,
        calls = calls,
        bankData = bankData,
        jobData = jobData,
        settings = {
            wallpaper = settings.wallpaper or 'default',
            ringtone = settings.ringtone or 'default',
            airplaneMode = (settings.airplane_mode or 0) == 1,
            hasPasskey = settings.passkey ~= nil and settings.passkey ~= ''
        },
        gallery = gallery,
        instapic = { profile = profile, feed = {}, stories = {} },
        isOwner = isOwner,
        myNumber = phoneNumber
    })
end)

-- ============================================================================
-- CONTACTS
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getContacts', function(source, cb, ownerCitizenid)
    local contacts = MySQL.query.await(
        'SELECT id, name, number, IFNULL(favorite, 0) as favorite FROM phone_contacts WHERE owner_citizenid = ? ORDER BY name ASC',
        { ownerCitizenid }
    ) or {}
    for _, c in ipairs(contacts) do c.favorite = c.favorite == 1 end
    cb(contacts)
end)

SB.Functions.CreateCallback('sb_phone:server:saveContact', function(source, cb, ownerCitizenid, name, number, contactId)
    if not name or name == '' or not number or number == '' then cb(false) return end
    if not contactId then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_contacts WHERE owner_citizenid = ?', { ownerCitizenid })
        if count >= Config.MaxContacts then
            TriggerClientEvent('sb_notify:client:Notify', source, 'Contact list full', 'error', 3000)
            cb(false) return
        end
    end
    if contactId then
        MySQL.update.await('UPDATE phone_contacts SET name = ?, number = ? WHERE id = ? AND owner_citizenid = ?', { name, number, contactId, ownerCitizenid })
    else
        MySQL.insert.await('INSERT IGNORE INTO phone_contacts (owner_citizenid, name, number) VALUES (?, ?, ?)', { ownerCitizenid, name, number })
    end
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:deleteContact', function(source, cb, contactId)
    MySQL.update.await('DELETE FROM phone_contacts WHERE id = ?', { contactId })
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:toggleFavorite', function(source, cb, contactId, favorite)
    MySQL.update.await('UPDATE phone_contacts SET favorite = ? WHERE id = ?', { favorite and 1 or 0, contactId })
    cb(true)
end)

-- ============================================================================
-- MESSAGES
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getMessages', function(source, cb, phoneNumber)
    local messages = MySQL.query.await(
        'SELECT id, sender_number, receiver_number, message, is_read, status, created_at FROM phone_messages WHERE sender_number = ? OR receiver_number = ? ORDER BY created_at ASC',
        { phoneNumber, phoneNumber }
    ) or {}
    cb(messages)
end)

SB.Functions.CreateCallback('sb_phone:server:sendMessage', function(source, cb, senderNumber, receiverNumber, text)
    if not text or text == '' or #text > Config.MaxMessageLength then cb(false) return end
    if playerAirplaneMode[source] then cb(false) return end

    local id = MySQL.insert.await(
        'INSERT INTO phone_messages (sender_number, receiver_number, message) VALUES (?, ?, ?)',
        { senderNumber, receiverNumber, text }
    )

    if id then
        local targetSrc = GetSourceByPhone(receiverNumber)
        if targetSrc and not playerAirplaneMode[targetSrc] then
            local recipientPlayer = SB.Functions.GetPlayer(targetSrc)
            local recipientCid = recipientPlayer and recipientPlayer.PlayerData.citizenid or nil
            local senderName = senderNumber
            if recipientCid then
                local contact = MySQL.single.await(
                    'SELECT name FROM phone_contacts WHERE owner_citizenid = ? AND number = ?',
                    { recipientCid, senderNumber }
                )
                if contact then senderName = contact.name end
            end
            TriggerClientEvent('sb_phone:client:newMessage', targetSrc, {
                senderNumber = senderNumber, senderName = senderName, message = text
            })
        end
    end
    cb(id ~= nil)
end)

SB.Functions.CreateCallback('sb_phone:server:markMessagesRead', function(source, cb, myNumber, otherNumber)
    if not myNumber or not otherNumber then cb(false) return end
    MySQL.update.await(
        'UPDATE phone_messages SET is_read = 1, status = ? WHERE sender_number = ? AND receiver_number = ? AND is_read = 0',
        { 'read', otherNumber, myNumber }
    )
    local senderSrc = GetSourceByPhone(otherNumber)
    if senderSrc then
        TriggerClientEvent('sb_phone:client:messagesRead', senderSrc, { readerNumber = myNumber })
    end
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:deleteMessage', function(source, cb, phoneNumber, messageId)
    if not phoneNumber or not messageId then cb(false) return end
    local affected = MySQL.update.await(
        'DELETE FROM phone_messages WHERE id = ? AND (sender_number = ? OR receiver_number = ?)',
        { messageId, phoneNumber, phoneNumber }
    )
    cb(affected and affected > 0)
end)

SB.Functions.CreateCallback('sb_phone:server:deleteConversation', function(source, cb, phoneNumber, otherNumber)
    if not phoneNumber or not otherNumber then cb(false) return end
    MySQL.update.await(
        'DELETE FROM phone_messages WHERE (sender_number = ? AND receiver_number = ?) OR (sender_number = ? AND receiver_number = ?)',
        { phoneNumber, otherNumber, otherNumber, phoneNumber }
    )
    cb(true)
end)

RegisterNetEvent('sb_phone:server:typing', function(senderNumber, receiverNumber, isTyping)
    local targetSrc = GetSourceByPhone(receiverNumber)
    if targetSrc then
        TriggerClientEvent('sb_phone:client:typingIndicator', targetSrc, {
            senderNumber = senderNumber, isTyping = isTyping
        })
    end
end)

-- ============================================================================
-- CALL HISTORY
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getCallHistory', function(source, cb, phoneNumber)
    local calls = MySQL.query.await(
        'SELECT id, caller_number, receiver_number, type, duration, created_at FROM phone_calls WHERE caller_number = ? OR receiver_number = ? ORDER BY created_at DESC LIMIT 50',
        { phoneNumber, phoneNumber }
    ) or {}
    cb(calls)
end)

SB.Functions.CreateCallback('sb_phone:server:clearCallHistory', function(source, cb, phoneNumber)
    MySQL.update.await('DELETE FROM phone_calls WHERE caller_number = ? OR receiver_number = ?', { phoneNumber, phoneNumber })
    cb(true)
end)

-- ============================================================================
-- BANK
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getBankData', function(source, cb, ownerCitizenid)
    local ownerPlayer = SB.Functions.GetPlayerByCitizenId(ownerCitizenid)
    if ownerPlayer then
        cb({ cash = ownerPlayer.PlayerData.money['cash'] or 0, bank = ownerPlayer.PlayerData.money['bank'] or 0 })
    else
        local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { ownerCitizenid })
        if result then
            local money = json.decode(result.money)
            cb({ cash = money.cash or 0, bank = money.bank or 0 })
        else
            cb({ cash = 0, bank = 0 })
        end
    end
end)

SB.Functions.CreateCallback('sb_phone:server:transferMoney', function(source, cb, ownerCitizenid, targetPhone, amount)
    amount = tonumber(amount) or 0
    if amount < Config.MinTransfer or amount > Config.MaxTransfer then cb({ success = false, message = 'Invalid amount' }) return end

    local ownerPlayer = SB.Functions.GetPlayerByCitizenId(ownerCitizenid)
    if not ownerPlayer then cb({ success = false, message = 'Account not found' }) return end

    local currentBank = ownerPlayer.PlayerData.money['bank'] or 0
    if currentBank < amount then cb({ success = false, message = 'Insufficient funds' }) return end

    local targetCid = GetCitizenidByPhone(targetPhone)
    if not targetCid then cb({ success = false, message = 'Recipient not found' }) return end
    if targetCid == ownerCitizenid then cb({ success = false, message = 'Cannot transfer to yourself' }) return end

    ownerPlayer.Functions.RemoveMoney('bank', amount, 'phone-transfer-out')

    local targetPlayer = SB.Functions.GetPlayerByCitizenId(targetCid)
    if targetPlayer then
        targetPlayer.Functions.AddMoney('bank', amount, 'phone-transfer-in')
        TriggerClientEvent('sb_notify:client:Notify', targetPlayer.PlayerData.source, 'Received $' .. amount .. ' transfer', 'success', 3000)
    else
        local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { targetCid })
        if result then
            local money = json.decode(result.money)
            money.bank = (money.bank or 0) + amount
            MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), targetCid })
        end
    end

    cb({
        success = true, message = 'Transfer complete',
        newBalance = {
            cash = ownerPlayer.PlayerData.money['cash'] or 0,
            bank = ownerPlayer.PlayerData.money['bank'] or 0
        }
    })
end)

-- ============================================================================
-- JOB
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getJobData', function(source, cb, ownerCitizenid)
    local ownerPlayer = SB.Functions.GetPlayerByCitizenId(ownerCitizenid)
    if ownerPlayer then
        local job = ownerPlayer.PlayerData.job or {}
        cb({
            title = job.label or 'Unemployed', rank = job.grade and job.grade.name or 'None',
            onDuty = job.onduty or false, badge = '#' .. tostring(math.random(1000, 9999)),
            department = job.label or ''
        })
    else
        cb({ title = 'Unemployed', rank = 'None', onDuty = false, badge = '', department = '' })
    end
end)

-- ============================================================================
-- SETTINGS
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:getSettings', function(source, cb, ownerCitizenid)
    local settings = MySQL.single.await('SELECT wallpaper, ringtone, airplane_mode, passkey FROM phone_settings WHERE owner_citizenid = ?', { ownerCitizenid })
    if not settings then
        MySQL.insert.await('INSERT IGNORE INTO phone_settings (owner_citizenid) VALUES (?)', { ownerCitizenid })
        settings = { wallpaper = 'default', ringtone = 'default', airplane_mode = 0, passkey = nil }
    end
    cb({
        wallpaper = settings.wallpaper or 'default', ringtone = settings.ringtone or 'default',
        airplaneMode = (settings.airplane_mode or 0) == 1,
        hasPasskey = settings.passkey ~= nil and settings.passkey ~= ''
    })
end)

SB.Functions.CreateCallback('sb_phone:server:saveSettings', function(source, cb, ownerCitizenid, settingsData)
    MySQL.update.await(
        'UPDATE phone_settings SET wallpaper = ?, ringtone = ?, airplane_mode = ? WHERE owner_citizenid = ?',
        { settingsData.wallpaper or 'default', settingsData.ringtone or 'default', settingsData.airplaneMode and 1 or 0, ownerCitizenid }
    )
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:verifyPasskey', function(source, cb, ownerCitizenid, enteredPin)
    local result = MySQL.single.await('SELECT passkey FROM phone_settings WHERE owner_citizenid = ?', { ownerCitizenid })
    if result and result.passkey then cb(result.passkey == enteredPin) else cb(true) end
end)

SB.Functions.CreateCallback('sb_phone:server:setPasskey', function(source, cb, ownerCitizenid, newPasskey)
    local pin = (newPasskey and newPasskey ~= '') and newPasskey or nil
    MySQL.update.await('UPDATE phone_settings SET passkey = ? WHERE owner_citizenid = ?', { pin, ownerCitizenid })
    cb(true)
end)

-- ============================================================================
-- GALLERY
-- ============================================================================

SB.Functions.CreateCallback('sb_phone:server:savePhoto', function(source, cb, ownerCitizenid, imageUrl)
    if not imageUrl or imageUrl == '' then cb(false) return end
    MySQL.insert.await('INSERT INTO phone_gallery (owner_citizenid, image_url) VALUES (?, ?)', { ownerCitizenid, imageUrl })
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:deletePhoto', function(source, cb, ownerCitizenid, photoId)
    if not photoId then cb(false) return end
    local affected = MySQL.update.await(
        'DELETE FROM phone_gallery WHERE id = ? AND owner_citizenid = ?',
        { photoId, ownerCitizenid }
    )
    cb(affected and affected > 0)
end)

SB.Functions.CreateCallback('sb_phone:server:getGallery', function(source, cb, ownerCitizenid)
    local gallery = MySQL.query.await(
        'SELECT id, image_url, created_at FROM phone_gallery WHERE owner_citizenid = ? ORDER BY created_at DESC',
        { ownerCitizenid }
    ) or {}
    cb(gallery)
end)

-- ============================================================================
-- INSTAPIC — Instagram Clone
-- ============================================================================

local function GetOrCreateProfile(citizenid, playerObj)
    local profile = MySQL.single.await('SELECT citizenid, username, bio FROM phone_social_profiles WHERE citizenid = ?', { citizenid })
    if not profile then
        local charinfo = playerObj and playerObj.PlayerData.charinfo or {}
        local uname = ((charinfo.firstname or 'user') .. '.' .. (charinfo.lastname or tostring(math.random(1000, 9999)))):lower():gsub('%s+', '')
        MySQL.insert.await('INSERT IGNORE INTO phone_social_profiles (citizenid, username, bio) VALUES (?, ?, ?)', { citizenid, uname, '' })
        profile = { citizenid = citizenid, username = uname, bio = '' }
    end
    return profile
end

local function GetProfileWithStats(citizenid, viewerCid)
    local profile = MySQL.single.await('SELECT citizenid, username, bio FROM phone_social_profiles WHERE citizenid = ?', { citizenid })
    if not profile then return nil end
    profile.follower_count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_follows WHERE following_citizenid = ?', { citizenid }) or 0
    profile.following_count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_follows WHERE follower_citizenid = ?', { citizenid }) or 0
    profile.post_count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_posts WHERE author_citizenid = ?', { citizenid }) or 0
    if viewerCid and viewerCid ~= citizenid then
        local f = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_follows WHERE follower_citizenid = ? AND following_citizenid = ?', { viewerCid, citizenid })
        profile.is_following = (f or 0) > 0
    end
    return profile
end

local function GetSourceByCitizenid(citizenid)
    local players = SB.Functions.GetPlayers()
    for _, src in ipairs(players) do
        local P = SB.Functions.GetPlayer(src)
        if P and P.PlayerData.citizenid == citizenid then return src end
    end
    return nil
end

-- PROFILE
SB.Functions.CreateCallback('sb_phone:server:getInstapicProfile', function(source, cb, targetCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    local viewerCid = Player.PlayerData.citizenid
    local target = targetCitizenid or viewerCid
    local profile = GetProfileWithStats(target, viewerCid)
    if not profile and target == viewerCid then
        GetOrCreateProfile(viewerCid, Player)
        profile = GetProfileWithStats(viewerCid, nil)
    end
    cb(profile)
end)

SB.Functions.CreateCallback('sb_phone:server:updateInstapicBio', function(source, cb, newBio)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    GetOrCreateProfile(cid, Player)
    MySQL.update.await('UPDATE phone_social_profiles SET bio = ? WHERE citizenid = ?', { (newBio or ''):sub(1, 300), cid })
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:searchInstapicUsers', function(source, cb, query)
    if not query or query == '' then cb({}) return end
    local results = MySQL.query.await(
        'SELECT citizenid, username, bio FROM phone_social_profiles WHERE username LIKE ? LIMIT 20',
        { '%' .. query .. '%' }
    ) or {}
    cb(results)
end)

-- FEED
SB.Functions.CreateCallback('sb_phone:server:getInstapicFeed', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local posts = MySQL.query.await([[
        SELECT p.id, p.author_citizenid, p.author_name, p.caption, p.image_url, p.image_gradient, p.location, p.comment_count, p.created_at,
               COUNT(l.id) as like_count,
               MAX(CASE WHEN l.citizenid = ? THEN 1 ELSE 0 END) as user_liked
        FROM phone_social_posts p
        LEFT JOIN phone_social_likes l ON l.post_id = p.id
        WHERE p.author_citizenid = ? OR p.author_citizenid IN (SELECT following_citizenid FROM phone_social_follows WHERE follower_citizenid = ?)
        GROUP BY p.id
        ORDER BY p.created_at DESC
        LIMIT 50
    ]], { cid, cid, cid }) or {}

    cb(posts)
end)

SB.Functions.CreateCallback('sb_phone:server:getInstapicExplore', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local posts = MySQL.query.await([[
        SELECT p.id, p.author_citizenid, p.author_name, p.caption, p.image_url, p.image_gradient, p.location, p.comment_count, p.created_at,
               COUNT(l.id) as like_count,
               MAX(CASE WHEN l.citizenid = ? THEN 1 ELSE 0 END) as user_liked
        FROM phone_social_posts p
        LEFT JOIN phone_social_likes l ON l.post_id = p.id
        WHERE p.author_citizenid != ? AND p.author_citizenid NOT IN (SELECT following_citizenid FROM phone_social_follows WHERE follower_citizenid = ?)
        GROUP BY p.id
        ORDER BY like_count DESC, p.created_at DESC
        LIMIT 50
    ]], { cid, cid, cid }) or {}

    cb(posts)
end)

-- POSTS
SB.Functions.CreateCallback('sb_phone:server:createInstapicPost', function(source, cb, caption, imageUrl, location)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    local cid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo or {}
    local authorName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')

    local gradients = {
        'linear-gradient(135deg, #1a1a2e, #16213e, #0f3460, #533483)',
        'linear-gradient(135deg, #2d3436, #000000)',
        'linear-gradient(135deg, #0f0c29, #302b63, #24243e)',
        'linear-gradient(135deg, #141e30, #243b55)',
        'linear-gradient(135deg, #1a1a2e, #e94560)',
        'linear-gradient(135deg, #f093fb, #f5576c)',
        'linear-gradient(135deg, #4facfe, #00f2fe)',
        'linear-gradient(135deg, #43e97b, #38f9d7)',
    }
    local gradient = gradients[math.random(#gradients)]

    local postId = MySQL.insert.await(
        'INSERT INTO phone_social_posts (author_citizenid, author_name, caption, image_url, image_gradient, location) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, authorName, caption or '', imageUrl, gradient, location }
    )

    if postId then
        cb({
            id = postId, author_citizenid = cid, author_name = authorName,
            caption = caption or '', image_url = imageUrl, image_gradient = gradient, location = location,
            like_count = 0, comment_count = 0, user_liked = 0,
            created_at = os.date('!%Y-%m-%dT%H:%M:%SZ')
        })
    else cb(nil) end
end)

SB.Functions.CreateCallback('sb_phone:server:deleteInstapicPost', function(source, cb, postId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    MySQL.update.await('DELETE FROM phone_social_comments WHERE post_id = ?', { postId })
    MySQL.update.await('DELETE FROM phone_social_likes WHERE post_id = ?', { postId })
    local affected = MySQL.update.await('DELETE FROM phone_social_posts WHERE id = ? AND author_citizenid = ?', { postId, cid })
    cb(affected and affected > 0)
end)

SB.Functions.CreateCallback('sb_phone:server:getInstapicUserPosts', function(source, cb, targetCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local posts = MySQL.query.await([[
        SELECT p.id, p.author_citizenid, p.author_name, p.caption, p.image_url, p.image_gradient, p.location, p.comment_count, p.created_at,
               COUNT(l.id) as like_count,
               MAX(CASE WHEN l.citizenid = ? THEN 1 ELSE 0 END) as user_liked
        FROM phone_social_posts p
        LEFT JOIN phone_social_likes l ON l.post_id = p.id
        WHERE p.author_citizenid = ?
        GROUP BY p.id
        ORDER BY p.created_at DESC
        LIMIT 50
    ]], { cid, targetCitizenid }) or {}

    cb(posts)
end)

-- LIKES
SB.Functions.CreateCallback('sb_phone:server:toggleInstapicLike', function(source, cb, postId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local existing = MySQL.single.await('SELECT id FROM phone_social_likes WHERE post_id = ? AND citizenid = ?', { postId, cid })
    if existing then
        MySQL.update.await('DELETE FROM phone_social_likes WHERE id = ?', { existing.id })
    else
        MySQL.insert.await('INSERT IGNORE INTO phone_social_likes (post_id, citizenid) VALUES (?, ?)', { postId, cid })
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_social_likes WHERE post_id = ?', { postId }) or 0
    cb({ liked = existing == nil, likeCount = count })
end)

-- COMMENTS
SB.Functions.CreateCallback('sb_phone:server:getInstapicComments', function(source, cb, postId)
    local comments = MySQL.query.await(
        'SELECT id, post_id, author_citizenid, author_name, content, created_at FROM phone_social_comments WHERE post_id = ? ORDER BY created_at ASC LIMIT 100',
        { postId }
    ) or {}
    cb(comments)
end)

SB.Functions.CreateCallback('sb_phone:server:addInstapicComment', function(source, cb, postId, content)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    if not content or content == '' then cb(nil) return end
    local cid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo or {}
    local authorName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')

    local commentId = MySQL.insert.await(
        'INSERT INTO phone_social_comments (post_id, author_citizenid, author_name, content) VALUES (?, ?, ?, ?)',
        { postId, cid, authorName, content:sub(1, 500) }
    )
    if commentId then
        MySQL.update.await('UPDATE phone_social_posts SET comment_count = comment_count + 1 WHERE id = ?', { postId })
        cb({ id = commentId, post_id = postId, author_citizenid = cid, author_name = authorName, content = content:sub(1, 500), created_at = os.date('!%Y-%m-%dT%H:%M:%SZ') })
    else cb(nil) end
end)

SB.Functions.CreateCallback('sb_phone:server:deleteInstapicComment', function(source, cb, commentId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local comment = MySQL.single.await('SELECT post_id FROM phone_social_comments WHERE id = ? AND author_citizenid = ?', { commentId, cid })
    if comment then
        MySQL.update.await('DELETE FROM phone_social_comments WHERE id = ?', { commentId })
        MySQL.update.await('UPDATE phone_social_posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = ?', { comment.post_id })
        cb(true)
    else cb(false) end
end)

-- FOLLOWS
SB.Functions.CreateCallback('sb_phone:server:toggleInstapicFollow', function(source, cb, targetCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid
    if cid == targetCitizenid then cb({ following = false }) return end

    local existing = MySQL.single.await('SELECT id FROM phone_social_follows WHERE follower_citizenid = ? AND following_citizenid = ?', { cid, targetCitizenid })
    if existing then
        MySQL.update.await('DELETE FROM phone_social_follows WHERE id = ?', { existing.id })
    else
        MySQL.insert.await('INSERT IGNORE INTO phone_social_follows (follower_citizenid, following_citizenid) VALUES (?, ?)', { cid, targetCitizenid })
    end

    cb({ following = existing == nil })
end)

SB.Functions.CreateCallback('sb_phone:server:getInstapicFollowers', function(source, cb, targetCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    local viewerCid = Player and Player.PlayerData.citizenid or ''
    local followers = MySQL.query.await([[
        SELECT p.citizenid, p.username, p.bio,
               MAX(CASE WHEN f2.id IS NOT NULL THEN 1 ELSE 0 END) as is_following
        FROM phone_social_follows f
        JOIN phone_social_profiles p ON p.citizenid = f.follower_citizenid
        LEFT JOIN phone_social_follows f2 ON f2.follower_citizenid = ? AND f2.following_citizenid = f.follower_citizenid
        WHERE f.following_citizenid = ?
        GROUP BY p.citizenid
    ]], { viewerCid, targetCitizenid }) or {}
    for _, u in ipairs(followers) do u.is_following = u.is_following == 1 end
    cb(followers)
end)

SB.Functions.CreateCallback('sb_phone:server:getInstapicFollowing', function(source, cb, targetCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    local viewerCid = Player and Player.PlayerData.citizenid or ''
    local following = MySQL.query.await([[
        SELECT p.citizenid, p.username, p.bio,
               MAX(CASE WHEN f2.id IS NOT NULL THEN 1 ELSE 0 END) as is_following
        FROM phone_social_follows f
        JOIN phone_social_profiles p ON p.citizenid = f.following_citizenid
        LEFT JOIN phone_social_follows f2 ON f2.follower_citizenid = ? AND f2.following_citizenid = f.following_citizenid
        WHERE f.follower_citizenid = ?
        GROUP BY p.citizenid
    ]], { viewerCid, targetCitizenid }) or {}
    for _, u in ipairs(following) do u.is_following = u.is_following == 1 end
    cb(following)
end)

-- STORIES
SB.Functions.CreateCallback('sb_phone:server:addInstapicStory', function(source, cb, color, imageUrl)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo or {}
    local authorName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or '')
    MySQL.insert.await(
        'INSERT INTO phone_social_stories (author_citizenid, author_name, color, image_url) VALUES (?, ?, ?, ?)',
        { cid, authorName, color or '#636366', imageUrl }
    )
    cb(true)
end)

SB.Functions.CreateCallback('sb_phone:server:getInstapicStories', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local stories = MySQL.query.await([[
        SELECT s.id, s.author_citizenid, s.author_name, s.color, s.image_url, s.created_at,
               MAX(CASE WHEN sv.viewer_citizenid = ? THEN 1 ELSE 0 END) as viewed
        FROM phone_social_stories s
        LEFT JOIN phone_social_story_views sv ON sv.story_id = s.id
        WHERE s.expires_at > NOW()
          AND (s.author_citizenid = ? OR s.author_citizenid IN (SELECT following_citizenid FROM phone_social_follows WHERE follower_citizenid = ?))
        GROUP BY s.id
        ORDER BY s.created_at DESC
    ]], { cid, cid, cid }) or {}

    -- Group by author
    local groups = {}
    local groupOrder = {}
    for _, s in ipairs(stories) do
        s.viewed = s.viewed == 1
        if not groups[s.author_citizenid] then
            groups[s.author_citizenid] = { author_citizenid = s.author_citizenid, author_name = s.author_name, stories = {}, has_unviewed = false }
            table.insert(groupOrder, s.author_citizenid)
        end
        table.insert(groups[s.author_citizenid].stories, s)
        if not s.viewed then groups[s.author_citizenid].has_unviewed = true end
    end

    local result = {}
    for _, acId in ipairs(groupOrder) do table.insert(result, groups[acId]) end
    cb(result)
end)

SB.Functions.CreateCallback('sb_phone:server:viewInstapicStory', function(source, cb, storyId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    MySQL.insert.await('INSERT IGNORE INTO phone_social_story_views (story_id, viewer_citizenid) VALUES (?, ?)', { storyId, cid })
    cb(true)
end)

-- DMs
SB.Functions.CreateCallback('sb_phone:server:getInstapicDMList', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local convos = MySQL.query.await([[
        SELECT
            CASE WHEN d.sender_citizenid = ? THEN d.receiver_citizenid ELSE d.sender_citizenid END as citizenid,
            p.username,
            d.message as last_message,
            d.created_at as last_message_at,
            SUM(CASE WHEN d.receiver_citizenid = ? AND d.is_read = 0 THEN 1 ELSE 0 END) as unread_count
        FROM phone_social_dms d
        JOIN phone_social_profiles p ON p.citizenid = CASE WHEN d.sender_citizenid = ? THEN d.receiver_citizenid ELSE d.sender_citizenid END
        WHERE d.sender_citizenid = ? OR d.receiver_citizenid = ?
        GROUP BY citizenid
        ORDER BY MAX(d.created_at) DESC
    ]], { cid, cid, cid, cid, cid }) or {}

    cb(convos)
end)

SB.Functions.CreateCallback('sb_phone:server:getInstapicDMChat', function(source, cb, otherCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local cid = Player.PlayerData.citizenid

    local messages = MySQL.query.await([[
        SELECT id, sender_citizenid, receiver_citizenid, message, is_read, created_at
        FROM phone_social_dms
        WHERE (sender_citizenid = ? AND receiver_citizenid = ?) OR (sender_citizenid = ? AND receiver_citizenid = ?)
        ORDER BY created_at ASC
        LIMIT 100
    ]], { cid, otherCitizenid, otherCitizenid, cid }) or {}

    cb(messages)
end)

SB.Functions.CreateCallback('sb_phone:server:sendInstapicDM', function(source, cb, receiverCitizenid, message)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    if not message or message == '' then cb(nil) return end
    local cid = Player.PlayerData.citizenid

    local profile = GetOrCreateProfile(cid, Player)

    local msgId = MySQL.insert.await(
        'INSERT INTO phone_social_dms (sender_citizenid, receiver_citizenid, message) VALUES (?, ?, ?)',
        { cid, receiverCitizenid, message:sub(1, 500) }
    )

    if msgId then
        local dm = { id = msgId, sender_citizenid = cid, receiver_citizenid = receiverCitizenid, message = message:sub(1, 500), is_read = 0, created_at = os.date('!%Y-%m-%dT%H:%M:%SZ') }
        -- Real-time push
        local targetSrc = GetSourceByCitizenid(receiverCitizenid)
        if targetSrc then
            TriggerClientEvent('sb_phone:client:instapicDM', targetSrc, { dm = dm, senderUsername = profile.username })
        end
        cb(dm)
    else cb(nil) end
end)

SB.Functions.CreateCallback('sb_phone:server:markInstapicDMsRead', function(source, cb, otherCitizenid)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    MySQL.update.await(
        'UPDATE phone_social_dms SET is_read = 1 WHERE sender_citizenid = ? AND receiver_citizenid = ? AND is_read = 0',
        { otherCitizenid, cid }
    )
    cb(true)
end)

-- ============================================================================
-- CALL EVENTS
-- ============================================================================

RegisterNetEvent('sb_phone:server:setAirplaneMode', function(enabled)
    playerAirplaneMode[source] = enabled == true
end)

RegisterNetEvent('sb_phone:server:initiateCall', function(callerNumber, receiverNumber)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if playerAirplaneMode[src] then
        TriggerClientEvent('sb_phone:client:callFailed', src, 'unavailable') return
    end
    if callerNumber == receiverNumber then
        TriggerClientEvent('sb_phone:client:callFailed', src, 'unavailable') return
    end
    if activeCalls[src] then
        TriggerClientEvent('sb_phone:client:callFailed', src, 'busy') return
    end
    for _, call in pairs(activeCalls) do
        if call.targetSource == src then
            TriggerClientEvent('sb_phone:client:callFailed', src, 'busy') return
        end
    end

    TriggerClientEvent('sb_phone:client:callRinging', src)

    if not receiverNumber or (
        not receiverNumber:match('^%(%d%d%d%) %d%d%d%-%d%d%d%d$') and
        not receiverNumber:match('^%d%d%d%-%d+$')
    ) then
        SetTimeout(3000, function() TriggerClientEvent('sb_phone:client:callFailed', src, 'invalid') end)
        return
    end

    local targetSrc = GetSourceByPhone(receiverNumber)

    if targetSrc and playerAirplaneMode[targetSrc] then
        SetTimeout(3000, function() TriggerClientEvent('sb_phone:client:callFailed', src, 'unavailable') end)
        MySQL.insert('INSERT INTO phone_calls (caller_number, receiver_number, type, duration) VALUES (?, ?, ?, ?)', { callerNumber, receiverNumber, 'missed', 0 })
        return
    end

    if not targetSrc then
        SetTimeout(3000, function() TriggerClientEvent('sb_phone:client:callFailed', src, 'unavailable') end)
        MySQL.insert('INSERT INTO phone_calls (caller_number, receiver_number, type, duration) VALUES (?, ?, ?, ?)', { callerNumber, receiverNumber, 'missed', 0 })
        return
    end

    local isBusy = false
    for _, call in pairs(activeCalls) do
        if call.targetSource == targetSrc then isBusy = true break end
    end
    if isBusy then
        SetTimeout(1000, function() TriggerClientEvent('sb_phone:client:callFailed', src, 'busy') end)
        return
    end

    local channel = src * 100 + targetSrc
    activeCalls[src] = {
        targetSource = targetSrc, channel = channel,
        callerNumber = callerNumber, receiverNumber = receiverNumber,
        startTime = os.time()
    }

    local targetPlayer = SB.Functions.GetPlayer(targetSrc)
    local callerName = callerNumber
    local targetRingtone = 'default'
    if targetPlayer then
        local targetCid = targetPlayer.PlayerData.citizenid
        local contact = MySQL.single.await('SELECT name FROM phone_contacts WHERE owner_citizenid = ? AND number = ?', { targetCid, callerNumber })
        if contact then callerName = contact.name end
        local settings = MySQL.single.await('SELECT ringtone FROM phone_settings WHERE owner_citizenid = ?', { targetCid })
        if settings and settings.ringtone then targetRingtone = settings.ringtone end
    end

    TriggerClientEvent('sb_phone:client:incomingCall', targetSrc, {
        callerSource = src, callerName = callerName, callerNumber = callerNumber,
        channel = channel, ringtone = targetRingtone
    })
end)

RegisterNetEvent('sb_phone:server:acceptCall', function(callerSource)
    local src = source
    local call = activeCalls[callerSource]
    if not call or call.targetSource ~= src then return end

    call.startTime = os.time()
    call.accepted = true

    TriggerClientEvent('sb_phone:client:callAccepted', callerSource, call.channel)
    TriggerClientEvent('sb_phone:client:callAccepted', src, call.channel)
end)

RegisterNetEvent('sb_phone:server:endCall', function()
    local src = source
    local call = activeCalls[src]
    local callerSrc = src

    if not call then
        for cSrc, c in pairs(activeCalls) do
            if c.targetSource == src then call = c callerSrc = cSrc break end
        end
    end

    if not call then return end

    local duration = 0
    if call.accepted then duration = os.time() - call.startTime end

    local callerType = 'outgoing'
    local receiverType = call.accepted and 'incoming' or 'missed'

    MySQL.insert('INSERT INTO phone_calls (caller_number, receiver_number, type, duration) VALUES (?, ?, ?, ?)', { call.callerNumber, call.receiverNumber, callerType, duration })
    MySQL.insert('INSERT INTO phone_calls (caller_number, receiver_number, type, duration) VALUES (?, ?, ?, ?)', { call.callerNumber, call.receiverNumber, receiverType, duration })

    TriggerClientEvent('sb_phone:client:callEnded', callerSrc)
    TriggerClientEvent('sb_phone:client:callEnded', call.targetSource)

    activeCalls[callerSrc] = nil
end)

RegisterNetEvent('sb_phone:server:declineCall', function(callerSource)
    local src = source
    local call = activeCalls[callerSource]
    if not call or call.targetSource ~= src then return end

    MySQL.insert('INSERT INTO phone_calls (caller_number, receiver_number, type, duration) VALUES (?, ?, ?, ?)', { call.callerNumber, call.receiverNumber, 'outgoing', 0 })
    MySQL.insert('INSERT INTO phone_calls (caller_number, receiver_number, type, duration) VALUES (?, ?, ?, ?)', { call.callerNumber, call.receiverNumber, 'missed', 0 })

    TriggerClientEvent('sb_phone:client:callDeclined', callerSource)
    activeCalls[callerSource] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerAirplaneMode[src] = nil

    local call = activeCalls[src]
    if call then
        TriggerClientEvent('sb_phone:client:callEnded', call.targetSource)
        activeCalls[src] = nil
        return
    end

    for callerSrc, c in pairs(activeCalls) do
        if c.targetSource == src then
            TriggerClientEvent('sb_phone:client:callEnded', callerSrc)
            activeCalls[callerSrc] = nil
            return
        end
    end
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetPlayerPhone(Player)
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.query.await(
        'SELECT phone_number FROM phone_serials WHERE owner_citizenid = ? LIMIT 1',
        { citizenid }
    )
    if result and result[1] and result[1].phone_number then
        return result[1].phone_number
    end
    return nil
end

-- ============================================================================
-- TEST COMMANDS (dev mode only — set sb_phone_devmode "true" in server.cfg)
-- ============================================================================

if GetConvar('sb_phone_devmode', 'false') == 'true' then
    RegisterCommand('testcall', function(source, args)
        local src = source
        if src == 0 then print('[sb_phone] Cannot use testcall from console') return end

        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Admin only command', 'error', 3000)
            return
        end

        local Player = SB.Functions.GetPlayer(src)
        if not Player then return end

        local myPhone = GetPlayerPhone(Player)
        if not myPhone then
            TriggerClientEvent('sb_notify:client:Notify', src, 'You need a phone first', 'error', 3000)
            return
        end

        local fakeName = args[1] or 'Test Caller'
        local fakeNumber = '(555) 999-0001'

        TriggerClientEvent('sb_phone:client:incomingCall', src, {
            callerSource = 0,
            callerName = fakeName,
            callerNumber = fakeNumber,
            channel = 0,
            ringtone = 'default'
        })

        print('^2[sb_phone]^7 Test call sent to player ' .. src)
    end, false)

    RegisterCommand('testmsg', function(source, args)
        local src = source
        if src == 0 then print('[sb_phone] Cannot use testmsg from console') return end

        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Admin only command', 'error', 3000)
            return
        end

        local Player = SB.Functions.GetPlayer(src)
        if not Player then return end

        local myPhone = GetPlayerPhone(Player)
        if not myPhone then
            TriggerClientEvent('sb_notify:client:Notify', src, 'You need a phone first', 'error', 3000)
            return
        end

        local msgText = table.concat(args, ' ')
        if msgText == '' then msgText = 'This is a test message from the system.' end

        local fakeNumber = '(555) 999-0001'
        local fakeName = 'Test Sender'

        MySQL.insert('INSERT INTO phone_messages (sender_number, receiver_number, message, is_read, created_at) VALUES (?, ?, ?, 0, NOW())',
            { fakeNumber, myPhone, msgText })

        TriggerClientEvent('sb_phone:client:newMessage', src, {
            senderNumber = fakeNumber,
            senderName = fakeName,
            message = msgText
        })

        exports['sb_notify']:Notify(src, 'Test message sent', 'success', 3000)
        print('^2[sb_phone]^7 Test message sent to player ' .. src)
    end, false)

    print('^3[sb_phone]^7 Dev mode enabled — test commands registered')
end

print('^2[sb_phone]^7 Server loaded')
