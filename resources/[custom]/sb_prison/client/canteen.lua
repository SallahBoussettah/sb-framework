-- ============================================================================
-- SB_PRISON - Canteen NPC (Phase 2)
-- Spawns canteen guard NPC at Bolingbroke, sb_target purchase options
-- ============================================================================

local canteenNpc = nil

-- ============================================================================
-- SPAWN CANTEEN NPC
-- ============================================================================

function SpawnCanteenNPC()
    if canteenNpc and DoesEntityExist(canteenNpc) then return end

    local cfg = Config.CanteenNPC
    local model = GetHashKey(cfg.model)

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    if not HasModelLoaded(model) then
        print('[sb_prison] ^1Failed to load canteen NPC model^7')
        return
    end

    canteenNpc = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)
    SetEntityAsMissionEntity(canteenNpc, true, true)
    SetEntityInvincible(canteenNpc, true)
    FreezeEntityPosition(canteenNpc, true)
    SetBlockingOfNonTemporaryEvents(canteenNpc, true)
    SetPedFleeAttributes(canteenNpc, 0, false)
    SetPedCombatAttributes(canteenNpc, 46, true)
    SetPedCanPlayAmbientAnims(canteenNpc, false)
    SetModelAsNoLongerNeeded(model)

    -- Build target options from Config.CanteenItems
    local options = {}
    for i, item in ipairs(Config.CanteenItems) do
        table.insert(options, {
            name = 'canteen_buy_' .. item.id,
            label = 'Buy ' .. item.label .. ' (' .. item.price .. ' credits)',
            icon = item.icon,
            distance = Config.CanteenNPC.targetRadius or 3.0,
            canInteract = function()
                local jailed, location = GetPrisonState()
                return jailed and location == 'bolingbroke'
            end,
            action = function()
                TriggerServerEvent('sb_prison:server:buyCanteenItem', i)
            end,
        })
    end

    exports['sb_target']:AddTargetEntity(canteenNpc, options)

    if Config.Debug then
        print('[sb_prison] Canteen NPC spawned at ' .. tostring(cfg.coords))
    end
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function CleanupCanteenNPC()
    if canteenNpc and DoesEntityExist(canteenNpc) then
        exports['sb_target']:RemoveTargetEntity(canteenNpc)
        DeletePed(canteenNpc)
    end
    canteenNpc = nil
end

-- ============================================================================
-- SPAWN THREAD (same pattern as guard NPCs — Wait(5000) for world load)
-- ============================================================================

CreateThread(function()
    Wait(5000)
    SpawnCanteenNPC()
end)
