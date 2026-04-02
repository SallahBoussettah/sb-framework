-- sb_companies | Server: Mechanic Order Placement, Validation, Status Tracking
-- Handles order terminal interactions for mechanic workshops

local SB = SBCompanies.SB

-- ===================================================================
-- HELPER: Get item label from sb_inventory's item registry
-- Falls back to item_name if not found
-- ===================================================================
local function GetItemLabel(itemName)
    local ok, itemData = pcall(exports['sb_inventory'].GetItemData, exports['sb_inventory'], itemName)
    if ok and itemData and itemData.label then
        return itemData.label
    end
    return itemName
end

-- ===================================================================
-- HELPER: Check if a company has raw materials to produce an item
-- Looks up the recipe and checks company stock for all ingredients
-- ===================================================================
local function CanCompanyProduce(companyId, itemName)
    -- Find the recipe that produces this item
    local recipe = nil
    for _, r in pairs(Recipes.All) do
        if r.result == itemName then
            recipe = r
            break
        end
    end

    -- No recipe means it is a raw/tool item always available
    if not recipe then
        return true
    end

    -- Check if company has all required ingredients
    for _, ingredient in ipairs(recipe.ingredients) do
        local stock = GetCompanyStock(companyId, ingredient.item)
        if stock < ingredient.amount then
            return false
        end
    end

    return true
end

-- ===================================================================
-- CALLBACK: Get all company catalogs with current prices
-- Returns: array of { id, label, items: [{ item_name, label, current_price, in_stock }] }
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:getCompanyCatalogs', function(source, cb)
    -- Validate player is a mechanic
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if not IsMechanicJob(jobName) then
        cb(false, 'You must be a mechanic to view catalogs')
        return
    end

    local catalogs = {}

    for _, companyCfg in ipairs(Config.Companies) do
        local companyId = companyCfg.id
        local prices = SBCompanies.CatalogPrices[companyId] or {}

        local items = {}
        for itemName, priceData in pairs(prices) do
            items[#items + 1] = {
                item_name     = itemName,
                label         = GetItemLabel(itemName),
                current_price = priceData.current_price,
                in_stock      = CanCompanyProduce(companyId, itemName),
            }
        end

        -- Sort items alphabetically by label
        table.sort(items, function(a, b)
            return a.label < b.label
        end)

        catalogs[#catalogs + 1] = {
            id    = companyId,
            label = companyCfg.label,
            items = items,
        }
    end

    cb(catalogs)
end)

-- ===================================================================
-- CALLBACK: Place an order from a mechanic workshop
-- Client sends: shopId, companyId, items (array of {item_name, quantity}), paymentSource
-- Validates: mechanic job, items exist in catalog, player has funds
-- Creates: orders row, order_items rows, delivery_queue entry
-- Returns: order id on success
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:placeOrder', function(source, cb, shopId, companyId, items, paymentSource)
    -- Validate player is a mechanic
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if not IsMechanicJob(jobName) then
        cb(false, 'You must be a mechanic to place orders')
        return
    end

    -- Validate shopId
    if not shopId or type(shopId) ~= 'string' or not Config.ShopById[shopId] then
        cb(false, 'Invalid shop')
        return
    end

    -- Validate companyId
    if not companyId or type(companyId) ~= 'string' then
        cb(false, 'Invalid company')
        return
    end

    local company = SBCompanies.Companies[companyId]
    if not company then
        cb(false, 'Company not found')
        return
    end

    local catalogPrices = SBCompanies.CatalogPrices[companyId]
    if not catalogPrices then
        cb(false, 'Company has no catalog')
        return
    end

    -- Validate paymentSource
    if paymentSource ~= 'bank' and paymentSource ~= 'cash' then
        cb(false, 'Invalid payment source (bank or cash)')
        return
    end

    -- Validate items array
    if not items or type(items) ~= 'table' or #items == 0 then
        cb(false, 'No items in order')
        return
    end

    -- Validate each item and calculate total cost
    local totalCost = 0
    local validatedItems = {}

    for _, orderItem in ipairs(items) do
        if not orderItem.item_name or type(orderItem.item_name) ~= 'string' then
            cb(false, 'Invalid item in order')
            return
        end

        local qty = tonumber(orderItem.quantity)
        if not qty or qty <= 0 or qty ~= math.floor(qty) then
            cb(false, 'Invalid quantity for ' .. tostring(orderItem.item_name))
            return
        end

        -- Check item exists in this company's catalog
        local priceData = catalogPrices[orderItem.item_name]
        if not priceData then
            cb(false, GetItemLabel(orderItem.item_name) .. ' is not sold by ' .. company.label)
            return
        end

        local lineTotal = priceData.current_price * qty
        totalCost = totalCost + lineTotal

        validatedItems[#validatedItems + 1] = {
            item_name  = orderItem.item_name,
            quantity   = qty,
            unit_price = priceData.current_price,
        }
    end

    if totalCost <= 0 then
        cb(false, 'Order total must be greater than $0')
        return
    end

    -- Check player has enough funds
    local playerMoney = Player.PlayerData.money[paymentSource] or 0
    if playerMoney < totalCost then
        cb(false, string.format('Insufficient %s ($%s needed, $%s available)',
            paymentSource, totalCost, math.floor(playerMoney)))
        return
    end

    -- Deduct payment from player
    local deducted = Player.Functions.RemoveMoney(paymentSource, totalCost,
        'Company order from ' .. company.label)
    if not deducted then
        cb(false, 'Payment failed')
        return
    end

    -- Create order row
    local orderId = MySQL.insert.await(
        'INSERT INTO orders (shop_id, company_id, ordered_by, status, total_cost, payment_source) VALUES (?, ?, ?, ?, ?, ?)',
        { shopId, companyId, citizenid, Enums.OrderStatus.PENDING, totalCost, paymentSource }
    )

    if not orderId then
        -- Rollback: refund money
        Player.Functions.AddMoney(paymentSource, totalCost, 'Order failed - refund')
        cb(false, 'Failed to create order')
        return
    end

    -- Create order_items rows
    for _, item in ipairs(validatedItems) do
        MySQL.insert(
            'INSERT INTO order_items (order_id, item_name, quantity, unit_price, quality) VALUES (?, ?, ?, ?, ?)',
            { orderId, item.item_name, item.quantity, item.unit_price, 'standard' }
        )
    end

    -- Create delivery_queue entry
    MySQL.insert(
        'INSERT INTO delivery_queue (order_id, status) VALUES (?, ?)',
        { orderId, Enums.DeliveryStatus.WAITING }
    )

    -- Credit company balance for the sale
    ModifyCompanyBalance(companyId, totalCost, Enums.TransactionType.SALE,
        'Order #' .. orderId .. ' from ' .. shopId)

    if Config.Debug then
        print(string.format('^2[sb_companies]^7 Order #%d placed by %s | %s -> %s | $%d (%s)',
            orderId, citizenid, companyId, shopId, totalCost, paymentSource))
    end

    cb(true, {
        order_id   = orderId,
        total_cost = totalCost,
        item_count = #validatedItems,
    })
end)

-- ===================================================================
-- CALLBACK: Get order history for a shop
-- Client sends: shopId
-- Returns: last 20 orders with status, items, total
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:getMyOrders', function(source, cb, shopId)
    -- Validate player is a mechanic
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if not IsMechanicJob(jobName) then
        cb(false, 'You must be a mechanic to view orders')
        return
    end

    -- Validate shopId
    if not shopId or type(shopId) ~= 'string' or not Config.ShopById[shopId] then
        cb(false, 'Invalid shop')
        return
    end

    -- Fetch last 20 orders for this shop
    local orders = MySQL.query.await([[
        SELECT o.id, o.company_id, o.ordered_by, o.status, o.total_cost, o.payment_source,
               o.created_at, o.updated_at
        FROM orders o
        WHERE o.shop_id = ?
        ORDER BY o.created_at DESC
        LIMIT 20
    ]], { shopId })

    if not orders or #orders == 0 then
        cb({})
        return
    end

    -- Fetch items for each order
    local results = {}
    for _, order in ipairs(orders) do
        local orderItems = MySQL.query.await([[
            SELECT item_name, quantity, unit_price, quality
            FROM order_items
            WHERE order_id = ?
        ]], { order.id })

        -- Enrich items with labels
        local enrichedItems = {}
        for _, oi in ipairs(orderItems or {}) do
            enrichedItems[#enrichedItems + 1] = {
                item_name  = oi.item_name,
                label      = GetItemLabel(oi.item_name),
                quantity   = oi.quantity,
                unit_price = oi.unit_price,
                quality    = oi.quality,
            }
        end

        -- Get company label
        local companyCfg = Config.CompanyById[order.company_id]
        local companyLabel = companyCfg and companyCfg.label or order.company_id

        results[#results + 1] = {
            id             = order.id,
            company_id     = order.company_id,
            company_label  = companyLabel,
            ordered_by     = order.ordered_by,
            status         = order.status,
            total_cost     = order.total_cost,
            payment_source = order.payment_source,
            created_at     = order.created_at,
            updated_at     = order.updated_at,
            items          = enrichedItems,
        }
    end

    cb(results)
end)

-- ===================================================================
-- CALLBACK: Cancel a pending order
-- Client sends: shopId, orderId
-- Only works if status is 'pending'. Refunds money to player.
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:cancelOrder', function(source, cb, shopId, orderId)
    -- Validate player is a mechanic
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if not IsMechanicJob(jobName) then
        cb(false, 'You must be a mechanic to cancel orders')
        return
    end

    -- Validate inputs
    if not shopId or type(shopId) ~= 'string' or not Config.ShopById[shopId] then
        cb(false, 'Invalid shop')
        return
    end

    orderId = tonumber(orderId)
    if not orderId then
        cb(false, 'Invalid order ID')
        return
    end

    -- Fetch the order
    local order = MySQL.single.await([[
        SELECT id, shop_id, company_id, ordered_by, status, total_cost, payment_source
        FROM orders
        WHERE id = ? AND shop_id = ?
    ]], { orderId, shopId })

    if not order then
        cb(false, 'Order not found')
        return
    end

    -- Only pending orders can be cancelled
    if order.status ~= Enums.OrderStatus.PENDING then
        cb(false, 'Only pending orders can be cancelled (current: ' .. order.status .. ')')
        return
    end

    -- Update order status to cancelled
    MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
        { Enums.OrderStatus.CANCELLED, orderId })

    -- Remove delivery_queue entry
    MySQL.query('DELETE FROM delivery_queue WHERE order_id = ?', { orderId })

    -- Refund money to the player who placed the order
    local refundSource = order.payment_source or 'bank'
    Player.Functions.AddMoney(refundSource, order.total_cost,
        'Order #' .. orderId .. ' cancelled - refund')

    -- Debit company balance for the reversal
    ModifyCompanyBalance(order.company_id, -order.total_cost, Enums.TransactionType.SALE,
        'Order #' .. orderId .. ' cancelled - reversal')

    if Config.Debug then
        print(string.format('^2[sb_companies]^7 Order #%d cancelled by %s | Refund $%d to %s',
            orderId, citizenid, order.total_cost, refundSource))
    end

    cb(true, {
        order_id   = orderId,
        refund     = order.total_cost,
        refund_to  = refundSource,
    })
end)
