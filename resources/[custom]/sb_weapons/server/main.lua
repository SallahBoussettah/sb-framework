--[[
    Everyday Chaos RP - Weapons Server (V2 Magazine System)
    Author: Salah Eddine Boussettah

    Handles: magazine load/unload, reload validation, serial numbers, admin commands.
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- Anti-exploit: operation locks per player
local operationLocks = {}
-- Anti-exploit: cooldown timestamps per player
local cooldowns = {}
local COOLDOWN_MS = 500

-- Server-side tracking: magazine currently "inside" each player's weapon
-- Prevents item loss on disconnect/crash/resource restart
local loadedMags = {} -- loadedMags[source] = { magName = string }

--- Check if player is valid and not on cooldown
---@param source number
---@return boolean
local function ValidatePlayer(source)
    if not source or source <= 0 then return false end
    local Player = SBCore.Functions.GetPlayer(source)
    if not Player then return false end
    return true
end

--- Check and set cooldown (returns true if on cooldown)
---@param source number
---@return boolean
local function IsOnCooldown(source)
    local now = GetGameTimer()
    if cooldowns[source] and (now - cooldowns[source]) < COOLDOWN_MS then
        return true
    end
    cooldowns[source] = now
    return false
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Find a compatible loaded magazine in player's inventory (for R key reload)
SBCore.Functions.CreateCallback('sb_weapons:server:findCompatibleMag', function(source, cb, weaponName)
    if not ValidatePlayer(source) then cb(false) return end
    if not weaponName or type(weaponName) ~= 'string' then cb(false) return end

    local weaponConfig = Config.Weapons[weaponName]
    if not weaponConfig or weaponConfig.noMagazine then cb(false) return end

    local compatibleMags = weaponConfig.compatibleMags
    if not compatibleMags then cb(false) return end

    -- Search inventory for a compatible loaded magazine
    for _, magName in ipairs(compatibleMags) do
        local items = exports['sb_inventory']:GetItemsByName(source, magName)
        for _, item in ipairs(items) do
            if item.metadata and item.metadata.loaded and item.metadata.loaded > 0 then
                cb(true, magName, item.slot, item.metadata)
                return
            end
        end
    end

    cb(false)
end)

--- Reload magazine: consume loaded mag, give back empty, return round count
SBCore.Functions.CreateCallback('sb_weapons:server:reloadMag', function(source, cb, magName, slot)
    if not ValidatePlayer(source) then cb(false, 0) return end
    if operationLocks[source] then cb(false, 0) return end
    if IsOnCooldown(source) then cb(false, 0) return end
    if not magName or type(magName) ~= 'string' then cb(false, 0) return end
    if not slot or type(slot) ~= 'number' or slot < 1 or slot > 40 then cb(false, 0) return end
    slot = math.floor(slot)
    operationLocks[source] = true

    local magConfig = Config.Magazines[magName]
    if not magConfig then
        operationLocks[source] = nil
        cb(false, 0)
        return
    end

    -- Get the specific mag item at that slot
    local items = exports['sb_inventory']:GetItemsByName(source, magName)
    local targetItem = nil
    for _, item in ipairs(items) do
        if item.slot == slot then
            targetItem = item
            break
        end
    end

    if not targetItem or not targetItem.metadata or not targetItem.metadata.loaded or targetItem.metadata.loaded <= 0 then
        operationLocks[source] = nil
        cb(false, 0)
        return
    end

    local roundsLoaded = targetItem.metadata.loaded

    -- Remove the loaded mag from specific slot (mag is now "inside the weapon")
    local removed = exports['sb_inventory']:RemoveItem(source, magName, 1, slot)
    if not removed then
        operationLocks[source] = nil
        cb(false, 0)
        return
    end

    -- Track this mag server-side (safety net for disconnect/crash)
    loadedMags[source] = { magName = magName }

    operationLocks[source] = nil
    cb(true, roundsLoaded)
end)

-- ============================================================================
-- MAGAZINE EMPTY / EJECT (returns mag to inventory when clip depleted or holstered)
-- ============================================================================

--- Called by client when clip reaches 0 - return empty mag to inventory
RegisterNetEvent('sb_weapons:server:magEmpty', function(magName)
    local source = source
    if not ValidatePlayer(source) then return end
    if not magName or type(magName) ~= 'string' then return end
    if not Config.Magazines[magName] then return end

    -- Only process if server is tracking a mag for this player (prevents duplication)
    if not loadedMags[source] then return end
    loadedMags[source] = nil

    -- Give back empty mag (no metadata, stacks with other empties)
    exports['sb_inventory']:AddItem(source, magName, 1, nil, nil, true)
end)

--- Called by client when holstering with rounds remaining - return loaded mag
RegisterNetEvent('sb_weapons:server:magEject', function(magName, remainingRounds)
    local source = source
    if not ValidatePlayer(source) then return end
    if not magName or type(magName) ~= 'string' then return end
    if not Config.Magazines[magName] then return end
    if not remainingRounds or type(remainingRounds) ~= 'number' then return end

    -- Only process if server is tracking a mag for this player (prevents duplication)
    if not loadedMags[source] then return end
    loadedMags[source] = nil

    remainingRounds = math.floor(remainingRounds)
    local magConfig = Config.Magazines[magName]

    -- Clamp to valid range
    if remainingRounds <= 0 then
        -- No rounds left, return empty
        exports['sb_inventory']:AddItem(source, magName, 1, nil, nil, true)
    elseif remainingRounds > magConfig.capacity then
        -- Cap at capacity (anti-exploit)
        local freeSlot = exports['sb_inventory']:GetFreeSlot(source)
        if freeSlot then
            exports['sb_inventory']:AddItem(source, magName, 1, {loaded = magConfig.capacity}, freeSlot, true)
        else
            exports['sb_inventory']:AddItem(source, magName, 1, {loaded = magConfig.capacity}, nil, true)
        end
    else
        -- Return with remaining rounds
        local freeSlot = exports['sb_inventory']:GetFreeSlot(source)
        if freeSlot then
            exports['sb_inventory']:AddItem(source, magName, 1, {loaded = remainingRounds}, freeSlot, true)
        else
            exports['sb_inventory']:AddItem(source, magName, 1, {loaded = remainingRounds}, nil, true)
        end
    end
end)

-- ============================================================================
-- MAGAZINE LOAD/UNLOAD
-- ============================================================================

--- Handle magazine load/unload from inventory context menu
RegisterNetEvent('sb_weapons:server:magazineAction', function(slot, action)
    local source = source
    if not ValidatePlayer(source) then return end
    if not slot or not action then return end
    if type(slot) ~= 'number' or slot < 1 or slot > 40 then return end
    if type(action) ~= 'string' or (action ~= 'load' and action ~= 'unload') then return end
    slot = math.floor(slot)

    -- Anti-exploit: operation lock + cooldown
    if operationLocks[source] then return end
    if IsOnCooldown(source) then return end
    operationLocks[source] = true

    -- Get item at the given slot
    local items = nil
    local magName = nil
    local magConfig = nil

    -- Find which magazine is in this slot by checking all magazine types
    for magType, conf in pairs(Config.Magazines) do
        local found = exports['sb_inventory']:GetItemsByName(source, magType)
        for _, item in ipairs(found) do
            if item.slot == slot then
                magName = magType
                magConfig = conf
                items = item
                break
            end
        end
        if items then break end
    end

    if not items or not magConfig then
        operationLocks[source] = nil
        return
    end

    if action == 'load' then
        -- LOAD: Remove 1 empty mag from stack, take bullets (loose + boxes), create loaded mag
        local loaded = items.metadata and items.metadata.loaded or 0
        if loaded > 0 then
            operationLocks[source] = nil
            return
        end

        -- Determine ammo item from weapon type
        local ammoItem = 'pistol_ammo'
        for _, weaponConfig in pairs(Config.Weapons) do
            if weaponConfig.weaponType == magConfig.weaponType then
                ammoItem = weaponConfig.ammoItem
                break
            end
        end

        -- Count total available: loose bullets + rounds in ammo boxes
        local looseBullets = exports['sb_inventory']:GetItemCount(source, ammoItem)
        local boxRounds = 0
        local ammoBoxes = exports['sb_inventory']:GetItemsByName(source, Config.AmmoBox.item)
        for _, box in ipairs(ammoBoxes) do
            local r = box.metadata and box.metadata.rounds or 0
            boxRounds = boxRounds + r
        end

        local totalAvailable = looseBullets + boxRounds
        if totalAvailable <= 0 then
            TriggerClientEvent('SB:Client:Notify', source, 'No ammo available', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        local toLoad = math.min(magConfig.capacity, totalAvailable)

        -- Remove 1 empty mag from the stack at this slot
        local removed = exports['sb_inventory']:RemoveItem(source, magName, 1, slot)
        if not removed then
            operationLocks[source] = nil
            return
        end

        -- Take bullets: first from loose ammo, then from boxes
        local bulletsRemoved = 0
        local remaining = toLoad

        -- 1) Take from loose bullets (iterate stacks per-slot)
        if remaining > 0 and looseBullets > 0 then
            local looseStacks = exports['sb_inventory']:GetItemsByName(source, ammoItem)
            for _, stack in ipairs(looseStacks) do
                if remaining <= 0 then break end
                local takeFromStack = math.min(remaining, stack.amount)
                local removed = exports['sb_inventory']:RemoveItem(source, ammoItem, takeFromStack, stack.slot)
                if removed then
                    bulletsRemoved = bulletsRemoved + takeFromStack
                    remaining = remaining - takeFromStack
                end
            end
        end

        -- 2) Take from ammo boxes (update metadata, reduce rounds)
        if remaining > 0 then
            -- Re-fetch boxes in case inventory changed
            ammoBoxes = exports['sb_inventory']:GetItemsByName(source, Config.AmmoBox.item)
            for _, box in ipairs(ammoBoxes) do
                if remaining <= 0 then break end
                local boxRoundsAvail = box.metadata and box.metadata.rounds or 0
                if boxRoundsAvail > 0 then
                    local takeFromBox = math.min(remaining, boxRoundsAvail)
                    local newRounds = boxRoundsAvail - takeFromBox
                    -- Remove old box, add updated box
                    exports['sb_inventory']:RemoveItem(source, Config.AmmoBox.item, 1, box.slot)
                    local boxSlot = box.slot
                    exports['sb_inventory']:AddItem(source, Config.AmmoBox.item, 1, {rounds = newRounds}, boxSlot, true)
                    bulletsRemoved = bulletsRemoved + takeFromBox
                    remaining = remaining - takeFromBox
                end
            end
        end

        if bulletsRemoved <= 0 then
            exports['sb_inventory']:AddItem(source, magName, 1, nil, nil, true)
            TriggerClientEvent('SB:Client:Notify', source, 'Failed to load', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        -- Find a free slot for the loaded mag
        local freeSlot = exports['sb_inventory']:GetFreeSlot(source)
        if not freeSlot then
            -- Rollback: give back bullets as loose + empty mag
            exports['sb_inventory']:AddItem(source, ammoItem, bulletsRemoved, nil, nil, true)
            exports['sb_inventory']:AddItem(source, magName, 1, nil, nil, true)
            TriggerClientEvent('SB:Client:Notify', source, 'Inventory full', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        -- Add loaded mag with metadata to specific slot
        local added = exports['sb_inventory']:AddItem(source, magName, 1, {loaded = bulletsRemoved}, freeSlot, true)
        if not added then
            exports['sb_inventory']:AddItem(source, ammoItem, bulletsRemoved, nil, nil, true)
            exports['sb_inventory']:AddItem(source, magName, 1, nil, nil, true)
            TriggerClientEvent('SB:Client:Notify', source, 'Failed to load', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        TriggerClientEvent('SB:Client:Notify', source, ('Loaded %d/%d rounds'):format(bulletsRemoved, magConfig.capacity), 'success', 2000)

    elseif action == 'unload' then
        -- UNLOAD: Remove loaded mag, give back bullets + 1 empty mag
        local loaded = items.metadata and items.metadata.loaded or 0
        if loaded <= 0 then
            operationLocks[source] = nil
            return
        end

        -- Determine ammo item
        local ammoItem = 'pistol_ammo'
        for _, weaponConfig in pairs(Config.Weapons) do
            if weaponConfig.weaponType == magConfig.weaponType then
                ammoItem = weaponConfig.ammoItem
                break
            end
        end

        -- Remove the loaded mag from specific slot
        local removed = exports['sb_inventory']:RemoveItem(source, magName, 1, slot)
        if not removed then
            operationLocks[source] = nil
            return
        end

        -- Give back bullets
        exports['sb_inventory']:AddItem(source, ammoItem, loaded, nil, nil, true)

        -- Give back empty mag (stacks with empties)
        exports['sb_inventory']:AddItem(source, magName, 1, nil, nil, true)

        TriggerClientEvent('SB:Client:Notify', source, ('Unloaded %d rounds'):format(loaded), 'success', 2000)
    end

    operationLocks[source] = nil
end)

-- ============================================================================
-- AMMO BOX FILL/EMPTY
-- ============================================================================

--- Handle ammo box fill/empty from inventory context menu
RegisterNetEvent('sb_weapons:server:ammoboxAction', function(slot, action)
    local source = source
    if not ValidatePlayer(source) then return end
    if not slot or not action then return end
    if type(slot) ~= 'number' or slot < 1 or slot > 40 then return end
    if type(action) ~= 'string' or (action ~= 'fill' and action ~= 'empty') then return end
    slot = math.floor(slot)

    -- Anti-exploit: operation lock + cooldown
    if operationLocks[source] then return end
    if IsOnCooldown(source) then return end
    operationLocks[source] = true

    local boxItem = Config.AmmoBox.item
    local boxCapacity = Config.AmmoBox.capacity
    local ammoItem = Config.AmmoBox.ammoItem

    -- Find the ammo box at this slot
    local boxes = exports['sb_inventory']:GetItemsByName(source, boxItem)
    local targetBox = nil
    for _, box in ipairs(boxes) do
        if box.slot == slot then
            targetBox = box
            break
        end
    end

    if not targetBox then
        operationLocks[source] = nil
        return
    end

    local currentRounds = targetBox.metadata and targetBox.metadata.rounds or 0

    if action == 'fill' then
        -- FILL: Take loose bullets from inventory, put into box
        if currentRounds >= boxCapacity then
            TriggerClientEvent('SB:Client:Notify', source, 'Box is full', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        local looseBullets = exports['sb_inventory']:GetItemCount(source, ammoItem)
        if looseBullets <= 0 then
            TriggerClientEvent('SB:Client:Notify', source, 'No loose ammo to box', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        local space = boxCapacity - currentRounds
        local toFill = math.min(space, looseBullets)

        -- Remove loose bullets (iterate stacks, remove per-slot to avoid partial removal)
        local bulletsRemoved = 0
        local remaining = toFill
        local stacks = exports['sb_inventory']:GetItemsByName(source, ammoItem)
        for _, stack in ipairs(stacks) do
            if remaining <= 0 then break end
            local takeFromStack = math.min(remaining, stack.amount)
            local removed = exports['sb_inventory']:RemoveItem(source, ammoItem, takeFromStack, stack.slot)
            if removed then
                bulletsRemoved = bulletsRemoved + takeFromStack
                remaining = remaining - takeFromStack
            end
        end

        if bulletsRemoved <= 0 then
            TriggerClientEvent('SB:Client:Notify', source, 'Failed to fill', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        -- Update box metadata (remove old, add updated at same slot)
        local newRounds = currentRounds + bulletsRemoved
        exports['sb_inventory']:RemoveItem(source, boxItem, 1, slot)
        exports['sb_inventory']:AddItem(source, boxItem, 1, {rounds = newRounds}, slot, true)

        TriggerClientEvent('SB:Client:Notify', source, ('Box: %d/%d rounds'):format(newRounds, boxCapacity), 'success', 2000)

    elseif action == 'empty' then
        -- EMPTY: Take rounds from box, give as loose bullets
        if currentRounds <= 0 then
            operationLocks[source] = nil
            return
        end

        -- Check if player can carry the loose bullets
        local canCarry = exports['sb_inventory']:GetCanCarryAmount(source, ammoItem)
        if canCarry <= 0 then
            TriggerClientEvent('SB:Client:Notify', source, 'No space for bullets', 'error', 2000)
            operationLocks[source] = nil
            return
        end

        local toEmpty = math.min(currentRounds, canCarry)

        -- Update box (remove old, add updated at same slot)
        local newRounds = currentRounds - toEmpty
        exports['sb_inventory']:RemoveItem(source, boxItem, 1, slot)
        exports['sb_inventory']:AddItem(source, boxItem, 1, {rounds = newRounds}, slot, true)

        -- Give loose bullets
        exports['sb_inventory']:AddItem(source, ammoItem, toEmpty, nil, nil, true)

        TriggerClientEvent('SB:Client:Notify', source, ('Took %d rounds (box: %d/%d)'):format(toEmpty, newRounds, boxCapacity), 'success', 2000)
    end

    operationLocks[source] = nil
end)

-- ============================================================================
-- SERIAL NUMBER GENERATION
-- ============================================================================

function GenerateSerial()
    return 'WP-' .. math.random(100000, 999999)
end

-- ============================================================================
-- ADMIN (exports only, command registration in sb_admin)
-- ============================================================================

--- Give full weapon kit: weapon + 3 loaded mags + ammo box
--- Called by sb_admin's /giveweapon command
exports('GiveWeaponKit', function(targetId, weaponName)
    weaponName = weaponName and string.lower(weaponName) or 'weapon_pistol'

    local weaponConfig = Config.Weapons[weaponName]
    if not weaponConfig then
        return false, 'Unknown weapon: ' .. weaponName
    end

    -- Give weapon item with serial number
    local metadata = {
        serial = GenerateSerial(),
        durability = Config.DefaultDurability
    }

    local success = exports['sb_inventory']:AddItem(targetId, weaponName, 1, metadata)
    if not success then
        return false, 'Failed to give weapon (inventory full?)'
    end

    -- Give 1 of each mag type (loaded)
    local magTypes = {'p_quick_mag', 'p_stand_mag', 'p_extended_mag'}
    for _, magName in ipairs(magTypes) do
        local magConf = Config.Magazines[magName]
        if magConf then
            local freeSlot = exports['sb_inventory']:GetFreeSlot(targetId)
            if freeSlot then
                exports['sb_inventory']:AddItem(targetId, magName, 1, {loaded = magConf.capacity}, freeSlot, true)
            end
        end
    end

    -- Give 1 ammo box with full capacity
    local boxSlot = exports['sb_inventory']:GetFreeSlot(targetId)
    if boxSlot then
        exports['sb_inventory']:AddItem(targetId, Config.AmmoBox.item, 1, {rounds = Config.AmmoBox.capacity}, boxSlot, true)
    end

    return true, weaponConfig.label
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source

    -- Return magazine that was "inside the weapon" to prevent item loss
    if loadedMags[src] then
        local magData = loadedMags[src]
        if magData.magName and Config.Magazines[magData.magName] then
            -- Give back empty mag (rounds lost on disconnect, like death)
            exports['sb_inventory']:AddItem(src, magData.magName, 1, nil, nil, true)
            print('^3[sb_weapons]^7 Returned lost magazine (' .. magData.magName .. ') to player ' .. src .. ' on disconnect')
        end
        loadedMags[src] = nil
    end

    operationLocks[src] = nil
    cooldowns[src] = nil
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

--- Give a weapon with auto-generated serial number (for crafting, pickups, etc.)
exports('GiveWeapon', function(source, weaponName, durability)
    local weaponConfig = Config.Weapons[weaponName]
    if not weaponConfig then return false end

    local metadata = {
        serial = GenerateSerial(),
        durability = durability or Config.DefaultDurability
    }

    return exports['sb_inventory']:AddItem(source, weaponName, 1, metadata)
end)

-- ============================================================================
-- STARTUP
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print('^2[sb_weapons]^7 V2 Magazine system loaded')
end)

--- Return all tracked magazines on resource stop (prevents item loss on restart)
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local count = 0
    for src, magData in pairs(loadedMags) do
        if magData.magName and Config.Magazines[magData.magName] then
            exports['sb_inventory']:AddItem(src, magData.magName, 1, nil, nil, true)
            count = count + 1
        end
    end
    loadedMags = {}

    if count > 0 then
        print('^3[sb_weapons]^7 Returned ' .. count .. ' tracked magazine(s) on resource stop')
    end
end)
