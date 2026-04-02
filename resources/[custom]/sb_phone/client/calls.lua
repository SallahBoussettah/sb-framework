-- ============================================================================
-- SB Phone V2 — Client Calls (pma-voice integration)
-- Author: Salah Eddine Boussettah
-- ============================================================================

local callState = 'idle'
local callChannel = nil
local callData = nil
local callTimeoutThread = nil

local function SetCallState(state) callState = state end

local function EndCallCleanup()
    if callChannel then
        local ok, err = pcall(function()
            exports['pma-voice']:setCallChannel(0)
        end)
        if not ok then print('^1[sb_phone]^7 pma-voice cleanup error: ' .. tostring(err)) end
        callChannel = nil
    end
    LocalPlayer.state:set('phoneInCall', 0, true)
    LocalPlayer.state:set('callSpeaker', false, true)
    NetworkSetVoiceActive(true)
    callData = nil
    SetCallState('idle')

    PhoneState.inCall = false
    PhoneState.inCallPeek = false
    PhoneState.callSpeaker = false
    PhoneState.callChannel = 0

    SendNUIMessage({ action = 'callEnded' })

    if not PhoneState.isOpen then
        SetPhoneFocus(false)
    end
end

-- Outgoing: Caller sees "Calling..."
RegisterNetEvent('sb_phone:client:callRinging', function()
    SetCallState('outgoing')
    SendNUIMessage({ action = 'callRinging' })

    callTimeoutThread = SetTimeout(Config.CallTimeout * 1000, function()
        if callState == 'outgoing' then
            TriggerServerEvent('sb_phone:server:endCall')
            EndCallCleanup()
            exports['sb_notify']:Notify('No answer', 'info', 3000)
        end
    end)
end)

-- Incoming: Target sees Dynamic Island expand
RegisterNetEvent('sb_phone:client:incomingCall', function(data)
    SetCallState('incoming')
    callData = data

    SendNUIMessage({
        action = 'incomingCall',
        data = {
            callerName = data.callerName,
            callerNumber = data.callerNumber,
            callerSource = data.callerSource,
            initial = data.callerName:sub(1, 1):upper(),
            ringtone = data.ringtone or 'default'
        }
    })

    if not PhoneState.isOpen then
        SetPhoneFocus(true)
    end

    callTimeoutThread = SetTimeout(Config.CallTimeout * 1000, function()
        if callState == 'incoming' then
            TriggerServerEvent('sb_phone:server:declineCall', data.callerSource)
            EndCallCleanup()
            SetPhoneFocus(false)
        end
    end)
end)

-- Call accepted: both join voice channel
RegisterNetEvent('sb_phone:client:callAccepted', function(channel)
    SetCallState('active')
    callChannel = channel
    PhoneState.callChannel = channel

    local ok, err = pcall(function()
        exports['pma-voice']:setCallChannel(channel)
    end)
    if not ok then
        print('^1[sb_phone]^7 pma-voice connect error: ' .. tostring(err))
        exports['sb_notify']:Notify('Voice channel failed', 'error', 3000)
    end
    LocalPlayer.state:set('phoneInCall', channel, true)
    LocalPlayer.state:set('callSpeaker', false, true)

    SendNUIMessage({
        action = 'callConnected',
        data = { channel = channel }
    })
end)

-- Call ended
RegisterNetEvent('sb_phone:client:callEnded', function()
    EndCallCleanup()
end)

-- Call declined
RegisterNetEvent('sb_phone:client:callDeclined', function()
    EndCallCleanup()
    exports['sb_notify']:Notify('Call declined', 'info', 3000)
    SendNUIMessage({ action = 'callDeclined' })
end)

-- Call failed (voicemail)
RegisterNetEvent('sb_phone:client:callFailed', function(reason)
    SetCallState('idle')
    callData = nil
    PhoneState.inCall = false
    PhoneState.inCallPeek = false
    NetworkSetVoiceActive(true)
    SendNUIMessage({
        action = 'callFailed',
        data = { reason = reason }
    })
end)

-- Cleanup
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if callState ~= 'idle' then EndCallCleanup() end
end)
