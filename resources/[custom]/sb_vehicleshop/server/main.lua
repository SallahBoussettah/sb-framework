--[[
    Everyday Chaos RP - Vehicle Shop System (Server)
    Author: Salah Eddine Boussettah

    Handles: License verification, purchase processing, plate generation, vehicle registration
]]

local SB = exports['sb_core']:GetCoreObject()

-- Operation lock to prevent double processing
local operationLocks = {}

-- Active test drives
local activeTestDrives = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Generate unique plate
local function GeneratePlate()
    local letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    local plate = ''

    for i = 1, #Config.PlateFormat do
        local char = Config.PlateFormat:sub(i, i)
        if char == 'X' then
            local idx = math.random(1, #letters)
            plate = plate .. letters:sub(idx, idx)
        elseif char == '0' then
            plate = plate .. tostring(math.random(0, 9))
        else
            plate = plate .. char
        end
    end

    -- Add prefix if configured
    if Config.PlatePrefix and Config.PlatePrefix ~= '' then
        plate = Config.PlatePrefix .. plate
    end

    return plate:sub(1, 8) -- Max 8 characters
end

-- Check if plate exists
local function PlateExists(plate)
    local result = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE plate = ?', { plate })
    return result > 0
end

-- Get unique plate (retry if exists)
local function GetUniquePlate()
    local plate
    local attempts = 0

    repeat
        plate = GeneratePlate()
        attempts = attempts + 1
    until not PlateExists(plate) or attempts > 100

    if attempts > 100 then
        print('[sb_vehicleshop] WARNING: Could not generate unique plate after 100 attempts')
        return nil
    end

    return plate
end

-- Log vehicle history event
local function LogVehicleHistory(plate, eventType, description, actorCitizenid, metadata)
    MySQL.insert('INSERT INTO vehicle_history (plate, event_type, description, actor_citizenid, metadata) VALUES (?, ?, ?, ?, ?)', {
        plate,
        eventType,
        description,
        actorCitizenid,
        metadata and json.encode(metadata) or nil
    })
end

-- ============================================================================
-- SERVER-SIDE VEHICLE SPAWN (OneSync persistent)
-- ============================================================================

-- Get vehicle type for CreateVehicleServerSetter
local function GetVehicleType(model)
    -- Default vehicle types based on common categories
    local vehicleTypes = {
        -- Bikes
        ['bmx'] = 'bike', ['cruiser'] = 'bike', ['fixter'] = 'bike', ['scorcher'] = 'bike', ['tribike'] = 'bike', ['tribike2'] = 'bike', ['tribike3'] = 'bike',
        -- Motorcycles
        ['akuma'] = 'bike', ['avarus'] = 'bike', ['bagger'] = 'bike', ['bati'] = 'bike', ['bati2'] = 'bike', ['bf400'] = 'bike',
        ['carbonrs'] = 'bike', ['cliffhanger'] = 'bike', ['daemon'] = 'bike', ['daemon2'] = 'bike', ['defiler'] = 'bike',
        ['diablous'] = 'bike', ['diablous2'] = 'bike', ['double'] = 'bike', ['enduro'] = 'bike', ['esskey'] = 'bike',
        ['faggio'] = 'bike', ['faggio2'] = 'bike', ['faggio3'] = 'bike', ['fcr'] = 'bike', ['fcr2'] = 'bike',
        ['gargoyle'] = 'bike', ['hakuchou'] = 'bike', ['hakuchou2'] = 'bike', ['hexer'] = 'bike', ['innovation'] = 'bike',
        ['lectro'] = 'bike', ['manchez'] = 'bike', ['nemesis'] = 'bike', ['nightblade'] = 'bike', ['oppressor'] = 'bike',
        ['oppressor2'] = 'bike', ['pcj'] = 'bike', ['ratbike'] = 'bike', ['ruffian'] = 'bike', ['sanchez'] = 'bike',
        ['sanchez2'] = 'bike', ['sanctus'] = 'bike', ['shotaro'] = 'bike', ['sovereign'] = 'bike', ['thrust'] = 'bike',
        ['vader'] = 'bike', ['vindicator'] = 'bike', ['vortex'] = 'bike', ['wolfsbane'] = 'bike', ['zombiea'] = 'bike', ['zombieb'] = 'bike',
        -- Boats
        ['dinghy'] = 'boat', ['dinghy2'] = 'boat', ['dinghy3'] = 'boat', ['dinghy4'] = 'boat', ['jetmax'] = 'boat',
        ['marquis'] = 'boat', ['seashark'] = 'boat', ['seashark2'] = 'boat', ['seashark3'] = 'boat', ['speeder'] = 'boat',
        ['speeder2'] = 'boat', ['squalo'] = 'boat', ['submersible'] = 'submarine', ['submersible2'] = 'submarine',
        ['suntrap'] = 'boat', ['toro'] = 'boat', ['toro2'] = 'boat', ['tropic'] = 'boat', ['tropic2'] = 'boat', ['tug'] = 'boat',
        -- Helicopters
        ['akula'] = 'heli', ['annihilator'] = 'heli', ['buzzard'] = 'heli', ['buzzard2'] = 'heli', ['cargobob'] = 'heli',
        ['cargobob2'] = 'heli', ['cargobob3'] = 'heli', ['cargobob4'] = 'heli', ['frogger'] = 'heli', ['frogger2'] = 'heli',
        ['havok'] = 'heli', ['hunter'] = 'heli', ['maverick'] = 'heli', ['polmav'] = 'heli', ['savage'] = 'heli',
        ['seasparrow'] = 'heli', ['skylift'] = 'heli', ['supervolito'] = 'heli', ['supervolito2'] = 'heli', ['swift'] = 'heli',
        ['swift2'] = 'heli', ['valkyrie'] = 'heli', ['valkyrie2'] = 'heli', ['volatus'] = 'heli',
        -- Planes
        ['alphaz1'] = 'plane', ['avenger'] = 'plane', ['avenger2'] = 'plane', ['besra'] = 'plane', ['blimp'] = 'plane',
        ['blimp2'] = 'plane', ['blimp3'] = 'plane', ['bombushka'] = 'plane', ['cargoplane'] = 'plane', ['cuban800'] = 'plane',
        ['dodo'] = 'plane', ['duster'] = 'plane', ['howard'] = 'plane', ['hydra'] = 'plane', ['jet'] = 'plane',
        ['lazer'] = 'plane', ['luxor'] = 'plane', ['luxor2'] = 'plane', ['mammatus'] = 'plane', ['microlight'] = 'plane',
        ['miljet'] = 'plane', ['mogul'] = 'plane', ['molotok'] = 'plane', ['nimbus'] = 'plane', ['nokota'] = 'plane',
        ['pyro'] = 'plane', ['rogue'] = 'plane', ['seabreeze'] = 'plane', ['shamal'] = 'plane', ['starling'] = 'plane',
        ['strikeforce'] = 'plane', ['stunt'] = 'plane', ['titan'] = 'plane', ['tula'] = 'plane', ['velum'] = 'plane', ['velum2'] = 'plane', ['vestra'] = 'plane', ['volatol'] = 'plane',
    }
    return vehicleTypes[model:lower()] or 'automobile'
end

-- Spawn vehicle server-side with persistence
local function SpawnPersistentVehicle(model, coords, heading, plate, citizenid)
    local modelHash = GetHashKey(model)
    local vehicleType = GetVehicleType(model)

    -- Use CreateVehicleServerSetter for proper OneSync server-side spawn
    local vehicle = CreateVehicleServerSetter(modelHash, vehicleType, coords.x, coords.y, coords.z, heading)

    if not vehicle or vehicle == 0 then
        print('[sb_vehicleshop] Failed to spawn vehicle: ' .. model)
        return nil, nil
    end

    -- CRITICAL: Set orphan mode to keep entity when owner disconnects
    -- Mode 2 = KeepEntity (vehicle persists even if owner leaves)
    SetEntityOrphanMode(vehicle, 2)

    -- Set the plate
    SetVehicleNumberPlateText(vehicle, plate)

    -- Get network ID for client sync
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- Register with sb_impound for tracking
    if GetResourceState('sb_impound') == 'started' then
        exports['sb_impound']:RegisterSpawnedVehicle(plate, citizenid, netId, model, nil)
    end

    print('[sb_vehicleshop] Spawned persistent vehicle: ' .. plate .. ' netId: ' .. netId .. ' type: ' .. vehicleType)

    return vehicle, netId
end

-- ============================================================================
-- VEHICLE REGISTRATION (for persistence tracking)
-- ============================================================================

-- Register a vehicle that was spawned by client (fallback/legacy)
RegisterNetEvent('sb_vehicleshop:server:registerPurchasedVehicle', function(plate, netId, model)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Register with sb_impound for persistence tracking
    if GetResourceState('sb_impound') == 'started' then
        exports['sb_impound']:RegisterSpawnedVehicle(plate, citizenid, netId, model, nil)
    end

    print('[sb_vehicleshop] Registered purchased vehicle: ' .. plate .. ' netId: ' .. tostring(netId))
end)

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Check if player has driver's license
SB.Functions.CreateCallback('sb_vehicleshop:hasLicense', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    if not Config.RequireLicense then
        cb(true)
        return
    end

    -- Check inventory for license
    local hasLicense = exports['sb_inventory']:HasItem(source, Config.LicenseItem, 1)
    cb(hasLicense)
end)

-- Get vehicles available at a dealership
SB.Functions.CreateCallback('sb_vehicleshop:getVehicles', function(source, cb, dealershipId)
    local vehicles = {}

    for vehicleModel, vehicleData in pairs(Config.Vehicles) do
        -- Check if vehicle is sold at this dealership
        local soldHere = false
        for _, dealer in ipairs(vehicleData.dealerships) do
            if dealer == dealershipId then
                soldHere = true
                break
            end
        end

        if soldHere then
            vehicles[#vehicles + 1] = {
                model = vehicleModel,
                label = vehicleData.label,
                brand = vehicleData.brand,
                price = vehicleData.price,
                category = vehicleData.category,
                class = vehicleData.class,
                description = vehicleData.description or '',
            }
        end
    end

    cb(vehicles)
end)

-- Get player's money
SB.Functions.CreateCallback('sb_vehicleshop:getMoney', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(0, 0)
        return
    end

    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    cb(cash, bank)
end)

-- Check if player has keys for a specific plate
SB.Functions.CreateCallback('sb_vehicleshop:hasKeyForPlate', function(source, cb, plate)
    if not plate then
        cb(false)
        return
    end

    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Get all car_keys from player inventory
    local keys = exports['sb_inventory']:GetItemsByName(source, Config.KeysItem)
    if not keys or #keys == 0 then
        cb(false)
        return
    end

    -- Check if any key matches the plate
    for _, keyItem in ipairs(keys) do
        if keyItem.metadata and keyItem.metadata.plate then
            local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
            if keyPlate == cleanPlate then
                cb(true)
                return
            end
        end
    end

    cb(false)
end)

-- ============================================================================
-- PURCHASE VEHICLE
-- ============================================================================

RegisterServerEvent('sb_vehicleshop:server:purchase')
AddEventHandler('sb_vehicleshop:server:purchase', function(vehicleModel, dealershipId, paymentMethod)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Check operation lock
    if operationLocks[citizenid] then
        SB.Functions.Notify(src, 'Please wait...', 'error')
        return
    end
    operationLocks[citizenid] = true

    -- Validate vehicle exists
    local vehicleData = Config.Vehicles[vehicleModel]
    if not vehicleData then
        SB.Functions.Notify(src, 'Invalid vehicle!', 'error')
        operationLocks[citizenid] = nil
        return
    end

    -- Validate dealership sells this vehicle
    local soldHere = false
    for _, dealer in ipairs(vehicleData.dealerships) do
        if dealer == dealershipId then
            soldHere = true
            break
        end
    end

    if not soldHere then
        SB.Functions.Notify(src, 'This vehicle is not available here!', 'error')
        operationLocks[citizenid] = nil
        return
    end

    -- Check license requirement
    if Config.RequireLicense then
        local hasLicense = exports['sb_inventory']:HasItem(src, Config.LicenseItem, 1)
        if not hasLicense then
            SB.Functions.Notify(src, 'You need a driver\'s license to purchase a vehicle!', 'error')
            operationLocks[citizenid] = nil
            return
        end
    end

    -- Check payment
    local price = vehicleData.price
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0

    local actualPayMethod = paymentMethod
    if paymentMethod == 'cash' then
        if cash < price then
            SB.Functions.Notify(src, 'Not enough cash! Need $' .. price, 'error')
            operationLocks[citizenid] = nil
            return
        end
    elseif paymentMethod == 'bank' then
        if bank < price then
            SB.Functions.Notify(src, 'Not enough in bank! Need $' .. price, 'error')
            operationLocks[citizenid] = nil
            return
        end
    else
        -- Auto-select payment method
        if cash >= price then
            actualPayMethod = 'cash'
        elseif bank >= price then
            actualPayMethod = 'bank'
        else
            SB.Functions.Notify(src, 'Not enough money! Need $' .. price, 'error')
            operationLocks[citizenid] = nil
            return
        end
    end

    -- Generate unique plate
    local plate = GetUniquePlate()
    if not plate then
        SB.Functions.Notify(src, 'Failed to generate vehicle plate. Try again.', 'error')
        operationLocks[citizenid] = nil
        return
    end

    -- Remove money
    local removed = Player.Functions.RemoveMoney(actualPayMethod, price, 'vehicle-purchase')
    if not removed then
        SB.Functions.Notify(src, 'Payment failed!', 'error')
        operationLocks[citizenid] = nil
        return
    end

    -- Log bank transaction if paid from bank
    if actualPayMethod == 'bank' then
        local balanceAfter = Player.Functions.GetMoney('bank')
        exports['sb_banking']:LogPurchase(citizenid, price, balanceAfter, 'Vehicle Purchase - ' .. vehicleData.label)
    end

    -- Insert vehicle into database
    local insertId = MySQL.insert.await([[
        INSERT INTO player_vehicles
        (citizenid, plate, vehicle, vehicle_label, state, garage, fuel, body, engine, original_owner, purchase_price)
        VALUES (?, ?, ?, ?, 0, 'none', 100, 1000.0, 1000.0, ?, ?)
    ]], {
        citizenid,
        plate,
        vehicleModel,
        vehicleData.label,
        citizenid,
        price
    })

    if not insertId then
        -- Refund on failure
        Player.Functions.AddMoney(actualPayMethod, price, 'vehicle-purchase-refund')
        SB.Functions.Notify(src, 'Failed to register vehicle. Refunded.', 'error')
        operationLocks[citizenid] = nil
        return
    end

    -- Log purchase
    LogVehicleHistory(plate, 'purchase', 'Vehicle purchased from ' .. dealershipId, citizenid, {
        price = price,
        dealership = dealershipId,
        paymentMethod = actualPayMethod
    })

    -- Give car keys
    if Config.GiveKeys then
        local keyMetadata = {
            plate = plate,
            vehicle = vehicleModel,
            label = vehicleData.label
        }
        exports['sb_inventory']:AddItem(src, Config.KeysItem, 1, keyMetadata)
    end

    -- Get spawn point from dealership config
    local dealer = Config.Dealerships[dealershipId] or Config.Dealerships['pdm']
    local spawnPoint = dealer.spawnPoint

    -- Spawn vehicle SERVER-SIDE with persistence
    local vehicle, netId = SpawnPersistentVehicle(
        vehicleModel,
        vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z),
        spawnPoint.w,
        plate,
        citizenid
    )

    if not vehicle or not netId then
        -- Refund on spawn failure
        Player.Functions.AddMoney(actualPayMethod, price, 'vehicle-spawn-failed-refund')
        SB.Functions.Notify(src, 'Failed to spawn vehicle. Refunded.', 'error')
        operationLocks[citizenid] = nil
        return
    end

    -- Tell client to setup the vehicle (apply properties, warp player)
    TriggerClientEvent('sb_vehicleshop:client:setupPurchasedVehicle', src, {
        netId = netId,
        model = vehicleModel,
        plate = plate,
        label = vehicleData.label
    })

    SB.Functions.Notify(src, 'Purchased ' .. vehicleData.label .. ' for $' .. price .. '!', 'success')

    operationLocks[citizenid] = nil
end)

-- ============================================================================
-- TEST DRIVE (FIX-006: Server-side cleanup on disconnect)
-- ============================================================================

RegisterServerEvent('sb_vehicleshop:server:startTestDrive')
AddEventHandler('sb_vehicleshop:server:startTestDrive', function(vehicleModel, dealershipId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Check if already on test drive
    if activeTestDrives[citizenid] then
        SB.Functions.Notify(src, 'You are already on a test drive!', 'error')
        return
    end

    -- Validate vehicle
    local vehicleData = Config.Vehicles[vehicleModel]
    if not vehicleData then
        SB.Functions.Notify(src, 'Invalid vehicle!', 'error')
        return
    end

    -- Check license
    if Config.RequireLicense then
        local hasLicense = exports['sb_inventory']:HasItem(src, Config.LicenseItem, 1)
        if not hasLicense then
            SB.Functions.Notify(src, 'You need a driver\'s license for a test drive!', 'error')
            return
        end
    end

    -- Generate test drive plate
    local testPlate = 'TD' .. math.random(10000, 99999)

    -- Mark test drive active (vehicleNetId will be set by client after spawn)
    activeTestDrives[citizenid] = {
        vehicle = vehicleModel,
        dealership = dealershipId,
        startTime = os.time(),
        vehicleNetId = nil,  -- Will be set by client
        source = src,
        plate = testPlate
    }

    -- Give test drive keys
    local keyMetadata = {
        plate = testPlate,
        vehicle = vehicleModel,
        label = vehicleData.label .. ' (Test Drive)'
    }
    exports['sb_inventory']:AddItem(src, Config.KeysItem, 1, keyMetadata)

    -- Tell client to spawn test drive vehicle
    TriggerClientEvent('sb_vehicleshop:client:spawnTestDrive', src, {
        model = vehicleModel,
        label = vehicleData.label,
        duration = Config.TestDrive.duration,
        plate = testPlate
    })
end)

-- Client sends vehicle netId after spawning (FIX-006)
RegisterServerEvent('sb_vehicleshop:server:registerTestDriveVehicle')
AddEventHandler('sb_vehicleshop:server:registerTestDriveVehicle', function(netId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    if activeTestDrives[citizenid] then
        activeTestDrives[citizenid].vehicleNetId = netId
        activeTestDrives[citizenid].source = src
    end
end)

RegisterServerEvent('sb_vehicleshop:server:endTestDrive')
AddEventHandler('sb_vehicleshop:server:endTestDrive', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local testDrive = activeTestDrives[citizenid]

    -- Remove test drive keys
    if testDrive and testDrive.plate then
        local cleanPlate = testDrive.plate:gsub('%s+', ''):upper()
        local keys = exports['sb_inventory']:GetItemsByName(src, Config.KeysItem)
        if keys then
            for _, keyItem in ipairs(keys) do
                if keyItem.metadata and keyItem.metadata.plate then
                    local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                    if keyPlate == cleanPlate then
                        exports['sb_inventory']:RemoveItem(src, Config.KeysItem, 1, keyItem.slot)
                        break
                    end
                end
            end
        end
    end

    activeTestDrives[citizenid] = nil
end)

-- Server-side cleanup function (FIX-006)
local function CleanupTestDriveVehicle(citizenid, src)
    local testDrive = activeTestDrives[citizenid]
    if not testDrive then return end

    -- Remove test drive keys if player is online
    if src and testDrive.plate then
        local cleanPlate = testDrive.plate:gsub('%s+', ''):upper()
        local keys = exports['sb_inventory']:GetItemsByName(src, Config.KeysItem)
        if keys then
            for _, keyItem in ipairs(keys) do
                if keyItem.metadata and keyItem.metadata.plate then
                    local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                    if keyPlate == cleanPlate then
                        exports['sb_inventory']:RemoveItem(src, Config.KeysItem, 1, keyItem.slot)
                        break
                    end
                end
            end
        end
    end

    -- Delete the vehicle entity if it exists
    if testDrive.vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(testDrive.vehicleNetId)
        if vehicle and DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
            print('[sb_vehicleshop] Cleaned up test drive vehicle for ' .. citizenid)
        end
    end

    activeTestDrives[citizenid] = nil
end

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

RegisterCommand('givecar', function(source, args, rawCommand)
    local src = source

    -- Console or admin check
    if src > 0 then
        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            TriggerClientEvent('SB:Client:Notify', src, 'No permission!', 'error')
            return
        end
    end

    local targetId = tonumber(args[1])
    local vehicleModel = args[2]

    if not targetId or not vehicleModel then
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, 'Usage: /givecar [id] [model]', 'error')
        else
            print('Usage: givecar [id] [model]')
        end
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, 'Player not found!', 'error')
        else
            print('Player not found!')
        end
        return
    end

    -- Generate plate
    local plate = GetUniquePlate()
    if not plate then
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, 'Failed to generate plate!', 'error')
        end
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local vehicleLabel = vehicleModel

    -- Check if it's a configured vehicle
    if Config.Vehicles[vehicleModel] then
        vehicleLabel = Config.Vehicles[vehicleModel].label
    end

    -- Insert into database
    MySQL.insert.await([[
        INSERT INTO player_vehicles
        (citizenid, plate, vehicle, vehicle_label, state, garage, fuel, body, engine, original_owner, purchase_price)
        VALUES (?, ?, ?, ?, 0, 'none', 100, 1000.0, 1000.0, ?, 0)
    ]], {
        citizenid,
        plate,
        vehicleModel,
        vehicleLabel,
        citizenid
    })

    -- Log
    LogVehicleHistory(plate, 'admin_give', 'Vehicle given by admin', citizenid, {
        admin = src > 0 and GetPlayerName(src) or 'Console'
    })

    -- Give keys
    if Config.GiveKeys then
        local keyMetadata = {
            plate = plate,
            vehicle = vehicleModel,
            label = vehicleLabel
        }
        exports['sb_inventory']:AddItem(targetId, Config.KeysItem, 1, keyMetadata)
    end

    -- Spawn for player
    TriggerClientEvent('sb_vehicleshop:client:spawnPurchased', targetId, {
        model = vehicleModel,
        plate = plate,
        label = vehicleLabel,
        price = 0,
        paymentMethod = 'admin'
    })

    SB.Functions.Notify(targetId, 'You received a ' .. vehicleLabel .. '!', 'success')

    if src > 0 then
        TriggerClientEvent('SB:Client:Notify', src, 'Gave ' .. vehicleLabel .. ' to player ' .. targetId, 'success')
    else
        print('Gave ' .. vehicleLabel .. ' to player ' .. targetId)
    end
end, false)

-- Give driver's license command
RegisterCommand('givelicense', function(source, args, rawCommand)
    local src = source

    -- Console or admin check
    if src > 0 then
        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            TriggerClientEvent('SB:Client:Notify', src, 'No permission!', 'error')
            return
        end
    end

    local targetId = tonumber(args[1])

    if not targetId then
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, 'Usage: /givelicense [id]', 'error')
        else
            print('Usage: givelicense [id]')
        end
        return
    end

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        if src > 0 then
            TriggerClientEvent('SB:Client:Notify', src, 'Player not found!', 'error')
        else
            print('Player not found!')
        end
        return
    end

    -- Give license with metadata
    local licenseMetadata = {
        citizenid = Player.PlayerData.citizenid,
        firstname = Player.PlayerData.charinfo.firstname,
        lastname = Player.PlayerData.charinfo.lastname,
        issued = os.date('%Y-%m-%d')
    }

    exports['sb_inventory']:AddItem(targetId, Config.LicenseItem, 1, licenseMetadata)

    SB.Functions.Notify(targetId, 'You received a driver\'s license!', 'success')

    if src > 0 then
        TriggerClientEvent('SB:Client:Notify', src, 'Gave driver\'s license to player ' .. targetId, 'success')
    else
        print('Gave driver\'s license to player ' .. targetId)
    end
end, false)

-- ============================================================================
-- VEHICLE TRANSFER / SELL
-- ============================================================================

-- Transfer vehicle ownership to another player
RegisterServerEvent('sb_vehicleshop:server:transferVehicle')
AddEventHandler('sb_vehicleshop:server:transferVehicle', function(plate, targetId, price)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    local TargetPlayer = SB.Functions.GetPlayer(targetId)

    if not Player then return end
    if not TargetPlayer then
        SB.Functions.Notify(src, 'Player not found', 'error')
        return
    end

    local sellerCitizenid = Player.PlayerData.citizenid
    local buyerCitizenid = TargetPlayer.PlayerData.citizenid

    -- Validate price
    price = tonumber(price) or 0
    if price < 0 then price = 0 end

    -- Check if seller owns the vehicle (REPLACE handles DB plates with/without spaces)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ?', { cleanPlate, sellerCitizenid })
    if not vehicle then
        SB.Functions.Notify(src, 'You don\'t own this vehicle', 'error')
        return
    end

    -- Check if seller has the keys
    local sellerKeys = exports['sb_inventory']:GetItemsByName(src, Config.KeysItem)
    local hasKeys = false
    local keySlot = nil

    if sellerKeys then
        for _, keyItem in ipairs(sellerKeys) do
            if keyItem.metadata and keyItem.metadata.plate then
                local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                local searchPlate = plate:gsub('%s+', ''):upper()
                if keyPlate == searchPlate then
                    hasKeys = true
                    keySlot = keyItem.slot
                    break
                end
            end
        end
    end

    if not hasKeys then
        SB.Functions.Notify(src, 'You need the keys to transfer this vehicle', 'error')
        return
    end

    -- Check if buyer has enough money (if price > 0)
    if price > 0 then
        local buyerCash = TargetPlayer.PlayerData.money.cash or 0
        local buyerBank = TargetPlayer.PlayerData.money.bank or 0

        if buyerCash + buyerBank < price then
            SB.Functions.Notify(src, 'Buyer doesn\'t have enough money', 'error')
            SB.Functions.Notify(targetId, 'You don\'t have enough money for this vehicle', 'error')
            return
        end

        -- Remove money from buyer (cash first, then bank)
        if buyerCash >= price then
            TargetPlayer.Functions.RemoveMoney('cash', price, 'vehicle-purchase-player')
        else
            local remaining = price - buyerCash
            if buyerCash > 0 then
                TargetPlayer.Functions.RemoveMoney('cash', buyerCash, 'vehicle-purchase-player')
            end
            TargetPlayer.Functions.RemoveMoney('bank', remaining, 'vehicle-purchase-player')
        end

        -- Give money to seller
        Player.Functions.AddMoney('cash', price, 'vehicle-sale-player')
    end

    -- Update database - transfer ownership (use cleanPlate with REPLACE)
    MySQL.update.await('UPDATE player_vehicles SET citizenid = ? WHERE REPLACE(plate, " ", "") = ?', { buyerCitizenid, cleanPlate })

    -- Remove keys from seller
    exports['sb_inventory']:RemoveItem(src, Config.KeysItem, 1, keySlot)

    -- Give keys to buyer
    local keyMetadata = {
        plate = plate,
        vehicle = vehicle.vehicle,
        label = vehicle.vehicle_label
    }
    exports['sb_inventory']:AddItem(targetId, Config.KeysItem, 1, keyMetadata)

    -- Log the transfer
    pcall(function()
        LogVehicleHistory(plate, 'transfer', 'Transferred from ' .. sellerCitizenid .. ' to ' .. buyerCitizenid, sellerCitizenid, {
            seller = sellerCitizenid,
            buyer = buyerCitizenid,
            price = price
        })
    end)

    -- Notify both players
    local vehicleLabel = vehicle.vehicle_label or vehicle.vehicle
    if price > 0 then
        SB.Functions.Notify(src, 'Sold ' .. vehicleLabel .. ' for $' .. price, 'success')
        SB.Functions.Notify(targetId, 'Bought ' .. vehicleLabel .. ' for $' .. price, 'success')
    else
        SB.Functions.Notify(src, 'Transferred ' .. vehicleLabel .. ' to player', 'success')
        SB.Functions.Notify(targetId, 'Received ' .. vehicleLabel, 'success')
    end

    print('[sb_vehicleshop] Vehicle ' .. plate .. ' transferred from ' .. sellerCitizenid .. ' to ' .. buyerCitizenid .. ' for $' .. price)
end)

-- Command: /sellvehicle [playerid] [price]
RegisterCommand('sellvehicle', function(source, args, rawCommand)
    local src = source
    if src == 0 then return end

    local targetId = tonumber(args[1])
    local price = tonumber(args[2]) or 0

    if not targetId then
        SB.Functions.Notify(src, 'Usage: /sellvehicle [playerid] [price]', 'error')
        return
    end

    -- Tell client to find nearest owned vehicle and trigger transfer
    TriggerClientEvent('sb_vehicleshop:client:initTransfer', src, targetId, price)
end, false)

-- Command: /givekey [playerid] (give your actual key to another player)
RegisterCommand('givekey', function(source, args, rawCommand)
    local src = source
    if src == 0 then return end

    local targetId = tonumber(args[1])

    if not targetId then
        SB.Functions.Notify(src, 'Usage: /givekey [playerid]', 'error')
        return
    end

    local TargetPlayer = SB.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        SB.Functions.Notify(src, 'Player not found', 'error')
        return
    end

    -- Tell client to find nearest owned vehicle and give key
    TriggerClientEvent('sb_vehicleshop:client:initGiveKey', src, targetId)
end, false)

-- Server event to give actual key (not duplicate)
RegisterServerEvent('sb_vehicleshop:server:giveKey')
AddEventHandler('sb_vehicleshop:server:giveKey', function(plate, targetId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    local TargetPlayer = SB.Functions.GetPlayer(targetId)

    if not Player or not TargetPlayer then
        SB.Functions.Notify(src, 'Player not found', 'error')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Find the key in player's inventory
    local keys = exports['sb_inventory']:GetItemsByName(src, Config.KeysItem)
    local keySlot = nil
    local keyMetadata = nil

    if keys then
        for _, keyItem in ipairs(keys) do
            if keyItem.metadata and keyItem.metadata.plate then
                local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                if keyPlate == cleanPlate then
                    keySlot = keyItem.slot
                    keyMetadata = keyItem.metadata
                    break
                end
            end
        end
    end

    if not keySlot then
        SB.Functions.Notify(src, 'You don\'t have keys for this vehicle', 'error')
        return
    end

    -- Remove key from giver
    exports['sb_inventory']:RemoveItem(src, Config.KeysItem, 1, keySlot)

    -- Give key to receiver
    exports['sb_inventory']:AddItem(targetId, Config.KeysItem, 1, keyMetadata)

    local vehicleLabel = keyMetadata.label or keyMetadata.vehicle or 'Vehicle'
    SB.Functions.Notify(src, 'Gave ' .. vehicleLabel .. ' key to player', 'success')
    SB.Functions.Notify(targetId, 'Received key for ' .. vehicleLabel, 'success')

    print('[sb_vehicleshop] ' .. citizenid .. ' gave key for ' .. plate .. ' to player ' .. targetId)
end)

-- ============================================================================
-- CLEANUP (FIX-006: Server-side test drive vehicle cleanup)
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        operationLocks[citizenid] = nil

        -- Cleanup test drive vehicle on disconnect (FIX-006)
        CleanupTestDriveVehicle(citizenid, src)
    end
end)

-- Also cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Cleanup all test drive vehicles
    for citizenid, testDrive in pairs(activeTestDrives) do
        if testDrive.vehicleNetId then
            local vehicle = NetworkGetEntityFromNetworkId(testDrive.vehicleNetId)
            if vehicle and DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
        end
    end
    activeTestDrives = {}
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetPlayerVehicles', function(citizenid)
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { citizenid })
    return result or {}
end)

exports('GetVehicleByPlate', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local result = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { cleanPlate })
    return result
end)

exports('IsVehicleOwned', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    local result = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { cleanPlate })
    return result > 0
end)

print('^2[sb_vehicleshop]^7 Vehicle shop system loaded')
