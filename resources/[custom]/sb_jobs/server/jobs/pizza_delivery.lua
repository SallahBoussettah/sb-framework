-- ============================================================================
-- Pizza Delivery — Server Job Logic
-- Registers handlers into the PublicJobServerHandlers framework
--
-- Key responsibilities:
--   1. Pick a restaurant based on player level (avoid repeats)
--   2. Pick delivery locations from that restaurant's pool
--   3. Validate deliveries (anti-exploit distance check)
-- ============================================================================

local function ShuffleTable(tbl)
    local shuffled = {}
    for i, v in ipairs(tbl) do
        shuffled[i] = v
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

-- Pick batchSize locations from a delivery pool, avoiding recently used ones
local function PickBatchLocations(deliveryPool, recentLocations, batchSize)
    local all = {}
    for i, loc in ipairs(deliveryPool) do
        local isRecent = false
        for _, recentIdx in ipairs(recentLocations or {}) do
            if recentIdx == i then
                isRecent = true
                break
            end
        end
        if not isRecent then
            table.insert(all, { index = i, coords = loc })
        end
    end

    -- If not enough non-recent, use all
    if #all < batchSize then
        all = {}
        for i, loc in ipairs(deliveryPool) do
            table.insert(all, { index = i, coords = loc })
        end
    end

    local shuffled = ShuffleTable(all)
    local picked = {}
    local pickedIndices = {}
    for i = 1, math.min(batchSize, #shuffled) do
        table.insert(picked, shuffled[i].coords)
        table.insert(pickedIndices, shuffled[i].index)
    end

    return picked, pickedIndices
end

-- Pick a random restaurant the player can access at their level
-- Avoids the same restaurant back-to-back when possible
local function PickRestaurant(jobCfg, playerLevel, lastRestaurantId)
    local eligible = {}
    for i, rest in ipairs(jobCfg.restaurants) do
        if playerLevel >= rest.minLevel then
            table.insert(eligible, { index = i, restaurant = rest })
        end
    end

    if #eligible == 0 then
        -- Fallback: use first restaurant
        return 1, jobCfg.restaurants[1]
    end

    -- Try to exclude last used restaurant for variety
    if #eligible > 1 and lastRestaurantId then
        local filtered = {}
        for _, r in ipairs(eligible) do
            if r.restaurant.id ~= lastRestaurantId then
                table.insert(filtered, r)
            end
        end
        if #filtered > 0 then
            eligible = filtered
        end
    end

    local pick = eligible[math.random(#eligible)]
    return pick.index, pick.restaurant
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobServerHandlers['pizza_delivery'] = {

    -- ========================================================================
    -- REQUEST BATCH — pick restaurant + delivery locations, send to client
    -- ========================================================================
    onRequestBatch = function(source, activeData, jobCfg)
        -- Initialize pizza-specific state on first batch
        if not activeData.recentLocations then
            activeData.recentLocations = {}
        end
        if not activeData.currentBatch then
            activeData.currentBatch = {}
        end

        local playerLevel = activeData.level or 1

        -- Pick restaurant
        local restIndex, restaurant = PickRestaurant(jobCfg, playerLevel, activeData.lastRestaurantId)
        activeData.lastRestaurantId = restaurant.id
        activeData.currentRestaurantIndex = restIndex

        -- Pick delivery locations from this restaurant's pool
        local locations, indices = PickBatchLocations(restaurant.deliveries, activeData.recentLocations, jobCfg.batchSize)

        -- Store batch state
        activeData.currentBatch = locations

        -- Update recent locations (keep last 30 = 3 batches worth)
        for _, idx in ipairs(indices) do
            table.insert(activeData.recentLocations, idx)
        end
        while #activeData.recentLocations > 30 do
            table.remove(activeData.recentLocations, 1)
        end

        -- Send restaurant + locations to client
        TriggerClientEvent('sb_jobs:client:batchReady', source, {
            restaurant = {
                coords = restaurant.coords,
                label = restaurant.label,
            },
            locations = locations,
        })
    end,

    -- ========================================================================
    -- VALIDATE DELIVERY — check batch bounds + distance anti-exploit
    -- ========================================================================
    onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg)
        if not activeData.currentBatch then return false end
        if deliveryIndex < 1 or deliveryIndex > #activeData.currentBatch then return false end

        -- Anti-exploit: check player proximity to delivery coords
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then
            local pedCoords = GetEntityCoords(ped)
            local target = activeData.currentBatch[deliveryIndex]
            local dist = #(pedCoords - vector3(target.x, target.y, target.z))
            if dist > 20.0 then
                print('[sb_jobs] Anti-exploit: Player ' .. source .. ' too far from delivery point (' .. math.floor(dist) .. 'm)')
                return false
            end
        end

        return true
    end,
}
