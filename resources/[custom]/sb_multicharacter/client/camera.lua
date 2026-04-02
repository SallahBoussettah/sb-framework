--[[
    Everyday Chaos RP - Multicharacter Camera System
    Author: Salah Eddine Boussettah

    Controls:
    - Right-click drag / Arrow LEFT/RIGHT = Rotate CHARACTER
    - Mouse scroll wheel = Zoom in/out
    - Arrow UP/DOWN = Move camera up/down
]]

-- ============================================================================
-- CAMERA VARIABLES
-- ============================================================================
local currentCam = nil
local currentFocus = 'fullBody'
local cameraZoom = 1.0              -- Zoom multiplier (0.5 = close, 1.0 = normal, 1.5 = far)
local cameraVerticalOffset = 0.0    -- Vertical pan offset
local pedRotation = 0.0             -- Character rotation offset
local basePedHeading = 180.0        -- Original ped heading

-- Zoom limits
local MIN_ZOOM = 0.4
local MAX_ZOOM = 1.8
local ZOOM_SPEED = 0.1

-- Vertical offset limits
local MIN_VERTICAL = -0.5
local MAX_VERTICAL = 0.8
local VERTICAL_SPEED = 0.05

-- Rotation speed
local ROTATION_SPEED = 3.0

-- ============================================================================
-- SETUP CHARACTER CAMERA
-- ============================================================================
function SetupCharacterCamera()
    local pedPos = Config.PreviewLocation.pedCoords
    basePedHeading = pedPos.w or 180.0

    -- Reset camera values
    cameraZoom = 1.0
    cameraVerticalOffset = 0.0
    pedRotation = 0.0
    currentFocus = 'fullBody'

    -- Create camera
    currentCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    -- Position camera
    UpdateCameraPosition()

    -- Activate camera
    SetCamActive(currentCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Set focus for better rendering
    SetFocusPosAndVel(pedPos.x, pedPos.y, pedPos.z, 0.0, 0.0, 0.0)
end

-- ============================================================================
-- DESTROY CHARACTER CAMERA
-- ============================================================================
function DestroyCharacterCamera()
    if currentCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentCam, false)
        currentCam = nil
    end
    ClearFocus()
end

-- ============================================================================
-- UPDATE CAMERA POSITION
-- ============================================================================
function UpdateCameraPosition()
    if not currentCam then return end

    local focusData = Config.CameraPositions[currentFocus]
    if not focusData then return end

    local pedPos = Config.PreviewLocation.pedCoords
    local angleRad = math.rad(basePedHeading)

    -- Calculate camera distance with zoom
    local distance = focusData.offset.y * cameraZoom

    -- Camera position (always in front of ped's base position)
    local camX = pedPos.x - (distance * math.sin(angleRad))
    local camY = pedPos.y + (distance * math.cos(angleRad))
    local camZ = pedPos.z + focusData.offset.z + cameraVerticalOffset

    -- Point at ped with vertical offset
    local pointZ = pedPos.z + (focusData.pointOffset and focusData.pointOffset.z or 0.0) + cameraVerticalOffset

    SetCamCoord(currentCam, camX, camY, camZ)
    PointCamAtCoord(currentCam, pedPos.x, pedPos.y, pointZ)
    SetCamFov(currentCam, focusData.fov)
end

-- ============================================================================
-- SET CAMERA FOCUS (fullBody, face, torso, legs, feet)
-- ============================================================================
function SetCameraFocus(focus)
    if not currentCam then return end

    local focusData = Config.CameraPositions[focus]
    if not focusData then return end

    currentFocus = focus

    -- Reset vertical offset when changing focus
    cameraVerticalOffset = 0.0

    -- Smooth transition using interpolation
    local pedPos = Config.PreviewLocation.pedCoords
    local angleRad = math.rad(basePedHeading)
    local distance = focusData.offset.y * cameraZoom

    local camX = pedPos.x - (distance * math.sin(angleRad))
    local camY = pedPos.y + (distance * math.cos(angleRad))
    local camZ = pedPos.z + focusData.offset.z
    local pointZ = pedPos.z + (focusData.pointOffset and focusData.pointOffset.z or 0.0)

    local targetCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(targetCam, camX, camY, camZ)
    PointCamAtCoord(targetCam, pedPos.x, pedPos.y, pointZ)
    SetCamFov(targetCam, focusData.fov)

    SetCamActiveWithInterp(targetCam, currentCam, Config.CameraTransitionTime, 1, 1)

    CreateThread(function()
        Wait(Config.CameraTransitionTime)
        if currentCam then
            DestroyCam(currentCam, false)
        end
        currentCam = targetCam
    end)
end

-- ============================================================================
-- ROTATE CHARACTER (Not camera!)
-- ============================================================================
function RotateCharacter(delta)
    if not previewPed or not DoesEntityExist(previewPed) then return end

    pedRotation = pedRotation + (delta * ROTATION_SPEED)

    -- Wrap angle
    if pedRotation > 360.0 then
        pedRotation = pedRotation - 360.0
    elseif pedRotation < 0.0 then
        pedRotation = pedRotation + 360.0
    end

    -- Apply rotation to ped
    SetEntityHeading(previewPed, basePedHeading + pedRotation)
end

-- ============================================================================
-- ZOOM CAMERA
-- ============================================================================
function ZoomCamera(direction)
    if not currentCam then return end

    -- direction: -1 = zoom in, 1 = zoom out
    cameraZoom = cameraZoom + (direction * ZOOM_SPEED)

    -- Clamp zoom
    if cameraZoom < MIN_ZOOM then
        cameraZoom = MIN_ZOOM
    elseif cameraZoom > MAX_ZOOM then
        cameraZoom = MAX_ZOOM
    end

    UpdateCameraPosition()
end

-- ============================================================================
-- MOVE CAMERA VERTICAL (Up/Down)
-- ============================================================================
function MoveCameraVertical(direction)
    if not currentCam then return end

    -- direction: 1 = up, -1 = down
    cameraVerticalOffset = cameraVerticalOffset + (direction * VERTICAL_SPEED)

    -- Clamp vertical offset
    if cameraVerticalOffset < MIN_VERTICAL then
        cameraVerticalOffset = MIN_VERTICAL
    elseif cameraVerticalOffset > MAX_VERTICAL then
        cameraVerticalOffset = MAX_VERTICAL
    end

    UpdateCameraPosition()
end

-- ============================================================================
-- RESET CAMERA
-- ============================================================================
function ResetCamera()
    cameraZoom = 1.0
    cameraVerticalOffset = 0.0
    pedRotation = 0.0

    if previewPed and DoesEntityExist(previewPed) then
        SetEntityHeading(previewPed, basePedHeading)
    end

    UpdateCameraPosition()
end

-- ============================================================================
-- GET CURRENT CAMERA FOCUS
-- ============================================================================
function GetCurrentCameraFocus()
    return currentFocus
end

-- ============================================================================
-- KEYBOARD INPUT THREAD (Arrow keys)
-- ============================================================================
CreateThread(function()
    while true do
        Wait(0)

        if (isInCharacterSelect or isCreatingCharacter) and currentCam then
            -- Arrow LEFT = Rotate character left
            if IsDisabledControlPressed(0, 174) then -- LEFT
                RotateCharacter(-1)
            end

            -- Arrow RIGHT = Rotate character right
            if IsDisabledControlPressed(0, 175) then -- RIGHT
                RotateCharacter(1)
            end

            -- Arrow UP = Move camera up
            if IsDisabledControlPressed(0, 172) then -- UP
                MoveCameraVertical(1)
            end

            -- Arrow DOWN = Move camera down
            if IsDisabledControlPressed(0, 173) then -- DOWN
                MoveCameraVertical(-1)
            end
        end
    end
end)
