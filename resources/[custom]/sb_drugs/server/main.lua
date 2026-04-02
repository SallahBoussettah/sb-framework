--[[
    Everyday Chaos RP - Drug System (Server)
    Author: Salah Eddine Boussettah

    Handles: production validation, shop purchases, item operations,
    anti-exploit (operation locks, cooldowns, distance checks),
    card progression trades, consumable item registration.
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- Anti-exploit state
local operationLock = {}      -- operationLock[src] = true while processing
local productionCooldown = {} -- productionCooldown[src] = os.time()
local sellCooldown = {}       -- sellCooldown[src] = os.time()
local activeEffects = {}      -- activeEffects[src] = { drugName, endTime }

-- ========================================================================
-- HELPERS
-- ========================================================================

local function NotifyPlayer(src, msg, type, duration)
    TriggerClientEvent('sb_drugs:client:notify', src, msg, type or 'info', duration or 3000)
end

local function GetPlayer(src)
    return SBCore.Functions.GetPlayer(src)
end

local function HasItem(src, itemName, amount)
    return exports['sb_inventory']:HasItem(src, itemName, amount or 1)
end

local function GetItemCount(src, itemName)
    return exports['sb_inventory']:GetItemCount(src, itemName)
end

local function AddItem(src, itemName, amount)
    return exports['sb_inventory']:AddItem(src, itemName, amount or 1)
end

local function RemoveItem(src, itemName, amount)
    return exports['sb_inventory']:RemoveItem(src, itemName, amount or 1)
end

local function IsLocked(src)
    return operationLock[src] == true
end

local function SetLock(src, state)
    operationLock[src] = state or nil
end

local function IsOnCooldown(src, cooldownTable, seconds)
    local last = cooldownTable[src]
    if not last then return false end
    return (os.time() - last) < seconds
end

-- ========================================================================
-- DATABASE INIT
-- ========================================================================
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `sb_drug_progression` (
            `citizenid` VARCHAR(50) NOT NULL,
            `access_card_weed` TINYINT(1) NOT NULL DEFAULT 0,
            `access_card_coke` TINYINT(1) NOT NULL DEFAULT 0,
            `access_card_meth` TINYINT(1) NOT NULL DEFAULT 0,
            `total_sold` INT NOT NULL DEFAULT 0,
            `total_earned` BIGINT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    print('[sb_drugs] Drug system initialized')
end)

-- ========================================================================
-- PRODUCTION STEP (generic handler for all chains)
-- ========================================================================

-- Core process step logic (takes explicit src to avoid source global issues)
local function DoProcessStep(src, stepId)
    local Player = GetPlayer(src)
    if not Player then return end

    -- Get step config
    local step = Config.ProductionChains[stepId]
    if not step then
        NotifyPlayer(src, 'Invalid production step', 'error')
        return
    end

    -- Anti-exploit: operation lock
    if IsLocked(src) then
        NotifyPlayer(src, 'Already processing something', 'error')
        return
    end

    -- Anti-exploit: cooldown
    if IsOnCooldown(src, productionCooldown, Config.ProductionCooldown) then
        NotifyPlayer(src, 'Wait before doing that again', 'error')
        return
    end

    -- Lock player
    SetLock(src, true)

    -- Check lab access card if location is a lab
    local locParts = {}
    for part in string.gmatch(step.location, '[^:]+') do
        locParts[#locParts + 1] = part
    end

    if locParts[1] == 'lab' or locParts[1] == 'plants' then
        local labKey = locParts[2]
        local lab = Config.Labs[labKey]
        if lab and lab.requiredCard then
            if not HasItem(src, lab.requiredCard, 1) then
                SetLock(src, false)
                NotifyPlayer(src, 'You need an access card for this lab', 'error')
                return
            end
        end
    end

    -- Validate inputs
    for _, input in ipairs(step.inputs) do
        if input.consumed then
            if not HasItem(src, input.item, input.amount) then
                SetLock(src, false)
                NotifyPlayer(src, 'Missing required materials', 'error')
                return
            end
        else
            -- Tool check (not consumed, just need to have it)
            if not HasItem(src, input.item, 1) then
                SetLock(src, false)
                NotifyPlayer(src, 'Missing required tool: ' .. input.item, 'error')
                return
            end
        end
    end

    -- Tell client to start the progress bar + animation
    TriggerClientEvent('sb_drugs:client:startProgress', src, stepId, step.duration, step.label, step.anim, step.minigame)
end

RegisterNetEvent('sb_drugs:server:processStep', function(stepId)
    DoProcessStep(source, stepId)
end)

-- Called by client after progress bar completes successfully
RegisterNetEvent('sb_drugs:server:completeStep', function(stepId)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    local step = Config.ProductionChains[stepId]
    if not step then
        SetLock(src, false)
        return
    end

    -- Must be locked (means they started properly)
    if not IsLocked(src) then return end

    -- Re-validate inputs (anti-exploit: items could have been removed during progress)
    for _, input in ipairs(step.inputs) do
        if input.consumed then
            if not HasItem(src, input.item, input.amount) then
                SetLock(src, false)
                NotifyPlayer(src, 'Materials were removed during processing', 'error')
                return
            end
        end
    end

    -- Remove consumed inputs
    for _, input in ipairs(step.inputs) do
        if input.consumed then
            RemoveItem(src, input.item, input.amount)
        end
    end

    -- Give outputs
    for _, output in ipairs(step.outputs) do
        AddItem(src, output.item, output.amount)
    end

    -- Set cooldown
    productionCooldown[src] = os.time()

    -- Unlock
    SetLock(src, false)

    -- Notify
    local outputLabel = step.outputs[1] and step.outputs[1].item or 'item'
    NotifyPlayer(src, 'Produced: ' .. outputLabel, 'success')

    -- Notify client of plant picked (for growth cycle visual)
    if stepId == 'weed_pick' then
        TriggerClientEvent('sb_drugs:client:plantPicked', src)
    end

    -- Police alert chance
    local alertChance = step.alertChance or 0
    if alertChance > 0 and math.random(100) <= alertChance then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        local ok, err = pcall(function()
            exports['sb_alerts']:SendAlert('police', {
                title = 'Suspicious Activity',
                description = 'Drug manufacturing activity detected in the area',
                coords = coords,
                priority = 2,
                source = 'sb_drugs',
            })
        end)
        if not ok then
            print('[sb_drugs] Alert failed: ' .. tostring(err))
        end
    end
end)

-- Called by client if progress bar was cancelled
RegisterNetEvent('sb_drugs:server:cancelStep', function()
    local src = source
    SetLock(src, false)
end)

-- ========================================================================
-- SHOP PURCHASE (NUI → server validation)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:purchaseShop', function(shopIndex, cartData)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    if IsLocked(src) then
        TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
        return
    end
    SetLock(src, true)

    -- Validate shop index
    local shop = Config.Shops[shopIndex]
    if not shop then
        SetLock(src, false)
        TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
        return
    end

    -- Build lookup of valid items
    local validItems = {}
    for _, shopItem in ipairs(shop.items) do
        validItems[shopItem.item] = shopItem.price
    end

    -- Validate cart
    if type(cartData) ~= 'table' or #cartData == 0 or #cartData > 10 then
        SetLock(src, false)
        TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
        return
    end

    local totalCost = 0
    local totalItems = 0
    local validCart = {}

    for _, entry in ipairs(cartData) do
        if type(entry.name) ~= 'string' or type(entry.amount) ~= 'number' then
            SetLock(src, false)
            TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
            return
        end

        local price = validItems[entry.name]
        if not price then
            SetLock(src, false)
            NotifyPlayer(src, 'Invalid item in cart', 'error')
            TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
            return
        end

        local amount = math.floor(entry.amount)
        if amount < 1 or amount > 50 then
            SetLock(src, false)
            TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
            return
        end

        totalCost = totalCost + (price * amount)
        totalItems = totalItems + amount
        validCart[#validCart + 1] = { item = entry.name, amount = amount, price = price }
    end

    if totalItems > 100 then
        SetLock(src, false)
        NotifyPlayer(src, 'Too many items', 'error')
        TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
        return
    end

    -- Check money (cash first, then bank)
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0

    if cash + bank < totalCost then
        SetLock(src, false)
        NotifyPlayer(src, 'Not enough money', 'error')
        TriggerClientEvent('sb_drugs:client:purchaseFailed', src)
        return
    end

    -- Deduct money (cash first)
    if cash >= totalCost then
        Player.Functions.RemoveMoney('cash', totalCost, 'drug-shop-purchase')
    elseif cash > 0 then
        Player.Functions.RemoveMoney('cash', cash, 'drug-shop-purchase-cash')
        Player.Functions.RemoveMoney('bank', totalCost - cash, 'drug-shop-purchase-bank')
    else
        Player.Functions.RemoveMoney('bank', totalCost, 'drug-shop-purchase')
    end

    -- Give items via sb_inventory export
    for _, entry in ipairs(validCart) do
        AddItem(src, entry.item, entry.amount)
    end

    -- Get updated balances
    Player = GetPlayer(src) -- refresh
    local newCash = Player.PlayerData.money.cash or 0
    local newBank = Player.PlayerData.money.bank or 0

    SetLock(src, false)
    NotifyPlayer(src, 'Purchase complete! -$' .. totalCost, 'success')
    TriggerClientEvent('sb_drugs:client:purchaseSuccess', src, newCash, newBank)
end)

-- ========================================================================
-- CARD PROGRESSION TRADES (Gerald / Madrazo)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:tradeForCard', function(tradeIndex)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    if IsLocked(src) then
        NotifyPlayer(src, 'Wait a moment', 'error')
        return
    end
    SetLock(src, true)

    local tradeNpc = Config.TradeNPCs[tradeIndex]
    if not tradeNpc then
        SetLock(src, false)
        return
    end

    local trade = tradeNpc.trade

    -- Check if already has reward
    if HasItem(src, trade.rewardItem, 1) then
        SetLock(src, false)
        NotifyPlayer(src, 'You already have this access card', 'error')
        return
    end

    -- Check required items
    if not HasItem(src, trade.requiredItem, trade.requiredAmount) then
        SetLock(src, false)
        NotifyPlayer(src, 'You need ' .. trade.requiredAmount .. 'x ' .. trade.requiredItem, 'error')
        return
    end

    -- Do trade
    RemoveItem(src, trade.requiredItem, trade.requiredAmount)
    AddItem(src, trade.rewardItem, 1)

    SetLock(src, false)
    NotifyPlayer(src, 'Received: ' .. trade.rewardItem, 'success')
end)

-- ========================================================================
-- CONSUMABLE DRUG ITEMS (register useable items)
-- ========================================================================
CreateThread(function()
    Wait(2000) -- Wait for sb_core to be ready

    for _, itemName in ipairs(Config.ConsumableItems) do
        SBCore.Functions.CreateUseableItem(itemName, function(source, item)
            local src = source
            if IsLocked(src) then return end

            -- Check if player has the item
            if not HasItem(src, itemName, 1) then return end

            -- Prevent stacking same drug (don't consume item if already active)
            local active = activeEffects[src]
            if active and active.drugName == itemName and os.time() < active.endTime then
                NotifyPlayer(src, 'Already under this effect', 'error')
                return
            end

            -- Remove item
            RemoveItem(src, itemName, 1)

            -- Track active effect on server
            local effectConfig = Config.DrugEffects[itemName]
            if effectConfig then
                activeEffects[src] = { drugName = itemName, endTime = os.time() + effectConfig.duration }
            end

            -- Trigger client effect
            TriggerClientEvent('sb_drugs:client:useConsumable', src, itemName)
        end)
    end

    -- Register "anywhere" craft triggers for rolling papers / blunt wraps
    SBCore.Functions.CreateUseableItem('rolling_papers', function(source, item)
        local src = source
        if not HasItem(src, 'weed_clean', 1) then
            NotifyPlayer(src, 'You need cleaned weed to roll', 'error')
            return
        end
        DoProcessStep(src, 'roll_joint')
    end)

    SBCore.Functions.CreateUseableItem('blunt_wrap', function(source, item)
        local src = source
        if not HasItem(src, 'weed_clean', 1) then
            NotifyPlayer(src, 'You need cleaned weed to roll', 'error')
            return
        end
        DoProcessStep(src, 'roll_blunt')
    end)

    -- Register syringe: fills heroin or meth syringe depending on what player has
    SBCore.Functions.CreateUseableItem('syringe', function(source, item)
        local src = source
        if HasItem(src, 'heroin_dose', 1) then
            DoProcessStep(src, 'fill_syringe_heroin')
        elseif HasItem(src, 'meth_bag', 1) then
            DoProcessStep(src, 'fill_syringe_meth')
        else
            NotifyPlayer(src, 'You need heroin or meth to fill a syringe', 'error')
        end
    end)

    -- Register coca_pure: prepares cocaine lines
    SBCore.Functions.CreateUseableItem('coca_pure', function(source, item)
        local src = source
        DoProcessStep(src, 'prep_cocaine_line')
    end)

    print('[sb_drugs] Consumable items registered')
end)

-- ========================================================================
-- ANYWHERE CRAFTS (right-click syringe filling, cocaine line prep)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:anywhereCraft', function(craftId)
    local src = source
    local step = Config.ProductionChains[craftId]
    if not step then return end
    if step.location ~= 'anywhere' then return end

    DoProcessStep(src, craftId)
end)

-- ========================================================================
-- CALLBACKS
-- ========================================================================

-- Get carry limits for shop UI
SBCore.Functions.CreateCallback('sb_drugs:server:getCarryLimits', function(source, cb)
    local Player = GetPlayer(source)
    if not Player then cb({}) return end

    local limits = {}
    -- For now, default carry limits based on inventory space
    -- Could be customized per item in the future
    cb(limits)
end)

-- Check if player has access card
SBCore.Functions.CreateCallback('sb_drugs:server:hasAccessCard', function(source, cb, cardName)
    cb(HasItem(source, cardName, 1))
end)

-- Get player money for shop NUI
SBCore.Functions.CreateCallback('sb_drugs:server:getPlayerMoney', function(source, cb)
    local Player = GetPlayer(source)
    if not Player then cb(0, 0) return end
    cb(Player.PlayerData.money.cash or 0, Player.PlayerData.money.bank or 0)
end)

-- ========================================================================
-- ADMIN COMMANDS
-- ========================================================================
RegisterCommand('drugstats', function(source, args)
    local src = source
    if src > 0 then
        local isAdmin = exports['sb_admin']:IsAdmin(src)
        if not isAdmin then return end
    end

    local targetId = tonumber(args[1])
    if not targetId then
        if src == 0 then print('Usage: /drugstats [serverid]') end
        return
    end

    local Player = GetPlayer(targetId)
    if not Player then
        if src == 0 then print('Player not found') end
        return
    end

    local hasWeed = HasItem(targetId, 'access_card_weed', 1) and 'YES' or 'NO'
    local hasCoke = HasItem(targetId, 'access_card_coke', 1) and 'YES' or 'NO'
    local hasMeth = HasItem(targetId, 'access_card_meth', 1) and 'YES' or 'NO'

    local msg = string.format('[Drug Stats] Player %d: Weed=%s Coke=%s Meth=%s', targetId, hasWeed, hasCoke, hasMeth)
    if src == 0 then
        print(msg)
    else
        NotifyPlayer(src, msg, 'info', 5000)
    end
end, false)

RegisterCommand('givecard', function(source, args)
    local src = source
    if src > 0 then
        local isAdmin = exports['sb_admin']:IsAdmin(src)
        if not isAdmin then return end
    end

    local targetId = tonumber(args[1])
    local cardType = args[2] -- 'weed', 'coke', or 'meth'

    if not targetId or not cardType then
        if src == 0 then print('Usage: /givecard [serverid] [weed/coke/meth]') end
        return
    end

    local cardName = 'access_card_' .. cardType
    if not Config.Labs[cardType] then
        if src == 0 then print('Invalid card type. Use: weed, coke, meth') end
        return
    end

    if AddItem(targetId, cardName, 1) then
        NotifyPlayer(targetId, 'Received ' .. cardName, 'success')
        if src > 0 then
            NotifyPlayer(src, 'Gave ' .. cardName .. ' to player ' .. targetId, 'success')
        else
            print('Gave ' .. cardName .. ' to player ' .. targetId)
        end
    end
end, false)

RegisterCommand('drugcooldown', function(source, args)
    local src = source
    if src > 0 then
        local isAdmin = exports['sb_admin']:IsAdmin(src)
        if not isAdmin then return end
    end

    local targetId = tonumber(args[1])
    if not targetId then
        if src == 0 then print('Usage: /drugcooldown [serverid]') end
        return
    end

    productionCooldown[targetId] = nil
    sellCooldown[targetId] = nil
    operationLock[targetId] = nil

    if src == 0 then
        print('Cleared all drug cooldowns for player ' .. targetId)
    else
        NotifyPlayer(src, 'Cleared drug cooldowns for player ' .. targetId, 'success')
    end
end, false)

-- ========================================================================
-- CLEANUP
-- ========================================================================
AddEventHandler('playerDropped', function()
    local src = source
    operationLock[src] = nil
    productionCooldown[src] = nil
    sellCooldown[src] = nil
    activeEffects[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    operationLock = {}
    productionCooldown = {}
    sellCooldown = {}
    activeEffects = {}
end)
