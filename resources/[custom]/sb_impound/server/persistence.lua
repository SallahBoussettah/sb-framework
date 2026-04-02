--[[
    Everyday Chaos RP - Vehicle Persistence (Server)
    Author: Salah Eddine Boussettah

    Handles: Server-side vehicle tracking, disconnect timeout, auto-impound

    IMPORTANT: Other scripts must call RegisterSpawnedVehicle when spawning player vehicles!
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- Server-side tracking of ALL spawned player vehicles
-- [plate] = { citizenid, netId, model, props, spawnTime, lastUpdate }
local spawnedVehicles = {}

-- Track abandoned vehicles after owner disconnects
-- [plate] = { citizenid, timestamp, props, impoundLocation }
local abandonedVehicles = {}

-- Track which vehicles have been taken by others (stolen)
local stolenVehicles = {} -- [plate] = true

print('^2[sb_impound]^7 Vehicle Persistence System loaded')

-- ============================================================================
-- DELETE VEHICLE FROM WORLD (server-side first, client fallback)
-- ============================================================================

function DeleteVehicleFromWorld(plate, netId)
    local deleted = false

    -- Try server-side deletion first (works for server-spawned persistent vehicles)
    if netId then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
            deleted = true
            print('[sb_impound] Deleted server entity for ' .. plate .. ' (netId: ' .. netId .. ')')
        end
    end

    -- Always also ask clients to try (catches edge cases where netId changed)
    TriggerClientEvent('sb_impound:client:deleteVehicle', -1, plate)

    if not deleted then
        print('[sb_impound] Server entity not found for ' .. plate .. ', requested client-side deletion')
    end
end

-- ============================================================================
-- VEHICLE REGISTRATION (Called by other scripts when spawning vehicles)
-- ============================================================================

function RegisterSpawnedVehicle(plate, citizenid, netId, model, props)
    if not plate or not citizenid then return false end

    local cleanPlate = plate:gsub('%s+', ''):upper()

    spawnedVehicles[cleanPlate] = {
        citizenid = citizenid,
        netId = netId,
        model = model,
        props = props,
        spawnTime = os.time(),
        lastUpdate = os.time()
    }

    print('[sb_impound] Registered spawned vehicle: ' .. cleanPlate .. ' for ' .. citizenid)
    return true
end

function UnregisterSpawnedVehicle(plate)
    if not plate then return end
    local cleanPlate = plate:gsub('%s+', ''):upper()
    spawnedVehicles[cleanPlate] = nil
    print('[sb_impound] Unregistered vehicle: ' .. cleanPlate)
end

function UpdateVehicleProps(plate, props, netId)
    if not plate then return end
    local cleanPlate = plate:gsub('%s+', ''):upper()

    if spawnedVehicles[cleanPlate] then
        spawnedVehicles[cleanPlate].props = props
        spawnedVehicles[cleanPlate].lastUpdate = os.time()
        if netId then
            spawnedVehicles[cleanPlate].netId = netId
        end
    end
end

-- Exports for other scripts
exports('RegisterSpawnedVehicle', RegisterSpawnedVehicle)
exports('UnregisterSpawnedVehicle', UnregisterSpawnedVehicle)
exports('UpdateVehicleProps', UpdateVehicleProps)

-- ============================================================================
-- SERVER EVENT: REGISTER VEHICLE (called by other scripts when spawning)
-- ============================================================================

RegisterNetEvent('sb_impound:server:registerVehicle', function(plate, netId, model, props)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    RegisterSpawnedVehicle(plate, citizenid, netId, model, props)
end)

-- ============================================================================
-- PLAYER DISCONNECT - MARK VEHICLES AS ABANDONED
-- ============================================================================

AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    print('[sb_impound] Player ' .. citizenid .. ' disconnected, checking their vehicles...')

    -- Find all spawned vehicles owned by this player
    local playerVehicleCount = 0
    for plate, data in pairs(spawnedVehicles) do
        if data.citizenid == citizenid then
            playerVehicleCount = playerVehicleCount + 1

            -- Skip rental vehicles - sb_rental enforcement handles their lifecycle
            if plate:sub(1, 3) == 'RNT' then
                print('[sb_impound] Vehicle ' .. plate .. ' is a rental, skipping impound (sb_rental handles it)')
                spawnedVehicles[plate] = nil -- Remove from impound tracking
            -- Check if vehicle was stolen (someone else is driving it)
            elseif stolenVehicles[plate] then
                print('[sb_impound] Vehicle ' .. plate .. ' was stolen, leaving in world')
                spawnedVehicles[plate] = nil -- Remove from our tracking
            else
                -- Request latest props from any client that can see it
                TriggerClientEvent('sb_impound:client:getVehiclePropsForAbandoned', -1, plate, data.netId)

                -- Mark as abandoned with stored data
                abandonedVehicles[plate] = {
                    citizenid = citizenid,
                    timestamp = os.time(),
                    props = data.props, -- Use stored props as fallback
                    netId = data.netId,
                    model = data.model,
                    impoundLocation = 'lspd' -- Default, could calculate based on coords
                }

                print('[sb_impound] Vehicle ' .. plate .. ' marked as abandoned, will impound in ' .. Config.DisconnectTimeout .. ' seconds')
            end
        end
    end

    if playerVehicleCount == 0 then
        print('[sb_impound] No spawned vehicles found for ' .. citizenid)
    end
end)

-- ============================================================================
-- UPDATE ABANDONED VEHICLE PROPS (if a client can still see it)
-- ============================================================================

RegisterNetEvent('sb_impound:server:updateAbandonedProps', function(plate, props, netId)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    if abandonedVehicles[cleanPlate] then
        abandonedVehicles[cleanPlate].props = props
        abandonedVehicles[cleanPlate].netId = netId
        print('[sb_impound] Updated props for abandoned vehicle: ' .. cleanPlate)
    end
end)

-- ============================================================================
-- VEHICLE ENTERED BY SOMEONE (STOLEN CHECK + RE-REGISTRATION)
-- ============================================================================

RegisterNetEvent('sb_impound:server:vehicleEntered', function(plate, driverCitizenId, netId, model)
    local cleanPlate = plate:gsub('%s+', ''):upper()

    -- Check if this is a spawned player vehicle
    local vehicleData = spawnedVehicles[cleanPlate]
    if not vehicleData then
        -- Also check abandoned
        vehicleData = abandonedVehicles[cleanPlate]
    end

    -- If vehicle is not tracked, check if it's an owned vehicle that needs re-registration
    if not vehicleData then
        -- Skip rental vehicles - they aren't in player_vehicles, sb_rental handles them
        if cleanPlate:sub(1, 3) == 'RNT' then
            return
        end

        -- Check database for ownership (handle plates with/without spaces)
        local dbVehicle = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND state = 0', { cleanPlate })

        if dbVehicle then
            -- This is a player-owned vehicle that's out in the world but not tracked
            if dbVehicle.citizenid == driverCitizenId then
                -- Owner is driving - re-register the vehicle
                spawnedVehicles[cleanPlate] = {
                    citizenid = driverCitizenId,
                    netId = netId or 0,
                    model = model or 'unknown',
                    props = nil,
                    spawnTime = os.time(),
                    lastUpdate = os.time()
                }
                print('[sb_impound] Re-registered vehicle ' .. cleanPlate .. ' for owner ' .. driverCitizenId)
                return
            else
                -- Someone else is driving an owned vehicle - mark as stolen
                stolenVehicles[cleanPlate] = true
                print('[sb_impound] Vehicle ' .. cleanPlate .. ' being driven by non-owner, marking as stolen')
                return
            end
        end

        -- Vehicle not in database with state 0, ignore
        return
    end

    -- Check if the person entering is the owner
    if driverCitizenId == vehicleData.citizenid then
        -- Owner is driving, remove from abandoned if present
        if abandonedVehicles[cleanPlate] then
            abandonedVehicles[cleanPlate] = nil
            -- Re-add to spawned vehicles
            spawnedVehicles[cleanPlate] = vehicleData
            print('[sb_impound] Owner returned to vehicle ' .. cleanPlate .. ', removing from abandoned list')
        end
        return
    end

    -- Someone else entered - vehicle is now stolen
    stolenVehicles[cleanPlate] = true
    abandonedVehicles[cleanPlate] = nil
    print('[sb_impound] Vehicle ' .. cleanPlate .. ' was taken by another player, marking as stolen')
end)

-- ============================================================================
-- PLAYER RECONNECTS - CHECK THEIR VEHICLES
-- ============================================================================

RegisterNetEvent('sb_impound:server:playerReconnected', function()
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local foundVehicles = {}

    -- Check if any of their abandoned vehicles are still pending
    for plate, data in pairs(abandonedVehicles) do
        if data.citizenid == citizenid then
            foundVehicles[#foundVehicles + 1] = plate
        end
    end

    if #foundVehicles > 0 then
        for _, plate in ipairs(foundVehicles) do
            -- Owner is back! Remove from abandoned list
            abandonedVehicles[plate] = nil

            -- Re-register the vehicle as spawned (if it still exists)
            -- The client will verify and update
            print('[sb_impound] Player reconnected, vehicle ' .. plate .. ' no longer abandoned')
        end

        Wait(2000)
        TriggerClientEvent('sb_notify:client:Notify', src, 'Your vehicle is still where you left it', 'info', 5000)
    end

    -- Check if any of their vehicles were stolen while away
    local stolenCount = 0
    for plate, _ in pairs(stolenVehicles) do
        local vehicle = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
        if vehicle and vehicle.citizenid == citizenid then
            stolenCount = stolenCount + 1
        end
    end

    if stolenCount > 0 then
        Wait(3000)
        TriggerClientEvent('sb_notify:client:Notify', src, 'Warning: ' .. stolenCount .. ' of your vehicles may have been stolen while you were away!', 'error', 8000)
    end
end)

-- ============================================================================
-- TIMEOUT CHECK THREAD
-- ============================================================================

CreateThread(function()
    Wait(10000) -- Initial delay

    while true do
        Wait(Config.CheckInterval * 1000)

        -- Skip if no abandoned vehicles (performance optimization)
        if next(abandonedVehicles) == nil then
            goto continue
        end

        local now = os.time()
        local toImpound = {}

        -- Check each abandoned vehicle
        for plate, data in pairs(abandonedVehicles) do
            local elapsed = now - data.timestamp

            if elapsed >= Config.DisconnectTimeout then
                -- Time's up - impound this vehicle
                toImpound[#toImpound + 1] = {
                    plate = plate,
                    data = data
                }
            else
                -- Debug: Show time remaining
                local remaining = Config.DisconnectTimeout - elapsed
                if remaining % 60 < Config.CheckInterval then
                    print('[sb_impound] Vehicle ' .. plate .. ' will be impounded in ' .. math.floor(remaining) .. ' seconds')
                end
            end
        end

        -- Process impounds
        for _, item in ipairs(toImpound) do
            local plate = item.plate
            local data = item.data

            -- Remove from tracking
            abandonedVehicles[plate] = nil
            spawnedVehicles[plate] = nil

            -- Delete the vehicle entity from the world
            DeleteVehicleFromWorld(plate, data.netId)

            -- Impound the vehicle
            local success = ImpoundVehicle(
                plate,
                'Owner disconnected - Auto impound after ' .. math.floor(Config.DisconnectTimeout / 60) .. ' minutes',
                data.impoundLocation,
                data.props,
                false -- not destroyed
            )

            if success then
                print('[sb_impound] Auto-impounded vehicle: ' .. plate)
            end
        end

        ::continue::
    end
end)

-- ============================================================================
-- VEHICLE STORED/DESPAWNED HANDLER
-- ============================================================================

RegisterNetEvent('sb_impound:server:vehicleStored', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    spawnedVehicles[cleanPlate] = nil
    abandonedVehicles[cleanPlate] = nil
    print('[sb_impound] Vehicle ' .. cleanPlate .. ' stored, removed from tracking')
end)

-- ============================================================================
-- VEHICLE DESTROYED HANDLER
-- ============================================================================

RegisterNetEvent('sb_impound:server:vehicleDestroyed', function(plate, props)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    local citizenid = Player.PlayerData.citizenid

    -- Verify ownership (REPLACE handles plates with/without spaces)
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ?', {
        cleanPlate, citizenid
    })

    if not vehicle then
        TriggerClientEvent('sb_notify:client:Notify', src, 'This is not your vehicle', 'error', 3000)
        return
    end

    -- Remove from tracking
    spawnedVehicles[cleanPlate] = nil
    abandonedVehicles[cleanPlate] = nil

    -- Find nearest impound
    local impoundLocation = 'lspd' -- Default

    -- Impound as destroyed
    local success = ImpoundVehicle(
        cleanPlate,
        'Vehicle destroyed',
        impoundLocation,
        props,
        true -- destroyed
    )

    if success then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Your destroyed vehicle has been sent to ' .. Config.Locations[impoundLocation].label .. '. Pay the repair fee to retrieve it.', 'warning', 8000)
    end
end)

-- ============================================================================
-- MANUAL SEND TO IMPOUND
-- ============================================================================

RegisterNetEvent('sb_impound:server:sendToImpound', function(plate)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    local citizenid = Player.PlayerData.citizenid

    -- Verify ownership (REPLACE handles plates with/without spaces)
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ? AND state = 0', {
        cleanPlate, citizenid
    })

    if not vehicle then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle not found or already stored', 'error', 3000)
        return
    end

    -- Request vehicle props from client
    TriggerClientEvent('sb_impound:client:getVehiclePropsForImpound', src, cleanPlate)
end)

RegisterNetEvent('sb_impound:server:confirmSendToImpound', function(plate, props, isDestroyed)
    local src = source
    local Player = SBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cleanPlate = plate:gsub('%s+', ''):upper()
    local citizenid = Player.PlayerData.citizenid

    -- Verify ownership again (REPLACE handles plates with/without spaces)
    local vehicle = MySQL.single.await('SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ? AND citizenid = ?', {
        cleanPlate, citizenid
    })

    if not vehicle then return end

    -- Remove from tracking
    spawnedVehicles[cleanPlate] = nil
    abandonedVehicles[cleanPlate] = nil

    -- Find nearest impound based on player position
    local impoundLocation = 'lspd'

    -- Delete vehicle from world
    local trackedData = spawnedVehicles[cleanPlate]
    DeleteVehicleFromWorld(cleanPlate, trackedData and trackedData.netId or nil)

    -- Impound
    local reason = isDestroyed and 'Vehicle destroyed - Sent to impound' or 'Manually sent to impound'
    local success = ImpoundVehicle(cleanPlate, reason, impoundLocation, props, isDestroyed)

    if success then
        local locationLabel = Config.Locations[impoundLocation].label
        TriggerClientEvent('sb_notify:client:Notify', src, 'Vehicle sent to ' .. locationLabel, 'success', 5000)
    end
end)

-- ============================================================================
-- CLEANUP ON RESOURCE STOP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Don't auto-impound on resource restart - just clear tracking
    abandonedVehicles = {}
    stolenVehicles = {}
    spawnedVehicles = {}
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsVehicleAbandoned', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    return abandonedVehicles[cleanPlate] ~= nil
end)

exports('IsVehicleStolen', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    return stolenVehicles[cleanPlate] == true
end)

exports('MarkVehicleStolen', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    stolenVehicles[cleanPlate] = true
    abandonedVehicles[cleanPlate] = nil
end)

exports('IsVehicleTracked', function(plate)
    local cleanPlate = plate:gsub('%s+', ''):upper()
    return spawnedVehicles[cleanPlate] ~= nil
end)

exports('GetTrackedVehicles', function()
    return spawnedVehicles
end)
