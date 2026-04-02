--[[
    Everyday Chaos RP - Burger Shot (Client)
    Author: Salah Eddine Boussettah

    Handles: Blip, NPC, target zones, cooking flow, supply purchases, counter
]]

local SB = exports['sb_core']:GetCoreObject()

-- ============================================================================
-- STATE
-- ============================================================================
local isLoggedIn = false
local clockInNPC = nil
local fridgeOpen = false
local counterStock = {}  -- Synced from server: { ['bs_fries'] = 3, ... }

-- ============================================================================
-- CORE EVENTS
-- ============================================================================

RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    SetupBlip()
    SetupClockInNPC()
    SetupStations()
    SetupSupplyFridge()
    SetupCounter()
end)

RegisterNetEvent('SB:Client:OnPlayerUnload', function()
    isLoggedIn = false
    CleanupNPC()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local PlayerData = SB.Functions.GetPlayerData()
    if PlayerData and PlayerData.citizenid then
        isLoggedIn = true
        SetupBlip()
        SetupClockInNPC()
        SetupStations()
        SetupSupplyFridge()
        SetupCounter()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CleanupNPC()
    if fridgeOpen then CloseFridgeMenu() end
end)

-- ============================================================================
-- BLIP
-- ============================================================================

function SetupBlip()
    local blip = AddBlipForCoord(Config.Blip.coords)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipAsShortRange(blip, Config.Blip.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end

-- ============================================================================
-- CLOCK IN NPC
-- ============================================================================

function SetupClockInNPC()
    local cfg = Config.ClockIn
    local hash = GetHashKey(cfg.model)
    RequestModel(hash)

    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then return end
    end

    clockInNPC = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.heading, false, true)
    FreezeEntityPosition(clockInNPC, true)
    SetEntityInvincible(clockInNPC, true)
    SetBlockingOfNonTemporaryEvents(clockInNPC, true)
    SetPedFleeAttributes(clockInNPC, 0, false)
    SetPedCombatAttributes(clockInNPC, 46, true)
    SetModelAsNoLongerNeeded(hash)

    exports['sb_target']:AddTargetEntity(clockInNPC, {
        {
            name = 'bs_clockin',
            label = cfg.label,
            icon = cfg.icon,
            distance = 2.5,
            job = Config.Job,
            action = function()
                TriggerServerEvent('sb_burgershot:server:toggleDuty')
            end
        }
    })
end

function CleanupNPC()
    if clockInNPC and DoesEntityExist(clockInNPC) then
        DeleteEntity(clockInNPC)
        clockInNPC = nil
    end
end

-- ============================================================================
-- COOKING STATIONS
-- ============================================================================

function SetupStations()
    for _, station in ipairs(Config.Stations) do
        exports['sb_target']:AddSphereZone(
            'bs_' .. station.id,
            station.coords,
            station.distance,
            {
                {
                    name = 'bs_cook_' .. station.id,
                    label = station.label,
                    icon = station.icon,
                    distance = station.distance,
                    job = Config.Job,
                    canInteract = function()
                        local PlayerData = SB.Functions.GetPlayerData()
                        return PlayerData.job and PlayerData.job.onduty
                    end,
                    action = function()
                        StartCooking(station)
                    end
                }
            }
        )
    end
end

function StartCooking(station)
    -- Prevent double-cooking
    if exports['sb_progressbar']:IsActive() then
        exports['sb_notify']:Notify('Already busy!', 'error', 2000)
        return
    end

    local recipe = station.recipe

    -- Ask server to validate ingredients
    SB.Functions.TriggerCallback('sb_burgershot:canCook', function(canCook)
        if not canCook then
            exports['sb_notify']:Notify('Missing ingredients!', 'error', 3000)
            return
        end

        -- Load animation dict
        if recipe.animation and recipe.animation.dict then
            RequestAnimDict(recipe.animation.dict)
            local timeout = 0
            while not HasAnimDictLoaded(recipe.animation.dict) do
                Wait(10)
                timeout = timeout + 10
                if timeout > 5000 then break end
            end
        end

        -- Start progress bar
        exports['sb_progressbar']:Start({
            label = recipe.label,
            duration = recipe.duration,
            canCancel = true,
            disableMovement = true,
            disableCombat = true,
            animation = recipe.animation,
            onComplete = function()
                TriggerServerEvent('sb_burgershot:server:finishCooking', station.id)
                ClearPedTasks(PlayerPedId())
            end,
            onCancel = function()
                exports['sb_notify']:Notify('Cancelled.', 'error', 2000)
                ClearPedTasks(PlayerPedId())
            end
        })
    end, station.id)
end

-- ============================================================================
-- SUPPLY FRIDGE (NUI Menu)
-- ============================================================================

function SetupSupplyFridge()
    local cfg = Config.SupplyFridge

    exports['sb_target']:AddSphereZone('bs_supply_fridge', cfg.coords, cfg.distance, {
        {
            name = 'bs_open_fridge',
            label = cfg.label,
            icon = cfg.icon,
            distance = cfg.distance,
            job = Config.Job,
            canInteract = function()
                local PlayerData = SB.Functions.GetPlayerData()
                return PlayerData.job and PlayerData.job.onduty
            end,
            action = function()
                OpenFridgeMenu()
            end
        }
    })
end

function OpenFridgeMenu()
    if fridgeOpen then return end
    fridgeOpen = true

    local PlayerData = SB.Functions.GetPlayerData()
    local cash = PlayerData.money and PlayerData.money.cash or 0

    SetNuiFocus(true, true)
    TriggerEvent('sb_hud:setVisible', false)
    SendNUIMessage({
        action = 'openFridge',
        items = Config.SupplyFridge.items,
        cash = cash
    })
end

function CloseFridgeMenu()
    if not fridgeOpen then return end
    fridgeOpen = false

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'closeFridge' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('closeFridge', function(data, cb)
    CloseFridgeMenu()
    cb('ok')
end)

RegisterNUICallback('purchaseSupplies', function(data, cb)
    if not data.cart or #data.cart == 0 then
        cb('ok')
        return
    end
    TriggerServerEvent('sb_burgershot:server:buySupplies', data.cart)
    cb('ok')
end)

-- ============================================================================
-- SERVER EVENTS (NUI updates)
-- ============================================================================

RegisterNetEvent('sb_burgershot:client:purchaseResult', function(success, cash)
    if success then
        SendNUIMessage({ action = 'purchaseSuccess', cash = cash })
    else
        SendNUIMessage({ action = 'purchaseFailed' })
    end
end)

-- Sync counter stock from server
RegisterNetEvent('sb_burgershot:client:syncStock', function(stock)
    counterStock = stock or {}
end)

-- ============================================================================
-- CUSTOMER COUNTER
-- ============================================================================

function SetupCounter()
    local cfg = Config.Counter

    exports['sb_target']:AddSphereZone('bs_counter', cfg.coords, cfg.distance, {
        -- Employee: stock all food items at once
        {
            name = 'bs_counter_stock',
            label = 'Stock Counter',
            icon = 'fa-arrow-down',
            distance = cfg.distance,
            job = Config.Job,
            canInteract = function()
                local PlayerData = SB.Functions.GetPlayerData()
                return PlayerData.job and PlayerData.job.onduty
            end,
            action = function()
                TriggerServerEvent('sb_burgershot:server:stockAll')
            end
        },
        -- Customer: buy fries
        {
            name = 'bs_buy_fries',
            label = 'Buy Fries - $' .. cfg.prices['bs_fries'],
            icon = 'fa-french-fries',
            distance = cfg.distance,
            canInteract = function()
                return (counterStock['bs_fries'] or 0) > 0
            end,
            action = function()
                TriggerServerEvent('sb_burgershot:server:buyFromCounter', 'bs_fries')
            end
        },
        -- Customer: buy burger
        {
            name = 'bs_buy_burger',
            label = 'Buy Bleeder Burger - $' .. cfg.prices['bs_burger'],
            icon = 'fa-burger',
            distance = cfg.distance,
            canInteract = function()
                return (counterStock['bs_burger'] or 0) > 0
            end,
            action = function()
                TriggerServerEvent('sb_burgershot:server:buyFromCounter', 'bs_burger')
            end
        },
        -- Customer: buy cola
        {
            name = 'bs_buy_cola',
            label = 'Buy eCola - $' .. cfg.prices['bs_cola'],
            icon = 'fa-cup-straw',
            distance = cfg.distance,
            canInteract = function()
                return (counterStock['bs_cola'] or 0) > 0
            end,
            action = function()
                TriggerServerEvent('sb_burgershot:server:buyFromCounter', 'bs_cola')
            end
        },
        -- Customer: buy meal
        {
            name = 'bs_buy_meal',
            label = 'Buy Murder Meal - $' .. cfg.prices['bs_meal'],
            icon = 'fa-box',
            distance = cfg.distance,
            canInteract = function()
                return (counterStock['bs_meal'] or 0) > 0
            end,
            action = function()
                TriggerServerEvent('sb_burgershot:server:buyFromCounter', 'bs_meal')
            end
        },
    })
end
