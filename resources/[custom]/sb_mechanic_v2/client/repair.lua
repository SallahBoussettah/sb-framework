-- sb_mechanic_v2 | Client Repair Logic (Staged Visual Flow)
-- Approach → Setup → Work → Cleanup with cancel support

local SB = exports['sb_core']:GetCoreObject()

-- ===== FAIL TRACKING (per session) =====
local RepairFails = {}

-- ===== REPAIR STATE =====
RepairBusy = false  -- global so repair_targets.lua can read it
local RepairCancelled = false

-- ===== HELPER: Check if player is in workshop zone =====
local function IsInWorkshop()
    local pos = GetEntityCoords(PlayerPedId())
    local dist = #(pos - Config.WorkshopZone.coords)
    return dist <= Config.WorkshopZone.radius
end

-- ===== HELPER: Load anim dict =====
local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    return HasAnimDictLoaded(dict)
end

-- ===== HELPER: Get world position for repair zone =====
local function GetApproachPosition(vehicle, zone)
    local vehPos = GetEntityCoords(vehicle)
    local vehHeading = GetEntityHeading(vehicle)

    if zone.approachBone then
        local boneIndex = GetEntityBoneIndexByName(vehicle, zone.approachBone)
        if boneIndex ~= -1 then
            vehPos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        end
    end

    -- Apply offset relative to vehicle heading
    local headingRad = math.rad(vehHeading)
    local offset = zone.approachOffset
    local worldX = vehPos.x + offset.x * math.cos(headingRad) - offset.y * math.sin(headingRad)
    local worldY = vehPos.y + offset.x * math.sin(headingRad) + offset.y * math.cos(headingRad)
    local worldZ = vehPos.z + offset.z

    return vector3(worldX, worldY, worldZ)
end

-- ===== HELPER: Face entity =====
local function FaceEntity(entity)
    local ped = PlayerPedId()
    local pedPos = GetEntityCoords(ped)
    local targetPos = GetEntityCoords(entity)
    local dx = targetPos.x - pedPos.x
    local dy = targetPos.y - pedPos.y
    local heading = math.deg(math.atan(dx, dy))
    if heading < 0 then heading = heading + 360.0 end
    SetEntityHeading(ped, heading)
end

-- ===== CANCEL INPUT MONITOR =====
-- Returns a function that checks if repair was cancelled
local function StartCancelMonitor()
    RepairCancelled = false

    CreateThread(function()
        while RepairBusy and not RepairCancelled do
            Wait(0)
            -- X key (73) or Backspace (194) to cancel
            DisableControlAction(0, 73, true)
            DisableControlAction(0, 194, true)
            if IsDisabledControlJustReleased(0, 73) or IsDisabledControlJustReleased(0, 194) then
                RepairCancelled = true
                exports['sb_notify']:Notify('Repair cancelled.', 'error', 2000)
            end
        end
    end)
end

-- ===== FULL CLEANUP =====
local function FullCleanup(vehicle, zone, hoodOpened)
    -- Stop animation
    ClearPedTasks(PlayerPedId())

    -- Stop VFX
    RepairVFX.StopAll()

    -- Remove all props
    RepairProps.CleanupAll()

    -- Close hood if we opened it
    if hoodOpened and vehicle and DoesEntityExist(vehicle) then
        RepairProps.CloseHood(vehicle)
    end

    RepairBusy = false
    RepairCancelled = false
end

-- ===== PERFORM REPAIR (STAGED FLOW) =====
-- Called from repair_targets.lua when player ALT-clicks a vehicle bone
function PerformRepair(entity, repairKey)
    if RepairBusy then return end

    local plate = Entity(entity).state.sb_plate
    if not plate then
        exports['sb_notify']:Notify('Cannot identify vehicle.', 'error', 3000)
        return
    end

    local def = Repairs.Definitions[repairKey]
    if not def then return end

    local zone, zoneName = RepairZones.GetZoneForRepair(repairKey)
    if not zone then
        -- Fallback: run repair without zone visuals
        zone = RepairZones.Definitions['engine']
        zoneName = 'engine'
    end

    RepairBusy = true
    local hoodOpened = false

    -- =========================================
    -- STAGE 1: VALIDATE (server check)
    -- =========================================
    SB.Functions.TriggerCallback('sb_mechanic_v2:checkRepairReqs', function(result)
        if not result then
            RepairBusy = false
            return
        end

        if not result.canRepair then
            exports['sb_notify']:Notify(result.reason or 'Cannot repair', 'error', 4000)
            RepairBusy = false
            return
        end

        -- Check lift requirement
        if zone.requiresLift and not CarJack.IsLifted(entity) then
            exports['sb_notify']:Notify('Vehicle must be lifted first (use car jack or elevator).', 'error', 4000)
            RepairBusy = false
            return
        end

        -- Start cancel monitor
        StartCancelMonitor()

        -- =========================================
        -- STAGE 2: APPROACH (walk to position)
        -- =========================================
        local approachPos = GetApproachPosition(entity, zone)
        local ped = PlayerPedId()

        TaskGoStraightToCoord(ped, approachPos.x, approachPos.y, approachPos.z, 1.0, 5000, GetEntityHeading(entity), 0.5)

        -- Wait for player to arrive or cancel
        local arrived = false
        local approachTimeout = GetGameTimer() + 8000
        while not arrived and not RepairCancelled do
            Wait(200)
            local pedPos = GetEntityCoords(ped)
            local dist = #(pedPos - approachPos)
            if dist < 1.5 then
                arrived = true
            end
            if GetGameTimer() > approachTimeout then
                arrived = true  -- timeout, proceed anyway if close enough
            end
            if not DoesEntityExist(entity) then
                FullCleanup(entity, zone, hoodOpened)
                return
            end
        end

        if RepairCancelled then
            FullCleanup(entity, zone, hoodOpened)
            return
        end

        -- Face the vehicle
        FaceEntity(entity)
        Wait(300)

        -- =========================================
        -- STAGE 3: SETUP (props, hood, hand tool)
        -- =========================================
        if RepairCancelled then
            FullCleanup(entity, zone, hoodOpened)
            return
        end

        -- Open hood if needed
        if zone.setup and zone.setup.openHood then
            RepairProps.OpenHood(entity)
            hoodOpened = true
            Wait(500)
        end

        -- Spawn ground props (toolbox etc.)
        RepairProps.SpawnZoneGroundProps(entity, zone)

        -- Attach hand prop
        local handPropModel = RepairZones.GetHandProp(repairKey)
        if handPropModel then
            RepairProps.AttachHandProp(handPropModel)
        end

        -- Safety timer: auto-cleanup after max duration
        local animDuration = def.animation and def.animation.duration or 8000
        RepairProps.StartSafetyTimer(animDuration + 15000)

        Wait(500)  -- brief pause for visual setup

        if RepairCancelled then
            FullCleanup(entity, zone, hoodOpened)
            return
        end

        -- =========================================
        -- STAGE 4: WORK (animation + minigame/progress)
        -- =========================================
        local animDict = zone.workAnim and zone.workAnim.dict or (def.animation and def.animation.dict) or 'mini@repair'
        local animName = zone.workAnim and zone.workAnim.anim or (def.animation and def.animation.anim) or 'fixing_a_ped'
        local animFlag = zone.workAnim and zone.workAnim.flag or 1

        LoadAnimDict(animDict)
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, animFlag, 0, false, false, false)

        -- Start particle effects
        local particleKey = RepairZones.GetParticles(repairKey)
        if particleKey then
            RepairVFX.Start(particleKey)
        end

        -- Run minigame or progress bar
        local minigamePassed = true
        local failKey = plate .. ':' .. repairKey

        if def.minigame and not def.isFluid then
            -- Minigame
            local finished = false
            exports['sb_minigame']:Start({
                type = def.minigame.type,
                difficulty = def.minigame.difficulty,
                rounds = def.minigame.rounds,
                label = def.label,
            }, function(success, score)
                minigamePassed = success
                finished = true
            end)

            while not finished and not RepairCancelled do
                Wait(100)
                if not DoesEntityExist(entity) then
                    FullCleanup(entity, zone, hoodOpened)
                    return
                end
            end
        else
            -- Progress bar (fluids / no-minigame)
            local progressFinished = false
            local progressSuccess = false
            exports['sb_progressbar']:Start({
                duration = animDuration,
                label = def.label .. '...',
                canCancel = true,
                onComplete = function()
                    progressSuccess = true
                    progressFinished = true
                end,
                onCancel = function()
                    progressSuccess = false
                    progressFinished = true
                end,
            })

            while not progressFinished and not RepairCancelled do
                Wait(100)
                if not DoesEntityExist(entity) then
                    FullCleanup(entity, zone, hoodOpened)
                    return
                end
            end
            minigamePassed = progressSuccess
        end

        -- Check cancel during work
        if RepairCancelled then
            FullCleanup(entity, zone, hoodOpened)
            return
        end

        -- Stop animation (keep props until cleanup)
        ClearPedTasks(ped)
        RepairVFX.StopAll()

        -- =========================================
        -- STAGE 5: RESULT
        -- =========================================
        if not minigamePassed then
            RepairFails[failKey] = (RepairFails[failKey] or 0) + 1
            local fails = RepairFails[failKey]

            if fails >= 2 then
                exports['sb_notify']:Notify('Failed again - part used at 50% effectiveness', 'error', 4000)
                local inWorkshop = IsInWorkshop()
                SB.Functions.TriggerCallback('sb_mechanic_v2:repairComponent', function(res)
                    if res and res.success then
                        local msg = ('%s (partial) - %s quality'):format(def.label, res.qualityLabel or 'Standard')
                        exports['sb_notify']:Notify(msg, 'warning', 4000)
                        if res.xpGain and res.xpGain > 0 then
                            exports['sb_notify']:Notify('+' .. res.xpGain .. ' XP', 'info', 2000)
                        end
                    end
                    RepairFails[failKey] = nil
                    FullCleanup(entity, zone, hoodOpened)
                end, plate, repairKey, fails, inWorkshop)
            else
                exports['sb_notify']:Notify('Repair failed - try again (materials saved)', 'error', 3000)
                FullCleanup(entity, zone, hoodOpened)
            end
            return
        end

        -- Success
        local failCount = RepairFails[failKey] or 0
        local inWorkshop = IsInWorkshop()

        SB.Functions.TriggerCallback('sb_mechanic_v2:repairComponent', function(res)
            if res and res.success then
                local msg = ('%s (+%d XP)'):format(def.label, res.xpGain or 0)
                exports['sb_notify']:Notify(msg, 'success', 4000)
                if res.qualityLabel then
                    exports['sb_notify']:Notify(res.qualityLabel .. ' quality - restored to ' .. math.floor(res.newValue or 0) .. '%', 'info', 3000)
                end
            else
                exports['sb_notify']:Notify('Repair failed on server', 'error', 3000)
            end
            RepairFails[failKey] = nil

            -- =========================================
            -- STAGE 6: CLEANUP (always runs)
            -- =========================================
            FullCleanup(entity, zone, hoodOpened)
        end, plate, repairKey, failCount, inWorkshop)

    end, repairKey, plate)
end
