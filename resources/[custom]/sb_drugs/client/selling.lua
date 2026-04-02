--[[
    Everyday Chaos RP - Drug Selling (Client)
    Author: Salah Eddine Boussettah

    Handles: phone booth detection, buyer NPC spawning,
    negotiation keybind prompts, NPC attack logic, cleanup.
    Uses sb_target on phone booth models for interaction.
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- State
local isSelling = false
local buyerPed = nil
local currentOffer = nil
local sellPromptActive = false

-- ========================================================================
-- HELPERS
-- ========================================================================

local function Notify(msg, type, duration)
    exports['sb_notify']:Notify(msg, type or 'info', duration or 3000)
end

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then return nil end
    end
    return hash
end

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

-- Find a walkable ground point ~25-40m from the player for buyer NPC to spawn
local function FindBuyerSpawnPoint(playerCoords)
    for i = 1, 10 do
        local angle = math.random() * math.pi * 2
        local dist = 25.0 + math.random() * 15.0 -- 25-40m away
        local x = playerCoords.x + math.cos(angle) * dist
        local y = playerCoords.y + math.sin(angle) * dist

        local found, z = GetGroundZFor_3dCoord(x, y, playerCoords.z + 50.0, false)
        if found and math.abs(z - playerCoords.z) < 10.0 then
            return vector3(x, y, z)
        end
    end
    -- Fallback: simple offset
    return vector3(playerCoords.x + 25.0, playerCoords.y + 25.0, playerCoords.z)
end

-- ========================================================================
-- PHONE BOOTH TARGETS (use model hashes)
-- ========================================================================
CreateThread(function()
    Wait(5000)

    -- Add target to all phone booth models
    for _, hash in ipairs(Config.PhoneBoothHashes) do
        exports['sb_target']:AddTargetModel(hash, {
            {
                name = 'drug_sell_phone_' .. tostring(hash),
                label = 'Call Buyer',
                icon = 'fa-phone',
                distance = 1.5,
                action = function()
                    StartSelling()
                end,
                canInteract = function()
                    return not isSelling
                end,
            },
        })
    end

    if Config.Debug then print('[sb_drugs] Phone booth targets registered') end
end)

-- ========================================================================
-- SELLING FLOW
-- ========================================================================

function StartSelling()
    if isSelling then
        Notify('Already in a deal', 'error')
        return
    end

    -- Request sell offer from server
    TriggerServerEvent('sb_drugs:server:requestSell')
end

-- Server sends back an offer
RegisterNetEvent('sb_drugs:client:sellOffer', function(offer)
    -- offer = { drugName, drugLabel, amount, pricePerUnit, totalPrice }
    if isSelling then return end
    isSelling = true
    currentOffer = offer

    Notify('Buyer is on the way...', 'info', 5000)

    -- Spawn buyer NPC near the player (not at a fixed SellLocation)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local spawnCoords = FindBuyerSpawnPoint(playerCoords)

    local randomModel = Config.BuyerModels[math.random(#Config.BuyerModels)]
    local hash = LoadModel(randomModel)
    if not hash then
        isSelling = false
        currentOffer = nil
        Notify('Buyer couldn\'t make it', 'error')
        return
    end

    buyerPed = CreatePed(0, hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false, true)
    SetEntityAsMissionEntity(buyerPed, true, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)
    SetPedFleeAttributes(buyerPed, 0, false)
    SetModelAsNoLongerNeeded(hash)

    -- Walk buyer toward player
    TaskGoToCoordAnyMeans(buyerPed, playerCoords.x, playerCoords.y, playerCoords.z, 1.0, 0, false, 786603, 0.0)

    -- Wait for buyer to arrive (max 45s), retask every 8s so NPC follows player movement
    local timeout = GetGameTimer() + 45000
    local lastRetask = GetGameTimer()
    while true do
        Wait(500)
        if not DoesEntityExist(buyerPed) then
            CleanupSell()
            return
        end

        playerCoords = GetEntityCoords(PlayerPedId())
        local buyerCoords = GetEntityCoords(buyerPed)
        local dist = #(playerCoords - buyerCoords)
        if dist < 3.0 then break end

        -- Retask every 8s with updated player position (in case player moved)
        if GetGameTimer() - lastRetask > 8000 then
            TaskGoToCoordAnyMeans(buyerPed, playerCoords.x, playerCoords.y, playerCoords.z, 1.0, 0, false, 786603, 0.0)
            lastRetask = GetGameTimer()
        end

        if GetGameTimer() > timeout then
            Notify('Buyer got lost', 'error')
            CleanupSell()
            return
        end
    end

    -- Buyer arrived — stop and face player
    TaskStandStill(buyerPed, -1)
    TaskTurnPedToFaceEntity(buyerPed, PlayerPedId(), 2000)
    Wait(1000)

    -- Show offer prompt
    ShowSellPrompt()
end)

function ShowSellPrompt()
    if not currentOffer or not isSelling then return end
    sellPromptActive = true

    local offer = currentOffer
    Notify(string.format('[Y] Accept $%s for %dx %s | [N] Decline | [G] Negotiate',
        tostring(offer.totalPrice), offer.amount, offer.drugLabel), 'info', 15000)

    -- Keybind listener
    CreateThread(function()
        local timeout = GetGameTimer() + 15000
        while sellPromptActive and GetGameTimer() < timeout do
            Wait(0)

            -- Y = Accept (key 246)
            if IsControlJustPressed(0, 246) then
                sellPromptActive = false
                AcceptDeal()
                return
            end

            -- N = Decline (key 306)
            if IsControlJustPressed(0, 306) then
                sellPromptActive = false
                DeclineDeal()
                return
            end

            -- G = Negotiate (key 47)
            if IsControlJustPressed(0, 47) then
                sellPromptActive = false
                NegotiateDeal()
                return
            end
        end

        -- Timed out
        if sellPromptActive then
            sellPromptActive = false
            Notify('Buyer got impatient and left', 'error')
            CleanupSell()
        end
    end)
end

function AcceptDeal()
    if not currentOffer then return end
    TriggerServerEvent('sb_drugs:server:completeSell', currentOffer.drugName, currentOffer.amount, currentOffer.totalPrice)
end

function DeclineDeal()
    Notify('Deal declined', 'info')
    CleanupSell()
end

function NegotiateDeal()
    if not currentOffer then return end
    TriggerServerEvent('sb_drugs:server:negotiateSell', currentOffer.drugName, currentOffer.amount, currentOffer.totalPrice)
end

-- Server confirms sale completed
RegisterNetEvent('sb_drugs:client:sellComplete', function(amount, cashReceived)
    Notify(string.format('Sold %dx for $%s', amount, tostring(cashReceived)), 'success', 5000)

    -- Buyer walks away
    if buyerPed and DoesEntityExist(buyerPed) then
        local coords = GetEntityCoords(buyerPed)
        TaskGoToCoordAnyMeans(buyerPed, coords.x + math.random(-50, 50), coords.y + math.random(-50, 50), coords.z, 2.0, 0, false, 786603, 0.0)

        -- Delete after walk away
        SetTimeout(15000, function()
            if buyerPed and DoesEntityExist(buyerPed) then
                DeleteEntity(buyerPed)
                buyerPed = nil
            end
        end)
    end

    isSelling = false
    currentOffer = nil
end)

-- Negotiation result
RegisterNetEvent('sb_drugs:client:negotiateResult', function(success, newPrice)
    if success then
        currentOffer.totalPrice = newPrice
        Notify(string.format('Counter-offer: $%s. [Y] Accept | [N] Decline', tostring(newPrice)), 'success', 10000)
        ShowSellPrompt()
    else
        -- NPC declines and walks away
        Notify('Buyer didn\'t like your counter-offer', 'error')
        CleanupSell()
    end
end)

-- NPC attacks
RegisterNetEvent('sb_drugs:client:buyerAttack', function()
    if buyerPed and DoesEntityExist(buyerPed) then
        -- Give NPC a weapon and attack
        GiveWeaponToPed(buyerPed, GetHashKey('WEAPON_PISTOL'), 50, false, true)
        SetEntityInvincible(buyerPed, false)
        SetPedFleeAttributes(buyerPed, 0, false)
        TaskCombatPed(buyerPed, PlayerPedId(), 0, 16)

        Notify('The buyer is attacking!', 'error', 5000)

        -- Delete after 30s regardless
        SetTimeout(30000, function()
            if buyerPed and DoesEntityExist(buyerPed) then
                DeleteEntity(buyerPed)
                buyerPed = nil
            end
        end)
    end

    isSelling = false
    currentOffer = nil
    sellPromptActive = false
end)

-- Server says sell failed (cooldown, no items, etc)
RegisterNetEvent('sb_drugs:client:sellFailed', function(reason)
    Notify(reason or 'Sell failed', 'error')
    isSelling = false
    currentOffer = nil
end)

-- ========================================================================
-- CLEANUP
-- ========================================================================

function CleanupSell()
    sellPromptActive = false
    currentOffer = nil
    isSelling = false

    if buyerPed and DoesEntityExist(buyerPed) then
        -- Walk away then delete
        local coords = GetEntityCoords(buyerPed)
        TaskGoToCoordAnyMeans(buyerPed, coords.x + math.random(-30, 30), coords.y + math.random(-30, 30), coords.z, 2.0, 0, false, 786603, 0.0)
        local ped = buyerPed
        buyerPed = nil
        SetTimeout(10000, function()
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    sellPromptActive = false
    if buyerPed and DoesEntityExist(buyerPed) then
        DeleteEntity(buyerPed)
        buyerPed = nil
    end
    isSelling = false
    currentOffer = nil
end)
