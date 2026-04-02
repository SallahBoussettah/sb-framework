-- ============================================================================
-- Bus Driver — Server Job Logic
-- Registers handlers into the PublicJobServerHandlers framework
--
-- Key responsibilities:
--   1. Pick random route (avoid repeat)
--   2. Validate delivery (proximity to last stop)
--   3. Calculate tip: per-passenger bonus + on-time bonus + random tip
--   4. Receive route stats from client
-- ============================================================================

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobServerHandlers['bus_driver'] = {

    -- ========================================================================
    -- REQUEST BATCH — pick random route, send to client
    -- ========================================================================
    onRequestBatch = function(source, activeData, jobCfg)
        local routes = jobCfg.routes
        if not routes or #routes == 0 then
            print('[sb_jobs] Bus Driver: No routes configured')
            return
        end

        -- Pick random route (avoid last used)
        local eligible = {}
        for i = 1, #routes do
            if i ~= activeData.lastRouteIndex then
                table.insert(eligible, i)
            end
        end

        if #eligible == 0 then
            eligible = { 1 }
        end

        local routeIndex = eligible[math.random(#eligible)]
        activeData.lastRouteIndex = routeIndex

        -- Store route info for validation
        local route = routes[routeIndex]
        activeData.currentRouteIndex = routeIndex
        activeData.currentBatch = { route } -- framework expects currentBatch
        activeData.busRouteStats = nil -- reset stats for new route

        -- Store last stop coords for delivery validation
        if route.stops and #route.stops > 0 then
            local lastStop = route.stops[#route.stops]
            activeData.lastStopCoords = lastStop.coords
        end

        -- Send to client
        TriggerClientEvent('sb_jobs:client:batchReady', source, {
            routeIndex = routeIndex,
        })
    end,

    -- ========================================================================
    -- VALIDATE DELIVERY — check player is near last stop
    -- ========================================================================
    onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg)
        if not activeData.lastStopCoords then return false end

        -- Anti-exploit: check player proximity to last stop
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then
            local pedCoords = GetEntityCoords(ped)
            local target = activeData.lastStopCoords
            local dist = #(pedCoords - vector3(target.x, target.y, target.z))
            if dist > 30.0 then
                print('[sb_jobs] Anti-exploit: Bus driver player ' .. source .. ' too far from last stop (' .. math.floor(dist) .. 'm)')
                return false
            end
        end

        return true
    end,

    -- ========================================================================
    -- CALCULATE TIP — per-passenger bonus + on-time bonus + random tip
    -- All bundled as "tip" since framework only has base + tip
    -- ========================================================================
    onCalculateTip = function(source, activeData, jobCfg)
        local stats = activeData.busRouteStats or {}
        local delivered = math.min(stats.totalDelivered or 0, 50) -- cap at 50
        local onTime = stats.onTime or false

        -- Per-passenger bonus
        local perPassengerBonus = jobCfg.perPassengerBonus or 8
        local passengerPay = delivered * perPassengerBonus

        -- On-time bonus (per passenger delivered)
        local onTimePay = 0
        if onTime then
            local onTimeBonusPerPassenger = jobCfg.onTimeBonus or 5
            onTimePay = delivered * onTimeBonusPerPassenger
        end

        -- Random tip
        local randomTip = math.random(jobCfg.tipMin, jobCfg.tipMax)

        return passengerPay + onTimePay + randomTip
    end,
}

-- ============================================================================
-- RECEIVE ROUTE STATS FROM CLIENT
-- ============================================================================

RegisterNetEvent('sb_jobs:server:reportBusRouteStats', function(stats)
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'bus_driver' then return end

    -- Validate and cap stats to prevent exploits
    if type(stats) ~= 'table' then return end

    active.busRouteStats = {
        totalDelivered = math.min(tonumber(stats.totalDelivered) or 0, 50),
        totalBoarded = math.min(tonumber(stats.totalBoarded) or 0, 50),
        onTime = stats.onTime == true,
    }
end)
