--[[
    Everyday Chaos RP - Shop System (Client)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, blips, NUI control
]]

local SB = exports['sb_core']:GetCoreObject()
local shopOpen = false
local spawnedNPCs = {}
local blips = {}

-- ============================================================================
-- MAP BLIPS
-- ============================================================================

local function CreateShopBlips()
    for _, shop in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(shop.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- ============================================================================
-- NPC SPAWNING
-- ============================================================================

local function SpawnShopNPCs()
    local model = GetHashKey(Config.ShopNPCModel)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print('[sb_shops] Failed to load NPC model')
            return
        end
    end

    for i, shop in ipairs(Config.Shops) do
        local coords = shop.coords
        local npc = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        SetEntityAsMissionEntity(npc, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedCombatAttributes(npc, 46, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)

        exports['sb_target']:AddTargetEntity(npc, {
            {
                name = 'shop_browse_' .. i,
                label = 'Browse Store',
                icon = 'fa-basket-shopping',
                distance = Config.ShopDistance,
                action = function(entity)
                    OpenShop(shop.label)
                end
            }
        })

        spawnedNPCs[#spawnedNPCs + 1] = npc
    end

    SetModelAsNoLongerNeeded(model)
end

-- ============================================================================
-- OPEN / CLOSE SHOP
-- ============================================================================

function OpenShop(shopLabel)
    if shopOpen then return end
    shopOpen = true

    local PlayerData = SB.Functions.GetPlayerData()
    local cash = PlayerData.money and PlayerData.money.cash or 0
    local bank = PlayerData.money and PlayerData.money.bank or 0

    SB.Functions.TriggerCallback('sb_shops:getCarryLimits', function(limits)
        SetNuiFocus(true, true)
        TriggerEvent('sb_hud:setVisible', false)
        SendNUIMessage({
            action = 'open',
            shopName = shopLabel or '24/7 Store',
            categories = Config.Categories,
            items = Config.Items,
            cash = cash,
            bank = bank,
            carryLimits = limits or {}
        })
    end)
end

function CloseShop()
    if not shopOpen then return end
    shopOpen = false

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseShop()
    cb('ok')
end)

RegisterNUICallback('notify', function(data, cb)
    exports['sb_notify']:Notify(data.msg, data.type or 'error', data.duration or 3000)
    cb('ok')
end)

RegisterNUICallback('purchase', function(data, cb)
    if not data.cart or #data.cart == 0 then
        cb('ok')
        return
    end
    TriggerServerEvent('sb_shops:server:purchase', data.cart)
    cb('ok')
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterNetEvent('sb_shops:client:purchaseResult', function(success, cash, bank)
    if success then
        -- Read fresh PlayerData to ensure balance is current
        local PlayerData = SB.Functions.GetPlayerData()
        local currentCash = (PlayerData.money and PlayerData.money.cash) or cash or 0
        local currentBank = (PlayerData.money and PlayerData.money.bank) or bank or 0
        SendNUIMessage({
            action = 'purchaseSuccess',
            cash = currentCash,
            bank = currentBank
        })
    else
        SendNUIMessage({ action = 'purchaseFailed' })
    end
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateShopBlips()
    SpawnShopNPCs()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, npc in ipairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    if shopOpen then
        CloseShop()
    end
end)
