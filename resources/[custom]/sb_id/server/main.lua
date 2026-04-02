local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- HELPERS
-- ============================================================================

function IsIDExpiredServer(expiryDateStr)
    if not expiryDateStr then return true end
    local month, day, year = expiryDateStr:match('(%d+)/(%d+)/(%d+)')
    if not month then return true end
    local expiryTime = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 23, min = 59, sec = 59 })
    return os.time() > expiryTime
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Returns: { hasID = bool, canAfford = bool }
SB.Functions.CreateCallback('sb_id:server:checkStatus', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({ hasID = false, canAfford = false }) return end

    local hasID = exports['sb_inventory']:HasItem(source, 'id_card', 1)
    local cash = Player.PlayerData.money['cash'] or 0
    local canAfford = cash >= Config.IDCost

    cb({ hasID = hasID, canAfford = canAfford })
end)

-- ============================================================================
-- ITEM USAGE HANDLER (listens to sb_inventory)
-- ============================================================================

AddEventHandler('sb_inventory:server:itemUsed', function(source, itemName, amount, metadata, category)
    if itemName ~= 'id_card' then return end

    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    if not metadata then
        TriggerClientEvent('sb_notify', source, 'This ID card is damaged', 'error', 3000)
        return
    end

    local expired = IsIDExpiredServer(metadata.expiryDate)

    -- Show to self
    TriggerClientEvent('sb_id:client:viewID', source, metadata, expired)

    -- Also show to nearby players
    local srcPed = GetPlayerPed(source)
    if srcPed and srcPed ~= 0 then
        local srcCoords = GetEntityCoords(srcPed)
        local players = GetPlayers()
        local shownToSomeone = false
        for _, targetId in ipairs(players) do
            local tid = tonumber(targetId)
            if tid and tid ~= source then
                local tPed = GetPlayerPed(tid)
                if tPed and tPed ~= 0 then
                    local tCoords = GetEntityCoords(tPed)
                    if #(srcCoords - tCoords) <= Config.ShowDistance then
                        TriggerClientEvent('sb_id:client:receiveShownID', tid, metadata, expired)
                        shownToSomeone = true
                    end
                end
            end
        end
        if shownToSomeone then
            TriggerClientEvent('sb_notify', source, 'You showed your ID', 'success', 3000)
        end
    end
end)

-- ============================================================================
-- ID REQUEST (from City Hall NPC)
-- ============================================================================

RegisterNetEvent('sb_id:server:requestID', function(address, mugshot, characteristics, cardTheme)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Validate address
    if not address or type(address) ~= 'string' or #address < 3 or #address > 100 then
        TriggerClientEvent('sb_notify', src, 'Please enter a valid address', 'error', 3000)
        return
    end

    -- Sanitize address input
    address = address:gsub('[<>"\']', '')

    -- Sanitize characteristics
    local chars = type(characteristics) == 'table' and characteristics or {}

    -- Purge any existing ID cards for this citizen (dropped, in other inventories, etc.)
    local citizenid = Player.PlayerData.citizenid
    exports['sb_inventory']:PurgeItemGlobal('id_card', 'citizenid', citizenid)

    -- Check money
    local playerMoney = Player.PlayerData.money['cash']
    if playerMoney < Config.IDCost then
        TriggerClientEvent('sb_notify', src, 'Not enough cash. ID costs $' .. Config.IDCost, 'error', 3000)
        return
    end

    -- Deduct money
    Player.Functions.RemoveMoney('cash', Config.IDCost, 'id-card-purchase')

    -- Build metadata
    local charinfo = Player.PlayerData.charinfo
    local metadata_table = Player.PlayerData.metadata or {}
    local now = os.time()

    local ownerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Unknown')

    local idMetadata = {
        firstname   = charinfo.firstname or 'Unknown',
        lastname    = charinfo.lastname or 'Unknown',
        citizenid   = Player.PlayerData.citizenid,
        dob         = charinfo.birthdate or '01/01/2000',
        gender      = charinfo.gender or 'Male',
        sex         = chars.sex or 'M',
        hair        = chars.hair or 'BRN',
        eyes        = chars.eyes or 'BRN',
        height      = chars.height or "5'10\"",
        weight      = chars.weight or '175 lb',
        bloodtype   = metadata_table.bloodtype or 'Unknown',
        nationality = charinfo.nationality or 'American',
        address     = address,
        issueDate   = os.date('%m/%d/%Y', now),
        expiryDate  = os.date('%m/%d/%Y', now + (Config.ExpiryDays * 86400)),
        mugshot     = mugshot or '',
        ownerName   = ownerName,
        cardTheme   = cardTheme or 'white'
    }

    -- Add item with metadata
    local success = exports['sb_inventory']:AddItem(src, 'id_card', 1, idMetadata, nil, true)

    if success then
        TriggerClientEvent('sb_notify', src, 'ID Card issued successfully', 'success', 3000)
    else
        -- Refund if adding item failed
        Player.Functions.AddMoney('cash', Config.IDCost, 'id-card-refund')
        TriggerClientEvent('sb_notify', src, 'Failed to issue ID card', 'error', 3000)
    end
end)

-- ============================================================================
-- RENEW ID (replace expired card)
-- ============================================================================

RegisterNetEvent('sb_id:server:renewID', function(address, mugshot, characteristics, cardTheme)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Validate address
    if not address or type(address) ~= 'string' or #address < 3 or #address > 100 then
        TriggerClientEvent('sb_notify', src, 'Please enter a valid address', 'error', 3000)
        return
    end

    address = address:gsub('[<>"\']', '')

    -- Sanitize characteristics
    local chars = type(characteristics) == 'table' and characteristics or {}

    -- Check money
    local playerMoney = Player.PlayerData.money['cash']
    if playerMoney < Config.IDCost then
        TriggerClientEvent('sb_notify', src, 'Not enough cash. ID renewal costs $' .. Config.IDCost, 'error', 3000)
        return
    end

    -- Purge all existing ID cards for this citizen
    local citizenid = Player.PlayerData.citizenid
    exports['sb_inventory']:PurgeItemGlobal('id_card', 'citizenid', citizenid)

    -- Deduct money
    Player.Functions.RemoveMoney('cash', Config.IDCost, 'id-card-renewal')

    -- Build new metadata
    local charinfo = Player.PlayerData.charinfo
    local metadata_table = Player.PlayerData.metadata or {}
    local now = os.time()
    local ownerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Unknown')

    local idMetadata = {
        firstname   = charinfo.firstname or 'Unknown',
        lastname    = charinfo.lastname or 'Unknown',
        citizenid   = Player.PlayerData.citizenid,
        dob         = charinfo.birthdate or '01/01/2000',
        gender      = charinfo.gender or 'Male',
        sex         = chars.sex or 'M',
        hair        = chars.hair or 'BRN',
        eyes        = chars.eyes or 'BRN',
        height      = chars.height or "5'10\"",
        weight      = chars.weight or '175 lb',
        bloodtype   = metadata_table.bloodtype or 'Unknown',
        nationality = charinfo.nationality or 'American',
        address     = address,
        issueDate   = os.date('%m/%d/%Y', now),
        expiryDate  = os.date('%m/%d/%Y', now + (Config.ExpiryDays * 86400)),
        mugshot     = mugshot or '',
        ownerName   = ownerName,
        cardTheme   = cardTheme or 'white'
    }

    local success = exports['sb_inventory']:AddItem(src, 'id_card', 1, idMetadata, nil, true)

    if success then
        TriggerClientEvent('sb_notify', src, 'ID Card renewed successfully', 'success', 3000)
    else
        Player.Functions.AddMoney('cash', Config.IDCost, 'id-card-renewal-refund')
        TriggerClientEvent('sb_notify', src, 'Failed to renew ID card', 'error', 3000)
    end
end)

-- ============================================================================
-- SHOW ID TO NEARBY PLAYER
-- ============================================================================

RegisterNetEvent('sb_id:server:showIDToPlayer', function(targetServerId)
    local src = source
    if not targetServerId then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local TargetPlayer = SB.Functions.GetPlayer(targetServerId)
    if not TargetPlayer then
        TriggerClientEvent('sb_notify', src, 'Player not found', 'error', 3000)
        return
    end

    -- Fetch actual ID card data from inventory (server-authoritative)
    local idCards = exports['sb_inventory']:GetItemsByName(src, 'id_card')
    if not idCards or #idCards == 0 then
        TriggerClientEvent('sb_notify', src, 'You don\'t have an ID card', 'error', 3000)
        return
    end

    local idData = idCards[1].metadata
    if not idData or not idData.citizenid then
        TriggerClientEvent('sb_notify', src, 'Your ID card is damaged', 'error', 3000)
        return
    end

    -- Send to target
    local expired = IsIDExpiredServer(idData.expiryDate)
    TriggerClientEvent('sb_id:client:receiveShownID', targetServerId, idData, expired)

    -- Notify sender
    TriggerClientEvent('sb_notify', src, 'You showed your ID', 'success', 3000)
end)
