-- sb_companies | Server Management
-- Owner/manager dashboard: company data, pricing, hiring, firing, funds

local SB = SBCompanies.SB

-- ===================================================================
-- HELPERS
-- ===================================================================

--- Check if a citizenid is owner or manager of a company
--- @return boolean
local function IsOwnerOrManager(citizenid, companyId)
    -- Check owner first
    if IsCompanyOwner(citizenid, companyId) then return true end

    -- Check manager role
    local empData = GetEmployeeData(citizenid)
    if empData and empData.company_id == companyId and empData.role == Enums.Role.MANAGER then
        return true
    end

    return false
end

--- Get full name from charinfo
local function GetPlayerFullName(Player)
    local charinfo = Player.PlayerData.charinfo
    if charinfo then
        return (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    end
    return 'Unknown'
end

-- ===================================================================
-- CALLBACK: Get Company Dashboard Data
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:getCompanyData', function(source, cb, companyId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(nil) end

    -- Validate parameter type
    if type(companyId) ~= 'string' then return cb(nil) end

    local citizenid = Player.PlayerData.citizenid

    -- Must be owner or manager
    if not IsOwnerOrManager(citizenid, companyId) then
        SB.Functions.Notify(src, 'You do not have management access', 'error', 3000)
        return cb(nil)
    end

    local company = SBCompanies.Companies[companyId]
    if not company then return cb(nil) end

    -- Build company info
    local companyInfo = {
        id = company.id,
        label = company.label,
        type = company.type,
        balance = company.balance,
        owner_citizenid = company.owner_citizenid,
    }

    -- Get owner name
    local ownerName = 'NPC Owned'
    if company.owner_citizenid then
        local ownerResult = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { company.owner_citizenid })
        if ownerResult then
            local charinfo = json.decode(ownerResult.charinfo)
            ownerName = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        end
    end
    companyInfo.owner_name = ownerName

    -- Build employees list
    local employees = {}
    local empRows = MySQL.query.await('SELECT ce.*, p.charinfo FROM company_employees ce LEFT JOIN players p ON ce.citizenid = p.citizenid WHERE ce.company_id = ?', { companyId })
    if empRows then
        for _, row in ipairs(empRows) do
            local empName = 'Unknown'
            if row.charinfo then
                local charinfo = json.decode(row.charinfo)
                empName = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
            end

            -- Check if online
            local isOnline = SB.Functions.GetPlayerByCitizenId(row.citizenid) ~= nil

            table.insert(employees, {
                citizenid = row.citizenid,
                name = empName,
                role = row.role,
                hired_at = row.hired_at,
                online = isOnline,
            })
        end
    end

    -- Build stock summary
    local stock = {}
    local stockData = SBCompanies.Stock[companyId]
    if stockData then
        for itemName, qty in pairs(stockData) do
            if qty > 0 then
                table.insert(stock, { item_name = itemName, quantity = qty })
            end
        end
    end

    -- Recent transactions (last 20)
    local transactions = MySQL.query.await(
        'SELECT * FROM company_transactions WHERE company_id = ? ORDER BY created_at DESC LIMIT 20',
        { companyId }
    )

    -- Catalog with prices
    local catalog = {}
    local catalogData = SBCompanies.CatalogPrices[companyId]
    if catalogData then
        for itemName, priceData in pairs(catalogData) do
            table.insert(catalog, {
                item_name = itemName,
                base_price = priceData.base_price,
                current_price = priceData.current_price,
            })
        end
    end

    cb({
        company = companyInfo,
        employees = employees,
        stock = stock,
        transactions = transactions or {},
        catalog = catalog,
    })
end)

-- ===================================================================
-- CALLBACK: Adjust Catalog Item Price
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:adjustPrice', function(source, cb, companyId, itemName, newPrice)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    -- Validate parameter types
    if type(companyId) ~= 'string' or type(itemName) ~= 'string' then return cb(false) end

    newPrice = tonumber(newPrice)
    if not newPrice or newPrice <= 0 then
        SB.Functions.Notify(src, 'Invalid price', 'error', 3000)
        return cb(false)
    end
    newPrice = math.floor(newPrice) -- Force integer

    local citizenid = Player.PlayerData.citizenid

    -- Must be owner or manager
    if not IsOwnerOrManager(citizenid, companyId) then
        SB.Functions.Notify(src, 'You do not have management access', 'error', 3000)
        return cb(false)
    end

    -- Validate item exists in this company's catalog
    local catalogData = SBCompanies.CatalogPrices[companyId]
    if not catalogData or not catalogData[itemName] then
        SB.Functions.Notify(src, 'Item not found in catalog', 'error', 3000)
        return cb(false)
    end

    local basePrice = catalogData[itemName].base_price

    -- Price must be between 50% and 200% of base_price
    local minPrice = math.floor(basePrice * 0.50)
    local maxPrice = math.floor(basePrice * 2.00)

    if newPrice < minPrice or newPrice > maxPrice then
        SB.Functions.Notify(src, 'Price must be between $' .. minPrice .. ' and $' .. maxPrice, 'error', 4000)
        return cb(false)
    end

    -- Update in-memory
    catalogData[itemName].current_price = newPrice

    -- Update database
    MySQL.query('UPDATE company_catalog SET current_price = ? WHERE company_id = ? AND item_name = ?',
        { newPrice, companyId, itemName })

    -- Also update shared Catalog.CompanyItems if present
    if Catalog.CompanyItems[companyId] then
        for _, entry in ipairs(Catalog.CompanyItems[companyId]) do
            if entry.item_name == itemName then
                entry.current_price = newPrice
                break
            end
        end
    end

    SB.Functions.Notify(src, 'Price updated to $' .. newPrice, 'success', 3000)

    if Config.Debug then
        print(('[sb_companies] %s adjusted %s price to $%d for %s'):format(
            Player.Functions.GetName(), itemName, newPrice, companyId))
    end

    cb(true)
end)

-- ===================================================================
-- CALLBACK: Hire Employee
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:hireEmployee', function(source, cb, companyId, targetCitizenId, role)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    -- Validate parameter types
    if type(companyId) ~= 'string' or type(targetCitizenId) ~= 'string' or type(role) ~= 'string' then
        return cb(false)
    end

    -- Validate role
    if not Config.Roles[role] then
        SB.Functions.Notify(src, 'Invalid role', 'error', 3000)
        return cb(false)
    end

    local citizenid = Player.PlayerData.citizenid

    -- Must be owner or manager
    if not IsOwnerOrManager(citizenid, companyId) then
        SB.Functions.Notify(src, 'You do not have management access', 'error', 3000)
        return cb(false)
    end

    -- Validate company exists
    if not SBCompanies.Companies[companyId] then
        SB.Functions.Notify(src, 'Company not found', 'error', 3000)
        return cb(false)
    end

    -- Check target is not already employed at another company
    local existingEmp = GetEmployeeData(targetCitizenId)
    if existingEmp then
        SB.Functions.Notify(src, 'This person is already employed at another company', 'error', 4000)
        return cb(false)
    end

    -- Check target citizen exists in the database
    local targetExists = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ?', { targetCitizenId })
    if not targetExists then
        SB.Functions.Notify(src, 'Citizen not found', 'error', 3000)
        return cb(false)
    end

    -- Insert into database
    MySQL.insert.await(
        'INSERT INTO company_employees (company_id, citizenid, role) VALUES (?, ?, ?)',
        { companyId, targetCitizenId, role }
    )

    -- Update in-memory
    SBCompanies.Employees[targetCitizenId] = {
        company_id = companyId,
        role = role,
    }

    -- Get target name for notification
    local targetName = 'Unknown'
    if targetExists.charinfo then
        local charinfo = json.decode(targetExists.charinfo)
        targetName = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    end

    SB.Functions.Notify(src, 'Hired ' .. targetName .. ' as ' .. Config.Roles[role].label, 'success', 4000)

    -- If target is online, notify them and update their employee state
    local TargetPlayer = SB.Functions.GetPlayerByCitizenId(targetCitizenId)
    if TargetPlayer then
        local targetSrc = TargetPlayer.PlayerData.source
        SB.Functions.Notify(targetSrc, 'You have been hired at ' .. SBCompanies.Companies[companyId].label .. ' as ' .. Config.Roles[role].label, 'success', 5000)
        TriggerClientEvent('sb_companies:setEmployeeState', targetSrc, {
            company_id = companyId,
            role = role,
            is_owner = false,
        })
    end

    print(('[sb_companies] %s hired %s (%s) as %s at %s'):format(
        Player.Functions.GetName(), targetName, targetCitizenId, role, companyId))

    cb(true)
end)

-- ===================================================================
-- CALLBACK: Fire Employee
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:fireEmployee', function(source, cb, companyId, targetCitizenId)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    -- Validate parameter types
    if type(companyId) ~= 'string' or type(targetCitizenId) ~= 'string' then return cb(false) end

    local citizenid = Player.PlayerData.citizenid

    -- Must be owner or manager
    if not IsOwnerOrManager(citizenid, companyId) then
        SB.Functions.Notify(src, 'You do not have management access', 'error', 3000)
        return cb(false)
    end

    -- Verify target is actually employed at this company
    local empData = GetEmployeeData(targetCitizenId)
    if not empData or empData.company_id ~= companyId then
        SB.Functions.Notify(src, 'This person is not employed at this company', 'error', 3000)
        return cb(false)
    end

    -- Cannot fire yourself
    if targetCitizenId == citizenid then
        SB.Functions.Notify(src, 'You cannot fire yourself', 'error', 3000)
        return cb(false)
    end

    -- Delete from database
    MySQL.query.await('DELETE FROM company_employees WHERE company_id = ? AND citizenid = ?',
        { companyId, targetCitizenId })

    -- Remove from in-memory
    SBCompanies.Employees[targetCitizenId] = nil

    SB.Functions.Notify(src, 'Employee has been terminated', 'success', 3000)

    -- If target is online, notify them and clear their employee state
    local TargetPlayer = SB.Functions.GetPlayerByCitizenId(targetCitizenId)
    if TargetPlayer then
        local targetSrc = TargetPlayer.PlayerData.source
        SB.Functions.Notify(targetSrc, 'You have been terminated from ' .. SBCompanies.Companies[companyId].label, 'error', 5000)
        TriggerClientEvent('sb_companies:setEmployeeState', targetSrc, nil)
    end

    print(('[sb_companies] %s fired %s from %s'):format(
        Player.Functions.GetName(), targetCitizenId, companyId))

    cb(true)
end)

-- ===================================================================
-- CALLBACK: Owner Withdraw Funds
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:withdrawFunds', function(source, cb, companyId, amount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    -- Validate parameter types
    if type(companyId) ~= 'string' then return cb(false) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        SB.Functions.Notify(src, 'Invalid amount', 'error', 3000)
        return cb(false)
    end
    amount = math.floor(amount) -- Force integer

    local citizenid = Player.PlayerData.citizenid

    -- Must be owner (not just manager)
    if not IsCompanyOwner(citizenid, companyId) then
        SB.Functions.Notify(src, 'Only the owner can withdraw funds', 'error', 3000)
        return cb(false)
    end

    local company = SBCompanies.Companies[companyId]
    if not company then return cb(false) end

    -- Enforce minimum balance of $10,000
    local minBalance = 10000
    local maxWithdraw = company.balance - minBalance

    if maxWithdraw <= 0 then
        SB.Functions.Notify(src, 'Company balance is at minimum ($' .. minBalance .. ')', 'error', 4000)
        return cb(false)
    end

    if amount > maxWithdraw then
        SB.Functions.Notify(src, 'Maximum withdrawal: $' .. maxWithdraw .. ' (min balance: $' .. minBalance .. ')', 'error', 4000)
        return cb(false)
    end

    -- Deduct from company
    ModifyCompanyBalance(companyId, -amount, Enums.TransactionType.OWNER_WITHDRAW,
        'Owner withdrawal by ' .. Player.Functions.GetName())

    -- Pay the owner
    Player.Functions.AddMoney('bank', amount, 'Company withdrawal from ' .. company.label)

    SB.Functions.Notify(src, 'Withdrew $' .. amount .. ' from ' .. company.label, 'success', 4000)

    print(('[sb_companies] Owner %s withdrew $%d from %s (balance: $%d)'):format(
        Player.Functions.GetName(), amount, companyId, company.balance))

    cb(true)
end)

-- ===================================================================
-- CALLBACK: Owner Deposit Funds
-- ===================================================================

SB.Functions.CreateCallback('sb_companies:depositFunds', function(source, cb, companyId, amount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    -- Validate parameter types
    if type(companyId) ~= 'string' then return cb(false) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        SB.Functions.Notify(src, 'Invalid amount', 'error', 3000)
        return cb(false)
    end
    amount = math.floor(amount) -- Force integer

    local citizenid = Player.PlayerData.citizenid

    -- Must be owner (not just manager)
    if not IsCompanyOwner(citizenid, companyId) then
        SB.Functions.Notify(src, 'Only the owner can deposit funds', 'error', 3000)
        return cb(false)
    end

    -- Check player has enough money in bank
    local bank = Player.Functions.GetMoney('bank')
    if bank < amount then
        SB.Functions.Notify(src, 'Insufficient bank funds', 'error', 3000)
        return cb(false)
    end

    -- Remove from player
    Player.Functions.RemoveMoney('bank', amount, 'Company deposit to ' .. SBCompanies.Companies[companyId].label)

    -- Add to company
    ModifyCompanyBalance(companyId, amount, Enums.TransactionType.OWNER_DEPOSIT,
        'Owner deposit by ' .. Player.Functions.GetName())

    local company = SBCompanies.Companies[companyId]
    SB.Functions.Notify(src, 'Deposited $' .. amount .. ' to ' .. company.label, 'success', 4000)

    print(('[sb_companies] Owner %s deposited $%d to %s (balance: $%d)'):format(
        Player.Functions.GetName(), amount, companyId, company.balance))

    cb(true)
end)
