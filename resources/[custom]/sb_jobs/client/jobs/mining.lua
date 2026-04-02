-- ============================================================================
-- Mining — Client Job Logic
-- Registers handlers into the PublicJobHandlers framework
--
-- Flow:
-- 1. Player starts job at Job Center NPC -> Bison spawns + pickaxe given
-- 2. Server assigns a mining site (based on player level)
-- 3. Client spawns node props within the site radius
-- 4. Player ALT-targets node zone -> minigame (timing) -> ore to inventory
-- 5. When all nodes mined -> zone complete -> payment + ore in inventory
-- 6. Ore can be sold at company receiving docks (sb_companies)
-- ============================================================================

-- ============================================================================
-- STATE
-- ============================================================================

local currentSite = nil            -- { id, label, center, radius, ... }
local spawnedNodes = {}            -- { { entity, targetId, mined, resource, position }, ... }
local minedCount = 0               -- nodes mined this site
local siteTarget = 0               -- total nodes this site
local farePhase = 'idle'           -- 'idle' | 'mining' | 'returning'
local hasDoneSite = false          -- at least one site completed
local waitingForBatch = false
local offRouteTimer = 0
local offRouteWarned = false
local returnBlip = nil
local siteCircleBlip = nil         -- circle area blip on minimap
local isMining = false             -- currently in mining animation/minigame
local pickaxeProp = nil            -- handle to attached pickaxe prop

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ClearReturnBlip()
    if returnBlip and DoesBlipExist(returnBlip) then
        RemoveBlip(returnBlip)
    end
    returnBlip = nil
end

local function ClearSiteCircleBlip()
    if siteCircleBlip and DoesBlipExist(siteCircleBlip) then
        RemoveBlip(siteCircleBlip)
    end
    siteCircleBlip = nil
end

local function DeletePickaxeProp()
    if pickaxeProp and DoesEntityExist(pickaxeProp) then
        DetachEntity(pickaxeProp, true, true)
        DeleteObject(pickaxeProp)
    end
    pickaxeProp = nil
end

local function AttachPickaxeToPlayer()
    DeletePickaxeProp()
    local ped = PlayerPedId()
    local hash = GetHashKey('prop_tool_pickaxe')
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return end
    end

    local boneIndex = GetPedBoneIndex(ped, 57005) -- right hand
    pickaxeProp = CreateObject(hash, 0, 0, 0, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if pickaxeProp and pickaxeProp > 0 then
        AttachEntityToEntity(pickaxeProp, ped, boneIndex,
            0.1, 0.0, -0.02,
            -100.0, 0.0, 0.0,
            true, true, false, true, 1, true)
    end
end

--- Get distance to nearest valid job point (for off-route detection)
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

    if currentSite and currentSite.center then
        local d = #(playerCoords - currentSite.center)
        if d < nearest then nearest = d end
    end

    if JobVehicle and DoesEntityExist(JobVehicle) then
        local vehCoords = GetEntityCoords(JobVehicle)
        local d = #(playerCoords - vehCoords)
        if d < nearest then nearest = d end
    end

    return nearest
end

--- Remove all spawned node entities and their targets
local function CleanupSpawnedNodes()
    for _, nodeData in ipairs(spawnedNodes) do
        if nodeData.targetId then
            exports['sb_target']:RemoveTarget(nodeData.targetId)
        end
        if nodeData.entity and DoesEntityExist(nodeData.entity) then
            DeleteObject(nodeData.entity)
        end
    end
    spawnedNodes = {}
end

--- Play animation from dict
local function PlayAnimDict(dict, anim, duration, flag)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return end
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration or -1, flag or 1, 0, false, false, false)
end

--- Create a circle area blip on the minimap for the site
local function CreateSiteCircleBlip(center, radius, label)
    local blip = AddBlipForRadius(center.x, center.y, center.z, radius)
    SetBlipHighDetail(blip, true)
    SetBlipColour(blip, 46) -- orange
    SetBlipAlpha(blip, 80)
    SetBlipRotation(blip, 0)

    local pointBlip = AddBlipForCoord(center.x, center.y, center.z)
    SetBlipSprite(pointBlip, 618) -- pickaxe/mine icon
    SetBlipDisplay(pointBlip, 4)
    SetBlipScale(pointBlip, 0.9)
    SetBlipColour(pointBlip, 46) -- orange
    SetBlipAsShortRange(pointBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Mining Site')
    EndTextCommandSetBlipName(pointBlip)

    return blip, pointBlip
end

--- Spawn a mining node prop at a position
local function SpawnNodeProp(coords, propName, jobCfg)
    local hash = GetHashKey(propName)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then return nil end
    end

    -- Spawn slightly above ground so PlaceObjectOnGroundProperly can settle it down
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local node = CreateObject(hash, coords.x, coords.y, coords.z + 1.0, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if not node or node <= 0 then return nil end

    PlaceObjectOnGroundProperly(node)
    Wait(50) -- let physics settle
    PlaceObjectOnGroundProperly(node) -- second pass for reliability
    FreezeEntityPosition(node, true)

    -- Orange outline glow
    local color = jobCfg.nodeOutlineColor or { r = 255, g = 165, b = 0, a = 200 }
    SetEntityDrawOutline(node, true)
    SetEntityDrawOutlineColor(color.r, color.g, color.b, color.a)
    SetEntityDrawOutlineShader(0)

    return node
end

--- Request collision + scene loading at a point and wait for it
local function LoadSceneAtCoord(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStart(x, y, z, 0.0, 0.0, 0.0, 50.0, 0)
    local timeout = 0
    while not IsNewLoadSceneLoaded() do
        Wait(50)
        timeout = timeout + 50
        if timeout > 10000 then break end
    end
    NewLoadSceneStop()
end

--- Probe for ground Z with multiple attempts from different heights
local function GetGroundZ(x, y, startZ)
    local probeHeights = { startZ + 200.0, startZ + 100.0, startZ + 50.0, startZ + 500.0, 1000.0 }
    for _, probeZ in ipairs(probeHeights) do
        RequestCollisionAtCoord(x, y, probeZ)
        Wait(0)
        local found, groundZ = GetGroundZFor_3dCoord(x, y, probeZ, false)
        if found and groundZ > 0.0 then
            return groundZ
        end
    end
    return nil
end

--- Generate random points within a radius on ground level
local function GenerateNodePositions(center, radius, count)
    -- Pre-load the terrain at the site center before probing
    LoadSceneAtCoord(center.x, center.y, center.z)
    Wait(500) -- extra settle time for terrain streaming

    local positions = {}
    local attempts = 0
    local maxAttempts = count * 5

    while #positions < count and attempts < maxAttempts do
        attempts = attempts + 1

        local angle = math.random() * 2.0 * math.pi
        local dist = math.sqrt(math.random()) * radius
        local x = center.x + math.cos(angle) * dist
        local y = center.y + math.sin(angle) * dist

        local groundZ = GetGroundZ(x, y, center.z)
        if not groundZ then
            goto continue
        end

        -- Check minimum spacing (10m between nodes)
        local tooClose = false
        for _, pos in ipairs(positions) do
            if #(vector3(x, y, groundZ) - pos) < 10.0 then
                tooClose = true
                break
            end
        end

        if not tooClose then
            table.insert(positions, vector3(x, y, groundZ))
        end

        ::continue::
    end

    return positions
end

--- Check if player has a pickaxe in inventory
local function HasPickaxe()
    local SB = exports['sb_core']:GetCoreObject()
    local Player = SB.Functions.GetPlayerData()
    if not Player or not Player.items then return false end
    for _, item in pairs(Player.items) do
        if item and item.name == 'mining_pickaxe' then return true end
    end
    return false
end

--- Mine a specific node by index (called from target action)
local function MineNode(nodeIndex, jobCfg)
    local nodeData = spawnedNodes[nodeIndex]
    if not nodeData or nodeData.mined then return end
    if isMining or farePhase ~= 'mining' then return end

    -- Require pickaxe
    if not HasPickaxe() then
        exports['sb_notify']:Notify('You need a mining pickaxe to mine!', 'error', 3000)
        return
    end

    isMining = true

    local resource = nodeData.resource
    local resTier = jobCfg.resourceTiers[resource]
    local resLabel = resTier and resTier.label or resource

    -- Determine minigame difficulty from tier
    local tier = 1
    if resTier then tier = resTier.tier or 1 end
    local mgDifficulty = jobCfg.minigame.difficulties[tier] or jobCfg.minigame.difficulties[1]

    -- Run minigame
    local mgResult = exports['sb_minigame']:StartMinigame({
        type = 'timing',
        speed = mgDifficulty.speed,
        zones = mgDifficulty.zones,
        targetSize = mgDifficulty.targetSize,
    })

    if not mgResult or mgResult == false then
        isMining = false
        exports['sb_notify']:Notify('Mining failed! Try again.', 'error', 3000)
        return
    end

    -- Attach pickaxe prop to hand for the animation
    AttachPickaxeToPlayer()

    -- Mining animation + progress bar
    local animCfg = jobCfg.miningAnim or {}
    if animCfg.dict then
        PlayAnimDict(animCfg.dict, animCfg.anim, jobCfg.miningDuration or 6000, 1)
    end

    local completed = exports['sb_progressbar']:Start({
        duration = jobCfg.miningDuration or 6000,
        label = 'Mining ' .. resLabel .. '...',
    })
    ClearPedTasks(PlayerPedId())

    -- Remove pickaxe prop after animation
    DeletePickaxeProp()

    if completed == false then
        isMining = false
        return
    end

    -- Mark as mined
    nodeData.mined = true

    -- Remove outline and delete node entity
    if nodeData.entity and DoesEntityExist(nodeData.entity) then
        SetEntityDrawOutline(nodeData.entity, false)
        DeleteObject(nodeData.entity)
    end
    nodeData.entity = nil

    -- Remove target zone
    if nodeData.targetId then
        exports['sb_target']:RemoveTarget(nodeData.targetId)
        nodeData.targetId = nil
    end

    -- Tell server we mined this node
    TriggerServerEvent('sb_jobs:server:minedNode', nodeIndex)

    minedCount = minedCount + 1
    isMining = false

    exports['sb_notify']:Notify('Mined ' .. resLabel .. '! (' .. minedCount .. '/' .. siteTarget .. ')', 'success', 3000)
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobHandlers['mining'] = {

    -- ========================================================================
    -- ON START — Spawn vehicle, set up state, request first site
    -- ========================================================================
    onStart = function(data, jobCfg)
        -- Reset state
        currentSite = nil
        CleanupSpawnedNodes()
        minedCount = 0
        siteTarget = 0
        farePhase = 'idle'
        hasDoneSite = false
        waitingForBatch = true
        offRouteTimer = 0
        offRouteWarned = false
        isMining = false
        DeletePickaxeProp()

        ClearReturnBlip()
        ClearSiteCircleBlip()

        -- Spawn vehicle
        JobVehicle = PJ_SpawnJobVehicle(data.vehicleModel, jobCfg.vehicleSpawn, jobCfg.vehicleSpawnSlots)
        if not JobVehicle then
            TriggerServerEvent('sb_jobs:server:quitPublicJob')
            return
        end

        -- Set plate
        if data.plate then
            SetVehicleNumberPlateText(JobVehicle, data.plate)
        end

        -- Return point blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        exports['sb_notify']:Notify('Mining job started! A pickaxe and your Bison are ready. Waiting for site assignment...', 'success', 5000)

        -- Request first site
        TriggerServerEvent('sb_jobs:server:requestBatch', data.jobId)
    end,

    -- ========================================================================
    -- ON BATCH READY — Site assigned, spawn nodes
    -- ========================================================================
    onBatchReady = function(data, jobCfg)
        local siteIndex = data.siteIndex
        local site = jobCfg.sites[siteIndex]
        if not site then return end

        local nodeResources = data.nodeResources

        -- Set up site state
        currentSite = {
            id = site.id,
            label = site.label,
            center = site.center,
            radius = site.radius,
        }
        minedCount = 0
        farePhase = 'mining'
        waitingForBatch = false

        -- Clear old blips and nodes
        PJ_ClearAllBlips()
        ClearReturnBlip()
        ClearSiteCircleBlip()
        CleanupSpawnedNodes()

        -- Create site circle blip
        local radiusBlip, pointBlip = CreateSiteCircleBlip(site.center, site.radius, 'Mine: ' .. site.label)
        siteCircleBlip = radiusBlip
        if pointBlip then
            table.insert(JobBlips, pointBlip)
        end

        -- Return blip
        returnBlip = PJ_CreateLocationBlip(jobCfg.returnPoint, 408, 47, 0.7, 'Return Vehicle (End Shift)')

        -- Generate node positions within the site
        local nodeCount = #nodeResources
        local positions = GenerateNodePositions(site.center, site.radius, nodeCount)

        -- Spawn nodes and register sphere zones (NOT entity targets — rocks are too big)
        for i = 1, math.min(nodeCount, #positions) do
            local resource = nodeResources[i]
            local resTier = jobCfg.resourceTiers[resource]
            local propName = site.nodeProp or 'prop_rock_4_a'

            local nodeEntity = SpawnNodeProp(positions[i], propName, jobCfg)

            if nodeEntity then
                local nodeIndex = #spawnedNodes + 1
                local nodeData = {
                    entity = nodeEntity,
                    targetId = nil,
                    mined = false,
                    resource = resource,
                    position = positions[i],
                }

                -- Use AddSphereZone at the node position (works reliably on large props)
                local resLabel = resTier and resTier.label or resource
                local capturedIndex = nodeIndex  -- capture for closure
                local targetId = exports['sb_target']:AddSphereZone(
                    'mining_node_' .. i,
                    positions[i],
                    jobCfg.interactRadius or 2.0,
                    {
                        {
                            label = 'Mine ' .. resLabel,
                            icon = 'fa-gem',
                            distance = 2.5,
                            canInteract = function()
                                if not ActivePublicJobData or ActivePublicJobData.jobId ~= 'mining' then return false end
                                if isMining then return false end
                                if farePhase ~= 'mining' then return false end
                                local nd = spawnedNodes[capturedIndex]
                                if not nd or nd.mined then return false end
                                return true
                            end,
                            action = function()
                                MineNode(capturedIndex, jobCfg)
                            end,
                        },
                    }
                )

                nodeData.targetId = targetId
                spawnedNodes[nodeIndex] = nodeData
            end
        end

        siteTarget = #spawnedNodes

        -- Report count to server
        TriggerServerEvent('sb_jobs:server:miningSiteReady', #spawnedNodes)

        -- GPS to site center
        PJ_SetGPSToCoord(site.center.x, site.center.y, site.center.z)

        exports['sb_notify']:Notify('Site: ' .. site.label .. ' — Mine ' .. #spawnedNodes .. ' nodes', 'info', 6000)
    end,

    -- ========================================================================
    -- ON TASK COMPLETE — Site finished, payment notification
    -- ========================================================================
    onTaskComplete = function(data, jobCfg)
        local payMsg = '$' .. data.pay
        if data.tip and data.tip > 0 then
            payMsg = payMsg .. ' + $' .. data.tip .. ' tip'
        end
        exports['sb_notify']:Notify('Site complete! ' .. payMsg .. ' (+' .. data.xp .. ' XP)', 'success', 4000)

        farePhase = 'idle'
        hasDoneSite = true
        currentSite = nil
        minedCount = 0
        siteTarget = 0
        isMining = false

        CleanupSpawnedNodes()
        ClearSiteCircleBlip()
        DeletePickaxeProp()

        -- Request next site or handle vehicle swap
        if PendingVehicleSwap then
            waitingForBatch = false
            exports['sb_notify']:Notify('Site complete! Return to the Job Center to swap your vehicle.', 'success', 8000)
            PJ_SetGPSToCoord(jobCfg.returnPoint.x, jobCfg.returnPoint.y, jobCfg.returnPoint.z)
        else
            waitingForBatch = true
            if ActivePublicJobData then
                TriggerServerEvent('sb_jobs:server:requestBatch', ActivePublicJobData.jobId)
            end
        end
    end,

    -- ========================================================================
    -- ON END — Clean up all state
    -- ========================================================================
    onEnd = function(jobCfg)
        CleanupSpawnedNodes()
        ClearReturnBlip()
        ClearSiteCircleBlip()
        DeletePickaxeProp()
        isMining = false

        currentSite = nil
        minedCount = 0
        siteTarget = 0
        farePhase = 'idle'
        hasDoneSite = false
        waitingForBatch = false
        offRouteTimer = 0
        offRouteWarned = false
        PendingVehicleSwap = false
        PendingSwapVehicle = nil
        PendingSwapRequiresLicense = nil

        exports['sb_notify']:Notify('Mining shift ended. Your progress has been saved.', 'info', 5000)
    end,

    -- ========================================================================
    -- ON TICK — Proximity checks, GPS updates (every 500ms)
    -- ========================================================================
    onTick = function(jobCfg)
        if not ActivePublicJobData then return end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        -- MINING PHASE — update GPS
        if farePhase == 'mining' and currentSite then
            if currentSite.center then
                PJ_SetGPSToCoord(currentSite.center.x, currentSite.center.y, currentSite.center.z)
            end
        end

        -- CHECK: At Job Center return point (end shift or vehicle swap)
        if farePhase == 'idle' and hasDoneSite and jobCfg.returnPoint then
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

        -- ANTI-ABUSE: Off-route detection
        if JobVehicle and DoesEntityExist(JobVehicle) and IsPedInVehicle(ped, JobVehicle, false) then
            local nearestDist = GetNearestValidDist(playerCoords, jobCfg)

            if nearestDist > (jobCfg.offRouteDistance or 600.0) then
                offRouteTimer = offRouteTimer + 0.5

                if offRouteTimer >= (jobCfg.offRouteWarnTime or 30.0) and not offRouteWarned then
                    offRouteWarned = true
                    exports['sb_notify']:Notify('You are going off-route! Return to your site or your vehicle will be confiscated and you will be fined $100.', 'error', 10000)
                end

                if offRouteTimer >= (jobCfg.offRouteConfiscateTime or 60.0) then
                    CleanupSpawnedNodes()
                    ClearSiteCircleBlip()
                    DeletePickaxeProp()
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
