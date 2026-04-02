-- ============================================================================
-- sb_mechanic - Server
-- Elevator state management and movement orchestration
-- ============================================================================

local elevatorStates = {}

-- Initialize state for each elevator from config
for _, elev in ipairs(Config.Elevators) do
    elevatorStates[elev.id] = {
        isUp = elev.startsUp,
        isInUse = false,
    }
end

-- ============================================================================
-- Helpers
-- ============================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic:server]', ...)
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

-- ============================================================================
-- Vehicle freeze/unfreeze relay
-- ============================================================================

RegisterNetEvent('sb_mechanic:askVehFreeze')
AddEventHandler('sb_mechanic:askVehFreeze', function(vehicles, elevId)
    for _, v in pairs(vehicles) do
        TriggerClientEvent('sb_mechanic:FreezeVeh', -1, v.netId, elevId)
    end
end)

RegisterNetEvent('sb_mechanic:askVehUnFreeze')
AddEventHandler('sb_mechanic:askVehUnFreeze', function(vehicles, elevId)
    for _, v in pairs(vehicles) do
        TriggerClientEvent('sb_mechanic:UnFreezeVeh', -1, v.netId, elevId)
    end
end)

-- ============================================================================
-- Cabin controls: Go Up (from inside, lower floor)
-- ============================================================================

RegisterNetEvent('sb_mechanic:liftUp')
AddEventHandler('sb_mechanic:liftUp', function(elevId)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then return end

    Citizen.CreateThread(function()
        if state.isInUse then return end
        state.isInUse = true

        Debug('Lift going UP:', elevId)

        -- Close bottom door
        TriggerClientEvent('sb_mechanic:closeDoorDown', -1, elevId)
        Wait(cfg.doorCloseWait)

        -- Step movement phases (5 intermediate steps)
        for i = 1, 5 do
            TriggerClientEvent('sb_mechanic:StepUp', -1, elevId)
            Wait(cfg.stepPhaseWait)
        end

        -- Final step + open door at top
        TriggerClientEvent('sb_mechanic:StepUpAndDoor', -1, elevId)

        state.isUp = true
        state.isInUse = false

        -- Auto-close door after delay
        Wait(cfg.autoCloseDelay)
        TriggerClientEvent('sb_mechanic:closeDoorUpIfNotBusy', -1, elevId)
    end)
end)

-- ============================================================================
-- Cabin controls: Go Down (from inside, upper floor)
-- ============================================================================

RegisterNetEvent('sb_mechanic:liftDown')
AddEventHandler('sb_mechanic:liftDown', function(elevId)
    local state = GetState(elevId)
    local cfg = GetElevConfig(elevId)
    if not state or not cfg then return end

    Citizen.CreateThread(function()
        if state.isInUse then return end
        state.isInUse = true

        Debug('Lift going DOWN:', elevId)

        -- Close top door
        TriggerClientEvent('sb_mechanic:closeDoorUp', -1, elevId)
        Wait(cfg.doorCloseWait)

        -- Step movement phases (5 intermediate steps)
        for i = 1, 5 do
            TriggerClientEvent('sb_mechanic:StepDown', -1, elevId)
            Wait(cfg.stepPhaseWait)
        end

        -- Final step + open door at bottom
        TriggerClientEvent('sb_mechanic:StepDownAndDoor', -1, elevId)

        state.isUp = false
        state.isInUse = false

        -- Auto-close door after delay
        Wait(cfg.autoCloseDelay)
        TriggerClientEvent('sb_mechanic:closeDoorDownIfNotBusy', -1, elevId)
    end)
end)

-- ============================================================================
-- Wall controls: Call elevator to upper floor
-- ============================================================================

RegisterNetEvent('sb_mechanic:askUp')
AddEventHandler('sb_mechanic:askUp', function(elevId)
    local state = GetState(elevId)
    if not state then return end

    Citizen.CreateThread(function()
        if not state.isUp then
            -- Elevator is below, bring it up (fast movement + open door)
            if state.isInUse then return end
            state.isInUse = true
            TriggerClientEvent('sb_mechanic:upAndDoor', -1, elevId)
            state.isUp = true
            state.isInUse = false
        else
            -- Already at top, just open the door
            TriggerClientEvent('sb_mechanic:openDoorUp', -1, elevId)
        end
    end)
end)

-- ============================================================================
-- Wall controls: Call elevator to lower floor
-- ============================================================================

RegisterNetEvent('sb_mechanic:askDown')
AddEventHandler('sb_mechanic:askDown', function(elevId)
    local state = GetState(elevId)
    if not state then return end

    Citizen.CreateThread(function()
        if state.isUp then
            -- Elevator is above, bring it down (fast movement + open door)
            if state.isInUse then return end
            state.isInUse = true
            TriggerClientEvent('sb_mechanic:downAndDoor', -1, elevId)
            state.isUp = false
            state.isInUse = false
        else
            -- Already at bottom, just open the door
            TriggerClientEvent('sb_mechanic:openDoorDown', -1, elevId)
        end
    end)
end)

-- ============================================================================
-- State sync for newly joining players
-- ============================================================================

RegisterNetEvent('sb_mechanic:GetStatus')
AddEventHandler('sb_mechanic:GetStatus', function()
    local player = source
    TriggerClientEvent('sb_mechanic:sendStatus', player, elevatorStates)
end)
