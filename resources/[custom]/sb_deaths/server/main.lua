--[[
    Everyday Chaos RP - Death System (Server)
    Author: Salah Eddine Boussettah
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- PLAYER DIED
-- ============================================================================

RegisterNetEvent('sb_deaths:server:onDeath', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    if not Player then return end

    Player.Functions.SetMetaData('isdead', true)

    local name = Player.Functions.GetName()
    print('^1[sb_deaths]^7 ' .. name .. ' died (ID: ' .. src .. ')')
end)

-- ============================================================================
-- PLAYER RESPAWNED
-- ============================================================================

RegisterNetEvent('sb_deaths:server:onRespawn', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    if not Player then return end

    -- Clear death state
    Player.Functions.SetMetaData('isdead', false)

    -- Deduct hospital bill ($500 always, allow negative bank)
    local bill = Config.HospitalBill
    local cash = Player.Functions.GetMoney('cash') or 0
    local bank = Player.Functions.GetMoney('bank') or 0

    if cash >= bill then
        Player.Functions.RemoveMoney('cash', bill, 'Hospital bill')
    else
        -- Take all cash first
        if cash > 0 then
            Player.Functions.RemoveMoney('cash', cash, 'Hospital bill')
        end
        -- Remainder from bank (can go negative/debt)
        local remainder = bill - cash
        Player.Functions.SetMoney('bank', bank - remainder, 'Hospital bill')
    end

    -- Reset hunger/thirst to 50 on respawn
    Player.Functions.SetMetaData('hunger', 50)
    Player.Functions.SetMetaData('thirst', 50)

    -- Notify player
    SB.Functions.Notify(src, 'Hospital bill: -$' .. bill, 'warning', 5000)

    print('^2[sb_deaths]^7 ' .. Player.Functions.GetName() .. ' respawned. Bill: $' .. bill)
end)

-- ============================================================================
-- KILLER NAME REQUEST
-- ============================================================================

RegisterNetEvent('sb_deaths:server:getKillerName', function(killerServerId)
    local src = source
    local Killer = SB.Functions.GetPlayer(killerServerId)

    local name = Config.Text.Unknown
    if Killer then
        name = Killer.Functions.GetName()
    end

    TriggerClientEvent('sb_deaths:client:setKillerName', src, name)
end)

-- ============================================================================
-- CALL EMERGENCY
-- ============================================================================

RegisterNetEvent('sb_deaths:server:callEmergency', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    if not Player then return end

    local name = Player.Functions.GetName()
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    -- Broadcast to all EMS on duty (future: filter by job)
    local players = SB.Functions.GetPlayers()
    for _, playerId in pairs(players) do
        local Target = SB.Functions.GetPlayer(playerId)
        if Target then
            local job = Target.Functions.GetJob()
            if job and (job.name == 'ambulance' or job.name == 'ems') and job.onduty then
                SB.Functions.Notify(playerId, 'Emergency call from ' .. name .. '! Check your map.', 'error', 10000)
                -- Future: add blip on their map
            end
        end
    end

    print('^3[sb_deaths]^7 Emergency call from ' .. name .. ' at ' .. tostring(coords))
end)
