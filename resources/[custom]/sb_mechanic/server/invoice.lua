-- ============================================================================
-- sb_mechanic - Server: Invoice System (Laptop Billing Terminal)
-- Worklog-based billing: auto-track work, laptop NUI to send bills
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- Pending bill responses (keyed by plate, stores mechanic src waiting for response)
local pendingBills = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function Debug(...)
    if Config.Debug then
        print('[sb_mechanic:server:invoice]', ...)
    end
end

-- ============================================================================
-- Log Work (called by stations.lua after each successful service)
-- ============================================================================

function LogWork(plate, serviceType, serviceLabel, price, mechanicCid, mechanicName)
    MySQL.insert('INSERT INTO mechanic_worklog (plate, service_type, service_label, price, mechanic_cid, mechanic_name) VALUES (?, ?, ?, ?, ?, ?)', {
        plate, serviceType, serviceLabel, price, mechanicCid, mechanicName
    })
    Debug('Logged work:', plate, serviceType, serviceLabel, '$' .. price)
end

-- ============================================================================
-- Get Unpaid Vehicles (for billing laptop)
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:getUnpaidVehicles', function(source, cb)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb({}) end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName or not job.onduty then
        return cb({})
    end

    -- Get all unpaid vehicles grouped by plate
    local results = MySQL.query.await([[
        SELECT w.plate, COUNT(*) as services, SUM(w.price) as total
        FROM mechanic_worklog w
        WHERE w.paid = 0
        GROUP BY w.plate
        ORDER BY MAX(w.created_at) DESC
    ]])

    if not results or #results == 0 then
        return cb({})
    end

    -- For each plate, look up owner name
    local vehicles = {}
    for _, row in ipairs(results) do
        local ownerData = MySQL.query.await([[
            SELECT p.charinfo
            FROM player_vehicles pv
            LEFT JOIN players p ON p.citizenid = pv.citizenid
            WHERE pv.plate = ?
            LIMIT 1
        ]], { row.plate })

        local ownerName = 'Unknown Owner'
        if ownerData and ownerData[1] and ownerData[1].charinfo then
            local charinfo = json.decode(ownerData[1].charinfo)
            if charinfo then
                ownerName = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
            end
        end

        table.insert(vehicles, {
            plate = row.plate,
            ownerName = ownerName,
            services = row.services,
            total = row.total,
        })
    end

    cb(vehicles)
end)

-- ============================================================================
-- Get Vehicle Worklog (itemized list for a specific plate)
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:getVehicleWorklog', function(source, cb, plate)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb({}) end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName or not job.onduty then
        return cb({})
    end

    local results = MySQL.query.await([[
        SELECT id, service_label, price, mechanic_name, created_at
        FROM mechanic_worklog
        WHERE plate = ? AND paid = 0
        ORDER BY created_at ASC
    ]], { plate })

    cb(results or {})
end)

-- ============================================================================
-- Send Bill (from laptop to vehicle owner)
-- ============================================================================

SB.Functions.CreateCallback('sb_mechanic:sendBill', function(source, cb, plate)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return cb(false, 'Player not found') end

    local job = Player.PlayerData.job
    if job.name ~= Config.JobName or not job.onduty then
        return cb(false, 'Must be on duty')
    end

    -- Get unpaid total for this plate
    local totalResult = MySQL.query.await([[
        SELECT SUM(price) as total FROM mechanic_worklog WHERE plate = ? AND paid = 0
    ]], { plate })

    if not totalResult or not totalResult[1] or not totalResult[1].total or totalResult[1].total == 0 then
        return cb(false, 'No unpaid work for this vehicle')
    end

    local total = totalResult[1].total

    -- Get itemized work for the popup
    local workItems = MySQL.query.await([[
        SELECT service_label, price FROM mechanic_worklog WHERE plate = ? AND paid = 0 ORDER BY created_at ASC
    ]], { plate })

    -- Lookup vehicle owner CID
    local vehicleData = MySQL.query.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not vehicleData or not vehicleData[1] then
        return cb(false, 'Vehicle owner not found in database')
    end

    local ownerCid = vehicleData[1].citizenid

    -- Check if owner is online
    local ownerSrc = nil
    local players = SB.Functions.GetPlayers()
    for _, pid in ipairs(players) do
        local TargetPlayer = SB.Functions.GetPlayer(pid)
        if TargetPlayer and TargetPlayer.PlayerData.citizenid == ownerCid then
            ownerSrc = pid
            break
        end
    end

    if not ownerSrc then
        return cb(false, 'Vehicle owner is not online')
    end

    local mechanicName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    -- Store pending bill
    pendingBills[plate] = {
        mechanicSrc = src,
        mechanicCid = Player.PlayerData.citizenid,
        mechanicName = mechanicName,
        ownerSrc = ownerSrc,
        ownerCid = ownerCid,
        total = total,
        timestamp = os.time(),
    }

    -- Format items for NUI
    local popupItems = {}
    for _, item in ipairs(workItems or {}) do
        table.insert(popupItems, {
            label = item.service_label,
            price = item.price,
        })
    end

    -- Send popup to owner
    TriggerClientEvent('sb_mechanic:showCustomerInvoice', ownerSrc, plate, popupItems, total, mechanicName)

    Debug('Bill sent for plate:', plate, 'total:', total, 'to player:', ownerSrc)
    cb(true, 'Bill sent to vehicle owner')
end)

-- ============================================================================
-- Respond to Bill (owner pays or declines)
-- ============================================================================

RegisterNetEvent('sb_mechanic:respondBill')
AddEventHandler('sb_mechanic:respondBill', function(plate, accept)
    local src = source
    local bill = pendingBills[plate]

    if not bill then
        TriggerClientEvent('sb_notify:Notify', src, 'Bill expired or not found', 'error', 3000)
        return
    end

    -- Validate this is the correct owner
    local Customer = SB.Functions.GetPlayer(src)
    if not Customer or Customer.PlayerData.citizenid ~= bill.ownerCid then
        TriggerClientEvent('sb_notify:Notify', src, 'Not your bill', 'error', 3000)
        return
    end

    if accept then
        -- Check customer has enough money
        local cash = Customer.PlayerData.money['cash'] or 0
        local bank = Customer.PlayerData.money['bank'] or 0
        local total = bill.total

        if cash + bank < total then
            TriggerClientEvent('sb_notify:Notify', src, 'Not enough money ($' .. total .. ' needed)', 'error', 3000)
            return
        end

        -- Remove money (cash first, then bank)
        local remaining = total
        if cash >= remaining then
            Customer.Functions.RemoveMoney('cash', remaining, 'mechanic-bill')
        else
            if cash > 0 then
                Customer.Functions.RemoveMoney('cash', cash, 'mechanic-bill-cash')
                remaining = remaining - cash
            end
            Customer.Functions.RemoveMoney('bank', remaining, 'mechanic-bill-bank')
        end

        -- Pay mechanic cash
        local Mechanic = SB.Functions.GetPlayer(bill.mechanicSrc)
        if Mechanic then
            Mechanic.Functions.AddMoney('cash', total, 'mechanic-bill-payment')
            TriggerClientEvent('sb_mechanic:billPaid', bill.mechanicSrc, plate, total)
        end

        -- Mark worklog as paid
        local invoiceId = 'INV-' .. os.time() .. '-' .. plate
        MySQL.update('UPDATE mechanic_worklog SET paid = 1, invoice_id = ? WHERE plate = ? AND paid = 0', {
            invoiceId, plate
        })

        -- Save vehicle mods to database (get current vehicle props from owner client)
        TriggerClientEvent('sb_mechanic:saveVehicleMods', src, plate)

        TriggerClientEvent('sb_notify:Notify', src, 'Bill paid! $' .. total, 'success', 3000)

        -- Log
        MySQL.insert('INSERT INTO vehicle_history (plate, event_type, description, actor_citizenid, metadata) VALUES (?, ?, ?, ?, ?)', {
            plate,
            'bill_paid',
            'bill_paid',
            bill.mechanicCid,
            json.encode({
                total = total,
                invoiceId = invoiceId,
                customerCid = bill.ownerCid,
            })
        })

        Debug('Bill paid for plate:', plate, 'total:', total)
    else
        -- Declined - notify mechanic
        if bill.mechanicSrc then
            TriggerClientEvent('sb_mechanic:billDeclined', bill.mechanicSrc, plate)
        end
        TriggerClientEvent('sb_notify:Notify', src, 'Bill declined', 'info', 3000)
    end

    -- Remove pending bill
    pendingBills[plate] = nil
end)

-- ============================================================================
-- Save vehicle mods (triggered after payment, client responds with props)
-- ============================================================================

RegisterNetEvent('sb_mechanic:saveVehicleModsResponse')
AddEventHandler('sb_mechanic:saveVehicleModsResponse', function(plate, vehicleProps)
    if plate and vehicleProps then
        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {
            json.encode(vehicleProps), plate
        })
        Debug('Vehicle mods saved for plate:', plate)
    end
end)

-- ============================================================================
-- Cleanup stale pending bills (older than 10 minutes)
-- ============================================================================

Citizen.CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for plate, bill in pairs(pendingBills) do
            if now - bill.timestamp > 600 then
                Debug('Cleaning stale bill:', plate)
                pendingBills[plate] = nil
            end
        end
    end
end)

-- ============================================================================
-- Ensure table exists on resource start
-- ============================================================================

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS mechanic_worklog (
            id INT AUTO_INCREMENT PRIMARY KEY,
            plate VARCHAR(10) NOT NULL,
            service_type VARCHAR(50) NOT NULL,
            service_label VARCHAR(100) NOT NULL,
            price INT NOT NULL DEFAULT 0,
            mechanic_cid VARCHAR(50) NOT NULL,
            mechanic_name VARCHAR(100) DEFAULT NULL,
            paid TINYINT(1) DEFAULT 0,
            invoice_id VARCHAR(50) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_plate (plate),
            INDEX idx_paid (paid),
            INDEX idx_mechanic (mechanic_cid)
        )
    ]])
    Debug('mechanic_worklog table ensured')
end)
