-- sb_mechanic_v2 | Server Elevator
-- State management, movement orchestration, queue system
-- Vehicle sync via AttachEntityToEntity (original patoche approach)

local elevatorStates = {}

-- Initialize state for each elevator from config
for _, elev in ipairs(Config.Elevators) do
    elevatorStates[elev.id] = {
        isUp = elev.startsUp,
        isInUse = false,
        queue = {},       -- ordered list of { source, floor, timestamp }
        dwellTimer = nil, -- timer handle for dwell countdown
    }
end

-- ===================================================================
-- HELPERS
-- ===================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic_v2:elevator:server]', ...)
    end
end

local function GetState(elevId)
    return elevatorStates[elevId]
end

local function GetElevConfig(elevId)
    for _, elev in ipairs(Config.Elevators) do
        if elev.id == elevId then return elev end
    end
    return nil
end

local function NotifyPlayer(source, msg, type, duration)
    TriggerClientEvent('sb_notify:client:Notify', source, msg, type or 'info', duration or 3000)
end

-- ===================================================================
-- VEHICLE ATTACH / DETACH RELAY
-- Broadcast to all clients — entity owner handles the actual attach
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:askVehAttach')
AddEventHandler('sb_mechanic_v2:askVehAttach', function(vehicles, elevId)
    for _, v in pairs(vehicles) do
        TriggerClientEvent('sb_mechanic_v2:AttachVeh', -1, v.netId, elevId)
    end
end)

RegisterNetEvent('sb_mechanic_v2:askVehDetach')
AddEventHandler('sb_mechanic_v2:askVehDetach', function(elevId)
    -- Detach is broadcast; each client detaches vehicles it controls
    TriggerClientEvent('sb_mechanic_v2:DetachAllOnPlatform', -1, elevId)
end)

-- ===================================================================
-- TIMING ESTIMATION
-- ===================================================================

--- FiveM client Wait(N) resolves to at least 1 game frame (~16-17ms at 60fps).
--- Wait(0) = 1 frame, Wait(1) = 1 frame, Wait(5) = 1 frame, etc.
--- Only Wait(N >= ~16) maps 1:1 to ms. For smaller values, each call = 1 frame.
local CLIENT_FRAME_MS = 18 -- conservative estimate (~55fps)

--- Estimate how long a client-side Wait(N) actually takes in real ms
local function ClientWaitMs(waitValue)
    return math.max(waitValue, CLIENT_FRAME_MS)
end

--- Estimate client-side duration for RunSteps only (no door animation)
local function GetStepsDuration(cfg, stepWait)
    local nbStep = math.floor((cfg.elevationHeight * 100) / 6)
    return nbStep * ClientWaitMs(stepWait)
end

--- Estimate full client-side final step duration:
--- RunSteps + arrivalDoorDelay + door open animation + arrivalUnlockDelay
local function GetFinalStepDuration(cfg, stepWait)
    return GetStepsDuration(cfg, stepWait)
        + cfg.arrivalDoorDelay
        + (cfg.doorSteps * CLIENT_FRAME_MS) -- door anim uses Wait(1) per step
        + cfg.arrivalUnlockDelay
end

-- ===================================================================
-- VEHICLE SCAN BROADCAST
-- Ask all clients to find and attach vehicles to the elevator
-- ===================================================================

local function BroadcastVehicleAttach(elevId, cfg, state)
    local platformPos = state.isUp and cfg.posUp or cfg.posDown
    TriggerClientEvent('sb_mechanic_v2:scanAndAttachVehicles', -1, elevId, platformPos, cfg.vehicleDetectRadius)
end

-- ===================================================================
-- MOVEMENT SEQUENCES
-- ===================================================================

--- Move elevator UP: close bottom door → 5 steps → final step + open top door
local function MoveUp(elevId, callback)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then
        if callback then callback() end
        return
    end

    Citizen.CreateThread(function()
        state.isInUse = true
        TriggerClientEvent('sb_mechanic_v2:elevatorBusy', -1, elevId)
        Debug('Elevator going UP:', elevId)

        -- Attach vehicles to elevator before movement
        BroadcastVehicleAttach(elevId, cfg, state)

        -- Close bottom door
        TriggerClientEvent('sb_mechanic_v2:closeDoorDown', -1, elevId)
        Wait(cfg.doorCloseWait)

        -- Step movement phases (5 intermediate steps)
        for i = 1, 5 do
            TriggerClientEvent('sb_mechanic_v2:StepUp', -1, elevId)
            Wait(cfg.stepPhaseWait)
        end

        -- Final step + open door at top
        TriggerClientEvent('sb_mechanic_v2:StepUpAndDoor', -1, elevId)

        -- Wait for client final step animation to complete
        Wait(GetFinalStepDuration(cfg, cfg.moveStepWait))

        state.isUp = true
        state.isInUse = false
        TriggerClientEvent('sb_mechanic_v2:elevatorFree', -1, elevId)

        -- Auto-close door after delay
        Wait(cfg.autoCloseDelay)
        TriggerClientEvent('sb_mechanic_v2:closeDoorUpIfNotBusy', -1, elevId)

        if callback then callback() end
    end)
end

--- Move elevator DOWN: close top door → 5 steps → final step + open bottom door
local function MoveDown(elevId, callback)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then
        if callback then callback() end
        return
    end

    Citizen.CreateThread(function()
        state.isInUse = true
        TriggerClientEvent('sb_mechanic_v2:elevatorBusy', -1, elevId)
        Debug('Elevator going DOWN:', elevId)

        -- Attach vehicles to elevator before movement
        BroadcastVehicleAttach(elevId, cfg, state)

        -- Close top door
        TriggerClientEvent('sb_mechanic_v2:closeDoorUp', -1, elevId)
        Wait(cfg.doorCloseWait)

        -- Step movement phases (5 intermediate steps)
        for i = 1, 5 do
            TriggerClientEvent('sb_mechanic_v2:StepDown', -1, elevId)
            Wait(cfg.stepPhaseWait)
        end

        -- Final step + open door at bottom
        TriggerClientEvent('sb_mechanic_v2:StepDownAndDoor', -1, elevId)

        -- Wait for client final step animation to complete
        Wait(GetFinalStepDuration(cfg, cfg.moveStepWait))

        state.isUp = false
        state.isInUse = false
        TriggerClientEvent('sb_mechanic_v2:elevatorFree', -1, elevId)

        -- Auto-close door after delay
        Wait(cfg.autoCloseDelay)
        TriggerClientEvent('sb_mechanic_v2:closeDoorDownIfNotBusy', -1, elevId)

        if callback then callback() end
    end)
end

--- Move elevator using fast speed (wall call — no one riding)
local function MoveUpFast(elevId, callback)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then
        if callback then callback() end
        return
    end

    Citizen.CreateThread(function()
        state.isInUse = true
        TriggerClientEvent('sb_mechanic_v2:elevatorBusy', -1, elevId)
        Debug('Elevator fast UP:', elevId)

        -- Attach vehicles to elevator before movement
        BroadcastVehicleAttach(elevId, cfg, state)

        TriggerClientEvent('sb_mechanic_v2:upAndDoor', -1, elevId)

        -- Wait for client animation to finish
        Wait(GetFinalStepDuration(cfg, cfg.fastMoveStepWait))

        state.isUp = true
        state.isInUse = false
        TriggerClientEvent('sb_mechanic_v2:elevatorFree', -1, elevId)

        -- Auto-close door after delay
        Wait(cfg.autoCloseDelay)
        TriggerClientEvent('sb_mechanic_v2:closeDoorUpIfNotBusy', -1, elevId)

        if callback then callback() end
    end)
end

local function MoveDownFast(elevId, callback)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then
        if callback then callback() end
        return
    end

    Citizen.CreateThread(function()
        state.isInUse = true
        TriggerClientEvent('sb_mechanic_v2:elevatorBusy', -1, elevId)
        Debug('Elevator fast DOWN:', elevId)

        -- Attach vehicles to elevator before movement
        BroadcastVehicleAttach(elevId, cfg, state)

        TriggerClientEvent('sb_mechanic_v2:downAndDoor', -1, elevId)

        -- Wait for client animation to finish
        Wait(GetFinalStepDuration(cfg, cfg.fastMoveStepWait))

        state.isUp = false
        state.isInUse = false
        TriggerClientEvent('sb_mechanic_v2:elevatorFree', -1, elevId)

        -- Auto-close door after delay
        Wait(cfg.autoCloseDelay)
        TriggerClientEvent('sb_mechanic_v2:closeDoorDownIfNotBusy', -1, elevId)

        if callback then callback() end
    end)
end

-- ===================================================================
-- QUEUE SYSTEM
-- ===================================================================

--- Process next item in queue after dwell time
local function ProcessQueue(elevId)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then return end

    -- Wait dwell time before checking queue
    local dwellTime = cfg.dwellTime or 10000
    Wait(dwellTime)

    -- Check if queue has entries
    if #state.queue == 0 then
        Debug('Queue empty for', elevId)
        return
    end

    -- Pop first entry
    local entry = table.remove(state.queue, 1)
    Debug('Processing queue entry for', elevId, '- floor:', entry.floor, 'source:', entry.source)

    -- Determine what needs to happen
    local wantsUp = (entry.floor == 'up')

    if (wantsUp and state.isUp) or (not wantsUp and not state.isUp) then
        -- Already at requested floor, just open the door
        if wantsUp then
            TriggerClientEvent('sb_mechanic_v2:openDoorUp', -1, elevId)
        else
            TriggerClientEvent('sb_mechanic_v2:openDoorDown', -1, elevId)
        end
        -- Notify requester
        if entry.source and entry.source > 0 then
            NotifyPlayer(entry.source, 'Elevator has arrived', 'success', 3000)
        end
        -- Continue processing queue
        Citizen.CreateThread(function()
            ProcessQueue(elevId)
        end)
    else
        -- Need to move. Determine movement type based on request origin
        -- Wall calls use fast movement, cabin calls use stepped movement
        local moveFunc
        if entry.type == 'wall' then
            moveFunc = wantsUp and MoveUpFast or MoveDownFast
        else
            moveFunc = wantsUp and MoveUp or MoveDown
        end

        -- Notify requester
        if entry.source and entry.source > 0 then
            NotifyPlayer(entry.source, 'Elevator is on its way', 'info', 3000)
        end

        moveFunc(elevId, function()
            -- Notify arrival
            if entry.source and entry.source > 0 then
                NotifyPlayer(entry.source, 'Elevator has arrived', 'success', 3000)
            end
            -- Continue processing queue
            Citizen.CreateThread(function()
                ProcessQueue(elevId)
            end)
        end)
    end
end

--- Queue a request for the elevator
--- @param elevId string  Elevator identifier
--- @param source number  Player server ID
--- @param floor string   'up' or 'down' — which floor is requested
--- @param requestType string  'wall' or 'cabin'
local function QueueRequest(elevId, source, floor, requestType)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then return end

    local wantsUp = (floor == 'up')

    -- Case 1: Elevator is already at requested floor and not busy
    if not state.isInUse and ((wantsUp and state.isUp) or (not wantsUp and not state.isUp)) then
        -- Just open the door
        if wantsUp then
            TriggerClientEvent('sb_mechanic_v2:openDoorUp', -1, elevId)
        else
            TriggerClientEvent('sb_mechanic_v2:openDoorDown', -1, elevId)
        end
        NotifyPlayer(source, 'Elevator has arrived', 'success', 3000)
        return
    end

    -- Case 2: Elevator is busy — add to queue
    if state.isInUse then
        table.insert(state.queue, {
            source = source,
            floor = floor,
            type = requestType,
            timestamp = os.time(),
        })
        local pos = #state.queue
        NotifyPlayer(source, 'Elevator is busy, please wait (#' .. pos .. ' in queue)', 'info', 5000)
        Debug('Queued request for', elevId, '- position:', pos, 'source:', source)
        return
    end

    -- Case 3: Elevator is idle but at wrong floor — start movement
    NotifyPlayer(source, 'Elevator is on its way', 'info', 3000)

    local moveFunc
    if requestType == 'wall' then
        moveFunc = wantsUp and MoveUpFast or MoveDownFast
    else
        moveFunc = wantsUp and MoveUp or MoveDown
    end

    moveFunc(elevId, function()
        NotifyPlayer(source, 'Elevator has arrived', 'success', 3000)
        -- Start processing queue after movement
        Citizen.CreateThread(function()
            ProcessQueue(elevId)
        end)
    end)
end

-- ===================================================================
-- UNIFIED REQUEST HANDLER
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:requestElevator')
AddEventHandler('sb_mechanic_v2:requestElevator', function(elevId, floor, requestType)
    local src = source
    QueueRequest(elevId, src, floor, requestType or 'cabin')
end)

-- ===================================================================
-- STATE SYNC FOR JOINING PLAYERS
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:GetStatus')
AddEventHandler('sb_mechanic_v2:GetStatus', function()
    local player = source
    -- Include queue length in response
    local syncData = {}
    for elevId, state in pairs(elevatorStates) do
        syncData[elevId] = {
            isUp = state.isUp,
            isInUse = state.isInUse,
            queueLength = #state.queue,
        }
    end
    TriggerClientEvent('sb_mechanic_v2:sendStatus', player, syncData)
end)
