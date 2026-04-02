local SB = exports['sb_core']:GetCoreObject()

local jobCenterNPC = nil
local isNUIOpen = false
local nuiMode = nil -- 'browse' or 'manage'

-- ============================================================================
-- NPC SPAWN
-- ============================================================================

local function SpawnNPC()
    local loc = Config.Location
    local model = GetHashKey(Config.NPCModel)

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then
            print('[sb_jobs] Failed to load NPC model: ' .. Config.NPCModel)
            return
        end
    end

    jobCenterNPC = CreatePed(4, model, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.coords.w, false, true)
    SetEntityInvincible(jobCenterNPC, true)
    FreezeEntityPosition(jobCenterNPC, true)
    SetBlockingOfNonTemporaryEvents(jobCenterNPC, true)
    SetPedFleeAttributes(jobCenterNPC, 0, false)
    SetPedCombatAttributes(jobCenterNPC, 46, true)
    SetPedCanPlayAmbientAnims(jobCenterNPC, false)
    SetModelAsNoLongerNeeded(model)

    TaskStartScenarioInPlace(jobCenterNPC, 'PROP_HUMAN_SEAT_CHAIR_UPRIGHT', 0, true)

    exports['sb_target']:AddTargetEntity(jobCenterNPC, {
        {
            name = 'job_browse',
            label = 'Browse Available Jobs',
            icon = 'fa-briefcase',
            distance = Config.InteractDistance,
            action = function()
                OpenJobCenter('browse')
            end
        },
        {
            name = 'job_manage',
            label = 'Manage Job Listings',
            icon = 'fa-clipboard-list',
            distance = Config.InteractDistance,
            canInteract = function()
                local playerData = SB.Functions.GetPlayerData()
                if not playerData or not playerData.job then return false end
                return playerData.job.isboss == true
            end,
            action = function()
                OpenJobCenter('manage')
            end
        }
    })
end

-- ============================================================================
-- BLIP
-- ============================================================================

local function CreateJobBlip()
    local loc = Config.Location
    local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
    SetBlipSprite(blip, loc.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, loc.blip.scale)
    SetBlipColour(blip, loc.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(loc.blip.label)
    EndTextCommandSetBlipName(blip)
end

-- ============================================================================
-- NUI CONTROL
-- ============================================================================

function OpenJobCenter(mode)
    if isNUIOpen then return end

    if mode == 'browse' then
        SB.Functions.TriggerCallback('sb_jobs:server:getJobCenterData', function(data)
            if not data then return end
            isNUIOpen = true
            nuiMode = 'browse'
            SetNuiFocus(true, true)
            TriggerEvent('sb_hud:setVisible', false)

            SendNUIMessage({
                action = 'open',
                mode = 'browse',
                currentJob = data.currentJob,
                publicJobs = data.publicJobs,
                rpListings = data.rpListings,
                activePublicJob = data.activePublicJob,
                appliedListings = data.appliedListings or {}
            })
        end)
    elseif mode == 'manage' then
        SB.Functions.TriggerCallback('sb_jobs:server:getBossData', function(data)
            if not data then return end
            isNUIOpen = true
            nuiMode = 'manage'
            SetNuiFocus(true, true)
            TriggerEvent('sb_hud:setVisible', false)

            SendNUIMessage({
                action = 'open',
                mode = 'manage',
                bossData = data
            })
        end)
    end
end

local function CloseNUI()
    if not isNUIOpen then return end
    isNUIOpen = false
    nuiMode = nil
    SetNuiFocus(false, false)
    TriggerEvent('sb_hud:setVisible', true)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(_, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('startPublicJob', function(data, cb)
    if not data.jobId then cb('ok') return end
    TriggerServerEvent('sb_jobs:server:startPublicJob', data.jobId)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('quitPublicJob', function(_, cb)
    TriggerServerEvent('sb_jobs:server:quitPublicJob')
    -- Wait briefly for server to process, then refresh the NUI data
    SetTimeout(500, function()
        if isNUIOpen and nuiMode == 'browse' then
            SB.Functions.TriggerCallback('sb_jobs:server:getJobCenterData', function(data)
                if not data then return end
                SendNUIMessage({
                    action = 'open',
                    mode = 'browse',
                    currentJob = data.currentJob,
                    publicJobs = data.publicJobs,
                    rpListings = data.rpListings,
                    activePublicJob = data.activePublicJob,
                    appliedListings = data.appliedListings or {}
                })
            end)
        end
    end)
    cb('ok')
end)

RegisterNUICallback('applyRPJob', function(data, cb)
    if not data.listingId then cb('ok') return end
    TriggerServerEvent('sb_jobs:server:applyRPJob', data.listingId)
    cb('ok')
end)

RegisterNUICallback('toggleListing', function(data, cb)
    TriggerServerEvent('sb_jobs:server:toggleListing', data.active)
    cb('ok')
end)

RegisterNUICallback('updateAppStatus', function(data, cb)
    if not data.appId or not data.status then cb('ok') return end
    TriggerServerEvent('sb_jobs:server:updateAppStatus', data.appId, data.status)
    cb('ok')
end)

-- ============================================================================
-- SERVER RESPONSES
-- ============================================================================

RegisterNetEvent('sb_jobs:client:notify', function(msg, type)
    exports['sb_notify']:Notify(msg, type or 'info', 5000)
end)

-- ============================================================================
-- INIT
-- ============================================================================

CreateThread(function()
    SpawnNPC()
    CreateJobBlip()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if jobCenterNPC and DoesEntityExist(jobCenterNPC) then
        DeleteEntity(jobCenterNPC)
    end
    if isNUIOpen then
        CloseNUI()
    end
end)
