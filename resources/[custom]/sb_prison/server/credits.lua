-- ============================================================================
-- SB_PRISON - Credits Economy (Phase 2)
-- DB table + CRUD functions used by server/main.lua and server/jobs.lua
-- ============================================================================

-- Create credits table on MySQL ready
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS sb_prison_credits (
            citizenid VARCHAR(50) NOT NULL UNIQUE,
            balance INT NOT NULL DEFAULT 0,
            total_earned INT NOT NULL DEFAULT 0,
            total_spent INT NOT NULL DEFAULT 0,
            PRIMARY KEY (citizenid)
        )
    ]])
    print('^2[sb_prison]^7 Credits table ready')
end)

-- ============================================================================
-- CRUD FUNCTIONS (global — used by server/main.lua and server/jobs.lua)
-- ============================================================================

function InitCredits(citizenid)
    local starting = Config.Credits.startingBalance or 0
    MySQL.query.await(
        'INSERT INTO sb_prison_credits (citizenid, balance, total_earned, total_spent) VALUES (?, ?, 0, 0) ON DUPLICATE KEY UPDATE citizenid = citizenid',
        { citizenid, starting }
    )
    -- Sync to client
    local src = GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('sb_prison:client:syncCredits', src, starting)
    end
end

function GetCredits(citizenid)
    local row = MySQL.single.await(
        'SELECT balance FROM sb_prison_credits WHERE citizenid = ?',
        { citizenid }
    )
    return row and row.balance or 0
end

function AddCredits(citizenid, amount, reason)
    local maxBal = Config.Credits.maxBalance or 9999
    MySQL.query.await(
        'UPDATE sb_prison_credits SET balance = LEAST(balance + ?, ?), total_earned = total_earned + ? WHERE citizenid = ?',
        { amount, maxBal, amount, citizenid }
    )
    local newBalance = GetCredits(citizenid)
    -- Sync to client
    local src = GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('sb_prison:client:syncCredits', src, newBalance)
    end
    if Config.Debug then
        print(string.format('[sb_prison] Credits +%d for %s (%s) → %d', amount, citizenid, reason or '', newBalance))
    end
    return newBalance
end

function RemoveCredits(citizenid, amount, reason)
    local current = GetCredits(citizenid)
    if current < amount then
        return false
    end
    MySQL.query.await(
        'UPDATE sb_prison_credits SET balance = balance - ?, total_spent = total_spent + ? WHERE citizenid = ?',
        { amount, amount, citizenid }
    )
    local newBalance = GetCredits(citizenid)
    -- Sync to client
    local src = GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('sb_prison:client:syncCredits', src, newBalance)
    end
    if Config.Debug then
        print(string.format('[sb_prison] Credits -%d for %s (%s) → %d', amount, citizenid, reason or '', newBalance))
    end
    return true
end

function DeleteCredits(citizenid)
    MySQL.query.await(
        'DELETE FROM sb_prison_credits WHERE citizenid = ?',
        { citizenid }
    )
    -- Sync 0 to client (if online)
    local src = GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('sb_prison:client:syncCredits', src, 0)
    end
end

-- ============================================================================
-- EXPORT
-- ============================================================================

exports('GetPrisonerCredits', function(citizenid)
    return GetCredits(citizenid)
end)
