-- ============================================================================
-- Newspaper Delivery — Server Job Logic
-- Registers handlers into the PublicJobServerHandlers framework
--
-- Key responsibilities:
--   1. Pick a delivery area based on player level (avoid repeats)
--   2. Give newspaper items to player inventory on batch start
--   3. Validate deliveries (anti-exploit distance check)
--   4. Remove 1 newspaper from inventory per throw (hit or miss)
--   5. Clean up newspapers on job end
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- USEABLE ITEM: Newspaper equip/unequip from inventory
-- ============================================================================

SB.Functions.CreateUseableItem('newspaper', function(source, item)
    local src = source
    local active = ActivePublicJobs[src]

    if not active or active.jobId ~= 'newspaper_delivery' then
        TriggerClientEvent('sb_jobs:client:notify', src, 'You need an active newspaper delivery job to use this.', 'error')
        return
    end

    local count = exports['sb_inventory']:GetItemCount(src, 'newspaper')
    if count <= 0 then
        TriggerClientEvent('sb_jobs:client:notify', src, 'You have no newspapers left.', 'error')
        return
    end

    TriggerClientEvent('sb_jobs:client:toggleNewspaper', src, count)
end)

-- ============================================================================
-- EVENT: Newspaper thrown (ammo decreased — remove 1 from inventory)
-- Called by client whenever weapon ammo decreases (hit or miss)
-- ============================================================================

RegisterNetEvent('sb_jobs:server:newspaperUsed', function()
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'newspaper_delivery' then return end

    -- Rate limit: max 1 removal per 400ms (prevents spam)
    local now = GetGameTimer()
    if active.lastThrowTime and now - active.lastThrowTime < 400 then return end
    active.lastThrowTime = now

    exports['sb_inventory']:RemoveItem(source, 'newspaper', 1)
end)

-- ============================================================================
-- EVENT: Newspaper recovered (picked up missed throw — re-add to inventory)
-- ============================================================================

RegisterNetEvent('sb_jobs:server:newspaperRecovered', function()
    local source = source
    local active = ActivePublicJobs[source]
    if not active or active.jobId ~= 'newspaper_delivery' then return end

    -- Rate limit: max 1 recovery per 1s
    local now = GetGameTimer()
    if active.lastRecoverTime and now - active.lastRecoverTime < 1000 then return end
    active.lastRecoverTime = now

    exports['sb_inventory']:AddItem(source, 'newspaper', 1, nil, nil, true)
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Pick a random area the player can access at their level
--- Avoids the same area back-to-back when possible
local function PickArea(jobCfg, playerLevel, lastAreaId)
    local eligible = {}
    for i, area in ipairs(jobCfg.areas) do
        if playerLevel >= area.minLevel then
            table.insert(eligible, { index = i, area = area })
        end
    end

    if #eligible == 0 then
        return 1, jobCfg.areas[1]
    end

    -- Try to exclude last used area for variety
    if #eligible > 1 and lastAreaId then
        local filtered = {}
        for _, a in ipairs(eligible) do
            if a.area.id ~= lastAreaId then
                table.insert(filtered, a)
            end
        end
        if #filtered > 0 then
            eligible = filtered
        end
    end

    local pick = eligible[math.random(#eligible)]
    return pick.index, pick.area
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

PublicJobServerHandlers['newspaper_delivery'] = {

    -- ========================================================================
    -- REQUEST BATCH — pick area, give newspapers, send locations to client
    -- ========================================================================
    onRequestBatch = function(source, activeData, jobCfg)
        local playerLevel = activeData.level or 1

        -- Pick area (avoid repeat)
        local areaIndex, area = PickArea(jobCfg, playerLevel, activeData.lastAreaId)
        activeData.lastAreaId = area.id
        activeData.currentAreaIndex = areaIndex

        -- Copy all locations in this area as the batch
        local locations = {}
        for _, loc in ipairs(area.locations) do
            table.insert(locations, loc)
        end

        -- Store batch for server-side validation
        activeData.currentBatch = locations

        -- Remove any leftover newspapers from previous batch
        local existingCount = exports['sb_inventory']:GetItemCount(source, 'newspaper')
        if existingCount > 0 then
            exports['sb_inventory']:RemoveItem(source, 'newspaper', existingCount)
        end

        -- Give newspapers to player inventory
        local count = #locations
        exports['sb_inventory']:AddItem(source, 'newspaper', count, nil, nil, false)

        -- Send area + locations + count to client
        TriggerClientEvent('sb_jobs:client:batchReady', source, {
            areaLabel = area.label,
            locations = locations,
            newspaperCount = count,
        })
    end,

    -- ========================================================================
    -- VALIDATE DELIVERY — check batch bounds + distance anti-exploit
    -- ========================================================================
    onValidateDelivery = function(source, deliveryIndex, activeData, jobCfg)
        if not activeData.currentBatch then return false end
        if deliveryIndex < 1 or deliveryIndex > #activeData.currentBatch then return false end

        -- Anti-exploit: check player proximity to delivery coords
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then
            local pedCoords = GetEntityCoords(ped)
            local target = activeData.currentBatch[deliveryIndex]
            local dist = #(pedCoords - vector3(target.x, target.y, target.z))
            if dist > 35.0 then
                print('[sb_jobs] Anti-exploit: Player ' .. source .. ' too far from newspaper delivery point (' .. math.floor(dist) .. 'm)')
                return false
            end
        end

        return true
    end,

    -- ========================================================================
    -- ON END (server) — Remove all newspapers from inventory
    -- Called by framework on quit, drop, confiscate, force-end
    -- ========================================================================
    onEnd = function(source, activeData)
        local count = exports['sb_inventory']:GetItemCount(source, 'newspaper')
        if count > 0 then
            exports['sb_inventory']:RemoveItem(source, 'newspaper', count)
        end
    end,
}
