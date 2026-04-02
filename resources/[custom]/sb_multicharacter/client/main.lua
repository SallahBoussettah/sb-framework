--[[
    Everyday Chaos RP - Multicharacter Client Main
    Author: Salah Eddine Boussettah
]]

local SB = exports['sb_core']:GetCoreObject()

-- Refresh SB object when sb_core restarts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- ============================================================================
-- STATE VARIABLES (Global for sharing between client scripts)
-- ============================================================================
isInCharacterSelect = false
isCreatingCharacter = false
previewPed = nil

-- Local variables
local characters = {}
local maxSlots = Config.DefaultSlots
local selectedCharacter = nil

-- ============================================================================
-- EXPORTS
-- ============================================================================
exports('IsInCharacterSelect', function()
    return isInCharacterSelect
end)

exports('IsCreatingCharacter', function()
    return isCreatingCharacter
end)

-- ============================================================================
-- INITIALIZATION (Fast & Seamless)
-- ============================================================================
CreateThread(function()
    -- Immediately disable auto-spawn
    exports.spawnmanager:setAutoSpawn(false)

    -- Keep screen black while loading
    DoScreenFadeOut(0)

    -- Hide HUD immediately so it doesn't flash before character select
    DisplayHud(false)
    DisplayRadar(false)
    TriggerEvent('sb_hud:setVisible', false)

    -- Start loading collision early
    local previewCoords = Config.PreviewLocation.pedCoords
    RequestCollisionAtCoord(previewCoords.x, previewCoords.y, previewCoords.z)

    -- Preload model early
    local model = `mp_m_freemode_01`
    RequestModel(model)

    -- Wait minimal time for network
    while not NetworkIsSessionStarted() do
        Wait(0)
    end

    -- If already logged in, don't interfere
    if SB.Functions.IsLoggedIn() then
        DoScreenFadeIn(500)
        return
    end

    -- Start character selection immediately
    StartCharacterSelection()
end)

-- Handle resource restart
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if NetworkIsPlayerActive(PlayerId()) and not SB.Functions.IsLoggedIn() then
        exports.spawnmanager:setAutoSpawn(false)
        StartCharacterSelection()
    end
end)

-- ============================================================================
-- START CHARACTER SELECTION (Optimized)
-- ============================================================================
function StartCharacterSelection()
    if isInCharacterSelect then return end
    isInCharacterSelect = true

    -- Keep screen faded
    DoScreenFadeOut(0)

    -- Disable spawn manager
    exports.spawnmanager:setAutoSpawn(false)

    -- Preload model for instant spawn
    local model = `mp_m_freemode_01`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    -- Force spawn player instantly at hidden location
    exports.spawnmanager:spawnPlayer({
        x = Config.PreviewLocation.playerHide.x,
        y = Config.PreviewLocation.playerHide.y,
        z = Config.PreviewLocation.playerHide.z,
        heading = 0.0,
        skipFade = true,
        model = model
    }, function()
        -- Immediately hide player
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, Config.PreviewLocation.playerHide.x, Config.PreviewLocation.playerHide.y, Config.PreviewLocation.playerHide.z, false, false, false, true)
        FreezeEntityPosition(playerPed, true)
        SetEntityVisible(playerPed, false, false)
        SetEntityInvincible(playerPed, true)
        SetModelAsNoLongerNeeded(model)

        -- Setup environment (non-blocking)
        SetupCharacterEnvironment()

        -- Request characters from server
        TriggerServerEvent('sb_multicharacter:server:GetCharacters')
    end)
end

-- ============================================================================
-- SETUP CHARACTER SELECTION ENVIRONMENT (Optimized)
-- ============================================================================
function SetupCharacterEnvironment()
    local previewCoords = Config.PreviewLocation.pedCoords

    -- Request collision (non-blocking)
    RequestCollisionAtCoord(previewCoords.x, previewCoords.y, previewCoords.z)

    -- Set weather and time immediately
    SetWeatherTypeNowPersist('EXTRASUNNY')
    NetworkOverrideClockTime(12, 0, 0)

    -- Disable HUD and radar (native + custom sb_hud)
    DisplayHud(false)
    DisplayRadar(false)
    TriggerEvent('sb_hud:setVisible', false)

    -- Setup camera
    SetupCharacterCamera()
end

-- ============================================================================
-- RECEIVE CHARACTERS FROM SERVER
-- ============================================================================
RegisterNetEvent('sb_multicharacter:client:ReceiveCharacters', function(charList, slots)
    characters = charList
    maxSlots = slots

    -- Create preview ped (default male if no characters)
    if #characters > 0 then
        local firstChar = characters[1]
        if firstChar.skin then
            CreatePreviewPed(firstChar.skin)
        else
            CreatePreviewPed(Config.DefaultAppearance.male)
        end
        selectedCharacter = firstChar
    else
        CreatePreviewPed(Config.DefaultAppearance.male)
    end

    -- Open NUI
    OpenCharacterSelectUI()
end)

-- ============================================================================
-- OPEN CHARACTER SELECT NUI
-- ============================================================================
function OpenCharacterSelectUI()
    -- Prepare character data for NUI
    local nuiCharacters = {}
    for i, char in ipairs(characters) do
        table.insert(nuiCharacters, {
            citizenid = char.citizenid,
            slot = char.cid,
            firstname = char.charinfo.firstname or 'Unknown',
            lastname = char.charinfo.lastname or '',
            job = char.job.label or 'Unemployed',
            bank = char.money.bank or 0,
            cash = char.money.cash or 0,
            lastPlayed = char.lastPlayed,
            gender = char.charinfo.gender or 0
        })
    end

    SendNUIMessage({
        action = 'openCharacterSelect',
        characters = nuiCharacters,
        maxSlots = maxSlots,
        serverName = Config.ServerName,
        tagline = Config.ServerTagline,
        spawnLocations = Config.SpawnLocations,
        allowDelete = Config.AllowDelete,
        deleteConfirmText = Config.DeleteConfirmText
    })

    -- Shutdown FiveM loading screen first, then grab NUI focus
    -- (ShutdownLoadingScreenNui releases cursor, so SetNuiFocus must come after)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    SetNuiFocus(true, true)

    -- Fade in screen once UI is ready
    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end
end

-- ============================================================================
-- CLOSE CHARACTER SELECT
-- ============================================================================
function CloseCharacterSelect()
    isInCharacterSelect = false

    -- Close NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    -- Cleanup
    DestroyCharacterCamera()
    DeletePreviewPed()

    -- Re-enable HUD (native + custom sb_hud)
    DisplayHud(true)
    DisplayRadar(true)
    TriggerEvent('sb_hud:setVisible', true)

    -- Reset weather override
    ClearWeatherTypePersist()
end

-- ============================================================================
-- SELECT CHARACTER (FROM NUI)
-- ============================================================================
function SelectCharacter(citizenid, spawnLocationId)
    -- Find spawn location
    local spawnLocation = nil
    for _, loc in ipairs(Config.SpawnLocations) do
        if loc.id == spawnLocationId then
            spawnLocation = loc
            break
        end
    end

    -- Show loading
    SendNUIMessage({ action = 'showLoading', message = 'Loading character...' })

    -- Request server to load character
    TriggerServerEvent('sb_multicharacter:server:SelectCharacter', citizenid, spawnLocation)
end

-- ============================================================================
-- SPAWN CHARACTER (AFTER SERVER CONFIRMS)
-- ============================================================================
RegisterNetEvent('sb_multicharacter:client:SpawnCharacter', function(coords)
    CloseCharacterSelect()

    -- Get the loaded character's appearance
    local Player = SB.Functions.GetPlayerData()
    local skin = Player.skin

    local playerPed = PlayerPedId()

    -- Unfreeze and show player
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, false)

    -- Apply appearance
    if skin then
        ApplyAppearance(playerPed, skin)
    end

    -- Teleport to spawn
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(playerPed, coords.w or 0.0)

    -- Short freeze for loading
    Wait(500)
    FreezeEntityPosition(playerPed, false)

    -- Trigger spawn complete
    TriggerEvent('sb_multicharacter:client:SpawnComplete')
end)

-- ============================================================================
-- START CHARACTER CREATION
-- ============================================================================
function StartCharacterCreation(slot)
    isCreatingCharacter = true
    selectedCharacter = nil

    -- Create fresh preview ped
    CreatePreviewPed(Config.DefaultAppearance.male)

    -- Open creation UI
    SendNUIMessage({
        action = 'openCharacterCreation',
        slot = slot,
        parents = Config.Parents,
        faceFeatures = Config.FaceFeatures,
        overlays = Config.HeadOverlays,
        eyeColors = Config.EyeColors,
        nationalities = Config.Nationalities,
        spawnLocations = Config.SpawnLocations,
        minAge = Config.MinAge,
        maxAge = Config.MaxAge
    })
end

-- ============================================================================
-- CHARACTER CREATION - UPDATE PREVIEW
-- ============================================================================
function UpdateCharacterPreview(appearance)
    if not previewPed or not DoesEntityExist(previewPed) then return end
    ApplyAppearance(previewPed, appearance)
end

-- ============================================================================
-- CHARACTER CREATION - CHANGE GENDER
-- ============================================================================
function ChangeGender(gender)
    local appearance = gender == 0 and Config.DefaultAppearance.male or Config.DefaultAppearance.female
    CreatePreviewPed(appearance)
end

-- ============================================================================
-- CREATE CHARACTER (SUBMIT FROM NUI)
-- ============================================================================
function CreateCharacter(data)
    if not isCreatingCharacter then return end

    -- Show loading
    SendNUIMessage({ action = 'showLoading', message = 'Creating character...' })

    -- Send to server
    TriggerServerEvent('sb_multicharacter:server:CreateCharacter', data)
end

-- ============================================================================
-- CHARACTER CREATED (SERVER CONFIRMS)
-- ============================================================================
RegisterNetEvent('sb_multicharacter:client:CharacterCreated', function(citizenid, coords)
    isCreatingCharacter = false
    CloseCharacterSelect()

    local playerPed = PlayerPedId()

    -- Unfreeze and show player
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, false)

    -- Get the new character's appearance
    local Player = SB.Functions.GetPlayerData()
    if Player.skin then
        ApplyAppearance(playerPed, Player.skin)
    end

    -- Teleport to spawn
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(playerPed, coords.w or 0.0)

    Wait(500)
    FreezeEntityPosition(playerPed, false)

    -- Notify
    SB.Functions.Notify('Welcome to ' .. Config.ServerName .. '!', 'success')

    TriggerEvent('sb_multicharacter:client:SpawnComplete')
end)

-- ============================================================================
-- DELETE CHARACTER
-- ============================================================================
function DeleteCharacter(citizenid)
    SendNUIMessage({ action = 'showLoading', message = 'Deleting character...' })
    TriggerServerEvent('sb_multicharacter:server:DeleteCharacter', citizenid)
end

RegisterNetEvent('sb_multicharacter:client:CharacterDeleted', function(citizenid)
    -- Remove from local list
    for i, char in ipairs(characters) do
        if char.citizenid == citizenid then
            table.remove(characters, i)
            break
        end
    end

    -- Refresh UI
    OpenCharacterSelectUI()

    -- Update preview ped
    if #characters > 0 then
        if characters[1].skin then
            CreatePreviewPed(characters[1].skin)
        end
    else
        CreatePreviewPed(Config.DefaultAppearance.male)
    end

    SendNUIMessage({ action = 'hideLoading' })
end)

-- ============================================================================
-- ERROR HANDLERS
-- ============================================================================
RegisterNetEvent('sb_multicharacter:client:SetupError', function(message)
    print('^1[SB_MULTICHARACTER]^7 Setup Error: ' .. message)
end)

RegisterNetEvent('sb_multicharacter:client:SelectError', function(message)
    SendNUIMessage({ action = 'hideLoading' })
    SendNUIMessage({ action = 'showError', message = message })
end)

RegisterNetEvent('sb_multicharacter:client:CreateError', function(message)
    SendNUIMessage({ action = 'hideLoading' })
    SendNUIMessage({ action = 'showError', message = message })
end)

RegisterNetEvent('sb_multicharacter:client:DeleteError', function(message)
    SendNUIMessage({ action = 'hideLoading' })
    SendNUIMessage({ action = 'showError', message = message })
end)

-- ============================================================================
-- CANCEL CHARACTER CREATION (BACK TO SELECT)
-- ============================================================================
function CancelCharacterCreation()
    isCreatingCharacter = false

    -- Refresh character list
    if #characters > 0 and characters[1].skin then
        CreatePreviewPed(characters[1].skin)
    else
        CreatePreviewPed(Config.DefaultAppearance.male)
    end

    -- Back to selection
    OpenCharacterSelectUI()
end

-- ============================================================================
-- PREVIEW CHARACTER (HOVER/SELECT IN UI)
-- ============================================================================
function PreviewCharacter(citizenid)
    for _, char in ipairs(characters) do
        if char.citizenid == citizenid then
            selectedCharacter = char
            if char.skin then
                CreatePreviewPed(char.skin)
            end
            break
        end
    end
end

-- ============================================================================
-- UTILITY - GET CLOTHING DATA FOR CURRENT PED MODEL
-- ============================================================================
function GetClothingData()
    if not previewPed or not DoesEntityExist(previewPed) then
        return nil
    end

    local clothingData = {
        components = {},
        props = {}
    }

    -- Get max drawables for each component
    for _, comp in ipairs(Config.ClothingComponents) do
        local maxDrawables = GetNumberOfPedDrawableVariations(previewPed, comp.id)
        local currentDrawable = GetPedDrawableVariation(previewPed, comp.id)
        local maxTextures = GetNumberOfPedTextureVariations(previewPed, comp.id, currentDrawable)

        clothingData.components[comp.id] = {
            id = comp.id,
            name = comp.name,
            maxDrawables = maxDrawables,
            maxTextures = maxTextures
        }
    end

    -- Get max props
    for _, prop in ipairs(Config.Props) do
        local maxDrawables = GetNumberOfPedPropDrawableVariations(previewPed, prop.id)
        local currentDrawable = GetPedPropIndex(previewPed, prop.id)
        local maxTextures = 0
        if currentDrawable >= 0 then
            maxTextures = GetNumberOfPedPropTextureVariations(previewPed, prop.id, currentDrawable)
        end

        clothingData.props[prop.id] = {
            id = prop.id,
            name = prop.name,
            maxDrawables = maxDrawables,
            maxTextures = maxTextures
        }
    end

    return clothingData
end

-- ============================================================================
-- DISABLE CONTROLS WHILE IN CHARACTER SELECT
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)

        if isInCharacterSelect or isCreatingCharacter then
            -- Disable most controls
            DisableAllControlActions(0)

            -- Allow mouse for NUI
            EnableControlAction(0, 1, true)   -- Mouse look LR
            EnableControlAction(0, 2, true)   -- Mouse look UD
            EnableControlAction(0, 106, true) -- Mouse wheel up
            EnableControlAction(0, 107, true) -- Mouse wheel down
        end
    end
end)

-- ============================================================================
-- RESOURCE STOP - CLEANUP
-- ============================================================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Cleanup
    if isInCharacterSelect then
        CloseCharacterSelect()
    end

    DeletePreviewPed()
    DestroyCharacterCamera()
end)
