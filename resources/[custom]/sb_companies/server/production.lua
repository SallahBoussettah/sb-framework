-- sb_companies | Server Production
-- Company worker crafting: raw materials -> finished parts + quality system
-- Callbacks: getPendingProduction, startProduction, completeProduction

local SB = SBCompanies.SB

-- ===================================================================
-- REVERSE RECIPE LOOKUP: result item_name -> recipe
-- ===================================================================
Recipes.ByResult = {}

local function BuildRecipeReverseLookup()
    local groups = {
        Recipes.RawToRefined,
        Recipes.RefinedToParts,
        Recipes.Fluids,
        Recipes.Tools,
        Recipes.Upgrades,
    }

    for _, group in ipairs(groups) do
        for _, recipe in ipairs(group) do
            Recipes.ByResult[recipe.result] = recipe
        end
    end

    if Config.Debug then
        local count = 0
        for _ in pairs(Recipes.ByResult) do count = count + 1 end
        print('^2[sb_companies]^7 Production: built reverse lookup for ' .. count .. ' recipes')
    end
end

BuildRecipeReverseLookup()

-- ===================================================================
-- ANTI-EXPLOIT: Per-player production lock
-- ===================================================================
local ProductionLock = {}  -- { [source] = true }

local function AcquireProductionLock(src)
    if ProductionLock[src] then return false end
    ProductionLock[src] = true
    return true
end

local function ReleaseProductionLock(src)
    ProductionLock[src] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    ProductionLock[src] = nil
end)

-- ===================================================================
-- HELPER: Validate employee role for production (worker or manager)
-- ===================================================================
local function CanCraft(role)
    if not role then return false end
    local roleData = Config.Roles[role]
    return roleData and roleData.canCraft == true
end

-- ===================================================================
-- HELPER: Get order items that still need to be produced
-- Returns items with remaining quantities (total ordered minus already in stock)
-- ===================================================================
local function GetRemainingOrderItems(orderId, companyId)
    local rows = MySQL.query.await(
        'SELECT item_name, quantity FROM order_items WHERE order_id = ?',
        { orderId }
    )

    if not rows or #rows == 0 then return nil end

    local items = {}
    for _, row in ipairs(rows) do
        -- Each order item needs to be produced
        table.insert(items, {
            item_name = row.item_name,
            quantity = row.quantity,
            recipe_id = Recipes.ByResult[row.item_name] and Recipes.ByResult[row.item_name].id or nil,
        })
    end

    return items
end

-- ===================================================================
-- CALLBACK: Get pending production orders for a company
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:getPendingProduction', function(source, cb, companyId)
    -- Validate player
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Validate company exists
    if not companyId or not SBCompanies.Companies[companyId] then
        cb(nil)
        return
    end

    -- Validate employee (worker or manager)
    local empData = GetEmployeeData(citizenid)
    if not empData or empData.company_id ~= companyId then
        -- Also check if owner
        if not IsCompanyOwner(citizenid, companyId) then
            cb(nil)
            return
        end
    elseif not CanCraft(empData.role) then
        cb(nil)
        return
    end

    -- Fetch pending and processing orders for this company
    local orders = MySQL.query.await(
        'SELECT id, status, created_at FROM orders WHERE company_id = ? AND status IN (?, ?) ORDER BY created_at ASC',
        { companyId, Enums.OrderStatus.PENDING, Enums.OrderStatus.PROCESSING }
    )

    if not orders or #orders == 0 then
        cb({})
        return
    end

    local result = {}
    for _, order in ipairs(orders) do
        local items = GetRemainingOrderItems(order.id, companyId)
        if items and #items > 0 then
            table.insert(result, {
                order_id = order.id,
                status = order.status,
                created_at = order.created_at,
                items = items,
            })
        end
    end

    cb(result)
end)

-- ===================================================================
-- CALLBACK: Start production (crafting) of an item from a pending order
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:startProduction', function(source, cb, companyId, orderId, itemName)
    -- Validate player
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Validate inputs
    if not companyId or not orderId or not itemName then
        cb(nil)
        return
    end

    -- Validate company
    if not SBCompanies.Companies[companyId] then
        cb(nil)
        return
    end

    -- Validate employee role
    local empData = GetEmployeeData(citizenid)
    local isOwner = IsCompanyOwner(citizenid, companyId)

    if not isOwner then
        if not empData or empData.company_id ~= companyId or not CanCraft(empData.role) then
            cb(nil)
            return
        end
    end

    -- Acquire production lock (prevent double crafting)
    if not AcquireProductionLock(source) then
        cb(nil)
        return
    end

    -- Validate order exists and is pending or processing
    local order = MySQL.query.await(
        'SELECT id, company_id, status FROM orders WHERE id = ? LIMIT 1',
        { orderId }
    )

    if not order or #order == 0 then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    order = order[1]

    if order.company_id ~= companyId then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    if order.status ~= Enums.OrderStatus.PENDING and order.status ~= Enums.OrderStatus.PROCESSING then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    -- Validate item is part of this order
    local orderItem = MySQL.query.await(
        'SELECT id, item_name, quantity FROM order_items WHERE order_id = ? AND item_name = ? LIMIT 1',
        { orderId, itemName }
    )

    if not orderItem or #orderItem == 0 then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    -- Validate recipe exists for this item
    local recipe = Recipes.ByResult[itemName]
    if not recipe then
        ReleaseProductionLock(source)
        if Config.Debug then
            print('^1[sb_companies]^7 Production: no recipe found for ' .. itemName)
        end
        cb(nil)
        return
    end

    -- Validate company has all raw materials in company_stock
    for _, ingredient in ipairs(recipe.ingredients) do
        local available = GetCompanyStock(companyId, ingredient.item)
        if available < ingredient.amount then
            ReleaseProductionLock(source)
            cb({
                error = 'missing_materials',
                missing_item = ingredient.item,
                required = ingredient.amount,
                available = available,
            })
            return
        end
    end

    -- Consume raw materials from company stock
    for _, ingredient in ipairs(recipe.ingredients) do
        ModifyCompanyStock(companyId, ingredient.item, -ingredient.amount)
    end

    -- Update order status to processing if it was pending
    if order.status == Enums.OrderStatus.PENDING then
        MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
            { Enums.OrderStatus.PROCESSING, orderId })
    end

    if Config.Debug then
        print('^2[sb_companies]^7 Production started: ' .. Player.PlayerData.charinfo.firstname .. ' crafting ' .. itemName .. ' (order #' .. orderId .. ')')
    end

    -- Return recipe data for client minigame
    cb({
        recipe_id = recipe.id,
        label = recipe.label,
        craftTime = recipe.craftTime,
        minigame = recipe.minigame,
        result = recipe.result,
        resultAmount = recipe.resultAmount,
    })
end)

-- ===================================================================
-- CALLBACK: Complete production after minigame
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:completeProduction', function(source, cb, companyId, orderId, itemName, success)
    -- Validate player
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Validate inputs
    if not companyId or not orderId or not itemName or success == nil then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    -- Validate company
    if not SBCompanies.Companies[companyId] then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    -- Validate employee role
    local empData = GetEmployeeData(citizenid)
    local isOwner = IsCompanyOwner(citizenid, companyId)

    if not isOwner then
        if not empData or empData.company_id ~= companyId or not CanCraft(empData.role) then
            ReleaseProductionLock(source)
            cb(nil)
            return
        end
    end

    -- Get recipe
    local recipe = Recipes.ByResult[itemName]
    if not recipe then
        ReleaseProductionLock(source)
        cb(nil)
        return
    end

    if success then
        -- Crafting succeeded: add finished item to company stock
        local quality = Enums.Quality.STANDARD.name  -- No per-employee levels yet

        ModifyCompanyStock(companyId, itemName, recipe.resultAmount)

        if Config.Debug then
            print('^2[sb_companies]^7 Production complete: ' .. recipe.resultAmount .. 'x ' .. itemName .. ' (' .. quality .. ') added to ' .. companyId)
        end

        -- Check if all items in order are now produced
        local allProduced = CheckOrderComplete(orderId, companyId)

        ReleaseProductionLock(source)
        cb({
            success = true,
            item_name = itemName,
            quantity = recipe.resultAmount,
            quality = quality,
            order_complete = allProduced,
        })
    else
        -- Crafting failed: 50% chance to save each ingredient
        local savedItems = {}
        for _, ingredient in ipairs(recipe.ingredients) do
            if math.random() < 0.5 then
                ModifyCompanyStock(companyId, ingredient.item, ingredient.amount)
                table.insert(savedItems, { item = ingredient.item, amount = ingredient.amount })
            end
        end

        if Config.Debug then
            print('^3[sb_companies]^7 Production failed: ' .. itemName .. ' by ' .. citizenid .. ', saved ' .. #savedItems .. ' ingredient(s)')
        end

        ReleaseProductionLock(source)
        cb({
            success = false,
            item_name = itemName,
            saved_materials = savedItems,
        })
    end
end)

-- ===================================================================
-- HELPER: Check if all items in an order have been produced
-- If complete, set order to 'ready' and add to delivery_queue
-- ===================================================================
function CheckOrderComplete(orderId, companyId)
    -- Get all items needed for this order
    local orderItems = MySQL.query.await(
        'SELECT item_name, quantity FROM order_items WHERE order_id = ?',
        { orderId }
    )

    if not orderItems or #orderItems == 0 then return false end

    -- Check if company stock has enough of each order item
    for _, item in ipairs(orderItems) do
        local inStock = GetCompanyStock(companyId, item.item_name)
        if inStock < item.quantity then
            return false
        end
    end

    -- All items produced - update order to 'ready'
    MySQL.query('UPDATE orders SET status = ? WHERE id = ?',
        { Enums.OrderStatus.READY, orderId })

    -- Deduct the finished items from company stock (reserved for this order)
    for _, item in ipairs(orderItems) do
        ModifyCompanyStock(companyId, item.item_name, -item.quantity)
    end

    -- Add to delivery queue
    MySQL.query(
        'INSERT INTO delivery_queue (order_id, status) VALUES (?, ?) ON DUPLICATE KEY UPDATE status = ?',
        { orderId, Enums.DeliveryStatus.WAITING, Enums.DeliveryStatus.WAITING }
    )

    if Config.Debug then
        print('^2[sb_companies]^7 Order #' .. orderId .. ' complete - added to delivery queue')
    end

    return true
end
