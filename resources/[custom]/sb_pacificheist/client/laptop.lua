-- ============================================================================
-- LAPTOP HACKING MINIGAME (Brute Force Scaleform)
-- Using correct FiveM scaleform natives
-- ============================================================================

local targetWords = {"SENTINEL", "OVERRIDE", "FIREWALL", "BACKDOOR", "EXPLOIT", "DECRYPT"}
local cachedScaleform = nil
local lives = 3
local returnValue = nil
local hackingActive = false
local inProgram = false
local isLocked = false

-- Global variables accessed by main.lua
hackFinished = false
hackStatus = false

-- Helper to add scaleform label parameter
local function ScaleformLabel(label)
    BeginTextCommandScaleformString(label)
    EndTextCommandScaleformString()
end

-- Helper to add string parameter
local function ScaleformString(str)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandScaleformString()
end

-- Initialize the brute force scaleform
local function InitializeBruteForce(scaleformName)
    print('[sb_pacificheist] InitializeBruteForce called with: ' .. tostring(scaleformName))

    local sf = RequestScaleformMovieInteractive(scaleformName)
    print('[sb_pacificheist] RequestScaleformMovieInteractive returned: ' .. tostring(sf))

    local timeout = 0
    while not HasScaleformMovieLoaded(sf) do
        Wait(0)
        timeout = timeout + 1
        if timeout > 1000 then
            print('[sb_pacificheist] ERROR: Scaleform failed to load after 1000 iterations!')
            return nil
        end
    end

    print('[sb_pacificheist] Scaleform loaded successfully, handle: ' .. tostring(sf))

    -- Load hack text bank
    local gxt = "hack"
    local slot = 0
    while HasAdditionalTextLoaded(slot) and not HasThisAdditionalTextLoaded(gxt, slot) do
        Wait(0)
        slot = slot + 1
        if slot > 10 then break end
    end
    if not HasThisAdditionalTextLoaded(gxt, slot) then
        ClearAdditionalText(slot, true)
        RequestAdditionalText(gxt, slot)
        timeout = 0
        while not HasThisAdditionalTextLoaded(gxt, slot) do
            Wait(0)
            timeout = timeout + 1
            if timeout > 500 then break end
        end
    end

    -- Set up scaleform labels using modern natives
    BeginScaleformMovieMethod(sf, "SET_LABELS")
    ScaleformString("Local (C:)")
    ScaleformString("Global Network")
    ScaleformString("External Device (J:)")
    ScaleformString("HackConnect.exe")
    ScaleformString("BruteForce.exe")
    ScaleformLabel("H_ICON_6")
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(sf, "SET_BACKGROUND")
    ScaleformMovieMethodAddParamInt(1)
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(sf, "ADD_PROGRAM")
    ScaleformMovieMethodAddParamFloat(1.0)
    ScaleformMovieMethodAddParamFloat(4.0)
    ScaleformString("My Computer")
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(sf, "ADD_PROGRAM")
    ScaleformMovieMethodAddParamFloat(6.0)
    ScaleformMovieMethodAddParamFloat(6.0)
    ScaleformString("Power Off")
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(sf, "SET_LIVES")
    ScaleformMovieMethodAddParamInt(lives)
    ScaleformMovieMethodAddParamInt(5)
    EndScaleformMovieMethod()

    -- Set column speeds (randomized for challenge)
    for i = 0, 7 do
        BeginScaleformMovieMethod(sf, "SET_COLUMN_SPEED")
        ScaleformMovieMethodAddParamInt(i)
        ScaleformMovieMethodAddParamInt(math.random(200, 260))
        EndScaleformMovieMethod()
    end

    return sf
end

-- Start the hacking minigame
function StartComputer()
    hackFinished = false
    hackStatus = false
    lives = 3
    inProgram = false
    isLocked = false
    returnValue = nil

    print('[sb_pacificheist] ========== LAPTOP DEBUG ==========')
    print('[sb_pacificheist] StartComputer() called')
    print('[sb_pacificheist] hackingActive before: ' .. tostring(hackingActive))

    CreateThread(function()
        print('[sb_pacificheist] Thread started, requesting scaleform...')
        cachedScaleform = InitializeBruteForce("HACKING_PC")

        print('[sb_pacificheist] Scaleform result: ' .. tostring(cachedScaleform))

        if not cachedScaleform then
            print('[sb_pacificheist] ERROR: Failed to initialize scaleform!')
            hackFinished = true
            hackStatus = false
            return
        end

        print('[sb_pacificheist] Scaleform loaded successfully, setting hackingActive = true')
        hackingActive = true

        -- Show instructions
        print('[sb_pacificheist] Showing notifications...')
        exports['sb_notify']:Notify('HACKING: Click on "BruteForce.exe" to start', 'primary', 5000)
        Wait(500)
        exports['sb_notify']:Notify('Match the letters when they align!', 'info', 5000)
        print('[sb_pacificheist] Entering main hacking loop...')

        local frameCount = 0
        while hackingActive do
            Wait(0)
            frameCount = frameCount + 1
            if frameCount == 1 then
                print('[sb_pacificheist] Hacking loop running, drawing scaleform...')
            end
            if frameCount % 500 == 0 then
                print('[sb_pacificheist] Hacking loop frame: ' .. frameCount)
            end

            -- Show cursor during hacking
            SetMouseCursorActiveThisFrame()
            SetMouseCursorSprite(1)
            DisableAllControlActions(0)

            -- Enable mouse controls for cursor
            EnableControlAction(0, 1, true)   -- Mouse X
            EnableControlAction(0, 2, true)   -- Mouse Y
            EnableControlAction(0, 239, true) -- Cursor X
            EnableControlAction(0, 240, true) -- Cursor Y
            EnableControlAction(0, 237, true) -- Cursor scroll up
            EnableControlAction(0, 238, true) -- Cursor scroll down
            EnableControlAction(0, 24, true)  -- Left click (attack)
            EnableControlAction(0, 25, true)  -- Right click (aim)

            -- Draw scaleform fullscreen
            DrawScaleformMovieFullscreen(cachedScaleform, 255, 255, 255, 255, 0)

            -- Handle mouse cursor position
            local cursorX = GetControlNormal(0, 239)
            local cursorY = GetControlNormal(0, 240)

            BeginScaleformMovieMethod(cachedScaleform, "SET_CURSOR")
            ScaleformMovieMethodAddParamFloat(cursorX)
            ScaleformMovieMethodAddParamFloat(cursorY)
            EndScaleformMovieMethod()

            -- Handle clicks
            if IsControlJustPressed(0, 24) and not isLocked then
                BeginScaleformMovieMethod(cachedScaleform, "SET_INPUT_EVENT_SELECT")
                returnValue = EndScaleformMovieMethodReturnValue()
                PlaySoundFrontend(-1, "HACKING_CLICK", "", true)
            elseif IsControlJustPressed(0, 25) and not inProgram and not isLocked then
                BeginScaleformMovieMethod(cachedScaleform, "SET_INPUT_EVENT_BACK")
                EndScaleformMovieMethod()
                PlaySoundFrontend(-1, "HACKING_CLICK", "", true)
            end
        end
    end)
end

-- Process return values from scaleform
CreateThread(function()
    while true do
        local sleep = 1000

        if cachedScaleform and HasScaleformMovieLoaded(cachedScaleform) and hackingActive then
            sleep = 0

            if returnValue and IsScaleformMovieMethodReturnValueReady(returnValue) then
                local programID = GetScaleformMovieMethodReturnValueInt(returnValue)

                -- 83 = Opened BruteForce program
                if programID == 83 and not inProgram then
                    lives = 3
                    BeginScaleformMovieMethod(cachedScaleform, "SET_LIVES")
                    ScaleformMovieMethodAddParamInt(lives)
                    ScaleformMovieMethodAddParamInt(5)
                    EndScaleformMovieMethod()

                    BeginScaleformMovieMethod(cachedScaleform, "OPEN_APP")
                    ScaleformMovieMethodAddParamFloat(1.0)
                    EndScaleformMovieMethod()

                    BeginScaleformMovieMethod(cachedScaleform, "SET_ROULETTE_WORD")
                    ScaleformString(targetWords[math.random(#targetWords)])
                    EndScaleformMovieMethod()

                    inProgram = true
                    print('[sb_pacificheist] BruteForce program opened')

                -- 87 = Wrong match (lost a life)
                elseif inProgram and programID == 87 then
                    lives = lives - 1
                    BeginScaleformMovieMethod(cachedScaleform, "SET_LIVES")
                    ScaleformMovieMethodAddParamInt(lives)
                    ScaleformMovieMethodAddParamInt(5)
                    EndScaleformMovieMethod()
                    PlaySoundFrontend(-1, "HACKING_CLICK_BAD", "", false)

                -- 92 = Correct match
                elseif inProgram and programID == 92 then
                    PlaySoundFrontend(-1, "HACKING_CLICK_GOOD", "", false)

                -- 86 = Won
                elseif inProgram and programID == 86 then
                    isLocked = true
                    PlaySoundFrontend(-1, "HACKING_SUCCESS", "", true)

                    BeginScaleformMovieMethod(cachedScaleform, "SET_ROULETTE_OUTCOME")
                    ScaleformMovieMethodAddParamBool(true)
                    ScaleformLabel("WINBRUTE")
                    EndScaleformMovieMethod()

                    Wait(3000)
                    BeginScaleformMovieMethod(cachedScaleform, "CLOSE_APP")
                    EndScaleformMovieMethod()
                    SetScaleformMovieAsNoLongerNeeded(cachedScaleform)

                    hackingActive = false
                    inProgram = false
                    isLocked = false
                    HackingCompleted(true)

                -- 6 = Power Off clicked
                elseif programID == 6 then
                    hackingActive = false
                    SetScaleformMovieAsNoLongerNeeded(cachedScaleform)
                    HackingCompleted(false)
                end

                -- Reset return value after processing
                returnValue = nil

                -- Check for game over
                if inProgram then
                    BeginScaleformMovieMethod(cachedScaleform, "SHOW_LIVES")
                    ScaleformMovieMethodAddParamBool(true)
                    EndScaleformMovieMethod()

                    if lives <= 0 then
                        isLocked = true
                        PlaySoundFrontend(-1, "HACKING_FAILURE", "", true)

                        BeginScaleformMovieMethod(cachedScaleform, "SET_ROULETTE_OUTCOME")
                        ScaleformMovieMethodAddParamBool(false)
                        ScaleformLabel("LOSEBRUTE")
                        EndScaleformMovieMethod()

                        Wait(3000)
                        BeginScaleformMovieMethod(cachedScaleform, "CLOSE_APP")
                        EndScaleformMovieMethod()
                        SetScaleformMovieAsNoLongerNeeded(cachedScaleform)

                        inProgram = false
                        isLocked = false
                        hackingActive = false
                        HackingCompleted(false)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- Callback when hacking completes
function HackingCompleted(status)
    hackFinished = true
    hackStatus = status
    print('[sb_pacificheist] Hacking completed with status: ' .. tostring(status))
    if status then
        exports['sb_notify']:Notify('Security system bypassed!', 'success', 3000)
    else
        exports['sb_notify']:Notify('Hack failed!', 'error', 3000)
    end
end
