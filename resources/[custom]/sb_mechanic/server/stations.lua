-- ============================================================================
-- sb_mechanic - Server: Station Validation
-- All mod/repair validation (job, duty, grade, items), vehicle history logging
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- Helpers
-- ============================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic:server:stations]', ...)
    end
end

local function ValidateMechanic(src)
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return false, nil, 'Player not found' end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName then
        return false, Player, 'Not a mechanic'
    end
    if not job.onduty then
        return false, Player, 'Not on duty'
    end

    return true, Player, nil
end

local function HasItem(src, itemName, count)
    return exports['sb_inventory']:HasItem(src, itemName, count)
end

local function RemoveItem(src, itemName, count)
    exports['sb_inventory']:RemoveItem(src, itemName, count)
end

local function LogVehicleHistory(plate, eventType, mechanicId, details)
    MySQL.insert('INSERT INTO vehicle_history (plate, event_type, description, actor_citizenid, metadata) VALUES (?, ?, ?, ?, ?)', {
        plate, eventType, eventType, mechanicId, json.encode(details or {})
    })
end

-- ============================================================================
-- Apply Repair
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyRepair', function(source, cb, repairType, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    -- Validate repair type
    local reqItem = nil
    if repairType == 'engine' then
        reqItem = Config.RequiredItems.engineRepair
    elseif repairType == 'body' then
        reqItem = Config.RequiredItems.bodyRepair
    else
        return cb(false, 'Invalid repair type')
    end

    -- Check items
    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing required item: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    -- Remove item
    RemoveItem(src, reqItem.name, reqItem.count)

    -- Log
    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, repairType .. '_repair', Player.PlayerData.citizenid, {
        repairType = repairType,
        mechanicName = mechanicName
    })

    -- Log work for billing
    local serviceLabel = repairType == 'engine' and 'Engine Repair' or 'Body Repair'
    local servicePrice = repairType == 'engine' and Config.Pricing.engineRepair or Config.Pricing.bodyRepair
    LogWork(plate, repairType .. '_repair', serviceLabel, servicePrice, Player.PlayerData.citizenid, mechanicName)

    cb(true, string.format('%s repair complete', repairType:sub(1,1):upper() .. repairType:sub(2)))
end)

-- ============================================================================
-- Apply Mod (performance upgrades)
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyMod', function(source, cb, modType, modIndex, toggle, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    -- Determine required item
    local reqItemKey = nil
    if modType == 11 then reqItemKey = 'engineUpgrade'
    elseif modType == 12 then reqItemKey = 'brakes'
    elseif modType == 13 then reqItemKey = 'transmission'
    elseif modType == 15 then reqItemKey = 'suspension'
    elseif modType == 16 then reqItemKey = 'armor'
    elseif modType == 18 then reqItemKey = 'turbo'
    else
        return cb(false, 'Invalid mod type')
    end

    local reqItem = Config.RequiredItems[reqItemKey]
    if not reqItem then return cb(false, 'No item config for mod') end

    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing required item: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    RemoveItem(src, reqItem.name, reqItem.count)

    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, 'upgrade', Player.PlayerData.citizenid, {
        modType = modType,
        modIndex = modIndex,
        toggle = toggle,
        mechanicName = mechanicName
    })

    -- Log work for billing
    local modLabelMap = {
        [11] = { type = 'engine_upgrade', label = 'Engine Upgrade', price = Config.Pricing.engineUpgrade },
        [12] = { type = 'brakes_upgrade', label = 'Brakes Upgrade', price = Config.Pricing.brakes },
        [13] = { type = 'transmission_upgrade', label = 'Transmission Upgrade', price = Config.Pricing.transmission },
        [15] = { type = 'suspension_upgrade', label = 'Suspension Upgrade', price = Config.Pricing.suspension },
        [16] = { type = 'armor_upgrade', label = 'Armor Upgrade', price = Config.Pricing.armor },
        [18] = { type = 'turbo_install', label = 'Turbo Install', price = Config.Pricing.turbo },
    }
    local modInfo = modLabelMap[modType]
    if modInfo then
        LogWork(plate, modInfo.type, modInfo.label, modInfo.price, Player.PlayerData.citizenid, mechanicName)
    end

    cb(true, 'Upgrade installed')
end)

-- ============================================================================
-- Apply Color
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyColor', function(source, cb, slot, colorId, r, g, b, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    local reqItem = Config.RequiredItems.paint
    if not reqItem then return cb(false, 'No item config') end

    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing required item: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    RemoveItem(src, reqItem.name, reqItem.count)

    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, 'paint', Player.PlayerData.citizenid, {
        slot = slot,
        colorId = colorId,
        customRGB = (r and g and b) and {r, g, b} or nil,
        mechanicName = mechanicName
    })

    -- Log work for billing
    local paintPriceMap = {
        primary = { type = 'paint_primary', label = 'Primary Color', price = Config.Pricing.primaryColor },
        secondary = { type = 'paint_secondary', label = 'Secondary Color', price = Config.Pricing.secondaryColor },
        pearlescent = { type = 'paint_pearlescent', label = 'Pearlescent Color', price = Config.Pricing.pearlescentColor },
    }
    local paintInfo = paintPriceMap[slot]
    if paintInfo then
        local finalPrice = (r and g and b) and Config.Pricing.customRGB or paintInfo.price
        local finalLabel = (r and g and b) and ('Custom ' .. paintInfo.label) or paintInfo.label
        LogWork(plate, paintInfo.type, finalLabel, finalPrice, Player.PlayerData.citizenid, mechanicName)
    end

    cb(true, 'Color applied')
end)

-- ============================================================================
-- Apply Wheels
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyWheels', function(source, cb, wheelType, wheelIndex, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    local reqItem = Config.RequiredItems.wheelSet
    if not reqItem then return cb(false, 'No item config') end

    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing required item: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    RemoveItem(src, reqItem.name, reqItem.count)

    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, 'wheels', Player.PlayerData.citizenid, {
        wheelType = wheelType,
        wheelIndex = wheelIndex,
        mechanicName = mechanicName
    })

    -- Log work for billing
    LogWork(plate, 'wheel_set', 'Wheel Set', Config.Pricing.wheelSet, Player.PlayerData.citizenid, mechanicName)

    cb(true, 'Wheels applied')
end)

-- ============================================================================
-- Apply Tire Repair
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyTireRepair', function(source, cb, tireIndex, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    local reqItem = Config.RequiredItems.tireRepair
    if not reqItem then return cb(false, 'No item config') end

    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing required item: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    RemoveItem(src, reqItem.name, reqItem.count)

    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, 'tire_repair', Player.PlayerData.citizenid, {
        tireIndex = tireIndex,
        mechanicName = mechanicName
    })

    -- Log work for billing
    LogWork(plate, 'tire_repair', 'Tire Repair', Config.Pricing.tireRepair, Player.PlayerData.citizenid, mechanicName)

    cb(true, 'Tire repaired')
end)

-- ============================================================================
-- Apply Cosmetic (neon, tint, xenon, horn, plate, extras, interior, dashboard)
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyCosmetic', function(source, cb, cosmeticType, value, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    -- Most cosmetics don't require items (except neon install might)
    -- No item consumption for cosmetic changes

    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, 'cosmetic_' .. tostring(cosmeticType), Player.PlayerData.citizenid, {
        cosmeticType = cosmeticType,
        value = value,
        mechanicName = mechanicName
    })

    -- Log work for billing
    local cosmeticPriceMap = {
        neon = { type = 'neon_kit', label = 'Neon Kit', price = Config.Pricing.neonKit },
        neon_color = { type = 'neon_color', label = 'Neon Color', price = Config.Pricing.neonColor },
        tint = { type = 'window_tint', label = 'Window Tint', price = Config.Pricing.windowTint },
        xenon = { type = 'xenon_lights', label = 'Xenon Headlights', price = Config.Pricing.xenonLights },
        xenon_color = { type = 'xenon_color', label = 'Xenon Color', price = Config.Pricing.xenonColor },
        horn = { type = 'horn', label = 'Horn', price = Config.Pricing.horn },
        plate = { type = 'plate_style', label = 'Plate Style', price = Config.Pricing.plateStyle },
        extras = { type = 'extras', label = 'Extra Toggle', price = Config.Pricing.extras },
        interior = { type = 'interior_color', label = 'Interior Color', price = Config.Pricing.interiorColor },
        dashboard = { type = 'dashboard_color', label = 'Dashboard Color', price = Config.Pricing.dashboardColor },
        livery = { type = 'livery', label = 'Livery', price = Config.Pricing.livery },
    }
    local cosInfo = cosmeticPriceMap[tostring(cosmeticType)]
    if cosInfo then
        LogWork(plate, cosInfo.type, cosInfo.label, cosInfo.price, Player.PlayerData.citizenid, mechanicName)
    end

    cb(true, 'Applied')
end)

-- ============================================================================
-- Apply Wash
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:applyWash', function(source, cb, vehicleNetId)
    local src = source
    local valid, Player, err = ValidateMechanic(src)
    if not valid then return cb(false, err) end

    local reqItem = Config.RequiredItems.wash
    if not reqItem then return cb(false, 'No item config') end

    if not HasItem(src, reqItem.name, reqItem.count) then
        return cb(false, 'Missing required item: ' .. (SB.Shared.Items[reqItem.name] and SB.Shared.Items[reqItem.name].label or reqItem.name))
    end

    RemoveItem(src, reqItem.name, reqItem.count)

    local plate = 'UNKNOWN'
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    LogVehicleHistory(plate, 'wash', Player.PlayerData.citizenid, {
        mechanicName = mechanicName
    })

    -- Log work for billing
    LogWork(plate, 'wash', 'Vehicle Wash', Config.Pricing.wash, Player.PlayerData.citizenid, mechanicName)

    cb(true, 'Vehicle washed')
end)
