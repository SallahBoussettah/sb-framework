--[[
    Everyday Chaos RP - Clothing Store System (Clothing Functions)
    Author: Salah Eddine Boussettah

    Handles: Ped appearance manipulation, preview, get/set functions
]]

-- ============================================================================
-- SETUP COMMAND: Capture positions for clothing store setup
-- ============================================================================
local setupData = {
    playerPos = nil,
    cameraPos = nil
}

RegisterCommand('clothingsetup', function(source, args)
    local arg = args[1]
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    if arg == 'player' then
        -- Save player standing position
        setupData.playerPos = { x = coords.x, y = coords.y, z = coords.z, h = heading }
        TriggerEvent('chat:addMessage', {
            args = { '^2[SETUP]', string.format('Player position saved: %.4f, %.4f, %.4f, heading: %.2f', coords.x, coords.y, coords.z, heading) }
        })
        print(string.format('[SETUP] Player position: vector4(%.4f, %.4f, %.4f, %.2f)', coords.x, coords.y, coords.z, heading))

    elseif arg == 'camera' then
        -- Save camera position
        setupData.cameraPos = { x = coords.x, y = coords.y, z = coords.z }
        TriggerEvent('chat:addMessage', {
            args = { '^2[SETUP]', string.format('Camera position saved: %.4f, %.4f, %.4f', coords.x, coords.y, coords.z) }
        })
        print(string.format('[SETUP] Camera position: vector3(%.4f, %.4f, %.4f)', coords.x, coords.y, coords.z))

    elseif arg == 'preview' then
        -- Preview the camera setup
        if not setupData.playerPos or not setupData.cameraPos then
            TriggerEvent('chat:addMessage', {
                args = { '^1[SETUP]', 'Set both positions first! /clothingsetup player AND /clothingsetup camera' }
            })
            return
        end

        -- Teleport player to saved position
        SetEntityCoords(ped, setupData.playerPos.x, setupData.playerPos.y, setupData.playerPos.z, false, false, false, false)
        SetEntityHeading(ped, setupData.playerPos.h)
        FreezeEntityPosition(ped, true)

        -- Create preview camera
        local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(cam, setupData.cameraPos.x, setupData.cameraPos.y, setupData.cameraPos.z)
        PointCamAtCoord(cam, setupData.playerPos.x, setupData.playerPos.y, setupData.playerPos.z + 0.5)
        SetCamFov(cam, 50.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)

        TriggerEvent('chat:addMessage', {
            args = { '^2[SETUP]', 'Previewing camera. Press BACKSPACE to exit preview.' }
        })

        -- Wait for backspace to exit
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(0)
                if IsControlJustPressed(0, 177) then -- Backspace
                    RenderScriptCams(false, true, 500, true, true)
                    DestroyCam(cam, true)
                    FreezeEntityPosition(ped, false)
                    TriggerEvent('chat:addMessage', {
                        args = { '^2[SETUP]', 'Preview ended.' }
                    })
                    break
                end
            end
        end)

    elseif arg == 'print' then
        -- Print config-ready format
        if not setupData.playerPos or not setupData.cameraPos then
            TriggerEvent('chat:addMessage', {
                args = { '^1[SETUP]', 'Set both positions first!' }
            })
            return
        end

        print('========================================')
        print('CLOTHING STORE SETUP - Copy to config.lua:')
        print('========================================')
        print(string.format('changingSpot = vector4(%.4f, %.4f, %.4f, %.2f),',
            setupData.playerPos.x, setupData.playerPos.y, setupData.playerPos.z, setupData.playerPos.h))
        print(string.format('cameraPos = vector3(%.4f, %.4f, %.4f),',
            setupData.cameraPos.x, setupData.cameraPos.y, setupData.cameraPos.z))
        print('========================================')

        TriggerEvent('chat:addMessage', {
            args = { '^2[SETUP]', 'Config printed to F8 console! Copy the changingSpot and cameraPos lines.' }
        })

    else
        -- Show help
        TriggerEvent('chat:addMessage', {
            args = { '^3[SETUP]', 'Clothing Store Position Setup:' }
        })
        TriggerEvent('chat:addMessage', {
            args = { '^7', '1. Stand where player should be → /clothingsetup player' }
        })
        TriggerEvent('chat:addMessage', {
            args = { '^7', '2. Move to camera position → /clothingsetup camera' }
        })
        TriggerEvent('chat:addMessage', {
            args = { '^7', '3. Preview the setup → /clothingsetup preview' }
        })
        TriggerEvent('chat:addMessage', {
            args = { '^7', '4. Print config values → /clothingsetup print' }
        })
    end
end, false)

-- ============================================================================
-- DEBUG COMMAND: Print drawable counts to find vanilla limits
-- ============================================================================
RegisterCommand('clothingdebug', function()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local gender = model == `mp_f_freemode_01` and 'female' or 'male'

    print('========================================')
    print('CLOTHING DEBUG - ' .. string.upper(gender))
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
        local count = GetNumberOfPedDrawableVariations(ped, compId)
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
        local count = GetNumberOfPedPropDrawableVariations(ped, propId)
        print(string.format('  [%d] = %d,  -- %s', propId, count, propNames[propId] or ''))
    end

    print('========================================')

    -- Also show in chat
    TriggerEvent('chat:addMessage', {
        args = { '^2[CLOTHING DEBUG]', 'Check F8 console for drawable counts!' }
    })
end, false)

-- ============================================================================
-- PREVIEW FUNCTIONS
-- ============================================================================

function PreviewComponent(componentId, drawable, texture)
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end

    texture = texture or 0

    -- For pants (component 4) with addon clothing, we need to prime the streaming
    -- by cycling through nearby drawables first
    if componentId == 4 and drawable > 200 then
        Citizen.CreateThread(function()
            -- Prime: cycle through a couple nearby drawables to trigger streaming
            SetPedComponentVariation(ped, componentId, drawable - 1, 0, 0)
            Citizen.Wait(30)
            SetPedComponentVariation(ped, componentId, drawable + 1, 0, 0)
            Citizen.Wait(30)
            -- Now set the actual target
            SetPedComponentVariation(ped, componentId, drawable, texture, 0)
            Citizen.Wait(50)
            -- Apply again to ensure it sticks
            SetPedComponentVariation(ped, componentId, drawable, texture, 0)
        end)
    else
        -- Normal path for other components
        SetPedComponentVariation(ped, componentId, drawable, texture, 0)
    end
end

function PreviewProp(propId, drawable, texture)
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end

    if drawable >= 0 then
        SetPedPropIndex(ped, propId, drawable, texture or 0, true)
    else
        ClearPedProp(ped, propId)
    end
end

-- ============================================================================
-- HELPER: Get player gender
-- ============================================================================

function GetPlayerGender()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if model == `mp_f_freemode_01` then
        return 'female'
    end
    return 'male'
end

-- ============================================================================
-- GET CLOTHING DATA (Available variations for each category)
-- ============================================================================

function GetClothingData()
    local ped = PlayerPedId()
    local data = {}
    local gender = GetPlayerGender()

    -- Get vanilla skip counts if hiding vanilla clothing
    local vanillaComps = Config.HideVanillaClothing and Config.VanillaDrawables[gender] or {}
    local vanillaProps = Config.HideVanillaClothing and Config.VanillaProps[gender] or {}

    -- Components
    for _, category in ipairs(Config.Categories) do
        if category.components then
            for _, compId in ipairs(category.components) do
                local totalDrawables = GetNumberOfPedDrawableVariations(ped, compId)
                local vanillaCount = vanillaComps[compId] or 0
                local startDrawable = Config.HideVanillaClothing and vanillaCount or 0
                local addonCount = totalDrawables - startDrawable

                -- Only include if there are addon clothes
                if addonCount > 0 then
                    local currentDrawable = GetPedDrawableVariation(ped, compId)
                    local currentTexture = GetPedTextureVariation(ped, compId)

                    data['comp_' .. compId] = {
                        type = 'component',
                        id = compId,
                        name = Config.ComponentNames[compId] or ('Component ' .. compId),
                        maxDrawables = addonCount,
                        startDrawable = startDrawable,  -- Where addon clothing starts
                        currentDrawable = currentDrawable,
                        currentTexture = currentTexture,
                        maxTextures = GetNumberOfPedTextureVariations(ped, compId, currentDrawable)
                    }
                end
            end
        end

        -- Props
        if category.props then
            for _, propId in ipairs(category.props) do
                local totalDrawables = GetNumberOfPedPropDrawableVariations(ped, propId)
                local vanillaCount = vanillaProps[propId] or 0
                local startDrawable = Config.HideVanillaClothing and vanillaCount or 0
                local addonCount = totalDrawables - startDrawable

                -- Only include if there are addon props (or allow "none" option)
                local currentDrawable = GetPedPropIndex(ped, propId)
                local currentTexture = GetPedPropTextureIndex(ped, propId)

                data['prop_' .. propId] = {
                    type = 'prop',
                    id = propId,
                    name = Config.PropNames[propId] or ('Prop ' .. propId),
                    maxDrawables = addonCount > 0 and addonCount or 0,
                    startDrawable = startDrawable,
                    currentDrawable = currentDrawable,
                    currentTexture = currentTexture,
                    maxTextures = currentDrawable >= 0 and GetNumberOfPedPropTextureVariations(ped, propId, currentDrawable) or 0
                }
            end
        end
    end

    return data
end

-- ============================================================================
-- GET CURRENT APPEARANCE
-- ============================================================================

function GetCurrentAppearance()
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return nil end

    local appearance = {
        model = GetEntityModel(ped),
        components = {},
        props = {}
    }

    -- Get all components
    for i = 0, 11 do
        appearance.components[tostring(i)] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i)
        }
    end

    -- Get all props
    for _, propId in ipairs({0, 1, 2, 6, 7}) do
        local propIndex = GetPedPropIndex(ped, propId)
        appearance.props[tostring(propId)] = {
            drawable = propIndex,
            texture = propIndex >= 0 and GetPedPropTextureIndex(ped, propId) or 0
        }
    end

    -- Get hair info
    appearance.hair = {
        style = GetPedDrawableVariation(ped, 2),
        color = GetPedHairColor(ped),
        highlight = GetPedHairHighlightColor(ped)
    }

    -- Get head blend data (heritage)
    local headBlendSuccess, shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(ped)
    if headBlendSuccess then
        appearance.mother = shapeFirst
        appearance.father = shapeSecond
        appearance.resemblance = shapeMix
        appearance.skinTone = skinMix
    end

    -- Get face features
    appearance.faceFeatures = {}
    for i = 0, 19 do
        appearance.faceFeatures[tostring(i)] = GetPedFaceFeature(ped, i)
    end

    -- Get head overlays
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

    -- Eye color
    appearance.eyeColor = GetPedEyeColor(ped)

    return appearance
end

-- ============================================================================
-- APPLY APPEARANCE TO PLAYER
-- ============================================================================

function ApplyAppearanceToPlayer(appearance)
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end
    if not appearance then return end

    -- Apply heritage (parents)
    if appearance.mother or appearance.father then
        SetPedHeadBlendData(ped,
            appearance.mother or 21,
            appearance.father or 0,
            0,
            appearance.mother or 21,
            appearance.father or 0,
            0,
            appearance.resemblance or 0.5,
            appearance.skinTone or 0.5,
            0.0,
            false
        )
    end

    -- Apply face features
    if appearance.faceFeatures then
        for i = 0, 19 do
            local value = appearance.faceFeatures[tostring(i)] or appearance.faceFeatures[i] or 0.0
            SetPedFaceFeature(ped, i, value)
        end
    end

    -- Apply head overlays
    if appearance.headOverlays then
        for i = 0, 12 do
            local overlay = appearance.headOverlays[tostring(i)] or appearance.headOverlays[i]
            if overlay then
                local index = overlay.index or 255
                local opacity = overlay.opacity or 1.0
                local color = overlay.color or 0
                local secondColor = overlay.secondColor or color

                SetPedHeadOverlay(ped, i, index, opacity)

                if i == 1 or i == 2 or i == 10 then
                    SetPedHeadOverlayColor(ped, i, 1, color, secondColor)
                elseif i == 4 or i == 5 or i == 8 then
                    SetPedHeadOverlayColor(ped, i, 2, color, secondColor)
                end
            else
                SetPedHeadOverlay(ped, i, 255, 0.0)
            end
        end
    end

    -- Apply hair
    if appearance.hair then
        if appearance.hair.style then
            SetPedComponentVariation(ped, 2, appearance.hair.style, 0, 0)
        end
        if appearance.hair.color then
            SetPedHairColor(ped, appearance.hair.color, appearance.hair.highlight or appearance.hair.color)
        end
    end

    -- Apply eye color
    if appearance.eyeColor then
        SetPedEyeColor(ped, appearance.eyeColor)
    end

    -- Apply components
    if appearance.components then
        for componentId, data in pairs(appearance.components) do
            local id = tonumber(componentId)
            if id and id ~= 2 then -- Skip hair component
                local drawable = data.drawable or 0
                local texture = data.texture or 0
                SetPedComponentVariation(ped, id, drawable, texture, 0)
            end
        end
    end

    -- Apply props
    if appearance.props then
        for propId, data in pairs(appearance.props) do
            local id = tonumber(propId)
            if id then
                local drawable = data.drawable
                local texture = data.texture or 0

                if drawable and drawable >= 0 then
                    SetPedPropIndex(ped, id, drawable, texture, true)
                else
                    ClearPedProp(ped, id)
                end
            end
        end
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetCurrentAppearance', GetCurrentAppearance)
exports('ApplyAppearance', ApplyAppearanceToPlayer)
