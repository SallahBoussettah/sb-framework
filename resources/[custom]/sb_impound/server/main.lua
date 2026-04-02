--[[
    Everyday Chaos RP - Impound System (Server)
    Author: Salah Eddine Boussettah

    Handles: Impound/retrieve logic, fees, key removal
]]

local SBCore = exports['sb_core']:GetCoreObject()
local operationLocks = {}

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SBCore = exports['sb_core']:GetCoreObject()
    end
end)

print('^2[sb_impound]^7 Impound System loaded')

-- ============================================================================
-- IMPOUND VEHICLE (called by persistence or admin)
-- ============================================================================

function ImpoundVehicle(plate, reason, impoundLocation, vehicleProps, isDestroyed)
    if not plate then return false end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    impoundLocation = impoundLocation or 'lspd'
    isDestroyed = isDestroyed or false

    -- Get vehicle data (REPLACE handles plates stored with or without spaces)
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { cleanPlate })
    if not vehicle then
        print('[sb_impound] Vehicle not found in database: ' .. cleanPlate)
        return false
    end

    -- Update state to impounded (2) or destroyed (3)
    local newState = isDestroyed and 3 or 2

    MySQL.update.await([[
        UPDATE player_vehicles
        SET state = ?, garage = ?, impound_reason = ?, impound_time = NOW()
        WHERE REPLACE(plate, ' ', '') = ?
    ]], { newState, impoundLocation, reason or 'Auto-impound', cleanPlate })

    -- Save vehicle properties if provided
    if vehicleProps then
        MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE REPLACE(plate, " ", "") = ?', {
            json.encode(vehicleProps), cleanPlate
        })
    end

    -- Remove keys from owner's inventory
    RemoveVehicleKeys(vehicle.citizenid, cleanPlate)

    print('[sb_impound] Impounded vehicle: ' .. cleanPlate .. ' | Reason: ' .. (reason or 'Auto-impound') .. ' | Location: ' .. impoundLocation)

    return true
end

-- ============================================================================
-- REMOVE KEYS FROM PLAYER
-- ============================================================================

function RemoveVehicleKeys(citizenid, plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Try to find online player first
    local Player = SBCore.Functions.GetPlayerByCitizenId(citizenid)

    if Player then
        -- Player is online - remove from their inventory
        local src = Player.PlayerData.source
        local keys = exports['sb_inventory']:GetItemsByName(src, 'car_keys')
        local keysRemoved = false

        if keys and #keys > 0 then
            for _, keyItem in ipairs(keys) do
                if keyItem.metadata and keyItem.metadata.plate then
                    local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                    if keyPlate == cleanPlate then
                        exports['sb_inventory']:RemoveItem(src, 'car_keys', 1, keyItem.slot)
                        keysRemoved = true
                        print('[sb_impound] Removed keys for ' .. cleanPlate .. ' from player ' .. citizenid)
                        break
                    end
                end
            end
        end

        -- Always notify player their keys were confiscated
        TriggerClientEvent('sb_notify:client:Notify', src, 'Your vehicle keys were confiscated', 'warning', 5000)

        if not keysRemoved then
            print('[sb_impound] No keys found for ' .. cleanPlate .. ' in player inventory')
        end
    else
        -- Player is offline - store flag to remove keys when they log in
        MySQL.insert.await([[
            INSERT INTO impound_key_removals (citizenid, plate) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE plate = ?
        ]], { citizenid, cleanPlate, cleanPlate })
        print('[sb_impound] Player offline, queued key removal for ' .. cleanPlate)
    end
end

-- ============================================================================
-- CHECK PENDING KEY REMOVALS ON LOGIN
-- ============================================================================

AddEventHandler('SB:Server:OnPlayerLoaded', function(src, PlayerObj)
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Check for pending key removals
    local pending = MySQL.query.await('SELECT plate FROM impound_key_removals WHERE citizenid = ?', { citizenid })

    if pending and #pending > 0 then
        Wait(2000) -- Wait for inventory to load

        for _, row in ipairs(pending) do
            local cleanPlate = row.plate:gsub('%s+', ''):upper()
            local keys = exports['sb_inventory']:GetItemsByName(src, 'car_keys')

            if keys then
                for _, keyItem in ipairs(keys) do
                    if keyItem.metadata and keyItem.metadata.plate then
                        local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                        if keyPlate == cleanPlate then
                            exports['sb_inventory']:RemoveItem(src, 'car_keys', 1, keyItem.slot)
                            break
                        end
                    end
                end
            end
        end

        -- Clear pending removals
        MySQL.query.await('DELETE FROM impound_key_removals WHERE citizenid = ?', { citizenid })

        if #pending > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Some vehicle keys were confiscated while you were away', 'warning', 5000)
        end
    end
end)

-- ============================================================================
-- GET IMPOUNDED VEHICLES
-- ============================================================================

SBCore.Functions.CreateCallback('sb_impound:server:getImpoundedVehicles', function(source, cb, locationId)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get vehicles impounded at this location (state 2 or 3)
    local vehicles = MySQL.query.await([[
        SELECT plate, vehicle, vehicle_label, state, garage as impound_location,
               impound_reason, impound_time, fuel, body, engine
        FROM player_vehicles
        WHERE citizenid = ? AND state IN (2, 3) AND garage = ?
    ]], { citizenid, locationId })

    if not vehicles then
        cb({})
        return
    end

    -- Calculate fees for each vehicle
    local now = os.time()
    for _, veh in ipairs(vehicles) do
        local baseFee = Config.ImpoundFee
        local destroyedFee = (veh.state == 3) and Config.DestroyedFee or 0

        -- Calculate storage fee based on time
        local storageFee = 0
        if veh.impound_time then
            local impoundTimestamp = ParseDateTime(veh.impound_time)
            local hoursStored = math.floor((now - impoundTimestamp) / 3600)
            storageFee = math.min(hoursStored * Config.DailyStorageFee, Config.MaxStorageHours * Config.DailyStorageFee)
        end

        veh.baseFee = baseFee
        veh.destroyedFee = destroyedFee
        veh.storageFee = storageFee
        veh.totalFee = baseFee + destroyedFee + storageFee
        veh.isDestroyed = (veh.state == 3)
    end

    cb(vehicles)
end)

-- ============================================================================
-- RETRIEVE VEHICLE FROM IMPOUND
-- ============================================================================

SBCore.Functions.CreateCallback('sb_impound:server:retrieveVehicle', function(source, cb, plate, locationId)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Check lock
    if operationLocks[citizenid] then
        cb(false, 'Please wait...')
        return
    end
    operationLocks[citizenid] = true

    -- Clean plate (NUI may send raw plate with spaces)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Get vehicle (REPLACE handles plates stored with/without spaces)
    local vehicle = MySQL.single.await([[
        SELECT * FROM player_vehicles
        WHERE REPLACE(plate, ' ', '') = ? AND citizenid = ? AND state IN (2, 3) AND garage = ?
    ]], { cleanPlate, citizenid, locationId })

    if not vehicle then
        operationLocks[citizenid] = nil
        cb(false, 'Vehicle not found')
        return
    end

    -- Calculate fee
    local baseFee = Config.ImpoundFee
    local destroyedFee = (vehicle.state == 3) and Config.DestroyedFee or 0
    local storageFee = 0

    if vehicle.impound_time then
        local impoundTimestamp = ParseDateTime(vehicle.impound_time)
        local hoursStored = math.floor((os.time() - impoundTimestamp) / 3600)
        storageFee = math.min(hoursStored * Config.DailyStorageFee, Config.MaxStorageHours * Config.DailyStorageFee)
    end

    local totalFee = baseFee + destroyedFee + storageFee

    -- Check money
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0

    if cash + bank < totalFee then
        operationLocks[citizenid] = nil
        cb(false, 'Not enough money. Need $' .. totalFee)
        return
    end

    -- Deduct money (cash first)
    local paidFromBank = 0
    if cash >= totalFee then
        Player.Functions.RemoveMoney('cash', totalFee, 'impound-fee')
    else
        if cash > 0 then
            Player.Functions.RemoveMoney('cash', cash, 'impound-fee')
        end
        local remaining = totalFee - cash
        Player.Functions.RemoveMoney('bank', remaining, 'impound-fee')
        paidFromBank = remaining
    end

    -- Log bank transaction
    if paidFromBank > 0 then
        local balanceAfter = Player.Functions.GetMoney('bank')
        exports['sb_banking']:LogPurchase(citizenid, paidFromBank, balanceAfter, 'Impound Fee - ' .. (vehicle.vehicle_label or vehicle.vehicle))
    end

    -- Update vehicle state to out (0)
    MySQL.update.await([[
        UPDATE player_vehicles
        SET state = 0, garage = 'none', impound_reason = NULL, impound_time = NULL
        WHERE REPLACE(plate, ' ', '') = ?
    ]], { cleanPlate })

    -- Give keys back (only if player doesn't already have one for this plate)
    local alreadyHasKey = false
    local existingKeys = exports['sb_inventory']:GetItemsByName(source, 'car_keys')
    if existingKeys and #existingKeys > 0 then
        for _, keyItem in ipairs(existingKeys) do
            if keyItem.metadata and keyItem.metadata.plate then
                local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                if keyPlate == cleanPlate then
                    alreadyHasKey = true
                    break
                end
            end
        end
    end

    if alreadyHasKey then
        print('[sb_impound] Player already has keys for ' .. plate .. ', skipping duplicate')
    else
        local keyMetadata = {
            plate = vehicle.plate,
            vehicle = vehicle.vehicle,
            label = vehicle.vehicle_label or vehicle.vehicle
        }
        local keysGiven = exports['sb_inventory']:AddItem(source, 'car_keys', 1, keyMetadata)

        if keysGiven then
            print('[sb_impound] Gave keys for ' .. plate .. ' to player ' .. citizenid)
            TriggerClientEvent('sb_notify:client:Notify', source, 'You received your vehicle keys', 'info', 3000)
        else
            print('[sb_impound] Failed to give keys for ' .. plate .. ' - inventory full?')
            TriggerClientEvent('sb_notify:client:Notify', source, 'Could not give keys - check your inventory!', 'warning', 5000)
        end
    end

    operationLocks[citizenid] = nil

    -- Return vehicle data - client will request server spawn with coords
    cb(true, {
        model = vehicle.vehicle,
        plate = vehicle.plate,
        label = vehicle.vehicle_label,
        props = vehicle.mods and json.decode(vehicle.mods) or nil,
        fuel = vehicle.fuel or 100,
        body = vehicle.body or 1000,
        engine = vehicle.engine or 1000,
        fee = totalFee
    })
end)

-- ============================================================================
-- SERVER-SIDE VEHICLE SPAWN (OneSync persistent - for impound retrieval)
-- ============================================================================

-- Get vehicle type for CreateVehicleServerSetter
local function GetVehicleType(model)
    local vehicleTypes = {
        -- Bikes
        ['bmx'] = 'bike', ['cruiser'] = 'bike', ['fixter'] = 'bike', ['scorcher'] = 'bike', ['tribike'] = 'bike',
        -- Motorcycles
        ['akuma'] = 'bike', ['bagger'] = 'bike', ['bati'] = 'bike', ['bati2'] = 'bike',
        ['daemon'] = 'bike', ['daemon2'] = 'bike', ['double'] = 'bike', ['enduro'] = 'bike',
        ['faggio'] = 'bike', ['faggio2'] = 'bike', ['faggio3'] = 'bike', ['fcr'] = 'bike',
        ['hakuchou'] = 'bike', ['hakuchou2'] = 'bike', ['hexer'] = 'bike',
        ['nemesis'] = 'bike', ['nightblade'] = 'bike', ['oppressor'] = 'bike', ['oppressor2'] = 'bike',
        ['pcj'] = 'bike', ['sanchez'] = 'bike', ['sanchez2'] = 'bike', ['shotaro'] = 'bike',
        ['vader'] = 'bike', ['vindicator'] = 'bike', ['zombiea'] = 'bike', ['zombieb'] = 'bike',
        -- Boats
        ['dinghy'] = 'boat', ['dinghy2'] = 'boat', ['jetmax'] = 'boat', ['marquis'] = 'boat',
        ['seashark'] = 'boat', ['seashark2'] = 'boat', ['speeder'] = 'boat', ['squalo'] = 'boat',
        ['submersible'] = 'submarine', ['submersible2'] = 'submarine', ['toro'] = 'boat', ['tropic'] = 'boat',
        -- Helicopters
        ['buzzard'] = 'heli', ['buzzard2'] = 'heli', ['cargobob'] = 'heli', ['frogger'] = 'heli',
        ['maverick'] = 'heli', ['savage'] = 'heli', ['skylift'] = 'heli', ['swift'] = 'heli', ['swift2'] = 'heli',
        -- Planes
        ['besra'] = 'plane', ['cuban800'] = 'plane', ['dodo'] = 'plane', ['duster'] = 'plane',
        ['hydra'] = 'plane', ['jet'] = 'plane', ['lazer'] = 'plane', ['luxor'] = 'plane', ['luxor2'] = 'plane',
        ['mammatus'] = 'plane', ['miljet'] = 'plane', ['shamal'] = 'plane', ['titan'] = 'plane',
        ['velum'] = 'plane', ['velum2'] = 'plane', ['vestra'] = 'plane',
    }
    return vehicleTypes[model:lower()] or 'automobile'
end

local function SpawnVehicleServerSide(model, coords, heading, plate, citizenid)
    local modelHash = GetHashKey(model)
    local vehicleType = GetVehicleType(model)

    -- Use CreateVehicleServerSetter for proper OneSync server-side spawn
    local vehicle = CreateVehicleServerSetter(modelHash, vehicleType, coords.x, coords.y, coords.z, heading)

    if not vehicle or vehicle == 0 then
        print('[sb_impound] Failed to spawn vehicle server-side: ' .. model)
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

    -- Register with persistence tracking
    exports['sb_impound']:RegisterSpawnedVehicle(plate, citizenid, netId, model, nil)

    print('[sb_impound] Spawned persistent vehicle: ' .. plate .. ' netId: ' .. netId .. ' type: ' .. vehicleType)

    return vehicle, netId
end

RegisterNetEvent('sb_impound:server:spawnRetrievedVehicle', function(vehicleData, coords, heading)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Verify this is the player's vehicle and state is 0 (just retrieved)
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
        vehicleData.model,
        coords,
        heading,
        vehicleData.plate,
        citizenid
    )

    if not spawnedVehicle or not netId then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Failed to spawn vehicle', 'error', 3000)
        return
    end

    -- Tell client to apply properties
    TriggerClientEvent('sb_impound:client:setupRetrievedVehicle', src, netId, vehicleData)
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

function ParseDateTime(dateStr)
    if not dateStr then return os.time() end

    if type(dateStr) == 'number' then
        if dateStr > 1000000000000 then
            return math.floor(dateStr / 1000)
        end
        return dateStr
    end

    if type(dateStr) ~= 'string' then
        dateStr = tostring(dateStr)
    end

    local pattern = '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)'
    local year, month, day, hour, min, sec = dateStr:match(pattern)

    if year then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end

    return os.time()
end

-- ============================================================================
-- DATABASE SETUP
-- ============================================================================

MySQL.ready(function()
    -- Add impound columns to player_vehicles if not exists
    MySQL.query([[
        ALTER TABLE player_vehicles
        ADD COLUMN IF NOT EXISTS impound_reason VARCHAR(255) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS impound_time TIMESTAMP NULL DEFAULT NULL
    ]])

    -- Create key removal tracking table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS impound_key_removals (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            plate VARCHAR(20) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_removal (citizenid, plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    print('[sb_impound] Database tables ready')
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ImpoundVehicle', ImpoundVehicle)
exports('RemoveVehicleKeys', RemoveVehicleKeys)

exports('IsVehicleImpounded', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local result = MySQL.scalar.await('SELECT state FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { cleanPlate })
    return result == 2 or result == 3
end)

exports('GetImpoundedVehicles', function(citizenid)
    return MySQL.query.await([[
        SELECT * FROM player_vehicles WHERE citizenid = ? AND state IN (2, 3)
    ]], { citizenid })
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

-- Player command: /impoundmycar - Send your own vehicle to impound
RegisterCommand('impoundmycar', function(source, args)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Request client to find and send their nearby vehicle
    TriggerClientEvent('sb_impound:client:impoundOwnVehicle', src)
end, false)

-- Admin command: /impound [plate] [destroyed] - Impound any vehicle
RegisterCommand('impound', function(source, args)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)

    -- Check admin permission
    if src > 0 then -- Not console
        if not Player then return end
        local isAdmin = SBCore.Functions.HasPermission(src, 'admin') or SBCore.Functions.HasPermission(src, 'god')
        if not isAdmin then
            TriggerClientEvent('sb_notify:client:Notify', src, 'You do not have permission', 'error', 3000)
            return
        end
    end

    if not args[1] then
        if src > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Usage: /impound [plate] [destroyed]', 'error', 3000)
        else
            print('[sb_impound] Usage: impound [plate] [destroyed]')
        end
        return
    end

    local plate = args[1]:upper():gsub('%s+', '')
    local isDestroyed = args[2] and (args[2]:lower() == 'true' or args[2] == '1' or args[2]:lower() == 'destroyed')

    -- Check if vehicle exists in database
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
    if not vehicle then
        if src > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle not found in database: ' .. plate, 'error', 3000)
        else
            print('[sb_impound] Vehicle not found: ' .. plate)
        end
        return
    end

    -- Check if already impounded
    if vehicle.state == 2 or vehicle.state == 3 then
        if src > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle is already impounded', 'error', 3000)
        else
            print('[sb_impound] Vehicle already impounded: ' .. plate)
        end
        return
    end

    -- Impound the vehicle
    local reason = isDestroyed and 'Admin impound (destroyed)' or 'Admin impound'
    local success = ImpoundVehicle(plate, reason, 'lspd', nil, isDestroyed)

    if success then
        -- Delete from world (server-side first, then client fallback)
        DeleteVehicleFromWorld(plate, nil)

        if src > 0 then
            local stateText = isDestroyed and 'impounded as DESTROYED' or 'impounded'
            TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle ' .. plate .. ' ' .. stateText, 'success', 5000)
        end
        print('[sb_impound] Admin impounded vehicle: ' .. plate .. (isDestroyed and ' (destroyed)' or ''))
    else
        if src > 0 then
            TriggerClientEvent('sb_notify:client:Notify', src, 'Failed to impound vehicle', 'error', 3000)
        end
    end
end, false)

-- Chat suggestions
TriggerEvent('chat:addSuggestion', '/impoundmycar', 'Send your destroyed vehicle to impound (only works if engine is dead)')
TriggerEvent('chat:addSuggestion', '/impound', 'Admin: Impound a vehicle by plate', {
    { name = 'plate', help = 'Vehicle plate (no spaces)' },
    { name = 'destroyed', help = 'Optional: true/false - mark as destroyed' }
})

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if Player then
        operationLocks[Player.PlayerData.citizenid] = nil
    end
end)
