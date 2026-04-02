-- ============================================================================
-- SB Phone V2 — Client
-- React + Tailwind UI
-- Author: Salah Eddine Boussettah
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- Forward declarations
local ClosePhone

-- State (PhoneState is global so calls.lua can access it)
PhoneState = { isOpen = false, nuiFocused = false, inCall = false, inCallPeek = false, callChannel = 0, callSpeaker = false }
local isPhoneOpen = false
local phoneMetadata = nil   -- { ownerCitizenid, ownerName, phoneNumber }
local phoneProp = nil
local animLoopActive = false
local textFieldFocused = false
local airplaneMode = false

-- ============================================================================
-- NUI FOCUS
-- ============================================================================
function SetPhoneFocus(on)
    PhoneState.nuiFocused = on
    if on then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        textFieldFocused = false
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- Movement controls to KEEP enabled while phone is open
local allowedControls = {
    30, 31, 32, 33, 34, 35, 21, 22, 23, 75, 249,
    172, 173, -- Arrow Up / Arrow Down (open/close phone)
}

local callPeekBlockControls = {
    24, 25, 45, 37, 44, 140, 141, 142, 257, 263, 264, 143, 47,
}

-- Controls to DISABLE during camera mode (weapons + keys we repurpose)
local cameraDisableControls = {
    1, 2,                            -- look X/Y — disabled so we read via GetDisabledControlNormal for scripted cam
    24, 25, 44, 37, 47, 58,         -- attack, aim, cover, select weapon, detonate, throw grenade
    140, 141, 142, 257, 263, 264,    -- melee attacks
    19,                              -- character wheel (ALT) — repurposed for focus toggle
    38,                              -- pickup (E) — repurposed for flash toggle
    172, 173,                        -- Arrow Up/Down — repurposed for flip/unused
}

CreateThread(function()
    while true do
        Wait(0)
        if cameraActive then
            -- Camera active: player walks + looks freely, just disable weapons/repurposed keys + hide HUD
            for i = 1, #cameraDisableControls do
                DisableControlAction(0, cameraDisableControls[i], true)
            end
            HideHudAndRadarThisFrame()
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            HideHudComponentThisFrame(19)
        elseif PhoneState.nuiFocused then
            DisableAllControlActions(0)
            for i = 1, #allowedControls do
                EnableControlAction(0, allowedControls[i], true)
            end
        elseif PhoneState.inCallPeek then
            for _, ctrl in ipairs(callPeekBlockControls) do
                DisableControlAction(0, ctrl, true)
            end
        end
    end
end)

-- Arrow Up keybind: open phone / expand from peek
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 172) and not cameraActive then
            if IsNuiFocused() and not isPhoneOpen and not PhoneState.inCallPeek then
                -- Another UI open
            elseif PhoneState.inCallPeek then
                PhoneState.inCallPeek = false
                SendNUIMessage({ action = 'expandCallPeek' })
                isPhoneOpen = true
                PhoneState.isOpen = true
                if not phoneProp then AttachPhoneProp() end
                SetPhoneFocus(true)
            elseif not isPhoneOpen then
                TriggerServerEvent('sb_phone:server:openByKeybind')
            end
        end

        -- Arrow Down: close phone / minimize to peek during call
        -- Skip entirely when camera is active (camera owns its own close flow)
        if not cameraActive and IsControlJustPressed(0, 173) then
            if isPhoneOpen then
                if PhoneState.inCall then
                    -- Active call: minimize to peek mode (keep call alive)
                    isPhoneOpen = false
                    PhoneState.isOpen = false
                    PhoneState.inCallPeek = true
                    SetPhoneFocus(false)
                    SendNUIMessage({ action = 'phoneMinimized' })
                else
                    -- No call: close the phone entirely
                    ClosePhone()
                end
            end
        end
    end
end)

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    return HasAnimDictLoaded(dict)
end

local function GetAnimSet()
    local ped = PlayerPedId()
    local inVehicle = IsPedInAnyVehicle(ped, false)
    if inVehicle then
        return {
            openDict = Config.Anims.CarOpenDict, openAnim = Config.Anims.CarOpenAnim,
            baseDict = Config.Anims.CarBaseDict, baseAnim = Config.Anims.CarBaseAnim,
            closeDict = Config.Anims.CarCloseDict, closeAnim = Config.Anims.CarCloseAnim,
            callDict = Config.Anims.CarCallDict, callAnim = Config.Anims.CarCallAnim,
        }
    else
        return {
            openDict = Config.Anims.OpenDict, openAnim = Config.Anims.OpenAnim,
            baseDict = Config.Anims.BaseDict, baseAnim = Config.Anims.BaseAnim,
            closeDict = Config.Anims.CloseDict, closeAnim = Config.Anims.CloseAnim,
            callDict = Config.Anims.CallDict, callAnim = Config.Anims.CallAnim,
        }
    end
end

local function PlayPhoneOpenAnim()
    local ped = PlayerPedId()
    local anims = GetAnimSet()
    if LoadAnimDict(anims.openDict) then
        TaskPlayAnim(ped, anims.openDict, anims.openAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
        Wait(800)
    end
    if LoadAnimDict(anims.baseDict) then
        -- Flag 49 = loop (1) + upper body (16) + allow movement (32)
        TaskPlayAnim(ped, anims.baseDict, anims.baseAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
    animLoopActive = true
    CreateThread(function()
        while animLoopActive do
            Wait(500)
            if not animLoopActive then break end
            local p = PlayerPedId()
            local currentAnims = GetAnimSet()
            local targetDict, targetAnim
            if PhoneState.inCall and not PhoneState.callSpeaker then
                targetDict = currentAnims.callDict
                targetAnim = currentAnims.callAnim
            else
                targetDict = currentAnims.baseDict
                targetAnim = currentAnims.baseAnim
            end
            if not IsEntityPlayingAnim(p, targetDict, targetAnim, 3) then
                if LoadAnimDict(targetDict) then
                    TaskPlayAnim(p, targetDict, targetAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
        end
    end)
end

local function PlayPhoneCloseAnim()
    animLoopActive = false
    local ped = PlayerPedId()
    local anims = GetAnimSet()
    if LoadAnimDict(anims.closeDict) then
        TaskPlayAnim(ped, anims.closeDict, anims.closeAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
        Wait(600)
        StopAnimTask(ped, anims.closeDict, anims.closeAnim, 1.0)
    end
end

function SwitchToCallAnim()
    PhoneState.inCall = true
    local ped = PlayerPedId()
    local anims = GetAnimSet()
    if LoadAnimDict(anims.callDict) then
        TaskPlayAnim(ped, anims.callDict, anims.callAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    end
end

function SwitchToBaseAnim()
    PhoneState.inCall = false
    local ped = PlayerPedId()
    local anims = GetAnimSet()
    if LoadAnimDict(anims.baseDict) then
        TaskPlayAnim(ped, anims.baseDict, anims.baseAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    end
end

function SwitchToSpeakerAnim()
    local ped = PlayerPedId()
    local anims = GetAnimSet()
    if LoadAnimDict(anims.baseDict) then
        TaskPlayAnim(ped, anims.baseDict, anims.baseAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    end
end

-- ============================================================================
-- FACE ID
-- ============================================================================

local function IsFaceObstructed()
    local ped = PlayerPedId()
    local maskDrawable = GetPedDrawableVariation(ped, 1)
    if maskDrawable > 0 then return true end
    local hatProp = GetPedPropIndex(ped, 0)
    if hatProp >= 0 then
        local gender = IsPedMale(ped) and 'male' or 'female'
        local helmets = Config.ObstructingHelmets[gender] or {}
        if helmets[hatProp] == false then return false end
        if hatProp > 18 then return true end
    end
    return false
end

-- ============================================================================
-- OPEN / CLOSE
-- ============================================================================

RegisterNetEvent('sb_phone:client:openPhone', function(metadata)
    if isPhoneOpen then return end
    phoneMetadata = metadata
    if not phoneMetadata.ownerCitizenid or not phoneMetadata.phoneNumber then
        exports['sb_notify']:Notify('This phone has no owner data', 'error', 3000)
        return
    end

    local playerData = SB.Functions.GetPlayerData()
    local isOwner = (playerData.citizenid == phoneMetadata.ownerCitizenid)

    SB.Functions.TriggerCallback('sb_phone:server:getPhoneData', function(data)
        if not data then
            exports['sb_notify']:Notify('Phone error', 'error', 3000)
            return
        end

        if data.settings then
            airplaneMode = data.settings.airplaneMode == true
            TriggerServerEvent('sb_phone:server:setAirplaneMode', airplaneMode)
        end

        AttachPhoneProp()
        CreateThread(function() PlayPhoneOpenAnim() end)

        isPhoneOpen = true
        PhoneState.isOpen = true

        SendNUIMessage({
            action = 'open',
            data = data,
            metadata = phoneMetadata,
            isOwner = isOwner,
            ownerName = phoneMetadata.ownerName,
            myNumber = phoneMetadata.phoneNumber,
            config = {
                soundVolume = Config.SoundVolume or 0.3,
                keyboardSounds = Config.KeyboardSounds ~= false
            }
        })

        SetTimeout(300, function()
            if isPhoneOpen then SetPhoneFocus(true) end
        end)
    end, phoneMetadata.ownerCitizenid, phoneMetadata.phoneNumber)
end)

ClosePhone = function()
    if not isPhoneOpen then return end
    isPhoneOpen = false
    PhoneState.isOpen = false
    PhoneState.inCall = false
    SetPhoneFocus(false)
    SendNUIMessage({ action = 'close' })
    CreateThread(function()
        PlayPhoneCloseAnim()
        DetachPhoneProp()
    end)
    phoneMetadata = nil
end

-- ============================================================================
-- PROP
-- ============================================================================

function AttachPhoneProp()
    local ped = PlayerPedId()
    if phoneProp then DeleteObject(phoneProp) phoneProp = nil end
    local model = GetHashKey(Config.Prop)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do Wait(100) timeout = timeout + 1 end
    if HasModelLoaded(model) then
        phoneProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        local boneIndex = GetPedBoneIndex(ped, Config.PropBone)
        AttachEntityToEntity(phoneProp, ped, boneIndex,
            Config.PropOffset.x, Config.PropOffset.y, Config.PropOffset.z,
            Config.PropRotation.x, Config.PropRotation.y, Config.PropRotation.z,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    end
end

function DetachPhoneProp()
    if phoneProp then DeleteObject(phoneProp) phoneProp = nil end
end

function StopPhoneAnim()
    animLoopActive = false
    local ped = PlayerPedId()
    local dicts = { Config.Anims.BaseDict, Config.Anims.CallDict, Config.Anims.CarBaseDict, Config.Anims.CarCallDict }
    for _, dict in ipairs(dicts) do StopAnimTask(ped, dict, '', 1.0) end
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('closePhone', function(_, cb) ClosePhone() cb('ok') end)

RegisterNUICallback('textFieldFocus', function(data, cb)
    textFieldFocused = data.focused == true
    if PhoneState.nuiFocused then
        SetNuiFocusKeepInput(not textFieldFocused)
    end
    cb('ok')
end)

RegisterNUICallback('checkFaceId', function(_, cb)
    cb({ success = not IsFaceObstructed() })
end)

RegisterNUICallback('saveContact', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:saveContact', function(success)
        cb({ success = success })
    end, phoneMetadata.ownerCitizenid, data.name, data.number, data.id or nil)
end)

RegisterNUICallback('deleteContact', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:deleteContact', function(success)
        cb({ success = success })
    end, data.id)
end)

RegisterNUICallback('toggleFavorite', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:toggleFavorite', function(success)
        cb({ success = success })
    end, data.id, data.favorite)
end)

RegisterNUICallback('getContacts', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getContacts', function(contacts)
        cb(contacts or {})
    end, phoneMetadata.ownerCitizenid)
end)

RegisterNUICallback('sendMessage', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:sendMessage', function(success)
        cb({ success = success })
    end, phoneMetadata.phoneNumber, data.receiverNumber, data.text)
end)

RegisterNUICallback('getMessages', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getMessages', function(messages)
        cb(messages or {})
    end, phoneMetadata.phoneNumber)
end)

RegisterNUICallback('markMessagesRead', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:markMessagesRead', function(success)
        cb({ success = success })
    end, phoneMetadata.phoneNumber, data.otherNumber)
end)

RegisterNUICallback('deleteMessage', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:deleteMessage', function(success)
        cb({ success = success })
    end, phoneMetadata.phoneNumber, data.messageId)
end)

RegisterNUICallback('deleteConversation', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:deleteConversation', function(success)
        cb({ success = success })
    end, phoneMetadata.phoneNumber, data.otherNumber)
end)

RegisterNUICallback('typing', function(data, cb)
    if not phoneMetadata then cb('ok') return end
    TriggerServerEvent('sb_phone:server:typing', phoneMetadata.phoneNumber, data.receiverNumber, data.isTyping)
    cb('ok')
end)

RegisterNetEvent('sb_phone:client:messagesRead', function(data)
    SendNUIMessage({ action = 'messagesRead', data = data })
end)

RegisterNetEvent('sb_phone:client:typingIndicator', function(data)
    SendNUIMessage({ action = 'typingIndicator', data = data })
end)

RegisterNUICallback('getCallHistory', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getCallHistory', function(calls)
        cb(calls or {})
    end, phoneMetadata.phoneNumber)
end)

RegisterNUICallback('clearCallHistory', function(_, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:clearCallHistory', function(success)
        cb({ success = success })
    end, phoneMetadata.phoneNumber)
end)

-- Call Controls
RegisterNUICallback('toggleCallMute', function(data, cb)
    NetworkSetVoiceActive(not data.muted)
    cb({ success = true })
end)

RegisterNUICallback('toggleCallSpeaker', function(data, cb)
    PhoneState.callSpeaker = data.speaker
    LocalPlayer.state:set('callSpeaker', data.speaker, true)
    if PhoneState.inCall then
        if data.speaker then SwitchToSpeakerAnim() else SwitchToCallAnim() end
    end
    cb({ success = true })
end)

RegisterNUICallback('toggleAirplaneMode', function(data, cb)
    airplaneMode = data.enabled == true
    TriggerServerEvent('sb_phone:server:setAirplaneMode', airplaneMode)
    cb({ success = true })
end)

RegisterNUICallback('copyToClipboard', function(data, cb)
    if data.text then exports['sb_notify']:Notify('Copied: ' .. data.text, 'success', 2000) end
    cb({ success = true })
end)

RegisterNUICallback('startCall', function(data, cb)
    if not phoneMetadata or PhoneState.inCall or airplaneMode then cb({ success = false }) return end
    PhoneState.inCall = true
    TriggerServerEvent('sb_phone:server:initiateCall', phoneMetadata.phoneNumber, data.number)
    SwitchToCallAnim()
    cb({ success = true })
end)

RegisterNUICallback('endCall', function(_, cb)
    TriggerServerEvent('sb_phone:server:endCall')
    PhoneState.inCall = false
    PhoneState.inCallPeek = false
    PhoneState.callSpeaker = false
    PhoneState.callChannel = 0
    LocalPlayer.state:set('phoneInCall', 0, true)
    LocalPlayer.state:set('callSpeaker', false, true)
    NetworkSetVoiceActive(true)
    if isPhoneOpen then
        SwitchToBaseAnim()
    else
        SetPhoneFocus(false)
        StopPhoneAnim()
        DetachPhoneProp()
    end
    cb({ success = true })
end)

RegisterNUICallback('acceptCall', function(data, cb)
    TriggerServerEvent('sb_phone:server:acceptCall', data.callerSource)
    PhoneState.inCall = true
    if not isPhoneOpen then
        PhoneState.inCallPeek = true
        SetPhoneFocus(false)
    end
    if not phoneProp then AttachPhoneProp() end
    SwitchToCallAnim()
    cb({ success = true })
end)

RegisterNUICallback('declineCall', function(data, cb)
    TriggerServerEvent('sb_phone:server:declineCall', data.callerSource)
    -- Receiver cleanup: release focus + stop anim/prop since we set focus for the peek
    PhoneState.inCall = false
    PhoneState.inCallPeek = false
    if not isPhoneOpen then
        SetPhoneFocus(false)
        StopPhoneAnim()
        DetachPhoneProp()
    end
    cb({ success = true })
end)

RegisterNUICallback('getBankData', function(_, cb)
    if not phoneMetadata then cb({ cash = 0, bank = 0 }) return end
    SB.Functions.TriggerCallback('sb_phone:server:getBankData', function(bankData)
        cb(bankData or { cash = 0, bank = 0 })
    end, phoneMetadata.ownerCitizenid)
end)

RegisterNUICallback('transferMoney', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:transferMoney', function(result)
        if result.success then
            exports['sb_notify']:Notify('Transfer successful!', 'success', 3000)
        else
            exports['sb_notify']:Notify(result.message or 'Transfer failed', 'error', 3000)
        end
        cb(result)
    end, phoneMetadata.ownerCitizenid, data.targetPhone, data.amount)
end)

RegisterNUICallback('getJobData', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getJobData', function(jobData)
        cb(jobData or {})
    end, phoneMetadata.ownerCitizenid)
end)

RegisterNUICallback('saveSettings', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:saveSettings', function(success)
        cb({ success = success })
    end, phoneMetadata.ownerCitizenid, data)
end)

RegisterNUICallback('verifyPasskey', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:verifyPasskey', function(success)
        if not success then
            exports['sb_notify']:Notify('Incorrect PIN', 'error', 3000)
            ClosePhone()
        end
        cb({ success = success })
    end, phoneMetadata.ownerCitizenid, data.pin)
end)

RegisterNUICallback('setPasskey', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:setPasskey', function(success)
        if success then exports['sb_notify']:Notify('Passkey updated', 'success', 3000) end
        cb({ success = success })
    end, phoneMetadata.ownerCitizenid, data.passkey)
end)

-- ============================================================================
-- CAMERA SYSTEM — In-phone camera controls
-- Phone stays docked (visible) with camera controls inside the NUI phone frame.
-- Screen goes transparent so game world shows through the viewfinder area.
-- Player keeps full movement + right-click camera control.
-- Shutter captures a screenshot of the game view.
-- ============================================================================

local cameraActive = false
local cameraSelfie = false
local cameraFlash = 'off'       -- 'off' | 'on' | 'auto'
local cameraLandscape = false
local savedCamMode = nil         -- saved third-person view mode before first-person
local flashThreadActive = false
local cameraFocused = false      -- true = NUI cursor visible (click mode), false = free-look

-- ──────────────────────────────────────────────
-- Upload helpers
-- ──────────────────────────────────────────────

-- Upload config is fetched from server (tokens stored in convars, not source)
local cachedUploadConfig = nil

local function GetUploadConfig(cb)
    if cachedUploadConfig then
        cb(cachedUploadConfig.url, cachedUploadConfig.field, {
            headers = cachedUploadConfig.headers,
            encoding = cachedUploadConfig.encoding,
            quality = cachedUploadConfig.quality
        })
        return
    end
    SB.Functions.TriggerCallback('sb_phone:server:getUploadConfig', function(config)
        if config then
            cachedUploadConfig = config
            cb(config.url, config.field, {
                headers = config.headers,
                encoding = config.encoding,
                quality = config.quality
            })
        else
            cb(nil, nil, nil)
        end
    end)
end

local function ParseUploadResponse(method, data)
    local ok, resp = pcall(json.decode, data)
    if not ok or not resp then return nil end
    if method == 'fivemanager' then
        return (resp.data and resp.data.url) or resp.url or resp.image_url or nil
    elseif method == 'imgur' then
        return resp.data and resp.data.link or nil
    elseif method == 'discord' then
        if resp.attachments and resp.attachments[1] then
            return resp.attachments[1].proxy_url or resp.attachments[1].url
        end
    elseif method == 'custom' then
        return resp.url or resp.image_url or resp.link or nil
    end
    return nil
end

local function RestoreUIAfterCapture()
    SendNUIMessage({ action = 'cameraCapturing', capturing = false })
    if cameraActive then
        -- Restore to current focus state
        if cameraFocused then
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(true)
        else
            SetNuiFocus(false, false)
        end
    elseif isPhoneOpen then
        SetPhoneFocus(true)
    end
end

local function UploadScreenshot(cb)
    local hasScreenshot = GetResourceState('screenshot-basic') == 'started'
    if not hasScreenshot then
        exports['sb_notify']:Notify('screenshot-basic resource not running', 'error', 4000)
        cb(nil)
        return
    end

    GetUploadConfig(function(url, field, options)
        if not url then
            exports['sb_notify']:Notify('Camera not configured. Set upload token in server.cfg.', 'error', 4000)
            cb(nil)
            return
        end

        -- Hide overlay UI temporarily for clean screenshot
        SendNUIMessage({ action = 'cameraCapturing', capturing = true })
        SetNuiFocus(false, false)

        SetTimeout(100, function()
            local ok, err = pcall(function()
                exports['screenshot-basic']:requestScreenshotUpload(url, field, options, function(data)
                    local imageUrl = ParseUploadResponse(Config.CameraUploadMethod or 'fivemanager', data)
                    RestoreUIAfterCapture()
                    cb(imageUrl)
                end)
            end)

            if not ok then
                print('^1[sb_phone]^7 Screenshot upload error: ' .. tostring(err))
                RestoreUIAfterCapture()
                exports['sb_notify']:Notify('Screenshot failed', 'error', 3000)
                cb(nil)
            end
        end)
    end)
end

-- ──────────────────────────────────────────────
-- Camera (CfxTexture streams game render to NUI canvas)
-- Rear camera: scripted cam at eye level with mouse-driven rotation (lb-phone style)
-- Selfie camera: scripted cam facing player's face
-- Phone stays in hand, NUI phone shows camera feed via canvas
-- ──────────────────────────────────────────────

local selfieCam = nil
local selfieCamActive = false

-- Rear camera state
local rearCam = nil
local rearCamActive = false
local rearCamYaw = 0.0
local rearCamPitch = 0.0
local rearCamFov = 50.0

local function CreateRearCam()
    local ped = PlayerPedId()
    rearCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    rearCamYaw = GetEntityHeading(ped)
    rearCamPitch = 0.0
    SetCamFov(rearCam, rearCamFov)
    SetCamActive(rearCam, true)
    RenderScriptCams(true, false, 0, true, false)
    -- Hide own ped so we don't see inside the model
    SetLocalPlayerInvisibleLocally(true)
    rearCamActive = true

    CreateThread(function()
        while rearCamActive do
            Wait(0)
            local p = PlayerPedId()
            -- Read mouse input (controls 1,2 are disabled in main loop, GetDisabledControlNormal reads them)
            if not cameraFocused then
                local inputX = GetDisabledControlNormal(0, 1)
                local inputY = GetDisabledControlNormal(0, 2)
                local sens = (GetProfileSetting(754) + 10) * (rearCamFov / 70.0) / 5.0
                rearCamYaw = rearCamYaw - inputX * sens
                rearCamPitch = math.max(-70.0, math.min(70.0, rearCamPitch - inputY * sens))
            end
            -- Eye-level position: head bone + forward offset in look direction
            local head = GetPedBoneCoords(p, 31086, 0.0, 0.0, 0.0)
            local yawRad = math.rad(rearCamYaw)
            local camX = head.x + (-math.sin(yawRad)) * 0.25
            local camY = head.y + math.cos(yawRad) * 0.25
            local camZ = head.z + 0.08
            SetCamCoord(rearCam, camX, camY, camZ)
            SetCamRot(rearCam, rearCamPitch, 0.0, rearCamYaw, 2)
            -- Rotate ped to match camera (true first-person feel)
            SetEntityHeading(p, rearCamYaw)
            SetGameplayCamRelativeHeading(0)
        end
    end)
end

local function DestroyRearCam()
    rearCamActive = false
    if rearCam then
        RenderScriptCams(false, false, 0, true, false)
        SetCamActive(rearCam, false)
        DestroyCam(rearCam, false)
        rearCam = nil
    end
    SetLocalPlayerInvisibleLocally(false)
end

local function CreateSelfieCam()
    local ped = PlayerPedId()
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0) -- SKEL_Head
    local fwd = GetEntityForwardVector(ped)
    local camPos = head + fwd * 1.2 + vector3(0.0, 0.0, 0.05)
    selfieCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(selfieCam, camPos.x, camPos.y, camPos.z)
    PointCamAtPedBone(selfieCam, ped, 31086, 0.0, 0.0, 0.1, true)
    SetCamActive(selfieCam, true)
    RenderScriptCams(true, true, 500, true, false)
    SetTimecycleModifier('MP_corona_heist_DOF')
    SetTimecycleModifierStrength(0.4)
    selfieCamActive = true
    -- Track player head each frame with smooth lerp for natural follow
    CreateThread(function()
        local smoothPos = nil
        local smoothFactor = 0.12
        while selfieCamActive do
            Wait(0)
            local p = PlayerPedId()
            local h = GetPedBoneCoords(p, 31086, 0.0, 0.0, 0.0)
            local f = GetEntityForwardVector(p)
            local target = h + f * 1.2 + vector3(0.0, 0.0, 0.05)
            if not smoothPos then
                smoothPos = target
            else
                smoothPos = vector3(
                    smoothPos.x + (target.x - smoothPos.x) * smoothFactor,
                    smoothPos.y + (target.y - smoothPos.y) * smoothFactor,
                    smoothPos.z + (target.z - smoothPos.z) * smoothFactor
                )
            end
            SetCamCoord(selfieCam, smoothPos.x, smoothPos.y, smoothPos.z)
            PointCamAtPedBone(selfieCam, p, 31086, 0.0, 0.0, 0.1, true)
        end
    end)
end

local function DestroySelfieCam()
    selfieCamActive = false
    if selfieCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(selfieCam, true)
        selfieCam = nil
        ClearTimecycleModifier()
    end
end

-- ──────────────────────────────────────────────
-- Flash Light System
-- Draws a bright light in front of the player each frame
-- ──────────────────────────────────────────────

local function StartFlashThread()
    if flashThreadActive then return end
    flashThreadActive = true
    CreateThread(function()
        while flashThreadActive and cameraActive do
            Wait(0)
            if cameraFlash == 'on' or cameraFlash == 'auto' then
                local ped = PlayerPedId()
                local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                local fwd = GetEntityForwardVector(ped)
                local lightPos = head + fwd * 2.0
                DrawLightWithRangeAndShadow(
                    lightPos.x, lightPos.y, lightPos.z,
                    255, 255, 255, 15.0, 10.0, 1.0
                )
            else
                Wait(200)
            end
        end
        flashThreadActive = false
    end)
end

-- ──────────────────────────────────────────────
-- Camera Helper Functions
-- ──────────────────────────────────────────────

local function DrawText2D(x, y, scale, text)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 180)
    SetTextDropShadow()
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function DrawCameraHelpText()
    local x = 0.015
    local y = 0.015
    local lh = 0.022
    local s = 0.30
    DrawText2D(x, y,          s, 'Press ~y~ENTER~s~ to take a photo')
    DrawText2D(x, y + lh,     s, 'Press ~y~UP~s~ to flip camera')
    DrawText2D(x, y + lh * 2, s, 'Press ~y~E~s~ to toggle flash')
    DrawText2D(x, y + lh * 3, s, 'Press ~y~LEFT/RIGHT~s~ to change mode')
    DrawText2D(x, y + lh * 4, s, 'Press ~y~ALT~s~ to toggle cursor')
    DrawText2D(x, y + lh * 5, s, 'Press ~y~BACKSPACE~s~ to close camera')
end

local function ToggleCameraFocus()
    cameraFocused = not cameraFocused
    if cameraFocused then
        -- Cursor mode: NUI gets cursor for clicking phone buttons
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        -- Free-look: release NUI, mouse goes to GetDisabledControlNormal for cam rotation
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ action = 'camera:focus', focused = cameraFocused })
end

local function FlipCameraFromKey()
    if not cameraActive then return end
    cameraSelfie = not cameraSelfie
    if cameraSelfie then
        DestroyRearCam()
        CreateSelfieCam()
    else
        DestroySelfieCam()
        CreateRearCam()
    end
    SendNUIMessage({ action = 'camera:keyAction', key = 'flip', selfie = cameraSelfie })
end

local function CycleFlashFromKey()
    if not cameraActive then return end
    if cameraFlash == 'off' then
        cameraFlash = 'on'
    elseif cameraFlash == 'on' then
        cameraFlash = 'auto'
    else
        cameraFlash = 'off'
    end
    if cameraFlash == 'on' or cameraFlash == 'auto' then
        StartFlashThread()
    else
        flashThreadActive = false
    end
    SendNUIMessage({ action = 'camera:setFlash', mode = cameraFlash })
end

local function CloseCameraFromKey()
    if not cameraActive then return end
    -- Trigger the NUI close flow (Camera.tsx calls closeCamera NUI callback)
    SendNUIMessage({ action = 'camera:keyAction', key = 'close' })
end

-- ──────────────────────────────────────────────
-- Camera NUI Callbacks
-- ──────────────────────────────────────────────

RegisterNUICallback('openCamera', function(data, cb)
    if cameraActive then cb({ success = false }) return end

    cameraSelfie = data.selfie == true
    cameraActive = true
    cameraFlash = 'off'
    cameraLandscape = false
    cameraFocused = false

    -- Stop phone animation (frees ped for walking)
    animLoopActive = false
    StopAnimTask(PlayerPedId(), '', '', 1.0)

    -- Both modes use scripted cameras with manual mouse rotation
    if cameraSelfie then
        CreateSelfieCam()
    else
        CreateRearCam()
    end

    -- Hide HUD
    exports['sb_hud']:SetHudVisible(false)

    -- Tell NUI we're in camera mode (Camera.tsx shows canvas with game feed)
    SendNUIMessage({ action = 'cameraMode', active = true })

    -- Free-look: release NUI input so mouse goes to GetDisabledControlNormal
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)

    cb({ success = true })
end)

RegisterNUICallback('toggleCameraSelfie', function(_, cb)
    if not cameraActive then cb({ success = false }) return end

    cameraSelfie = not cameraSelfie
    if cameraSelfie then
        DestroyRearCam()
        CreateSelfieCam()
    else
        DestroySelfieCam()
        CreateRearCam()
    end

    cb({ success = true, selfie = cameraSelfie })
end)

RegisterNUICallback('setCameraZoom', function(_, cb)
    cb({ success = false })
end)

-- toggleFlash NUI callback (still needed for NUI button clicks in focus mode)
RegisterNUICallback('toggleFlash', function(data, cb)
    if not cameraActive then cb({ success = false }) return end
    local mode = data.mode or 'off'
    cameraFlash = mode
    if mode == 'on' or mode == 'auto' then StartFlashThread() else flashThreadActive = false end
    SendNUIMessage({ action = 'camera:setFlash', mode = cameraFlash })
    cb({ success = true, mode = cameraFlash })
end)

RegisterNUICallback('setCameraLandscape', function(data, cb)
    if not cameraActive then cb({ success = false }) return end
    cameraLandscape = data.active == true
    SendNUIMessage({ action = 'camera:setLandscape', active = cameraLandscape })
    cb({ success = true })
end)

RegisterNUICallback('closeCamera', function(_, cb)
    if cameraActive then
        cameraActive = false
        cameraSelfie = false
        cameraFocused = false

        -- Stop flash light
        cameraFlash = 'off'
        flashThreadActive = false

        -- Destroy whichever cam is active
        DestroySelfieCam()
        DestroyRearCam()

        -- Reset landscape
        cameraLandscape = false

        -- Restore HUD
        exports['sb_hud']:SetHudVisible(true)

        -- Navigate home, disable camera mode
        SendNUIMessage({ action = 'goHome' })
        SendNUIMessage({ action = 'cameraMode', active = false })
        Wait(200)

        -- Restore phone animation + focus
        if isPhoneOpen then
            CreateThread(function() PlayPhoneOpenAnim() end)
            SetPhoneFocus(true)
        end
    end
    cb({ success = true })
end)

RegisterNUICallback('capturePhoto', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end

    local saveToGallery = data.saveToGallery ~= false

    UploadScreenshot(function(imageUrl)
        if imageUrl then
            if saveToGallery then
                SB.Functions.TriggerCallback('sb_phone:server:savePhoto', function(success)
                    -- saved to gallery
                end, phoneMetadata.ownerCitizenid, imageUrl)
            end
            cb({ success = true, url = imageUrl })
        else
            cb({ success = false })
        end
    end)
end)

-- Quick capture for Instapic (no camera view, just screenshot current game view)
RegisterNUICallback('quickCapture', function(_, cb)
    if not phoneMetadata then cb({ success = false }) return end

    UploadScreenshot(function(imageUrl)
        if imageUrl then
            SB.Functions.TriggerCallback('sb_phone:server:savePhoto', function(success)
                -- saved
            end, phoneMetadata.ownerCitizenid, imageUrl)
            cb({ success = true, url = imageUrl })
        else
            cb({ success = false })
        end
    end)
end)

RegisterNUICallback('deleteGalleryPhoto', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:deletePhoto', function(success)
        cb({ success = success })
    end, phoneMetadata.ownerCitizenid, data.photoId)
end)

RegisterNUICallback('getGalleryPhotos', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getGallery', function(photos)
        cb(photos or {})
    end, phoneMetadata.ownerCitizenid)
end)

-- ============================================================================
-- CAMERA KEYBOARD CONTROLS
-- Keyboard-driven camera (like lb-phone): Enter=photo, Up=flip, E=flash,
-- Left/Right=mode, ALT=toggle cursor/free-look, Backspace=close
-- ============================================================================

CreateThread(function()
    while true do
        if not cameraActive then
            Wait(500)
        else
            Wait(0)

            -- ALT (19) — toggle cursor / free-look
            if IsDisabledControlJustPressed(0, 19) then
                ToggleCameraFocus()
            end

            -- ENTER (191) — take photo / toggle video
            if IsDisabledControlJustPressed(0, 191) then
                SendNUIMessage({ action = 'camera:keyAction', key = 'takePhoto' })
            end

            -- Arrow Up (172) — flip camera
            if IsDisabledControlJustPressed(0, 172) then
                FlipCameraFromKey()
            end

            -- E (38) — cycle flash
            if IsDisabledControlJustPressed(0, 38) then
                CycleFlashFromKey()
            end

            -- Arrow Left (174) — mode left
            if IsDisabledControlJustPressed(0, 174) then
                SendNUIMessage({ action = 'camera:keyAction', key = 'modeLeft' })
            end

            -- Arrow Right (175) — mode right
            if IsDisabledControlJustPressed(0, 175) then
                SendNUIMessage({ action = 'camera:keyAction', key = 'modeRight' })
            end

            -- Backspace (177) — close camera
            if IsDisabledControlJustPressed(0, 177) then
                CloseCameraFromKey()
            end
        end
    end
end)

-- ============================================================================
-- INSTAPIC NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('getInstapicProfile', function(data, cb)
    if not phoneMetadata then cb(nil) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicProfile', function(profile) cb(profile) end, data.citizenid or nil)
end)

RegisterNUICallback('updateInstapicBio', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:updateInstapicBio', function(success)
        cb({ success = success })
    end, data.bio)
end)

RegisterNUICallback('searchInstapicUsers', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:searchInstapicUsers', function(results) cb(results or {}) end, data.query)
end)

RegisterNUICallback('getInstapicFeed', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicFeed', function(posts) cb(posts or {}) end)
end)

RegisterNUICallback('getInstapicExplore', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicExplore', function(posts) cb(posts or {}) end)
end)

RegisterNUICallback('createInstapicPost', function(data, cb)
    if not phoneMetadata then cb(nil) return end
    SB.Functions.TriggerCallback('sb_phone:server:createInstapicPost', function(post) cb(post) end,
        data.caption, data.imageUrl, data.location)
end)

RegisterNUICallback('deleteInstapicPost', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:deleteInstapicPost', function(success) cb({ success = success }) end, data.postId)
end)

RegisterNUICallback('getInstapicUserPosts', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicUserPosts', function(posts) cb(posts or {}) end, data.citizenid)
end)

RegisterNUICallback('toggleInstapicLike', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:toggleInstapicLike', function(result) cb(result or {}) end, data.postId)
end)

RegisterNUICallback('getInstapicComments', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicComments', function(comments) cb(comments or {}) end, data.postId)
end)

RegisterNUICallback('addInstapicComment', function(data, cb)
    if not phoneMetadata then cb(nil) return end
    SB.Functions.TriggerCallback('sb_phone:server:addInstapicComment', function(comment) cb(comment) end, data.postId, data.content)
end)

RegisterNUICallback('deleteInstapicComment', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:deleteInstapicComment', function(success) cb({ success = success }) end, data.commentId)
end)

RegisterNUICallback('toggleInstapicFollow', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:toggleInstapicFollow', function(result) cb(result or {}) end, data.citizenid)
end)

RegisterNUICallback('getInstapicFollowers', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicFollowers', function(followers) cb(followers or {}) end, data.citizenid)
end)

RegisterNUICallback('getInstapicFollowing', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicFollowing', function(following) cb(following or {}) end, data.citizenid)
end)

RegisterNUICallback('addInstapicStory', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:addInstapicStory', function(success) cb({ success = success }) end, data.color, data.imageUrl)
end)

RegisterNUICallback('getInstapicStories', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicStories', function(stories) cb(stories or {}) end)
end)

RegisterNUICallback('viewInstapicStory', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:viewInstapicStory', function(success) cb({ success = success }) end, data.storyId)
end)

RegisterNUICallback('getInstapicDMList', function(_, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicDMList', function(convos) cb(convos or {}) end)
end)

RegisterNUICallback('getInstapicDMChat', function(data, cb)
    if not phoneMetadata then cb({}) return end
    SB.Functions.TriggerCallback('sb_phone:server:getInstapicDMChat', function(messages) cb(messages or {}) end, data.citizenid)
end)

RegisterNUICallback('sendInstapicDM', function(data, cb)
    if not phoneMetadata then cb(nil) return end
    SB.Functions.TriggerCallback('sb_phone:server:sendInstapicDM', function(dm) cb(dm) end, data.citizenid, data.message)
end)

RegisterNUICallback('markInstapicDMsRead', function(data, cb)
    if not phoneMetadata then cb({ success = false }) return end
    SB.Functions.TriggerCallback('sb_phone:server:markInstapicDMsRead', function(success) cb({ success = success }) end, data.citizenid)
end)

-- Real-time DM push
RegisterNetEvent('sb_phone:client:instapicDM', function(data)
    SendNUIMessage({ action = 'instapicDM', data = data })
end)

RegisterNUICallback('refreshData', function(_, cb)
    if not phoneMetadata then cb(nil) return end
    SB.Functions.TriggerCallback('sb_phone:server:getPhoneData', function(data) cb(data) end,
        phoneMetadata.ownerCitizenid, phoneMetadata.phoneNumber)
end)

-- ============================================================================
-- INCOMING NOTIFICATIONS
-- ============================================================================

RegisterNetEvent('sb_phone:client:newMessage', function(msgData)
    SendNUIMessage({ action = 'newMessage', data = msgData })
end)

-- ============================================================================
-- PEEK CALLBACKS
-- ============================================================================

RegisterNUICallback('peekClosed', function(_, cb) PhoneState.inCallPeek = false SetPhoneFocus(false) cb('ok') end)

RegisterNUICallback('phoneMinimized', function(_, cb)
    isPhoneOpen = false
    PhoneState.isOpen = false
    PhoneState.inCallPeek = true
    SetPhoneFocus(false)
    cb('ok')
end)

RegisterNUICallback('phoneExpanded', function(_, cb)
    isPhoneOpen = true
    PhoneState.isOpen = true
    PhoneState.inCallPeek = false
    SetPhoneFocus(true)
    if not phoneProp then AttachPhoneProp() end
    cb('ok')
end)

-- ============================================================================
-- CALL ANIMATION EVENTS
-- ============================================================================

RegisterNetEvent('sb_phone:client:callAccepted', function()
    PhoneState.inCall = true
    PhoneState.callSpeaker = false
    if not phoneProp then AttachPhoneProp() end
    SwitchToCallAnim()
end)

RegisterNetEvent('sb_phone:client:callEnded', function()
    PhoneState.inCall = false
    PhoneState.inCallPeek = false
    PhoneState.callSpeaker = false
    PhoneState.callChannel = 0
    LocalPlayer.state:set('phoneInCall', 0, true)
    LocalPlayer.state:set('callSpeaker', false, true)
    NetworkSetVoiceActive(true)
    if isPhoneOpen then SwitchToBaseAnim() else StopPhoneAnim() DetachPhoneProp() end
end)

-- ============================================================================
-- DEATH CLEANUP — stop phone anim/prop when player dies
-- ============================================================================

CreateThread(function()
    local wasDead = false
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local isDead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
        if isDead and not wasDead then
            -- Player just died: clean up phone state
            if isPhoneOpen then
                ClosePhone()
            end
            if PhoneState.inCallPeek then
                PhoneState.inCallPeek = false
                SetPhoneFocus(false)
            end
            animLoopActive = false
            DetachPhoneProp()
            if cameraActive then
                cameraActive = false
                cameraSelfie = false
                cameraFocused = false
                cameraFlash = 'off'
                flashThreadActive = false
                cameraLandscape = false
                DestroySelfieCam()
                DestroyRearCam()
                SetNuiFocus(false, false)
                exports['sb_hud']:SetHudVisible(true)
                SendNUIMessage({ action = 'cameraMode', active = false })
            end
        end
        wasDead = isDead
    end
end)

-- ============================================================================
-- RESOURCE CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if cameraActive then
        cameraActive = false
        cameraFocused = false
        cameraFlash = 'off'
        flashThreadActive = false
        cameraLandscape = false
        DestroySelfieCam()
        DestroyRearCam()
        SetNuiFocus(false, false)
        exports['sb_hud']:SetHudVisible(true)
    end
    if isPhoneOpen then ClosePhone() end
    animLoopActive = false
    DetachPhoneProp()
    LocalPlayer.state:set('phoneInCall', 0, true)
    LocalPlayer.state:set('callSpeaker', false, true)
end)

print('^2[sb_phone]^7 Client loaded')
