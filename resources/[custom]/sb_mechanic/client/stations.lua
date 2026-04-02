-- ============================================================================
-- sb_mechanic - Client: Station System
-- Station zones, camera, NUI open/close, live preview, invoice state
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- State
local currentStation = nil      -- station config table
local currentVehicle = 0        -- entity handle
local originalProps = nil       -- snapshot for revert
local stationCam = nil          -- camera handle
local nuiOpen = false

-- Forward declarations (referenced before definition)
local DestroyStationCamera

-- ============================================================================
-- Helpers
-- ============================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic:stations]', ...)
    end
end

local function IsOnDuty()
    return exports['sb_mechanic']:IsOnDuty()
end

local function IsMechanic()
    return exports['sb_mechanic']:IsMechanic()
end

-- ============================================================================
-- Pending Service System (globals — accessible from mobile.lua)
-- NUI is for SELECTION only. Physical work happens via sb_target.
-- ============================================================================

pendingService = nil        -- queued service data (type, callback, args, etc.)
pendingOriginalProps = nil  -- vehicle props snapshot for revert on cancel
pendingHeldProp = nil       -- tool prop attached to mechanic hand

local function AttachToolProp(propModel)
    if not propModel then return end
    Citizen.CreateThread(function()
        local hash = GetHashKey(propModel)
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 5000 do
            Wait(0)
            timeout = timeout + 1
        end
        if HasModelLoaded(hash) then
            local ped = PlayerPedId()
            local prop = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005),
                0.1, 0.02, -0.02, 10.0, 0.0, 0.0,
                true, true, false, true, 1, true)
            pendingHeldProp = prop
            SetModelAsNoLongerNeeded(hash)
        end
    end)
end

local function DetachToolProp()
    if pendingHeldProp and DoesEntityExist(pendingHeldProp) then
        DeleteEntity(pendingHeldProp)
    end
    pendingHeldProp = nil
end

-- Queue a service from NUI, close menu, let mechanic walk to car
local function QueueServiceAndClose(serviceData)
    -- Capture vehicle state before closing clears it
    serviceData.vehicle = currentVehicle
    serviceData.netId = NetworkGetNetworkIdFromEntity(currentVehicle)

    -- Store as globals (mobile.lua reads these)
    pendingService = serviceData
    pendingOriginalProps = originalProps

    -- Close NUI without reverting (preview stays on car for paint/cosmetics)
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    DestroyStationCamera()

    -- Clear local station state
    currentStation = nil
    currentVehicle = 0
    originalProps = nil

    -- Attach tool prop to mechanic's hand
    local animCfg = Config.ServiceAnimations[serviceData.animType]
    if animCfg and animCfg.prop then
        AttachToolProp(animCfg.prop.model)
    end

    -- Notify
    exports['sb_notify']:Notify('Walk to the vehicle → ' .. (serviceData.label or 'Apply Service'), 'info', 5000)
end

-- Cancel queued service (reverts previews, clears state)
function CancelPendingService()
    if not pendingService then return end

    -- Revert vehicle if we had a preview applied (paint, wheels, etc.)
    if pendingOriginalProps and pendingService.vehicle and DoesEntityExist(pendingService.vehicle) then
        exports['sb_garage']:SetVehicleProperties(pendingService.vehicle, pendingOriginalProps)
    end

    DetachToolProp()
    pendingService = nil
    pendingOriginalProps = nil

    exports['sb_notify']:Notify('Service cancelled', 'info', 3000)
end

-- ============================================================================
-- Vehicle Detection per Station
-- ============================================================================

local function FindStationVehicle(station)
    local spots = station.vehicleSpots
    local detectRadius = station.vehicleDetectRadius or 5.0

    if not spots or #spots == 0 then
        -- Fallback: search near station coords
        spots = { station.coords }
    end

    local closest = nil
    local closestDist = detectRadius + 1

    local handle, vehicle = FindFirstVehicle()
    local found = true
    while found do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            for _, spot in ipairs(spots) do
                local dist = #(vehCoords - spot)
                if dist < closestDist then
                    closest = vehicle
                    closestDist = dist
                end
            end
        end
        found, vehicle = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)

    return closest
end

-- ============================================================================
-- Vehicle Data Gathering (comprehensive for NUI)
-- ============================================================================

local function GatherVehicleData(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local data = {}

    -- Basic
    data.plate = GetVehicleNumberPlateText(vehicle)
    data.model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    data.label = GetLabelText(data.model)
    if data.label == 'NULL' then data.label = data.model end

    -- Health
    data.engineHealth = math.floor(GetVehicleEngineHealth(vehicle))
    data.bodyHealth = math.floor(GetVehicleBodyHealth(vehicle))

    -- Current mods
    SetVehicleModKit(vehicle, 0)
    data.mods = {}
    for modType = 0, 48 do
        local current = GetVehicleMod(vehicle, modType)
        local max = GetNumVehicleMods(vehicle, modType)
        if max > 0 then
            data.mods[tostring(modType)] = {
                current = current,
                max = max - 1, -- 0-indexed, -1 = stock
            }
        end
    end

    -- Toggle mods
    data.turbo = IsToggleModOn(vehicle, 18)
    data.xenon = IsToggleModOn(vehicle, 22)
    data.smokeEnabled = IsToggleModOn(vehicle, 20)

    -- Colors
    local pri, sec = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    local interior = GetVehicleInteriorColour(vehicle)
    local dashboard = GetVehicleDashboardColour(vehicle)
    data.colors = {
        primary = pri,
        secondary = sec,
        pearlescent = pearl,
        wheel = wheel,
        interior = interior,
        dashboard = dashboard,
    }

    -- Custom RGB
    local hasCustPri, cpR, cpG, cpB = GetVehicleCustomPrimaryColour(vehicle)
    local hasCustSec, csR, csG, csB = GetVehicleCustomSecondaryColour(vehicle)
    if hasCustPri then
        data.colors.customPrimary = {cpR, cpG, cpB}
    end
    if hasCustSec then
        data.colors.customSecondary = {csR, csG, csB}
    end

    -- Wheels
    data.wheelType = GetVehicleWheelType(vehicle)
    data.frontWheels = GetVehicleMod(vehicle, 23)
    data.backWheels = GetVehicleMod(vehicle, 24)
    data.numFrontWheels = GetNumVehicleMods(vehicle, 23)
    data.numBackWheels = GetNumVehicleMods(vehicle, 24)

    -- Tyres
    data.tyresBurst = {}
    for i = 0, 5 do
        data.tyresBurst[tostring(i)] = IsVehicleTyreBurst(vehicle, i, false)
    end

    -- Neon
    data.neonEnabled = {
        IsVehicleNeonLightEnabled(vehicle, 0),
        IsVehicleNeonLightEnabled(vehicle, 1),
        IsVehicleNeonLightEnabled(vehicle, 2),
        IsVehicleNeonLightEnabled(vehicle, 3),
    }
    local nR, nG, nB = GetVehicleNeonLightsColour(vehicle)
    data.neonColor = {nR, nG, nB}

    -- Tyre smoke
    local tsR, tsG, tsB = GetVehicleTyreSmokeColor(vehicle)
    data.tyreSmokeColor = {tsR, tsG, tsB}

    -- Window tint
    data.windowTint = GetVehicleWindowTint(vehicle)

    -- Xenon color
    if data.xenon then
        data.xenonColor = GetVehicleXenonLightsColour(vehicle)
    else
        data.xenonColor = -1
    end

    -- Horn
    data.horn = GetVehicleMod(vehicle, 14)

    -- Plate style
    data.plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    -- Livery
    data.livery = GetVehicleLivery(vehicle)
    data.numLiveries = GetVehicleLiveryCount(vehicle)

    -- Extras
    data.extras = {}
    for i = 0, 14 do
        if DoesExtraExist(vehicle, i) then
            data.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    -- Dirt level
    data.dirtLevel = GetVehicleDirtLevel(vehicle)

    return data
end

-- ============================================================================
-- Camera System
-- ============================================================================

local function CreateStationCamera(station, vehicle, camOverride)
    local camCfg = camOverride or station.camera
    local vehCoords = GetEntityCoords(vehicle)

    local camPos = GetOffsetFromEntityInWorldCoords(vehicle, camCfg.offset.x, camCfg.offset.y, camCfg.offset.z)
    local pointAt = GetOffsetFromEntityInWorldCoords(vehicle, camCfg.pointOffset.x, camCfg.pointOffset.y, camCfg.pointOffset.z)

    if stationCam then
        -- Smooth transition to new angle
        local newCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(newCam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(newCam, pointAt.x, pointAt.y, pointAt.z)
        SetCamFov(newCam, 60.0)
        SetCamActiveWithInterp(newCam, stationCam, 800, true, true)
        DestroyCam(stationCam, false)
        stationCam = newCam
    else
        stationCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(stationCam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(stationCam, pointAt.x, pointAt.y, pointAt.z)
        SetCamFov(stationCam, 60.0)
        SetCamActive(stationCam, true)
        RenderScriptCams(true, true, 500, true, false)
    end
end

DestroyStationCamera = function()
    if stationCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(stationCam, false)
        stationCam = nil
    end
end

-- ============================================================================
-- NUI Open / Close
-- ============================================================================

local function OpenStationNUI(station, vehicleData)
    -- Cancel any existing pending service when opening a new station
    if pendingService then
        CancelPendingService()
    end

    nuiOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        mode = station.id,
        stationLabel = station.label,
        vehicle = vehicleData,
        pricing = Config.Pricing,
        wheelTypes = Config.WheelTypes,
        gtaColors = Config.GtaColors,
        windowTints = Config.WindowTints,
        xenonColors = Config.XenonColors,
        horns = Config.Horns,
        plateStyles = Config.PlateStyles,
        modLabels = Config.ModLabels,
    })
end

local function CloseStationNUI(revert)
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    DestroyStationCamera()

    if revert and currentVehicle and DoesEntityExist(currentVehicle) and originalProps then
        exports['sb_garage']:SetVehicleProperties(currentVehicle, originalProps)
    end

    currentStation = nil
    currentVehicle = 0
    originalProps = nil
end

-- ============================================================================
-- Station Interaction Logic (shared by all target types)
-- ============================================================================

local function OnStationInteract(station)
    -- Find vehicle near this station's vehicle spots
    local vehicle = FindStationVehicle(station)
    if not vehicle or not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('No vehicle found at this station', 'error', 3000)
        return
    end

    -- Check vehicle is stationary
    local speed = GetEntitySpeed(vehicle)
    if speed > 0.5 then
        exports['sb_notify']:Notify('Vehicle must be stationary', 'error', 3000)
        return
    end

    -- Store state
    currentStation = station
    currentVehicle = vehicle
    originalProps = exports['sb_garage']:GetVehicleProperties(vehicle)

    -- Gather data and open NUI
    local vehicleData = GatherVehicleData(vehicle)
    if not vehicleData then
        exports['sb_notify']:Notify('Failed to read vehicle data', 'error', 3000)
        currentStation = nil
        currentVehicle = 0
        originalProps = nil
        return
    end

    CreateStationCamera(station, vehicle)
    OpenStationNUI(station, vehicleData)
end

-- ============================================================================
-- Station Zone Registration
-- ============================================================================

Citizen.CreateThread(function()
    Wait(3000) -- Wait for targets to be ready

    local targetOptions = function(station)
        return {
            {
                name = 'mechanic_open_' .. station.id,
                label = station.label,
                icon = station.icon,
                distance = station.distance,
                canInteract = function()
                    return IsMechanic() and IsOnDuty()
                end,
                action = function()
                    OnStationInteract(station)
                end
            }
        }
    end

    for _, station in ipairs(Config.Stations) do
        if station.targetModel then
            -- Engine bay: target an existing MLO object model
            exports['sb_target']:AddTargetModel(station.targetModel, targetOptions(station))
        else
            -- Other stations: sphere zone at coords
            exports['sb_target']:AddSphereZone(
                'mechanic_station_' .. station.id,
                station.coords,
                station.radius,
                targetOptions(station)
            )
        end
    end
end)

-- ============================================================================
-- NUI Callbacks
-- ============================================================================

-- Close (Done) — revert to originalProps to undo unapplied previews
-- originalProps is updated after each successful apply, so applied work is kept
RegisterNUICallback('close', function(data, cb)
    CloseStationNUI(true)
    cb('ok')
end)

-- Cancel — also revert (same behavior, both undo unapplied previews)
RegisterNUICallback('cancel', function(data, cb)
    CloseStationNUI(true)
    cb('ok')
end)

-- ============================================================================
-- Sub-tab camera switching (body/paint station)
-- ============================================================================

RegisterNUICallback('switchSubCamera', function(data, cb)
    if not currentStation or not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end

    local subtab = data.subtab -- 'primary', 'secondary', 'pearlescent', 'livery'
    local subCams = currentStation.subCameras
    if subCams and subtab and subCams[subtab] then
        CreateStationCamera(currentStation, currentVehicle, subCams[subtab])
    end

    cb('ok')
end)

-- ============================================================================
-- PREVIEW callbacks (client-side only, no server validation)
-- ============================================================================

RegisterNUICallback('previewColor', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end

    local slot = data.slot       -- 'primary', 'secondary', 'pearlescent'
    local colorId = data.colorId -- GTA color index or nil for custom
    local r, g, b = data.r, data.g, data.b

    if slot == 'primary' then
        if r and g and b then
            SetVehicleCustomPrimaryColour(currentVehicle, r, g, b)
        elseif colorId then
            ClearVehicleCustomPrimaryColour(currentVehicle)
            local _, sec = GetVehicleColours(currentVehicle)
            SetVehicleColours(currentVehicle, colorId, sec)
        end
    elseif slot == 'secondary' then
        if r and g and b then
            SetVehicleCustomSecondaryColour(currentVehicle, r, g, b)
        elseif colorId then
            ClearVehicleCustomSecondaryColour(currentVehicle)
            local pri, _ = GetVehicleColours(currentVehicle)
            SetVehicleColours(currentVehicle, pri, colorId)
        end
    elseif slot == 'pearlescent' then
        if colorId then
            local _, wheelCol = GetVehicleExtraColours(currentVehicle)
            SetVehicleExtraColours(currentVehicle, colorId, wheelCol)
        end
    end

    cb('ok')
end)

RegisterNUICallback('previewWheels', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end

    if data.wheelType ~= nil then
        SetVehicleWheelType(currentVehicle, data.wheelType)
    end

    if data.wheelIndex ~= nil then
        SetVehicleMod(currentVehicle, 23, data.wheelIndex, false)
        -- Apply back wheels too if they exist
        if GetNumVehicleMods(currentVehicle, 24) > 0 then
            SetVehicleMod(currentVehicle, 24, data.wheelIndex, false)
        end
    end

    cb('ok')
end)

RegisterNUICallback('previewNeon', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end

    if data.enabled ~= nil then
        -- data.enabled = {left, right, front, back}
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(currentVehicle, i, data.enabled[i + 1] or false)
        end
    end

    if data.r and data.g and data.b then
        SetVehicleNeonLightsColour(currentVehicle, data.r, data.g, data.b)
    end

    cb('ok')
end)

RegisterNUICallback('previewTint', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end

    if data.tintId ~= nil then
        SetVehicleWindowTint(currentVehicle, data.tintId)
    end

    cb('ok')
end)

RegisterNUICallback('previewXenon', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end

    if data.enabled ~= nil then
        ToggleVehicleMod(currentVehicle, 22, data.enabled)
    end

    if data.colorId ~= nil then
        SetVehicleXenonLightsColour(currentVehicle, data.colorId)
    end

    cb('ok')
end)

RegisterNUICallback('previewHorn', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.hornId ~= nil then
        SetVehicleMod(currentVehicle, 14, data.hornId, false)
    end
    cb('ok')
end)

RegisterNUICallback('previewPlateStyle', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.plateId ~= nil then
        SetVehicleNumberPlateTextIndex(currentVehicle, data.plateId)
    end
    cb('ok')
end)

RegisterNUICallback('previewExtra', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.extraId ~= nil and data.enabled ~= nil then
        SetVehicleExtra(currentVehicle, data.extraId, not data.enabled) -- inverted API
    end
    cb('ok')
end)

RegisterNUICallback('previewLivery', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.liveryId ~= nil then
        SetVehicleLivery(currentVehicle, data.liveryId)
    end
    cb('ok')
end)

RegisterNUICallback('previewInteriorColor', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.colorId ~= nil then
        SetVehicleInteriorColour(currentVehicle, data.colorId)
    end
    cb('ok')
end)

RegisterNUICallback('previewDashboardColor', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.colorId ~= nil then
        SetVehicleDashboardColour(currentVehicle, data.colorId)
    end
    cb('ok')
end)

RegisterNUICallback('previewMod', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb('err') end
    if data.modType ~= nil and data.modIndex ~= nil then
        SetVehicleMod(currentVehicle, data.modType, data.modIndex, false)
    end
    if data.toggle ~= nil and data.modType ~= nil then
        ToggleVehicleMod(currentVehicle, data.modType, data.toggle)
    end
    cb('ok')
end)

-- ============================================================================
-- APPLY callbacks (server validated)
-- ============================================================================

-- ============================================================================
-- APPLY callbacks → Queue service and close NUI
-- Mechanic physically walks to car and uses sb_target to execute
-- ============================================================================

RegisterNUICallback('applyRepair', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    local repairType = data.repairType -- 'engine' or 'body'
    QueueServiceAndClose({
        type = 'repair',
        repairType = repairType,
        animType = repairType == 'engine' and 'engine' or 'body',
        label = repairType == 'engine' and 'Repair Engine' or 'Repair Body',
        requiresHood = repairType == 'engine',
        callback = 'sb_mechanic:applyRepair',
        callbackArgs = { repairType },
        postAction = 'repair',
        postData = { repairType = repairType },
    })
    cb({success = true, queued = true})
end)

RegisterNUICallback('applyUpgrade', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    local modType = data.modType
    local modIndex = data.modIndex
    local toggle = data.toggle

    QueueServiceAndClose({
        type = 'upgrade',
        animType = 'upgrade',
        label = 'Install Upgrade',
        requiresHood = true,
        callback = 'sb_mechanic:applyMod',
        callbackArgs = { modType, modIndex, toggle },
        postAction = 'mod',
        postData = { modType = modType, modIndex = modIndex, toggle = toggle },
    })
    cb({success = true, queued = true})
end)

RegisterNUICallback('applyColor', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    QueueServiceAndClose({
        type = 'paint',
        animType = 'paint',
        label = 'Apply Paint',
        requiresHood = false,
        callback = 'sb_mechanic:applyColor',
        callbackArgs = { data.slot, data.colorId, data.r, data.g, data.b },
        postAction = 'color',
        postData = {},
    })
    cb({success = true, queued = true})
end)

RegisterNUICallback('applyWheels', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    QueueServiceAndClose({
        type = 'wheels',
        animType = 'wheels',
        label = 'Change Wheels',
        requiresHood = false,
        callback = 'sb_mechanic:applyWheels',
        callbackArgs = { data.wheelType, data.wheelIndex },
        postAction = 'wheels',
        postData = {},
    })
    cb({success = true, queued = true})
end)

RegisterNUICallback('applyTireRepair', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    local tireIndex = data.tireIndex
    QueueServiceAndClose({
        type = 'tire',
        animType = 'tire',
        label = 'Fix Tire',
        requiresHood = false,
        callback = 'sb_mechanic:applyTireRepair',
        callbackArgs = { tireIndex },
        postAction = 'tire',
        postData = { tireIndex = tireIndex },
    })
    cb({success = true, queued = true})
end)

RegisterNUICallback('applyCosmetic', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    local cosType = tostring(data.cosmeticType)
    local animType = 'cosmetic'
    local animLabel = 'Apply Modification'
    if cosType == 'neon' or cosType == 'neon_color' then
        animType = 'neon'
        animLabel = 'Install Neon'
    elseif cosType == 'xenon' or cosType == 'xenon_color' then
        animType = 'xenon'
        animLabel = 'Install Xenon Lights'
    elseif cosType == 'tint' then
        animLabel = 'Apply Window Tint'
    elseif cosType == 'horn' then
        animLabel = 'Install Horn'
    elseif cosType == 'plate' then
        animLabel = 'Change Plate'
    elseif cosType == 'livery' then
        animType = 'paint'
        animLabel = 'Apply Livery'
    elseif cosType == 'interior' or cosType == 'dashboard' then
        animLabel = 'Change Interior Color'
    end

    QueueServiceAndClose({
        type = 'cosmetic',
        animType = animType,
        label = animLabel,
        requiresHood = animType == 'xenon',
        callback = 'sb_mechanic:applyCosmetic',
        callbackArgs = { data.cosmeticType, data.value },
        postAction = 'cosmetic',
        postData = {},
    })
    cb({success = true, queued = true})
end)

RegisterNUICallback('applyWash', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return cb({success = false}) end

    QueueServiceAndClose({
        type = 'wash',
        animType = 'wash',
        label = 'Wash Vehicle',
        requiresHood = false,
        callback = 'sb_mechanic:applyWash',
        callbackArgs = {},
        postAction = 'wash',
        postData = {},
    })
    cb({success = true, queued = true})
end)

-- ============================================================================
-- Vehicle movement monitor (revert if vehicle is driven away while NUI open)
-- ============================================================================

Citizen.CreateThread(function()
    while true do
        Wait(1000)
        if nuiOpen and currentVehicle and DoesEntityExist(currentVehicle) then
            local speed = GetEntitySpeed(currentVehicle)
            if speed > 2.0 then
                exports['sb_notify']:Notify('Vehicle moved! Closing station.', 'error', 3000)
                CloseStationNUI(true)
            end
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if nuiOpen then
        CloseStationNUI(true)
    end
    -- Cleanup pending service
    if pendingService then
        CancelPendingService()
    end
end)

-- ============================================================================
-- /getcam — Debug camera helper
-- Noclip to where you want the camera, aim at the car, run /getcam
-- Prints vehicle-relative offset + pointOffset ready for config.lua
-- ============================================================================

RegisterCommand('getcam', function(source, args)
    if not exports['sb_admin']:IsAdmin() then return end
    local label = args[1] or 'unnamed'

    local ped = PlayerPedId()
    local myPos = GetEntityCoords(ped)
    local myRot = GetGameplayCamRot(2)

    -- Find nearest vehicle
    local nearestVeh = nil
    local nearestDist = 50.0
    local handle, vehicle = FindFirstVehicle()
    local found = true
    while found do
        if DoesEntityExist(vehicle) then
            local dist = #(GetEntityCoords(vehicle) - myPos)
            if dist < nearestDist then
                nearestVeh = vehicle
                nearestDist = dist
            end
        end
        found, vehicle = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)

    if not nearestVeh then
        exports['sb_notify']:Notify('No vehicle nearby', 'error', 3000)
        return
    end

    local vehPos = GetEntityCoords(nearestVeh)
    local vehHeading = GetEntityHeading(nearestVeh)

    -- Convert world coords to vehicle-local offset
    local headingRad = math.rad(vehHeading)
    local dx = myPos.x - vehPos.x
    local dy = myPos.y - vehPos.y
    local dz = myPos.z - vehPos.z

    local localX =  dx * math.cos(headingRad) + dy * math.sin(headingRad)
    local localY = -dx * math.sin(headingRad) + dy * math.cos(headingRad)
    local localZ = dz

    -- Round to 1 decimal
    localX = math.floor(localX * 10 + 0.5) / 10
    localY = math.floor(localY * 10 + 0.5) / 10
    localZ = math.floor(localZ * 10 + 0.5) / 10

    local output = string.format(
        'camera = {\n    offset = vector3(%.1f, %.1f, %.1f),\n    pointOffset = vector3(0.0, 0.0, 0.0),\n},',
        localX, localY, localZ
    )

    -- Print to F8 console + chat
    print('========== CAMERA CONFIG [' .. label .. '] ==========')
    print('Vehicle: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(nearestVeh)))
    print('Vehicle pos: ' .. tostring(vehPos))
    print('Vehicle heading: ' .. string.format('%.1f', vehHeading))
    print('Your pos: ' .. tostring(myPos))
    print('')
    print(label .. ' = {')
    print('    offset = vector3(' .. string.format('%.1f, %.1f, %.1f', localX, localY, localZ) .. '),')
    print('    pointOffset = vector3(0.0, 0.0, 0.0),')
    print('},')
    print('=============================================')

    TriggerEvent('chat:addMessage', {
        color = {255, 107, 53},
        args = {'getcam [' .. label .. ']', string.format('offset = vector3(%.1f, %.1f, %.1f) — check F8', localX, localY, localZ)}
    })

    exports['sb_notify']:Notify('[' .. label .. '] saved to F8 console', 'success', 3000)
end, false)
