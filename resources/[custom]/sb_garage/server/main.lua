--[[
    Everyday Chaos RP - Garage System (Server)
    Author: Salah Eddine Boussettah

    Handles: Database operations, validation, vehicle storage/retrieval
]]

local SB = exports['sb_core']:GetCoreObject()

-- Operation locks to prevent double processing
local operationLocks = {}

-- Last operation timestamps for cooldown
local lastOperations = {}

-- ============================================================================
-- SERVER START: Return all "out" vehicles to garage
-- Vehicles with state=0 have no entity in the world after a restart.
-- Move them back to stored (state=1) in their last garage (or legion fallback).
-- ============================================================================

CreateThread(function()
    Wait(1000) -- Wait for oxmysql to be ready

    local affected = MySQL.update.await([[
        UPDATE player_vehicles
        SET state = 1,
            garage = CASE
                WHEN garage IS NULL OR garage = '' OR garage = 'none' THEN 'legion'
                ELSE garage
            END
        WHERE state = 0
    ]])

    if affected and affected > 0 then
        print('^3[sb_garage]^7 Server restart detected: returned ' .. affected .. ' vehicle(s) to their garages')
    end
end)

-- ============================================================================
-- DEBUG HELPER
-- ============================================================================

local function Debug(...)
    if Config and Config.Debug then
        print('[sb_garage:server]', ...)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function LockOperation(citizenid)
    operationLocks[citizenid] = os.time()
end

local function UnlockOperation(citizenid)
    operationLocks[citizenid] = nil
end

-- Check if locked, but auto-unlock after 10 seconds (prevents stuck locks)
local function IsOperationLocked(citizenid)
    local lockTime = operationLocks[citizenid]
    if not lockTime then return false end

    -- Auto-unlock after 10 seconds
    if (os.time() - lockTime) > 10 then
        Debug('IsOperationLocked: auto-unlocking stuck lock for', citizenid)
        operationLocks[citizenid] = nil
        return false
    end

    return true
end

local function CheckCooldown(citizenid)
    local lastOp = lastOperations[citizenid] or 0
    local now = os.time() * 1000
    if (now - lastOp) < Config.StoreCooldown then
        return false
    end
    lastOperations[citizenid] = now
    return true
end

-- Log vehicle history event (wrapped in pcall to prevent errors if table doesn't exist)
local function LogVehicleHistory(plate, eventType, description, actorCitizenid, metadata)
    pcall(function()
        MySQL.insert('INSERT INTO vehicle_history (plate, event_type, description, actor_citizenid, metadata) VALUES (?, ?, ?, ?, ?)', {
            plate,
            eventType,
            description,
            actorCitizenid,
            metadata and json.encode(metadata) or nil
        })
    end)
end

-- Count vehicles at a garage
local function GetGarageVehicleCount(citizenid, garageId)
    local result = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = 1', {
        citizenid, garageId
    })
    return result or 0
end

-- ============================================================================
-- SERVER-SIDE VEHICLE SPAWN (OneSync persistent - prevents deletion on owner disconnect)
-- ============================================================================

-- Get vehicle type for CreateVehicleServerSetter
local function GetVehicleType(model)
    local vehicleTypes = {
        -- Bikes
        ['bmx'] = 'bike', ['cruiser'] = 'bike', ['fixter'] = 'bike', ['scorcher'] = 'bike', ['tribike'] = 'bike', ['tribike2'] = 'bike', ['tribike3'] = 'bike',
        -- Motorcycles
        ['akuma'] = 'bike', ['avarus'] = 'bike', ['bagger'] = 'bike', ['bati'] = 'bike', ['bati2'] = 'bike', ['bf400'] = 'bike',
        ['carbonrs'] = 'bike', ['daemon'] = 'bike', ['daemon2'] = 'bike', ['double'] = 'bike', ['enduro'] = 'bike',
        ['faggio'] = 'bike', ['faggio2'] = 'bike', ['faggio3'] = 'bike', ['fcr'] = 'bike', ['fcr2'] = 'bike',
        ['hakuchou'] = 'bike', ['hakuchou2'] = 'bike', ['hexer'] = 'bike', ['innovation'] = 'bike',
        ['nemesis'] = 'bike', ['nightblade'] = 'bike', ['oppressor'] = 'bike', ['oppressor2'] = 'bike',
        ['pcj'] = 'bike', ['sanchez'] = 'bike', ['sanchez2'] = 'bike', ['shotaro'] = 'bike', ['thrust'] = 'bike',
        ['vader'] = 'bike', ['vindicator'] = 'bike', ['vortex'] = 'bike', ['zombiea'] = 'bike', ['zombieb'] = 'bike',
        -- Boats
        ['dinghy'] = 'boat', ['dinghy2'] = 'boat', ['dinghy3'] = 'boat', ['dinghy4'] = 'boat', ['jetmax'] = 'boat',
        ['marquis'] = 'boat', ['seashark'] = 'boat', ['seashark2'] = 'boat', ['speashark3'] = 'boat', ['speeder'] = 'boat',
        ['speeder2'] = 'boat', ['squalo'] = 'boat', ['submersible'] = 'submarine', ['submersible2'] = 'submarine',
        ['suntrap'] = 'boat', ['toro'] = 'boat', ['toro2'] = 'boat', ['tropic'] = 'boat', ['tropic2'] = 'boat', ['tug'] = 'boat',
        -- Helicopters
        ['akula'] = 'heli', ['annihilator'] = 'heli', ['buzzard'] = 'heli', ['buzzard2'] = 'heli', ['cargobob'] = 'heli',
        ['frogger'] = 'heli', ['frogger2'] = 'heli', ['havok'] = 'heli', ['hunter'] = 'heli', ['maverick'] = 'heli',
        ['savage'] = 'heli', ['seasparrow'] = 'heli', ['skylift'] = 'heli', ['swift'] = 'heli', ['swift2'] = 'heli',
        ['valkyrie'] = 'heli', ['valkyrie2'] = 'heli', ['volatus'] = 'heli',
        -- Planes
        ['alphaz1'] = 'plane', ['besra'] = 'plane', ['cuban800'] = 'plane', ['dodo'] = 'plane', ['duster'] = 'plane',
        ['hydra'] = 'plane', ['jet'] = 'plane', ['lazer'] = 'plane', ['luxor'] = 'plane', ['luxor2'] = 'plane',
        ['mammatus'] = 'plane', ['miljet'] = 'plane', ['nimbus'] = 'plane', ['shamal'] = 'plane', ['stunt'] = 'plane',
        ['titan'] = 'plane', ['velum'] = 'plane', ['velum2'] = 'plane', ['vestra'] = 'plane',
    }
    return vehicleTypes[model:lower()] or 'automobile'
end

local function SpawnVehicleServerSide(model, coords, heading, plate, citizenid)
    local modelHash = GetHashKey(model)
    local vehicleType = GetVehicleType(model)

    -- Use CreateVehicleServerSetter for proper OneSync server-side spawn
    local vehicle = CreateVehicleServerSetter(modelHash, vehicleType, coords.x, coords.y, coords.z, heading)

    if not vehicle or vehicle == 0 then
        print('[sb_garage] Failed to spawn vehicle server-side: ' .. model)
        return nil, nil
    end

    -- CRITICAL: Set orphan mode to keep entity when owner disconnects
    -- Mode 2 = KeepEntity (vehicle persists even if owner leaves)
    SetEntityOrphanMode(vehicle, 2)

    -- Set plate
    SetVehicleNumberPlateText(vehicle, plate)

    -- Mark as owned immediately so sb_worldcontrol doesn't lock it before client applies props
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', plate, true)

    -- Flag vehicle as hidden — client will read this and hide it before applying props
    Entity(vehicle).state:set('sb_hidden', true, true)

    -- Get network ID
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- Register with sb_impound for persistence tracking
    if GetResourceState('sb_impound') == 'started' then
        exports['sb_impound']:RegisterSpawnedVehicle(plate, citizenid, netId, model, nil)
    end

    print('[sb_garage] Spawned persistent vehicle: ' .. plate .. ' netId: ' .. netId .. ' type: ' .. vehicleType)

    return vehicle, netId
end

-- Find and remove car keys by plate from player's inventory
local function RemoveCarKeysByPlate(source, plate)
    Debug('RemoveCarKeysByPlate: plate=', plate, 'TakeKeysOnStore=', Config.TakeKeysOnStore)
    if not Config.TakeKeysOnStore then return true end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    Debug('RemoveCarKeysByPlate: cleanPlate=', cleanPlate)

    -- Get all car_keys items from player's inventory
    local keys = exports['sb_inventory']:GetItemsByName(source, Config.KeysItem)
    if not keys or #keys == 0 then
        Debug('RemoveCarKeysByPlate: no keys found in inventory')
        return false
    end

    Debug('RemoveCarKeysByPlate: found', #keys, 'key(s) in inventory')
    for _, keyItem in ipairs(keys) do
        if keyItem.metadata and keyItem.metadata.plate then
            local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
            Debug('RemoveCarKeysByPlate: checking key in slot', keyItem.slot, 'keyPlate=', keyPlate)
            if keyPlate == cleanPlate then
                -- Remove the key from this slot
                Debug('RemoveCarKeysByPlate: removing key from slot', keyItem.slot)
                exports['sb_inventory']:RemoveItem(source, Config.KeysItem, 1, keyItem.slot)
                return true
            end
        end
    end

    Debug('RemoveCarKeysByPlate: no matching keys found')
    return false -- No keys found (might have been lost/sold)
end

-- Give car keys to player (only if they don't already have one for this plate)
local function GiveCarKeys(source, plate, vehicle, vehicleLabel)
    Debug('GiveCarKeys: plate=', plate, 'vehicle=', vehicle, 'GiveKeysOnRetrieve=', Config.GiveKeysOnRetrieve)
    if not Config.GiveKeysOnRetrieve then return true end

    -- Check if player already has a key for this plate
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local existingKeys = exports['sb_inventory']:GetItemsByName(source, Config.KeysItem)
    if existingKeys and #existingKeys > 0 then
        for _, keyItem in ipairs(existingKeys) do
            if keyItem.metadata and keyItem.metadata.plate then
                local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                if keyPlate == cleanPlate then
                    Debug('GiveCarKeys: player already has key for', cleanPlate, '- skipping')
                    return true
                end
            end
        end
    end

    local keyMetadata = {
        plate = plate,
        vehicle = vehicle,
        label = vehicleLabel
    }

    local result = exports['sb_inventory']:AddItem(source, Config.KeysItem, 1, keyMetadata)
    Debug('GiveCarKeys: AddItem result=', result)
    return result
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Get vehicles for garage UI
SB.Functions.CreateCallback('sb_garage:getVehicles', function(source, cb, garageId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb({}, {})
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get all stored vehicles for this player
    local vehicles = MySQL.query.await([[
        SELECT id, plate, vehicle, vehicle_label, state, garage, fuel, body, engine, mods
        FROM player_vehicles
        WHERE citizenid = ? AND state = 1
        ORDER BY garage = ? DESC, vehicle_label ASC
    ]], { citizenid, garageId })

    -- Calculate stats
    local thisGarageCount = 0
    local totalStored = 0

    if vehicles then
        for _, veh in ipairs(vehicles) do
            totalStored = totalStored + 1
            if veh.garage == garageId then
                thisGarageCount = thisGarageCount + 1
            end
        end
    end

    local stats = {
        thisGarage = thisGarageCount,
        maxPerGarage = Config.MaxVehiclesPerGarage,
        totalStored = totalStored
    }

    cb(vehicles or {}, stats)
end)

-- Get player money
SB.Functions.CreateCallback('sb_garage:getMoney', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(0, 0)
        return
    end

    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    cb(cash, bank)
end)

-- Store vehicle
SB.Functions.CreateCallback('sb_garage:storeVehicle', function(source, cb, plate, props, garageId)
    Debug('storeVehicle callback: plate=', plate, 'garageId=', garageId)

    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        Debug('storeVehicle: Player not found')
        cb(false, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    Debug('storeVehicle: citizenid=', citizenid)

    -- Check operation lock
    if IsOperationLocked(citizenid) then
        Debug('storeVehicle: operation locked')
        cb(false, 'Please wait...')
        return
    end

    -- Check cooldown
    if not CheckCooldown(citizenid) then
        Debug('storeVehicle: cooldown active')
        cb(false, 'Please wait before storing another vehicle')
        return
    end

    LockOperation(citizenid)

    -- Validate plate
    if not plate or plate == '' then
        Debug('storeVehicle: invalid plate')
        UnlockOperation(citizenid)
        cb(false, 'Invalid vehicle')
        return
    end

    -- Clean plate for comparison (remove all spaces for consistent matching)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    Debug('storeVehicle: cleaned plate=', cleanPlate)

    -- Check if vehicle exists and belongs to player (REPLACE handles DB plates with/without spaces)
    Debug('storeVehicle: querying database...')
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ?', {
        cleanPlate, citizenid
    })

    if not vehicle then
        Debug('storeVehicle: vehicle not found in database')
        UnlockOperation(citizenid)
        cb(false, 'You don\'t own this vehicle')
        return
    end

    -- Use the actual plate from DB for updates
    plate = vehicle.plate
    Debug('storeVehicle: vehicle found, state=', vehicle.state, 'DB plate=', plate)

    -- If database says stored but player has it physically, fix the state first
    -- (This handles state desync from crashes/restarts)
    if vehicle.state == 1 then
        Debug('storeVehicle: DB says stored but vehicle exists physically - fixing state desync')
        MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE REPLACE(plate, " ", "") = ?', { cleanPlate })
        -- Continue with normal store operation
    end

    -- Check garage capacity
    local garageCount = GetGarageVehicleCount(citizenid, garageId)
    Debug('storeVehicle: garage count=', garageCount, 'max=', Config.MaxVehiclesPerGarage)
    if garageCount >= Config.MaxVehiclesPerGarage then
        UnlockOperation(citizenid)
        cb(false, 'This garage is full (' .. Config.MaxVehiclesPerGarage .. '/' .. Config.MaxVehiclesPerGarage .. ')')
        return
    end

    -- Extract values from props
    local fuel = props.fuelLevel or 100
    local body = props.bodyHealth or 1000
    local engine = props.engineHealth or 1000
    local mods = json.encode(props)

    Debug('storeVehicle: fuel=', fuel, 'body=', body, 'engine=', engine)

    -- Update database (use cleanPlate with REPLACE for matching)
    Debug('storeVehicle: updating database...')
    local updated = MySQL.update.await([[
        UPDATE player_vehicles
        SET state = 1, garage = ?, fuel = ?, body = ?, engine = ?, mods = ?
        WHERE REPLACE(plate, ' ', '') = ? AND citizenid = ?
    ]], {
        garageId,
        fuel,
        body,
        engine,
        mods,
        cleanPlate,
        citizenid
    })

    Debug('storeVehicle: update result=', updated)

    if not updated or updated == 0 then
        Debug('storeVehicle: database update failed')
        UnlockOperation(citizenid)
        cb(false, 'Failed to store vehicle')
        return
    end

    -- Remove car keys from inventory (wrapped in pcall to prevent errors)
    Debug('storeVehicle: removing car keys...')
    local keySuccess, keyError = pcall(function()
        RemoveCarKeysByPlate(source, plate)
    end)
    if not keySuccess then
        Debug('storeVehicle: key removal error:', keyError)
    end

    -- Log history
    LogVehicleHistory(plate, 'garage_store', 'Stored at ' .. garageId, citizenid, {
        garage = garageId,
        fuel = fuel,
        body = body,
        engine = engine
    })

    Debug('storeVehicle: SUCCESS')
    UnlockOperation(citizenid)
    cb(true, 'Vehicle stored')
end)

-- Retrieve vehicle
SB.Functions.CreateCallback('sb_garage:retrieveVehicle', function(source, cb, plate, garageId)
    Debug('retrieveVehicle callback: plate=', plate, 'garageId=', garageId)

    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        Debug('retrieveVehicle: Player not found')
        cb(false, nil, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    Debug('retrieveVehicle: citizenid=', citizenid)

    -- Check operation lock
    if IsOperationLocked(citizenid) then
        Debug('retrieveVehicle: operation locked')
        cb(false, nil, 'Please wait...')
        return
    end

    -- Check cooldown
    if not CheckCooldown(citizenid) then
        Debug('retrieveVehicle: cooldown active')
        cb(false, nil, 'Please wait before retrieving another vehicle')
        return
    end

    LockOperation(citizenid)

    -- Validate plate
    if not plate or plate == '' then
        Debug('retrieveVehicle: invalid plate')
        UnlockOperation(citizenid)
        cb(false, nil, 'Invalid vehicle')
        return
    end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    Debug('retrieveVehicle: cleaned plate=', cleanPlate)

    -- Get vehicle from database (REPLACE handles DB plates with/without spaces)
    Debug('retrieveVehicle: querying database...')
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ?', {
        cleanPlate, citizenid
    })

    if not vehicle then
        Debug('retrieveVehicle: vehicle not found')
        UnlockOperation(citizenid)
        cb(false, nil, 'You don\'t own this vehicle')
        return
    end

    Debug('retrieveVehicle: vehicle found, state=', vehicle.state, 'garage=', vehicle.garage)

    -- Check if vehicle is stored
    if vehicle.state ~= 1 then
        Debug('retrieveVehicle: vehicle not stored (state != 1)')
        UnlockOperation(citizenid)
        cb(false, nil, 'Vehicle is not stored')
        return
    end

    -- Check if transfer fee applies (different garage)
    local needsTransfer = vehicle.garage ~= garageId
    local transferFee = needsTransfer and Config.TransferFee or 0
    Debug('retrieveVehicle: needsTransfer=', needsTransfer, 'transferFee=', transferFee)

    if needsTransfer then
        local cash = Player.PlayerData.money.cash or 0
        local bank = Player.PlayerData.money.bank or 0
        Debug('retrieveVehicle: cash=', cash, 'bank=', bank)

        if cash < transferFee and bank < transferFee then
            Debug('retrieveVehicle: not enough money for transfer')
            UnlockOperation(citizenid)
            cb(false, nil, 'Not enough money for transfer fee ($' .. transferFee .. ')')
            return
        end

        -- Deduct transfer fee (cash first)
        if cash >= transferFee then
            Player.Functions.RemoveMoney('cash', transferFee, 'garage-transfer')
            Debug('retrieveVehicle: deducted from cash')
        else
            Player.Functions.RemoveMoney('bank', transferFee, 'garage-transfer')
            Debug('retrieveVehicle: deducted from bank')
        end
    end

    -- Update database - mark as out (use cleanPlate with REPLACE)
    Debug('retrieveVehicle: updating database...')
    local updated = MySQL.update.await([[
        UPDATE player_vehicles
        SET state = 0
        WHERE REPLACE(plate, ' ', '') = ? AND citizenid = ?
    ]], {
        cleanPlate,
        citizenid
    })

    Debug('retrieveVehicle: update result=', updated)

    if not updated or updated == 0 then
        Debug('retrieveVehicle: database update failed')
        -- Refund if we charged
        if needsTransfer then
            Player.Functions.AddMoney('cash', transferFee, 'garage-transfer-refund')
        end
        UnlockOperation(citizenid)
        cb(false, nil, 'Failed to retrieve vehicle')
        return
    end

    -- Give car keys back to player
    Debug('retrieveVehicle: giving car keys...')
    GiveCarKeys(source, vehicle.plate, vehicle.vehicle, vehicle.vehicle_label)

    -- Log history
    LogVehicleHistory(plate, 'garage_retrieve', 'Retrieved from ' .. garageId, citizenid, {
        garage = garageId,
        originalGarage = vehicle.garage,
        transferFee = transferFee
    })

    Debug('retrieveVehicle: SUCCESS')
    UnlockOperation(citizenid)

    -- Return vehicle data - client will request server spawn with coords
    cb(true, {
        plate = vehicle.plate,
        vehicle = vehicle.vehicle,
        vehicle_label = vehicle.vehicle_label,
        fuel = vehicle.fuel,
        body = vehicle.body,
        engine = vehicle.engine,
        mods = vehicle.mods
    }, needsTransfer and ('Vehicle transferred. Fee: $' .. transferFee) or nil)
end)

-- ============================================================================
-- SERVER-SIDE VEHICLE DELETION (for stored vehicles)
-- ============================================================================

RegisterNetEvent('sb_garage:server:deleteStoredVehicle', function(netId, plate)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Verify the vehicle is actually stored in DB (prevent abuse)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local vehicle = MySQL.single.await('SELECT state FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ? AND state = 1', {
        cleanPlate, Player.PlayerData.citizenid
    })

    if not vehicle then
        Debug('deleteStoredVehicle: vehicle not stored or not owned, ignoring')
        return
    end

    -- Delete the entity server-side
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
        Debug('deleteStoredVehicle: deleted entity for plate', plate, 'netId', netId)
    else
        Debug('deleteStoredVehicle: entity not found for netId', netId, '- may already be gone')
    end
end)

-- ============================================================================
-- SERVER-SIDE SPAWN REQUEST (client sends spawn coords after retrieve)
-- ============================================================================

RegisterNetEvent('sb_garage:server:spawnVehicle', function(vehicleData, coords, heading)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Verify this is the player's vehicle (REPLACE handles DB plates with/without spaces)
    local cleanPlate = vehicleData.plate:gsub('%s+', ''):upper()
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ? AND state = 0', {
        cleanPlate, citizenid
    })

    if not vehicle then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle not found', 'error', 3000)
        return
    end

    -- Spawn vehicle server-side
    local spawnedVehicle, netId = SpawnVehicleServerSide(
        vehicleData.vehicle,
        coords,
        heading,
        vehicleData.plate,
        citizenid
    )

    if not spawnedVehicle or not netId then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Failed to spawn vehicle', 'error', 3000)
        return
    end

    -- Tell client to apply properties to this vehicle
    TriggerClientEvent('sb_garage:client:applyVehicleProperties', src, netId, vehicleData)
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        UnlockOperation(citizenid)
        lastOperations[citizenid] = nil
    end
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Fix vehicle state (for stuck/desynced vehicles)
RegisterCommand('fixvehicle', function(source, args, rawCommand)
    local src = source

    -- Admin check
    if src > 0 then
        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            TriggerClientEvent('SB:Client:Notify', src, 'No permission!', 'error')
            return
        end
    end

    local plate = args[1]
    local newState = tonumber(args[2])

    if not plate then
        local msg = 'Usage: /fixvehicle [plate] [state: 0=out, 1=stored]'
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, msg, 'error')
        else
            print(msg)
        end
        return
    end

    -- Default to state 0 (out) if not specified
    if newState == nil then newState = 0 end

    plate = plate:upper()

    local updated = MySQL.update.await('UPDATE player_vehicles SET state = ? WHERE plate LIKE ?', {
        newState, '%' .. plate .. '%'
    })

    local msg = 'Updated ' .. updated .. ' vehicle(s) matching "' .. plate .. '" to state ' .. newState
    if src > 0 then
        TriggerClientEvent('SB:Client:Notify', src, msg, 'success')
    end
    print('[sb_garage] ' .. msg)
end, false)

-- Give keys for a vehicle
RegisterCommand('givekeys', function(source, args, rawCommand)
    local src = source

    -- Admin check
    if src > 0 then
        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            TriggerClientEvent('SB:Client:Notify', src, 'No permission!', 'error')
            return
        end
    end

    local targetId = tonumber(args[1])
    local plate = args[2]

    if not targetId or not plate then
        local msg = 'Usage: /givekeys [playerid] [plate]'
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, msg, 'error')
        else
            print(msg)
        end
        return
    end

    plate = plate:upper()

    -- Get vehicle info from database
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE plate LIKE ?', { '%' .. plate .. '%' })

    if not vehicle then
        local msg = 'No vehicle found with plate: ' .. plate
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, msg, 'error')
        else
            print(msg)
        end
        return
    end

    -- Give keys
    local keyMetadata = {
        plate = vehicle.plate,
        vehicle = vehicle.vehicle,
        label = vehicle.vehicle_label
    }

    exports['sb_inventory']:AddItem(targetId, Config.KeysItem, 1, keyMetadata)

    local msg = 'Gave keys for ' .. vehicle.plate .. ' to player ' .. targetId
    if src > 0 then
        TriggerClientEvent('SB:Client:Notify', src, msg, 'success')
    end
    print('[sb_garage] ' .. msg)
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetPlayerVehicles', function(citizenid, garageId)
    local query = 'SELECT * FROM player_vehicles WHERE citizenid = ?'
    local params = { citizenid }

    if garageId then
        query = query .. ' AND garage = ? AND state = 1'
        params[#params + 1] = garageId
    end

    local result = MySQL.query.await(query, params)
    return result or {}
end)

exports('GetStoredVehicles', function(citizenid)
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = 1', { citizenid })
    return result or {}
end)

exports('IsVehicleStored', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local result = MySQL.scalar.await('SELECT state FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { cleanPlate })
    return result == 1
end)

exports('SetVehicleState', function(plate, state, garageId)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local params = { state, cleanPlate }
    local query = 'UPDATE player_vehicles SET state = ?'

    if garageId then
        query = query .. ', garage = ?'
        table.insert(params, 2, garageId)
    end

    query = query .. ' WHERE REPLACE(plate, " ", "") = ?'

    local updated = MySQL.update.await(query, params)
    return updated > 0
end)

print('^2[sb_garage]^7 Garage system loaded')
