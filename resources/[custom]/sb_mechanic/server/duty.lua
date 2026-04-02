-- ============================================================================
-- sb_mechanic - Server: Duty System
-- Duty toggle validation, parts shelf purchase
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- Toggle Duty
-- ============================================================================

RegisterNetEvent('sb_mechanic:toggleDuty')
AddEventHandler('sb_mechanic:toggleDuty', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName then
        TriggerClientEvent('sb_notify:Notify', src, 'You are not a mechanic', 'error', 3000)
        return
    end

    local newDuty = not job.onduty
    Player.Functions.SetJobDuty(newDuty)
    TriggerClientEvent('sb_mechanic:dutyToggled', src, newDuty)

    if Config.Debug then
        print('[sb_mechanic:server] Player ' .. src .. ' duty toggled to: ' .. tostring(newDuty))
    end
end)

-- ============================================================================
-- Force Off Duty on Disconnect
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.PlayerData.job
    if job.name == Config.JobName and job.onduty then
        Player.Functions.SetJobDuty(false)
        if Config.Debug then
            print('[sb_mechanic:server] Player ' .. src .. ' disconnected — set off duty')
        end
    end
end)

-- ============================================================================
-- Force All Mechanics Off Duty on Resource Stop
-- ============================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local players = SB.Functions.GetPlayers()
    for _, src in ipairs(players) do
        local Player = SB.Functions.GetPlayer(src)
        if Player then
            local job = Player.PlayerData.job
            if job.name == Config.JobName and job.onduty then
                Player.Functions.SetJobDuty(false)
                TriggerClientEvent('sb_mechanic:dutyToggled', src, false)
                if Config.Debug then
                    print('[sb_mechanic:server] Resource stopping — player ' .. src .. ' set off duty')
                end
            end
        end
    end
end)

-- ============================================================================
-- Buy Parts
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:buyPart', function(source, cb, itemName, price)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Player not found') end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName then
        return cb(false, 'You are not a mechanic')
    end

    if not job.onduty then
        return cb(false, 'You must be on duty')
    end

    -- Validate item exists in config
    local validItem = false
    for _, item in ipairs(Config.PartsShelf.items) do
        if item.name == itemName and item.price == price then
            validItem = true
            break
        end
    end

    if not validItem then
        return cb(false, 'Invalid item')
    end

    -- Check if player has enough cash
    local cash = Player.PlayerData.money['cash'] or 0
    if cash < price then
        return cb(false, 'Not enough cash ($' .. price .. ' needed)')
    end

    -- Remove money and add item
    Player.Functions.RemoveMoney('cash', price, 'mechanic-parts-purchase')
    local added = exports['sb_inventory']:AddItem(src, itemName, 1)
    if not added then
        -- Refund if inventory full
        Player.Functions.AddMoney('cash', price, 'mechanic-parts-refund')
        return cb(false, 'Inventory full')
    end

    cb(true, 'Purchased ' .. (SB.Shared.Items[itemName] and SB.Shared.Items[itemName].label or itemName))
end)
