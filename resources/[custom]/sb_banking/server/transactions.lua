--[[
    Everyday Chaos RP - Transaction History (Server)
    Author: Salah Eddine Boussettah
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- ADD TRANSACTION (Export)
-- ============================================================================

exports('AddTransaction', function(citizenid, txType, amount, balanceAfter, description, targetCitizenid)
    MySQL.insert('INSERT INTO bank_transactions (citizenid, type, amount, balance_after, description, target_citizenid) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, txType, amount, balanceAfter, description or '', targetCitizenid
    })
end)

-- Easy export for logging purchases from other scripts
-- Usage: exports['sb_banking']:LogPurchase(citizenid, amount, balanceAfter, 'Vehicle Purchase - Sultan')
exports('LogPurchase', function(citizenid, amount, balanceAfter, description)
    MySQL.insert('INSERT INTO bank_transactions (citizenid, type, amount, balance_after, description) VALUES (?, ?, ?, ?, ?)', {
        citizenid, 'purchase', amount, balanceAfter, description or 'Purchase'
    })
end)

-- Easy export for logging refunds
exports('LogRefund', function(citizenid, amount, balanceAfter, description)
    MySQL.insert('INSERT INTO bank_transactions (citizenid, type, amount, balance_after, description) VALUES (?, ?, ?, ?, ?)', {
        citizenid, 'refund', amount, balanceAfter, description or 'Refund'
    })
end)

-- ============================================================================
-- GET TRANSACTIONS (for NUI)
-- ============================================================================

RegisterNetEvent('sb_banking:server:getTransactions', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Use card owner's citizenid if at ATM with someone else's card
    local citizenid = Player.PlayerData.citizenid
    if atmSessions and atmSessions[src] then
        citizenid = atmSessions[src].citizenid
    end

    local transactions = MySQL.query.await(
        'SELECT id, type, amount, balance_after, description, created_at FROM bank_transactions WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50',
        {citizenid}
    )

    TriggerClientEvent('sb_banking:client:transactions', src, transactions or {})
end)
