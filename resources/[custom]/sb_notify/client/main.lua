--[[
    Everyday Chaos RP - Notification System
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local isUIReady = false
local lastNotifications = {} -- { message = timestamp } for deduplication
local DEDUP_COOLDOWN = 2000 -- Prevent same notification within 2 seconds

-- ============================================================================
-- SHOW NOTIFICATION
-- ============================================================================
local function ShowNotification(message, type, duration)
    if not message then return end

    type = type or 'primary'
    duration = duration or Config.DefaultDuration

    -- Deduplication: prevent same message from appearing within cooldown period
    local currentTime = GetGameTimer()
    local dedupKey = message .. '_' .. type
    if lastNotifications[dedupKey] and (currentTime - lastNotifications[dedupKey]) < DEDUP_COOLDOWN then
        return -- Skip duplicate notification
    end
    lastNotifications[dedupKey] = currentTime

    -- Clean old entries every so often (prevent memory leak)
    if math.random(1, 20) == 1 then
        for key, time in pairs(lastNotifications) do
            if (currentTime - time) > 10000 then
                lastNotifications[key] = nil
            end
        end
    end

    -- Play sound
    if Config.EnableSounds and Config.Sounds[type] then
        local sound = Config.Sounds[type]
        PlaySoundFrontend(-1, sound.name, sound.set, true)
    end

    -- Send to NUI
    SendNUIMessage({
        action = 'showNotification',
        message = message,
        type = type,
        duration = duration,
        position = Config.Position,
        maxNotifications = Config.MaxNotifications
    })
end

-- ============================================================================
-- EVENTS
-- ============================================================================

-- Listen for notifications from sb_core
RegisterNetEvent('SB:Client:Notify', function(message, type, duration)
    ShowNotification(message, type, duration)
end)

-- Alternative event name
RegisterNetEvent('sb_notify:client:Notify', function(message, type, duration)
    ShowNotification(message, type, duration)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================
exports('Notify', ShowNotification)
exports('ShowNotification', ShowNotification)

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================
RegisterNUICallback('uiReady', function(data, cb)
    isUIReady = true
    cb('ok')
end)

-- ============================================================================
-- COMMANDS (for testing)
-- ============================================================================
if Config.Debug then
    RegisterCommand('testnotify', function(source, args)
        local type = args[1] or 'primary'
        local message = args[2] or 'This is a test notification!'
        ShowNotification(message, type)
    end, false)
end

-- Always register a simple test command
RegisterCommand('notify', function(source, args)
    if #args < 2 then
        ShowNotification('Usage: /notify [type] [message]', 'error')
        return
    end

    local type = args[1]
    table.remove(args, 1)
    local message = table.concat(args, ' ')

    ShowNotification(message, type)
end, false)
