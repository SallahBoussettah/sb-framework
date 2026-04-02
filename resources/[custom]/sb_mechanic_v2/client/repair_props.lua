-- sb_mechanic_v2 | Repair Props
-- Prop spawn/attach/cleanup with safety net

RepairProps = {}

-- Tracked props for cleanup
local ActiveProps = {}
local HandProp = 0
local SafetyTimer = nil

-- ===== LOAD MODEL =====
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

-- ===== SPAWN GROUND PROP =====
-- Creates a frozen, no-collision prop at a world position
function RepairProps.SpawnGroundProp(model, worldPos, rot)
    local hash = LoadModel(model)
    if not HasModelLoaded(hash) then return 0 end

    local obj = CreateObject(hash, worldPos.x, worldPos.y, worldPos.z, false, false, false)
    if obj == 0 then return 0 end

    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    if rot then
        SetEntityRotation(obj, rot.x, rot.y, rot.z, 0, false)
    end

    table.insert(ActiveProps, obj)
    return obj
end

-- ===== ATTACH HAND PROP =====
-- Attaches a prop to the player's right hand
function RepairProps.AttachHandProp(model)
    RepairProps.RemoveHandProp()  -- remove any existing

    local ped = PlayerPedId()
    local hash = LoadModel(model)
    if not HasModelLoaded(hash) then return 0 end

    local boneIndex = GetPedBoneIndex(ped, 57005)  -- SKEL_R_Hand
    local obj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
    if obj == 0 then return 0 end

    AttachEntityToEntity(obj, ped, boneIndex,
        0.0, 0.0, 0.0,  -- offset
        0.0, 0.0, 0.0,  -- rotation
        true, true, false, true, 1, true)

    HandProp = obj
    table.insert(ActiveProps, obj)
    return obj
end

-- ===== REMOVE HAND PROP =====
function RepairProps.RemoveHandProp()
    if HandProp ~= 0 and DoesEntityExist(HandProp) then
        DetachEntity(HandProp, true, true)
        DeleteEntity(HandProp)
    end
    HandProp = 0
end

-- ===== CLEANUP ALL PROPS =====
function RepairProps.CleanupAll()
    -- Remove hand prop
    RepairProps.RemoveHandProp()

    -- Remove all tracked ground props
    for i = #ActiveProps, 1, -1 do
        local prop = ActiveProps[i]
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        ActiveProps[i] = nil
    end
    ActiveProps = {}

    -- Cancel safety timer
    if SafetyTimer then
        SafetyTimer = nil
    end
end

-- ===== START SAFETY TIMER =====
-- Auto-cleanup after maxDuration + buffer in case of bugs
function RepairProps.StartSafetyTimer(maxDurationMs)
    local cleanupTime = GetGameTimer() + maxDurationMs + 5000
    SafetyTimer = cleanupTime

    CreateThread(function()
        while SafetyTimer and GetGameTimer() < SafetyTimer do
            Wait(1000)
        end
        if SafetyTimer then
            print('[sb_mechanic_v2] Safety timer triggered - cleaning up orphaned props')
            RepairProps.CleanupAll()
        end
    end)
end

-- ===== HOOD CONTROL =====
function RepairProps.OpenHood(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleDoorOpen(vehicle, 4, false, false)  -- 4 = hood
end

function RepairProps.CloseHood(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleDoorShut(vehicle, 4, false)
end

-- ===== SPAWN ZONE GROUND PROPS =====
-- Spawns ground props defined in a zone's setup relative to vehicle
function RepairProps.SpawnZoneGroundProps(vehicle, zone)
    if not zone or not zone.setup or not zone.setup.groundProps then return end

    local vehPos = GetEntityCoords(vehicle)
    local vehHeading = GetEntityHeading(vehicle)
    local headingRad = math.rad(vehHeading)

    for _, propDef in ipairs(zone.setup.groundProps) do
        -- Transform offset from vehicle-local to world coords
        local ox = propDef.offset.x
        local oy = propDef.offset.y
        local worldX = vehPos.x + ox * math.cos(headingRad) - oy * math.sin(headingRad)
        local worldY = vehPos.y + ox * math.sin(headingRad) + oy * math.cos(headingRad)
        local worldZ = vehPos.z + propDef.offset.z

        RepairProps.SpawnGroundProp(propDef.model, vector3(worldX, worldY, worldZ), propDef.rot)
    end
end

-- ===== DEATH HANDLER =====
-- Clean up props if player dies during repair
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local ped = PlayerPedId()
        if victim == ped and IsPedDeadOrDying(ped, true) then
            if #ActiveProps > 0 or HandProp ~= 0 then
                RepairProps.CleanupAll()
            end
        end
    end
end)

-- ===== RESOURCE STOP CLEANUP =====
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RepairProps.CleanupAll()
end)
