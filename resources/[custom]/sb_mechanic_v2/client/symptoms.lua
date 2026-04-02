-- sb_mechanic_v2 | Client Symptoms
-- Apply driving effects based on condition using HANDLING MODIFICATIONS
-- Inspired by jg-mechanic's calculateServicingHandling() approach
-- Modifies actual vehicle handling floats proportionally to base values
-- Driver sees NO numbers — they FEEL the car breaking down

-- ===== SYMPTOM STATE =====
local stalling = false
local nextStallTime = 0
local stallEndTime = 0
local steerBiasDirection = 0  -- -1 or 1, randomized per alignment issue
local clutchSlipping = false
local lastGear = 0
local overheatParticle = nil

-- ===== ORIGINAL HANDLING CACHE =====
-- Captured once when entering a vehicle, restored on exit
local OriginalHandling = nil

local function CaptureOriginalHandling(vehicle)
    OriginalHandling = {
        fInitialDriveForce       = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce'),
        fBrakeForce              = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce'),
        fTractionCurveMin        = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin'),
        fTractionCurveMax        = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
        fSuspensionForce         = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce'),
        fAntiRollBarForce        = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fAntiRollBarForce'),
        fRollCentreHeightFront   = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightFront'),
        fRollCentreHeightRear    = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightRear'),
        fDriveInertia            = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveInertia'),
        fClutchChangeRateScaleUpShift   = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift'),
        fClutchChangeRateScaleDownShift = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift'),
    }
end

local function RestoreOriginalHandling(vehicle)
    if not OriginalHandling then return end
    if not DoesEntityExist(vehicle) then return end

    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce', OriginalHandling.fInitialDriveForce)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', OriginalHandling.fBrakeForce)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', OriginalHandling.fTractionCurveMin)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', OriginalHandling.fTractionCurveMax)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce', OriginalHandling.fSuspensionForce)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fAntiRollBarForce', OriginalHandling.fAntiRollBarForce)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightFront', OriginalHandling.fRollCentreHeightFront)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightRear', OriginalHandling.fRollCentreHeightRear)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveInertia', OriginalHandling.fDriveInertia)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift', OriginalHandling.fClutchChangeRateScaleUpShift)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift', OriginalHandling.fClutchChangeRateScaleDownShift)

    OriginalHandling = nil
end

-- ===== HANDLING MATH =====
-- Lerp from original value down to minFraction based on damage (0-1)
-- damage = 0 means full health (return original), damage = 1 means worst (return original * minFraction)
local function ScaleHandling(original, minFraction, damage)
    return original * (minFraction + (1.0 - minFraction) * (1.0 - damage))
end

-- ===== MAIN SYMPTOM LOOP (5Hz) =====
CreateThread(function()
    while true do
        Wait(Config.SymptomTickRate)

        if not IsInVehicle or not IsTrackedVehicle or CurrentVehicle == 0 or not CurrentPlate then
            goto continue
        end

        local vehicle = CurrentVehicle
        if not DoesEntityExist(vehicle) then goto continue end

        local cond = VehicleConditions[CurrentPlate]
        if not cond then goto continue end

        local ped = PlayerPedId()
        -- Only apply if player is driver
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then goto continue end

        -- Capture original handling on first symptom tick
        if not OriginalHandling then
            CaptureOriginalHandling(vehicle)
        end

        local gameTime = GetGameTimer()
        local speed = GetEntitySpeed(vehicle) * 3.6  -- km/h
        local oh = OriginalHandling  -- shorthand

        -- ===== SPARK PLUGS: Engine Stalls + Drive Inertia =====
        if cond.spark_plugs and cond.spark_plugs < 30 then
            if not stalling and gameTime > nextStallTime then
                stalling = true
                stallEndTime = gameTime + (Config.Stall.duration * 1000)
                SetVehicleEngineOn(vehicle, false, true, true)

                local severity = 1 - (cond.spark_plugs / 30)
                local minInt = Config.Stall.minInterval * (1 - severity * 0.5)
                local maxInt = Config.Stall.maxInterval * (1 - severity * 0.6)
                nextStallTime = gameTime + math.random(math.floor(minInt * 1000), math.floor(maxInt * 1000))
            end

            if stalling and gameTime > stallEndTime then
                stalling = false
                SetVehicleEngineOn(vehicle, true, false, true)
            end

            -- Spark plugs affect drive inertia (engine responsiveness)
            local damage = 1 - (cond.spark_plugs / 30)  -- 0 to 1
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveInertia',
                ScaleHandling(oh.fDriveInertia, 0.3, damage))
        else
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDriveInertia', oh.fDriveInertia)
        end

        -- ===== ENGINE BLOCK + OIL: Drive Force (Power) =====
        -- Combines engine_block, oil_level, oil_quality, air_filter into one power multiplier
        -- Uses fInitialDriveForce — scales proportionally to the car's actual power
        local powerMult = 1.0
        local safeguard = Config.EngineDegradation.safeguardFloor

        if cond.engine_block then
            if cond.engine_block <= safeguard then
                -- LIMP MODE: 15% of original power
                powerMult = 0.15

                -- Push safeguard to GTA native so engine doesn't visually die
                local nativeTarget = safeguard * 10.0
                local currentNative = GetVehicleEngineHealth(vehicle)
                if currentNative < nativeTarget then
                    SetVehicleEngineHealth(vehicle, nativeTarget)
                end

                -- Frequent stalls in limp mode
                if not stalling and math.random() < 0.04 and speed > 5 then
                    stalling = true
                    stallEndTime = gameTime + 3500
                    SetVehicleEngineOn(vehicle, false, true, true)
                    nextStallTime = gameTime + math.random(4000, 10000)
                end
            elseif cond.engine_block < 15 then
                -- Engine badly damaged — 35% power + occasional stalls
                powerMult = 0.35

                if not stalling and math.random() < 0.02 and speed > 10 then
                    stalling = true
                    stallEndTime = gameTime + 3000
                    SetVehicleEngineOn(vehicle, false, true, true)
                    nextStallTime = gameTime + math.random(3000, 8000)
                end
            elseif cond.engine_block < Config.EngineDegradation.cascadingThreshold then
                -- Engine in cascade zone — 65% power
                powerMult = 0.65
            end
        end

        -- Oil stacks on top of engine damage (only if engine isn't already in limp/cascade)
        if powerMult >= 0.65 then
            if cond.oil_level and cond.oil_level < 20 then
                powerMult = powerMult * 0.6
            elseif cond.oil_quality and cond.oil_quality < 25 then
                powerMult = powerMult * 0.8
            end

            -- Air filter affects power too
            if cond.air_filter and cond.air_filter < 20 then
                powerMult = powerMult * 0.85
            end
        end

        -- Apply power via fInitialDriveForce (proportional to the car's actual power)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce',
            oh.fInitialDriveForce * math.max(0.10, powerMult))

        -- ===== COOLANT: Overheat / Steam =====
        if cond.coolant_level and cond.coolant_level < 20 then
            if not overheatParticle or not DoesParticleFxLoopedExist(overheatParticle) then
                RequestNamedPtfxAsset('core')
                if HasNamedPtfxAssetLoaded('core') then
                    SetPtfxAssetNextCall('core')
                    local boneIndex = GetEntityBoneIndexByName(vehicle, 'bonnet')
                    if boneIndex ~= -1 then
                        overheatParticle = StartParticleFxLoopedOnEntityBone(
                            'ent_ray_heathaze', vehicle,
                            0.0, 0.0, 0.2, 0.0, 0.0, 0.0,
                            boneIndex, 1.5, false, false, false
                        )
                    end
                end
            end

            if not stalling and math.random() < 0.01 and speed > 5 then
                stalling = true
                stallEndTime = gameTime + 2000
                SetVehicleEngineOn(vehicle, false, true, true)
                nextStallTime = gameTime + math.random(5000, 15000)
            end
        else
            if overheatParticle and DoesParticleFxLoopedExist(overheatParticle) then
                StopParticleFxLooped(overheatParticle, false)
                overheatParticle = nil
            end
        end

        -- ===== BATTERY: Dim Lights =====
        if cond.battery and cond.battery < 15 then
            SetVehicleLightMultiplier(vehicle, 0.2)
        elseif cond.alternator and cond.alternator < 20 then
            SetVehicleLightMultiplier(vehicle, 0.5)
        else
            SetVehicleLightMultiplier(vehicle, 1.0)
        end

        -- ===== BRAKES: fBrakeForce (proportional to car's actual brakes) =====
        local brakeMult = 1.0
        if cond.brake_fluid and cond.brake_fluid < 15 then
            brakeMult = 0.15
        elseif (cond.brake_pads_front and cond.brake_pads_front < 20) or
               (cond.brake_pads_rear and cond.brake_pads_rear < 20) then
            -- Scale by worst brake pad
            local worstPad = 100
            if cond.brake_pads_front then worstPad = math.min(worstPad, cond.brake_pads_front) end
            if cond.brake_pads_rear then worstPad = math.min(worstPad, cond.brake_pads_rear) end
            local damage = 1 - (worstPad / 20)  -- 0 to 1
            brakeMult = 1.0 - (damage * 0.6)    -- 1.0 down to 0.4
        end

        -- Brake rotors add additional degradation
        if cond.brake_rotors and cond.brake_rotors < 25 then
            local rotorDamage = 1 - (cond.brake_rotors / 25)
            brakeMult = brakeMult * (1.0 - rotorDamage * 0.3)
        end

        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce',
            oh.fBrakeForce * math.max(0.10, brakeMult))

        -- ===== SUSPENSION: fSuspensionForce + fAntiRollBarForce + Roll Center =====
        local suspDamage = 0
        if cond.shocks_front and cond.shocks_front < 30 then
            suspDamage = math.max(suspDamage, 1 - (cond.shocks_front / 30))
        end
        if cond.shocks_rear and cond.shocks_rear < 30 then
            suspDamage = math.max(suspDamage, 1 - (cond.shocks_rear / 30))
        end

        -- Springs contribute too
        if cond.springs and cond.springs < 30 then
            local springDamage = 1 - (cond.springs / 30)
            suspDamage = math.max(suspDamage, springDamage * 0.7)
        end

        if suspDamage > 0 then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce',
                ScaleHandling(oh.fSuspensionForce, 0.3, suspDamage))
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fAntiRollBarForce',
                ScaleHandling(oh.fAntiRollBarForce, 0.2, suspDamage))
            -- Raise roll center to simulate body roll
            local rollMod = suspDamage * 0.15
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightFront',
                oh.fRollCentreHeightFront + rollMod)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightRear',
                oh.fRollCentreHeightRear + rollMod)
        else
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce', oh.fSuspensionForce)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fAntiRollBarForce', oh.fAntiRollBarForce)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightFront', oh.fRollCentreHeightFront)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fRollCentreHeightRear', oh.fRollCentreHeightRear)
        end

        -- ===== TIRES: Traction (fTractionCurveMin/Max) =====
        local tireDamage = 0
        local tireComps = { 'tire_fl', 'tire_fr', 'tire_rl', 'tire_rr' }
        for _, comp in ipairs(tireComps) do
            if cond[comp] and cond[comp] < 40 then
                local dmg = 1 - (cond[comp] / 40)
                tireDamage = math.max(tireDamage, dmg)
            end
        end

        -- Wheel bearings also affect traction
        if cond.wheel_bearings and cond.wheel_bearings < 25 then
            local bearingDmg = 1 - (cond.wheel_bearings / 25)
            tireDamage = math.max(tireDamage, bearingDmg * 0.5)
        end

        if tireDamage > 0 then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin',
                ScaleHandling(oh.fTractionCurveMin, 0.3, tireDamage))
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax',
                ScaleHandling(oh.fTractionCurveMax, 0.4, tireDamage))
        else
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', oh.fTractionCurveMin)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', oh.fTractionCurveMax)
        end

        -- ===== ALIGNMENT: Steering Pull =====
        if cond.alignment and cond.alignment < 30 then
            if steerBiasDirection == 0 then
                steerBiasDirection = math.random() > 0.5 and 1 or -1
            end
            local severity = 1 - (cond.alignment / 30)
            local bias = steerBiasDirection * severity * 0.3
            SetVehicleSteerBias(vehicle, bias)
        else
            if steerBiasDirection ~= 0 then
                SetVehicleSteerBias(vehicle, 0.0)
                steerBiasDirection = 0
            end
        end

        -- ===== CLUTCH: Gear Shift Rates =====
        if cond.clutch and cond.clutch < 25 then
            local damage = 1 - (cond.clutch / 25)

            -- Slow down gear shifts
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift',
                ScaleHandling(oh.fClutchChangeRateScaleUpShift, 0.2, damage))
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift',
                ScaleHandling(oh.fClutchChangeRateScaleDownShift, 0.2, damage))

            -- Momentary power dip on gear change
            local currentGear = GetVehicleCurrentGear(vehicle)
            if currentGear ~= lastGear and lastGear ~= 0 then
                if not clutchSlipping then
                    clutchSlipping = true
                    -- Temporarily slam drive force way down
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce',
                        oh.fInitialDriveForce * 0.15)
                    SetTimeout(400, function()
                        clutchSlipping = false
                        -- Will be restored next symptom tick
                    end)
                end
            end
            lastGear = currentGear
        else
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleUpShift',
                oh.fClutchChangeRateScaleUpShift)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fClutchChangeRateScaleDownShift',
                oh.fClutchChangeRateScaleDownShift)
        end

        -- ===== TRANSMISSION: Additional Power Loss =====
        if cond.transmission and cond.transmission < 25 then
            local damage = 1 - (cond.transmission / 25)
            -- Stack on current fInitialDriveForce (which already has engine/oil applied)
            local currentForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
            local transPenalty = 1.0 - (damage * 0.3)  -- up to 30% additional loss
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce',
                currentForce * transPenalty)
        end

        -- ===== PUSH WEAR DAMAGE BACK TO GTA NATIVES =====
        if cond.engine_block and cond.engine_block < 50 then
            local safeguardNative = Config.EngineDegradation.safeguardFloor * 10.0
            local currentNative = GetVehicleEngineHealth(vehicle)
            local wearTarget = math.max(safeguardNative, cond.engine_block * 10.0)
            if wearTarget < currentNative then
                SetVehicleEngineHealth(vehicle, wearTarget)
            end
        end

        if cond.body_panels and cond.body_panels < 50 then
            local currentNative = GetVehicleBodyHealth(vehicle)
            local wearTarget = cond.body_panels * 10.0
            if wearTarget < currentNative then
                SetVehicleBodyHealth(vehicle, wearTarget)
            end
        end

        -- ===== TIRES: Push wear to GTA + Blowout Risk =====
        local numWheels = GetVehicleNumberOfWheels(vehicle)
        local tires = {
            { comp = 'tire_fl', healthIdx = 0, tyreIdx = 0 },
            { comp = 'tire_fr', healthIdx = 1, tyreIdx = 1 },
            { comp = 'tire_rl', healthIdx = 2, tyreIdx = 4 },
            { comp = 'tire_rr', healthIdx = 3, tyreIdx = 5 },
        }

        for _, tire in ipairs(tires) do
            if tire.healthIdx >= numWheels then goto nextTire end
            local val = cond[tire.comp]
            if val then
                if val == 0 then
                    if not IsVehicleTyreBurst(vehicle, tire.tyreIdx, false) then
                        SetVehicleTyreBurst(vehicle, tire.tyreIdx, true, 1000.0)
                    end
                elseif val < 20 then
                    local wheelHealth = val / 20 * 350
                    local currentWheelHealth = GetVehicleWheelHealth(vehicle, tire.healthIdx)
                    if wheelHealth < currentWheelHealth then
                        SetVehicleWheelHealth(vehicle, tire.healthIdx, math.max(50.0, wheelHealth))
                    end

                    if val < 8 and speed > 40 and math.random() < 0.003 then
                        SetVehicleTyreBurst(vehicle, tire.tyreIdx, true, 1000.0)
                    end
                end
            end
            ::nextTire::
        end

        -- ===== WIRING: Electrical Flicker =====
        if cond.wiring and cond.wiring < 30 then
            if math.random() < 0.03 then
                SetVehicleLights(vehicle, 1)
                SetTimeout(math.random(100, 300), function()
                    if DoesEntityExist(vehicle) then
                        SetVehicleLights(vehicle, 0)
                    end
                end)
            end
        end

        ::continue::
    end
end)

-- ===== CLEANUP ON VEHICLE EXIT =====
CreateThread(function()
    local wasInVehicle = false
    local lastVehicle = 0

    while true do
        Wait(500)

        if IsInVehicle and not wasInVehicle then
            -- Just entered
            lastVehicle = CurrentVehicle
            steerBiasDirection = 0
            lastGear = 0
            OriginalHandling = nil  -- Will be captured on first symptom tick
        elseif not IsInVehicle and wasInVehicle then
            -- Just exited — restore ALL handling to original values
            if lastVehicle ~= 0 and DoesEntityExist(lastVehicle) then
                RestoreOriginalHandling(lastVehicle)
                SetVehicleSteerBias(lastVehicle, 0.0)
                SetVehicleLightMultiplier(lastVehicle, 1.0)

                if overheatParticle and DoesParticleFxLoopedExist(overheatParticle) then
                    StopParticleFxLooped(overheatParticle, false)
                    overheatParticle = nil
                end

                stalling = false
                steerBiasDirection = 0
                lastGear = 0
            end
            lastVehicle = 0
            OriginalHandling = nil
        end

        wasInVehicle = IsInVehicle
    end
end)
