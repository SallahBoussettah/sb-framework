--[[
    Everyday Chaos RP - Fuel System (Server)
    Author: Salah Eddine Boussettah

    Handles: Fuel sync, payments, jerry can management
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- FUEL SYNC
-- ============================================================================

-- Store fuel levels for persistence (by netId -> fuel level)
local vehicleFuelLevels = {}

-- Sync fuel from client and broadcast to all nearby players
RegisterNetEvent('sb_fuel:server:syncFuel', function(netId, fuelLevel)
    local src = source
    if not netId or not fuelLevel then return end

    -- Validate fuel level
    fuelLevel = math.max(0.0, math.min(100.0, fuelLevel))
    vehicleFuelLevels[netId] = fuelLevel

    -- Also update database if this is an owned vehicle
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then
            -- Update player_vehicles table
            MySQL.Async.execute('UPDATE player_vehicles SET fuel = @fuel WHERE plate = @plate', {
                ['@fuel'] = fuelLevel,
                ['@plate'] = plate
            })
        end

        -- Broadcast fuel update to ALL players (they'll ignore if not relevant)
        -- This ensures passengers and nearby players see the correct fuel level
        TriggerClientEvent('sb_fuel:client:syncFuelBroadcast', -1, netId, fuelLevel)
    end
end)

-- Client requests fuel level
RegisterNetEvent('sb_fuel:server:requestFuel', function(netId, plate)
    local src = source

    -- First check cached level
    if vehicleFuelLevels[netId] then
        TriggerClientEvent('sb_fuel:client:setFuel', src, netId, vehicleFuelLevels[netId])
        return
    end

    -- Check database for owned vehicles
    if plate then
        MySQL.Async.fetchScalar('SELECT fuel FROM player_vehicles WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(fuel)
            if fuel then
                vehicleFuelLevels[netId] = fuel
                TriggerClientEvent('sb_fuel:client:setFuel', src, netId, fuel)
            else
                -- Not an owned vehicle - use default or random
                local randomFuel = math.random(30, 80)
                vehicleFuelLevels[netId] = randomFuel
                TriggerClientEvent('sb_fuel:client:setFuel', src, netId, randomFuel)
            end
        end)
    else
        -- Random fuel for NPC vehicles
        local randomFuel = math.random(30, 80)
        vehicleFuelLevels[netId] = randomFuel
        TriggerClientEvent('sb_fuel:client:setFuel', src, netId, randomFuel)
    end
end)

-- ============================================================================
-- PAYMENT HANDLING (FIX-005: Pre-authorization system)
-- ============================================================================

-- Track fuel authorizations per player
local fuelAuthorizations = {}

-- Authorize (reserve) money before refueling starts
-- This prevents the exploit where player spends money during refueling
SB.Functions.CreateCallback('sb_fuel:server:authorizeFuel', function(source, cb, estimatedCost)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 0, 'Player not found')
        return
    end

    -- Validate
    if not estimatedCost or estimatedCost <= 0 then
        cb(false, 0, 'Invalid amount')
        return
    end

    -- Round to 2 decimals
    estimatedCost = math.floor(estimatedCost * 100 + 0.5) / 100

    -- Check if already has authorization (prevent double-auth)
    if fuelAuthorizations[source] then
        cb(false, 0, 'Already refueling')
        return
    end

    -- Check money (cash + bank)
    local cash = Player.Functions.GetMoney('cash')
    local bank = Player.Functions.GetMoney('bank')
    local totalMoney = cash + bank

    -- Authorize up to what player can afford
    local authorizedAmount = math.min(estimatedCost, totalMoney)

    if authorizedAmount < 1 then
        cb(false, 0, 'Not enough money')
        return
    end

    -- Remove money as authorization (will refund unused at end)
    local remainingToAuth = authorizedAmount
    local fromCash = 0
    local fromBank = 0

    if cash >= remainingToAuth then
        fromCash = remainingToAuth
        Player.Functions.RemoveMoney('cash', fromCash, 'fuel-authorization')
    else
        fromCash = cash
        if fromCash > 0 then
            Player.Functions.RemoveMoney('cash', fromCash, 'fuel-authorization')
        end
        remainingToAuth = remainingToAuth - fromCash

        fromBank = remainingToAuth
        if fromBank > 0 then
            Player.Functions.RemoveMoney('bank', fromBank, 'fuel-authorization')
        end
    end

    -- Store authorization
    fuelAuthorizations[source] = {
        amount = authorizedAmount,
        fromCash = fromCash,
        fromBank = fromBank,
        timestamp = os.time()
    }

    cb(true, authorizedAmount, 'Authorized')
end)

-- Finalize fuel charge - deduct actual amount, refund unused
RegisterNetEvent('sb_fuel:server:finalizeFuel', function(actualCost)
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    local auth = fuelAuthorizations[src]
    if not auth then
        -- No authorization found - shouldn't happen
        return
    end

    -- Clear authorization
    fuelAuthorizations[src] = nil

    if not Player then
        -- Player left - nothing to refund
        return
    end

    -- Validate actual cost
    actualCost = actualCost or 0
    actualCost = math.floor(actualCost * 100 + 0.5) / 100
    actualCost = math.max(0, math.min(auth.amount, actualCost))

    -- Calculate refund
    local refund = auth.amount - actualCost

    if refund > 0.01 then
        -- Refund to the source(s) proportionally
        -- Prioritize refunding to bank first (since we took from cash first)
        local bankRefund = math.min(refund, auth.fromBank)
        local cashRefund = refund - bankRefund

        if bankRefund > 0 then
            Player.Functions.AddMoney('bank', bankRefund, 'fuel-refund')
        end
        if cashRefund > 0 then
            Player.Functions.AddMoney('cash', cashRefund, 'fuel-refund')
        end
    end

    -- Log bank transaction if any was paid from bank (after refund calculation)
    local actualFromBank = auth.fromBank - (refund > 0.01 and math.min(refund, auth.fromBank) or 0)
    if actualFromBank > 0.01 then
        local citizenid = Player.PlayerData.citizenid
        local balanceAfter = Player.Functions.GetMoney('bank')
        exports['sb_banking']:LogPurchase(citizenid, math.floor(actualFromBank), balanceAfter, 'Fuel Purchase - Gas Station')
    end
end)

-- Cancel fuel authorization (called if refueling is cancelled before any fuel added)
RegisterNetEvent('sb_fuel:server:cancelFuelAuth', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    local auth = fuelAuthorizations[src]
    if not auth then return end

    -- Clear authorization
    fuelAuthorizations[src] = nil

    if not Player then return end

    -- Full refund
    if auth.fromBank > 0 then
        Player.Functions.AddMoney('bank', auth.fromBank, 'fuel-auth-cancelled')
    end
    if auth.fromCash > 0 then
        Player.Functions.AddMoney('cash', auth.fromCash, 'fuel-auth-cancelled')
    end
end)

-- Clear stale authorization (called before new refuel attempt to reset stuck state)
-- This handles edge cases where authorization wasn't properly cleared
RegisterNetEvent('sb_fuel:server:clearStaleAuth', function()
    local src = source
    local auth = fuelAuthorizations[src]

    if auth then
        -- Check if authorization is older than 60 seconds (stale)
        local age = os.time() - (auth.timestamp or 0)
        if age > 60 then
            local Player = SB.Functions.GetPlayer(src)
            if Player then
                -- Refund the stale authorization
                if auth.fromBank > 0 then
                    Player.Functions.AddMoney('bank', auth.fromBank, 'fuel-auth-stale-refund')
                end
                if auth.fromCash > 0 then
                    Player.Functions.AddMoney('cash', auth.fromCash, 'fuel-auth-stale-refund')
                end
                print(('[sb_fuel] Cleared stale fuel authorization for player %d (age: %ds)'):format(src, age))
            end
            fuelAuthorizations[src] = nil
        end
    end
end)

-- Clean up authorizations on player disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source
    if fuelAuthorizations[src] then
        -- Authorization lost on disconnect - money was already taken
        -- This is intentional to prevent disconnect exploit
        fuelAuthorizations[src] = nil
    end
end)

-- Periodic cleanup of stale authorizations (safety net)
CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds

        local now = os.time()
        for src, auth in pairs(fuelAuthorizations) do
            local age = now - (auth.timestamp or 0)
            -- Clear authorizations older than 2 minutes
            if age > 120 then
                local Player = SB.Functions.GetPlayer(src)
                if Player then
                    -- Refund
                    if auth.fromBank > 0 then
                        Player.Functions.AddMoney('bank', auth.fromBank, 'fuel-auth-timeout-refund')
                    end
                    if auth.fromCash > 0 then
                        Player.Functions.AddMoney('cash', auth.fromCash, 'fuel-auth-timeout-refund')
                    end
                end
                fuelAuthorizations[src] = nil
                print(('[sb_fuel] Auto-cleared stuck fuel authorization for player %d (age: %ds)'):format(src, age))
            end
        end
    end
end)

-- Legacy charge event (kept for backwards compatibility, but shouldn't be used)
RegisterNetEvent('sb_fuel:server:chargeFuel', function(amount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Validate and round amount to 2 decimal places (prevent floating point errors)
    if not amount or amount <= 0 then return end
    amount = math.floor(amount * 100 + 0.5) / 100

    -- Skip if rounded to 0
    if amount <= 0 then return end

    -- Try cash first
    local cash = Player.Functions.GetMoney('cash')
    if cash >= amount then
        Player.Functions.RemoveMoney('cash', amount, 'fuel-purchase')
    else
        -- Try bank
        local bank = Player.Functions.GetMoney('bank')
        if bank >= amount then
            Player.Functions.RemoveMoney('bank', amount, 'fuel-purchase')
        else
            -- Not enough money (shouldn't happen - client checks first)
            TriggerClientEvent('sb_notify', src, 'Not enough money', 'error', 3000)
        end
    end
end)

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Callback to get jerry can info for client
SB.Functions.CreateCallback('sb_fuel:server:getJerryCanInfo', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    -- Check if player has jerry can (use sb_inventory export)
    local jerryCanItems = exports['sb_inventory']:GetItemsByName(source, Config.JerryCan.item)
    if not jerryCanItems or #jerryCanItems == 0 then
        cb(nil)
        return
    end

    -- Return first jerry can's info
    local jerrycan = jerryCanItems[1]
    cb({
        slot = jerrycan.slot,
        fuel = (jerrycan.metadata and jerrycan.metadata.fuel) or 0
    })
end)

-- Callback to check if player can syphon (has syphon kit + jerry can with space)
SB.Functions.CreateCallback('sb_fuel:server:canSyphon', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local result = {
        hasSyphonKit = true,  -- Default to true if no item required
        hasJerryCan = false,
        jerryFuel = 0,
        jerrySlot = nil
    }

    -- Check for syphon kit if required (use sb_inventory export)
    if Config.Syphon.item then
        result.hasSyphonKit = exports['sb_inventory']:HasItem(source, Config.Syphon.item, 1)
    end

    -- Check for jerry can (use sb_inventory export)
    local jerryCanItems = exports['sb_inventory']:GetItemsByName(source, Config.JerryCan.item)
    if jerryCanItems and #jerryCanItems > 0 then
        local jerrycan = jerryCanItems[1]
        result.hasJerryCan = true
        result.jerryFuel = (jerrycan.metadata and jerrycan.metadata.fuel) or 0
        result.jerrySlot = jerrycan.slot
    end

    cb(result)
end)

-- ============================================================================
-- JERRY CAN MANAGEMENT
-- ============================================================================

-- Fill jerry can at pump
RegisterNetEvent('sb_fuel:server:fillJerryCan', function(cost, fuelAmount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Validate and round cost
    if not cost or cost <= 0 or not fuelAmount then return end
    cost = math.floor(cost * 100 + 0.5) / 100

    -- Check money
    local cash = Player.Functions.GetMoney('cash')
    if cash < cost then
        TriggerClientEvent('sb_notify', src, 'Not enough money', 'error', 3000)
        return
    end

    -- Remove money
    Player.Functions.RemoveMoney('cash', cost, 'jerrycan-refill')

    -- Find jerry can in inventory and update metadata (use sb_inventory export)
    local inventory = exports['sb_inventory']:GetItemsByName(src, Config.JerryCan.item)
    if inventory and #inventory > 0 then
        local item = inventory[1]
        -- Update the item's metadata
        exports['sb_inventory']:SetItemMetadata(src, item.slot, { fuel = fuelAmount })
    end
end)

-- Update jerry can fuel amount
RegisterNetEvent('sb_fuel:server:updateJerryCan', function(slot, fuelAmount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then
        print('[sb_fuel:debug] updateJerryCan: Player not found for source ' .. tostring(src))
        return
    end

    -- Validate
    if not slot or not fuelAmount then
        print('[sb_fuel:debug] updateJerryCan: invalid params slot=' .. tostring(slot) .. ' fuel=' .. tostring(fuelAmount))
        return
    end
    fuelAmount = math.max(0, math.min(Config.JerryCan.maxCapacity, fuelAmount))

    print('[sb_fuel:debug] updateJerryCan: slot=' .. tostring(slot) .. ' fuelAmount=' .. tostring(fuelAmount))

    -- Update metadata
    local success = exports['sb_inventory']:SetItemMetadata(src, slot, { fuel = fuelAmount })
    print('[sb_fuel:debug] SetItemMetadata result=' .. tostring(success))
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Give fuel to vehicle
RegisterCommand('setfuel', function(source, args, rawCommand)
    local src = source
    if src == 0 then
        -- Console
        print('[sb_fuel] Usage: setfuel [playerid] [amount]')
        return
    end

    -- Check permission
    if not IsPlayerAceAllowed(src, 'command.sb_admin') then
        TriggerClientEvent('sb_notify', src, 'No permission', 'error', 3000)
        return
    end

    local targetId = tonumber(args[1]) or src
    local amount = tonumber(args[2]) or 100

    amount = math.max(0, math.min(100, amount))

    TriggerClientEvent('sb_fuel:client:adminSetFuel', targetId, amount)
    TriggerClientEvent('sb_notify', src, string.format('Set fuel to %d%% for player %d', amount, targetId), 'success', 3000)
end, false)

-- Give jerry can (with fuel)
RegisterCommand('givejerrycan', function(source, args, rawCommand)
    local src = source
    if src == 0 then return end

    if not IsPlayerAceAllowed(src, 'command.sb_admin') then
        TriggerClientEvent('sb_notify', src, 'No permission', 'error', 3000)
        return
    end

    local targetId = tonumber(args[1]) or src
    local fuelAmount = tonumber(args[2]) or Config.JerryCan.maxCapacity

    local Player = SB.Functions.GetPlayer(targetId)
    if not Player then
        TriggerClientEvent('sb_notify', src, 'Player not found', 'error', 3000)
        return
    end

    -- Add jerry can with fuel metadata
    local success = exports['sb_inventory']:AddItem(targetId, Config.JerryCan.item, 1, { fuel = fuelAmount }, nil, true)
    if success then
        TriggerClientEvent('sb_notify', src, string.format('Gave jerry can (%dL) to player %d', fuelAmount, targetId), 'success', 3000)
        TriggerClientEvent('sb_notify', targetId, string.format('Received jerry can with %dL of fuel', fuelAmount), 'success', 3000)
    else
        TriggerClientEvent('sb_notify', src, 'Failed to give jerry can', 'error', 3000)
    end
end, false)

-- ============================================================================
-- ITEM REGISTRATION
-- ============================================================================

-- Register jerry can as usable item
CreateThread(function()
    Wait(1000)

    -- Register with sb_core
    SB.Functions.CreateUseableItem(Config.JerryCan.item, function(source, item)
        TriggerClientEvent('sb_fuel:client:useJerryCan', source, item)
    end)

    -- Register syphon kit if exists
    if Config.Syphon.item and Config.Syphon.enabled then
        -- Syphon kit doesn't need to be usable - it's just checked for presence
    end
end)


-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Get vehicle fuel from server cache
exports('GetVehicleFuel', function(netId)
    return vehicleFuelLevels[netId] or 100.0
end)

-- Set vehicle fuel in server cache
exports('SetVehicleFuel', function(netId, fuel)
    fuel = math.max(0.0, math.min(100.0, fuel))
    vehicleFuelLevels[netId] = fuel
    return true
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Fuel levels will be lost on restart - database saves handle owned vehicles
end)

-- Clean up fuel cache when vehicle is deleted
AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and vehicleFuelLevels[netId] then
        vehicleFuelLevels[netId] = nil
    end
end)
