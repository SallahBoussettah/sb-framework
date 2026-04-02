local isActive = false
local canCancel = false
local onComplete = nil
local onCancel = nil
local disableMovement = false
local disableCarMovement = false
local disableCombat = false
local animDict = nil
local animName = nil
local propObj = nil

-- Start progress bar
local function Start(options)
    if isActive then return false end
    if not options or not options.duration or options.duration <= 0 then return false end

    isActive = true
    canCancel = options.canCancel or false
    onComplete = options.onComplete
    onCancel = options.onCancel
    disableMovement = options.disableMovement ~= nil and options.disableMovement or Config.DisableMovement
    disableCarMovement = options.disableCarMovement ~= nil and options.disableCarMovement or Config.DisableCarMovement
    disableCombat = options.disableCombat ~= nil and options.disableCombat or Config.DisableCombat

    -- Play animation if provided
    if options.animation then
        animDict = options.animation.dict
        animName = options.animation.anim
        if animDict and animName then
            RequestAnimDict(animDict)
            local timeout = 0
            while not HasAnimDictLoaded(animDict) and timeout < 1000 do
                Wait(10)
                timeout = timeout + 10
            end
            if HasAnimDictLoaded(animDict) then
                local flag = options.animation.flag or 49
                TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, -1, flag, 0, false, false, false)
            end
        end
    end

    -- Attach prop if provided
    if options.prop then
        local model = type(options.prop.model) == 'string' and joaat(options.prop.model) or options.prop.model
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 1000 do
            Wait(10)
            timeout = timeout + 10
        end
        if HasModelLoaded(model) then
            local ped = PlayerPedId()
            local bone = GetPedBoneIndex(ped, options.prop.bone or 57005)
            local pos = options.prop.pos or vector3(0.0, 0.0, 0.0)
            local rot = options.prop.rot or vector3(0.0, 0.0, 0.0)
            propObj = CreateObject(model, 0.0, 0.0, 0.0, true, true, true)
            AttachEntityToEntity(propObj, ped, bone, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(model)
        end
    end

    -- Send to NUI
    SendNUIMessage({
        action = 'start',
        label = options.label or 'Processing...',
        duration = options.duration,
        icon = options.icon or nil,
    })

    SetNuiFocus(false, false)

    -- Control loop
    CreateThread(function()
        while isActive do
            -- Cancel on death
            if Config.CancelOnDeath and IsEntityDead(PlayerPedId()) then
                Cancel()
                return
            end

            -- Cancel on ragdoll
            if Config.CancelOnRagdoll and IsPedRagdoll(PlayerPedId()) then
                Cancel()
                return
            end

            -- Cancel key (X - control 73)
            if canCancel and IsControlJustPressed(0, 73) then
                Cancel()
                return
            end

            -- Disable controls
            if disableMovement then
                for _, control in ipairs(Config.DisableMovementControls) do
                    DisableControlAction(0, control, true)
                end
            end

            if disableCarMovement and IsPedInAnyVehicle(PlayerPedId(), false) then
                for _, control in ipairs(Config.DisableCarControls) do
                    DisableControlAction(0, control, true)
                end
            end

            if disableCombat then
                for _, control in ipairs(Config.DisableCombatControls) do
                    DisableControlAction(0, control, true)
                end
            end

            Wait(0)
        end
    end)

    return true
end

-- Cancel progress bar
local function Cancel()
    if not isActive then return end

    isActive = false

    SendNUIMessage({ action = 'cancel' })
    Cleanup()

    if onCancel then
        onCancel()
    end

    ResetCallbacks()
end

-- Called from NUI when progress completes
RegisterNUICallback('progressComplete', function(_, cb)
    if not isActive then
        cb('ok')
        return
    end

    isActive = false
    Cleanup()

    if onComplete then
        onComplete()
    end

    ResetCallbacks()
    cb('ok')
end)

-- Cleanup animation and prop
function Cleanup()
    if animDict then
        StopAnimTask(PlayerPedId(), animDict, animName, 1.0)
        RemoveAnimDict(animDict)
        animDict = nil
        animName = nil
    end

    if propObj and DoesEntityExist(propObj) then
        DeleteEntity(propObj)
        propObj = nil
    end
end

-- Reset callback references
function ResetCallbacks()
    onComplete = nil
    onCancel = nil
end

-- Exports
exports('Start', Start)
exports('Cancel', Cancel)
exports('IsActive', function() return isActive end)

-- Event-based API
RegisterNetEvent('sb_progressbar:start', function(options)
    Start(options)
end)

RegisterNetEvent('sb_progressbar:cancel', function()
    Cancel()
end)

-- ============================================================
-- TEST COMMANDS (Remove before production)
-- ============================================================

-- /testprog - Basic progress bar (5 seconds)
RegisterCommand('testprog', function()
    Start({
        label = 'Repairing Vehicle...',
        duration = 5000,
        icon = 'wrench',
        canCancel = true,
        onComplete = function()
            TriggerEvent('SB:Client:Notify', 'Progress completed!', 'success', 3000)
        end,
        onCancel = function()
            TriggerEvent('SB:Client:Notify', 'Progress cancelled!', 'error', 3000)
        end,
    })
end, false)

-- /testprog2 - With animation (8 seconds)
RegisterCommand('testprog2', function()
    Start({
        label = 'Picking Lock...',
        duration = 8000,
        icon = 'lock',
        canCancel = true,
        animation = { dict = 'anim@heists@keycard@', anim = 'idle', flag = 49 },
        onComplete = function()
            TriggerEvent('SB:Client:Notify', 'Lock picked!', 'success', 3000)
        end,
        onCancel = function()
            TriggerEvent('SB:Client:Notify', 'Lock pick failed!', 'error', 3000)
        end,
    })
end, false)

-- /testprog3 - Short fast bar (2 seconds, no cancel)
RegisterCommand('testprog3', function()
    Start({
        label = 'Searching...',
        duration = 2000,
        icon = 'search',
        canCancel = false,
        onComplete = function()
            TriggerEvent('SB:Client:Notify', 'Search complete!', 'success', 3000)
        end,
    })
end, false)
