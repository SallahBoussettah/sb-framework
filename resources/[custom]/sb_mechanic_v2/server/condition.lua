-- sb_mechanic_v2 | Server Condition
-- In-memory condition cache, degradation processing, telemetry handler,
-- DB persistence, API callbacks/exports

local SB = SBMechanic.SB

-- ===== LOAD CONDITION FROM DB =====
function LoadCondition(plate)
    if SBMechanic.Conditions[plate] then
        return SBMechanic.Conditions[plate]
    end

    local row = MySQL.single.await('SELECT * FROM vehicle_condition WHERE plate = ?', { plate })

    if not row then
        -- Create new record with defaults
        local defaults = Components.GetDefaults()
        InsertConditionToDB(plate, defaults)
        SBMechanic.Conditions[plate] = defaults
        return defaults
    end

    -- Build condition table from row
    local cond = {}
    for _, comp in ipairs(Components.List) do
        cond[comp.name] = row[comp.name] or comp.default
    end
    cond.total_km = row.total_km or 0.0
    cond.last_oil_change_km = row.last_oil_change_km or 0.0
    cond.last_service_km = row.last_service_km or 0.0

    SBMechanic.Conditions[plate] = cond
    return cond
end

-- ===== INSERT NEW CONDITION TO DB =====
function InsertConditionToDB(plate, cond)
    local cols = { 'plate' }
    local placeholders = { '?' }
    local values = { plate }

    for _, comp in ipairs(Components.List) do
        cols[#cols + 1] = '`' .. comp.name .. '`'
        placeholders[#placeholders + 1] = '?'
        values[#values + 1] = cond[comp.name]
    end

    cols[#cols + 1] = 'total_km'
    placeholders[#placeholders + 1] = '?'
    values[#values + 1] = cond.total_km or 0.0

    cols[#cols + 1] = 'last_oil_change_km'
    placeholders[#placeholders + 1] = '?'
    values[#values + 1] = cond.last_oil_change_km or 0.0

    cols[#cols + 1] = 'last_service_km'
    placeholders[#placeholders + 1] = '?'
    values[#values + 1] = cond.last_service_km or 0.0

    local query = string.format(
        'INSERT INTO vehicle_condition (%s) VALUES (%s)',
        table.concat(cols, ', '),
        table.concat(placeholders, ', ')
    )

    MySQL.insert(query, values)
end

-- ===== SAVE CONDITION TO DB =====
function SaveConditionToDB(plate, cond)
    local sets = {}
    local values = {}

    for _, comp in ipairs(Components.List) do
        sets[#sets + 1] = '`' .. comp.name .. '` = ?'
        values[#values + 1] = cond[comp.name]
    end

    sets[#sets + 1] = 'total_km = ?'
    values[#values + 1] = cond.total_km or 0.0
    sets[#sets + 1] = 'last_oil_change_km = ?'
    values[#values + 1] = cond.last_oil_change_km or 0.0
    sets[#sets + 1] = 'last_service_km = ?'
    values[#values + 1] = cond.last_service_km or 0.0

    values[#values + 1] = plate

    local query = string.format(
        'UPDATE vehicle_condition SET %s WHERE plate = ?',
        table.concat(sets, ', ')
    )

    MySQL.update(query, values)
end

-- ===== MARK DIRTY =====
local function MarkDirty(plate)
    SBMechanic.DirtyPlates[plate] = true
end

-- ===== APPLY DEGRADATION TO COMPONENT =====
local function Degrade(cond, component, amount)
    if not cond[component] then return end
    cond[component] = math.max(0.0, cond[component] - amount)
end

-- ===== NATIVE-SYNCED COMPONENTS =====
-- These are read directly from GTA natives and override our values (damage direction only)
local NativeSyncedComponents = {
    engine_block = true,
    body_panels = true,
    tire_fl = true,
    tire_fr = true,
    tire_rl = true,
    tire_rr = true,
    windshield = true,
}

-- ===== GET VEHICLE CLASS MULTIPLIER =====
local function GetClassMultiplier(vehicleClass)
    return Config.VehicleClassMultiplier[vehicleClass] or 1.0
end

-- ===== PROCESS TELEMETRY =====
-- Called when client sends driving data every 2 seconds
function ProcessTelemetry(plate, telemetry)
    local cond = SBMechanic.Conditions[plate]
    if not cond then return end

    local distKm = math.min(telemetry.distanceKm or 0, 2.0)             -- cap at 2 km/tick (~3600 km/h max)
    local highRPMSeconds = math.min(telemetry.highRPMSeconds or 0, 3.0) -- cap at 3s per tick
    local hardBrakes = math.min(telemetry.hardBrakes or 0, 5)           -- cap at 5 per tick
    local offroadSeconds = math.min(telemetry.offroadSeconds or 0, 3.0) -- cap at 3s per tick
    local nativeOverrides = telemetry.nativeOverrides or {}
    local splashDamage = telemetry.splashDamage or {}
    local velocityCrashes = telemetry.velocityCrashes or {}
    local vehicleClass = telemetry.vehicleClass or 1

    -- Cap velocity crashes to 3 entries per tick
    if #velocityCrashes > 3 then
        local capped = {}
        for i = 1, 3 do capped[i] = velocityCrashes[i] end
        velocityCrashes = capped
    end

    -- Vehicle class multiplier scales all wear degradation
    local classMult = GetClassMultiplier(vehicleClass)

    -- Track total km
    cond.total_km = (cond.total_km or 0) + distKm

    -- 1. Distance degradation (wear-only components, skip native-synced) * class multiplier
    if distKm > 0 then
        for comp, rate in pairs(Config.Degradation.distance) do
            if not NativeSyncedComponents[comp] then
                Degrade(cond, comp, rate * distKm * classMult)
            end
        end
    end

    -- 2. High RPM degradation (wear-only components, skip native-synced) * class multiplier
    if highRPMSeconds > 0 then
        for comp, rate in pairs(Config.Degradation.highRPM) do
            if not NativeSyncedComponents[comp] then
                Degrade(cond, comp, rate * highRPMSeconds * classMult)
            end
        end
    end

    -- 3. Hard braking events * class multiplier
    if hardBrakes > 0 then
        for comp, amount in pairs(Config.Degradation.hardBrake) do
            Degrade(cond, comp, amount * hardBrakes * classMult)
        end
    end

    -- 4. Off-road degradation (skip native-synced) * class multiplier
    if offroadSeconds > 0 then
        for comp, rate in pairs(Config.Degradation.offroad) do
            if not NativeSyncedComponents[comp] then
                Degrade(cond, comp, rate * offroadSeconds * classMult)
            end
        end
    end

    -- 5. Native health overrides (replaces old crash system)
    -- For each native-synced component, take the LOWER of (native value, current condition)
    -- Crashes instantly lower components, but we never heal via native sync
    -- Engine block respects the limp mode safeguard floor
    local safeguard = Config.EngineDegradation.safeguardFloor
    for comp, nativeVal in pairs(nativeOverrides) do
        if cond[comp] and NativeSyncedComponents[comp] then
            -- Apply safeguard floor to engine_block
            local floor = (comp == 'engine_block') and safeguard or 0.0
            if nativeVal < cond[comp] then
                cond[comp] = math.max(floor, nativeVal)
            end
        end
    end

    -- 6. Splash damage from native health deltas (crash impacts on related components)
    -- Already amplified on client side, apply class multiplier on top
    for comp, dmg in pairs(splashDamage) do
        if cond[comp] and not NativeSyncedComponents[comp] then
            Degrade(cond, comp, dmg * classMult)
        end
    end

    -- 7. Velocity-based crash damage (independent of GTA native health)
    -- Uses sudden speed loss to calculate damage — works on custom cars with low fCollisionDamageMult
    local vcConfig = Config.Collision.VelocityCrash
    for _, crash in ipairs(velocityCrashes) do
        local speedDrop = crash.speedDrop or 0
        if speedDrop >= vcConfig.MinSpeedDrop then
            -- Calculate damage: linear scale from MinSpeedDrop to ScaleSpeed
            local severity = math.min(1.0, speedDrop / vcConfig.ScaleSpeed)
            local damage = vcConfig.MaxDamage * severity  -- 0 to MaxDamage %

            -- Apply to engine and body (these are the primary crash targets)
            Degrade(cond, 'engine_block', damage)
            Degrade(cond, 'body_panels', damage * 0.8)

            -- Enforce engine safeguard
            if cond.engine_block < safeguard then
                cond.engine_block = safeguard
            end

            -- Splash to related components (mild — native health sync already splashes separately)
            Degrade(cond, 'radiator',       damage * 0.25 * classMult)
            Degrade(cond, 'coolant_level',  damage * 0.15 * classMult)
            Degrade(cond, 'spark_plugs',    damage * 0.10 * classMult)
            Degrade(cond, 'headlights',     damage * 0.30 * classMult)
            Degrade(cond, 'taillights',     damage * 0.15 * classMult)
            Degrade(cond, 'alignment',      damage * 0.25 * classMult)
            Degrade(cond, 'battery',        damage * 0.10 * classMult)
            Degrade(cond, 'ecu',            damage * 0.08 * classMult)
            Degrade(cond, 'wiring',         damage * 0.08 * classMult)
            Degrade(cond, 'windshield',     damage * 0.20 * classMult)
        end
    end

    -- 8. Cascading damage (per-second rates * telemetry interval) * class multiplier
    local intervalSec = Config.TelemetryInterval / 1000
    for _, cascade in ipairs(Config.Cascading) do
        local sourceVal = cond[cascade.source] or 100
        if sourceVal < cascade.threshold then
            local severity = 1 - (sourceVal / cascade.threshold) -- 0 to 1
            for target, rate in pairs(cascade.targets) do
                Degrade(cond, target, rate * severity * intervalSec * classMult)
            end
        end
    end

    -- 9. Engine self-degradation REMOVED
    -- Engine damage is now stable — it stays where crashes/wear put it.
    -- The only gradual engine drain comes from cascading (bad oil, coolant, etc.)
    -- This prevents the "death spiral" where a single crash leads to limp mode in minutes.

    -- Enforce engine safeguard floor (limp mode, never reach 0 from degradation)
    if cond.engine_block and cond.engine_block < safeguard then
        cond.engine_block = safeguard
    end

    MarkDirty(plate)

    return cond
end

-- ===== TELEMETRY EVENT FROM CLIENT =====
RegisterNetEvent('sb_mechanic_v2:telemetry', function(plate, telemetry)
    local src = source
    if not plate or not telemetry then return end

    -- Basic validation
    if type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end

    -- Ensure condition is loaded
    if not SBMechanic.Conditions[plate] then
        LoadCondition(plate)
    end

    -- Process and get updated condition
    local cond = ProcessTelemetry(plate, telemetry)
    if not cond then return end

    -- Build slim condition update for client (only values, no tracking fields)
    -- Broadcast to ALL clients so nearby mechanics always have fresh data
    local update = {}
    for _, comp in ipairs(Components.List) do
        update[comp.name] = cond[comp.name]
    end

    TriggerClientEvent('sb_mechanic_v2:conditionUpdate', -1, plate, update)
end)

-- ===== VEHICLE EXITED — SAVE IMMEDIATELY =====
RegisterNetEvent('sb_mechanic_v2:vehicleExited', function(plate)
    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end
    local cond = SBMechanic.Conditions[plate]
    if cond and SBMechanic.DirtyPlates[plate] then
        SaveConditionToDB(plate, cond)
        SBMechanic.DirtyPlates[plate] = nil
    end
end)

-- ===== EXTERNAL DAMAGE EVENT =====
-- Handles damage to vehicles that aren't currently driven by the reporting player
-- Sent by the nearby vehicle health scanner in client/main.lua
RegisterNetEvent('sb_mechanic_v2:externalDamage', function(plate, nativeOverrides, splashDamage, vehicleClass)
    local src = source
    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end
    if not nativeOverrides then return end

    local cond = SBMechanic.Conditions[plate]
    if not cond then
        -- Vehicle not loaded in memory yet, load it
        cond = LoadCondition(plate)
    end
    if not cond then return end

    local safeguard = Config.EngineDegradation.safeguardFloor
    local classMult = (Config.VehicleClassMultiplier[vehicleClass] or 1.0)

    -- Apply native overrides (damage direction only)
    for comp, nativeVal in pairs(nativeOverrides) do
        if cond[comp] and NativeSyncedComponents[comp] then
            local floor = (comp == 'engine_block') and safeguard or 0.0
            if nativeVal < cond[comp] then
                cond[comp] = math.max(floor, nativeVal)
            end
        end
    end

    -- Apply splash damage
    if splashDamage then
        for comp, dmg in pairs(splashDamage) do
            if cond[comp] and not NativeSyncedComponents[comp] then
                Degrade(cond, comp, dmg * classMult)
            end
        end
    end

    MarkDirty(plate)
end)

-- ===== INSTANT DAMAGE EVENT =====
-- Fires immediately on crash/tire burst via SynVehicleRealism hooks
-- Broadcasts updated condition to ALL clients (not just source)
RegisterNetEvent('sb_mechanic_v2:instantDamage', function(plate, nativeOverrides, splashDamage, vehicleClass)
    local src = source
    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end
    if not nativeOverrides then return end

    local cond = SBMechanic.Conditions[plate]
    if not cond then
        cond = LoadCondition(plate)
    end
    if not cond then return end

    local safeguard = Config.EngineDegradation.safeguardFloor
    local classMult = (Config.VehicleClassMultiplier[vehicleClass] or 1.0)

    -- Apply native overrides (damage direction only)
    for comp, nativeVal in pairs(nativeOverrides) do
        if cond[comp] and NativeSyncedComponents[comp] then
            local floor = (comp == 'engine_block') and safeguard or 0.0
            if nativeVal < cond[comp] then
                cond[comp] = math.max(floor, nativeVal)
            end
        end
    end

    -- Apply splash damage
    if splashDamage then
        for comp, dmg in pairs(splashDamage) do
            if cond[comp] and not NativeSyncedComponents[comp] then
                Degrade(cond, comp, dmg * classMult)
            end
        end
    end

    MarkDirty(plate)

    -- Broadcast to ALL clients so nearby mechanics always have fresh data
    local update = {}
    for _, comp in ipairs(Components.List) do
        update[comp.name] = cond[comp.name]
    end
    TriggerClientEvent('sb_mechanic_v2:conditionUpdate', -1, plate, update)
end)

-- ===== PRE-SCAN SYNC EVENT =====
-- Called by client/diagnostics.lua right before an OBD scan
-- Syncs the vehicle's actual native state (tires, windshield, engine, body) to condition DB
-- Unlike telemetry (damage-only), pre-scan applies BOTH directions for native-synced components
-- because the mechanic is physically looking at the car — the scan must match what they see
RegisterNetEvent('sb_mechanic_v2:preScanSync', function(plate, nativeState)
    local src = source
    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return end
    if not nativeState or type(nativeState) ~= 'table' then return end

    -- Verify player is a mechanic
    local Player = SBMechanic.SB.Functions.GetPlayer(src)
    if not Player then return end
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then return end

    local cond = SBMechanic.Conditions[plate]
    if not cond then
        cond = LoadCondition(plate)
    end
    if not cond then return end

    local safeguard = Config.EngineDegradation.safeguardFloor

    -- Apply native state in BOTH directions (pre-scan = physical inspection)
    -- Healthy tire in GTA → healthy in scan. Burst tire → burst in scan.
    for comp, nativeVal in pairs(nativeState) do
        if cond[comp] and NativeSyncedComponents[comp] then
            local floor = (comp == 'engine_block') and safeguard or 0.0
            cond[comp] = math.max(floor, nativeVal)
        end
    end

    MarkDirty(plate)
end)

-- ===== PRE-SCAN SYNC CALLBACK =====
-- Callback version of preScanSync — returns true after processing
-- so client can chain the scan reliably without SetTimeout
SB.Functions.CreateCallback('sb_mechanic_v2:preScanSyncCB', function(source, cb, plate, nativeState)
    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then return cb(false) end
    if not nativeState or type(nativeState) ~= 'table' then return cb(false) end

    -- Verify player is a mechanic
    local Player = SBMechanic.SB.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then return cb(false) end

    local cond = SBMechanic.Conditions[plate]
    if not cond then
        cond = LoadCondition(plate)
    end
    if not cond then return cb(false) end

    local safeguard = Config.EngineDegradation.safeguardFloor

    -- Debug: log what the client sent vs what server has
    print(('[sb_mechanic_v2] preScanSyncCB plate=%s'):format(plate))
    for comp, nativeVal in pairs(nativeState) do
        if NativeSyncedComponents[comp] then
            print(('[sb_mechanic_v2]   %s: native=%.1f server=%.1f → SET %.1f'):format(
                comp, nativeVal, cond[comp] or -1, nativeVal
            ))
        end
    end

    -- Apply native state in BOTH directions (pre-scan = physical inspection)
    -- The mechanic is looking at the car — scan must match what they see
    -- Healthy tire in GTA → healthy in scan. Burst tire → burst in scan.
    for comp, nativeVal in pairs(nativeState) do
        if cond[comp] and NativeSyncedComponents[comp] then
            local floor = (comp == 'engine_block') and safeguard or 0.0
            cond[comp] = math.max(floor, nativeVal)
        end
    end

    MarkDirty(plate)
    cb(true)
end)

-- ===== VEHICLE SPAWN HOOK =====
-- When a vehicle gets its sb_plate state bag set, load/create its condition
RegisterNetEvent('sb_mechanic_v2:vehicleSpawned', function(plate, vehicleNetId)
    local src = source
    if not plate or type(plate) ~= 'string' then return end

    local cond = LoadCondition(plate)

    -- Set state bag on the vehicle entity
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        Entity(vehicle).state:set('sb_condition', true, true)
    end

    -- Send full condition to requesting client
    local update = {}
    for _, comp in ipairs(Components.List) do
        update[comp.name] = cond[comp.name]
    end

    TriggerClientEvent('sb_mechanic_v2:conditionUpdate', src, plate, update)
end)

-- ===== SERVER EXPORTS =====
exports('GetVehicleCondition', function(plate)
    return LoadCondition(plate)
end)

exports('SetComponent', function(plate, component, value)
    local cond = LoadCondition(plate)
    if not cond[component] then return false end
    cond[component] = math.max(0.0, math.min(100.0, value))
    MarkDirty(plate)
    return true
end)

exports('DamageComponent', function(plate, component, amount)
    local cond = LoadCondition(plate)
    if not cond[component] then return false end
    Degrade(cond, component, amount)
    MarkDirty(plate)
    return true
end)

-- ===== CALLBACKS =====
SB.Functions.CreateCallback('sb_mechanic_v2:getCondition', function(source, cb, plate)
    local cond = LoadCondition(plate)
    cb(cond)
end)

SB.Functions.CreateCallback('sb_mechanic_v2:setComponent', function(source, cb, plate, component, value)
    local cond = LoadCondition(plate)
    if not cond[component] then return cb(false) end
    cond[component] = math.max(0.0, math.min(100.0, value))
    MarkDirty(plate)
    cb(true)
end)

SB.Functions.CreateCallback('sb_mechanic_v2:damageComponent', function(source, cb, plate, component, amount)
    local cond = LoadCondition(plate)
    if not cond[component] then return cb(false) end
    Degrade(cond, component, amount)
    MarkDirty(plate)
    cb(true)
end)

-- ===== ADMIN: RESET VEHICLE CONDITION =====
-- Usage: /resetcondition (while in or near a vehicle with sb_plate)
RegisterCommand('resetcondition', function(source, args)
    local src = source
    if src == 0 then
        -- Server console: require plate arg
        local plate = args[1]
        if not plate then print('[sb_mechanic_v2] Usage: resetcondition <plate>') return end
        local defaults = Components.GetDefaults()
        SBMechanic.Conditions[plate] = defaults
        MarkDirty(plate)
        SaveConditionToDB(plate, defaults)
        print('[sb_mechanic_v2] Reset condition for plate: ' .. plate)
        TriggerClientEvent('sb_mechanic_v2:conditionUpdate', -1, plate, defaults)
        return
    end

    -- Player: check admin
    if not exports['sb_admin']:IsAdmin(src) then
        TriggerClientEvent('sb_notify', src, 'Admin only.', 'error', 3000)
        return
    end

    -- Get plate from args or current vehicle
    local plate = args[1]
    if not plate then
        -- Try to get from player's current vehicle
        local ped = GetPlayerPed(src)
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle and vehicle ~= 0 then
            plate = Entity(vehicle).state.sb_plate
        end
    end

    if not plate then
        TriggerClientEvent('sb_notify', src, 'Usage: /resetcondition [plate] or sit in a vehicle', 'error', 4000)
        return
    end

    local defaults = Components.GetDefaults()
    SBMechanic.Conditions[plate] = defaults
    MarkDirty(plate)
    SaveConditionToDB(plate, defaults)
    TriggerClientEvent('sb_mechanic_v2:conditionUpdate', -1, plate, defaults)
    TriggerClientEvent('sb_notify', src, 'Reset condition for: ' .. plate, 'success', 3000)
    print(('[sb_mechanic_v2] Admin %s reset condition for plate: %s'):format(GetPlayerName(src), plate))
end, false)
