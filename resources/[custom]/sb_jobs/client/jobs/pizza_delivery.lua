-- ============================================================================
-- Pizza Delivery — Client Job Logic
-- Registers handlers into the PublicJobHandlers framework
--
-- Flow:
-- 1. Player starts job at Job Center NPC → vehicle spawns outside
-- 2. Client immediately requests a batch (server picks restaurant + locations)
-- 3. GPS routes to assigned restaurant
-- 4. At restaurant: progress bar "Loading 10 pizzas..."
-- 5. Delivery blips appear, GPS to first delivery
-- 6. Deliver all 10 → client requests next batch (new restaurant assigned)
-- 7. GPS routes to new restaurant → repeat from step 4
-- 8. To end shift: return vehicle to Job Center area (between batches)
-- ============================================================================

-- State
local currentRestaurant = nil   -- { coords = vector4, label = string }
local deliveryQueue = {}
local deliveredSet = {}         -- deliveredSet[index] = true when delivered
local deliveredCount = 0        -- How many delivered in current batch
local headingToRestaurant = false
local batchActive = false
local isLoading = false
local returnBlip = nil
local restaurantBlip = nil
local hasPizzas = false         -- At least one batch loaded (for return vehicle check)
local waitingForBatch = false   -- True while waiting for server to assign next batch
local offRouteTimer = 0         -- Seconds spent off-route (in vehicle, far from all valid points)
local offRouteWarned = false    -- Whether warning was shown

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearRestaurantBlip()
    if restaurantBlip and DoesBlipExist(restaurantBlip) then
        RemoveBlip(restaurantBlip)
    end
    restaurantBlip = nil
end

local function ClearReturnBlip()
    if returnBlip and DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
    returnBlip = nil
end

-- Get distance to the nearest valid job point (restaurant, deliveries, return, vehicle spawn)
local function GetNearestValidDist(playerCoords, jobCfg)
    local nearest = 999999.0

    -- Return point (always valid)
    if jobCfg.returnPoint then
        local d = #(playerCoords - jobCfg.returnPoint)
        if d < nearest then nearest = d end
    end

    -- Vehicle spawn (valid at start)
    if jobCfg.vehicleSpawn then
        local d = #(playerCoords - vector3(jobCfg.vehicleSpawn.x, jobCfg.vehicleSpawn.y, jobCfg.vehicleSpawn.z))
        if d < nearest then nearest = d end
    end

    -- Current restaurant
    if currentRestaurant and currentRestaurant.coords then
        local c = currentRestaurant.coords
        local d = #(playerCoords - vector3(c.x, c.y, c.z))
        if d < nearest then nearest = d end
    end

    -- All delivery locations in current batch
    for _, loc in ipairs(deliveryQueue) do
        local d = #(playerCoords - loc)
        if d < nearest then nearest = d end
    end

    return nearest
end

local function CreateRestaurantBlip(restaurant)
    ClearRestaurantBlip()
    restaurantBlip = PJ_CreateLocationBlip(restaurant.coords, 267, 17, 0.9, restaurant.label)
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobHandlers['pizza_delivery'] = {

    -- ========================================================================
    -- ON START — Spawn vehicle, request first batch (gets restaurant assignment)
    -- ========================================================================
    onStart = function(data, jobCfg)
        -- Reset state
        currentRestaurant = nil
        deliveryQueue = {}
        deliveredSet = {}
        deliveredCount = 0
        headingToRestaurant = false
        batchActive = false
        isLoading = false
        hasPizzas = false
        waitingForBatch = true
        offRouteTimer = 0
        offRouteWarned = false

        -- Spawn vehicle outside Job Center (player walks to it)
        JobVehicle = PJ_SpawnJobVehicle(data.vehicleModel, jobCfg.vehicleSpawn, jobCfg.vehicleSpawnSlots)
        if not JobVehicle then
            TriggerServerEvent('sb_jobs:server:quitPublicJob')
            return
        end

        -- Set the plate from server
        if data.plate then
            SetVehicleNumberPlateText(JobVehicle, data.plate)
        end

        -- Return point blip (Job Center — to end shift)
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        exports['sb_notify']:Notify('Pizza Delivery job started! Your vehicle is parked outside. Waiting for restaurant assignment...', 'success', 5000)

        -- Request first batch — server picks a restaurant + delivery locations
        TriggerServerEvent('sb_jobs:server:requestBatch', data.jobId)
    end,

    -- ========================================================================
    -- ON BATCH READY — Received restaurant + locations from server
    -- ========================================================================
    onBatchReady = function(data, jobCfg)
        local restaurant = data.restaurant
        local locations = data.locations

        -- Store state
        currentRestaurant = restaurant
        deliveryQueue = locations
        deliveredSet = {}
        deliveredCount = 0
        headingToRestaurant = true
        batchActive = false
        waitingForBatch = false

        -- Clear old delivery blips, recreate persistent blips
        PJ_ClearAllBlips()
        ClearReturnBlip()

        -- Restaurant blip + GPS
        CreateRestaurantBlip(restaurant)
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        PJ_SetGPSToCoord(restaurant.coords.x, restaurant.coords.y, restaurant.coords.z)
        exports['sb_notify']:Notify('Head to ' .. restaurant.label .. ' to pick up pizzas!', 'info', 6000)
    end,

    -- ========================================================================
    -- ON TASK COMPLETE — Remove blip, GPS to next or request new batch
    -- ========================================================================
    onTaskComplete = function(data, jobCfg)
        local payMsg = '$' .. data.pay
        if data.tip > 0 then
            payMsg = payMsg .. ' + $' .. data.tip .. ' tip'
        end
        exports['sb_notify']:Notify('Delivery #' .. data.index .. ' complete! ' .. payMsg .. ' (+' .. data.xp .. ' XP)', 'success', 4000)

        -- Mark as delivered
        deliveredSet[data.index] = true
        deliveredCount = deliveredCount + 1

        -- Remove delivered blip
        if JobBlips[data.index] and DoesBlipExist(JobBlips[data.index]) then
            RemoveBlip(JobBlips[data.index])
            JobBlips[data.index] = nil
        end

        -- Check if batch done or GPS to nearest remaining
        if deliveredCount >= #deliveryQueue then
            -- Batch complete
            batchActive = false

            if PendingVehicleSwap then
                waitingForBatch = false
                exports['sb_notify']:Notify('Batch complete! Return to the Job Center to swap your vehicle.', 'success', 8000)
                PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
            else
                waitingForBatch = true
                exports['sb_notify']:Notify('Batch complete! Getting next restaurant assignment... Or return your vehicle to the Job Center to end your shift.', 'success', 8000)

                if ActivePublicJobData then
                    TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
                end
            end
        else
            -- GPS to nearest remaining delivery
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearestIdx, nearestDist = nil, 999999.0
            for i, loc in ipairs(deliveryQueue) do
                if not deliveredSet[i] then
                    local d = #(playerCoords - loc)
                    if d < nearestDist then
                        nearestIdx = i
                        nearestDist = d
                    end
                end
            end
            if nearestIdx then
                PJ_SetGPSToCoord(deliveryQueue[nearestIdx].x, deliveryQueue[nearestIdx].y, deliveryQueue[nearestIdx].z)
            end
            local remaining = #deliveryQueue - deliveredCount
            exports['sb_notify']:Notify(remaining .. ' deliveries remaining', 'info', 3000)
        end
    end,

    -- ========================================================================
    -- ON END — Clean up local state
    -- ========================================================================
    onEnd = function(jobCfg)
        currentRestaurant = nil
        deliveryQueue = {}
        deliveredSet = {}
        deliveredCount = 0
        headingToRestaurant = false
        batchActive = false
        isLoading = false
        hasPizzas = false
        waitingForBatch = false
        offRouteTimer = 0
        offRouteWarned = false
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil
        ClearRestaurantBlip()
        ClearReturnBlip()
        exports['sb_notify']:Notify('Pizza delivery shift ended. Your progress has been saved.', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TICK — Proximity checks (every 500ms)
    -- ========================================================================
    onTick = function(jobCfg)
        if not ActivePublicJobData then return end
        if isLoading then return end -- Don't run checks while loading

        local playerCoords = GetEntityCoords(PlayerPedId())

        -- ----------------------------------------------------------------
        -- PHASE 1: Heading to restaurant — check if arrived
        -- ----------------------------------------------------------------
        if headingToRestaurant and currentRestaurant then
            local restCoords = currentRestaurant.coords
            local pickupDist = #(playerCoords - vector3(restCoords.x, restCoords.y, restCoords.z))

            if pickupDist < 5.0 then
                -- Must be in or near the job vehicle to pick up
                if not JobVehicle or not DoesEntityExist(JobVehicle) then
                    exports['sb_notify']:Notify('You need your job vehicle to pick up pizzas!', 'error', 4000)
                    Wait(3000)
                    return
                end

                local vehDist = #(playerCoords - GetEntityCoords(JobVehicle))
                if vehDist > 10.0 then
                    exports['sb_notify']:Notify('Bring your job vehicle here first!', 'error', 4000)
                    Wait(3000)
                    return
                end

                isLoading = true
                headingToRestaurant = false

                exports['sb_progressbar']:Start({ duration = 5000, label = 'Loading 10 pizzas...' })
                Wait(5000)
                if not ActivePublicJobData then return end

                isLoading = false
                hasPizzas = true

                -- Now enter delivery phase — show all delivery blips
                batchActive = true

                -- Create numbered delivery blips
                for i, loc in ipairs(deliveryQueue) do
                    JobBlips[i] = PJ_CreateNumberedBlip(loc, i, 'Delivery #' .. i)
                end

                -- GPS to nearest delivery
                local nearestIdx, nearestDist = nil, 999999.0
                for i, loc in ipairs(deliveryQueue) do
                    if not deliveredSet[i] then
                        local d = #(GetEntityCoords(PlayerPedId()) - loc)
                        if d < nearestDist then
                            nearestIdx = i
                            nearestDist = d
                        end
                    end
                end
                if nearestIdx then
                    PJ_SetGPSToCoord(deliveryQueue[nearestIdx].x, deliveryQueue[nearestIdx].y, deliveryQueue[nearestIdx].z)
                end

                exports['sb_notify']:Notify('Pizzas loaded! Deliver to any location — your choice!', 'info', 5000)
            end
            return -- Don't check other things while heading to restaurant
        end

        -- ----------------------------------------------------------------
        -- PHASE 2: Delivering — check if at ANY undelivered point
        -- ----------------------------------------------------------------
        if batchActive and deliveredCount < #deliveryQueue then
            -- Find which undelivered location the player is near
            local nearIdx = nil
            for i, loc in ipairs(deliveryQueue) do
                if not deliveredSet[i] then
                    local d = #(playerCoords - loc)
                    if d < 4.0 then
                        nearIdx = i
                        break
                    end
                end
            end

            if nearIdx then
                -- Must have job vehicle nearby to deliver
                if not JobVehicle or not DoesEntityExist(JobVehicle) then
                    exports['sb_notify']:Notify('You need your job vehicle to make deliveries!', 'error', 4000)
                    Wait(3000)
                    return
                end

                local vehDist = #(playerCoords - GetEntityCoords(JobVehicle))
                if vehDist > 15.0 then
                    exports['sb_notify']:Notify('Bring your job vehicle closer!', 'error', 4000)
                    Wait(3000)
                    return
                end

                isLoading = true
                exports['sb_progressbar']:Start({ duration = 3000, label = 'Delivering pizza #' .. nearIdx .. '...' })
                Wait(3000)
                if not ActivePublicJobData then return end
                isLoading = false
                TriggerServerEvent('sb_jobs:server:completeDelivery', ActivePublicJobData.jobId, nearIdx)
                Wait(1000)
            end
        end

        -- ----------------------------------------------------------------
        -- CHECK: At Job Center return point (vehicle swap or end shift)
        -- Only available when NOT in the middle of delivering
        -- ----------------------------------------------------------------
        if not batchActive and not headingToRestaurant and hasPizzas and jobCfg.returnPoint then
            local returnDist = #(playerCoords - jobCfg.returnPoint)
            local radius = jobCfg.returnRadius or 8.0

            if returnDist < radius then
                if PendingVehicleSwap then
                    -- Vehicle swap — player returned to swap their vehicle
                    isLoading = true
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Swapping vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    isLoading = false
                    TriggerServerEvent('sb_jobs:server:swapVehicle')
                elseif not waitingForBatch then
                    -- Normal quit — return vehicle to end shift
                    isLoading = true
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Returning vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    isLoading = false
                    TriggerServerEvent('sb_jobs:server:quitPublicJob')
                end
            end
        end

        -- ----------------------------------------------------------------
        -- ANTI-ABUSE: Off-route vehicle detection
        -- If player is in job vehicle and >400m from ALL valid points
        -- for 30s → warning, 60s → confiscate vehicle + $100 fine
        -- ----------------------------------------------------------------
        local ped = PlayerPedId()
        if JobVehicle and DoesEntityExist(JobVehicle) and IsPedInVehicle(ped, JobVehicle, false) then
            local nearestDist = GetNearestValidDist(playerCoords, jobCfg)

            if nearestDist > 400.0 then
                offRouteTimer = offRouteTimer + 0.5 -- tick is every 500ms

                if offRouteTimer >= 30.0 and not offRouteWarned then
                    offRouteWarned = true
                    exports['sb_notify']:Notify('You are going off-route! Return to your delivery area or your vehicle will be confiscated and you will be fined $100.', 'error', 10000)
                end

                if offRouteTimer >= 60.0 then
                    -- Confiscate vehicle + fine
                    PJ_DeleteJobVehicle()
                    TriggerServerEvent('sb_jobs:server:vehicleConfiscated')
                    return
                end
            else
                offRouteTimer = 0
                offRouteWarned = false
            end
        else
            -- Not in job vehicle, reset timer
            offRouteTimer = 0
            offRouteWarned = false
        end
    end,
}
