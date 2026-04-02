--[[
    Everyday Chaos RP - MMA Arena Betting System (Client)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, blip, target, fight visuals, NUI control
]]

local SB = exports['sb_core']:GetCoreObject()
local nuiOpen = false
local spawnedNPCs = {}
local spawnedFighters = {}
local arenaBlip = nil
local currentState = 'IDLE'

-- ============================================================================
-- MAP BLIP
-- ============================================================================

local function CreateArenaBlip()
    local cfg = Config.Blip
    arenaBlip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(arenaBlip, cfg.sprite)
    SetBlipDisplay(arenaBlip, 4)
    SetBlipScale(arenaBlip, cfg.scale)
    SetBlipColour(arenaBlip, cfg.color)
    SetBlipAsShortRange(arenaBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label)
    EndTextCommandSetBlipName(arenaBlip)
end

-- ============================================================================
-- MODEL LOADING HELPER
-- ============================================================================

local function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print('[sb_mma] Failed to load model: ' .. tostring(model))
            return nil
        end
    end
    return hash
end

-- ============================================================================
-- BOOKMAKER NPC SPAWNING
-- ============================================================================

local function SpawnBookmakers()
    for i, bk in ipairs(Config.Bookmakers) do
        local hash = LoadModel(bk.model)
        if hash then
            local npc = CreatePed(4, hash, bk.coords.x, bk.coords.y, bk.coords.z - 1.0, bk.coords.w, false, true)
            SetEntityAsMissionEntity(npc, true, true)
            SetBlockingOfNonTemporaryEvents(npc, true)
            SetPedFleeAttributes(npc, 0, false)
            SetPedCombatAttributes(npc, 46, true)
            SetPedCanRagdollFromPlayerImpact(npc, false)
            SetEntityInvincible(npc, true)
            FreezeEntityPosition(npc, true)

            exports['sb_target']:AddTargetEntity(npc, {
                {
                    name = 'mma_bookmaker_' .. i,
                    label = bk.label,
                    icon = bk.icon,
                    distance = bk.distance,
                    action = function()
                        OpenBettingUI()
                    end
                }
            })

            spawnedNPCs[#spawnedNPCs + 1] = npc
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

-- ============================================================================
-- FIGHTER PED SPAWNING / CLEANUP
-- ============================================================================

local function CleanupFighters()
    for _, ped in ipairs(spawnedFighters) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedFighters = {}
end

local function SpawnFighterPeds(fighters)
    CleanupFighters()

    for slot = 1, 2 do
        local fighter = fighters[slot]
        if fighter then
            local hash = LoadModel(fighter.model)
            if hash then
                local pos = fighter.position
                local ped = CreatePed(4, hash, pos.x, pos.y, pos.z - 1.0, pos.w, false, true)
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedFleeAttributes(ped, 0, false)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                SetPedCanRagdollFromPlayerImpact(ped, false)

                -- Strip weapons
                RemoveAllPedWeapons(ped, true)

                -- Combat-ready stance
                SetPedCombatAttributes(ped, 46, true)
                SetPedCombatMovement(ped, 2)

                spawnedFighters[slot] = ped
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

-- ============================================================================
-- FIGHT SIMULATION
-- ============================================================================

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        t = t + 10
        if t > 5000 then return false end
    end
    return true
end

local function WalkPedTo(ped, coords, heading)
    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, 1.0, -1, heading, 0.5)
    -- Wait until arrived or timeout
    local timeout = 0
    while timeout < 10000 do
        Wait(200)
        timeout = timeout + 200
        local pedCoords = GetEntityCoords(ped)
        local dist = #(pedCoords - vector3(coords.x, coords.y, coords.z))
        if dist < 1.0 then break end
    end
    Wait(300)
end

local function PreparePedForMovement(ped)
    -- Must clear blocking + tasks so the ped can accept new tasks after being frozen
    SetBlockingOfNonTemporaryEvents(ped, false)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

local function GetHeadingBetween(from, to)
    local dx = to.x - from.x
    local dy = to.y - from.y
    return math.deg(math.atan(dx, dy)) % 360.0
end

local function SimulateFight(winnerSlot)
    local loserSlot = winnerSlot == 1 and 2 or 1
    local winner = spawnedFighters[winnerSlot]
    local loser = spawnedFighters[loserSlot]

    if not winner or not loser or not DoesEntityExist(winner) or not DoesEntityExist(loser) then return end

    local winnerCorner = Config.Fighters[winnerSlot].position
    local loserCorner = Config.Fighters[loserSlot].position
    local ringCenter = Config.CageCenter

    -- Prepare peds: clear blocking events, clear tasks, unfreeze
    PreparePedForMovement(winner)
    PreparePedForMovement(loser)
    SetEntityInvincible(winner, true)
    SetEntityInvincible(loser, true)

    -- Walk targets: slightly offset from center so they don't overlap
    local winnerTarget = vector3(
        ringCenter.x + (winnerCorner.x - ringCenter.x) * 0.25,
        ringCenter.y + (winnerCorner.y - ringCenter.y) * 0.25,
        ringCenter.z
    )
    local loserTarget = vector3(
        ringCenter.x + (loserCorner.x - ringCenter.x) * 0.25,
        ringCenter.y + (loserCorner.y - ringCenter.y) * 0.25,
        ringCenter.z
    )

    -- Heading: face each other
    local winnerHeading = GetHeadingBetween(winnerTarget, loserTarget)
    local loserHeading = GetHeadingBetween(loserTarget, winnerTarget)

    -- Walk to center (TaskGoStraightToCoord works without navmesh — flat cage floor)
    TaskGoStraightToCoord(winner, winnerTarget.x, winnerTarget.y, winnerTarget.z, 1.0, 15000, winnerHeading, 1.0)
    TaskGoStraightToCoord(loser, loserTarget.x, loserTarget.y, loserTarget.z, 1.0, 15000, loserHeading, 1.0)

    -- Wait for both to arrive
    local timeout = 0
    while timeout < 12000 do
        Wait(400)
        timeout = timeout + 400
        if not DoesEntityExist(winner) or not DoesEntityExist(loser) then return end
        local wDist = #(GetEntityCoords(winner) - winnerTarget)
        local lDist = #(GetEntityCoords(loser) - loserTarget)
        if wDist < 2.0 and lDist < 2.0 then break end
    end

    Wait(500)

    -- Remove invincibility for the fight
    SetEntityInvincible(winner, false)
    SetEntityInvincible(loser, false)

    -- Set health
    SetEntityMaxHealth(winner, Config.Fighters[winnerSlot].health + 100)
    SetEntityHealth(winner, Config.Fighters[winnerSlot].health + 100)
    SetEntityMaxHealth(loser, Config.Fighters[loserSlot].health + 100)
    SetEntityHealth(loser, Config.Fighters[loserSlot].health + 100)

    -- Make them hostile to each other
    SetPedRelationshipGroupHash(winner, GetHashKey('MMAGROUP1'))
    SetPedRelationshipGroupHash(loser, GetHashKey('MMAGROUP2'))
    SetRelationshipBetweenGroups(5, GetHashKey('MMAGROUP1'), GetHashKey('MMAGROUP2'))
    SetRelationshipBetweenGroups(5, GetHashKey('MMAGROUP2'), GetHashKey('MMAGROUP1'))

    -- Fight! (TaskCombatPed makes them walk toward each other and punch)
    TaskCombatPed(winner, loser, 0, 16)
    TaskCombatPed(loser, winner, 0, 16)

    -- Drain loser's health in a separate thread
    CreateThread(function()
        Wait(5000) -- Let them fight naturally first

        local drainPerTick = 6
        while DoesEntityExist(loser) and not IsEntityDead(loser) do
            local currentHealth = GetEntityHealth(loser)
            if currentHealth <= 101 then break end
            SetEntityHealth(loser, math.max(101, currentHealth - drainPerTick))
            Wait(500)
        end

        -- Ensure loser goes down
        if DoesEntityExist(loser) and not IsEntityDead(loser) then
            SetEntityHealth(loser, 0)
        end

        Wait(3000)

        -- Winner celebration
        if DoesEntityExist(winner) then
            ClearPedTasks(winner)
            SetEntityInvincible(winner, true)
            if LoadAnimDict('anim@mp_player_intcelebrationmale@thumbs_up') then
                TaskPlayAnim(winner, 'anim@mp_player_intcelebrationmale@thumbs_up', 'thumbs_up', 8.0, -8.0, 4000, 0, 0, false, false, false)
            end
        end

        Wait(4000)

        -- Loser gets back up
        if DoesEntityExist(loser) then
            ResurrectPed(loser)
            ClearPedTasksImmediately(loser)
            SetEntityHealth(loser, 200)
            SetEntityInvincible(loser, true)
            Wait(1000)
        end

        -- Winner stops celebrating
        if DoesEntityExist(winner) then
            ClearPedTasks(winner)
            SetEntityInvincible(winner, true)
        end

        Wait(500)

        -- Walk back to corners
        local wCornerVec = vector3(winnerCorner.x, winnerCorner.y, winnerCorner.z)
        local lCornerVec = vector3(loserCorner.x, loserCorner.y, loserCorner.z)

        if DoesEntityExist(winner) then
            TaskGoStraightToCoord(winner, winnerCorner.x, winnerCorner.y, winnerCorner.z, 1.0, 15000, winnerCorner.w, 1.0)
        end
        if DoesEntityExist(loser) then
            TaskGoStraightToCoord(loser, loserCorner.x, loserCorner.y, loserCorner.z, 1.0, 15000, loserCorner.w, 1.0)
        end

        -- Wait for both to arrive back
        local returnTimeout = 0
        while returnTimeout < 12000 do
            Wait(500)
            returnTimeout = returnTimeout + 500
            local wDone = not DoesEntityExist(winner) or #(GetEntityCoords(winner) - wCornerVec) < 1.5
            local lDone = not DoesEntityExist(loser) or #(GetEntityCoords(loser) - lCornerVec) < 1.5
            if wDone and lDone then break end
        end

        -- Snap and freeze back in corners
        if DoesEntityExist(winner) then
            ClearPedTasks(winner)
            SetEntityCoords(winner, winnerCorner.x, winnerCorner.y, winnerCorner.z - 1.0, false, false, false, false)
            SetEntityHeading(winner, winnerCorner.w)
            SetBlockingOfNonTemporaryEvents(winner, true)
            FreezeEntityPosition(winner, true)
        end

        if DoesEntityExist(loser) then
            ClearPedTasks(loser)
            SetEntityCoords(loser, loserCorner.x, loserCorner.y, loserCorner.z - 1.0, false, false, false, false)
            SetEntityHeading(loser, loserCorner.w)
            SetBlockingOfNonTemporaryEvents(loser, true)
            FreezeEntityPosition(loser, true)
        end
    end)
end

-- ============================================================================
-- NUI CONTROL
-- ============================================================================

function OpenBettingUI()
    if nuiOpen then return end

    SB.Functions.TriggerCallback('sb_mma:getState', function(stateData)
        SB.Functions.TriggerCallback('sb_mma:getHistory', function(history)
            local PlayerData = SB.Functions.GetPlayerData()
            local cash = PlayerData.money and PlayerData.money.cash or 0

            nuiOpen = true
            SetNuiFocus(true, true)
            TriggerEvent('sb_hud:setVisible', false)

            SendNUIMessage({
                action = 'open',
                state = stateData,
                history = history,
                cash = cash,
            })
        end)
    end)
end

function CloseBettingUI()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseBettingUI()
    cb('ok')
end)

RegisterNUICallback('placeBet', function(data, cb)
    if not data.fighter or not data.amount then
        cb('ok')
        return
    end
    TriggerServerEvent('sb_mma:server:placeBet', data.fighter, data.amount)
    cb('ok')
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterNetEvent('sb_mma:client:stateUpdate', function(data)
    currentState = data.state

    -- Update NUI if open
    if nuiOpen then
        local PlayerData = SB.Functions.GetPlayerData()
        local cash = PlayerData.money and PlayerData.money.cash or 0
        SendNUIMessage({
            action = 'stateUpdate',
            state = data,
            cash = cash,
        })
    end

    -- Spawn/cleanup fighters based on state
    if data.state == 'BETTING_OPEN' and data.fighters then
        SpawnFighterPeds(data.fighters)
    elseif data.state == 'IDLE' then
        CleanupFighters()
    end
end)

RegisterNetEvent('sb_mma:client:startFight', function(winnerSlot)
    SimulateFight(winnerSlot)
end)

RegisterNetEvent('sb_mma:client:fightResult', function(winner, winnerName)
    if nuiOpen then
        SendNUIMessage({
            action = 'fightResult',
            winner = winner,
            winnerName = winnerName,
        })
    end
end)

RegisterNetEvent('sb_mma:client:announcement', function(msg, msgType)
    exports['sb_notify']:Notify(msg, msgType or 'info', 5000)
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateArenaBlip()
    SpawnBookmakers()

    -- Register chat suggestion for admin command
    TriggerEvent('chat:addSuggestion', '/' .. Config.AdminCommand, 'MMA arena control (admin)', {
        { name = 'action', help = 'start | stop | status' }
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Cleanup NPCs
    for _, npc in ipairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    -- Cleanup fighters
    CleanupFighters()

    -- Cleanup blip
    if arenaBlip and DoesBlipExist(arenaBlip) then
        RemoveBlip(arenaBlip)
    end

    -- Close NUI
    if nuiOpen then
        CloseBettingUI()
    end
end)
