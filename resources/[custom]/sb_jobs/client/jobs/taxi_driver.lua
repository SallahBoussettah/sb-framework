-- ============================================================================
-- Taxi Driver — Client Job Logic
-- Registers handlers into the PublicJobHandlers framework
--
-- Flow:
-- 1. Player starts job at Job Center NPC -> vehicle spawns outside
-- 2. Client requests first fare (server picks random pickup + destination)
-- 3. GPS routes to pickup location
-- 4. NPC passenger spawns near pickup, walks to vehicle, enters rear seat
-- 5. GPS routes to destination, quality tracking begins
-- 6. At destination: NPC exits, progress bar, payment
-- 7. Next fare requested automatically
-- 8. To end shift: return vehicle to Job Center (between fares)
-- ============================================================================

-- State
local currentPickup = nil           -- vector4 of current pickup
local currentDestination = nil      -- vector3 of current destination
local passengerPed = nil            -- handle to spawned NPC
local passengerInVehicle = false    -- whether NPC is seated
local passengerExiting = false      -- whether NPC is exiting
local qualityScore = 100            -- starts at 100 per fare
local lastVehicleHealth = 1000      -- for collision detection
local farePhase = 'idle'            -- 'idle' | 'pickup' | 'driving' | 'dropoff'
local pickupBlip = nil
local destBlip = nil
local returnBlip = nil
local hasDoneFare = false           -- at least one fare done (for return check)
local waitingForBatch = false
local offRouteTimer = 0
local offRouteWarned = false
local passengerSpawned = false      -- whether we already spawned the NPC at pickup
local npcWalkingToVehicle = false   -- whether NPC is walking to vehicle

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearPickupBlip()
    if pickupBlip and DoesBlipExist(pickupBlip) then
        RemoveBlip(pickupBlip)
    end
    pickupBlip = nil
end

local function ClearDestBlip()
    if destBlip and DoesBlipExist(destBlip) then
        RemoveBlip(destBlip)
    end
    destBlip = nil
end

local function ClearReturnBlip()
    if returnBlip and DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
    returnBlip = nil
end

local function DeletePassenger()
    if passengerPed and DoesEntityExist(passengerPed) then
        SetEntityAsNoLongerNeeded(passengerPed)
        SetPedAsNoLongerNeeded(passengerPed)
        DeletePed(passengerPed)
    end
    passengerPed = nil
    passengerInVehicle = false
    passengerExiting = false
    passengerSpawned = false
    npcWalkingToVehicle = false
end

local function GetQualityMultiplier(score, jobCfg)
    for _, threshold in ipairs(jobCfg.qualityThresholds) do
        if score >= threshold.min then
            return threshold.multiplier
        end
    end
    return 0.0
end

-- Get distance to the nearest valid job point (pickup, destination, return, vehicle spawn)
local function GetNearestValidDist(playerCoords, jobCfg)
    local nearest = 999999.0

    -- Return point
    if jobCfg.returnPoint then
        local d = #(playerCoords - jobCfg.returnPoint)
        if d < nearest then nearest = d end
    end

    -- Vehicle spawn
    if jobCfg.vehicleSpawn then
        local d = #(playerCoords - vector3(jobCfg.vehicleSpawn.x, jobCfg.vehicleSpawn.y, jobCfg.vehicleSpawn.z))
        if d < nearest then nearest = d end
    end

    -- Current pickup
    if currentPickup then
        local d = #(playerCoords - vector3(currentPickup.x, currentPickup.y, currentPickup.z))
        if d < nearest then nearest = d end
    end

    -- Current destination
    if currentDestination then
        local d = #(playerCoords - currentDestination)
        if d < nearest then nearest = d end
    end

    return nearest
end

-- SpawnPassengerPed is provided by PJ_SpawnPassengerPed() in client/publicjobs.lua

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobHandlers['taxi_driver'] = {

    -- ========================================================================
    -- ON START — Spawn vehicle, request first fare
    -- ========================================================================
    onStart = function(data, jobCfg)
        -- Reset state
        currentPickup = nil
        currentDestination = nil
        DeletePassenger()
        qualityScore = 100
        lastVehicleHealth = 1000
        farePhase = 'idle'
        hasDoneFare = false
        waitingForBatch = true
        offRouteTimer = 0
        offRouteWarned = false

        ClearPickupBlip()
        ClearDestBlip()
        ClearReturnBlip()

        -- Spawn vehicle
        JobVehicle = PJ_SpawnJobVehicle(data.vehicleModel, jobCfg.vehicleSpawn, jobCfg.vehicleSpawnSlots)
        if not JobVehicle then
            TriggerServerEvent('sb_jobs:server:quitPublicJob')
            return
        end

        -- Set plate
        if data.plate then
            SetVehicleNumberPlateText(JobVehicle, data.plate)
        end

        -- Return point blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        exports['sb_notify']:Notify('Taxi Driver job started! Your vehicle is parked outside. Waiting for fare assignment...', 'success', 5000)

        -- Request first fare
        TriggerServerEvent('sb_jobs:server:requestBatch', data.jobId)
    end,

    -- ========================================================================
    -- ON BATCH READY — Received pickup + destination from server
    -- ========================================================================
    onBatchReady = function(data, jobCfg)
        currentPickup = data.pickup
        currentDestination = data.destination
        farePhase = 'pickup'
        qualityScore = 100
        passengerSpawned = false
        npcWalkingToVehicle = false
        passengerInVehicle = false
        passengerExiting = false
        waitingForBatch = false

        -- Clear old blips
        PJ_ClearAllBlips()
        ClearPickupBlip()
        ClearDestBlip()
        ClearReturnBlip()

        -- Pickup blip (person icon, yellow)
        pickupBlip = PJ_CreateLocationBlip(currentPickup, 280, 5, 0.9, 'Passenger Pickup')

        -- Return blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        -- GPS to pickup
        PJ_SetGPSToCoord(currentPickup.x, currentPickup.y, currentPickup.z)

        local areaName = GetLabelText(GetNameOfZone(currentPickup.x, currentPickup.y, currentPickup.z))
        exports['sb_notify']:Notify('Passenger waiting in ' .. areaName .. '. Head there to pick them up!', 'info', 6000)
    end,

    -- ========================================================================
    -- ON TASK COMPLETE — Payment notification, cleanup, next fare
    -- ========================================================================
    onTaskComplete = function(data, jobCfg)
        local payMsg = '$' .. data.pay
        if data.tip > 0 then
            payMsg = payMsg .. ' + $' .. data.tip .. ' tip'
        end
        exports['sb_notify']:Notify('Fare complete! ' .. payMsg .. ' (+' .. data.xp .. ' XP)', 'success', 4000)

        -- Cleanup passenger
        DeletePassenger()
        ClearPickupBlip()
        ClearDestBlip()

        farePhase = 'idle'
        hasDoneFare = true

        -- Request next fare or handle vehicle swap
        if PendingVehicleSwap then
            waitingForBatch = false
            exports['sb_notify']:Notify('Fare complete! Return to the Job Center to swap your vehicle.', 'success', 8000)
            local jobCfg2 = Config.PublicJobs['taxi_driver']
            if jobCfg2 then
                PJ_SetGPSToCoord(jobCfg2.returnPoint.x, jobCfg2.returnPoint.y, jobCfg2.returnPoint.z)
            end
        else
            waitingForBatch = true
            if ActivePublicJobData then
                TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
            end
        end
    end,

    -- ========================================================================
    -- ON END — Clean up all state
    -- ========================================================================
    onEnd = function(jobCfg)
        DeletePassenger()
        ClearPickupBlip()
        ClearDestBlip()
        ClearReturnBlip()

        currentPickup = nil
        currentDestination = nil
        qualityScore = 100
        lastVehicleHealth = 1000
        farePhase = 'idle'
        hasDoneFare = false
        waitingForBatch = false
        offRouteTimer = 0
        offRouteWarned = false
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        exports['sb_notify']:Notify('Taxi shift ended. Your progress has been saved.', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TICK — Proximity checks, NPC management, quality tracking (every 500ms)
    -- ========================================================================
    onTick = function(jobCfg)
        if not ActivePublicJobData then return end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        -- ----------------------------------------------------------------
        -- PHASE: PICKUP — drive to pickup, spawn NPC, wait for them to enter
        -- ----------------------------------------------------------------
        if farePhase == 'pickup' and currentPickup then
            local pickupCoords = vector3(currentPickup.x, currentPickup.y, currentPickup.z)
            local distToPickup = #(playerCoords - pickupCoords)

            -- Spawn NPC when within 30m
            if distToPickup < 30.0 and not passengerSpawned then
                passengerPed = PJ_SpawnPassengerPed(currentPickup, jobCfg)
                if passengerPed then
                    passengerSpawned = true
                else
                    exports['sb_notify']:Notify('Failed to spawn passenger. Requesting new fare...', 'error', 4000)
                    farePhase = 'idle'
                    waitingForBatch = true
                    if ActivePublicJobData then
                        TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
                    end
                    return
                end
            end

            -- When within 5m and stopped, NPC walks to vehicle
            if passengerSpawned and passengerPed and DoesEntityExist(passengerPed) and not npcWalkingToVehicle then
                if distToPickup < 8.0 and JobVehicle and DoesEntityExist(JobVehicle) then
                    local speed = GetEntitySpeed(JobVehicle)
                    if speed < 1.0 then
                        -- NPC walks to rear-right seat (seat index 2)
                        npcWalkingToVehicle = true
                        TaskEnterVehicle(passengerPed, JobVehicle, 10000, 2, 1.0, 1, 0)
                    end
                end
            end

            -- Check if NPC is seated
            if npcWalkingToVehicle and passengerPed and DoesEntityExist(passengerPed) then
                if IsPedInVehicle(passengerPed, JobVehicle, false) then
                    -- Passenger is in! Switch to driving phase
                    passengerInVehicle = true
                    npcWalkingToVehicle = false
                    farePhase = 'driving'

                    -- Clear pickup blip, create destination blip
                    ClearPickupBlip()
                    destBlip = PJ_CreateLocationBlip(currentDestination, 1, 2, 0.9, 'Passenger Destination')

                    -- GPS to destination
                    PJ_SetGPSToCoord(currentDestination.x, currentDestination.y, currentDestination.z)

                    -- Initialize quality tracking
                    qualityScore = 100
                    if JobVehicle and DoesEntityExist(JobVehicle) then
                        lastVehicleHealth = GetVehicleBodyHealth(JobVehicle)
                    end

                    local areaName = GetLabelText(GetNameOfZone(currentDestination.x, currentDestination.y, currentDestination.z))
                    exports['sb_notify']:Notify('Passenger aboard! Drive to ' .. areaName .. '. Drive carefully for a better tip!', 'info', 5000)
                end
            end

            return
        end

        -- ----------------------------------------------------------------
        -- PHASE: DRIVING — track quality, check if near destination
        -- ----------------------------------------------------------------
        if farePhase == 'driving' and currentDestination then
            -- Quality tracking: collision detection
            if JobVehicle and DoesEntityExist(JobVehicle) then
                local currentHealth = GetVehicleBodyHealth(JobVehicle)
                local healthDrop = lastVehicleHealth - currentHealth

                if healthDrop > 50 then
                    -- Collision detected
                    qualityScore = math.max(0, qualityScore - 10)
                    local mult = GetQualityMultiplier(qualityScore, jobCfg)
                    if mult <= 0 then
                        exports['sb_notify']:Notify('Terrible driving! No tip for this fare.', 'error', 3000)
                    elseif qualityScore < 70 then
                        exports['sb_notify']:Notify('Rough driving! Your tip is decreasing...', 'error', 2000)
                    end
                end
                lastVehicleHealth = currentHealth

                -- Check if vehicle is upside down
                if IsEntityUpsidedown(JobVehicle) then
                    qualityScore = math.max(0, qualityScore - 5)
                end
            end

            -- Check if near destination
            local distToDest = #(playerCoords - currentDestination)
            if distToDest < 8.0 then
                -- Check if vehicle is stopped or slow
                if JobVehicle and DoesEntityExist(JobVehicle) then
                    local speed = GetEntitySpeed(JobVehicle)
                    if speed < 2.0 then
                        farePhase = 'dropoff'

                        -- Report quality to server before completing
                        TriggerServerEvent('sb_jobs:server:reportQuality', qualityScore)

                        -- NPC exits vehicle
                        if passengerPed and DoesEntityExist(passengerPed) then
                            passengerExiting = true
                            TaskLeaveVehicle(passengerPed, JobVehicle, 0)

                            -- Wait for exit then walk away
                            CreateThread(function()
                                local exitTimeout = 0
                                while passengerPed and DoesEntityExist(passengerPed) and IsPedInVehicle(passengerPed, JobVehicle, false) do
                                    Wait(200)
                                    exitTimeout = exitTimeout + 200
                                    if exitTimeout > 5000 then break end
                                end

                                -- Make NPC walk away
                                if passengerPed and DoesEntityExist(passengerPed) then
                                    local pedCoords = GetEntityCoords(passengerPed)
                                    local heading = GetEntityHeading(passengerPed)
                                    local rad = math.rad(heading)
                                    local walkTo = vector3(pedCoords.x - math.sin(rad) * 20.0, pedCoords.y + math.cos(rad) * 20.0, pedCoords.z)
                                    TaskGoStraightToCoord(passengerPed, walkTo.x, walkTo.y, walkTo.z, 1.0, 8000, 0.0, 0.0)
                                    SetEntityAsNoLongerNeeded(passengerPed)
                                    SetPedAsNoLongerNeeded(passengerPed)
                                end

                                Wait(2000)
                                -- Clean up ped reference after they walked away
                                if passengerPed and DoesEntityExist(passengerPed) then
                                    DeletePed(passengerPed)
                                end
                                passengerPed = nil
                                passengerInVehicle = false
                                passengerExiting = false
                            end)
                        end

                        -- Progress bar then complete
                        exports['sb_progressbar']:Start({ duration = 2000, label = 'Completing fare...' })
                        Wait(2000)
                        if not ActivePublicJobData then return end

                        ClearDestBlip()

                        -- Complete the delivery (index is always 1 for taxi)
                        TriggerServerEvent('sb_jobs:server:completeDelivery', ActivePublicJobData.jobId, 1)
                        Wait(1000)
                    end
                end
            end

            return
        end

        -- ----------------------------------------------------------------
        -- CHECK: At Job Center return point (vehicle swap or end shift)
        -- Only between fares
        -- ----------------------------------------------------------------
        if farePhase == 'idle' and hasDoneFare and jobCfg.returnPoint then
            local returnDist = #(playerCoords - jobCfg.returnPoint)
            local radius = jobCfg.returnRadius or 8.0

            if returnDist < radius then
                if PendingVehicleSwap then
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Swapping vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    TriggerServerEvent('sb_jobs:server:swapVehicle')
                elseif not waitingForBatch then
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Returning vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    TriggerServerEvent('sb_jobs:server:quitPublicJob')
                end
            end
        end

        -- ----------------------------------------------------------------
        -- ANTI-ABUSE: Off-route vehicle detection
        -- ----------------------------------------------------------------
        if JobVehicle and DoesEntityExist(JobVehicle) and IsPedInVehicle(ped, JobVehicle, false) then
            local nearestDist = GetNearestValidDist(playerCoords, jobCfg)

            if nearestDist > 400.0 then
                offRouteTimer = offRouteTimer + 0.5

                if offRouteTimer >= 30.0 and not offRouteWarned then
                    offRouteWarned = true
                    exports['sb_notify']:Notify('You are going off-route! Return to your fare area or your vehicle will be confiscated and you will be fined $100.', 'error', 10000)
                end

                if offRouteTimer >= 60.0 then
                    PJ_DeleteJobVehicle()
                    DeletePassenger()
                    TriggerServerEvent('sb_jobs:server:vehicleConfiscated')
                    return
                end
            else
                offRouteTimer = 0
                offRouteWarned = false
            end
        else
            offRouteTimer = 0
            offRouteWarned = false
        end
    end,
}
