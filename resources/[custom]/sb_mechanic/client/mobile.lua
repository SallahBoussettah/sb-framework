-- ============================================================================
-- sb_mechanic - Client: Vehicle Interactions & Service Execution
-- Vehicle part open/close (hood, doors, trunk), mobile repairs,
-- pending station service execution via sb_target, /mechanic command
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()
local isRepairing = false

-- ============================================================================
-- Helpers
-- ============================================================================

local function IsOnDuty()
    return exports['sb_mechanic']:IsOnDuty()
end

local function IsMechanic()
    return exports['sb_mechanic']:IsMechanic()
end

-- ============================================================================
-- Rear Engine Detection
-- ============================================================================

local function GetEngineDoorIndex(vehicle)
    local boneIndex = GetEntityBoneIndexByName(vehicle, 'engine')
    if boneIndex ~= -1 then
        local bonePos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, bonePos.x, bonePos.y, bonePos.z)
        if offset.y < 0 then
            return 5 -- rear engine = open trunk
        end
    end
    return 4 -- front engine = open hood
end

local function IsHoodOpen(vehicle)
    local doorIdx = GetEngineDoorIndex(vehicle)
    return GetVehicleDoorAngleRatio(vehicle, doorIdx) > 0.1
end

local function IsDoorOpen(vehicle, doorIndex)
    return GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0.1
end

-- ============================================================================
-- Station Detection (is vehicle at an MLO station?)
-- ============================================================================

function IsVehicleAtStation(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    local vehCoords = GetEntityCoords(vehicle)
    for _, station in ipairs(Config.Stations) do
        if station.vehicleSpots then
            for _, spot in ipairs(station.vehicleSpots) do
                if #(vehCoords - spot) < (station.vehicleDetectRadius or 5.0) then
                    return true
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- Post-Action: Apply changes locally after server confirms success
-- ============================================================================

local function ApplyPostAction(vehicle, postAction, postData)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if postAction == 'repair' then
        if postData.repairType == 'engine' then
            SetVehicleEngineHealth(vehicle, 1000.0)
            SetVehicleFixed(vehicle)
            SetVehicleEngineOn(vehicle, true, true, false)
        elseif postData.repairType == 'body' then
            SetVehicleBodyHealth(vehicle, 1000.0)
            SetVehicleFixed(vehicle)
            SetVehicleDeformationFixed(vehicle)
        end
    elseif postAction == 'mod' then
        SetVehicleModKit(vehicle, 0)
        if postData.toggle ~= nil then
            ToggleVehicleMod(vehicle, postData.modType, postData.toggle)
        else
            SetVehicleMod(vehicle, postData.modType, postData.modIndex, false)
        end
    elseif postAction == 'tire' then
        SetVehicleTyreFixed(vehicle, postData.tireIndex)
    elseif postAction == 'wash' then
        SetVehicleDirtLevel(vehicle, 0.0)
        WashDecalsFromVehicle(vehicle, 1.0)
    end
    -- color, wheels, cosmetic = already applied via preview or server-side
end

-- ============================================================================
-- Execute Pending Station Service (called from sb_target)
-- ============================================================================

local function ExecutePendingService(entity)
    if not pendingService then return end
    if isRepairing then return end
    if not entity or not DoesEntityExist(entity) then return end

    isRepairing = true
    local service = pendingService
    local vehicle = service.vehicle

    -- Delete the held tool prop (animation will spawn its own via progressbar)
    if pendingHeldProp and DoesEntityExist(pendingHeldProp) then
        DeleteEntity(pendingHeldProp)
        pendingHeldProp = nil
    end

    -- Get animation config
    local animCfg = Config.ServiceAnimations[service.animType]

    -- Face the vehicle
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 1000)

    Citizen.SetTimeout(1000, function()
        -- Build progress bar options
        local progressOpts = {
            duration = animCfg and animCfg.duration or 8000,
            label = animCfg and animCfg.label or (service.label .. '...'),
            canCancel = true,
            onComplete = function()
                -- Build server callback args: stored args + netId at the end
                local args = {}
                for _, v in ipairs(service.callbackArgs or {}) do
                    table.insert(args, v)
                end
                table.insert(args, service.netId)

                -- Server validates and charges
                SB.Functions.TriggerCallback(service.callback, function(success, msg)
                    if success then
                        ApplyPostAction(vehicle, service.postAction, service.postData)
                        exports['sb_notify']:Notify(msg, 'success', 3000)
                        -- Clear original props (service completed, no revert)
                        pendingOriginalProps = nil
                    else
                        -- Failed — revert previews
                        if pendingOriginalProps and DoesEntityExist(vehicle) then
                            exports['sb_garage']:SetVehicleProperties(vehicle, pendingOriginalProps)
                        end
                        exports['sb_notify']:Notify(msg, 'error', 3000)
                        pendingOriginalProps = nil
                    end

                    pendingService = nil
                    isRepairing = false
                end, table.unpack(args))
            end,
            onCancel = function()
                ClearPedTasks(ped)
                exports['sb_notify']:Notify('Service cancelled', 'error', 3000)
                -- Don't revert on cancel — mechanic can retry
                -- They can use "Cancel Service" target to fully cancel + revert
                isRepairing = false
            end,
        }

        -- Add animation if configured
        if animCfg then
            progressOpts.animation = {
                dict = animCfg.dict,
                anim = animCfg.anim,
                flag = animCfg.flag or 49,
            }
            if animCfg.prop then
                progressOpts.prop = {
                    model = animCfg.prop.model,
                    bone = animCfg.prop.bone or 57005,
                    pos = animCfg.prop.pos or vector3(0.0, 0.0, 0.0),
                    rot = animCfg.prop.rot or vector3(0.0, 0.0, 0.0),
                }
            end
        end

        local started = exports['sb_progressbar']:Start(progressOpts)
        if not started then
            isRepairing = false
        end
    end)
end

-- ============================================================================
-- Perform Mobile Repair (free-roam, item-based, no billing)
-- ============================================================================

local function DoMobileRepair(vehicle, repairType)
    if isRepairing then return end
    if not DoesEntityExist(vehicle) then return end

    isRepairing = true
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- Server validation first (check items)
    SB.Functions.TriggerCallback('sb_mechanic:mobileRepair', function(success, msg)
        if not success then
            exports['sb_notify']:Notify(msg, 'error', 3000)
            isRepairing = false
            return
        end

        local animCfg = Config.ServiceAnimations[repairType]
        if not animCfg then
            isRepairing = false
            return
        end

        local ped = PlayerPedId()
        TaskTurnPedToFaceEntity(ped, vehicle, 1000)

        Citizen.SetTimeout(1000, function()
            local progressOpts = {
                duration = animCfg.duration,
                label = animCfg.label,
                canCancel = true,
                animation = {
                    dict = animCfg.dict,
                    anim = animCfg.anim,
                    flag = animCfg.flag or 49,
                },
                onComplete = function()
                    if DoesEntityExist(vehicle) then
                        if repairType == 'engine' then
                            local newHealth = math.min(GetVehicleEngineHealth(vehicle) + 400, Config.MobileRepair.maxEngineHealth)
                            SetVehicleEngineHealth(vehicle, newHealth + 0.0)
                            SetVehicleEngineOn(vehicle, true, true, false)
                        elseif repairType == 'body' then
                            local newHealth = math.min(GetVehicleBodyHealth(vehicle) + 400, Config.MobileRepair.maxBodyHealth)
                            SetVehicleBodyHealth(vehicle, newHealth + 0.0)
                            SetVehicleDeformationFixed(vehicle)
                        elseif repairType == 'tire' then
                            for i = 0, 5 do
                                if IsVehicleTyreBurst(vehicle, i, false) then
                                    SetVehicleTyreFixed(vehicle, i)
                                    break
                                end
                            end
                        end
                    end
                    exports['sb_notify']:Notify(msg, 'success', 3000)
                    isRepairing = false
                end,
                onCancel = function()
                    ClearPedTasks(PlayerPedId())
                    exports['sb_notify']:Notify('Repair cancelled', 'error', 3000)
                    isRepairing = false
                end,
            }

            if animCfg.prop then
                progressOpts.prop = {
                    model = animCfg.prop.model,
                    bone = animCfg.prop.bone or 57005,
                    pos = animCfg.prop.pos or vector3(0.0, 0.0, 0.0),
                    rot = animCfg.prop.rot or vector3(0.0, 0.0, 0.0),
                }
            end

            local started = exports['sb_progressbar']:Start(progressOpts)
            if not started then
                isRepairing = false
            end
        end)
    end, repairType, netId)
end

-- ============================================================================
-- sb_target: Vehicle Part Interactions + Service Execution
-- ============================================================================

Citizen.CreateThread(function()
    Wait(3000) -- Wait for sb_target to be ready

    exports['sb_target']:AddGlobalVehicle({
        -- =============================================
        -- HOOD (Engine Cover)
        -- =============================================
        {
            name = 'mechanic_open_hood',
            label = 'Open Hood',
            icon = 'fa-car-burst',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return not IsHoodOpen(entity)
            end,
            action = function(entity)
                local doorIdx = GetEngineDoorIndex(entity)
                SetVehicleDoorOpen(entity, doorIdx, false, false)
                exports['sb_notify']:Notify('Hood opened', 'info', 2000)
            end
        },
        {
            name = 'mechanic_close_hood',
            label = 'Close Hood',
            icon = 'fa-xmark',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return IsHoodOpen(entity)
            end,
            action = function(entity)
                local doorIdx = GetEngineDoorIndex(entity)
                SetVehicleDoorShut(entity, doorIdx, false)
                exports['sb_notify']:Notify('Hood closed', 'info', 2000)
            end
        },
        -- =============================================
        -- DOORS
        -- =============================================
        {
            name = 'mechanic_open_door_fl',
            label = 'Open Door (FL)',
            icon = 'fa-door-open',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return not IsDoorOpen(entity, 0)
            end,
            action = function(entity)
                SetVehicleDoorOpen(entity, 0, false, false)
            end
        },
        {
            name = 'mechanic_close_door_fl',
            label = 'Close Door (FL)',
            icon = 'fa-door-closed',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return IsDoorOpen(entity, 0)
            end,
            action = function(entity)
                SetVehicleDoorShut(entity, 0, false)
            end
        },
        {
            name = 'mechanic_open_door_fr',
            label = 'Open Door (FR)',
            icon = 'fa-door-open',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return not IsDoorOpen(entity, 1)
            end,
            action = function(entity)
                SetVehicleDoorOpen(entity, 1, false, false)
            end
        },
        {
            name = 'mechanic_close_door_fr',
            label = 'Close Door (FR)',
            icon = 'fa-door-closed',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return IsDoorOpen(entity, 1)
            end,
            action = function(entity)
                SetVehicleDoorShut(entity, 1, false)
            end
        },
        {
            name = 'mechanic_open_door_rl',
            label = 'Open Door (RL)',
            icon = 'fa-door-open',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return not IsDoorOpen(entity, 2)
            end,
            action = function(entity)
                SetVehicleDoorOpen(entity, 2, false, false)
            end
        },
        {
            name = 'mechanic_close_door_rl',
            label = 'Close Door (RL)',
            icon = 'fa-door-closed',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return IsDoorOpen(entity, 2)
            end,
            action = function(entity)
                SetVehicleDoorShut(entity, 2, false)
            end
        },
        {
            name = 'mechanic_open_door_rr',
            label = 'Open Door (RR)',
            icon = 'fa-door-open',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return not IsDoorOpen(entity, 3)
            end,
            action = function(entity)
                SetVehicleDoorOpen(entity, 3, false, false)
            end
        },
        {
            name = 'mechanic_close_door_rr',
            label = 'Close Door (RR)',
            icon = 'fa-door-closed',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                return IsDoorOpen(entity, 3)
            end,
            action = function(entity)
                SetVehicleDoorShut(entity, 3, false)
            end
        },
        -- =============================================
        -- TRUNK
        -- =============================================
        {
            name = 'mechanic_open_trunk',
            label = 'Open Trunk',
            icon = 'fa-box-open',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                local engineDoor = GetEngineDoorIndex(entity)
                if engineDoor == 5 then return false end
                return not IsDoorOpen(entity, 5)
            end,
            action = function(entity)
                SetVehicleDoorOpen(entity, 5, false, false)
                exports['sb_notify']:Notify('Trunk opened', 'info', 2000)
            end
        },
        {
            name = 'mechanic_close_trunk',
            label = 'Close Trunk',
            icon = 'fa-xmark',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                local engineDoor = GetEngineDoorIndex(entity)
                if engineDoor == 5 then return false end
                return IsDoorOpen(entity, 5)
            end,
            action = function(entity)
                SetVehicleDoorShut(entity, 5, false)
                exports['sb_notify']:Notify('Trunk closed', 'info', 2000)
            end
        },
        -- =============================================
        -- MOBILE REPAIRS (free-roam, item-based)
        -- =============================================
        {
            name = 'mobile_repair_engine',
            label = 'Repair Engine',
            icon = 'fa-wrench',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                -- Only for free-roam (no pending station service)
                if pendingService then return false end
                if not IsHoodOpen(entity) then return false end
                return GetVehicleEngineHealth(entity) < 900
            end,
            action = function(entity)
                DoMobileRepair(entity, 'engine')
            end
        },
        {
            name = 'mobile_repair_body',
            label = 'Repair Body',
            icon = 'fa-car-burst',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if pendingService then return false end
                return GetVehicleBodyHealth(entity) < 900
            end,
            action = function(entity)
                DoMobileRepair(entity, 'body')
            end
        },
        {
            name = 'mobile_repair_tire',
            label = 'Fix Tire',
            icon = 'fa-circle-dot',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if pendingService then return false end
                for i = 0, 5 do
                    if IsVehicleTyreBurst(entity, i, false) then
                        return true
                    end
                end
                return false
            end,
            action = function(entity)
                DoMobileRepair(entity, 'tire')
            end
        },
        -- =============================================
        -- PENDING STATION SERVICE EXECUTION
        -- These appear when a service was queued from the station NUI.
        -- Mechanic walked to car manually, now uses target to execute.
        -- =============================================
        {
            name = 'pending_repair_engine',
            label = 'Repair Engine',
            icon = 'fa-wrench',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                if pendingService.type ~= 'repair' or pendingService.repairType ~= 'engine' then return false end
                return IsHoodOpen(entity)
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_repair_body',
            label = 'Repair Body',
            icon = 'fa-car-burst',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                return pendingService.type == 'repair' and pendingService.repairType == 'body'
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_upgrade',
            label = 'Install Upgrade',
            icon = 'fa-gears',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                if pendingService.type ~= 'upgrade' then return false end
                return IsHoodOpen(entity)
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_paint',
            label = 'Apply Paint',
            icon = 'fa-spray-can',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                return pendingService.type == 'paint'
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_wheels',
            label = 'Change Wheels',
            icon = 'fa-tire',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                return pendingService.type == 'wheels'
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_tire',
            label = 'Fix Tire',
            icon = 'fa-circle-dot',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                return pendingService.type == 'tire'
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_cosmetic',
            label = 'Apply Modification',
            icon = 'fa-palette',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                if pendingService.type ~= 'cosmetic' then return false end
                -- Xenon requires hood open
                if pendingService.requiresHood and not IsHoodOpen(entity) then return false end
                return true
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        {
            name = 'pending_wash',
            label = 'Wash Vehicle',
            icon = 'fa-droplet',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if isRepairing then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                return pendingService.type == 'wash'
            end,
            action = function(entity)
                ExecutePendingService(entity)
            end
        },
        -- =============================================
        -- CANCEL QUEUED SERVICE
        -- =============================================
        {
            name = 'cancel_pending_service',
            label = 'Cancel Service',
            icon = 'fa-ban',
            distance = Config.MobileRepair.distance,
            canInteract = function(entity)
                if not IsMechanic() or not IsOnDuty() then return false end
                if not pendingService then return false end
                if pendingService.vehicle ~= entity then return false end
                return not isRepairing
            end,
            action = function(entity)
                CancelPendingService()
            end
        },
    })
end)

-- ============================================================================
-- /mechanic command (for civilians to call a mechanic)
-- ============================================================================

RegisterCommand('mechanic', function()
    local playerData = SB.Functions.GetPlayerData()
    if not playerData then return end

    if playerData.job and playerData.job.name == Config.JobName then
        exports['sb_notify']:Notify('You are a mechanic!', 'error', 3000)
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash) or 'Unknown'

    exports['sb_alerts']:SendAlert(Config.JobName, {
        title = 'Mechanic Requested',
        message = 'A citizen needs roadside assistance at ' .. streetName,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        icon = 'fa-wrench',
        blipSprite = 446,
        blipColor = 47,
    })

    exports['sb_notify']:Notify('Mechanic request sent. Please wait nearby.', 'info', 5000)
end, false)

-- ============================================================================
-- Cleanup on resource stop
-- ============================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if pendingHeldProp and DoesEntityExist(pendingHeldProp) then
        DeleteEntity(pendingHeldProp)
        pendingHeldProp = nil
    end
end)
