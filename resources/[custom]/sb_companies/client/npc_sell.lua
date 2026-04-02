-- sb_companies | Client: NPC Sell Raw Materials
-- Miners sell raw materials at company receiving docks
-- Opens NUI with available items and their buy prices

local SB = exports['sb_core']:GetCoreObject()

local sellOpen = false
local currentSellCompanyId = nil

-- ============================================================================
-- HELPER: Get sellable items from player inventory
-- Matches items against the company's buysMaterials list
-- ============================================================================

local function GetSellableItems(companyId)
    local companyCfg = Config.CompanyById[companyId]
    if not companyCfg or not companyCfg.buysMaterials then return {} end

    -- Build lookup set for fast matching
    local buySet = {}
    for _, matName in ipairs(companyCfg.buysMaterials) do
        buySet[matName] = true
    end

    -- Get player inventory items
    local PlayerData = SB.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return {} end

    local sellable = {}
    for _, item in pairs(PlayerData.items) do
        if item and item.name and buySet[item.name] and item.amount and item.amount > 0 then
            local price = Config.RawMaterialPrices[item.name] or 0
            sellable[#sellable + 1] = {
                name = item.name,
                label = item.label or item.name,
                amount = item.amount,
                priceEach = price,
            }
        end
    end

    return sellable
end

-- ============================================================================
-- EVENT: Open Sell Raw Materials
-- ============================================================================

RegisterNetEvent('sb_companies:openSellRaw', function(companyId)
    if sellOpen then return end
    if not companyId then return end

    local companyCfg = Config.CompanyById[companyId]
    if not companyCfg then
        exports['sb_notify']:Notify('Unknown company', 'error', 3000)
        return
    end

    local sellable = GetSellableItems(companyId)

    if #sellable == 0 then
        exports['sb_notify']:Notify('You have no raw materials that ' .. companyCfg.label .. ' buys', 'info', 4000)
        return
    end

    sellOpen = true
    currentSellCompanyId = companyId
    SetNuiFocus(true, true)
    TriggerEvent('sb_hud:setVisible', false)

    SendNUIMessage({
        action = 'openSellRaw',
        data = {
            companyId = companyId,
            companyLabel = companyCfg.label,
            items = sellable,
        }
    })
end)

-- ============================================================================
-- CLOSE SELL
-- ============================================================================

local function CloseSell()
    if not sellOpen then return end
    sellOpen = false
    currentSellCompanyId = nil

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'closeSellRaw' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('sellRawMaterial', function(data, cb)
    if not sellOpen then cb('ok') return end
    if not data.companyId or not data.itemName or not data.quantity then
        exports['sb_notify']:Notify('Invalid sell data', 'error', 3000)
        cb('ok')
        return
    end

    local quantity = tonumber(data.quantity)
    if not quantity or quantity <= 0 then
        exports['sb_notify']:Notify('Invalid quantity', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:sellRawMaterials', function(result)
        if result and result.success then
            local total = result.total or 0
            exports['sb_notify']:Notify('Sold ' .. quantity .. 'x ' .. (result.label or data.itemName) .. ' for $' .. total, 'success', 4000)

            -- Refresh sellable items
            local updatedItems = GetSellableItems(data.companyId)
            if #updatedItems == 0 then
                exports['sb_notify']:Notify('No more materials to sell', 'info', 3000)
                CloseSell()
            else
                SendNUIMessage({
                    action = 'updateSellItems',
                    data = { items = updatedItems }
                })
            end
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to sell materials', 'error', 3000)
        end
    end, data.companyId, data.itemName, quantity)

    cb('ok')
end)

RegisterNUICallback('closeSellRaw', function(_, cb)
    CloseSell()
    cb('ok')
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if sellOpen then
        CloseSell()
    end
end)
