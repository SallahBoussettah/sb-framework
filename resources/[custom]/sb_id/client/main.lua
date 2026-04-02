local SB = exports['sb_core']:GetCoreObject()

local cityHallNPC = nil
local isNUIOpen = false
local currentIDData = nil
local mugshotHandle = nil
local mugshotTxd = nil
local pendingBase64 = nil  -- Holds base64 result from NUI conversion
local playerHasID = false  -- Tracks if player has an ID card (for target menu)

-- ============================================================================
-- NPC SPAWN
-- ============================================================================

local function SpawnNPC()
    local loc = Config.Location
    local model = GetHashKey(Config.NPCModel)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end

    cityHallNPC = CreatePed(4, model, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.coords.w, false, true)
    SetEntityInvincible(cityHallNPC, true)
    FreezeEntityPosition(cityHallNPC, true)
    SetBlockingOfNonTemporaryEvents(cityHallNPC, true)
    SetPedFleeAttributes(cityHallNPC, 0, false)
    SetPedCombatAttributes(cityHallNPC, 46, true)
    SetPedCanPlayAmbientAnims(cityHallNPC, false)

    SetModelAsNoLongerNeeded(model)

    -- Sit on the chair using scenario
    TaskStartScenarioInPlace(cityHallNPC, 'PROP_HUMAN_SEAT_CHAIR_UPRIGHT', 0, true)

    -- Add target interactions — server callback determines which action to take
    exports['sb_target']:AddTargetEntity(cityHallNPC, {
        {
            name = 'id_apply',
            label = 'Apply for ID Card ($' .. Config.IDCost .. ')',
            icon = 'fa-id-card',
            distance = Config.InteractDistance,
            canInteract = function()
                return not playerHasID
            end,
            action = function(entity)
                SB.Functions.TriggerCallback('sb_id:server:checkStatus', function(status)
                    if status.hasID then
                        exports['sb_notify']:Notify('You already have an ID card', 'error', 3000)
                        playerHasID = true
                    elseif not status.canAfford then
                        exports['sb_notify']:Notify('Not enough cash. ID costs $' .. Config.IDCost, 'error', 3000)
                    else
                        StartIDApplication(false)
                    end
                end)
            end
        },
        {
            name = 'id_renew',
            label = 'Renew ID Card ($' .. Config.IDCost .. ')',
            icon = 'fa-rotate',
            distance = Config.InteractDistance,
            canInteract = function()
                return playerHasID
            end,
            action = function(entity)
                SB.Functions.TriggerCallback('sb_id:server:checkStatus', function(status)
                    if not status.hasID then
                        exports['sb_notify']:Notify('You don\'t have an ID card to renew', 'error', 3000)
                        playerHasID = false
                    elseif not status.canAfford then
                        exports['sb_notify']:Notify('Not enough cash. Renewal costs $' .. Config.IDCost, 'error', 3000)
                    else
                        StartIDApplication(true)
                    end
                end)
            end
        }
    })
end

-- ============================================================================
-- BLIP
-- ============================================================================

local function CreateBlip()
    local loc = Config.Location
    local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
    SetBlipSprite(blip, loc.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, loc.blip.scale)
    SetBlipColour(blip, loc.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(loc.blip.label)
    EndTextCommandSetBlipName(blip)
end

-- ============================================================================
-- PED CHARACTERISTICS DETECTION
-- ============================================================================

local HairColorNames = {
    [0] = 'BLK',   -- Black
    [1] = 'BLK',   -- Dark Black
    [2] = 'BRN',   -- Dark Brown
    [3] = 'BRN',   -- Brown
    [4] = 'LBR',   -- Light Brown
    [5] = 'BLD',   -- Blonde
    [6] = 'BLD',   -- Blonde
    [7] = 'BLD',   -- Light Blonde
    [8] = 'RED',   -- Red
    [9] = 'RED',   -- Light Red
    [10] = 'RED',  -- Pink Red
    [11] = 'BLK',  -- Dark Blonde
    [12] = 'AUB',  -- Auburn
    [13] = 'BLD',  -- Platinum Blonde
    [14] = 'BRN',  -- Medium Brown
    [15] = 'GRY',  -- Gray
}

local EyeColorNames = {
    [0] = 'GRN',   -- Green
    [1] = 'BRN',   -- Brown
    [2] = 'BLU',   -- Blue
    [3] = 'BRN',   -- Dark Brown
    [4] = 'HZL',   -- Hazel
    [5] = 'GRN',   -- Light Green
    [6] = 'GRY',   -- Gray
    [7] = 'BLU',   -- Light Blue
}

local function GetPedCharacteristics()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)

    -- Gender detection
    local isFemale = (model == GetHashKey('mp_f_freemode_01'))
    local sex = isFemale and 'F' or 'M'

    -- Hair color
    local hairIndex = GetPedHairColor(ped)
    local hairColor = HairColorNames[hairIndex] or 'BRN'

    -- Eye color
    local eyeIndex = GetPedEyeColor(ped)
    local eyeColor = EyeColorNames[eyeIndex] or 'BRN'

    -- Height (no native — generate based on gender, seeded by citizenid for consistency)
    local playerData = SB.Functions.GetPlayerData()
    local cid = playerData.citizenid or '00000'
    local seed = 0
    for i = 1, #cid do
        seed = seed + string.byte(cid, i)
    end
    math.randomseed(seed)

    local heightInches, weight
    if isFemale then
        heightInches = math.random(60, 69)   -- 5'0" to 5'9"
        weight = math.random(110, 155)
    else
        heightInches = math.random(66, 76)   -- 5'6" to 6'4"
        weight = math.random(150, 220)
    end

    -- Reset random seed so we don't affect other systems
    math.randomseed(GetGameTimer())

    local feet = math.floor(heightInches / 12)
    local inches = heightInches % 12
    local height = feet .. "'" .. string.format('%02d', inches) .. '"'

    return {
        sex = sex,
        hair = hairColor,
        eyes = eyeColor,
        height = height,
        weight = weight .. ' lb'
    }
end

-- ============================================================================
-- MUGSHOT CAPTURE
-- ============================================================================

-- Clear any existing headshot handles to prevent leaks
local function ClearHeadshots()
    for i = 1, 32 do
        if IsPedheadshotValid(i) then
            UnregisterPedheadshot(i)
        end
    end
end

-- Capture a headshot and return the nui-img URL + handle
local function CaptureHeadshot(cb)
    ClearHeadshots()
    local ped = PlayerPedId()
    local handle = RegisterPedheadshotTransparent(ped)

    local timeout = 50 -- 5 seconds max
    while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end

    if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
        local txd = GetPedheadshotTxdString(handle)
        local url = string.format('https://nui-img/%s/%s', txd, txd)
        mugshotHandle = handle
        mugshotTxd = txd
        cb(url, handle)
    else
        UnregisterPedheadshot(handle)
        cb(nil, nil)
    end
end

-- Convert a nui-img URL to base64 via NUI, returns base64 string
local function CaptureBase64(cb)
    CaptureHeadshot(function(url, handle)
        if not url then
            cb(nil)
            return
        end

        -- Ask NUI to convert the nui-img URL to base64
        pendingBase64 = nil
        SendNUIMessage({
            action = 'convertBase64',
            imgUrl = url,
            handle = handle
        })

        -- Wait for NUI callback
        local timer = 50 -- 5 seconds max
        while pendingBase64 == nil and timer > 0 do
            Wait(100)
            timer = timer - 1
        end

        local result = pendingBase64
        pendingBase64 = nil
        cb(result)
    end)
end

-- NUI callback for base64 conversion result
RegisterNUICallback('base64Result', function(data, cb)
    if data.base64 and data.base64 ~= '' then
        pendingBase64 = data.base64
    else
        pendingBase64 = false  -- Signal failure (not nil, so the wait loop exits)
    end

    -- Unregister the headshot handle
    if data.handle then
        UnregisterPedheadshot(data.handle)
        if mugshotHandle == data.handle then
            mugshotHandle = nil
            mugshotTxd = nil
        end
    end

    cb('ok')
end)

local function ReleaseMugshot()
    if mugshotHandle then
        UnregisterPedheadshot(mugshotHandle)
        mugshotHandle = nil
        mugshotTxd = nil
    end
end

-- ============================================================================
-- NUI CONTROL
-- ============================================================================

local function OpenNUI()
    isNUIOpen = true
    SetNuiFocus(true, true)
    TriggerEvent('sb_hud:setVisible', false)
end

local function CloseNUI()
    isNUIOpen = false
    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'close' })
    ReleaseMugshot()
    currentIDData = nil
end

-- ============================================================================
-- ID APPLICATION FLOW
-- ============================================================================

function StartIDApplication(isRenewal)
    -- Capture mugshot first with progress bar
    exports['sb_progressbar']:Start({
        duration = 3000,
        label = 'Taking photo...',
        canCancel = false,
        anim = {
            dict = 'mp_facial',
            clip = 'mic_chatter',
            flag = 49
        },
        onComplete = function()
            -- Detect ped physical characteristics
            local chars = GetPedCharacteristics()

            -- Capture base64 mugshot
            CaptureBase64(function(base64)
                OpenNUI()
                SendNUIMessage({
                    action = 'openForm',
                    isRenewal = isRenewal,
                    cost = Config.IDCost,
                    mugshotBase64 = base64 or '',
                    characteristics = chars
                })
            end)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('ID application cancelled', 'info', 2000)
        end
    })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('submitApplication', function(data, cb)
    CloseNUI()

    local address = data.address
    if not address or #address < 3 then
        exports['sb_notify']:Notify('Please enter a valid address', 'error', 3000)
        cb('ok')
        return
    end

    local mugshotData = data.mugshotBase64 or ''
    local chars = data.characteristics or {}
    local cardTheme = data.cardTheme or 'white'

    exports['sb_progressbar']:Start({
        duration = 5000,
        label = 'Processing ID application...',
        canCancel = false,
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a',
            flag = 49
        },
        onComplete = function()
            if data.isRenewal then
                TriggerServerEvent('sb_id:server:renewID', address, mugshotData, chars, cardTheme)
            else
                TriggerServerEvent('sb_id:server:requestID', address, mugshotData, chars, cardTheme)
            end
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Application cancelled', 'info', 2000)
        end
    })

    cb('ok')
end)

-- ============================================================================
-- VIEW OWN ID (from inventory use)
-- ============================================================================

RegisterNetEvent('sb_id:client:viewID', function(idData, expired)
    if isNUIOpen then return end
    currentIDData = idData

    -- Check if this card belongs to the local player
    local playerData = SB.Functions.GetPlayerData()
    local isOwner = playerData.citizenid == idData.citizenid

    if isOwner then
        -- Self-view: capture a fresh live headshot URL
        CaptureHeadshot(function(liveUrl, handle)
            OpenNUI()
            SendNUIMessage({
                action = 'showCard',
                data = idData,
                expired = expired or false,
                mugshot = idData.mugshot or '',
                liveMugshotUrl = liveUrl or '',
                isSelfView = true
            })
        end)
    else
        -- Viewing someone else's card: use stored base64 only
        OpenNUI()
        SendNUIMessage({
            action = 'showCard',
            data = idData,
            expired = expired or false,
            mugshot = idData.mugshot or '',
            liveMugshotUrl = '',
            isSelfView = false
        })
    end
end)

-- ============================================================================
-- RECEIVE SHOWN ID (from another player)
-- ============================================================================

RegisterNetEvent('sb_id:client:receiveShownID', function(idData, expired)
    if isNUIOpen then return end

    OpenNUI()
    SendNUIMessage({
        action = 'showCard',
        data = idData,
        expired = expired,
        mugshot = idData.mugshot or '',          -- Stored base64 from issuance
        liveMugshotUrl = '',                      -- No live URL for other players
        isSelfView = false
    })

    -- Auto-close after configured time
    SetTimeout(Config.AutoCloseTime * 1000, function()
        if isNUIOpen then
            CloseNUI()
        end
    end)
end)

-- ============================================================================
-- SHOW ID TO NEARBY PLAYER (command)
-- ============================================================================

local function ShowIDToNearby()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDist = Config.ShowDistance + 1

    local players = GetActivePlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)
            if dist < closestDist then
                closestDist = dist
                closestPlayer = GetPlayerServerId(playerId)
            end
        end
    end

    if not closestPlayer then
        exports['sb_notify']:Notify('No one nearby to show your ID to', 'info', 3000)
        return
    end

    TriggerServerEvent('sb_id:server:showIDToPlayer', closestPlayer)
end

RegisterCommand('showid', function()
    ShowIDToNearby()
end, false)

TriggerEvent('chat:addSuggestion', '/showid', 'Show your ID card to the nearest player')

-- ============================================================================
-- ID STATUS SYNC
-- ============================================================================

local function RefreshIDStatus()
    SB.Functions.TriggerCallback('sb_id:server:checkStatus', function(status)
        if status then
            playerHasID = status.hasID
        end
    end)
end

-- Refresh when inventory slot updates (item added/removed)
RegisterNetEvent('sb_inventory:client:updateSlot', function()
    RefreshIDStatus()
end)

-- Refresh when inventory fully refreshes (transfers, etc.)
RegisterNetEvent('sb_inventory:client:refreshInventory', function()
    RefreshIDStatus()
end)

-- ============================================================================
-- INIT
-- ============================================================================

CreateThread(function()
    SpawnNPC()
    CreateBlip()

    -- Initial ID status check once player is loaded
    Wait(2000)
    RefreshIDStatus()
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if cityHallNPC and DoesEntityExist(cityHallNPC) then
        DeleteEntity(cityHallNPC)
    end
    ReleaseMugshot()
    if isNUIOpen then
        CloseNUI()
    end
end)
