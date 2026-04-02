--[[
    Everyday Chaos RP - Inventory Server
    Author: Salah Eddine Boussettah

    ALL inventory validation happens here. The client only sends requests.
    The server owns the inventory state and decides if operations are valid.
]]

local SBCore = exports['sb_core']:GetCoreObject()
local Inventories = {}   -- Active inventories in memory: [identifier] = { slots, items }
local Drops = {}         -- Active world drops: [dropId] = { items, coords }
local DropCounter = 0    -- Incremental drop ID
local ItemDefs = {}      -- Item definitions loaded from database
local PlayerCitizenIds = {} -- Cache: [source] = citizenid (survives sb_core cleanup)

-- ========================================================================
-- LOAD ITEMS FROM DATABASE
-- ========================================================================
CreateThread(function()
    local items = MySQL.query.await('SELECT * FROM sb_items')
    if items then
        for _, item in ipairs(items) do
            ItemDefs[item.name] = {
                name = item.name,
                label = item.label,
                type = item.type,
                category = item.category,
                image = item.image,
                stackable = (item.stackable == 1 or item.stackable == true),
                max_stack = item.max_stack,
                useable = (item.useable == 1 or item.useable == true),
                shouldClose = (item.shouldClose == 1 or item.shouldClose == true),
                description = item.description
            }
        end
        print(('[sb_inventory] Loaded %d items from database'):format(#items))
    else
        print('[sb_inventory] WARNING: No items loaded from database!')
    end
end)

-- ========================================================================
-- UTILITY FUNCTIONS
-- ========================================================================

--- Check if item exists in item definitions
---@param itemName string
---@return table|nil
local function GetItemData(itemName)
    return ItemDefs[itemName]
end

--- Generate a unique slot-based inventory table
---@param slots number
---@return table
local function CreateEmptyInventory(slots)
    local inv = {}
    for i = 1, slots do
        inv[i] = nil
    end
    return inv
end

--- Find first available slot for an item
---@param inventory table
---@param itemName string
---@param maxSlots number
---@return number|nil
local function FindAvailableSlot(inventory, itemName, maxSlots)
    local itemData = GetItemData(itemName)
    if not itemData then return nil end

    -- If stackable, find existing stack with space first
    if itemData.stackable then
        local maxStack = itemData.max_stack or 50
        for i = 1, maxSlots do
            if inventory[i] and inventory[i].name == itemName and inventory[i].amount < maxStack then
                return i
            end
        end
    end

    -- Find empty slot
    for i = 1, maxSlots do
        if not inventory[i] then
            return i
        end
    end

    return nil
end

--- Get player's inventory identifier (uses cache as fallback for playerDropped race)
---@param source number
---@return string|nil
local function GetPlayerIdentifier(source)
    local player = SBCore.Functions.GetPlayer(source)
    if player then
        local citizenid = player.PlayerData.citizenid
        PlayerCitizenIds[source] = citizenid  -- Keep cache updated
        return citizenid
    end
    -- Fallback to cache if sb_core already cleaned up
    return PlayerCitizenIds[source]
end

-- ========================================================================
-- INVENTORY MANAGEMENT
-- ========================================================================

--- Load player inventory from database
---@param source number
function LoadPlayerInventory(source)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    PlayerCitizenIds[source] = citizenid
    local identifier = 'player_' .. citizenid

    -- Load inventory directly from database
    local result = MySQL.single.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local items = {}

    if result and result.inventory then
        local decoded = json.decode(result.inventory) or {}
        -- Normalize keys to numeric (json.decode gives string keys from JSON objects)
        for k, v in pairs(decoded) do
            local numKey = tonumber(k)
            if numKey and v then
                items[numKey] = v
            end
        end
    end

    Inventories[identifier] = {
        type = 'player',
        slots = Config.MaxSlots,
        items = items,
        owner = citizenid
    }

    print(('[sb_inventory] Loaded inventory for %s (%s)'):format(GetPlayerName(source), citizenid))
end

--- Save player inventory to database
---@param source number
function SavePlayerInventory(source)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return end

    local encoded = json.encode(inv.items)
    MySQL.update.await('UPDATE players SET inventory = ? WHERE citizenid = ?', {
        encoded,
        citizenid
    })
end

--- Add item to a player's inventory (server-side validated)
---@param source number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@param slot number|nil
---@return boolean
function AddItem(source, itemName, amount, metadata, slot, silent)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return false end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return false end

    local itemData = GetItemData(itemName)
    if not itemData then
        print(('[sb_inventory] Invalid item: %s'):format(itemName))
        return false
    end

    amount = amount or 1
    local maxStack = itemData.max_stack or 50

    -- Helper: check if metadata has any keys (non-empty)
    local function hasMetadata(meta)
        return meta and next(meta) ~= nil
    end

    -- If a specific slot is requested, use single-slot logic
    if slot then
        if inv.items[slot] and inv.items[slot].name == itemName and itemData.stackable
           and not hasMetadata(inv.items[slot].metadata) and not hasMetadata(metadata) then
            if inv.items[slot].amount + amount > maxStack then
                TriggerClientEvent('SB:Client:Notify', source, 'Stack is full!', 'error', 3000)
                return false
            end
            inv.items[slot].amount = inv.items[slot].amount + amount
        elseif not inv.items[slot] then
            inv.items[slot] = { name = itemName, amount = amount, slot = slot, metadata = metadata or {} }
        else
            TriggerClientEvent('SB:Client:Notify', source, 'Slot is occupied!', 'error', 3000)
            return false
        end

        TriggerClientEvent('sb_inventory:client:updateSlot', source, slot, inv.items[slot])
        if not silent then
            TriggerClientEvent('SB:Client:Notify', source, ('Received %dx %s'):format(amount, itemData.label), 'success', 3000)
        end
        MySQL.insert('INSERT INTO sb_inventory_log (action, source, item, amount, metadata) VALUES (?, ?, ?, ?, ?)', {
            'add', citizenid, itemName, amount, json.encode(metadata or {})
        })
        SavePlayerInventory(source)
        return true
    end

    -- Auto-distribute across slots: plan where items will go
    local remaining = amount
    local plan = {} -- { { slot = n, add = n }, ... }

    -- First: fill existing partial stacks (only if neither side has metadata)
    if itemData.stackable and not hasMetadata(metadata) then
        for i = 1, inv.slots do
            if remaining <= 0 then break end
            if inv.items[i] and inv.items[i].name == itemName and not hasMetadata(inv.items[i].metadata) then
                local space = maxStack - inv.items[i].amount
                if space > 0 then
                    local toAdd = math.min(remaining, space)
                    plan[#plan + 1] = { slot = i, add = toAdd, existing = true }
                    remaining = remaining - toAdd
                end
            end
        end
    end

    -- Then: use empty slots for remaining
    for i = 1, inv.slots do
        if remaining <= 0 then break end
        if not inv.items[i] then
            local toAdd = math.min(remaining, maxStack)
            plan[#plan + 1] = { slot = i, add = toAdd, existing = false }
            remaining = remaining - toAdd
        end
    end

    -- Check if everything fits
    if remaining > 0 then
        TriggerClientEvent('SB:Client:Notify', source, 'Inventory is full!', 'error', 3000)
        return false
    end

    -- Execute the plan
    for _, entry in ipairs(plan) do
        if entry.existing then
            inv.items[entry.slot].amount = inv.items[entry.slot].amount + entry.add
        else
            inv.items[entry.slot] = {
                name = itemName,
                amount = entry.add,
                slot = entry.slot,
                metadata = metadata or {}
            }
        end
        TriggerClientEvent('sb_inventory:client:updateSlot', source, entry.slot, inv.items[entry.slot])
    end

    if not silent then
        TriggerClientEvent('SB:Client:Notify', source, ('Received %dx %s'):format(amount, itemData.label), 'success', 3000)
    end

    MySQL.insert('INSERT INTO sb_inventory_log (action, source, item, amount, metadata) VALUES (?, ?, ?, ?, ?)', {
        'add', citizenid, itemName, amount, json.encode(metadata or {})
    })

    SavePlayerInventory(source)
    return true
end

--- Remove item from a player's inventory
---@param source number
---@param itemName string
---@param amount number
---@param slot number|nil
---@return boolean
function RemoveItem(source, itemName, amount, slot)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return false end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return false end

    local itemData = GetItemData(itemName)
    if not itemData then return false end

    amount = amount or 1

    -- Find the item
    local targetSlot = nil
    if slot and inv.items[slot] and inv.items[slot].name == itemName then
        targetSlot = slot
    else
        for i = 1, inv.slots do
            if inv.items[i] and inv.items[i].name == itemName then
                targetSlot = i
                break
            end
        end
    end

    if not targetSlot then return false end

    -- Remove amount
    if inv.items[targetSlot].amount <= amount then
        inv.items[targetSlot] = nil
    else
        inv.items[targetSlot].amount = inv.items[targetSlot].amount - amount
    end

    -- Update client
    TriggerClientEvent('sb_inventory:client:updateSlot', source, targetSlot, inv.items[targetSlot])

    -- Log
    MySQL.insert('INSERT INTO sb_inventory_log (action, source, item, amount) VALUES (?, ?, ?, ?)', {
        'remove', citizenid, itemName, amount
    })

    SavePlayerInventory(source)
    return true
end

--- Check if player has item
---@param source number
---@param itemName string
---@param amount number|nil
---@return boolean
function HasItem(source, itemName, amount)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return false end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return false end

    amount = amount or 1
    local count = 0

    for _, item in pairs(inv.items) do
        if item and item.name == itemName then
            count = count + item.amount
        end
    end

    return count >= amount
end

--- Get item count in player inventory
---@param source number
---@param itemName string
---@return number
function GetItemCount(source, itemName)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return 0 end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return 0 end

    local count = 0
    for _, item in pairs(inv.items) do
        if item and item.name == itemName then
            count = count + item.amount
        end
    end

    return count
end

-- ========================================================================
-- STASH MANAGEMENT
-- ========================================================================

--- Load or create a stash
---@param stashId string
---@param stashData table|nil
---@return table
function LoadStash(stashId, stashData)
    if Inventories[stashId] then
        return Inventories[stashId]
    end

    local result = MySQL.single.await('SELECT * FROM sb_inventory_stashes WHERE identifier = ?', { stashId })

    if result then
        local stashItems = {}
        if result.items then
            local decoded = json.decode(result.items) or {}
            for k, v in pairs(decoded) do
                local numKey = tonumber(k)
                if numKey and v then stashItems[numKey] = v end
            end
        end
        Inventories[stashId] = {
            type = 'stash',
            slots = result.slots,
            items = stashItems,
            owner = result.owner,
            job = result.job
        }
    else
        -- Create new stash
        local slots = stashData and stashData.slots or Config.InventoryTypes.stash.slots

        Inventories[stashId] = {
            type = 'stash',
            slots = slots,
            items = {},
            owner = stashData and stashData.owner or nil,
            job = stashData and stashData.job or nil
        }

        MySQL.insert('INSERT INTO sb_inventory_stashes (identifier, label, type, owner, job, slots) VALUES (?, ?, ?, ?, ?, ?)', {
            stashId,
            stashData and stashData.label or 'Stash',
            stashData and stashData.type or 'shared',
            stashData and stashData.owner or nil,
            stashData and stashData.job or nil,
            slots
        })
    end

    return Inventories[stashId]
end

--- Save stash to database
---@param stashId string
function SaveStash(stashId)
    local inv = Inventories[stashId]
    if not inv or inv.type ~= 'stash' then return end

    MySQL.update('UPDATE sb_inventory_stashes SET items = ? WHERE identifier = ?', {
        json.encode(inv.items),
        stashId
    })
end

-- ========================================================================
-- VEHICLE INVENTORY
-- ========================================================================

--- Load vehicle trunk/glovebox
---@param plate string
---@param vehicleClass number
---@return table trunk, table glovebox
function LoadVehicleInventory(plate, vehicleClass)
    local trunkId = 'trunk_' .. plate
    local gloveboxId = 'glovebox_' .. plate

    if Inventories[trunkId] then
        return Inventories[trunkId], Inventories[gloveboxId]
    end

    local classData = Config.VehicleClasses[vehicleClass] or Config.VehicleClasses[1]
    local result = MySQL.single.await('SELECT * FROM sb_inventory_vehicles WHERE plate = ?', { plate })

    if result then
        local trunkItems = {}
        if result.trunk then
            local decoded = json.decode(result.trunk) or {}
            for k, v in pairs(decoded) do
                local numKey = tonumber(k)
                if numKey and v then trunkItems[numKey] = v end
            end
        end
        local gloveboxItems = {}
        if result.glovebox then
            local decoded = json.decode(result.glovebox) or {}
            for k, v in pairs(decoded) do
                local numKey = tonumber(k)
                if numKey and v then gloveboxItems[numKey] = v end
            end
        end
        Inventories[trunkId] = {
            type = 'trunk',
            slots = result.trunk_slots,
            items = trunkItems
        }
        Inventories[gloveboxId] = {
            type = 'glovebox',
            slots = result.glovebox_slots,
            items = gloveboxItems
        }
    else
        Inventories[trunkId] = {
            type = 'trunk',
            slots = classData.slots,
            items = {}
        }
        Inventories[gloveboxId] = {
            type = 'glovebox',
            slots = Config.GloveboxDefault.slots,
            items = {}
        }

        MySQL.insert('INSERT INTO sb_inventory_vehicles (plate, trunk_slots, glovebox_slots) VALUES (?, ?, ?)', {
            plate, classData.slots, Config.GloveboxDefault.slots
        })
    end

    return Inventories[trunkId], Inventories[gloveboxId]
end

--- Save vehicle inventory
---@param plate string
function SaveVehicleInventory(plate)
    local trunkId = 'trunk_' .. plate
    local gloveboxId = 'glovebox_' .. plate

    local trunk = Inventories[trunkId]
    local glovebox = Inventories[gloveboxId]
    if not trunk then return end

    MySQL.update('UPDATE sb_inventory_vehicles SET trunk = ?, glovebox = ? WHERE plate = ?', {
        json.encode(trunk.items),
        json.encode(glovebox and glovebox.items or {}),
        plate
    })
end

-- ========================================================================
-- DROP SYSTEM
-- ========================================================================

--- Create a world drop
---@param source number
---@param slot number
---@param amount number
function CreateDrop(source, slot, amount)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return end

    local item = inv.items[slot]
    if not item then return end

    amount = math.min(amount, item.amount)

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    DropCounter = DropCounter + 1
    local dropId = 'drop_' .. DropCounter

    -- Create drop inventory
    local dropItem = {
        name = item.name,
        amount = amount,
        slot = 1,
        metadata = item.metadata
    }

    Drops[dropId] = {
        items = { [1] = dropItem },
        coords = coords
    }

    Inventories[dropId] = {
        type = 'drop',
        slots = Config.InventoryTypes.drop.slots,
        items = { [1] = dropItem }
    }

    -- Remove from player
    if item.amount <= amount then
        inv.items[slot] = nil
    else
        inv.items[slot].amount = inv.items[slot].amount - amount
    end

    TriggerClientEvent('sb_inventory:client:updateSlot', source, slot, inv.items[slot])
    TriggerClientEvent('sb_inventory:client:createDrop', -1, dropId, coords)

    -- Update ground panel if inventory is open
    local function toStringKeys(tbl)
        local result = {}
        for k, v in pairs(tbl) do
            result[tostring(k)] = v
        end
        return result
    end
    TriggerClientEvent('sb_inventory:client:updateGround', source, {
        id = dropId,
        type = 'ground',
        slots = Config.InventoryTypes.drop.slots,
        items = toStringKeys(Inventories[dropId].items),
        label = 'Ground'
    })

    SavePlayerInventory(source)

    -- Auto-despawn after timeout
    SetTimeout(Config.Drops.despawnTime * 1000, function()
        if Drops[dropId] then
            Drops[dropId] = nil
            Inventories[dropId] = nil
            TriggerClientEvent('sb_inventory:client:removeDrop', -1, dropId)
        end
    end)
end

-- ========================================================================
-- MOVE ITEMS (drag-and-drop between slots/inventories)
-- ========================================================================

--- Move item between slots (same or different inventory)
---@param source number
---@param fromInv string
---@param toInv string
---@param fromSlot number
---@param toSlot number
---@param amount number
function MoveItem(source, fromInv, toInv, fromSlot, toSlot, amount)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    local srcInv = Inventories[fromInv]
    local dstInv = Inventories[toInv]

    if not srcInv or not dstInv then return end

    local srcItem = srcInv.items[fromSlot]
    if not srcItem then return end

    amount = math.min(amount, srcItem.amount)
    local itemData = GetItemData(srcItem.name)
    if not itemData then return end

    -- Validate target slot
    if toSlot < 1 or toSlot > dstInv.slots then return end

    local dstItem = dstInv.items[toSlot]

    -- Don't stack items with metadata (loaded mags, ammo boxes, etc.)
    local srcHasMeta = srcItem.metadata and next(srcItem.metadata) ~= nil
    local dstHasMeta = dstItem and dstItem.metadata and next(dstItem.metadata) ~= nil

    if dstItem and dstItem.name == srcItem.name and itemData.stackable and not srcHasMeta and not dstHasMeta then
        -- Stack items (check max_stack) - only if neither has metadata
        local maxStack = itemData.max_stack or 50
        if dstItem.amount + amount > maxStack then
            TriggerClientEvent('SB:Client:Notify', source, 'Stack is full!', 'error', 3000)
            return
        end
        dstInv.items[toSlot].amount = dstInv.items[toSlot].amount + amount
        if srcItem.amount <= amount then
            srcInv.items[fromSlot] = nil
        else
            srcInv.items[fromSlot].amount = srcInv.items[fromSlot].amount - amount
        end
    elseif not dstItem then
        -- Move to empty slot
        if srcItem.amount <= amount then
            dstInv.items[toSlot] = srcItem
            dstInv.items[toSlot].slot = toSlot
            srcInv.items[fromSlot] = nil
        else
            dstInv.items[toSlot] = {
                name = srcItem.name,
                amount = amount,
                slot = toSlot,
                metadata = srcItem.metadata
            }
            srcInv.items[fromSlot].amount = srcInv.items[fromSlot].amount - amount
        end
    elseif dstItem and fromInv == toInv then
        -- Swap items (same inventory only)
        srcInv.items[fromSlot] = dstItem
        srcInv.items[fromSlot].slot = fromSlot
        dstInv.items[toSlot] = srcItem
        dstInv.items[toSlot].slot = toSlot
    else
        -- Can't move (different item, different inventory, no swap)
        TriggerClientEvent('SB:Client:Notify', source, 'Cannot swap between inventories', 'error', 3000)
        return
    end

    -- Convert items to string-keyed table to prevent msgpack array reindexing
    local function moveToStringKeys(tbl)
        local result = {}
        for k, v in pairs(tbl) do
            result[tostring(k)] = v
        end
        return result
    end

    -- Update client
    TriggerClientEvent('sb_inventory:client:refreshInventory', source, fromInv, moveToStringKeys(srcInv.items), toInv, moveToStringKeys(dstInv.items))

    -- Save affected inventories
    if fromInv:find('player_') then SavePlayerInventory(source) end
    if toInv:find('player_') then SavePlayerInventory(source) end
    if fromInv:find('trunk_') or fromInv:find('glovebox_') then
        local plate = fromInv:gsub('trunk_', ''):gsub('glovebox_', '')
        SaveVehicleInventory(plate)
    end
    if toInv:find('trunk_') or toInv:find('glovebox_') then
        local plate = toInv:gsub('trunk_', ''):gsub('glovebox_', '')
        SaveVehicleInventory(plate)
    end
    if fromInv:find('stash_') or (not fromInv:find('player_') and not fromInv:find('trunk_') and not fromInv:find('glovebox_') and not fromInv:find('drop_')) then
        SaveStash(fromInv)
    end
    if toInv:find('stash_') or (not toInv:find('player_') and not toInv:find('trunk_') and not toInv:find('glovebox_') and not toInv:find('drop_')) then
        SaveStash(toInv)
    end
end

-- ========================================================================
-- EVENTS
-- ========================================================================

--- Player loaded
AddEventHandler('SB:Server:OnPlayerLoaded', function(source, Player)
    LoadPlayerInventory(source)
end)

--- Load inventories for all connected players on resource start/restart
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Wait for database to be ready
    Wait(2000)

    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local source = tonumber(playerId)
        if source then
            LoadPlayerInventory(source)
        end
    end
    if #players > 0 then
        print(('[sb_inventory] Reloaded inventories for %d connected players'):format(#players))
    end
end)

--- Player dropped
AddEventHandler('playerDropped', function()
    local source = source
    SavePlayerInventory(source)

    -- Clean up inventory from memory
    local citizenid = PlayerCitizenIds[source]
    if citizenid then
        Inventories['player_' .. citizenid] = nil
    end
    PlayerCitizenIds[source] = nil
end)

--- Open inventory request
RegisterNetEvent('sb_inventory:server:openInventory', function(invType, identifier, data)
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    local playerInvId = 'player_' .. citizenid
    local playerInv = Inventories[playerInvId]
    if not playerInv then
        LoadPlayerInventory(source)
        playerInv = Inventories[playerInvId]
        if not playerInv then return end
    end

    local secondaryInv = nil
    local secondaryId = nil

    if invType == 'player' then
        -- Check if client detected a nearby ground drop
        local groundDropId = data and data.groundDropId or nil
        if groundDropId and Inventories[groundDropId] then
            secondaryInv = Inventories[groundDropId]
            secondaryId = groundDropId
        end
    elseif invType == 'trunk' then
        local plate = identifier
        local vehicleClass = data and data.class or 1
        local trunk, _ = LoadVehicleInventory(plate, vehicleClass)
        secondaryInv = trunk
        secondaryId = 'trunk_' .. plate
    elseif invType == 'glovebox' then
        local plate = identifier
        local vehicleClass = data and data.class or 1
        local _, glovebox = LoadVehicleInventory(plate, vehicleClass)
        secondaryInv = glovebox
        secondaryId = 'glovebox_' .. plate
    elseif invType == 'stash' then
        local stash = LoadStash(identifier, data)
        if stash.job then
            local player = SBCore.Functions.GetPlayer(source)
            if player and player.PlayerData.job and player.PlayerData.job.name ~= stash.job then
                TriggerClientEvent('SB:Client:Notify', source, 'No access!', 'error', 3000)
                return
            end
        end
        secondaryInv = stash
        secondaryId = identifier
    elseif invType == 'drop' then
        local drop = Inventories[identifier]
        if not drop then return end
        secondaryInv = drop
        secondaryId = identifier
    end

    -- Convert items to string-keyed table to prevent msgpack array reindexing
    local function toStringKeys(tbl)
        local result = {}
        for k, v in pairs(tbl) do
            result[tostring(k)] = v
        end
        return result
    end

    -- Get player stats for UI header
    local playerStats = { cash = 0, bank = 0, cid = citizenid }
    local Player = SBCore.Functions.GetPlayer(source)
    if Player and Player.PlayerData and Player.PlayerData.money then
        playerStats.cash = Player.PlayerData.money.cash or 0
        playerStats.bank = Player.PlayerData.money.bank or 0
    end

    -- Determine secondary label
    local secondaryLabel = nil
    if secondaryInv then
        if data and data.label then
            secondaryLabel = data.label
        elseif invType == 'player' then
            secondaryLabel = 'Ground'
        else
            secondaryLabel = invType:sub(1, 1):upper() .. invType:sub(2)
        end
    end

    -- Send to client
    TriggerClientEvent('sb_inventory:client:openInventory', source, {
        playerInv = {
            id = playerInvId,
            type = 'player',
            slots = playerInv.slots,
            items = toStringKeys(playerInv.items)
        },
        secondaryInv = secondaryInv and {
            id = secondaryId,
            type = (invType == 'player') and 'ground' or secondaryInv.type,
            slots = secondaryInv.slots,
            items = toStringKeys(secondaryInv.items),
            label = secondaryLabel
        } or nil,
        items = ItemDefs,
        playerStats = playerStats
    })
end)

--- Move item request from client
RegisterNetEvent('sb_inventory:server:moveItem', function(fromInv, toInv, fromSlot, toSlot, amount)
    local source = source
    MoveItem(source, fromInv, toInv, fromSlot, toSlot, amount)
end)

--- Use item request
RegisterNetEvent('sb_inventory:server:useItem', function(slot)
    local source = source

    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return end

    local item = inv.items[slot]
    if not item then return end

    local itemData = GetItemData(item.name)
    if not itemData then return end
    if not itemData.useable then return end

    -- Block consumption if already full
    local Player = SBCore.Functions.GetPlayer(source)
    if Player and Player.PlayerData.metadata then
        if itemData.category == 'food' and (Player.PlayerData.metadata.hunger or 0) >= 100 then
            TriggerClientEvent('SB:Client:Notify', source, "You're not hungry!", 'error', 2000)
            return
        end
        if itemData.category == 'drink' and (Player.PlayerData.metadata.thirst or 0) >= 100 then
            TriggerClientEvent('SB:Client:Notify', source, "You're not thirsty!", 'error', 2000)
            return
        end
    end

    -- Send item use to client with category for animations
    TriggerClientEvent('sb_inventory:client:useItem', source, item.name, slot, item.metadata, itemData.category, itemData.shouldClose)

    -- Trigger sb_core useable item callbacks (CreateUseableItem handlers in other scripts)
    if SBCore and SBCore.Functions and SBCore.Functions.UseItem then
        local ok, err = pcall(SBCore.Functions.UseItem, source, item.name)
        if not ok then
            print('^1[sb_inventory]^7 UseItem callback error for "' .. tostring(item.name) .. '": ' .. tostring(err))
        end
    end

    -- Notify other server scripts (sb_metabolism listens for this)
    TriggerEvent('sb_inventory:server:itemUsed', source, item.name, 1, item.metadata, itemData.category)

    -- Don't consume certain categories on use (they're reusable)
    local nonConsumableCategories = {
        ['weapon'] = true,
        ['ammo'] = true,
        ['magazine'] = true,
        ['misc'] = true,      -- Keys, tools, etc.
        ['document'] = true,  -- ID cards, licenses, etc.
        ['vehicle'] = true,   -- Car keys, vehicle items
        ['tool'] = true,      -- Jerry cans, syphon kits, etc.
        ['tech'] = true,      -- Phone, electronics
        ['electronics'] = true, -- Phone, electronics
        ['police'] = true,    -- Police equipment (radio, handcuffs, radar_gun, etc.)
        ['drug'] = true,      -- Drug items: sb_drugs handles removal via CreateUseableItem callbacks
    }

    if not nonConsumableCategories[itemData.category] then
        -- Consume the item (remove 1 from stack)
        if item.amount <= 1 then
            inv.items[slot] = nil
        else
            inv.items[slot].amount = inv.items[slot].amount - 1
        end

        -- Update client slot
        TriggerClientEvent('sb_inventory:client:updateSlot', source, slot, inv.items[slot])

        -- Save
        SavePlayerInventory(source)
    end

    -- Log usage
    MySQL.insert('INSERT INTO sb_inventory_log (action, source, item, amount) VALUES (?, ?, ?, ?)', {
        'use', citizenid, item.name, 1
    })
end)

--- Drop item request
RegisterNetEvent('sb_inventory:server:dropItem', function(slot, amount)
    local source = source
    CreateDrop(source, slot, amount)
end)

--- Give item to nearby player
RegisterNetEvent('sb_inventory:server:giveItem', function(targetId, slot, amount)
    local source = source
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return end

    local item = inv.items[slot]
    if not item then return end

    amount = math.min(amount, item.amount)

    -- Check distance
    local srcPed = GetPlayerPed(source)
    local tgtPed = GetPlayerPed(targetId)
    if not srcPed or not tgtPed then return end

    local srcCoords = GetEntityCoords(srcPed)
    local tgtCoords = GetEntityCoords(tgtPed)
    local dist = #(srcCoords - tgtCoords)

    if dist > Config.Distances.give then
        TriggerClientEvent('SB:Client:Notify', source, 'Player too far away!', 'error', 3000)
        return
    end

    -- Add to target
    local success = AddItem(targetId, item.name, amount, item.metadata)
    if success then
        RemoveItem(source, item.name, amount, slot)
        local itemData = GetItemData(item.name)
        TriggerClientEvent('SB:Client:Notify', source, ('Gave %dx %s'):format(amount, itemData.label), 'info', 3000)
    end
end)

--- Close inventory
RegisterNetEvent('sb_inventory:server:closeInventory', function()
    local source = source
    -- Clean up any drop that's now empty
    for dropId, drop in pairs(Drops) do
        local inv = Inventories[dropId]
        if inv then
            local hasItems = false
            for _, item in pairs(inv.items) do
                if item then hasItems = true break end
            end
            if not hasItems then
                Drops[dropId] = nil
                Inventories[dropId] = nil
                TriggerClientEvent('sb_inventory:client:removeDrop', -1, dropId)
            end
        end
    end
end)

-- ========================================================================
-- EXPORTS (for other scripts to use)
-- ========================================================================
--- Get all items of a specific type from a player's inventory (with metadata)
---@param source number
---@param itemName string
---@return table items array of {name, amount, slot, metadata}
function GetItemsByName(source, itemName)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return {} end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return {} end

    local results = {}
    for i = 1, inv.slots do
        local item = inv.items[i]
        if item and item.name == itemName then
            results[#results + 1] = {
                name = item.name,
                amount = item.amount,
                slot = item.slot or i,
                metadata = item.metadata or {}
            }
        end
    end
    return results
end

--- Get how many more of an item a player can carry
---@param source number
---@param itemName string
---@return number
function GetCanCarryAmount(source, itemName)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return 0 end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return 0 end

    local itemData = GetItemData(itemName)
    if not itemData then return 0 end

    local maxStack = itemData.max_stack or 50
    local canCarry = 0

    -- Count remaining space in existing stacks + empty slots
    for i = 1, inv.slots do
        if inv.items[i] then
            if inv.items[i].name == itemName and itemData.stackable then
                canCarry = canCarry + (maxStack - inv.items[i].amount)
            end
        else
            -- Empty slot can hold a full stack
            canCarry = canCarry + maxStack
        end
    end

    return canCarry
end

--- Get first empty slot in player inventory
---@param source number
---@return number|nil
function GetFreeSlot(source)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return nil end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return nil end

    for i = 1, inv.slots do
        if not inv.items[i] then
            return i
        end
    end
    return nil
end

--- Set metadata on an existing item in a player's inventory
---@param source number
---@param slot number
---@param metadata table
---@return boolean
function SetItemMetadata(source, slot, metadata)
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then return false end

    local identifier = 'player_' .. citizenid
    local inv = Inventories[identifier]
    if not inv then return false end

    if not inv.items[slot] then return false end
    if not metadata then return false end

    -- Merge new metadata into existing
    if not inv.items[slot].metadata then
        inv.items[slot].metadata = {}
    end
    for k, v in pairs(metadata) do
        inv.items[slot].metadata[k] = v
    end

    -- Update client
    TriggerClientEvent('sb_inventory:client:updateSlot', source, slot, inv.items[slot])

    -- Persist
    SavePlayerInventory(source)
    return true
end

--- Purge all instances of an item from ALL loaded inventories (players, drops, stashes)
--- where a metadata field matches a given value.
--- Used for invalidation (e.g. removing old ID cards when a new one is issued).
---@param itemName string
---@param metaKey string
---@param metaValue any
---@return number count of items removed
function PurgeItemGlobal(itemName, metaKey, metaValue)
    local removed = 0
    for invId, inv in pairs(Inventories) do
        if inv.items then
            for slot, item in pairs(inv.items) do
                if item and item.name == itemName and item.metadata and item.metadata[metaKey] == metaValue then
                    inv.items[slot] = nil
                    removed = removed + 1

                    -- If this is a player inventory, notify their client to update the slot
                    if inv.type == 'player' then
                        local cid = invId:gsub('player_', '')
                        for src, cachedCid in pairs(PlayerCitizenIds) do
                            if cachedCid == cid then
                                TriggerClientEvent('sb_inventory:client:updateSlot', src, slot, nil)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return removed
end

exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('HasItem', HasItem)
exports('GetItemCount', GetItemCount)
exports('GetItemData', GetItemData)
exports('GetItemsByName', GetItemsByName)
exports('GetCanCarryAmount', GetCanCarryAmount)
exports('GetFreeSlot', GetFreeSlot)
exports('SetItemMetadata', SetItemMetadata)
exports('LoadStash', LoadStash)
exports('SaveStash', SaveStash)
exports('PurgeItemGlobal', PurgeItemGlobal)

--- Set items directly on a stash (bypasses export copy issue)
---@param stashId string
---@param items table  -- { [slot] = { name, amount, slot, metadata } }
exports('SetStashItems', function(stashId, items)
    if not Inventories[stashId] then return false end
    Inventories[stashId].items = items
    return true
end)

-- ========================================================================
-- COMMANDS (Admin/Debug)
-- ========================================================================
RegisterCommand('giveitem', function(source, args)
    if source == 0 then return end -- Console only with target
    local player = SBCore.Functions.GetPlayer(source)
    if not player then return end

    -- Check admin (TODO: proper admin system)
    local itemName = args[1]
    local amount = tonumber(args[2]) or 1

    if not itemName then
        TriggerClientEvent('SB:Client:Notify', source, 'Usage: /giveitem [item] [amount]', 'info', 5000)
        return
    end

    local success = AddItem(source, itemName, amount)
    if not success then
        TriggerClientEvent('SB:Client:Notify', source, 'Failed to give item!', 'error', 3000)
    end
end, false)

RegisterCommand('clearinv', function(source, args)
    if source == 0 then return end
    local citizenid = GetPlayerIdentifier(source)
    if not citizenid then
        print('[sb_inventory] clearinv: no citizenid for source ' .. tostring(source))
        return
    end

    print(('[sb_inventory] clearinv: clearing for citizenid=%s'):format(citizenid))

    -- Clear in-memory inventory
    local identifier = 'player_' .. citizenid
    if Inventories[identifier] then
        Inventories[identifier].items = {}
        print('[sb_inventory] clearinv: in-memory cleared for ' .. identifier)
    else
        print('[sb_inventory] clearinv: no in-memory inventory for ' .. identifier)
    end

    -- Force clear in database directly (no callback, synchronous)
    MySQL.update.await('UPDATE players SET inventory = NULL WHERE citizenid = ?', { citizenid })
    print('[sb_inventory] clearinv: database updated')

    TriggerClientEvent('SB:Client:Notify', source, 'Inventory cleared!', 'success', 3000)
end, false)

-- ========================================================================
-- AUTO-SAVE LOOP
-- ========================================================================
CreateThread(function()
    while true do
        Wait(300000) -- Save all inventories every 5 minutes
        for id, inv in pairs(Inventories) do
            if inv.type == 'stash' then
                SaveStash(id)
            end
        end
        print('[sb_inventory] Auto-saved all stash inventories')
    end
end)

print('[sb_inventory] Server-side loaded successfully')
