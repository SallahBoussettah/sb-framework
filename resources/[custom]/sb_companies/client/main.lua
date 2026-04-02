-- sb_companies | Client Main
-- Init, blips, company building entry, shared state

local SB = exports['sb_core']:GetCoreObject()

-- Client state
CompanyState = {
    nearCompany = nil,       -- company id if player is near a company
    isWorker = false,        -- true if player is a company employee
    companyId = nil,         -- player's company id (if employee)
    companyRole = nil,       -- player's role at company
}

-- ===================================================================
-- MAP BLIPS
-- ===================================================================
CreateThread(function()
    for _, company in ipairs(Config.Companies) do
        local blipCfg = company.blip
        if blipCfg then
            local blip = AddBlipForCoord(company.location.x, company.location.y, company.location.z)
            SetBlipSprite(blip, blipCfg.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, blipCfg.scale)
            SetBlipColour(blip, blipCfg.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(blipCfg.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ===================================================================
-- COMPANY BUILDING TARGETS
-- ===================================================================
CreateThread(function()
    for _, company in ipairs(Config.Companies) do
        -- Receiving dock: miners sell raw materials
        exports['sb_target']:AddSphereZone('company_recv_' .. company.id, company.receivingDock, 2.0, {
            {
                label = 'Sell Raw Materials',
                icon = 'fas fa-boxes-stacked',
                distance = 2.5,
                action = function()
                    TriggerEvent('sb_companies:openSellRaw', company.id)
                end,
            },
        })

        -- Production area: company workers craft
        exports['sb_target']:AddSphereZone('company_prod_' .. company.id, company.productionArea, 2.0, {
            {
                label = 'Production Terminal',
                icon = 'fas fa-industry',
                distance = 2.5,
                canInteract = function()
                    return IsCompanyEmployee(company.id, {'worker', 'manager'})
                end,
                action = function()
                    TriggerEvent('sb_companies:openProduction', company.id)
                end,
            },
        })

        -- Loading dock: drivers pick up deliveries
        exports['sb_target']:AddSphereZone('company_load_' .. company.id, company.loadingDock, 2.0, {
            {
                label = 'Delivery Pickup',
                icon = 'fas fa-truck-loading',
                distance = 2.5,
                canInteract = function()
                    return IsCompanyEmployee(company.id, {'driver', 'manager'})
                end,
                action = function()
                    TriggerEvent('sb_companies:openDeliveryPickup', company.id)
                end,
            },
        })

        -- Management desk: owner/manager dashboard
        exports['sb_target']:AddSphereZone('company_mgmt_' .. company.id, company.managementDesk, 1.5, {
            {
                label = 'Company Management',
                icon = 'fas fa-briefcase',
                distance = 2.0,
                canInteract = function()
                    return IsCompanyEmployee(company.id, {'manager'}) or IsCompanyOwner(company.id)
                end,
                action = function()
                    TriggerEvent('sb_companies:openManagement', company.id)
                end,
            },
        })
    end
end)

-- ===================================================================
-- SHOP TARGETS (Mechanic Workshop)
-- ===================================================================
CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        -- Order terminal
        exports['sb_target']:AddSphereZone('order_terminal_' .. shop.id, shop.orderTerminal, shop.orderTerminalRadius or 1.5, {
            {
                label = 'Order Parts',
                icon = 'fas fa-shopping-cart',
                distance = 2.0,
                canInteract = function()
                    local Player = SB.Functions.GetPlayerData()
                    return Player and IsMechanicJobClient(Player.job.name)
                end,
                action = function()
                    TriggerEvent('sb_companies:openOrderTerminal', shop.id)
                end,
            },
        })

        -- Parts dispensers
        for _, dispenser in ipairs(shop.dispensers or {}) do
            exports['sb_target']:AddSphereZone('dispenser_' .. dispenser.id, dispenser.coords, 1.2, {
                {
                    label = dispenser.label or 'Parts Storage',
                    icon = 'fas fa-box-open',
                    distance = 2.0,
                    canInteract = function()
                        local Player = SB.Functions.GetPlayerData()
                        return Player and IsMechanicJobClient(Player.job.name)
                    end,
                    action = function()
                        TriggerEvent('sb_companies:openShopStorage', shop.id, dispenser.id, dispenser.categories)
                    end,
                },
            })
        end
    end
end)

-- ===================================================================
-- HELPER: Check mechanic job (client side)
-- ===================================================================
function IsMechanicJobClient(jobName)
    return jobName == 'bn-mechanic' or jobName == 'mechanic'
end

-- ===================================================================
-- HELPER: Check if player is employee of specific company with role
-- ===================================================================
function IsCompanyEmployee(companyId, allowedRoles)
    if not CompanyState.isWorker then return false end
    if CompanyState.companyId ~= companyId then return false end
    if not allowedRoles then return true end

    for _, role in ipairs(allowedRoles) do
        if CompanyState.companyRole == role then return true end
    end
    return false
end

-- ===================================================================
-- HELPER: Check if player is company owner
-- ===================================================================
function IsCompanyOwner(companyId)
    local Player = SB.Functions.GetPlayerData()
    if not Player then return false end
    -- This is checked server-side, but we need a quick client check
    -- We'll use a cached value from the server
    return CompanyState.isOwnerOf == companyId
end

-- ===================================================================
-- EMPLOYEE STATE SYNC
-- ===================================================================
RegisterNetEvent('sb_companies:setEmployeeState', function(data)
    if data then
        CompanyState.isWorker = true
        CompanyState.companyId = data.company_id
        CompanyState.companyRole = data.role
        CompanyState.isOwnerOf = data.is_owner and data.company_id or nil
    else
        CompanyState.isWorker = false
        CompanyState.companyId = nil
        CompanyState.companyRole = nil
        CompanyState.isOwnerOf = nil
    end
end)

-- Request employee state on spawn
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('sb_companies:requestEmployeeState')
end)

-- Also request on resource start
CreateThread(function()
    Wait(2000)
    TriggerServerEvent('sb_companies:requestEmployeeState')
end)

-- ===================================================================
-- SERVER EVENT: Request employee state
-- ===================================================================
RegisterNetEvent('sb_companies:requestEmployeeState', function()
    -- Handled server-side, triggers sb_companies:setEmployeeState back
end)
