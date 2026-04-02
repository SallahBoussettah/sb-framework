-- sb_companies | Server Economy
-- Miners selling raw materials to companies, employee state sync

local SB = SBCompanies.SB

-- ===================================================================
-- OPERATION LOCK (prevent double-sell exploits)
-- ===================================================================

local operationLock = {}

local function AcquireLock(src)
    if operationLock[src] then return false end
    operationLock[src] = true
    return true
end

local function ReleaseLock(src)
    operationLock[src] = nil
end

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    operationLock[source] = nil
end)

-- ===================================================================
-- CALLBACK: Miner Sells Raw Materials to a Company
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:sellRawMaterials', function(source, cb, companyId, itemName, quantity)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb({ success = false, message = 'Player not found' }) end

    -- Acquire lock to prevent double-sell
    if not AcquireLock(src) then
        return cb({ success = false, message = 'Transaction in progress...' })
    end

    -- Validate parameter types
    if type(companyId) ~= 'string' or type(itemName) ~= 'string' then
        ReleaseLock(src)
        return cb({ success = false, message = 'Invalid parameters' })
    end

    quantity = tonumber(quantity)
    if not quantity or quantity <= 0 then
        ReleaseLock(src)
        return cb({ success = false, message = 'Invalid quantity' })
    end
    quantity = math.floor(quantity) -- Prevent float exploits

    -- Validate company exists
    local companyCfg = Config.CompanyById[companyId]
    if not companyCfg then
        ReleaseLock(src)
        return cb({ success = false, message = 'Company not found' })
    end

    -- Validate item is in this company's buysMaterials list
    local acceptsItem = false
    for _, mat in ipairs(companyCfg.buysMaterials) do
        if mat == itemName then
            acceptsItem = true
            break
        end
    end

    if not acceptsItem then
        ReleaseLock(src)
        return cb({ success = false, message = 'This company does not buy ' .. itemName })
    end

    -- Validate item has a price
    local unitPrice = Config.RawMaterialPrices[itemName]
    if not unitPrice then
        ReleaseLock(src)
        return cb({ success = false, message = 'No price set for this material' })
    end

    local totalPrice = unitPrice * quantity

    -- Check player actually has the items in inventory
    local playerCount = exports['sb_inventory']:GetItemCount(src, itemName)
    if not playerCount or playerCount < quantity then
        ReleaseLock(src)
        return cb({ success = false, message = 'You don\'t have enough ' .. itemName })
    end

    -- Check company has enough funds to pay
    local company = SBCompanies.Companies[companyId]
    if not company then
        ReleaseLock(src)
        return cb({ success = false, message = 'Company data not found' })
    end

    if company.balance < totalPrice then
        ReleaseLock(src)
        return cb({ success = false, message = 'Company cannot afford this purchase ($' .. totalPrice .. ')' })
    end

    -- All validated. Execute the transaction:
    -- 1. Remove items from player inventory
    local removed = exports['sb_inventory']:RemoveItem(src, itemName, quantity)
    if not removed then
        ReleaseLock(src)
        return cb({ success = false, message = 'Failed to remove items from inventory' })
    end

    -- 2. Add items to company stock
    ModifyCompanyStock(companyId, itemName, quantity)

    -- 3. Deduct cost from company balance
    ModifyCompanyBalance(companyId, -totalPrice, Enums.TransactionType.RAW_PURCHASE,
        quantity .. 'x ' .. itemName .. ' purchased from miner')

    -- 4. Pay the player (bank deposit)
    Player.Functions.AddMoney('bank', totalPrice, 'Raw material sale to ' .. companyCfg.label)

    -- Log
    local citizenid = Player.PlayerData.citizenid
    local playerName = Player.Functions.GetName()
    print(('[sb_companies] %s (%s) sold %dx %s to %s for $%d'):format(
        playerName, citizenid, quantity, itemName, companyId, totalPrice
    ))

    ReleaseLock(src)
    cb({
        success = true,
        message = 'Sold ' .. quantity .. 'x ' .. itemName .. ' for $' .. totalPrice,
        totalPaid = totalPrice,
    })
end)

-- ===================================================================
-- EVENT: Employee State Request
-- Client requests their employment data on spawn / company UI open
-- ===================================================================

RegisterNetEvent('sb_companies:requestEmployeeState', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local empData = GetEmployeeData(citizenid)

    -- Also check if owner of any company
    local isOwner = false
    local ownerCompanyId = nil
    for companyId, company in pairs(SBCompanies.Companies) do
        if company.owner_citizenid == citizenid then
            isOwner = true
            ownerCompanyId = companyId
            break
        end
    end

    if empData then
        TriggerClientEvent('sb_companies:setEmployeeState', src, {
            company_id = empData.company_id,
            role = empData.role,
            is_owner = isOwner,
        })
    elseif isOwner then
        TriggerClientEvent('sb_companies:setEmployeeState', src, {
            company_id = ownerCompanyId,
            role = 'manager',
            is_owner = true,
        })
    else
        TriggerClientEvent('sb_companies:setEmployeeState', src, nil)
    end
end)
