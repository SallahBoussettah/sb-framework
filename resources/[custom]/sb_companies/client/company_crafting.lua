-- sb_companies | Client: Company Crafting / Production
-- Company workers craft items at the production area
-- Uses minigame for solid parts, progress bar for fluids

local SB = exports['sb_core']:GetCoreObject()

local productionOpen = false
local isCrafting = false

-- ============================================================================
-- CRAFTING ANIMATION
-- ============================================================================

local CRAFT_ANIM_DICT = 'mini@repair'
local CRAFT_ANIM_NAME = 'fixing_a_player'

local function PlayCraftingAnimation()
    RequestAnimDict(CRAFT_ANIM_DICT)
    local timeout = 0
    while not HasAnimDictLoaded(CRAFT_ANIM_DICT) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then return end
    end

    local ped = PlayerPedId()
    TaskPlayAnim(ped, CRAFT_ANIM_DICT, CRAFT_ANIM_NAME, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function StopCraftingAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
end

-- ============================================================================
-- EVENT: Open Production Terminal
-- ============================================================================

RegisterNetEvent('sb_companies:openProduction', function(companyId)
    if productionOpen then return end
    if isCrafting then return end
    if not companyId then return end

    -- Validate employee status
    if not IsCompanyEmployee(companyId, {'worker', 'manager'}) then
        exports['sb_notify']:Notify('You are not authorized to use production', 'error', 3000)
        return
    end

    SB.Functions.TriggerCallback('sb_companies:getPendingProduction', function(data)
        if not data then
            exports['sb_notify']:Notify('Failed to load production queue', 'error', 3000)
            return
        end

        local companyCfg = Config.CompanyById[companyId]
        local companyLabel = companyCfg and companyCfg.label or 'Unknown Company'

        productionOpen = true
        SetNuiFocus(true, true)
        TriggerEvent('sb_hud:setVisible', false)

        SendNUIMessage({
            action = 'openProduction',
            data = {
                companyId = companyId,
                companyLabel = companyLabel,
                orders = data.orders or {},
            }
        })
    end, companyId)
end)

-- ============================================================================
-- CLOSE PRODUCTION
-- ============================================================================

local function CloseProduction()
    if not productionOpen then return end
    productionOpen = false

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'closeProduction' })
end

-- ============================================================================
-- CRAFTING FLOW
-- ============================================================================

local function DoCrafting(companyId, orderId, itemName, recipe)
    if isCrafting then return end
    isCrafting = true

    -- Close the NUI so player sees the game world
    CloseProduction()

    -- Tell server we are starting production
    SB.Functions.TriggerCallback('sb_companies:startProduction', function(startResult)
        if not startResult or not startResult.success then
            exports['sb_notify']:Notify(startResult and startResult.message or 'Cannot start production', 'error', 3000)
            isCrafting = false
            return
        end

        -- Play crafting animation
        PlayCraftingAnimation()

        local craftSuccess = false

        if recipe and recipe.minigame then
            -- Solid part: use minigame
            exports['sb_minigame']:Start({
                type = recipe.minigame.type,
                difficulty = recipe.minigame.difficulty,
                rounds = recipe.minigame.rounds,
                label = recipe.label or 'Crafting...',
            }, function(success, score)
                craftSuccess = success

                -- Stop animation
                StopCraftingAnimation()

                -- Tell server the result
                SB.Functions.TriggerCallback('sb_companies:completeProduction', function(completeResult)
                    if completeResult and completeResult.success then
                        if craftSuccess then
                            local qualityLabel = completeResult.quality or 'standard'
                            exports['sb_notify']:Notify('Crafted ' .. (recipe.label or itemName) .. ' (' .. qualityLabel .. ')', 'success', 4000)
                        else
                            exports['sb_notify']:Notify('Crafting failed! Materials consumed.', 'error', 3000)
                        end
                    else
                        exports['sb_notify']:Notify(completeResult and completeResult.message or 'Production error', 'error', 3000)
                    end

                    isCrafting = false
                end, companyId, orderId, itemName, craftSuccess)
            end)
        else
            -- Fluid: use progress bar instead (no minigame)
            local craftTime = (recipe and recipe.craftTime) or 3000

            exports['sb_progressbar']:Show(craftTime, recipe and recipe.label or 'Mixing fluids...')
            Wait(craftTime)

            craftSuccess = true

            -- Stop animation
            StopCraftingAnimation()

            -- Tell server the result
            SB.Functions.TriggerCallback('sb_companies:completeProduction', function(completeResult)
                if completeResult and completeResult.success then
                    exports['sb_notify']:Notify('Produced ' .. (recipe and recipe.label or itemName), 'success', 4000)
                else
                    exports['sb_notify']:Notify(completeResult and completeResult.message or 'Production error', 'error', 3000)
                end

                isCrafting = false
            end, companyId, orderId, itemName, craftSuccess)
        end
    end, companyId, orderId, itemName)
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('startCraft', function(data, cb)
    if not productionOpen then cb('ok') return end
    if isCrafting then
        exports['sb_notify']:Notify('Already crafting', 'error', 2000)
        cb('ok')
        return
    end
    if not data.companyId or not data.orderId or not data.itemName then
        exports['sb_notify']:Notify('Invalid craft data', 'error', 3000)
        cb('ok')
        return
    end

    -- Look up the recipe for this item
    local recipe = nil
    for _, r in pairs(Recipes.All) do
        if r.result == data.itemName then
            recipe = r
            break
        end
    end

    DoCrafting(data.companyId, data.orderId, data.itemName, recipe)
    cb('ok')
end)

RegisterNUICallback('closeProduction', function(_, cb)
    CloseProduction()
    cb('ok')
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if productionOpen then
        CloseProduction()
    end
    if isCrafting then
        StopCraftingAnimation()
        isCrafting = false
    end
end)
