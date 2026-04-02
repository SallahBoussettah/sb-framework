--[[
    Everyday Chaos RP - Multicharacter Ped System
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- PED VARIABLES
-- ============================================================================
-- previewPed, isInCharacterSelect, isCreatingCharacter are global (declared in main.lua)

-- ============================================================================
-- CREATE PREVIEW PED
-- ============================================================================
function CreatePreviewPed(appearance)
    -- Delete existing preview ped
    DeletePreviewPed()

    local pedCoords = Config.PreviewLocation.pedCoords

    -- Determine model based on gender
    local model = appearance.model
    if not model then
        model = (appearance.gender == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
    end

    -- Request model
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(model) then
        print('^1[SB_MULTICHARACTER]^7 Failed to load model')
        return
    end

    -- Create the ped
    previewPed = CreatePed(4, model, pedCoords.x, pedCoords.y, pedCoords.z - 1.0, pedCoords.w, false, true)

    -- Set ped properties
    SetEntityHeading(previewPed, pedCoords.w)
    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedCanRagdollFromPlayerImpact(previewPed, false)
    TaskSetBlockingOfNonTemporaryEvents(previewPed, true)

    -- Play idle animation
    PlayIdleAnimation()

    -- Apply appearance if provided
    if appearance then
        ApplyAppearance(previewPed, appearance)
    end

    -- Release model
    SetModelAsNoLongerNeeded(model)

    return previewPed
end

-- ============================================================================
-- DELETE PREVIEW PED
-- ============================================================================
function DeletePreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end
end

-- ============================================================================
-- APPLY APPEARANCE TO PED
-- ============================================================================
function ApplyAppearance(ped, appearance)
    if not ped or not DoesEntityExist(ped) then return end
    if not appearance then return end

    -- Apply heritage (parents)
    ApplyHeritage(ped, appearance)

    -- Apply face features
    ApplyFaceFeatures(ped, appearance.faceFeatures)

    -- Apply head overlays
    ApplyHeadOverlays(ped, appearance.headOverlays)

    -- Apply hair
    ApplyHair(ped, appearance)

    -- Apply eye color
    if appearance.eyeColor then
        SetPedEyeColor(ped, appearance.eyeColor)
    end

    -- Apply clothing components
    ApplyClothing(ped, appearance.components)

    -- Apply props
    ApplyProps(ped, appearance.props)
end

-- ============================================================================
-- APPLY HERITAGE (PARENTS BLEND)
-- ============================================================================
function ApplyHeritage(ped, appearance)
    local mother = appearance.mother or 21
    local father = appearance.father or 0
    local resemblance = appearance.resemblance or 0.5
    local skinTone = appearance.skinTone or 0.5

    SetPedHeadBlendData(ped,
        mother,             -- Shape first ID (mother)
        father,             -- Shape second ID (father)
        0,                  -- Shape third ID
        mother,             -- Skin first ID (mother)
        father,             -- Skin second ID (father)
        0,                  -- Skin third ID
        resemblance,        -- Shape mix (0.0 = mother, 1.0 = father)
        skinTone,           -- Skin mix (0.0 = mother, 1.0 = father)
        0.0,                -- Third mix
        false               -- Is parent
    )
end

-- ============================================================================
-- APPLY FACE FEATURES
-- ============================================================================
function ApplyFaceFeatures(ped, features)
    if not features then return end

    -- Face features are indexed 0-19
    for i = 0, 19 do
        local value = features[tostring(i)] or features[i] or 0.0
        SetPedFaceFeature(ped, i, value)
    end
end

-- ============================================================================
-- APPLY HEAD OVERLAYS (Makeup, blemishes, etc.)
-- ============================================================================
function ApplyHeadOverlays(ped, overlays)
    if not overlays then return end

    -- Overlay indices:
    -- 0 = Blemishes, 1 = Facial Hair, 2 = Eyebrows, 3 = Ageing
    -- 4 = Makeup, 5 = Blush, 6 = Complexion, 7 = Sun Damage
    -- 8 = Lipstick, 9 = Moles/Freckles, 10 = Chest Hair, 11 = Body Blemishes, 12 = Add Body Blemishes

    for i = 0, 12 do
        local overlay = overlays[tostring(i)] or overlays[i]
        if overlay then
            local index = overlay.index or 255
            local opacity = overlay.opacity or 1.0
            local color = overlay.color or 0
            local secondColor = overlay.secondColor or color

            -- Set overlay
            SetPedHeadOverlay(ped, i, index, opacity)

            -- Set overlay color for applicable overlays
            -- 1 = Hair color, 2 = Makeup color
            if i == 1 or i == 2 or i == 10 then
                -- Facial hair, eyebrows, chest hair use hair color (type 1)
                SetPedHeadOverlayColor(ped, i, 1, color, secondColor)
            elseif i == 4 or i == 5 or i == 8 then
                -- Makeup, blush, lipstick use makeup color (type 2)
                SetPedHeadOverlayColor(ped, i, 2, color, secondColor)
            end
        else
            -- Clear overlay if not set
            SetPedHeadOverlay(ped, i, 255, 0.0)
        end
    end
end

-- ============================================================================
-- APPLY HAIR
-- ============================================================================
function ApplyHair(ped, appearance)
    local hair = appearance.hair or {}

    -- Hair style
    local hairStyle = hair.style or 0
    SetPedComponentVariation(ped, 2, hairStyle, 0, 0)

    -- Hair color
    local hairColor = hair.color or 0
    local hairHighlight = hair.highlight or 0
    SetPedHairColor(ped, hairColor, hairHighlight)
end

-- ============================================================================
-- APPLY CLOTHING COMPONENTS
-- ============================================================================
-- Naked defaults used when no addon clothing available or when explicitly naked
local ClothingNakedDefaults = {
    [1] = 0,   -- Mask (0 = no mask)
    [3] = 15,  -- Torso (15 = naked arms)
    [4] = 21,  -- Pants (21 = boxers/underwear)
    [5] = 0,   -- Bags (0 = none)
    [6] = 34,  -- Shoes (34 = barefoot)
    [7] = 0,   -- Accessories (0 = none)
    [8] = 15,  -- Undershirt (15 = none)
    [9] = 0,   -- Body Armor (0 = none)
    [10] = 0,  -- Decals (0 = none)
    [11] = 15, -- Tops (15 = naked torso)
}

function ApplyClothing(ped, components)
    if not components then return end

    -- Component IDs:
    -- 0 = Face, 1 = Mask, 2 = Hair, 3 = Torso, 4 = Leg
    -- 5 = Parachute/Bag, 6 = Shoes, 7 = Accessory, 8 = Undershirt
    -- 9 = Kevlar, 10 = Badge, 11 = Torso 2

    -- Get gender for vanilla offsets
    local model = GetEntityModel(ped)
    local gender = model == `mp_f_freemode_01` and 'female' or 'male'

    for componentId, data in pairs(components) do
        local id = tonumber(componentId)
        if id and id ~= 2 then -- Skip hair component (handled separately)
            local drawable = data.drawable or 0
            local texture = data.texture or 0

            -- If HideVanillaClothing is enabled, check if this is a vanilla drawable
            -- When in vanilla range, ALWAYS use naked default - let user pick clothing via UI
            if Config.HideVanillaClothing and id ~= 3 then  -- Don't adjust torso (id 3)
                local vanillaCount = Config.VanillaDrawables[gender] and Config.VanillaDrawables[gender][id] or 0

                -- If drawable is in vanilla range, use naked default
                -- User will select addon clothing via the UI sliders
                if drawable < vanillaCount then
                    drawable = ClothingNakedDefaults[id] or 0
                    texture = 0
                end
            end

            SetPedComponentVariation(ped, id, drawable, texture, 0)
        end
    end
end

-- ============================================================================
-- APPLY PROPS (Hats, glasses, ears, watches, bracelets)
-- ============================================================================
function ApplyProps(ped, props)
    if not props then return end

    -- Prop IDs:
    -- 0 = Hats, 1 = Glasses, 2 = Ears, 6 = Watches, 7 = Bracelets

    -- Get gender for vanilla offsets
    local model = GetEntityModel(ped)
    local gender = model == `mp_f_freemode_01` and 'female' or 'male'

    for propId, data in pairs(props) do
        local id = tonumber(propId)
        if id then
            local drawable = data.drawable
            local texture = data.texture or 0

            if drawable and drawable >= 0 then
                -- If HideVanillaClothing is enabled, check if this is a vanilla drawable
                if Config.HideVanillaClothing then
                    local vanillaCount = Config.VanillaProps[gender] and Config.VanillaProps[gender][id] or 0
                    local totalDrawables = GetNumberOfPedPropDrawableVariations(ped, id)
                    local addonCount = totalDrawables - vanillaCount

                    -- If drawable is in vanilla range and there are addon props, use first addon
                    if drawable < vanillaCount and addonCount > 0 then
                        drawable = vanillaCount  -- First addon drawable
                        texture = 0
                    elseif drawable < vanillaCount and addonCount <= 0 then
                        -- No addon props, clear the prop
                        ClearPedProp(ped, id)
                        goto continue
                    end
                end

                SetPedPropIndex(ped, id, drawable, texture, true)
            else
                ClearPedProp(ped, id)
            end

            ::continue::
        end
    end
end

-- ============================================================================
-- PLAY IDLE ANIMATION
-- ============================================================================
function PlayIdleAnimation()
    if not previewPed or not DoesEntityExist(previewPed) then return end

    local animDict = Config.IdleAnimation.dict
    local animName = Config.IdleAnimation.anim

    -- Request animation dictionary
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(previewPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

-- ============================================================================
-- PLAY PREVIEW POSE
-- ============================================================================
local currentPoseIndex = 1

function PlayPreviewPose(index)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    local poses = Config.PreviewPoses
    if not poses or #poses == 0 then return end

    currentPoseIndex = index
    local pose = poses[index]

    -- Clear current animation
    ClearPedTasks(previewPed)

    if not pose.dict or not pose.anim then
        return -- Default stance (no animation)
    end

    RequestAnimDict(pose.dict)
    local timeout = 0
    while not HasAnimDictLoaded(pose.dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if HasAnimDictLoaded(pose.dict) then
        TaskPlayAnim(previewPed, pose.dict, pose.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

function GetCurrentPoseIndex()
    return currentPoseIndex
end

function GetPoseCount()
    return Config.PreviewPoses and #Config.PreviewPoses or 0
end

-- ============================================================================
-- CHANGE PED MODEL (Gender change)
-- ============================================================================
function ChangePedModel(gender)
    local model = gender == 0 and `mp_m_freemode_01` or `mp_f_freemode_01`
    local defaultAppearance = gender == 0 and Config.DefaultAppearance.male or Config.DefaultAppearance.female

    CreatePreviewPed(defaultAppearance)
end

-- ============================================================================
-- GET CURRENT APPEARANCE FROM PED
-- ============================================================================
function GetPedAppearance(ped)
    if not ped or not DoesEntityExist(ped) then return nil end

    local appearance = {}

    -- Model
    appearance.model = GetEntityModel(ped)
    appearance.gender = appearance.model == `mp_f_freemode_01` and 1 or 0

    -- Heritage
    local headBlend = {}
    Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped, Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueFloat(0), Citizen.PointerValueFloat(0), Citizen.PointerValueFloat(0))

    -- Face features
    appearance.faceFeatures = {}
    for i = 0, 19 do
        appearance.faceFeatures[tostring(i)] = GetPedFaceFeature(ped, i)
    end

    -- Head overlays
    appearance.headOverlays = {}
    for i = 0, 12 do
        local overlayValue = GetPedHeadOverlayValue(ped, i)
        if overlayValue ~= 255 then
            appearance.headOverlays[tostring(i)] = {
                index = overlayValue,
                opacity = 1.0,
                color = 0,
                secondColor = 0
            }
        end
    end

    -- Hair
    appearance.hair = {
        style = GetPedDrawableVariation(ped, 2),
        color = GetPedHairColor(ped),
        highlight = GetPedHairHighlightColor(ped)
    }

    -- Eye color
    appearance.eyeColor = GetPedEyeColor(ped)

    -- Components
    appearance.components = {}
    for i = 0, 11 do
        appearance.components[tostring(i)] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i)
        }
    end

    -- Props
    appearance.props = {}
    for _, propId in ipairs({0, 1, 2, 6, 7}) do
        local propIndex = GetPedPropIndex(ped, propId)
        if propIndex >= 0 then
            appearance.props[tostring(propId)] = {
                drawable = propIndex,
                texture = GetPedPropTextureIndex(ped, propId)
            }
        end
    end

    return appearance
end

-- ============================================================================
-- SET SINGLE COMPONENT
-- ============================================================================
-- Default "naked" drawables for mp_m_freemode_01 and mp_f_freemode_01
local DefaultComponents = {
    [1] = 0,   -- Mask (0 = no mask)
    [3] = 15,  -- Torso (15 = naked arms)
    [4] = 21,  -- Pants (21 = boxers for male, similar for female)
    [6] = 34,  -- Shoes (34 = barefoot)
    [7] = 0,   -- Accessories (0 = none)
    [8] = 15,  -- Undershirt (15 = none)
    [11] = 15, -- Tops (15 = naked torso)
}

function SetPedComponent(componentId, drawable, texture)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    -- If drawable is -1, reset to default (naked/none)
    if drawable == -1 then
        local defaultDrawable = DefaultComponents[componentId] or 0
        SetPedComponentVariation(previewPed, componentId, defaultDrawable, 0, 0)
    else
        SetPedComponentVariation(previewPed, componentId, drawable, texture or 0, 0)
    end
end

-- ============================================================================
-- SET SINGLE PROP
-- ============================================================================
function SetPedProp(propId, drawable, texture)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    if drawable and drawable >= 0 then
        SetPedPropIndex(previewPed, propId, drawable, texture or 0, true)
    else
        ClearPedProp(previewPed, propId)
    end
end

-- ============================================================================
-- SET FACE FEATURE
-- ============================================================================
function SetPedFaceFeatureValue(featureId, value)
    if not previewPed or not DoesEntityExist(previewPed) then return end
    SetPedFaceFeature(previewPed, featureId, value)
end

-- ============================================================================
-- SET HEAD OVERLAY
-- ============================================================================
function SetPedHeadOverlayValue(overlayId, index, opacity, color, secondColor)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    -- Ensure opacity is a valid float (default to 0.99)
    -- NOTE: GTA V has a bug where opacity of exactly 1.0 doesn't show overlays
    -- Using 0.99 as max instead
    local opacityValue = tonumber(opacity)
    if not opacityValue or opacityValue <= 0 then
        opacityValue = 0.99
    elseif opacityValue >= 1.0 then
        opacityValue = 0.99
    end

    -- Ensure color values
    local colorValue = tonumber(color) or 0
    local secondColorValue = tonumber(secondColor) or colorValue

    -- Set the overlay
    SetPedHeadOverlay(previewPed, overlayId, index, opacityValue)

    -- Always set color for overlays that support it
    -- Type 1 = hair color (facial hair, eyebrows, chest hair)
    -- Type 2 = makeup color (makeup, blush, lipstick)
    if overlayId == 1 or overlayId == 2 or overlayId == 10 then
        SetPedHeadOverlayColor(previewPed, overlayId, 1, colorValue, secondColorValue)
    elseif overlayId == 4 or overlayId == 5 or overlayId == 8 then
        SetPedHeadOverlayColor(previewPed, overlayId, 2, colorValue, secondColorValue)
    end
end

-- ============================================================================
-- SET HERITAGE
-- ============================================================================
function SetPedHeritage(mother, father, resemblance, skinTone)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    SetPedHeadBlendData(previewPed,
        mother or 21,
        father or 0,
        0,
        mother or 21,
        father or 0,
        0,
        resemblance or 0.5,
        skinTone or 0.5,
        0.0,
        false
    )
end

-- ============================================================================
-- SET HAIR STYLE AND COLOR
-- ============================================================================
function SetPedHairStyle(style, color, highlight)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    if style then
        SetPedComponentVariation(previewPed, 2, style, 0, 0)
    end

    if color then
        SetPedHairColor(previewPed, color, highlight or color)
    end
end

-- ============================================================================
-- SET EYE COLOR
-- ============================================================================
function SetPedEyeColorValue(color)
    if not previewPed or not DoesEntityExist(previewPed) then return end
    SetPedEyeColor(previewPed, color)
end

-- ============================================================================
-- HELPER: Get ped gender for vanilla offsets
-- ============================================================================
function GetPreviewPedGender()
    if not previewPed or not DoesEntityExist(previewPed) then return 'male' end
    local model = GetEntityModel(previewPed)
    return model == `mp_f_freemode_01` and 'female' or 'male'
end

-- ============================================================================
-- GET VANILLA CLOTHING OFFSETS
-- ============================================================================
function GetComponentStartDrawable(componentId)
    if not Config.HideVanillaClothing then return 0 end
    local gender = GetPreviewPedGender()
    local vanillaCount = Config.VanillaDrawables[gender] and Config.VanillaDrawables[gender][componentId] or 0
    return vanillaCount
end

function GetPropStartDrawable(propId)
    if not Config.HideVanillaClothing then return 0 end
    local gender = GetPreviewPedGender()
    local vanillaCount = Config.VanillaProps[gender] and Config.VanillaProps[gender][propId] or 0
    return vanillaCount
end

-- ============================================================================
-- GET MAX VARIATIONS FOR COMPONENT/PROP
-- ============================================================================
function GetMaxComponentVariations(componentId)
    if not previewPed or not DoesEntityExist(previewPed) then return 0 end
    local total = GetNumberOfPedDrawableVariations(previewPed, componentId)
    if Config.HideVanillaClothing then
        local startDrawable = GetComponentStartDrawable(componentId)
        return math.max(0, total - startDrawable)
    end
    return total
end

function GetMaxComponentTextures(componentId, drawable)
    if not previewPed or not DoesEntityExist(previewPed) then return 0 end
    return GetNumberOfPedTextureVariations(previewPed, componentId, drawable)
end

function GetMaxPropVariations(propId)
    if not previewPed or not DoesEntityExist(previewPed) then return 0 end
    local total = GetNumberOfPedPropDrawableVariations(previewPed, propId)
    if Config.HideVanillaClothing then
        local startDrawable = GetPropStartDrawable(propId)
        return math.max(0, total - startDrawable)
    end
    return total
end

function GetMaxPropTextures(propId, drawable)
    if not previewPed or not DoesEntityExist(previewPed) then return 0 end
    return GetNumberOfPedPropTextureVariations(previewPed, propId, drawable)
end

-- ============================================================================
-- SET COMPONENT/PROP WITH OFFSET HANDLING
-- ============================================================================
-- Default "naked" drawables for mp_m_freemode_01 and mp_f_freemode_01
local NakedDefaults = {
    [1] = 0,   -- Mask (0 = no mask)
    [3] = 15,  -- Torso (15 = naked arms)
    [4] = 21,  -- Pants (21 = boxers/underwear)
    [5] = 0,   -- Bags (0 = none)
    [6] = 34,  -- Shoes (34 = barefoot)
    [7] = 0,   -- Accessories (0 = none)
    [8] = 15,  -- Undershirt (15 = none)
    [9] = 0,   -- Body Armor (0 = none)
    [10] = 0,  -- Decals (0 = none)
    [11] = 15, -- Tops (15 = naked torso)
}

-- Use these when setting clothing from UI (which uses relative indices)
function SetPedComponentWithOffset(componentId, relativeDrawable, texture)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    -- If -1, use naked/default drawable
    if relativeDrawable < 0 then
        local nakedDrawable = NakedDefaults[componentId] or 0
        print(string.format('[CLOTHING DEBUG] SetPedComponentWithOffset: id=%d, relative=%d -> NAKED drawable=%d',
            componentId, relativeDrawable, nakedDrawable))
        SetPedComponentVariation(previewPed, componentId, nakedDrawable, 0, 0)
        return
    end

    local actualDrawable = relativeDrawable
    if Config.HideVanillaClothing then
        local offset = GetComponentStartDrawable(componentId)
        actualDrawable = relativeDrawable + offset

        -- Bounds check: make sure drawable exists
        local maxDrawables = GetNumberOfPedDrawableVariations(previewPed, componentId)
        if actualDrawable >= maxDrawables then
            print(string.format('[CLOTHING DEBUG] WARNING: drawable %d out of bounds (max=%d) for component %d, capping',
                actualDrawable, maxDrawables, componentId))
            actualDrawable = maxDrawables - 1
            if actualDrawable < offset then
                -- No addon clothes exist, use naked default
                local nakedDrawable = NakedDefaults[componentId] or 0
                SetPedComponentVariation(previewPed, componentId, nakedDrawable, 0, 0)
                return
            end
        end

        print(string.format('[CLOTHING DEBUG] SetPedComponentWithOffset: id=%d, relative=%d + offset=%d -> actual=%d',
            componentId, relativeDrawable, offset, actualDrawable))
    else
        print(string.format('[CLOTHING DEBUG] SetPedComponentWithOffset: id=%d, drawable=%d (no offset)',
            componentId, actualDrawable))
    end
    SetPedComponentVariation(previewPed, componentId, actualDrawable, texture or 0, 0)
end

function SetPedPropWithOffset(propId, relativeDrawable, texture)
    if not previewPed or not DoesEntityExist(previewPed) then return end
    if relativeDrawable < 0 then
        ClearPedProp(previewPed, propId)
        return
    end
    local actualDrawable = relativeDrawable
    if Config.HideVanillaClothing then
        actualDrawable = relativeDrawable + GetPropStartDrawable(propId)
    end
    SetPedPropIndex(previewPed, propId, actualDrawable, texture or 0, true)
end

-- ============================================================================
-- RANDOMIZE APPEARANCE
-- ============================================================================
function RandomizeAppearance()
    if not previewPed or not DoesEntityExist(previewPed) then return end

    local gender = GetEntityModel(previewPed) == `mp_f_freemode_01` and 1 or 0
    local hairColor = math.random(0, 63)

    local appearance = {
        gender = gender,
        mother = math.random(0, 20),
        father = math.random(0, 20),
        resemblance = math.random() * 1.0,
        skinTone = math.random() * 1.0,
        faceFeatures = {},
        headOverlays = {},
        hair = {
            style = math.random(0, GetMaxComponentVariations(2) - 1),
            color = hairColor,
            highlight = math.random(0, 63)
        },
        eyeColor = math.random(0, 31),
        components = {},
        props = {}
    }

    -- Random face features
    for i = 0, 19 do
        appearance.faceFeatures[tostring(i)] = (math.random() * 2.0) - 1.0
    end

    -- Gender-specific head overlays
    if gender == 0 then
        -- Male: eyebrows, facial hair, chest hair
        local eyebrowMax = GetNumHeadOverlayValues(2) - 1
        local facialHairMax = GetNumHeadOverlayValues(1) - 1
        local chestHairMax = GetNumHeadOverlayValues(10) - 1

        appearance.headOverlays["1"] = {
            index = math.random(0, facialHairMax),
            opacity = math.random(60, 100) / 100.0,
            color = hairColor,
            secondColor = hairColor
        }
        appearance.headOverlays["2"] = {
            index = math.random(0, eyebrowMax),
            opacity = math.random(70, 100) / 100.0,
            color = hairColor,
            secondColor = hairColor
        }
        if math.random() > 0.5 then
            appearance.headOverlays["10"] = {
                index = math.random(0, chestHairMax),
                opacity = math.random(50, 100) / 100.0,
                color = hairColor,
                secondColor = hairColor
            }
        end
    else
        -- Female: eyebrows, makeup, blush, lipstick
        local eyebrowMax = GetNumHeadOverlayValues(2) - 1
        local makeupMax = GetNumHeadOverlayValues(4) - 1
        local blushMax = GetNumHeadOverlayValues(5) - 1
        local lipstickMax = GetNumHeadOverlayValues(8) - 1

        appearance.headOverlays["2"] = {
            index = math.random(0, eyebrowMax),
            opacity = math.random(70, 100) / 100.0,
            color = hairColor,
            secondColor = hairColor
        }
        appearance.headOverlays["4"] = {
            index = math.random(0, makeupMax),
            opacity = math.random(50, 100) / 100.0,
            color = math.random(0, 63),
            secondColor = math.random(0, 63)
        }
        if math.random() > 0.3 then
            appearance.headOverlays["5"] = {
                index = math.random(0, blushMax),
                opacity = math.random(40, 80) / 100.0,
                color = math.random(0, 63),
                secondColor = math.random(0, 63)
            }
        end
        if math.random() > 0.3 then
            appearance.headOverlays["8"] = {
                index = math.random(0, lipstickMax),
                opacity = math.random(60, 100) / 100.0,
                color = math.random(0, 63),
                secondColor = math.random(0, 63)
            }
        end
    end

    -- Handle clothing based on whether we're using vanilla or addon
    if Config.HideVanillaClothing then
        -- ADDON CLOTHING: Pick random items from addon range for each component
        local genderKey = gender == 0 and 'male' or 'female'

        -- Upper body components (torso/3, undershirt/8, tops/11)
        for _, compId in ipairs({3, 8, 11}) do
            local addonCount = GetMaxComponentVariations(compId)
            if addonCount > 0 then
                local relativeDrawable = math.random(0, addonCount - 1)
                local actualDrawable = relativeDrawable + GetComponentStartDrawable(compId)
                local maxTexture = GetMaxComponentTextures(compId, actualDrawable)
                local texture = maxTexture > 1 and math.random(0, maxTexture - 1) or 0
                appearance.components[tostring(compId)] = { drawable = actualDrawable, texture = texture }
            end
        end

        -- Legs, shoes, accessories
        for _, compId in ipairs({4, 6, 7}) do
            local addonCount = GetMaxComponentVariations(compId)
            if addonCount > 0 then
                local relativeDrawable = math.random(0, addonCount - 1)
                local actualDrawable = relativeDrawable + GetComponentStartDrawable(compId)
                local maxTexture = GetMaxComponentTextures(compId, actualDrawable)
                local texture = maxTexture > 1 and math.random(0, maxTexture - 1) or 0
                appearance.components[tostring(compId)] = { drawable = actualDrawable, texture = texture }
            end
        end
    else
        -- VANILLA CLOTHING: Use curated outfits to prevent clipping
        local maleOutfits = {
            { torso = 15, undershirt = 15, tops = 15 },  -- Shirtless
            { torso = 0,  undershirt = 15, tops = 0 },   -- T-shirt
            { torso = 0,  undershirt = 15, tops = 1 },   -- Sport tee
            { torso = 0,  undershirt = 15, tops = 2 },   -- Tank top
            { torso = 0,  undershirt = 15, tops = 4 },   -- Polo
            { torso = 0,  undershirt = 15, tops = 5 },   -- V-neck
            { torso = 0,  undershirt = 15, tops = 6 },   -- Crew neck
            { torso = 4,  undershirt = 15, tops = 3 },   -- Button shirt
            { torso = 4,  undershirt = 15, tops = 7 },   -- Long sleeve
            { torso = 4,  undershirt = 15, tops = 14 },  -- Sweater
            { torso = 14, undershirt = 15, tops = 13 },  -- Hoodie
            { torso = 4,  undershirt = 15, tops = 16 },  -- Jacket
            { torso = 11, undershirt = 15, tops = 10 },  -- Suit jacket
        }

        local femaleOutfits = {
            { torso = 15, undershirt = 15, tops = 15 },  -- Bikini/shirtless
            { torso = 0,  undershirt = 15, tops = 0 },   -- T-shirt
            { torso = 0,  undershirt = 15, tops = 1 },   -- Sport top
            { torso = 0,  undershirt = 15, tops = 2 },   -- Tank top
            { torso = 0,  undershirt = 15, tops = 3 },   -- Crop top
            { torso = 0,  undershirt = 15, tops = 4 },   -- Halter
            { torso = 0,  undershirt = 15, tops = 5 },   -- Blouse
            { torso = 0,  undershirt = 15, tops = 6 },   -- V-neck
            { torso = 3,  undershirt = 15, tops = 7 },   -- Long sleeve
            { torso = 14, undershirt = 15, tops = 13 },  -- Hoodie
            { torso = 5,  undershirt = 15, tops = 16 },  -- Jacket
            { torso = 4,  undershirt = 15, tops = 14 },  -- Sweater
        }

        local outfits = gender == 0 and maleOutfits or femaleOutfits
        local outfit = outfits[math.random(1, #outfits)]

        -- Apply upper body with random texture variation
        for _, comp in ipairs({{3, outfit.torso}, {8, outfit.undershirt}, {11, outfit.tops}}) do
            local compId, drawable = comp[1], comp[2]
            local maxTexture = GetMaxComponentTextures(compId, drawable)
            local texture = maxTexture > 1 and math.random(0, maxTexture - 1) or 0
            appearance.components[tostring(compId)] = { drawable = drawable, texture = texture }
        end

        -- Legs and shoes can be randomized freely (they don't clip with upper body)
        for _, compId in ipairs({4, 6}) do
            local maxDrawable = GetNumberOfPedDrawableVariations(previewPed, compId)
            if maxDrawable > 0 then
                local drawable = math.random(0, maxDrawable - 1)
                local maxTexture = GetMaxComponentTextures(compId, drawable)
                local texture = maxTexture > 1 and math.random(0, maxTexture - 1) or 0
                appearance.components[tostring(compId)] = { drawable = drawable, texture = texture }
            end
        end
    end

    -- Random props (optional: hats, glasses, watches)
    local propChance = { [0] = 0.25, [1] = 0.25, [6] = 0.3 }
    for propId, chance in pairs(propChance) do
        if math.random() < chance then
            local addonCount = GetMaxPropVariations(propId)
            if addonCount > 0 then
                local relativeDrawable = math.random(0, addonCount - 1)
                local actualDrawable = relativeDrawable
                if Config.HideVanillaClothing then
                    actualDrawable = relativeDrawable + GetPropStartDrawable(propId)
                end
                appearance.props[tostring(propId)] = {
                    drawable = actualDrawable,
                    texture = 0
                }
            end
        end
    end

    -- Apply randomized appearance
    ApplyAppearance(previewPed, appearance)

    return appearance
end

-- ============================================================================
-- GET CLOTHING DATA (For NUI - returns addon-only counts)
-- ============================================================================
function GetClothingData()
    if not previewPed or not DoesEntityExist(previewPed) then return {} end

    local data = {}

    -- Component IDs used in character creation clothing tab
    -- Including Bags (5) and Body Armor (9) so user can control them
    local componentIds = {11, 8, 4, 6, 3, 7, 5, 9, 1}  -- Tops, Undershirt, Pants, Shoes, Torso, Accessories, Bags, Armor, Masks
    local componentNames = {
        [1] = 'Mask', [3] = 'Torso', [4] = 'Pants', [5] = 'Bag', [6] = 'Shoes',
        [7] = 'Accessory', [8] = 'Undershirt', [9] = 'Armor', [11] = 'Top'
    }

    for _, compId in ipairs(componentIds) do
        local totalRaw = GetNumberOfPedDrawableVariations(previewPed, compId)
        local offset = GetComponentStartDrawable(compId)
        local maxVariations = GetMaxComponentVariations(compId)
        print(string.format('[CLOTHING DATA] Component %d (%s): total=%d, offset=%d, addon=%d',
            compId, componentNames[compId] or '?', totalRaw, offset, maxVariations))
        local currentDrawable = GetPedDrawableVariation(previewPed, compId)
        local currentTexture = GetPedTextureVariation(previewPed, compId)

        -- Convert current drawable to relative (0-based for addon)
        local relativeDrawable = currentDrawable
        if Config.HideVanillaClothing then
            local startDrawable = GetComponentStartDrawable(compId)
            relativeDrawable = currentDrawable - startDrawable
            if relativeDrawable < 0 then relativeDrawable = 0 end
        end

        data['comp_' .. compId] = {
            type = 'component',
            id = compId,
            name = componentNames[compId] or ('Component ' .. compId),
            maxDrawables = maxVariations,
            currentDrawable = relativeDrawable,
            currentTexture = currentTexture,
            maxTextures = GetMaxComponentTextures(compId, currentDrawable)
        }
    end

    -- Prop IDs
    local propIds = {0, 1, 6}  -- Hats, Glasses, Watches
    local propNames = {
        [0] = 'Hat', [1] = 'Glasses', [6] = 'Watch'
    }

    for _, propId in ipairs(propIds) do
        local maxVariations = GetMaxPropVariations(propId)
        local currentDrawable = GetPedPropIndex(previewPed, propId)
        local currentTexture = currentDrawable >= 0 and GetPedPropTextureIndex(previewPed, propId) or 0

        -- Convert current drawable to relative
        local relativeDrawable = currentDrawable
        if Config.HideVanillaClothing and currentDrawable >= 0 then
            local startDrawable = GetPropStartDrawable(propId)
            relativeDrawable = currentDrawable - startDrawable
            if relativeDrawable < 0 then relativeDrawable = -1 end  -- -1 means no prop
        end

        data['prop_' .. propId] = {
            type = 'prop',
            id = propId,
            name = propNames[propId] or ('Prop ' .. propId),
            maxDrawables = maxVariations,
            currentDrawable = relativeDrawable,
            currentTexture = currentTexture,
            maxTextures = currentDrawable >= 0 and GetMaxPropTextures(propId, currentDrawable) or 0
        }
    end

    -- Include hair max for NUI
    data.maxHairStyles = GetNumberOfPedDrawableVariations(previewPed, 2) - 1

    return data
end

-- ============================================================================
-- DEBUG COMMAND: Print drawable counts using PREVIEW PED
-- ============================================================================
-- Use this in character selection to get female counts
RegisterCommand('previewdebug', function()
    if not previewPed or not DoesEntityExist(previewPed) then
        print('^1[SB_MULTICHARACTER]^7 No preview ped exists! Enter character creation first.')
        TriggerEvent('chat:addMessage', {
            args = { '^1[ERROR]', 'No preview ped! Enter character creation first.' }
        })
        return
    end

    local model = GetEntityModel(previewPed)
    local gender = model == `mp_f_freemode_01` and 'female' or 'male'

    print('========================================')
    print('PREVIEW PED DEBUG - ' .. string.upper(gender))
    print('========================================')
    print('Use these values in Config.VanillaDrawables')
    print('Run this command WITHOUT addon clothing loaded!')
    print('----------------------------------------')
    print('COMPONENTS:')

    local compIds = {1, 3, 4, 5, 6, 7, 8, 9, 10, 11}
    local compNames = {
        [1] = 'Masks', [3] = 'Torso', [4] = 'Pants', [5] = 'Bags',
        [6] = 'Shoes', [7] = 'Accessories', [8] = 'Undershirts',
        [9] = 'Body Armor', [10] = 'Decals', [11] = 'Tops'
    }

    for _, compId in ipairs(compIds) do
        local count = GetNumberOfPedDrawableVariations(previewPed, compId)
        print(string.format('  [%d] = %d,  -- %s', compId, count, compNames[compId] or ''))
    end

    print('----------------------------------------')
    print('PROPS:')

    local propIds = {0, 1, 2, 6, 7}
    local propNames = {
        [0] = 'Hats', [1] = 'Glasses', [2] = 'Ears',
        [6] = 'Watches', [7] = 'Bracelets'
    }

    for _, propId in ipairs(propIds) do
        local count = GetNumberOfPedPropDrawableVariations(previewPed, propId)
        print(string.format('  [%d] = %d,  -- %s', propId, count, propNames[propId] or ''))
    end

    print('========================================')

    -- Also show in chat
    TriggerEvent('chat:addMessage', {
        args = { '^2[PREVIEW DEBUG]', 'Check F8 console for ' .. string.upper(gender) .. ' drawable counts!' }
    })
end, false)

