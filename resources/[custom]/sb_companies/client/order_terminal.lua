-- sb_companies | Client: Order Terminal
-- Mechanic orders parts from companies via NUI terminal
-- Located at workshop PCs (Config.Shops[].orderTerminal)

local SB = exports['sb_core']:GetCoreObject()

local terminalOpen = false
local currentShopId = nil

-- ============================================================================
-- EVENT: Open Order Terminal
-- ============================================================================

RegisterNetEvent('sb_companies:openOrderTerminal', function(shopId)
    if terminalOpen then return end
    if not shopId then return end

    SB.Functions.TriggerCallback('sb_companies:getCompanyCatalogs', function(catalogs)
        if not catalogs then
            exports['sb_notify']:Notify('Failed to load catalog', 'error', 3000)
            return
        end

        local PlayerData = SB.Functions.GetPlayerData()
        local playerCash = PlayerData.money and PlayerData.money.cash or 0
        local playerBank = PlayerData.money and PlayerData.money.bank or 0

        terminalOpen = true
        currentShopId = shopId
        SetNuiFocus(true, true)
        TriggerEvent('sb_hud:setVisible', false)

        SendNUIMessage({
            action = 'openOrderTerminal',
            data = {
                companies = catalogs,
                shopId = shopId,
                playerCash = playerCash,
                playerBank = playerBank,
            }
        })
    end)
end)

-- ============================================================================
-- CLOSE TERMINAL
-- ============================================================================

local function CloseTerminal()
    if not terminalOpen then return end
    terminalOpen = false
    currentShopId = nil

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'closeOrderTerminal' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('placeOrder', function(data, cb)
    if not terminalOpen then cb('ok') return end
    if not data.shopId or not data.companyId or not data.items or #data.items == 0 then
        exports['sb_notify']:Notify('Invalid order data', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:placeOrder', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Order placed! Total: $' .. (result.total or 0), 'success', 4000)

            -- Refresh player money in NUI
            local PlayerData = SB.Functions.GetPlayerData()
            local playerCash = PlayerData.money and PlayerData.money.cash or 0
            local playerBank = PlayerData.money and PlayerData.money.bank or 0

            SendNUIMessage({
                action = 'orderPlaced',
                data = {
                    orderId = result.orderId,
                    playerCash = playerCash,
                    playerBank = playerBank,
                }
            })
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to place order', 'error', 3000)
        end
    end, data.shopId, data.companyId, data.items, data.paymentSource or 'bank')

    cb('ok')
end)

RegisterNUICallback('getOrderHistory', function(data, cb)
    if not terminalOpen then cb('ok') return end

    local shopId = data.shopId or currentShopId
    if not shopId then cb('ok') return end

    SB.Functions.TriggerCallback('sb_companies:getMyOrders', function(orders)
        SendNUIMessage({
            action = 'orderHistory',
            data = { orders = orders or {} }
        })
    end, shopId)

    cb('ok')
end)

RegisterNUICallback('cancelOrder', function(data, cb)
    if not terminalOpen then cb('ok') return end
    if not data.orderId then
        exports['sb_notify']:Notify('Invalid order', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:cancelOrder', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Order cancelled. Refund: $' .. (result.refund or 0), 'success', 4000)

            -- Refresh order history
            local shopId = currentShopId
            if shopId then
                SB.Functions.TriggerCallback('sb_companies:getMyOrders', function(orders)
                    SendNUIMessage({
                        action = 'orderHistory',
                        data = { orders = orders or {} }
                    })
                end, shopId)
            end

            -- Refresh player money
            local PlayerData = SB.Functions.GetPlayerData()
            local playerCash = PlayerData.money and PlayerData.money.cash or 0
            local playerBank = PlayerData.money and PlayerData.money.bank or 0
            SendNUIMessage({
                action = 'updateMoney',
                data = { playerCash = playerCash, playerBank = playerBank }
            })
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to cancel order', 'error', 3000)
        end
    end, data.orderId)

    cb('ok')
end)

RegisterNUICallback('closeOrderTerminal', function(_, cb)
    CloseTerminal()
    cb('ok')
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if terminalOpen then
        CloseTerminal()
    end
end)
