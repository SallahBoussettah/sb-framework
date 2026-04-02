-- sb_mechanic_v2 | Phase 2: Client Supplier Terminal
-- PC terminal interaction for ordering raw materials, NUI bridge

local SB = exports['sb_core']:GetCoreObject()
local SupplierOpen = false

-- ===================================================================
-- SUPPLIER TERMINAL (PC at workshop)
-- ===================================================================
CreateThread(function()
    local cfg = Config.Supplier.terminal

    exports['sb_target']:AddSphereZone('supplier_terminal', cfg.coords, cfg.radius or 1.0, {
        {
            label = 'Order Materials',
            icon = 'fas fa-desktop',
            distance = 2.0,
            canInteract = function()
                local Player = SB.Functions.GetPlayerData()
                if not Player or not Config.IsMechanicJob(Player.job.name) then return false end
                return true
            end,
            action = function()
                OpenSupplierShop()
            end,
        },
    })
end)

-- ===================================================================
-- OPEN SUPPLIER SHOP
-- ===================================================================
function OpenSupplierShop()
    if SupplierOpen then return end

    SB.Functions.TriggerCallback('sb_mechanic_v2:getSupplierStock', function(data)
        if not data then
            exports['sb_notify']:Notify('Terminal offline', 'error', 3000)
            return
        end

        SupplierOpen = true

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openSupplier',
            stock = data.stock,
            bulkThreshold = data.bulkThreshold,
            bulkDiscount = data.bulkDiscount,
            playerCash = data.playerCash,
            playerBank = data.playerBank,
        })
    end)
end

-- ===================================================================
-- CLOSE SUPPLIER NUI
-- ===================================================================
function CloseSupplierNUI()
    if not SupplierOpen then return end
    SupplierOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSupplier' })
end

-- ===================================================================
-- NUI CALLBACK: Buy item
-- ===================================================================
RegisterNUICallback('buyItem', function(data, cb)
    cb('ok')

    local itemName = data.itemName
    local amount = tonumber(data.amount) or 1
    local paymentType = data.paymentType or 'cash'

    if not itemName or amount < 1 then return end

    SB.Functions.TriggerCallback('sb_mechanic_v2:buyFromSupplier', function(success)
        if success then
            -- Refresh stock view (re-fetch to update player money)
            SB.Functions.TriggerCallback('sb_mechanic_v2:getSupplierStock', function(newData)
                if newData and SupplierOpen then
                    SendNUIMessage({
                        action = 'updateSupplier',
                        playerCash = newData.playerCash,
                        playerBank = newData.playerBank,
                    })
                end
            end)
        end
    end, itemName, amount, paymentType)
end)

-- ===================================================================
-- NUI CALLBACK: Close supplier
-- ===================================================================
RegisterNUICallback('closeSupplier', function(data, cb)
    cb('ok')
    CloseSupplierNUI()
end)
