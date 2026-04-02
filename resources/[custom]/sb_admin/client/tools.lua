-- sb_admin/client/tools.lua
-- Teleport, Godmode, Revive, Coords, Vehicle Spawn

GodmodeActive = false
local adminVehicle = nil
local showCoords = false

-- Teleport to Waypoint
function TeleportToWaypoint()
    local waypoint = GetFirstBlipInfoId(8) -- Waypoint blip

    if not DoesBlipExist(waypoint) then
        SendNUIMessage({ action = 'notify', text = 'No waypoint set!', type = 'error' })
        return
    end

    local coord = GetBlipInfoIdCoord(waypoint)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = vehicle ~= 0 and vehicle or ped

    -- Try to find ground Z
    local groundFound = false
    local groundZ = 0.0

    -- Teleport high first, then raycast down
    SetEntityCoords(entity, coord.x, coord.y, 800.0, false, false, false, false)
    Wait(500)

    -- Try multiple heights
    for z = 800.0, 0.0, -25.0 do
        SetEntityCoords(entity, coord.x, coord.y, z, false, false, false, false)
        Wait(50)
        local found, gZ = GetGroundZFor_3dCoord(coord.x, coord.y, z, false)
        if found then
            groundZ = gZ
            groundFound = true
            break
        end
    end

    if groundFound then
        SetEntityCoords(entity, coord.x, coord.y, groundZ + 1.0, false, false, false, false)
    else
        SetEntityCoords(entity, coord.x, coord.y, coord.z + 1.0, false, false, false, false)
    end

    SendNUIMessage({ action = 'notify', text = 'Teleported!', type = 'success' })
end

-- God Mode
function ToggleGodmode()
    GodmodeActive = not GodmodeActive
    local ped = PlayerPedId()
    SetEntityInvincible(ped, GodmodeActive)

    if GodmodeActive then
        SendNUIMessage({ action = 'notify', text = 'God Mode: ON', type = 'success' })
    else
        SendNUIMessage({ action = 'notify', text = 'God Mode: OFF', type = 'info' })
    end
end

-- Maintain god mode on ped change
CreateThread(function()
    local lastPed = 0
    while true do
        if GodmodeActive then
            local ped = PlayerPedId()
            if ped ~= lastPed then
                SetEntityInvincible(ped, true)
                lastPed = ped
            end
        end
        Wait(1000)
    end
end)

-- Revive Self
function ReviveSelf()
    local ped = PlayerPedId()

    -- Resurrect if dead
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(
            GetEntityCoords(ped).x,
            GetEntityCoords(ped).y,
            GetEntityCoords(ped).z,
            GetEntityHeading(ped),
            true, false
        )
        ped = PlayerPedId()
    end

    -- Full heal
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    ClearPedLastWeaponDamage(ped)

    -- Clear ragdoll
    SetPedToRagdoll(ped, 0, 0, 0, false, false, false)

    -- Trigger sb_deaths revive if available
    TriggerEvent('sb_deaths:revive')

    SendNUIMessage({ action = 'notify', text = 'Revived!', type = 'success' })
end

-- Spawn Vehicle
function SpawnAdminVehicle(modelName)
    if not modelName or modelName == '' then
        SendNUIMessage({ action = 'notify', text = 'Invalid model name!', type = 'error' })
        return
    end

    local hash = GetHashKey(modelName)

    if not IsModelInCdimage(hash) then
        SendNUIMessage({ action = 'notify', text = 'Model not found: ' .. modelName, type = 'error' })
        return
    end

    -- Request model
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            SendNUIMessage({ action = 'notify', text = 'Model load timeout!', type = 'error' })
            return
        end
    end

    local ped = PlayerPedId()

    -- If player is in a vehicle, delete it and remove its keys
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    if currentVehicle ~= 0 then
        local oldPlate = GetVehicleNumberPlateText(currentVehicle)
        TaskLeaveVehicle(ped, currentVehicle, 16)
        Wait(300)
        if DoesEntityExist(currentVehicle) then
            DeleteEntity(currentVehicle)
        end
        -- Remove keys for old vehicle
        if oldPlate then
            TriggerServerEvent('sb_admin:removeCarKeys', oldPlate:gsub("%s+", ""))
        end
    -- Otherwise, delete previous admin vehicle if exists
    elseif Config and Config.DeletePreviousVehicle and adminVehicle and DoesEntityExist(adminVehicle) then
        local oldPlate = GetVehicleNumberPlateText(adminVehicle)
        DeleteEntity(adminVehicle)
        if oldPlate then
            TriggerServerEvent('sb_admin:removeCarKeys', oldPlate:gsub("%s+", ""))
        end
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Spawn in front of player
    local forwardX = coords.x + (-math.sin(math.rad(heading)) * 3.0)
    local forwardY = coords.y + (math.cos(math.rad(heading)) * 3.0)

    local vehicle = CreateVehicle(hash, forwardX, forwardY, coords.z + 0.5, heading, true, false)
    SetModelAsNoLongerNeeded(hash)

    -- Set as admin vehicle
    adminVehicle = vehicle

    -- Set player in driver seat
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    -- Generate a unique plate
    local plate = 'ADM' .. math.random(10000, 99999)
    SetVehicleNumberPlateText(vehicle, plate)

    -- Vehicle setup
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDirtLevel(vehicle, 0.0)

    -- Mark as player-owned (for sb_worldcontrol compatibility)
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', plate, true)

    -- Request server to give keys
    TriggerServerEvent('sb_admin:giveCarKeys', plate, modelName)

    SendNUIMessage({ action = 'notify', text = 'Spawned: ' .. modelName, type = 'success' })
    exports['sb_notify']:Notify('Spawned: ' .. modelName .. ' (keys given)', 'success', 3000)
end

-- Coordinates display thread
CreateThread(function()
    while true do
        if showCoords then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            -- Draw text on screen
            local text = string.format("~o~X:~w~ %.2f ~o~Y:~w~ %.2f ~o~Z:~w~ %.2f ~o~H:~w~ %.2f", coords.x, coords.y, coords.z, heading)
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextDropShadow()
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString(text)
            DrawText(0.01, 0.95)

            -- Draw marker at feet
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.1, 255, 140, 0, 100, false, true, 2, nil, nil, false)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Toggle coords display from NUI
RegisterNUICallback('toggleCoords', function(data, cb)
    showCoords = not showCoords
    cb({ active = showCoords })
end)

-- ============================================================================
-- TIME CONTROL
-- ============================================================================

local timeFreeze = false
local frozenHour = 12
local frozenMinute = 0

RegisterNetEvent('sb_admin:setTime', function(hour, minute)
    frozenHour = hour
    frozenMinute = minute
    timeFreeze = true -- Auto-freeze when setting time
    NetworkOverrideClockTime(hour, minute, 0)
    SendNUIMessage({ action = 'notify', text = ('Time: %02d:%02d (frozen)'):format(hour, minute), type = 'success' })
end)

RegisterNetEvent('sb_admin:toggleFreezeTime', function()
    timeFreeze = not timeFreeze
    if timeFreeze then
        frozenHour = GetClockHours()
        frozenMinute = GetClockMinutes()
        SendNUIMessage({ action = 'notify', text = ('Time frozen at %02d:%02d'):format(frozenHour, frozenMinute), type = 'info' })
    else
        NetworkOverrideClockTime(GetClockHours(), GetClockMinutes(), 0)
        SendNUIMessage({ action = 'notify', text = 'Time unfrozen', type = 'info' })
    end
end)

-- Keep time frozen
CreateThread(function()
    while true do
        if timeFreeze then
            NetworkOverrideClockTime(frozenHour, frozenMinute, 0)
        end
        Wait(1000)
    end
end)

-- Server teleport event (used by /goto and /bring)
RegisterNetEvent('sb_admin:teleport', function(coords)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = vehicle ~= 0 and vehicle or ped
    SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false)
end)

-- Full heal event (used by /heal - sets health to max)
RegisterNetEvent('sb_admin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    ClearPedLastWeaponDamage(ped)
end)

-- ============================================================================
-- REMOVE VEHICLE (looking at or inside)
-- ============================================================================

function GetVehicleLookingAt()
    local ped = PlayerPedId()

    -- Use camera direction instead of ped forward so it matches where you're actually looking
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local radX = camRot.x * math.pi / 180.0
    local radZ = camRot.z * math.pi / 180.0
    local forward = vector3(
        -math.sin(radZ) * math.abs(math.cos(radX)),
        math.cos(radZ) * math.abs(math.cos(radX)),
        math.sin(radX)
    )
    local endCoords = camCoords + forward * 25.0

    -- Raycast from camera in look direction (flag 10 = vehicles)
    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, 10, ped, 0)
    local _, hit, _, _, entity = GetShapeTestResult(rayHandle)

    if hit and DoesEntityExist(entity) and IsEntityAVehicle(entity) then
        return entity
    end

    -- Fallback: find closest vehicle within 5m
    local playerCoords = GetEntityCoords(ped)
    local closestVeh = nil
    local closestDist = 5.0
    local handle, veh = FindFirstVehicle()
    local found = true
    while found do
        if DoesEntityExist(veh) and veh ~= GetVehiclePedIsIn(ped, false) then
            local dist = #(playerCoords - GetEntityCoords(veh))
            if dist < closestDist then
                closestDist = dist
                closestVeh = veh
            end
        end
        found, veh = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)

    return closestVeh
end

function RemoveVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    -- If in a vehicle, get out first then delete
    if vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        TaskLeaveVehicle(ped, vehicle, 16)
        Wait(500)
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
            -- Remove keys for this plate
            if plate then
                TriggerServerEvent('sb_admin:removeCarKeys', plate:gsub("%s+", ""))
            end
            exports['sb_notify']:Notify('Vehicle removed (keys taken)', 'success', 2000)
        end
        return true
    end

    -- Otherwise, try to get vehicle we're looking at
    vehicle = GetVehicleLookingAt()

    if vehicle and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        -- Request network control so we can delete vehicles we don't own
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        NetworkRequestControlOfEntity(vehicle)
        local timeout = 0
        while not NetworkHasControlOfEntity(vehicle) and timeout < 20 do
            Wait(100)
            NetworkRequestControlOfEntity(vehicle)
            timeout = timeout + 1
        end
        if NetworkHasControlOfEntity(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteEntity(vehicle)
            if plate then
                TriggerServerEvent('sb_admin:removeCarKeys', plate:gsub("%s+", ""))
            end
            exports['sb_notify']:Notify('Vehicle removed (keys taken)', 'success', 2000)
        else
            exports['sb_notify']:Notify('Could not get control of vehicle', 'error', 2000)
        end
        return true
    end

    exports['sb_notify']:Notify('No vehicle found', 'error', 2000)
    return false
end

-- /removecar command
RegisterCommand('removecar', function()
    if not exports['sb_admin']:IsAdmin() then
        exports['sb_notify']:Notify('No permission', 'error', 2000)
        return
    end
    RemoveVehicle()
end, false)

-- /car [model] - Spawn a vehicle by model name
RegisterCommand('car', function(source, args)
    if not exports['sb_admin']:IsAdmin() then
        exports['sb_notify']:Notify('No permission', 'error', 2000)
        return
    end

    local model = args[1]
    if not model or model == '' then
        exports['sb_notify']:Notify('Usage: /car [model]', 'error', 3000)
        return
    end

    SpawnAdminVehicle(model)
end, false)

-- /dv - Delete vehicle (alias for removecar)
RegisterCommand('dv', function()
    if not exports['sb_admin']:IsAdmin() then
        exports['sb_notify']:Notify('No permission', 'error', 2000)
        return
    end
    RemoveVehicle()
end, false)

-- /tp x, y, z[, heading] - Teleport to specific coordinates
RegisterCommand('tp', function(source, args)
    if not exports['sb_admin']:IsAdmin() then
        exports['sb_notify']:Notify('No permission', 'error', 2000)
        return
    end

    -- Join all args and strip commas to support: /tp -550.47, -192.47, 38.22, 38.24
    local raw = table.concat(args, ' ')
    local parts = {}
    for num in raw:gmatch("[%-]?%d+%.?%d*") do
        parts[#parts + 1] = tonumber(num)
    end

    if #parts < 3 then
        exports['sb_notify']:Notify('Usage: /tp x, y, z[, heading]', 'error', 3000)
        return
    end

    local x, y, z = parts[1], parts[2], parts[3]
    local heading = parts[4]

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = vehicle ~= 0 and vehicle or ped

    SetEntityCoords(entity, x, y, z, false, false, false, false)
    if heading then
        SetEntityHeading(entity, heading)
    end

    exports['sb_notify']:Notify(string.format('Teleported to %.2f, %.2f, %.2f', x, y, z), 'success', 3000)
end, false)

-- /cp4 - Copy current vector4 position to clipboard
RegisterCommand('cp4', function()
    if not exports['sb_admin']:IsAdmin() then
        exports['sb_notify']:Notify('No permission', 'error', 2000)
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local text = string.format("%.2f, %.2f, %.2f, %.2f", coords.x, coords.y, coords.z, heading)
    SendNUIMessage({ action = 'copyText', text = text })
    exports['sb_notify']:Notify('Copied vector4: ' .. text, 'success', 3000)
end, false)

-- /cp3 - Copy current vector3 position to clipboard
RegisterCommand('cp3', function()
    if not exports['sb_admin']:IsAdmin() then
        exports['sb_notify']:Notify('No permission', 'error', 2000)
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local text = string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z)
    SendNUIMessage({ action = 'copyText', text = text })
    exports['sb_notify']:Notify('Copied vector3: ' .. text, 'success', 3000)
end, false)
