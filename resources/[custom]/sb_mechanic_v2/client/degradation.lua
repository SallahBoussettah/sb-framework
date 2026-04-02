-- sb_mechanic_v2 | Client Degradation
-- Telemetry collection (km, RPM, braking, offroad, native health sync, velocity crash), send to server every 2s
-- Collision cooldown, speed gate, damage amplification, vehicle class tracking
-- Tracks ANY sb_plate vehicle regardless of ownership

-- ===== TELEMETRY STATE =====
local telemetry = {
    distanceKm = 0,
    highRPMSeconds = 0,
    hardBrakes = 0,
    offroadSeconds = 0,
    nativeOverrides = {},   -- component -> 0-100 value from GTA natives
    splashDamage = {},      -- component -> damage amount from native health deltas
    velocityCrashes = {},   -- array of { speedDrop = km/h } for velocity-based crash events
    vehicleClass = 0,       -- GTA vehicle class for server-side scaling
}

local lastPos = nil
local lastSpeed = 0
local sampleInterval = Config.TelemetrySampleRate / 1000  -- convert ms to seconds

-- Previous native health values for delta detection
local lastEngineHealth = 1000.0
local lastBodyHealth = 1000.0

-- Collision cooldown state
local lastCollisionTime = 0

-- Velocity crash cooldown (separate from native health cooldown)
local lastVelocityCrashTime = 0

-- ===== RESET TELEMETRY =====
local function ResetTelemetry()
    telemetry.distanceKm = 0
    telemetry.highRPMSeconds = 0
    telemetry.hardBrakes = 0
    telemetry.offroadSeconds = 0
    telemetry.nativeOverrides = {}
    telemetry.splashDamage = {}
    telemetry.velocityCrashes = {}
    -- vehicleClass persists (doesn't reset between sends)
end

-- ===== REUSABLE TIRE/WINDSHIELD STATE READER =====
-- Reads tire burst/health and windshield state from GTA natives
-- Returns table of component overrides (0-100 scale)
function ReadTireState(vehicle)
    local overrides = {}
    local numWheels = GetVehicleNumberOfWheels(vehicle)
    local wheelMap = {
        { healthIdx = 0, tyreIdx = 0, comp = 'tire_fl' },
        { healthIdx = 1, tyreIdx = 1, comp = 'tire_fr' },
        { healthIdx = 2, tyreIdx = 4, comp = 'tire_rl' },
        { healthIdx = 3, tyreIdx = 5, comp = 'tire_rr' },
    }
    for _, w in ipairs(wheelMap) do
        if w.healthIdx < numWheels then
            if IsVehicleTyreBurst(vehicle, w.tyreIdx, false) then
                overrides[w.comp] = 0.0
            else
                local wheelHealth = GetVehicleWheelHealth(vehicle, w.healthIdx)
                overrides[w.comp] = math.max(0.0, math.min(100.0, wheelHealth / 3.5))
            end
        end
    end
    -- Windshield: window index 0 = front windshield
    -- Skip motorcycles (class 8) and bicycles (class 13) — they have no windows,
    -- and IsVehicleWindowIntact returns false for non-existent window slots
    -- NOTE: This only detects fully shattered windows (SmashVehicleWindow).
    -- Collision cracks are visual-only and not detected by the native.
    local vehClass = GetVehicleClass(vehicle)
    if vehClass ~= 8 and vehClass ~= 13 then
        if not IsVehicleWindowIntact(vehicle, 0) then
            overrides.windshield = 0.0
        end
    end
    return overrides
end

-- ===== RESET NATIVE BASELINES =====
-- Called by main.lua after pushing repairs to GTA natives
-- Prevents false delta detection on the next telemetry sample
function ResetNativeBaselines(engineHealth, bodyHealth)
    lastEngineHealth = engineHealth
    lastBodyHealth = bodyHealth
end

-- ===== NATIVE HEALTH READING =====
-- Reads GTA native health values and converts to our 0-100 scale
-- Applies collision cooldown, speed gate, and damage amplification
local function ReadNativeHealth(vehicle, speedKmh)
    local overrides = {}
    local splash = {}
    local gameTime = GetGameTimer()

    -- Engine health: 0-1000 -> 0-100
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local enginePct = math.max(0.0, math.min(100.0, engineHealth / 10.0))
    overrides.engine_block = enginePct

    -- Body health: 0-1000 -> 0-100
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local bodyPct = math.max(0.0, math.min(100.0, bodyHealth / 10.0))
    overrides.body_panels = bodyPct

    -- Tires + windshield via shared helper
    local tireOverrides = ReadTireState(vehicle)
    for comp, val in pairs(tireOverrides) do
        overrides[comp] = val
    end

    -- ===== SPLASH DAMAGE FROM NATIVE DELTAS =====
    local engineDelta = lastEngineHealth - engineHealth
    local bodyDelta = lastBodyHealth - bodyHealth

    local hasImpact = (engineDelta > 20 or bodyDelta > 20)
    local aboveSpeedGate = speedKmh >= Config.Collision.MinImpactSpeed
    local offCooldown = (gameTime - lastCollisionTime) >= Config.Collision.CooldownMs

    if hasImpact and aboveSpeedGate and offCooldown then
        lastCollisionTime = gameTime

        -- Use raw GTA native values — NO amplification, NO write-back
        -- Velocity crash system handles custom cars with low fCollisionDamageMult
        -- Overrides already contain the current native health from above

        -- Splash damage from crash impacts to related components
        local splashAmp = Config.Collision.SplashAmplification

        if engineDelta > 20 then
            local severity = math.min(1.0, engineDelta / 500.0)
            splash.radiator = 3.0 * severity * splashAmp
            splash.coolant_level = 2.0 * severity * splashAmp
            splash.spark_plugs = 1.5 * severity * splashAmp
        end

        if bodyDelta > 20 then
            local severity = math.min(1.0, bodyDelta / 500.0)
            splash.headlights = 3.5 * severity * splashAmp
            splash.taillights = 2.0 * severity * splashAmp
            splash.alignment = 3.0 * severity * splashAmp
            splash.battery = 1.5 * severity * splashAmp
            splash.ecu = 1.0 * severity * splashAmp
            splash.wiring = 1.0 * severity * splashAmp
        end
    elseif hasImpact and not aboveSpeedGate then
        -- Low-speed bump: mild splash only
        if engineDelta > 50 then
            local severity = math.min(1.0, engineDelta / 800.0)
            splash.radiator = 0.8 * severity
            splash.coolant_level = 0.4 * severity
        end
        if bodyDelta > 50 then
            local severity = math.min(1.0, bodyDelta / 800.0)
            splash.headlights = 1.0 * severity
            splash.alignment = 0.8 * severity
        end
    end

    lastEngineHealth = engineHealth
    lastBodyHealth = bodyHealth

    return overrides, splash
end

-- ===== ACCUMULATE SPLASH DAMAGE =====
local function AccumulateSplash(existing, new)
    for comp, dmg in pairs(new) do
        existing[comp] = (existing[comp] or 0) + dmg
    end
end

-- ===== TELEMETRY COLLECTION (every 500ms) =====
CreateThread(function()
    while true do
        Wait(Config.TelemetrySampleRate)

        -- Gate: must be in a vehicle with sb_plate
        if not IsInVehicle or not IsTrackedVehicle or CurrentVehicle == 0 or not CurrentPlate then
            lastPos = nil
            lastSpeed = 0
            lastEngineHealth = 1000.0
            lastBodyHealth = 1000.0
            lastCollisionTime = 0
            lastVelocityCrashTime = 0
            goto continue
        end

        local vehicle = CurrentVehicle
        if not DoesEntityExist(vehicle) then goto continue end

        local ped = PlayerPedId()
        local isDriver = GetPedInVehicleSeat(vehicle, -1) == ped
        local speed = GetEntitySpeed(vehicle) -- m/s
        local speedKmh = speed * 3.6
        local gameTime = GetGameTimer()

        -- Track vehicle class (any occupant can read this)
        telemetry.vehicleClass = GetVehicleClass(vehicle)

        -- ===== DRIVER-ONLY TELEMETRY (distance, RPM, braking, offroad) =====
        if isDriver then
            local pos = GetEntityCoords(vehicle)

            -- 1. Distance traveled
            if lastPos then
                local dist = #(pos - lastPos)
                if dist > 0.5 and dist < 100 then
                    telemetry.distanceKm = telemetry.distanceKm + (dist / 1000.0)
                end
            end
            lastPos = pos

            -- 2. High RPM detection
            local rpm = GetVehicleCurrentRpm(vehicle)
            if rpm > 0.8 then
                telemetry.highRPMSeconds = telemetry.highRPMSeconds + sampleInterval
            end

            -- 3. Hard braking detection
            local speedDrop = (lastSpeed * 3.6) - speedKmh
            if speedDrop > 30 then
                telemetry.hardBrakes = telemetry.hardBrakes + 1
            end

            -- 4. Off-road detection
            local offroad = false
            local found, roadPos = GetNthClosestVehicleNode(pos.x, pos.y, pos.z, 0, 1, 0.0, 0)
            if found and roadPos then
                if #(pos - roadPos) > 12.0 then
                    offroad = true
                end
            end
            if offroad then
                telemetry.offroadSeconds = telemetry.offroadSeconds + sampleInterval
            end
        end

        -- ===== VELOCITY-BASED CRASH DETECTION (any occupant) =====
        -- Detects crashes by sudden deceleration, works on ALL vehicles including custom cars
        -- This is independent of GTA's native health system
        if lastSpeed > 0 then
            local lastSpeedKmh = lastSpeed * 3.6
            local speedDrop = lastSpeedKmh - speedKmh

            local vcConfig = Config.Collision.VelocityCrash
            local offVCCooldown = (gameTime - lastVelocityCrashTime) >= Config.Collision.CooldownMs

            if speedDrop >= vcConfig.MinSpeedDrop and offVCCooldown then
                lastVelocityCrashTime = gameTime
                telemetry.velocityCrashes[#telemetry.velocityCrashes + 1] = {
                    speedDrop = speedDrop,
                }
            end
        end

        lastSpeed = speed

        -- ===== NATIVE HEALTH SYNC (any occupant) =====
        local overrides, splash = ReadNativeHealth(vehicle, speedKmh)
        telemetry.nativeOverrides = overrides
        AccumulateSplash(telemetry.splashDamage, splash)

        ::continue::
    end
end)

-- ===== SEND TELEMETRY TO SERVER (every 2s) =====
CreateThread(function()
    while true do
        Wait(Config.TelemetryInterval)

        if not IsInVehicle or not IsTrackedVehicle or not CurrentPlate then
            ResetTelemetry()
            goto continue
        end

        local hasNativeOverrides = next(telemetry.nativeOverrides) ~= nil
        local hasSplashDamage = next(telemetry.splashDamage) ~= nil
        local hasVelocityCrashes = #telemetry.velocityCrashes > 0

        if telemetry.distanceKm > 0 or telemetry.highRPMSeconds > 0 or
           telemetry.hardBrakes > 0 or telemetry.offroadSeconds > 0 or
           hasNativeOverrides or hasSplashDamage or hasVelocityCrashes then

            TriggerServerEvent('sb_mechanic_v2:telemetry', CurrentPlate, {
                distanceKm = telemetry.distanceKm,
                highRPMSeconds = telemetry.highRPMSeconds,
                hardBrakes = telemetry.hardBrakes,
                offroadSeconds = telemetry.offroadSeconds,
                nativeOverrides = telemetry.nativeOverrides,
                splashDamage = telemetry.splashDamage,
                velocityCrashes = telemetry.velocityCrashes,
                vehicleClass = telemetry.vehicleClass,
            })
        end

        ResetTelemetry()

        ::continue::
    end
end)

-- ===== SYNVEHICLEREALISM INTEGRATION =====
-- Hook events from SynVehicleRealism for instant damage detection
-- bypasses the 2-second telemetry batch cycle

local lastInstantDamageTime = 0
local INSTANT_DAMAGE_COOLDOWN = 1000 -- 1 second cooldown to prevent spam

-- Hook `vehicleDamage` — fires when SynVehicleRealism detects a crash
AddEventHandler('vehicleDamage', function(vehicle)
    if not IsTrackedVehicle or not CurrentPlate then return end
    if vehicle ~= CurrentVehicle then return end
    if not DoesEntityExist(vehicle) then return end

    local now = GetGameTimer()
    if now - lastInstantDamageTime < INSTANT_DAMAGE_COOLDOWN then return end
    lastInstantDamageTime = now

    -- Read native health immediately
    local overrides, splash = ReadNativeHealth(vehicle, GetEntitySpeed(vehicle) * 3.6)

    -- Send to server IMMEDIATELY (bypass 2s batch)
    TriggerServerEvent('sb_mechanic_v2:instantDamage', CurrentPlate, overrides, splash, GetVehicleClass(vehicle))
end)

-- Hook `SynVehicleRealism:client:SyncWheelColliders` — fires when wheel damage state changes
RegisterNetEvent('SynVehicleRealism:client:SyncWheelColliders', function(plate, data)
    if not plate then return end

    local now = GetGameTimer()
    if now - lastInstantDamageTime < INSTANT_DAMAGE_COOLDOWN then return end

    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) and Entity(veh).state.sb_plate == plate then
            lastInstantDamageTime = now
            local overrides = ReadTireState(veh)
            if next(overrides) then
                TriggerServerEvent('sb_mechanic_v2:instantDamage', plate, overrides, {}, GetVehicleClass(veh))
            end
            break
        end
    end
end)
