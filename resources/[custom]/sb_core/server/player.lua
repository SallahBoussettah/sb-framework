--[[
    Everyday Chaos RP - Player Class
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- PLAYER CLASS CONSTRUCTOR
-- ============================================================================
function SB.Player.CreatePlayer(PlayerData)
    local self = {}
    self.PlayerData = PlayerData
    self.Functions = {}

    -- ========================================================================
    -- MONEY FUNCTIONS
    -- ========================================================================

    function self.Functions.AddMoney(moneyType, amount, reason)
        reason = reason or 'unknown'
        amount = tonumber(amount)

        if not amount or amount <= 0 then
            return false
        end

        -- Round to 2 decimal places to prevent floating point errors
        amount = math.floor(amount * 100 + 0.5) / 100

        if not self.PlayerData.money[moneyType] then
            return false
        end

        self.PlayerData.money[moneyType] = math.floor((self.PlayerData.money[moneyType] + amount) * 100 + 0.5) / 100
        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnMoneyChange', self.PlayerData.source, moneyType, amount, 'add', reason)
        TriggerEvent('SB:Server:OnMoneyChange', self.PlayerData.source, moneyType, amount, 'add', reason)

        SBShared.Debug(string.format('Player %s | Added %s %s | Reason: %s',
            self.PlayerData.citizenid, amount, moneyType, reason))

        return true
    end

    function self.Functions.RemoveMoney(moneyType, amount, reason)
        reason = reason or 'unknown'
        amount = tonumber(amount)

        if not amount or amount <= 0 then
            return false
        end

        -- Round to 2 decimal places to prevent floating point errors
        amount = math.floor(amount * 100 + 0.5) / 100

        if not self.PlayerData.money[moneyType] then
            return false
        end

        if self.PlayerData.money[moneyType] < amount then
            return false
        end

        self.PlayerData.money[moneyType] = math.floor((self.PlayerData.money[moneyType] - amount) * 100 + 0.5) / 100
        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnMoneyChange', self.PlayerData.source, moneyType, amount, 'remove', reason)
        TriggerEvent('SB:Server:OnMoneyChange', self.PlayerData.source, moneyType, amount, 'remove', reason)

        SBShared.Debug(string.format('Player %s | Removed %s %s | Reason: %s',
            self.PlayerData.citizenid, amount, moneyType, reason))

        return true
    end

    function self.Functions.SetMoney(moneyType, amount, reason)
        reason = reason or 'unknown'
        amount = tonumber(amount)

        if not amount then
            return false
        end

        -- Round to 2 decimal places to prevent floating point errors
        amount = math.floor(amount * 100 + 0.5) / 100

        -- Only bank can go negative (debt), cash cannot
        if amount < 0 and moneyType ~= 'bank' then
            return false
        end

        if not self.PlayerData.money[moneyType] then
            return false
        end

        local difference = amount - self.PlayerData.money[moneyType]
        self.PlayerData.money[moneyType] = amount
        self.Functions.UpdatePlayerData()

        local operation = difference >= 0 and 'add' or 'remove'
        TriggerClientEvent('SB:Client:OnMoneyChange', self.PlayerData.source, moneyType, math.abs(difference), operation, reason)

        return true
    end

    function self.Functions.GetMoney(moneyType)
        if moneyType then
            return self.PlayerData.money[moneyType] or 0
        end
        return self.PlayerData.money
    end

    -- ========================================================================
    -- JOB FUNCTIONS
    -- ========================================================================

    function self.Functions.SetJob(jobName, grade)
        jobName = tostring(jobName)
        grade = tostring(grade or 0)

        local job = SBShared.Jobs[jobName]
        if not job then
            SBShared.Debug('Invalid job: ' .. jobName)
            return false
        end

        if not job.grades[grade] then
            SBShared.Debug('Invalid grade: ' .. grade .. ' for job: ' .. jobName)
            return false
        end

        local oldJob = self.PlayerData.job

        self.PlayerData.job = {
            name = jobName,
            label = job.label,
            payment = job.grades[grade].payment or 0,
            type = job.type or 'civ',
            onduty = job.defaultDuty or false,
            isboss = job.grades[grade].isboss or false,
            grade = {
                name = job.grades[grade].name,
                level = tonumber(grade)
            }
        }

        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
        TriggerEvent('SB:Server:OnJobUpdate', self.PlayerData.source, self.PlayerData.job, oldJob)

        SBShared.Debug(string.format('Player %s | Job changed to %s (Grade: %s)',
            self.PlayerData.citizenid, jobName, grade))

        return true
    end

    function self.Functions.SetJobDuty(onDuty)
        self.PlayerData.job.onduty = onDuty
        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnDutyChange', self.PlayerData.source, onDuty)
        TriggerEvent('SB:Server:OnDutyChange', self.PlayerData.source, onDuty)

        return true
    end

    function self.Functions.GetJob()
        return self.PlayerData.job
    end

    -- ========================================================================
    -- GANG FUNCTIONS
    -- ========================================================================

    function self.Functions.SetGang(gangName, grade)
        gangName = tostring(gangName)
        grade = tostring(grade or 0)

        local gang = SBShared.Gangs[gangName]
        if not gang then
            SBShared.Debug('Invalid gang: ' .. gangName)
            return false
        end

        if not gang.grades[grade] then
            SBShared.Debug('Invalid grade: ' .. grade .. ' for gang: ' .. gangName)
            return false
        end

        local oldGang = self.PlayerData.gang

        self.PlayerData.gang = {
            name = gangName,
            label = gang.label,
            isboss = gang.grades[grade].isboss or false,
            grade = {
                name = gang.grades[grade].name,
                level = tonumber(grade)
            }
        }

        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnGangUpdate', self.PlayerData.source, self.PlayerData.gang)
        TriggerEvent('SB:Server:OnGangUpdate', self.PlayerData.source, self.PlayerData.gang, oldGang)

        return true
    end

    function self.Functions.GetGang()
        return self.PlayerData.gang
    end

    -- ========================================================================
    -- METADATA FUNCTIONS
    -- ========================================================================

    function self.Functions.SetMetaData(key, value)
        if not self.PlayerData.metadata then
            self.PlayerData.metadata = {}
        end

        self.PlayerData.metadata[key] = value
        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnMetaDataChange', self.PlayerData.source, key, value)

        return true
    end

    function self.Functions.GetMetaData(key)
        if key then
            return self.PlayerData.metadata[key]
        end
        return self.PlayerData.metadata
    end

    function self.Functions.AddMetaData(key, amount)
        if not self.PlayerData.metadata[key] then
            self.PlayerData.metadata[key] = 0
        end

        self.PlayerData.metadata[key] = self.PlayerData.metadata[key] + amount
        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnMetaDataChange', self.PlayerData.source, key, self.PlayerData.metadata[key])

        return true
    end

    function self.Functions.RemoveMetaData(key, amount)
        if not self.PlayerData.metadata[key] then
            return false
        end

        self.PlayerData.metadata[key] = math.max(0, self.PlayerData.metadata[key] - amount)
        self.Functions.UpdatePlayerData()

        TriggerClientEvent('SB:Client:OnMetaDataChange', self.PlayerData.source, key, self.PlayerData.metadata[key])

        return true
    end

    -- ========================================================================
    -- INVENTORY FUNCTIONS (Placeholder - will be handled by sb_inventory)
    -- ========================================================================

    function self.Functions.AddItem(item, amount, slot, info)
        -- Will be overridden by inventory system
        SBShared.Debug('AddItem called - inventory system not loaded')
        return true
    end

    function self.Functions.RemoveItem(item, amount, slot)
        -- Will be overridden by inventory system
        SBShared.Debug('RemoveItem called - inventory system not loaded')
        return true
    end

    function self.Functions.HasItem(item, amount)
        -- Will be overridden by inventory system
        amount = amount or 1
        return false
    end

    function self.Functions.GetItemByName(item)
        -- Will be overridden by inventory system
        return nil
    end

    function self.Functions.GetItemsByName(item)
        -- Will be overridden by inventory system
        return {}
    end

    -- ========================================================================
    -- UTILITY FUNCTIONS
    -- ========================================================================

    function self.Functions.GetName()
        if self.PlayerData.charinfo then
            return self.PlayerData.charinfo.firstname .. ' ' .. self.PlayerData.charinfo.lastname
        end
        return self.PlayerData.name
    end

    function self.Functions.UpdatePlayerData()
        TriggerClientEvent('SB:Client:UpdatePlayerData', self.PlayerData.source, self.PlayerData)
    end

    function self.Functions.SetPlayerData(key, value)
        self.PlayerData[key] = value
        self.Functions.UpdatePlayerData()
    end

    function self.Functions.GetPlayerData()
        return self.PlayerData
    end

    function self.Functions.SetPosition(coords)
        self.PlayerData.position = coords
    end

    function self.Functions.GetPosition()
        return self.PlayerData.position
    end

    function self.Functions.Notify(message, type, duration)
        TriggerClientEvent('SB:Client:Notify', self.PlayerData.source, message, type, duration)
    end

    -- ========================================================================
    -- SAVE FUNCTION
    -- ========================================================================

    function self.Functions.Save()
        -- Get current position
        local ped = GetPlayerPed(self.PlayerData.source)
        if ped and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            self.PlayerData.position = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                w = heading
            }
        end

        MySQL.update.await([[
            UPDATE players SET
                money = ?,
                charinfo = ?,
                job = ?,
                gang = ?,
                position = ?,
                metadata = ?,
                skin = ?
            WHERE citizenid = ?
        ]], {
            json.encode(self.PlayerData.money),
            json.encode(self.PlayerData.charinfo),
            json.encode(self.PlayerData.job),
            json.encode(self.PlayerData.gang),
            json.encode(self.PlayerData.position),
            json.encode(self.PlayerData.metadata),
            json.encode(self.PlayerData.skin or {}),
            self.PlayerData.citizenid
        })

        SBShared.Debug('Saved player: ' .. self.PlayerData.citizenid)
    end

    -- ========================================================================
    -- LOGOUT FUNCTION
    -- ========================================================================

    function self.Functions.Logout()
        self.Functions.Save()

        TriggerClientEvent('SB:Client:OnPlayerUnload', self.PlayerData.source)
        TriggerEvent('SB:Server:OnPlayerUnload', self.PlayerData.source)

        SB.Players[self.PlayerData.source] = nil

        SBShared.Debug('Player logged out: ' .. self.PlayerData.citizenid)
    end

    return self
end

-- ============================================================================
-- PLAYER LOGIN FUNCTION
-- ============================================================================
function SB.Player.Login(source, citizenid, newData)
    if not source or source == 0 then
        return false
    end

    local license = SB.Functions.GetIdentifier(source, 'license')
    if not license then
        return false
    end

    local PlayerData

    if newData then
        -- New character
        PlayerData = SB.Player.CheckPlayerData(source, newData)
        PlayerData.citizenid = citizenid
        PlayerData.license = license
        PlayerData.name = GetPlayerName(source)

        -- Insert into database
        MySQL.insert.await([[
            INSERT INTO players (citizenid, cid, license, name, money, charinfo, job, gang, position, metadata, inventory, skin)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            PlayerData.citizenid,
            PlayerData.cid,
            PlayerData.license,
            PlayerData.name,
            json.encode(PlayerData.money),
            json.encode(PlayerData.charinfo),
            json.encode(PlayerData.job),
            json.encode(PlayerData.gang),
            json.encode(PlayerData.position),
            json.encode(PlayerData.metadata),
            json.encode(PlayerData.inventory or {}),
            json.encode(PlayerData.skin or {})
        })
    else
        -- Existing character
        local result = MySQL.single.await([[
            SELECT * FROM players WHERE citizenid = ? AND license = ?
        ]], { citizenid, license })

        if not result then
            return false
        end

        PlayerData = SB.Player.CheckPlayerData(source, {
            citizenid = result.citizenid,
            cid = result.cid,
            license = result.license,
            name = result.name,
            money = json.decode(result.money),
            charinfo = json.decode(result.charinfo),
            job = json.decode(result.job),
            gang = json.decode(result.gang),
            position = json.decode(result.position),
            metadata = json.decode(result.metadata),
            inventory = json.decode(result.inventory or '[]'),
            skin = json.decode(result.skin or '{}')
        })
    end

    -- Create player object
    local PlayerObj = SB.Player.CreatePlayer(PlayerData)
    SB.Players[source] = PlayerObj

    -- Update state bag (use native Player function)
    local playerState = Player(source).state
    playerState.isLoggedIn = true
    playerState.citizenid = PlayerData.citizenid

    -- Trigger events
    TriggerClientEvent('SB:Client:OnPlayerLoaded', source, PlayerData)
    TriggerEvent('SB:Server:OnPlayerLoaded', source, PlayerObj)

    SBShared.Debug('Player logged in: ' .. PlayerData.citizenid)

    return PlayerObj
end

-- ============================================================================
-- CHECK/VALIDATE PLAYER DATA
-- ============================================================================
function SB.Player.CheckPlayerData(source, data)
    data = data or {}

    local PlayerData = {
        source = source,
        citizenid = data.citizenid or SB.Functions.CreateCitizenId(),
        cid = data.cid or 1,
        license = data.license or SB.Functions.GetIdentifier(source, 'license'),
        name = data.name or GetPlayerName(source),
        money = data.money or SBShared.DeepCopy(Config.DefaultMoney),
        charinfo = data.charinfo or {},
        job = data.job or SBShared.DeepCopy(Config.DefaultJob),
        gang = data.gang or SBShared.DeepCopy(Config.DefaultGang),
        position = data.position or SBShared.DeepCopy(Config.DefaultSpawn),
        metadata = data.metadata or SBShared.DeepCopy(Config.DefaultMetadata),
        inventory = data.inventory or {},
        skin = data.skin or {}
    }

    -- Validate money
    for k, v in pairs(Config.DefaultMoney) do
        if PlayerData.money[k] == nil then
            PlayerData.money[k] = v
        end
    end

    -- Validate metadata
    for k, v in pairs(Config.DefaultMetadata) do
        if PlayerData.metadata[k] == nil then
            PlayerData.metadata[k] = v
        end
    end

    -- Generate fingerprint/wallet if missing
    if not PlayerData.metadata.fingerprint or PlayerData.metadata.fingerprint == '' then
        PlayerData.metadata.fingerprint = SBShared.RandomStr(10)
    end

    if not PlayerData.metadata.walletid or PlayerData.metadata.walletid == '' then
        PlayerData.metadata.walletid = 'EC-' .. SBShared.RandomStr(5)
    end

    if not PlayerData.metadata.bloodtype or PlayerData.metadata.bloodtype == 'Unknown' then
        PlayerData.metadata.bloodtype = SBShared.GetRandomBloodType()
    end

    return PlayerData
end
