--[[
    Everyday Chaos RP - Client Events
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- PLAYER LOAD EVENTS
-- ============================================================================

-- Player loaded
RegisterNetEvent('SB:Client:OnPlayerLoaded', function(PlayerData)
    SB.PlayerData = PlayerData
    SB.Functions.SetLoggedIn(true)

    -- Set state bag
    LocalPlayer.state:set('isLoggedIn', true, true)

    -- Notify
    local charinfo = PlayerData.charinfo
    if charinfo and charinfo.firstname then
        SB.Functions.Notify(Lang('player_loaded', charinfo.firstname .. ' ' .. charinfo.lastname), 'success')
    end

    SBShared.Debug('Player loaded: ' .. PlayerData.citizenid)
end)

-- Player unloaded
RegisterNetEvent('SB:Client:OnPlayerUnload', function()
    SB.PlayerData = {}
    SB.Functions.SetLoggedIn(false)

    LocalPlayer.state:set('isLoggedIn', false, true)

    SBShared.Debug('Player unloaded')
end)

-- Update player data from server
RegisterNetEvent('SB:Client:UpdatePlayerData', function(PlayerData)
    SB.PlayerData = PlayerData
end)

-- ============================================================================
-- CALLBACK EVENTS
-- ============================================================================

-- Receive callback response from server
RegisterNetEvent('SB:Client:TriggerCallback', function(name, ...)
    if SB.ServerCallbacks[name] then
        SB.ServerCallbacks[name](...)
        SB.ServerCallbacks[name] = nil
    end
end)

-- Handle client callback request from server
RegisterNetEvent('SB:Client:TriggerClientCallback', function(name, requestId, ...)
    if SB.ClientCallbacks[name] then
        SB.ClientCallbacks[name](function(...)
            TriggerServerEvent('SB:Server:TriggerClientCallbackResponse', requestId, ...)
        end, ...)
    end
end)

-- ============================================================================
-- MONEY EVENTS
-- ============================================================================

RegisterNetEvent('SB:Client:OnMoneyChange', function(moneyType, amount, operation, reason)
    -- NOTE: Do NOT modify SB.PlayerData.money here!
    -- UpdatePlayerData() already sends the correct final state to the client.
    -- Modifying it again here would cause doubling (e.g., withdraw 1000 shows 2000 cash).

    -- This event is used by HUD and other systems to react to money changes
    -- (e.g., show change animation, play sound, etc.)

    SBShared.Debug(string.format('Money %s: %s %s | Reason: %s', operation, amount, moneyType, reason or 'unknown'))
end)

-- ============================================================================
-- JOB EVENTS
-- ============================================================================

RegisterNetEvent('SB:Client:OnJobUpdate', function(job)
    SB.PlayerData.job = job

    local msg = ('Job: %s — %s | $%s every 15min on duty'):format(
        job.label,
        job.grade and job.grade.name or 'Unknown',
        job.payment or 0
    )
    exports['sb_notify']:Notify(msg, 'info', 7000)

    SBShared.Debug('Job updated: ' .. job.name)
end)

RegisterNetEvent('SB:Client:OnDutyChange', function(onDuty)
    if SB.PlayerData.job then
        SB.PlayerData.job.onduty = onDuty
    end

    SB.Functions.Notify(onDuty and Lang('job_on_duty') or Lang('job_off_duty'), 'primary')
end)

-- ============================================================================
-- GANG EVENTS
-- ============================================================================

RegisterNetEvent('SB:Client:OnGangUpdate', function(gang)
    SB.PlayerData.gang = gang
    SB.Functions.Notify(Lang('gang_changed', gang.label), 'primary')

    SBShared.Debug('Gang updated: ' .. gang.name)
end)

-- ============================================================================
-- METADATA EVENTS
-- ============================================================================

RegisterNetEvent('SB:Client:OnMetaDataChange', function(key, value)
    if SB.PlayerData.metadata then
        SB.PlayerData.metadata[key] = value
    end

    SBShared.Debug('Metadata updated: ' .. key .. ' = ' .. tostring(value))
end)

-- ============================================================================
-- NOTIFICATION EVENT
-- ============================================================================

RegisterNetEvent('SB:Client:Notify', function(message, type, duration)
    -- Use sb_notify if available, otherwise native fallback
    if GetResourceState('sb_notify') == 'started' then
        -- sb_notify handles this event directly, so do nothing here
        -- to avoid duplicate notifications
        return
    end

    -- Fallback to native notification if sb_notify not loaded
    type = type or 'primary'
    duration = duration or Config.NotifyDuration

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)

    SBShared.Debug('Notification: ' .. message)
end)

-- ============================================================================
-- REVIVE EVENT (handled by client/death.lua)
-- ============================================================================
-- The SB:Client:Revive event is now registered in client/death.lua
-- which properly clears the death state before reviving.

-- ============================================================================
-- LOGOUT EVENT
-- ============================================================================

RegisterNetEvent('SB:Client:OnLogout', function()
    SB.PlayerData = {}
    SB.Functions.SetLoggedIn(false)

    -- Trigger multicharacter (when we have it)
    -- TriggerEvent('sb_multicharacter:client:OpenUI')

    SBShared.Debug('Player logged out')
end)

-- ============================================================================
-- CHARACTER EVENTS
-- ============================================================================

RegisterNetEvent('SB:Client:CharacterCreated', function(citizenid)
    SBShared.Debug('Character created: ' .. citizenid)
    -- Will trigger appearance customization when we have it
end)

RegisterNetEvent('SB:Client:CharacterDeleted', function(citizenid)
    SBShared.Debug('Character deleted: ' .. citizenid)
    -- Refresh character list
end)

-- ============================================================================
-- POSITION UPDATE LOOP
-- ============================================================================

CreateThread(function()
    while true do
        Wait(60000) -- Every minute

        if SB.Functions.IsLoggedIn() then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            TriggerServerEvent('SB:Server:UpdatePosition', {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                w = heading
            })
        end
    end
end)

-- ============================================================================
-- DISABLE WANTED LEVEL (if configured)
-- ============================================================================

if not Config.EnableWantedLevel then
    CreateThread(function()
        while true do
            Wait(0)

            local playerId = PlayerId()
            if GetPlayerWantedLevel(playerId) > 0 then
                SetPlayerWantedLevel(playerId, 0, false)
                SetPlayerWantedLevelNow(playerId, false)
            end
        end
    end)
end
