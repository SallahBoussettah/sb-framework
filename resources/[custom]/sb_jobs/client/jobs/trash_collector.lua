-- ============================================================================
-- Trash Collector — Client Job Logic (Freeform Discovery)
-- Registers handlers into the PublicJobHandlers framework
--
-- Flow:
-- 1. Player starts job at Job Center NPC -> Trashmaster spawns
-- 2. Server sends batchReady immediately (no zone assignment)
-- 3. Discovery thread scans nearby (~40m) for bin props every 1s
-- 4. New bins get a trash bag spawned on the ground nearby (no outlines)
-- 5. Player ALT-targets bag -> picks up -> carries to truck -> throws in
-- 6. Every 12 bags -> server triggers payment, collecting continues
-- 7. Shift ends when player returns truck to Job Center
-- ============================================================================

-- ============================================================================
-- STATE
-- ============================================================================

local discoveredBins = {}           -- coordKey -> true (prevents re-spawning at same bin)
local spawnedBags = {}              -- { { entity = handle, targetId = id, collected = false }, ... }
local totalCollected = 0            -- running total for the shift
local discoveryActive = false       -- prevents duplicate discovery threads
local carryingBag = false           -- player is carrying a trash bag
local bagProp = nil                 -- handle to attached bag prop
local farePhase = 'idle'            -- 'idle' | 'collecting'
local waitingForBatch = false
local offRouteTimer = 0
local offRouteWarned = false
local returnBlip = nil
local truckBlip = nil
local isCrew = false                -- true if player is a crew member (not leader)
local crewLeaderSource = nil        -- server ID of crew leader (if crew member)
local truckTargetId = nil           -- sb_target ID for truck interactions
local inviteTargetId = nil          -- sb_target ID for player invites
local binHashSet = nil              -- cached hash set for bin models
local hasLeftBase = false           -- true once player has driven away from Job Center

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearReturnBlip()
    if returnBlip and DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
    returnBlip = nil
end

local function ClearTruckBlip()
    if truckBlip and DoesBlipExist(truckBlip) then
        RemoveBlip(truckBlip)
    end
    truckBlip = nil
end

local function DeleteBagProp()
    if bagProp and DoesEntityExist(bagProp) then
        DetachEntity(bagProp, true, true)
        DeleteObject(bagProp)
    end
    bagProp = nil
    carryingBag = false
end

local function ResetMovementClipset()
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 0.25)
end

local function ApplyCarryClipset(jobCfg)
    local clipset = jobCfg.carryClipset or 'anim@heists@box_carry@'
    RequestAnimSet(clipset)
    local timeout = 0
    while not HasAnimSetLoaded(clipset) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return end
    end
    SetPedMovementClipset(PlayerPedId(), clipset, 0.25)
end

local function AttachBagToPlayer(jobCfg)
    local ped = PlayerPedId()
    local propModel = jobCfg.trashBagProp or 'prop_cs_rub_binbag_01'
    local hash = GetHashKey(propModel)

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return false end
    end

    local off = jobCfg.attachOffset or { x = 0.12, y = 0.0, z = -0.05, rotX = 20.0, rotY = 0.0, rotZ = 0.0 }
    local boneIndex = GetPedBoneIndex(ped, jobCfg.attachBone or 57005)

    bagProp = CreateObject(hash, 0, 0, 0, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if bagProp and bagProp > 0 then
        AttachEntityToEntity(bagProp, ped, boneIndex,
            off.x, off.y, off.z,
            off.rotX, off.rotY, off.rotZ,
            true, true, false, true, 1, true)
        carryingBag = true
        return true
    end

    return false
end

--- Get distance to nearest valid job point (for off-route detection)
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

    -- Job vehicle
    if JobVehicle and DoesEntityExist(JobVehicle) then
        local vehCoords = GetEntityCoords(JobVehicle)
        local d = #(playerCoords - vehCoords)
        if d < nearest then nearest = d end
    end

    return nearest
end

--- Remove all spawned bag entities and their targets
local function CleanupSpawnedBags()
    for _, bagData in ipairs(spawnedBags) do
        if bagData.targetId then
            exports['sb_target']:RemoveTarget(bagData.targetId)
        end
        if bagData.entity and DoesEntityExist(bagData.entity) then
            DeleteObject(bagData.entity)
        end
    end
    spawnedBags = {}
end

--- Remove truck ALT-target
local function RemoveTruckTarget()
    if truckTargetId then
        exports['sb_target']:RemoveTarget(truckTargetId)
        truckTargetId = nil
    end
end

--- Remove invite ALT-target
local function RemoveInviteTarget()
    if inviteTargetId then
        exports['sb_target']:RemoveTarget(inviteTargetId)
        inviteTargetId = nil
    end
end

--- Play animation from dict
local function PlayAnimDict(dict, anim, duration, flag)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return end
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration or -1, flag or 1, 0, false, false, false)
end

--- Build a hash set of bin model hashes for fast lookup
local function BuildBinHashSet(jobCfg)
    local hashSet = {}
    for _, modelName in ipairs(jobCfg.binModels) do
        hashSet[GetHashKey(modelName)] = true
    end
    return hashSet
end

--- Generate a coordinate key for dedup (floor to prevent floating point drift)
local function CoordKey(coords)
    return math.floor(coords.x) .. '_' .. math.floor(coords.y) .. '_' .. math.floor(coords.z)
end

--- Count active (uncollected) bags
local function CountActiveBags()
    local count = 0
    for _, bagData in ipairs(spawnedBags) do
        if not bagData.collected then
            count = count + 1
        end
    end
    return count
end

--- Spawn a trash bag on the ground near a bin (no outlines)
local function SpawnGroundBag(binCoords, jobCfg)
    local propModel = jobCfg.trashBagProp or 'prop_cs_rub_binbag_01'
    local hash = GetHashKey(propModel)

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return nil end
    end

    -- Random offset from the bin
    local offset = jobCfg.bagSpawnOffset or 1.5
    local angle = math.random() * 2.0 * math.pi
    local spawnX = binCoords.x + math.cos(angle) * offset
    local spawnY = binCoords.y + math.sin(angle) * offset
    local spawnZ = binCoords.z

    local bag = CreateObject(hash, spawnX, spawnY, spawnZ, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if not bag or bag <= 0 then return nil end

    -- Place on ground properly and freeze
    PlaceObjectOnGroundProperly(bag)
    FreezeEntityPosition(bag, true)

    return bag
end

--- Register ALT-target on a bag entity for pickup
local function RegisterBagTarget(bagData, jobCfg)
    local targetId = exports['sb_target']:AddTargetEntity(bagData.entity, {
        {
            label = 'Pick Up Trash',
            icon = 'fa-hand-paper',
            canInteract = function(entity)
                if not ActivePublicJobData or ActivePublicJobData.jobId ~= 'trash_collector' then return false end
                if carryingBag then return false end
                if farePhase ~= 'collecting' then return false end
                -- Check this bag isn't already collected
                for _, bd in ipairs(spawnedBags) do
                    if bd.entity == entity and bd.collected then return false end
                end
                return true
            end,
            action = function(entity)
                if carryingBag or farePhase ~= 'collecting' then return end

                -- Find this bag in our table
                local thisBag = nil
                for _, bd in ipairs(spawnedBags) do
                    if bd.entity == entity then
                        thisBag = bd
                        break
                    end
                end
                if not thisBag or thisBag.collected then return end

                -- Pickup animation + progress bar
                local pickupCfg = jobCfg.pickupAnim or {}
                if pickupCfg.dict then
                    PlayAnimDict(pickupCfg.dict, pickupCfg.anim, jobCfg.pickupDuration or 2000, 1)
                end

                local completed = exports['sb_progressbar']:Start({ duration = jobCfg.pickupDuration or 2000, label = 'Picking up trash...' })
                ClearPedTasks(PlayerPedId())

                if completed == false then return end

                -- Mark as collected
                thisBag.collected = true

                -- Delete ground bag
                if DoesEntityExist(entity) then
                    DeleteObject(entity)
                end
                thisBag.entity = nil

                -- Remove this bag's target
                if thisBag.targetId then
                    exports['sb_target']:RemoveTarget(thisBag.targetId)
                    thisBag.targetId = nil
                end

                -- Attach carried bag to player hand
                local attached = AttachBagToPlayer(jobCfg)
                if not attached then
                    exports['sb_notify']:Notify('Failed to pick up trash bag.', 'error', 3000)
                    thisBag.collected = false -- allow retry
                    return
                end

                -- Apply heavy carry movement
                ApplyCarryClipset(jobCfg)

                -- GPS to truck
                if JobVehicle and DoesEntityExist(JobVehicle) then
                    local vehCoords = GetEntityCoords(JobVehicle)
                    PJ_SetGPSToCoord(vehCoords.x, vehCoords.y, vehCoords.z)
                end

                exports['sb_notify']:Notify('Got a trash bag! Take it to the truck.', 'info', 3000)
            end,
        },
    })

    bagData.targetId = targetId
end

--- Discovery thread: scans nearby for bin props and spawns bags
local function StartDiscoveryThread(jobCfg)
    if discoveryActive then return end
    discoveryActive = true

    -- Pre-load the bag model
    local propHash = GetHashKey(jobCfg.trashBagProp or 'prop_cs_rub_binbag_01')
    RequestModel(propHash)
    local loadTimeout = 0
    while not HasModelLoaded(propHash) do
        Wait(100)
        loadTimeout = loadTimeout + 100
        if loadTimeout > 5000 then break end
    end

    CreateThread(function()
        local discoveryRadius = jobCfg.discoveryRadius or 40.0
        local maxActive = jobCfg.maxActiveBags or 5

        while discoveryActive and farePhase == 'collecting' and ActivePublicJobData and ActivePublicJobData.jobId == 'trash_collector' do
            Wait(1000)

            -- Skip if carrying a bag or too many uncollected bags already
            local activeBags = CountActiveBags()
            if activeBags < maxActive and not carryingBag then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local objects = GetGamePool('CObject')

                for _, obj in ipairs(objects) do
                    if activeBags >= maxActive then break end

                    if DoesEntityExist(obj) then
                        local model = GetEntityModel(obj)
                        if binHashSet and binHashSet[model] then
                            local objCoords = GetEntityCoords(obj)
                            local dist = #(objCoords - playerCoords)

                            if dist <= discoveryRadius then
                                local key = CoordKey(objCoords)

                                if not discoveredBins[key] then
                                    discoveredBins[key] = true

                                    -- Spawn a bag near this bin
                                    local bagEntity = SpawnGroundBag(objCoords, jobCfg)
                                    if bagEntity then
                                        local bagData = {
                                            entity = bagEntity,
                                            targetId = nil,
                                            collected = false,
                                        }
                                        RegisterBagTarget(bagData, jobCfg)
                                        table.insert(spawnedBags, bagData)
                                        activeBags = activeBags + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        discoveryActive = false
    end)
end

--- Stop the discovery thread
local function StopDiscoveryThread()
    discoveryActive = false
end

--- Register truck ALT-targets (throw trash + ride on back)
local function RegisterTruckTargets(vehicle, jobCfg)
    RemoveTruckTarget()
    truckTargetId = exports['sb_target']:AddTargetEntity(vehicle, {
        {
            label = 'Throw Trash',
            icon = 'fa-trash',
            canInteract = function(entity)
                return carryingBag and ActivePublicJobData and ActivePublicJobData.jobId == 'trash_collector'
            end,
            action = function(entity)
                if not carryingBag or not ActivePublicJobData then return end

                local ped = PlayerPedId()
                local vehCoords = GetEntityCoords(entity)
                local playerCoords = GetEntityCoords(ped)
                if #(playerCoords - vehCoords) > (jobCfg.throwRadius or 5.0) then
                    exports['sb_notify']:Notify('Get closer to the truck!', 'error', 3000)
                    return
                end

                -- Throw animation + progress bar
                local throwCfg = jobCfg.throwAnim or {}
                if throwCfg.dict then
                    PlayAnimDict(throwCfg.dict, throwCfg.anim, jobCfg.throwDuration or 2000, 1)
                end

                local completed = exports['sb_progressbar']:Start({ duration = jobCfg.throwDuration or 2000, label = 'Throwing trash...' })
                ClearPedTasks(ped)

                if completed == false then return end

                -- Remove bag and reset movement
                DeleteBagProp()
                ResetMovementClipset()

                -- Tell server
                TriggerServerEvent('sb_jobs:server:trashCollected')

                totalCollected = totalCollected + 1
                local bagsPerPayment = jobCfg.bagsPerPayment or 12
                local inCycle = ((totalCollected - 1) % bagsPerPayment) + 1
                exports['sb_notify']:Notify('Bags: ' .. inCycle .. '/' .. bagsPerPayment, 'success', 2000)

                -- Clear GPS (no longer carrying)
                PJ_ClearGPS()
            end,
        },
        {
            label = 'Ride on Back',
            icon = 'fa-truck',
            canInteract = function(entity)
                if not ActivePublicJobData or ActivePublicJobData.jobId ~= 'trash_collector' then return false end
                if carryingBag then return false end
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then return false end
                return true
            end,
            action = function(entity)
                local ped = PlayerPedId()
                -- Try seat 1 first, then seat 2 (back hangers)
                if IsVehicleSeatFree(entity, 1) then
                    TaskEnterVehicle(ped, entity, 5000, 1, 2.0, 1, 0)
                elseif IsVehicleSeatFree(entity, 2) then
                    TaskEnterVehicle(ped, entity, 5000, 2, 2.0, 1, 0)
                else
                    exports['sb_notify']:Notify('No room on the back of the truck!', 'error', 3000)
                end
            end,
        },
    })
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobHandlers['trash_collector'] = {

    -- ========================================================================
    -- ON START — Spawn vehicle, set up targets, request batch
    -- ========================================================================
    onStart = function(data, jobCfg)
        -- Reset state
        discoveredBins = {}
        CleanupSpawnedBags()
        totalCollected = 0
        DeleteBagProp()
        ResetMovementClipset()
        farePhase = 'idle'
        waitingForBatch = true
        offRouteTimer = 0
        offRouteWarned = false
        isCrew = data.isCrew or false
        crewLeaderSource = data.leaderSource or nil
        hasLeftBase = false
        StopDiscoveryThread()

        ClearReturnBlip()
        ClearTruckBlip()
        RemoveTruckTarget()
        RemoveInviteTarget()

        -- Build bin hash set once
        binHashSet = BuildBinHashSet(jobCfg)

        -- Crew members don't spawn their own vehicle
        if not isCrew then
            JobVehicle = PJ_SpawnJobVehicle(data.vehicleModel, jobCfg.vehicleSpawn, jobCfg.vehicleSpawnSlots)
            if not JobVehicle then
                TriggerServerEvent('sb_jobs:server:quitPublicJob')
                return
            end

            -- Set plate
            if data.plate then
                SetVehicleNumberPlateText(JobVehicle, data.plate)
            end
        end

        -- Return point blip (only for leader)
        if not isCrew then
            returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')
        end

        -- Register truck ALT-targets
        if JobVehicle and DoesEntityExist(JobVehicle) then
            RegisterTruckTargets(JobVehicle, jobCfg)
        end

        exports['sb_notify']:Notify('Trash Collector job started! Drive around and collect trash bags near bins.', 'success', 5000)

        -- Request batch (inits server state)
        if isCrew then
            -- Crew members wait for leader's batch to be forwarded
        else
            TriggerServerEvent('sb_jobs:server:requestBatch', data.jobId)
        end
    end,

    -- ========================================================================
    -- ON BATCH READY — Start freeform discovery (no zone assignment)
    -- ========================================================================
    onBatchReady = function(data, jobCfg)
        -- If we're crew, we need the truck entity from the leader
        if isCrew and data.truckNetId then
            local timeout = 0
            while not NetworkDoesNetworkIdExist(data.truckNetId) do
                Wait(100)
                timeout = timeout + 100
                if timeout > 5000 then break end
            end
            if NetworkDoesNetworkIdExist(data.truckNetId) then
                JobVehicle = NetworkGetEntityFromNetworkId(data.truckNetId)
                -- Re-register truck targets for crew member
                if JobVehicle and DoesEntityExist(JobVehicle) then
                    RegisterTruckTargets(JobVehicle, jobCfg)
                end
            end
        end

        farePhase = 'collecting'
        waitingForBatch = false

        -- Build bin hash set if not already done
        if not binHashSet then
            binHashSet = BuildBinHashSet(jobCfg)
        end

        -- Start the discovery thread
        StartDiscoveryThread(jobCfg)

        -- Return blip (leader only)
        if not isCrew then
            ClearReturnBlip()
            returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')
        end

        exports['sb_notify']:Notify('Drive around the city and look for trash near bins!', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TASK COMPLETE — Payment received, keep collecting
    -- ========================================================================
    onTaskComplete = function(data, jobCfg)
        local payMsg = '$' .. data.pay
        if data.tip and data.tip > 0 then
            payMsg = payMsg .. ' + $' .. data.tip .. ' tip'
        end
        exports['sb_notify']:Notify('Payment received! ' .. payMsg .. ' (+' .. data.xp .. ' XP)', 'success', 4000)

        -- Don't stop collecting — keep going. Discovery thread stays active.
        -- farePhase stays 'collecting', no need to request a new batch.

        -- Handle vehicle swap if needed (unlikely since all levels use 'trash')
        if PendingVehicleSwap then
            exports['sb_notify']:Notify('Return to the Job Center to swap your vehicle.', 'success', 8000)
            PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
        end
    end,

    -- ========================================================================
    -- ON END — Clean up all state
    -- ========================================================================
    onEnd = function(jobCfg)
        StopDiscoveryThread()
        DeleteBagProp()
        ResetMovementClipset()
        ClearReturnBlip()
        ClearTruckBlip()
        CleanupSpawnedBags()
        RemoveTruckTarget()
        RemoveInviteTarget()

        discoveredBins = {}
        totalCollected = 0
        farePhase = 'idle'
        waitingForBatch = false
        offRouteTimer = 0
        offRouteWarned = false
        isCrew = false
        crewLeaderSource = nil
        binHashSet = nil
        hasLeftBase = false
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        exports['sb_notify']:Notify('Trash Collector shift ended. Your progress has been saved.', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TICK — GPS updates, return point check, off-route (every 500ms)
    -- ========================================================================
    onTick = function(jobCfg)
        if not ActivePublicJobData then return end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        -- ----------------------------------------------------------------
        -- COLLECTING PHASE — GPS to truck when carrying, otherwise clear
        -- ----------------------------------------------------------------
        if farePhase == 'collecting' then
            if carryingBag then
                -- GPS to truck
                if JobVehicle and DoesEntityExist(JobVehicle) then
                    local vehCoords = GetEntityCoords(JobVehicle)
                    PJ_SetGPSToCoord(vehCoords.x, vehCoords.y, vehCoords.z)
                end

                -- Anti-exploit: check if bag prop got detached
                if bagProp and not DoesEntityExist(bagProp) then
                    DeleteBagProp()
                    ResetMovementClipset()
                end
            end
            -- No GPS when not carrying — player explores freely
        end

        -- ----------------------------------------------------------------
        -- CHECK: Track if player has left the Job Center area
        -- (prevents instant end-shift on job start since truck spawns there)
        -- ----------------------------------------------------------------
        if not hasLeftBase and jobCfg.returnPoint then
            local returnDist = #(playerCoords - jobCfg.returnPoint)
            local leaveRadius = (jobCfg.returnRadius or 8.0) * 3 -- must drive ~24m away
            if returnDist > leaveRadius then
                hasLeftBase = true
            end
        end

        -- ----------------------------------------------------------------
        -- CHECK: At Job Center return point (end shift or vehicle swap)
        -- Only for leader, only when not carrying a bag, only after leaving base once
        -- ----------------------------------------------------------------
        if not isCrew and not carryingBag and hasLeftBase and jobCfg.returnPoint then
            local returnDist = #(playerCoords - jobCfg.returnPoint)
            local radius = jobCfg.returnRadius or 8.0

            if returnDist < radius then
                if PendingVehicleSwap then
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Swapping vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    TriggerServerEvent('sb_jobs:server:swapVehicle')
                elseif farePhase == 'collecting' then
                    -- Player returned to Job Center while collecting — end shift
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Returning vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    TriggerServerEvent('sb_jobs:server:quitPublicJob')
                end
            end
        end

        -- ----------------------------------------------------------------
        -- ANTI-ABUSE: Off-route detection (leader only, when in vehicle)
        -- ----------------------------------------------------------------
        if not isCrew and JobVehicle and DoesEntityExist(JobVehicle) and IsPedInVehicle(ped, JobVehicle, false) then
            local nearestDist = GetNearestValidDist(playerCoords, jobCfg)

            if nearestDist > (jobCfg.offRouteDistance or 500.0) then
                offRouteTimer = offRouteTimer + 0.5

                if offRouteTimer >= (jobCfg.offRouteWarnTime or 30.0) and not offRouteWarned then
                    offRouteWarned = true
                    exports['sb_notify']:Notify('You are going off-route! Return or your vehicle will be confiscated and you will be fined $100.', 'error', 10000)
                end

                if offRouteTimer >= (jobCfg.offRouteConfiscateTime or 60.0) then
                    StopDiscoveryThread()
                    DeleteBagProp()
                    ResetMovementClipset()
                    CleanupSpawnedBags()
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

-- ============================================================================
-- CREW INVITE — ALT-target on nearby players (periodic registration in tick)
-- We use a command/key approach instead: ALT-target on closest player
-- ============================================================================

-- Register a simple command for crew invites (leader targets a nearby player)
RegisterNetEvent('sb_jobs:client:trashInvitePrompt', function(leaderName)
    -- Show accept/decline notification to the invited player
    exports['sb_notify']:Notify(leaderName .. ' invites you to collect trash. Press Y to accept.', 'info', 10000)

    -- Listen for Y key press within 10 seconds
    CreateThread(function()
        local timer = 0
        while timer < 10000 do
            Wait(0)
            if IsControlJustPressed(0, 246) then -- Y key (INPUT_FRONTEND_ACCEPT in alt context)
                TriggerServerEvent('sb_jobs:server:trashAcceptInvite')
                exports['sb_notify']:Notify('Joining trash crew...', 'success', 3000)
                return
            end
            timer = timer + GetFrameTime() * 1000
        end
    end)
end)

-- Crew member receives job start (from server forwarding)
RegisterNetEvent('sb_jobs:client:trashCrewStart', function(data)
    -- This is handled by the normal jobStarted event with isCrew = true
end)

-- Command to invite nearest player
RegisterCommand('trashinvite', function()
    if not ActivePublicJobData or ActivePublicJobData.jobId ~= 'trash_collector' then
        exports['sb_notify']:Notify('You must be on a trash collector job to invite.', 'error', 3000)
        return
    end
    if isCrew then
        exports['sb_notify']:Notify('Only the crew leader can invite players.', 'error', 3000)
        return
    end

    -- Find closest player
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local closestPlayer, closestDist = nil, 999999

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(playerCoords - targetCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = GetPlayerServerId(playerId)
                end
            end
        end
    end

    local jobCfg = Config.PublicJobs['trash_collector']
    local inviteRadius = jobCfg and jobCfg.inviteRadius or 10.0

    if not closestPlayer or closestDist > inviteRadius then
        exports['sb_notify']:Notify('No players nearby to invite. Get closer!', 'error', 3000)
        return
    end

    TriggerServerEvent('sb_jobs:server:trashInvite', closestPlayer)
    exports['sb_notify']:Notify('Invite sent!', 'success', 3000)
end, false)

-- Notification when crew member joins
RegisterNetEvent('sb_jobs:client:trashCrewJoined', function(playerName)
    exports['sb_notify']:Notify(playerName .. ' joined your trash crew!', 'success', 4000)
end)

-- Notification when crew member leaves
RegisterNetEvent('sb_jobs:client:trashCrewLeft', function(playerName)
    exports['sb_notify']:Notify(playerName .. ' left the trash crew.', 'info', 4000)
end)

-- Zone completion triggered by server (for all crew members)
RegisterNetEvent('sb_jobs:client:trashZoneComplete', function()
    -- This triggers the standard deliveryComplete flow
    -- No extra handling needed — server calls completeDelivery for each member
end)
