--[[
    Everyday Chaos RP - Server Events
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- PLAYER CONNECTION EVENTS
-- ============================================================================

-- Player connecting (validation, ban checks, user creation)
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source

    deferrals.defer()
    Wait(0)

    deferrals.update('Checking player data...')

    -- Get identifiers
    local license = GetPlayerIdentifierByType(src, 'license')
    local discord = GetPlayerIdentifierByType(src, 'discord')

    -- Check for license (allow clients with fivem identifier as fallback for dev testing)
    if not license then
        local fivem = GetPlayerIdentifierByType(src, 'fivem')
        if fivem then
            license = 'license:dev_' .. fivem:gsub('fivem:', '')
            print('^3[SB_CORE]^7 Client connected without Rockstar license, using fivem fallback: ' .. license)
        else
            deferrals.done('No Rockstar license found. Please restart FiveM.')
            return
        end
    end

    deferrals.update('Checking ban status...')

    -- Check if banned
    local isBanned, banData = SB.Functions.IsPlayerBanned(src)
    if isBanned then
        local expireText = banData.expire and os.date('%Y-%m-%d %H:%M', banData.expire) or 'Permanent'
        deferrals.done(string.format(
            'You are banned from this server!\n\nReason: %s\nExpires: %s\nBanned by: %s',
            banData.reason,
            expireText,
            banData.bannedby
        ))
        return
    end

    deferrals.update('Loading account...')

    -- Create or update user account
    local user = SB.Functions.CreateUser(src)
    if not user then
        deferrals.done('Failed to load your account. Please try again.')
        return
    end

    -- Store user in memory for quick access
    SB.Users[src] = user

    -- ================================================================
    -- WHITELIST GATE (requires sb_whitelist resource)
    -- ================================================================
    local whitelistActive = GetResourceState('sb_whitelist') == 'started'
    local whitelistEnabled = false

    if whitelistActive then
        local ok, result = pcall(function()
            return exports['sb_whitelist']:IsEnabled()
        end)
        if ok then
            whitelistEnabled = result
        else
            print('^1[SB_CORE]^7 Whitelist export error: ' .. tostring(result))
        end
    end

    if whitelistEnabled then
        deferrals.update('Checking whitelist...')
        Wait(100)

        -- Check if admin (bypass everything)
        local identifiers = GetPlayerIdentifiers(src)
        local ok2, isAdmin = pcall(function()
            return exports['sb_whitelist']:IsAdminIdentifier(identifiers)
        end)
        if not ok2 then
            isAdmin = false
            print('^1[SB_CORE]^7 Admin check error: ' .. tostring(isAdmin))
        end

        if isAdmin then
            print('^2[SB_CORE]^7 Admin bypass for: ' .. name)
            deferrals.update('Welcome back, Admin!')
            Wait(500)
            deferrals.done()
            return
        end

        -- Check if already whitelisted
        local whitelistResult = MySQL.single.await(
            'SELECT is_whitelisted FROM users WHERE license = ?', { license }
        )

        if whitelistResult and (whitelistResult.is_whitelisted == 1 or whitelistResult.is_whitelisted == true) then
            -- Whitelisted player - straight in, no password needed
            print('^2[SB_CORE]^7 Whitelisted player: ' .. name)
            deferrals.update('Welcome to ' .. Config.ServerName .. '!')
            Wait(500)
            deferrals.done()
            return
        end

        -- NOT WHITELISTED - Show password card first
        local ok3, serverPassword = pcall(function()
            return exports['sb_whitelist']:GetPassword()
        end)
        if not ok3 then
            serverPassword = ""
            print('^1[SB_CORE]^7 Password export error: ' .. tostring(serverPassword))
        end
        local passwordVerified = false

        if serverPassword and serverPassword ~= "" then
            -- Password card
            local passwordCard = json.encode({
                type = "AdaptiveCard",
                version = "1.3",
                body = {
                    {
                        type = "TextBlock",
                        text = "Everyday Chaos RP",
                        size = "Large",
                        weight = "Bolder",
                        horizontalAlignment = "Center"
                    },
                    {
                        type = "TextBlock",
                        text = "This server is currently in development. A password is required to join during this phase.",
                        wrap = true,
                        horizontalAlignment = "Center"
                    },
                    {
                        type = "Input.Text",
                        id = "password",
                        placeholder = "Enter server password",
                        isRequired = true
                    }
                },
                actions = {
                    {
                        type = "Action.Submit",
                        title = "Submit",
                        id = "submit_password"
                    }
                }
            })

            -- Loop until correct password
            while not passwordVerified do
                local cardResult = nil
                deferrals.presentCard(passwordCard, function(data, rawData)
                    cardResult = data
                end)

                -- Wait for card response
                while cardResult == nil do
                    Wait(100)
                end

                if cardResult.password and cardResult.password == serverPassword then
                    passwordVerified = true
                else
                    -- Wrong password - show error card then re-show password
                    local errorCard = json.encode({
                        type = "AdaptiveCard",
                        version = "1.3",
                        body = {
                            {
                                type = "TextBlock",
                                text = "Everyday Chaos RP",
                                size = "Large",
                                weight = "Bolder",
                                horizontalAlignment = "Center"
                            },
                            {
                                type = "TextBlock",
                                text = "Wrong password. Try again.",
                                color = "Attention",
                                wrap = true,
                                horizontalAlignment = "Center"
                            },
                            {
                                type = "Input.Text",
                                id = "password",
                                placeholder = "Enter server password",
                                isRequired = true
                            }
                        },
                        actions = {
                            {
                                type = "Action.Submit",
                                title = "Submit",
                                id = "submit_password"
                            }
                        }
                    })

                    cardResult = nil
                    deferrals.presentCard(errorCard, function(data, rawData)
                        cardResult = data
                    end)

                    while cardResult == nil do
                        Wait(100)
                    end

                    if cardResult.password and cardResult.password == serverPassword then
                        passwordVerified = true
                    end
                end
            end
        else
            -- No password required, skip to whitelist check
            passwordVerified = true
        end

        -- Password verified - now show whitelist waiting screen
        print('^3[SB_CORE]^7 Player registered, waiting for whitelist: ' .. name .. ' (' .. license .. ')')

        local whitelisted = false

        while not whitelisted do
            local whitelistCard = json.encode({
                type = "AdaptiveCard",
                version = "1.3",
                body = {
                    {
                        type = "TextBlock",
                        text = "Everyday Chaos RP",
                        size = "Large",
                        weight = "Bolder",
                        horizontalAlignment = "Center"
                    },
                    {
                        type = "TextBlock",
                        text = "Your account has been registered!",
                        color = "Good",
                        wrap = true,
                        horizontalAlignment = "Center"
                    },
                    {
                        type = "TextBlock",
                        text = "You are not yet whitelisted. Contact the server owner to get approved, then click Check Whitelist below.",
                        wrap = true,
                        horizontalAlignment = "Center"
                    },
                    {
                        type = "TextBlock",
                        text = "Server Owner: Salah Eddine Boussettah",
                        weight = "Bolder",
                        horizontalAlignment = "Center",
                        wrap = true
                    },
                    {
                        type = "TextBlock",
                        text = "Your License: " .. license,
                        size = "Small",
                        isSubtle = true,
                        wrap = true,
                        horizontalAlignment = "Center"
                    }
                },
                actions = {
                    {
                        type = "Action.OpenUrl",
                        title = "Contact on Discord",
                        url = "https://discord.com/users/1049326601986375731"
                    },
                    {
                        type = "Action.Submit",
                        title = "Check Whitelist",
                        id = "check_whitelist"
                    }
                }
            })

            local cardResult = nil
            deferrals.presentCard(whitelistCard, function(data, rawData)
                cardResult = data
            end)

            -- Wait for button click
            while cardResult == nil do
                Wait(100)
            end

            -- Re-check database
            deferrals.update('Checking whitelist status...')
            Wait(500)

            local recheck = MySQL.single.await(
                'SELECT is_whitelisted FROM users WHERE license = ?', { license }
            )

            if recheck and (recheck.is_whitelisted == 1 or recheck.is_whitelisted == true) then
                whitelisted = true
                print('^2[SB_CORE]^7 Player now whitelisted: ' .. name .. ' (' .. license .. ')')
            end
            -- If still not whitelisted, loop shows the card again
        end

        -- Player is now whitelisted
        deferrals.update('Welcome to ' .. Config.ServerName .. '!')
        Wait(500)
        deferrals.done()
        return
    end

    -- No whitelist system or disabled - let through
    deferrals.update('Welcome to ' .. Config.ServerName .. '!')
    Wait(500)

    deferrals.done()
end)

-- Player dropped (disconnected)
AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = SB.Players[src]
    local User = SB.Users[src]

    if Player then
        -- Save player data
        Player.Functions.Save()

        -- Trigger event for other resources
        TriggerEvent('SB:Server:PlayerDropped', Player, reason)

        -- Remove from players table
        SB.Players[src] = nil

        SBShared.Debug('Player dropped: ' .. Player.PlayerData.citizenid .. ' | Reason: ' .. reason)
    end

    -- Clean up user from memory
    if User then
        SB.Users[src] = nil
    end
end)

-- ============================================================================
-- CHARACTER EVENTS
-- ============================================================================

-- Load character
RegisterNetEvent('SB:Server:LoadCharacter', function(citizenid)
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    if not license then
        SB.Functions.Kick(src, 'No license found')
        return
    end

    -- Check if character belongs to this player
    local result = MySQL.scalar.await([[
        SELECT license FROM players WHERE citizenid = ?
    ]], { citizenid })

    if result ~= license then
        SB.Functions.Kick(src, 'Character does not belong to you')
        return
    end

    -- Login player
    local Player = SB.Player.Login(src, citizenid)

    if Player then
        SBShared.Debug('Character loaded: ' .. citizenid)
    else
        SB.Functions.Notify(src, 'Failed to load character', 'error')
    end
end)

-- Create new character
RegisterNetEvent('SB:Server:CreateCharacter', function(data)
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    if not license then
        SB.Functions.Kick(src, 'No license found')
        return
    end

    -- Check character count
    local charCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM players WHERE license = ?
    ]], { license })

    local maxSlots = Config.PlayerSlots[license] or Config.MaxCharacters

    if charCount >= maxSlots then
        SB.Functions.Notify(src, 'Maximum characters reached', 'error')
        return
    end

    -- Get next CID
    local maxCid = MySQL.scalar.await([[
        SELECT MAX(cid) FROM players WHERE license = ?
    ]], { license })

    local newCid = (maxCid or 0) + 1

    -- Generate unique data
    local citizenid = SB.Functions.CreateCitizenId()
    local phone = SB.Functions.CreatePhoneNumber()
    local account = SB.Functions.CreateAccountNumber()

    -- Prepare character data
    local charinfo = {
        firstname = data.firstname,
        lastname = data.lastname,
        birthdate = data.birthdate,
        gender = data.gender,
        nationality = data.nationality or 'American',
        phone = phone,
        account = account
    }

    local newData = {
        cid = newCid,
        charinfo = charinfo,
        money = SBShared.DeepCopy(Config.DefaultMoney),
        job = SBShared.DeepCopy(Config.DefaultJob),
        gang = SBShared.DeepCopy(Config.DefaultGang),
        position = SBShared.DeepCopy(Config.DefaultSpawn),
        metadata = SBShared.DeepCopy(Config.DefaultMetadata)
    }

    -- Login with new data
    local Player = SB.Player.Login(src, citizenid, newData)

    if Player then
        TriggerClientEvent('SB:Client:CharacterCreated', src, citizenid)
        SBShared.Debug('Character created: ' .. citizenid)
    else
        SB.Functions.Notify(src, 'Failed to create character', 'error')
    end
end)

-- Delete character
RegisterNetEvent('SB:Server:DeleteCharacter', function(citizenid)
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    -- Verify ownership
    local result = MySQL.scalar.await([[
        SELECT license FROM players WHERE citizenid = ?
    ]], { citizenid })

    if result ~= license then
        SB.Functions.Kick(src, 'Character does not belong to you')
        return
    end

    -- Delete character and related data
    MySQL.query.await('DELETE FROM players WHERE citizenid = ?', { citizenid })
    MySQL.query.await('DELETE FROM player_vehicles WHERE citizenid = ?', { citizenid })

    TriggerClientEvent('SB:Client:CharacterDeleted', src, citizenid)

    SBShared.Debug('Character deleted: ' .. citizenid)
end)

-- ============================================================================
-- PLAYER UPDATE EVENTS
-- ============================================================================

-- Update player position
RegisterNetEvent('SB:Server:UpdatePosition', function(coords)
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    if Player then
        Player.PlayerData.position = coords
    end
end)

-- Update player metadata (for HUD updates like hunger/thirst)
RegisterNetEvent('SB:Server:UpdateMetadata', function(key, value)
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    if Player then
        Player.Functions.SetMetaData(key, value)
    end
end)

-- ============================================================================
-- MONEY EVENTS
-- ============================================================================

-- Request money transfer between players
RegisterNetEvent('SB:Server:GiveMoney', function(targetId, amount)
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    local Target = SB.Functions.GetPlayer(targetId)

    if not Player or not Target then
        SB.Functions.Notify(src, 'Player not found', 'error')
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        SB.Functions.Notify(src, 'Invalid amount', 'error')
        return
    end

    if Player.Functions.GetMoney('cash') < amount then
        SB.Functions.Notify(src, Lang('money_not_enough'), 'error')
        return
    end

    Player.Functions.RemoveMoney('cash', amount, 'Gave to ' .. Target.Functions.GetName())
    Target.Functions.AddMoney('cash', amount, 'Received from ' .. Player.Functions.GetName())

    SB.Functions.Notify(src, Lang('money_removed', SBShared.FormatMoney(amount)), 'success')
    SB.Functions.Notify(targetId, Lang('money_received', SBShared.FormatMoney(amount)), 'success')
end)

-- Death events are handled by sb_deaths resource

-- ============================================================================
-- LOGOUT EVENT
-- ============================================================================

RegisterNetEvent('SB:Server:Logout', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)

    if Player then
        Player.Functions.Logout()
        TriggerClientEvent('SB:Client:OnLogout', src)
    end
end)

-- ============================================================================
-- AUTO-SAVE
-- ============================================================================

-- Save all players every 5 minutes
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- 5 minutes

        local count = 0
        for _, Player in pairs(SB.Players) do
            Player.Functions.Save()
            count = count + 1
        end

        if count > 0 then
            SBShared.Debug('Auto-saved ' .. count .. ' players')
        end
    end
end)

-- ============================================================================
-- PAYCHECK SYSTEM
-- ============================================================================

-- Pay on-duty players every 15 minutes
CreateThread(function()
    while true do
        Wait(15 * 60 * 1000) -- 15 minutes

        local paid = 0
        for _, Player in pairs(SB.Players) do
            local job = Player.PlayerData.job
            if job and job.name ~= 'unemployed' and job.payment and job.payment > 0 then
                local jobDef = SBShared.Jobs[job.name]
                local shouldPay = job.onduty or (jobDef and jobDef.offDutyPay)

                if shouldPay then
                    Player.Functions.AddMoney('bank', job.payment, 'Paycheck: ' .. (job.label or job.name))
                    TriggerClientEvent('sb_notify:client:Notify', Player.PlayerData.source,
                        ('Paycheck: $%s deposited to your bank'):format(job.payment), 'success', 5000)
                    paid = paid + 1
                end
            end
        end

        if paid > 0 then
            print(('[sb_core] Paychecks distributed to %d players'):format(paid))
        end
    end
end)
