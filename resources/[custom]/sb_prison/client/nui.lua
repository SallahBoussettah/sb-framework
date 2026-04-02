-- ============================================================================
-- SB_PRISON - NUI Callbacks
-- Booking Dashboard communication (React NUI ↔ Lua)
-- ============================================================================

local nuiOpen = false

-- ============================================================================
-- OPEN / CLOSE
-- ============================================================================

function OpenBookingDashboard(escortedServerId)
    if nuiOpen then return end

    local SB = exports['sb_core']:GetCoreObject()
    local PlayerData = SB.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job or PlayerData.job.name ~= 'police' then return end

    nuiOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        type = 'open',
        officer = {
            name = (PlayerData.charinfo.firstname or '') .. ' ' .. (PlayerData.charinfo.lastname or ''),
            citizenid = PlayerData.citizenid,
            badge = tostring(PlayerData.metadata and PlayerData.metadata.callsign or PlayerData.job.grade.level),
            grade = PlayerData.job.grade.level,
        },
        escortedId = escortedServerId,
    })
end

function CloseBookingDashboard()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'forceClose' })
end

function IsBookingDashboardOpen()
    return nuiOpen
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(_, cb)
    CloseBookingDashboard()
    cb('ok')
end)

RegisterNUICallback('searchSuspect', function(data, cb)
    TriggerServerEvent('sb_prison:server:searchSuspect', data.query)
    cb('ok')
end)

RegisterNUICallback('getSuspectProfile', function(data, cb)
    TriggerServerEvent('sb_prison:server:getSuspectProfile', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('registerBooking', function(data, cb)
    TriggerServerEvent('sb_prison:server:bookPlayerFromDashboard', data)
    cb('ok')
end)

RegisterNUICallback('getMugshots', function(_, cb)
    TriggerServerEvent('sb_prison:server:getMugshots')
    cb('ok')
end)

-- ============================================================================
-- SERVER → CLIENT → NUI RELAYS
-- ============================================================================

RegisterNetEvent('sb_prison:client:nui:searchResults', function(results)
    SendNUIMessage({ type = 'searchResults', results = results })
end)

RegisterNetEvent('sb_prison:client:nui:suspectProfile', function(profile)
    SendNUIMessage({ type = 'suspectProfile', profile = profile })
end)

RegisterNetEvent('sb_prison:client:nui:bookingComplete', function(confirmation)
    SendNUIMessage({ type = 'bookingComplete', confirmation = confirmation })
end)

RegisterNetEvent('sb_prison:client:nui:mugshotList', function(photos)
    SendNUIMessage({ type = 'mugshotList', photos = photos })
end)
