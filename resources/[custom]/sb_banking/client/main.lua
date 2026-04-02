--[[
    Everyday Chaos RP - Banking System (Client)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, bank interaction, NUI control
]]

local SB = exports['sb_core']:GetCoreObject()
local bankOpen = false
local currentMode = nil  -- 'bank' or 'atm'
local spawnedNPCs = {}
local spawnedProps = {}
local blips = {}

-- ============================================================================
-- MAP BLIPS
-- ============================================================================

local function CreateBankBlips()
    for _, location in ipairs(Config.BankLocations) do
        local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
        SetBlipSprite(blip, 108)          -- Bank/dollar icon
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 2)            -- Green (classic bank color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(location.label or 'Bank')
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- ============================================================================
-- NPC SPAWNING
-- ============================================================================

local function SpawnBankNPCs()
    local model = GetHashKey(Config.BankNPCModel)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print('[sb_banking] Failed to load NPC model')
            return
        end
    end

    for i, location in ipairs(Config.BankLocations) do
        local coords = location.coords

        -- Delete props if specified (e.g., remove chairs in the way)
        if location.deleteProps then
            for _, prop in ipairs(location.deleteProps) do
                local propModel = prop.model
                local propCoords = prop.coords
                local propRadius = prop.radius or 2.0

                -- Find and delete existing prop
                local existingProp = GetClosestObjectOfType(propCoords.x, propCoords.y, propCoords.z, propRadius, propModel, false, false, false)
                if existingProp and existingProp ~= 0 then
                    SetEntityAsMissionEntity(existingProp, true, true)
                    DeleteEntity(existingProp)
                end
            end
        end

        -- Spawn standing NPC
        local npc = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        SetEntityAsMissionEntity(npc, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedCombatAttributes(npc, 46, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)

        -- Register target on NPC
        exports['sb_target']:AddTargetEntity(npc, {
            {
                name = 'bank_interact_' .. i,
                label = 'Access Bank',
                icon = 'fa-university',
                distance = Config.BankDistance,
                action = function(entity)
                    OpenBank()
                end
            }
        })

        spawnedNPCs[#spawnedNPCs + 1] = npc
    end

    SetModelAsNoLongerNeeded(model)
end

-- ============================================================================
-- OPEN / CLOSE BANK
-- ============================================================================

function OpenBank()
    if bankOpen then return end
    bankOpen = true
    currentMode = 'bank'

    SetNuiFocus(true, true)
    TriggerEvent('sb_hud:setVisible', false)
    SendNUIMessage({
        action = 'open',
        mode = 'bank'
    })

    -- Request account data from server
    TriggerServerEvent('sb_banking:server:getAccountData')
end

function OpenATM()
    if bankOpen then return end
    bankOpen = true
    currentMode = 'atm'

    SetNuiFocus(true, true)
    TriggerEvent('sb_hud:setVisible', false)
    SendNUIMessage({
        action = 'open',
        mode = 'atm'
    })

    -- Request account data from server
    TriggerServerEvent('sb_banking:server:getAccountData')
end

function CloseBank()
    if not bankOpen then return end
    bankOpen = false
    currentMode = nil

    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'close' })

    -- Clear ATM session on server
    TriggerServerEvent('sb_banking:server:closeATM')
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseBank()
    cb('ok')
end)

RegisterNUICallback('notify', function(data, cb)
    exports['sb_notify']:Notify(data.msg, data.type or 'error', 4000)
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    TriggerServerEvent('sb_banking:server:createAccount', data.pin)
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('sb_banking:server:deposit', data.amount)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('sb_banking:server:withdraw', data.amount)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('sb_banking:server:transfer', data.target, data.amount)
    cb('ok')
end)

RegisterNUICallback('verifyPin', function(data, cb)
    TriggerServerEvent('sb_banking:server:verifyPin', data.pin)
    cb('ok')
end)

RegisterNUICallback('atmWithdraw', function(data, cb)
    TriggerServerEvent('sb_banking:server:atmWithdraw', data.amount, data.pin)
    cb('ok')
end)

RegisterNUICallback('atmDeposit', function(data, cb)
    TriggerServerEvent('sb_banking:server:atmDeposit', data.amount)
    cb('ok')
end)

RegisterNUICallback('resetPin', function(data, cb)
    TriggerServerEvent('sb_banking:server:resetPin', data.pin)
    cb('ok')
end)

RegisterNUICallback('unlockCard', function(data, cb)
    TriggerServerEvent('sb_banking:server:unlockCard')
    cb('ok')
end)

RegisterNUICallback('replaceCard', function(data, cb)
    TriggerServerEvent('sb_banking:server:replaceCard')
    cb('ok')
end)

RegisterNUICallback('getTransactions', function(data, cb)
    TriggerServerEvent('sb_banking:server:getTransactions')
    cb('ok')
end)

RegisterNUICallback('savingsDeposit', function(data, cb)
    TriggerServerEvent('sb_banking:server:savingsDeposit', data.amount)
    cb('ok')
end)

RegisterNUICallback('savingsWithdraw', function(data, cb)
    TriggerServerEvent('sb_banking:server:savingsWithdraw', data.amount)
    cb('ok')
end)

RegisterNUICallback('requestCard', function(data, cb)
    TriggerServerEvent('sb_banking:server:requestCard')
    cb('ok')
end)

RegisterNUICallback('getSocietyTransactions', function(data, cb)
    -- Society not yet implemented on server
    cb('ok')
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterNetEvent('sb_banking:client:noAccount', function()
    if currentMode == 'atm' then
        -- Can't create account at ATM
        CloseBank()
        exports['sb_notify']:Notify('You need a bank account first. Visit the bank.', 'error', 5000)
        return
    end
    SendNUIMessage({
        action = 'showCreate'
    })
end)

RegisterNetEvent('sb_banking:client:accountData', function(data)
    SendNUIMessage({
        action = 'accountData',
        data = data
    })
end)

RegisterNetEvent('sb_banking:client:accountCreated', function(data)
    SendNUIMessage({
        action = 'accountCreated',
        data = data
    })
    -- Re-fetch account data to show dashboard
    TriggerServerEvent('sb_banking:server:getAccountData')
end)

RegisterNetEvent('sb_banking:client:updateBalance', function(cash, bank)
    SendNUIMessage({
        action = 'updateBalance',
        cash = cash,
        bank = bank
    })
end)

RegisterNetEvent('sb_banking:client:pinVerified', function()
    SendNUIMessage({ action = 'pinVerified' })
end)

RegisterNetEvent('sb_banking:client:cardLocked', function()
    SendNUIMessage({ action = 'cardLocked' })
end)

RegisterNetEvent('sb_banking:client:wrongPin', function(remaining)
    SendNUIMessage({
        action = 'wrongPin',
        remaining = remaining
    })
end)

RegisterNetEvent('sb_banking:client:transactions', function(transactions)
    SendNUIMessage({
        action = 'transactions',
        data = transactions
    })
end)

RegisterNetEvent('sb_banking:client:atmSuccess', function(amount, balance)
    SendNUIMessage({
        action = 'atmSuccess',
        amount = amount,
        balance = balance
    })
end)

RegisterNetEvent('sb_banking:client:updateSavings', function(savings)
    SendNUIMessage({
        action = 'updateSavings',
        savings = savings
    })
end)

RegisterNetEvent('sb_banking:client:cardIssued', function(cardId)
    SendNUIMessage({
        action = 'cardIssued',
        cardId = cardId
    })
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateBankBlips()
    SpawnBankNPCs()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, npc in ipairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    for _, prop in ipairs(spawnedProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end

    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    if bankOpen then
        CloseBank()
    end
end)
