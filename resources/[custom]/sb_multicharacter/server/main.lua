--[[
    Everyday Chaos RP - Multicharacter Server
    Author: Salah Eddine Boussettah
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- GET CHARACTERS FOR PLAYER
-- ============================================================================
RegisterNetEvent('sb_multicharacter:server:GetCharacters', function()
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    if not license then
        TriggerClientEvent('sb_multicharacter:client:SetupError', src, 'No license found')
        return
    end

    -- Get character slots from users table
    local user = SB.Functions.GetUser(src)
    local maxSlots = user and user.character_slots or Config.DefaultSlots

    -- Load all characters for this license
    local characters = MySQL.query.await([[
        SELECT citizenid, cid, charinfo, money, job, gang, position, skin, metadata, last_updated
        FROM players
        WHERE license = ?
        ORDER BY cid ASC
    ]], { license })

    local charList = {}

    for _, char in ipairs(characters or {}) do
        local charinfo = json.decode(char.charinfo) or {}
        local money = json.decode(char.money) or {}
        local job = json.decode(char.job) or {}
        local skin = json.decode(char.skin)
        local position = json.decode(char.position)

        table.insert(charList, {
            citizenid = char.citizenid,
            cid = char.cid,
            charinfo = charinfo,
            money = money,
            job = job,
            skin = skin,
            position = position,
            lastPlayed = char.last_updated
        })
    end

    TriggerClientEvent('sb_multicharacter:client:ReceiveCharacters', src, charList, maxSlots)
end)

-- ============================================================================
-- SELECT CHARACTER (PLAY)
-- ============================================================================
RegisterNetEvent('sb_multicharacter:server:SelectCharacter', function(citizenid, spawnLocation)
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    if not license then
        TriggerClientEvent('sb_multicharacter:client:SelectError', src, 'No license found')
        return
    end

    -- Verify character belongs to this player
    local result = MySQL.scalar.await([[
        SELECT license FROM players WHERE citizenid = ?
    ]], { citizenid })

    if result ~= license then
        TriggerClientEvent('sb_multicharacter:client:SelectError', src, 'Character does not belong to you')
        DropPlayer(src, 'Attempted to load unauthorized character')
        return
    end

    -- Determine spawn coordinates
    local spawnCoords = nil

    if spawnLocation and spawnLocation.useSaved then
        -- Use saved position
        local position = MySQL.scalar.await([[
            SELECT position FROM players WHERE citizenid = ?
        ]], { citizenid })

        if position then
            local pos = json.decode(position)
            if pos and pos.x then
                spawnCoords = vector4(pos.x, pos.y, pos.z, pos.w or 0.0)
            end
        end
    elseif spawnLocation and spawnLocation.coords then
        -- Use selected hotel/location
        spawnCoords = spawnLocation.coords
    end

    -- Fallback to default spawn
    if not spawnCoords then
        spawnCoords = Config.NewCharacterSpawn
    end

    -- Login through sb_core
    local Player = SB.Player.Login(src, citizenid)

    if Player then
        -- Update last_updated timestamp
        MySQL.update.await([[
            UPDATE players SET last_updated = NOW() WHERE citizenid = ?
        ]], { citizenid })

        TriggerClientEvent('sb_multicharacter:client:SpawnCharacter', src, spawnCoords)
        SBShared.Debug('Character selected: ' .. citizenid)
    else
        TriggerClientEvent('sb_multicharacter:client:SelectError', src, 'Failed to load character')
    end
end)

-- ============================================================================
-- CREATE NEW CHARACTER
-- ============================================================================
RegisterNetEvent('sb_multicharacter:server:CreateCharacter', function(data)
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    if not license then
        TriggerClientEvent('sb_multicharacter:client:CreateError', src, 'No license found')
        return
    end

    -- Validate input data
    if not data or not data.charinfo or not data.skin then
        TriggerClientEvent('sb_multicharacter:client:CreateError', src, 'Invalid character data')
        return
    end

    -- Validate name length
    local firstname = data.charinfo.firstname or ''
    local lastname = data.charinfo.lastname or ''

    if #firstname < Config.MinNameLength or #firstname > Config.MaxNameLength then
        TriggerClientEvent('sb_multicharacter:client:CreateError', src, 'Invalid first name length')
        return
    end

    if #lastname < Config.MinNameLength or #lastname > Config.MaxNameLength then
        TriggerClientEvent('sb_multicharacter:client:CreateError', src, 'Invalid last name length')
        return
    end

    -- Sanitize name (alphanumeric and spaces only)
    firstname = firstname:gsub('[^%w%s]', ''):gsub('^%s*(.-)%s*$', '%1')
    lastname = lastname:gsub('[^%w%s]', ''):gsub('^%s*(.-)%s*$', '%1')

    -- Get user's character slots
    local user = SB.Functions.GetUser(src)
    local maxSlots = user and user.character_slots or Config.DefaultSlots

    -- Check current character count
    local charCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM players WHERE license = ?
    ]], { license })

    if charCount >= maxSlots then
        TriggerClientEvent('sb_multicharacter:client:CreateError', src, 'Maximum characters reached')
        return
    end

    -- Get next CID (character slot number)
    local maxCid = MySQL.scalar.await([[
        SELECT MAX(cid) FROM players WHERE license = ?
    ]], { license })

    local newCid = (maxCid or 0) + 1

    -- Generate unique identifiers
    local citizenid = SB.Functions.CreateCitizenId()
    local phone = SB.Functions.CreatePhoneNumber()
    local account = SB.Functions.CreateAccountNumber()

    -- Prepare character info
    local charinfo = {
        firstname = firstname,
        lastname = lastname,
        birthdate = data.charinfo.birthdate or '1990-01-01',
        gender = data.charinfo.gender or 0,
        nationality = data.charinfo.nationality or 'American',
        phone = phone,
        account = account
    }

    -- Prepare spawn position
    local spawnCoords = data.spawnLocation and data.spawnLocation.coords or Config.NewCharacterSpawn
    local position = {
        x = spawnCoords.x,
        y = spawnCoords.y,
        z = spawnCoords.z,
        w = spawnCoords.w or 0.0
    }

    -- Use sb_core defaults for money, job, gang, metadata
    local playerName = GetPlayerName(src)
    local defaultMoney = SBShared.DeepCopy(SB.Config.DefaultMoney)
    local defaultJob = SBShared.DeepCopy(SB.Config.DefaultJob)
    local defaultGang = SBShared.DeepCopy(SB.Config.DefaultGang)
    local defaultMetadata = SBShared.DeepCopy(SB.Config.DefaultMetadata)

    -- Insert character into database
    MySQL.insert.await([[
        INSERT INTO players (citizenid, cid, license, name, charinfo, money, job, gang, position, metadata, skin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        newCid,
        license,
        playerName,
        json.encode(charinfo),
        json.encode(defaultMoney),
        json.encode(defaultJob),
        json.encode(defaultGang),
        json.encode(position),
        json.encode(defaultMetadata),
        json.encode(data.skin)
    })

    -- Login the new character
    local Player = SB.Player.Login(src, citizenid)

    if Player then
        TriggerClientEvent('sb_multicharacter:client:CharacterCreated', src, citizenid, spawnCoords)
        SBShared.Debug('Character created: ' .. citizenid .. ' (' .. firstname .. ' ' .. lastname .. ')')
    else
        TriggerClientEvent('sb_multicharacter:client:CreateError', src, 'Failed to create character')
    end
end)

-- ============================================================================
-- DELETE CHARACTER
-- ============================================================================
RegisterNetEvent('sb_multicharacter:server:DeleteCharacter', function(citizenid)
    local src = source
    local license = SB.Functions.GetIdentifier(src, 'license')

    if not license then
        TriggerClientEvent('sb_multicharacter:client:DeleteError', src, 'No license found')
        return
    end

    if not Config.AllowDelete then
        TriggerClientEvent('sb_multicharacter:client:DeleteError', src, 'Character deletion is disabled')
        return
    end

    -- Verify character belongs to this player
    local result = MySQL.scalar.await([[
        SELECT license FROM players WHERE citizenid = ?
    ]], { citizenid })

    if result ~= license then
        TriggerClientEvent('sb_multicharacter:client:DeleteError', src, 'Character does not belong to you')
        return
    end

    -- Delete character and related data
    MySQL.query.await('DELETE FROM players WHERE citizenid = ?', { citizenid })
    MySQL.query.await('DELETE FROM player_vehicles WHERE citizenid = ?', { citizenid })

    -- Trigger event for other resources to clean up
    TriggerEvent('sb_multicharacter:server:CharacterDeleted', citizenid)

    TriggerClientEvent('sb_multicharacter:client:CharacterDeleted', src, citizenid)
    SBShared.Debug('Character deleted: ' .. citizenid)
end)

-- ============================================================================
-- CHECK IF NAME EXISTS (Optional validation)
-- ============================================================================
RegisterNetEvent('sb_multicharacter:server:CheckName', function(firstname, lastname)
    local src = source

    local exists = MySQL.scalar.await([[
        SELECT citizenid FROM players
        WHERE JSON_EXTRACT(charinfo, '$.firstname') = ?
        AND JSON_EXTRACT(charinfo, '$.lastname') = ?
        LIMIT 1
    ]], { firstname, lastname })

    TriggerClientEvent('sb_multicharacter:client:NameCheckResult', src, exists ~= nil)
end)

-- ============================================================================
-- GET CLOTHING OPTIONS (Get max drawables for components)
-- ============================================================================
SB.Functions.CreateCallback('sb_multicharacter:server:GetClothingData', function(source, cb, model)
    -- This is handled client-side as we need the ped
    cb(nil)
end)

-- ============================================================================
-- RESOURCE EVENTS
-- ============================================================================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^2[SB_MULTICHARACTER]^7 Multicharacter system started')
end)
