-- ============================================================================
-- SB_PRISON - Prison Jobs Client (Phase 2)
-- Multi-step job flow (walk between stations), credits state
-- ============================================================================

-- Credits state (synced from server)
local prisonCredits = 0

-- Cooldown tracking: jobCooldownEnd[jobId] = GetGameTimer() value
local jobCooldownEnd = {}

-- Job state machine
local isDoingJob = false
local activeJobId = nil
local activeJobStep = 0

-- Spawned zone names for cleanup
local spawnedJobZones = {}

-- ============================================================================
-- GLOBAL ACCESSORS (called by client/main.lua)
-- ============================================================================

function GetPrisonCredits()
    return prisonCredits
end

-- ============================================================================
-- SPAWN JOB ZONES (called when prisoner starts serving at Bolingbroke)
-- ============================================================================

function SpawnPrisonJobZones()
    -- Prevent double-spawn
    if #spawnedJobZones > 0 then return end

    for jobId, cfg in pairs(Config.PrisonJobs) do
        local entry = cfg.entryZone
        local zoneName = 'prison_job_' .. jobId
        exports['sb_target']:AddBoxZone(zoneName, entry.coords, entry.width, entry.length, entry.height, entry.heading, {
            {
                name = 'start_prison_job_' .. jobId,
                label = cfg.targetLabel,
                icon = cfg.targetIcon,
                distance = cfg.targetDistance,
                canInteract = function()
                    local jailed, location = GetPrisonState()
                    if not jailed or location ~= 'bolingbroke' then return false end
                    if isDoingJob then return false end
                    if jobCooldownEnd[jobId] and GetGameTimer() < jobCooldownEnd[jobId] then return false end
                    return true
                end,
                action = function()
                    StartJobFlow(jobId, cfg)
                end,
            }
        })
        table.insert(spawnedJobZones, zoneName)
    end

    if Config.Debug then
        print('[sb_prison] Spawned ' .. #spawnedJobZones .. ' prison job entry zones')
    end
end

-- ============================================================================
-- HELPERS
-- ============================================================================

-- Resolve coords for a step: supports single vector3 or table of vector3s (random pick)
-- resolvedCoords is populated once per job cycle in StartJobFlow
local resolvedCoords = {}

function ResolveStepCoords(step)
    local c = step.coords
    if type(c) == 'table' and c.x then
        -- Single vector3
        return c
    elseif type(c) == 'table' and #c > 0 then
        -- Array of vector3s — pick random
        return c[math.random(#c)]
    end
    return c
end

-- ============================================================================
-- MULTI-STEP JOB FLOW (intake-style state machine)
-- ============================================================================

function StartJobFlow(jobId, cfg)
    if isDoingJob then return end
    isDoingJob = true
    activeJobId = jobId
    activeJobStep = 1

    local steps = cfg.steps

    -- Pre-resolve random coords for this cycle (so markers stay consistent)
    resolvedCoords = {}
    for i, step in ipairs(steps) do
        resolvedCoords[i] = ResolveStepCoords(step)
    end

    -- HUD + marker draw thread
    CreateThread(function()
        while isDoingJob and activeJobStep >= 1 and activeJobStep <= #steps do
            local step = steps[activeJobStep]
            local stepCoords = resolvedCoords[activeJobStep]

            -- Draw HUD text (below timer at 0.06 and credits at 0.095)
            SetTextFont(4)
            SetTextScale(0.45, 0.45)
            SetTextColour(255, 220, 50, 255)
            SetTextCentre(true)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEntry('STRING')
            AddTextComponentString(step.hudText)
            DrawText(0.5, 0.13)

            -- Draw marker at current step (skip step 1 since player is already there)
            if activeJobStep > 1 then
                local mc = cfg.markerColor
                DrawMarker(
                    cfg.markerType,
                    stepCoords.x, stepCoords.y, stepCoords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    cfg.markerScale.x, cfg.markerScale.y, cfg.markerScale.z,
                    mc.r, mc.g, mc.b, mc.a,
                    false, false, 2, false, nil, nil, false
                )
            end

            Wait(0)
        end
    end)

    -- Step execution thread
    CreateThread(function()
        -- Step 1 fires immediately (player is at entry zone)
        ExecuteJobStep(cfg, 1)

        -- Steps 2+ require walking to the marker
        for stepNum = 2, #steps do
            if not isDoingJob then return end
            activeJobStep = stepNum

            -- Wait for player to reach the marker
            local stepCoords = resolvedCoords[stepNum]
            while isDoingJob do
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                local dist = #(pos - stepCoords)
                if dist <= cfg.triggerDist then
                    break
                end
                Wait(300)
            end

            if not isDoingJob then return end

            -- Execute step action
            local success = ExecuteJobStep(cfg, stepNum)
            if not success then
                -- Minigame failed — abort the whole shift
                isDoingJob = false
                activeJobId = nil
                activeJobStep = 0
                resolvedCoords = {}
                exports['sb_notify']:Notify('Shift failed — try again later', 'error', 3000)
                return
            end
        end

        -- All steps complete — tell server
        if isDoingJob then
            TriggerServerEvent('sb_prison:server:completeJob', jobId)
            jobCooldownEnd[jobId] = GetGameTimer() + (cfg.cooldown * 1000)
        end

        isDoingJob = false
        activeJobId = nil
        activeJobStep = 0
        resolvedCoords = {}
    end)
end

-- Execute a single step (animation + optional minigame + progress bar)
-- Returns true on success, false on minigame fail
function ExecuteJobStep(cfg, stepNum)
    local step = cfg.steps[stepNum]
    local stepCoords = resolvedCoords[stepNum]
    local ped = PlayerPedId()

    -- Face the station
    TaskTurnPedToFaceCoord(ped, stepCoords.x, stepCoords.y, stepCoords.z, 1000)
    Wait(500)

    -- Minigame (if this step has one)
    if step.minigame then
        local minigameResult = nil
        exports['sb_minigame']:Start({
            type = step.minigame.type,
            difficulty = step.minigame.difficulty,
            rounds = step.minigame.rounds,
            label = step.minigame.label,
        }, function(success, score)
            minigameResult = success
        end)

        -- Wait for minigame callback
        while minigameResult == nil do Wait(100) end

        if not minigameResult then
            return false
        end
    end

    -- Animation + progress bar
    local anim = step.animation
    if anim then
        RequestAnimDict(anim.dict)
        local timeout = 0
        while not HasAnimDictLoaded(anim.dict) and timeout < 5000 do
            Wait(100)
            timeout = timeout + 100
        end
        if HasAnimDictLoaded(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.anim, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)
        end
    end

    exports['sb_progressbar']:Start({
        duration = step.progressDuration,
        label = step.progressLabel,
        disableMovement = true,
        disableCombat = true,
    })
    Wait(step.progressDuration)

    ClearPedTasks(ped)
    if anim then
        RemoveAnimDict(anim.dict)
    end

    return true
end

-- ============================================================================
-- CLEANUP JOB ZONES (called on release / resource stop)
-- ============================================================================

function CleanupPrisonJobZones()
    for _, zoneName in ipairs(spawnedJobZones) do
        exports['sb_target']:RemoveZone(zoneName)
    end
    spawnedJobZones = {}
    jobCooldownEnd = {}
    isDoingJob = false
    activeJobId = nil
    activeJobStep = 0
    resolvedCoords = {}
    prisonCredits = 0
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Server syncs credits balance
RegisterNetEvent('sb_prison:client:syncCredits', function(balance)
    prisonCredits = balance or 0
end)

-- Server confirms job completion
RegisterNetEvent('sb_prison:client:jobComplete', function(data)
    prisonCredits = data.credits or prisonCredits

    -- Update the timer in main.lua
    if SetTimeRemaining and data.timeRemaining then
        SetTimeRemaining(data.timeRemaining)
    end

    exports['sb_notify']:Notify(
        '+' .. (data.creditsEarned or 0) .. ' credits, -' .. (data.timeReduction or 0) .. 's time',
        'success', 4000
    )
end)
