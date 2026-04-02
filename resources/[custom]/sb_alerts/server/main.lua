--[[
    Everyday Chaos RP - Alert System (Server)
    Author: Salah Eddine Boussettah

    Central dispatch system. Routes alerts to on-duty job members.
    Any script can send alerts via exports. Alerts are ephemeral (memory only).
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- ALERT STATE
-- ============================================================================

local alerts = {}           -- { [alertId] = alertData }
local cooldowns = {}        -- { [sourceKey] = timestamp }
local alertCounter = 0      -- Simple incrementing ID

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GenerateAlertId()
    alertCounter = alertCounter + 1
    return 'alert_' .. os.time() .. '_' .. alertCounter
end

local function IsOnCooldown(sourceKey)
    if not cooldowns[sourceKey] then return false end

    local cooldownTime = Config.SourceCooldowns[sourceKey] or Config.SourceCooldowns['default'] or 5
    return (os.time() - cooldowns[sourceKey]) < cooldownTime
end

local function SetCooldown(sourceKey)
    cooldowns[sourceKey] = os.time()
end

local function GetAlertTypeStyle(alertType)
    return Config.AlertTypes[alertType] or Config.AlertTypes['general']
end

local function GetBlipConfig(alertType, customBlip)
    local preset = Config.BlipPresets[alertType] or Config.BlipPresets['general']
    local blip = {}

    -- Start with defaults
    for k, v in pairs(Config.DefaultBlip) do
        blip[k] = v
    end

    -- Apply preset
    for k, v in pairs(preset) do
        blip[k] = v
    end

    -- Apply custom overrides
    if customBlip then
        for k, v in pairs(customBlip) do
            blip[k] = v
        end
    end

    return blip
end

-- Find all on-duty players for a job name OR job type
local function GetTargetPlayers(jobFilter)
    local targets = {}

    for src, Player in pairs(SB.Functions.GetSBPlayers()) do
        local job = Player.PlayerData.job
        if job and job.onduty then
            -- Match by exact job name
            if job.name == jobFilter then
                targets[#targets + 1] = src
            -- Match by job type (e.g., 'leo' matches police + sheriff)
            elseif job.type == jobFilter then
                targets[#targets + 1] = src
            end
        end
    end

    return targets
end

-- Clean expired alerts
local function CleanExpiredAlerts()
    local now = os.time()
    for id, alert in pairs(alerts) do
        if alert.expiresAt and now >= alert.expiresAt then
            -- Notify clients to remove blip
            for _, src in pairs(alert.notifiedPlayers or {}) do
                TriggerClientEvent('sb_alerts:client:removeAlert', src, id)
            end
            alerts[id] = nil
        end
    end
end

-- Run cleanup every 30 seconds
CreateThread(function()
    while true do
        Wait(30000)
        CleanExpiredAlerts()
    end
end)

-- ============================================================================
-- CORE: SEND ALERT
-- ============================================================================

local function SendAlert(jobFilter, data)
    if not data then return nil end
    if not jobFilter or jobFilter == '' then return nil end

    -- Validate required fields
    if not data.title then
        print('^1[sb_alerts]^7 Alert missing title')
        return nil
    end

    -- Check cooldown
    local sourceKey = data.source or 'default'
    if IsOnCooldown(sourceKey) then
        if Config.Debug then
            print('^3[sb_alerts]^7 Alert from ' .. sourceKey .. ' on cooldown')
        end
        return nil
    end

    -- Cap total alerts
    local alertCount = 0
    for _ in pairs(alerts) do alertCount = alertCount + 1 end
    if alertCount >= Config.MaxAlerts then
        -- Remove oldest
        local oldestId, oldestTime = nil, math.huge
        for id, a in pairs(alerts) do
            if a.timestamp < oldestTime then
                oldestId = id
                oldestTime = a.timestamp
            end
        end
        if oldestId then
            alerts[oldestId] = nil
        end
    end

    -- Build alert
    local alertId = GenerateAlertId()
    local alertType = data.type or 'general'
    local style = GetAlertTypeStyle(alertType)
    local blipConfig = GetBlipConfig(alertType, data.blip)
    local now = os.time()

    local alert = {
        id = alertId,
        type = alertType,
        jobFilter = jobFilter,
        title = data.title,
        description = data.description or '',
        location = data.location or '',
        coords = data.coords,
        caller = data.caller or '',
        icon = data.icon or style.icon,
        header = data.header or style.header,
        color = data.color or style.color,
        isPanic = style.isPanic or false,
        blip = blipConfig,
        source = sourceKey,
        priority = data.priority or 3,
        maxResponders = data.maxResponders or 0,
        metadata = data.metadata or {},
        timestamp = now,
        expiresAt = now + (data.expiry or Config.AlertExpiry),
        responders = {},
        notifiedPlayers = {},
    }

    alerts[alertId] = alert
    SetCooldown(sourceKey)

    -- Find targets
    local targets = GetTargetPlayers(jobFilter)

    if #targets == 0 then
        if Config.Debug then
            print('^3[sb_alerts]^7 No on-duty players for: ' .. jobFilter .. ' (alert queued)')
        end
        -- Alert stays in memory — new on-duty players can see it
        return alertId
    end

    -- Send to all targets
    local clientData = {
        id = alert.id,
        type = alert.type,
        title = alert.title,
        description = alert.description,
        location = alert.location,
        coords = alert.coords and { x = alert.coords.x, y = alert.coords.y, z = alert.coords.z } or nil,
        caller = alert.caller,
        icon = alert.icon,
        header = alert.header,
        color = alert.color,
        isPanic = alert.isPanic,
        blip = alert.blip,
        priority = alert.priority,
        timestamp = alert.timestamp,
        responderCount = 0,
    }

    for _, src in pairs(targets) do
        TriggerClientEvent('sb_alerts:client:newAlert', src, clientData)
        alert.notifiedPlayers[#alert.notifiedPlayers + 1] = src

        -- Play sound
        if style.sound then
            TriggerClientEvent('sb_alerts:client:playSound', src, style.sound.name, style.sound.set)
        end
    end

    print('^2[sb_alerts]^7 Alert sent: "' .. alert.title .. '" to ' .. #targets .. ' ' .. jobFilter .. ' player(s)')

    return alertId
end

-- ============================================================================
-- CORE: SEND TO MULTIPLE JOBS
-- ============================================================================

local function SendAlertMulti(jobFilters, data)
    if not jobFilters or type(jobFilters) ~= 'table' then return nil end

    local alertIds = {}
    for _, jobFilter in pairs(jobFilters) do
        local id = SendAlert(jobFilter, data)
        if id then
            alertIds[#alertIds + 1] = id
        end
    end

    return alertIds
end

-- ============================================================================
-- CORE: SEND TO SPECIFIC PLAYER
-- ============================================================================

local function SendAlertToPlayer(targetSource, data)
    if not targetSource or not data then return nil end

    local Player = SB.Functions.GetPlayer(targetSource)
    if not Player then return nil end

    local alertId = GenerateAlertId()
    local alertType = data.type or 'general'
    local style = GetAlertTypeStyle(alertType)
    local blipConfig = GetBlipConfig(alertType, data.blip)
    local now = os.time()

    local alert = {
        id = alertId,
        type = alertType,
        jobFilter = 'direct',
        title = data.title or 'Alert',
        description = data.description or '',
        location = data.location or '',
        coords = data.coords,
        caller = data.caller or '',
        icon = data.icon or style.icon,
        header = data.header or style.header,
        color = data.color or style.color,
        isPanic = style.isPanic or false,
        blip = blipConfig,
        source = data.source or 'direct',
        priority = data.priority or 3,
        maxResponders = data.maxResponders or 0,
        metadata = data.metadata or {},
        timestamp = now,
        expiresAt = now + (data.expiry or Config.AlertExpiry),
        responders = {},
        notifiedPlayers = { targetSource },
    }

    alerts[alertId] = alert

    local clientData = {
        id = alert.id,
        type = alert.type,
        title = alert.title,
        description = alert.description,
        location = alert.location,
        coords = alert.coords and { x = alert.coords.x, y = alert.coords.y, z = alert.coords.z } or nil,
        caller = alert.caller,
        icon = alert.icon,
        header = alert.header,
        color = alert.color,
        isPanic = alert.isPanic,
        blip = alert.blip,
        priority = data.priority or 3,
        timestamp = alert.timestamp,
        responderCount = 0,
    }

    TriggerClientEvent('sb_alerts:client:newAlert', targetSource, clientData)

    if style.sound then
        TriggerClientEvent('sb_alerts:client:playSound', targetSource, style.sound.name, style.sound.set)
    end

    return alertId
end

-- ============================================================================
-- CORE: CANCEL ALERT
-- ============================================================================

local function CancelAlert(alertId)
    local alert = alerts[alertId]
    if not alert then return false end

    for _, src in pairs(alert.notifiedPlayers) do
        TriggerClientEvent('sb_alerts:client:removeAlert', src, alertId)
    end

    alerts[alertId] = nil
    return true
end

-- ============================================================================
-- CORE: CLEAR ALL ALERTS FOR A JOB
-- ============================================================================

local function ClearJobAlerts(jobFilter)
    local cleared = 0
    for id, alert in pairs(alerts) do
        if alert.jobFilter == jobFilter then
            CancelAlert(id)
            cleared = cleared + 1
        end
    end
    return cleared
end

-- ============================================================================
-- QUERY FUNCTIONS
-- ============================================================================

local function GetActiveAlerts(jobFilter)
    local result = {}
    for id, alert in pairs(alerts) do
        if not jobFilter or alert.jobFilter == jobFilter then
            result[#result + 1] = {
                id = alert.id,
                type = alert.type,
                title = alert.title,
                location = alert.location,
                timestamp = alert.timestamp,
                responderCount = #alert.responders,
            }
        end
    end
    return result
end

local function IsAlertActive(alertId)
    return alerts[alertId] ~= nil
end

local function GetResponderCount(alertId)
    local alert = alerts[alertId]
    if not alert then return 0 end
    return #alert.responders
end

-- ============================================================================
-- CLIENT EVENTS
-- ============================================================================

-- Player accepts an alert
RegisterNetEvent('sb_alerts:server:acceptAlert', function(alertId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local alert = alerts[alertId]
    if not alert then
        TriggerClientEvent('sb_alerts:client:alertGone', src, alertId)
        return
    end

    -- Check max responders
    local maxResp = alert.maxResponders or 0
    local responders = alert.responders or {}
    alert.responders = responders

    if maxResp > 0 and #responders >= maxResp then
        SB.Functions.Notify(src, 'Maximum responders reached', 'error', 3000)
        return
    end

    -- Check if already responding
    for _, responder in pairs(responders) do
        if responder.source == src then
            SB.Functions.Notify(src, 'Already responding to this alert', 'warning', 3000)
            return
        end
    end

    -- Add as responder
    alert.responders[#alert.responders + 1] = {
        source = src,
        name = Player.Functions.GetName(),
        timestamp = os.time(),
    }

    -- Confirm to accepting player
    TriggerClientEvent('sb_alerts:client:alertAccepted', src, alertId, alert.coords and {
        x = alert.coords.x, y = alert.coords.y, z = alert.coords.z
    } or nil)

    -- Notify all notified players of updated responder count
    for _, notifiedSrc in pairs(alert.notifiedPlayers) do
        TriggerClientEvent('sb_alerts:client:updateResponders', notifiedSrc, alertId, #alert.responders)
    end

    local name = Player.Functions.GetName()
    print('^2[sb_alerts]^7 ' .. name .. ' responding to: ' .. alert.title .. ' (' .. #alert.responders .. ' total)')
end)

-- Player declines an alert
RegisterNetEvent('sb_alerts:server:declineAlert', function(alertId)
    local src = source
    -- Just remove from client, no server action needed
    TriggerClientEvent('sb_alerts:client:removeAlert', src, alertId)
end)

-- Player resolves an alert (completed the task)
RegisterNetEvent('sb_alerts:server:resolveAlert', function(alertId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local alert = alerts[alertId]
    if not alert then return end

    -- Cancel the alert for everyone
    CancelAlert(alertId)

    local name = Player.Functions.GetName()
    print('^2[sb_alerts]^7 Alert resolved by ' .. name .. ': ' .. alert.title)
end)

-- When a player goes on-duty, send them any pending alerts for their job
AddEventHandler('SB:Server:OnDutyChange', function(src, onDuty)
    if not onDuty then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.Functions.GetJob()
    if not job then return end

    -- Find alerts matching this job
    local now = os.time()
    for _, alert in pairs(alerts) do
        if alert.expiresAt and alert.expiresAt > now then
            local matches = false
            if alert.jobFilter == job.name then
                matches = true
            elseif alert.jobFilter == job.type then
                matches = true
            end

            if matches then
                -- Check if already notified
                local alreadyNotified = false
                for _, notifiedSrc in pairs(alert.notifiedPlayers) do
                    if notifiedSrc == src then
                        alreadyNotified = true
                        break
                    end
                end

                if not alreadyNotified then
                    local clientData = {
                        id = alert.id,
                        type = alert.type,
                        title = alert.title,
                        description = alert.description,
                        location = alert.location,
                        coords = alert.coords and { x = alert.coords.x, y = alert.coords.y, z = alert.coords.z } or nil,
                        caller = alert.caller,
                        icon = alert.icon,
                        header = alert.header,
                        color = alert.color,
                        isPanic = alert.isPanic,
                        blip = alert.blip,
                        priority = alert.priority,
                        timestamp = alert.timestamp,
                        responderCount = #alert.responders,
                    }

                    TriggerClientEvent('sb_alerts:client:newAlert', src, clientData)
                    alert.notifiedPlayers[#alert.notifiedPlayers + 1] = src
                end
            end
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('SendAlert', SendAlert)
exports('SendAlertMulti', SendAlertMulti)
exports('SendAlertToPlayer', SendAlertToPlayer)
exports('CancelAlert', CancelAlert)
exports('ClearJobAlerts', ClearJobAlerts)
exports('GetActiveAlerts', GetActiveAlerts)
exports('IsAlertActive', IsAlertActive)
exports('GetResponderCount', GetResponderCount)

-- ============================================================================
-- TEST COMMAND (Admin only)
-- ============================================================================

-- /testalert [type]          — sends directly to YOU (for testing the UI)
-- /testalert [type] dispatch — sends through job routing (real dispatch test)
RegisterCommand('testalert', function(source, args)
    if source > 0 then
        local Player = SB.Functions.GetPlayer(source)
        if not Player then return end
        if not IsPlayerAceAllowed(source, 'command.sb_admin') then
            SB.Functions.Notify(source, 'Admin only', 'error', 3000)
            return
        end
    end

    local alertType = args[1] or 'police'
    local mode = args[2] or 'direct'  -- 'direct' = send to self, 'dispatch' = real job routing

    -- Get player coords for the alert location
    local coords = nil
    local locationStr = 'Test Location'
    if source > 0 then
        local ped = GetPlayerPed(source)
        if ped then
            coords = GetEntityCoords(ped)
            locationStr = string.format('%.0f, %.0f, %.0f', coords.x, coords.y, coords.z)
        end
    end

    -- Test data per type
    local testAlerts = {
        ['police'] = {
            type = 'police',
            title = 'Shots Fired',
            description = 'Automatic gunfire reported near the fountain. Multiple suspects wearing masks.',
            location = 'Legion Square',
            caller = 'Anonymous Caller',
        },
        ['ems'] = {
            type = 'ems',
            title = 'Person Down',
            description = 'Unconscious person found on the sidewalk, possible overdose. Immediate medical attention required.',
            location = 'Strawberry Ave',
            caller = 'Civilian (911)',
        },
        ['mechanic'] = {
            type = 'mechanic',
            title = 'Vehicle Breakdown',
            description = 'Engine stalled on the highway, vehicle is smoking. Requesting roadside repair.',
            location = 'Route 68',
            caller = 'John Doe',
        },
        ['panic'] = {
            type = 'panic',
            title = 'Officer Down',
            description = 'Panic signal activated. Immediate backup and medical assistance required!',
            location = 'Paleto Bay Bank',
            caller = 'Unit: 1A-04',
        },
        ['general'] = {
            type = 'general',
            title = 'Dispatch Notice',
            description = 'General alert from dispatch.',
            location = 'Los Santos',
            caller = 'Dispatch',
        },
    }

    local testData = testAlerts[alertType] or testAlerts['general']
    testData.coords = coords
    testData.location = testData.location or locationStr
    testData.source = 'test_command'
    testData.priority = 2

    if mode == 'dispatch' then
        -- Real dispatch: route through job system
        local jobTarget = alertType
        if alertType == 'panic' then jobTarget = 'leo' end
        SendAlert(jobTarget, testData)
        if source > 0 then
            SB.Functions.Notify(source, 'Dispatched to: ' .. jobTarget, 'success', 3000)
        end
    else
        -- Direct: send straight to the caller (for UI testing)
        if source > 0 then
            SendAlertToPlayer(source, testData)
            SB.Functions.Notify(source, 'Test alert sent to you (' .. alertType .. ')', 'success', 3000)
        else
            print('^1[sb_alerts]^7 Direct mode requires in-game player. Use: testalert [type] dispatch')
        end
    end
end, true) -- ACE restricted

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        alerts = {}
        cooldowns = {}
        print('^3[sb_alerts]^7 Alert system stopped, all alerts cleared')
    end
end)

print('^2[sb_alerts]^7 Alert system loaded')
