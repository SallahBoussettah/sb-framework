--[[
    Everyday Chaos RP - Clothing Store System (Client Main)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, blips, shop open/close, camera, NUI control
]]

local SB = exports['sb_core']:GetCoreObject()
local shopOpen = false
local currentStore = nil
local currentStoreIndex = nil
local currentStoreData = nil
local spawnedNPCs = {}
local blips = {}

-- Camera state
local shopCam = nil
local camFov = Config.Camera.defaultFov
local baseCamPos = nil  -- Store's camera position

-- Original appearance (for cancel/revert)
local originalAppearance = nil
local originalPosition = nil  -- Where player was before walking to changing spot

-- ============================================================================
-- MAP BLIPS
-- ============================================================================

local function CreateStoreBlips()
    for _, store in ipairs(Config.Stores) do
        local blip = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.Blip.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- ============================================================================
-- NPC SPAWNING
-- ============================================================================

local function SpawnStoreNPCs()
    local model = GetHashKey(Config.NPCModel)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print('[sb_clothing] Failed to load NPC model')
            return
        end
    end

    for i, store in ipairs(Config.Stores) do
        local coords = store.coords
        local npc = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        SetEntityAsMissionEntity(npc, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedCombatAttributes(npc, 46, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)

        local storeIndex = i
        exports['sb_target']:AddTargetEntity(npc, {
            {
                name = 'clothing_browse_' .. i,
                label = 'Browse Clothing',
                icon = 'fa-shirt',
                distance = Config.InteractDistance,
                action = function(entity)
                    TryOpenClothingShop(storeIndex)
                end
            }
        })

        spawnedNPCs[#spawnedNPCs + 1] = npc
    end

    SetModelAsNoLongerNeeded(model)
end

-- ============================================================================
-- CAMERA CONTROL
-- ============================================================================

local function CreateShopCamera(storeData)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    -- If camera already exists, don't recreate
    if shopCam then return end

    camFov = Config.Camera.defaultFov

    shopCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    -- Use store-specific camera position if available
    if storeData and storeData.cameraPos then
        baseCamPos = storeData.cameraPos
        SetCamCoord(shopCam, baseCamPos.x, baseCamPos.y, baseCamPos.z)
    else
        -- Fallback: position camera in front of player
        local pedHeading = GetEntityHeading(ped)
        local camOffset = Config.Camera.defaultOffset
        local rad = math.rad(pedHeading)
        local camX = pedCoords.x + (camOffset.y * math.sin(rad))
        local camY = pedCoords.y + (camOffset.y * math.cos(rad))
        local camZ = pedCoords.z + camOffset.z
        baseCamPos = vector3(camX, camY, camZ)
        SetCamCoord(shopCam, camX, camY, camZ)
    end

    -- Point at where player will be standing (use changingSpot if available)
    local lookAtPos = pedCoords
    if storeData and storeData.changingSpot then
        lookAtPos = vector3(storeData.changingSpot.x, storeData.changingSpot.y, storeData.changingSpot.z)
    end

    PointCamAtCoord(shopCam, lookAtPos.x, lookAtPos.y, lookAtPos.z + 0.5)
    SetCamFov(shopCam, camFov)
    SetCamActive(shopCam, true)

    -- Smooth camera transition (1.5 seconds for cinematic feel)
    RenderScriptCams(true, true, 1500, true, true)
end

local function DestroyShopCamera()
    if shopCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(shopCam, true)
        shopCam = nil
        baseCamPos = nil
    end
end

local function UpdateCamera()
    if not shopCam or not baseCamPos then return end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    -- Camera stays at base position, just updates FOV and look-at
    PointCamAtCoord(shopCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.5)
    SetCamFov(shopCam, camFov)
end

-- Continuously update camera to track player
CreateThread(function()
    while true do
        if shopOpen and shopCam then
            UpdateCamera()
        end
        Wait(0)
    end
end)

-- ============================================================================
-- WALK TO CHANGING SPOT
-- ============================================================================

local function SmoothTurnToHeading(ped, targetHeading, duration)
    -- Smoothly interpolate heading over duration (ms)
    local startHeading = GetEntityHeading(ped)
    local startTime = GetGameTimer()

    -- Calculate shortest rotation direction
    local diff = targetHeading - startHeading
    if diff > 180 then diff = diff - 360 end
    if diff < -180 then diff = diff + 360 end

    Citizen.CreateThread(function()
        while true do
            local elapsed = GetGameTimer() - startTime
            local progress = math.min(elapsed / duration, 1.0)

            -- Ease out cubic for smooth deceleration
            local eased = 1 - math.pow(1 - progress, 3)

            local newHeading = startHeading + (diff * eased)
            SetEntityHeading(ped, newHeading)

            if progress >= 1.0 then
                SetEntityHeading(ped, targetHeading)
                break
            end

            Citizen.Wait(0)
        end
    end)
end

local function WalkToChangingSpot(storeData, callback)
    local ped = PlayerPedId()

    if not storeData.changingSpot then
        -- No changing spot defined, just use current position
        callback()
        return
    end

    local spot = storeData.changingSpot

    -- Save original position to return to later
    originalPosition = GetEntityCoords(ped)

    -- Use navmesh pathfinding to navigate around obstacles
    TaskFollowNavMeshToCoord(ped, spot.x, spot.y, spot.z, 1.0, -1, 0.5, false, 0.0)

    local cameraStarted = false
    local callbackFired = false

    -- Wait until player reaches destination
    Citizen.CreateThread(function()
        local timeout = 0
        local maxTimeout = 15000 -- 15 seconds max
        local lastPos = GetEntityCoords(ped)
        local stuckTime = 0
        local lastHeading = GetEntityHeading(ped)
        local directionChanges = 0

        while timeout < maxTimeout do
            Citizen.Wait(50)
            timeout = timeout + 50

            local pedCoords = GetEntityCoords(ped)
            local distance = #(pedCoords - vector3(spot.x, spot.y, spot.z))
            local currentHeading = GetEntityHeading(ped)

            -- Detect bouncing (rapid heading changes while close)
            if distance < 2.5 then
                local headingDiff = math.abs(currentHeading - lastHeading)
                if headingDiff > 180 then headingDiff = 360 - headingDiff end
                if headingDiff > 45 then
                    directionChanges = directionChanges + 1
                end
                lastHeading = currentHeading

                -- If bouncing too much, just teleport
                if directionChanges > 4 then
                    ClearPedTasks(ped)
                    SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
                    if not cameraStarted then
                        cameraStarted = true
                        CreateShopCamera(storeData)
                    end
                    SmoothTurnToHeading(ped, spot.w, 300)
                    if not callbackFired then
                        callbackFired = true
                        callback()
                    end
                    break
                end
            end

            -- When close (2.5m), start camera transition early
            if distance < 2.5 and not cameraStarted then
                cameraStarted = true
                CreateShopCamera(storeData)
            end

            -- When close enough (1.2m) OR player stopped moving near destination (2.0m)
            local isCloseEnough = distance < 1.2
            local playerStopped = GetEntitySpeed(ped) < 0.1 and distance < 2.0

            if isCloseEnough or playerStopped then
                ClearPedTasks(ped)
                -- Set position and start turning simultaneously
                SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
                SmoothTurnToHeading(ped, spot.w, 300)

                if not callbackFired then
                    callbackFired = true
                    callback()
                end
                break
            end

            -- Check if stuck (not moving for 1 second)
            local movedDistance = #(pedCoords - lastPos)
            if movedDistance < 0.05 then
                stuckTime = stuckTime + 50
                if stuckTime > 1000 then
                    ClearPedTasks(ped)
                    SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
                    if not cameraStarted then
                        cameraStarted = true
                        CreateShopCamera(storeData)
                    end
                    SmoothTurnToHeading(ped, spot.w, 300)
                    if not callbackFired then
                        callbackFired = true
                        callback()
                    end
                    break
                end
            else
                stuckTime = 0
                lastPos = pedCoords
            end
        end

        -- Timeout reached, force everything
        if timeout >= maxTimeout and not callbackFired then
            ClearPedTasks(ped)
            SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, false)
            SetEntityHeading(ped, spot.w)
            if not cameraStarted then
                CreateShopCamera(storeData)
            end
            callbackFired = true
            callback()
        end
    end)
end

-- ============================================================================
-- OPEN / CLOSE SHOP
-- ============================================================================

function TryOpenClothingShop(storeIndex)
    if shopOpen then return end

    local store = Config.Stores[storeIndex]
    if not store then return end

    -- Check if store has a changing spot (reservation needed)
    if store.changingSpot then
        -- Check if store is available
        SB.Functions.TriggerCallback('sb_clothing:checkStoreAvailable', function(available, occupiedBy)
            if not available then
                exports['sb_notify']:Notify('Someone is already using the changing room. Please wait.', 'error', 4000)
                return
            end

            -- Reserve the store
            SB.Functions.TriggerCallback('sb_clothing:reserveStore', function(reserved)
                if not reserved then
                    exports['sb_notify']:Notify('Could not reserve changing room.', 'error', 3000)
                    return
                end

                -- Successfully reserved, now open
                OpenClothingShop(storeIndex)
            end, storeIndex)
        end, storeIndex)
    else
        -- No changing spot, open directly (old behavior)
        OpenClothingShop(storeIndex)
    end
end

function OpenClothingShop(storeIndex)
    if shopOpen then return end

    local store = Config.Stores[storeIndex]
    if not store then return end

    shopOpen = true
    currentStore = store.type
    currentStoreIndex = storeIndex
    currentStoreData = store

    local ped = PlayerPedId()
    local PlayerData = SB.Functions.GetPlayerData()

    -- Make player invincible while changing clothes
    SetEntityInvincible(ped, true)

    -- Save current appearance for revert
    originalAppearance = GetCurrentAppearance()

    -- Hide HUD immediately
    TriggerEvent('sb_hud:setVisible', false)

    -- Walk to changing spot (camera created during walk for smoothness)
    WalkToChangingSpot(store, function()
        -- Freeze player after arriving
        FreezeEntityPosition(ped, true)

        -- Camera already created during walk, but create if not (fallback for stores without changingSpot)
        if not shopCam then
            CreateShopCamera(store)
        end

        -- Get player money
        local cash = PlayerData.money and PlayerData.money.cash or 0
        local bank = PlayerData.money and PlayerData.money.bank or 0

        -- Get clothing variations for each category
        local clothingData = GetClothingData()

        -- Get saved outfits and owned clothing
        SB.Functions.TriggerCallback('sb_clothing:getSavedOutfits', function(outfits)
            SB.Functions.TriggerCallback('sb_clothing:getOwnedClothing', function(ownedClothing)
                -- Enable NUI
                SetNuiFocus(true, true)

                -- Get player name and citizen ID
                local firstName = PlayerData.charinfo and PlayerData.charinfo.firstname or 'Unknown'
                local lastName = PlayerData.charinfo and PlayerData.charinfo.lastname or ''
                local fullName = firstName .. ' ' .. lastName
                local citizenId = PlayerData.citizenid or 'EC-00000'

                SendNUIMessage({
                    action = 'open',
                    storeName = Config.StoreNames[store.type] or 'Clothing Store',
                    storeType = store.type,
                    priceMultiplier = Config.PriceMultiplier[store.type] or 1.0,
                    categories = Config.Categories,
                    basePrices = Config.BasePrices,
                    clothingData = clothingData,
                    freeComponents = Config.FreeComponents or {},
                    cash = cash,
                    bank = bank,
                    playerName = fullName,
                    citizenId = citizenId,
                    savedOutfits = outfits or {},
                    ownedClothing = ownedClothing or {},
                    maxOutfits = Config.MaxSavedOutfits
                })
            end)
        end)
    end)
end

function CloseClothingShop(revert)
    if not shopOpen then return end
    shopOpen = false

    local ped = PlayerPedId()

    -- Remove invincibility
    SetEntityInvincible(ped, false)

    -- Revert appearance if cancelled
    if revert and originalAppearance then
        ApplyAppearanceToPlayer(originalAppearance)
    end

    -- Destroy camera
    DestroyShopCamera()

    -- Unfreeze player
    FreezeEntityPosition(ped, false)

    -- Walk back to original position if we moved
    if originalPosition then
        local targetPos = originalPosition
        originalPosition = nil

        -- Start walking back
        TaskGoToCoordAnyMeans(ped, targetPos.x, targetPos.y, targetPos.z, 1.0, 0, false, 786603, 0xbf800000)

        -- Monitor and stop when close enough or stuck
        Citizen.CreateThread(function()
            local timeout = 0
            local maxTimeout = 8000 -- 8 seconds max for walk back
            local lastPos = GetEntityCoords(ped)
            local stuckTime = 0
            local lastHeading = GetEntityHeading(ped)
            local directionChanges = 0

            while timeout < maxTimeout do
                Citizen.Wait(100)
                timeout = timeout + 100

                local pedCoords = GetEntityCoords(ped)
                local distance = #(pedCoords - vector3(targetPos.x, targetPos.y, targetPos.z))
                local currentHeading = GetEntityHeading(ped)

                -- Detect bouncing (rapid heading changes)
                local headingDiff = math.abs(currentHeading - lastHeading)
                if headingDiff > 180 then headingDiff = 360 - headingDiff end
                if headingDiff > 45 then
                    directionChanges = directionChanges + 1
                end
                lastHeading = currentHeading

                -- If bouncing too much, just stop
                if directionChanges > 3 then
                    ClearPedTasks(ped)
                    break
                end

                -- Stop when close enough (2.5m radius - bigger to avoid NPC)
                if distance < 2.5 then
                    ClearPedTasks(ped)
                    break
                end

                -- Check if stuck (not moving for 0.8 seconds)
                local movedDistance = #(pedCoords - lastPos)
                if movedDistance < 0.05 then
                    stuckTime = stuckTime + 100
                    if stuckTime > 800 then
                        ClearPedTasks(ped)
                        break
                    end
                else
                    stuckTime = 0
                    lastPos = pedCoords
                end
            end

            -- Timeout, stop walking
            if timeout >= maxTimeout then
                ClearPedTasks(ped)
            end
        end)
    end

    -- Release store reservation
    if currentStoreIndex and currentStoreData and currentStoreData.changingSpot then
        TriggerServerEvent('sb_clothing:server:releaseStore', currentStoreIndex)
    end

    -- Show HUD
    TriggerEvent('sb_hud:setVisible', true)

    -- Disable NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    -- Clear state
    originalAppearance = nil
    currentStore = nil
    currentStoreIndex = nil
    currentStoreData = nil
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseClothingShop(data.revert)
    cb('ok')
end)

RegisterNUICallback('previewComponent', function(data, cb)
    PreviewComponent(data.componentId, data.drawable, data.texture)
    cb('ok')
end)

RegisterNUICallback('previewProp', function(data, cb)
    PreviewProp(data.propId, data.drawable, data.texture)
    cb('ok')
end)

RegisterNUICallback('rotatePlayer', function(data, cb)
    local ped = PlayerPedId()
    local currentHeading = GetEntityHeading(ped)
    local newHeading = currentHeading - (data.deltaX * 0.5)
    SetEntityHeading(ped, newHeading)
    cb('ok')
end)

RegisterNUICallback('zoomCamera', function(data, cb)
    camFov = camFov + (data.delta * Config.Camera.zoomSpeed)
    camFov = math.max(Config.Camera.minFov, math.min(Config.Camera.maxFov, camFov))
    UpdateCamera()
    cb('ok')
end)

RegisterNUICallback('purchase', function(data, cb)
    if not data.items or #data.items == 0 then
        cb('ok')
        return
    end
    TriggerServerEvent('sb_clothing:server:purchase', data.items, currentStore)
    cb('ok')
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    local currentAppearance = GetCurrentAppearance()
    TriggerServerEvent('sb_clothing:server:saveOutfit', data.name, currentAppearance)
    cb('ok')
end)

RegisterNUICallback('loadOutfit', function(data, cb)
    if data.outfit and data.outfit.appearance then
        ApplyAppearanceToPlayer(data.outfit.appearance)
    end
    cb('ok')
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    TriggerServerEvent('sb_clothing:server:deleteOutfit', data.index)
    cb('ok')
end)

RegisterNUICallback('saveOwnedAppearance', function(data, cb)
    -- Save current appearance after equipping owned items
    local appearance = GetCurrentAppearance()
    TriggerServerEvent('sb_clothing:server:saveAppearance', appearance)
    originalAppearance = appearance
    exports['sb_notify']:Notify('Outfit saved!', 'success', 3000)
    cb('ok')
end)

RegisterNUICallback('getTextures', function(data, cb)
    local ped = PlayerPedId()
    local textures = {}

    if data.isProp then
        local maxTextures = GetNumberOfPedPropTextureVariations(ped, data.id, data.drawable)
        for i = 0, maxTextures - 1 do
            textures[#textures + 1] = i
        end
    else
        local maxTextures = GetNumberOfPedTextureVariations(ped, data.id, data.drawable)
        for i = 0, maxTextures - 1 do
            textures[#textures + 1] = i
        end
    end

    cb({ textures = textures })
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterNetEvent('sb_clothing:client:purchaseResult', function(success, payMethod, amount)
    if success then
        -- Update original appearance to current (so cancel doesn't revert)
        originalAppearance = GetCurrentAppearance()

        -- Save appearance to database
        TriggerServerEvent('sb_clothing:server:saveAppearance', originalAppearance)

        if payMethod == 'free' or amount == 0 then
            exports['sb_notify']:Notify('Changes applied!', 'success', 3000)
        else
            exports['sb_notify']:Notify('Purchased for $' .. amount .. ' (' .. payMethod .. ')', 'success', 3000)
        end

        -- Update money display
        local PlayerData = SB.Functions.GetPlayerData()
        SendNUIMessage({
            action = 'updateMoney',
            cash = PlayerData.money and PlayerData.money.cash or 0,
            bank = PlayerData.money and PlayerData.money.bank or 0
        })
    else
        exports['sb_notify']:Notify('Purchase failed!', 'error', 3000)
    end
end)

RegisterNetEvent('sb_clothing:client:outfitSaved', function(success, outfits)
    if success then
        exports['sb_notify']:Notify('Outfit saved!', 'success', 3000)
        SendNUIMessage({
            action = 'updateOutfits',
            savedOutfits = outfits or {}
        })
    else
        exports['sb_notify']:Notify('Failed to save outfit', 'error', 3000)
    end
end)

RegisterNetEvent('sb_clothing:client:outfitDeleted', function(success, outfits)
    if success then
        exports['sb_notify']:Notify('Outfit deleted', 'success', 3000)
        SendNUIMessage({
            action = 'updateOutfits',
            savedOutfits = outfits or {}
        })
    else
        exports['sb_notify']:Notify('Failed to delete outfit', 'error', 3000)
    end
end)

RegisterNetEvent('sb_clothing:client:updateOwnedClothing', function(ownedClothing)
    SendNUIMessage({
        action = 'updateOwnedClothing',
        ownedClothing = ownedClothing or {}
    })
end)

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

CreateThread(function()
    while true do
        Wait(0)
        if shopOpen and shopCam then
            -- Disable controls
            DisableAllControlActions(0)
            -- Note: Player rotation and zoom are handled by NUI (script.js)
        end
    end
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateStoreBlips()
    SpawnStoreNPCs()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Release store reservation if held
    if currentStoreIndex then
        TriggerServerEvent('sb_clothing:server:releaseStore', currentStoreIndex)
    end

    for _, npc in ipairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    if shopOpen then
        CloseClothingShop(true)
    end
end)
