-- sb_mechanic_v2 | Phase 2: Client Crafting
-- Bench targets, NUI bridge, minigame integration

local SB = exports['sb_core']:GetCoreObject()
local CraftingOpen = false
local CurrentBenchId = nil

-- ===================================================================
-- CRAFTING BENCH TARGETS
-- ===================================================================
CreateThread(function()
    -- Add sb_target sphere zones for each crafting station location
    for _, station in ipairs(Config.CraftingStations) do
        exports['sb_target']:AddSphereZone('craft_' .. station.id, station.coords, 1.0, {
            {
                label = 'Use ' .. station.label,
                icon = 'fas fa-hammer',
                distance = 2.0,
                canInteract = function()
                    local Player = SB.Functions.GetPlayerData()
                    if not Player or not Config.IsMechanicJob(Player.job.name) then return false end
                    return true
                end,
                action = function()
                    OpenCraftingBench(station.id)
                end,
            },
        })
    end
end)

-- ===================================================================
-- OPEN CRAFTING BENCH
-- ===================================================================
function OpenCraftingBench(benchId)
    if CraftingOpen then return end

    SB.Functions.TriggerCallback('sb_mechanic_v2:getCraftingRecipes', function(data)
        if not data then
            exports['sb_notify']:Notify('Failed to load recipes', 'error', 3000)
            return
        end

        CraftingOpen = true
        CurrentBenchId = benchId

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openCrafting',
            benchId = data.benchId,
            benchLabel = data.benchLabel,
            recipes = data.recipes,
            craftingLevel = data.craftingLevel,
            qualityTier = data.qualityTier,
        })
    end, benchId)
end

-- ===================================================================
-- CLOSE CRAFTING NUI
-- ===================================================================
function CloseCraftingNUI()
    if not CraftingOpen then return end
    CraftingOpen = false
    CurrentBenchId = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCrafting' })
end

-- ===================================================================
-- NUI CALLBACK: Craft item
-- ===================================================================
RegisterNUICallback('craft', function(data, cb)
    cb('ok')

    local recipeId = data.recipeId
    if not recipeId then return end

    local recipe = Recipes.All[recipeId]
    if not recipe then return end

    -- Close NUI first
    CloseCraftingNUI()

    -- Play crafting animation
    local ped = PlayerPedId()
    local animDict = 'mini@repair'
    local animName = 'fixing_a_player'

    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Minigame or progress bar
    local minigamePassed = true

    if recipe.minigame then
        -- Use sb_minigame
        local finished = false
        exports['sb_minigame']:Start({
            type = recipe.minigame.type,
            difficulty = recipe.minigame.difficulty,
            rounds = recipe.minigame.rounds,
            label = recipe.label,
        }, function(success, score)
            minigamePassed = success
            finished = true
        end)

        -- Wait for minigame to finish
        while not finished do
            Wait(100)
        end
    else
        -- Fluid station: just a progress bar
        local progressFinished = false
        local progressSuccess = false
        exports['sb_progressbar']:Start({
            duration = recipe.craftTime,
            label = 'Mixing ' .. recipe.label,
            canCancel = true,
            onComplete = function()
                progressSuccess = true
                progressFinished = true
            end,
            onCancel = function()
                progressSuccess = false
                progressFinished = true
            end,
        })

        while not progressFinished do
            Wait(100)
        end
        minigamePassed = progressSuccess
    end

    -- Stop animation
    ClearPedTasks(ped)

    if not minigamePassed then
        exports['sb_notify']:Notify('Crafting failed - materials saved', 'error', 3000)
        return
    end

    -- Server craft callback
    SB.Functions.TriggerCallback('sb_mechanic_v2:craftItem', function(success, result)
        if success and result then
            local qualityText = result.qualityLabel or 'Standard'
            local msg = ('Crafted %dx %s (%s quality)'):format(
                result.resultAmount, result.resultLabel, qualityText
            )
            exports['sb_notify']:Notify(msg, 'success', 4000)

            if result.xpGain and result.xpGain > 0 then
                exports['sb_notify']:Notify('+' .. result.xpGain .. ' Crafting XP', 'info', 2000)
            end
        else
            exports['sb_notify']:Notify('Crafting failed - check materials', 'error', 3000)
        end
    end, recipeId)
end)

-- ===================================================================
-- NUI CALLBACK: Close crafting
-- ===================================================================
RegisterNUICallback('closeCrafting', function(data, cb)
    cb('ok')
    CloseCraftingNUI()
end)
