--[[
    Everyday Chaos RP - Metabolism Server
    Author: Salah Eddine Boussettah

    Handles hunger/thirst decay and food/drink restoration.
    Syncs with sb_core metadata and sb_hud via PlayerData updates.
]]

local SBCore = nil

-- Defer core object retrieval to ensure sb_core is loaded
CreateThread(function()
    while not SBCore do
        local success, result = pcall(function()
            return exports['sb_core']:GetCoreObject()
        end)
        if success and result then
            SBCore = result
            print('[sb_metabolism] Connected to sb_core')
        else
            Wait(1000)
        end
    end
end)

-- ========================================================================
-- DECAY TIMER
-- ========================================================================
CreateThread(function()
    -- Wait for core to be ready
    while not SBCore do Wait(500) end
    print('[sb_metabolism] Decay timer started (interval: ' .. Config.DecayInterval .. 'ms)')

    while true do
        Wait(Config.DecayInterval)

        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local source = tonumber(playerId)
            if source then
                local Player = SBCore.Functions.GetPlayer(source)
                if Player and Player.PlayerData and Player.PlayerData.metadata then
                    local hunger = Player.PlayerData.metadata.hunger or 100
                    local thirst = Player.PlayerData.metadata.thirst or 100

                    -- Decay
                    hunger = math.max(0, hunger - Config.HungerDecay)
                    thirst = math.max(0, thirst - Config.ThirstDecay)

                    -- Update metadata (this syncs to client via sb_core)
                    Player.Functions.SetMetaData('hunger', hunger)
                    Player.Functions.SetMetaData('thirst', thirst)

                    -- Notify client if below damage threshold for damage ticks
                    if hunger <= Config.DamageThreshold or thirst <= Config.DamageThreshold then
                        TriggerClientEvent('sb_metabolism:client:startDamage', source, hunger, thirst)
                    end
                end
            end
        end
    end
end)

-- ========================================================================
-- ITEM USAGE HANDLER (listens to sb_inventory)
-- ========================================================================
AddEventHandler('sb_inventory:server:itemUsed', function(source, itemName, amount, metadata, category)
    if not SBCore then return end

    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hunger = Player.PlayerData.metadata.hunger or 100
    local thirst = Player.PlayerData.metadata.thirst or 100

    -- Check if it's a food item
    if Config.FoodItems[itemName] then
        local restore = Config.FoodItems[itemName]
        hunger = math.min(100, hunger + restore)
        Player.Functions.SetMetaData('hunger', hunger)
        TriggerClientEvent('SB:Client:Notify', source,
            ('Hunger +%d%%'):format(restore), 'success', 2000)
    end

    -- Check if it's a drink item
    if Config.DrinkItems[itemName] then
        local restore = Config.DrinkItems[itemName]
        thirst = math.min(100, thirst + restore)
        Player.Functions.SetMetaData('thirst', thirst)
        TriggerClientEvent('SB:Client:Notify', source,
            ('Thirst +%d%%'):format(restore), 'success', 2000)
    end
end)

-- ========================================================================
-- STRESS DECAY TIMER
-- ========================================================================
local lastStressGain = {} -- [source] = timestamp of last stress gain

CreateThread(function()
    while not SBCore do Wait(500) end
    print('[sb_metabolism] Stress decay timer started (interval: ' .. Config.StressDecayInterval .. 'ms)')

    while true do
        Wait(Config.StressDecayInterval)

        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local source = tonumber(playerId)
            if source then
                local Player = SBCore.Functions.GetPlayer(source)
                if Player and Player.PlayerData and Player.PlayerData.metadata then
                    local stress = Player.PlayerData.metadata.stress or 0
                    if stress > 0 then
                        local now = GetGameTimer()
                        local lastGain = lastStressGain[source] or 0
                        -- Only decay if cooldown has passed
                        if (now - lastGain) >= Config.StressDecayCooldown then
                            stress = math.max(Config.StressMin, stress - Config.StressDecayRate)
                            Player.Functions.SetMetaData('stress', stress)
                        end
                    end
                end
            end
        end
    end
end)

-- ========================================================================
-- STRESS GAIN HANDLER (from client)
-- ========================================================================
RegisterNetEvent('sb_metabolism:server:addStress', function(amount)
    local source = source
    if not SBCore then return end
    if type(amount) ~= 'number' or amount <= 0 or amount > 10 then return end

    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local stress = Player.PlayerData.metadata.stress or 0
    stress = math.min(Config.StressMax, stress + amount)
    Player.Functions.SetMetaData('stress', stress)
    lastStressGain[source] = GetGameTimer()
end)

-- ========================================================================
-- STRESS RELIEF ITEMS
-- ========================================================================
AddEventHandler('sb_inventory:server:itemUsed', function(source, itemName, amount, metadata, category)
    if not SBCore then return end
    if not Config.StressReliefItems[itemName] then return end

    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return end

    local stress = Player.PlayerData.metadata.stress or 0
    local relief = Config.StressReliefItems[itemName]
    stress = math.max(Config.StressMin, stress - relief)
    Player.Functions.SetMetaData('stress', stress)
    TriggerClientEvent('SB:Client:Notify', source,
        ('Stress -%d%%'):format(relief), 'success', 2000)
end)

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    lastStressGain[source] = nil
end)

-- ========================================================================
-- PLAYER LOADED - Ensure metadata has hunger/thirst/stress
-- ========================================================================
AddEventHandler('SB:Server:OnPlayerLoaded', function(source, Player)
    if not Player then return end

    if not Player.PlayerData.metadata.hunger then
        Player.Functions.SetMetaData('hunger', 100)
    end
    if not Player.PlayerData.metadata.thirst then
        Player.Functions.SetMetaData('thirst', 100)
    end
    if not Player.PlayerData.metadata.stress then
        Player.Functions.SetMetaData('stress', 0)
    end
end)

print('[sb_metabolism] Server-side loaded successfully')
