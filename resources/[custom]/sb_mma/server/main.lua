--[[
    Everyday Chaos RP - MMA Arena Betting System (Server)
    Author: Salah Eddine Boussettah

    Handles: Fight state machine, bet management, payouts, DB persistence
    Security: Operation locks, cooldowns, input validation
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- DATABASE SETUP
-- ============================================================================

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS mma_bet_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            fight_id VARCHAR(36) NOT NULL,
            fighter_index TINYINT NOT NULL,
            fighter_name VARCHAR(50) NOT NULL,
            bet_amount INT NOT NULL,
            payout INT DEFAULT 0,
            won TINYINT DEFAULT 0,
            odds DECIMAL(5,2) DEFAULT 0.00,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_fight_id (fight_id)
        )
    ]])
end)

-- ============================================================================
-- STATE MACHINE
-- ============================================================================
-- IDLE → BETTING_OPEN → FIGHT_IN_PROGRESS → PAYOUT → COOLDOWN → IDLE

local STATE = {
    IDLE = 'IDLE',
    BETTING_OPEN = 'BETTING_OPEN',
    FIGHT_IN_PROGRESS = 'FIGHT_IN_PROGRESS',
    PAYOUT = 'PAYOUT',
    COOLDOWN = 'COOLDOWN',
}

local currentState = STATE.IDLE
local currentFight = nil       -- { id, fighters = {[1]={name,model}, [2]={name,model}}, bets = {}, startTime }
local bettingEndTime = 0

-- ============================================================================
-- ANTI-EXPLOIT: Operation lock + cooldown
-- ============================================================================

local operationLock = {}
local betCooldown = {}
local BET_COOLDOWN_SECONDS = 3

local function AcquireLock(src)
    if operationLock[src] then return false end
    operationLock[src] = true
    return true
end

local function ReleaseLock(src)
    operationLock[src] = nil
end

local function IsOnCooldown(src)
    local last = betCooldown[src]
    if not last then return false end
    return (os.time() - last) < BET_COOLDOWN_SECONDS
end

local function SetCooldown(src)
    betCooldown[src] = os.time()
end

AddEventHandler('playerDropped', function()
    local src = source
    operationLock[src] = nil
    betCooldown[src] = nil
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GenerateFightId()
    local chars = 'abcdef0123456789'
    local id = ''
    for i = 1, 8 do
        local r = math.random(1, #chars)
        id = id .. chars:sub(r, r)
    end
    return 'MMA-' .. id
end

local function PickRandom(tbl)
    return tbl[math.random(1, #tbl)]
end

local function GenerateFighters()
    local fighters = {}
    for slot = 1, 2 do
        local cfg = Config.Fighters[slot]
        fighters[slot] = {
            name = PickRandom(cfg.names),
            model = PickRandom(cfg.models),
            health = cfg.health,
            position = cfg.position,
        }
    end
    -- Ensure unique names
    if fighters[1].name == fighters[2].name then
        local names2 = Config.Fighters[2].names
        for _, n in ipairs(names2) do
            if n ~= fighters[1].name then
                fighters[2].name = n
                break
            end
        end
    end
    return fighters
end

local function GetBetTotals()
    if not currentFight then return 0, 0, 0 end
    local pool1, pool2, total = 0, 0, 0
    for _, bet in ipairs(currentFight.bets) do
        if bet.fighter == 1 then
            pool1 = pool1 + bet.amount
        else
            pool2 = pool2 + bet.amount
        end
        total = total + bet.amount
    end
    return pool1, pool2, total
end

local function CalculateOdds()
    local pool1, pool2, total = GetBetTotals()
    local odds1 = pool1 > 0 and (total / pool1) or 2.0
    local odds2 = pool2 > 0 and (total / pool2) or 2.0
    odds1 = math.min(odds1, Config.MaxPayoutMultiplier)
    odds2 = math.min(odds2, Config.MaxPayoutMultiplier)
    -- Round to 2 decimals
    odds1 = math.floor(odds1 * 100 + 0.5) / 100
    odds2 = math.floor(odds2 * 100 + 0.5) / 100
    return odds1, odds2
end

local function GetStateData()
    if currentState == STATE.IDLE then
        return { state = STATE.IDLE }
    end

    local odds1, odds2 = CalculateOdds()
    local pool1, pool2, totalPool = GetBetTotals()
    local betCount = currentFight and #currentFight.bets or 0

    return {
        state = currentState,
        fightId = currentFight and currentFight.id,
        fighters = currentFight and currentFight.fighters,
        odds = { odds1, odds2 },
        pools = { pool1, pool2 },
        totalPool = totalPool,
        betCount = betCount,
        bettingEndTime = bettingEndTime,
        winner = currentFight and currentFight.winner,
    }
end

local function BroadcastState()
    local data = GetStateData()
    TriggerClientEvent('sb_mma:client:stateUpdate', -1, data)
end

-- ============================================================================
-- FIGHT LIFECYCLE
-- ============================================================================

local function StartBetting()
    if currentState ~= STATE.IDLE and currentState ~= STATE.COOLDOWN then return false end

    currentState = STATE.BETTING_OPEN
    currentFight = {
        id = GenerateFightId(),
        fighters = GenerateFighters(),
        bets = {},
        startTime = os.time(),
        winner = nil,
    }
    bettingEndTime = GetGameTimer() + Config.Timers.Betting

    BroadcastState()

    -- Notify all players
    TriggerClientEvent('sb_mma:client:announcement', -1, 'MMA Fight betting is now open!', 'info')

    if Config.Debug then
        print(('[sb_mma] Fight %s started - Betting open for %ds'):format(currentFight.id, Config.Timers.Betting / 1000))
    end

    -- Timer: close betting and start fight
    SetTimeout(Config.Timers.Betting, function()
        if currentState == STATE.BETTING_OPEN then
            StartFight()
        end
    end)

    return true
end

local function DetermineWinner()
    local pool1, pool2 = GetBetTotals()
    local total = pool1 + pool2

    -- Base 50/50, with slight underdog bias
    local weight1 = 0.5
    if total > 0 then
        local ratio1 = pool1 / total
        -- Shift slightly toward the underdog (less bet on)
        -- If 70% bet on fighter 1, their win chance drops to ~45%
        weight1 = 0.5 - (ratio1 - 0.5) * 0.3
        weight1 = math.max(0.2, math.min(0.8, weight1))
    end

    local roll = math.random()
    return roll < weight1 and 1 or 2
end

function StartFight()
    if currentState ~= STATE.BETTING_OPEN then return end

    if #currentFight.bets == 0 then
        -- No bets placed, skip fight
        currentState = STATE.COOLDOWN
        currentFight = nil
        BroadcastState()
        TriggerClientEvent('sb_mma:client:announcement', -1, 'No bets placed. Fight cancelled.', 'error')
        SetTimeout(Config.Timers.Cooldown, function()
            if currentState == STATE.COOLDOWN then
                currentState = STATE.IDLE
                BroadcastState()
            end
        end)
        return
    end

    currentState = STATE.FIGHT_IN_PROGRESS
    local winner = DetermineWinner()
    currentFight.winner = winner

    BroadcastState()

    TriggerClientEvent('sb_mma:client:announcement', -1, 'The fight has begun!', 'info')
    -- Tell clients to simulate the fight
    TriggerClientEvent('sb_mma:client:startFight', -1, winner)

    -- Timer: end fight and do payouts
    SetTimeout(Config.Timers.MaxFight, function()
        if currentState == STATE.FIGHT_IN_PROGRESS then
            ProcessPayouts()
        end
    end)
end

function ProcessPayouts()
    if currentState ~= STATE.FIGHT_IN_PROGRESS then return end

    currentState = STATE.PAYOUT
    local winner = currentFight.winner
    local winnerName = currentFight.fighters[winner].name
    local odds1, odds2 = CalculateOdds()
    local winOdds = winner == 1 and odds1 or odds2

    TriggerClientEvent('sb_mma:client:fightResult', -1, winner, winnerName)

    -- Process each bet
    for _, bet in ipairs(currentFight.bets) do
        local betOdds = bet.fighter == 1 and odds1 or odds2
        local won = bet.fighter == winner
        local payout = 0

        if won then
            payout = math.floor(bet.amount * winOdds)
            local Player = SB.Functions.GetPlayer(bet.source)
            if Player then
                Player.Functions.AddMoney('cash', payout, 'MMA fight winnings')
                SB.Functions.Notify(bet.source,
                    ('You won $%s on %s!'):format(payout, winnerName), 'success', 6000)
            end
        else
            SB.Functions.Notify(bet.source,
                ('You lost $%s. %s was defeated.'):format(bet.amount, currentFight.fighters[bet.fighter].name), 'error', 6000)
        end

        -- Save to DB
        MySQL.insert(
            'INSERT INTO mma_bet_history (citizenid, fight_id, fighter_index, fighter_name, bet_amount, payout, won, odds) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { bet.citizenid, currentFight.id, bet.fighter, currentFight.fighters[bet.fighter].name, bet.amount, payout, won and 1 or 0, betOdds }
        )
    end

    BroadcastState()

    -- Move to cooldown
    SetTimeout(5000, function()
        currentState = STATE.COOLDOWN
        BroadcastState()
        SetTimeout(Config.Timers.Cooldown, function()
            if currentState == STATE.COOLDOWN then
                currentState = STATE.IDLE
                currentFight = nil
                BroadcastState()
            end
        end)
    end)
end

-- ============================================================================
-- STOP / CANCEL (refund all bets)
-- ============================================================================

local function StopFight(reason)
    if currentState == STATE.IDLE then return false end

    -- Refund all bets
    if currentFight and currentFight.bets then
        for _, bet in ipairs(currentFight.bets) do
            local Player = SB.Functions.GetPlayer(bet.source)
            if Player then
                Player.Functions.AddMoney('cash', bet.amount, 'MMA fight cancelled - refund')
                SB.Functions.Notify(bet.source, ('Fight cancelled. $%s refunded.'):format(bet.amount), 'info', 5000)
            end
        end
    end

    currentState = STATE.IDLE
    currentFight = nil
    BroadcastState()
    TriggerClientEvent('sb_mma:client:announcement', -1, reason or 'Fight has been cancelled.', 'error')
    return true
end

-- ============================================================================
-- BET HANDLER
-- ============================================================================

RegisterNetEvent('sb_mma:server:placeBet', function(fighterIndex, amount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Anti-exploit: lock
    if not AcquireLock(src) then
        SB.Functions.Notify(src, 'Transaction in progress...', 'error', 2000)
        return
    end

    -- Anti-exploit: cooldown
    if IsOnCooldown(src) then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Please wait before betting again.', 'error', 2000)
        return
    end

    -- State check
    if currentState ~= STATE.BETTING_OPEN or not currentFight then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Betting is not open right now.', 'error', 3000)
        return
    end

    -- Validate fighter index
    fighterIndex = tonumber(fighterIndex)
    if not fighterIndex or (fighterIndex ~= 1 and fighterIndex ~= 2) then
        ReleaseLock(src)
        return
    end

    -- Validate amount
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        ReleaseLock(src)
        return
    end
    amount = math.floor(amount)

    if amount < Config.MinBet then
        ReleaseLock(src)
        SB.Functions.Notify(src, ('Minimum bet is $%s'):format(Config.MinBet), 'error', 3000)
        return
    end

    if amount > Config.MaxBet then
        ReleaseLock(src)
        SB.Functions.Notify(src, ('Maximum bet is $%s'):format(Config.MaxBet), 'error', 3000)
        return
    end

    -- Check if player already bet this fight
    local citizenid = Player.PlayerData.citizenid
    for _, bet in ipairs(currentFight.bets) do
        if bet.citizenid == citizenid then
            ReleaseLock(src)
            SB.Functions.Notify(src, 'You already placed a bet this fight!', 'error', 3000)
            return
        end
    end

    -- Check funds (cash only for betting)
    local cash = Player.PlayerData.money.cash
    if cash < amount then
        ReleaseLock(src)
        SB.Functions.Notify(src, 'Not enough cash!', 'error', 3000)
        return
    end

    -- Deduct money
    Player.Functions.RemoveMoney('cash', amount, 'MMA bet on ' .. currentFight.fighters[fighterIndex].name)

    -- Record bet
    currentFight.bets[#currentFight.bets + 1] = {
        source = src,
        citizenid = citizenid,
        fighter = fighterIndex,
        amount = amount,
    }

    SetCooldown(src)
    ReleaseLock(src)

    local fighterName = currentFight.fighters[fighterIndex].name
    SB.Functions.Notify(src, ('Bet $%s on %s'):format(amount, fighterName), 'success', 4000)

    -- Broadcast updated odds
    BroadcastState()

    if Config.Debug then
        print(('[sb_mma] %s bet $%d on fighter %d (%s)'):format(citizenid, amount, fighterIndex, fighterName))
    end
end)

-- ============================================================================
-- CALLBACKS
-- ============================================================================

SB.Functions.CreateCallback('sb_mma:getState', function(source, cb)
    cb(GetStateData())
end)

SB.Functions.CreateCallback('sb_mma:getHistory', function(source, cb)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then cb({}) return end

    local citizenid = Player.PlayerData.citizenid
    local history = MySQL.query.await(
        'SELECT fighter_name, bet_amount, payout, won, odds, created_at FROM mma_bet_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT 20',
        { citizenid }
    )
    cb(history or {})
end)

-- ============================================================================
-- SCHEDULE THREAD
-- ============================================================================

CreateThread(function()
    local lastTriggeredHour = -1

    while true do
        Wait(30000) -- Check every 30 seconds

        if currentState == STATE.IDLE then
            local gameHour = tonumber(os.date('%H'))
            for _, hour in ipairs(Config.Schedule) do
                if gameHour == hour and lastTriggeredHour ~= gameHour then
                    lastTriggeredHour = gameHour
                    StartBetting()
                    break
                end
            end
            -- Reset when hour changes
            if gameHour ~= lastTriggeredHour then
                lastTriggeredHour = -1
            end
        end
    end
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

RegisterCommand(Config.AdminCommand, function(source, args)
    local src = source

    -- Console always allowed
    if src > 0 then
        if not IsPlayerAceAllowed(src, 'command.sb_admin') then
            SB.Functions.Notify(src, 'Admin only command.', 'error', 3000)
            return
        end
    end

    local action = args[1] and args[1]:lower() or 'status'

    if action == 'start' then
        local success = StartBetting()
        if success then
            if src > 0 then SB.Functions.Notify(src, 'MMA fight started.', 'success', 3000) end
            print('[sb_mma] Admin forced fight start')
        else
            if src > 0 then SB.Functions.Notify(src, 'Cannot start fight in current state: ' .. currentState, 'error', 3000) end
        end

    elseif action == 'stop' then
        local success = StopFight('Fight cancelled by admin.')
        if success then
            if src > 0 then SB.Functions.Notify(src, 'Fight stopped and bets refunded.', 'success', 3000) end
            print('[sb_mma] Admin stopped fight')
        else
            if src > 0 then SB.Functions.Notify(src, 'No active fight to stop.', 'error', 3000) end
        end

    elseif action == 'status' then
        local pool1, pool2, total = GetBetTotals()
        local msg = ('State: %s | Bets: %d | Pool: $%d'):format(
            currentState,
            currentFight and #currentFight.bets or 0,
            total
        )
        if src > 0 then
            SB.Functions.Notify(src, msg, 'info', 5000)
        end
        print('[sb_mma] ' .. msg)

    else
        if src > 0 then SB.Functions.Notify(src, 'Usage: /mma start|stop|status', 'info', 4000) end
    end
end, false)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print('[sb_mma] MMA Arena Betting System loaded')
end)
