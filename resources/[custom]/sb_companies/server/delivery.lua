-- sb_companies | Server Delivery
-- Delivery queue management, driver claims, completion logic
-- Callbacks: getDeliveryQueue, claimDelivery, completeDelivery

local SB = SBCompanies.SB

-- ===================================================================
-- ANTI-EXPLOIT: Per-player delivery lock
-- ===================================================================
local DeliveryLock = {}      -- { [source] = true }
local ActiveClaims = {}      -- { [citizenid] = delivery_id }

local function AcquireDeliveryLock(src)
    if DeliveryLock[src] then return false end
    DeliveryLock[src] = true
    return true
end

local function ReleaseDeliveryLock(src)
    DeliveryLock[src] = nil
end

-- ===================================================================
-- HELPER: Validate employee role for delivery (driver or manager)
-- ===================================================================
local function CanDrive(role)
    if not role then return false end
    local roleData = Config.Roles[role]
    return roleData and roleData.canDrive == true
end

-- ===================================================================
-- CALLBACK: Get available deliveries for drivers
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:getDeliveryQueue', function(source, cb, companyId)
    -- Validate player
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Validate company
    if not companyId or not SBCompanies.Companies[companyId] then
        cb(nil)
        return
    end

    -- Validate employee (driver or manager)
    local empData = GetEmployeeData(citizenid)
    local isOwner = IsCompanyOwner(citizenid, companyId)

    if not isOwner then
        if not empData or empData.company_id ~= companyId or not CanDrive(empData.role) then
            cb(nil)
            return
        end
    end

    -- Fetch waiting deliveries for this company
    local deliveries = MySQL.query.await([[
        SELECT dq.id AS delivery_id, dq.order_id, o.shop_id, o.total_cost
        FROM delivery_queue dq
        INNER JOIN orders o ON o.id = dq.order_id
        WHERE o.company_id = ? AND dq.status = ?
        ORDER BY dq.id ASC
    ]], { companyId, Enums.DeliveryStatus.WAITING })

    if not deliveries or #deliveries == 0 then
        cb({})
        return
    end

    local result = {}
    for _, del in ipairs(deliveries) do
        -- Get shop label
        local shop = Config.ShopById[del.shop_id]
        local shopLabel = shop and shop.label or del.shop_id

        -- Get order items
        local items = MySQL.query.await(
            'SELECT item_name, quantity FROM order_items WHERE order_id = ?',
            { del.order_id }
        )

        local itemList = {}
        for _, item in ipairs(items or {}) do
            table.insert(itemList, {
                item_name = item.item_name,
                quantity = item.quantity,
            })
        end

        table.insert(result, {
            delivery_id = del.delivery_id,
            order_id = del.order_id,
            shop_id = del.shop_id,
            shop_label = shopLabel,
            items = itemList,
            total_value = del.total_cost,
        })
    end

    cb(result)
end)

-- ===================================================================
-- CALLBACK: Driver claims a delivery
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:claimDelivery', function(source, cb, deliveryId)
    -- Validate player
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Validate input
    if not deliveryId then
        cb(nil)
        return
    end

    -- Check if player already has an active claim
    if ActiveClaims[citizenid] then
        cb({ error = 'already_claimed', message = 'You already have an active delivery' })
        return
    end

    -- Acquire lock
    if not AcquireDeliveryLock(source) then
        cb(nil)
        return
    end

    -- Fetch delivery and validate
    local delivery = MySQL.query.await([[
        SELECT dq.id, dq.order_id, dq.status, o.company_id, o.shop_id, o.total_cost
        FROM delivery_queue dq
        INNER JOIN orders o ON o.id = dq.order_id
        WHERE dq.id = ? LIMIT 1
    ]], { deliveryId })

    if not delivery or #delivery == 0 then
        ReleaseDeliveryLock(source)
        cb(nil)
        return
    end

    delivery = delivery[1]

    -- Validate delivery is waiting
    if delivery.status ~= Enums.DeliveryStatus.WAITING then
        ReleaseDeliveryLock(source)
        cb({ error = 'not_available', message = 'Delivery is no longer available' })
        return
    end

    -- Validate player is employee (driver/manager) of this company
    local empData = GetEmployeeData(citizenid)
    local isOwner = IsCompanyOwner(citizenid, delivery.company_id)

    if not isOwner then
        if not empData or empData.company_id ~= delivery.company_id or not CanDrive(empData.role) then
            ReleaseDeliveryLock(source)
            cb(nil)
            return
        end
    end

    -- Claim the delivery
    MySQL.query(
        'UPDATE delivery_queue SET status = ?, claimed_by = ?, claimed_at = NOW() WHERE id = ? AND status = ?',
        { Enums.DeliveryStatus.CLAIMED, citizenid, deliveryId, Enums.DeliveryStatus.WAITING }
    )

    -- Update order status
    MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
        { Enums.OrderStatus.IN_TRANSIT, delivery.order_id })

    -- Track active claim
    ActiveClaims[citizenid] = deliveryId

    -- Get order items
    local items = MySQL.query.await(
        'SELECT item_name, quantity FROM order_items WHERE order_id = ?',
        { delivery.order_id }
    )

    local itemList = {}
    for _, item in ipairs(items or {}) do
        table.insert(itemList, {
            item_name = item.item_name,
            quantity = item.quantity,
        })
    end

    -- Get shop dropoff location
    local shop = Config.ShopById[delivery.shop_id]
    local dropoff = shop and shop.deliveryDropoff or nil
    local dropoffRadius = shop and shop.deliveryDropoffRadius or 5.0

    if Config.Debug then
        print('^2[sb_companies]^7 Delivery #' .. deliveryId .. ' claimed by ' .. citizenid)
    end

    ReleaseDeliveryLock(source)
    cb({
        delivery_id = deliveryId,
        order_id = delivery.order_id,
        company_id = delivery.company_id,
        shop_id = delivery.shop_id,
        shop_label = shop and shop.label or delivery.shop_id,
        items = itemList,
        total_value = delivery.total_cost,
        dropoff = dropoff,
        dropoff_radius = dropoffRadius,
    })
end)

-- ===================================================================
-- CALLBACK: Driver completes delivery at shop
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:completeDelivery', function(source, cb, deliveryId)
    -- Validate player
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Validate input
    if not deliveryId then
        cb(nil)
        return
    end

    -- Acquire lock
    if not AcquireDeliveryLock(source) then
        cb(nil)
        return
    end

    -- Fetch delivery
    local delivery = MySQL.query.await([[
        SELECT dq.id, dq.order_id, dq.status, dq.claimed_by, o.company_id, o.shop_id, o.total_cost
        FROM delivery_queue dq
        INNER JOIN orders o ON o.id = dq.order_id
        WHERE dq.id = ? LIMIT 1
    ]], { deliveryId })

    if not delivery or #delivery == 0 then
        ReleaseDeliveryLock(source)
        cb(nil)
        return
    end

    delivery = delivery[1]

    -- Validate status is claimed or in_transit
    if delivery.status ~= Enums.DeliveryStatus.CLAIMED and delivery.status ~= Enums.DeliveryStatus.IN_TRANSIT then
        ReleaseDeliveryLock(source)
        cb({ error = 'invalid_status', message = 'Delivery is not in a completable state' })
        return
    end

    -- Validate claimed_by matches player
    if delivery.claimed_by ~= citizenid then
        ReleaseDeliveryLock(source)
        cb({ error = 'not_yours', message = 'This delivery is not assigned to you' })
        return
    end

    -- Get order items
    local orderItems = MySQL.query.await(
        'SELECT item_name, quantity, quality FROM order_items WHERE order_id = ?',
        { delivery.order_id }
    )

    if not orderItems or #orderItems == 0 then
        ReleaseDeliveryLock(source)
        cb(nil)
        return
    end

    -- Move items from order into shop storage
    for _, item in ipairs(orderItems) do
        local quality = item.quality or 'standard'
        AddToShopStorage(delivery.shop_id, item.item_name, item.quantity, quality)
    end

    -- Update delivery status to completed
    MySQL.query(
        'UPDATE delivery_queue SET status = ?, completed_at = NOW() WHERE id = ?',
        { Enums.DeliveryStatus.COMPLETED, deliveryId }
    )

    -- Update order status to delivered
    MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
        { Enums.OrderStatus.DELIVERED, delivery.order_id })

    -- Pay driver
    local driverPay = Config.Delivery.driverPayment
    Player.Functions.AddMoney('bank', driverPay, 'company-delivery')

    -- Credit company balance with order total
    ModifyCompanyBalance(delivery.company_id, delivery.total_cost, Enums.TransactionType.SALE,
        'Order #' .. delivery.order_id .. ' delivered to ' .. delivery.shop_id)

    -- Log delivery fee as expense
    ModifyCompanyBalance(delivery.company_id, -driverPay, Enums.TransactionType.DELIVERY_FEE,
        'Driver payment for delivery #' .. deliveryId)

    -- Clear active claim
    ActiveClaims[citizenid] = nil

    if Config.Debug then
        print('^2[sb_companies]^7 Delivery #' .. deliveryId .. ' completed by ' .. citizenid .. ' | Driver paid $' .. driverPay .. ' | Company credited $' .. delivery.total_cost)
    end

    ReleaseDeliveryLock(source)
    cb({
        success = true,
        delivery_id = deliveryId,
        driver_payment = driverPay,
        company_credit = delivery.total_cost,
    })
end)

-- ===================================================================
-- PLAYER DISCONNECT: Reset active delivery claims
-- ===================================================================
AddEventHandler('playerDropped', function()
    local src = source
    DeliveryLock[src] = nil

    -- Get citizenid before player data is cleaned up
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    if not citizenid then return end

    local claimedDeliveryId = ActiveClaims[citizenid]
    if not claimedDeliveryId then return end

    -- Reset delivery back to waiting
    MySQL.query(
        'UPDATE delivery_queue SET status = ?, claimed_by = NULL, claimed_at = NULL WHERE id = ? AND status IN (?, ?)',
        { Enums.DeliveryStatus.WAITING, claimedDeliveryId, Enums.DeliveryStatus.CLAIMED, Enums.DeliveryStatus.IN_TRANSIT }
    )

    -- Reset order status back to ready
    local delivery = MySQL.query.await(
        'SELECT order_id FROM delivery_queue WHERE id = ? LIMIT 1',
        { claimedDeliveryId }
    )

    if delivery and #delivery > 0 then
        MySQL.query('UPDATE orders SET status = ? WHERE id = ? AND status = ?',
            { Enums.OrderStatus.READY, delivery[1].order_id, Enums.OrderStatus.IN_TRANSIT })
    end

    ActiveClaims[citizenid] = nil

    if Config.Debug then
        print('^3[sb_companies]^7 Delivery #' .. claimedDeliveryId .. ' reset (player ' .. citizenid .. ' disconnected)')
    end
end)

-- ===================================================================
-- CLEANUP: Stale delivery claims (claimed too long ago)
-- ===================================================================
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        local timeoutMinutes = Config.Delivery.claimTimeout

        -- Find stale claims
        local stale = MySQL.query.await([[
            SELECT dq.id AS delivery_id, dq.claimed_by, dq.order_id
            FROM delivery_queue dq
            WHERE dq.status IN (?, ?)
              AND dq.claimed_at IS NOT NULL
              AND dq.claimed_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)
        ]], { Enums.DeliveryStatus.CLAIMED, Enums.DeliveryStatus.IN_TRANSIT, timeoutMinutes })

        if stale and #stale > 0 then
            for _, entry in ipairs(stale) do
                -- Reset delivery to waiting
                MySQL.query(
                    'UPDATE delivery_queue SET status = ?, claimed_by = NULL, claimed_at = NULL WHERE id = ?',
                    { Enums.DeliveryStatus.WAITING, entry.delivery_id }
                )

                -- Reset order status back to ready
                MySQL.query('UPDATE orders SET status = ? WHERE id = ? AND status = ?',
                    { Enums.OrderStatus.READY, entry.order_id, Enums.OrderStatus.IN_TRANSIT })

                -- Clear from active claims
                if entry.claimed_by and ActiveClaims[entry.claimed_by] == entry.delivery_id then
                    ActiveClaims[entry.claimed_by] = nil
                end

                if Config.Debug then
                    print('^3[sb_companies]^7 Stale delivery #' .. entry.delivery_id .. ' reset (claimed by ' .. (entry.claimed_by or 'unknown') .. ', timed out after ' .. timeoutMinutes .. 'min)')
                end
            end
        end
    end
end)
