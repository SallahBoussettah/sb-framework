-- sb_mechanic_v2 | Client Diagnostics
-- OBD scanner target, physical inspection targets, NUI bridge

local SB = exports['sb_core']:GetCoreObject()

local isTabletOpen = false
local scanPlate = nil  -- plate currently being scanned

-- ===== SHARED canInteract FOR ALL DIAG TARGETS =====
local function DiagCanInteract(entity, distance, coords)
    if isTabletOpen then return false end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    if not entity or not DoesEntityExist(entity) then return false end
    if not Entity(entity).state.sb_plate then return false end
    local Player = SB.Functions.GetPlayerData()
    if not Player or not Config.IsMechanicJob(Player.job.name) then return false end
    return true
end

-- ===== canInteract FOR OBD SCANNER =====
-- Item check happens in action (server-side) since inventory has no client export
local ScannerCanInteract = DiagCanInteract

-- ===== OBD SCANNER TARGET =====
-- Global vehicle target: "Plug In OBD Scanner"
exports['sb_target']:AddGlobalVehicle({
    {
        name = 'mechanic_obd_scanner',
        label = 'Plug In OBD Scanner',
        icon = 'fa-laptop-medical',
        distance = 2.5,
        canInteract = ScannerCanInteract,
        action = function(entity)
            local plate = Entity(entity).state.sb_plate
            if not plate then
                exports['sb_notify']:Notify('No diagnostic port found.', 'error', 3000)
                return
            end

            -- Check if player has OBD2 Scanner (server-side)
            SB.Functions.TriggerCallback('sb_mechanic_v2:hasItem', function(hasScanner)
                if not hasScanner then
                    exports['sb_notify']:Notify('You need an OBD2 Scanner to diagnose vehicles.', 'error', 4000)
                    return
                end

                -- Progress bar with animation (callback-based)
                exports['sb_progressbar']:Start({
                    duration = 3000,
                    label = 'Connecting scanner...',
                    canCancel = true,
                    animation = {
                        dict = 'anim@gangops@facility@servers@bodysearch@',
                        anim = 'player_search',
                        flag = 1,
                    },
                    onComplete = function()
                        -- Pre-scan: sync native vehicle state to server before running DTC checks
                        -- This catches damage that happened outside telemetry (e.g. shot tires, broken windshield)
                        local nativeState = {}
                        if DoesEntityExist(entity) then
                            -- Engine & body
                            nativeState.engine_block = math.max(0.0, math.min(100.0, GetVehicleEngineHealth(entity) / 10.0))
                            nativeState.body_panels = math.max(0.0, math.min(100.0, GetVehicleBodyHealth(entity) / 10.0))
                            -- Tires + windshield via shared helper
                            local tireOverrides = ReadTireState(entity)
                            for comp, val in pairs(tireOverrides) do
                                nativeState[comp] = val
                            end
                        end

                        -- Debug: show what the client reads from GTA natives
                        print('[sb_mechanic_v2] preScan nativeState:')
                        for comp, val in pairs(nativeState) do
                            print(('  %s = %.1f'):format(comp, val))
                        end
                        -- Also log raw windshield checks per index
                        if DoesEntityExist(entity) then
                            for _, wndIdx in ipairs({0, 1, 2, 3, 4, 5, 6, 7}) do
                                local intact = IsVehicleWindowIntact(entity, wndIdx)
                                if not intact then
                                    print(('  [WINDOW] index %d = BROKEN'):format(wndIdx))
                                end
                            end
                        end

                        -- Callback chain: wait for server to process sync, THEN run scan
                        SB.Functions.TriggerCallback('sb_mechanic_v2:preScanSyncCB', function(synced)
                            if not synced then
                                exports['sb_notify']:Notify('Sync failed — retrying scan...', 'warning', 2000)
                            end
                            scanPlate = plate
                            SB.Functions.TriggerCallback('sb_mechanic_v2:scanVehicle', function(results, diagLevel, xpGain)
                                if not results then
                                    exports['sb_notify']:Notify('Scan failed.', 'error', 3000)
                                    return
                                end
                                OpenDiagnosticTablet(plate, results, diagLevel, xpGain)
                            end, plate)
                        end, plate, nativeState)
                    end,
                    onCancel = function()
                        exports['sb_notify']:Notify('Scanner connection cancelled.', 'error', 2000)
                    end,
                })
            end, 'tool_diagnostic')
        end,
    },
})

-- PHYSICAL INSPECTION TARGETS REMOVED: Inspections now accessible via tablet SVG zone clicks.

-- ===== PERFORM PHYSICAL INSPECTION =====
function PerformInspection(entity, zone)
    local plate = Entity(entity).state.sb_plate
    if not plate then
        exports['sb_notify']:Notify('Cannot identify vehicle.', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        duration = 2000,
        label = 'Inspecting ' .. zone .. '...',
        canCancel = true,
        animation = {
            dict = 'mini@repair',
            anim = 'fixing_a_player',
            flag = 1,
        },
        onComplete = function()
            -- Request inspection from server
            SB.Functions.TriggerCallback('sb_mechanic_v2:inspectZone', function(texts, xpGain)
                if not texts or #texts == 0 then
                    exports['sb_notify']:Notify('Nothing to report.', 'info', 3000)
                    return
                end

                -- Show results as notifications
                for i, text in ipairs(texts) do
                    SetTimeout(i * 400, function()
                        exports['sb_notify']:Notify(text, 'info', 5000)
                    end)
                end

                -- Show XP gain
                if xpGain and xpGain > 0 then
                    SetTimeout((#texts + 1) * 400, function()
                        exports['sb_notify']:Notify('+' .. xpGain .. ' XP', 'success', 2000)
                    end)
                end
            end, plate, zone)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Inspection cancelled.', 'error', 2000)
        end,
    })
end

-- ===== NUI: OPEN TABLET =====
function OpenDiagnosticTablet(plate, results, diagLevel, xpGain)
    if isTabletOpen then return end
    isTabletOpen = true
    scanPlate = plate

    SendNUIMessage({
        action = 'open',
        plate = plate,
        results = results,
        diagLevel = diagLevel or 1,
        xpGain = xpGain or 0,
        timestamp = ('%02d:%02d:%02d'):format(GetClockHours(), GetClockMinutes(), GetClockSeconds()),
    })

    SetNuiFocus(true, true)
end

-- ===== NUI: CLOSE TABLET =====
function CloseDiagnosticTablet()
    if not isTabletOpen then return end
    isTabletOpen = false

    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    scanPlate = nil
end

-- ===== NUI CALLBACKS =====
RegisterNUICallback('closeDiagnostics', function(_, cb)
    CloseDiagnosticTablet()
    cb('ok')
end)

-- Physical inspection from SVG zone click
RegisterNUICallback('inspectZone', function(data, cb)
    local zone = data.zone
    if not zone or not scanPlate then
        cb('error')
        return
    end

    -- Find the vehicle by plate
    local vehicles = GetGamePool('CVehicle')
    local targetVeh = nil
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local plate = Entity(veh).state.sb_plate
            if plate == scanPlate then
                targetVeh = veh
                break
            end
        end
    end

    if not targetVeh then
        cb('error')
        return
    end

    -- Close tablet temporarily and do inspection
    CloseDiagnosticTablet()

    -- Small delay then perform inspection
    SetTimeout(300, function()
        PerformInspection(targetVeh, zone)
    end)

    cb('ok')
end)

-- ===== ESC KEY TO CLOSE =====
CreateThread(function()
    while true do
        Wait(0)
        if isTabletOpen then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 142, true)  -- MeleeAttackAlternate
            DisableControlAction(0, 18, true)   -- Enter
            DisableControlAction(0, 322, true)  -- ESC (cancel)
            DisableControlAction(0, 200, true)  -- ESC (pause)

            if IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 200) then
                CloseDiagnosticTablet()
            end
        else
            Wait(500)
        end
    end
end)

-- ===== CLEANUP =====
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isTabletOpen then
        CloseDiagnosticTablet()
    end
end)
