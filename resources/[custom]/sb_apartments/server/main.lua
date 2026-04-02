-- sb_apartments Server
-- MLO-direct apartment system (routing buckets kept for future shell mode)

local SBCore = exports['sb_core']:GetCoreObject()

-- ============================================
-- STATE
-- ============================================
local rentalsCache = {}          -- [unitId] = rental data
local keysCache = {}             -- [unitId] = { citizenids }
local BucketPool = {}            -- [bucket] = unitId or nil
local UnitOccupants = {}         -- [unitId] = { [src] = true }
local UnitBuckets = {}           -- [unitId] = bucket
local PlayerUnits = {}           -- [src] = unitId (which unit they're in)
local PendingDoorbells = {}      -- [unitId_src] = { src, unitId, timeout }
local operationLocks = {}        -- [key] = timestamp (mutex)
local doorLockState = {}         -- [unitId] = true/false (owner-controlled lock)

-- Helper: sb_notify has no server export, so fire client event
local function NotifyPlayer(src, msg, notifType, duration)
    TriggerClientEvent('sb_apartments:client:notify', src, msg, notifType, duration)
end

-- Initialize bucket pool (1-62, only used in shell mode)
for i = 1, 62 do
    BucketPool[i] = nil
end

-- ============================================
-- OPERATION LOCKS (from sb_garage pattern)
-- ============================================

local function LockOperation(key)
    operationLocks[key] = os.time()
end

local function UnlockOperation(key)
    operationLocks[key] = nil
end

local function IsOperationLocked(key)
    local lockTime = operationLocks[key]
    if not lockTime then return false end
    if (os.time() - lockTime) > 10 then
        operationLocks[key] = nil
        return false
    end
    return true
end

-- ============================================
-- ROUTING BUCKET MANAGER (shell mode only)
-- ============================================

local function AllocateBucket(unitId)
    if UnitBuckets[unitId] then
        return UnitBuckets[unitId]
    end

    for i = 1, 62 do
        if not BucketPool[i] then
            BucketPool[i] = unitId
            UnitBuckets[unitId] = i
            return i
        end
    end

    print('[sb_apartments] ERROR: No free routing buckets!')
    return nil
end

local function ReleaseBucket(unitId)
    local bucket = UnitBuckets[unitId]
    if bucket then
        BucketPool[bucket] = nil
        UnitBuckets[unitId] = nil
    end
end

local function GetUnitBucket(unitId)
    return UnitBuckets[unitId]
end

-- ============================================
-- BUILDING HELPER
-- ============================================

local function GetBuildingForUnit(unitId)
    for buildingId, building in pairs(Config.Buildings) do
        if building.units[unitId] then
            return buildingId, building
        end
    end
    return nil, nil
end

local function IsShellMode(buildingId)
    local building = Config.Buildings[buildingId]
    return building and building.useShells == true
end

-- Door lock helper: temp unlock via sb_doorlock, re-lock after duration
local function TempUnlockDoor(unitId, duration)
    local doorId = 'apt_' .. unitId
    if GetResourceState('sb_doorlock') ~= 'started' then return end
    local isLocked = exports['sb_doorlock']:GetDoorState(doorId)
    if isLocked then
        exports['sb_doorlock']:SetDoorState(doorId, false)
        SetTimeout(duration or 5000, function()
            -- Re-lock unless owner has explicitly unlocked
            if not (doorLockState[unitId] == true) then
                exports['sb_doorlock']:SetDoorState(doorId, true)
            end
        end)
    end
end

-- ============================================
-- OCCUPANT TRACKING
-- ============================================

local function AddOccupant(unitId, src)
    if not UnitOccupants[unitId] then
        UnitOccupants[unitId] = {}
    end
    UnitOccupants[unitId][src] = true
    PlayerUnits[src] = unitId
end

local function RemoveOccupant(unitId, src)
    if UnitOccupants[unitId] then
        UnitOccupants[unitId][src] = nil

        -- Check if empty
        local empty = true
        for _ in pairs(UnitOccupants[unitId]) do
            empty = false
            break
        end

        if empty then
            UnitOccupants[unitId] = nil
            ReleaseBucket(unitId)  -- only matters in shell mode
        end
    end
    PlayerUnits[src] = nil
end

local function GetOccupants(unitId)
    return UnitOccupants[unitId] or {}
end

local function IsUnitOccupied(unitId)
    return UnitOccupants[unitId] ~= nil and next(UnitOccupants[unitId]) ~= nil
end

-- ============================================
-- DATABASE MIGRATION
-- ============================================

local function EnsureDatabase()
    -- Rentals table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `sb_apartment_rentals` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `unit_id` VARCHAR(50) NOT NULL,
            `building_id` VARCHAR(50) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `rent_amount` INT NOT NULL,
            `deposit_paid` INT NOT NULL,
            `shell_variant` VARCHAR(50) DEFAULT NULL,
            `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `next_payment` TIMESTAMP NOT NULL,
            `missed_payments` INT DEFAULT 0,
            `grace_notified` TINYINT DEFAULT 0,
            `pending_payment` TINYINT DEFAULT 0,
            `status` ENUM('active', 'ended', 'evicted') DEFAULT 'active',
            `ended_at` TIMESTAMP NULL,
            INDEX `idx_citizenid` (`citizenid`),
            INDEX `idx_status` (`status`),
            INDEX `idx_next_payment` (`next_payment`),
            INDEX `idx_unit_status` (`unit_id`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Keys table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `sb_apartment_keys` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `unit_id` VARCHAR(50) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `granted_by` VARCHAR(50) NOT NULL,
            `granted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_key` (`unit_id`, `citizenid`),
            INDEX `idx_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Stash table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `sb_apartment_stash` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `unit_id` VARCHAR(50) NOT NULL,
            `stash_id` VARCHAR(100) UNIQUE NOT NULL,
            `items` LONGTEXT,
            `slots` INT DEFAULT 50,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_unit_id` (`unit_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Log table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `sb_apartment_log` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `unit_id` VARCHAR(50) NOT NULL,
            `action` VARCHAR(50) NOT NULL,
            `citizenid` VARCHAR(50),
            `details` TEXT,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_unit_id` (`unit_id`),
            INDEX `idx_action` (`action`),
            INDEX `idx_created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Drop the broken unique key if it exists (it prevents multiple ended/evicted rentals for same unit)
    pcall(function()
        MySQL.query.await('ALTER TABLE `sb_apartment_rentals` DROP INDEX `unique_active_rental`')
    end)

    print('[sb_apartments] Database tables verified')
end

-- ============================================
-- INITIALIZATION
-- ============================================

CreateThread(function()
    EnsureDatabase()
    LoadRentalsCache()
    CreateThread(RentPaymentLoop)
end)

function LoadRentalsCache()
    local result = MySQL.query.await('SELECT * FROM sb_apartment_rentals WHERE status = ?', {'active'})

    rentalsCache = {}
    for _, rental in ipairs(result or {}) do
        rentalsCache[rental.unit_id] = rental
    end

    -- Load keys
    local keys = MySQL.query.await('SELECT * FROM sb_apartment_keys')
    keysCache = {}
    for _, key in ipairs(keys or {}) do
        if not keysCache[key.unit_id] then
            keysCache[key.unit_id] = {}
        end
        table.insert(keysCache[key.unit_id], key.citizenid)
    end

    print('[sb_apartments] Loaded ' .. #(result or {}) .. ' active rentals')
end

-- ============================================
-- ACCESS HELPERS
-- ============================================

local function HasAccess(citizenid, unitId)
    local rental = rentalsCache[unitId]
    if rental and rental.citizenid == citizenid then
        return true, 'owner'
    end
    if keysCache[unitId] then
        for _, cid in ipairs(keysCache[unitId]) do
            if cid == citizenid then
                return true, 'keyholder'
            end
        end
    end
    return false, nil
end

local function IsUnitRented(unitId)
    return rentalsCache[unitId] ~= nil
end

-- ============================================
-- CALLBACKS
-- ============================================

-- Returns which rented doors the owner has explicitly unlocked (for client door lock init)
-- All doors default LOCKED. Only returns true for doors the owner explicitly unlocked.
SBCore.Functions.CreateCallback('sb_apartments:server:getRentedUnits', function(source, cb)
    local unlocked = {}
    for unitId, _ in pairs(rentalsCache) do
        unlocked[unitId] = doorLockState[unitId] == true  -- true = owner explicitly unlocked
    end
    cb(unlocked)
end)

SBCore.Functions.CreateCallback('sb_apartments:server:getBuildingUnits', function(source, cb, buildingId)
    local building = Config.Buildings[buildingId]
    if not building then
        cb({})
        return
    end

    local rentals = {}
    for unitId, _ in pairs(building.units) do
        if rentalsCache[unitId] then
            table.insert(rentals, {
                unit_id = unitId,
                citizenid = rentalsCache[unitId].citizenid
            })
        end
    end

    cb(rentals)
end)

SBCore.Functions.CreateCallback('sb_apartments:server:getUnitDetails', function(source, cb, buildingId, unitId)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    local citizenid = Player.PlayerData.citizenid
    local rental = rentalsCache[unitId]
    if not rental then cb(nil) return end

    local isOwner = rental.citizenid == citizenid

    -- Get keys with names
    local keys = {}
    local keyResult = MySQL.query.await(
        'SELECT ak.citizenid, p.charinfo FROM sb_apartment_keys ak JOIN players p ON ak.citizenid = p.citizenid WHERE ak.unit_id = ?',
        {unitId}
    )
    for _, key in ipairs(keyResult or {}) do
        local charinfo = json.decode(key.charinfo)
        table.insert(keys, {
            citizenid = key.citizenid,
            name = charinfo.firstname .. ' ' .. charinfo.lastname
        })
    end

    cb({
        rental = {
            citizenid = rental.citizenid,
            rent_amount = rental.rent_amount,
            deposit_paid = rental.deposit_paid,
            started_at = rental.started_at,
            next_payment = rental.next_payment,
            missed_payments = rental.missed_payments
        },
        keys = keys,
        isOwner = isOwner
    })
end)

-- Enter apartment callback (validates access, conditional bucket for shell mode)
SBCore.Functions.CreateCallback('sb_apartments:server:enterApartment', function(source, cb, buildingId, unitId)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    local citizenid = Player.PlayerData.citizenid
    local hasAccess, accessType = HasAccess(citizenid, unitId)

    if not hasAccess then
        cb(nil)
        return
    end

    local building = Config.Buildings[buildingId]
    if not building then
        cb(nil)
        return
    end

    if building.useShells then
        -- Shell mode (future use) - allocate routing bucket
        local bucket = AllocateBucket(unitId)
        if not bucket then
            NotifyPlayer(source, 'Apartments are full, try again later', 'error', 3000)
            cb(nil)
            return
        end
        SetPlayerRoutingBucket(source, bucket)
    end

    -- Track occupant
    AddOccupant(unitId, source)

    -- Temp unlock door so player can walk in (re-locks after 5s)
    TempUnlockDoor(unitId, 5000)

    -- Log entry
    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'entered', citizenid, json.encode({access = accessType})
    })

    cb({
        tier = building.tier,
        accessType = accessType,
        unitId = unitId,
        buildingId = buildingId
    })
end)

-- Garage: get vehicles stored at apartment
SBCore.Functions.CreateCallback('sb_apartments:server:getGarageVehicles', function(source, cb, unitId)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end

    local citizenid = Player.PlayerData.citizenid
    local garageId = 'apt_' .. unitId

    -- Check the player has access to this apartment
    local hasAccess = HasAccess(citizenid, unitId)
    if not hasAccess then cb({}) return end

    local vehicles = MySQL.query.await(
        'SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = 1',
        {citizenid, garageId}
    )

    cb(vehicles or {})
end)

-- Garage: store vehicle
SBCore.Functions.CreateCallback('sb_apartments:server:storeVehicle', function(source, cb, unitId, plate)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    local citizenid = Player.PlayerData.citizenid
    local garageId = 'apt_' .. unitId

    -- Check access
    local hasAccess = HasAccess(citizenid, unitId)
    if not hasAccess then
        NotifyPlayer(source, 'No access to this garage', 'error', 3000)
        cb(false)
        return
    end

    -- Check vehicle limit
    local buildingId, building = GetBuildingForUnit(unitId)
    local maxVehicles = (building and building.garage and building.garage.maxVehicles) or 3
    local stored = MySQL.scalar.await(
        'SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = 1',
        {citizenid, garageId}
    )
    if stored >= maxVehicles then
        NotifyPlayer(source, 'Garage is full (' .. maxVehicles .. ' max)', 'error', 3000)
        cb(false)
        return
    end

    -- Operation lock
    local lockKey = 'garage_' .. plate
    if IsOperationLocked(lockKey) then
        NotifyPlayer(source, 'Please wait...', 'error', 2000)
        cb(false)
        return
    end
    LockOperation(lockKey)

    -- Update vehicle record
    MySQL.update('UPDATE player_vehicles SET garage = ?, state = 1 WHERE citizenid = ? AND plate = ?',
        {garageId, citizenid, plate})

    UnlockOperation(lockKey)

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'vehicle_stored', citizenid, json.encode({plate = plate})
    })

    cb(true)
end)

-- Garage: retrieve vehicle
SBCore.Functions.CreateCallback('sb_apartments:server:retrieveVehicle', function(source, cb, unitId, plate)
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    local citizenid = Player.PlayerData.citizenid
    local garageId = 'apt_' .. unitId

    local hasAccess = HasAccess(citizenid, unitId)
    if not hasAccess then cb(false) return end

    local lockKey = 'garage_' .. plate
    if IsOperationLocked(lockKey) then
        NotifyPlayer(source, 'Please wait...', 'error', 2000)
        cb(false)
        return
    end
    LockOperation(lockKey)

    -- Get vehicle data
    local vehData = MySQL.single.await(
        'SELECT * FROM player_vehicles WHERE citizenid = ? AND plate = ? AND garage = ? AND state = 1',
        {citizenid, plate, garageId}
    )

    if not vehData then
        UnlockOperation(lockKey)
        cb(false)
        return
    end

    -- Find spawn point
    local buildingId, building = GetBuildingForUnit(unitId)
    if not building or not building.garage then
        UnlockOperation(lockKey)
        cb(false)
        return
    end

    local spawnPoint = nil
    for _, sp in ipairs(building.garage.spawnPoints) do
        -- Check if spawn point is clear
        local vehicles = GetAllVehicles()
        local clear = true
        for _, v in ipairs(vehicles) do
            local vCoords = GetEntityCoords(v)
            if #(vector3(vCoords.x, vCoords.y, vCoords.z) - sp.coords) < 3.0 then
                clear = false
                break
            end
        end
        if clear then
            spawnPoint = sp
            break
        end
    end

    if not spawnPoint then
        UnlockOperation(lockKey)
        NotifyPlayer(source, 'No parking space available', 'error', 3000)
        cb(false)
        return
    end

    -- Spawn vehicle server-side (sb_garage pattern)
    local modelHash = GetHashKey(vehData.vehicle)
    local vehicleType = GetVehicleType(vehData.vehicle)
    local vehicle = CreateVehicleServerSetter(modelHash, vehicleType, spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z, spawnPoint.heading)

    if not vehicle or vehicle == 0 then
        UnlockOperation(lockKey)
        NotifyPlayer(source, 'Failed to spawn vehicle', 'error', 3000)
        cb(false)
        return
    end

    SetEntityOrphanMode(vehicle, 2)
    SetVehicleNumberPlateText(vehicle, plate)
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', plate, true)
    Entity(vehicle).state:set('sb_hidden', true, true)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- Update state to out (0)
    MySQL.update('UPDATE player_vehicles SET state = 0 WHERE citizenid = ? AND plate = ?', {citizenid, plate})

    -- Register with impound
    if GetResourceState('sb_impound') == 'started' then
        exports['sb_impound']:RegisterSpawnedVehicle(plate, citizenid, netId, vehData.vehicle, nil)
    end

    UnlockOperation(lockKey)

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'vehicle_retrieved', citizenid, json.encode({plate = plate})
    })

    cb(true, netId)
end)

-- ============================================
-- GET MY RENTALS
-- ============================================

RegisterNetEvent('sb_apartments:server:getMyRentals', function()
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local rentals = MySQL.query.await('SELECT * FROM sb_apartment_rentals WHERE citizenid = ? AND status = ?', {citizenid, 'active'})
    local keys = MySQL.query.await('SELECT * FROM sb_apartment_keys WHERE citizenid = ?', {citizenid})

    TriggerClientEvent('sb_apartments:client:updateRentals', source, rentals or {}, keys or {})
end)

-- ============================================
-- RENT UNIT
-- ============================================

RegisterNetEvent('sb_apartments:server:rentUnit', function(buildingId, unitId, paymentMethod)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local building = Config.Buildings[buildingId]
    if not building then
        NotifyPlayer(source, 'Invalid building', 'error', 3000)
        return
    end

    local unit = building.units[unitId]
    if not unit then
        NotifyPlayer(source, 'Invalid unit', 'error', 3000)
        return
    end

    -- Mutex lock on unit to prevent race condition
    local lockKey = 'rent_' .. unitId
    if IsOperationLocked(lockKey) then
        NotifyPlayer(source, 'Someone else is renting this unit, try again', 'error', 3000)
        return
    end
    LockOperation(lockKey)

    -- Double-check not already rented (after lock)
    if rentalsCache[unitId] then
        UnlockOperation(lockKey)
        NotifyPlayer(source, 'This unit is already rented', 'error', 3000)
        return
    end

    -- Check rental limit
    local citizenid = Player.PlayerData.citizenid
    local playerRentals = MySQL.query.await(
        'SELECT COUNT(*) as count FROM sb_apartment_rentals WHERE citizenid = ? AND status = ?',
        {citizenid, 'active'}
    )
    if playerRentals[1].count >= Config.MaxRentals then
        UnlockOperation(lockKey)
        NotifyPlayer(source, 'You can only rent up to ' .. Config.MaxRentals .. ' apartments', 'error', 3000)
        return
    end

    -- Calculate costs
    local rent = unit.rent
    local deposit = rent * Config.DepositMultiplier
    local totalCost = rent + deposit

    -- Check payment
    local moneyType = paymentMethod == 'cash' and 'cash' or 'bank'
    if Player.Functions.GetMoney(moneyType) < totalCost then
        UnlockOperation(lockKey)
        NotifyPlayer(source, 'Not enough money. Need $' .. totalCost, 'error', 3000)
        return
    end

    Player.Functions.RemoveMoney(moneyType, totalCost, 'apartment-rental-' .. unitId)

    -- Create rental record
    local nextPayment = os.time() + (Config.RentCycle / 1000)

    MySQL.insert('INSERT INTO sb_apartment_rentals (unit_id, building_id, citizenid, rent_amount, deposit_paid, next_payment, status) VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?)', {
        unitId, buildingId, citizenid, rent, deposit, nextPayment, 'active'
    })

    -- Update cache
    rentalsCache[unitId] = {
        unit_id = unitId,
        building_id = buildingId,
        citizenid = citizenid,
        rent_amount = rent,
        deposit_paid = deposit,
        next_payment = os.date('%Y-%m-%d %H:%M:%S', nextPayment),
        missed_payments = 0,
        grace_notified = 0,
        pending_payment = 0,
        status = 'active'
    }

    -- Log
    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'rental_started', citizenid, json.encode({rent = rent, deposit = deposit, payment = paymentMethod})
    })

    UnlockOperation(lockKey)

    TriggerClientEvent('sb_apartments:client:rentalSuccess', source, buildingId, unitId)
    print('[sb_apartments] ' .. citizenid .. ' rented ' .. unitId .. ' for $' .. totalCost)
end)

-- ============================================
-- EXIT APARTMENT
-- ============================================

RegisterNetEvent('sb_apartments:server:exitApartment', function()
    local source = source
    local unitId = PlayerUnits[source]
    if not unitId then return end

    -- Only reset routing bucket in shell mode
    local buildingId = GetBuildingForUnit(unitId)
    if buildingId and IsShellMode(buildingId) then
        SetPlayerRoutingBucket(source, 0)
    end

    -- Temp unlock door so player can walk out
    TempUnlockDoor(unitId, 5000)

    -- Remove occupant (releases bucket if last, only matters in shell mode)
    RemoveOccupant(unitId, source)

    local Player = SBCore.Functions.GetPlayer(source)
    if Player then
        MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
            unitId, 'exited', Player.PlayerData.citizenid, '{}'
        })
    end
end)

-- ============================================
-- DOOR LOCK TOGGLE (owner-controlled)
-- ============================================

RegisterNetEvent('sb_apartments:server:toggleDoorLock', function(unitId)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Must have access (owner or keyholder)
    local hasAccess, accessType = HasAccess(citizenid, unitId)
    if not hasAccess then
        NotifyPlayer(source, 'You don\'t have access to this door', 'error', 3000)
        return
    end

    -- Must be rented
    if not rentalsCache[unitId] then
        NotifyPlayer(source, 'This unit is vacant', 'info', 3000)
        return
    end

    -- Toggle: doorLockState true = owner unlocked, nil/false = default locked
    local isCurrentlyUnlocked = doorLockState[unitId] == true
    if isCurrentlyUnlocked then
        doorLockState[unitId] = nil  -- back to default locked
    else
        doorLockState[unitId] = true  -- owner explicitly unlocks
    end

    local isNowLocked = doorLockState[unitId] ~= true

    -- Update door via sb_doorlock (broadcasts to all clients)
    if GetResourceState('sb_doorlock') == 'started' then
        exports['sb_doorlock']:SetDoorState('apt_' .. unitId, isNowLocked)
    end

    local lockStr = isNowLocked and 'locked' or 'unlocked'
    NotifyPlayer(source, 'Door ' .. lockStr, 'info', 2000)

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'door_' .. lockStr, citizenid, '{}'
    })
end)

-- ============================================
-- END RENTAL
-- ============================================

RegisterNetEvent('sb_apartments:server:endRental', function(unitId)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local rental = rentalsCache[unitId]

    if not rental or rental.citizenid ~= citizenid then
        NotifyPlayer(source, 'You do not rent this unit', 'error', 3000)
        return
    end

    -- Calculate deposit refund
    local missed = rental.missed_payments or 0
    local refundRate = Config.DepositRefund[missed] or 0
    local refund = math.floor(rental.deposit_paid * refundRate)

    if refund > 0 then
        Player.Functions.AddMoney('bank', refund, 'apartment-deposit-return-' .. unitId)
        NotifyPlayer(source, 'Deposit refund: $' .. refund .. ' (' .. math.floor(refundRate * 100) .. '%)', 'success', 5000)
    else
        NotifyPlayer(source, 'Deposit forfeited due to missed payments', 'warning', 5000)
    end

    -- Update database
    MySQL.update('UPDATE sb_apartment_rentals SET status = ?, ended_at = NOW() WHERE unit_id = ? AND citizenid = ? AND status = ?',
        {'ended', unitId, citizenid, 'active'})

    -- Remove keys
    MySQL.query('DELETE FROM sb_apartment_keys WHERE unit_id = ?', {unitId})

    -- Clear cache
    rentalsCache[unitId] = nil
    keysCache[unitId] = nil
    doorLockState[unitId] = nil

    -- Kick out all occupants
    local buildingId = GetBuildingForUnit(unitId)
    local occupants = GetOccupants(unitId)
    local hadOccupants = next(occupants) ~= nil
    for occSrc, _ in pairs(occupants) do
        if buildingId and IsShellMode(buildingId) then
            SetPlayerRoutingBucket(occSrc, 0)
        end
        TriggerClientEvent('sb_apartments:client:forceExit', occSrc, unitId)
        RemoveOccupant(unitId, occSrc)
    end

    -- Log
    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'rental_ended', citizenid, json.encode({voluntary = true, refund = refund})
    })

    -- Door: temp unlock for occupants to leave, then lock
    if GetResourceState('sb_doorlock') == 'started' then
        local doorId = 'apt_' .. unitId
        if hadOccupants then
            exports['sb_doorlock']:SetDoorState(doorId, false)
        end
        SetTimeout(hadOccupants and 5000 or 0, function()
            exports['sb_doorlock']:SetDoorState(doorId, true)
        end)
    end

    TriggerClientEvent('sb_apartments:client:rentalEnded', source, unitId)
    print('[sb_apartments] ' .. citizenid .. ' ended rental of ' .. unitId)
end)

-- ============================================
-- KEY MANAGEMENT
-- ============================================

RegisterNetEvent('sb_apartments:server:giveKey', function(unitId, targetPlayerId)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    local TargetPlayer = SBCore.Functions.GetPlayer(targetPlayerId)
    if not Player or not TargetPlayer then return end

    local citizenid = Player.PlayerData.citizenid
    local targetCitizenid = TargetPlayer.PlayerData.citizenid
    local rental = rentalsCache[unitId]

    if not rental or rental.citizenid ~= citizenid then
        NotifyPlayer(source, 'You do not own this unit', 'error', 3000)
        return
    end

    local currentKeys = keysCache[unitId] or {}
    if #currentKeys >= Config.MaxKeysPerUnit then
        NotifyPlayer(source, 'Maximum keys already given out', 'error', 3000)
        return
    end

    for _, cid in ipairs(currentKeys) do
        if cid == targetCitizenid then
            NotifyPlayer(source, 'This person already has keys', 'error', 3000)
            return
        end
    end

    MySQL.insert('INSERT INTO sb_apartment_keys (unit_id, citizenid, granted_by) VALUES (?, ?, ?)', {
        unitId, targetCitizenid, citizenid
    })

    if not keysCache[unitId] then keysCache[unitId] = {} end
    table.insert(keysCache[unitId], targetCitizenid)

    local ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    NotifyPlayer(source, 'Keys given to ' .. TargetPlayer.PlayerData.charinfo.firstname, 'success', 3000)
    TriggerClientEvent('sb_apartments:client:keyReceived', targetPlayerId, unitId, ownerName)

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'key_given', citizenid, json.encode({to = targetCitizenid})
    })
end)

RegisterNetEvent('sb_apartments:server:revokeKey', function(unitId, targetCitizenid)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local rental = rentalsCache[unitId]

    if not rental or rental.citizenid ~= citizenid then
        NotifyPlayer(source, 'You do not own this unit', 'error', 3000)
        return
    end

    MySQL.query('DELETE FROM sb_apartment_keys WHERE unit_id = ? AND citizenid = ?', {unitId, targetCitizenid})

    if keysCache[unitId] then
        for i, cid in ipairs(keysCache[unitId]) do
            if cid == targetCitizenid then
                table.remove(keysCache[unitId], i)
                break
            end
        end
    end

    NotifyPlayer(source, 'Keys revoked', 'success', 3000)

    -- Notify + kick if online & inside
    local TargetPlayer = SBCore.Functions.GetPlayerByCitizenId(targetCitizenid)
    if TargetPlayer then
        TriggerClientEvent('sb_apartments:client:keyRevoked', TargetPlayer.PlayerData.source, unitId)

        -- If they're inside this unit, kick them out
        local targetSrc = TargetPlayer.PlayerData.source
        if PlayerUnits[targetSrc] == unitId then
            local buildingId = GetBuildingForUnit(unitId)
            if buildingId and IsShellMode(buildingId) then
                SetPlayerRoutingBucket(targetSrc, 0)
            end
            TempUnlockDoor(unitId, 5000)  -- Let them walk out
            TriggerClientEvent('sb_apartments:client:forceExit', targetSrc, unitId)
            RemoveOccupant(unitId, targetSrc)
        end
    end

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'key_revoked', citizenid, json.encode({from = targetCitizenid})
    })
end)

-- ============================================
-- DOORBELL & VISITING SYSTEM
-- ============================================

RegisterNetEvent('sb_apartments:server:ringDoorbell', function(unitId)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- Check if unit is rented
    local rental = rentalsCache[unitId]
    if not rental then
        NotifyPlayer(source, 'This unit is vacant', 'info', 3000)
        return
    end

    -- Don't ring your own doorbell
    local citizenid = Player.PlayerData.citizenid
    if rental.citizenid == citizenid then return end

    -- Check for existing pending doorbell
    local doorbellKey = unitId .. '_' .. source
    if PendingDoorbells[doorbellKey] then
        NotifyPlayer(source, 'Already waiting for response...', 'info', 2000)
        return
    end

    -- Find owner or occupants to notify
    local notified = false

    -- Check occupants first (someone is inside)
    local occupants = GetOccupants(unitId)
    for occSrc, _ in pairs(occupants) do
        TriggerClientEvent('sb_apartments:client:doorbellRing', occSrc, unitId, source, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname)
        notified = true
    end

    -- If no occupants, try to notify online owner
    if not notified then
        local Owner = SBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
        if Owner then
            TriggerClientEvent('sb_apartments:client:doorbellRing', Owner.PlayerData.source, unitId, source, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname)
            notified = true
        end
    end

    if not notified then
        NotifyPlayer(source, 'Nobody is home', 'info', 3000)
        return
    end

    -- Store pending doorbell with timeout
    PendingDoorbells[doorbellKey] = {
        src = source,
        unitId = unitId,
        visitorName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    }

    NotifyPlayer(source, 'Doorbell rung, waiting for response...', 'info', 5000)

    -- Auto-expire after timeout
    SetTimeout(Config.DoorbellTimeout * 1000, function()
        if PendingDoorbells[doorbellKey] then
            PendingDoorbells[doorbellKey] = nil
            -- Notify visitor
            if GetPlayerPing(source) > 0 then  -- Check player is still connected
                NotifyPlayer(source, 'No answer', 'info', 3000)
                TriggerClientEvent('sb_apartments:client:doorbellExpired', source, unitId)
            end
        end
    end)

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'doorbell_ring', citizenid, json.encode({visitor = citizenid})
    })
end)

RegisterNetEvent('sb_apartments:server:acceptVisitor', function(unitId, visitorSrc)
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local doorbellKey = unitId .. '_' .. visitorSrc
    local pending = PendingDoorbells[doorbellKey]
    if not pending then
        NotifyPlayer(source, 'Doorbell expired', 'info', 2000)
        return
    end

    -- Clear pending
    PendingDoorbells[doorbellKey] = nil

    -- Check visitor is still online
    local Visitor = SBCore.Functions.GetPlayer(visitorSrc)
    if not Visitor then
        NotifyPlayer(source, 'Visitor disconnected', 'info', 3000)
        return
    end

    local rental = rentalsCache[unitId]
    local buildingId = rental and rental.building_id
    local building = Config.Buildings[buildingId]
    if not building then return end

    if building.useShells then
        -- Shell mode: allocate bucket for visitor
        local bucket = AllocateBucket(unitId)
        if not bucket then
            NotifyPlayer(source, 'Could not allocate space', 'error', 3000)
            return
        end
        SetPlayerRoutingBucket(visitorSrc, bucket)
    end

    AddOccupant(unitId, visitorSrc)

    -- Temp unlock door for visitor entry
    TempUnlockDoor(unitId, 5000)

    -- Tell visitor to enter (MLO direct - just unlock door and set state)
    TriggerClientEvent('sb_apartments:client:visitorEnter', visitorSrc, {
        unitId = unitId,
        buildingId = buildingId,
        tier = building.tier,
        isVisitor = true
    })

    NotifyPlayer(source, 'Visitor allowed in', 'success', 3000)
    NotifyPlayer(visitorSrc, 'Access granted, entering...', 'success', 3000)

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'visitor_accepted', Player.PlayerData.citizenid, json.encode({visitor = Visitor.PlayerData.citizenid})
    })
end)

RegisterNetEvent('sb_apartments:server:denyVisitor', function(unitId, visitorSrc)
    local source = source

    local doorbellKey = unitId .. '_' .. visitorSrc
    local pending = PendingDoorbells[doorbellKey]
    if not pending then return end

    PendingDoorbells[doorbellKey] = nil

    -- Notify visitor
    if GetPlayerPing(visitorSrc) > 0 then
        NotifyPlayer(visitorSrc, 'Access denied', 'error', 3000)
        TriggerClientEvent('sb_apartments:client:doorbellDenied', visitorSrc, unitId)
    end

    local Player = SBCore.Functions.GetPlayer(source)
    if Player then
        MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
            unitId, 'visitor_denied', Player.PlayerData.citizenid, json.encode({visitor = visitorSrc})
        })
    end
end)

-- ============================================
-- RENT PAYMENT LOOP (SAFE - no offline deduction)
-- ============================================

function RentPaymentLoop()
    while true do
        Wait(Config.RentCheckInterval)

        local now = os.time()

        for unitId, rental in pairs(rentalsCache) do
            if rental.status == 'active' then
                local nextPayment = ParseDateTime(rental.next_payment)

                -- Payment reminder (1 day before)
                if not rental._reminded and (nextPayment - now) <= Config.PaymentReminder and (nextPayment - now) > 0 then
                    local Player = SBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
                    if Player then
                        TriggerClientEvent('sb_apartments:client:rentDue', Player.PlayerData.source, unitId, rental.rent_amount, 0)
                    end
                    rental._reminded = true
                end

                -- Payment is due
                if now >= nextPayment then
                    -- Check grace period
                    local graceDue = nextPayment + Config.GracePeriod

                    if now < graceDue then
                        -- Still in grace period - only collect from online players
                        local Player = SBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
                        if Player then
                            ProcessOnlinePayment(unitId, rental, Player)
                        end
                        -- If offline, mark as pending (will collect on login)
                        if rental.pending_payment == 0 then
                            MySQL.update('UPDATE sb_apartment_rentals SET pending_payment = 1 WHERE unit_id = ? AND status = ?', {unitId, 'active'})
                            rental.pending_payment = 1
                        end
                    else
                        -- Grace period expired
                        local Player = SBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
                        if Player then
                            -- Try to collect
                            local paid = ProcessOnlinePayment(unitId, rental, Player)
                            if not paid then
                                HandleMissedPayment(unitId, rental, Player)
                            end
                        else
                            -- Player offline and grace expired - count as missed
                            HandleMissedPayment(unitId, rental, nil)
                        end
                    end
                end
            end
        end
    end
end

function ProcessOnlinePayment(unitId, rental, Player)
    local rent = rental.rent_amount

    if Player.Functions.GetMoney('bank') >= rent then
        Player.Functions.RemoveMoney('bank', rent, 'apartment-rent-' .. unitId)

        local nextPayment = os.time() + (Config.RentCycle / 1000)
        MySQL.update('UPDATE sb_apartment_rentals SET next_payment = FROM_UNIXTIME(?), missed_payments = 0, pending_payment = 0, grace_notified = 0 WHERE unit_id = ? AND status = ?',
            {nextPayment, unitId, 'active'})

        rental.next_payment = os.date('%Y-%m-%d %H:%M:%S', nextPayment)
        rental.missed_payments = 0
        rental.pending_payment = 0
        rental.grace_notified = 0
        rental._reminded = nil

        NotifyPlayer(Player.PlayerData.source, 'Rent of $' .. rent .. ' paid automatically', 'info', 5000)
        return true
    end

    return false
end

function HandleMissedPayment(unitId, rental, Player)
    local missedPayments = (rental.missed_payments or 0) + 1

    MySQL.update('UPDATE sb_apartment_rentals SET missed_payments = ?, pending_payment = 0, grace_notified = 0 WHERE unit_id = ? AND status = ?',
        {missedPayments, unitId, 'active'})

    rental.missed_payments = missedPayments
    rental.pending_payment = 0
    rental.grace_notified = 0
    rental._reminded = nil

    -- Advance next_payment so we don't keep re-checking
    local nextPayment = os.time() + (Config.RentCycle / 1000)
    MySQL.update('UPDATE sb_apartment_rentals SET next_payment = FROM_UNIXTIME(?) WHERE unit_id = ? AND status = ?',
        {nextPayment, unitId, 'active'})
    rental.next_payment = os.date('%Y-%m-%d %H:%M:%S', nextPayment)

    if Player then
        TriggerClientEvent('sb_apartments:client:rentDue', Player.PlayerData.source, unitId, rental.rent_amount, missedPayments)
    end

    -- Evict after too many missed payments
    if missedPayments >= Config.MaxMissedPayments then
        EvictTenant(unitId, rental)
    end

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'payment_missed', rental.citizenid, json.encode({missed = missedPayments})
    })
end

-- Collect pending payments on player login
RegisterNetEvent('SBCore:Server:OnPlayerLoaded', function()
    local source = source
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Check for pending payments
    for unitId, rental in pairs(rentalsCache) do
        if rental.citizenid == citizenid and rental.pending_payment == 1 then
            Wait(5000) -- Give client time to load
            ProcessOnlinePayment(unitId, rental, Player)
        end
    end
end)

-- ============================================
-- EVICTION
-- ============================================

function EvictTenant(unitId, rental)
    MySQL.update('UPDATE sb_apartment_rentals SET status = ?, ended_at = NOW() WHERE unit_id = ? AND status = ?',
        {'evicted', unitId, 'active'})

    MySQL.query('DELETE FROM sb_apartment_keys WHERE unit_id = ?', {unitId})

    -- Kick occupants
    local buildingId = GetBuildingForUnit(unitId)
    local occupants = GetOccupants(unitId)
    local hadOccupants = next(occupants) ~= nil
    for occSrc, _ in pairs(occupants) do
        if buildingId and IsShellMode(buildingId) then
            SetPlayerRoutingBucket(occSrc, 0)
        end
        TriggerClientEvent('sb_apartments:client:forceExit', occSrc, unitId)
        RemoveOccupant(unitId, occSrc)
    end

    -- Notify player if online
    local Player = SBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
    if Player then
        TriggerClientEvent('sb_apartments:client:evicted', Player.PlayerData.source, unitId)
    end

    rentalsCache[unitId] = nil
    keysCache[unitId] = nil
    doorLockState[unitId] = nil

    -- Door: temp unlock for occupants to leave, then lock
    if GetResourceState('sb_doorlock') == 'started' then
        local doorId = 'apt_' .. unitId
        if hadOccupants then
            exports['sb_doorlock']:SetDoorState(doorId, false)
        end
        SetTimeout(hadOccupants and 5000 or 0, function()
            exports['sb_doorlock']:SetDoorState(doorId, true)
        end)
    end

    MySQL.insert('INSERT INTO sb_apartment_log (unit_id, action, citizenid, details) VALUES (?, ?, ?, ?)', {
        unitId, 'evicted', rental.citizenid, json.encode({reason = 'missed_payments'})
    })

    print('[sb_apartments] ' .. rental.citizenid .. ' evicted from ' .. unitId)
end

-- ============================================
-- PLAYER DISCONNECT CLEANUP
-- ============================================

AddEventHandler('playerDropped', function()
    local source = source
    local unitId = PlayerUnits[source]

    if unitId then
        RemoveOccupant(unitId, source)
    end

    -- Clean up any pending doorbells from this player
    for key, doorbell in pairs(PendingDoorbells) do
        if doorbell.src == source then
            PendingDoorbells[key] = nil
        end
    end
end)

-- ============================================
-- RESOURCE RESTART CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Return all players to bucket 0 (safety net for shell mode)
    for src, unitId in pairs(PlayerUnits) do
        pcall(function()
            local buildingId = GetBuildingForUnit(unitId)
            if buildingId and IsShellMode(buildingId) then
                SetPlayerRoutingBucket(src, 0)
            end
        end)
    end
end)

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

function ParseDateTime(dateStr)
    if not dateStr then return 0 end
    if type(dateStr) == 'number' then return dateStr end

    dateStr = tostring(dateStr)
    local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
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

    return 0
end

-- ============================================
-- ADMIN COMMANDS
-- ============================================

RegisterCommand('apt_forcevacate', function(source, args)
    if source > 0 and not exports['sb_admin']:IsAdmin() then return end

    local unitId = args[1]
    if not unitId then
        print('[sb_apartments] Usage: apt_forcevacate <unitId>')
        return
    end

    local rental = rentalsCache[unitId]
    if not rental then
        print('[sb_apartments] Unit ' .. unitId .. ' is not rented')
        return
    end

    EvictTenant(unitId, rental)
    print('[sb_apartments] Force-vacated ' .. unitId)
end, false)

RegisterCommand('apt_inspect', function(source, args)
    if source > 0 and not exports['sb_admin']:IsAdmin() then return end

    local unitId = args[1]
    if not unitId then
        print('[sb_apartments] Usage: apt_inspect <unitId>')
        return
    end

    local rental = rentalsCache[unitId]
    if rental then
        print('[sb_apartments] Unit: ' .. unitId)
        print('  Renter: ' .. rental.citizenid)
        print('  Rent: $' .. rental.rent_amount)
        print('  Missed: ' .. (rental.missed_payments or 0))
        print('  Next Payment: ' .. (rental.next_payment or 'N/A'))
        print('  Bucket: ' .. (UnitBuckets[unitId] or 'none'))
        local occupantList = {}
        if UnitOccupants[unitId] then
            for s in pairs(UnitOccupants[unitId]) do occupantList[#occupantList+1] = tostring(s) end
        end
        print('  Occupants: ' .. (#occupantList > 0 and table.concat(occupantList, ', ') or 'none'))
    else
        print('[sb_apartments] Unit ' .. unitId .. ' is vacant')
    end
end, false)

RegisterCommand('apt_resetbuckets', function(source, args)
    if source > 0 and not exports['sb_admin']:IsAdmin() then return end

    for src, unitId in pairs(PlayerUnits) do
        pcall(function()
            SetPlayerRoutingBucket(src, 0)
        end)
    end

    BucketPool = {}
    UnitBuckets = {}
    UnitOccupants = {}
    PlayerUnits = {}

    for i = 1, 62 do
        BucketPool[i] = nil
    end

    print('[sb_apartments] All buckets reset')
end, false)

-- ============================================
-- EXPORTS
-- ============================================

exports('HasAccess', function(citizenid, unitId)
    return HasAccess(citizenid, unitId)
end)

exports('GetUnitRenter', function(unitId)
    local rental = rentalsCache[unitId]
    return rental and rental.citizenid or nil
end)

exports('IsInsideApartment', function(src)
    return PlayerUnits[src] ~= nil
end)

exports('GetApartmentBucket', function(unitId)
    return GetUnitBucket(unitId)
end)
