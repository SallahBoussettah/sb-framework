-- ============================================================================
-- SB_DOORLOCK - Client Main
-- Door locking system with job-based authorization
-- ============================================================================

local SBCore = exports['sb_core']:GetCoreObject()

-- Door state tracking
local DoorStates = {}           -- Current lock states
local DoorObjects = {}          -- Door entity handles
local DoorHashes = {}           -- Door system hashes
local BypassedDoors = {}        -- Doors bypassed by heist (destroyed)
local PlayerJob = nil           -- Cached player job (updated on job change)

-- ============================================================================
-- JOB CHANGE HANDLING
-- ============================================================================

-- Update cached job when it changes
RegisterNetEvent('sb_core:client:OnJobUpdate', function(job)
    PlayerJob = job
    print(('[sb_doorlock] ^5Job updated: %s (grade %d)^7'):format(job.name, job.grade.level))
end)

-- Also listen for player data updates
RegisterNetEvent('sb_core:client:UpdatePlayer', function(data)
    if data and data.job then
        PlayerJob = data.job
        print(('[sb_doorlock] ^5Player data updated, job: %s^7'):format(data.job.name))
    end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function Notify(msg, type, duration)
    exports['sb_notify']:Notify(msg, type or 'info', duration or 3000)
end

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end
    end
end

local function GetDoorHash(door, index)
    return ('door_%s_%d'):format(door.id, index or 1)
end

-- Convert unsigned 32-bit hash to signed (GTA uses signed hashes)
local function ToSignedHash(hash)
    if hash > 0x7FFFFFFF then
        return hash - 0x100000000
    end
    return hash
end

-- Track barrier entities and their original positions
local BarrierEntities = {}  -- [doorId] = { entity, originalCoords }

-- Track door entities for freeze-based locking (MLO doors)
local DoorEntities = {}  -- [doorId] = { entity, closedHeading }

-- Find and cache barrier entity
local function GetBarrierEntity(door)
    if BarrierEntities[door.id] and DoesEntityExist(BarrierEntities[door.id].entity) then
        return BarrierEntities[door.id].entity, BarrierEntities[door.id].originalCoords
    end

    local modelHash = door.modelHash or GetHashKey(door.model)
    modelHash = ToSignedHash(modelHash)

    -- Find the closest object of this type
    local obj = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 3.0, modelHash, false, false, false)

    if obj and obj ~= 0 then
        local originalCoords = GetEntityCoords(obj)
        BarrierEntities[door.id] = {
            entity = obj,
            originalCoords = originalCoords
        }
        print(('[sb_doorlock] ^2Found barrier entity: %s | entity=%d | coords=%.2f,%.2f,%.2f^7'):format(
            door.id, obj, originalCoords.x, originalCoords.y, originalCoords.z))
        return obj, originalCoords
    end

    print(('[sb_doorlock] ^1Barrier entity NOT FOUND: %s | hash=%d^7'):format(door.id, modelHash))
    return nil, nil
end

-- Set barrier state (move up/down)
local function SetBarrierState(door, locked)
    local entity, originalCoords = GetBarrierEntity(door)
    if not entity then return false end

    if locked then
        -- Closed/Up - move to original position
        SetEntityCoords(entity, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
        FreezeEntityPosition(entity, true)
    else
        -- Open/Down - move down
        local offset = door.openOffset or vector3(0, 0, -2.0)
        local newZ = originalCoords.z + offset.z
        SetEntityCoords(entity, originalCoords.x + offset.x, originalCoords.y + offset.y, newZ, false, false, false, false)
        FreezeEntityPosition(entity, true)
    end

    return true
end

-- ============================================================================
-- ENTITY-BASED DOOR LOCKING (for MLO doors that ignore native door system)
-- Used when door has enforceState = true
-- ============================================================================

-- Find and cache a door entity
local function GetDoorEntity(door)
    -- Check cache first
    local cached = DoorEntities[door.id]
    if cached and DoesEntityExist(cached.entity) then
        return cached.entity, cached.closedHeading
    end

    -- Clear stale cache
    DoorEntities[door.id] = nil

    local modelHash = door.modelHash or GetHashKey(door.model)
    modelHash = ToSignedHash(modelHash)

    local obj = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 2.0, modelHash, false, false, false)

    if obj and obj ~= 0 then
        -- Capture the entity's heading right now as the "closed" position
        -- This works because GTA spawns MLO objects in their default (closed) state
        local heading = GetEntityHeading(obj)
        DoorEntities[door.id] = {
            entity = obj,
            closedHeading = heading
        }
        print(('[sb_doorlock] ^2Found door entity: %s | entity=%d | heading=%.1f^7'):format(door.id, obj, heading))
        return obj, heading
    end

    return nil, nil
end

-- Freeze/unfreeze a door entity to physically prevent pushing
-- @param resetHeading: if true, snap door back to closed rotation before freezing
local function SetDoorEntityState(door, locked, resetHeading)
    local entity, closedHeading = GetDoorEntity(door)
    if not entity then return false end

    if locked then
        -- Snap back to closed position if requested (e.g. when re-locking after temp unlock)
        if resetHeading and closedHeading then
            FreezeEntityPosition(entity, false) -- must unfreeze to change heading
            SetEntityHeading(entity, closedHeading)
        end
        FreezeEntityPosition(entity, true)
    else
        -- Unfreeze so player can push it open
        FreezeEntityPosition(entity, false)
    end

    return true
end

-- ============================================================================
-- DOOR SYSTEM INITIALIZATION
-- ============================================================================

local function InitializeDoor(door, index)
    local doorIndex = index
    -- Support both model name (string) or direct modelHash (number)
    local modelHash = door.modelHash or GetHashKey(door.model)

    -- Convert to signed 32-bit hash (GTA uses signed hashes internally)
    modelHash = ToSignedHash(modelHash)

    print(('[sb_doorlock] ^3Initializing door: %s | modelHash: %d (0x%X) | coords: %.2f, %.2f, %.2f | type: %s | locked: %s^7'):format(
        door.id, modelHash, modelHash & 0xFFFFFFFF, door.coords.x, door.coords.y, door.coords.z, door.doorType or 'door', tostring(door.locked)))

    -- For prop barriers (bollards that move up/down)
    if door.doorType == 'barrier' then
        -- Barriers are handled by finding and moving the prop entity
        SetBarrierState(door, door.locked)
        print(('[sb_doorlock] ^2Barrier %s initialized - locked=%s^7'):format(door.id, tostring(door.locked)))
    -- For MLO doors with enforceState: use entity freeze (native door system doesn't work for MLO)
    elseif door.enforceState then
        local success = SetDoorEntityState(door, door.locked)
        print(('[sb_doorlock] ^2EnforceState door %s initialized - locked=%s (entity found: %s)^7'):format(door.id, tostring(door.locked), tostring(success)))
    -- For garage doors, use BOTH methods to ensure it works
    elseif door.doorType == 'garage' or door.vehicleActivated then
        -- Method 1: Door System (works for most doors)
        local hash = GetDoorHash(door, 1)
        DoorHashes[hash] = true
        AddDoorToSystem(
            GetHashKey(hash),
            modelHash,
            door.coords.x,
            door.coords.y,
            door.coords.z,
            false, false, false
        )
        local state = door.locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED
        DoorSystemSetDoorState(GetHashKey(hash), state, false, false)

        -- Method 2: SetStateOfClosestDoorOfType (backup for animated props)
        SetStateOfClosestDoorOfType(modelHash, door.coords.x, door.coords.y, door.coords.z, door.locked, 0.0, false)

        print(('[sb_doorlock] ^2Garage/Barrier %s initialized with BOTH methods (hash=%d, state=%d, locked=%s)^7'):format(door.id, modelHash, state, tostring(door.locked)))
    elseif door.doorType == 'double' and door.doors then
        -- For double doors
        for k, subDoor in ipairs(door.doors) do
            local hash = GetDoorHash(door, k)
            DoorHashes[hash] = true

            AddDoorToSystem(
                GetHashKey(hash),
                modelHash,
                subDoor.coords.x,
                subDoor.coords.y,
                subDoor.coords.z,
                false, false, false
            )

            -- Set initial state
            local state = door.locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED
            DoorSystemSetDoorState(GetHashKey(hash), state, false, false)

            if Config.Debug then
                print(('[sb_doorlock] Initialized double door: %s (part %d) - %s'):format(door.id, k, door.locked and 'LOCKED' or 'UNLOCKED'))
            end
        end
    else
        -- Single door
        local hash = GetDoorHash(door, 1)
        DoorHashes[hash] = true

        AddDoorToSystem(
            GetHashKey(hash),
            modelHash,
            door.coords.x,
            door.coords.y,
            door.coords.z,
            false, false, false
        )

        -- Set initial state
        local state = door.locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED
        DoorSystemSetDoorState(GetHashKey(hash), state, false, false)

        if Config.Debug then
            print(('[sb_doorlock] Initialized door: %s - %s'):format(door.id, door.locked and 'LOCKED' or 'UNLOCKED'))
        end
    end

    -- Track state
    DoorStates[door.id] = door.locked
end

local function InitializeAllDoors()
    for i, door in ipairs(Config.Doors) do
        InitializeDoor(door, i)
    end
    print('[sb_doorlock] All doors initialized')
end

-- ============================================================================
-- DOOR STATE MANAGEMENT
-- ============================================================================

local function SetDoorState(doorId, locked, playSound)
    local door = Config.GetDoorById(doorId)
    if not door then
        print(('[sb_doorlock] ^1SetDoorState: Door not found: %s^7'):format(doorId))
        return
    end

    -- Check if door was bypassed (destroyed by heist)
    if BypassedDoors[doorId] then
        return -- Door is destroyed, can't lock/unlock
    end

    DoorStates[doorId] = locked

    -- Get model hash and convert to signed
    local modelHash = door.modelHash or GetHashKey(door.model)
    modelHash = ToSignedHash(modelHash)

    print(('[sb_doorlock] ^5SetDoorState: %s | locked=%s | modelHash=%d^7'):format(doorId, tostring(locked), modelHash))

    -- For prop barriers (bollards that move up/down)
    if door.doorType == 'barrier' then
        SetBarrierState(door, locked)
        print(('[sb_doorlock] ^2Barrier %s -> %s^7'):format(doorId, locked and 'CLOSED' or 'OPEN'))
    -- For MLO doors with enforceState: use entity freeze (native door system doesn't work)
    elseif door.enforceState then
        -- resetHeading=true when locking so door snaps back to closed position
        local success = SetDoorEntityState(door, locked, locked)
        print(('[sb_doorlock] ^2EnforceState door %s -> %s (entity found: %s)^7'):format(doorId, locked and 'LOCKED/FROZEN' or 'UNLOCKED/UNFROZEN', tostring(success)))
    -- For garage doors, use BOTH methods
    elseif door.doorType == 'garage' or door.vehicleActivated then
        local state = locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED

        -- Method 1: Door System
        local hash = GetDoorHash(door, 1)
        DoorSystemSetDoorState(GetHashKey(hash), state, false, false)

        -- Method 2: SetStateOfClosestDoorOfType
        SetStateOfClosestDoorOfType(modelHash, door.coords.x, door.coords.y, door.coords.z, locked, 0.0, false)

        print(('[sb_doorlock] ^2Garage/Barrier %s -> BOTH methods (hash=%d, state=%d, locked=%s)^7'):format(
            doorId, modelHash, state, tostring(locked)))
    elseif door.doorType == 'double' and door.doors then
        local state = locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED
        for k, _ in ipairs(door.doors) do
            local hash = GetDoorHash(door, k)
            DoorSystemSetDoorState(GetHashKey(hash), state, false, false)
        end
        print(('[sb_doorlock] ^2Double door %s -> DoorSystemSetDoorState state=%d^7'):format(doorId, state))
    else
        local state = locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED
        local hash = GetDoorHash(door, 1)
        DoorSystemSetDoorState(GetHashKey(hash), state, false, false)
        print(('[sb_doorlock] ^2Single door %s -> DoorSystemSetDoorState hash=%s state=%d^7'):format(doorId, hash, state))
    end

    -- Play sound
    if playSound then
        local sound = locked and Config.Sounds.lock or Config.Sounds.unlock
        -- PlaySoundFrontend(-1, sound.file, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    end
end

local function GetDoorState(doorId)
    return DoorStates[doorId]
end

-- ============================================================================
-- DOOR INTERACTION
-- ============================================================================

local function ToggleDoor(doorId, skipAnimation)
    local door = Config.GetDoorById(doorId)
    if not door then
        print(('[sb_doorlock] ^1ToggleDoor: Door not found: %s^7'):format(doorId))
        return
    end

    -- Check if bypassed
    if BypassedDoors[doorId] then
        Notify('This door has been destroyed', 'error')
        return
    end

    local currentState = GetDoorState(doorId)
    local newState = not currentState

    print(('[sb_doorlock] ^3ToggleDoor: %s | currentState=%s | newState=%s^7'):format(doorId, tostring(currentState), tostring(newState)))

    -- Request authorization from server
    SBCore.Functions.TriggerCallback('sb_doorlock:checkAccess', function(authorized, reason)
        if authorized then
            -- Play animation (skip for garage doors)
            if not skipAnimation and door.doorType ~= 'garage' then
                local ped = PlayerPedId()
                LoadAnimDict(Config.Animation.dict)
                TaskPlayAnim(ped, Config.Animation.dict, Config.Animation.anim, 8.0, 8.0, Config.Animation.duration, 16, 0, false, false, false)
                Wait(Config.Animation.duration)
            end

            -- Update state on server (broadcasts to all clients)
            TriggerServerEvent('sb_doorlock:updateState', doorId, newState)

            -- Also toggle linked door if exists
            if door.linkedDoor then
                TriggerServerEvent('sb_doorlock:updateState', door.linkedDoor, newState)
            end

            -- Different message for garage doors
            if door.doorType == 'garage' then
                Notify(newState and 'Gate closed' or 'Gate opened', 'success', 2000)
            else
                Notify(newState and 'Door locked' or 'Door unlocked', 'success')
            end
        else
            Notify(reason or 'Access denied', 'error')
        end
    end, doorId)
end

-- ============================================================================
-- SB_TARGET INTEGRATION
-- ============================================================================

-- Check if player is authorized for a door (client-side check)
local function IsPlayerAuthorized(door)
    -- If door is bypassed, no one can interact
    if BypassedDoors[door.id] then
        return false
    end

    -- Get FRESH player data from sb_core (don't cache, always fetch latest)
    local playerData = SBCore.Functions.GetPlayerData()
    if not playerData then return false end

    -- Update cached job reference
    if playerData.job then
        PlayerJob = playerData.job
    end

    -- Public access doors
    if door.allAuthorized then
        return true
    end

    -- Check job authorization using fresh data
    local job = playerData.job
    if door.authorizedJobs and job then
        local requiredGrade = door.authorizedJobs[job.name]
        if requiredGrade ~= nil then
            if job.grade and job.grade.level >= requiredGrade then
                return true
            end
        end
    end

    -- Check gang authorization
    if door.authorizedGangs and playerData.gang then
        local requiredGrade = door.authorizedGangs[playerData.gang.name]
        if requiredGrade ~= nil then
            if playerData.gang.grade.level >= requiredGrade then
                return true
            end
        end
    end

    -- Check item authorization (requires server callback for accuracy)
    -- For now, we'll let the server handle item checks

    -- No authorization found
    return false
end

local function SetupDoorTargets()
    if not Config.UseTarget then return end

    Wait(2000) -- Wait for sb_target to load

    for i, door in ipairs(Config.Doors) do
        -- Skip vault doors (handled by heist)
        if door.special == 'vault' then
            goto continue
        end

        local targetCoords = door.textCoords or door.coords
        local zoneName = 'doorlock_' .. door.id

        -- Different label/icon for garage doors
        local isGarage = door.doorType == 'garage'
        local label = isGarage and 'Open/Close Gate' or 'Toggle Door Lock'
        local icon = isGarage and 'fa-warehouse' or 'fa-lock'

        exports['sb_target']:AddSphereZone(zoneName, targetCoords, door.distance or 2.0, {
            {
                name = 'toggle_door_' .. door.id,
                label = label,
                icon = icon,
                distance = door.distance or 2.5,
                canInteract = function()
                    -- Only show option if player is authorized
                    return IsPlayerAuthorized(door)
                end,
                action = function()
                    ToggleDoor(door.id, isGarage) -- Skip animation for garage doors
                end
            }
        })

        ::continue::
    end

    print('[sb_doorlock] Door targets registered with sb_target')
end

-- ============================================================================
-- E-KEY PROXIMITY INTERACTION (Alternative to target)
-- ============================================================================

local function GetNearestDoor()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local nearestDoor = nil
    local nearestDist = 999.0

    for i, door in ipairs(Config.Doors) do
        if door.special ~= 'vault' then -- Skip vault doors
            local dist = #(pedCoords - door.coords)
            if dist < (door.distance or Config.DefaultDistance) and dist < nearestDist then
                nearestDist = dist
                nearestDoor = door
            end
        end
    end

    return nearestDoor, nearestDist
end

-- E-Key handler (if not using target)
if not Config.UseTarget then
    CreateThread(function()
        while true do
            local sleep = 500
            local door, dist = GetNearestDoor()

            if door and dist < (door.distance or Config.DefaultDistance) then
                sleep = 0

                -- Draw prompt
                local label = DoorStates[door.id] and '~g~[E]~w~ Unlock' or '~g~[E]~w~ Lock'
                if BypassedDoors[door.id] then
                    label = '~r~Door Destroyed'
                end

                SetTextComponentFormat('STRING')
                AddTextComponentString(label)
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)

                if IsControlJustPressed(0, Config.InteractKey) and not BypassedDoors[door.id] then
                    ToggleDoor(door.id)
                end
            end

            Wait(sleep)
        end
    end)
end

-- ============================================================================
-- VEHICLE HORN ACTIVATION (for garage doors)
-- ============================================================================

local function GetNearestVehicleDoor()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then return nil end

    local vehCoords = GetEntityCoords(vehicle)
    local nearestDoor = nil
    local nearestDist = 999.0

    for i, door in ipairs(Config.Doors) do
        -- Only consider doors that are vehicle-activated AND player is authorized
        if door.vehicleActivated and door.special ~= 'vault' and IsPlayerAuthorized(door) then
            local dist = #(vehCoords - door.coords)
            if dist < (door.distance or 8.0) and dist < nearestDist then
                nearestDist = dist
                nearestDoor = door
            end
        end
    end

    return nearestDoor, nearestDist
end

local function ToggleDoorFromVehicle(door)
    if not door then return end

    -- Check if bypassed
    if BypassedDoors[door.id] then return end

    -- Client-side pre-check (security - don't even try if not authorized)
    local authorized = IsPlayerAuthorized(door)
    local playerData = SBCore.Functions.GetPlayerData()
    local jobName = playerData and playerData.job and playerData.job.name or 'none'

    if Config.Debug then
        print(('[sb_doorlock] ^3Vehicle auth check: door=%s | job=%s | authorized=%s^7'):format(door.id, jobName, tostring(authorized)))
    end

    if not authorized then
        Notify('Access denied - ' .. jobName .. ' not authorized', 'error')
        return
    end

    local currentState = GetDoorState(door.id)
    local newState = not currentState

    print(('[sb_doorlock] ^3ToggleDoorFromVehicle: %s | currentState=%s | newState=%s^7'):format(door.id, tostring(currentState), tostring(newState)))

    -- Request authorization from server (double-check)
    SBCore.Functions.TriggerCallback('sb_doorlock:checkAccess', function(authorized, reason)
        if authorized then
            -- Update state on server (broadcasts to all clients)
            TriggerServerEvent('sb_doorlock:updateState', door.id, newState)

            -- Also toggle linked door if exists
            if door.linkedDoor then
                TriggerServerEvent('sb_doorlock:updateState', door.linkedDoor, newState)
            end

            Notify(newState and 'Gate closed' or 'Gate opened', 'success', 2000)
        else
            Notify(reason or 'Access denied', 'error')
        end
    end, door.id)
end

-- Vehicle horn detection thread
CreateThread(function()
    local hornCooldown = false

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
            local door, dist = GetNearestVehicleDoor()

            if door and dist < (door.distance or 8.0) then
                sleep = 0

                -- Check for horn press (E key / control 86)
                -- Use both regular and disabled check (sb_police disables horn when lights on)
                local hornPressed = IsControlJustPressed(0, 86) or IsDisabledControlJustPressed(0, 86)

                if hornPressed and not hornCooldown then
                    hornCooldown = true
                    ToggleDoorFromVehicle(door)

                    -- Short cooldown to prevent spam
                    Citizen.SetTimeout(1000, function()
                        hornCooldown = false
                    end)
                end
            end
        end

        Wait(sleep)
    end
end)

-- ============================================================================
-- HEIST BYPASS SYSTEM
-- ============================================================================

-- Called by sb_pacificheist when thermite destroys a door
RegisterNetEvent('sb_doorlock:bypassDoor', function(doorId)
    local door = Config.GetDoorById(doorId)
    if not door then return end

    BypassedDoors[doorId] = true
    DoorStates[doorId] = false

    -- Unlock the door permanently
    local state = Config.DoorStates.UNLOCKED

    if door.doorType == 'double' and door.doors then
        for k, _ in ipairs(door.doors) do
            local hash = GetDoorHash(door, k)
            DoorSystemSetDoorState(GetHashKey(hash), state, false, false)
        end
    else
        local hash = GetDoorHash(door, 1)
        DoorSystemSetDoorState(GetHashKey(hash), state, false, false)
    end

    if Config.Debug then
        print(('[sb_doorlock] Door %s BYPASSED (heist)'):format(doorId))
    end
end)

-- Reset bypassed doors (after heist reset)
RegisterNetEvent('sb_doorlock:resetBypass', function(doorId)
    if doorId then
        BypassedDoors[doorId] = nil
        local door = Config.GetDoorById(doorId)
        if door then
            SetDoorState(doorId, door.locked, false)
        end
    else
        -- Reset all
        BypassedDoors = {}
        for _, door in ipairs(Config.Doors) do
            SetDoorState(door.id, door.locked, false)
        end
    end
end)

-- ============================================================================
-- SERVER SYNC EVENTS
-- ============================================================================

RegisterNetEvent('sb_doorlock:setState', function(doorId, locked)
    print(('[sb_doorlock] ^5Client received setState: doorId=%s | locked=%s^7'):format(doorId, tostring(locked)))
    SetDoorState(doorId, locked, true)
end)

RegisterNetEvent('sb_doorlock:syncAllStates', function(states)
    for doorId, locked in pairs(states) do
        SetDoorState(doorId, locked, false)
    end
end)

-- ============================================================================
-- DEBUG
-- ============================================================================

if Config.Debug then
    CreateThread(function()
        while true do
            for i, door in ipairs(Config.Doors) do
                local color = DoorStates[door.id] and {255, 0, 0, 100} or {0, 255, 0, 100}
                if BypassedDoors[door.id] then
                    color = {255, 165, 0, 100} -- Orange for bypassed
                end
                DrawMarker(1, door.coords.x, door.coords.y, door.coords.z, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, color[1], color[2], color[3], color[4], false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        end
    end)
end

-- ============================================================================
-- STATE ENFORCEMENT THREAD
-- Continuously enforces door states to prevent GTA from auto-opening
-- ============================================================================

CreateThread(function()
    local lastDebugTime = 0

    while true do
        Wait(500) -- Check every 500ms

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local currentTime = GetGameTimer()

        for _, door in ipairs(Config.Doors) do
            -- Enforce for garage/barrier doors + any door with enforceState flag
            if (door.doorType == 'garage' or door.doorType == 'barrier' or door.vehicleActivated or door.enforceState) and not BypassedDoors[door.id] then
                local dist = #(playerCoords - door.coords)

                -- If player is near (within 50m), enforce the state
                if dist < 50.0 then
                    local locked = DoorStates[door.id]
                    if locked ~= nil then
                        if door.doorType == 'barrier' then
                            -- Barriers: move the prop entity
                            SetBarrierState(door, locked)
                        elseif door.enforceState then
                            -- MLO doors: use entity freeze (native door system doesn't work for MLO doors)
                            SetDoorEntityState(door, locked)
                        else
                            -- Garage doors: use door natives
                            local modelHash = door.modelHash or GetHashKey(door.model)
                            modelHash = ToSignedHash(modelHash)
                            local state = locked and Config.DoorStates.LOCKED or Config.DoorStates.UNLOCKED

                            -- Method 1: Door System
                            local hash = GetDoorHash(door, 1)
                            DoorSystemSetDoorState(GetHashKey(hash), state, false, false)

                            -- Method 2: SetStateOfClosestDoorOfType
                            SetStateOfClosestDoorOfType(modelHash, door.coords.x, door.coords.y, door.coords.z, locked, 0.0, false)
                        end

                        -- Debug output every 5 seconds
                        if Config.Debug and (currentTime - lastDebugTime) > 5000 and dist < 15.0 then
                            print(('[sb_doorlock] ^6Enforcing state: %s | type=%s | locked=%s | dist=%.1f^7'):format(door.id, door.doorType, tostring(locked), dist))
                            lastDebugTime = currentTime
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    Wait(1000)
    InitializeAllDoors()
    SetupDoorTargets()

    -- Request current states from server
    TriggerServerEvent('sb_doorlock:requestStates')
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetDoorState', GetDoorState)
exports('SetDoorState', SetDoorState)
exports('ToggleDoor', function(doorId, skipAnimation)
    ToggleDoor(doorId, skipAnimation)
end)
exports('BypassDoor', function(doorId)
    TriggerEvent('sb_doorlock:bypassDoor', doorId)
end)
exports('ResetBypass', function(doorId)
    TriggerEvent('sb_doorlock:resetBypass', doorId)
end)
