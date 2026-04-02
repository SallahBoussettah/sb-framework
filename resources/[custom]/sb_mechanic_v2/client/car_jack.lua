-- sb_mechanic_v2 | Car Jack System
-- Lift/lower vehicles for wheel and undercarriage repairs

local SB = exports['sb_core']:GetCoreObject()

CarJack = {}

-- Active jack props { [vehicleNetId] = { prop = entity, vehicle = entity } }
local ActiveJacks = {}

local JACK_LIFT_HEIGHT = 0.5  -- meters to lift
local JACK_PROP_MODEL = 'prop_car_jack'
local JACK_USE_DISTANCE = 3.0

-- ===== HELPER: Load model =====
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

-- ===== CHECK IF VEHICLE IS LIFTED =====
-- Returns true if vehicle is on jack OR on elevator (isUp = false means down/lifted for work)
function CarJack.IsLifted(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    -- Check jack state bag
    if Entity(vehicle).state.sb_lifted then
        return true
    end

    -- Check elevator: vehicle on elevator platform at lower level counts as lifted
    -- The elevator system sets isUp state; when down, the vehicle is in the pit for work
    for _, cfg in ipairs(Config.Elevators) do
        local vehPos = GetEntityCoords(vehicle)
        local distDown = #(vehPos - cfg.posDown)
        if distDown < cfg.vehicleDetectRadius then
            return true  -- vehicle is on elevator at lower level
        end
    end

    return false
end

-- ===== PLACE JACK =====
local function PlaceJack(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local plate = Entity(vehicle).state.sb_plate
    if not plate then
        exports['sb_notify']:Notify('Cannot identify vehicle.', 'error', 3000)
        return
    end

    -- Check if already jacked
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if ActiveJacks[netId] then
        exports['sb_notify']:Notify('Vehicle already on jack.', 'error', 3000)
        return
    end

    -- Check player has tool_jack
    SB.Functions.TriggerCallback('sb_mechanic_v2:hasItem', function(hasJack)
        if not hasJack then
            exports['sb_notify']:Notify('You need a Car Jack.', 'error', 3000)
            return
        end

        -- Progress bar for placing jack
        exports['sb_progressbar']:Start({
            duration = 3000,
            label = 'Placing car jack...',
            canCancel = true,
            animation = {
                dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                anim = 'machinic_loop_mechandplayer',
                flag = 1,
            },
            onComplete = function()
                if not DoesEntityExist(vehicle) then return end

                -- Spawn jack prop at side of vehicle
                local vehPos = GetEntityCoords(vehicle)
                local vehHeading = GetEntityHeading(vehicle)
                local headingRad = math.rad(vehHeading)
                local jackX = vehPos.x + (-1.0) * math.cos(headingRad)
                local jackY = vehPos.y + (-1.0) * math.sin(headingRad)
                local jackZ = vehPos.z - 0.5

                local hash = LoadModel(JACK_PROP_MODEL)
                local jackProp = 0
                if HasModelLoaded(hash) then
                    jackProp = CreateObject(hash, jackX, jackY, jackZ, false, false, false)
                    if jackProp ~= 0 then
                        FreezeEntityPosition(jackProp, true)
                        SetEntityCollision(jackProp, false, false)
                    end
                end

                -- Lift vehicle
                local newZ = vehPos.z + JACK_LIFT_HEIGHT
                SetEntityCoords(vehicle, vehPos.x, vehPos.y, newZ, false, false, false, false)
                FreezeEntityPosition(vehicle, true)

                -- Set state
                Entity(vehicle).state:set('sb_lifted', true, true)

                ActiveJacks[netId] = {
                    prop = jackProp,
                    vehicle = vehicle,
                }

                exports['sb_notify']:Notify('Vehicle lifted.', 'success', 3000)
            end,
            onCancel = function()
                exports['sb_notify']:Notify('Cancelled.', 'error', 2000)
            end,
        })
    end, 'tool_jack')
end

-- ===== LOWER JACK =====
local function LowerJack(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local jackData = ActiveJacks[netId]
    if not jackData then
        exports['sb_notify']:Notify('No jack found on this vehicle.', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        duration = 2000,
        label = 'Removing car jack...',
        canCancel = true,
        animation = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            anim = 'machinic_loop_mechandplayer',
            flag = 1,
        },
        onComplete = function()
            if not DoesEntityExist(vehicle) then return end

            -- Lower vehicle
            local vehPos = GetEntityCoords(vehicle)
            SetEntityCoords(vehicle, vehPos.x, vehPos.y, vehPos.z - JACK_LIFT_HEIGHT, false, false, false, false)
            FreezeEntityPosition(vehicle, false)

            -- Clear state
            Entity(vehicle).state:set('sb_lifted', false, true)

            -- Remove prop
            if jackData.prop and jackData.prop ~= 0 and DoesEntityExist(jackData.prop) then
                DeleteEntity(jackData.prop)
            end

            ActiveJacks[netId] = nil

            exports['sb_notify']:Notify('Vehicle lowered.', 'success', 3000)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled.', 'error', 2000)
        end,
    })
end

-- ===== REGISTER ALT-CLICK TARGET ON VEHICLES =====
-- "Use Car Jack" / "Lower Car Jack" target
exports['sb_target']:AddGlobalVehicle({
    {
        name = 'mechanic_use_jack',
        label = 'Use Car Jack',
        icon = 'fa-arrow-up',
        distance = JACK_USE_DISTANCE,
        canInteract = function(entity)
            if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
            if not entity or not DoesEntityExist(entity) then return false end
            if not Entity(entity).state.sb_plate then return false end
            -- Only show when NOT lifted
            if Entity(entity).state.sb_lifted then return false end
            -- Must be mechanic
            local Player = SB.Functions.GetPlayerData()
            if not Player or not Config.IsMechanicJob(Player.job.name) then return false end
            return true
        end,
        action = function(entity)
            PlaceJack(entity)
        end,
    },
    {
        name = 'mechanic_lower_jack',
        label = 'Lower Car Jack',
        icon = 'fa-arrow-down',
        distance = JACK_USE_DISTANCE,
        canInteract = function(entity)
            if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
            if not entity or not DoesEntityExist(entity) then return false end
            if not Entity(entity).state.sb_plate then return false end
            -- Only show when lifted by jack (not elevator)
            if not Entity(entity).state.sb_lifted then return false end
            local netId = NetworkGetNetworkIdFromEntity(entity)
            if not ActiveJacks[netId] then return false end
            local Player = SB.Functions.GetPlayerData()
            if not Player or not Config.IsMechanicJob(Player.job.name) then return false end
            return true
        end,
        action = function(entity)
            LowerJack(entity)
        end,
    },
})

-- ===== CLEANUP =====
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for netId, data in pairs(ActiveJacks) do
        if data.prop and data.prop ~= 0 and DoesEntityExist(data.prop) then
            DeleteEntity(data.prop)
        end
        if data.vehicle and DoesEntityExist(data.vehicle) then
            FreezeEntityPosition(data.vehicle, false)
            Entity(data.vehicle).state:set('sb_lifted', false, true)
        end
    end
    ActiveJacks = {}
end)
