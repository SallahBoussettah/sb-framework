--[[
    Everyday Chaos RP - Drug System (Client)
    Author: Salah Eddine Boussettah

    Handles: IPL loading, lab zones, field zones, NPC spawning,
    shop interaction, production flow, progress bars, animations,
    blips, sb_target zones.
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- State
local spawnedNPCs = {}
local spawnedBlips = {}
local isProcessing = false
local currentShopIndex = nil

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
        if GetGameTimer() > timeout then
            print('[sb_drugs] Failed to load model: ' .. tostring(model))
            return nil
        end
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

local function SpawnNPC(model, coords, freeze, scenario)
    local hash = LoadModel(model)
    if not hash then return nil end

    local x, y, z, h = coords.x, coords.y, coords.z, coords.w or 0.0
    local ped = CreatePed(0, hash, x, y, z - 1.0, h, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, freeze ~= false)

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function CreateBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    spawnedBlips[#spawnedBlips + 1] = blip
    return blip
end

-- ========================================================================
-- IPL LOADING (bob74_ipl for MC Business interiors)
-- ========================================================================
CreateThread(function()
    Wait(2000) -- Wait for bob74_ipl to be ready

    local ok, err = pcall(function()
        -- Weed Farm
        local weedFarm = exports['bob74_ipl']:GetBikerWeedFarmObject()
        if weedFarm then
            weedFarm.Style.Set(weedFarm.Style.basic)
            if weedFarm.Security then
                weedFarm.Security.Set(weedFarm.Security.basic)
            end
            -- Set plant growth stages — Plant.Set(stage, lightType)
            for i = 1, 9 do
                local plant = weedFarm['Plant' .. i]
                if plant then
                    plant.Set(plant.Stage.full, plant.Light.basic)
                end
            end
            RefreshInterior(weedFarm.interiorId)
        end

        -- Cocaine Lockup
        local cocaineLab = exports['bob74_ipl']:GetBikerCocaineObject()
        if cocaineLab then
            cocaineLab.Style.Set(cocaineLab.Style.upgrade, false)
            if cocaineLab.Security then
                cocaineLab.Security.Set(cocaineLab.Security.upgrade, false)
            end
            RefreshInterior(cocaineLab.interiorId)
        end

        -- Meth Lab
        local methLab = exports['bob74_ipl']:GetBikerMethLabObject()
        if methLab then
            methLab.Style.Set(methLab.Style.upgrade, false)
            if methLab.Security then
                methLab.Security.Set(methLab.Security.upgrade, false)
            end
            RefreshInterior(methLab.interiorId)
        end
    end)

    if ok then
        if Config.Debug then print('[sb_drugs] IPL interiors loaded') end
    else
        print('[sb_drugs] IPL loading error (bob74_ipl may not be ready): ' .. tostring(err))
    end
end)

-- ========================================================================
-- SHOP NPCs + BLIPS
-- ========================================================================
CreateThread(function()
    Wait(3000)

    for i, shop in ipairs(Config.Shops) do
        -- Spawn NPC
        local ped = SpawnNPC(shop.model, shop.coords, true, 'WORLD_HUMAN_STAND_IMPATIENT')
        if ped then
            spawnedNPCs[#spawnedNPCs + 1] = ped

            -- Add target
            exports['sb_target']:AddTargetEntity(ped, {
                {
                    name = 'drug_shop_' .. i,
                    label = 'Browse ' .. shop.name,
                    icon = 'fa-store',
                    distance = 2.5,
                    action = function()
                        OpenDrugShop(i)
                    end,
                },
            })
        end

        -- Blip
        if shop.blip then
            CreateBlip(vector3(shop.coords.x, shop.coords.y, shop.coords.z),
                shop.blip.sprite, shop.blip.color, shop.blip.scale, shop.name)
        end
    end

    if Config.Debug then print('[sb_drugs] Shop NPCs spawned: ' .. #Config.Shops) end
end)

-- ========================================================================
-- TRADE NPCs (Gerald, Madrazo)
-- ========================================================================
CreateThread(function()
    Wait(3500)

    for i, tradeNpc in ipairs(Config.TradeNPCs) do
        local ped = SpawnNPC(tradeNpc.model, tradeNpc.coords, true, 'WORLD_HUMAN_STAND_IMPATIENT')
        if ped then
            spawnedNPCs[#spawnedNPCs + 1] = ped

            exports['sb_target']:AddTargetEntity(ped, {
                {
                    name = 'drug_trade_' .. i,
                    label = tradeNpc.trade.label,
                    icon = 'fa-handshake',
                    distance = 2.5,
                    action = function()
                        TriggerServerEvent('sb_drugs:server:tradeForCard', i)
                    end,
                },
            })
        end

        if tradeNpc.blip then
            CreateBlip(vector3(tradeNpc.coords.x, tradeNpc.coords.y, tradeNpc.coords.z),
                tradeNpc.blip.sprite, tradeNpc.blip.color, tradeNpc.blip.scale, tradeNpc.name)
        end
    end
end)

-- ========================================================================
-- WEED PLANT GROWTH SYSTEM (per-group visual growth via bob74_ipl)
--
-- 9 harvest zones, each mapping 1:1 to bob74_ipl Plant1-Plant9.
-- Each zone independently grows: full (pickable) -> harvest -> small -> medium -> full
-- Uses interior entity sets: stage1=small, stage2=medium, stage3=full
-- ========================================================================
local groupState = {}        -- [1..9] = { stage=3, resetTime=0 }
local groupZones = {}        -- [1..9] = zone name string
local groupsInitialized = false
local currentPickGroup = nil
local isInWeedFarm = false

local stageMap = { [1] = 'small', [2] = 'medium', [3] = 'full' }

-- Set a single bob74_ipl plant group to a specific stage (1=small, 2=medium, 3=full)
local function SetGroupStage(groupIdx, stage)
    local stageName = stageMap[stage]
    if not stageName then return end

    local ok, err = pcall(function()
        local weedFarm = exports['bob74_ipl']:GetBikerWeedFarmObject()
        if not weedFarm then return end

        local plant = weedFarm['Plant' .. groupIdx]
        if plant then
            plant.Stage.Set(plant.Stage[stageName], false)
            RefreshInterior(weedFarm.interiorId)
        end
    end)

    if not ok then
        print('[sb_drugs] SetGroupStage(' .. groupIdx .. ', ' .. stage .. ') error: ' .. tostring(err))
    end

    if groupState[groupIdx] then
        groupState[groupIdx].stage = stage
    end
end

-- Create 9 sb_target BoxZones, one per weed group
local function InitWeedGroups()
    if groupsInitialized then return end

    local groups = Config.WeedGroups
    if not groups or #groups == 0 then return end

    groupZones = {}

    for i, group in ipairs(groups) do
        local zoneName = 'weed_group_' .. i

        exports['sb_target']:AddBoxZone(
            zoneName,
            group.coords,
            group.width or 3.0, group.length or 4.0, 2.0,
            0.0,
            {
                {
                    name = zoneName,
                    label = 'Harvest Weed Buds',
                    icon = 'fa-cannabis',
                    distance = 2.0,
                    action = function()
                        if isProcessing then
                            Notify('Already processing', 'error')
                            return
                        end
                        if groupState[i].stage ~= 3 then
                            Notify('These plants are still growing', 'error')
                            return
                        end
                        currentPickGroup = i
                        TriggerServerEvent('sb_drugs:server:processStep', 'weed_pick')
                    end,
                    canInteract = function()
                        return not isProcessing and groupState[i] and groupState[i].stage == 3
                    end,
                },
            }
        )

        groupZones[i] = zoneName
    end

    groupsInitialized = true
    if Config.Debug then print('[sb_drugs] Weed group zones created: ' .. #groups) end
end

-- Cleanup all weed group zones
local function CleanupWeedGroups()
    if groupsInitialized then
        for _, zoneName in pairs(groupZones) do
            pcall(function()
                exports['sb_target']:RemoveZone(zoneName)
            end)
        end
    end
    groupsInitialized = false
    groupZones = {}
    currentPickGroup = nil
end

-- Handle plant picked: visually shrink that group to small, start regrow timer
RegisterNetEvent('sb_drugs:client:plantPicked', function()
    if currentPickGroup and groupState[currentPickGroup] then
        SetGroupStage(currentPickGroup, 1)
        groupState[currentPickGroup].resetTime = GetGameTimer() / 1000
    end
    currentPickGroup = nil
end)

-- Per-group growth cycle thread
CreateThread(function()
    while true do
        Wait(1000)

        if not isInWeedFarm then goto continue end

        local now = GetGameTimer() / 1000
        local stageTime = Config.PlantGrowth.stageTime

        for i = 1, #Config.WeedGroups do
            local gs = groupState[i]
            if gs and gs.resetTime > 0 then
                local elapsed = now - gs.resetTime

                if gs.stage == 1 and elapsed >= stageTime then
                    -- Small -> Medium
                    SetGroupStage(i, 2)
                    if Config.Debug then print('[sb_drugs] Group ' .. i .. ': small -> medium') end
                elseif gs.stage == 2 and elapsed >= (stageTime * 2) then
                    -- Medium -> Full (pickable again)
                    SetGroupStage(i, 3)
                    gs.resetTime = 0
                    if Config.Debug then print('[sb_drugs] Group ' .. i .. ': medium -> full') end
                end
            end
        end

        ::continue::
    end
end)

-- ========================================================================
-- LAB TELEPORT HELPER (fade out -> freeze -> teleport -> fade in)
-- ========================================================================
local isTeleporting = false

local function TeleportToLab(targetCoords, label, labKey, entering)
    if isTeleporting then return end
    isTeleporting = true

    local ped = PlayerPedId()
    DoScreenFadeOut(1000)
    Wait(1000)
    FreezeEntityPosition(ped, true)

    -- Teleport
    SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
    Wait(1100)

    DoScreenFadeIn(500)
    FreezeEntityPosition(ped, false)
    isTeleporting = false
    Notify(label, 'info', 2000)

    -- Weed plant growth system (per-group)
    if labKey == 'weed' then
        if entering then
            isInWeedFarm = true

            local now = GetGameTimer() / 1000
            local stageTime = Config.PlantGrowth.stageTime

            -- Initialize per-group state (or restore from previous visit)
            for i = 1, #Config.WeedGroups do
                if not groupState[i] then
                    groupState[i] = { stage = 3, resetTime = 0 }
                end

                -- Calculate current stage from elapsed time since reset
                local gs = groupState[i]
                if gs.resetTime > 0 then
                    local elapsed = now - gs.resetTime
                    if elapsed >= stageTime * 2 then
                        gs.stage = 3
                        gs.resetTime = 0
                    elseif elapsed >= stageTime then
                        gs.stage = 2
                    else
                        gs.stage = 1
                    end
                end

                SetGroupStage(i, gs.stage)
            end

            Wait(500) -- Let entities stream in
            InitWeedGroups()
        else
            isInWeedFarm = false
            CleanupWeedGroups()
        end
    end
end

-- ========================================================================
-- LAB ENTRANCES (surface-level sb_target zones) + EXITS (inside lab)
-- ========================================================================
CreateThread(function()
    Wait(4000)

    for labKey, lab in pairs(Config.Labs) do
        -- Blip at surface entrance (not underground)
        if lab.blip then
            CreateBlip(lab.surfaceEnter, lab.blip.sprite, lab.blip.color, lab.blip.scale, lab.name)
        end

        -- ENTRANCE: sb_target at surface location
        exports['sb_target']:AddBoxZone(
            'drug_entrance_' .. labKey,
            lab.surfaceEnter,
            2.0, 2.0, 3.0,
            0.0,
            {
                {
                    name = 'drug_enter_' .. labKey,
                    label = 'Enter ' .. lab.name,
                    icon = 'fa-door-open',
                    distance = 2.0,
                    action = function()
                        -- Check access card via server callback
                        SBCore.Functions.TriggerCallback('sb_drugs:server:hasAccessCard', function(hasCard)
                            if hasCard then
                                TeleportToLab(lab.labEnter, 'Entering ' .. lab.name .. '...', labKey, true)
                            else
                                Notify('You need an access card for this lab', 'error')
                            end
                        end, lab.requiredCard)
                    end,
                },
            }
        )

        -- EXIT: sb_target inside the lab
        exports['sb_target']:AddBoxZone(
            'drug_exit_' .. labKey,
            lab.labExit,
            2.0, 2.0, 3.0,
            0.0,
            {
                {
                    name = 'drug_leave_' .. labKey,
                    label = 'Leave ' .. lab.name,
                    icon = 'fa-door-open',
                    distance = 2.0,
                    action = function()
                        TeleportToLab(lab.surfaceExit, 'Leaving ' .. lab.name .. '...', labKey, false)
                    end,
                },
            }
        )

        -- STATION TARGETS (work zones inside the lab)
        for stationKey, station in pairs(lab.stations) do
            local stepId = nil
            for chainId, chain in pairs(Config.ProductionChains) do
                if chain.location == 'lab:' .. labKey .. ':' .. stationKey then
                    stepId = chainId
                    break
                end
            end

            if stepId then
                local zs = station.zoneSize or 2.0
                exports['sb_target']:AddBoxZone(
                    'drug_lab_' .. labKey .. '_' .. stationKey,
                    station.coords,
                    zs, zs, 2.5,
                    station.heading,
                    {
                        {
                            name = 'drug_process_' .. stepId,
                            label = station.label,
                            icon = 'fa-flask',
                            distance = 2.0,
                            action = function()
                                if isProcessing then
                                    Notify('Already processing', 'error')
                                    return
                                end
                                TriggerServerEvent('sb_drugs:server:processStep', stepId)
                            end,
                            canInteract = function()
                                return not isProcessing
                            end,
                        },
                    }
                )
            end
        end
    end
end)

-- ========================================================================
-- FIELD ZONES (outdoor harvesting)
-- ========================================================================
CreateThread(function()
    Wait(4500)

    for fieldKey, field in pairs(Config.Fields) do
        -- Field blip
        if field.blip then
            CreateBlip(field.coords, field.blip.sprite, field.blip.color, field.blip.scale, field.label)
        end

        -- Find production steps for this field
        local fieldSteps = {}
        for chainId, chain in pairs(Config.ProductionChains) do
            if chain.location == 'field:' .. fieldKey then
                fieldSteps[#fieldSteps + 1] = { id = chainId, chain = chain }
            end
        end

        if #fieldSteps > 0 then
            -- Create options array for sb_target
            local options = {}
            for _, fs in ipairs(fieldSteps) do
                options[#options + 1] = {
                    name = 'drug_field_' .. fs.id,
                    label = fs.chain.label,
                    icon = 'fa-leaf',
                    distance = 2.0,
                    action = function()
                        if isProcessing then
                            Notify('Already processing', 'error')
                            return
                        end
                        TriggerServerEvent('sb_drugs:server:processStep', fs.id)
                    end,
                    canInteract = function()
                        return not isProcessing
                    end,
                }
            end

            exports['sb_target']:AddBoxZone(
                'drug_field_' .. fieldKey,
                field.coords,
                field.radius, field.radius, 15.0,
                0.0,
                options
            )
        end
    end
end)

-- ========================================================================
-- SHOP NUI (open/close/purchase)
-- ========================================================================

function OpenDrugShop(shopIndex)
    local shop = Config.Shops[shopIndex]
    if not shop then return end

    currentShopIndex = shopIndex

    SBCore.Functions.TriggerCallback('sb_drugs:server:getPlayerMoney', function(cash, bank)
        SBCore.Functions.TriggerCallback('sb_drugs:server:getCarryLimits', function(limits)
            SetNuiFocus(true, true)
            SendNUIMessage({
                type = 'open',
                shopName = shop.name,
                items = shop.items,
                cash = cash,
                bank = bank,
                carryLimits = limits,
            })
        end)
    end)
end

RegisterNUICallback('closeShop', function(data, cb)
    SetNuiFocus(false, false)
    currentShopIndex = nil
    cb('ok')
end)

RegisterNUICallback('purchaseShop', function(data, cb)
    if not currentShopIndex then
        cb('error')
        return
    end
    TriggerServerEvent('sb_drugs:server:purchaseShop', currentShopIndex, data.cart)
    cb('ok')
end)

RegisterNUICallback('notify', function(data, cb)
    Notify(data.msg, data.type, data.duration)
    cb('ok')
end)

-- Server responses for shop
RegisterNetEvent('sb_drugs:client:purchaseSuccess', function(cash, bank)
    SendNUIMessage({
        type = 'purchaseSuccess',
        cash = cash,
        bank = bank,
    })
end)

RegisterNetEvent('sb_drugs:client:purchaseFailed', function()
    SendNUIMessage({ type = 'purchaseFailed' })
end)

-- ========================================================================
-- PRODUCTION PROGRESS BAR + ANIMATION
-- ========================================================================

RegisterNetEvent('sb_drugs:client:startProgress', function(stepId, duration, label, anim, minigame)
    if isProcessing then return end
    isProcessing = true

    -- Minigame check first (if required)
    if minigame then
        local finished = false
        local success = false

        exports['sb_minigame']:Start({
            type = minigame,    -- 'timing' or 'precision'
            difficulty = 3,
            rounds = 3,
            label = label,
        }, function(result)
            success = result
            finished = true
        end)

        -- Wait for minigame callback
        while not finished do
            Wait(100)
        end

        if not success then
            isProcessing = false
            TriggerServerEvent('sb_drugs:server:cancelStep')
            Notify('Failed! Try again.', 'error')
            return
        end
    end

    -- Build progress bar options
    local progressOpts = {
        duration = duration * 1000,
        label = label,
        canCancel = true,
        onComplete = function()
            isProcessing = false
            TriggerServerEvent('sb_drugs:server:completeStep', stepId)
        end,
        onCancel = function()
            isProcessing = false
            TriggerServerEvent('sb_drugs:server:cancelStep')
            Notify('Cancelled', 'error')
        end,
    }

    -- Add animation if provided
    if anim and anim.dict and anim.clip then
        progressOpts.animation = { dict = anim.dict, anim = anim.clip, flag = 1 }
    end

    -- Start progress bar (callback-based, returns immediately)
    local started = exports['sb_progressbar']:Start(progressOpts)
    if not started then
        isProcessing = false
        TriggerServerEvent('sb_drugs:server:cancelStep')
    end
end)

-- ========================================================================
-- NOTIFICATION HANDLER (server → client)
-- ========================================================================

RegisterNetEvent('sb_drugs:client:notify', function(msg, type, duration)
    Notify(msg, type, duration)
end)

-- ========================================================================
-- CLEANUP
-- ========================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove NPCs
    for _, ped in ipairs(spawnedNPCs) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end

    -- Remove blips
    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    -- Close NUI
    SetNuiFocus(false, false)

    -- Reset state
    isProcessing = false
    currentShopIndex = nil

    -- Reset plant growth system
    isInWeedFarm = false
    CleanupWeedGroups()
end)
