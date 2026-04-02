-- sb_mechanic_v2 | Phase 2: Supplier NPC Server Logic
-- Callbacks for browsing stock and purchasing raw materials

local SB = SBMechanic.SB

-- ===================================================================
-- CALLBACK: Get supplier stock list with prices
-- ===================================================================
SB.Functions.CreateCallback('sb_mechanic_v2:getSupplierStock', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    -- Verify mechanic job
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then
        return cb(nil)
    end

    -- Build stock list from config
    local stock = {}
    for itemName, basePrice in pairs(Config.SupplierPrices) do
        local itemDef = CraftItems.ByName[itemName]
        if itemDef then
            table.insert(stock, {
                name = itemName,
                label = itemDef.label,
                category = itemDef.category,
                description = itemDef.description,
                price = math.ceil(basePrice * Config.Supplier.markup),
                maxStack = itemDef.max_stack or 50,
            })
        end
    end

    -- Sort alphabetically by label
    table.sort(stock, function(a, b) return a.label < b.label end)

    cb({
        stock = stock,
        bulkThreshold = Config.Supplier.bulkThreshold,
        bulkDiscount = Config.Supplier.bulkDiscount,
        playerCash = Player.PlayerData.money.cash,
        playerBank = Player.PlayerData.money.bank,
    })
end)

-- ===================================================================
-- CALLBACK: Buy from supplier
-- ===================================================================
SB.Functions.CreateCallback('sb_mechanic_v2:buyFromSupplier', function(source, cb, itemName, amount, paymentType)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    -- Verify mechanic job
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then
        return cb(false)
    end

    -- Validate item
    local basePrice = Config.SupplierPrices[itemName]
    if not basePrice then
        return cb(false)
    end

    -- Validate amount
    amount = tonumber(amount) or 0
    if amount < 1 or amount > 100 then
        return cb(false)
    end

    -- Check if player can carry
    local canCarry = exports['sb_inventory']:GetCanCarryAmount(source, itemName)
    if (canCarry or 0) < amount then
        TriggerClientEvent('sb_notify:client:Notify', source, 'Not enough inventory space', 'error', 3000)
        return cb(false)
    end

    -- Calculate price with markup
    local unitPrice = math.ceil(basePrice * Config.Supplier.markup)
    local totalPrice = unitPrice * amount

    -- Apply bulk discount
    if amount >= Config.Supplier.bulkThreshold then
        totalPrice = math.ceil(totalPrice * (1 - Config.Supplier.bulkDiscount))
    end

    -- Determine payment method
    paymentType = paymentType or 'cash'
    if paymentType ~= 'cash' and paymentType ~= 'bank' then
        paymentType = 'cash'
    end

    -- Check funds
    local playerMoney = Player.PlayerData.money[paymentType] or 0
    if playerMoney < totalPrice then
        TriggerClientEvent('sb_notify:client:Notify', source, 'Not enough ' .. paymentType, 'error', 3000)
        return cb(false)
    end

    -- Deduct money
    local removed = Player.Functions.RemoveMoney(paymentType, totalPrice, 'Supplier purchase: ' .. itemName .. ' x' .. amount)
    if not removed then
        TriggerClientEvent('sb_notify:client:Notify', source, 'Payment failed', 'error', 3000)
        return cb(false)
    end

    -- Add items to inventory
    local added = exports['sb_inventory']:AddItem(source, itemName, amount)
    if not added then
        -- Refund if item add failed
        Player.Functions.AddMoney(paymentType, totalPrice, 'Supplier refund: ' .. itemName .. ' x' .. amount)
        return cb(false)
    end

    -- Notify success
    local itemDef = CraftItems.ByName[itemName]
    local label = itemDef and itemDef.label or itemName
    local discountText = ''
    if amount >= Config.Supplier.bulkThreshold then
        discountText = ' (bulk discount applied)'
    end

    TriggerClientEvent('sb_notify:client:Notify', source,
        ('Purchased %dx %s for $%d%s'):format(amount, label, totalPrice, discountText),
        'success', 4000
    )

    cb(true)
end)
