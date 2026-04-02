-- ============================================================================
-- SB_PRISON - Client
-- Booking interaction, jail state, timer, release, guard NPCs
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

-- State
local isJailed = false
local jailLocation = nil       -- 'mrpd' or 'bolingbroke'
local timeRemaining = 0
local sentenceMonths = 0
local sentenceCharges = ''
local awaitingTransport = false
local isOnHold = false

-- Intake state machine
local intakeStep = 0           -- 0 = not in intake, 1-4 = active step, 5 = complete
local intakeActive = false

-- Release state machine
local releaseStep = 0          -- 0 = not in release, 1-3 = active step, 4 = complete
local releaseActive = false

-- NPCs & entities
local guardNpcs = {}
local checkinNpc = nil
local cachedUploadConfig = nil

-- Mugshot camera state
local mugshotCameraActive = false

-- ============================================================================
-- NOTIFY HANDLER (server → client → sb_notify)
-- ============================================================================

RegisterNetEvent('sb_prison:client:notify', function(msg, type, duration)
    exports['sb_notify']:Notify(msg, type, duration or 5000)
end)

-- ============================================================================
-- RESOURCE RESTART RE-SYNC
-- On script restart, ask server if we're still jailed
-- ============================================================================

CreateThread(function()
    Wait(3000) -- Let everything initialize
    TriggerServerEvent('sb_prison:server:requestJailSync')
end)

-- ============================================================================
-- BOOKING TERMINAL SETUP — PC interaction + holding area scan
-- ============================================================================

-- Find a cuffed player (or test dummy) inside the holding area
function FindCuffedPlayerInHoldingArea()
    local area = Config.HoldingArea

    -- Check for test dummy first (from /policedummy)
    local dummyPed = exports['sb_police']:GetTestDummyPed()
    if dummyPed and DoesEntityExist(dummyPed) then
        local dummyCoords = GetEntityCoords(dummyPed)
        local dist = #(dummyCoords - area.coords)
        if dist <= area.radius then
            return -1  -- sentinel for dummy mode
        end
    end

    -- Check real players
    local players = GetActivePlayers()
    local myId = PlayerId()

    for _, player in ipairs(players) do
        if player ~= myId then
            local ped = GetPlayerPed(player)
            if ped and DoesEntityExist(ped) then
                local pedCoords = GetEntityCoords(ped)
                local dist = #(pedCoords - area.coords)
                if dist <= area.radius then
                    local serverId = GetPlayerServerId(player)
                    local cuffState = Player(serverId).state.cuffed
                    if cuffState then
                        return serverId
                    end
                end
            end
        end
    end
    return nil
end

CreateThread(function()
    -- Booking station zone (PC + Camera — single zone, two options)
    local pc = Config.BookingPC
    exports['sb_target']:AddBoxZone('booking_station', pc.coords, pc.width, pc.length, pc.height, pc.heading, {
        {
            name = 'open_booking_terminal',
            label = 'Booking Terminal',
            icon = 'fa-computer',
            distance = 3.0,
            canInteract = function()
                local PlayerData = exports['sb_core']:GetCoreObject().Functions.GetPlayerData()
                return PlayerData and PlayerData.job and PlayerData.job.name == 'police'
            end,
            action = function()
                local cuffedId = FindCuffedPlayerInHoldingArea()
                if not cuffedId then
                    exports['sb_notify']:Notify('No cuffed suspect found in the holding area', 'error', 4000)
                    return
                end
                OpenBookingDashboard(cuffedId)
            end
        },
        {
            name = 'open_mugshot_camera',
            label = 'Mugshot Camera',
            icon = 'fa-camera',
            distance = 3.0,
            canInteract = function()
                if mugshotCameraActive then return false end
                local PlayerData = exports['sb_core']:GetCoreObject().Functions.GetPlayerData()
                return PlayerData and PlayerData.job and PlayerData.job.name == 'police'
            end,
            action = function()
                local cuffedId = FindCuffedPlayerInHoldingArea()
                if not cuffedId then
                    exports['sb_notify']:Notify('No cuffed suspect found in the holding area', 'error', 4000)
                    return
                end
                StartMugshotCamera(cuffedId)
            end
        }
    })
    print('[sb_prison] ^2Booking station zone registered^7 at ' .. tostring(pc.coords))

    -- Bolingbroke blip
    local blipCfg = Config.Bolingbroke.blip
    if blipCfg then
        local blip = AddBlipForCoord(blipCfg.coords.x, blipCfg.coords.y, blipCfg.coords.z)
        SetBlipSprite(blip, blipCfg.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, blipCfg.scale)
        SetBlipColour(blip, blipCfg.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blipCfg.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ============================================================================
-- GUARD NPCs AT BOLINGBROKE
-- ============================================================================

CreateThread(function()
    Wait(5000) -- Let world load
    for _, guard in ipairs(Config.Bolingbroke.guards) do
        local model = GetHashKey(guard.model)
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 10000 do
            Wait(100)
            timeout = timeout + 100
        end
        if HasModelLoaded(model) then
            -- If sitting, spawn 1.0 below chair so ped drops into seat (sb_id pattern)
            local spawnZ = guard.sit and (guard.coords.z - 1.0) or guard.coords.z
            local ped = CreatePed(4, model, guard.coords.x, guard.coords.y, spawnZ, guard.coords.w, false, true)
            SetEntityAsMissionEntity(ped, true, true)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedCombatAttributes(ped, 46, true)
            SetPedCanPlayAmbientAnims(ped, false)

            if guard.sit then
                TaskStartScenarioInPlace(ped, 'PROP_HUMAN_SEAT_CHAIR_UPRIGHT', 0, true)
            end

            GiveWeaponToPed(ped, GetHashKey('WEAPON_PISTOL'), 100, false, true)
            SetModelAsNoLongerNeeded(model)
            table.insert(guardNpcs, ped)
        end
    end
end)

-- ============================================================================
-- BOLINGBROKE CHECK-IN NPC (officer interacts to register prisoner)
-- ============================================================================

-- Find a cuffed player in the Bolingbroke check-in area (same pattern as MRPD holding area)
function FindCuffedPlayerInCheckinArea()
    local area = Config.Bolingbroke.checkinArea

    -- Check for test dummy first (from /policedummy)
    local ok, dummyPed = pcall(function() return exports['sb_police']:GetTestDummyPed() end)
    if ok and dummyPed and DoesEntityExist(dummyPed) then
        local dummyCoords = GetEntityCoords(dummyPed)
        if #(dummyCoords - area.coords) <= area.radius then
            return -1  -- sentinel for dummy/self-test mode
        end
    end

    -- Check real players
    local players = GetActivePlayers()
    local myId = PlayerId()

    for _, player in ipairs(players) do
        if player ~= myId then
            local ped = GetPlayerPed(player)
            if ped and DoesEntityExist(ped) then
                local pedCoords = GetEntityCoords(ped)
                if #(pedCoords - area.coords) <= area.radius then
                    local serverId = GetPlayerServerId(player)
                    local cuffState = Player(serverId).state.cuffed
                    if cuffState then
                        return serverId
                    end
                end
            end
        end
    end
    return nil
end

CreateThread(function()
    Wait(5000) -- Let world load
    local npcCfg = Config.Bolingbroke.checkinNpc
    local model = GetHashKey(npcCfg.model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    if not HasModelLoaded(model) then
        print('[sb_prison] ^1Failed to load check-in NPC model^7')
        return
    end

    local spawnZ = npcCfg.sit and (npcCfg.coords.z - 1.0) or npcCfg.coords.z
    checkinNpc = CreatePed(4, model, npcCfg.coords.x, npcCfg.coords.y, spawnZ, npcCfg.coords.w, false, true)
    SetEntityAsMissionEntity(checkinNpc, true, true)
    SetEntityInvincible(checkinNpc, true)
    FreezeEntityPosition(checkinNpc, true)
    SetBlockingOfNonTemporaryEvents(checkinNpc, true)
    SetPedFleeAttributes(checkinNpc, 0, false)
    SetPedCombatAttributes(checkinNpc, 46, true)
    SetPedCanPlayAmbientAnims(checkinNpc, false)

    if npcCfg.sit then
        TaskStartScenarioInPlace(checkinNpc, 'PROP_HUMAN_SEAT_CHAIR_UPRIGHT', 0, true)
    end

    SetModelAsNoLongerNeeded(model)

    -- Add target on the NPC
    exports['sb_target']:AddTargetEntity(checkinNpc, {
        {
            name = 'checkin_prisoner',
            label = 'Check In Prisoner',
            icon = 'fa-right-to-bracket',
            distance = 3.0,
            canInteract = function()
                local PlayerData = exports['sb_core']:GetCoreObject().Functions.GetPlayerData()
                return PlayerData and PlayerData.job and PlayerData.job.name == 'police'
            end,
            action = function()
                local prisonerId = FindCuffedPlayerInCheckinArea()
                if not prisonerId then
                    exports['sb_notify']:Notify('No cuffed prisoner found in the check-in area', 'error', 3000)
                    return
                end

                -- Progress bar for check-in
                exports['sb_progressbar']:Start({ duration = 3000, label = 'Checking in prisoner...' })
                Wait(3000)

                if prisonerId == -1 then
                    TriggerServerEvent('sb_prison:server:prisonerArrived', GetPlayerServerId(PlayerId()))
                else
                    TriggerServerEvent('sb_prison:server:prisonerArrived', prisonerId)
                end
            end
        }
    })

    print('[sb_prison] ^2Check-in NPC spawned^7 at Bolingbroke intake')
end)

-- ============================================================================
-- BOOKING PROCESS (now handled via NUI dashboard)
-- ============================================================================

-- Triggered by server when officer uses "Send to Jail" from field
-- Opens the dashboard instead of the old progress bar flow
RegisterNetEvent('sb_prison:client:startBooking', function(targetSrc, totalMonths)
    exports['sb_notify']:Notify('Booking suspect (' .. totalMonths .. ' months pending). Use the terminal.', 'info', 5000)
end)

-- ============================================================================
-- MUGSHOT CAMERA (Fixed position, rotate + zoom only)
-- Officer interacts with camera station, views fixed cam, rotates/zooms, captures.
-- No overlay — physical height board prop handles the backdrop.
-- ============================================================================

-- Shot labels for the 2-photo guided flow
local shotLabels = { 'FRONT (1/2)', 'SIDE (2/2)' }
local maxShots = 2

function StartMugshotCamera(suspectServerId)
    if mugshotCameraActive then return end
    mugshotCameraActive = true

    local cfg = Config.MugshotCam
    local shotsTaken = 0
    local currentFov = cfg.defaultFov
    local currentPitch = cfg.initialRot.x
    local currentHeading = cfg.initialRot.z
    local isCapturing = false
    local playerPed = PlayerPedId()

    -- Freeze officer
    FreezeEntityPosition(playerPed, true)

    -- Hide HUD + minimap for clean photos
    exports['sb_hud']:SetHudVisible(false)
    DisplayRadar(false)

    -- Create fixed camera
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, cfg.camPos.x, cfg.camPos.y, cfg.camPos.z)
    SetCamRot(cam, currentPitch, 0.0, currentHeading, 2)
    SetCamFov(cam, currentFov)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, false)

    Wait(500)

    -- === MAIN CAMERA LOOP ===
    while mugshotCameraActive do
        DisableAllControlActions(0)

        -- Only draw text overlays when NOT capturing (so screenshots are clean)
        if not isCapturing then
            local currentLabel = shotLabels[shotsTaken + 1] or 'DONE'

            -- --- Shot label (top-center) ---
            SetTextFont(4)
            SetTextScale(0.0, 0.55)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEntry('STRING')
            AddTextComponentString(currentLabel)
            DrawText(0.5, 0.02)

            -- --- Controls help (bottom-center) ---
            SetTextFont(0)
            SetTextScale(0.0, 0.32)
            SetTextColour(220, 220, 220, 220)
            SetTextCentre(true)
            SetTextDropshadow(1, 0, 0, 0, 255)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString('W/S ~b~Up/Down~w~   A/D ~b~Left/Right~w~   SCROLL ~b~Zoom~w~   E ~b~Capture~w~   BACKSPACE ~b~Exit')
            DrawText(0.5, 0.95)
        end

        -- --- ROTATE: A/D (heading), W/S (pitch) ---
        local minHeading = cfg.initialRot.z - cfg.headingRange
        local maxHeading = cfg.initialRot.z + cfg.headingRange
        if IsDisabledControlPressed(0, 34) then -- A = rotate left
            currentHeading = math.min(maxHeading, currentHeading + cfg.rotSpeed)
        end
        if IsDisabledControlPressed(0, 35) then -- D = rotate right
            currentHeading = math.max(minHeading, currentHeading - cfg.rotSpeed)
        end
        if IsDisabledControlPressed(0, 32) then -- W = tilt up
            currentPitch = math.min(cfg.maxPitch, currentPitch + cfg.rotSpeed)
        end
        if IsDisabledControlPressed(0, 33) then -- S = tilt down
            currentPitch = math.max(cfg.minPitch, currentPitch - cfg.rotSpeed)
        end
        SetCamRot(cam, currentPitch, 0.0, currentHeading, 2)

        -- --- ZOOM: scroll wheel ---
        if IsDisabledControlJustPressed(0, 241) then -- scroll up = zoom in
            currentFov = math.max(cfg.minFov, currentFov - cfg.zoomStep)
            SetCamFov(cam, currentFov)
        end
        if IsDisabledControlJustPressed(0, 242) then -- scroll down = zoom out
            currentFov = math.min(cfg.maxFov, currentFov + cfg.zoomStep)
            SetCamFov(cam, currentFov)
        end

        -- --- CAPTURE: E key ---
        if IsDisabledControlJustPressed(0, 38) and not isCapturing and shotsTaken < maxShots then
            isCapturing = true
            CreateThread(function()
                -- Wait 2 frames so the screen renders clean (no text overlays)
                Wait(0)
                Wait(0)
                UploadMugshot(function(url)
                    if url then
                        shotsTaken = shotsTaken + 1
                        -- Save to server (generic, linked to officer only)
                        TriggerServerEvent('sb_prison:server:saveMugshot', url)
                        exports['sb_notify']:Notify(shotLabels[shotsTaken] .. ' saved', 'success', 2000)

                        -- Auto-exit after both shots
                        if shotsTaken >= maxShots then
                            Wait(1000)
                            mugshotCameraActive = false
                        end
                    else
                        exports['sb_notify']:Notify('Failed to save photo, try again', 'error', 2000)
                    end
                    isCapturing = false
                end)
            end)
        end

        -- --- EXIT: BACKSPACE ---
        if IsDisabledControlJustPressed(0, 194) then
            mugshotCameraActive = false
        end

        Wait(0)
    end

    -- === CLEANUP ===
    RenderScriptCams(false, true, 500, true, false)
    DestroyCam(cam, false)
    FreezeEntityPosition(playerPed, false)
    mugshotCameraActive = false

    -- Restore HUD + minimap
    exports['sb_hud']:SetHudVisible(true)
    DisplayRadar(true)

    exports['sb_notify']:Notify('Camera closed — ' .. shotsTaken .. '/' .. maxShots .. ' photos taken', 'info', 3000)
end

function GetUploadConfig(cb)
    if cachedUploadConfig then
        cb(cachedUploadConfig.url, cachedUploadConfig.field, {
            headers = cachedUploadConfig.headers,
            encoding = cachedUploadConfig.encoding,
            quality = cachedUploadConfig.quality
        })
        return
    end
    SB.Functions.TriggerCallback('sb_prison:server:getUploadConfig', function(config)
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

function UploadMugshot(cb)
    local hasScreenshot = GetResourceState('screenshot-basic') == 'started'
    if not hasScreenshot then
        print('[sb_prison] screenshot-basic not running, skipping mugshot')
        cb(nil)
        return
    end

    GetUploadConfig(function(url, field, options)
        if not url then
            print('[sb_prison] No upload config available, skipping mugshot')
            cb(nil)
            return
        end

        local ok, err = pcall(function()
            exports['screenshot-basic']:requestScreenshotUpload(url, field, options, function(data)
                local imageUrl = ParseUploadResponse(data)
                cb(imageUrl)
            end)
        end)

        if not ok then
            print('[sb_prison] Screenshot error: ' .. tostring(err))
            cb(nil)
        end
    end)
end

function ParseUploadResponse(data)
    local ok, resp = pcall(json.decode, data)
    if not ok or not resp then return nil end
    -- Fivemanager response
    return (resp.data and resp.data.url) or resp.url or resp.image_url or nil
end

-- ============================================================================
-- JAIL STATE
-- ============================================================================

-- Start serving sentence (from server)
-- Booking complete — NO teleport, officer escorts manually
RegisterNetEvent('sb_prison:client:bookingComplete', function(data)
    jailLocation = data.location
    timeRemaining = data.timeRemaining
    sentenceMonths = data.months
    sentenceCharges = data.charges

    if data.location == 'mrpd' then
        -- Short sentence: officer will walk them to a cell, then start serving
        isJailed = true
        awaitingTransport = false
        isOnHold = false
        -- Timer starts immediately for MRPD
        StartTimerThread()
        StartJailControlsThread()
        exports['sb_notify']:Notify('Sentenced to ' .. sentenceMonths .. ' months — MRPD holding', 'error', 8000)
    else
        -- Long sentence: officer will walk them to car and transport
        isJailed = true
        awaitingTransport = true
        isOnHold = true
        StartJailControlsThread()
        StartOnHoldHUDThread()
        exports['sb_notify']:Notify('Booked — awaiting transport to Bolingbroke', 'error', 8000)
    end
end)

RegisterNetEvent('sb_prison:client:startSentence', function(data)
    isJailed = true
    jailLocation = data.location
    timeRemaining = data.timeRemaining
    sentenceMonths = data.months
    sentenceCharges = data.charges
    awaitingTransport = false
    isOnHold = false

    if data.location == 'mrpd' then
        -- MRPD: teleport to cell, start timer immediately
        local cells = Config.MRPD.cellSpawns
        local cell = cells[math.random(#cells)]
        local ped = PlayerPedId()
        SetEntityCoords(ped, cell.x, cell.y, cell.z, false, false, false, false)
        SetEntityHeading(ped, cell.w)
        StartTimerThread()
        StartJailControlsThread()
        exports['sb_notify']:Notify('Sentenced to ' .. sentenceMonths .. ' months', 'error', 8000)
    elseif data.location == 'bolingbroke' then
        if data.bypass then
            -- Admin /jail — skip intake, teleport directly
            local spawnCoords = Config.Bolingbroke.yardSpawn
            local ped = PlayerPedId()
            SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
            SetEntityHeading(ped, spawnCoords.w)
            ApplyPrisonerOutfit()
            StartTimerThread()
            StartJailControlsThread()
            StartPerimeterThread()
            if SpawnPrisonJobZones then SpawnPrisonJobZones() end
            exports['sb_notify']:Notify('Sentenced to ' .. sentenceMonths .. ' months', 'error', 8000)
        elseif data.reconnect then
            -- Reconnect: already served, just restore state at yard
            local spawnCoords = Config.Bolingbroke.yardSpawn
            local ped = PlayerPedId()
            SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
            SetEntityHeading(ped, spawnCoords.w)
            ApplyPrisonerOutfit()
            StartTimerThread()
            StartJailControlsThread()
            StartPerimeterThread()
            if SpawnPrisonJobZones then SpawnPrisonJobZones() end
            exports['sb_notify']:Notify('Serving ' .. sentenceMonths .. ' months', 'error', 8000)
        else
            -- Normal flow: officer checked in → start intake process
            StartJailControlsThread()
            StartIntakeProcess()
            exports['sb_notify']:Notify('Follow the intake steps', 'info', 8000)
        end
    end

    -- Apply movement clipset (if configured)
    if Config.PrisonerClipset then
        local ped = PlayerPedId()
        RequestAnimSet(Config.PrisonerClipset)
        local timeout = 0
        while not HasAnimSetLoaded(Config.PrisonerClipset) and timeout < 5000 do
            Wait(100)
            timeout = timeout + 100
        end
        if HasAnimSetLoaded(Config.PrisonerClipset) then
            SetPedMovementClipset(ped, Config.PrisonerClipset, 0.5)
        end
    end
end)

-- Awaiting transport / ON HOLD (booked but not checked in at Bolingbroke)
-- NO teleport — officer escorts suspect manually (to cell or transport vehicle)
RegisterNetEvent('sb_prison:client:awaitTransport', function(data)
    awaitingTransport = true
    isOnHold = true
    jailLocation = data.location
    timeRemaining = data.timeRemaining
    sentenceMonths = data.months
    sentenceCharges = data.charges

    isJailed = true

    -- Reconnect: place in MRPD cell (player needs to be somewhere)
    if data.reconnect then
        local cells = Config.MRPD.cellSpawns
        local cell = cells[math.random(#cells)]
        local ped = PlayerPedId()
        SetEntityCoords(ped, cell.x, cell.y, cell.z, false, false, false, false)
        SetEntityHeading(ped, cell.w)
    end

    StartJailControlsThread()
    StartOnHoldHUDThread()
end)

-- ============================================================================
-- REMOVE ALL WEAPONS
-- ============================================================================

RegisterNetEvent('sb_prison:client:removeAllWeapons', function()
    RemoveAllPedWeapons(PlayerPedId(), true)
end)

-- ============================================================================
-- SAVE APPEARANCE (server requests, client sends back)
-- ============================================================================

RegisterNetEvent('sb_prison:client:saveAppearance', function()
    local appearance = exports['sb_clothing']:GetCurrentAppearance()
    if appearance then
        TriggerServerEvent('sb_prison:server:saveAppearance', appearance)
    end
end)

-- ============================================================================
-- RESTORE APPEARANCE
-- ============================================================================

RegisterNetEvent('sb_prison:client:restoreAppearance', function(appearance)
    if appearance then
        exports['sb_clothing']:ApplyAppearance(appearance)
    end
end)

-- ============================================================================
-- PRISONER OUTFIT (DLC Collection-based resolver)
-- ============================================================================

-- Cache resolved global indices so we only scan once per session
local resolvedDlcCache = {}

-- Resolve a DLC collection + local index to a global drawable index
-- Uses FiveM collection natives (available build 2802+, we have 3258)
function ResolveDlcDrawable(ped, componentId, collectionName, localIndex)
    local cacheKey = componentId .. '_' .. collectionName .. '_' .. localIndex
    if resolvedDlcCache[cacheKey] then
        return resolvedDlcCache[cacheKey]
    end

    local total = GetNumberOfPedDrawableVariations(ped, componentId)

    if Config.Debug then
        print(string.format('[sb_prison] Resolving: comp %d, collection "%s", local %d — scanning %d drawables',
            componentId, collectionName, localIndex, total))
    end

    for globalIdx = 0, total - 1 do
        -- GetPedCollectionNameFromDrawable returns the DLC collection NAME (string)
        -- GetPedCollectionLocalIndexFromDrawable returns the local index within that collection
        local ok1, colName = pcall(GetPedCollectionNameFromDrawable, ped, componentId, globalIdx)
        local ok2, localIdx = pcall(GetPedCollectionLocalIndexFromDrawable, ped, componentId, globalIdx)

        if not ok1 or not ok2 then
            if Config.Debug then
                print('[sb_prison] Collection natives not available. Error: ' .. tostring(colName))
            end
            return nil
        end

        if tostring(colName) == collectionName and localIdx == localIndex then
            resolvedDlcCache[cacheKey] = globalIdx
            if Config.Debug then
                print(string.format('[sb_prison] RESOLVED: %s local %d → global %d', collectionName, localIndex, globalIdx))
            end
            return globalIdx
        end
    end

    if Config.Debug then
        print(string.format('[sb_prison] FAILED to resolve: %s local %d (not found in %d drawables)', collectionName, localIndex, total))
    end
    return nil
end

function ApplyPrisonerOutfit()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = (model == GetHashKey('mp_m_freemode_01'))
    local outfit = isMale and Config.PrisonerOutfit.male or Config.PrisonerOutfit.female

    -- Pick a random variant (50/50)
    local variantIdx = math.random(1, #outfit.variants)
    local variant = outfit.variants[variantIdx]

    if Config.Debug then
        print(string.format('[sb_prison] Applying prisoner outfit (%s, variant %d/%d)',
            isMale and 'male' or 'female', variantIdx, #outfit.variants))
    end

    -- Step 1: Apply DLC components from chosen variant (top first — GTA auto-sets compatible torso)
    local dlcSuccess = true
    for _, item in ipairs(variant.dlcComponents) do
        local globalIdx = ResolveDlcDrawable(ped, item.componentId, item.collection, item.localIndex)
        if globalIdx then
            SetPedComponentVariation(ped, item.componentId, globalIdx, item.texture, 0)
            local actual = GetPedDrawableVariation(ped, item.componentId)
            if Config.Debug then
                print(string.format('[sb_prison]   DLC Comp %d: global %d tex %d (actual: %d) %s',
                    item.componentId, globalIdx, item.texture, actual,
                    actual == globalIdx and 'OK' or '** MISMATCH'))
            end
        else
            dlcSuccess = false
            if Config.Debug then
                print(string.format('[sb_prison]   DLC Comp %d: FAILED to resolve %s local %d',
                    item.componentId, item.collection, item.localIndex))
            end
        end
    end

    -- Step 2: Apply static/vanilla components (shared across all variants)
    -- Skip torso (3) — GTA already set it when we applied the top above
    for componentId, data in pairs(outfit.staticComponents) do
        SetPedComponentVariation(ped, componentId, data[1], data[2], 0)
    end

    -- Step 3: Clear all props (hats, glasses, etc.)
    for _, propId in ipairs({0, 1, 2, 6, 7}) do
        ClearPedProp(ped, propId)
    end

    if Config.Debug then
        local autoTorso = GetPedDrawableVariation(ped, 3)
        local autoTorsoTex = GetPedTextureVariation(ped, 3)
        print(string.format('[sb_prison]   Torso (auto-set by GTA): drawable %d, texture %d', autoTorso, autoTorsoTex))

        if not dlcSuccess then
            print('[sb_prison] WARNING: Some DLC components failed to resolve. Check collection names in config.lua.')
        end
    end
end

-- ============================================================================
-- BOLINGBROKE INTAKE PROCESS (4-step state machine)
-- ============================================================================

function StripToUnderwear()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local isMale = (model == GetHashKey('mp_m_freemode_01'))
    local outfit = isMale and Config.UnderwearOutfit.male or Config.UnderwearOutfit.female

    for componentId, data in pairs(outfit) do
        SetPedComponentVariation(ped, componentId, data[1], data[2], 0)
    end
    -- Clear props
    for _, propId in ipairs({0, 1, 2, 6, 7}) do
        ClearPedProp(ped, propId)
    end
end

function PlayShowerEffect()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local cfg = Config.ShowerPtfx

    -- Request ptfx dict
    RequestNamedPtfxAsset(cfg.dict)
    local timeout = 0
    while not HasNamedPtfxAssetLoaded(cfg.dict) and timeout < 5000 do
        Wait(100)
        timeout = timeout + 100
    end
    if not HasNamedPtfxAssetLoaded(cfg.dict) then return end

    UseParticleFxAsset(cfg.dict)
    local ptfx = StartParticleFxLoopedAtCoord(
        cfg.name,
        coords.x, coords.y, coords.z + cfg.offsetZ,
        0.0, 0.0, 0.0,
        cfg.scale, false, false, false, false
    )

    -- Freeze player, play shower for 5 seconds
    FreezeEntityPosition(ped, true)
    Wait(5000)
    FreezeEntityPosition(ped, false)

    StopParticleFxLooped(ptfx, false)
    RemoveNamedPtfxAsset(cfg.dict)
end

function StartIntakeProcess()
    if intakeActive then return end
    intakeActive = true
    intakeStep = 1
    isOnHold = false  -- Stop ON HOLD HUD if it was showing

    local intake = Config.Bolingbroke.intake
    local steps = intake.steps

    -- HUD + marker draw thread
    CreateThread(function()
        while intakeActive and intakeStep >= 1 and intakeStep <= #steps do
            local step = steps[intakeStep]

            -- Draw HUD text
            SetTextFont(Config.OnHoldHUD.font)
            SetTextScale(Config.OnHoldHUD.scale, Config.OnHoldHUD.scale)
            SetTextColour(255, 200, 0, 255)
            SetTextCentre(true)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEntry('STRING')
            AddTextComponentString(step.hudText)
            DrawText(Config.OnHoldHUD.x, Config.OnHoldHUD.y)

            -- Draw marker at current step
            local mc = intake.markerColor
            DrawMarker(
                intake.markerType,
                step.coords.x, step.coords.y, step.coords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                intake.markerScale.x, intake.markerScale.y, intake.markerScale.z,
                mc.r, mc.g, mc.b, mc.a,
                false, false, 2, false, nil, nil, false
            )

            Wait(0)
        end
    end)

    -- Step detection thread
    CreateThread(function()
        while intakeActive and intakeStep >= 1 and intakeStep <= #steps do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local step = steps[intakeStep]
            local dist = #(pos - step.coords)

            if dist <= intake.triggerDist then
                -- Player reached the step marker
                local stepNum = intakeStep

                if stepNum == 4 then
                    -- YARD DOOR: immediate — no progress bar, just walk through
                    intakeStep = 5
                    intakeActive = false

                    TriggerServerEvent('sb_prison:server:intakeComplete')

                    StartTimerThread()
                    StartPerimeterThread()
                    if SpawnPrisonJobZones then SpawnPrisonJobZones() end

                    exports['sb_notify']:Notify('Intake complete — serving ' .. sentenceMonths .. ' months', 'error', 8000)
                    return
                end

                -- Steps 1-3: face direction + progress bar
                TaskTurnPedToFaceCoord(ped, step.coords.x, step.coords.y, step.coords.z, 1000)
                Wait(500)

                exports['sb_progressbar']:Start({ duration = step.actionDuration, label = step.actionText })
                Wait(step.actionDuration)

                if stepNum == 1 then
                    -- DEPOSIT: save appearance WITH the deposit event (no race condition)
                    local appearance = exports['sb_clothing']:GetCurrentAppearance()
                    TriggerServerEvent('sb_prison:server:intakeDeposit', appearance)
                    StripToUnderwear()
                    exports['sb_notify']:Notify('Items confiscated', 'info', 3000)

                elseif stepNum == 2 then
                    -- SHOWER: water particle effect
                    PlayShowerEffect()
                    exports['sb_notify']:Notify('Shower complete', 'info', 3000)

                elseif stepNum == 3 then
                    -- PRISON OUTFIT: apply orange jumpsuit
                    ApplyPrisonerOutfit()
                    exports['sb_notify']:Notify('Prison uniform issued', 'info', 3000)
                end

                -- Advance to next step
                intakeStep = stepNum + 1
            end

            Wait(500)
        end
    end)
end

-- ============================================================================
-- BOLINGBROKE RELEASE PROCESS (3-step walkout)
-- ============================================================================

RegisterNetEvent('sb_prison:client:startRelease', function(isReconnect, startStep)
    -- Set state — still jailed during the release walk
    isJailed = true
    jailLocation = 'bolingbroke'
    timeRemaining = 0
    awaitingTransport = false
    isOnHold = false
    intakeActive = false
    intakeStep = 0

    if isReconnect then
        -- Reconnect: put them at yard, apply outfit based on progress
        local spawnCoords = Config.Bolingbroke.yardSpawn
        local ped = PlayerPedId()
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        SetEntityHeading(ped, spawnCoords.w)
        -- Only apply prison outfit if they haven't gotten clothes back yet
        if not startStep or startStep < 3 then
            ApplyPrisonerOutfit()
        end
    end

    StartJailControlsThread()
    StartPerimeterThread()
    StartReleaseProcess(startStep or 1)
end)

function StartReleaseProcess(startStep)
    if releaseActive then return end
    releaseActive = true
    releaseStep = startStep or 1

    local rel = Config.Bolingbroke.release
    local steps = rel.steps

    -- HUD + marker draw thread
    CreateThread(function()
        while releaseActive and releaseStep >= 1 and releaseStep <= #steps do
            local step = steps[releaseStep]

            -- Draw HUD text
            SetTextFont(Config.OnHoldHUD.font)
            SetTextScale(Config.OnHoldHUD.scale, Config.OnHoldHUD.scale)
            SetTextColour(0, 200, 0, 255)
            SetTextCentre(true)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEntry('STRING')
            AddTextComponentString(step.hudText)
            DrawText(Config.OnHoldHUD.x, Config.OnHoldHUD.y)

            -- Draw marker at current step
            local mc = rel.markerColor
            DrawMarker(
                rel.markerType,
                step.coords.x, step.coords.y, step.coords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                rel.markerScale.x, rel.markerScale.y, rel.markerScale.z,
                mc.r, mc.g, mc.b, mc.a,
                false, false, 2, false, nil, nil, false
            )

            Wait(0)
        end
    end)

    -- Step detection thread
    CreateThread(function()
        while releaseActive and releaseStep >= 1 and releaseStep <= #steps do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local step = steps[releaseStep]
            local dist = #(pos - step.coords)

            if dist <= rel.triggerDist then
                local stepNum = releaseStep

                if stepNum == 3 then
                    -- EXIT: immediate — no progress bar, just walk through
                    releaseStep = 4
                    releaseActive = false

                    TriggerServerEvent('sb_prison:server:releaseConfirm')

                    -- Clean up jail state (no teleport — player walks out naturally)
                    isJailed = false
                    if CleanupPrisonJobZones then CleanupPrisonJobZones() end

                    if Config.PrisonerClipset then
                        ResetPedMovementClipset(ped, 0.5)
                    end

                    exports['sb_notify']:Notify('You have been released from Bolingbroke', 'success', 5000)
                    return
                end

                -- Steps 1-2: face direction + progress bar
                TaskTurnPedToFaceCoord(ped, step.coords.x, step.coords.y, step.coords.z, 1000)
                Wait(500)

                exports['sb_progressbar']:Start({ duration = step.actionDuration, label = step.actionText })
                Wait(step.actionDuration)

                if stepNum == 1 then
                    -- REMOVE PRISON UNIFORM: strip to underwear (client-side only)
                    StripToUnderwear()
                    exports['sb_notify']:Notify('Prison uniform removed', 'info', 3000)

                elseif stepNum == 2 then
                    -- CHANGE & COLLECT: server restores civilian clothes + items
                    TriggerServerEvent('sb_prison:server:releaseClothes')
                    Wait(800) -- let appearance apply
                    TriggerServerEvent('sb_prison:server:releaseItems')
                    exports['sb_notify']:Notify('Belongings collected', 'info', 3000)
                end

                -- Advance to next step
                releaseStep = stepNum + 1
            end

            Wait(500)
        end
    end)
end

-- ============================================================================
-- ON HOLD HUD THREAD
-- ============================================================================

function StartOnHoldHUDThread()
    CreateThread(function()
        local cfg = Config.OnHoldHUD
        while isOnHold do
            SetTextFont(cfg.font)
            SetTextScale(cfg.scale, cfg.scale)
            SetTextColour(cfg.color.r, cfg.color.g, cfg.color.b, cfg.color.a)
            SetTextCentre(true)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEntry('STRING')
            AddTextComponentString(cfg.text)
            DrawText(cfg.x, cfg.y)
            Wait(0)
        end
    end)
end

-- ============================================================================
-- TIMER COUNTDOWN THREAD
-- ============================================================================

function StartTimerThread()
    -- Countdown thread (decrements every second, no drawing)
    CreateThread(function()
        while isJailed and timeRemaining > 0 do
            Wait(1000)
            timeRemaining = timeRemaining - 1
        end
    end)

    -- Per-frame draw thread (native text must be drawn every frame)
    CreateThread(function()
        while isJailed do
            -- Don't draw timer when release process is active (release HUD takes over)
            if not releaseActive then
                local minutes = math.floor(timeRemaining / 60)
                local seconds = timeRemaining % 60
                local timerText = string.format('~r~SENTENCE: ~w~%02d:%02d', minutes, seconds)

                SetTextFont(Config.Timer.font)
                SetTextScale(Config.Timer.scale, Config.Timer.scale)
                SetTextColour(255, 255, 255, 255)
                SetTextCentre(true)
                SetTextDropshadow(2, 0, 0, 0, 255)
                SetTextEntry('STRING')
                AddTextComponentString(timerText)
                DrawText(Config.Timer.x, Config.Timer.y)

                -- Credits HUD (gold, below timer)
                local credits = GetPrisonCredits and GetPrisonCredits() or 0
                local creditsText = string.format('~y~CREDITS: ~w~%d', credits)
                local chud = Config.CreditsHUD
                SetTextFont(chud.font)
                SetTextScale(chud.scale, chud.scale)
                SetTextColour(chud.color.r, chud.color.g, chud.color.b, chud.color.a)
                SetTextCentre(true)
                SetTextDropshadow(2, 0, 0, 0, 255)
                SetTextEntry('STRING')
                AddTextComponentString(creditsText)
                DrawText(chud.x, chud.y)
            end

            Wait(0)
        end
    end)
end

-- ============================================================================
-- JAIL CONTROLS RESTRICTION THREAD
-- ============================================================================

function StartJailControlsThread()
    CreateThread(function()
        while isJailed do
            local ped = PlayerPedId()

            -- Disable weapon controls (but allow unarmed melee/fists)
            DisableControlAction(0, 25, true)   -- Aim (weapon)
            DisableControlAction(0, 47, true)   -- Weapon select
            DisableControlAction(0, 58, true)   -- Weapon select
            DisableControlAction(0, 45, true)   -- Reload

            -- Disable vehicle entry
            DisableControlAction(0, 23, true)   -- Enter vehicle
            DisableControlAction(0, 75, true)   -- Exit vehicle

            -- Remove weapons if somehow obtained (fists are fine)
            if GetSelectedPedWeapon(ped) ~= GetHashKey('WEAPON_UNARMED') then
                RemoveAllPedWeapons(ped, true)
            end

            Wait(0)
        end
    end)
end

-- ============================================================================
-- PERIMETER CHECK (Bolingbroke only)
-- ============================================================================

function StartPerimeterThread()
    CreateThread(function()
        while isJailed and jailLocation == 'bolingbroke' do
            Wait(2000)

            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)

            if not IsPointInPolygon(pos.x, pos.y, Config.Bolingbroke.perimeter) then
                -- Teleport back to yard
                local spawn = Config.Bolingbroke.yardSpawn
                SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
                SetEntityHeading(ped, spawn.w)
                exports['sb_notify']:Notify('You cannot leave the prison perimeter', 'error', 3000)
            end
        end
    end)
end

-- Point-in-polygon (ray casting algorithm)
function IsPointInPolygon(x, y, polygon)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y

        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

-- ============================================================================
-- RELEASE
-- ============================================================================

RegisterNetEvent('sb_prison:client:release', function(location)
    isJailed = false
    awaitingTransport = false
    isOnHold = false
    intakeActive = false
    intakeStep = 0
    releaseActive = false
    releaseStep = 0
    timeRemaining = 0

    -- Cleanup prison job zones
    if CleanupPrisonJobZones then CleanupPrisonJobZones() end

    local ped = PlayerPedId()

    -- Teleport to release point
    local releasePoint
    if location == 'mrpd' then
        releasePoint = Config.MRPD.releasePoint
    else
        releasePoint = Config.Bolingbroke.releasePoint
    end

    SetEntityCoords(ped, releasePoint.x, releasePoint.y, releasePoint.z, false, false, false, false)
    SetEntityHeading(ped, releasePoint.w)

    -- Reset movement clipset (if one was applied)
    if Config.PrisonerClipset then
        ResetPedMovementClipset(ped, 0.5)
    end

    -- Appearance is restored by server via sb_prison:client:restoreAppearance event

    exports['sb_notify']:Notify('You have been released from prison', 'success', 5000)
end)

-- ============================================================================
-- STATE ACCESSORS (used by client/jobs.lua and client/canteen.lua)
-- ============================================================================

function GetPrisonState()
    return isJailed, jailLocation, timeRemaining
end

function SetTimeRemaining(val)
    timeRemaining = val
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('IsJailed', function()
    return isJailed
end)

exports('GetSentenceData', function()
    return {
        isJailed = isJailed,
        location = jailLocation,
        timeRemaining = timeRemaining,
        months = sentenceMonths,
        charges = sentenceCharges,
        awaitingTransport = awaitingTransport,
    }
end)
-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Close NUI if open
    if IsBookingDashboardOpen() then
        CloseBookingDashboard()
    end

    -- Delete guard NPCs
    for _, ped in ipairs(guardNpcs) do
        if DoesEntityExist(ped) then
            DeletePed(ped)
        end
    end

    -- Delete check-in NPC
    if checkinNpc and DoesEntityExist(checkinNpc) then
        DeletePed(checkinNpc)
    end

    -- Remove target zones
    exports['sb_target']:RemoveZone('booking_station')

    -- Cleanup prison job zones and canteen NPC
    if CleanupPrisonJobZones then CleanupPrisonJobZones() end
    if CleanupCanteenNPC then CleanupCanteenNPC() end

    -- Reset player state if jailed
    if isJailed then
        isJailed = false
        awaitingTransport = false
        isOnHold = false
        intakeActive = false
        intakeStep = 0
        releaseActive = false
        releaseStep = 0
        local ped = PlayerPedId()
        if Config.PrisonerClipset then
            ResetPedMovementClipset(ped, 0.0)
        end
    end
end)
