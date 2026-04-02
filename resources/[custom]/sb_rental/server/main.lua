-- sb_rental Server Main
-- Rent/Return Processing, Payments, Callbacks

local SBCore = exports['sb_core']:GetCoreObject()
local operationLocks = {}

-- FIX-007: Track rental vehicle netIds for server-side despawn
local rentalVehicles = {}  -- [rentalId] = { netId, plate, citizenid }

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SBCore = exports['sb_core']:GetCoreObject()
    end
end)

print('^2[sb_rental]^7 Vehicle Rental System loaded')

-- FIX-007: Register rental vehicle netId from client
RegisterNetEvent('sb_rental:server:registerVehicle', function(rentalId, netId, plate)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    rentalVehicles[rentalId] = {
        netId = netId,
        plate = plate,
        citizenid = citizenid,
        source = src
    }
end)

-- FIX-007: Export to get rental vehicle netId (used by enforcement)
exports('GetRentalVehicleNetId', function(rentalId)
    if rentalVehicles[rentalId] then
        return rentalVehicles[rentalId].netId
    end
    return nil
end)

-- FIX-007: Clear rental vehicle tracking
exports('ClearRentalVehicle', function(rentalId)
    rentalVehicles[rentalId] = nil
end)

-- ============================================================================
-- SERVER-SIDE VEHICLE SPAWN (OneSync persistent)
-- ============================================================================

-- Get vehicle type for CreateVehicleServerSetter
local function GetVehicleType(model)
    local vehicleTypes = {
        -- Bikes (bicycles)
        ['bmx'] = 'bike', ['cruiser'] = 'bike', ['fixter'] = 'bike', ['scorcher'] = 'bike', ['tribike'] = 'bike',
        -- Motorcycles/Scooters
        ['faggio'] = 'bike', ['faggio2'] = 'bike', ['faggio3'] = 'bike',
    }
    return vehicleTypes[model:lower()] or 'automobile'
end

-- Spawn rental vehicle server-side with persistence
local function SpawnPersistentRentalVehicle(model, coords, heading, plate, citizenid, rentalId)
    local modelHash = GetHashKey(model)
    local vehicleType = GetVehicleType(model)

    -- Use CreateVehicleServerSetter for proper OneSync server-side spawn
    local vehicle = CreateVehicleServerSetter(modelHash, vehicleType, coords.x, coords.y, coords.z, heading)

    if not vehicle or vehicle == 0 then
        print('[sb_rental] Failed to spawn rental vehicle: ' .. model)
        return nil, nil
    end

    -- CRITICAL: Set orphan mode to keep entity when owner disconnects
    SetEntityOrphanMode(vehicle, 2)

    -- Set the plate
    SetVehicleNumberPlateText(vehicle, plate)

    -- Get network ID
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- Track this rental vehicle
    rentalVehicles[rentalId] = {
        netId = netId,
        plate = plate,
        citizenid = citizenid
    }

    -- Register with sb_impound for persistence tracking
    if GetResourceState('sb_impound') == 'started' then
        exports['sb_impound']:RegisterSpawnedVehicle(plate, citizenid, netId, model, nil)
    end

    print('[sb_rental] Spawned persistent rental: ' .. plate .. ' netId: ' .. netId)

    return vehicle, netId
end

-- Event: Client requests server to spawn rental vehicle
RegisterNetEvent('sb_rental:server:spawnRentalVehicle', function(vehicleModel, plate, rentalId, locationId, coords, heading)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Verify this is the player's rental
    local rental = MySQL.single.await('SELECT * FROM vehicle_rentals WHERE rental_id = ? AND citizenid = ? AND status = "active"', {
        rentalId, citizenid
    })

    if not rental then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Rental not found', 'error', 3000)
        return
    end

    -- Spawn vehicle server-side
    local vehicle, netId = SpawnPersistentRentalVehicle(
        vehicleModel,
        coords,
        heading,
        plate,
        citizenid,
        rentalId
    )

    if not vehicle or not netId then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Failed to spawn rental vehicle', 'error', 3000)
        return
    end

    -- Tell client to setup the vehicle
    TriggerClientEvent('sb_rental:client:setupRentalVehicle', src, {
        netId = netId,
        plate = plate,
        rentalId = rentalId,
        vehicle = vehicleModel
    })
end)

-- Generate unique rental ID
function GenerateRentalId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = 'R-'
    for i = 1, 5 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end

    -- Check if exists
    local exists = MySQL.scalar.await('SELECT rental_id FROM vehicle_rentals WHERE rental_id = ?', { id })
    if exists then
        return GenerateRentalId()
    end

    return id
end

-- Generate rental plate
function GeneratePlate()
    local nums = tostring(math.random(100, 999))
    local plate = Config.PlatePrefix .. ' ' .. nums

    -- Check if exists
    local exists = MySQL.scalar.await('SELECT plate FROM vehicle_rentals WHERE plate = ? AND status = "active"', { plate })
    if exists then
        return GeneratePlate()
    end

    return plate
end

-- Get vehicle info from config
function GetVehicleInfo(model)
    for category, vehicles in pairs(Config.Vehicles) do
        for _, vehicle in ipairs(vehicles) do
            if vehicle.model == model then
                return vehicle, category
            end
        end
    end
    return nil, nil
end

-- Check if player is blacklisted
SBCore.Functions.CreateCallback('sb_rental:server:checkBlacklist', function(source, cb)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb(true, 'Unknown')
        return
    end

    local citizenid = Player.PlayerData.citizenid

    local blacklist = MySQL.scalar.await([[
        SELECT blacklist_until FROM vehicle_rentals
        WHERE citizenid = ? AND blacklist_until IS NOT NULL AND blacklist_until > NOW()
        ORDER BY blacklist_until DESC LIMIT 1
    ]], { citizenid })

    if blacklist then
        -- Format for display (handle raw timestamp or string)
        local formatted = FormatDateTime(blacklist)
        cb(true, formatted)
    else
        cb(false, nil)
    end
end)

-- Check if player has active rental
SBCore.Functions.CreateCallback('sb_rental:server:hasActiveRental', function(source, cb)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    local rental = MySQL.scalar.await([[
        SELECT id FROM vehicle_rentals
        WHERE citizenid = ? AND status IN ('active', 'late', 'stolen')
        LIMIT 1
    ]], { citizenid })

    cb(rental ~= nil)
end)

-- Get active rental details
SBCore.Functions.CreateCallback('sb_rental:server:getActiveRental', function(source, cb)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    local rental = MySQL.single.await([[
        SELECT * FROM vehicle_rentals
        WHERE citizenid = ? AND status IN ('active', 'late', 'stolen')
        LIMIT 1
    ]], { citizenid })

    -- Format the dates for client display
    if rental then
        rental.rental_end_formatted = FormatDateTime(rental.rental_end)
        rental.rental_start_formatted = FormatDateTime(rental.rental_start)
    end

    cb(rental)
end)

-- Rent vehicle callback
SBCore.Functions.CreateCallback('sb_rental:server:rentVehicle', function(source, cb, vehicleModel, days, locationId)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Check operation lock
    if operationLocks[citizenid] then
        cb(false, 'Please wait...')
        return
    end
    operationLocks[citizenid] = true

    -- Validate inputs
    if not vehicleModel or not days or not locationId then
        operationLocks[citizenid] = nil
        cb(false, 'Invalid rental data')
        return
    end

    days = tonumber(days)
    if not days or days < 1 or days > Config.MaxRentalDays then
        operationLocks[citizenid] = nil
        cb(false, 'Invalid rental duration')
        return
    end

    -- Get vehicle info
    local vehicleInfo, category = GetVehicleInfo(vehicleModel)
    if not vehicleInfo then
        operationLocks[citizenid] = nil
        cb(false, 'Vehicle not available')
        return
    end

    -- Check location has this category
    local location = Config.Locations[locationId]
    if not location then
        operationLocks[citizenid] = nil
        cb(false, 'Invalid location')
        return
    end

    local hasCategory = false
    for _, cat in ipairs(location.categories) do
        if cat == category then
            hasCategory = true
            break
        end
    end

    if not hasCategory then
        operationLocks[citizenid] = nil
        cb(false, 'Vehicle not available at this location')
        return
    end

    -- Check for existing active rental
    local existingRental = MySQL.scalar.await([[
        SELECT id FROM vehicle_rentals
        WHERE citizenid = ? AND status IN ('active', 'late', 'stolen')
        LIMIT 1
    ]], { citizenid })

    if existingRental then
        operationLocks[citizenid] = nil
        cb(false, 'You already have an active rental')
        return
    end

    -- Check blacklist
    local blacklist = MySQL.scalar.await([[
        SELECT blacklist_until FROM vehicle_rentals
        WHERE citizenid = ? AND blacklist_until IS NOT NULL AND blacklist_until > NOW()
        ORDER BY blacklist_until DESC LIMIT 1
    ]], { citizenid })

    if blacklist then
        operationLocks[citizenid] = nil
        cb(false, 'You are banned from renting vehicles')
        return
    end

    -- Calculate cost
    local dailyRate = vehicleInfo.daily
    local totalCost = dailyRate * days

    -- Check player money
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0

    if cash + bank < totalCost then
        operationLocks[citizenid] = nil
        cb(false, 'Not enough money. Need $' .. totalCost)
        return
    end

    -- Deduct payment (cash first)
    local remaining = totalCost
    local paidFromBank = 0
    if cash >= remaining then
        Player.Functions.RemoveMoney('cash', remaining, 'vehicle-rental')
    else
        if cash > 0 then
            Player.Functions.RemoveMoney('cash', cash, 'vehicle-rental')
            remaining = remaining - cash
        end
        Player.Functions.RemoveMoney('bank', remaining, 'vehicle-rental')
        paidFromBank = remaining
    end

    -- Log bank transaction if any was paid from bank
    if paidFromBank > 0 then
        local balanceAfter = Player.Functions.GetMoney('bank')
        exports['sb_banking']:LogPurchase(citizenid, paidFromBank, balanceAfter, 'Vehicle Rental - ' .. vehicleInfo.label .. ' (' .. days .. ' days)')
    end

    -- Generate IDs
    local rentalId = GenerateRentalId()
    local plate = GeneratePlate()

    -- Calculate rental end (in real minutes based on game day)
    local rentalMinutes = days * Config.GameDayMinutes
    local rentalStart = os.date('%Y-%m-%d %H:%M:%S')
    local rentalEndTime = os.time() + (rentalMinutes * 60)
    local rentalEnd = os.date('%Y-%m-%d %H:%M:%S', rentalEndTime)

    -- Insert rental record
    MySQL.insert.await([[
        INSERT INTO vehicle_rentals
        (rental_id, citizenid, vehicle, vehicle_label, plate, category, location_id,
         daily_rate, days_rented, total_cost, rental_start, rental_end, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
    ]], {
        rentalId, citizenid, vehicleModel, vehicleInfo.label, plate, category,
        locationId, dailyRate, days, totalCost, rentalStart, rentalEnd
    })

    -- Create rental license item
    local licenseMetadata = {
        rental_id = rentalId,
        vehicle = vehicleModel,
        vehicle_label = vehicleInfo.label,
        plate = plate,
        renter_name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        rental_start = rentalStart,
        rental_end = rentalEnd,
        days = days,
        location = location.label,
        status = 'active'
    }

    -- Add rental license to inventory
    local success = exports['sb_inventory']:AddItem(source, 'rental_license', 1, licenseMetadata)
    if not success then
        -- Refund if item couldn't be added
        Player.Functions.AddMoney('cash', totalCost, 'rental-refund')
        MySQL.query.await('DELETE FROM vehicle_rentals WHERE rental_id = ?', { rentalId })
        operationLocks[citizenid] = nil
        cb(false, 'Could not create rental license. Check inventory space.')
        return
    end

    -- Give car keys for the rental vehicle
    local keyMetadata = {
        plate = plate,
        vehicle = vehicleModel,
        label = vehicleInfo.label .. ' (Rental)'
    }
    exports['sb_inventory']:AddItem(source, 'car_keys', 1, keyMetadata)

    operationLocks[citizenid] = nil

    -- Format return date for display
    local returnBy = os.date('%A, %b %d at %I:%M %p', rentalEndTime)

    cb(true, {
        rentalId = rentalId,
        vehicle = vehicleModel,
        plate = plate,
        returnBy = returnBy
    })
end)

-- Return vehicle callback
SBCore.Functions.CreateCallback('sb_rental:server:returnVehicle', function(source, cb, rentalId, bodyHealth)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Check operation lock
    if operationLocks[citizenid] then
        cb(false, 'Please wait...')
        return
    end
    operationLocks[citizenid] = true

    -- Get rental record
    local rental = MySQL.single.await([[
        SELECT * FROM vehicle_rentals
        WHERE rental_id = ? AND citizenid = ? AND status IN ('active', 'late', 'stolen')
    ]], { rentalId, citizenid })

    if not rental then
        operationLocks[citizenid] = nil
        cb(false, 'Rental not found')
        return
    end

    -- Calculate time differences
    local now = os.time()
    local rentalEndTime = ParseDateTime(rental.rental_end)
    local rentalStartTime = ParseDateTime(rental.rental_start)

    local minutesUsed = math.ceil((now - rentalStartTime) / 60)
    local minutesPaid = rental.days_rented * Config.GameDayMinutes
    local minutesRemaining = minutesPaid - minutesUsed

    local refund = 0
    local lateFees = 0
    local damageFees = 0
    local lostKeysFee = 0

    -- Check if player has the car keys
    local hasKeys = false
    local keySlot = nil
    local cleanPlate = rental.plate:gsub('%s+', ''):upper()

    local keys = exports['sb_inventory']:GetItemsByName(source, 'car_keys')
    if keys then
        for _, keyItem in ipairs(keys) do
            if keyItem.metadata and keyItem.metadata.plate then
                local keyPlate = keyItem.metadata.plate:gsub('%s+', ''):upper()
                if keyPlate == cleanPlate then
                    hasKeys = true
                    keySlot = keyItem.slot
                    break
                end
            end
        end
    end

    -- Charge lost keys fee if no keys
    if not hasKeys then
        lostKeysFee = Config.LostKeysFee or 150
    end

    -- Calculate late fees if overdue
    if now > rentalEndTime then
        local minutesLate = math.ceil((now - rentalEndTime) / 60)
        local daysLate = math.ceil(minutesLate / Config.GameDayMinutes)
        lateFees = rental.daily_rate * Config.LateMultiplier * daysLate
    else
        -- Early return refund (50% of unused time)
        if minutesRemaining > Config.GracePeriodMinutes then
            local unusedDays = math.floor(minutesRemaining / Config.GameDayMinutes)
            if unusedDays > 0 then
                refund = math.floor((rental.daily_rate * unusedDays) * 0.5)
            end
        end
    end

    -- Calculate damage fees
    bodyHealth = tonumber(bodyHealth) or 1000
    if bodyHealth < 800 then
        local damagePoints = 800 - bodyHealth
        damageFees = math.floor(damagePoints * Config.DamageRate)
    end

    -- Process payments/refunds
    local netAmount = refund - lateFees - damageFees - lostKeysFee
    local paidFromBank = 0

    if netAmount > 0 then
        -- Refund to player
        Player.Functions.AddMoney('cash', netAmount, 'rental-refund')
    elseif netAmount < 0 then
        -- Charge player
        local charge = math.abs(netAmount)
        local cash = Player.PlayerData.money.cash or 0
        local bank = Player.PlayerData.money.bank or 0

        if cash + bank >= charge then
            local remaining = charge
            if cash >= remaining then
                Player.Functions.RemoveMoney('cash', remaining, 'rental-fees')
            else
                if cash > 0 then
                    Player.Functions.RemoveMoney('cash', cash, 'rental-fees')
                    remaining = remaining - cash
                end
                Player.Functions.RemoveMoney('bank', remaining, 'rental-fees')
                paidFromBank = remaining
            end
        else
            -- Charge what we can
            if cash > 0 then
                Player.Functions.RemoveMoney('cash', cash, 'rental-fees')
            end
            if bank > 0 then
                Player.Functions.RemoveMoney('bank', bank, 'rental-fees')
                paidFromBank = bank
            end
        end
    end

    -- Log bank transaction if any fees were paid from bank
    if paidFromBank > 0 then
        local balanceAfter = Player.Functions.GetMoney('bank')
        local feeDescription = 'Rental Fees'
        if lateFees > 0 then feeDescription = feeDescription .. ' - Late: $' .. lateFees end
        if damageFees > 0 then feeDescription = feeDescription .. ' - Damage: $' .. damageFees end
        if lostKeysFee > 0 then feeDescription = feeDescription .. ' - Lost Keys: $' .. lostKeysFee end
        exports['sb_banking']:LogPurchase(citizenid, paidFromBank, balanceAfter, feeDescription)
    end

    -- Update rental record
    MySQL.query.await([[
        UPDATE vehicle_rentals
        SET status = 'returned', actual_return = NOW(), late_fees = ?, damage_fees = ?
        WHERE rental_id = ?
    ]], { lateFees, damageFees, rentalId })

    -- Remove rental license from inventory
    local items = exports['sb_inventory']:GetItemsByName(source, 'rental_license')
    if items then
        for _, item in pairs(items) do
            if item.metadata and item.metadata.rental_id == rentalId then
                exports['sb_inventory']:RemoveItem(source, 'rental_license', 1, item.slot)
                break
            end
        end
    end

    -- Remove car keys for the rental vehicle (only if player has them)
    if hasKeys and keySlot then
        exports['sb_inventory']:RemoveItem(source, 'car_keys', 1, keySlot)
    end

    operationLocks[citizenid] = nil

    -- Notify client to update
    TriggerClientEvent('sb_rental:client:rentalUpdated', source, nil)

    cb(true, {
        refund = refund,
        lateFees = lateFees,
        damageFees = damageFees,
        lostKeysFee = lostKeysFee
    })
end)

-- Parse datetime string/number to timestamp (returns seconds since epoch)
function ParseDateTime(dateStr)
    if not dateStr then return os.time() end

    -- If it's already a number
    if type(dateStr) == 'number' then
        -- Check if it's milliseconds (> 10^12, i.e., 13+ digits) and convert to seconds
        -- Timestamps after year 2001 in seconds are > 1000000000 (10 digits)
        -- Timestamps in milliseconds are > 1000000000000 (13 digits)
        if dateStr > 1000000000000 then
            return math.floor(dateStr / 1000)
        end
        return dateStr
    end

    -- If it's not a string, convert to string first
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

-- Format timestamp to readable date string
function FormatDateTime(timestamp)
    if not timestamp then return 'N/A' end

    -- Handle milliseconds
    if type(timestamp) == 'number' and timestamp > 1000000000000 then
        timestamp = math.floor(timestamp / 1000)
    end

    -- Handle string timestamps
    if type(timestamp) == 'string' then
        timestamp = ParseDateTime(timestamp)
    end

    return os.date('%A, %b %d at %I:%M %p', timestamp)
end

-- Request rental update (for client warning thread)
RegisterNetEvent('sb_rental:server:requestRentalUpdate', function()
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    local rental = MySQL.single.await([[
        SELECT * FROM vehicle_rentals
        WHERE citizenid = ? AND status IN ('active', 'late', 'stolen')
        LIMIT 1
    ]], { citizenid })

    if rental then
        -- Format dates for client display
        rental.rental_end_formatted = FormatDateTime(rental.rental_end)
        rental.rental_start_formatted = FormatDateTime(rental.rental_start)

        TriggerClientEvent('sb_rental:client:rentalUpdated', source, rental)

        -- Check for warnings
        local now = os.time()
        local rentalEndTime = ParseDateTime(rental.rental_end)
        local minutesUntilExpiry = math.floor((rentalEndTime - now) / 60)

        if minutesUntilExpiry <= 0 then
            TriggerClientEvent('sb_rental:client:warning', source, 'overdue', {})
        elseif minutesUntilExpiry <= 10 then
            TriggerClientEvent('sb_rental:client:warning', source, 'expiring_soon', { minutes = 10 })
        elseif minutesUntilExpiry <= 30 then
            TriggerClientEvent('sb_rental:client:warning', source, 'expiring_soon', { minutes = 30 })
        elseif minutesUntilExpiry <= 60 then
            TriggerClientEvent('sb_rental:client:warning', source, 'expiring_soon', { minutes = 60 })
        end

        if rental.status == 'stolen' then
            TriggerClientEvent('sb_rental:client:warning', source, 'stolen', {})
        end
    else
        TriggerClientEvent('sb_rental:client:rentalUpdated', source, nil)
    end
end)

-- Handle rental license item use
RegisterNetEvent('sb_inventory:server:useItem', function(itemName, slot)
    if itemName ~= 'rental_license' then return end

    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local item = exports['sb_inventory']:GetItemBySlot(source, slot)
    if not item or not item.metadata then return end

    -- Get current status from database
    local rental = MySQL.single.await([[
        SELECT status FROM vehicle_rentals WHERE rental_id = ?
    ]], { item.metadata.rental_id })

    local metadata = item.metadata
    if rental then
        metadata.status = rental.status
    end

    TriggerClientEvent('sb_rental:client:showLicense', source, metadata)
end)

-- Exports
exports('GetPlayerRentals', function(citizenid)
    return MySQL.query.await([[
        SELECT * FROM vehicle_rentals WHERE citizenid = ? ORDER BY created_at DESC
    ]], { citizenid })
end)

exports('GetActiveRental', function(citizenid)
    return MySQL.single.await([[
        SELECT * FROM vehicle_rentals
        WHERE citizenid = ? AND status IN ('active', 'late', 'stolen')
        LIMIT 1
    ]], { citizenid })
end)

exports('GetRentalByPlate', function(plate)
    return MySQL.single.await([[
        SELECT * FROM vehicle_rentals WHERE plate = ?
    ]], { plate })
end)

exports('IsRentalVehicle', function(plate)
    local rental = MySQL.scalar.await([[
        SELECT id FROM vehicle_rentals WHERE plate = ? AND status IN ('active', 'late', 'stolen')
    ]], { plate })
    return rental ~= nil
end)

-- Cleanup on disconnect (FIX-007: Also clear vehicle tracking)
AddEventHandler('playerDropped', function()
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        operationLocks[citizenid] = nil

        -- FIX-007: Clear rental vehicle tracking for this player
        for rentalId, data in pairs(rentalVehicles) do
            if data.citizenid == citizenid then
                -- Note: We don't delete the vehicle on disconnect
                -- The enforcement thread will handle it if overdue
                -- Just clear the tracking (vehicle stays in world)
                rentalVehicles[rentalId] = nil
                break
            end
        end
    end
end)
