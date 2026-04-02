--[[
    Everyday Chaos RP - Garage System (Client)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, blips, NUI control, vehicle store/retrieve
]]

local SB = exports['sb_core']:GetCoreObject()
local garageOpen = false
local currentGarage = nil
local spawnedNPCs = {}
local blips = {}

-- Track recently exited vehicle
local lastExitedVehicle = nil
local lastExitedTime = 0
local lastExitedPlate = nil

-- ============================================================================
-- DEBUG HELPER
-- ============================================================================

local function Debug(...)
    if Config and Config.Debug then
        print('[sb_garage:client]', ...)
    end
end

-- ============================================================================
-- MAP BLIPS
-- ============================================================================

local function CreateGarageBlips()
    for garageId, garage in pairs(Config.Garages) do
        local blip = AddBlipForCoord(garage.npcPos.x, garage.npcPos.y, garage.npcPos.z)
        SetBlipSprite(blip, garage.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, garage.blip.scale)
        SetBlipColour(blip, garage.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(garage.blip.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- ============================================================================
-- HELPER: Check if player has owned vehicle nearby in store zone
-- ============================================================================

local function HasOwnedVehicleInZone(garageId)
    local garage = Config.Garages[garageId]
    if not garage then
        Debug('HasOwnedVehicleInZone: garage not found', garageId)
        return false
    end

    local ped = PlayerPedId()

    -- Can't store if sitting in a vehicle
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        Debug('HasOwnedVehicleInZone: player is in vehicle')
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local zoneCenter = garage.storeZone.center
    local zoneRadius = garage.storeZone.radius

    -- Check recently exited vehicle
    if lastExitedVehicle and DoesEntityExist(lastExitedVehicle) then
        local vehCoords = GetEntityCoords(lastExitedVehicle)
        local distToZone = #(vehCoords - zoneCenter)
        Debug('HasOwnedVehicleInZone: lastExitedVehicle exists, distToZone=', distToZone, 'radius=', zoneRadius)
        if distToZone <= zoneRadius then
            Debug('HasOwnedVehicleInZone: TRUE (lastExitedVehicle in zone)')
            return true
        end
    end

    -- Check for any nearby owned vehicle in zone
    local vehicles = GetGamePool('CVehicle')
    Debug('HasOwnedVehicleInZone: checking', #vehicles, 'vehicles')
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local isOwned = Entity(veh).state.sb_owned
            if isOwned then
                local vehCoords = GetEntityCoords(veh)
                local distToPlayer = #(playerCoords - vehCoords)
                local distToZone = #(vehCoords - zoneCenter)

                Debug('HasOwnedVehicleInZone: owned vehicle found, distToPlayer=', distToPlayer, 'distToZone=', distToZone)

                -- Vehicle must be within 15m of player AND inside store zone
                if distToPlayer <= 15.0 and distToZone <= zoneRadius then
                    Debug('HasOwnedVehicleInZone: TRUE (owned vehicle in zone)')
                    return true
                end
            end
        end
    end

    Debug('HasOwnedVehicleInZone: FALSE (no owned vehicle in zone)')
    return false
end

-- ============================================================================
-- NPC SPAWNING
-- ============================================================================

local function SpawnGarageNPCs()
    for garageId, garage in pairs(Config.Garages) do
        local model = GetHashKey(Config.NPCModel)
        RequestModel(model)

        local timeout = 0
        while not HasModelLoaded(model) do
            Wait(10)
            timeout = timeout + 10
            if timeout > 5000 then
                print('[sb_garage] Failed to load NPC model: ' .. Config.NPCModel)
                goto continue
            end
        end

        local coords = garage.npcPos
        local npc = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        SetEntityAsMissionEntity(npc, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedCombatAttributes(npc, 46, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)

        -- Store garageId in closure for canInteract
        local gId = garageId

        -- Add target options
        exports['sb_target']:AddTargetEntity(npc, {
            {
                name = 'garage_store_' .. garageId,
                label = 'Store Vehicle',
                icon = 'fa-warehouse',
                distance = Config.InteractDistance,
                canInteract = function(entity)
                    return HasOwnedVehicleInZone(gId)
                end,
                action = function(entity)
                    StoreVehicle(gId)
                end
            },
            {
                name = 'garage_browse_' .. garageId,
                label = 'My Vehicles',
                icon = 'fa-car',
                distance = Config.InteractDistance,
                action = function(entity)
                    OpenGarage(gId)
                end
            }
        })

        spawnedNPCs[#spawnedNPCs + 1] = npc

        SetModelAsNoLongerNeeded(model)

        ::continue::
    end
end

-- ============================================================================
-- VEHICLE EXIT TRACKING
-- ============================================================================

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(ped, false)

        -- If player just exited a vehicle
        if currentVehicle == 0 and lastExitedVehicle == nil then
            local lastVeh = GetVehiclePedIsIn(ped, true)
            if lastVeh ~= 0 and DoesEntityExist(lastVeh) then
                -- Check if it's an owned vehicle
                local plate = GetVehicleNumberPlateText(lastVeh)
                local isOwned = Entity(lastVeh).state.sb_owned

                Debug('VehicleExitTracker: exited vehicle, plate=', plate, 'isOwned=', isOwned)

                if isOwned then
                    lastExitedVehicle = lastVeh
                    lastExitedTime = GetGameTimer()
                    lastExitedPlate = plate
                    Debug('VehicleExitTracker: tracking owned vehicle', plate)
                end
            end
        elseif currentVehicle ~= 0 then
            -- Player is in a vehicle, clear tracking
            if lastExitedVehicle then
                Debug('VehicleExitTracker: player entered vehicle, clearing tracking')
            end
            lastExitedVehicle = nil
            lastExitedTime = 0
            lastExitedPlate = nil
        end

        -- Clear tracking after timeout
        if lastExitedTime > 0 and (GetGameTimer() - lastExitedTime) > Config.RecentExitTime then
            Debug('VehicleExitTracker: timeout, clearing tracking for', lastExitedPlate)
            lastExitedVehicle = nil
            lastExitedTime = 0
            lastExitedPlate = nil
        end

        -- Verify tracked vehicle still exists
        if lastExitedVehicle and not DoesEntityExist(lastExitedVehicle) then
            Debug('VehicleExitTracker: tracked vehicle no longer exists')
            lastExitedVehicle = nil
            lastExitedTime = 0
            lastExitedPlate = nil
        end
    end
end)

-- ============================================================================
-- STORE VEHICLE
-- ============================================================================

function StoreVehicle(garageId)
    Debug('StoreVehicle called for garage:', garageId)

    local garage = Config.Garages[garageId]
    if not garage then
        Debug('StoreVehicle: garage not found')
        return
    end

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    -- Check if in store zone
    local zoneCenter = garage.storeZone.center
    local zoneRadius = garage.storeZone.radius
    local distance = #(playerCoords - zoneCenter)

    Debug('StoreVehicle: player distance to zone center:', distance)

    -- First check if player is currently in a vehicle
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local vehicleToStore = nil
    local plate = nil

    if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
        Debug('StoreVehicle: player is in vehicle, cannot store')
        exports['sb_notify']:Notify('Please exit your vehicle first', 'error', 3000)
        return
    end

    -- Check for recently exited vehicle
    if lastExitedVehicle and DoesEntityExist(lastExitedVehicle) then
        Debug('StoreVehicle: using lastExitedVehicle, plate:', lastExitedPlate)
        vehicleToStore = lastExitedVehicle
        plate = lastExitedPlate
    else
        Debug('StoreVehicle: no lastExitedVehicle, searching nearby')
        -- Look for nearby owned vehicles
        local vehicles = GetGamePool('CVehicle')
        local closestDist = 999.0
        local closestVeh = nil

        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local isOwned = Entity(veh).state.sb_owned
                if isOwned then
                    local vehCoords = GetEntityCoords(veh)
                    local dist = #(playerCoords - vehCoords)
                    Debug('StoreVehicle: found owned vehicle at distance:', dist)
                    if dist < closestDist and dist < 10.0 then
                        closestDist = dist
                        closestVeh = veh
                    end
                end
            end
        end

        if closestVeh then
            vehicleToStore = closestVeh
            plate = GetVehicleNumberPlateText(closestVeh)
            Debug('StoreVehicle: using closest owned vehicle, plate:', plate)
        end
    end

    if not vehicleToStore then
        Debug('StoreVehicle: no vehicle found to store')
        exports['sb_notify']:Notify('No vehicle found to store', 'error', 3000)
        return
    end

    -- Verify it's owned
    local isOwned = Entity(vehicleToStore).state.sb_owned
    Debug('StoreVehicle: vehicle sb_owned state:', isOwned)
    if not isOwned then
        exports['sb_notify']:Notify('You can only store owned vehicles', 'error', 3000)
        return
    end

    -- Block rental vehicles from being stored (FIX-001)
    local isRental = Entity(vehicleToStore).state.sb_rental
    if isRental then
        Debug('StoreVehicle: vehicle is a rental, cannot store')
        exports['sb_notify']:Notify('Rental vehicles cannot be stored in garage', 'error', 3000)
        return
    end

    -- Block test drive vehicles from being stored (FIX-002)
    local isTestDrive = Entity(vehicleToStore).state.sb_testdrive
    if isTestDrive then
        Debug('StoreVehicle: vehicle is a test drive, cannot store')
        exports['sb_notify']:Notify('Test drive vehicles cannot be stored', 'error', 3000)
        return
    end

    -- Check if anyone is in the vehicle (FIX-003: Cannot store with occupants)
    local hasOccupants = false
    for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(vehicleToStore)) - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicleToStore, seat)
        if pedInSeat ~= 0 and DoesEntityExist(pedInSeat) then
            hasOccupants = true
            Debug('StoreVehicle: vehicle has occupant in seat', seat)
            break
        end
    end

    if hasOccupants then
        Debug('StoreVehicle: vehicle has occupants, cannot store')
        exports['sb_notify']:Notify('Cannot store vehicle with passengers inside', 'error', 3000)
        return
    end

    -- Check if player has keys for this vehicle
    Debug('StoreVehicle: checking keys for plate:', plate)
    SB.Functions.TriggerCallback('sb_vehicleshop:hasKeyForPlate', function(hasKey)
        if not hasKey then
            Debug('StoreVehicle: player does not have keys')
            exports['sb_notify']:Notify('You need the car keys to store this vehicle', 'error', 3000)
            return
        end

        Debug('StoreVehicle: player has keys, proceeding...')

        -- Get vehicle properties
        Debug('StoreVehicle: getting vehicle properties...')
        local props = GetVehicleProperties(vehicleToStore)
        if not props then
            Debug('StoreVehicle: failed to get properties')
            exports['sb_notify']:Notify('Failed to read vehicle data', 'error', 3000)
            return
        end
        Debug('StoreVehicle: got properties, plate:', plate, 'fuel:', props.fuelLevel, 'body:', props.bodyHealth)

        -- Send to server
        Debug('StoreVehicle: sending to server...')
        -- Get network ID before sending to server (needed for server-side deletion)
        local netId = NetworkGetNetworkIdFromEntity(vehicleToStore)
        Debug('StoreVehicle: vehicle netId=', netId)

        SB.Functions.TriggerCallback('sb_garage:storeVehicle', function(success, message)
            Debug('StoreVehicle: server response - success:', success, 'message:', message)
            if success then
                -- Unregister from sb_impound before deleting
                TriggerServerEvent('sb_impound:server:vehicleStored', plate)

                -- Tell server to delete the vehicle entity (server-spawned entities must be deleted server-side)
                TriggerServerEvent('sb_garage:server:deleteStoredVehicle', netId, plate)

                -- Clear tracking
                lastExitedVehicle = nil
                lastExitedTime = 0
                lastExitedPlate = nil

                exports['sb_notify']:Notify('Vehicle stored successfully', 'success', 3000)
            else
                exports['sb_notify']:Notify(message or 'Failed to store vehicle', 'error', 3000)
            end
        end, plate, props, garageId)
    end, plate)
end

-- ============================================================================
-- OPEN / CLOSE GARAGE UI
-- ============================================================================

function OpenGarage(garageId)
    Debug('OpenGarage called for:', garageId)

    if garageOpen then
        Debug('OpenGarage: already open')
        return
    end

    local garage = Config.Garages[garageId]
    if not garage then
        Debug('OpenGarage: garage not found')
        return
    end

    currentGarage = garageId
    garageOpen = true

    Debug('OpenGarage: fetching vehicles...')
    -- Get player's vehicles at this garage
    SB.Functions.TriggerCallback('sb_garage:getVehicles', function(vehicles, stats)
        Debug('OpenGarage: got', #vehicles, 'vehicles')
        -- Get money for transfer fee display
        SB.Functions.TriggerCallback('sb_garage:getMoney', function(cash, bank)
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'open',
                garageName = garage.label,
                garageId = garageId,
                vehicles = vehicles,
                stats = stats,
                transferFee = Config.TransferFee,
                maxVehicles = Config.MaxVehiclesPerGarage,
                cash = cash,
                bank = bank
            })
        end)
    end, garageId)
end

function CloseGarage()
    if not garageOpen then return end

    garageOpen = false
    currentGarage = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseGarage()
    cb('ok')
end)

RegisterNUICallback('retrieve', function(data, cb)
    if not currentGarage then
        cb({ success = false })
        return
    end

    local plate = data.plate
    if not plate then
        cb({ success = false })
        return
    end

    SB.Functions.TriggerCallback('sb_garage:retrieveVehicle', function(success, vehicleData, message)
        if success and vehicleData then
            -- Find spawn point
            local garage = Config.Garages[currentGarage]
            local spawnPoint = FindAvailableSpawnPoint(garage)

            if not spawnPoint then
                exports['sb_notify']:Notify('Parking lot is full, try again later', 'error', 4000)
                cb({ success = false })
                return
            end

            -- Request SERVER to spawn the vehicle (server-side spawn = persists on disconnect)
            TriggerServerEvent('sb_garage:server:spawnVehicle', vehicleData, vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z), spawnPoint.w)

            CloseGarage()
            cb({ success = true })
        else
            exports['sb_notify']:Notify(message or 'Failed to retrieve vehicle', 'error', 3000)
            cb({ success = false })
        end
    end, plate, currentGarage)
end)

-- ============================================================================
-- SPAWN POINT CHECKING
-- ============================================================================

function FindAvailableSpawnPoint(garage)
    for _, spawnPoint in ipairs(garage.spawnPoints) do
        local occupied = IsPositionOccupied(
            spawnPoint.x, spawnPoint.y, spawnPoint.z,
            3.0,    -- radius
            false,  -- check vehicles
            true,   -- check peds
            false,  -- ignore dead peds
            false,  -- check objects
            false,  -- check projectiles
            true,   -- ignore player
            false   -- ignore known entity
        )

        -- Also check for vehicles specifically
        local vehicles = GetGamePool('CVehicle')
        local isBlocked = false

        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehCoords = GetEntityCoords(veh)
                local dist = #(vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z) - vehCoords)
                if dist < 4.0 then
                    isBlocked = true
                    break
                end
            end
        end

        if not occupied and not isBlocked then
            return spawnPoint
        end
    end

    return nil
end

-- ============================================================================
-- SPAWN VEHICLE FROM GARAGE
-- ============================================================================

function SpawnVehicleFromGarage(vehicleData, spawnPoint)
    local model = vehicleData.vehicle
    local hash = GetHashKey(model)

    RequestModel(hash)

    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            exports['sb_notify']:Notify('Failed to load vehicle model', 'error', 3000)
            return
        end
    end

    local vehicle = CreateVehicle(hash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, vehicleData.plate)

    -- Set as owned vehicle for sb_worldcontrol
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', vehicleData.plate, true)

    -- Apply saved properties
    if vehicleData.mods then
        local props = json.decode(vehicleData.mods)
        if props then
            SetVehicleProperties(vehicle, props)
        end
    end

    -- Apply basic values if not in mods
    if vehicleData.fuel then
        SetVehicleFuelLevel(vehicle, vehicleData.fuel + 0.0)
    end

    if vehicleData.body then
        SetVehicleBodyHealth(vehicle, vehicleData.body + 0.0)
    end

    if vehicleData.engine then
        SetVehicleEngineHealth(vehicle, vehicleData.engine + 0.0)
    end

    SetModelAsNoLongerNeeded(hash)

    -- Spawn unlocked so player can use it immediately
    -- They can lock it with keys if they want
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)

    -- Register with sb_impound for persistence tracking
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local props = GetVehicleProperties(vehicle)
    TriggerServerEvent('sb_impound:server:registerVehicle', vehicleData.plate, netId, vehicleData.vehicle, props)

    Debug('SpawnVehicleFromGarage: spawned vehicle, plate=', vehicleData.plate)
    exports['sb_notify']:Notify('Your ' .. vehicleData.vehicle_label .. ' is ready!', 'success', 4000)
end

-- ============================================================================
-- APPLY PROPERTIES TO SERVER-SPAWNED VEHICLE
-- ============================================================================

-- Hide vehicles flagged as hidden by server (before client applies props)
AddStateBagChangeHandler('sb_hidden', nil, function(bagName, key, value)
    if not value then return end
    -- Entity may not exist on client yet when state bag replicates — retry
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

RegisterNetEvent('sb_garage:client:applyVehicleProperties', function(netId, vehicleData)
    -- Wait for the vehicle to be fully networked (server-spawned vehicles need more time)
    Wait(1000)

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local attempts = 0

    -- Try to get the vehicle entity (may take a moment to sync)
    while (not vehicle or not DoesEntityExist(vehicle)) and attempts < 50 do
        Wait(100)
        vehicle = NetworkGetEntityFromNetworkId(netId)
        attempts = attempts + 1
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        Debug('applyVehicleProperties: Could not find vehicle with netId', netId)
        exports['sb_notify']:Notify('Failed to locate vehicle', 'error', 3000)
        return
    end

    -- Ensure vehicle is hidden (state bag handler should have done this, but be safe)
    SetEntityAlpha(vehicle, 0, false)

    -- Wait for the model to be loaded on this client (crucial for server-spawned vehicles)
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
        Debug('applyVehicleProperties: WARNING - could not get network control after 50 attempts')
    end

    -- Wait for vehicle to be fully loaded and drawable before applying any properties
    local readyAttempts = 0
    while not HasCollisionLoadedAroundEntity(vehicle) and readyAttempts < 30 do
        Wait(100)
        readyAttempts = readyAttempts + 1
    end
    Wait(500)

    -- Parse props once for reuse
    local props = nil
    if vehicleData.mods then
        props = json.decode(vehicleData.mods)
    end

    -- Apply all properties (colors and damage are applied inside SetVehicleProperties)
    SetVehicleModKit(vehicle, 0)
    if props then
        SetVehicleProperties(vehicle, props)
    end

    -- Reveal the vehicle now that all props, colors, and damage are applied
    ResetEntityAlpha(vehicle)
    Entity(vehicle).state:set('sb_hidden', false, true)

    -- Apply fuel
    if vehicleData.fuel then
        SetVehicleFuelLevel(vehicle, vehicleData.fuel + 0.0)
        if GetResourceState('sb_fuel') == 'started' then
            exports['sb_fuel']:SetFuel(vehicle, vehicleData.fuel)
        end
    end

    -- Set state bags
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', vehicleData.plate, true)

    -- Unlock doors so player can use it
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)

    -- Re-apply colors and damage in safety passes (GTA resets these on freshly spawned server vehicles)
    -- Pass 2: after 1.5s, Pass 3: after 4s (catches late GTA resets)
    local safetyPasses = { 1500, 4000 }
    for passNum, delay in ipairs(safetyPasses) do
        Wait(delay - (passNum > 1 and safetyPasses[passNum - 1] or 0))

        if not DoesEntityExist(vehicle) then break end
        if not props then break end

        if EnsureVehicleControl(vehicle, 30) then
            SetVehicleModKit(vehicle, 0)
            ApplyVehicleColors(vehicle, props)
            ApplyVehicleDamage(vehicle, props)
            Debug('applyVehicleProperties: Re-applied colors + damage on pass ' .. (passNum + 1))
        end
    end

    Debug('applyVehicleProperties: Applied properties to vehicle', vehicleData.plate)
    exports['sb_notify']:Notify('Your ' .. vehicleData.vehicle_label .. ' is ready!', 'success', 4000)
end)

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

CreateThread(function()
    while true do
        Wait(0)

        if garageOpen then
            DisableAllControlActions(0)
        end
    end
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateGarageBlips()
    SpawnGarageNPCs()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Cleanup NPCs
    for _, npc in ipairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    -- Cleanup blips
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    if garageOpen then
        SetNuiFocus(false, false)
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsGarageOpen', function()
    return garageOpen
end)

exports('GetCurrentGarage', function()
    return currentGarage
end)
