--[[
    Everyday Chaos RP - Banking System (Server)
    Author: Salah Eddine Boussettah

    Handles: Account creation, deposits, withdrawals, transfers, PIN, cards
]]

local SB = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- DATABASE INIT
-- ============================================================================

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bank_accounts` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) UNIQUE NOT NULL,
            `pin` VARCHAR(255) NOT NULL,
            `card_id` VARCHAR(16) NOT NULL,
            `card_locked` TINYINT DEFAULT 0,
            `pin_attempts` INT DEFAULT 0,
            `savings` BIGINT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Add savings column if table already exists without it
    MySQL.query([[
        ALTER TABLE `bank_accounts` ADD COLUMN IF NOT EXISTS `savings` BIGINT DEFAULT 0;
    ]])

    -- Interest tracking columns
    MySQL.query([[
        ALTER TABLE `bank_accounts` ADD COLUMN IF NOT EXISTS `interest_earned` BIGINT DEFAULT 0;
    ]])
    MySQL.query([[
        ALTER TABLE `bank_accounts` ADD COLUMN IF NOT EXISTS `last_interest_date` TIMESTAMP NULL DEFAULT NULL;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bank_transactions` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `type` ENUM('deposit', 'withdraw', 'transfer_in', 'transfer_out', 'account_open', 'card_replace', 'atm_withdraw', 'savings_deposit', 'savings_withdraw', 'card_request') NOT NULL,
            `amount` INT NOT NULL,
            `balance_after` INT NOT NULL,
            `description` VARCHAR(255) DEFAULT NULL,
            `target_citizenid` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_citizenid` (`citizenid`),
            INDEX `idx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Update ENUM if table already exists (add new types including purchases)
    MySQL.query([[
        ALTER TABLE `bank_transactions` MODIFY COLUMN `type` ENUM('deposit', 'withdraw', 'transfer_in', 'transfer_out', 'account_open', 'card_replace', 'atm_withdraw', 'savings_deposit', 'savings_withdraw', 'card_request', 'purchase', 'refund') NOT NULL;
    ]])

    print('[sb_banking] Database tables ready')
end)

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GenerateCardId()
    local card = '4532'  -- Visa-style prefix
    for i = 1, 12 do
        card = card .. tostring(math.random(0, 9))
    end
    return card
end

local function HashPin(pin)
    -- Simple hash for PIN storage (not plaintext)
    local hash = 0
    for i = 1, #pin do
        hash = (hash * 31 + string.byte(pin, i)) % 2147483647
    end
    return tostring(hash)
end

local function GetAccount(citizenid)
    local result = MySQL.single.await('SELECT * FROM bank_accounts WHERE citizenid = ?', {citizenid})
    return result
end

local function ValidateAmount(amount, min, max)
    amount = tonumber(amount)
    if not amount then return nil end
    amount = math.floor(amount)  -- Prevent float exploits
    if amount < (min or 1) then return nil end
    if max and amount > max then return nil end
    return amount
end

local operationLock = {}  -- [source] = true when processing
local atmSessions = {}  -- [source] = { citizenid, cardId, ownerName }

local function AcquireLock(src)
    if operationLock[src] then return false end
    operationLock[src] = true
    return true
end

local function ReleaseLock(src)
    operationLock[src] = nil
end

-- ============================================================================
-- ACCOUNT CREATION
-- ============================================================================

RegisterNetEvent('sb_banking:server:createAccount', function(pin)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Validate PIN
    if not pin or #pin ~= Config.PinLength or not tonumber(pin) then
        SB.Functions.Notify(src, 'PIN must be ' .. Config.PinLength .. ' digits.', 'error', 3000)
        return
    end

    -- Check if already has account
    local existing = GetAccount(citizenid)
    if existing then
        SB.Functions.Notify(src, 'You already have a bank account.', 'error', 3000)
        return
    end

    -- Create account
    local cardId = GenerateCardId()
    local hashedPin = HashPin(pin)

    MySQL.insert.await('INSERT INTO bank_accounts (citizenid, pin, card_id) VALUES (?, ?, ?)', {
        citizenid, hashedPin, cardId
    })

    -- Give starting bonus
    Player.Functions.AddMoney('bank', Config.StartingBonus, 'Account opening bonus')

    -- Give credit card item (required for ATM)
    local ownerName = Player.Functions.GetName()
    exports['sb_inventory']:AddItem(src, 'creditcard', 1, {
        cardId = cardId,
        citizenid = citizenid,
        ownerName = ownerName,
        issued = os.date('%Y-%m-%d')
    })

    -- Log transaction
    local balance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'account_open', Config.StartingBonus, balance, 'Account opened - Welcome bonus')

    SB.Functions.Notify(src, 'Account created! $' .. Config.StartingBonus .. ' welcome bonus deposited.', 'success', 5000)

    -- Send account data back to client
    TriggerClientEvent('sb_banking:client:accountCreated', src, {
        cardId = cardId,
        balance = balance
    })

    print('[sb_banking] Account created for ' .. Player.Functions.GetName() .. ' (Card: ' .. cardId .. ')')
end)

-- ============================================================================
-- CHECK ACCOUNT (on bank/atm open)
-- ============================================================================

RegisterNetEvent('sb_banking:server:getAccountData', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- If ATM session exists, show card owner's account data
    local session = atmSessions[src]
    local citizenid
    local cash = Player.Functions.GetMoney('cash') or 0
    local bank
    local name

    if session then
        -- ATM with card (possibly someone else's)
        citizenid = session.citizenid
        local isOwnCard = (citizenid == Player.PlayerData.citizenid)

        if isOwnCard then
            bank = Player.Functions.GetMoney('bank') or 0
            name = Player.Functions.GetName()
        else
            -- Someone else's card: check if owner is online first for live balance
            local OwnerPlayer = SB.Functions.GetPlayerByCitizenId(citizenid)
            if OwnerPlayer then
                bank = OwnerPlayer.Functions.GetMoney('bank') or 0
                name = OwnerPlayer.Functions.GetName()
            else
                -- Owner offline: get from DB
                local result = MySQL.single.await('SELECT money, charinfo FROM players WHERE citizenid = ?', {citizenid})
                if result then
                    local money = json.decode(result.money)
                    bank = money.bank or 0
                    local charinfo = json.decode(result.charinfo)
                    name = charinfo.firstname .. ' ' .. charinfo.lastname
                else
                    bank = 0
                    name = session.ownerName or 'Unknown'
                end
            end
        end
    else
        -- Bank NPC (always player's own account)
        citizenid = Player.PlayerData.citizenid
        bank = Player.Functions.GetMoney('bank') or 0
        name = Player.Functions.GetName()
    end

    local account = GetAccount(citizenid)
    if not account then
        TriggerClientEvent('sb_banking:client:noAccount', src)
        return
    end

    -- Calculate monthly earnings (projected: savings * rate / 12)
    local savings = account.savings or 0
    local monthlyEarnings = math.floor(savings * Config.SavingsInterestRate / 12)

    -- Get total deposited from savings_deposit transactions
    local totalResult = MySQL.single.await(
        'SELECT COALESCE(SUM(amount), 0) as total FROM bank_transactions WHERE citizenid = ? AND type = ?',
        {citizenid, 'savings_deposit'}
    )
    local totalDeposited = totalResult and totalResult.total or 0

    TriggerClientEvent('sb_banking:client:accountData', src, {
        name = name,
        cash = cash,
        bank = bank,
        savings = savings,
        monthlyEarnings = monthlyEarnings,
        totalDeposited = totalDeposited,
        interestEarned = account.interest_earned or 0,
        cardId = account.card_id,
        cardLocked = account.card_locked == 1,
    })
end)

-- ============================================================================
-- DEPOSIT (Bank only)
-- ============================================================================

RegisterNetEvent('sb_banking:server:deposit', function(amount)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    amount = ValidateAmount(amount, 1, Config.MaxDeposit)
    if not amount then
        SB.Functions.Notify(src, 'Invalid amount. Max deposit: $' .. Config.MaxDeposit, 'error', 3000)
        ReleaseLock(src)
        return
    end

    local cash = Player.Functions.GetMoney('cash')
    if cash < amount then
        SB.Functions.Notify(src, 'Not enough cash.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Verify account exists
    local citizenid = Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then
        SB.Functions.Notify(src, 'You don\'t have a bank account.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Process
    Player.Functions.RemoveMoney('cash', amount, 'Bank deposit')
    Player.Functions.AddMoney('bank', amount, 'Bank deposit')

    local balance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'deposit', amount, balance, 'Cash deposit')

    SB.Functions.Notify(src, 'Deposited $' .. amount, 'success', 3000)
    TriggerClientEvent('sb_banking:client:updateBalance', src, Player.Functions.GetMoney('cash'), balance)
    ReleaseLock(src)
end)

-- ============================================================================
-- WITHDRAW (Bank)
-- ============================================================================

RegisterNetEvent('sb_banking:server:withdraw', function(amount)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    amount = ValidateAmount(amount, 1, Config.MaxWithdraw)
    if not amount then
        SB.Functions.Notify(src, 'Invalid amount. Max withdrawal: $' .. Config.MaxWithdraw, 'error', 3000)
        ReleaseLock(src)
        return
    end

    local bank = Player.Functions.GetMoney('bank')
    if bank < amount then
        SB.Functions.Notify(src, 'Insufficient funds.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then ReleaseLock(src) return end

    Player.Functions.RemoveMoney('bank', amount, 'Bank withdrawal')
    Player.Functions.AddMoney('cash', amount, 'Bank withdrawal')

    local balance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'withdraw', amount, balance, 'Bank withdrawal')

    SB.Functions.Notify(src, 'Withdrew $' .. amount, 'success', 3000)
    TriggerClientEvent('sb_banking:client:updateBalance', src, Player.Functions.GetMoney('cash'), balance)
    ReleaseLock(src)
end)

-- ============================================================================
-- ATM WITHDRAW (requires PIN)
-- ============================================================================

RegisterNetEvent('sb_banking:server:atmWithdraw', function(amount, pin)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    -- Get ATM session (card owner)
    local session = atmSessions[src]
    if not session then
        SB.Functions.Notify(src, 'No card session. Please re-insert card.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    local cardOwnerCid = session.citizenid
    local account = GetAccount(cardOwnerCid)

    if not account then
        SB.Functions.Notify(src, 'No bank account found.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    if account.card_locked == 1 then
        TriggerClientEvent('sb_banking:client:cardLocked', src)
        ReleaseLock(src)
        return
    end

    -- Verify PIN (defense-in-depth)
    if HashPin(pin) ~= account.pin then
        SB.Functions.Notify(src, 'Invalid PIN.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Validate amount
    amount = ValidateAmount(amount, 1, Config.MaxWithdraw)
    if not amount then
        SB.Functions.Notify(src, 'Invalid amount. Max: $' .. Config.MaxWithdraw, 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Get card owner's balance (may be a different player)
    local isOwnCard = (cardOwnerCid == Player.PlayerData.citizenid)
    local ownerBank
    local OwnerPlayer = not isOwnCard and SB.Functions.GetPlayerByCitizenId(cardOwnerCid) or nil

    if isOwnCard then
        ownerBank = Player.Functions.GetMoney('bank')
    elseif OwnerPlayer then
        -- Owner is online: use live in-memory balance
        ownerBank = OwnerPlayer.Functions.GetMoney('bank') or 0
    else
        -- Owner is offline: get from database
        local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', {cardOwnerCid})
        if not result then
            SB.Functions.Notify(src, 'Account error.', 'error', 3000)
            ReleaseLock(src)
            return
        end
        local money = json.decode(result.money)
        ownerBank = money.bank or 0
    end

    if ownerBank < amount then
        SB.Functions.Notify(src, 'Insufficient funds.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Process withdrawal from card owner's account
    if isOwnCard then
        Player.Functions.RemoveMoney('bank', amount, 'ATM withdrawal')
    elseif OwnerPlayer then
        -- Owner is online: only use in-memory (sb_core handles DB sync)
        OwnerPlayer.Functions.RemoveMoney('bank', amount, 'ATM withdrawal (card used by another player)')
    else
        -- Owner is offline: update database directly
        local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', {cardOwnerCid})
        local money = json.decode(result.money)
        money.bank = money.bank - amount
        MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(money), cardOwnerCid})
    end

    -- Give cash to the player using the ATM
    Player.Functions.AddMoney('cash', amount, 'ATM withdrawal')

    local balance = ownerBank - amount
    exports['sb_banking']:AddTransaction(cardOwnerCid, 'atm_withdraw', amount, balance, 'ATM withdrawal')

    SB.Functions.Notify(src, 'Withdrew $' .. amount .. ' from ATM', 'success', 3000)
    TriggerClientEvent('sb_banking:client:atmSuccess', src, amount, balance)
    ReleaseLock(src)
end)

-- ============================================================================
-- ATM DEPOSIT (uses card owner's account)
-- ============================================================================

RegisterNetEvent('sb_banking:server:atmDeposit', function(amount)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    -- Get ATM session (card owner)
    local session = atmSessions[src]
    if not session then
        SB.Functions.Notify(src, 'No card session. Please re-insert card.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    amount = ValidateAmount(amount, 1, Config.MaxDeposit)
    if not amount then
        SB.Functions.Notify(src, 'Invalid amount. Max deposit: $' .. Config.MaxDeposit, 'error', 3000)
        ReleaseLock(src)
        return
    end

    local cash = Player.Functions.GetMoney('cash')
    if cash < amount then
        SB.Functions.Notify(src, 'Not enough cash.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    local cardOwnerCid = session.citizenid
    local isOwnCard = (cardOwnerCid == Player.PlayerData.citizenid)
    local OwnerPlayer = not isOwnCard and SB.Functions.GetPlayerByCitizenId(cardOwnerCid) or nil

    -- Remove cash from player
    Player.Functions.RemoveMoney('cash', amount, 'ATM deposit')

    -- Add to card owner's bank account
    local balance
    if isOwnCard then
        Player.Functions.AddMoney('bank', amount, 'ATM deposit')
        balance = Player.Functions.GetMoney('bank')
    elseif OwnerPlayer then
        -- Owner is online: only use in-memory (sb_core handles DB sync)
        OwnerPlayer.Functions.AddMoney('bank', amount, 'ATM deposit (from another player\'s card)')
        balance = OwnerPlayer.Functions.GetMoney('bank')
    else
        -- Owner is offline: update database directly
        local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', {cardOwnerCid})
        if not result then
            -- Refund on error
            Player.Functions.AddMoney('cash', amount, 'ATM deposit refund')
            SB.Functions.Notify(src, 'Account error.', 'error', 3000)
            ReleaseLock(src)
            return
        end
        local money = json.decode(result.money)
        money.bank = (money.bank or 0) + amount
        balance = money.bank
        MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(money), cardOwnerCid})
    end

    exports['sb_banking']:AddTransaction(cardOwnerCid, 'deposit', amount, balance, 'ATM deposit')

    SB.Functions.Notify(src, 'Deposited $' .. amount, 'success', 3000)
    TriggerClientEvent('sb_banking:client:atmSuccess', src, amount, balance)
    ReleaseLock(src)
end)

-- ============================================================================
-- TRANSFER
-- ============================================================================

RegisterNetEvent('sb_banking:server:transfer', function(targetIdentifier, amount)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    -- Validate target identifier
    if not targetIdentifier or type(targetIdentifier) ~= 'string' or #targetIdentifier < 1 then
        SB.Functions.Notify(src, 'Invalid recipient ID.', 'error', 3000)
        ReleaseLock(src)
        return
    end
    targetIdentifier = targetIdentifier:gsub('[^%w%-_]', '')  -- Sanitize input

    amount = ValidateAmount(amount, Config.MinTransfer, Config.MaxTransfer)
    if not amount then
        SB.Functions.Notify(src, 'Amount must be between $' .. Config.MinTransfer .. ' and $' .. Config.MaxTransfer, 'error', 3000)
        ReleaseLock(src)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Can't transfer to self
    if targetIdentifier == citizenid then
        SB.Functions.Notify(src, 'Cannot transfer to yourself.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    local bank = Player.Functions.GetMoney('bank')
    if bank < amount then
        SB.Functions.Notify(src, 'Insufficient funds.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Check target has an account
    local targetAccount = GetAccount(targetIdentifier)
    if not targetAccount then
        SB.Functions.Notify(src, 'Target does not have a bank account.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Process transfer (sender)
    Player.Functions.RemoveMoney('bank', amount, 'Transfer to ' .. targetIdentifier)
    local senderBalance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'transfer_out', amount, senderBalance, 'Transfer sent', targetIdentifier)

    -- Process transfer (receiver) - might be offline
    local TargetPlayer = SB.Functions.GetPlayerByCitizenId(targetIdentifier)
    if TargetPlayer then
        -- Online
        TargetPlayer.Functions.AddMoney('bank', amount, 'Transfer from ' .. citizenid)
        local targetBalance = TargetPlayer.Functions.GetMoney('bank')
        exports['sb_banking']:AddTransaction(targetIdentifier, 'transfer_in', amount, targetBalance, 'Transfer received', citizenid)
        SB.Functions.Notify(TargetPlayer.PlayerData.source, 'Received $' .. amount .. ' transfer.', 'success', 5000)
    else
        -- Offline - update database directly
        local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', {targetIdentifier})
        if result then
            local money = json.decode(result.money)
            money.bank = (money.bank or 0) + amount
            MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(money), targetIdentifier})
            exports['sb_banking']:AddTransaction(targetIdentifier, 'transfer_in', amount, money.bank, 'Transfer received (offline)', citizenid)
        end
    end

    -- Get target name for notification
    local targetName = targetIdentifier
    local targetInfo = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', {targetIdentifier})
    if targetInfo then
        local charinfo = json.decode(targetInfo.charinfo)
        targetName = charinfo.firstname .. ' ' .. charinfo.lastname
    end

    SB.Functions.Notify(src, 'Transferred $' .. amount .. ' to ' .. targetName, 'success', 5000)
    TriggerClientEvent('sb_banking:client:updateBalance', src, Player.Functions.GetMoney('cash'), senderBalance)
    ReleaseLock(src)
end)

-- ============================================================================
-- PIN MANAGEMENT
-- ============================================================================

RegisterNetEvent('sb_banking:server:resetPin', function(newPin)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    if not newPin or #newPin ~= Config.PinLength or not tonumber(newPin) then
        SB.Functions.Notify(src, 'PIN must be ' .. Config.PinLength .. ' digits.', 'error', 3000)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local hashedPin = HashPin(newPin)

    MySQL.update('UPDATE bank_accounts SET pin = ?, pin_attempts = 0, card_locked = 0 WHERE citizenid = ?', {
        hashedPin, citizenid
    })

    SB.Functions.Notify(src, 'PIN updated successfully.', 'success', 3000)
end)

-- ============================================================================
-- CARD MANAGEMENT
-- ============================================================================

RegisterNetEvent('sb_banking:server:unlockCard', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    MySQL.update('UPDATE bank_accounts SET card_locked = 0, pin_attempts = 0 WHERE citizenid = ?', {citizenid})

    SB.Functions.Notify(src, 'Card unlocked.', 'success', 3000)
end)

RegisterNetEvent('sb_banking:server:replaceCard', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then return end

    local cash = Player.Functions.GetMoney('cash')
    local bank = Player.Functions.GetMoney('bank')

    if (cash + bank) < Config.CardReplaceFee then
        SB.Functions.Notify(src, 'Card replacement costs $' .. Config.CardReplaceFee, 'error', 3000)
        return
    end

    -- Charge fee (cash first, then bank)
    if cash >= Config.CardReplaceFee then
        Player.Functions.RemoveMoney('cash', Config.CardReplaceFee, 'Card replacement')
    else
        if cash > 0 then
            Player.Functions.RemoveMoney('cash', cash, 'Card replacement')
        end
        local remainder = Config.CardReplaceFee - cash
        Player.Functions.RemoveMoney('bank', remainder, 'Card replacement')
    end

    -- Remove old card from inventory
    exports['sb_inventory']:RemoveItem(src, 'creditcard', 1)

    -- Generate new card
    local newCardId = GenerateCardId()
    MySQL.update('UPDATE bank_accounts SET card_id = ?, card_locked = 0, pin_attempts = 0 WHERE citizenid = ?', {
        newCardId, citizenid
    })

    -- Give new card
    local ownerName = Player.Functions.GetName()
    exports['sb_inventory']:AddItem(src, 'creditcard', 1, {
        cardId = newCardId,
        citizenid = citizenid,
        ownerName = ownerName,
        issued = os.date('%Y-%m-%d')
    })

    local balance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'card_replace', Config.CardReplaceFee, balance, 'Card replaced')

    SB.Functions.Notify(src, 'New card issued. Fee: $' .. Config.CardReplaceFee, 'success', 5000)
end)

-- ============================================================================
-- SAVINGS
-- ============================================================================

RegisterNetEvent('sb_banking:server:savingsDeposit', function(amount)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    amount = ValidateAmount(amount, 1, Config.MaxSavingsDeposit)
    if not amount then
        SB.Functions.Notify(src, 'Invalid amount. Max: $' .. Config.MaxSavingsDeposit, 'error', 3000)
        ReleaseLock(src)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then
        SB.Functions.Notify(src, 'No bank account found.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    local bank = Player.Functions.GetMoney('bank')
    if bank < amount then
        SB.Functions.Notify(src, 'Insufficient bank funds.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Process: remove from bank, add to savings
    Player.Functions.RemoveMoney('bank', amount, 'Savings deposit')
    local newSavings = (account.savings or 0) + amount
    MySQL.update('UPDATE bank_accounts SET savings = ? WHERE citizenid = ?', {newSavings, citizenid})

    local bankBalance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'savings_deposit', amount, bankBalance, 'Deposit to savings')

    local monthlyEarnings = math.floor(newSavings * Config.SavingsInterestRate / 12)
    local totalResult = MySQL.single.await(
        'SELECT COALESCE(SUM(amount), 0) as total FROM bank_transactions WHERE citizenid = ? AND type = ?',
        {citizenid, 'savings_deposit'}
    )
    local totalDeposited = totalResult and totalResult.total or 0

    SB.Functions.Notify(src, 'Deposited $' .. amount .. ' to savings.', 'success', 3000)
    TriggerClientEvent('sb_banking:client:updateBalance', src, Player.Functions.GetMoney('cash'), bankBalance)
    TriggerClientEvent('sb_banking:client:updateSavings', src, {
        savings = newSavings,
        monthlyEarnings = monthlyEarnings,
        totalDeposited = totalDeposited,
    })
    ReleaseLock(src)
end)

RegisterNetEvent('sb_banking:server:savingsWithdraw', function(amount)
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    amount = ValidateAmount(amount, 1, Config.MaxSavingsWithdraw)
    if not amount then
        SB.Functions.Notify(src, 'Invalid amount. Max: $' .. Config.MaxSavingsWithdraw, 'error', 3000)
        ReleaseLock(src)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then
        SB.Functions.Notify(src, 'No bank account found.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    local savings = account.savings or 0
    if savings < amount then
        SB.Functions.Notify(src, 'Insufficient savings balance.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Process: remove from savings, add to bank
    local newSavings = savings - amount
    MySQL.update('UPDATE bank_accounts SET savings = ? WHERE citizenid = ?', {newSavings, citizenid})
    Player.Functions.AddMoney('bank', amount, 'Savings withdrawal')

    local bankBalance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'savings_withdraw', amount, bankBalance, 'Withdraw from savings')

    local monthlyEarnings = math.floor(newSavings * Config.SavingsInterestRate / 12)
    local totalResult = MySQL.single.await(
        'SELECT COALESCE(SUM(amount), 0) as total FROM bank_transactions WHERE citizenid = ? AND type = ?',
        {citizenid, 'savings_deposit'}
    )
    local totalDeposited = totalResult and totalResult.total or 0

    SB.Functions.Notify(src, 'Withdrew $' .. amount .. ' from savings.', 'success', 3000)
    TriggerClientEvent('sb_banking:client:updateBalance', src, Player.Functions.GetMoney('cash'), bankBalance)
    TriggerClientEvent('sb_banking:client:updateSavings', src, {
        savings = newSavings,
        monthlyEarnings = monthlyEarnings,
        totalDeposited = totalDeposited,
    })
    ReleaseLock(src)
end)

-- ============================================================================
-- REQUEST CARD (Settings)
-- ============================================================================

RegisterNetEvent('sb_banking:server:requestCard', function()
    local src = source
    if not AcquireLock(src) then return end

    local Player = SB.Functions.GetPlayer(src)
    if not Player then ReleaseLock(src) return end

    local citizenid = Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then
        SB.Functions.Notify(src, 'No bank account found.', 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Check funds (bank balance)
    local bank = Player.Functions.GetMoney('bank')
    if bank < Config.CardRequestFee then
        SB.Functions.Notify(src, 'Insufficient funds. Card costs $' .. Config.CardRequestFee, 'error', 3000)
        ReleaseLock(src)
        return
    end

    -- Charge fee from bank
    Player.Functions.RemoveMoney('bank', Config.CardRequestFee, 'Card request fee')

    -- Generate new card ID
    local newCardId = GenerateCardId()
    MySQL.update('UPDATE bank_accounts SET card_id = ?, card_locked = 0, pin_attempts = 0 WHERE citizenid = ?', {
        newCardId, citizenid
    })

    -- Give card item
    local ownerName = Player.Functions.GetName()
    exports['sb_inventory']:AddItem(src, 'creditcard', 1, {
        cardId = newCardId,
        citizenid = citizenid,
        ownerName = ownerName,
        issued = os.date('%Y-%m-%d')
    })

    local bankBalance = Player.Functions.GetMoney('bank')
    exports['sb_banking']:AddTransaction(citizenid, 'card_request', Config.CardRequestFee, bankBalance, 'New card requested')

    SB.Functions.Notify(src, 'New card issued! Fee: $' .. Config.CardRequestFee, 'success', 5000)
    TriggerClientEvent('sb_banking:client:updateBalance', src, Player.Functions.GetMoney('cash'), bankBalance)
    TriggerClientEvent('sb_banking:client:cardIssued', src, newCardId)
    ReleaseLock(src)
end)

-- ============================================================================
-- ATM PIN VERIFY (separate from withdraw)
-- ============================================================================

RegisterNetEvent('sb_banking:server:verifyPin', function(pin)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Use ATM session (card owner's citizenid) if available, otherwise player's own
    local session = atmSessions[src]
    local citizenid = session and session.citizenid or Player.PlayerData.citizenid
    local account = GetAccount(citizenid)
    if not account then return end

    if account.card_locked == 1 then
        TriggerClientEvent('sb_banking:client:cardLocked', src)
        return
    end

    if HashPin(pin) ~= account.pin then
        local attempts = account.pin_attempts + 1
        MySQL.update('UPDATE bank_accounts SET pin_attempts = ? WHERE citizenid = ?', {attempts, citizenid})

        if attempts >= Config.MaxPinAttempts then
            MySQL.update('UPDATE bank_accounts SET card_locked = 1 WHERE citizenid = ?', {citizenid})
            TriggerClientEvent('sb_banking:client:cardLocked', src)
        else
            local remaining = Config.MaxPinAttempts - attempts
            TriggerClientEvent('sb_banking:client:wrongPin', src, remaining)
        end
        return
    end

    -- PIN correct, reset attempts
    if account.pin_attempts > 0 then
        MySQL.update('UPDATE bank_accounts SET pin_attempts = 0 WHERE citizenid = ?', {citizenid})
    end

    TriggerClientEvent('sb_banking:client:pinVerified', src)
end)

-- ============================================================================
-- CARD CHECK (ATM access)
-- ============================================================================

RegisterNetEvent('sb_banking:server:checkCard', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    -- Get all credit cards the player has
    local cards = exports['sb_inventory']:GetItemsByName(src, 'creditcard')
    if not cards or #cards == 0 then
        TriggerClientEvent('sb_banking:client:cardCheckResult', src, false)
        return
    end

    -- Use the first card found
    local card = cards[1]
    local meta = card.metadata or {}
    local playerCid = Player.PlayerData.citizenid

    -- Support legacy cards without full metadata (assume player's own card)
    local cardOwnerCitizenId = meta.citizenid or playerCid
    local cardId = meta.cardId or 'legacy'
    local ownerName = meta.ownerName or Player.Functions.GetName()

    -- Verify the card owner has an account
    local account = GetAccount(cardOwnerCitizenId)
    if not account then
        TriggerClientEvent('sb_banking:client:cardCheckResult', src, false)
        return
    end

    -- Store ATM session (tracks whose card is being used)
    atmSessions[src] = {
        citizenid = cardOwnerCitizenId,
        cardId = cardId,
        ownerName = ownerName
    }

    TriggerClientEvent('sb_banking:client:cardCheckResult', src, true)
end)

-- ============================================================================
-- SAVINGS INTEREST PAYOUT
-- ============================================================================

CreateThread(function()
    -- Wait for DB to be ready
    Wait(10000)

    while true do
        Wait(Config.InterestPayoutInterval * 60 * 1000)  -- Convert minutes to ms

        local accounts = MySQL.query.await(
            'SELECT citizenid, savings, interest_earned FROM bank_accounts WHERE savings > 0'
        )

        if accounts and #accounts > 0 then
            local paid = 0

            for _, acc in ipairs(accounts) do
                if acc.savings > 0 then
                    -- RP-friendly: each cycle pays monthly interest (rate / 12)
                    -- e.g., $1,000 at 2.5% → $2 per cycle
                    local interest = math.floor(acc.savings * Config.SavingsInterestRate / 12)

                    if interest > 0 then
                        local newSavings = acc.savings + interest
                        local newInterestEarned = (acc.interest_earned or 0) + interest

                        MySQL.update(
                            'UPDATE bank_accounts SET savings = ?, interest_earned = ?, last_interest_date = NOW() WHERE citizenid = ?',
                            {newSavings, newInterestEarned, acc.citizenid}
                        )

                        paid = paid + 1
                    end
                end
            end

            if paid > 0 then
                print('[sb_banking] Paid interest to ' .. paid .. ' savings accounts')
            end
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('HasAccount', function(citizenid)
    local account = GetAccount(citizenid)
    return account ~= nil
end)

exports('GetBalance', function(citizenid)
    local result = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', {citizenid})
    if result then
        local money = json.decode(result.money)
        return money.bank or 0
    end
    return 0
end)

-- Clear ATM session when bank/atm is closed
RegisterNetEvent('sb_banking:server:closeATM', function()
    atmSessions[source] = nil
end)

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    operationLock[source] = nil
    atmSessions[source] = nil
end)
