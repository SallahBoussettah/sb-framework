-- sb_mechanic_v2 | Client Elevator
-- Prop management, door animations, platform movement, vehicle + player sync
-- Vehicle sync via AttachEntityToEntity (original patoche approach)

local SB = exports['sb_core']:GetCoreObject()

-- ===================================================================
-- STATE
-- ===================================================================
local elevators = {}
local targetZones = {}
local isReady = false

local elevatorMoving = {}   -- [elevId] = true/false

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic_v2:elevator]', ...)
    end
end

-- ===================================================================
-- HELPERS
-- ===================================================================

local function IsMechanic()
    local playerData = SB.Functions.GetPlayerData()
    return playerData and playerData.job and Config.IsMechanicJob(playerData.job.name)
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

local function LoadModel(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    return hash
end

--- Request and await entity control with timeout
local function AwaitEntityControl(entity, timeout)
    timeout = timeout or 2000
    if NetworkHasControlOfEntity(entity) then return true end
    local start = GetGameTimer()
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        if GetGameTimer() - start > timeout then return false end
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

-- ===================================================================
-- VEHICLE DETECTION
-- ===================================================================

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

-- ===================================================================
-- PROP MANAGEMENT
-- ===================================================================

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

    local lodDist = 120

    -- Elevator platform
    if not DoesEntityExist(state.elevateID) then
        local pos = state.isUp and cfg.posUp or cfg.posDown
        local spawnPos = vector3(pos.x, pos.y, pos.z + cfg.spawnOffsetZ)
        state.elevateID = FindOrCreateProp(cfg.elevatorProp, spawnPos, cfg.elevatorHeading, cfg.elevatorRotation)
        Debug('Spawned elevator prop:', state.elevateID)
    else
        SetEntityVisible(state.elevateID, true)
    end
    SetEntityLodDist(state.elevateID, lodDist)

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
    SetEntityLodDist(state.doorDownID, lodDist)

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
    SetEntityLodDist(state.doorUpID, lodDist)
end

-- ===================================================================
-- STATE INIT
-- ===================================================================

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
    elevatorMoving[elevId] = false
end

for _, elev in ipairs(Config.Elevators) do
    InitElevatorState(elev.id)
end

-- ===================================================================
-- BLIP
-- ===================================================================

local function CreateBlip()
    if not Config.Blip or not Config.Blip.enabled then return end
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

-- ===================================================================
-- TARGET ZONES
-- ===================================================================

local function RegisterTargetZones()
    for _, cfg in ipairs(Config.Elevators) do
        local elevId = cfg.id

        -- Wall control - upper floor (call elevator)
        targetZones[elevId .. '_wall_up'] = exports['sb_target']:AddSphereZone(
            'mechv2_' .. elevId .. '_wall_up',
            cfg.controlUp,
            cfg.controlDistance,
            {
                {
                    name = 'mechv2_call_up_' .. elevId,
                    label = 'Call Elevator',
                    icon = 'fa-elevator',
                    distance = cfg.controlDistance + 0.5,
                    canInteract = function()
                        return IsMechanic()
                    end,
                    action = function()
                        TriggerServerEvent('sb_mechanic_v2:requestElevator', elevId, 'up', 'wall')
                    end
                }
            }
        )

        -- Wall control - lower floor (call elevator)
        targetZones[elevId .. '_wall_down'] = exports['sb_target']:AddSphereZone(
            'mechv2_' .. elevId .. '_wall_down',
            cfg.controlDown,
            cfg.controlDistance,
            {
                {
                    name = 'mechv2_call_down_' .. elevId,
                    label = 'Call Elevator',
                    icon = 'fa-elevator',
                    distance = cfg.controlDistance + 0.5,
                    canInteract = function()
                        return IsMechanic()
                    end,
                    action = function()
                        TriggerServerEvent('sb_mechanic_v2:requestElevator', elevId, 'down', 'wall')
                    end
                }
            }
        )

        -- Cabin control - upper floor (go down)
        targetZones[elevId .. '_cabin_up'] = exports['sb_target']:AddSphereZone(
            'mechv2_' .. elevId .. '_cabin_up',
            cfg.controlCabinUp,
            cfg.cabinDistance,
            {
                {
                    name = 'mechv2_godown_' .. elevId,
                    label = 'Go Down',
                    icon = 'fa-arrow-down',
                    distance = cfg.cabinDistance + 0.3,
                    canInteract = function()
                        return IsMechanic()
                    end,
                    action = function()
                        TriggerServerEvent('sb_mechanic_v2:requestElevator', elevId, 'down', 'cabin')
                    end
                }
            }
        )

        -- Cabin control - lower floor (go up)
        targetZones[elevId .. '_cabin_down'] = exports['sb_target']:AddSphereZone(
            'mechv2_' .. elevId .. '_cabin_down',
            cfg.controlCabinDown,
            cfg.cabinDistance,
            {
                {
                    name = 'mechv2_goup_' .. elevId,
                    label = 'Go Up',
                    icon = 'fa-arrow-up',
                    distance = cfg.cabinDistance + 0.3,
                    canInteract = function()
                        return IsMechanic()
                    end,
                    action = function()
                        TriggerServerEvent('sb_mechanic_v2:requestElevator', elevId, 'up', 'cabin')
                    end
                }
            }
        )
    end
end

-- ===================================================================
-- DOOR ANIMATIONS
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:openDoorDown')
AddEventHandler('sb_mechanic_v2:openDoorDown', function(elevId)
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

RegisterNetEvent('sb_mechanic_v2:closeDoorDown')
AddEventHandler('sb_mechanic_v2:closeDoorDown', function(elevId)
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

RegisterNetEvent('sb_mechanic_v2:closeDoorDownIfNotBusy')
AddEventHandler('sb_mechanic_v2:closeDoorDownIfNotBusy', function(elevId)
    local state = GetElev(elevId)
    if not state or state.isInUse then return end
    TriggerEvent('sb_mechanic_v2:closeDoorDown', elevId)
end)

RegisterNetEvent('sb_mechanic_v2:openDoorUp')
AddEventHandler('sb_mechanic_v2:openDoorUp', function(elevId)
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

RegisterNetEvent('sb_mechanic_v2:closeDoorUp')
AddEventHandler('sb_mechanic_v2:closeDoorUp', function(elevId)
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

RegisterNetEvent('sb_mechanic_v2:closeDoorUpIfNotBusy')
AddEventHandler('sb_mechanic_v2:closeDoorUpIfNotBusy', function(elevId)
    local state = GetElev(elevId)
    if not state or state.isInUse then return end
    TriggerEvent('sb_mechanic_v2:closeDoorUp', elevId)
end)

-- ===================================================================
-- CORE STEP LOOP (shared by all movement handlers)
-- ===================================================================

--- Run N steps of elevator movement, moving prop each tick
--- Player rides naturally via collision with gravity disabled
local function RunSteps(elevId, direction, stepWait)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local elev = state.elevateID
    if not DoesEntityExist(elev) then return end

    local sign = (direction == 'up') and 1 or -1
    local delta = cfg.moveStepSize * sign
    local nbStep = math.floor((cfg.elevationHeight * 100) / 6)

    elevatorMoving[elevId] = true

    -- Disable gravity + ragdoll so ped rides the platform via collision
    -- without falling through on descent or bouncing
    local ped = PlayerPedId()
    SetPedGravity(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedConfigFlag(ped, 164, true)  -- prevent fall-trigger ragdoll

    for i = 0, nbStep do
        Wait(stepWait)
        -- Move elevator prop
        local cx, cy, cz = table.unpack(GetEntityCoords(elev))
        SetEntityCoords(elev, cx, cy, cz + delta)
    end
end

-- ===================================================================
-- ELEVATOR MOVEMENT — STEPPED (cabin controls, 5 intermediate + 1 final)
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:StepUp')
AddEventHandler('sb_mechanic_v2:StepUp', function(elevId)
    local state = GetElev(elevId)
    if not state then return end
    state.isInUse = true
    RunSteps(elevId, 'up', GetElevConfig(elevId).moveStepWait)
end)

RegisterNetEvent('sb_mechanic_v2:StepDown')
AddEventHandler('sb_mechanic_v2:StepDown', function(elevId)
    local state = GetElev(elevId)
    if not state then return end
    state.isInUse = true
    RunSteps(elevId, 'down', GetElevConfig(elevId).moveStepWait)
end)

-- Final step + open door at destination

RegisterNetEvent('sb_mechanic_v2:StepUpAndDoor')
AddEventHandler('sb_mechanic_v2:StepUpAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    state.isUp = true
    state.isInUse = true
    RunSteps(elevId, 'up', cfg.moveStepWait)

    -- Snap to final position
    if DoesEntityExist(state.elevateID) then
        SetEntityCoords(state.elevateID, cfg.posUp.x, cfg.posUp.y, cfg.posUp.z)
    end

    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic_v2:openDoorUp', elevId)

    -- Detach vehicles at destination
    TriggerServerEvent('sb_mechanic_v2:askVehDetach', elevId)

    elevatorMoving[elevId] = false
    SetPedGravity(PlayerPedId(), true)
    SetPedCanRagdoll(PlayerPedId(), true)
    SetPedConfigFlag(PlayerPedId(), 164, false)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

RegisterNetEvent('sb_mechanic_v2:StepDownAndDoor')
AddEventHandler('sb_mechanic_v2:StepDownAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    state.isUp = false
    state.isInUse = true
    RunSteps(elevId, 'down', cfg.moveStepWait)

    -- Snap to final position
    if DoesEntityExist(state.elevateID) then
        SetEntityCoords(state.elevateID, cfg.posDown.x, cfg.posDown.y, cfg.posDown.z)
    end

    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic_v2:openDoorDown', elevId)

    -- Detach vehicles at destination
    TriggerServerEvent('sb_mechanic_v2:askVehDetach', elevId)

    elevatorMoving[elevId] = false
    SetPedGravity(PlayerPedId(), true)
    SetPedCanRagdoll(PlayerPedId(), true)
    SetPedConfigFlag(PlayerPedId(), 164, false)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

-- ===================================================================
-- ELEVATOR MOVEMENT — FAST (wall call, uses fastMoveStepWait)
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:upAndDoor')
AddEventHandler('sb_mechanic_v2:upAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    state.isUp = true
    state.isInUse = true
    RunSteps(elevId, 'up', cfg.fastMoveStepWait)

    -- Snap to final position
    if DoesEntityExist(state.elevateID) then
        SetEntityCoords(state.elevateID, cfg.posUp.x, cfg.posUp.y, cfg.posUp.z)
    end

    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic_v2:openDoorUp', elevId)

    -- Detach vehicles at destination
    TriggerServerEvent('sb_mechanic_v2:askVehDetach', elevId)

    elevatorMoving[elevId] = false
    SetPedGravity(PlayerPedId(), true)
    SetPedCanRagdoll(PlayerPedId(), true)
    SetPedConfigFlag(PlayerPedId(), 164, false)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

RegisterNetEvent('sb_mechanic_v2:downAndDoor')
AddEventHandler('sb_mechanic_v2:downAndDoor', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    state.isUp = false
    state.isInUse = true
    RunSteps(elevId, 'down', cfg.fastMoveStepWait)

    -- Snap to final position
    if DoesEntityExist(state.elevateID) then
        SetEntityCoords(state.elevateID, cfg.posDown.x, cfg.posDown.y, cfg.posDown.z)
    end

    Wait(cfg.arrivalDoorDelay)
    TriggerEvent('sb_mechanic_v2:openDoorDown', elevId)

    -- Detach vehicles at destination
    TriggerServerEvent('sb_mechanic_v2:askVehDetach', elevId)

    elevatorMoving[elevId] = false
    SetPedGravity(PlayerPedId(), true)
    SetPedCanRagdoll(PlayerPedId(), true)
    SetPedConfigFlag(PlayerPedId(), 164, false)

    Wait(cfg.arrivalUnlockDelay)
    state.isInUse = false
end)

-- ===================================================================
-- VEHICLE ATTACH / DETACH (original patoche approach)
-- Vehicles are attached to the elevator entity so they move with it
-- ===================================================================

--- Server broadcasts this before movement — each client scans for vehicles
--- near the platform and attaches them to the elevator prop
RegisterNetEvent('sb_mechanic_v2:scanAndAttachVehicles')
AddEventHandler('sb_mechanic_v2:scanAndAttachVehicles', function(elevId, pos, radius)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end
    if not DoesEntityExist(state.elevateID) then return end

    local vehicles = GetNearbyVehicles(pos, radius)
    for _, v in ipairs(vehicles) do
        local veh = v.entity
        if DoesEntityExist(veh) and AwaitEntityControl(veh, 1000) then
            local vehPos = GetEntityCoords(veh)
            local platPos = GetEntityCoords(state.elevateID)
            local offsetX = vehPos.x - platPos.x
            local offsetY = vehPos.y - platPos.y
            local offsetZ = vehPos.z - platPos.z
            local distAttach = -math.sqrt(offsetX * offsetX + offsetY * offsetY)
            local headingOffset = GetEntityHeading(veh) - cfg.elevatorHeading

            AttachEntityToEntity(veh, state.elevateID, 0,
                0, distAttach, offsetZ,
                0, 0, headingOffset,
                0, false, true, false, 2, true)

            Debug('Scan attached vehicle', v.netId, 'to elevator', elevId)
        end
    end
end)

--- Server broadcasts this on arrival — each client detaches vehicles it controls
RegisterNetEvent('sb_mechanic_v2:DetachAllOnPlatform')
AddEventHandler('sb_mechanic_v2:DetachAllOnPlatform', function(elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local checkPos = state.isUp and cfg.posUp or cfg.posDown
    local vehicles = GetNearbyVehicles(checkPos, cfg.vehicleDetectRadius + 5.0)
    for _, v in ipairs(vehicles) do
        if DoesEntityExist(v.entity) and IsEntityAttachedToEntity(v.entity, state.elevateID) then
            if AwaitEntityControl(v.entity, 1000) then
                DetachEntity(v.entity, true, true)
                Debug('Detached vehicle', v.netId, 'from elevator', elevId)
            end
        end
    end
end)

RegisterNetEvent('sb_mechanic_v2:AttachVeh')
AddEventHandler('sb_mechanic_v2:AttachVeh', function(netId, elevId)
    local cfg = GetElevConfig(elevId)
    local state = GetElev(elevId)
    if not cfg or not state then return end

    local curVeh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(curVeh) then return end
    if not DoesEntityExist(state.elevateID) then return end

    if not AwaitEntityControl(curVeh, 3000) then
        Debug('Failed to get control of vehicle', netId)
        return
    end

    -- Calculate relative offset from vehicle to elevator platform
    local vehPos = GetEntityCoords(curVeh)
    local platPos = GetEntityCoords(state.elevateID)
    local offsetX = vehPos.x - platPos.x
    local offsetY = vehPos.y - platPos.y
    local offsetZ = vehPos.z - platPos.z

    -- Distance on the XY plane (negative for attachment)
    local distAttach = -math.sqrt(offsetX * offsetX + offsetY * offsetY)

    -- Heading offset relative to elevator
    local vehHeading = GetEntityHeading(curVeh)
    local headingOffset = vehHeading - cfg.elevatorHeading

    AttachEntityToEntity(curVeh, state.elevateID, 0,
        0, distAttach, offsetZ,
        0, 0, headingOffset,
        0, false, true, false, 2, true)

    Debug('Attached vehicle', netId, 'to elevator', elevId)
end)

RegisterNetEvent('sb_mechanic_v2:DetachVeh')
AddEventHandler('sb_mechanic_v2:DetachVeh', function(netId, elevId)
    local curVeh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(curVeh) then return end

    if AwaitEntityControl(curVeh, 2000) then
        DetachEntity(curVeh, true, true)
        Debug('Detached vehicle', netId)
    end
end)

-- ===================================================================
-- PLAYER GRAVITY SAFETY THREAD
-- Ensures gravity stays disabled while any elevator is moving
-- and re-enables it if the movement flag gets stuck
-- ===================================================================

CreateThread(function()
    while true do
        local anyMoving = false
        for _, moving in pairs(elevatorMoving) do
            if moving then
                anyMoving = true
                break
            end
        end

        if anyMoving then
            local ped = PlayerPedId()
            SetPedGravity(ped, false)
            SetPedCanRagdoll(ped, false)
            SetPedConfigFlag(ped, 164, true)
            Wait(100)
        else
            Wait(1000)
        end
    end
end)

-- ===================================================================
-- ELEVATOR BUSY / FREE (server tells client to update isInUse)
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:elevatorBusy')
AddEventHandler('sb_mechanic_v2:elevatorBusy', function(elevId)
    local state = GetElev(elevId)
    if state then
        state.isInUse = true
    end
end)

RegisterNetEvent('sb_mechanic_v2:elevatorFree')
AddEventHandler('sb_mechanic_v2:elevatorFree', function(elevId)
    local state = GetElev(elevId)
    if state then
        state.isInUse = false
    end
end)

-- ===================================================================
-- STATE SYNC (from server on join/restart)
-- ===================================================================

RegisterNetEvent('sb_mechanic_v2:sendStatus')
AddEventHandler('sb_mechanic_v2:sendStatus', function(serverStates)
    for elevId, serverState in pairs(serverStates) do
        local state = GetElev(elevId)
        if state then
            state.isUp = serverState.isUp
            state.isInUse = serverState.isInUse
        end
    end

    -- Now ensure props exist at correct positions
    for _, cfg in ipairs(Config.Elevators) do
        EnsureProps(cfg.id)
    end

    isReady = true
    Debug('Elevator state synced from server')
end)

-- ===================================================================
-- PROXIMITY-BASED PROP SPAWNING
-- ===================================================================

CreateThread(function()
    while true do
        Wait(2000)
        local playerPos = GetEntityCoords(PlayerPedId())
        for _, cfg in ipairs(Config.Elevators) do
            local dist = #(playerPos - cfg.posUp)
            local distDown = #(playerPos - cfg.posDown)
            if dist < cfg.spawnDistance or distDown < cfg.spawnDistance then
                EnsureProps(cfg.id)
            end
        end
    end
end)

-- ===================================================================
-- INIT
-- ===================================================================

CreateThread(function()
    -- Request elevator state from server on start
    TriggerServerEvent('sb_mechanic_v2:GetStatus')

    while not isReady do
        Wait(100)
    end

    CreateBlip()
    RegisterTargetZones()

    Debug('Elevator + blip initialized')
end)

-- ===================================================================
-- CLEANUP
-- ===================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    SetPedGravity(ped, true)
    SetPedCanRagdoll(ped, true)
    SetPedConfigFlag(ped, 164, false)
end)

-- ===================================================================
-- EXPORT: IsMechanic (for other client files)
-- ===================================================================

exports('IsMechanic', IsMechanic)
