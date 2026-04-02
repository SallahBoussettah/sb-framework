-- sb_companies | Client: Company Management
-- Owner/manager dashboard for company operations
-- Handles pricing, employees, and company funds

local SB = exports['sb_core']:GetCoreObject()

local managementOpen = false
local currentCompanyId = nil

-- ============================================================================
-- EVENT: Open Management Dashboard
-- ============================================================================

RegisterNetEvent('sb_companies:openManagement', function(companyId)
    if managementOpen then return end
    if not companyId then return end

    -- Validate authorization
    if not IsCompanyEmployee(companyId, {'manager'}) and not IsCompanyOwner(companyId) then
        exports['sb_notify']:Notify('You are not authorized to manage this company', 'error', 3000)
        return
    end

    SB.Functions.TriggerCallback('sb_companies:getCompanyData', function(data)
        if not data then
            exports['sb_notify']:Notify('Failed to load company data', 'error', 3000)
            return
        end

        managementOpen = true
        currentCompanyId = companyId
        SetNuiFocus(true, true)
        TriggerEvent('sb_hud:setVisible', false)

        SendNUIMessage({
            action = 'openManagement',
            data = data,
        })
    end, companyId)
end)

-- ============================================================================
-- CLOSE MANAGEMENT
-- ============================================================================

local function CloseManagement()
    if not managementOpen then return end
    managementOpen = false
    currentCompanyId = nil

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'closeManagement' })
end

-- ============================================================================
-- HELPER: Refresh company data in NUI
-- ============================================================================

local function RefreshManagementData()
    if not managementOpen or not currentCompanyId then return end

    SB.Functions.TriggerCallback('sb_companies:getCompanyData', function(data)
        if data then
            SendNUIMessage({
                action = 'updateManagement',
                data = data,
            })
        end
    end, currentCompanyId)
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('adjustPrice', function(data, cb)
    if not managementOpen then cb('ok') return end
    if not data.companyId or not data.itemName or not data.newPrice then
        exports['sb_notify']:Notify('Invalid price data', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:adjustPrice', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Price updated for ' .. (result.label or data.itemName), 'success', 3000)
            RefreshManagementData()
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to adjust price', 'error', 3000)
        end
    end, data.companyId, data.itemName, data.newPrice)

    cb('ok')
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    if not managementOpen then cb('ok') return end
    if not data.companyId or not data.targetCitizenId or not data.role then
        exports['sb_notify']:Notify('Invalid hire data', 'error', 3000)
        cb('ok')
        return
    end

    -- Validate role
    if not Config.Roles[data.role] then
        exports['sb_notify']:Notify('Invalid role', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:hireEmployee', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Hired ' .. (result.name or 'employee') .. ' as ' .. Config.Roles[data.role].label, 'success', 4000)
            RefreshManagementData()
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to hire employee', 'error', 3000)
        end
    end, data.companyId, data.targetCitizenId, data.role)

    cb('ok')
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    if not managementOpen then cb('ok') return end
    if not data.companyId or not data.targetCitizenId then
        exports['sb_notify']:Notify('Invalid employee data', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:fireEmployee', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Employee removed', 'success', 3000)
            RefreshManagementData()
        else
            exports['sb_notify']:Notify(result and result.message or 'Failed to fire employee', 'error', 3000)
        end
    end, data.companyId, data.targetCitizenId)

    cb('ok')
end)

RegisterNUICallback('withdrawFunds', function(data, cb)
    if not managementOpen then cb('ok') return end
    if not data.companyId or not data.amount then
        exports['sb_notify']:Notify('Invalid withdrawal data', 'error', 3000)
        cb('ok')
        return
    end

    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        exports['sb_notify']:Notify('Invalid amount', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:withdrawFunds', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Withdrew $' .. amount .. ' from company', 'success', 4000)
            RefreshManagementData()
        else
            exports['sb_notify']:Notify(result and result.message or 'Withdrawal failed', 'error', 3000)
        end
    end, data.companyId, amount)

    cb('ok')
end)

RegisterNUICallback('depositFunds', function(data, cb)
    if not managementOpen then cb('ok') return end
    if not data.companyId or not data.amount then
        exports['sb_notify']:Notify('Invalid deposit data', 'error', 3000)
        cb('ok')
        return
    end

    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        exports['sb_notify']:Notify('Invalid amount', 'error', 3000)
        cb('ok')
        return
    end

    SB.Functions.TriggerCallback('sb_companies:depositFunds', function(result)
        if result and result.success then
            exports['sb_notify']:Notify('Deposited $' .. amount .. ' into company', 'success', 4000)
            RefreshManagementData()
        else
            exports['sb_notify']:Notify(result and result.message or 'Deposit failed', 'error', 3000)
        end
    end, data.companyId, amount)

    cb('ok')
end)

RegisterNUICallback('closeManagement', function(_, cb)
    CloseManagement()
    cb('ok')
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if managementOpen then
        CloseManagement()
    end
end)
