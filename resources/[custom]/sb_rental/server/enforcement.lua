-- sb_rental Server Enforcement
-- Late fee thread, stolen marking, despawn logic

local SBCore = exports['sb_core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SBCore = exports['sb_core']:GetCoreObject()
    end
end)

-- Parse datetime string/number to timestamp (returns seconds since epoch)
function ParseDateTime(dateStr)
    if not dateStr then return os.time() end

    -- If it's already a number
    if type(dateStr) == 'number' then
        -- Check if it's milliseconds (> 10^12, i.e., 13+ digits) and convert to seconds
        -- Timestamps after year 2001 in seconds are > 1000000000 (10 digits)
        -- Timestamps in milliseconds are > 1000000000000 (13 digits)
        if dateStr > 1000000000000 then
            return math.floor(dateStr / 1000)
        end
        return dateStr
    end

    -- If it's not a string, convert to string first
    if type(dateStr) ~= 'string' then
        dateStr = tostring(dateStr)
    end

    local pattern = '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)'
    local year, month, day, hour, min, sec = dateStr:match(pattern)

    if year then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end

    return os.time()
end

-- Calculate minutes difference (uses raw seconds for precision with fractional GameDayMinutes)
function GetMinutesDifference(timestamp1, timestamp2)
    return (timestamp1 - timestamp2) / 60
end

-- Enforcement thread
CreateThread(function()
    Wait(30000)
    print('^2[sb_rental:enforcement]^7 Thread started')

    while true do
        local now = os.time()

        -- Get all active/late rentals
        local success, activeRentals = pcall(function()
            return MySQL.query.await([[
                SELECT * FROM vehicle_rentals
                WHERE status IN ('active', 'late', 'stolen')
            ]])
        end)

        if not success then
            print('^1[sb_rental:enforcement]^7 DB query error: ' .. tostring(activeRentals))
        elseif activeRentals and #activeRentals > 0 then
            for _, rental in ipairs(activeRentals) do
                local rentalEndTime = ParseDateTime(rental.rental_end)
                local minutesLate = GetMinutesDifference(now, rentalEndTime)

                -- Only process if past grace period
                if minutesLate > Config.GracePeriodMinutes then
                    local daysLate = math.ceil(minutesLate / Config.GameDayMinutes)
                    local lateFee = rental.daily_rate * Config.LateMultiplier * daysLate

                    -- Update late fees and status
                    if rental.status == 'active' then
                        local ok, err = pcall(function()
                            MySQL.query.await([[
                                UPDATE vehicle_rentals
                                SET late_fees = ?, status = 'late', updated_at = NOW()
                                WHERE id = ?
                            ]], { lateFee, rental.id })
                        end)
                        if not ok then
                            print('^1[sb_rental:enforcement]^7 Late update error: ' .. tostring(err))
                        end

                        -- Notify player if online
                        NotifyRenter(rental.citizenid, 'overdue')
                    else
                        local ok, err = pcall(function()
                            MySQL.query.await([[
                                UPDATE vehicle_rentals
                                SET late_fees = ?, updated_at = NOW()
                                WHERE id = ?
                            ]], { lateFee, rental.id })
                        end)
                        if not ok then
                            print('^1[sb_rental:enforcement]^7 Fee update error: ' .. tostring(err))
                        end
                    end

                    -- Mark as stolen after threshold
                    if daysLate >= Config.StolenThresholdDays and rental.status ~= 'stolen' then
                        local ok, err = pcall(function()
                            MySQL.query.await([[
                                UPDATE vehicle_rentals
                                SET status = 'stolen', updated_at = NOW()
                                WHERE id = ?
                            ]], { rental.id })
                        end)
                        if not ok then
                            print('^1[sb_rental:enforcement]^7 Stolen update error: ' .. tostring(err))
                        end

                        NotifyRenter(rental.citizenid, 'stolen')
                    end

                    -- Auto-despawn after despawn threshold
                    if daysLate >= Config.DespawnThresholdDays then
                        local ok, err = pcall(function()
                            DespawnRentalVehicle(rental)
                        end)
                        if not ok then
                            print('^1[sb_rental:enforcement]^7 Despawn error: ' .. tostring(err))
                        end

                        -- Blacklist player
                        local blacklistUntil = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.BlacklistHours * 3600))

                        local ok2, err2 = pcall(function()
                            MySQL.query.await([[
                                UPDATE vehicle_rentals
                                SET status = 'despawned', blacklist_until = ?, updated_at = NOW()
                                WHERE id = ?
                            ]], { blacklistUntil, rental.id })
                        end)
                        if not ok2 then
                            print('^1[sb_rental:enforcement]^7 Despawn DB error: ' .. tostring(err2))
                        end

                        -- Try to deduct fees from player bank
                        local ok3, err3 = pcall(function()
                            DeductLateFees(rental.citizenid, lateFee)
                        end)
                        if not ok3 then
                            print('^1[sb_rental:enforcement]^7 Deduct error: ' .. tostring(err3))
                        end

                        -- Remove rental license
                        local ok4, err4 = pcall(function()
                            RemoveRentalLicense(rental.citizenid, rental.rental_id)
                        end)
                        if not ok4 then
                            print('^1[sb_rental:enforcement]^7 License remove error: ' .. tostring(err4))
                        end

                        NotifyRenter(rental.citizenid, 'despawned', { blacklistUntil = blacklistUntil })
                    end
                end
            end
        end

        Wait(300000)
    end
end)

-- Despawn rental vehicle (FIX-007: Server-side deletion + client fallback)
function DespawnRentalVehicle(rental)
    -- Try to get vehicle netId from tracking
    local netId = exports['sb_rental']:GetRentalVehicleNetId(rental.rental_id)

    if netId then
        -- Server-side deletion
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end

        -- Clear tracking
        exports['sb_rental']:ClearRentalVehicle(rental.rental_id)
    end

    -- Also trigger client-side despawn as fallback (in case entity routing differs)
    TriggerClientEvent('sb_rental:client:despawnRental', -1, rental.plate)
end

-- Notify renter if online
function NotifyRenter(citizenid, notifyType, data)
    local Player = SBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Player then return end

    local source = Player.PlayerData.source
    if not source then return end

    if notifyType == 'overdue' then
        TriggerClientEvent('sb_rental:client:warning', source, 'overdue', {})
    elseif notifyType == 'stolen' then
        TriggerClientEvent('sb_rental:client:warning', source, 'stolen', {})
    elseif notifyType == 'despawned' then
        TriggerClientEvent('sb_notify:client:Notify', source, 'Your rental has been repossessed! Banned from rentals until ' .. (data and data.blacklistUntil or '24 hours'), 'error', 10000)
        TriggerClientEvent('sb_rental:client:rentalUpdated', source, nil)
    end
end

-- Deduct late fees from player bank
function DeductLateFees(citizenid, amount)
    local Player = SBCore.Functions.GetPlayerByCitizenId(citizenid)

    if Player then
        -- Player is online
        local bank = Player.PlayerData.money.bank or 0
        local deduct = math.min(amount, bank)
        if deduct > 0 then
            Player.Functions.RemoveMoney('bank', deduct, 'rental-late-fees')
        end
    else
        -- Player is offline - deduct from database
        MySQL.query.await([[
            UPDATE players
            SET money = JSON_SET(money, '$.bank', GREATEST(0, JSON_EXTRACT(money, '$.bank') - ?))
            WHERE citizenid = ?
        ]], { amount, citizenid })
    end
end

-- Remove rental license from player inventory
function RemoveRentalLicense(citizenid, rentalId)
    local Player = SBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Player then return end

    local source = Player.PlayerData.source
    if not source then return end

    local items = exports['sb_inventory']:GetItemsByName(source, 'rental_license')
    if items then
        for _, item in pairs(items) do
            if item.metadata and item.metadata.rental_id == rentalId then
                exports['sb_inventory']:RemoveItem(source, 'rental_license', 1, item.slot)
                break
            end
        end
    end
end

-- Admin command to force return a rental
RegisterCommand('forcereturnal', function(source, args)
    if source > 0 then
        -- Check admin permission
        if not IsPlayerAceAllowed(source, 'command.sb_admin') then
            TriggerClientEvent('sb_notify:client:Notify', source, 'No permission', 'error', 3000)
            return
        end
    end

    local rentalId = args[1]
    if not rentalId then
        print('Usage: /forcereturnrental [rental_id]')
        return
    end

    -- Get rental
    local rental = MySQL.single.await('SELECT * FROM vehicle_rentals WHERE rental_id = ?', { rentalId })
    if not rental then
        print('Rental not found: ' .. rentalId)
        return
    end

    -- Update status
    MySQL.query.await([[
        UPDATE vehicle_rentals
        SET status = 'returned', actual_return = NOW()
        WHERE rental_id = ?
    ]], { rentalId })

    -- Despawn vehicle
    TriggerClientEvent('sb_rental:client:despawnRental', -1, rental.plate)

    -- Remove license if player online
    RemoveRentalLicense(rental.citizenid, rentalId)

    -- Update client
    local Player = SBCore.Functions.GetPlayerByCitizenId(rental.citizenid)
    if Player then
        TriggerClientEvent('sb_rental:client:rentalUpdated', Player.PlayerData.source, nil)
        exports['sb_notify']:Notify(Player.PlayerData.source, 'Your rental has been force-returned by admin', 'warning', 5000)
    end

    print('^2[sb_rental]^7 Force returned rental: ' .. rentalId)
end)

-- Admin command to clear blacklist
RegisterCommand('clearrentalban', function(source, args)
    if source > 0 then
        if not IsPlayerAceAllowed(source, 'command.sb_admin') then
            TriggerClientEvent('sb_notify:client:Notify', source, 'No permission', 'error', 3000)
            return
        end
    end

    local citizenid = args[1]
    if not citizenid then
        print('Usage: /clearrentalban [citizenid]')
        return
    end

    MySQL.query.await([[
        UPDATE vehicle_rentals
        SET blacklist_until = NULL
        WHERE citizenid = ?
    ]], { citizenid })

    print('^2[sb_rental]^7 Cleared rental ban for: ' .. citizenid)
end)

-- Admin command to list active rentals
RegisterCommand('listrentals', function(source, args)
    if source > 0 then
        if not IsPlayerAceAllowed(source, 'command.sb_admin') then
            TriggerClientEvent('sb_notify:client:Notify', source, 'No permission', 'error', 3000)
            return
        end
    end

    local rentals = MySQL.query.await([[
        SELECT rental_id, citizenid, vehicle_label, plate, status, rental_end
        FROM vehicle_rentals
        WHERE status IN ('active', 'late', 'stolen')
        ORDER BY rental_end ASC
    ]])

    if not rentals or #rentals == 0 then
        print('^3[sb_rental]^7 No active rentals')
        return
    end

    print('^3[sb_rental]^7 Active Rentals:')
    for _, r in ipairs(rentals) do
        print(string.format('  %s | %s | %s | %s | %s | Due: %s',
            r.rental_id, r.citizenid, r.vehicle_label, r.plate, r.status, r.rental_end))
    end
end)
