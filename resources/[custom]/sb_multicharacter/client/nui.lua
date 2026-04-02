--[[
    Everyday Chaos RP - Multicharacter NUI Handlers
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

-- ============================================================================
-- SELECT CHARACTER
-- ============================================================================
RegisterNUICallback('selectCharacter', function(data, cb)
    local citizenid = data.citizenid
    local spawnLocationId = data.spawnLocation

    if citizenid and spawnLocationId then
        SelectCharacter(citizenid, spawnLocationId)
    end

    cb('ok')
end)

-- ============================================================================
-- CREATE NEW CHARACTER (OPEN CREATION SCREEN)
-- ============================================================================
RegisterNUICallback('newCharacter', function(data, cb)
    local slot = data.slot

    StartCharacterCreation(slot)

    cb('ok')
end)

-- ============================================================================
-- SUBMIT CHARACTER CREATION
-- ============================================================================
RegisterNUICallback('createCharacter', function(data, cb)
    -- Validate required fields
    if not data.charinfo or not data.charinfo.firstname or not data.charinfo.lastname then
        cb({ success = false, error = 'Missing required information' })
        return
    end

    -- Prepare character data
    -- IMPORTANT: Always use GetPedAppearance to get actual drawable indices
    -- (data.appearance from JS has relative indices which won't work when loading)
    local characterData = {
        charinfo = {
            firstname = data.charinfo.firstname,
            lastname = data.charinfo.lastname,
            birthdate = data.charinfo.birthdate or '1990-01-01',
            gender = data.charinfo.gender or 0,
            nationality = data.charinfo.nationality or 'American'
        },
        skin = GetPedAppearance(previewPed),  -- Always get actual values from ped
        spawnLocation = data.spawnLocation
    }

    CreateCharacter(characterData)

    cb({ success = true })
end)

-- ============================================================================
-- CANCEL CHARACTER CREATION (BACK TO SELECT)
-- ============================================================================
RegisterNUICallback('cancelCreation', function(data, cb)
    CancelCharacterCreation()
    cb('ok')
end)

-- ============================================================================
-- DELETE CHARACTER
-- ============================================================================
RegisterNUICallback('deleteCharacter', function(data, cb)
    local citizenid = data.citizenid

    if citizenid then
        DeleteCharacter(citizenid)
    end

    cb('ok')
end)

-- ============================================================================
-- PREVIEW CHARACTER (HOVER/SELECT IN LIST)
-- ============================================================================
RegisterNUICallback('previewCharacter', function(data, cb)
    local citizenid = data.citizenid

    if citizenid then
        PreviewCharacter(citizenid)
    end

    cb('ok')
end)

-- ============================================================================
-- CHANGE CAMERA FOCUS
-- ============================================================================
RegisterNUICallback('setCameraFocus', function(data, cb)
    local focus = data.focus

    if focus then
        SetCameraFocus(focus)
    end

    cb('ok')
end)

-- ============================================================================
-- CHANGE POSE
-- ============================================================================
RegisterNUICallback('setPose', function(data, cb)
    local index = tonumber(data.index)
    if index then
        PlayPreviewPose(index)
    end
    cb('ok')
end)

-- ============================================================================
-- ROTATE CHARACTER
-- ============================================================================
RegisterNUICallback('rotateCharacter', function(data, cb)
    local deltaX = data.deltaX or 0

    if deltaX ~= 0 then
        RotateCharacter(deltaX)
    end

    cb('ok')
end)

-- ============================================================================
-- ZOOM CAMERA
-- ============================================================================
RegisterNUICallback('zoomCamera', function(data, cb)
    local direction = data.direction or 0

    if direction ~= 0 then
        ZoomCamera(direction)
    end

    cb('ok')
end)

-- ============================================================================
-- MOVE CAMERA VERTICAL
-- ============================================================================
RegisterNUICallback('moveCameraVertical', function(data, cb)
    local direction = data.direction or 0

    if direction ~= 0 then
        MoveCameraVertical(direction)
    end

    cb('ok')
end)

-- ============================================================================
-- RESET CAMERA
-- ============================================================================
RegisterNUICallback('resetCamera', function(data, cb)
    ResetCamera()
    cb('ok')
end)

-- ============================================================================
-- CHANGE GENDER (IN CREATION)
-- ============================================================================
RegisterNUICallback('changeGender', function(data, cb)
    local gender = data.gender or 0

    ChangeGender(gender)

    -- Wait for ped to be created + addon clothing metadata to load
    Wait(1000)
    local clothingData = GetClothingData()

    cb({ clothingData = clothingData })
end)

-- ============================================================================
-- UPDATE APPEARANCE (LIVE PREVIEW)
-- ============================================================================
RegisterNUICallback('updateAppearance', function(data, cb)
    if data.appearance then
        UpdateCharacterPreview(data.appearance)
    end
    cb('ok')
end)

-- ============================================================================
-- SET HERITAGE (PARENTS)
-- ============================================================================
RegisterNUICallback('setHeritage', function(data, cb)
    local mother = data.mother
    local father = data.father
    local resemblance = data.resemblance
    local skinTone = data.skinTone

    SetPedHeritage(mother, father, resemblance, skinTone)

    cb('ok')
end)

-- ============================================================================
-- SET FACE FEATURE
-- ============================================================================
RegisterNUICallback('setFaceFeature', function(data, cb)
    local featureId = data.featureId
    local value = data.value

    if featureId ~= nil and value ~= nil then
        SetPedFaceFeatureValue(featureId, value)
    end

    cb('ok')
end)

-- ============================================================================
-- SET HEAD OVERLAY
-- ============================================================================
RegisterNUICallback('setHeadOverlay', function(data, cb)
    local overlayId = data.overlayId
    local index = data.index
    local opacity = data.opacity
    local color = data.color
    local secondColor = data.secondColor

    if overlayId ~= nil then
        SetPedHeadOverlayValue(overlayId, index, opacity, color, secondColor)
    end

    cb('ok')
end)

-- ============================================================================
-- SET HAIR
-- ============================================================================
RegisterNUICallback('setHair', function(data, cb)
    local style = data.style
    local color = data.color
    local highlight = data.highlight

    SetPedHairStyle(style, color, highlight)

    cb('ok')
end)

-- ============================================================================
-- SET EYE COLOR
-- ============================================================================
RegisterNUICallback('setEyeColor', function(data, cb)
    local color = data.color

    if color ~= nil then
        SetPedEyeColorValue(color)
    end

    cb('ok')
end)

-- ============================================================================
-- SET CLOTHING COMPONENT
-- ============================================================================
RegisterNUICallback('setComponent', function(data, cb)
    local componentId = data.componentId
    local drawable = data.drawable  -- This is relative (0-based for addon clothing)
    local texture = data.texture

    -- Debug: print what we're setting
    print(string.format('[CLOTHING DEBUG] setComponent: id=%s, drawable=%s, texture=%s',
        tostring(componentId), tostring(drawable), tostring(texture)))

    if componentId ~= nil and drawable ~= nil then
        -- Use offset version to skip vanilla clothing
        SetPedComponentWithOffset(componentId, drawable, texture)

        -- Calculate actual drawable for texture lookup
        local actualDrawable = drawable
        if Config.HideVanillaClothing and drawable >= 0 then
            actualDrawable = drawable + GetComponentStartDrawable(componentId)
        end

        -- Return max textures for the actual drawable
        local maxTextures = GetMaxComponentTextures(componentId, actualDrawable)
        cb({ maxTextures = maxTextures })
    else
        cb('ok')
    end
end)

-- ============================================================================
-- SET PROP
-- ============================================================================
RegisterNUICallback('setProp', function(data, cb)
    local propId = data.propId
    local drawable = data.drawable  -- This is relative (0-based for addon props)
    local texture = data.texture

    if propId ~= nil then
        -- Use offset version to skip vanilla props
        SetPedPropWithOffset(propId, drawable, texture)

        -- Return max textures for new drawable
        if drawable and drawable >= 0 then
            -- Calculate actual drawable for texture lookup
            local actualDrawable = drawable
            if Config.HideVanillaClothing then
                actualDrawable = drawable + GetPropStartDrawable(propId)
            end
            local maxTextures = GetMaxPropTextures(propId, actualDrawable)
            cb({ maxTextures = maxTextures })
        else
            cb('ok')
        end
    else
        cb('ok')
    end
end)

-- ============================================================================
-- GET CLOTHING DATA (Max variations)
-- ============================================================================
RegisterNUICallback('getClothingData', function(data, cb)
    -- Wait briefly for addon clothing metadata to load on client
    Wait(500)
    local clothingData = GetClothingData()
    cb({ clothingData = clothingData })
end)

-- ============================================================================
-- RANDOMIZE APPEARANCE
-- ============================================================================
RegisterNUICallback('randomizeAppearance', function(data, cb)
    local appearance = RandomizeAppearance()
    cb({ appearance = appearance })
end)

-- ============================================================================
-- GET CURRENT APPEARANCE
-- ============================================================================
RegisterNUICallback('getCurrentAppearance', function(data, cb)
    local appearance = GetPedAppearance(previewPed)
    cb({ appearance = appearance })
end)

-- ============================================================================
-- PLAY SOUND
-- ============================================================================
RegisterNUICallback('playSound', function(data, cb)
    local soundName = data.sound
    local soundSet = data.soundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET'

    PlaySoundFrontend(-1, soundName, soundSet, true)

    cb('ok')
end)

-- ============================================================================
-- CLOSE UI
-- ============================================================================
RegisterNUICallback('closeUI', function(data, cb)
    -- Only allow closing during certain states (not during loading)
    if isInCharacterSelect and not isCreatingCharacter then
        -- User is exiting without selecting - could disconnect
        -- For now, just close NUI
        SetNuiFocus(false, false)
    end

    cb('ok')
end)

-- ============================================================================
-- GET SPAWN LOCATIONS
-- ============================================================================
RegisterNUICallback('getSpawnLocations', function(data, cb)
    cb({ locations = Config.SpawnLocations })
end)

-- ============================================================================
-- DEBUG - LOG FROM NUI
-- ============================================================================
RegisterNUICallback('debug', function(data, cb)
    print('^3[SB_MULTICHARACTER NUI]^7 ' .. tostring(data.message))
    cb('ok')
end)

