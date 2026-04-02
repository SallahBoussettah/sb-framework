--[[
    Everyday Chaos RP - Burger Shot (Server)
    Author: Salah Eddine Boussettah

    Handles: Crafting validation, supply purchases, counter stash, anti-exploit
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- ANTI-EXPLOIT
-- ============================================================================

local operationLock = {}
local operationCooldown = {}
local COOLDOWN_SECONDS = 2

local function AcquireLock(src)
    if operationLock[src] then return false end
    operationLock[src] = true
    return true
end

local function ReleaseLock(src)
    operationLock[src] = nil
end

local function IsOnCooldown(src)
    local last = operationCooldown[src]
    if not last then return false end
    return (os.time() - last) < COOLDOWN_SECONDS
end

local function SetCooldown(src)
    operationCooldown[src] = os.time()
end

AddEventHandler('playerDropped', function()
    local src = source
    operationLock[src] = nil
    operationCooldown[src] = nil
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

-- Build station lookup from config
local StationLookup = {}
for _, station in ipairs(Config.Stations) do
    StationLookup[station.id] = station
end

-- Build supply item lookup
local SupplyLookup = {}
for _, item in ipairs(Config.SupplyFridge.items) do
    SupplyLookup[item.name] = item
end

-- Item labels for counter display
local ItemLabels = {
    ['bs_fries']  = 'Fries',
    ['bs_burger'] = 'Bleeder Burger',
    ['bs_cola']   = 'eCola',
    ['bs_meal']   = 'Murder Meal Box',
}

-- Validate player has the burgershot job and is on duty
local function ValidateEmployee(src)
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return false end
    local job = Player.PlayerData.job
    if not job or job.name ~= Config.Job then return false end
    if not job.onduty then return false end
    return true, Player
end

-- Distance check between player and coords
local function IsNearCoords(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pedCoords = GetEntityCoords(ped)
    local dist = #(pedCoords - coords)
    return dist <= (maxDist or 15.0)
end

-- ============================================================================
-- COUNTER STOCK (Server-side stash)
-- ============================================================================

local CounterStock = {}  -- { ['bs_burger'] = 3, ['bs_fries'] = 5, ... }

local function SyncCounterStock(targetSrc)
    if targetSrc then
        TriggerClientEvent('sb_burgershot:client:syncStock', targetSrc, CounterStock)
    else
        TriggerClientEvent('sb_burgershot:client:syncStock', -1, CounterStock)
    end
end

-- Sync stock to player on login
RegisterNetEvent('SB:Server:OnPlayerLoaded', function()
    local src = source
    SyncCounterStock(src)
end)

-- ============================================================================
-- CLOCK IN / OUT
-- ============================================================================

RegisterNetEvent('sb_burgershot:server:toggleDuty', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.PlayerData.job
    if not job or job.name ~= Config.Job then
        SB.Functions.Notify(src, 'You don\'t work here!', 'error', 3000)
        return
    end

    local newDuty = not job.onduty
    Player.Functions.SetJobDuty(newDuty)

    if newDuty then
        SB.Functions.Notify(src, 'Clocked in! Welcome to Burger Shot.', 'success', 3000)
    else
        SB.Functions.Notify(src, 'Clocked out. See you next shift!', 'info', 3000)
    end
end)

-- ============================================================================
-- COOKING CALLBACKS & EVENTS
-- ============================================================================

-- Check if player can cook (has required ingredients)
SB.Functions.CreateCallback('sb_burgershot:canCook', function(source, cb, stationId)
    local src = source
    if not ValidateEmployee(src) then
        cb(false)
        return
    end

    local station = StationLookup[stationId]
    if not station then
        cb(false)
        return
    end

    -- Check distance to station
    if not IsNearCoords(src, station.coords, 5.0) then
        cb(false)
        return
    end

    -- Check all required ingredients
    local recipe = station.recipe
    for _, input in ipairs(recipe.inputs) do
        local hasItem = exports['sb_inventory']:HasItem(src, input.name, input.amount)
        if not hasItem then
            cb(false)
            return
        end
    end

    cb(true)
end)

-- Finish cooking: remove ingredients, give output
RegisterNetEvent('sb_burgershot:server:finishCooking', function(stationId)
    local src = source

    if not AcquireLock(src) then
        SB.Functions.Notify(src, 'Already processing...', 'error', 2000)
        return
    end

    if IsOnCooldown(src) then
        ReleaseLock(src)
        return
    end

    local valid, Player = ValidateEmployee(src)
    if not valid then
        ReleaseLock(src)
        return
    end

    local station = StationLookup[stationId]
    if not station then
        ReleaseLock(src)
        return
    end

    -- Distance check
    if not IsNearCoords(src, station.coords, 5.0) then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Too far from the station!', 'error', 2000)
        return
    end

    local recipe = station.recipe

    -- Re-validate ingredients (prevent race conditions)
    for _, input in ipairs(recipe.inputs) do
        local hasItem = exports['sb_inventory']:HasItem(src, input.name, input.amount)
        if not hasItem then
            ReleaseLock(src)
            SB.Functions.Notify(src, 'Missing ingredients!', 'error', 3000)
            return
        end
    end

    -- Remove ingredients
    for _, input in ipairs(recipe.inputs) do
        exports['sb_inventory']:RemoveItem(src, input.name, input.amount)
    end

    -- Give output
    local success = exports['sb_inventory']:AddItem(src, recipe.output.name, recipe.output.amount, nil, nil, true)
    if success then
        SB.Functions.Notify(src, 'Prepared: ' .. (ItemLabels[recipe.output.name] or recipe.output.name), 'success', 3000)
    else
        -- Refund ingredients if can't add output
        for _, input in ipairs(recipe.inputs) do
            exports['sb_inventory']:AddItem(src, input.name, input.amount)
        end
        SB.Functions.Notify(src, 'Not enough inventory space!', 'error', 3000)
    end

    SetCooldown(src)
    ReleaseLock(src)
end)

-- ============================================================================
-- SUPPLY FRIDGE (Cart-based NUI purchase)
-- ============================================================================

local MAX_SUPPLY_ITEMS = 10       -- Max unique items per purchase
local MAX_SUPPLY_AMOUNT = 20      -- Max quantity per item
local MAX_SUPPLY_TOTAL = 50       -- Max total items per purchase

RegisterNetEvent('sb_burgershot:server:buySupplies', function(cart)
    local src = source

    if not AcquireLock(src) then
        SB.Functions.Notify(src, 'Already processing...', 'error', 2000)
        return
    end

    if IsOnCooldown(src) then
        ReleaseLock(src)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    local valid, Player = ValidateEmployee(src)
    if not valid then
        ReleaseLock(src)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    -- Validate cart type and size
    if type(cart) ~= 'table' or #cart == 0 then
        ReleaseLock(src)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    if #cart > MAX_SUPPLY_ITEMS then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Too many items!', 'error', 3000)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    -- Distance check
    if not IsNearCoords(src, Config.SupplyFridge.coords, 5.0) then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Too far from the fridge!', 'error', 2000)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    -- Validate items and calculate total
    local total = 0
    local totalAmount = 0
    local validItems = {}
    local seenItems = {}

    for _, cartItem in ipairs(cart) do
        if type(cartItem) ~= 'table' then
            ReleaseLock(src)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end

        local itemName = cartItem.name
        local amount = tonumber(cartItem.amount)

        if type(itemName) ~= 'string' then
            ReleaseLock(src)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end

        if not amount or amount <= 0 or amount > MAX_SUPPLY_AMOUNT then
            ReleaseLock(src)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end
        amount = math.floor(amount)

        if seenItems[itemName] then
            ReleaseLock(src)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end
        seenItems[itemName] = true

        local supplyItem = SupplyLookup[itemName]
        if not supplyItem then
            ReleaseLock(src)
            SB.Functions.Notify(src, 'Invalid item!', 'error', 3000)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end

        totalAmount = totalAmount + amount
        if totalAmount > MAX_SUPPLY_TOTAL then
            ReleaseLock(src)
            SB.Functions.Notify(src, 'Too many items! Max ' .. MAX_SUPPLY_TOTAL .. ' per order.', 'error', 3000)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end

        total = total + (supplyItem.price * amount)
        validItems[#validItems + 1] = { name = itemName, label = supplyItem.label, amount = amount, price = supplyItem.price }
    end

    if total <= 0 then
        ReleaseLock(src)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    -- Check cash
    local cash = Player.PlayerData.money.cash
    if cash < total then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Not enough cash! Need $' .. total, 'error', 3000)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    -- Check carry capacity for each item
    for _, item in ipairs(validItems) do
        local canCarry = exports['sb_inventory']:GetCanCarryAmount(src, item.name)
        if canCarry < item.amount then
            SB.Functions.Notify(src, 'Can\'t carry that many ' .. item.label .. '!', 'error', 3000)
            ReleaseLock(src)
            TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
            return
        end
    end

    -- Add items to inventory
    local addedItems = {}
    local allAdded = true

    for _, item in ipairs(validItems) do
        local success = exports['sb_inventory']:AddItem(src, item.name, item.amount, nil, nil, true)
        if success then
            addedItems[#addedItems + 1] = item
        else
            allAdded = false
            break
        end
    end

    if not allAdded then
        -- Rollback
        for _, item in ipairs(addedItems) do
            exports['sb_inventory']:RemoveItem(src, item.name, item.amount)
        end
        SB.Functions.Notify(src, 'Not enough inventory space!', 'error', 3000)
        ReleaseLock(src)
        TriggerClientEvent('sb_burgershot:client:purchaseResult', src, false)
        return
    end

    -- Deduct money
    Player.Functions.RemoveMoney('cash', total)
    local newCash = Player.Functions.GetMoney('cash')

    SetCooldown(src)
    ReleaseLock(src)

    SB.Functions.Notify(src, ('Purchased supplies for $%d'):format(total), 'success', 3000)
    TriggerClientEvent('sb_burgershot:client:purchaseResult', src, true, newCash)
end)

-- ============================================================================
-- COUNTER: Employee stocks ALL food items at once
-- ============================================================================

local SellableItems = { 'bs_fries', 'bs_burger', 'bs_cola', 'bs_meal' }

RegisterNetEvent('sb_burgershot:server:stockAll', function()
    local src = source

    if not AcquireLock(src) then
        SB.Functions.Notify(src, 'Already processing...', 'error', 2000)
        return
    end

    if IsOnCooldown(src) then
        ReleaseLock(src)
        return
    end

    local valid = ValidateEmployee(src)
    if not valid then
        ReleaseLock(src)
        return
    end

    -- Distance check
    if not IsNearCoords(src, Config.Counter.coords, 5.0) then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Too far from the counter!', 'error', 2000)
        return
    end

    -- Stock all sellable items from inventory
    local totalStocked = 0
    local stockedList = {}

    for _, itemName in ipairs(SellableItems) do
        local count = exports['sb_inventory']:GetItemCount(src, itemName)
        if count and count > 0 then
            exports['sb_inventory']:RemoveItem(src, itemName, count)
            CounterStock[itemName] = (CounterStock[itemName] or 0) + count
            totalStocked = totalStocked + count
            stockedList[#stockedList + 1] = count .. 'x ' .. (ItemLabels[itemName] or itemName)
        end
    end

    if totalStocked == 0 then
        SB.Functions.Notify(src, 'No food items to stock!', 'error', 3000)
    else
        SB.Functions.Notify(src, 'Stocked: ' .. table.concat(stockedList, ', '), 'success', 4000)
        SyncCounterStock()
    end

    SetCooldown(src)
    ReleaseLock(src)
end)

-- ============================================================================
-- COUNTER: Customer buys
-- ============================================================================

-- Customer purchases from counter
RegisterNetEvent('sb_burgershot:server:buyFromCounter', function(itemName)
    local src = source

    if not AcquireLock(src) then
        SB.Functions.Notify(src, 'Already processing...', 'error', 2000)
        return
    end

    if IsOnCooldown(src) then
        ReleaseLock(src)
        return
    end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    -- Validate input
    if type(itemName) ~= 'string' then ReleaseLock(src) return end

    local price = Config.Counter.prices[itemName]
    if not price then
        ReleaseLock(src)
        return
    end

    -- Distance check
    if not IsNearCoords(src, Config.Counter.coords, 5.0) then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Too far from the counter!', 'error', 2000)
        return
    end

    -- Check counter stock
    if not CounterStock[itemName] or CounterStock[itemName] < 1 then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Out of stock!', 'error', 3000)
        return
    end

    -- Check money (cash first, then bank)
    local cash = Player.PlayerData.money.cash
    local bank = Player.PlayerData.money.bank
    local payMethod = nil

    if cash >= price then
        payMethod = 'cash'
    elseif bank >= price then
        payMethod = 'bank'
    else
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Not enough money! Need $' .. price, 'error', 3000)
        return
    end

    -- Check carry capacity
    local canCarry = exports['sb_inventory']:GetCanCarryAmount(src, itemName)
    if canCarry < 1 then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Inventory full!', 'error', 3000)
        return
    end

    -- Process purchase
    Player.Functions.RemoveMoney(payMethod, price)
    CounterStock[itemName] = CounterStock[itemName] - 1

    local success = exports['sb_inventory']:AddItem(src, itemName, 1)
    if success then
        local label = ItemLabels[itemName] or itemName
        SB.Functions.Notify(src, 'Bought ' .. label .. ' for $' .. price .. ' (' .. payMethod .. ')', 'success', 3000)
        SyncCounterStock()

        -- Log bank transactions
        if payMethod == 'bank' then
            local citizenid = Player.PlayerData.citizenid
            local balanceAfter = Player.Functions.GetMoney('bank')
            exports['sb_banking']:LogPurchase(citizenid, price, balanceAfter, 'Burger Shot - ' .. label)
        end
    else
        -- Refund on failure
        Player.Functions.AddMoney(payMethod, price)
        CounterStock[itemName] = CounterStock[itemName] + 1
        SB.Functions.Notify(src, 'Could not add item!', 'error', 3000)
    end

    SetCooldown(src)
    ReleaseLock(src)
end)
