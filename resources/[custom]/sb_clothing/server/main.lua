--[[
    Everyday Chaos RP - Clothing Store System (Server)
    Author: Salah Eddine Boussettah

    Handles: Purchase processing, appearance saving, outfits management
]]

local SB = exports['sb_core']:GetCoreObject()

-- Operation lock to prevent double processing
local operationLocks = {}

-- Store reservation system (only one player per changing spot)
local storeReservations = {} -- [storeIndex] = playerId

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- ============================================================================
-- STORE RESERVATION SYSTEM
-- ============================================================================

SB.Functions.CreateCallback('sb_clothing:checkStoreAvailable', function(source, cb, storeIndex)
    local currentUser = storeReservations[storeIndex]
    if currentUser and currentUser ~= source then
        -- Store is occupied by another player
        cb(false, currentUser)
    else
        cb(true, nil)
    end
end)

SB.Functions.CreateCallback('sb_clothing:reserveStore', function(source, cb, storeIndex)
    local currentUser = storeReservations[storeIndex]
    if currentUser and currentUser ~= source then
        -- Already occupied
        cb(false)
    else
        -- Reserve for this player
        storeReservations[storeIndex] = source
        cb(true)
    end
end)

RegisterServerEvent('sb_clothing:server:releaseStore')
AddEventHandler('sb_clothing:server:releaseStore', function(storeIndex)
    local src = source
    -- Only release if this player owns the reservation
    if storeReservations[storeIndex] == src then
        storeReservations[storeIndex] = nil
    end
end)

-- ============================================================================
-- SAVED OUTFITS CALLBACKS
-- ============================================================================

SB.Functions.CreateCallback('sb_clothing:getSavedOutfits', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local metadata = Player.PlayerData.metadata or {}
    local outfits = metadata.savedOutfits or {}
    cb(outfits)
end)

SB.Functions.CreateCallback('sb_clothing:getOwnedClothing', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local metadata = Player.PlayerData.metadata or {}
    local ownedClothing = metadata.ownedClothing or {}
    cb(ownedClothing)
end)

-- ============================================================================
-- PURCHASE PROCESSING
-- ============================================================================

RegisterServerEvent('sb_clothing:server:purchase')
AddEventHandler('sb_clothing:server:purchase', function(items, storeType)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Check operation lock
    if operationLocks[citizenid] then
        SB.Functions.Notify(src, 'Please wait...', 'error')
        return
    end
    operationLocks[citizenid] = true

    -- Validate items
    if not items or #items == 0 then
        operationLocks[citizenid] = nil
        return
    end

    -- Calculate total with price multiplier (skip free components)
    local multiplier = Config.PriceMultiplier[storeType] or 1.0
    local total = 0
    local paidItems = {} -- Items that cost money

    for _, item in ipairs(items) do
        local basePrice = 100 -- Default
        local isFree = false

        if item.type == 'component' then
            -- Check if this component is free
            if Config.FreeComponents and Config.FreeComponents[item.id] then
                isFree = true
            else
                basePrice = Config.BasePrices[item.id] or 100
            end
        elseif item.type == 'prop' then
            -- "None" option (drawable = -1) is always free
            if item.drawable < 0 then
                isFree = true
            else
                basePrice = Config.BasePrices['prop_' .. item.id] or 100
            end
        end

        if not isFree then
            total = total + math.floor(basePrice * multiplier)
            paidItems[#paidItems + 1] = item
        end
    end

    -- If total > 0, need to pay
    local payMethod = 'free'
    if total > 0 then
        -- Check money (cash first, then bank)
        local cash = Player.PlayerData.money.cash or 0
        local bank = Player.PlayerData.money.bank or 0

        if cash >= total then
            payMethod = 'cash'
        elseif bank >= total then
            payMethod = 'bank'
        else
            SB.Functions.Notify(src, 'Not enough money! Need $' .. total, 'error')
            TriggerClientEvent('sb_clothing:client:purchaseResult', src, false)
            operationLocks[citizenid] = nil
            return
        end

        -- Remove money
        local removed = Player.Functions.RemoveMoney(payMethod, total, 'clothing-purchase')
        if not removed then
            SB.Functions.Notify(src, 'Payment failed!', 'error')
            TriggerClientEvent('sb_clothing:client:purchaseResult', src, false)
            operationLocks[citizenid] = nil
            return
        end

        -- Log bank transaction if paid from bank
        if payMethod == 'bank' then
            local balanceAfter = Player.Functions.GetMoney('bank')
            local storeLabel = storeType:gsub('^%l', string.upper) -- Capitalize first letter
            exports['sb_banking']:LogPurchase(citizenid, total, balanceAfter, 'Clothing Purchase - ' .. storeLabel)
        end
    end

    -- Track purchased items in owned clothing (only paid items, not free torso changes)
    if #paidItems > 0 then
        local metadata = Player.PlayerData.metadata or {}
        local ownedClothing = metadata.ownedClothing or {}

        for _, item in ipairs(paidItems) do
            -- Create unique key: type_id_drawable_texture
            local key = string.format('%s_%d_%d_%d', item.type, item.id, item.drawable, item.texture)
            if not ownedClothing[key] then
                ownedClothing[key] = {
                    type = item.type,
                    id = item.id,
                    drawable = item.drawable,
                    texture = item.texture,
                    purchasedAt = os.time()
                }
            end
        end

        Player.Functions.SetMetaData('ownedClothing', ownedClothing)

        -- Send updated owned clothing to client
        TriggerClientEvent('sb_clothing:client:updateOwnedClothing', src, ownedClothing)
    end

    -- Success - client already has the clothing applied
    TriggerClientEvent('sb_clothing:client:purchaseResult', src, true, payMethod, total)
    operationLocks[citizenid] = nil
end)

-- ============================================================================
-- SAVE APPEARANCE
-- ============================================================================

RegisterServerEvent('sb_clothing:server:saveAppearance')
AddEventHandler('sb_clothing:server:saveAppearance', function(appearance)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if not appearance then return end

    local citizenid = Player.PlayerData.citizenid

    -- Get current skin data and merge with new clothing
    local currentSkin = Player.PlayerData.skin or {}

    -- Merge components
    if appearance.components then
        currentSkin.components = currentSkin.components or {}
        for compId, data in pairs(appearance.components) do
            currentSkin.components[compId] = data
        end
    end

    -- Merge props
    if appearance.props then
        currentSkin.props = currentSkin.props or {}
        for propId, data in pairs(appearance.props) do
            currentSkin.props[propId] = data
        end
    end

    -- Save to database
    MySQL.update('UPDATE players SET skin = ? WHERE citizenid = ?', {
        json.encode(currentSkin),
        citizenid
    })

    -- Update player data in memory
    Player.Functions.SetPlayerData('skin', currentSkin)
end)

-- ============================================================================
-- SAVED OUTFITS
-- ============================================================================

RegisterServerEvent('sb_clothing:server:saveOutfit')
AddEventHandler('sb_clothing:server:saveOutfit', function(outfitName, appearance)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if not outfitName or outfitName == '' then
        SB.Functions.Notify(src, 'Please enter an outfit name', 'error')
        TriggerClientEvent('sb_clothing:client:outfitSaved', src, false)
        return
    end

    if not appearance then
        TriggerClientEvent('sb_clothing:client:outfitSaved', src, false)
        return
    end

    local metadata = Player.PlayerData.metadata or {}
    local outfits = metadata.savedOutfits or {}

    -- Check max outfits
    if #outfits >= Config.MaxSavedOutfits then
        SB.Functions.Notify(src, 'Maximum outfits reached! Delete one first.', 'error')
        TriggerClientEvent('sb_clothing:client:outfitSaved', src, false)
        return
    end

    -- Add new outfit
    outfits[#outfits + 1] = {
        name = outfitName,
        appearance = appearance,
        savedAt = os.time()
    }

    -- Update metadata
    metadata.savedOutfits = outfits
    Player.Functions.SetMetaData('savedOutfits', outfits)

    TriggerClientEvent('sb_clothing:client:outfitSaved', src, true, outfits)
end)

RegisterServerEvent('sb_clothing:server:deleteOutfit')
AddEventHandler('sb_clothing:server:deleteOutfit', function(index)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local metadata = Player.PlayerData.metadata or {}
    local outfits = metadata.savedOutfits or {}

    if index < 1 or index > #outfits then
        TriggerClientEvent('sb_clothing:client:outfitDeleted', src, false)
        return
    end

    -- Remove outfit at index
    table.remove(outfits, index)

    -- Update metadata
    metadata.savedOutfits = outfits
    Player.Functions.SetMetaData('savedOutfits', outfits)

    TriggerClientEvent('sb_clothing:client:outfitDeleted', src, true, outfits)
end)

-- ============================================================================
-- CLEANUP ON DISCONNECT
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        operationLocks[citizenid] = nil
    end

    -- Release any store reservations held by this player
    for storeIndex, playerId in pairs(storeReservations) do
        if playerId == src then
            storeReservations[storeIndex] = nil
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetPlayerOutfits', function(citizenid)
    local result = MySQL.query.await('SELECT metadata FROM players WHERE citizenid = ?', { citizenid })
    if result and result[1] then
        local metadata = json.decode(result[1].metadata) or {}
        return metadata.savedOutfits or {}
    end
    return {}
end)

print('^2[sb_clothing]^7 Clothing store system loaded')
