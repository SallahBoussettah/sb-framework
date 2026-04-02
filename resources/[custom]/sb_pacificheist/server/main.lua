-- ============================================================================
-- SB_PACIFICHEIST - Server Main
-- Pacific Standard Bank Heist for sb_core framework
-- ============================================================================

local SBCore = exports['sb_core']:GetCoreObject()

-- State tracking
local lastHeistTime = 0
local heistActive = false
local glassRewardItem = nil
local glassRewardIndex = 1

-- Server-side loot state (prevents double-grab exploit)
local lootState = {
    mainStack = false,
    stacks = {},
    trolleys = {},
    drills = {},
    glass = false,
    paintings = {},
}
local c4State = {}
local firstLooter = nil  -- server ID of player who first stole a painting/glass item

-- ============================================================================
-- CALLBACKS
-- ============================================================================

SBCore.Functions.CreateCallback('sb_pacificheist:checkPoliceCount', function(source, cb)
    local players = SBCore.Functions.GetPlayers()
    local policeCount = 0

    for _, playerId in ipairs(players) do
        local player = SBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job.name == 'police' and player.PlayerData.job.onduty then
            policeCount = policeCount + 1
        end
    end

    cb(policeCount >= Config.RequiredPoliceCount)
end)

SBCore.Functions.CreateCallback('sb_pacificheist:checkCooldown', function(source, cb)
    local currentTime = os.time()
    local timeSinceLast = currentTime - lastHeistTime

    if lastHeistTime == 0 or timeSinceLast >= Config.HeistCooldown then
        cb(true, 0)
    else
        local remaining = Config.HeistCooldown - timeSinceLast
        cb(false, remaining)
    end
end)

SBCore.Functions.CreateCallback('sb_pacificheist:isHeistActive', function(source, cb)
    -- If cooldown has expired, heist is no longer active
    if heistActive and lastHeistTime > 0 then
        local elapsed = os.time() - lastHeistTime
        if elapsed >= Config.HeistCooldown then
            heistActive = false
        end
    end
    cb(heistActive)
end)

SBCore.Functions.CreateCallback('sb_pacificheist:hasItem', function(source, cb, itemName)
    local player = SBCore.Functions.GetPlayer(source)
    if not player then
        print('[sb_pacificheist] Player not found!')
        cb(false)
        return
    end

    local hasItem = exports['sb_inventory']:HasItem(source, itemName)
    cb(hasItem)
end)

-- Atomic loot claim - prevents double-grab exploit
SBCore.Functions.CreateCallback('sb_pacificheist:canLoot', function(source, cb, lootType, index)
    if lootType == 'mainStack' then
        if lootState.mainStack then cb(false) return end
        lootState.mainStack = true
        TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'mainStack')
    elseif lootType == 'stack' then
        if lootState.stacks[index] then cb(false) return end
        lootState.stacks[index] = true
        TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'stack', index)
    elseif lootType == 'trolley' then
        if lootState.trolleys[index] then cb(false) return end
        lootState.trolleys[index] = true
        TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'trolley', index)
    elseif lootType == 'drill' then
        if lootState.drills[index] then cb(false) return end
        lootState.drills[index] = true
        TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'drill', index)
    elseif lootType == 'glass' then
        if lootState.glass then cb(false) return end
        lootState.glass = true
        TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'glass')
    elseif lootType == 'painting' then
        if lootState.paintings[index] then cb(false) return end
        lootState.paintings[index] = true
        TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'painting', index)
    else
        cb(false)
        return
    end

    -- Track first player to steal a painting or glass item (for buyer GPS)
    if not firstLooter and (lootType == 'painting' or lootType == 'glass') then
        firstLooter = source
        TriggerClientEvent('sb_pacificheist:setAsRobber', source)
    end

    cb(true)
end)

-- ============================================================================
-- HEIST START
-- ============================================================================

RegisterNetEvent('sb_pacificheist:startHeist', function()
    local src = source
    local player = SBCore.Functions.GetPlayer(src)
    if not player then return end

    -- Double check cooldown server-side
    local currentTime = os.time()
    if lastHeistTime > 0 and (currentTime - lastHeistTime) < Config.HeistCooldown then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Bank is still on cooldown.', 'error', 3000)
        return
    end

    lastHeistTime = currentTime
    heistActive = true

    -- Notify ALL players so anyone can participate
    TriggerClientEvent('sb_pacificheist:heistStarted', -1)

    -- Log the heist start
    print(('[sb_pacificheist] Heist started by %s (ID: %s)'):format(player.PlayerData.name, src))
end)

-- ============================================================================
-- VAULT ACTIONS
-- ============================================================================

RegisterNetEvent('sb_pacificheist:vaultAction', function(actionType, started)
    -- Sync vault actions to all clients
    TriggerClientEvent('sb_pacificheist:syncVaultAction', -1, actionType, started)
end)

-- Sync thermite flame effects to all OTHER players
RegisterNetEvent('sb_pacificheist:thermiteFlames', function(doorIndex, active)
    local src = source
    TriggerClientEvent('sb_pacificheist:syncThermiteFlames', -1, doorIndex, active, src)
end)

RegisterNetEvent('sb_pacificheist:vaultOpened', function(vaultType)
    TriggerClientEvent('sb_pacificheist:syncVaultOpened', -1, vaultType)
end)

RegisterNetEvent('sb_pacificheist:doorUnlocked', function(index)
    TriggerClientEvent('sb_pacificheist:syncDoorUnlock', -1, index)
end)

RegisterNetEvent('sb_pacificheist:setGlassReward', function(item, index)
    glassRewardItem = item
    glassRewardIndex = index
    TriggerClientEvent('sb_pacificheist:syncGlassReward', -1, item, index)
end)

-- ============================================================================
-- LOOT TRACKING
-- ============================================================================

RegisterNetEvent('sb_pacificheist:lootTaken', function(lootType, index)
    TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, lootType, index)
end)

RegisterNetEvent('sb_pacificheist:c4Planted', function(index)
    c4State[index] = true
    TriggerClientEvent('sb_pacificheist:syncLootTaken', -1, 'c4', index)

    -- Server-authoritative check: all 6 gates planted?
    local allPlanted = true
    for i = 1, #Config.CellGates do
        if not c4State[i] then
            allPlanted = false
            break
        end
    end

    if allPlanted then
        -- Tell ALL clients detonation is ready (authoritative, no race conditions)
        TriggerClientEvent('sb_pacificheist:allC4Planted', -1)
    end
end)

-- C4 detonation sync to all clients
RegisterNetEvent('sb_pacificheist:detonateC4', function()
    TriggerClientEvent('sb_pacificheist:syncDetonateC4', -1)
end)

-- Inner vault door state sync
RegisterNetEvent('sb_pacificheist:innerVaultLaptopHacked', function()
    TriggerClientEvent('sb_pacificheist:syncInnerVaultLaptop', -1)
end)

RegisterNetEvent('sb_pacificheist:innerVaultDoorOpened', function()
    TriggerClientEvent('sb_pacificheist:syncInnerVaultDoor', -1)
end)

-- ============================================================================
-- ITEM MANAGEMENT
-- ============================================================================

RegisterNetEvent('sb_pacificheist:removeItem', function(itemName)
    local src = source
    local player = SBCore.Functions.GetPlayer(src)
    if not player then return end

    exports['sb_inventory']:RemoveItem(src, itemName, 1)
end)

RegisterNetEvent('sb_pacificheist:rewardItem', function(itemName, count, rewardType)
    local src = source
    local player = SBCore.Functions.GetPlayer(src)
    if not player then return end

    if rewardType == 'money' then
        if Config.BlackMoney then
            -- Give dirty money item instead
            exports['sb_inventory']:AddItem(src, 'dirty_money', count)
        else
            player.Functions.AddMoney('cash', count, 'pacific-heist')
        end
    else
        if itemName and count then
            exports['sb_inventory']:AddItem(src, itemName, count)
        end
    end
end)

-- ============================================================================
-- SELL LOOT
-- ============================================================================

RegisterNetEvent('sb_pacificheist:sellLoot', function()
    local src = source
    local player = SBCore.Functions.GetPlayer(src)
    if not player then return end

    local totalMoney = 0

    -- Sell reward items
    for _, reward in ipairs(Config.RewardItems) do
        local amount = exports['sb_inventory']:GetItemCount(src, reward.name)
        if amount > 0 then
            exports['sb_inventory']:RemoveItem(src, reward.name, amount)
            totalMoney = totalMoney + (amount * reward.sellPrice)
        end
    end

    -- Sell glass cutting rewards
    for _, reward in ipairs(Config.GlassCuttingRewards) do
        local amount = exports['sb_inventory']:GetItemCount(src, reward.item)
        if amount > 0 then
            exports['sb_inventory']:RemoveItem(src, reward.item, amount)
            totalMoney = totalMoney + (amount * reward.price)
        end
    end

    -- Sell paintings
    for _, reward in ipairs(Config.PaintingRewards) do
        local amount = exports['sb_inventory']:GetItemCount(src, reward.item)
        if amount > 0 then
            exports['sb_inventory']:RemoveItem(src, reward.item, amount)
            totalMoney = totalMoney + (amount * reward.price)
        end
    end

    -- Give money
    if totalMoney > 0 then
        if Config.BlackMoney then
            exports['sb_inventory']:AddItem(src, 'dirty_money', totalMoney)
        else
            player.Functions.AddMoney('cash', totalMoney, 'pacific-heist-sale')
        end
        TriggerClientEvent('sb_pacificheist:moneyReceived', src, totalMoney)
    end

    print(('[sb_pacificheist] %s sold loot for $%d'):format(player.PlayerData.name, totalMoney))
end)

-- ============================================================================
-- POLICE ALERT
-- ============================================================================

RegisterNetEvent('sb_pacificheist:policeAlert', function(coords)
    local players = SBCore.Functions.GetPlayers()

    for _, playerId in ipairs(players) do
        local player = SBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job.name == 'police' then
            TriggerClientEvent('sb_pacificheist:policeAlert', playerId, coords)
        end
    end
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Give heist kit for testing
RegisterCommand('heistkit', function(source, args)
    local src = source
    local player = SBCore.Functions.GetPlayer(src)

    print('[sb_pacificheist] /heistkit command triggered by source: ' .. tostring(src))

    if not player then
        print('[sb_pacificheist] Player not found!')
        return
    end

    -- Check admin permission (ACE)
    if not IsPlayerAceAllowed(src, 'command.sb_admin') then
        TriggerClientEvent('sb_notify:client:Notify', src, 'No permission!', 'error', 3000)
        print('[sb_pacificheist] No permission for player')
        return
    end

    print('[sb_pacificheist] Giving heist items to ' .. player.PlayerData.name)

    -- Give all heist items using sb_inventory export
    local allSuccess = true
    allSuccess = exports['sb_inventory']:AddItem(src, 'heist_drill', 1) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'heist_bag', 1) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'glass_cutter', 1) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'c4_explosive', 6) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'thermite_charge', 4) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'hacking_laptop', 1) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'trojan_usb', 1) and allSuccess
    allSuccess = exports['sb_inventory']:AddItem(src, 'switchblade', 1) and allSuccess  -- For paintings

    if allSuccess then
        TriggerClientEvent('sb_notify:client:Notify', src, 'Heist kit received!', 'success', 5000)
        print(('[sb_pacificheist] Heist kit given to %s (ID: %s)'):format(player.PlayerData.name, src))
    else
        TriggerClientEvent('sb_notify:client:Notify', src, 'Some items failed - check if items exist in database', 'warning', 5000)
        print('[sb_pacificheist] Some items may have failed to add')
    end
end, false)

-- Reset heist (admin/police)
RegisterCommand('resetheist', function(source, args)
    local src = source
    local player = SBCore.Functions.GetPlayer(src)
    if not player then return end

    -- Check if admin or on-duty police
    local isAdmin = IsPlayerAceAllowed(src, 'command.sb_admin')
    local isPolice = player.PlayerData.job.name == 'police' and player.PlayerData.job.onduty

    if not isAdmin and not isPolice then
        TriggerClientEvent('sb_notify:client:Notify', src, 'No permission!', 'error', 3000)
        return
    end

    if heistActive then
        heistActive = false
        -- Reset server-side loot/C4/GPS state
        lootState = { mainStack = false, stacks = {}, trolleys = {}, drills = {}, glass = false, paintings = {} }
        c4State = {}
        firstLooter = nil
        TriggerClientEvent('sb_pacificheist:resetHeist', -1)
        print(('[sb_pacificheist] Heist reset by %s (ID: %s)'):format(player.PlayerData.name, src))
    else
        TriggerClientEvent('sb_notify:client:Notify', src, 'No active heist to reset.', 'error', 3000)
    end
end, false)

-- Skip cooldown (admin only)
RegisterCommand('heistcooldown', function(source, args)
    local src = source

    if not IsPlayerAceAllowed(src, 'command.sb_admin') then
        TriggerClientEvent('sb_notify:client:Notify', src, 'No permission!', 'error', 3000)
        return
    end

    lastHeistTime = 0

    TriggerClientEvent('sb_notify:client:Notify', src, 'Heist cooldown reset!', 'success', 3000)
end, false)

-- ============================================================================
-- RESOURCE CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Reset heist if resource stops
    if heistActive then
        heistActive = false
        lastHeistTime = 0
        lootState = { mainStack = false, stacks = {}, trolleys = {}, drills = {}, glass = false, paintings = {} }
        c4State = {}
        firstLooter = nil
    end
end)

-- ============================================================================
-- CHAT SUGGESTIONS
-- ============================================================================

TriggerEvent('chat:addSuggestion', '/heistkit', 'Get Pacific Heist testing kit (Admin)', {})
TriggerEvent('chat:addSuggestion', '/resetheist', 'Reset the Pacific Heist (Admin/Police)', {})
TriggerEvent('chat:addSuggestion', '/heistcooldown', 'Reset heist cooldown (Admin)', {})

print('[sb_pacificheist] Server loaded - Pacific Standard Bank Heist')
