-- =============================================
-- SB_POLICE - Client Main
-- React UI Integration
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

local isOnDuty = false
local isMDTOpen = false
local playerJob = nil
local characterLoaded = false  -- Track if character has been loaded

-- Refresh SB object when sb_core restarts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- =============================================
-- Initialization - Wait for Character Load
-- =============================================

-- Listen for character spawn complete from sb_multicharacter
RegisterNetEvent('sb_multicharacter:client:SpawnComplete', function()
    characterLoaded = true
    print('[sb_police] ^2Character spawn complete, requesting job data...^7')
    Wait(500)  -- Small delay to ensure sb_core has finished setting up player
    RequestJobData()
end)

-- Also listen for sb_core player loaded event (backup)
RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    if not characterLoaded then
        characterLoaded = true
        print('[sb_police] ^2Player loaded via SB:Client:OnPlayerLoaded^7')
        Wait(500)
        RequestJobData()
    end
end)

-- Function to request job data
function RequestJobData()
    -- Try to get job data from cached SB object first
    if SB and SB.PlayerData and SB.PlayerData.job then
        playerJob = SB.PlayerData.job
        print('[sb_police] ^2Got job from SB.PlayerData:^7 ' .. (playerJob.name or 'unknown'))
    else
        -- Request job data from server
        print('[sb_police] ^3Requesting job data from server...^7')
        TriggerServerEvent('sb_police:server:requestJobData')
    end
end

-- Handle sb_police resource restart (only request if character already loaded)
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Check if player is already spawned (resource restart scenario)
        Wait(1000)
        local playerPed = PlayerPedId()
        if playerPed and DoesEntityExist(playerPed) and not IsEntityDead(playerPed) then
            -- Player exists, likely a resource restart - request job data
            characterLoaded = true
            print('[sb_police] ^3Resource restarted with active player, requesting job data...^7')
            TriggerServerEvent('sb_police:server:requestJobData')
        end
    end
end)

-- =============================================
-- Job Updates
-- =============================================

function GetCurrentJob()
    if SB and SB.PlayerData and SB.PlayerData.job then
        return SB.PlayerData.job
    end
    return nil
end

RegisterNetEvent('SB:Client:OnJobUpdate', function(job)
    playerJob = job
    print('[sb_police] ^3Job updated via event:^7 ' .. (job.name or 'unknown'))

    if job.name == Config.PoliceJob then
        exports['sb_notify']:Notify('MDT available - Press ' .. Config.MDTKey .. ' to open', 'info', 5000)
    else
        if isMDTOpen then
            CloseMDT()
            exports['sb_notify']:Notify('You are no longer a police officer', 'error', 3000)
        end
    end
end)

RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    Wait(500)
    playerJob = GetCurrentJob()
    if playerJob then
        print('[sb_police] ^2Player loaded, job:^7 ' .. (playerJob.name or 'unknown'))
    end
end)

RegisterNetEvent('sb_police:client:setJobData', function(job)
    playerJob = job
    print('[sb_police] ^5Job set via server event:^7 ' .. (job.name or 'unknown'))

    -- Notify if police
    if job.name == Config.PoliceJob then
        exports['sb_notify']:Notify('Police MDT ready - Press ' .. Config.MDTKey, 'success', 3000)
    end
end)

-- Manual refresh command if job detection fails
RegisterCommand('refreshjob', function()
    characterLoaded = true  -- If user is manually refreshing, character must be loaded
    print('[sb_police] ^3Manually refreshing job data...^7')
    TriggerServerEvent('sb_police:server:requestJobData')
    exports['sb_notify']:Notify('Refreshing job data...', 'info', 2000)
end, false)

-- =============================================
-- MDT Controls
-- =============================================

RegisterCommand('openMDT', function()
    if not CanOpenMDT() then
        exports['sb_notify']:Notify('You must be a police officer to use the MDT', 'error', 3000)
        return
    end
    ToggleMDT()
end, false)

RegisterKeyMapping('openMDT', 'Open Police MDT', 'keyboard', Config.MDTKey)

function CanOpenMDT()
    -- Must have character loaded first
    if not characterLoaded then return false end

    if not playerJob then
        playerJob = GetCurrentJob()
    end

    if not playerJob then return false end

    return playerJob.name == Config.PoliceJob
end

function ToggleMDT()
    if isMDTOpen then
        CloseMDT()
    else
        OpenMDT()
    end
end

function OpenMDT()
    if isMDTOpen then return end

    isMDTOpen = true
    SetNuiFocus(true, true)

    local charinfo = SB.PlayerData and SB.PlayerData.charinfo or {}
    local job = SB.PlayerData and SB.PlayerData.job or {}

    SendNUIMessage({
        type = 'open',
        officerData = {
            name = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or ''),
            rank = job.grade and job.grade.name or 'Officer',
            badge = job.metadata and job.metadata.badge or 'N/A',
            isOnDuty = isOnDuty,
            grade = job.grade and job.grade.level or 0
        }
    })

    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    print('[sb_police] MDT Opened')
end

function CloseMDT()
    if not isMDTOpen then return end

    isMDTOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        type = 'close'
    })

    print('[sb_police] MDT Closed')
end

-- =============================================
-- NUI Callbacks
-- =============================================

RegisterNUICallback('close', function(_, cb)
    CloseMDT()
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(data, cb)
    TriggerServerEvent('sb_police:server:toggleDuty', data.isOnDuty)
    cb('ok')
end)

RegisterNUICallback('getOfficers', function(_, cb)
    TriggerServerEvent('sb_police:server:getOnDutyOfficers')
    cb('ok')
end)

RegisterNUICallback('getAlerts', function(_, cb)
    TriggerServerEvent('sb_police:server:getAlerts')
    cb('ok')
end)

RegisterNUICallback('getPenalCode', function(_, cb)
    TriggerServerEvent('sb_police:server:getPenalCode')
    cb('ok')
end)

RegisterNUICallback('searchCitizens', function(data, cb)
    TriggerServerEvent('sb_police:server:searchCitizens', data.query)
    cb('ok')
end)

RegisterNUICallback('searchVehicles', function(data, cb)
    TriggerServerEvent('sb_police:server:searchVehicles', data.query)
    cb('ok')
end)

RegisterNUICallback('getCitizenDetails', function(data, cb)
    TriggerServerEvent('sb_police:server:getCitizenDetails', data.id)
    cb('ok')
end)

RegisterNUICallback('getVehicleDetails', function(data, cb)
    TriggerServerEvent('sb_police:server:getVehicleDetails', data.plate)
    cb('ok')
end)

RegisterNUICallback('applyCharges', function(data, cb)
    TriggerServerEvent('sb_police:server:applyCharges', data.citizenId, data.charges, data.totalFine, data.totalJail)
    cb('ok')
end)

RegisterNUICallback('filterReports', function(data, cb)
    TriggerServerEvent('sb_police:server:filterReports', data.filter)
    cb('ok')
end)

RegisterNUICallback('createReport', function(_, cb)
    TriggerServerEvent('sb_police:server:createReport')
    cb('ok')
end)

RegisterNUICallback('updateReport', function(data, cb)
    TriggerServerEvent('sb_police:server:updateReport', data.id, data.title, data.description)
    cb('ok')
end)

RegisterNUICallback('markVehicleStolen', function(data, cb)
    TriggerServerEvent('sb_police:server:markVehicleStolen', data.plate)
    cb('ok')
end)

RegisterNUICallback('addVehicleBOLO', function(data, cb)
    TriggerServerEvent('sb_police:server:addVehicleBOLO', data.plate)
    cb('ok')
end)

-- Warrants & BOLOs
RegisterNUICallback('getWarrants', function(_, cb)
    TriggerServerEvent('sb_police:server:getWarrants')
    cb('ok')
end)

RegisterNUICallback('createWarrant', function(data, cb)
    TriggerServerEvent('sb_police:server:createWarrant', data.citizenId, data.citizenName, data.charges, data.reason, data.priority)
    cb('ok')
end)

RegisterNUICallback('closeWarrant', function(data, cb)
    TriggerServerEvent('sb_police:server:closeWarrant', data.warrantId, data.closedReason)
    cb('ok')
end)

RegisterNUICallback('getBOLOs', function(_, cb)
    TriggerServerEvent('sb_police:server:getBOLOs')
    cb('ok')
end)

RegisterNUICallback('createBOLO', function(data, cb)
    TriggerServerEvent('sb_police:server:createBOLO', data.personName, data.description, data.reason, data.lastSeen, data.priority)
    cb('ok')
end)

RegisterNUICallback('closeBOLO', function(data, cb)
    TriggerServerEvent('sb_police:server:closeBOLO', data.boloId, data.closedReason)
    cb('ok')
end)

RegisterNUICallback('getAllVehicleFlags', function(_, cb)
    TriggerServerEvent('sb_police:server:getAllVehicleFlags')
    cb('ok')
end)

-- Officer Roster
RegisterNUICallback('getOfficerRoster', function(_, cb)
    TriggerServerEvent('sb_police:server:getOfficerRoster')
    cb('ok')
end)

RegisterNUICallback('updateOfficerStatus', function(data, cb)
    TriggerServerEvent('sb_police:server:updateOfficerStatus', data.status)
    cb('ok')
end)

RegisterNUICallback('setOfficerGrade', function(data, cb)
    TriggerServerEvent('sb_police:server:setOfficerGradeByCitizenId', data.citizenid, data.grade)
    cb('ok')
end)

RegisterNUICallback('fireOfficer', function(data, cb)
    TriggerServerEvent('sb_police:server:fireOfficerByCitizenId', data.citizenid)
    cb('ok')
end)

-- Time Clock / Duty Stats
RegisterNUICallback('getDutyStats', function(_, cb)
    TriggerServerEvent('sb_police:server:getDutyStats')
    cb('ok')
end)

RegisterNUICallback('getAllOfficersDuty', function(_, cb)
    TriggerServerEvent('sb_police:server:getAllOfficersDuty')
    cb('ok')
end)

-- Citations
RegisterNUICallback('createCitation', function(data, cb)
    TriggerServerEvent('sb_police:server:createCitation', data.targetSource or data.citizenId, data.offense, data.fine, data.notes, data.vehiclePlate, data.location)
    cb('ok')
end)

-- Citizen Notes
RegisterNUICallback('addCitizenNote', function(data, cb)
    TriggerServerEvent('sb_police:server:addCitizenNote', data.citizenId, data.note)
    cb('ok')
end)

RegisterNUICallback('deleteCitizenNote', function(data, cb)
    TriggerServerEvent('sb_police:server:deleteCitizenNote', data.noteId, data.citizenId)
    cb('ok')
end)

-- Dispatch actions (delegate to sb_alerts)
RegisterNUICallback('acceptAlert', function(data, cb)
    TriggerServerEvent('sb_alerts:server:acceptAlert', data.alertId)
    -- Set GPS waypoint if coords available
    if data.coords and data.coords.x and data.coords.y then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
        exports['sb_notify']:Notify('GPS waypoint set', 'info', 2000)
    end
    cb('ok')
end)

RegisterNUICallback('declineAlert', function(data, cb)
    TriggerServerEvent('sb_alerts:server:declineAlert', data.alertId)
    cb('ok')
end)

RegisterNUICallback('setAlertGPS', function(data, cb)
    if data.coords and data.coords.x and data.coords.y then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
        exports['sb_notify']:Notify('GPS waypoint set', 'info', 2000)
    else
        exports['sb_notify']:Notify('No coordinates available for this alert', 'error', 3000)
    end
    cb('ok')
end)

RegisterNUICallback('resolveAlert', function(data, cb)
    TriggerServerEvent('sb_alerts:server:resolveAlert', data.alertId)
    cb('ok')
end)

-- Report Improvements
RegisterNUICallback('addReportSuspect', function(data, cb)
    TriggerServerEvent('sb_police:server:addReportSuspect', data.reportId, data.citizenId, data.citizenName)
    cb('ok')
end)

RegisterNUICallback('addReportVictim', function(data, cb)
    TriggerServerEvent('sb_police:server:addReportVictim', data.reportId, data.citizenName)
    cb('ok')
end)

RegisterNUICallback('addReportVehicle', function(data, cb)
    TriggerServerEvent('sb_police:server:addReportVehicle', data.reportId, data.plate)
    cb('ok')
end)

RegisterNUICallback('addReportEvidence', function(data, cb)
    TriggerServerEvent('sb_police:server:addReportEvidence', data.reportId, data.text)
    cb('ok')
end)

RegisterNUICallback('addReportOfficer', function(data, cb)
    TriggerServerEvent('sb_police:server:addReportOfficer', data.reportId, data.officerName)
    cb('ok')
end)

RegisterNUICallback('removeReportItem', function(data, cb)
    TriggerServerEvent('sb_police:server:removeReportItem', data.reportId, data.fieldName, data.index)
    cb('ok')
end)

RegisterNUICallback('updateReportStatus', function(data, cb)
    TriggerServerEvent('sb_police:server:updateReportStatus', data.reportId, data.status)
    cb('ok')
end)

-- =============================================
-- Server Events
-- =============================================

RegisterNetEvent('sb_police:client:updateDuty', function(onDuty, shiftStartUnix)
    isOnDuty = onDuty

    SendNUIMessage({
        type = 'updateDuty',
        isOnDuty = isOnDuty,
        shiftStart = shiftStartUnix or nil  -- Unix seconds, optional (for duty restore after restart)
    })

    if onDuty then
        if shiftStartUnix then
            -- Restored from resource restart (no os.time on client)
            exports['sb_notify']:Notify('Duty restored — shift continues', 'success', 4000)
        else
            exports['sb_notify']:Notify('You are now on duty', 'success', 3000)
        end
    else
        exports['sb_notify']:Notify('You are now off duty', 'info', 3000)
    end
end)

RegisterNetEvent('sb_police:client:updateOfficers', function(officers)
    SendNUIMessage({
        type = 'updateOfficers',
        officers = officers
    })
end)

RegisterNetEvent('sb_police:client:updateAlerts', function(alerts)
    SendNUIMessage({
        type = 'updateAlerts',
        alerts = alerts
    })
end)

RegisterNetEvent('sb_police:client:searchResults', function(searchType, results)
    SendNUIMessage({
        type = 'searchResults',
        searchType = searchType,
        results = results
    })
end)

RegisterNetEvent('sb_police:client:penalCode', function(codes)
    SendNUIMessage({
        type = 'penalCode',
        codes = codes
    })
end)

RegisterNetEvent('sb_police:client:citizenDetails', function(citizen)
    SendNUIMessage({
        type = 'citizenDetails',
        citizen = citizen
    })
end)

RegisterNetEvent('sb_police:client:vehicleDetails', function(vehicle)
    SendNUIMessage({
        type = 'vehicleDetails',
        vehicle = vehicle
    })
end)

RegisterNetEvent('sb_police:client:reportsList', function(reports)
    SendNUIMessage({
        type = 'reportsList',
        reports = reports
    })
end)

RegisterNetEvent('sb_police:client:reportCreated', function(reportId)
    exports['sb_notify']:Notify('Report #' .. reportId .. ' created', 'success', 3000)
    TriggerServerEvent('sb_police:server:filterReports', 'all')
end)

RegisterNetEvent('sb_police:client:chargesApplied', function(success, citizenId)
    if success then
        exports['sb_notify']:Notify('Charges applied successfully', 'success', 3000)
        -- Re-fetch citizen details so the profile updates in real time
        if citizenId then
            TriggerServerEvent('sb_police:server:getCitizenDetails', citizenId)
        end
    else
        exports['sb_notify']:Notify('Failed to apply charges', 'error', 3000)
    end
end)

-- Warrants & BOLOs
RegisterNetEvent('sb_police:client:warrantsList', function(warrants)
    SendNUIMessage({ type = 'warrantsList', warrants = warrants })
end)

RegisterNetEvent('sb_police:client:bolosList', function(bolos)
    SendNUIMessage({ type = 'bolosList', bolos = bolos })
end)

RegisterNetEvent('sb_police:client:vehicleFlagsList', function(flags)
    SendNUIMessage({ type = 'vehicleFlagsList', flags = flags })
end)

-- Officer Roster
RegisterNetEvent('sb_police:client:officerRoster', function(roster)
    SendNUIMessage({ type = 'officerRoster', roster = roster })
end)

-- Duty Stats
RegisterNetEvent('sb_police:client:dutyStats', function(stats)
    SendNUIMessage({ type = 'dutyStats', stats = stats })
end)

RegisterNetEvent('sb_police:client:allOfficersDuty', function(data)
    SendNUIMessage({ type = 'allOfficersDuty', data = data })
end)

-- Citation created
RegisterNetEvent('sb_police:client:citationCreated', function(citationId, citizenId)
    exports['sb_notify']:Notify('Citation #' .. citationId .. ' created', 'success', 3000)
    -- Re-fetch citizen details to refresh profile
    if citizenId then
        TriggerServerEvent('sb_police:server:getCitizenDetails', citizenId)
    end
end)

-- Citizen notes updated
RegisterNetEvent('sb_police:client:citizenNotes', function(citizenId, notes)
    SendNUIMessage({ type = 'citizenNotes', citizenId = citizenId, notes = notes })
end)

-- sb_alerts client integration — pipe alerts directly to MDT NUI
RegisterNetEvent('sb_alerts:client:newAlert', function(alertData)
    if not isOnDuty then return end
    -- Map sb_alerts priority (1=high, 2=medium, 3=low) to MDT strings
    local pri = 'medium'
    if alertData.priority == 1 then pri = 'high'
    elseif alertData.priority == 3 then pri = 'low' end

    -- Push directly to React MDT dispatch page
    SendNUIMessage({
        type = 'newAlert',
        alert = {
            id = alertData.id,
            title = alertData.title or 'Alert',
            location = alertData.location or 'Unknown',
            coords = alertData.coords or nil,
            priority = pri,
            caller = alertData.caller or 'Dispatch',
            type = alertData.type or nil,
            time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
            timestamp = alertData.timestamp or GetGameTimer(),
            responderCount = alertData.responderCount or 0,
        }
    })
end)

RegisterNetEvent('sb_alerts:client:removeAlert', function(alertId)
    if not isOnDuty then return end
    SendNUIMessage({
        type = 'removeAlert',
        alertId = alertId,
    })
end)

RegisterNetEvent('sb_alerts:client:updateResponders', function(alertId, count)
    if not isOnDuty then return end
    SendNUIMessage({
        type = 'updateResponders',
        alertId = alertId,
        responderCount = count,
    })
end)

-- Report Improvements
RegisterNetEvent('sb_police:client:reportUpdated', function(reportId, field, updatedItems)
    SendNUIMessage({ type = 'reportUpdated', reportId = reportId, field = field, items = updatedItems })
end)

RegisterNetEvent('sb_police:client:reportStatusUpdated', function(reportId, status)
    SendNUIMessage({ type = 'reportStatusUpdated', reportId = reportId, status = status })
end)

-- =============================================
-- Exports
-- =============================================

exports('IsOnDuty', function()
    return isOnDuty
end)

exports('IsMDTOpen', function()
    return isMDTOpen
end)

exports('OpenMDT', function()
    if CanOpenMDT() then
        OpenMDT()
    end
end)

exports('CloseMDT', function()
    CloseMDT()
end)

-- =============================================
-- Debug Command
-- =============================================

-- /cite command - quick field citation
RegisterCommand('cite', function(source, args)
    if not CanOpenMDT() then
        exports['sb_notify']:Notify('You must be a police officer', 'error', 3000)
        return
    end
    if not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty to issue citations', 'error', 3000)
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        exports['sb_notify']:Notify('Usage: /cite [server_id]', 'info', 3000)
        return
    end

    -- Open MDT and navigate to citizen page with citation form
    if not isMDTOpen then
        OpenMDT()
    end

    -- Send target info to NUI so citation form can pre-fill
    Wait(500)
    SendNUIMessage({
        type = 'openCitationForm',
        targetSource = targetId,
    })
end, false)

RegisterCommand('policedebug', function()
    print('[sb_police] ========== DEBUG INFO ==========')
    print('[sb_police] Character Loaded:', characterLoaded)
    print('[sb_police] Cached playerJob:')
    print('  Name:', playerJob and playerJob.name or 'nil')
    print('  Grade:', playerJob and playerJob.grade and playerJob.grade.name or 'nil')
    print('[sb_police] STATE:')
    print('  Is On Duty:', isOnDuty)
    print('  MDT Open:', isMDTOpen)
    print('  Can Open MDT:', CanOpenMDT())
    print('[sb_police] ==================================')

    local charStatus = characterLoaded and 'Yes' or 'No'
    local msg = 'Char: ' .. charStatus .. ' | Job: ' .. (playerJob and playerJob.name or 'nil') .. ' | Can open: ' .. tostring(CanOpenMDT())
    exports['sb_notify']:Notify(msg, 'info', 5000)
end, false)
