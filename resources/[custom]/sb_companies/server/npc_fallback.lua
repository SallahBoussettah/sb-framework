-- sb_companies | NPC Fallback System
-- Auto-production and auto-delivery when no player workers/drivers are online

local SB = SBCompanies.SB

-- ===================================================================
-- HELPER: Check if a citizenid is currently online
-- ===================================================================

local function GetPlayerByCitizenId(citizenid)
    local players = SB.Functions.GetPlayers()
    for _, src in ipairs(players) do
        local p = SB.Functions.GetPlayer(src)
        if p and p.PlayerData.citizenid == citizenid then return src end
    end
    return nil
end

-- ===================================================================
-- HELPER: Check if any employee of a company is online
-- Returns true if at least one worker/manager/driver is connected
-- ===================================================================

local function IsAnyWorkerOnline(companyId)
    for citizenid, empData in pairs(SBCompanies.Employees) do
        if empData.company_id == companyId then
            if GetPlayerByCitizenId(citizenid) then
                return true
            end
        end
    end

    -- Also check if owner is online
    local company = SBCompanies.Companies[companyId]
    if company and company.owner_citizenid then
        if GetPlayerByCitizenId(company.owner_citizenid) then
            return true
        end
    end

    return false
end

-- ===================================================================
-- HELPER: Check if any driver of a company is online
-- ===================================================================

local function IsAnyDriverOnline(companyId)
    for citizenid, empData in pairs(SBCompanies.Employees) do
        if empData.company_id == companyId then
            local role = empData.role
            -- Drivers and managers can drive
            if role == Enums.Role.DRIVER or role == Enums.Role.MANAGER then
                if GetPlayerByCitizenId(citizenid) then
                    return true
                end
            end
        end
    end

    -- Owner can also drive
    local company = SBCompanies.Companies[companyId]
    if company and company.owner_citizenid then
        if GetPlayerByCitizenId(company.owner_citizenid) then
            return true
        end
    end

    return false
end

-- ===================================================================
-- HELPER: Find recipe that produces a given item
-- ===================================================================

local function FindRecipeForItem(itemName)
    for _, recipe in pairs(Recipes.All) do
        if recipe.result == itemName then
            return recipe
        end
    end
    return nil
end

-- ===================================================================
-- NPC PRODUCTION TIMER
-- Runs every 60 seconds
-- Auto-produces pending orders when no workers are online
-- ===================================================================

CreateThread(function()
    -- Wait for data to load
    Wait(15000)

    while true do
        Wait(60000) -- 60 seconds

        -- Find all pending orders older than npcDelay
        local pendingOrders = MySQL.query.await([[
            SELECT o.*, oi.item_name, oi.quantity AS item_qty
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            WHERE o.status = 'pending'
              AND o.created_at < DATE_SUB(NOW(), INTERVAL ? SECOND)
        ]], { Config.Production.npcDelay })

        if not pendingOrders or #pendingOrders == 0 then goto continue_production end

        -- Group order items by order_id
        local orderGroups = {}
        for _, row in ipairs(pendingOrders) do
            if not orderGroups[row.id] then
                orderGroups[row.id] = {
                    id = row.id,
                    company_id = row.company_id,
                    shop_id = row.shop_id,
                    items = {},
                }
            end
            table.insert(orderGroups[row.id].items, {
                item_name = row.item_name,
                quantity = row.item_qty,
            })
        end

        for orderId, orderData in pairs(orderGroups) do
            local companyId = orderData.company_id

            -- Only NPC-produce if no worker is online
            if IsAnyWorkerOnline(companyId) then goto continue_order end

            local allProduced = true

            for _, orderItem in ipairs(orderData.items) do
                local recipe = FindRecipeForItem(orderItem.item_name)

                if recipe then
                    -- For each unit of the item ordered, consume raw materials
                    local batchesNeeded = math.ceil(orderItem.quantity / recipe.resultAmount)

                    for _ = 1, batchesNeeded do
                        local hasAllMaterials = true

                        -- Check if company has raw materials
                        for _, ingredient in ipairs(recipe.ingredients) do
                            local stockQty = GetCompanyStock(companyId, ingredient.item)
                            if stockQty < ingredient.amount then
                                hasAllMaterials = false
                                break
                            end
                        end

                        if hasAllMaterials then
                            -- Consume raw materials from company stock
                            for _, ingredient in ipairs(recipe.ingredients) do
                                ModifyCompanyStock(companyId, ingredient.item, -ingredient.amount)
                            end
                        else
                            -- Auto-buy raw materials at NPC markup price
                            local totalRestockCost = 0
                            for _, ingredient in ipairs(recipe.ingredients) do
                                local stockQty = GetCompanyStock(companyId, ingredient.item)
                                local needed = ingredient.amount - stockQty

                                if needed > 0 then
                                    local basePrice = Config.RawMaterialPrices[ingredient.item] or 50
                                    local markupPrice = math.floor(basePrice * Config.NPCRestockMarkup)
                                    local cost = markupPrice * needed
                                    totalRestockCost = totalRestockCost + cost

                                    -- Add the purchased materials to stock
                                    ModifyCompanyStock(companyId, ingredient.item, needed)
                                end
                            end

                            -- Deduct restock cost from company balance
                            local company = SBCompanies.Companies[companyId]
                            if company and company.balance >= totalRestockCost then
                                ModifyCompanyBalance(companyId, -totalRestockCost, Enums.TransactionType.RAW_PURCHASE,
                                    'NPC auto-restock for order #' .. orderId)
                            else
                                -- Company cannot afford. Skip this order.
                                allProduced = false
                                goto continue_order
                            end

                            -- Now consume the materials
                            for _, ingredient in ipairs(recipe.ingredients) do
                                ModifyCompanyStock(companyId, ingredient.item, -ingredient.amount)
                            end
                        end
                    end
                else
                    -- No recipe found; just add the item directly to stock
                    -- (fluids or pre-made items)
                    ModifyCompanyStock(companyId, orderItem.item_name, orderItem.quantity)
                end
            end

            if allProduced then
                -- Set quality to NPC standard
                local npcQuality = Config.Production.npcQuality

                -- Update order status to 'ready'
                MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
                    { Enums.OrderStatus.READY, orderId })

                -- Create delivery_queue entry
                MySQL.insert('INSERT INTO delivery_queue (order_id, status) VALUES (?, ?)',
                    { orderId, Enums.DeliveryStatus.WAITING })

                if Config.Debug then
                    print(('[sb_companies] NPC auto-produced order #%d for %s'):format(orderId, companyId))
                end
            end

            ::continue_order::
        end

        ::continue_production::
    end
end)

-- ===================================================================
-- NPC DELIVERY TIMER
-- Runs every 60 seconds
-- Auto-dispatches and completes deliveries when no drivers are online
-- ===================================================================

CreateThread(function()
    -- Wait for data to load
    Wait(20000)

    while true do
        Wait(60000) -- 60 seconds

        -- STEP 1: Check waiting deliveries older than npcWaitTime, dispatch NPC
        local waitingDeliveries = MySQL.query.await([[
            SELECT dq.*, o.company_id, o.shop_id
            FROM delivery_queue dq
            JOIN orders o ON o.id = dq.order_id
            WHERE dq.status = 'waiting'
              AND dq.id IN (
                  SELECT dq2.id FROM delivery_queue dq2
                  JOIN orders o2 ON o2.id = dq2.order_id
                  WHERE dq2.status = 'waiting'
                    AND o2.status = 'ready'
              )
        ]])

        if waitingDeliveries then
            for _, delivery in ipairs(waitingDeliveries) do
                -- Check creation time via order created_at
                local orderRow = MySQL.single.await('SELECT created_at FROM orders WHERE id = ?', { delivery.order_id })
                if not orderRow then goto continue_waiting end

                -- Check if any driver of this company is online
                if IsAnyDriverOnline(delivery.company_id) then goto continue_waiting end

                -- Check if waiting long enough (npcWaitTime in minutes)
                -- We check delivery_queue entries implicitly by checking order age
                -- For robustness, check via TIMESTAMPDIFF
                local ageCheck = MySQL.single.await([[
                    SELECT TIMESTAMPDIFF(MINUTE, o.updated_at, NOW()) AS age_minutes
                    FROM orders o WHERE o.id = ? AND o.status = 'ready'
                ]], { delivery.order_id })

                if not ageCheck or (ageCheck.age_minutes or 0) < Config.Delivery.npcWaitTime then
                    goto continue_waiting
                end

                -- Dispatch NPC: set status to 'npc_dispatched' with arrival time
                local driveTime = math.random(Config.Delivery.npcDriveTimeMin, Config.Delivery.npcDriveTimeMax)
                MySQL.query([[
                    UPDATE delivery_queue
                    SET status = 'npc_dispatched',
                        npc_arrive_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)
                    WHERE id = ?
                ]], { driveTime, delivery.id })

                -- Update order status to in_transit
                MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
                    { Enums.OrderStatus.IN_TRANSIT, delivery.order_id })

                if Config.Debug then
                    print(('[sb_companies] NPC dispatched for delivery #%d (order #%d) - ETA %d min'):format(
                        delivery.id, delivery.order_id, driveTime))
                end

                ::continue_waiting::
            end
        end

        -- STEP 2: Complete NPC deliveries where npc_arrive_at has passed
        local arrivedDeliveries = MySQL.query.await([[
            SELECT dq.*, o.company_id, o.shop_id
            FROM delivery_queue dq
            JOIN orders o ON o.id = dq.order_id
            WHERE dq.status = 'npc_dispatched'
              AND dq.npc_arrive_at IS NOT NULL
              AND dq.npc_arrive_at <= NOW()
        ]])

        if arrivedDeliveries then
            for _, delivery in ipairs(arrivedDeliveries) do
                -- Get order items
                local orderItems = MySQL.query.await(
                    'SELECT * FROM order_items WHERE order_id = ?',
                    { delivery.order_id }
                )

                if orderItems then
                    -- Move items to shop storage with NPC quality cap
                    local npcMaxRestore = Config.Delivery.npcQualityCap
                    -- Determine quality name based on npcMaxRestore threshold
                    local npcQuality = Config.Production.npcQuality -- 'standard'

                    for _, item in ipairs(orderItems) do
                        AddToShopStorage(delivery.shop_id, item.item_name, item.quantity, npcQuality)
                    end

                    -- Charge company the NPC surcharge
                    ModifyCompanyBalance(delivery.company_id, -Config.Delivery.npcSurcharge,
                        Enums.TransactionType.DELIVERY_FEE,
                        'NPC delivery surcharge for order #' .. delivery.order_id)
                end

                -- Mark delivery completed
                MySQL.query([[
                    UPDATE delivery_queue
                    SET status = 'completed', completed_at = NOW()
                    WHERE id = ?
                ]], { delivery.id })

                -- Mark order delivered
                MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
                    { Enums.OrderStatus.DELIVERED, delivery.order_id })

                if Config.Debug then
                    print(('[sb_companies] NPC delivery #%d completed (order #%d) to shop %s'):format(
                        delivery.id, delivery.order_id, delivery.shop_id))
                end
            end
        end
    end
end)
