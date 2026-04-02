local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- PUBLIC JOB CLIENT FRAMEWORK
-- Job-specific files register handlers into PublicJobHandlers[jobId]
-- ============================================================================

PublicJobHandlers = {}
-- PublicJobHandlers['pizza_delivery'] = {
--     onStart      = function(data, jobCfg) end,    -- Called when job starts
--     onBatchReady = function(locations, jobCfg) end, -- Called when batch of tasks arrives
--     onTaskComplete = function(data, jobCfg) end,   -- Called when a task/delivery completes
--     onEnd        = function(jobCfg) end,           -- Called when job ends
--     onTick       = function(jobCfg) end,           -- Called every 500ms while job active
-- }

-- ============================================================================
-- SHARED STATE (accessible by job files)
-- ============================================================================

ActivePublicJobData = nil   -- { jobId, level, pay, vehicleModel }
JobVehicle = nil
JobBlips = {}
JobRestaurantBlip = nil
PendingVehicleSwap = false       -- True when player needs to return to Job Center for vehicle swap
PendingSwapVehicle = nil         -- Model name of the new vehicle to swap to
PendingSwapRequiresLicense = nil -- License item name if new vehicle needs one

-- ============================================================================
-- SHARED HELPERS (used by job-specific files)
-- ============================================================================

function PJ_ClearAllBlips()
    for _, blip in pairs(JobBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    JobBlips = {}
    if JobRestaurantBlip and DoesBlipExist(JobRestaurantBlip) then
        RemoveBlip(JobRestaurantBlip)
        JobRestaurantBlip = nil
    end
end

function PJ_ClearGPS()
    ClearGpsMultiRoute()
    SetGpsMultiRouteRender(false)
end

function PJ_SetGPSToCoord(x, y, z)
    PJ_ClearGPS()
    SetNewWaypoint(x, y)
end

function PJ_DeleteJobVehicle()
    if JobVehicle and DoesEntityExist(JobVehicle) then
        DeleteVehicle(JobVehicle)
    end
    JobVehicle = nil
end

function PJ_SpawnJobVehicle(vehicleModel, spawnCoords, spawnSlots)
    local hash = GetHashKey(vehicleModel)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then
            exports['sb_notify']:Notify('Failed to load vehicle model', 'error', 5000)
            return nil
        end
    end

    -- Pick spawn position: use slots if available, otherwise single point
    local spawnX, spawnY, spawnZ, heading

    if spawnSlots and #spawnSlots > 0 then
        -- Find first clear slot
        local foundSlot = false
        for _, slot in ipairs(spawnSlots) do
            local _, closestVeh = GetClosestVehicle(slot.x, slot.y, slot.z, 3.0, 0, 71)
            if not closestVeh or closestVeh == 0 then
                spawnX, spawnY, spawnZ, heading = slot.x, slot.y, slot.z, slot.w
                foundSlot = true
                break
            end
        end
        -- All slots full — use last slot anyway
        if not foundSlot then
            local last = spawnSlots[#spawnSlots]
            spawnX, spawnY, spawnZ, heading = last.x, last.y, last.z, last.w
        end
    else
        spawnX, spawnY, spawnZ = spawnCoords.x, spawnCoords.y, spawnCoords.z
        heading = spawnCoords.w or 0.0
    end

    local veh = CreateVehicle(hash, spawnX, spawnY, spawnZ, heading, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    Entity(veh).state.sb_owned = true

    return veh
end

function PJ_CreateNumberedBlip(coords, index, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, false)
    ShowNumberOnBlip(blip, index)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or ('Task #' .. index))
    EndTextCommandSetBlipName(blip)
    return blip
end

--- Spawn a random NPC passenger ped near given coords
---@param coords vector4 Spawn position
---@param jobCfg table Job config (must have .passengerModels)
---@return number|nil ped The spawned ped handle, or nil on failure
function PJ_SpawnPassengerPed(coords, jobCfg)
    local models = jobCfg.passengerModels
    if not models or #models == 0 then return nil end
    local modelName = models[math.random(#models)]
    local hash = GetHashKey(modelName)

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then
            print('[sb_jobs] Failed to load passenger model: ' .. modelName)
            return nil
        end
    end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)

    if ped and ped > 0 then
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, false)
    end

    return ped
end

function PJ_CreateLocationBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale or 0.9)
    SetBlipColour(blip, color or 17)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Job Location')
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ============================================================================
-- EVENT: JOB STARTED (from server)
-- ============================================================================

RegisterNetEvent('sb_jobs:client:jobStarted', function(data)
    ActivePublicJobData = data
    local jobCfg = Config.PublicJobs[data.jobId]
    if not jobCfg then return end

    local handler = PublicJobHandlers[data.jobId]
    if handler and handler.onStart then
        handler.onStart(data, jobCfg)
    end

    -- Start tick loop
    CreateThread(function()
        while ActivePublicJobData and ActivePublicJobData.jobId == data.jobId do
            Wait(500)
            local h = PublicJobHandlers[data.jobId]
            if h and h.onTick then
                local jobCfg2 = Config.PublicJobs[data.jobId]
                if jobCfg2 then
                    h.onTick(jobCfg2)
                end
            end
            if not ActivePublicJobData then break end
        end
    end)
end)

-- ============================================================================
-- EVENT: BATCH READY (from server)
-- ============================================================================

RegisterNetEvent('sb_jobs:client:batchReady', function(data)
    if not ActivePublicJobData then return end
    local jobCfg = Config.PublicJobs[ActivePublicJobData.jobId]
    local handler = PublicJobHandlers[ActivePublicJobData.jobId]
    if handler and handler.onBatchReady then
        handler.onBatchReady(data, jobCfg)
    end
end)

-- ============================================================================
-- EVENT: TASK/DELIVERY COMPLETE (from server)
-- ============================================================================

RegisterNetEvent('sb_jobs:client:deliveryComplete', function(data)
    if not ActivePublicJobData then return end

    -- Level up handling (generic — applies to all jobs)
    if data.newLevel and data.newLevel > ActivePublicJobData.level then
        ActivePublicJobData.level = data.newLevel
        ActivePublicJobData.pay = data.newPay
        exports['sb_notify']:Notify('LEVEL UP! You are now Level ' .. data.newLevel .. ' - Pay increased to $' .. data.newPay, 'success', 6000)

        if data.pendingSwap and data.pendingSwapVehicle then
            -- Vehicle type changed — player must return to Job Center to swap
            PendingVehicleSwap = true
            PendingSwapVehicle = data.pendingSwapVehicle
            PendingSwapRequiresLicense = data.swapRequiresLicense or nil
            ActivePublicJobData.vehicleModel = data.pendingSwapVehicle

            if data.swapRequiresLicense then
                exports['sb_notify']:Notify('New vehicle unlocked! Return to the Job Center to swap your vehicle. Note: You will need a driver\'s license for this vehicle.', 'info', 8000)
            else
                exports['sb_notify']:Notify('New vehicle unlocked! Return to the Job Center to swap your vehicle.', 'info', 6000)
            end
        elseif data.newVehicle and data.newVehicle ~= ActivePublicJobData.vehicleModel then
            -- Same vehicle type (shouldn't happen with pendingSwap, but fallback)
            ActivePublicJobData.vehicleModel = data.newVehicle
        end
    end

    local jobCfg = Config.PublicJobs[ActivePublicJobData.jobId]
    local handler = PublicJobHandlers[ActivePublicJobData.jobId]
    if handler and handler.onTaskComplete then
        handler.onTaskComplete(data, jobCfg)
    end
end)

-- ============================================================================
-- EVENT: VEHICLE SWAP RESULT (from server)
-- ============================================================================

RegisterNetEvent('sb_jobs:client:swapResult', function(data)
    if not ActivePublicJobData then return end

    if data.success then
        -- Delete old vehicle
        PJ_DeleteJobVehicle()

        -- Spawn new vehicle at the Job Center spawn point
        local jobCfg = Config.PublicJobs[ActivePublicJobData.jobId]
        if jobCfg then
            JobVehicle = PJ_SpawnJobVehicle(data.vehicleModel, jobCfg.vehicleSpawn, jobCfg.vehicleSpawnSlots)
            if JobVehicle and data.plate then
                SetVehicleNumberPlateText(JobVehicle, data.plate)
            end
        end

        -- Clear swap state
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        exports['sb_notify']:Notify('Vehicle swapped to ' .. data.vehicleLabel .. '! Continue your deliveries.', 'success', 5000)

        -- Request next batch now that swap is done
        if ActivePublicJobData then
            TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
        end
    else
        -- Swap failed (e.g., no license) — clear pending state so player can continue working
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        exports['sb_notify']:Notify(data.reason or 'Vehicle swap failed', 'error', 8000)
        exports['sb_notify']:Notify('You can continue delivering with your current vehicle, or return here to quit your shift.', 'info', 5000)
    end
end)

-- ============================================================================
-- EVENT: JOB ENDED (from server)
-- ============================================================================

RegisterNetEvent('sb_jobs:client:jobEnded', function()
    if ActivePublicJobData then
        local jobCfg = Config.PublicJobs[ActivePublicJobData.jobId]
        local handler = PublicJobHandlers[ActivePublicJobData.jobId]
        if handler and handler.onEnd then
            handler.onEnd(jobCfg)
        end
    end
    PJ_CleanupJob()
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

function PJ_CleanupJob()
    ActivePublicJobData = nil
    PendingVehicleSwap = false
    PendingSwapVehicle = nil
    PendingSwapRequiresLicense = nil
    PJ_ClearAllBlips()
    PJ_ClearGPS()
    PJ_DeleteJobVehicle()
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ActivePublicJobData then
        PJ_CleanupJob()
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('HasActivePublicJob', function()
    return ActivePublicJobData ~= nil
end)

exports('GetActivePublicJob', function()
    return ActivePublicJobData
end)
