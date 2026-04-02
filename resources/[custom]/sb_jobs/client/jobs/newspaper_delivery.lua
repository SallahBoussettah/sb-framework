-- ============================================================================
-- Newspaper Delivery — Client Job Logic
-- Registers handlers into the PublicJobHandlers framework
--
-- Flow:
-- 1. Player starts job at Job Center → vehicle spawns outside
-- 2. Server sends batch (area locations + newspapers added to inventory)
-- 3. Client auto-equips WEAPON_ACIDPACKAGE with ammo = newspaper count
-- 4. Player rides to delivery markers, aims, and throws newspapers
-- 5. IsProjectileTypeWithinDistance detects throw → completeDelivery
-- 6. Ammo tracking: every throw (hit or miss) removes 1 from inventory
-- 7. Player can equip/unequip newspaper from inventory or hotbar
-- 8. All delivered → next batch; return to Job Center to end shift
-- ============================================================================

-- State
local deliveryQueue = {}        -- Current batch locations
local deliveredSet = {}         -- deliveredSet[index] = true when delivered
local deliveredCount = 0        -- How many delivered in current batch
local batchActive = false       -- True while delivering a batch
local returnBlip = nil
local hasBatch = false          -- True once at least one batch was received
local waitingForBatch = false   -- True while waiting for server to assign next batch
local offRouteTimer = 0
local offRouteWarned = false
local throwDelay = false        -- Prevents double-detection of same projectile
local outOfNewspapers = false   -- True when player ran out of ammo mid-batch
local weaponHash = nil          -- Cached WEAPON_ACIDPACKAGE hash
local renderThreadActive = false
local isNewspaperEquipped = false -- True when newspaper weapon is on ped
local lastAmmoCount = nil        -- Last known ammo count (for throw detection)
local missedThrows = {}          -- Pickupable missed throws: { { coords = vec3, time = ms }, ... }
local MAX_MISSED_THROWS = 8
local MISSED_THROW_LIFETIME = 120000  -- 2 min auto-cleanup

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearReturnBlip()
    if returnBlip and DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
    returnBlip = nil
end

--- Distance to the nearest valid job point (return, vehicle spawn, current deliveries)
local function GetNearestValidDist(playerCoords, jobCfg)
    local nearest = 999999.0

    if jobCfg.returnPoint then
        local d = #(playerCoords - jobCfg.returnPoint)
        if d < nearest then nearest = d end
    end

    if jobCfg.vehicleSpawn then
        local d = #(playerCoords - vector3(jobCfg.vehicleSpawn.x, jobCfg.vehicleSpawn.y, jobCfg.vehicleSpawn.z))
        if d < nearest then nearest = d end
    end

    for _, loc in ipairs(deliveryQueue) do
        local d = #(playerCoords - loc)
        if d < nearest then nearest = d end
    end

    return nearest
end

--- GPS to nearest undelivered location
local function GPSToNearest()
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearestIdx, nearestDist = nil, 999999.0
    for i, loc in ipairs(deliveryQueue) do
        if not deliveredSet[i] then
            local d = #(playerPos - loc)
            if d < nearestDist then
                nearestIdx = i
                nearestDist = d
            end
        end
    end
    if nearestIdx then
        PJ_SetGPSToCoord(deliveryQueue[nearestIdx].x, deliveryQueue[nearestIdx].y, deliveryQueue[nearestIdx].z)
    end
end

--- Equip the newspaper weapon on the player's ped
local function EquipNewspaper(count)
    local ped = PlayerPedId()

    -- Holster any sb_weapons weapon first
    local ok, isArmed = pcall(exports['sb_weapons'].IsArmed, exports['sb_weapons'])
    if ok and isArmed then
        exports['sb_weapons']:ForceHolster()
        Wait(500)
    end

    -- Clear any existing newspaper weapon, then give fresh
    RemoveWeaponFromPed(ped, weaponHash)
    Wait(50)
    GiveWeaponToPed(ped, weaponHash, count, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
    Wait(50)

    isNewspaperEquipped = true
    lastAmmoCount = GetAmmoInPedWeapon(ped, weaponHash)

    -- Block weapon fire/aim while ALT (target eye) is held
    CreateThread(function()
        while isNewspaperEquipped do
            -- Check ALT with both normal and disabled variants (sb_target may disable the control)
            if IsControlPressed(0, 19) or IsDisabledControlPressed(0, 19) then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)  -- INPUT_ATTACK
                DisableControlAction(0, 25, true)  -- INPUT_AIM
                DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE
                DisableControlAction(0, 257, true) -- INPUT_ATTACK2
            end
            Wait(0)
        end
    end)
end

--- Unequip the newspaper weapon
local function UnequipNewspaper()
    RemoveWeaponFromPed(PlayerPedId(), weaponHash)
    isNewspaperEquipped = false
    lastAmmoCount = nil
end

--- Show "Press E" help text on screen
local function ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ============================================================================
-- EVENT: Toggle newspaper equip/unequip (from inventory use via server)
-- ============================================================================

RegisterNetEvent('sb_jobs:client:toggleNewspaper', function(count)
    if not ActivePublicJobData or ActivePublicJobData.jobId ~= 'newspaper_delivery' then return end
    if not weaponHash then return end

    if isNewspaperEquipped then
        -- Unequip
        UnequipNewspaper()
        exports['sb_notify']:Notify('Newspapers put away.', 'info', 2000)
    else
        -- Equip
        EquipNewspaper(count)
        exports['sb_notify']:Notify('Newspapers equipped - aim and throw!', 'success', 2000)
    end
end)

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobHandlers['newspaper_delivery'] = {

    -- ========================================================================
    -- ON START — Spawn vehicle, request first batch
    -- ========================================================================
    onStart = function(data, jobCfg)
        -- Reset state
        deliveryQueue = {}
        deliveredSet = {}
        deliveredCount = 0
        batchActive = false
        hasBatch = false
        waitingForBatch = true
        offRouteTimer = 0
        offRouteWarned = false
        throwDelay = false
        outOfNewspapers = false
        renderThreadActive = false
        isNewspaperEquipped = false
        lastAmmoCount = nil

        -- Clean up any lingering missed throw targets
        for _, mt in ipairs(missedThrows) do
            if mt.entity then
                exports['sb_target']:RemoveTargetEntity({mt.entity})
                if DoesEntityExist(mt.entity) then
                    SetEntityAsMissionEntity(mt.entity, true, true)
                    DeleteEntity(mt.entity)
                end
            end
        end
        missedThrows = {}

        -- Cache weapon hash
        weaponHash = GetHashKey(jobCfg.weaponName)

        -- Spawn vehicle at Job Center parking
        JobVehicle = PJ_SpawnJobVehicle(data.vehicleModel, jobCfg.vehicleSpawn, jobCfg.vehicleSpawnSlots)
        if not JobVehicle then
            TriggerServerEvent('sb_jobs:server:quitPublicJob')
            return
        end

        if data.plate then
            SetVehicleNumberPlateText(JobVehicle, data.plate)
        end

        -- Return point blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        exports['sb_notify']:Notify('Newspaper Delivery started! Your vehicle is parked outside. Getting your route...', 'success', 5000)

        -- Request first batch
        TriggerServerEvent('sb_jobs:server:requestBatch', data.jobId)
    end,

    -- ========================================================================
    -- ON BATCH READY — Receive locations, create markers/blips, auto-equip
    -- ========================================================================
    onBatchReady = function(data, jobCfg)
        local locations = data.locations
        local newspaperCount = data.newspaperCount or #locations

        -- Store state
        deliveryQueue = locations
        deliveredSet = {}
        deliveredCount = 0
        batchActive = true
        hasBatch = true
        waitingForBatch = false
        outOfNewspapers = false
        throwDelay = false

        -- Clear old blips, recreate persistent ones
        PJ_ClearAllBlips()
        ClearReturnBlip()
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        -- Create numbered delivery blips
        for i, loc in ipairs(locations) do
            JobBlips[i] = PJ_CreateNumberedBlip(loc, i, 'Delivery #' .. i)
        end

        -- GPS to nearest
        GPSToNearest()

        -- Auto-equip newspaper weapon (items were added to inventory by server)
        EquipNewspaper(newspaperCount)

        -- Start render thread for markers + projectile detection + ammo tracking + pickups
        if not renderThreadActive then
            renderThreadActive = true
            CreateThread(function()
                local drawDist = jobCfg.markerDrawDistance or 30.0
                local throwRad = jobCfg.throwRadius or 3.0

                while renderThreadActive and ActivePublicJobData and ActivePublicJobData.jobId == 'newspaper_delivery' do
                    local ped = PlayerPedId()
                    local playerPos = GetEntityCoords(ped)
                    local sleep = 500

                    if batchActive then
                        -- --------------------------------------------------------
                        -- AMMO TRACKING: detect throws (ammo decrease) + miss tracking
                        -- --------------------------------------------------------
                        if isNewspaperEquipped and lastAmmoCount ~= nil then
                            local currentAmmo = GetAmmoInPedWeapon(ped, weaponHash)
                            if currentAmmo < lastAmmoCount then
                                local thrown = lastAmmoCount - currentAmmo
                                for _ = 1, thrown do
                                    TriggerServerEvent('sb_jobs:server:newspaperUsed')
                                end

                                -- Track potential miss
                                local snapDelivered = deliveredCount
                                local newspaperModel = GetHashKey('W_AM_Papers_XM3')

                                CreateThread(function()
                                    Wait(2500)

                                    if deliveredCount == snapDelivered and batchActive and #missedThrows < MAX_MISSED_THROWS then
                                        -- Scan ALL objects, find W_AM_Papers_XM3 props NOT in our hand
                                        local myPos = GetEntityCoords(PlayerPedId())
                                        local bestProp = nil
                                        local bestDist = 40.0
                                        local objects = GetGamePool('CObject')
                                        for _, obj in ipairs(objects) do
                                            if DoesEntityExist(obj) and GetEntityModel(obj) == newspaperModel then
                                                local objPos = GetEntityCoords(obj)
                                                local d = #(myPos - objPos)
                                                -- Skip anything within 1.5m (weapon in hand) or already tracked
                                                if d > 1.5 and d < bestDist then
                                                    local alreadyTracked = false
                                                    for _, mt in ipairs(missedThrows) do
                                                        if mt.entity == obj then
                                                            alreadyTracked = true
                                                            break
                                                        end
                                                    end
                                                    if not alreadyTracked then
                                                        bestDist = d
                                                        bestProp = obj
                                                    end
                                                end
                                            end
                                        end

                                        if bestProp and DoesEntityExist(bestProp) then
                                            -- Prevent GTA from despawning the prop
                                            SetEntityAsMissionEntity(bestProp, true, true)
                                            local tName = 'pickup_newspaper_' .. bestProp
                                            exports['sb_target']:AddTargetEntity({bestProp}, {
                                                {
                                                    name = tName,
                                                    label = 'Pick up Newspaper',
                                                    icon = 'fa-newspaper',
                                                    distance = 2.5,
                                                    action = function(entity)
                                                        exports['sb_target']:RemoveTargetEntity({entity}, {tName})
                                                        TriggerServerEvent('sb_jobs:server:newspaperRecovered')
                                                        if isNewspaperEquipped then
                                                            local curAmmo = GetAmmoInPedWeapon(PlayerPedId(), weaponHash)
                                                            SetPedAmmo(PlayerPedId(), weaponHash, curAmmo + 1)
                                                            lastAmmoCount = curAmmo + 1
                                                        end
                                                        exports['sb_notify']:Notify('Newspaper picked up!', 'success', 2000)
                                                        if DoesEntityExist(entity) then
                                                            SetEntityAsMissionEntity(entity, true, true)
                                                            DeleteEntity(entity)
                                                        end
                                                        for idx = #missedThrows, 1, -1 do
                                                            if missedThrows[idx].entity == entity then
                                                                table.remove(missedThrows, idx)
                                                                break
                                                            end
                                                        end
                                                    end,
                                                    canInteract = function()
                                                        return ActivePublicJobData and ActivePublicJobData.jobId == 'newspaper_delivery'
                                                    end,
                                                }
                                            })

                                            table.insert(missedThrows, {
                                                entity = bestProp,
                                                time = GetGameTimer(),
                                            })
                                            exports['sb_notify']:Notify('Missed throw! Look for the newspaper nearby.', 'info', 3000)
                                        end
                                    end
                                end)
                            end
                            lastAmmoCount = currentAmmo
                        end

                        -- --------------------------------------------------------
                        -- AUTO-UNEQUIP: detect if player switched weapon
                        -- --------------------------------------------------------
                        if isNewspaperEquipped then
                            local currentWeapon = GetSelectedPedWeapon(ped)
                            if currentWeapon ~= weaponHash then
                                isNewspaperEquipped = false
                                lastAmmoCount = nil
                                RemoveWeaponFromPed(ped, weaponHash)
                            end
                        end

                        -- --------------------------------------------------------
                        -- MARKER DRAWING + PROJECTILE DETECTION
                        -- --------------------------------------------------------
                        for i, loc in ipairs(deliveryQueue) do
                            if not deliveredSet[i] then
                                local dist = #(playerPos - loc)

                                if dist < 50.0 then
                                    sleep = 0
                                end

                                if dist < drawDist then
                                    DrawMarker(
                                        1,
                                        loc.x, loc.y, loc.z - 1.5,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        4.0, 4.0, 2.0,
                                        227, 14, 88, 165,
                                        false, false, 2, false, nil, nil, false
                                    )

                                    if not throwDelay and IsProjectileTypeWithinDistance(loc.x, loc.y, loc.z, weaponHash, throwRad, true) then
                                        throwDelay = true
                                        TriggerServerEvent('sb_jobs:server:completeDelivery', 'newspaper_delivery', i)

                                        CreateThread(function()
                                            Wait(1500)
                                            throwDelay = false
                                        end)
                                    end
                                end
                            end
                        end
                    end

                    -- --------------------------------------------------------
                    -- MISSED THROW PICKUPS (entity lifecycle only)
                    -- sb_target handles all interaction — we just track expiry
                    -- --------------------------------------------------------
                    if #missedThrows > 0 then
                        local now = GetGameTimer()
                        for i = #missedThrows, 1, -1 do
                            local mt = missedThrows[i]
                            if now - mt.time > MISSED_THROW_LIFETIME then
                                -- Expired: clean up target and entity
                                if mt.entity then
                                    exports['sb_target']:RemoveTargetEntity({mt.entity})
                                    if DoesEntityExist(mt.entity) then
                                        SetEntityAsMissionEntity(mt.entity, true, true)
                                        DeleteEntity(mt.entity)
                                    end
                                end
                                table.remove(missedThrows, i)
                            elseif mt.entity and not DoesEntityExist(mt.entity) then
                                -- Entity cleaned up by GTA
                                table.remove(missedThrows, i)
                            end
                        end
                    end

                    Wait(sleep)
                end

                renderThreadActive = false
            end)
        end

        exports['sb_notify']:Notify(newspaperCount .. ' newspapers to deliver in ' .. data.areaLabel .. '. Use your inventory or hotbar to equip/unequip. Aim and throw at the pink markers!', 'success', 7000)
    end,

    -- ========================================================================
    -- ON TASK COMPLETE — Remove blip, GPS to next or request new batch
    -- ========================================================================
    onTaskComplete = function(data, jobCfg)
        local payMsg = '$' .. data.pay
        if data.tip > 0 then
            payMsg = payMsg .. ' + $' .. data.tip .. ' tip'
        end
        exports['sb_notify']:Notify('Delivery #' .. data.index .. ' complete! ' .. payMsg .. ' (+' .. data.xp .. ' XP)', 'success', 4000)

        -- Mark as delivered
        deliveredSet[data.index] = true
        deliveredCount = deliveredCount + 1

        -- Remove delivered blip
        if JobBlips[data.index] and DoesBlipExist(JobBlips[data.index]) then
            RemoveBlip(JobBlips[data.index])
            JobBlips[data.index] = nil
        end

        -- Check if batch done
        if deliveredCount >= #deliveryQueue then
            batchActive = false
            UnequipNewspaper()

            if PendingVehicleSwap then
                waitingForBatch = false
                exports['sb_notify']:Notify('Route complete! Return to the Job Center to swap your vehicle.', 'success', 8000)
                PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
            else
                waitingForBatch = true
                exports['sb_notify']:Notify('Route complete! Getting next area... Or return your vehicle to end your shift.', 'success', 8000)

                if ActivePublicJobData then
                    TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
                end
            end
        else
            GPSToNearest()
            local remaining = #deliveryQueue - deliveredCount
            exports['sb_notify']:Notify(remaining .. ' newspapers remaining', 'info', 3000)
        end
    end,

    -- ========================================================================
    -- ON END — Clean up all state
    -- ========================================================================
    onEnd = function(jobCfg)
        -- Remove weapon from ped
        if weaponHash then
            UnequipNewspaper()
        end

        -- Reset state
        deliveryQueue = {}
        deliveredSet = {}
        deliveredCount = 0
        batchActive = false
        hasBatch = false
        waitingForBatch = false
        offRouteTimer = 0
        offRouteWarned = false
        throwDelay = false
        outOfNewspapers = false
        renderThreadActive = false
        isNewspaperEquipped = false
        lastAmmoCount = nil

        -- Clean up missed throw targets and props
        for _, mt in ipairs(missedThrows) do
            if mt.entity then
                exports['sb_target']:RemoveTargetEntity({mt.entity})
                if DoesEntityExist(mt.entity) then
                    SetEntityAsMissionEntity(mt.entity, true, true)
                    DeleteEntity(mt.entity)
                end
            end
        end
        missedThrows = {}

        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        ClearReturnBlip()

        exports['sb_notify']:Notify('Newspaper delivery shift ended. Your progress has been saved.', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TICK — Out-of-ammo detection, return-to-base, off-route (every 500ms)
    -- ========================================================================
    onTick = function(jobCfg)
        if not ActivePublicJobData then return end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        -- ----------------------------------------------------------------
        -- CHECK: Out of newspapers mid-batch
        -- Weapon removed by GTA when ammo = 0 → player can't throw anymore
        -- ----------------------------------------------------------------
        if batchActive and weaponHash and not throwDelay and not outOfNewspapers then
            if deliveredCount < #deliveryQueue and isNewspaperEquipped then
                if not HasPedGotWeapon(ped, weaponHash, false) then
                    -- Ammo reached 0, weapon auto-removed by GTA
                    isNewspaperEquipped = false
                    lastAmmoCount = nil
                    outOfNewspapers = true
                    batchActive = false

                    exports['sb_notify']:Notify('Out of newspapers! Route incomplete. Getting next area...', 'error', 6000)

                    if PendingVehicleSwap then
                        waitingForBatch = false
                        PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
                    else
                        waitingForBatch = true
                        if ActivePublicJobData then
                            TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
                        end
                    end
                end
            end
        end

        -- ----------------------------------------------------------------
        -- CHECK: At Job Center return point (vehicle swap or end shift)
        -- Only when NOT in the middle of delivering
        -- ----------------------------------------------------------------
        if not batchActive and hasBatch and jobCfg.returnPoint then
            local returnDist = #(playerCoords - jobCfg.returnPoint)
            local radius = jobCfg.returnRadius or 8.0

            if returnDist < radius then
                if PendingVehicleSwap then
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Swapping vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    TriggerServerEvent('sb_jobs:server:swapVehicle')
                elseif not waitingForBatch then
                    exports['sb_progressbar']:Start({ duration = 3000, label = 'Returning vehicle...' })
                    Wait(3000)
                    if not ActivePublicJobData then return end
                    TriggerServerEvent('sb_jobs:server:quitPublicJob')
                end
            end
        end

        -- ----------------------------------------------------------------
        -- ANTI-ABUSE: Off-route vehicle detection
        -- >400m from all valid points for 30s → warning, 60s → confiscate
        -- ----------------------------------------------------------------
        if JobVehicle and DoesEntityExist(JobVehicle) and IsPedInVehicle(ped, JobVehicle, false) then
            local nearestDist = GetNearestValidDist(playerCoords, jobCfg)

            if nearestDist > 400.0 then
                offRouteTimer = offRouteTimer + 0.5

                if offRouteTimer >= 30.0 and not offRouteWarned then
                    offRouteWarned = true
                    exports['sb_notify']:Notify('You are going off-route! Return to your delivery area or your vehicle will be confiscated and you will be fined $100.', 'error', 10000)
                end

                if offRouteTimer >= 60.0 then
                    UnequipNewspaper()
                    PJ_DeleteJobVehicle()
                    TriggerServerEvent('sb_jobs:server:vehicleConfiscated')
                    return
                end
            else
                offRouteTimer = 0
                offRouteWarned = false
            end
        else
            offRouteTimer = 0
            offRouteWarned = false
        end
    end,
}
