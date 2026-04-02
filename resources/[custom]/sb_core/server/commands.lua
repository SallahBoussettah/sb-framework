--[[
    Everyday Chaos RP - Server Commands (Player Only)
    Author: Salah Eddine Boussettah
    Note: Admin commands have been moved to sb_admin
]]

-- ============================================================================
-- PLAYER COMMANDS
-- ============================================================================

-- Get player ID
RegisterCommand('myid', function(source)
    local src = source
    if src == 0 then return end

    SB.Functions.Notify(src, 'Your ID: ' .. src, 'primary')
end, false)

-- Check money balance
RegisterCommand('money', function(source)
    local src = source
    if src == 0 then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then
        SB.Functions.Notify(src, 'You must select a character first', 'error')
        return
    end

    local money = Player.Functions.GetMoney()
    local cash = SBShared.FormatMoney(money.cash or 0)
    local bank = SBShared.FormatMoney(money.bank or 0)
    local crypto = money.crypto or 0

    TriggerClientEvent('chat:addMessage', src, {
        template = '<div class="chat-message money-info"><b>Your Balance:</b><br/>Cash: {0}<br/>Bank: {1}<br/>Crypto: {2}</div>',
        args = { cash, bank, tostring(crypto) }
    })
end, false)

-- Get player info (citizenid, name)
RegisterCommand('me', function(source, args)
    local src = source
    if src == 0 then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local message = table.concat(args, ' ')
    if message == '' then return end

    -- Broadcast to nearby players
    local coords = GetEntityCoords(GetPlayerPed(src))
    local players = SB.Functions.GetPlayers()

    for _, playerId in pairs(players) do
        local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
        if #(coords - targetCoords) < 30.0 then
            TriggerClientEvent('chat:addMessage', playerId, {
                template = '<div class="chat-message me"><span class="me-name">{0}</span> {1}</div>',
                args = { Player.Functions.GetName(), message }
            })
        end
    end
end, false)

-- Toggle duty (for job)
RegisterCommand('duty', function(source)
    local src = source
    if src == 0 then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.Functions.GetJob()
    if job.name == 'unemployed' then
        SB.Functions.Notify(src, 'You don\'t have a job', 'error')
        return
    end

    local newDuty = not job.onduty
    Player.Functions.SetJobDuty(newDuty)

    print(('[sb_core] ^3DEBUG: /duty command - job: %s, newDuty: %s^7'):format(job.name, tostring(newDuty)))

    -- Sync with sb_police if player is police
    if job.name == 'police' and GetResourceState('sb_police') == 'started' then
        print('[sb_core] ^3DEBUG: Triggering sb_police:server:syncDutyFromCore^7')
        TriggerEvent('sb_police:server:syncDutyFromCore', src, newDuty)
    else
        print(('[sb_core] ^3DEBUG: NOT triggering sb_police sync - job: %s, sb_police state: %s^7'):format(job.name, GetResourceState('sb_police')))
    end

    SB.Functions.Notify(src, newDuty and Lang('job_on_duty') or Lang('job_off_duty'), 'success')
end, false)

-- ============================================================================
-- DEBUG COMMANDS
-- ============================================================================

if Config.Debug then
    -- Debug: Print player data
    RegisterCommand('debugplayer', function(source)
        local src = source
        if src == 0 then return end

        local Player = SB.Functions.GetPlayer(src)
        if Player then
            print(json.encode(Player.PlayerData, { indent = true }))
        end
    end, false)

    -- Debug: Reload shared data
    RegisterCommand('reloadshared', function(source)
        if source ~= 0 and not IsPlayerAceAllowed(source, 'command') then
            return
        end

        print('^2[SB_CORE]^7 Shared data reloaded')
    end, false)
end
