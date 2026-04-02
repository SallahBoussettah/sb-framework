-- sb_companies | Server: Shop Storage CRUD + Dispenser Callbacks
-- Mechanics grab parts from workshop dispensers via these callbacks

local SB = SBCompanies.SB

-- ===================================================================
-- HELPER: Get item label from sb_inventory's item registry
-- Falls back to item_name if not found
-- ===================================================================
local function GetItemLabel(itemName)
    local ok, itemData = pcall(exports['sb_inventory'].GetItemData, exports['sb_inventory'], itemName)
    if ok and itemData and itemData.label then
        return itemData.label
    end
    return itemName
end

-- ===================================================================
-- CALLBACK: Get shop storage items filtered by dispenser categories
-- Client sends: shopId, categories (array of category strings)
-- Returns: array of { item_name, label, quantity, quality, category }
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:getShopStorage', function(source, cb, shopId, categories)
    -- Validate player is a mechanic
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if not IsMechanicJob(jobName) then
        cb(false, 'You must be a mechanic to access storage')
        return
    end

    -- Validate shopId
    if not shopId or type(shopId) ~= 'string' then
        cb(false, 'Invalid shop')
        return
    end

    local shopCfg = Config.ShopById[shopId]
    if not shopCfg then
        cb(false, 'Shop not found')
        return
    end

    -- Validate categories
    if not categories or type(categories) ~= 'table' or #categories == 0 then
        cb(false, 'No categories specified')
        return
    end

    -- Build a lookup set for the requested categories
    local categorySet = {}
    for _, cat in ipairs(categories) do
        if type(cat) == 'string' then
            categorySet[cat] = true
        end
    end

    -- Get storage for this shop
    local storage = SBCompanies.ShopStorage[shopId]
    if not storage then
        cb({})
        return
    end

    -- Filter items by matching categories from Config.ItemCategories
    local results = {}
    for _, entry in pairs(storage) do
        if entry.quantity > 0 then
            local itemCategory = Config.ItemCategories[entry.item_name]
            if itemCategory and categorySet[itemCategory] then
                results[#results + 1] = {
                    item_name = entry.item_name,
                    label     = GetItemLabel(entry.item_name),
                    quantity  = entry.quantity,
                    quality   = entry.quality,
                    category  = itemCategory,
                }
            end
        end
    end

    -- Sort alphabetically by label for consistent UI
    table.sort(results, function(a, b)
        return a.label < b.label
    end)

    cb(results)
end)

-- ===================================================================
-- CALLBACK: Grab item from shop storage into player inventory
-- Client sends: shopId, itemName, quantity, quality
-- Validates: mechanic job, storage has enough, player can carry
-- ===================================================================
SB.Functions.CreateCallback('sb_companies:grabFromStorage', function(source, cb, shopId, itemName, quantity, quality)
    -- Validate player is a mechanic
    local Player = SB.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end

    local jobName = Player.PlayerData.job and Player.PlayerData.job.name
    if not IsMechanicJob(jobName) then
        cb(false, 'You must be a mechanic to grab parts')
        return
    end

    -- Validate inputs
    if not shopId or type(shopId) ~= 'string' then
        cb(false, 'Invalid shop')
        return
    end

    if not Config.ShopById[shopId] then
        cb(false, 'Shop not found')
        return
    end

    if not itemName or type(itemName) ~= 'string' then
        cb(false, 'Invalid item')
        return
    end

    quantity = tonumber(quantity)
    if not quantity or quantity <= 0 or quantity ~= math.floor(quantity) then
        cb(false, 'Invalid quantity')
        return
    end

    quality = quality or 'standard'
    if type(quality) ~= 'string' then
        cb(false, 'Invalid quality')
        return
    end

    -- Validate quality tier exists
    local qualityTier = Enums.QualityByName[quality]
    if not qualityTier then
        cb(false, 'Unknown quality tier: ' .. tostring(quality))
        return
    end

    -- Check shop storage has enough
    local storage = SBCompanies.ShopStorage[shopId]
    if not storage then
        cb(false, 'Storage is empty')
        return
    end

    local key = itemName .. ':' .. quality
    local entry = storage[key]
    if not entry or entry.quantity < quantity then
        local available = entry and entry.quantity or 0
        cb(false, 'Not enough in storage (have ' .. available .. ')')
        return
    end

    -- Check player can carry
    local canCarry = exports['sb_inventory']:GetCanCarryAmount(source, itemName)
    if canCarry < quantity then
        if canCarry == 0 then
            cb(false, 'Inventory full')
        else
            cb(false, 'Can only carry ' .. canCarry .. ' more')
        end
        return
    end

    -- Build item metadata with quality info
    local metadata = {
        quality     = quality,
        maxRestore  = qualityTier.maxRestore,
        degradeMult = qualityTier.degradeMult,
    }

    -- Remove from storage first (server-authoritative)
    local removed = RemoveFromShopStorage(shopId, itemName, quantity, quality)
    if not removed then
        cb(false, 'Failed to remove from storage')
        return
    end

    -- Add to player inventory
    local added = exports['sb_inventory']:AddItem(source, itemName, quantity, metadata)
    if not added then
        -- Rollback: put items back into storage
        AddToShopStorage(shopId, itemName, quantity, quality)
        cb(false, 'Failed to add to inventory')
        return
    end

    local itemLabel = GetItemLabel(itemName)

    if Config.Debug then
        print(string.format('^2[sb_companies]^7 %s grabbed %dx %s (%s) from %s',
            Player.PlayerData.citizenid, quantity, itemLabel, quality, shopId))
    end

    cb(true, {
        item_name = itemName,
        label     = itemLabel,
        quantity  = quantity,
        quality   = quality,
    })
end)
