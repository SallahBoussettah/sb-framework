--[[
    Everyday Chaos RP - Drug Selling (Server)
    Author: Salah Eddine Boussettah

    Handles: sell validation, price calculation, money distribution,
    negotiation logic, police alerts, cooldowns.
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- Cooldown tracking (shared with server/main.lua via global)
local sellCooldowns = {}

-- ========================================================================
-- HELPERS
-- ========================================================================

local function GetPlayer(src)
    return SBCore.Functions.GetPlayer(src)
end

local function HasItem(src, itemName, amount)
    return exports['sb_inventory']:HasItem(src, itemName, amount or 1)
end

local function GetItemCount(src, itemName)
    return exports['sb_inventory']:GetItemCount(src, itemName)
end

local function NotifyPlayer(src, msg, type, duration)
    TriggerClientEvent('sb_drugs:client:notify', src, msg, type or 'info', duration or 3000)
end

-- ========================================================================
-- REQUEST SELL (player interacts with phone booth)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:requestSell', function()
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    -- Cooldown check
    local lastSell = sellCooldowns[src]
    if lastSell and (os.time() - lastSell) < Config.SellCooldown then
        local remaining = Config.SellCooldown - (os.time() - lastSell)
        TriggerClientEvent('sb_drugs:client:sellFailed', src, 'Wait ' .. remaining .. 's before selling again')
        return
    end

    -- Find what drugs the player has
    local availableDrugs = {}
    for drugName, drugConfig in pairs(Config.Selling.drugs) do
        local count = GetItemCount(src, drugName)
        if count > 0 then
            availableDrugs[#availableDrugs + 1] = {
                name = drugName,
                label = drugConfig.label,
                count = count,
                minPrice = drugConfig.minPrice,
                maxPrice = drugConfig.maxPrice,
            }
        end
    end

    if #availableDrugs == 0 then
        TriggerClientEvent('sb_drugs:client:sellFailed', src, 'You have nothing to sell')
        return
    end

    -- Pick a random drug from what they have
    local chosen = availableDrugs[math.random(#availableDrugs)]

    -- Random quantity (1 to min of maxSell and what they have)
    local amount = math.random(1, math.min(Config.Selling.maxSellAmount, chosen.count))

    -- Random price per unit
    local pricePerUnit = math.random(chosen.minPrice, chosen.maxPrice)
    local totalPrice = pricePerUnit * amount

    -- Send offer to client (client calculates buyer spawn point locally)
    TriggerClientEvent('sb_drugs:client:sellOffer', src, {
        drugName = chosen.name,
        drugLabel = chosen.label,
        amount = amount,
        pricePerUnit = pricePerUnit,
        totalPrice = totalPrice,
    })
end)

-- ========================================================================
-- COMPLETE SELL (player accepted the deal)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:completeSell', function(drugName, amount, agreedPrice)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    -- Validate drug is sellable
    local drugConfig = Config.Selling.drugs[drugName]
    if not drugConfig then
        TriggerClientEvent('sb_drugs:client:sellFailed', src, 'Invalid drug')
        return
    end

    -- Validate player has items
    if not HasItem(src, drugName, amount) then
        TriggerClientEvent('sb_drugs:client:sellFailed', src, 'Missing items')
        return
    end

    -- Validate price is reasonable (anti-exploit)
    local maxPossible = drugConfig.maxPrice * amount * 2 -- allow for negotiation bonus
    if agreedPrice > maxPossible or agreedPrice < 0 then
        TriggerClientEvent('sb_drugs:client:sellFailed', src, 'Invalid price')
        return
    end

    -- Remove items
    exports['sb_inventory']:RemoveItem(src, drugName, amount)

    -- Give money
    local moneyType = Config.Selling.moneyType or 'cash'
    Player.Functions.AddMoney(moneyType, agreedPrice, 'drug-sale')

    -- Set cooldown
    sellCooldowns[src] = os.time()

    -- Notify client
    TriggerClientEvent('sb_drugs:client:sellComplete', src, amount, agreedPrice)

    -- Police alert chance
    local alertChance = Config.Selling.policeAlertChance or 20
    -- Guaranteed alert on 3+ items
    if amount >= 3 then alertChance = 100 end

    if math.random(100) <= alertChance then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        pcall(function()
            exports['sb_alerts']:SendAlert('police', {
                title = 'Drug Sale',
                description = 'Suspicious transaction detected',
                coords = coords,
                priority = 2,
            })
        end)
    end

    -- Attack chance
    if math.random(100) <= (Config.Selling.attackChance or 10) then
        TriggerClientEvent('sb_drugs:client:buyerAttack', src)
    end
end)

-- ========================================================================
-- NEGOTIATE (player wants better price)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:negotiateSell', function(drugName, amount, currentPrice)
    local src = source

    local drugConfig = Config.Selling.drugs[drugName]
    if not drugConfig then
        TriggerClientEvent('sb_drugs:client:sellFailed', src, 'Invalid drug')
        return
    end

    -- Success chance
    local successChance = Config.Selling.negotiateSuccessChance or 30
    if math.random(100) <= successChance then
        -- Better price (20-50% increase)
        local bonus = math.floor(currentPrice * (math.random(20, 50) / 100))
        local newPrice = currentPrice + bonus
        TriggerClientEvent('sb_drugs:client:negotiateResult', src, true, newPrice)
    else
        -- Failed negotiation
        local walkChance = Config.Selling.negotiateFailWalkChance or 30
        if math.random(100) <= walkChance then
            -- NPC walks away
            TriggerClientEvent('sb_drugs:client:negotiateResult', src, false, 0)
        else
            -- NPC stays, no price change
            TriggerClientEvent('sb_drugs:client:negotiateResult', src, true, currentPrice)
        end
    end
end)

-- ========================================================================
-- STRESS RELIEF (from drug consumption)
-- ========================================================================
RegisterNetEvent('sb_drugs:server:stressRelief', function(amount)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end

    -- Reduce stress in player metadata if it exists
    local metadata = Player.PlayerData.metadata
    if metadata and metadata.stress then
        metadata.stress = math.max(0, (metadata.stress or 0) - (amount or 0))
        Player.Functions.SetMetaData('stress', metadata.stress)
    end
end)

-- ========================================================================
-- CLEANUP
-- ========================================================================
AddEventHandler('playerDropped', function()
    local src = source
    sellCooldowns[src] = nil
end)
