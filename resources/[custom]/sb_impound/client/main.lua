--[[
    Everyday Chaos RP - Impound System (Client)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, blips, NUI, vehicle detection, retrieve spawning
]]

local SBCore = exports['sb_core']:GetCoreObject()
local spawnedNPCs = {}
local currentLocation = nil
local isUIOpen = false

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Wait for player to load
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    Wait(1000)

    -- Spawn NPCs and create blips
    for locationId, location in pairs(Config.Locations) do
        SpawnNPC(locationId, location)
        CreateLocationBlip(locationId, location)
    end

    -- Notify server player reconnected (for abandoned vehicle handling)
    TriggerServerEvent('sb_impound:server:playerReconnected')
end)

-- ============================================================================
-- NPC SPAWNING
-- ============================================================================

function SpawnNPC(locationId, location)
    local model = Config.NPCModel
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    local npc = CreatePed(4, model, location.npcPos.x, location.npcPos.y, location.npcPos.z - 1.0, location.npcPos.w, false, true)

    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    spawnedNPCs[locationId] = npc

    -- Add target
    exports['sb_target']:AddTargetEntity(npc, {
        {
            name = 'impound_' .. locationId,
            label = 'View Impounded Vehicles',
            icon = 'fa-car',
            distance = 2.5,
            action = function()
                OpenImpoundUI(locationId)
            end
        }
    })
end

function CreateLocationBlip(locationId, location)
    local blip = AddBlipForCoord(location.npcPos.x, location.npcPos.y, location.npcPos.z)
    SetBlipSprite(blip, location.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, location.blip.scale)
    SetBlipColour(blip, location.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(location.blip.label)
    EndTextCommandSetBlipName(blip)
end

-- ============================================================================
-- UI HANDLING
-- ============================================================================

function OpenImpoundUI(locationId)
    if isUIOpen then return end

    currentLocation = locationId
    local location = Config.Locations[locationId]

    -- Get impounded vehicles from server
    SBCore.Functions.TriggerCallback('sb_impound:server:getImpoundedVehicles', function(vehicles)
        if not vehicles then vehicles = {} end

        SetNuiFocus(true, true)
        isUIOpen = true

        SendNUIMessage({
            action = 'openImpound',
            location = {
                id = locationId,
                label = location.label
            },
            vehicles = vehicles
        })
    end, locationId)
end

function CloseImpoundUI()
    if not isUIOpen then return end

    SetNuiFocus(false, false)
    isUIOpen = false
    currentLocation = nil

    SendNUIMessage({
        action = 'closeImpound'
    })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('closeUI', function(data, cb)
    CloseImpoundUI()
    cb('ok')
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    if not currentLocation or not data.plate then
        cb({ success = false, error = 'Invalid request' })
        return
    end

    SBCore.Functions.TriggerCallback('sb_impound:server:retrieveVehicle', function(success, result)
        if success then
            -- Find spawn point
            local location = Config.Locations[currentLocation]
            local spawnPoint = FindAvailableSpawnPoint(location.spawnPoints)

            if not spawnPoint then
                exports['sb_notify']:Notify('No available spawn points, try again', 'error', 3000)
                cb({ success = false, error = 'No spawn point' })
                return
            end

            -- Request SERVER to spawn the vehicle (server-side spawn = persists on disconnect)
            TriggerServerEvent('sb_impound:server:spawnRetrievedVehicle', result, vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z), spawnPoint.w)

            CloseImpoundUI()
            exports['sb_notify']:Notify('Vehicle retrieved! Fee: $' .. result.fee, 'success', 5000)
            cb({ success = true })
        else
            exports['sb_notify']:Notify(result or 'Failed to retrieve vehicle', 'error', 3000)
            cb({ success = false, error = result })
        end
    end, data.plate, currentLocation)
end)

-- ============================================================================
-- VEHICLE SPAWNING
-- ============================================================================

function FindAvailableSpawnPoint(spawnPoints)
    for _, point in ipairs(spawnPoints) do
        local vehicle = GetClosestVehicle(point.x, point.y, point.z, 3.0, 0, 70)
        if vehicle == 0 then
            return point
        end
    end
    return nil
end

function SpawnRetrievedVehicle(vehicleData, spawnPoint)
    local model = vehicleData.model

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        exports['sb_notify']:Notify('Failed to load vehicle model', 'error', 3000)
        return
    end

    local vehicle = CreateVehicle(model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)

    -- Set plate
    SetVehicleNumberPlateText(vehicle, vehicleData.plate)

    -- Apply saved properties
    if vehicleData.props then
        exports['sb_garage']:SetVehicleProperties(vehicle, vehicleData.props)
    end

    -- Set fuel
    if vehicleData.fuel then
        exports['sb_fuel']:SetFuel(vehicle, vehicleData.fuel)
    end

    -- Set damage
    if vehicleData.body then
        SetVehicleBodyHealth(vehicle, vehicleData.body)
    end
    if vehicleData.engine then
        SetVehicleEngineHealth(vehicle, vehicleData.engine)
    end

    -- Mark as owned
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('sb_garage:server:setVehicleOwned', netId, vehicleData.plate)

    -- Set state bags
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', vehicleData.plate, true)

    -- Register with sb_impound for persistence tracking
    local props = exports['sb_garage']:GetVehicleProperties(vehicle)
    TriggerServerEvent('sb_impound:server:registerVehicle', vehicleData.plate, netId, vehicleData.model, props)

    SetModelAsNoLongerNeeded(model)

    -- Walk player to vehicle
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(vehicle)

    TaskGoStraightToCoord(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, 1.0, -1, 0.0, 0.0)
end

-- ============================================================================
-- SETUP SERVER-SPAWNED RETRIEVED VEHICLE
-- ============================================================================

-- Hide vehicles flagged as hidden by server (before client applies props)
AddStateBagChangeHandler('sb_hidden', nil, function(bagName, key, value)
    if not value then return end
    CreateThread(function()
        local entity = GetEntityFromStateBagName(bagName)
        local retries = 0
        while (not entity or entity == 0 or not DoesEntityExist(entity)) and retries < 50 do
            Wait(50)
            entity = GetEntityFromStateBagName(bagName)
            retries = retries + 1
        end
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            SetEntityAlpha(entity, 0, false)
        end
    end)
end)

-- Helper: ensure we have network control before modifying vehicle
local function EnsureVehicleControl(vehicle, maxAttempts)
    maxAttempts = maxAttempts or 50
    local attempts = 0
    while not NetworkHasControlOfEntity(vehicle) and attempts < maxAttempts do
        NetworkRequestControlOfEntity(vehicle)
        Wait(100)
        attempts = attempts + 1
    end
    return NetworkHasControlOfEntity(vehicle)
end

RegisterNetEvent('sb_impound:client:setupRetrievedVehicle', function(netId, vehicleData)
    -- Wait for the vehicle to be fully networked (server-spawned vehicles need more time)
    Wait(1000)

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local attempts = 0

    while (not vehicle or not DoesEntityExist(vehicle)) and attempts < 50 do
        Wait(100)
        vehicle = NetworkGetEntityFromNetworkId(netId)
        attempts = attempts + 1
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('Failed to locate vehicle', 'error', 3000)
        return
    end

    -- Ensure vehicle is hidden (state bag handler should have done this, but be safe)
    SetEntityAlpha(vehicle, 0, false)

    -- Wait for the model to be loaded on this client
    local modelHash = GetEntityModel(vehicle)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local modelWait = 0
        while not HasModelLoaded(modelHash) and modelWait < 50 do
            Wait(100)
            modelWait = modelWait + 1
        end
    end

    -- Request network control of the vehicle (essential for server-spawned vehicles)
    if not EnsureVehicleControl(vehicle, 50) then
        print('[sb_impound] WARNING - could not get network control after 50 attempts')
    end

    -- Wait for vehicle to be fully loaded before applying properties
    local readyAttempts = 0
    while not HasCollisionLoadedAroundEntity(vehicle) and readyAttempts < 30 do
        Wait(100)
        readyAttempts = readyAttempts + 1
    end
    Wait(500)

    -- IMPORTANT: Set plate first (OneSync server-spawned vehicles may not sync plate properly)
    SetVehicleNumberPlateText(vehicle, vehicleData.plate)

    -- IMPORTANT: Set mod kit BEFORE applying any colors or mods
    SetVehicleModKit(vehicle, 0)

    -- Apply saved properties (colors and damage applied inside, in correct order)
    if vehicleData.props then
        exports['sb_garage']:SetVehicleProperties(vehicle, vehicleData.props)
    end

    -- Set fuel
    if vehicleData.fuel then
        SetVehicleFuelLevel(vehicle, vehicleData.fuel + 0.0)
        if GetResourceState('sb_fuel') == 'started' then
            exports['sb_fuel']:SetFuel(vehicle, vehicleData.fuel)
        end
    end

    -- Reveal the vehicle now that all props, colors, and damage are applied
    ResetEntityAlpha(vehicle)
    Entity(vehicle).state:set('sb_hidden', false, true)

    -- Set state bags
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', vehicleData.plate, true)

    -- Unlock doors
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)

    -- Walk player to vehicle
    local playerPed = PlayerPedId()
    local vehicleCoords = GetEntityCoords(vehicle)
    TaskGoStraightToCoord(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, 1.0, -1, 0.0, 0.0)

    -- Re-apply colors and damage in safety passes (GTA resets these on freshly spawned server vehicles)
    local props = vehicleData.props
    local safetyPasses = { 1500, 4000 }
    for passNum, delay in ipairs(safetyPasses) do
        Wait(delay - (passNum > 1 and safetyPasses[passNum - 1] or 0))

        if not DoesEntityExist(vehicle) then break end
        if not props then break end

        if EnsureVehicleControl(vehicle, 30) then
            SetVehicleModKit(vehicle, 0)
            exports['sb_garage']:ApplyVehicleColors(vehicle, props)
            exports['sb_garage']:ApplyVehicleDamage(vehicle, props)
        end
    end

    exports['sb_notify']:Notify('Your ' .. vehicleData.label .. ' is ready!', 'success', 4000)
end)

-- ============================================================================
-- VEHICLE EXISTENCE CHECK (for persistence system)
-- ============================================================================

RegisterNetEvent('sb_impound:client:checkVehicleExists', function(plate, ownerCitizenId)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Search for vehicle with this plate
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(vehicle):gsub('%s+', ''):upper()

        if vehPlate == cleanPlate then
            -- Found the vehicle - get its info
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            local props = exports['sb_garage']:GetVehicleProperties(vehicle)

            -- Check if someone is driving it
            local driver = GetPedInVehicleSeat(vehicle, -1)
            local hasDriver = driver ~= 0 and driver ~= nil

            -- Report to server
            TriggerServerEvent('sb_impound:server:vehicleFound', cleanPlate, netId, props, hasDriver)
            return
        end
    end
end)

-- ============================================================================
-- GET PROPS FOR ABANDONED VEHICLE (called when owner disconnects)
-- ============================================================================

RegisterNetEvent('sb_impound:client:getVehiclePropsForAbandoned', function(plate, netId)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Try to find by netId first (faster)
    local vehicle = nil
    if netId and netId > 0 then
        vehicle = NetworkGetEntityFromNetworkId(netId)
    end

    -- Fallback: search by plate
    if not vehicle or not DoesEntityExist(vehicle) then
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            local vehPlate = GetVehicleNumberPlateText(veh):gsub('%s+', ''):upper()
            if vehPlate == cleanPlate then
                vehicle = veh
                break
            end
        end
    end

    -- If we found it, get updated props
    if vehicle and DoesEntityExist(vehicle) then
        local props = exports['sb_garage']:GetVehicleProperties(vehicle)
        local currentNetId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent('sb_impound:server:updateAbandonedProps', cleanPlate, props, currentNetId)
    end
end)

-- ============================================================================
-- DELETE VEHICLE (when impounded)
-- ============================================================================

RegisterNetEvent('sb_impound:client:deleteVehicle', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(vehicle):gsub('%s+', ''):upper()

        if vehPlate == cleanPlate then
            -- Delete the vehicle
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
            return
        end
    end
end)

-- ============================================================================
-- VEHICLE ENTERED TRACKING (for stolen detection)
-- ============================================================================

CreateThread(function()
    local lastVehicle = nil

    while true do
        Wait(500)

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and vehicle ~= lastVehicle then
            -- Entered a new vehicle
            local plate = GetVehicleNumberPlateText(vehicle)
            local cleanPlate = plate:gsub('%s+', ''):upper()

            -- Get player's citizenid
            local PlayerData = SBCore.Functions.GetPlayerData()
            if PlayerData and PlayerData.citizenid then
                -- Check if we're in driver seat
                if GetPedInVehicleSeat(vehicle, -1) == playerPed then
                    -- Get netId and model for re-registration if needed
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    local model = GetEntityModel(vehicle)
                    TriggerServerEvent('sb_impound:server:vehicleEntered', cleanPlate, PlayerData.citizenid, netId, model)
                end
            end

            lastVehicle = vehicle
        elseif vehicle == 0 then
            lastVehicle = nil
        end
    end
end)

-- ============================================================================
-- GET VEHICLE PROPS FOR MANUAL IMPOUND
-- ============================================================================

RegisterNetEvent('sb_impound:client:getVehiclePropsForImpound', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(vehicle):gsub('%s+', ''):upper()

        if vehPlate == cleanPlate then
            local props = exports['sb_garage']:GetVehicleProperties(vehicle)
            local isDestroyed = IsVehicleDamaged(vehicle) and GetVehicleEngineHealth(vehicle) < 100

            TriggerServerEvent('sb_impound:server:confirmSendToImpound', cleanPlate, props, isDestroyed)
            return
        end
    end

    -- Vehicle not found in world
    exports['sb_notify']:Notify('Vehicle not found', 'error', 3000)
end)

-- ============================================================================
-- IMPOUND OWN VEHICLE COMMAND HANDLER (only for destroyed vehicles)
-- ============================================================================

RegisterNetEvent('sb_impound:client:impoundOwnVehicle', function()
    local playerPed = PlayerPedId()
    local vehicle = nil

    -- Check if player is in a vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        vehicle = GetVehiclePedIsIn(playerPed, false)
    else
        -- Check for nearby vehicle
        local playerCoords = GetEntityCoords(playerPed)
        vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 70)
    end

    if not vehicle or vehicle == 0 then
        exports['sb_notify']:Notify('No vehicle found nearby', 'error', 3000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Check if this is the player's vehicle (via state bag)
    local isOwned = Entity(vehicle).state.sb_owned
    if not isOwned then
        exports['sb_notify']:Notify('This is not your vehicle', 'error', 3000)
        return
    end

    -- Check if destroyed (engine health below 100)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local isDestroyed = engineHealth < 100

    -- Only allow impounding destroyed vehicles
    if not isDestroyed then
        exports['sb_notify']:Notify('Vehicle is not destroyed. Use a garage to store it.', 'error', 4000)
        return
    end

    -- Get vehicle properties
    local props = exports['sb_garage']:GetVehicleProperties(vehicle)

    -- Exit vehicle if inside
    if IsPedInAnyVehicle(playerPed, false) then
        TaskLeaveVehicle(playerPed, vehicle, 0)
        Wait(1500)
    end

    -- Show progress
    exports['sb_progressbar']:Start({
        duration = 3000,
        label = 'Calling impound service...',
        canCancel = false
    })
    Wait(3000)

    -- Send to server
    TriggerServerEvent('sb_impound:server:confirmSendToImpound', cleanPlate, props, true)

    -- Delete vehicle locally (server will also broadcast delete)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)

    exports['sb_notify']:Notify('Destroyed vehicle sent to impound ($2500 fee to retrieve)', 'success', 5000)
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Delete NPCs
    for _, npc in pairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    -- Close UI
    if isUIOpen then
        SetNuiFocus(false, false)
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsImpoundOpen', function()
    return isUIOpen
end)

exports('GetCurrentImpoundLocation', function()
    return currentLocation
end)
