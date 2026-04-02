-- sb_target: Main Client
-- Core raycast loop, activation, NUI communication, entity highlights

local SB = nil
local isActive = false
local isLoggedIn = false
local currentEntity = 0
local currentOptions = {}  -- Full list shown to user (entity + zones)
local cachedEntityOpts = {} -- Entity-only options cache
local menuOpen = false
local lastZoneCheck = 0
local lastCleanup = 0
local zoneOptions = {}
local leftClickPending = false

-- Performance caches
local lastCrosshairState = nil
local cachedPlayerJob = 'unemployed'
local lastJobCheck = 0
local JOB_CACHE_INTERVAL = 5000
local lastEntityEval = 0
local ENTITY_EVAL_INTERVAL = 500

-----------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------

CreateThread(function()
    while not exports['sb_core'] do Wait(100) end
    SB = exports['sb_core']:GetCoreObject()
    -- Check if player is already logged in (resource started mid-session)
    if exports['sb_core']:IsLoggedIn() then
        isLoggedIn = true
    end
end)

RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    isLoggedIn = true
end)

RegisterNetEvent('SB:Client:OnPlayerUnload', function()
    isLoggedIn = false
    FullDeactivate()
end)

-----------------------------------------------------------
-- RAYCAST
-----------------------------------------------------------

local function DoRaycast()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    local radX = math.rad(camRot.x)
    local radZ = math.rad(camRot.z)
    local dirX = -math.sin(radZ) * math.abs(math.cos(radX))
    local dirY = math.cos(radZ) * math.abs(math.cos(radX))
    local dirZ = math.sin(radX)

    local dest = vector3(
        camCoords.x + dirX * Config.RaycastDistance,
        camCoords.y + dirY * Config.RaycastDistance,
        camCoords.z + dirZ * Config.RaycastDistance
    )

    local ped = PlayerPedId()

    -- Use StartShapeTestRay instead of StartShapeTestLosProbe
    -- LosProbe stops at glass/metal barriers, Ray passes through them
    local ray = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        dest.x, dest.y, dest.z,
        Config.RaycastFlags,
        ped,
        0
    )

    local _, hit, hitCoords, _, entityHit = GetShapeTestResult(ray)

    return hit == 1, hitCoords, entityHit, vector3(dirX, dirY, dirZ), camCoords
end

-----------------------------------------------------------
-- FIND REGISTERED TARGET IN LOOK DIRECTION
-----------------------------------------------------------

local function FindTargetInLookDirection(playerCoords, camCoords, lookDir, maxDist)
    local bestEntity = nil
    local bestScore = 999999

    -- Helper to check an entity
    local function checkEntity(entity)
        if not DoesEntityExist(entity) then return end

        local entCoords = GetEntityCoords(entity)
        local dist = #(playerCoords - entCoords)

        -- Only check entities within max distance
        if dist > maxDist then return end

        -- Calculate direction from camera to entity (aim at chest height)
        local targetPoint = vector3(entCoords.x, entCoords.y, entCoords.z + 0.5)
        local toEntity = targetPoint - camCoords
        local toEntityLen = #toEntity

        if toEntityLen < 0.1 then return end

        -- Normalize
        local toEntityNorm = toEntity / toEntityLen

        -- Dot product to check if entity is in front of camera
        local dot = lookDir.x * toEntityNorm.x + lookDir.y * toEntityNorm.y + lookDir.z * toEntityNorm.z

        -- Entity must be directly in front (dot > 0.95 means within ~18 degree cone)
        if dot > 0.95 then
            -- Score based on how centered + how close
            local score = (1 - dot) * 100 + dist * 0.1
            if score < bestScore then
                bestScore = score
                bestEntity = entity
            end
        end
    end

    -- Check all registered entity targets
    for entity, _ in pairs(TargetRegistry.entities) do
        checkEntity(entity)
    end

    -- Check for model-based targets near the player
    for modelHash, _ in pairs(TargetRegistry.models) do
        local obj = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, maxDist, modelHash, false, false, false)
        if obj ~= 0 then
            checkEntity(obj)
        end
    end

    return bestEntity
end

-----------------------------------------------------------
-- ENTITY HIGHLIGHT (marker-based, safe for all builds)
-----------------------------------------------------------

local highlightedEntity = 0
local cachedHighlightHeight = 0

local function SetEntityHighlight(entity, enabled)
    if enabled then
        if entity ~= highlightedEntity then
            highlightedEntity = entity
            -- Cache the model height once
            local model = GetEntityModel(entity)
            if model then
                local _, max = GetModelDimensions(model)
                cachedHighlightHeight = max.z + 0.3
            else
                cachedHighlightHeight = 1.3
            end
        end
    else
        if highlightedEntity == entity then
            highlightedEntity = 0
        end
    end
end

-- Draw highlight marker above targeted entity
CreateThread(function()
    while true do
        if highlightedEntity ~= 0 and DoesEntityExist(highlightedEntity) then
            local coords = GetEntityCoords(highlightedEntity)
            DrawMarker(2, coords.x, coords.y, coords.z + cachedHighlightHeight,
                0.0, 0.0, 0.0,
                180.0, 0.0, 0.0,
                0.15, 0.15, 0.15,
                249, 115, 22, 200,
                true, false, 2, true, nil, nil, false)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-----------------------------------------------------------
-- NUI COMMUNICATION
-----------------------------------------------------------

local function ShowCrosshair(hasTarget)
    if lastCrosshairState == hasTarget then return end
    lastCrosshairState = hasTarget
    SendNUIMessage({
        action = 'showCrosshair',
        hasTarget = hasTarget
    })
end

local function HideCrosshair()
    if lastCrosshairState == nil then return end
    lastCrosshairState = nil
    SendNUIMessage({
        action = 'hideCrosshair'
    })
end

local function ShowMenu(options)
    local menuData = {}
    for i, opt in ipairs(options) do
        -- Support function labels/icons (call them to get the value)
        local label = type(opt.label) == 'function' and opt.label() or opt.label
        local icon = type(opt.icon) == 'function' and opt.icon() or (opt.icon or 'fa-circle')

        menuData[#menuData + 1] = {
            index = i,
            label = label,
            icon = icon
        }
    end

    SendNUIMessage({
        action = 'showMenu',
        options = menuData
    })
end

local function HideMenu()
    SendNUIMessage({
        action = 'hideMenu'
    })
end

-----------------------------------------------------------
-- MENU OPEN / CLOSE
-----------------------------------------------------------

local function OpenMenu()
    if #currentOptions == 0 then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    ShowMenu(currentOptions)
end

local function CloseMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    HideMenu()
end

-----------------------------------------------------------
-- OPTION EXECUTION
-----------------------------------------------------------

RegisterNUICallback('selectOption', function(data, cb)
    cb('ok')
    local index = tonumber(data.index)
    if index and currentOptions[index] then
        local opt = currentOptions[index]
        local entity = currentEntity

        CloseMenu()

        if opt.action then
            opt.action(entity)
        elseif opt.event then
            TriggerEvent(opt.event, entity)
        elseif opt.serverEvent then
            TriggerServerEvent(opt.serverEvent, entity)
        end
    end
end)

RegisterNUICallback('closeTarget', function(_, cb)
    cb('ok')
    CloseMenu()
end)

-----------------------------------------------------------
-- ACTIVATION / DEACTIVATION
-----------------------------------------------------------

local function Activate()
    if isActive then return end
    if not isLoggedIn then return end
    isActive = true
    ShowCrosshair(false)

    -- Separate thread to disable controls every frame while active
    CreateThread(function()
        while isActive do
            DisableControlAction(0, 24, true)   -- Attack (left click)
            DisableControlAction(0, 25, true)   -- Aim (right click)
            DisableControlAction(0, 47, true)   -- Weapon (disable weapon)
            DisableControlAction(0, 58, true)   -- Weapon (disable weapon)
            DisableControlAction(0, 140, true)  -- MeleeAttackLight
            DisableControlAction(0, 141, true)  -- MeleeAttackHeavy
            DisableControlAction(0, 142, true)  -- MeleeAttackAlternate
            DisableControlAction(0, 106, true)  -- VehicleMouseControlOverride

            -- Capture left-click reliably every frame
            if not menuOpen and IsDisabledControlJustPressed(0, 24) then
                leftClickPending = true
            end

            Wait(0)
        end
    end)
end

function FullDeactivate()
    if not isActive and not menuOpen then return end
    isActive = false
    CloseMenu()
    HideCrosshair()
    SetEntityHighlight(currentEntity, false)
    currentEntity = 0
    currentOptions = {}
    cachedEntityOpts = {}
    zoneOptions = {}
    leftClickPending = false
    lastCrosshairState = nil
end

-----------------------------------------------------------
-- GET PLAYER JOB
-----------------------------------------------------------

local function GetPlayerJob()
    local now = GetGameTimer()
    if now - lastJobCheck < JOB_CACHE_INTERVAL then
        return cachedPlayerJob
    end
    lastJobCheck = now
    if SB and SB.Functions and SB.Functions.GetPlayerData then
        local data = SB.Functions.GetPlayerData()
        if data and data.job then
            cachedPlayerJob = data.job.name or 'unemployed'
        end
    end
    return cachedPlayerJob
end

-----------------------------------------------------------
-- MAIN LOOP
-----------------------------------------------------------

CreateThread(function()
    while true do
        if isLoggedIn and IsControlPressed(0, Config.ActivateKey) then
            if not isActive then
                Activate()
            end

            if not menuOpen then
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local playerJob = GetPlayerJob()
                local now = GetGameTimer()

                -- Raycast
                local hit, hitCoords, entityHit, lookDir, camCoords = DoRaycast()
                local newOptions = {}

                -- Zone check (throttled)
                if now - lastZoneCheck > Config.ZoneCheckInterval then
                    lastZoneCheck = now
                    if ZoneRegistry.zoneCount > 0 then
                        zoneOptions = ZoneRegistry.GetOptionsAtPoint(playerCoords, playerJob)
                    else
                        zoneOptions = {}
                    end
                end

                -- Check if we hit a registered entity directly
                local targetEntity = nil

                if hit and entityHit ~= 0 and DoesEntityExist(entityHit) and GetEntityType(entityHit) ~= 0 then
                    -- Direct hit - check if it's registered (entity, model, global, or bone)
                    if TargetRegistry.entities[entityHit] then
                        targetEntity = entityHit
                    elseif TargetRegistry.models[GetEntityModel(entityHit)] then
                        targetEntity = entityHit
                    else
                        -- Check if global targets or bone targets apply to this entity type
                        local eType = GetEntityType(entityHit)
                        local hasGlobal = false
                        if eType == 1 then
                            hasGlobal = (IsPedAPlayer(entityHit) and #TargetRegistry.globalPlayer > 0)
                                or (not IsPedAPlayer(entityHit) and #TargetRegistry.globalPed > 0)
                        elseif eType == 2 then
                            hasGlobal = #TargetRegistry.globalVehicle > 0
                            -- Also check if any bone targets are registered
                            if not hasGlobal then
                                for _ in pairs(TargetRegistry.bones) do
                                    hasGlobal = true
                                    break
                                end
                            end
                        elseif eType == 3 then
                            hasGlobal = #TargetRegistry.globalObject > 0
                        end

                        if hasGlobal then
                            targetEntity = entityHit
                        else
                            -- Hit something not registered — look for registered targets in the look direction
                            targetEntity = FindTargetInLookDirection(playerCoords, camCoords, lookDir, Config.RaycastDistance)
                        end
                    end
                else
                    -- No entity hit - still check for registered targets in look direction
                    targetEntity = FindTargetInLookDirection(playerCoords, camCoords, lookDir, Config.RaycastDistance)
                end

                if targetEntity then
                    if targetEntity ~= currentEntity then
                        -- New entity - recalculate options
                        SetEntityHighlight(currentEntity, false)
                        currentEntity = targetEntity
                        cachedEntityOpts = TargetRegistry.GetOptionsForEntity(targetEntity, playerCoords, playerJob)
                        lastEntityEval = now
                    elseif now - lastEntityEval > ENTITY_EVAL_INTERVAL then
                        -- Same entity - re-evaluate periodically for distance changes
                        cachedEntityOpts = TargetRegistry.GetOptionsForEntity(targetEntity, playerCoords, playerJob)
                        lastEntityEval = now
                    end
                    -- Merge cached entity options + zone options
                    newOptions = {}
                    for _, opt in ipairs(cachedEntityOpts) do
                        newOptions[#newOptions + 1] = opt
                    end
                    for _, opt in ipairs(zoneOptions) do
                        newOptions[#newOptions + 1] = opt
                    end
                else
                    -- No entity hit by raycast - check for wall-mounted props nearby
                    local fallbackEntity = 0
                    if hit and #(playerCoords - hitCoords) < Config.DefaultDistance + 1.0 then
                        for modelHash, _ in pairs(TargetRegistry.models) do
                            local obj = GetClosestObjectOfType(
                                playerCoords.x, playerCoords.y, playerCoords.z,
                                3.0, modelHash, false, false, false
                            )
                            if obj ~= 0 and DoesEntityExist(obj) then
                                fallbackEntity = obj
                                break
                            end
                        end
                    end

                    if fallbackEntity ~= 0 then
                        -- Found a registered model object nearby
                        if fallbackEntity ~= currentEntity then
                            SetEntityHighlight(currentEntity, false)
                            currentEntity = fallbackEntity
                            cachedEntityOpts = TargetRegistry.GetOptionsForEntity(fallbackEntity, playerCoords, playerJob)
                            lastEntityEval = now
                        elseif now - lastEntityEval > ENTITY_EVAL_INTERVAL then
                            cachedEntityOpts = TargetRegistry.GetOptionsForEntity(fallbackEntity, playerCoords, playerJob)
                            lastEntityEval = now
                        end
                        newOptions = {}
                        for _, opt in ipairs(cachedEntityOpts) do
                            newOptions[#newOptions + 1] = opt
                        end
                        for _, opt in ipairs(zoneOptions) do
                            newOptions[#newOptions + 1] = opt
                        end
                    else
                        if currentEntity ~= 0 then
                            SetEntityHighlight(currentEntity, false)
                            currentEntity = 0
                            cachedEntityOpts = {}
                        end
                        newOptions = zoneOptions
                    end
                end

                -- Update highlight and crosshair
                local hasTarget = #newOptions > 0
                if hasTarget and currentEntity ~= 0 then
                    SetEntityHighlight(currentEntity, true)
                end
                ShowCrosshair(hasTarget)
                currentOptions = newOptions

                -- Left-click to open menu
                if hasTarget and leftClickPending then
                    leftClickPending = false
                    OpenMenu()
                elseif not hasTarget then
                    leftClickPending = false
                end

                -- Stale entity cleanup (throttled)
                if now - lastCleanup > Config.CleanupInterval then
                    lastCleanup = now
                    for entity, _ in pairs(TargetRegistry.entities) do
                        if not DoesEntityExist(entity) then
                            TargetRegistry.entities[entity] = nil
                        end
                    end
                end

                -- Debug zone drawing
                if Config.Debug and ZoneRegistry.zoneCount > 0 then
                    ZoneRegistry.DrawDebug()
                end
            end

            Wait(0)
        else
            -- Don't deactivate if menu is open (NUI has stolen input)
            if isActive and not menuOpen then
                FullDeactivate()
            end
            Wait(menuOpen and 0 or 500)
        end
    end
end)

-----------------------------------------------------------
-- TEST TARGETS (Remove in production)
-----------------------------------------------------------

local testPed = nil

RegisterCommand('testdummy', function()
    -- Spawn a ped 2m in front of the player
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local rad = math.rad(heading)
    local spawnPos = vector3(
        coords.x - math.sin(rad) * 2.0,
        coords.y + math.cos(rad) * 2.0,
        coords.z
    )

    -- Delete old test ped if exists
    if testPed and DoesEntityExist(testPed) then
        DeleteEntity(testPed)
    end

    -- Load model
    local model = joaat('a_m_m_business_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    -- Create ped
    testPed = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z - 1.0, heading + 180.0, false, true)
    SetEntityInvincible(testPed, true)
    FreezeEntityPosition(testPed, true)
    SetBlockingOfNonTemporaryEvents(testPed, true)
    SetModelAsNoLongerNeeded(model)

    -- Register target directly on this entity
    TargetRegistry.AddTargetEntity({testPed}, {
        { name = 'test_talk', label = 'Talk to NPC', icon = 'fa-comment', distance = 3.0,
          action = function(entity)
              print('[sb_target] Talk action fired on entity: ' .. tostring(entity))
              TriggerEvent('SB:Client:Notify', 'Talking to test NPC!', 'success', 3000)
          end
        },
        { name = 'test_search', label = 'Search', icon = 'fa-magnifying-glass', distance = 3.0,
          action = function(entity)
              print('[sb_target] Search action fired on entity: ' .. tostring(entity))
              TriggerEvent('SB:Client:Notify', 'Searching NPC...', 'info', 3000)
          end
        },
        { name = 'test_rob', label = 'Rob', icon = 'fa-hand-holding-dollar', distance = 3.0,
          action = function(entity)
              print('[sb_target] Rob action fired on entity: ' .. tostring(entity))
              TriggerEvent('SB:Client:Notify', 'Robbing NPC!', 'warning', 3000)
          end
        }
    })

    print('[sb_target] Test dummy spawned! Entity handle: ' .. tostring(testPed))
    print('[sb_target] Registered targets: ' .. tostring(TargetRegistry.entities[testPed] and #TargetRegistry.entities[testPed] or 0))
    TriggerEvent('SB:Client:Notify', 'Test dummy spawned! Hold ALT and aim at it.', 'success', 5000)
end, false)

-- Debug: list all registered entity targets
RegisterCommand('targetlist', function()
    print('[sb_target] === Registered Entity Targets ===')
    local count = 0
    for entity, opts in pairs(TargetRegistry.entities) do
        count = count + 1
        local exists = DoesEntityExist(entity)
        local coords = exists and GetEntityCoords(entity) or vector3(0,0,0)
        print(('[sb_target] Entity %d: exists=%s, options=%d, coords=%.1f,%.1f,%.1f'):format(
            entity, tostring(exists), #opts, coords.x, coords.y, coords.z
        ))
    end
    print('[sb_target] Total: ' .. count .. ' entities registered')

    print('[sb_target] === Registered Model Targets ===')
    local modelCount = 0
    for hash, opts in pairs(TargetRegistry.models) do
        modelCount = modelCount + 1
        print(('[sb_target] Model 0x%08X: options=%d'):format(hash, #opts))
    end
    print('[sb_target] Total: ' .. modelCount .. ' models registered')
end, false)

-- Debug: print raycast info
RegisterCommand('targetdebug', function()
    CreateThread(function()
        for i = 1, 50 do
            local hit, hitCoords, entityHit = DoRaycast()
            if hit then
                local etype = GetEntityType(entityHit)
                print(('[sb_target] Hit: entity=%d, type=%d, coords=%.1f,%.1f,%.1f'):format(
                    entityHit, etype, hitCoords.x, hitCoords.y, hitCoords.z
                ))
                local playerCoords = GetEntityCoords(PlayerPedId())
                local dist = #(playerCoords - GetEntityCoords(entityHit))
                print(('[sb_target] Distance: %.2f, HasOptions: %s'):format(
                    dist,
                    tostring(TargetRegistry.entities[entityHit] ~= nil)
                ))
            else
                print('[sb_target] No hit')
            end
            Wait(500)
        end
        print('[sb_target] Debug ended')
    end)
end, false)

RegisterCommand('removedummy', function()
    if testPed and DoesEntityExist(testPed) then
        TargetRegistry.RemoveTargetEntity({testPed})
        DeleteEntity(testPed)
        testPed = nil
        print('[sb_target] Test dummy removed')
    end
end, false)

-----------------------------------------------------------
-- CLEANUP ON RESOURCE STOP
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        FullDeactivate()
    end
end)
