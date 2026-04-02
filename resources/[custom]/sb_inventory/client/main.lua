--[[
    Everyday Chaos RP - Inventory Client
    Author: Salah Eddine Boussettah

    Client handles: UI display, input, animations, drops rendering, ground detection.
    All actual item operations go through the server.
]]

local SBCore = exports['sb_core']:GetCoreObject()
local isOpen = false
local currentInventory = nil     -- Current open inventory data
local drops = {}                 -- World drops: [dropId] = { coords, entity }
local hotbarItems = {}           -- Cached hotbar items (slots 1-5) for keyboard shortcuts

-- ========================================================================
-- INVENTORY OPEN/CLOSE
-- ========================================================================

--- Open inventory with automatic ground detection
---@param invType string|nil
---@param identifier string|nil
---@param data table|nil
function OpenInventory(invType, identifier, data)
    if isOpen then return end

    -- Auto-detect nearby ground drops when opening player inventory
    local groundDropId = nil
    if (invType == 'player' or not invType) and not identifier then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local nearestDist = Config.Distances.drop

        for dropId, drop in pairs(drops) do
            local dist = #(coords - drop.coords)
            if dist < nearestDist then
                nearestDist = dist
                groundDropId = dropId
            end
        end
    end

    TriggerServerEvent('sb_inventory:server:openInventory', invType or 'player', identifier, {
        groundDropId = groundDropId
    })
end

--- Close inventory
function CloseInventory()
    if not isOpen then return end
    isOpen = false
    currentInventory = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeInventory' })
    TriggerServerEvent('sb_inventory:server:closeInventory')
end

-- ========================================================================
-- KEY BINDINGS
-- ========================================================================

--- I - Open/close personal inventory
RegisterCommand('+sb_inv_toggle', function()
    if isOpen then
        CloseInventory()
    else
        OpenInventory('player')
    end
end, false)
RegisterCommand('-sb_inv_toggle', function() end, false)
RegisterKeyMapping('+sb_inv_toggle', 'Open Inventory', 'keyboard', Config.OpenKey)

--- Hotbar keys (1-5) - use items from slots 1-5 when inventory is closed
for i = 1, Config.HotbarSlots do
    RegisterCommand('hotbar_' .. i, function()
        if isOpen then return end
        UseHotbarSlot(i)
    end, false)
    RegisterKeyMapping('hotbar_' .. i, 'Hotbar Slot ' .. i, 'keyboard', tostring(i))
end

--- Disable native weapon wheel keys (1-5) so hotbar works
CreateThread(function()
    while true do
        Wait(0)
        for i = 157, 161 do
            DisableControlAction(0, i, true)
        end
    end
end)

-- ========================================================================
-- HOTBAR (shows briefly on quick-use, auto-hides)
-- ========================================================================

local hotbarVisible = false
local hotbarHideTimer = nil

--- Use item from hotbar slot
---@param slot number
function UseHotbarSlot(slot)
    if not hotbarItems[slot] then return end
    TriggerServerEvent('sb_inventory:server:useItem', slot)
    ShowHotbar(slot)
end

--- Show the hotbar HUD briefly
---@param activeSlot number|nil  The slot being used (highlighted)
function ShowHotbar(activeSlot)
    hotbarVisible = true

    -- Send hotbar items with string keys to prevent array reindexing
    local hotbarData = {}
    for i = 1, Config.HotbarSlots do
        if hotbarItems[i] then
            hotbarData[tostring(i)] = hotbarItems[i]
        end
    end

    SendNUIMessage({
        action = 'showHotbar',
        items = hotbarData,
        activeSlot = activeSlot
    })

    -- Cancel previous hide timer
    if hotbarHideTimer then
        hotbarHideTimer = nil
    end

    -- Auto-hide after timeout
    hotbarHideTimer = true
    SetTimeout(Config.UI.hotbarTimeout, function()
        if hotbarVisible and hotbarHideTimer then
            hotbarVisible = false
            hotbarHideTimer = nil
            SendNUIMessage({ action = 'hideHotbar' })
        end
    end)
end

-- ========================================================================
-- SERVER EVENTS
-- ========================================================================

--- Receive inventory data and open UI
RegisterNetEvent('sb_inventory:client:openInventory', function(data)
    if isOpen then return end
    isOpen = true
    currentInventory = data

    -- Hide hotbar when inventory opens
    if hotbarVisible then
        hotbarVisible = false
        hotbarHideTimer = nil
        SendNUIMessage({ action = 'hideHotbar' })
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInventory',
        playerInv = data.playerInv,
        secondaryInv = data.secondaryInv,
        items = data.items,
        playerStats = data.playerStats
    })

    -- Update hotbar cache
    if data.playerInv and data.playerInv.items then
        for i = 1, Config.HotbarSlots do
            hotbarItems[i] = data.playerInv.items[i] or data.playerInv.items[tostring(i)] or nil
        end
    end
end)

--- Update single slot
RegisterNetEvent('sb_inventory:client:updateSlot', function(slot, itemData)
    -- Update hotbar cache
    if slot <= Config.HotbarSlots then
        hotbarItems[slot] = itemData
        -- Refresh visible hotbar
        if hotbarVisible and not isOpen then
            ShowHotbar()
        end
    end

    if isOpen then
        SendNUIMessage({ action = 'updateSlot', slot = slot, item = itemData })
    end
end)

--- Refresh full inventory
RegisterNetEvent('sb_inventory:client:refreshInventory', function(fromInvId, fromItems, toInvId, toItems)
    if not isOpen then return end
    SendNUIMessage({
        action = 'refreshInventory',
        fromInv = fromInvId,
        fromItems = fromItems,
        toInv = toInvId,
        toItems = toItems
    })

    -- Update hotbar cache from player inventory
    if currentInventory and currentInventory.playerInv then
        local playerItems = (fromInvId == currentInventory.playerInv.id) and fromItems or
                            (toInvId == currentInventory.playerInv.id) and toItems or nil
        if playerItems then
            for i = 1, Config.HotbarSlots do
                hotbarItems[i] = playerItems[i] or playerItems[tostring(i)] or nil
            end
        end
    end
end)

--- Update ground panel (after dropping an item while inventory is open)
RegisterNetEvent('sb_inventory:client:updateGround', function(secondaryInv)
    if not isOpen then return end
    SendNUIMessage({
        action = 'updateGround',
        secondaryInv = secondaryInv
    })

    -- Update current inventory reference
    if currentInventory then
        currentInventory.secondaryInv = secondaryInv
    end
end)

--- Use item (play animation, apply effect)
RegisterNetEvent('sb_inventory:client:useItem', function(itemName, slot, metadata, category, shouldClose)
    if shouldClose and isOpen then
        CloseInventory()
    end

    local animConfig = Config.UseAnimations[category]

    if animConfig then
        local ped = PlayerPedId()

        RequestAnimDict(animConfig.dict)
        local timeout = 0
        while not HasAnimDictLoaded(animConfig.dict) and timeout < 5000 do
            Wait(10)
            timeout = timeout + 10
        end

        if HasAnimDictLoaded(animConfig.dict) then
            TaskPlayAnim(ped, animConfig.dict, animConfig.clip, 8.0, -8.0, animConfig.duration, 49, 0, false, false, false)

            local propEntity = nil
            if animConfig.prop then
                local propModel = GetHashKey(animConfig.prop.model)
                RequestModel(propModel)
                while not HasModelLoaded(propModel) do Wait(10) end

                local bone = GetPedBoneIndex(ped, animConfig.prop.bone)
                propEntity = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, false)
                AttachEntityToEntity(propEntity, ped, bone,
                    animConfig.prop.pos.x, animConfig.prop.pos.y, animConfig.prop.pos.z,
                    animConfig.prop.rot.x, animConfig.prop.rot.y, animConfig.prop.rot.z,
                    true, true, false, true, 1, true)
            end

            Wait(animConfig.duration)

            ClearPedTasks(ped)
            if propEntity then
                DeleteObject(propEntity)
            end
        end
    end

    TriggerEvent('sb_inventory:itemUsed', itemName, slot, metadata)
end)

-- ========================================================================
-- DROP SYSTEM (Client-side prop rendering)
-- ========================================================================

--- Create drop prop in world
RegisterNetEvent('sb_inventory:client:createDrop', function(dropId, coords)
    if drops[dropId] then return end

    local model = GetHashKey(Config.Drops.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local entity = CreateObject(model, coords.x, coords.y, coords.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)

    drops[dropId] = {
        coords = coords,
        entity = entity
    }

    -- Add target option for pickup
    exports['sb_target']:AddTargetEntity(entity, {
        {
            name = 'pickup_drop_' .. dropId,
            label = 'Pick Up',
            icon = 'fa-hand',
            distance = Config.Distances.drop,
            action = function()
                OpenInventory('drop', dropId)
            end
        }
    })
end)

--- Remove drop prop from world
RegisterNetEvent('sb_inventory:client:removeDrop', function(dropId)
    local drop = drops[dropId]
    if not drop then return end

    if DoesEntityExist(drop.entity) then
        DeleteObject(drop.entity)
    end

    drops[dropId] = nil
end)

-- ========================================================================
-- NUI CALLBACKS
-- ========================================================================

--- Move item (drag and drop)
RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('sb_inventory:server:moveItem',
        data.fromInv, data.toInv,
        data.fromSlot, data.toSlot,
        data.amount
    )
    cb('ok')
end)

--- Use item
RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('sb_inventory:server:useItem', data.slot)
    cb('ok')
end)

--- Drop item
RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('sb_inventory:server:dropItem', data.slot, data.amount)
    cb('ok')
end)

--- Give item
RegisterNUICallback('giveItem', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestPlayer, closestDist = nil, Config.Distances.give

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(coords - targetCoords)
            if dist < closestDist then
                closestDist = dist
                closestPlayer = GetPlayerServerId(playerId)
            end
        end
    end

    if closestPlayer then
        TriggerServerEvent('sb_inventory:server:giveItem', closestPlayer, data.slot, data.amount)
    else
        exports['sb_notify']:Notify('No player nearby!', 'error', 3000)
    end
    cb('ok')
end)

--- Close inventory from NUI
RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventory()
    cb('ok')
end)

--- Split stack
RegisterNUICallback('splitItem', function(data, cb)
    TriggerServerEvent('sb_inventory:server:moveItem',
        data.fromInv, data.fromInv,
        data.fromSlot, data.toSlot,
        data.amount
    )
    cb('ok')
end)

--- Magazine action (load/unload) - forwarded to sb_weapons server
RegisterNUICallback('magazineAction', function(data, cb)
    TriggerServerEvent('sb_weapons:server:magazineAction', data.slot, data.action)
    cb('ok')
end)

--- Ammo box action (fill/empty) - forwarded to sb_weapons server
RegisterNUICallback('ammoboxAction', function(data, cb)
    TriggerServerEvent('sb_weapons:server:ammoboxAction', data.slot, data.action)
    cb('ok')
end)

-- ========================================================================
-- VEHICLE TRUNK/GLOVEBOX ACCESS
-- ========================================================================

--- Check if player is near vehicle trunk
function GetNearbyVehiclePlate(checkType)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if checkType == 'glovebox' then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 then return nil, nil end
        local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
        local class = GetVehicleClass(vehicle)
        return plate, class
    else
        local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, Config.Distances.trunk, 0, 70)
        if vehicle == 0 then return nil, nil end

        local trunkCoords = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, 'boot'))
        if trunkCoords and #(coords - trunkCoords) <= Config.Distances.trunk then
            local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
            local class = GetVehicleClass(vehicle)
            return plate, class
        end
    end

    return nil, nil
end

-- ========================================================================
-- CLEANUP
-- ========================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for dropId, drop in pairs(drops) do
        if DoesEntityExist(drop.entity) then
            DeleteObject(drop.entity)
        end
    end

    if isOpen then
        CloseInventory()
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeInventory' })
end)

print('[sb_inventory] Client-side loaded successfully')
