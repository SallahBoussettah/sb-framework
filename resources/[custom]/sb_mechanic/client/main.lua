-- ============================================================================
-- sb_mechanic - Client
-- Benny's elevator platform, doors, targets, and vehicle attachment
-- ============================================================================

local isReady = false

-- Runtime state per elevator (keyed by elevator id)
local elevators = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic:client]', ...)
    end
end

local function GetElevConfig(elevId)
    for _, elev in ipairs(Config.Elevators) do
        if elev.id == elevId then return elev end
    end
    return nil
end

local function GetElev(elevId)
    return elevators[elevId]
end

local function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(0)
        timeout = timeout + 1
    end
    return hash
end

local function RequestEntityControl(entity)
    local attempts = 0
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and attempts < 50 do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
        attempts = attempts + 1
    end
end

-- ============================================================================
-- Vehicle detection on platform
-- ============================================================================

local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next
        disposeFunc(iter)
    end)
end

local function GetNearbyVehicles(coords, radius)
    local result = {}
    for veh in EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle) do
        local vehCoords = GetEntityCoords(veh)
        if #(vehCoords - coords) < radius then
            table.insert(result, {
                entity = veh,
                netId = NetworkGetNetworkIdFromEntity(veh)
            })
        end
    end
    return result
end

local function GetVehiclesOnPlatform(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return {} end

    local checkPos = state.isUp and cfg.posUp or cfg.posDown
    return GetNearbyVehicles(checkPos, cfg.vehicleDetectRadius)
end

-- ============================================================================
-- Prop management
-- ============================================================================

local function FindOrCreateProp(propName, pos, heading, rotation)
    local hash = GetHashKey(propName)
    local existing = GetClosestObjectOfType(pos.x, pos.y, pos.z, 3.0, hash, false, false, false)
    if existing ~= 0 then
        return existing
    end

    local mdl = LoadModel(propName)
    local obj = CreateObject(mdl, pos.x, pos.y, pos.z, false, false, true)
    FreezeEntityPosition(obj, true)
    if rotation then
        SetEntityRotation(obj, rotation.x, rotation.y, rotation.z, 0, false)
    end
    SetEntityHeading(obj, heading)
    return obj
end

local function FindDoorProp(propName, closedPos, openPos, isOpen)
    local hash = GetHashKey(propName)
    local checkPos = isOpen and openPos or closedPos
    local existing = GetClosestObjectOfType(checkPos.x, checkPos.y, checkPos.z, 1.0, hash, false, false, false)
    if existing ~= 0 then
        return existing
    end
    return 0
end

local function EnsureProps(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    -- Elevator platform
    if not DoesEntityExist(state.elevateID) then
        local pos = state.isUp and cfg.posUp or cfg.posDown
        local spawnPos = vector3(pos.x, pos.y, pos.z + cfg.spawnOffsetZ)
        state.elevateID = FindOrCreateProp(cfg.elevatorProp, spawnPos, cfg.elevatorHeading, cfg.elevatorRotation)
        Debug('Spawned elevator prop:', state.elevateID)
    else
        SetEntityVisible(state.elevateID, true)
    end

    -- Bottom door
    if not DoesEntityExist(state.doorDownID) then
        local found = FindDoorProp(cfg.doorProp, cfg.doorDownClosed, cfg.doorDownOpen, state.downDoorIsOpen)
        if found ~= 0 then
            state.doorDownID = found
        else
            local pos = state.downDoorIsOpen and cfg.doorDownOpen or cfg.doorDownClosed
            state.doorDownID = FindOrCreateProp(cfg.doorProp, pos, cfg.doorHeading, nil)
        end
        Debug('Spawned door down:', state.doorDownID)
    else
        SetEntityVisible(state.doorDownID, true)
    end

    -- Top door
    if not DoesEntityExist(state.doorUpID) then
        local found = FindDoorProp(cfg.doorProp, cfg.doorUpClosed, cfg.doorUpOpen, state.upDoorIsOpen)
        if found ~= 0 then
            state.doorUpID = found
        else
            local pos = state.upDoorIsOpen and cfg.doorUpOpen or cfg.doorUpClosed
            state.doorUpID = FindOrCreateProp(cfg.doorProp, pos, cfg.doorHeading, nil)
        end
        Debug('Spawned door up:', state.doorUpID)
    else
        SetEntityVisible(state.doorUpID, true)
    end
end

-- ============================================================================
-- Initialize state table for each elevator
-- ============================================================================

local function InitElevatorState(elevId)
    elevators[elevId] = {
        isUp = true,
        isInUse = false,
        elevateID = 0,
        doorDownID = 0,
        doorUpID = 0,
        downDoorIsOpen = false,
        upDoorIsOpen = false,
    }
end

for _, elev in ipairs(Config.Elevators) do
    InitElevatorState(elev.id)
end

-- ============================================================================
-- Blip creation
-- ============================================================================

local function CreateBlip()
    if not Config.Blip.enabled then return end
    local blip = AddBlipForCoord(Config.Blip.coords.x, Config.Blip.coords.y, Config.Blip.coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end

-- ============================================================================
-- sb_target zone registration
-- ============================================================================

local targetZones = {}

local function RegisterTargetZones()
    for _, cfg in ipairs(Config.Elevators) do
        local elevId = cfg.id

        -- Wall control - upper floor (call elevator)
        targetZones[elevId .. '_wall_up'] = exports['sb_target']:AddSphereZone(
            'mechanic_' .. elevId .. '_wall_up',
            cfg.controlUp,
            cfg.controlDistance,
            {
                {
                    name = 'mechanic_call_up_' .. elevId,
                    label = 'Call Elevator',
                    icon = 'fa-elevator',
                    distance = cfg.controlDistance + 0.5,
                    canInteract = function()
                        return exports['sb_mechanic']:IsMechanic()
                    end,
                    action = function()
                        local state = GetElev(elevId)
                        if state.isInUse then
                            exports['sb_notify']:Notify('Elevator is in use', 'error', 3000)
                            return
                        end
                        -- Freeze vehicles before calling
                        local vehs = GetVehiclesOnPlatform(elevId)
                        TriggerServerEvent('sb_mechanic:askVehFreeze', vehs, elevId)
                        TriggerServerEvent('sb_mechanic:askUp', elevId)
                        exports['sb_notify']:Notify('Calling elevator...', 'info', 3000)
                    end
                }
            }
        )

        -- Wall control - lower floor (call elevator)
        targetZones[elevId .. '_wall_down'] = exports['sb_target']:AddSphereZone(
            'mechanic_' .. elevId .. '_wall_down',
            cfg.controlDown,
            cfg.controlDistance,
            {
                {
                    name = 'mechanic_call_down_' .. elevId,
                    label = 'Call Elevator',
                    icon = 'fa-elevator',
                    distance = cfg.controlDistance + 0.5,
                    canInteract = function()
                        return exports['sb_mechanic']:IsMechanic()
                    end,
                    action = function()
                        local state = GetElev(elevId)
                        if state.isInUse then
                            exports['sb_notify']:Notify('Elevator is in use', 'error', 3000)
                            return
                        end
                        local vehs = GetVehiclesOnPlatform(elevId)
                        TriggerServerEvent('sb_mechanic:askVehFreeze', vehs, elevId)
                        TriggerServerEvent('sb_mechanic:askDown', elevId)
                        exports['sb_notify']:Notify('Calling elevator...', 'info', 3000)
                    end
                }
            }
        )

        -- Cabin control - upper floor (go down)
        targetZones[elevId .. '_cabin_up'] = exports['sb_target']:AddSphereZone(
            'mechanic_' .. elevId .. '_cabin_up',
            cfg.controlCabinUp,
            cfg.cabinDistance,
            {
                {
                    name = 'mechanic_godown_' .. elevId,
                    label = 'Go Down',
                    icon = 'fa-arrow-down',
                    distance = cfg.cabinDistance + 0.3,
                    canInteract = function()
                        if not exports['sb_mechanic']:IsMechanic() then return false end
                        local state = GetElev(elevId)
                        return not state.isInUse
                    end,
                    action = function()
                        local state = GetElev(elevId)
                        if state.isInUse then
                            exports['sb_notify']:Notify('Elevator is in use', 'error', 3000)
                            return
                        end
                        local vehs = GetNearbyVehicles(cfg.posUp, cfg.vehicleDetectRadius)
                        TriggerServerEvent('sb_mechanic:askVehFreeze', vehs, elevId)
                        TriggerServerEvent('sb_mechanic:liftDown', elevId)
                        exports['sb_notify']:Notify('Going down...', 'info', 3000)
                    end
                }
            }
        )

        -- Cabin control - lower floor (go up)
        targetZones[elevId .. '_cabin_down'] = exports['sb_target']:AddSphereZone(
            'mechanic_' .. elevId .. '_cabin_down',
            cfg.controlCabinDown,
            cfg.cabinDistance,
            {
                {
                    name = 'mechanic_goup_' .. elevId,
                    label = 'Go Up',
                    icon = 'fa-arrow-up',
                    distance = cfg.cabinDistance + 0.3,
                    canInteract = function()
                        if not exports['sb_mechanic']:IsMechanic() then return false end
                        local state = GetElev(elevId)
                        return not state.isInUse
                    end,
                    action = function()
                        local state = GetElev(elevId)
                        if state.isInUse then
                            exports['sb_notify']:Notify('Elevator is in use', 'error', 3000)
                            return
                        end
                        local vehs = GetNearbyVehicles(cfg.posDown, cfg.vehicleDetectRadius)
                        TriggerServerEvent('sb_mechanic:askVehFreeze', vehs, elevId)
                        TriggerServerEvent('sb_mechanic:liftUp', elevId)
                        exports['sb_notify']:Notify('Going up...', 'info', 3000)
                    end
                }
            }
        )
    end
end

-- ============================================================================
-- Prop management thread (spawns/manages props when nearby)
-- ============================================================================

Citizen.CreateThread(function()
    while true do
        Wait(500)
        if isReady then
            local pedCoords = GetEntityCoords(PlayerPedId())
            for _, cfg in ipairs(Config.Elevators) do
                local state = GetElev(cfg.id)
                if state and not state.isInUse then
                    local distUp = #(pedCoords - cfg.controlUp)
                    local distDown = #(pedCoords - cfg.controlDown)
                    if distUp < cfg.spawnDistance or distDown < cfg.spawnDistance then
                        EnsureProps(cfg.id)
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- Door animations
-- ============================================================================

RegisterNetEvent('sb_mechanic:openDoorDown')
AddEventHandler('sb_mechanic:openDoorDown', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end
    if state.downDoorIsOpen then return end

    state.downDoorIsOpen = true
    local door = state.doorDownID
    if not DoesEntityExist(door) then return end

    for i = 1, cfg.doorSteps do
        Wait(1)
        SetEntityCoords(door, GetOffsetFromEntityInWorldCoords(door, 0, 0, cfg.doorStepSize))
    end
    SetEntityCoords(door, cfg.doorDownOpen.x, cfg.doorDownOpen.y, cfg.doorDownOpen.z)
end)

RegisterNetEvent('sb_mechanic:closeDoorDown')
AddEventHandler('sb_mechanic:closeDoorDown', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end
    if not state.downDoorIsOpen then return end

    state.downDoorIsOpen = false
    local door = state.doorDownID
    if not DoesEntityExist(door) then return end

    for i = 1, cfg.doorSteps do
        Wait(1)
        SetEntityCoords(door, GetOffsetFromEntityInWorldCoords(door, 0, 0, -cfg.doorStepSize))
    end
    SetEntityCoords(door, cfg.doorDownClosed.x, cfg.doorDownClosed.y, cfg.doorDownClosed.z)
end)

RegisterNetEvent('sb_mechanic:closeDoorDownIfNotBusy')
AddEventHandler('sb_mechanic:closeDoorDownIfNotBusy', function(elevId)
    local state = GetElev(elevId)
    if not state or state.isInUse then return end
    TriggerEvent('sb_mechanic:closeDoorDown', elevId)
end)

RegisterNetEvent('sb_mechanic:openDoorUp')
AddEventHandler('sb_mechanic:openDoorUp', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end
    if state.upDoorIsOpen then return end

    state.upDoorIsOpen = true
    local door = state.doorUpID
    if not DoesEntityExist(door) then return end

    for i = 1, cfg.doorSteps do
        Wait(1)
        SetEntityCoords(door, GetOffsetFromEntityInWorldCoords(door, 0, 0, cfg.doorStepSize))
    end
    SetEntityCoords(door, cfg.doorUpOpen.x, cfg.doorUpOpen.y, cfg.doorUpOpen.z)
end)

RegisterNetEvent('sb_mechanic:closeDoorUp')
AddEventHandler('sb_mechanic:closeDoorUp', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end
    if not state.upDoorIsOpen then return end

    state.upDoorIsOpen = false
    local door = state.doorUpID
    if not DoesEntityExist(door) then return end

    for i = 1, cfg.doorSteps do
        Wait(1)
        SetEntityCoords(door, GetOffsetFromEntityInWorldCoords(door, 0, 0, -cfg.doorStepSize))
    end
    SetEntityCoords(door, cfg.doorUpClosed.x, cfg.doorUpClosed.y, cfg.doorUpClosed.z)
end)

RegisterNetEvent('sb_mechanic:closeDoorUpIfNotBusy')
AddEventHandler('sb_mechanic:closeDoorUpIfNotBusy', function(elevId)
    local state = GetElev(elevId)
    if not state or state.isInUse then return end
    TriggerEvent('sb_mechanic:closeDoorUp', elevId)
end)

-- ============================================================================
-- Elevator movement
-- ============================================================================

-- Stepped up movement (intermediate phase, slower)
RegisterNetEvent('sb_mechanic:StepUp')
AddEventHandler('sb_mechanic:StepUp', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    state.isInUse = true
    local nbStep = (cfg.elevationHeight * 100) / 6

    for i = 0, nbStep do
        Wait(cfg.moveStepWait)
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz + cfg.moveStepSize)
    end
end)

-- Stepped down movement (intermediate phase, slower)
RegisterNetEvent('sb_mechanic:StepDown')
AddEventHandler('sb_mechanic:StepDown', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    state.isInUse = true
    local nbStep = (cfg.elevationHeight * 100) / 6

    for i = 0, nbStep do
        Wait(cfg.moveStepWait)
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz - cfg.moveStepSize)
    end
end)

-- Step up + open door at top (final phase of cabin "Go Up")
RegisterNetEvent('sb_mechanic:StepUpAndDoor')
AddEventHandler('sb_mechanic:StepUpAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    state.isUp = true
    state.isInUse = true
    local nbStep = (cfg.elevationHeight * 100) / 6

    for i = 0, nbStep do
        Wait(cfg.moveStepWait)
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz + cfg.moveStepSize)
    end

    SetEntityCoords(elev, cfg.posUp.x, cfg.posUp.y, cfg.posUp.z)
    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic:openDoorUp', elevId)

    -- Unfreeze vehicles
    local vehs = GetNearbyVehicles(cfg.posUp, cfg.vehicleDetectRadius)
    TriggerServerEvent('sb_mechanic:askVehUnFreeze', vehs, elevId)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

-- Step down + open door at bottom (final phase of cabin "Go Down")
RegisterNetEvent('sb_mechanic:StepDownAndDoor')
AddEventHandler('sb_mechanic:StepDownAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    state.isUp = false
    state.isInUse = true
    local nbStep = (cfg.elevationHeight * 100) / 6

    for i = 0, nbStep do
        Wait(cfg.moveStepWait)
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz - cfg.moveStepSize)
    end

    SetEntityCoords(elev, cfg.posDown.x, cfg.posDown.y, cfg.posDown.z)
    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic:openDoorDown', elevId)

    -- Unfreeze vehicles
    local vehs = GetNearbyVehicles(cfg.posDown, cfg.vehicleDetectRadius)
    TriggerServerEvent('sb_mechanic:askVehUnFreeze', vehs, elevId)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

-- Fast up + open door (wall call when elevator is below)
RegisterNetEvent('sb_mechanic:upAndDoor')
AddEventHandler('sb_mechanic:upAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    state.isUp = true
    state.isInUse = true
    local nbStep = (cfg.elevationHeight * 100) / 6

    for i = 0, nbStep do
        Wait(cfg.fastMoveStepWait)
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz + cfg.fastMoveStepSize)
    end

    SetEntityCoords(elev, cfg.posUp.x, cfg.posUp.y, cfg.posUp.z)
    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic:openDoorUp', elevId)

    local vehs = GetNearbyVehicles(cfg.posUp, cfg.vehicleDetectRadius)
    TriggerServerEvent('sb_mechanic:askVehUnFreeze', vehs, elevId)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

-- Fast down + open door (wall call when elevator is above)
RegisterNetEvent('sb_mechanic:downAndDoor')
AddEventHandler('sb_mechanic:downAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    state.isUp = false
    state.isInUse = true
    local nbStep = (cfg.elevationHeight * 100) / 6

    for i = 0, nbStep do
        Wait(cfg.fastMoveStepWait)
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz - cfg.fastMoveStepSize)
    end

    SetEntityCoords(elev, cfg.posDown.x, cfg.posDown.y, cfg.posDown.z)
    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic:openDoorDown', elevId)

    local vehs = GetNearbyVehicles(cfg.posDown, cfg.vehicleDetectRadius)
    TriggerServerEvent('sb_mechanic:askVehUnFreeze', vehs, elevId)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

-- ============================================================================
-- Vehicle attach/detach
-- ============================================================================

RegisterNetEvent('sb_mechanic:FreezeVeh')
AddEventHandler('sb_mechanic:FreezeVeh', function(netId, elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local curVeh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(curVeh) then return end

    local heading = GetEntityHeading(curVeh)
    RequestEntityControl(curVeh)

    local platPos = state.isUp and cfg.posUp or cfg.posDown
    local vehPos = GetEntityCoords(curVeh)

    local dx = vehPos.x - platPos.x
    local dy = vehPos.y - platPos.y
    local dz = vehPos.z - platPos.z
    local distAttach = -math.sqrt(dx * dx + dy * dy)

    AttachEntityToEntity(curVeh, state.elevateID, 0,
        0, distAttach, dz,
        0, 0, heading - cfg.elevatorHeading,
        0, false, true, false, 2, true)
end)

RegisterNetEvent('sb_mechanic:UnFreezeVeh')
AddEventHandler('sb_mechanic:UnFreezeVeh', function(netId, elevId)
    local curVeh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(curVeh) then return end

    RequestEntityControl(curVeh)
    DetachEntity(curVeh, true, true)
end)

-- ============================================================================
-- State sync from server
-- ============================================================================

RegisterNetEvent('sb_mechanic:sendStatus')
AddEventHandler('sb_mechanic:sendStatus', function(serverStates)
    for elevId, serverState in pairs(serverStates) do
        local state = GetElev(elevId)
        if state then
            state.isUp = serverState.isUp
        end
    end
    isReady = true
end)

-- ============================================================================
-- Initialization
-- ============================================================================

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('sb_mechanic:GetStatus')
end)

Citizen.CreateThread(function()
    -- Request status on resource start (handles restarts)
    TriggerServerEvent('sb_mechanic:GetStatus')

    -- Wait until ready
    while not isReady do
        Wait(100)
    end

    -- Create blip and target zones
    CreateBlip()
    RegisterTargetZones()

    Debug('sb_mechanic initialized')
end)
