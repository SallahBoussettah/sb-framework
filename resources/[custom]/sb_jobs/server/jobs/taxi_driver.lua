-- ============================================================================
-- Taxi Driver — Server Job Logic
-- Registers handlers into the PublicJobServerHandlers framework
--
-- Key responsibilities:
--   1. Pick random pickup + destination (min distance apart, avoid repeats)
--   2. Validate delivery (proximity check to destination)
--   3. Calculate quality-based tips
-- ============================================================================

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetDistance3D(a, b)
    return #(vector3(a.x, a.y, a.z or 0) - vector3(b.x, b.y, b.z or 0))
end

-- Pick a random pickup location, avoiding the last used one
local function PickRandomPickup(jobCfg, lastPickupIndex)
    local pickups = jobCfg.pickupLocations
    if not pickups or #pickups == 0 then return nil, nil end

    -- Build eligible list (exclude last used)
    local eligible = {}
    for i, loc in ipairs(pickups) do
        if i ~= lastPickupIndex then
            table.insert(eligible, { index = i, coords = loc })
        end
    end

    -- Fallback if only one pickup exists
    if #eligible == 0 then
        return 1, pickups[1]
    end

    local pick = eligible[math.random(#eligible)]
    return pick.index, pick.coords
end

-- Pick a random destination that is at least minDist from the pickup
local function PickRandomDestination(jobCfg, pickupCoords, lastDestIndex)
    local destinations = jobCfg.destinationLocations
    local minDist = jobCfg.minFareDistance or 500
    if not destinations or #destinations == 0 then return nil, nil end

    -- Build eligible list (far enough from pickup, not last used)
    local eligible = {}
    for i, loc in ipairs(destinations) do
        local dist = GetDistance3D(pickupCoords, loc)
        if dist >= minDist and i ~= lastDestIndex then
            table.insert(eligible, { index = i, coords = loc })
        end
    end

    -- If none far enough, relax the constraint
    if #eligible == 0 then
        for i, loc in ipairs(destinations) do
            if i ~= lastDestIndex then
                table.insert(eligible, { index = i, coords = loc })
            end
        end
    end

    -- Final fallback
    if #eligible == 0 then
        return 1, destinations[1]
    end

    local pick = eligible[math.random(#eligible)]
    return pick.index, pick.coords
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobServerHandlers['taxi_driver'] = {

    -- ========================================================================
    -- REQUEST BATCH — pick random pickup + destination, send to client
    -- ========================================================================
    onRequestBatch = function(source, activeData, jobCfg)
        -- Initialize taxi-specific state
        if not activeData.lastPickupIndex then
            activeData.lastPickupIndex = nil
        end
        if not activeData.lastDestIndex then
            activeData.lastDestIndex = nil
        end

        -- Pick random pickup
        local pickupIdx, pickupCoords = PickRandomPickup(jobCfg, activeData.lastPickupIndex)
        if not pickupCoords then
            print('[sb_jobs] Taxi: No pickup locations configured')
            return
        end
        activeData.lastPickupIndex = pickupIdx

        -- Pick random destination (min distance from pickup)
        local destIdx, destCoords = PickRandomDestination(jobCfg, pickupCoords, activeData.lastDestIndex)
        if not destCoords then
            print('[sb_jobs] Taxi: No destination locations configured')
            return
        end
        activeData.lastDestIndex = destIdx

        -- Store for validation
        activeData.currentDestination = destCoords
        activeData.currentBatch = { destCoords } -- framework expects currentBatch for validation
        activeData.qualityScore = 100 -- reset quality for new fare

        -- Send to client
        TriggerClientEvent('sb_jobs:client:batchReady', source, {
            pickup = pickupCoords,
            destination = destCoords,
        })
    end,

    -- ========================================================================
    -- VALIDATE DELIVERY — check player is near destination
    -- ========================================================================
    onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg)
        if not activeData.currentDestination then return false end

        -- Anti-exploit: check player proximity to destination
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then
            local pedCoords = GetEntityCoords(ped)
            local target = activeData.currentDestination
            local dist = #(pedCoords - vector3(target.x, target.y, target.z))
            if dist > 25.0 then
                print('[sb_jobs] Anti-exploit: Taxi player ' .. source .. ' too far from destination (' .. math.floor(dist) .. 'm)')
                return false
            end
        end

        return true
    end,

    -- ========================================================================
    -- CALCULATE TIP — quality-based tip (overrides generic random tip)
    -- ========================================================================
    onCalculateTip = function(source, activeData, jobCfg)
        local quality = activeData.qualityScore or 100

        -- Find multiplier from quality thresholds
        local multiplier = 0.0
        for _, threshold in ipairs(jobCfg.qualityThresholds) do
            if quality >= threshold.min then
                multiplier = threshold.multiplier
                break
            end
        end

        -- Calculate tip: random base × quality multiplier
        local baseTip = math.random(jobCfg.tipMin, jobCfg.tipMax)
        local tip = math.floor(baseTip * multiplier)

        return tip
    end,
}
