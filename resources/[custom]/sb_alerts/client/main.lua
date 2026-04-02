--[[
    Everyday Chaos RP - Alert System (Client)
    Author: Salah Eddine Boussettah

    Handles NUI display, blip management, and keybind interactions.
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local activeAlerts = {}      -- { [alertId] = alertData }
local alertBlips = {}        -- { [alertId] = blipHandle }
local acceptedAlerts = {}    -- { [alertId] = true }
local focusedAlertId = nil   -- Currently focused alert (most recent)
local isUIReady = false

-- Forward declarations
local RemoveAlertBlip

-- ============================================================================
-- NUI COMMUNICATION
-- ============================================================================

local function SendToNUI(action, data)
    SendNUIMessage({
        action = action,
        data = data
    })
end

-- ============================================================================
-- BLIP MANAGEMENT
-- ============================================================================

local function CreateAlertBlip(alertId, alertData)
    if not alertData.coords then return end

    local coords = alertData.coords
    local blipCfg = alertData.blip or {}

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipCfg.sprite or 161)
    SetBlipColour(blip, blipCfg.color or 1)
    SetBlipScale(blip, blipCfg.scale or 1.0)
    SetBlipAsShortRange(blip, false)

    if blipCfg.flash then
        SetBlipFlashes(blip, true)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(alertData.title or 'Alert')
    EndTextCommandSetBlipName(blip)

    alertBlips[alertId] = blip

    -- Auto-remove blip after duration
    local duration = (blipCfg.duration or Config.DefaultBlipDuration) * 1000
    if duration > 0 then
        SetTimeout(duration, function()
            RemoveAlertBlip(alertId)
        end)
    end
end

RemoveAlertBlip = function(alertId)
    local blip = alertBlips[alertId]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    alertBlips[alertId] = nil
end

local lastGPSNotify = 0

local function SetGPSToAlert(alertId)
    local alert = activeAlerts[alertId]
    if not alert or not alert.coords then return end

    SetNewWaypoint(alert.coords.x, alert.coords.y)

    -- Only notify once per 5 seconds to avoid spam
    local now = GetGameTimer()
    if now - lastGPSNotify > 5000 then
        lastGPSNotify = now
        exports['sb_notify']:Notify('GPS set to alert location', 'success', 3000)
    end
end

-- ============================================================================
-- ALERT LIFECYCLE
-- ============================================================================

local function AddAlert(alertData)
    activeAlerts[alertData.id] = alertData
    focusedAlertId = alertData.id

    -- Create blip on map
    CreateAlertBlip(alertData.id, alertData)

    -- Send to NUI
    SendToNUI('newAlert', {
        id = alertData.id,
        type = alertData.type,
        title = alertData.title,
        description = alertData.description,
        location = alertData.location,
        caller = alertData.caller,
        icon = alertData.icon,
        header = alertData.header,
        color = alertData.color,
        isPanic = alertData.isPanic,
        priority = alertData.priority,
        responderCount = alertData.responderCount or 0,
        duration = Config.ToastDuration,
        gpsKey = Config.GPSKey,
        acceptKey = Config.AcceptKey,
    })
end

local function RemoveAlert(alertId)
    activeAlerts[alertId] = nil
    acceptedAlerts[alertId] = nil
    RemoveAlertBlip(alertId)

    if focusedAlertId == alertId then
        -- Focus next alert
        focusedAlertId = nil
        for id, _ in pairs(activeAlerts) do
            focusedAlertId = id
            break
        end
    end

    SendToNUI('removeAlert', { id = alertId })
end

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterNetEvent('sb_alerts:client:newAlert', function(alertData)
    AddAlert(alertData)
end)

RegisterNetEvent('sb_alerts:client:removeAlert', function(alertId)
    RemoveAlert(alertId)
end)

RegisterNetEvent('sb_alerts:client:alertAccepted', function(alertId, coords)
    acceptedAlerts[alertId] = true

    -- Set blip route (blue GPS line — no extra waypoint marker)
    if coords then
        local blip = alertBlips[alertId]
        if blip and DoesBlipExist(blip) then
            SetBlipRoute(blip, true)
            SetBlipRouteColour(blip, 38) -- Blue route
        end

        -- Monitor arrival — clear blip + route when close
        CreateThread(function()
            local arrivalDist = 50.0
            while acceptedAlerts[alertId] and activeAlerts[alertId] do
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                local dist = #(pos - vector3(coords.x, coords.y, coords.z))

                if dist < arrivalDist then
                    RemoveAlertBlip(alertId)
                    exports['sb_notify']:Notify('Arrived at alert location', 'success', 3000)
                    break
                end

                Wait(2000)
            end
        end)
    end

    SendToNUI('alertAccepted', { id = alertId })
    exports['sb_notify']:Notify('Alert accepted — GPS route set', 'success', 3000)
end)

RegisterNetEvent('sb_alerts:client:alertGone', function(alertId)
    RemoveAlert(alertId)
    exports['sb_notify']:Notify('Alert is no longer active', 'warning', 3000)
end)

RegisterNetEvent('sb_alerts:client:updateResponders', function(alertId, count)
    if activeAlerts[alertId] then
        activeAlerts[alertId].responderCount = count
        SendToNUI('updateResponders', { id = alertId, count = count })
    end
end)

RegisterNetEvent('sb_alerts:client:playSound', function(soundName, soundSet)
    PlaySoundFrontend(-1, soundName, soundSet, true)
end)

-- ============================================================================
-- KEYBINDS
-- ============================================================================

-- H key — Set GPS to focused alert
-- Command renamed to reset FiveM's cached keybinding (was +alert_gps bound to G)
RegisterCommand('+sb_alert_setgps', function()
    if focusedAlertId and activeAlerts[focusedAlertId] then
        SetGPSToAlert(focusedAlertId)
    end
end, false)
RegisterCommand('-sb_alert_setgps', function() end, false)
RegisterKeyMapping('+sb_alert_setgps', 'Set GPS to Alert', 'keyboard', Config.GPSKey)

-- Y key — Accept focused alert
local lastAcceptNotify = 0
RegisterCommand('+sb_alert_accept', function()
    if focusedAlertId and activeAlerts[focusedAlertId] then
        if acceptedAlerts[focusedAlertId] then
            local now = GetGameTimer()
            if now - lastAcceptNotify > 5000 then
                lastAcceptNotify = now
                exports['sb_notify']:Notify('Already responding', 'warning', 2000)
            end
            return
        end
        TriggerServerEvent('sb_alerts:server:acceptAlert', focusedAlertId)
    end
end, false)
RegisterCommand('-sb_alert_accept', function() end, false)
RegisterKeyMapping('+sb_alert_accept', 'Accept Alert', 'keyboard', Config.AcceptKey)

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('uiReady', function(data, cb)
    isUIReady = true
    cb('ok')
end)

RegisterNUICallback('acceptAlert', function(data, cb)
    local alertId = data.id
    if alertId and activeAlerts[alertId] then
        if not acceptedAlerts[alertId] then
            TriggerServerEvent('sb_alerts:server:acceptAlert', alertId)
        end
    end
    cb('ok')
end)

RegisterNUICallback('declineAlert', function(data, cb)
    local alertId = data.id
    if alertId then
        TriggerServerEvent('sb_alerts:server:declineAlert', alertId)
        RemoveAlert(alertId)
    end
    cb('ok')
end)

RegisterNUICallback('setGPS', function(data, cb)
    local alertId = data.id
    if alertId and activeAlerts[alertId] then
        SetGPSToAlert(alertId)
    end
    cb('ok')
end)

RegisterNUICallback('alertExpired', function(data, cb)
    local alertId = data.id
    if alertId then
        RemoveAlert(alertId)
    end
    cb('ok')
end)

-- ============================================================================
-- EXPORTS (Client)
-- ============================================================================

exports('GetMyAlerts', function()
    local result = {}
    for id, alert in pairs(activeAlerts) do
        result[#result + 1] = {
            id = alert.id,
            type = alert.type,
            title = alert.title,
            accepted = acceptedAlerts[id] or false,
        }
    end
    return result
end)

exports('HasPendingAlerts', function()
    for id, _ in pairs(activeAlerts) do
        if not acceptedAlerts[id] then
            return true
        end
    end
    return false
end)

exports('AcceptAlert', function(alertId)
    if alertId and activeAlerts[alertId] and not acceptedAlerts[alertId] then
        TriggerServerEvent('sb_alerts:server:acceptAlert', alertId)
    end
end)

exports('DeclineAlert', function(alertId)
    if alertId then
        TriggerServerEvent('sb_alerts:server:declineAlert', alertId)
        RemoveAlert(alertId)
    end
end)

exports('ResolveAlert', function(alertId)
    if alertId then
        TriggerServerEvent('sb_alerts:server:resolveAlert', alertId)
        RemoveAlert(alertId)
    end
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Remove all blips
        for id, _ in pairs(alertBlips) do
            RemoveAlertBlip(id)
        end
        activeAlerts = {}
        acceptedAlerts = {}
        alertBlips = {}
    end
end)
