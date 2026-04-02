--[[
    Everyday Chaos RP - Status Circles + Vehicle Dashboard HUD
    Author: Salah Eddine Boussettah
    Version: 2.0.0
]]

local SB = exports['sb_core']:GetCoreObject()

-- Refresh SB object when sb_core restarts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local isHudVisible = false
local isCinematicMode = false
local isUIReady = false
local currentVoiceRange = Config.DefaultVoiceRange
local lastMoney = { cash = 0 }
local moneyChanged = false

-- Combat/Activity tracking
local isInCombat = false
local lastHealth = 200
local combatTimeout = 0
local showHudUntil = 0

-- Seatbelt state
local isSeatbeltOn = false
exports('IsSeatbeltOn', function() return isSeatbeltOn end)

-- Needs display timer
local lastNeedsShow = 0
local NEEDS_INTERVAL = 10000
local NEEDS_DURATION = 3000

-- Stamina tracking
local playerStamina = 100.0
local STAMINA_DRAIN_PER_SEC = 3.25  -- Per second while sprinting (~30s to deplete)
local STAMINA_REGEN_PER_SEC = 5.0   -- Per second while not sprinting (~20s to recover)
local STAMINA_RESUME = 20
local staminaDepleted = false

-- Jump stamina cost
local JUMP_COST_BASE = 2.0
local JUMP_COST_SPAM = 5.0
local JUMP_SPAM_WINDOW = 3000
local jumpTimestamps = {}

-- HUD Editor state
local isEditorOpen = false

-- Minimap scaleform (hide native health/armor)
local minimapScaleform = nil

-- Load saved positions from KVP
local function LoadHudPositions()
    local saved = GetResourceKvpString('sb_hud_positions')
    if saved then
        SendNUIMessage({
            action = 'loadPositions',
            positions = saved
        })
    end
end

-- Save positions to KVP
local function SaveHudPositions(positionsJson)
    SetResourceKvp('sb_hud_positions', positionsJson)
end

-- ============================================================================
-- PER-FRAME LOOP (minimal - only natives that REQUIRE per-frame calls)
-- ============================================================================
CreateThread(function()
    while not SB.Functions.IsLoggedIn() do
        Wait(500)
    end

    -- Wait a bit more for the game to fully initialize
    Wait(1000)

    -- Force enable radar/minimap
    DisplayRadar(true)
    SetRadarBigmapEnabled(false, false)
    SetRadarZoom(0)

    -- Reset minimap to default rectangular (undo any previous circular minimap)
    SetMinimapClipType(0)
    -- Remove any old texture replacements
    RemoveReplaceTexture("platform:/textures/graphics", "radarmasksm")
    RemoveReplaceTexture("platform:/textures/graphics", "circlemap")
    -- Reset minimap position/size to GTA defaults
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045, 0.002, 0.150, 0.188888)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.020, 0.032, 0.111, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.03, 0.022, 0.266, 0.237)
    DisplayRadar(true)

    -- Load scaleform to hide native health/armor on minimap
    if not HasScaleformMovieLoaded(minimapScaleform) then
        minimapScaleform = RequestScaleformMovie("minimap")
        while not HasScaleformMovieLoaded(minimapScaleform) do
            Wait(100)
        end
    end

    local cachedPlayerId = PlayerId()

    while true do
        Wait(0)

        -- Hide native health/armor bars on minimap (GTA resets this every frame)
        if minimapScaleform then
            BeginScaleformMovieMethod(minimapScaleform, "SETUP_HEALTH_ARMOUR")
            ScaleformMovieMethodAddParamInt(3)
            EndScaleformMovieMethod()
        end

        -- Hide default GTA HUD elements (MUST be per-frame)
        HideHudComponentThisFrame(1)  -- Wanted Stars
        HideHudComponentThisFrame(2)  -- Weapon Icon
        HideHudComponentThisFrame(3)  -- Cash
        HideHudComponentThisFrame(4)  -- MP Cash
        HideHudComponentThisFrame(6)  -- Vehicle Name
        HideHudComponentThisFrame(7)  -- Area Name
        HideHudComponentThisFrame(8)  -- Vehicle Class
        HideHudComponentThisFrame(9)  -- Street Name

        if not IsPlayerFreeAiming(cachedPlayerId) then
            HideHudComponentThisFrame(14) -- Reticle
        end

        -- Block sprint when custom stamina depleted (MUST be per-frame)
        if staminaDepleted then
            DisableControlAction(0, 21, true)
        end
    end
end)

-- ============================================================================
-- JUMP DETECTION (100ms loop - no need for per-frame)
-- ============================================================================
CreateThread(function()
    while not SB.Functions.IsLoggedIn() do
        Wait(500)
    end

    local wasJumping = false

    while true do
        Wait(100)

        local isJumping = IsPedJumping(PlayerPedId())
        if isJumping and not wasJumping then
            local now = GetGameTimer()
            -- Filter old timestamps
            local recent = {}
            for i = 1, #jumpTimestamps do
                if now - jumpTimestamps[i] < JUMP_SPAM_WINDOW then
                    recent[#recent + 1] = jumpTimestamps[i]
                end
            end
            recent[#recent + 1] = now
            jumpTimestamps = recent

            local cost = #jumpTimestamps >= 3 and JUMP_COST_SPAM or JUMP_COST_BASE
            playerStamina = math.max(0, playerStamina - cost)
            if playerStamina <= 0 then
                staminaDepleted = true
            end
        end
        wasJumping = isJumping
    end
end)

-- ============================================================================
-- INITIALIZE HUD
-- ============================================================================
CreateThread(function()
    while not SB.Functions.IsLoggedIn() do
        Wait(500)
    end

    Wait(1000)

    SendNUIMessage({
        action = 'initHUD',
        config = {
            position = Config.Position,
            colors = Config.Colors,
            showHealth = Config.ShowHealth,
            showArmor = Config.ShowArmor,
            showHunger = Config.ShowHunger,
            showThirst = Config.ShowThirst,
            showStamina = Config.ShowStamina,
            showStress = Config.ShowStress,
            showMoney = Config.ShowMoney,
            showJob = Config.ShowJob,
            showVoice = Config.ShowVoice,
            voiceRanges = Config.VoiceRanges,
            statusOffset = Config.StatusIconsOffset,
            speedUnit = Config.SpeedUnit,
            maxSpeed = Config.MaxSpeed
        }
    })

    isUIReady = true
    LoadHudPositions()

    local PlayerData = SB.Functions.GetPlayerData()
    if PlayerData and PlayerData.money then
        lastMoney.cash = PlayerData.money.cash or 0
    end
end)

-- ============================================================================
-- NATIVE STAMINA OVERRIDE (Stats + periodic restore, NOT per-frame)
-- ============================================================================
CreateThread(function()
    while not SB.Functions.IsLoggedIn() do
        Wait(1000)
    end

    local staminaHash = GetHashKey('MP0_STAMINA')
    local lungHash = GetHashKey('MP0_LUNG_CAPACITY')
    StatSetInt(staminaHash, 100, true)
    StatSetInt(lungHash, 100, true)

    while true do
        Wait(500)
        if not staminaDepleted then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        StatSetInt(staminaHash, 100, true)
        StatSetInt(lungHash, 100, true)
    end
end)

-- ============================================================================
-- UPDATE LOOP (optimized: delta-time stamina, aggressive dirty-checking)
-- ============================================================================
local wasPaused = false

-- Pre-allocate NUI message tables
local hudJobData = { name = 'Unemployed', label = 'Unemployed', onDuty = false }
local hudData = {
    health = 0, armor = 0, hunger = 100, thirst = 100,
    stamina = 100, stress = 0, cash = 0, playerId = 0,
    moneyChanged = false, inCombat = false, showHud = false,
    showNeeds = false, showMoney = false, inVehicle = false,
    vehicleType = 'car', -- 'car', 'bike', 'bicycle'
    speed = 0, rpm = 0, fuel = 100, gear = 0, engineHealth = 1000,
    seatbelt = false, job = hudJobData, voiceRange = 1, isTalking = false
}
local hudMessage = { action = 'updateHUD', data = hudData }

-- Cache previous values for dirty-checking
local prevHealth, prevArmor, prevStamina = 0, 0, 100
local prevHunger, prevThirst, prevStress = 100, 100, 0
local prevInVehicle, prevSpeed, prevGear, prevRpm = false, 0, 0, 0
local prevShowHud = false
local prevCombat = false
local prevTalking = false

-- Stamina timing
local lastStaminaUpdate = 0

CreateThread(function()
    while not isUIReady do
        Wait(500)
    end

    local playerId = PlayerId()
    local serverId = GetPlayerServerId(playerId)
    lastStaminaUpdate = GetGameTimer()

    while true do
        local updateRate = Config.UpdateInterval

        local isPaused = IsPauseMenuActive() or GetPauseMenuState() > 0
        if isPaused then
            if not wasPaused then
                SendNUIMessage({ action = 'hideHUD' })
                wasPaused = true
            end
            Wait(500)
            goto continue
        elseif wasPaused then
            wasPaused = false
            SendNUIMessage({ action = 'showHUD' })
            Wait(100)
            goto continue
        end

        if isHudVisible and not isCinematicMode and not isEditorOpen and SB.Functions.IsLoggedIn() then
            local playerPed = PlayerPedId()
            local PlayerData = SB.Functions.GetPlayerData()
            local currentTime = GetGameTimer()

            -- Get health (only call native once)
            local rawHealth = GetEntityHealth(playerPed)
            local health = rawHealth - 100
            if health < 0 then health = 0 elseif health > 100 then health = 100 end

            local armor = GetPedArmour(playerPed)
            if armor > 100 then armor = 100 end

            -- Get metadata
            local hunger, thirst, stress = 100, 100, 0
            local meta = PlayerData and PlayerData.metadata
            if meta then
                hunger = meta.hunger or 100
                thirst = meta.thirst or 100
                stress = meta.stress or 0
            end

            -- Get money
            local cash = 0
            local money = PlayerData and PlayerData.money
            if money then
                cash = money.cash or 0
            end

            -- Money change detection
            if cash ~= lastMoney.cash then
                moneyChanged = true
                lastMoney.cash = cash
                showHudUntil = currentTime + 5000
            end

            -- Combat detection (uses cached rawHealth)
            local inCombat = false
            if IsPedShooting(playerPed) or IsPlayerFreeAiming(playerId) or IsPedInMeleeCombat(playerPed) then
                inCombat = true
            elseif rawHealth < lastHealth then
                inCombat = true
            elseif GetSelectedPedWeapon(playerPed) ~= `WEAPON_UNARMED` then
                inCombat = true
            end
            lastHealth = rawHealth

            if inCombat then
                combatTimeout = currentTime + 5000
            end
            isInCombat = currentTime < combatTimeout

            -- Delta-time stamina tracking with stress multiplier
            local dt = (currentTime - lastStaminaUpdate) / 1000.0 -- seconds
            lastStaminaUpdate = currentTime

            -- Get stress-based stamina multiplier from sb_metabolism
            local staminaMultiplier = 1.0
            if GetResourceState('sb_metabolism') == 'started' then
                local ok, mult = pcall(function()
                    return exports['sb_metabolism']:GetStressStaminaMultiplier()
                end)
                if ok and mult then staminaMultiplier = mult end
            end

            local isSprinting = IsPedSprinting(playerPed)
            if isSprinting and not staminaDepleted then
                playerStamina = playerStamina - (STAMINA_DRAIN_PER_SEC * staminaMultiplier * dt)
                if playerStamina < 0 then
                    playerStamina = 0
                    staminaDepleted = true
                end
            elseif not isSprinting then
                if playerStamina < 100 then
                    playerStamina = playerStamina + (STAMINA_REGEN_PER_SEC * dt)
                    if playerStamina > 100 then playerStamina = 100 end
                end
                if staminaDepleted and playerStamina >= STAMINA_RESUME then
                    staminaDepleted = false
                end
            end

            -- Round stamina to nearest 5 to reduce NUI update frequency
            local staminaInt = math.floor(playerStamina / 5 + 0.5) * 5

            -- HUD visibility logic
            local shouldShowHud = isInCombat or health < 100 or armor > 0 or
                                  hunger <= 25 or thirst <= 25 or stress > 0 or
                                  staminaInt < 100 or currentTime < showHudUntil

            -- Needs display (every 10 seconds)
            local showNeeds = false
            if currentTime - lastNeedsShow >= NEEDS_INTERVAL then
                lastNeedsShow = currentTime
                showNeeds = true
                showHudUntil = currentTime + NEEDS_DURATION + 500
                shouldShowHud = true
                SendNUIMessage({ action = 'showNeeds', duration = NEEDS_DURATION })
            end
            if hunger <= 25 or thirst <= 25 then
                showNeeds = true
            end

            -- Vehicle data
            local inVehicle = IsPedInAnyVehicle(playerPed, false)
            local speed, rpm, fuel, gear, engineHealth, seatbelt = 0, 0, 100, 0, 1000, false
            local vehicleType = 'car'

            if inVehicle then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local vehModel = GetEntityModel(vehicle)

                -- Determine vehicle type (model-based, handles emergency bikes etc.)
                if IsThisModelABicycle(vehModel) then
                    vehicleType = 'bicycle'
                elseif IsThisModelABike(vehModel) then
                    vehicleType = 'bike'
                end

                speed = math.floor(GetEntitySpeed(vehicle) * Config.SpeedMultiplier)
                rpm = GetVehicleCurrentRpm(vehicle)
                gear = GetVehicleCurrentGear(vehicle)
                fuel = GetVehicleFuelLevel(vehicle)
                if fuel <= 0 then fuel = 100 end
                engineHealth = GetVehicleEngineHealth(vehicle)
                seatbelt = isSeatbeltOn
                shouldShowHud = true
            end

            -- Voice check (always poll for real-time update)
            local isTalking = NetworkIsPlayerTalking(playerId)

            -- Dirty check: only send NUI update if something meaningful changed
            local dirty = health ~= prevHealth or armor ~= prevArmor or
                          staminaInt ~= prevStamina or hunger ~= prevHunger or
                          thirst ~= prevThirst or stress ~= prevStress or
                          inVehicle ~= prevInVehicle or
                          shouldShowHud ~= prevShowHud or isInCombat ~= prevCombat or
                          isTalking ~= prevTalking or
                          moneyChanged or showNeeds

            -- Vehicle speed/gear/rpm changes
            if inVehicle and (speed ~= prevSpeed or gear ~= prevGear or math.abs(rpm - prevRpm) > 0.02) then
                dirty = true
            end

            if dirty then
                prevTalking = isTalking

                -- Update cached previous values
                prevHealth = health
                prevArmor = armor
                prevStamina = staminaInt
                prevHunger = hunger
                prevThirst = thirst
                prevStress = stress
                prevInVehicle = inVehicle
                prevShowHud = shouldShowHud
                prevCombat = isInCombat
                prevSpeed = speed
                prevGear = gear
                prevRpm = rpm

                -- Job info
                local job = PlayerData and PlayerData.job
                hudJobData.name = job and job.name or 'unemployed'
                hudJobData.label = job and job.label or 'Unemployed'
                hudJobData.onDuty = job and job.onduty or false

                -- Update pre-allocated table fields
                hudData.health = health
                hudData.armor = armor
                hudData.hunger = hunger
                hudData.thirst = thirst
                hudData.stamina = staminaInt
                hudData.stress = stress
                hudData.cash = cash
                hudData.playerId = serverId
                hudData.moneyChanged = moneyChanged
                hudData.inCombat = isInCombat
                hudData.showHud = shouldShowHud
                hudData.showNeeds = showNeeds
                hudData.showMoney = currentTime < showHudUntil or moneyChanged
                hudData.inVehicle = inVehicle
                hudData.vehicleType = vehicleType
                hudData.speed = speed
                hudData.rpm = rpm
                hudData.fuel = fuel
                hudData.gear = gear
                hudData.engineHealth = engineHealth
                hudData.seatbelt = seatbelt
                hudData.voiceRange = currentVoiceRange
                hudData.isTalking = isTalking

                SendNUIMessage(hudMessage)

                if moneyChanged then
                    moneyChanged = false
                end
            end
        end

        ::continue::
        Wait(updateRate)
    end
end)

-- ============================================================================
-- CINEMATIC MODE (Hide HUD)
-- ============================================================================
RegisterCommand('togglehud', function()
    isCinematicMode = not isCinematicMode

    SendNUIMessage({
        action = 'setCinematicMode',
        enabled = isCinematicMode
    })

    DisplayRadar(not isCinematicMode)
end, false)

RegisterKeyMapping('togglehud', 'Toggle HUD (Cinematic Mode)', 'keyboard', Config.CinematicKey)

-- ============================================================================
-- HUD EDITOR (Drag & Resize)
-- ============================================================================
RegisterCommand('hudeditor', function()
    if isEditorOpen then return end
    isEditorOpen = true

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openEditor'
    })
end, false)

RegisterNUICallback('editorSave', function(data, cb)
    SaveHudPositions(data.positions)
    isEditorOpen = false
    SetNuiFocus(false, false)
    if GetResourceState('sb_notify') == 'started' then
        exports['sb_notify']:Notify('HUD layout saved!', 'success', 2000)
    end
    cb('ok')
end)

RegisterNUICallback('editorCancel', function(data, cb)
    isEditorOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('editorReset', function(data, cb)
    DeleteResourceKvp('sb_hud_positions')
    if GetResourceState('sb_notify') == 'started' then
        exports['sb_notify']:Notify('HUD layout reset to default', 'info', 2000)
    end
    cb('ok')
end)

-- ============================================================================
-- SEATBELT SYSTEM
-- ============================================================================
local seatbeltCooldown = 0
local lastExitAttempt = 0

-- Apply seatbelt protection
local function ApplySeatbeltProtection(ped, enabled)
    if enabled then
        -- SEATBELT ON: Protect player
        SetPedConfigFlag(ped, 32, false)           -- Can NOT fly through windshield
        SetPedCanBeKnockedOffVehicle(ped, 1)       -- Can NOT be knocked off bike
        SetPedCanBeDraggedOut(ped, false)          -- Can NOT be dragged out
        SetPedCanRagdoll(ped, false)               -- Can NOT ragdoll
        -- Disable windshield ejection params
        SetFlyThroughWindscreenParams(100000.0, 100000.0, 100.0, 100.0)  -- Nearly impossible to eject
    else
        -- SEATBELT OFF: Remove protection (can fly out)
        SetPedConfigFlag(ped, 32, true)            -- CAN fly through windshield
        SetPedCanBeKnockedOffVehicle(ped, 0)       -- CAN be knocked off bike
        SetPedCanBeDraggedOut(ped, true)           -- CAN be dragged out
        SetPedCanRagdoll(ped, true)                -- CAN ragdoll
        -- Enable windshield ejection params - lower values = easier to eject
        SetFlyThroughWindscreenParams(10.0, 10.0, 10.0, 10.0)  -- Easy to eject on collision
    end
end

-- Toggle seatbelt
RegisterCommand('seatbelt', function()
    local currentTime = GetGameTimer()
    if currentTime < seatbeltCooldown then return end
    seatbeltCooldown = currentTime + 500

    local playerPed = PlayerPedId()
    if not IsPedInAnyVehicle(playerPed, false) then return end

    isSeatbeltOn = not isSeatbeltOn
    ApplySeatbeltProtection(playerPed, isSeatbeltOn)

    if isSeatbeltOn then
        -- Seatbelt click sound
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        if GetResourceState('sb_notify') == 'started' then
            exports['sb_notify']:Notify('Seatbelt fastened', 'success', 2000)
        end
    else
        -- Seatbelt release sound
        PlaySoundFrontend(-1, "NAV_LEFT_RIGHT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        if GetResourceState('sb_notify') == 'started' then
            exports['sb_notify']:Notify('Seatbelt removed', 'info', 2000)
        end
    end
end, false)

RegisterKeyMapping('seatbelt', 'Toggle Seatbelt', 'keyboard', 'B')

-- Block vehicle exit while seatbelt is on + manage seatbelt state
CreateThread(function()
    local wasInVehicle = false

    while true do
        local sleep = 200
        local playerPed = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(playerPed, false)

        if inVehicle then
            -- Just entered vehicle - ensure NO protection (can fly out without seatbelt)
            if not wasInVehicle then
                isSeatbeltOn = false
                ApplySeatbeltProtection(playerPed, false)  -- Ensure can fly through windshield
            end

            -- Block exit if seatbelt is on
            if isSeatbeltOn then
                sleep = 0
                -- Disable F (exit vehicle) and other exit controls
                DisableControlAction(0, 75, true)  -- F - Exit vehicle
                DisableControlAction(0, 231, true) -- F - Exit vehicle alternate

                -- Show message if they try to exit
                if IsDisabledControlJustPressed(0, 75) or IsDisabledControlJustPressed(0, 231) then
                    local now = GetGameTimer()
                    if now - lastExitAttempt > 2000 then
                        lastExitAttempt = now
                        if GetResourceState('sb_notify') == 'started' then
                            exports['sb_notify']:Notify('Remove seatbelt first (B)', 'error', 2000)
                        end
                    end
                end
            end
        else
            -- Reset seatbelt and ALL protection when exiting vehicle
            if wasInVehicle then
                isSeatbeltOn = false
                ApplySeatbeltProtection(playerPed, false)  -- Reset all protection
            end
        end

        wasInVehicle = inVehicle
        Wait(sleep)
    end
end)

-- ============================================================================
-- VOICE RANGE CONTROL (pma-voice integration)
-- ============================================================================

-- Listen to pma-voice proximity cycle event
AddEventHandler('pma-voice:setTalkingMode', function(mode)
    if mode >= 1 and mode <= #Config.VoiceRanges then
        currentVoiceRange = mode
        -- Immediate NUI update for voice range
        SendNUIMessage({ action = 'updateVoice', voiceRange = currentVoiceRange, isTalking = NetworkIsPlayerTalking(PlayerId()) })
        local range = Config.VoiceRanges[currentVoiceRange]
        if GetResourceState('sb_notify') == 'started' then
            exports['sb_notify']:Notify('Voice: ' .. range.label, 'info', 2000)
        end
    end
end)

-- voicerange command triggers pma-voice's cycle
RegisterCommand('voicerange', function()
    ExecuteCommand('cycleproximity')
end, false)

-- ============================================================================
-- EVENTS FROM SB_CORE
-- ============================================================================

RegisterNetEvent('SB:Client:OnMoneyChange', function(moneyType, amount, operation, reason)
    moneyChanged = true
    showHudUntil = GetGameTimer() + 5000
end)

RegisterNetEvent('SB:Client:OnPlayerLoaded', function(PlayerData)
    Wait(500)
    isHudVisible = true

    if PlayerData and PlayerData.money then
        lastMoney.cash = PlayerData.money.cash or 0
    end

    SendNUIMessage({
        action = 'showHUD'
    })
end)

RegisterNetEvent('SB:Client:OnPlayerUnload', function()
    isHudVisible = false
    SendNUIMessage({
        action = 'hideHUD'
    })
end)

RegisterNetEvent('SB:Client:OnJobUpdate', function(job)
end)

RegisterNetEvent('SB:Client:OnMetaDataChange', function(key, value)
end)

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================
RegisterNUICallback('uiReady', function(data, cb)
    isUIReady = true
    cb('ok')
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================
exports('IsHudVisible', function()
    return isHudVisible and not isCinematicMode
end)

exports('SetHudVisible', function(visible)
    isHudVisible = visible
    SendNUIMessage({
        action = visible and 'showHUD' or 'hideHUD'
    })
end)

exports('GetVoiceRange', function()
    return currentVoiceRange, Config.VoiceRanges[currentVoiceRange]
end)

exports('ForceShowHud', function(duration)
    showHudUntil = GetGameTimer() + (duration or 5000)
end)

exports('UpdateAmmo', function(current, capacity, magLabel)
    SendNUIMessage({
        action = 'updateAmmo',
        current = current,
        capacity = capacity,
        magLabel = magLabel,
        show = true
    })
end)

exports('HideAmmo', function()
    SendNUIMessage({
        action = 'updateAmmo',
        show = false
    })
end)

AddEventHandler('sb_hud:setVisible', function(visible)
    isHudVisible = visible
    SendNUIMessage({
        action = visible and 'showHUD' or 'hideHUD'
    })
    DisplayRadar(visible)
end)

-- ============================================================================
-- RADAR KEEPALIVE (ensures minimap stays visible)
-- ============================================================================
CreateThread(function()
    while not SB.Functions.IsLoggedIn() do
        Wait(1000)
    end

    -- Initial delay for full game load
    Wait(3000)

    -- Force minimap on multiple times during startup
    for i = 1, 5 do
        DisplayRadar(true)
        SetRadarBigmapEnabled(false, false)
        Wait(500)
    end

    -- Toggle bigmap to force minimap initialization (fixes minimap not loading on spawn)
    SetBigmapActive(true, false)
    Wait(200)
    SetBigmapActive(false, false)
    Wait(200)
    DisplayRadar(true)

    -- Force radar as exterior (helps with streaming)
    SetRadarAsExteriorThisFrame()
    Wait(100)
    DisplayRadar(true)

    while true do
        Wait(5000)

        -- If HUD should be visible, ensure radar is enabled
        if isHudVisible then
            DisplayRadar(true)
        end
    end
end)

-- ============================================================================
-- STREET NAME DISPLAY (500ms polling)
-- ============================================================================
CreateThread(function()
    while not isUIReady do
        Wait(500)
    end

    local lastStreet = ''
    local lastCross = ''
    local lastZone = ''

    while true do
        Wait(500)

        if isHudVisible and not isCinematicMode then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)

            -- Get street names
            local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash) or ''
            local cross = ''
            if crossHash and crossHash ~= 0 then
                cross = GetStreetNameFromHashKey(crossHash) or ''
            end

            -- Get zone name
            local zoneId = GetNameOfZone(coords.x, coords.y, coords.z)
            local zone = GetLabelText(zoneId) or zoneId

            -- Dirty check: only send when values change
            if street ~= lastStreet or cross ~= lastCross or zone ~= lastZone then
                lastStreet = street
                lastCross = cross
                lastZone = zone

                SendNUIMessage({
                    action = 'updateStreet',
                    street = street,
                    cross = cross,
                    zone = zone
                })
            end
        end
    end
end)

-- ============================================================================
-- RESOURCE EVENTS
-- ============================================================================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    DisplayRadar(true)
    SetRadarBigmapEnabled(false, false)
    SetRadarZoom(0)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DisplayRadar(true)
end)
