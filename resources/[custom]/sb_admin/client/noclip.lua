-- sb_admin/client/noclip.lua
-- NoClip / Free Camera Flight System

NoclipActive = false
local noclipSpeed = Config.NoClipBaseSpeed
local noclipCam = nil

function ToggleNoclip()
    NoclipActive = not NoclipActive

    local ped = PlayerPedId()

    if NoclipActive then
        -- Store original position
        local coords = GetEntityCoords(ped)

        -- Create camera
        noclipCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(noclipCam, coords.x, coords.y, coords.z)

        local rot = GetEntityRotation(ped, 2)
        SetCamRot(noclipCam, rot.x, rot.y, rot.z, 2)

        RenderScriptCams(true, true, 500, true, true)

        -- Make player invisible and frozen
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)

        SendNUIMessage({ action = 'notify', text = 'NoClip: ON', type = 'success' })
    else
        -- Restore player
        local camCoord = GetCamCoord(noclipCam)

        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(noclipCam, false)
        noclipCam = nil

        SetEntityCoords(ped, camCoord.x, camCoord.y, camCoord.z, false, false, false, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)

        if not GodmodeActive then
            SetEntityInvincible(ped, false)
        end

        -- Find ground
        local found, groundZ = GetGroundZFor_3dCoord(camCoord.x, camCoord.y, camCoord.z + 1.0, false)
        if found then
            SetEntityCoords(ped, camCoord.x, camCoord.y, groundZ, false, false, false, false)
        end

        SendNUIMessage({ action = 'notify', text = 'NoClip: OFF', type = 'info' })
    end
end

-- NoClip movement loop
CreateThread(function()
    while true do
        if NoclipActive and noclipCam then
            local rot = GetCamRot(noclipCam, 2)
            local rightVector = vector3(
                math.cos(math.rad(rot.z)),
                math.sin(math.rad(rot.z)),
                0.0
            )

            -- Calculate forward direction
            local rX = rot.x * math.pi / 180.0
            local rZ = rot.z * math.pi / 180.0
            local fwdX = -math.sin(rZ) * math.abs(math.cos(rX))
            local fwdY = math.cos(rZ) * math.abs(math.cos(rX))
            local fwdZ = math.sin(rX)

            local camCoord = GetCamCoord(noclipCam)
            local speed = noclipSpeed

            -- Speed modifiers
            if IsControlPressed(0, 209) then -- Left Shift
                speed = speed * Config.NoClipFastMultiplier
            end
            if IsControlPressed(0, 36) then -- Left Ctrl
                speed = speed * Config.NoClipSlowMultiplier
            end

            -- Scroll to adjust base speed
            if IsControlPressed(0, 241) then -- Scroll Up
                noclipSpeed = math.min(noclipSpeed + 0.1, 10.0)
            end
            if IsControlPressed(0, 242) then -- Scroll Down
                noclipSpeed = math.max(noclipSpeed - 0.1, 0.1)
            end

            local newX, newY, newZ = camCoord.x, camCoord.y, camCoord.z

            -- Movement (WASD)
            if IsControlPressed(0, 32) then -- W
                newX = newX + fwdX * speed
                newY = newY + fwdY * speed
                newZ = newZ + fwdZ * speed
            end
            if IsControlPressed(0, 33) then -- S
                newX = newX - fwdX * speed
                newY = newY - fwdY * speed
                newZ = newZ - fwdZ * speed
            end
            if IsControlPressed(0, 34) then -- A
                newX = newX - rightVector.x * speed
                newY = newY - rightVector.y * speed
            end
            if IsControlPressed(0, 35) then -- D
                newX = newX + rightVector.x * speed
                newY = newY + rightVector.y * speed
            end

            -- Vertical
            if IsControlPressed(0, 44) then -- Q (up)
                newZ = newZ + speed * 0.5
            end
            if IsControlPressed(0, 20) then -- Z (down)
                newZ = newZ - speed * 0.5
            end

            SetCamCoord(noclipCam, newX, newY, newZ)

            -- Mouse look
            local mouseX = GetDisabledControlNormal(0, 1) * 4.0
            local mouseY = GetDisabledControlNormal(0, 2) * 4.0

            local newRotX = rot.x - mouseY
            local newRotZ = rot.z - mouseX

            -- Clamp vertical rotation
            newRotX = math.max(-89.0, math.min(89.0, newRotX))

            SetCamRot(noclipCam, newRotX, 0.0, newRotZ, 2)

            -- Move ped to camera position (for streaming)
            SetEntityCoords(PlayerPedId(), newX, newY, newZ, false, false, false, false)

            -- Disable controls that interfere
            DisableControlAction(0, 1, true)   -- Mouse X
            DisableControlAction(0, 2, true)   -- Mouse Y
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 36, true)  -- Ctrl
            DisableControlAction(0, 44, true)  -- Q
            DisableControlAction(0, 20, true)  -- Z

            Wait(0)
        else
            Wait(500)
        end
    end
end)
