--[[
    Everyday Chaos RP - Shop System (Server)
    Author: Salah Eddine Boussettah

    Handles: Purchase validation, money handling, item giving
    Security: Operation locks, cooldowns, input sanitization
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- Build a lookup table for quick item validation
local ItemLookup = {}
for _, item in ipairs(Config.Items) do
    ItemLookup[item.name] = item
end

-- ============================================================================
-- ANTI-EXPLOIT: Operation lock + cooldown
-- ============================================================================

local operationLock = {}   -- [source] = true when processing
local purchaseCooldown = {} -- [source] = os.time() of last purchase

local COOLDOWN_SECONDS = 2
local MAX_CART_ITEMS = 10      -- Max unique items per purchase
local MAX_ITEM_AMOUNT = 50     -- Max quantity per item per purchase
local MAX_TOTAL_ITEMS = 100    -- Max total items per purchase

local function AcquireLock(src)
    if operationLock[src] then return false end
    operationLock[src] = true
    return true
end

local function ReleaseLock(src)
    operationLock[src] = nil
end

local function IsOnCooldown(src)
    local last = purchaseCooldown[src]
    if not last then return false end
    return (os.time() - last) < COOLDOWN_SECONDS
end

local function SetCooldown(src)
    purchaseCooldown[src] = os.time()
end

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    operationLock[src] = nil
    purchaseCooldown[src] = nil
end)

-- ============================================================================
-- CARRY LIMITS CALLBACK
-- ============================================================================

SB.Functions.CreateCallback('sb_shops:getCarryLimits', function(source, cb)
    local limits = {}
    for _, item in ipairs(Config.Items) do
        limits[item.name] = exports['sb_inventory']:GetCanCarryAmount(source, item.name)
    end
    cb(limits)
end)

-- ============================================================================
-- PURCHASE HANDLER
-- ============================================================================

RegisterNetEvent('sb_shops:server:purchase', function(cart)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Anti-exploit: operation lock
    if not AcquireLock(src) then
        SB.Functions.Notify(src, 'Transaction in progress...', 'error', 2000)
        return
    end

    -- Anti-exploit: cooldown
    if IsOnCooldown(src) then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Please wait before buying again.', 'error', 2000)
        return
    end

    -- Validate cart type and size
    if type(cart) ~= 'table' or #cart == 0 then
        ReleaseLock(src)
        return
    end

    if #cart > MAX_CART_ITEMS then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Too many items in cart!', 'error', 3000)
        TriggerClientEvent('sb_shops:client:purchaseResult', src, false)
        return
    end

    -- Calculate total and validate items
    local total = 0
    local totalAmount = 0
    local validItems = {}
    local seenItems = {} -- Prevent duplicate entries for same item

    for _, cartItem in ipairs(cart) do
        if type(cartItem) ~= 'table' then
            ReleaseLock(src)
            return
        end

        local itemName = cartItem.name
        local amount = tonumber(cartItem.amount)

        -- Type checks
        if type(itemName) ~= 'string' then
            ReleaseLock(src)
            return
        end

        -- Amount validation (integer, positive, within limit)
        if not amount or amount <= 0 or amount > MAX_ITEM_AMOUNT then
            ReleaseLock(src)
            return
        end
        amount = math.floor(amount) -- Force integer

        -- Prevent duplicate item entries in cart
        if seenItems[itemName] then
            ReleaseLock(src)
            return
        end
        seenItems[itemName] = true

        -- Validate item exists in shop
        local shopItem = ItemLookup[itemName]
        if not shopItem then
            ReleaseLock(src)
            SB.Functions.Notify(src, 'Invalid item in cart', 'error', 3000)
            TriggerClientEvent('sb_shops:client:purchaseResult', src, false)
            return
        end

        totalAmount = totalAmount + amount
        if totalAmount > MAX_TOTAL_ITEMS then
            ReleaseLock(src)
            SB.Functions.Notify(src, 'Too many items! Max ' .. MAX_TOTAL_ITEMS .. ' per purchase.', 'error', 3000)
            TriggerClientEvent('sb_shops:client:purchaseResult', src, false)
            return
        end

        total = total + (shopItem.price * amount)
        validItems[#validItems + 1] = { name = itemName, amount = amount, price = shopItem.price }
    end

    if total <= 0 then
        ReleaseLock(src)
        return
    end

    -- Check carry capacity for each item before purchase
    for _, item in ipairs(validItems) do
        local canCarry = exports['sb_inventory']:GetCanCarryAmount(src, item.name)
        if canCarry < item.amount then
            local itemLabel = item.name:gsub('_', ' '):gsub('^%l', string.upper)
            if canCarry <= 0 then
                SB.Functions.Notify(src, 'Can\'t carry any more ' .. itemLabel .. '!', 'error', 4000)
            else
                SB.Functions.Notify(src, 'Can only carry ' .. canCarry .. ' more ' .. itemLabel .. '!', 'error', 4000)
            end
            ReleaseLock(src)
            TriggerClientEvent('sb_shops:client:purchaseResult', src, false)
            return
        end
    end

    -- Check if player can afford it (cash first, then bank)
    local cash = Player.PlayerData.money.cash
    local bank = Player.PlayerData.money.bank
    local payMethod = nil

    if cash >= total then
        payMethod = 'cash'
    elseif bank >= total then
        payMethod = 'bank'
    else
        SB.Functions.Notify(src, 'Not enough money! Need $' .. total, 'error', 4000)
        ReleaseLock(src)
        TriggerClientEvent('sb_shops:client:purchaseResult', src, false)
        return
    end

    -- Add items to inventory (AddItem handles multi-slot distribution)
    local addedItems = {}
    local allAdded = true

    for _, item in ipairs(validItems) do
        -- Generate serial number for phone items
        local metadata = nil
        if item.name == 'phone' then
            metadata = {
                serial = 'SB-' .. string.format('%04X', math.random(0, 65535)) .. '-' .. string.format('%04X', math.random(0, 65535)) .. '-' .. string.format('%04X', math.random(0, 65535))
            }
        end
        local success = exports['sb_inventory']:AddItem(src, item.name, item.amount, metadata, nil, true)
        if success then
            addedItems[#addedItems + 1] = item
        else
            allAdded = false
            break
        end
    end

    if not allAdded then
        for _, item in ipairs(addedItems) do
            exports['sb_inventory']:RemoveItem(src, item.name, item.amount)
        end
        SB.Functions.Notify(src, 'Not enough inventory space!', 'error', 4000)
        ReleaseLock(src)
        TriggerClientEvent('sb_shops:client:purchaseResult', src, false)
        return
    end

    -- Calculate expected balances after deduction
    local newCash = cash
    local newBank = bank
    if payMethod == 'cash' then
        newCash = cash - total
    else
        newBank = bank - total
    end

    -- Remove money
    Player.Functions.RemoveMoney(payMethod, total)

    -- Log bank transaction if paid from bank
    if payMethod == 'bank' then
        local citizenid = Player.PlayerData.citizenid
        local balanceAfter = Player.Functions.GetMoney('bank')
        local itemCount = #validItems
        local description = 'Store Purchase - ' .. itemCount .. ' item(s)'
        exports['sb_banking']:LogPurchase(citizenid, total, balanceAfter, description)
    end

    -- Set cooldown and release lock
    SetCooldown(src)
    ReleaseLock(src)

    SB.Functions.Notify(src, ('Purchased for $%d (%s)'):format(total, payMethod), 'success', 4000)
    TriggerClientEvent('sb_shops:client:purchaseResult', src, true, newCash, newBank)
end)
