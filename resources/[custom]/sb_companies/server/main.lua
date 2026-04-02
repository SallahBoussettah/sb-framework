-- sb_companies | Server Main
-- Table creation, state init, catalog loading, save loops, exports

local SB = exports['sb_core']:GetCoreObject()

-- Global server state
SBCompanies = {
    SB = SB,
    Companies = {},      -- { [companyId] = { id, label, owner, balance, ... } }
    Employees = {},      -- { [citizenid] = { company_id, role } }
    Stock = {},          -- { [companyId] = { [itemName] = quantity } }
    CatalogPrices = {},  -- { [companyId] = { [itemName] = { base_price, current_price } } }
    ShopStorage = {},    -- { [shopId] = { [itemName..quality] = { item_name, quantity, quality } } }
}

-- ===================================================================
-- DATABASE TABLE CREATION
-- ===================================================================
CreateThread(function()
    -- Tables are created via install.sql, but ensure they exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `companies` (
            `id` VARCHAR(50) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `type` VARCHAR(50) NOT NULL DEFAULT 'manufacturing',
            `owner_citizenid` VARCHAR(50) DEFAULT NULL,
            `balance` INT NOT NULL DEFAULT 50000,
            `purchase_price` INT NOT NULL DEFAULT 500000,
            `tax_rate` FLOAT NOT NULL DEFAULT 0.05,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `company_employees` (
            `id` INT AUTO_INCREMENT,
            `company_id` VARCHAR(50) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `role` ENUM('worker','driver','manager') NOT NULL DEFAULT 'worker',
            `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_company_citizen` (`company_id`, `citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `company_stock` (
            `id` INT AUTO_INCREMENT,
            `company_id` VARCHAR(50) NOT NULL,
            `item_name` VARCHAR(100) NOT NULL,
            `quantity` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_company_item` (`company_id`, `item_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `company_catalog` (
            `id` INT AUTO_INCREMENT,
            `company_id` VARCHAR(50) NOT NULL,
            `item_name` VARCHAR(100) NOT NULL,
            `base_price` INT NOT NULL DEFAULT 100,
            `current_price` INT NOT NULL DEFAULT 100,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_catalog_item` (`company_id`, `item_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `orders` (
            `id` INT AUTO_INCREMENT,
            `shop_id` VARCHAR(50) NOT NULL,
            `company_id` VARCHAR(50) NOT NULL,
            `ordered_by` VARCHAR(50) NOT NULL,
            `status` ENUM('pending','processing','ready','in_transit','delivered','cancelled') NOT NULL DEFAULT 'pending',
            `total_cost` INT NOT NULL DEFAULT 0,
            `payment_source` VARCHAR(20) NOT NULL DEFAULT 'bank',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `order_items` (
            `id` INT AUTO_INCREMENT,
            `order_id` INT NOT NULL,
            `item_name` VARCHAR(100) NOT NULL,
            `quantity` INT NOT NULL DEFAULT 1,
            `unit_price` INT NOT NULL DEFAULT 0,
            `quality` VARCHAR(20) NOT NULL DEFAULT 'standard',
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `delivery_queue` (
            `id` INT AUTO_INCREMENT,
            `order_id` INT NOT NULL,
            `status` ENUM('waiting','claimed','in_transit','completed','npc_dispatched') NOT NULL DEFAULT 'waiting',
            `claimed_by` VARCHAR(50) DEFAULT NULL,
            `claimed_at` TIMESTAMP NULL DEFAULT NULL,
            `completed_at` TIMESTAMP NULL DEFAULT NULL,
            `npc_arrive_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_delivery_order` (`order_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `shop_storage` (
            `id` INT AUTO_INCREMENT,
            `shop_id` VARCHAR(50) NOT NULL,
            `item_name` VARCHAR(100) NOT NULL,
            `quantity` INT NOT NULL DEFAULT 0,
            `quality` VARCHAR(20) NOT NULL DEFAULT 'standard',
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_shop_item_quality` (`shop_id`, `item_name`, `quality`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `company_transactions` (
            `id` INT AUTO_INCREMENT,
            `company_id` VARCHAR(50) NOT NULL,
            `type` ENUM('sale','purchase','salary','delivery_fee','raw_purchase','tax','owner_withdraw','owner_deposit') NOT NULL,
            `amount` INT NOT NULL DEFAULT 0,
            `description` VARCHAR(255) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mining_nodes` (
            `id` INT AUTO_INCREMENT,
            `node_id` VARCHAR(50) NOT NULL,
            `depleted_at` TIMESTAMP NULL DEFAULT NULL,
            `respawn_minutes` INT NOT NULL DEFAULT 10,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uk_node` (`node_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Wait a tick for tables to be created
    Wait(500)

    -- Load all data into memory
    LoadCompanies()
    LoadEmployees()
    LoadStock()
    LoadCatalog()
    LoadShopStorage()

    print('^2[sb_companies]^7 Server initialized - ' .. #Config.Companies .. ' companies loaded')
end)

-- ===================================================================
-- DATA LOADING
-- ===================================================================

function LoadCompanies()
    local rows = MySQL.query.await('SELECT * FROM companies')
    SBCompanies.Companies = {}
    for _, row in ipairs(rows or {}) do
        SBCompanies.Companies[row.id] = row
    end
end

function LoadEmployees()
    local rows = MySQL.query.await('SELECT * FROM company_employees')
    SBCompanies.Employees = {}
    for _, row in ipairs(rows or {}) do
        SBCompanies.Employees[row.citizenid] = {
            company_id = row.company_id,
            role = row.role,
            id = row.id,
        }
    end
end

function LoadStock()
    local rows = MySQL.query.await('SELECT * FROM company_stock')
    SBCompanies.Stock = {}
    for _, row in ipairs(rows or {}) do
        if not SBCompanies.Stock[row.company_id] then
            SBCompanies.Stock[row.company_id] = {}
        end
        SBCompanies.Stock[row.company_id][row.item_name] = row.quantity
    end
end

function LoadCatalog()
    local rows = MySQL.query.await('SELECT * FROM company_catalog')
    SBCompanies.CatalogPrices = {}
    -- Also build the shared Catalog lookup
    Catalog.ItemToCompany = {}
    Catalog.CompanyItems = {}

    for _, row in ipairs(rows or {}) do
        if not SBCompanies.CatalogPrices[row.company_id] then
            SBCompanies.CatalogPrices[row.company_id] = {}
        end
        SBCompanies.CatalogPrices[row.company_id][row.item_name] = {
            base_price = row.base_price,
            current_price = row.current_price,
        }

        -- Build shared catalog mappings
        Catalog.ItemToCompany[row.item_name] = row.company_id
        if not Catalog.CompanyItems[row.company_id] then
            Catalog.CompanyItems[row.company_id] = {}
        end
        table.insert(Catalog.CompanyItems[row.company_id], {
            item_name = row.item_name,
            base_price = row.base_price,
            current_price = row.current_price,
        })
    end
end

function LoadShopStorage()
    local rows = MySQL.query.await('SELECT * FROM shop_storage WHERE quantity > 0')
    SBCompanies.ShopStorage = {}
    for _, row in ipairs(rows or {}) do
        if not SBCompanies.ShopStorage[row.shop_id] then
            SBCompanies.ShopStorage[row.shop_id] = {}
        end
        local key = row.item_name .. ':' .. row.quality
        SBCompanies.ShopStorage[row.shop_id][key] = {
            item_name = row.item_name,
            quantity = row.quantity,
            quality = row.quality,
        }
    end
end

-- ===================================================================
-- HELPER: Get company stock for an item
-- ===================================================================
function GetCompanyStock(companyId, itemName)
    if not SBCompanies.Stock[companyId] then return 0 end
    return SBCompanies.Stock[companyId][itemName] or 0
end

-- ===================================================================
-- HELPER: Modify company stock (add or remove)
-- ===================================================================
function ModifyCompanyStock(companyId, itemName, delta)
    if not SBCompanies.Stock[companyId] then
        SBCompanies.Stock[companyId] = {}
    end
    local current = SBCompanies.Stock[companyId][itemName] or 0
    local newQty = math.max(0, current + delta)
    SBCompanies.Stock[companyId][itemName] = newQty

    MySQL.query('INSERT INTO company_stock (company_id, item_name, quantity) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = ?',
        { companyId, itemName, newQty, newQty })

    return newQty
end

-- ===================================================================
-- HELPER: Modify company balance
-- ===================================================================
function ModifyCompanyBalance(companyId, delta, txType, description)
    local company = SBCompanies.Companies[companyId]
    if not company then return false end

    company.balance = math.max(0, company.balance + delta)
    MySQL.query('UPDATE companies SET balance = ? WHERE id = ?', { company.balance, companyId })

    -- Log transaction
    if txType then
        MySQL.query('INSERT INTO company_transactions (company_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { companyId, txType, math.abs(delta), description or '' })
    end

    return true
end

-- ===================================================================
-- HELPER: Add item to shop storage
-- ===================================================================
function AddToShopStorage(shopId, itemName, quantity, quality)
    quality = quality or 'standard'
    if not SBCompanies.ShopStorage[shopId] then
        SBCompanies.ShopStorage[shopId] = {}
    end

    local key = itemName .. ':' .. quality
    if not SBCompanies.ShopStorage[shopId][key] then
        SBCompanies.ShopStorage[shopId][key] = {
            item_name = itemName,
            quantity = 0,
            quality = quality,
        }
    end

    SBCompanies.ShopStorage[shopId][key].quantity = SBCompanies.ShopStorage[shopId][key].quantity + quantity

    MySQL.query('INSERT INTO shop_storage (shop_id, item_name, quantity, quality) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + ?',
        { shopId, itemName, quantity, quality, quantity })
end

-- ===================================================================
-- HELPER: Remove item from shop storage
-- ===================================================================
function RemoveFromShopStorage(shopId, itemName, quantity, quality)
    quality = quality or 'standard'
    if not SBCompanies.ShopStorage[shopId] then return false end

    local key = itemName .. ':' .. quality
    local entry = SBCompanies.ShopStorage[shopId][key]
    if not entry or entry.quantity < quantity then return false end

    entry.quantity = entry.quantity - quantity

    if entry.quantity <= 0 then
        SBCompanies.ShopStorage[shopId][key] = nil
        MySQL.query('DELETE FROM shop_storage WHERE shop_id = ? AND item_name = ? AND quality = ?',
            { shopId, itemName, quality })
    else
        MySQL.query('UPDATE shop_storage SET quantity = ? WHERE shop_id = ? AND item_name = ? AND quality = ?',
            { entry.quantity, shopId, itemName, quality })
    end

    return true
end

-- ===================================================================
-- HELPER: Check if player is employee of company
-- ===================================================================
function GetEmployeeData(citizenid)
    return SBCompanies.Employees[citizenid]
end

-- ===================================================================
-- HELPER: Check if player is owner of company
-- ===================================================================
function IsCompanyOwner(citizenid, companyId)
    local company = SBCompanies.Companies[companyId]
    return company and company.owner_citizenid == citizenid
end

-- ===================================================================
-- HELPER: Check if mechanic job
-- ===================================================================
local MechanicJobs = {
    ['bn-mechanic'] = true,
    ['mechanic']    = true,
}

function IsMechanicJob(jobName)
    return MechanicJobs[jobName] == true
end

-- ===================================================================
-- PERIODIC SAVE (every 5 minutes, save dirty state)
-- ===================================================================
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        -- Company balances are saved on modification, so this is just a safety net
        for companyId, company in pairs(SBCompanies.Companies) do
            MySQL.query('UPDATE companies SET balance = ? WHERE id = ?', { company.balance, companyId })
        end
        if Config.Debug then
            print('^2[sb_companies]^7 Periodic save complete')
        end
    end
end)

-- ===================================================================
-- PLAYER DISCONNECT: Cleanup
-- ===================================================================
AddEventHandler('playerDropped', function()
    -- Delivery claim cleanup is handled in server/delivery.lua
end)

-- ===================================================================
-- EXPORTS
-- ===================================================================

-- Get shop storage data for a shop
exports('GetShopStorage', function(shopId)
    return SBCompanies.ShopStorage[shopId] or {}
end)

-- Add items to shop storage (used by delivery completion)
exports('AddToShopStorage', function(shopId, itemName, quantity, quality)
    AddToShopStorage(shopId, itemName, quantity, quality)
end)

-- Check if player is company employee
exports('GetEmployeeData', function(citizenid)
    return GetEmployeeData(citizenid)
end)

-- Get company data
exports('GetCompanyData', function(companyId)
    return SBCompanies.Companies[companyId]
end)

-- Get company catalog prices
exports('GetCatalogPrices', function(companyId)
    return SBCompanies.CatalogPrices[companyId] or {}
end)
