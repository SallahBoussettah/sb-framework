-- ============================================================================
-- sb_mechanic - Server: Mobile Repair
-- Mobile repair validation, item consumption
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- Helpers
-- ============================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic:server:mobile]', ...)
    end
end

local function HasItem(src, itemName, count)
    return exports['sb_inventory']:HasItem(src, itemName, count)
end

local function RemoveItem(src, itemName, count)
    exports['sb_inventory']:RemoveItem(src, itemName, count)
end

-- ============================================================================
-- Mobile Repair Callback
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:mobileRepair', function(source, cb, repairType, vehicleNetId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Player not found') end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName then
        return cb(false, 'Not a mechanic')
    end
    if not job.onduty then
        return cb(false, 'Not on duty')
    end

    -- Determine required item
    local reqItemKey = nil
    if repairType == 'engine' then
        reqItemKey = 'mobileEngine'
    elseif repairType == 'body' then
        reqItemKey = 'mobileBody'
    elseif repairType == 'tire' then
        reqItemKey = 'mobileTire'
    else
        return cb(false, 'Invalid repair type')
    end

    local reqItem = Config.RequiredItems[reqItemKey]
    if not reqItem then return cb(false, 'No item config') end

    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    -- Remove item
    RemoveItem(src, reqItem.name, reqItem.count)

    -- Log
    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    MySQL.insert('INSERT INTO vehicle_history (plate, event_type, description, actor_citizenid, metadata) VALUES (?, ?, ?, ?, ?)', {
        plate,
        'mobile_' .. repairType,
        'mobile_' .. repairType,
        Player.PlayerData.citizenid,
        json.encode({
            repairType = repairType,
            mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        })
    })

    Debug('Mobile repair:', repairType, 'plate:', plate, 'mechanic:', src)

    local labels = { engine = 'Engine', body = 'Body', tire = 'Tire' }
    cb(true, (labels[repairType] or 'Vehicle') .. ' repaired (roadside)')
end)
