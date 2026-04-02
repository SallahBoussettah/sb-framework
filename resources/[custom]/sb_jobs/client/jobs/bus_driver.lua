-- ============================================================================
-- Bus Driver — Client Job Logic
-- Registers handlers into the PublicJobHandlers framework
--
-- Flow:
-- 1. Player starts job at Job Center NPC -> bus spawns outside
-- 2. Client requests first route (server picks random route)
-- 3. GPS routes to first stop with blip
-- 4. At each stop: doors open, exiting NPCs leave, new NPCs board
-- 5. Advance to next stop until route complete
-- 6. On route complete: all passengers exit, stats reported, payment
-- 7. Next route requested automatically
-- 8. To end shift: return vehicle to Job Center (between routes)
-- ============================================================================

-- ============================================================================
-- STATE
-- ============================================================================

local currentRoute = nil            -- route table from config
local currentStopIndex = 0          -- which stop we're heading to (1-based)
local routeStartTime = 0            -- GetGameTimer() when route started
local passengers = {}               -- array of { ped, seatIndex, boardedAtStop, exitsAtStop }
local occupiedSeats = {}            -- map of seatIndex -> true
local routePhase = 'idle'           -- idle | driving_to_stop | at_stop_processing | driving_to_next | route_complete
local totalPassengersDelivered = 0  -- passengers who exited at their stop this route
local totalPassengersBoarded = 0    -- passengers who boarded this route
local hasDoneRoute = false          -- at least one route done (for return check)
local waitingForBatch = false
local offRouteTimer = 0
local offRouteWarned = false
local routesCompletedThisCycle = 0   -- routes done in current 10-route cycle
local cooldownActive = false         -- true during 10min cooldown
local cooldownEndTime = 0            -- GetGameTimer() when cooldown ends
local stopBlip = nil
local returnBlip = nil
local processingStop = false         -- lock to prevent re-entry into stop processing

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearStopBlip()
    if stopBlip and DoesBlipExist(stopBlip) then
        RemoveBlip(stopBlip)
    end
    stopBlip = nil
end

local function ClearReturnBlip()
    if returnBlip and DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
    returnBlip = nil
end

local function DeleteAllPassengers()
    for _, p in ipairs(passengers) do
        if p.ped and DoesEntityExist(p.ped) then
            SetEntityAsNoLongerNeeded(p.ped)
            SetPedAsNoLongerNeeded(p.ped)
            DeletePed(p.ped)
        end
    end
    passengers = {}
    occupiedSeats = {}
end

-- SpawnPassengerPed is provided by PJ_SpawnPassengerPed() in client/publicjobs.lua

local function GetAvailableSeat(jobCfg)
    local vehicleModel = 'bus'
    if ActivePublicJobData then
        vehicleModel = ActivePublicJobData.vehicleModel or 'bus'
    end
    local seats = jobCfg.vehicleSeats[vehicleModel] or jobCfg.vehicleSeats['bus']

    for _, seatIdx in ipairs(seats) do
        if not occupiedSeats[seatIdx] then
            return seatIdx
        end
    end
    return nil -- bus is full
end

local function GetMaxSeats(jobCfg)
    local vehicleModel = 'bus'
    if ActivePublicJobData then
        vehicleModel = ActivePublicJobData.vehicleModel or 'bus'
    end
    local seats = jobCfg.vehicleSeats[vehicleModel] or jobCfg.vehicleSeats['bus']
    return #seats
end

local function SetBusDoors(vehicle, open)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    if open then
        SetVehicleDoorOpen(vehicle, 0, false, false) -- front left
        SetVehicleDoorOpen(vehicle, 1, false, false) -- front right
    else
        SetVehicleDoorShut(vehicle, 0, false)
        SetVehicleDoorShut(vehicle, 1, false)
    end
end

-- Get distance to the nearest valid job point (current stop, return, vehicle spawn)
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

    -- Current stop
    if currentRoute and currentStopIndex > 0 and currentStopIndex <= #currentRoute.stops then
        local stop = currentRoute.stops[currentStopIndex]
        local d = #(playerCoords - vector3(stop.coords.x, stop.coords.y, stop.coords.z))
        if d < nearest then nearest = d end
    end

    return nearest
end

local function SetGPSToStop(stop)
    if stop and stop.coords then
        PJ_SetGPSToCoord(stop.coords.x, stop.coords.y, stop.coords.z)
    end
end

local function CreateStopBlip(stop, index, totalStops)
    ClearStopBlip()
    if stop and stop.coords then
        stopBlip = PJ_CreateLocationBlip(stop.coords, 513, 5, 0.9, 'Stop ' .. index .. '/' .. totalStops .. ' - ' .. stop.label)
    end
end

-- ============================================================================
-- STOP PROCESSING — async thread handles exit + board phases
-- ============================================================================

local function ProcessStop(jobCfg)
    if processingStop then return end
    processingStop = true

    CreateThread(function()
        local stopCoords = currentRoute.stops[currentStopIndex].coords
        local stopIndex = currentStopIndex
        local totalStops = #currentRoute.stops

        -- Open bus doors
        if JobVehicle and DoesEntityExist(JobVehicle) then
            SetBusDoors(JobVehicle, true)
        end

        exports['sb_notify']:Notify('Stop ' .. stopIndex .. '/' .. totalStops .. ': ' .. currentRoute.stops[stopIndex].label, 'info', 3000)

        -- ============================
        -- EXIT PHASE: passengers whose exitsAtStop == currentStopIndex
        -- ============================
        local exiting = {}
        local remaining = {}
        for _, p in ipairs(passengers) do
            if p.exitsAtStop == stopIndex then
                table.insert(exiting, p)
            else
                table.insert(remaining, p)
            end
        end

        for _, p in ipairs(exiting) do
            if p.ped and DoesEntityExist(p.ped) then
                TaskLeaveVehicle(p.ped, JobVehicle, 0)
            end
            occupiedSeats[p.seatIndex] = nil
        end

        -- Wait for them to exit
        if #exiting > 0 then
            local exitTimeout = 0
            local allExited = false
            while exitTimeout < 8000 and not allExited do
                Wait(300)
                exitTimeout = exitTimeout + 300
                allExited = true
                for _, p in ipairs(exiting) do
                    if p.ped and DoesEntityExist(p.ped) and IsPedInVehicle(p.ped, JobVehicle, false) then
                        allExited = false
                        break
                    end
                end
            end

            -- Walk away and delete
            for _, p in ipairs(exiting) do
                if p.ped and DoesEntityExist(p.ped) then
                    local pedCoords = GetEntityCoords(p.ped)
                    local heading = GetEntityHeading(p.ped)
                    local rad = math.rad(heading)
                    local walkDist = jobCfg.npcWalkAwayDistance or 25.0
                    local walkTo = vector3(
                        pedCoords.x - math.sin(rad) * walkDist,
                        pedCoords.y + math.cos(rad) * walkDist,
                        pedCoords.z
                    )
                    TaskGoStraightToCoord(p.ped, walkTo.x, walkTo.y, walkTo.z, 1.0, 8000, 0.0, 0.0)
                    SetEntityAsNoLongerNeeded(p.ped)
                    SetPedAsNoLongerNeeded(p.ped)
                    totalPassengersDelivered = totalPassengersDelivered + 1
                end
            end

            -- Schedule deletion of exiting peds
            local exitingPeds = {}
            for _, p in ipairs(exiting) do
                if p.ped and DoesEntityExist(p.ped) then
                    table.insert(exitingPeds, p.ped)
                end
            end

            if #exitingPeds > 0 then
                CreateThread(function()
                    Wait(jobCfg.npcDeleteDelay or 5000)
                    for _, ped in ipairs(exitingPeds) do
                        if DoesEntityExist(ped) then
                            DeletePed(ped)
                        end
                    end
                end)
            end

            if #exiting > 0 then
                exports['sb_notify']:Notify(#exiting .. ' passenger(s) dropped off.', 'success', 2000)
            end
        end

        passengers = remaining

        -- ============================
        -- LAST STOP: all remaining passengers exit, route complete
        -- ============================
        if stopIndex == totalStops then
            -- Exit all remaining passengers
            for _, p in ipairs(passengers) do
                if p.ped and DoesEntityExist(p.ped) then
                    TaskLeaveVehicle(p.ped, JobVehicle, 0)
                    occupiedSeats[p.seatIndex] = nil
                end
            end

            if #passengers > 0 then
                Wait(3000)
                for _, p in ipairs(passengers) do
                    if p.ped and DoesEntityExist(p.ped) then
                        totalPassengersDelivered = totalPassengersDelivered + 1
                        local pedCoords = GetEntityCoords(p.ped)
                        local heading = GetEntityHeading(p.ped)
                        local rad = math.rad(heading)
                        local walkDist = jobCfg.npcWalkAwayDistance or 25.0
                        local walkTo = vector3(
                            pedCoords.x - math.sin(rad) * walkDist,
                            pedCoords.y + math.cos(rad) * walkDist,
                            pedCoords.z
                        )
                        TaskGoStraightToCoord(p.ped, walkTo.x, walkTo.y, walkTo.z, 1.0, 8000, 0.0, 0.0)
                        SetEntityAsNoLongerNeeded(p.ped)
                        SetPedAsNoLongerNeeded(p.ped)
                    end
                end

                -- Schedule deletion
                local lastPeds = {}
                for _, p in ipairs(passengers) do
                    if p.ped and DoesEntityExist(p.ped) then
                        table.insert(lastPeds, p.ped)
                    end
                end
                passengers = {}
                occupiedSeats = {}

                if #lastPeds > 0 then
                    CreateThread(function()
                        Wait(jobCfg.npcDeleteDelay or 5000)
                        for _, ped in ipairs(lastPeds) do
                            if DoesEntityExist(ped) then
                                DeletePed(ped)
                            end
                        end
                    end)
                end
            end

            -- Close doors
            if JobVehicle and DoesEntityExist(JobVehicle) then
                SetBusDoors(JobVehicle, false)
            end

            routePhase = 'route_complete'
            processingStop = false
            return
        end

        -- ============================
        -- BOARD PHASE: spawn 1-4 new passengers
        -- ============================
        local emptyChance = jobCfg.emptyStopChance or 0.30
        local doBoard = math.random() > emptyChance

        if doBoard then
            local minP = jobCfg.minPassengersPerStop or 1
            local maxP = jobCfg.maxPassengersPerStop or 4
            local numToBoard = math.random(minP, maxP)

            local boarded = 0
            for i = 1, numToBoard do
                local seat = GetAvailableSeat(jobCfg)
                if not seat then break end -- bus full

                -- Spawn NPC near stop
                local spawnDist = jobCfg.npcSpawnDistance or 15.0
                local angle = math.rad(math.random(0, 359))
                local spawnCoords = vector4(
                    stopCoords.x + math.cos(angle) * spawnDist,
                    stopCoords.y + math.sin(angle) * spawnDist,
                    stopCoords.z,
                    stopCoords.w or 0.0
                )

                local ped = PJ_SpawnPassengerPed(spawnCoords, jobCfg)
                if ped then
                    -- Determine exit stop: at least 2 stops ahead, max last stop
                    local minExit = math.min(stopIndex + 2, totalStops)
                    local exitStop = math.random(minExit, totalStops)

                    occupiedSeats[seat] = true
                    local passengerData = {
                        ped = ped,
                        seatIndex = seat,
                        boardedAtStop = stopIndex,
                        exitsAtStop = exitStop,
                    }
                    table.insert(passengers, passengerData)

                    -- Task NPC to enter vehicle
                    TaskEnterVehicle(ped, JobVehicle, (jobCfg.boardTimeout or 15000), seat, 1.0, 1, 0)
                    boarded = boarded + 1
                    totalPassengersBoarded = totalPassengersBoarded + 1
                end
            end

            -- Wait for all to board (or timeout with fallback teleport)
            if boarded > 0 then
                local boardWait = 0
                local boardTimeoutMs = jobCfg.boardTimeout or 15000
                while boardWait < boardTimeoutMs do
                    Wait(500)
                    boardWait = boardWait + 500

                    -- Check if all new passengers are in
                    local allIn = true
                    for _, p in ipairs(passengers) do
                        if p.boardedAtStop == stopIndex and p.ped and DoesEntityExist(p.ped) then
                            if not IsPedInVehicle(p.ped, JobVehicle, false) then
                                allIn = false
                                break
                            end
                        end
                    end
                    if allIn then break end
                end

                -- Fallback: teleport stuck NPCs into their seats
                for _, p in ipairs(passengers) do
                    if p.boardedAtStop == stopIndex and p.ped and DoesEntityExist(p.ped) then
                        if not IsPedInVehicle(p.ped, JobVehicle, false) then
                            SetPedIntoVehicle(p.ped, JobVehicle, p.seatIndex)
                        end
                    end
                end

                exports['sb_notify']:Notify(boarded .. ' passenger(s) boarded.', 'info', 2000)
            end
        end

        -- Close doors and advance to next stop
        if JobVehicle and DoesEntityExist(JobVehicle) then
            SetBusDoors(JobVehicle, false)
        end

        currentStopIndex = currentStopIndex + 1

        if currentStopIndex <= totalStops then
            local nextStop = currentRoute.stops[currentStopIndex]
            CreateStopBlip(nextStop, currentStopIndex, totalStops)
            SetGPSToStop(nextStop)
            routePhase = 'driving_to_next'
            exports['sb_notify']:Notify('Next stop: ' .. nextStop.label .. ' (' .. currentStopIndex .. '/' .. totalStops .. ')', 'info', 4000)
        end

        processingStop = false
    end)
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobHandlers['bus_driver'] = {

    -- ========================================================================
    -- ON START — Spawn vehicle, request first route
    -- ========================================================================
    onStart = function(data, jobCfg)
        -- Reset state
        currentRoute = nil
        currentStopIndex = 0
        routeStartTime = 0
        DeleteAllPassengers()
        routePhase = 'idle'
        hasDoneRoute = false
        waitingForBatch = true
        offRouteTimer = 0
        offRouteWarned = false
        processingStop = false
        totalPassengersDelivered = 0
        totalPassengersBoarded = 0

        ClearStopBlip()
        ClearReturnBlip()

        routesCompletedThisCycle = 0
        cooldownActive = false
        cooldownEndTime = 0

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

        -- Full fuel + slower consumption for bus
        exports['sb_fuel']:SetFuel(JobVehicle, jobCfg.startFuel or 100.0)
        Entity(JobVehicle).state:set('sb_fuel_multiplier', jobCfg.fuelMultiplier or 0.4, true)

        -- Return point blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        exports['sb_notify']:Notify('Bus Driver job started! Your vehicle is parked outside. Waiting for route assignment...', 'success', 5000)

        -- Request first route
        TriggerServerEvent('sb_jobs:server:requestBatch', data.jobId)
    end,

    -- ========================================================================
    -- ON BATCH READY — Received route from server
    -- ========================================================================
    onBatchReady = function(data, jobCfg)
        local routeIndex = data.routeIndex
        if not routeIndex or not jobCfg.routes[routeIndex] then
            exports['sb_notify']:Notify('Failed to get route assignment.', 'error', 4000)
            return
        end

        currentRoute = jobCfg.routes[routeIndex]
        currentStopIndex = 1
        routeStartTime = GetGameTimer()
        totalPassengersDelivered = 0
        totalPassengersBoarded = 0
        routePhase = 'driving_to_stop'
        waitingForBatch = false
        processingStop = false

        -- Clear old blips
        PJ_ClearAllBlips()
        ClearStopBlip()
        ClearReturnBlip()

        -- Create blip for first stop
        local firstStop = currentRoute.stops[1]
        CreateStopBlip(firstStop, 1, #currentRoute.stops)

        -- Return blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        -- GPS to first stop
        SetGPSToStop(firstStop)

        exports['sb_notify']:Notify('Route: ' .. currentRoute.label .. ' (' .. #currentRoute.stops .. ' stops). Head to the first stop!', 'info', 6000)
    end,

    -- ========================================================================
    -- ON TASK COMPLETE — Payment notification, cleanup, next route
    -- ========================================================================
    onTaskComplete = function(data, jobCfg)
        local payMsg = '$' .. data.pay
        if data.tip > 0 then
            payMsg = payMsg .. ' + $' .. data.tip .. ' bonus'
        end
        exports['sb_notify']:Notify('Route complete! ' .. payMsg .. ' (+' .. data.xp .. ' XP)', 'success', 4000)

        -- Cleanup
        DeleteAllPassengers()
        ClearStopBlip()

        routePhase = 'idle'
        currentRoute = nil
        currentStopIndex = 0
        hasDoneRoute = true
        routesCompletedThisCycle = routesCompletedThisCycle + 1

        -- Check if cycle is complete (10 routes)
        local maxRoutes = jobCfg.maxRoutesPerCycle or 10
        if routesCompletedThisCycle >= maxRoutes then
            waitingForBatch = false
            cooldownActive = true
            local cooldownSec = jobCfg.cooldownSeconds or 600
            cooldownEndTime = GetGameTimer() + (cooldownSec * 1000)
            local cooldownMin = math.floor(cooldownSec / 60)
            exports['sb_notify']:Notify('Full cycle complete! (' .. maxRoutes .. ' routes). Return to the Job Center. You must wait ' .. cooldownMin .. ' minutes before starting another cycle.', 'info', 10000)
            if jobCfg.returnPoint then
                PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
            end
            return
        end

        -- Request next route or handle vehicle swap
        if PendingVehicleSwap then
            waitingForBatch = false
            exports['sb_notify']:Notify('Route complete! Return to the Job Center to swap your vehicle.', 'success', 8000)
            if jobCfg.returnPoint then
                PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
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
        DeleteAllPassengers()
        ClearStopBlip()
        ClearReturnBlip()

        currentRoute = nil
        currentStopIndex = 0
        routeStartTime = 0
        routePhase = 'idle'
        hasDoneRoute = false
        waitingForBatch = false
        offRouteTimer = 0
        offRouteWarned = false
        processingStop = false
        totalPassengersDelivered = 0
        totalPassengersBoarded = 0
        routesCompletedThisCycle = 0
        cooldownActive = false
        cooldownEndTime = 0
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        exports['sb_notify']:Notify('Bus Driver shift ended. Your progress has been saved.', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TICK — Proximity checks, phase management (every 500ms)
    -- ========================================================================
    onTick = function(jobCfg)
        if not ActivePublicJobData then return end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        -- ----------------------------------------------------------------
        -- PHASE: DRIVING TO STOP / DRIVING TO NEXT
        -- Check if we're within stop radius and slow enough
        -- ----------------------------------------------------------------
        if (routePhase == 'driving_to_stop' or routePhase == 'driving_to_next') and currentRoute and currentStopIndex > 0 then
            local stop = currentRoute.stops[currentStopIndex]
            if stop then
                local stopCoords = vector3(stop.coords.x, stop.coords.y, stop.coords.z)
                local distToStop = #(playerCoords - stopCoords)
                local stopRadius = jobCfg.stopRadius or 12.0
                local speedThreshold = jobCfg.speedThreshold or 1.5

                if distToStop < stopRadius then
                    if JobVehicle and DoesEntityExist(JobVehicle) then
                        local speed = GetEntitySpeed(JobVehicle)
                        if speed < speedThreshold then
                            routePhase = 'at_stop_processing'
                            ProcessStop(jobCfg)
                        end
                    end
                end
            end
        end

        -- ----------------------------------------------------------------
        -- PHASE: ROUTE COMPLETE — report stats and complete delivery
        -- ----------------------------------------------------------------
        if routePhase == 'route_complete' then
            routePhase = 'completing' -- prevent re-entry

            -- Calculate on-time
            local elapsed = (GetGameTimer() - routeStartTime) / 1000
            local parTime = currentRoute.parTime or 600
            local onTime = elapsed <= parTime

            -- Report stats to server
            TriggerServerEvent('sb_jobs:server:reportBusRouteStats', {
                totalDelivered = math.min(totalPassengersDelivered, 50),
                totalBoarded = math.min(totalPassengersBoarded, 50),
                onTime = onTime,
            })

            -- Progress bar
            exports['sb_progressbar']:Start({ duration = 2000, label = 'Completing route...' })
            Wait(2000)
            if not ActivePublicJobData then return end

            ClearStopBlip()

            -- Complete the delivery
            TriggerServerEvent('sb_jobs:server:completeDelivery', ActivePublicJobData.jobId, 1)
            Wait(1000)
            return
        end

        -- ----------------------------------------------------------------
        -- CHECK: Cooldown after full cycle (10 routes)
        -- ----------------------------------------------------------------
        if routePhase == 'idle' and cooldownActive then
            local now = GetGameTimer()
            if now >= cooldownEndTime then
                -- Cooldown finished, reset cycle
                cooldownActive = false
                routesCompletedThisCycle = 0

                -- Refuel bus for next cycle
                if JobVehicle and DoesEntityExist(JobVehicle) then
                    exports['sb_fuel']:SetFuel(JobVehicle, jobCfg.startFuel or 100.0)
                end

                exports['sb_notify']:Notify('Cooldown over! Starting a new cycle. Requesting route...', 'success', 5000)
                waitingForBatch = true
                if ActivePublicJobData then
                    TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
                end
            else
                -- Show remaining time every tick (~500ms) as a draw text would be better,
                -- but we'll show a notification periodically (every 30s)
                local remaining = math.ceil((cooldownEndTime - now) / 1000)
                local mins = math.floor(remaining / 60)
                local secs = remaining % 60
                if remaining % 30 == 0 and remaining > 0 then
                    exports['sb_notify']:Notify('Cooldown: ' .. mins .. 'm ' .. secs .. 's remaining. Stay near the Job Center.', 'info', 3000)
                end
            end
            return
        end

        -- ----------------------------------------------------------------
        -- CHECK: At Job Center return point (vehicle swap or end shift)
        -- Only between routes
        -- ----------------------------------------------------------------
        if routePhase == 'idle' and hasDoneRoute and jobCfg.returnPoint then
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
            local offRouteDist = jobCfg.offRouteDistance or 400.0

            if nearestDist > offRouteDist then
                offRouteTimer = offRouteTimer + 0.5

                local warnTime = jobCfg.offRouteWarnTime or 30.0
                local confiscateTime = jobCfg.offRouteConfiscateTime or 60.0

                if offRouteTimer >= warnTime and not offRouteWarned then
                    offRouteWarned = true
                    exports['sb_notify']:Notify('You are going off-route! Return to your route area or your vehicle will be confiscated and you will be fined $100.', 'error', 10000)
                end

                if offRouteTimer >= confiscateTime then
                    DeleteAllPassengers()
                    PJ_DeleteJobVehicle()
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
