-- sb_minigame | Client Main
-- Standalone reusable minigame engine

local activeCallback = nil
local isActive = false

-- ===== MAIN EXPORT =====
exports('Start', function(options, cb)
    if isActive then
        if cb then cb(false, 0) end
        return
    end

    -- Check if player is dead
    if exports['sb_deaths'] and exports['sb_deaths']:IsPlayerDead(PlayerId()) then
        if cb then cb(false, 0) end
        return
    end

    local opts = options or {}
    local gameType = opts.type or 'timing'
    local difficulty = opts.difficulty or 3
    local rounds = opts.rounds or 3
    local label = opts.label or ''

    -- Validate
    if gameType ~= 'timing' and gameType ~= 'sequence' and gameType ~= 'precision' then
        print('[sb_minigame] Invalid game type: ' .. tostring(gameType))
        if cb then cb(false, 0) end
        return
    end

    difficulty = math.max(1, math.min(5, difficulty))
    rounds = math.max(1, rounds)

    isActive = true
    activeCallback = cb

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'start',
        type = gameType,
        difficulty = difficulty,
        rounds = rounds,
        label = label,
    })
end)

-- ===== NUI CALLBACK: RESULT =====
RegisterNUICallback('result', function(data, cb)
    cb('ok')

    local success = data.success
    local score = data.score or 0

    CloseMinigame()

    if activeCallback then
        local fn = activeCallback
        activeCallback = nil
        fn(success, score)
    end
end)

-- ===== CLOSE / CLEANUP =====
function CloseMinigame()
    if not isActive then return end
    isActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- Close on death
CreateThread(function()
    while true do
        Wait(500)
        if isActive then
            if IsEntityDead(PlayerPedId()) then
                CloseMinigame()
                if activeCallback then
                    local fn = activeCallback
                    activeCallback = nil
                    fn(false, 0)
                end
            end
        end
    end
end)

-- Close on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isActive then
            CloseMinigame()
        end
    end
end)

-- ===== TEST COMMANDS =====
RegisterCommand('testmini1', function()
    exports['sb_minigame']:Start({
        type = 'timing',
        difficulty = 3,
        rounds = 3,
        label = 'Timing Test',
    }, function(success, score)
        print('[sb_minigame] Timing result: ' .. tostring(success) .. ' score: ' .. tostring(score))
        if exports['sb_notify'] then
            exports['sb_notify']:Notify(
                success and ('Timing passed! Score: ' .. score) or ('Timing failed. Score: ' .. score),
                success and 'success' or 'error',
                3000
            )
        end
    end)
end, false)

RegisterCommand('testmini2', function()
    exports['sb_minigame']:Start({
        type = 'sequence',
        difficulty = 3,
        rounds = 3,
        label = 'Sequence Test',
    }, function(success, score)
        print('[sb_minigame] Sequence result: ' .. tostring(success) .. ' score: ' .. tostring(score))
        if exports['sb_notify'] then
            exports['sb_notify']:Notify(
                success and ('Sequence passed! Score: ' .. score) or ('Sequence failed. Score: ' .. score),
                success and 'success' or 'error',
                3000
            )
        end
    end)
end, false)

RegisterCommand('testmini3', function()
    exports['sb_minigame']:Start({
        type = 'precision',
        difficulty = 3,
        rounds = 3,
        label = 'Precision Test',
    }, function(success, score)
        print('[sb_minigame] Precision result: ' .. tostring(success) .. ' score: ' .. tostring(score))
        if exports['sb_notify'] then
            exports['sb_notify']:Notify(
                success and ('Precision passed! Score: ' .. score) or ('Precision failed. Score: ' .. score),
                success and 'success' or 'error',
                3000
            )
        end
    end)
end, false)
