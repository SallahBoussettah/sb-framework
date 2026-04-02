-- sb_mechanic_v2 | Client Main
-- State management, vehicle tracking, condition sync
-- Tracks ANY vehicle with sb_plate (not just owned by current player)

local SB = exports['sb_core']:GetCoreObject()

-- ===== CLIENT STATE =====
VehicleConditions = {}      -- plate -> { component = value, ... }
CurrentVehicle = 0          -- current vehicle entity handle
CurrentPlate = nil          -- current vehicle plate string
IsInVehicle = false
IsTrackedVehicle = false    -- whether current vehicle has sb_plate (regardless of owner)

-- ===== VEHICLE ENTER/EXIT TRACKING =====
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and not IsInVehicle then
            -- Just entered a vehicle
            CurrentVehicle = vehicle
            IsInVehicle = true
            IsTrackedVehicle = false
            CurrentPlate = nil

            -- Try to get plate from state bag, retry a few times since replication can lag
            local plate = nil
            for i = 1, 10 do
                local statePlate = Entity(vehicle).state.sb_plate
                if statePlate then
                    plate = statePlate
                    break
                end
                Wait(200)
                if GetVehiclePedIsIn(ped, false) == 0 then
                    break
                end
            end

            if plate then
                CurrentPlate = plate
                IsTrackedVehicle = true
                print('[sb_mechanic_v2] Tracking vehicle: ' .. plate)

                -- Request condition from server if not cached
                if not VehicleConditions[CurrentPlate] then
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    TriggerServerEvent('sb_mechanic_v2:vehicleSpawned', CurrentPlate, netId)
                end
            else
                -- No sb_plate — not a garage vehicle, no condition tracking
                local nativePlate = GetVehicleNumberPlateText(vehicle)
                if nativePlate then
                    CurrentPlate = string.gsub(nativePlate, '^%s+', '')
                    CurrentPlate = string.gsub(CurrentPlate, '%s+$', '')
                end
                IsTrackedVehicle = false
            end

        elseif vehicle ~= 0 and IsInVehicle and not IsTrackedVehicle then
            -- Still in vehicle but plate wasn't detected yet (late replication)
            if DoesEntityExist(vehicle) then
                local statePlate = Entity(vehicle).state.sb_plate
                if statePlate then
                    CurrentPlate = statePlate
                    IsTrackedVehicle = true
                    print('[sb_mechanic_v2] Late tracking vehicle: ' .. statePlate)

                    if not VehicleConditions[CurrentPlate] then
                        local netId = NetworkGetNetworkIdFromEntity(vehicle)
                        TriggerServerEvent('sb_mechanic_v2:vehicleSpawned', CurrentPlate, netId)
                    end
                end
            end

        elseif vehicle == 0 and IsInVehicle then
            -- Exited vehicle — tell server to save this vehicle's condition now
            if IsTrackedVehicle and CurrentPlate then
                TriggerServerEvent('sb_mechanic_v2:vehicleExited', CurrentPlate)
            end
            CurrentVehicle = 0
            CurrentPlate = nil
            IsInVehicle = false
            IsTrackedVehicle = false
        end
    end
end)

-- ===== PUSH REPAIRS TO GTA NATIVES =====
-- When a component value INCREASES (repair), push it back to GTA natives
-- so the next telemetry read doesn't re-damage the component from stale native state
local function PushRepairsToNatives(plate, oldCond, newCond)
    -- Find the vehicle entity by plate
    local vehicle = nil
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) and Entity(veh).state.sb_plate == plate then
            vehicle = veh
            break
        end
    end
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- Tire repairs: set tire as fixed and restore wheel health
    local tireMap = {
        { comp = 'tire_fl', tyreIdx = 0, healthIdx = 0 },
        { comp = 'tire_fr', tyreIdx = 1, healthIdx = 1 },
        { comp = 'tire_rl', tyreIdx = 4, healthIdx = 2 },
        { comp = 'tire_rr', tyreIdx = 5, healthIdx = 3 },
    }
    for _, t in ipairs(tireMap) do
        local oldVal = oldCond[t.comp] or 0
        local newVal = newCond[t.comp] or 0
        if newVal > oldVal and oldVal < 10 then
            -- Tire was repaired — fix the burst and set wheel health
            SetVehicleTyreBurst(vehicle, t.tyreIdx, false, 0)
            SetVehicleTyreFixed(vehicle, t.tyreIdx)
            SetVehicleWheelHealth(vehicle, t.healthIdx, newVal * 3.5)
        elseif newVal > oldVal then
            -- Partial tire repair (not burst, just damaged)
            SetVehicleWheelHealth(vehicle, t.healthIdx, newVal * 3.5)
        end
    end

    -- Engine block repair: push to native engine health
    if newCond.engine_block and oldCond.engine_block and newCond.engine_block > oldCond.engine_block then
        SetVehicleEngineHealth(vehicle, newCond.engine_block * 10.0)
    end

    -- Body panels repair: push to native body health
    if newCond.body_panels and oldCond.body_panels and newCond.body_panels > oldCond.body_panels then
        SetVehicleBodyHealth(vehicle, newCond.body_panels * 10.0)
    end

    -- Windshield repair
    if newCond.windshield and oldCond.windshield and newCond.windshield > oldCond.windshield and oldCond.windshield < 10 then
        FixVehicleWindow(vehicle, 0)
    end

    -- Reset native baselines in degradation.lua so delta detection doesn't false-trigger
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    ResetNativeBaselines(engineHealth, bodyHealth)
end

-- ===== RECEIVE CONDITION UPDATES FROM SERVER =====
RegisterNetEvent('sb_mechanic_v2:conditionUpdate', function(plate, conditionData)
    if not plate or not conditionData then return end

    local oldCond = VehicleConditions[plate]
    VehicleConditions[plate] = conditionData

    -- If a component was REPAIRED (new > old), push to GTA natives
    if oldCond then
        PushRepairsToNatives(plate, oldCond, conditionData)
    end
end)

-- ===== NEARBY VEHICLE HEALTH SCANNER =====
-- Scans for sb_plate vehicles within range that aren't the current vehicle
-- Catches: someone shot your parked car, NPC rammed it, another player crashed into it
local SCAN_RANGE = 80.0
local NearbyVehicleHealth = {} -- plate -> { engine = last, body = last }

CreateThread(function()
    while true do
        Wait(2000) -- every 2 seconds

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        -- Get nearby vehicles using the game pool
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) and vehicle ~= CurrentVehicle then
                local vehPos = GetEntityCoords(vehicle)
                local dist = #(pos - vehPos)

                if dist < SCAN_RANGE then
                    local plate = Entity(vehicle).state.sb_plate
                    if plate then
                        local engineHealth = GetVehicleEngineHealth(vehicle)
                        local bodyHealth = GetVehicleBodyHealth(vehicle)

                        local last = NearbyVehicleHealth[plate]
                        if not last then
                            -- First time seeing this vehicle, store baseline + current tire/windshield state
                            local tireState = {}
                            local numWheels = GetVehicleNumberOfWheels(vehicle)
                            local wheelMap = {
                                { healthIdx = 0, tyreIdx = 0, comp = 'tire_fl' },
                                { healthIdx = 1, tyreIdx = 1, comp = 'tire_fr' },
                                { healthIdx = 2, tyreIdx = 4, comp = 'tire_rl' },
                                { healthIdx = 3, tyreIdx = 5, comp = 'tire_rr' },
                            }
                            for _, w in ipairs(wheelMap) do
                                if w.healthIdx < numWheels then
                                    tireState[w.comp] = IsVehicleTyreBurst(vehicle, w.tyreIdx, false)
                                end
                            end
                            -- Windshield: skip motorcycles (8) / bicycles (13) — no windows
                            local nearbyVehClass = GetVehicleClass(vehicle)
                            local windshieldState = true
                            if nearbyVehClass ~= 8 and nearbyVehClass ~= 13 then
                                windshieldState = IsVehicleWindowIntact(vehicle, 0)
                            end

                            NearbyVehicleHealth[plate] = {
                                engine = engineHealth,
                                body = bodyHealth,
                                tires = tireState,
                                windshield = windshieldState,
                            }
                        else
                            -- Check if health dropped since last scan
                            local engineDrop = last.engine - engineHealth
                            local bodyDrop = last.body - bodyHealth

                            -- Check tires and windshield INDEPENDENTLY of engine/body damage
                            local numWheels = GetVehicleNumberOfWheels(vehicle)
                            local wheelMap = {
                                { healthIdx = 0, tyreIdx = 0, comp = 'tire_fl' },
                                { healthIdx = 1, tyreIdx = 1, comp = 'tire_fr' },
                                { healthIdx = 2, tyreIdx = 4, comp = 'tire_rl' },
                                { healthIdx = 3, tyreIdx = 5, comp = 'tire_rr' },
                            }

                            local overrides = {}
                            local hasDamage = false

                            -- Tire burst detection: compare current state to last known state
                            local newTireState = {}
                            for _, w in ipairs(wheelMap) do
                                if w.healthIdx < numWheels then
                                    local isBurst = IsVehicleTyreBurst(vehicle, w.tyreIdx, false)
                                    newTireState[w.comp] = isBurst
                                    if isBurst and not (last.tires and last.tires[w.comp]) then
                                        -- Tire just burst since last scan
                                        overrides[w.comp] = 0.0
                                        hasDamage = true
                                    elseif isBurst then
                                        -- Still burst from before, ensure server knows
                                        overrides[w.comp] = 0.0
                                        hasDamage = true
                                    else
                                        -- Not burst: sync wheel health
                                        local wheelHealth = GetVehicleWheelHealth(vehicle, w.healthIdx)
                                        local wheelPct = math.max(0.0, math.min(100.0, wheelHealth / 3.5))
                                        if wheelPct < 90 then
                                            overrides[w.comp] = wheelPct
                                            hasDamage = true
                                        end
                                    end
                                end
                            end

                            -- Windshield detection: skip motorcycles (8) / bicycles (13)
                            local scanVehClass = GetVehicleClass(vehicle)
                            local windshieldIntact = true
                            if scanVehClass ~= 8 and scanVehClass ~= 13 then
                                windshieldIntact = IsVehicleWindowIntact(vehicle, 0)
                                if not windshieldIntact and (last.windshield == nil or last.windshield) then
                                    overrides.windshield = 0.0
                                    hasDamage = true
                                elseif not windshieldIntact then
                                    overrides.windshield = 0.0
                                    hasDamage = true
                                end
                            end

                            -- Engine/body damage detection (original logic)
                            if engineDrop > 10 or bodyDrop > 10 then
                                overrides.engine_block = math.max(0.0, math.min(100.0, engineHealth / 10.0))
                                overrides.body_panels = math.max(0.0, math.min(100.0, bodyHealth / 10.0))
                                hasDamage = true
                            end

                            if hasDamage then
                                -- Calculate splash damage from engine/body impacts
                                local splash = {}
                                if engineDrop > 30 then
                                    local severity = math.min(1.0, engineDrop / 500.0)
                                    splash.radiator = 4.0 * severity
                                    splash.coolant_level = 3.0 * severity
                                    splash.spark_plugs = 2.5 * severity
                                end
                                if bodyDrop > 30 then
                                    local severity = math.min(1.0, bodyDrop / 500.0)
                                    splash.headlights = 5.0 * severity
                                    splash.taillights = 3.0 * severity
                                    splash.alignment = 4.0 * severity
                                end

                                -- Send external damage to server
                                TriggerServerEvent('sb_mechanic_v2:externalDamage', plate, overrides, splash, GetVehicleClass(vehicle))
                            end

                            -- Update baseline with current state
                            NearbyVehicleHealth[plate] = {
                                engine = engineHealth,
                                body = bodyHealth,
                                tires = newTireState,
                                windshield = windshieldIntact,
                            }
                        end
                    end
                end
            end
        end

        -- Cleanup entries for vehicles no longer nearby
        for plate, _ in pairs(NearbyVehicleHealth) do
            local found = false
            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) then
                    local vPlate = Entity(vehicle).state.sb_plate
                    if vPlate == plate then
                        local vehPos = GetEntityCoords(vehicle)
                        if #(pos - vehPos) < SCAN_RANGE + 20 then
                            found = true
                        end
                        break
                    end
                end
            end
            if not found then
                NearbyVehicleHealth[plate] = nil
            end
        end
    end
end)

-- ===== VEHICLE CONDITIONS CACHE TTL =====
-- Evict entries for vehicles no longer nearby every 60s
CreateThread(function()
    while true do
        Wait(60000)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehicles = GetGamePool('CVehicle')

        -- Build set of plates for vehicles within 150m
        local nearbyPlates = {}
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehPos = GetEntityCoords(veh)
                if #(pos - vehPos) < 150.0 then
                    local plate = Entity(veh).state.sb_plate
                    if plate then
                        nearbyPlates[plate] = true
                    end
                end
            end
        end

        -- Also keep the current vehicle's plate
        if CurrentPlate then
            nearbyPlates[CurrentPlate] = true
        end

        -- Evict stale entries
        local evicted = 0
        for plate, _ in pairs(VehicleConditions) do
            if not nearbyPlates[plate] then
                VehicleConditions[plate] = nil
                evicted = evicted + 1
            end
        end
    end
end)

-- ===== CLEANUP =====
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if CurrentVehicle ~= 0 and DoesEntityExist(CurrentVehicle) then
        ResetSymptoms(CurrentVehicle)
    end
end)

function ResetSymptoms(vehicle)
    if not DoesEntityExist(vehicle) then return end
    -- Reset non-handling symptoms (handling is restored by symptoms.lua on exit)
    SetVehicleSteerBias(vehicle, 0.0)
    SetVehicleLightMultiplier(vehicle, 1.0)
end
