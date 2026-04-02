-- sb_companies | Client: Shop Storage
-- Mechanic grabs parts from workshop dispensers
-- Opens NUI with storage items filtered by dispenser categories

local SB = exports['sb_core']:GetCoreObject()

local storageOpen = false

-- ============================================================================
-- EVENT: Open Shop Storage
-- ============================================================================

RegisterNetEvent('sb_companies:openShopStorage', function(shopId, dispenserId, categories)
    if storageOpen then return end
    if not shopId or not dispenserId or not categories then return end

    SB.Functions.TriggerCallback('sb_companies:getShopStorage', function(items)
        if not items then
            exports['sb_notify']:Notify('Failed to load storage', 'error', 3000)
            return
        end

        storageOpen = true
        SetNuiFocus(true, true)
        TriggerEvent('sb_hud:setVisible', false)

        SendNUIMessage({
            action = 'openStorage',
            data = {
                items = items,
                shopId = shopId,
                dispenserId = dispenserId,
                categories = categories,
            }
        })
    end, shopId, categories)
end)

-- ============================================================================
-- CLOSE STORAGE
-- ============================================================================

local function CloseStorage()
    if not storageOpen then return end
    storageOpen = false

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'closeStorage' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('grabFromStorage', function(data, cb)
    if not storageOpen then cb('ok') return end
    if not data.shopId or not data.itemName or not data.quantity then
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:grabFromStorage', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Grabbed ' .. data.quantity .. 'x ' .. (result.label or data.itemName), 'success', 3000)

            -- Refresh storage view with updated items
            SB.Functions.TriggerCallback('sb_companies:getShopStorage', function(items)
                if items then
                    SendNUIMessage({
                        action = 'updateStorageItems',
                        data = { items = items }
                    })
                end
            end, data.shopId, data.categories or {})
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to grab item', 'error', 3000)
        end
    end, data.shopId, data.itemName, data.quantity, data.quality or 'standard')

    cb('ok')
end)

RegisterNUICallback('closeStorage', function(_, cb)
    CloseStorage()
    cb('ok')
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if storageOpen then
        CloseStorage()
    end
end)
