-- ============================================================================
-- Mining — Server Job Logic
-- Registers handlers into the PublicJobServerHandlers framework
--
-- Key responsibilities:
--   1. Pick mining site based on player level, avoid repeats
--   2. Generate node resource list (random from site's resource pool)
--   3. Track mined nodes, give ore to player inventory
--   4. Complete site -> payment through standard framework
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- PER-PLAYER MINING STATE
-- ============================================================================

-- MiningState[source] = {
--     siteNodes = { 'raw_iron', 'raw_copper', ... }, -- resource per node index
--     nodesMined = {},           -- set of node indices already mined
--     nodesReady = 0,            -- total nodes spawned on client
-- }
local MiningState = {}

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Get eligible sites for a player's level
local function GetEligibleSites(jobCfg, level)
    local eligible = {}
    for i, site in ipairs(jobCfg.sites) do
        if level >= site.requiredLevel then
            table.insert(eligible, i)
        end
    end
    return eligible
end

--- Generate random resource list for a site
local function GenerateNodeResources(site, jobCfg, count)
    local resources = site.resources
    if not resources or #resources == 0 then return {} end

    local result = {}
    for i = 1, count do
        result[i] = resources[math.random(#resources)]
    end
    return result
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobServerHandlers['mining'] = {

    -- ========================================================================
    -- REQUEST BATCH — pick site, generate nodes, send to client
    -- ========================================================================
    onRequestBatch = function(source, activeData, jobCfg)
        local sites = jobCfg.sites
        if not sites or #sites == 0 then
            print('[sb_jobs] Mining: No sites configured')
            return
        end

        local level = activeData.level or 1

        -- Get eligible sites for this level
        local eligible = GetEligibleSites(jobCfg, level)
        if #eligible == 0 then
            eligible = { 1 } -- fallback to first site
        end

        -- Avoid repeating last site
        local filtered = {}
        for _, idx in ipairs(eligible) do
            if idx ~= activeData.lastSiteIndex then
                table.insert(filtered, idx)
            end
        end
        if #filtered == 0 then
            filtered = eligible
        end

        local siteIndex = filtered[math.random(#filtered)]
        activeData.lastSiteIndex = siteIndex

        local site = sites[siteIndex]
        local nodesPerBatch = jobCfg.nodesPerBatch or 15

        -- Generate resource list for nodes
        local nodeResources = GenerateNodeResources(site, jobCfg, nodesPerBatch)

        -- Store state
        MiningState[source] = {
            siteNodes = nodeResources,
            nodesMined = {},
            nodesReady = 0,
        }

        -- Framework expects currentBatch
        activeData.currentBatch = { site }
        activeData.currentSiteIndex = siteIndex

        -- Send to client
        TriggerClientEvent('sb_jobs:client:batchReady', source, {
            siteIndex = siteIndex,
            nodeResources = nodeResources,
        })
    end,

    -- ========================================================================
    -- VALIDATE DELIVERY — site completion validated per-node
    -- ========================================================================
    onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg)
        return true
    end,

    -- ========================================================================
    -- CALCULATE TIP
    -- ========================================================================
    onCalculateTip = function(source, activeData, jobCfg)
        return math.random(jobCfg.tipMin, jobCfg.tipMax)
    end,
}

-- ============================================================================
-- GIVE PICKAXE ON JOB START
-- ============================================================================
-- FiveM calls ALL handlers for the same event. The framework (publicjobs.lua)
-- handles keys/vehicle/tracking. We just add the pickaxe for mining jobs here.

RegisterNetEvent('sb_jobs:server:startPublicJob', function(jobId)
    local source = source
    if jobId ~= 'mining' then return end
    -- Small delay to let the framework handler create ActivePublicJobs[source] first
    SetTimeout(500, function()
        if ActivePublicJobs[source] and ActivePublicJobs[source].jobId == 'mining' then
            exports['sb_inventory']:AddItem(source, 'mining_pickaxe', 1, {
                label = 'Mining Pickaxe (Job)'
            })
        end
    end)
end)

-- ============================================================================
-- MINING SITE READY — Client reports how many nodes spawned
-- ============================================================================

RegisterNetEvent('sb_jobs:server:miningSiteReady', function(nodeCount)
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'mining' then return end

    if type(nodeCount) ~= 'number' then return end

    local state = MiningState[source]
    if not state then return end

    state.nodesReady = nodeCount

    -- If no nodes could spawn, request a new site
    if nodeCount == 0 then
        local jobCfg = Config.PublicJobs['mining']
        if jobCfg then
            Wait(2000)
            if ActivePublicJobs[source] and ActivePublicJobs[source].jobId == 'mining' then
                PublicJobServerHandlers['mining'].onRequestBatch(source, active, jobCfg)
            end
        end
    end
end)

-- ============================================================================
-- NODE MINED — Player mined a specific node
-- ============================================================================

RegisterNetEvent('sb_jobs:server:minedNode', function(nodeIndex)
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'mining' then return end

    if type(nodeIndex) ~= 'number' then return end

    local state = MiningState[source]
    if not state then return end

    -- Validate node index
    if nodeIndex < 1 or nodeIndex > #state.siteNodes then return end

    -- Prevent double-mining
    if state.nodesMined[nodeIndex] then return end
    state.nodesMined[nodeIndex] = true

    local resource = state.siteNodes[nodeIndex]
    if not resource then return end

    local jobCfg = Config.PublicJobs['mining']
    if not jobCfg then return end

    local resTier = jobCfg.resourceTiers[resource]
    if not resTier then return end

    -- Calculate yield
    local minYield = resTier.yield[1] or 1
    local maxYield = resTier.yield[2] or 1
    local yield = math.random(minYield, maxYield)

    -- Give ore to player inventory
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return end

    exports['sb_inventory']:AddItem(source, resource, yield)

    local resLabel = resTier.label or resource
    TriggerClientEvent('sb_jobs:client:notify', source, '+' .. yield .. 'x ' .. resLabel, 'success')

    -- Check if all nodes mined
    local totalMined = 0
    for _ in pairs(state.nodesMined) do
        totalMined = totalMined + 1
    end

    if totalMined >= state.nodesReady then
        -- Site complete -> trigger payment via standard framework
        TriggerEvent('sb_jobs:server:miningComplete_internal', source)
    end
end)

-- ============================================================================
-- SITE COMPLETE — Trigger payment through standard delivery flow
-- ============================================================================

AddEventHandler('sb_jobs:server:miningComplete_internal', function(targetSource)
    local Player = SB.Functions.GetPlayer(targetSource)
    if not Player then return end

    local active = ActivePublicJobs[targetSource]
    if not active or active.jobId ~= 'mining' then return end

    local jobCfg = Config.PublicJobs['mining']
    if not jobCfg then return end

    -- Validate
    local handler = PublicJobServerHandlers['mining']
    if handler and handler.onValidateDelivery then
        local valid = handler.onValidateDelivery(targetSource, 1, active, jobCfg)
        if not valid then return end
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get current progress
    local progress = MySQL.query.await(
        'SELECT * FROM job_public_progress WHERE citizenid = ? AND job_id = ?',
        { citizenid, 'mining' }
    )
    if not progress or not progress[1] then
        MySQL.insert.await(
            'INSERT INTO job_public_progress (citizenid, job_id, xp, level, total_completions) VALUES (?, ?, 0, 1, 0)',
            { citizenid, 'mining' }
        )
        progress = { { xp = 0, level = 1, total_completions = 0 } }
    end

    local currentXP = progress[1].xp
    local currentLevel = progress[1].level
    local completions = progress[1].total_completions

    -- Calculate pay
    local levelData = jobCfg.levels[currentLevel] or jobCfg.levels[1]
    local basePay = levelData.pay

    -- Tip
    local tip
    if handler and handler.onCalculateTip then
        tip = handler.onCalculateTip(targetSource, active, jobCfg)
    else
        tip = math.random(jobCfg.tipMin, jobCfg.tipMax)
    end

    local totalPay = basePay + tip

    -- Add XP
    local xpGain = math.max(0, tonumber(jobCfg.xpPerDelivery) or 0)
    local newXP = math.min((currentXP or 0) + xpGain, 999999)

    -- Calculate level
    local newLevel = 1
    for _, lv in ipairs(jobCfg.levels) do
        if newXP >= lv.xpRequired then
            newLevel = lv.level
        else
            break
        end
    end
    local maxLevel = #jobCfg.levels
    if newLevel > maxLevel then newLevel = maxLevel end

    local newCompletions = (completions or 0) + 1

    -- Update DB
    MySQL.query('UPDATE job_public_progress SET xp = ?, level = ?, total_completions = ? WHERE citizenid = ? AND job_id = ?',
        { newXP, newLevel, newCompletions, citizenid, 'mining' })

    -- Pay player
    Player.Functions.AddMoney('cash', totalPay, 'mining')

    -- Build response
    local responseData = {
        index = 1,
        pay = basePay,
        tip = tip,
        xp = xpGain,
        totalXp = newXP,
        level = currentLevel,
        newLevel = newLevel,
    }

    if newLevel > currentLevel then
        local newLevelData = jobCfg.levels[newLevel] or jobCfg.levels[1]
        responseData.newVehicle = newLevelData.vehicle
        responseData.newPay = newLevelData.pay
        active.level = newLevel

        if newLevelData.vehicle ~= active.currentVehicle then
            active.pendingSwapVehicle = newLevelData.vehicle
            responseData.pendingSwap = true
            responseData.pendingSwapVehicle = newLevelData.vehicle
            if jobCfg.requiresLicense and jobCfg.requiresLicense[newLevelData.vehicle] then
                responseData.swapRequiresLicense = jobCfg.requiresLicense[newLevelData.vehicle]
            end
        end
    end

    TriggerClientEvent('sb_jobs:client:deliveryComplete', targetSource, responseData)

    -- Clean up mining state
    MiningState[targetSource] = nil

    print('[sb_jobs] Mining site complete for player ' .. targetSource .. ' — $' .. totalPay .. ' (+' .. xpGain .. ' XP)')
end)

-- ============================================================================
-- CLEANUP ON QUIT/DROP
-- ============================================================================

local function RemovePickaxe(source)
    local ok, items = pcall(exports['sb_inventory'].GetItemsByName, exports['sb_inventory'], source, 'mining_pickaxe')
    if ok and items then
        for _, item in ipairs(items) do
            exports['sb_inventory']:RemoveItem(source, 'mining_pickaxe', 1, item.slot)
        end
    end
end

local function HandleMiningCleanup(source)
    MiningState[source] = nil
    RemovePickaxe(source)
end

AddEventHandler('playerDropped', function()
    HandleMiningCleanup(source)
end)

RegisterNetEvent('sb_jobs:server:quitPublicJob', function()
    HandleMiningCleanup(source)
end)

RegisterNetEvent('sb_jobs:server:vehicleConfiscated', function()
    HandleMiningCleanup(source)
end)
