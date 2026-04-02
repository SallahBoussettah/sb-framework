-- sb_mechanic_v2 | Phase 2: Server Crafting Logic
-- Callbacks for recipe browsing, crafting with quality tiers, XP, cooldowns

local SB = SBMechanic.SB

-- Anti-exploit: per-player craft cooldowns { [source] = { [recipeId] = timestamp } }
local CraftCooldowns = {}

-- ===================================================================
-- CALLBACK: Get crafting recipes for a bench
-- ===================================================================
SB.Functions.CreateCallback('sb_mechanic_v2:getCraftingRecipes', function(source, cb, benchId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    -- Verify mechanic job
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then
        return cb(nil)
    end

    -- Validate bench
    if not Recipes.Benches[benchId] then
        return cb(nil)
    end

    -- Get player crafting level
    local citizenid = Player.PlayerData.citizenid
    local craftingLevel = GetLevel(citizenid, 'xp_crafting')

    -- Get available recipes for this bench + level
    local available = Recipes.GetAvailable(benchId, craftingLevel)

    -- Build response with ingredient counts from inventory
    local recipesData = {}
    for _, recipe in ipairs(available) do
        local ingredientData = {}
        for _, ing in ipairs(recipe.ingredients) do
            local have = exports['sb_inventory']:GetItemCount(source, ing.item)
            table.insert(ingredientData, {
                item = ing.item,
                label = (CraftItems.ByName[ing.item] and CraftItems.ByName[ing.item].label) or ing.item,
                amount = ing.amount,
                have = have or 0,
            })
        end

        table.insert(recipesData, {
            id = recipe.id,
            label = recipe.label,
            bench = recipe.bench,
            skillReq = recipe.skillReq,
            craftTime = recipe.craftTime,
            hasMinigame = recipe.minigame ~= nil,
            resultAmount = recipe.resultAmount or 1,
            resultLabel = (CraftItems.ByName[recipe.result] and CraftItems.ByName[recipe.result].label) or recipe.label,
            resultItem = recipe.result,
            ingredients = ingredientData,
            xpReward = recipe.xpReward,
        })
    end

    cb({
        recipes = recipesData,
        benchId = benchId,
        benchLabel = Recipes.Benches[benchId].label,
        craftingLevel = craftingLevel,
        qualityTier = Config.QualityTiers[craftingLevel],
    })
end)

-- ===================================================================
-- CALLBACK: Craft an item
-- ===================================================================
SB.Functions.CreateCallback('sb_mechanic_v2:craftItem', function(source, cb, recipeId)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return cb(false, nil) end

    -- Verify mechanic job
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then
        return cb(false, nil)
    end

    -- Get recipe
    local recipe = Recipes.All[recipeId]
    if not recipe then
        return cb(false, nil)
    end

    local citizenid = Player.PlayerData.citizenid
    local craftingLevel = GetLevel(citizenid, 'xp_crafting')

    -- Check skill requirement
    if craftingLevel < recipe.skillReq then
        return cb(false, nil)
    end

    -- Check cooldown
    local now = os.time()
    if CraftCooldowns[source] and CraftCooldowns[source][recipeId] then
        local elapsed = now - CraftCooldowns[source][recipeId]
        if elapsed < Config.CraftCooldown then
            return cb(false, nil)
        end
    end

    -- Check all ingredients
    for _, ing in ipairs(recipe.ingredients) do
        local have = exports['sb_inventory']:GetItemCount(source, ing.item)
        if (have or 0) < ing.amount then
            return cb(false, nil)
        end
    end

    -- Check if player can carry the result
    local canCarry = exports['sb_inventory']:GetCanCarryAmount(source, recipe.result)
    if (canCarry or 0) < (recipe.resultAmount or 1) then
        TriggerClientEvent('sb_notify:client:Notify', source, 'Inventory full', 'error', 3000)
        return cb(false, nil)
    end

    -- Remove ingredients
    for _, ing in ipairs(recipe.ingredients) do
        local removed = exports['sb_inventory']:RemoveItem(source, ing.item, ing.amount)
        if not removed then
            -- Rollback shouldn't be needed since we validated, but safety
            return cb(false, nil)
        end
    end

    -- Determine quality tier
    local tier = Config.QualityTiers[craftingLevel] or Config.QualityTiers[1]
    local metadata = {
        quality = tier.name,
        qualityLabel = tier.label,
        maxRestore = tier.maxRestore,
        degradeMult = tier.degradeMult,
        craftedBy = citizenid,
        craftedAt = os.time(),
    }

    -- Add crafted item to inventory
    local added = exports['sb_inventory']:AddItem(source, recipe.result, recipe.resultAmount or 1, metadata)
    if not added then
        -- Failed to add — return ingredients (best effort)
        for _, ing in ipairs(recipe.ingredients) do
            exports['sb_inventory']:AddItem(source, ing.item, ing.amount)
        end
        return cb(false, nil)
    end

    -- Set cooldown
    if not CraftCooldowns[source] then CraftCooldowns[source] = {} end
    CraftCooldowns[source][recipeId] = now

    -- Award XP
    if recipe.xpReward and recipe.xpReward > 0 then
        AddXP(citizenid, 'xp_crafting', recipe.xpReward)
    end

    -- Increment parts_crafted stat
    local skills = SBMechanic.Skills[citizenid]
    if skills then
        skills.parts_crafted = (skills.parts_crafted or 0) + 1
        SaveSkills(citizenid)
    end

    -- Return success with quality info
    cb(true, {
        quality = tier.name,
        qualityLabel = tier.label,
        resultLabel = (CraftItems.ByName[recipe.result] and CraftItems.ByName[recipe.result].label) or recipe.label,
        resultAmount = recipe.resultAmount or 1,
        xpGain = recipe.xpReward,
    })
end)

-- Cleanup cooldowns on disconnect
AddEventHandler('playerDropped', function()
    CraftCooldowns[source] = nil
end)
