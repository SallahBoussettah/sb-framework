-- =============================================
-- SB_POLICE - Field Actions
-- Cuffing, Escort, Transport, Search
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

-- Local state
local isCuffed = false           -- Are WE cuffed?
local cuffType = nil             -- 'soft' or 'hard'
local isBeingEscorted = false    -- Are WE being escorted?
local escortedBy = nil           -- Server ID of officer escorting us
local escortingPlayer = nil      -- Server ID of player we're escorting
local isEscortingDummy = false   -- Are we escorting the test dummy? (forward-declared for IsEscortingPlayer)
local isInTransport = false      -- Are we locked in a vehicle (transported)?
local isOnDuty = false           -- Police duty status

-- Tackle state
local tackleCooldown = false

-- Animation states
local cuffAnimLoop = nil

-- =============================================
-- Utility Functions
-- =============================================

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return HasAnimDictLoaded(dict)
end

local function GetServerIdFromPed(ped)
    if not DoesEntityExist(ped) then return nil end
    if not IsPedAPlayer(ped) then return nil end
    local player = NetworkGetPlayerIndexFromPed(ped)
    if player == -1 then return nil end
    return GetPlayerServerId(player)
end

local function GetPedFromServerId(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    return GetPlayerPed(player)
end

-- =============================================
-- State Checkers (for interactions.lua)
-- =============================================

function IsPlayerCuffed(ped)
    if not ped then return false end
    local serverId = GetServerIdFromPed(ped)
    if not serverId then return false end
    local state = Player(serverId).state.cuffed
    return state ~= nil and state ~= false
end

function GetPlayerCuffType(ped)
    if not ped then return nil end
    local serverId = GetServerIdFromPed(ped)
    if not serverId then return nil end
    return Player(serverId).state.cuffed
end

function IsPlayerBeingEscorted(ped)
    if not ped then return false end
    local serverId = GetServerIdFromPed(ped)
    if not serverId then return false end
    local state = Player(serverId).state.escortedBy
    return state ~= nil and state ~= false
end

function IsEscortingPlayer()
    return escortingPlayer ~= nil or isEscortingDummy
end

function GetEscortedPlayer()
    if escortingPlayer then return escortingPlayer end
    if isEscortingDummy then return -1 end  -- sentinel: dummy mode
    return nil
end

-- =============================================
-- Cuffing System
-- =============================================

function StartCuffAction(targetPed, cType)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    -- Check if already cuffed
    if IsPlayerCuffed(targetPed) then
        exports['sb_notify']:Notify('Target is already cuffed', 'error', 3000)
        return
    end

    local duration = Config.Field.CuffDuration

    -- Tell server to start paired animation on target NOW (before progress bar)
    TriggerServerEvent('sb_police:server:startCuffAnim', targetId)

    exports['sb_progressbar']:Start({
        label = cType == 'soft' and 'Applying soft cuffs...' or 'Applying hard cuffs...',
        duration = duration,
        icon = 'lock',
        canCancel = true,
        animation = Config.Field.Animations.cuff_officer,
        onComplete = function()
            TriggerServerEvent('sb_police:server:cuffPlayer', targetId, cType)
        end,
        onCancel = function()
            TriggerServerEvent('sb_police:server:cancelCuffAnim', targetId)
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

function StartUncuffAction(targetPed)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    -- Check if actually cuffed
    if not IsPlayerCuffed(targetPed) then
        exports['sb_notify']:Notify('Target is not cuffed', 'error', 3000)
        return
    end

    local duration = Config.Field.UncuffDuration

    exports['sb_progressbar']:Start({
        label = 'Removing cuffs...',
        duration = duration,
        icon = 'unlock',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            TriggerServerEvent('sb_police:server:uncuffPlayer', targetId)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

-- Called when officer STARTS cuffing us (paired animation, before cuff state applied)
RegisterNetEvent('sb_police:client:playCuffAnim', function(officerServerId)
    local myPed = PlayerPedId()
    local srcPlayer = GetPlayerFromServerId(officerServerId)
    local officerPed = GetPlayerPed(srcPlayer)

    if officerPed and DoesEntityExist(officerPed) then
        -- Position in front of officer, back facing them
        local officerCoords = GetEntityCoords(officerPed)
        local officerHeading = GetEntityHeading(officerPed)
        local rad = math.rad(officerHeading)
        local newX = officerCoords.x - math.sin(rad) * 1.0
        local newY = officerCoords.y + math.cos(rad) * 1.0

        SetEntityCoords(myPed, newX, newY, officerCoords.z, false, false, false, false)
        SetEntityHeading(myPed, officerHeading)
    end

    -- Play suspect-side paired animation
    LoadAnimDict('mp_arrest_paired')
    TaskPlayAnim(myPed, 'mp_arrest_paired', 'crook_p2_back_right', 8.0, -8.0, 3750, 0, 0, false, false, false)
end)

-- Called when officer cancels cuffing
RegisterNetEvent('sb_police:client:cancelCuffAnim', function()
    ClearPedTasks(PlayerPedId())
end)

-- Called when WE get cuffed (state applied after animation)
RegisterNetEvent('sb_police:client:applyCuffs', function(cType, officerServerId)
    isCuffed = true
    cuffType = cType
    local ped = PlayerPedId()

    -- Paired animation already played via playCuffAnim, just apply idle cuff state
    ClearPedTasks(ped)
    ApplyCuffIdle(ped, cType)

    -- Disable combat
    SetPedCanPlayAmbientAnims(ped, false)
    DisablePlayerFiring(PlayerId(), true)
    SetPlayerCanDoDriveBy(PlayerId(), false)

    exports['sb_notify']:Notify('You have been cuffed', 'info', 3000)

    -- Cuff control loop
    CreateThread(function()
        while isCuffed do
            local ped = PlayerPedId()

            -- Disable attack controls
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 47, true)  -- Weapon
            DisableControlAction(0, 58, true)  -- Weapon
            DisableControlAction(0, 140, true) -- Melee light
            DisableControlAction(0, 141, true) -- Melee heavy
            DisableControlAction(0, 142, true) -- Melee alt
            DisableControlAction(0, 263, true) -- Melee
            DisableControlAction(0, 264, true) -- Melee
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 45, true)  -- Reload

            -- Disable entering vehicles (must be put in)
            if not isInTransport then
                DisableControlAction(0, 23, true)  -- Enter vehicle
                DisableControlAction(0, 75, true)  -- Exit vehicle
            end

            Wait(0)
        end
    end)
end)

-- Helper: apply cuff idle animation + movement clipset
function ApplyCuffIdle(ped, cType)
    LoadAnimDict('mp_arresting')
    if cType == 'soft' then
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        SetPedMovementClipset(ped, 'move_m@prisoner_cuffed', 0.5)
    elseif cType == 'hard' then
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        SetEnableHandcuffs(ped, true)
        SetPedMovementClipset(ped, 'move_m@prisoner_cuffed', 0.25)
    end
end

-- Called when WE get uncuffed
RegisterNetEvent('sb_police:client:removeCuffs', function()
    isCuffed = false
    cuffType = nil
    local ped = PlayerPedId()

    -- Clear animations
    ClearPedTasks(ped)
    ResetPedMovementClipset(ped, 0.5)
    SetEnableHandcuffs(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    DisablePlayerFiring(PlayerId(), false)
    SetPlayerCanDoDriveBy(PlayerId(), true)

    exports['sb_notify']:Notify('You have been uncuffed', 'success', 3000)
end)

-- =============================================
-- Escort System
-- =============================================

function StartEscort(targetPed)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    -- Must be cuffed to escort
    if not IsPlayerCuffed(targetPed) then
        exports['sb_notify']:Notify('Target must be cuffed first', 'error', 3000)
        return
    end

    -- Already being escorted by someone else?
    if IsPlayerBeingEscorted(targetPed) then
        exports['sb_notify']:Notify('Target is already being escorted', 'error', 3000)
        return
    end

    TriggerServerEvent('sb_police:server:startEscort', targetId)
end

function StopEscort()
    if not escortingPlayer then return end
    TriggerServerEvent('sb_police:server:stopEscort', escortingPlayer)
end

-- We started escorting someone
RegisterNetEvent('sb_police:client:escortStarted', function(targetId)
    escortingPlayer = targetId
    exports['sb_notify']:Notify('Escorting suspect', 'info', 3000)
end)

-- We stopped escorting
RegisterNetEvent('sb_police:client:escortStopped', function()
    escortingPlayer = nil
    ClearPedTasks(PlayerPedId())
end)

-- WE are being escorted (attach to officer - origin_police approach)
RegisterNetEvent('sb_police:client:beingEscorted', function(officerId)
    isBeingEscorted = true
    escortedBy = officerId

    exports['sb_notify']:Notify('You are being escorted', 'info', 3000)

    local myPed = PlayerPedId()
    local srcPlayer = GetPlayerFromServerId(escortedBy)
    local officerPed = GetPlayerPed(srcPlayer)

    if not officerPed or not DoesEntityExist(officerPed) then
        -- Officer ped not loaded yet, wait a moment
        local timeout = 0
        while (not officerPed or not DoesEntityExist(officerPed)) and timeout < 5000 do
            Wait(100)
            timeout = timeout + 100
            srcPlayer = GetPlayerFromServerId(escortedBy)
            officerPed = GetPlayerPed(srcPlayer)
        end
    end

    if not officerPed or not DoesEntityExist(officerPed) then
        isBeingEscorted = false
        escortedBy = nil
        exports['sb_notify']:Notify('Escort failed - officer not found', 'error', 3000)
        return
    end

    -- Play cuffed idle animation
    LoadAnimDict('mp_arresting')
    TaskPlayAnim(myPed, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Attach to officer - use raw bone ID 11816 (origin_police approach)
    AttachEntityToEntity(myPed, officerPed, 11816, 0.28, 0.43, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

    -- Escort loop with walk task (origin_police approach)
    CreateThread(function()
        local walking = false

        while isBeingEscorted do
            local srcPlayer = GetPlayerFromServerId(escortedBy)
            local officerPed = GetPlayerPed(srcPlayer)

            if not officerPed or not DoesEntityExist(officerPed) or not IsPedOnFoot(officerPed) or IsPedDeadOrDying(officerPed, true) then
                isBeingEscorted = false
                escortedBy = nil
                DetachEntity(PlayerPedId(), true, false)
                ClearPedTasks(PlayerPedId())
                break
            end

            local myPed = PlayerPedId()

            -- Re-attach if detached
            if not IsEntityAttachedToEntity(myPed, officerPed) and isBeingEscorted then
                AttachEntityToEntity(myPed, officerPed, 11816, 0.28, 0.43, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            end

            -- Walk task when officer moves (prevents stiff floating body)
            local spd = GetEntitySpeed(officerPed)
            if spd > 0.1 then
                if not walking then
                    walking = true
                end
                local myCoords = GetEntityCoords(myPed)
                local myForward = GetEntityForwardVector(myPed)
                local targetCoords = myCoords + (myForward * 5.0)
                local walkSpeed = spd > 2.0 and 2.0 or 1.0
                TaskGoStraightToCoord(myPed, targetCoords.x, targetCoords.y, targetCoords.z, walkSpeed, -1, GetEntityHeading(myPed), 0.0)
            elseif walking then
                walking = false
                ClearPedTasks(myPed)
                -- Re-apply cuff idle
                LoadAnimDict('mp_arresting')
                TaskPlayAnim(myPed, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            -- Disable movement controls
            DisableControlAction(0, 30, true)  -- Move LR
            DisableControlAction(0, 31, true)  -- Move UD
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 23, true)  -- Enter vehicle
            DisableControlAction(0, 75, true)  -- Exit vehicle

            Wait(100)
        end
    end)
end)

-- WE are released from escort
RegisterNetEvent('sb_police:client:escortReleased', function()
    isBeingEscorted = false
    escortedBy = nil

    local myPed = PlayerPedId()

    -- Detach from officer
    DetachEntity(myPed, true, false)
    ClearPedTasks(myPed)

    -- Re-apply cuff idle if still cuffed
    if isCuffed then
        LoadAnimDict('mp_arresting')
        TaskPlayAnim(myPed, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    exports['sb_notify']:Notify('You have been released from escort', 'info', 3000)
end)

-- =============================================
-- Vehicle Transport
-- =============================================

function PutInVehicle(vehicle)
    if not escortingPlayer then
        exports['sb_notify']:Notify('You must be escorting someone', 'error', 3000)
        return
    end

    if not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('Invalid vehicle', 'error', 3000)
        return
    end

    -- Find an empty back seat (prefer rear right, then rear left)
    local seat = nil
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)

    -- Check rear seats first (indices 1 and 2 are typically back seats)
    for i = 1, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            seat = i
            break
        end
    end

    if not seat then
        exports['sb_notify']:Notify('No empty back seat available', 'error', 3000)
        return
    end

    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

    exports['sb_progressbar']:Start({
        label = 'Putting suspect in vehicle...',
        duration = 2500,
        icon = 'car',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            TriggerServerEvent('sb_police:server:putInVehicle', escortingPlayer, vehicleNetId, seat)
            escortingPlayer = nil
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

function TakeOutOfVehicle(targetPed)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    if not IsPedInAnyVehicle(targetPed, false) then
        exports['sb_notify']:Notify('Target is not in a vehicle', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        label = 'Taking suspect out of vehicle...',
        duration = 2000,
        icon = 'car',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            TriggerServerEvent('sb_police:server:takeOutOfVehicle', targetId)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

-- WE are being put in a vehicle
RegisterNetEvent('sb_police:client:putInVehicle', function(vehicleNetId, seat)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return end

    isInTransport = true
    isBeingEscorted = false
    escortedBy = nil
    local ped = PlayerPedId()

    -- Detach from officer if attached
    if IsEntityAttached(ped) then
        DetachEntity(ped, true, false)
    end

    -- Clear tasks before warping
    ClearPedTasks(ped)

    -- Warp into vehicle
    TaskWarpPedIntoVehicle(ped, vehicle, seat)

    -- Disable exit
    CreateThread(function()
        while isInTransport and IsPedInVehicle(ped, vehicle, false) do
            DisableControlAction(0, 75, true)  -- Exit vehicle
            Wait(0)
        end
    end)

    exports['sb_notify']:Notify('You have been placed in a vehicle', 'info', 3000)
end)

-- WE are being taken out of a vehicle
RegisterNetEvent('sb_police:client:takeOutOfVehicle', function()
    isInTransport = false
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end

    -- Re-apply cuff animation after exiting vehicle
    if isCuffed then
        CreateThread(function()
            Wait(1500)
            if isCuffed and not IsPedInAnyVehicle(PlayerPedId(), false) then
                ApplyCuffIdle(PlayerPedId(), cuffType)
            end
        end)
    end

    exports['sb_notify']:Notify('You have been removed from the vehicle', 'info', 3000)
end)

-- =============================================
-- Search / Pat Down
-- =============================================

function StartSearch(targetPed)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    -- Target should be cuffed for a proper search
    if not IsPlayerCuffed(targetPed) then
        exports['sb_notify']:Notify('Target should be cuffed first', 'warning', 3000)
        -- Still allow search, just with a warning
    end

    local duration = Config.Field.SearchDuration
    local anim = Config.Field.Animations.search

    exports['sb_progressbar']:Start({
        label = 'Searching suspect...',
        duration = duration,
        icon = 'search',  -- Lucide icon
        canCancel = true,
        animation = anim,
        onComplete = function()
            TriggerServerEvent('sb_police:server:searchPlayer', targetId)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Search cancelled', 'info', 2000)
        end
    })
end

-- =============================================
-- GSR (Gunshot Residue) Test
-- =============================================

function StartGSRTest(targetPed)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        label = 'Performing GSR test...',
        duration = Config.GSR.TestDuration,
        icon = 'search',
        canCancel = true,
        animation = Config.Field.Animations.search,
        onComplete = function()
            -- Ask server for GSR result
            SB.Functions.TriggerCallback('sb_police:server:gsrTest', function(result)
                if result then
                    exports['sb_notify']:Notify('GSR Test: POSITIVE - Gunshot residue detected', 'error', 8000)
                else
                    exports['sb_notify']:Notify('GSR Test: NEGATIVE - No residue found', 'success', 5000)
                end
            end, targetId)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('GSR test cancelled', 'info', 2000)
        end
    })
end

-- =============================================
-- Breathalyzer Test
-- =============================================

function StartBreathalyzerTest(targetPed)
    local targetId = GetServerIdFromPed(targetPed)
    if not targetId then
        exports['sb_notify']:Notify('Invalid target', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        label = 'Administering breathalyzer...',
        duration = Config.Breathalyzer.TestDuration,
        icon = 'search',
        canCancel = true,
        onComplete = function()
            -- For now: always 0.00 BAC (no alcohol system yet)
            -- Future: hook into sb_metabolism alcohol tracking
            exports['sb_notify']:Notify('Breathalyzer: 0.00 BAC - NEGATIVE', 'success', 5000)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Breathalyzer cancelled', 'info', 2000)
        end
    })
end

-- =============================================
-- Vehicle Search (opens trunk inventory)
-- =============================================

function StartVehicleSearch(vehicle)
    if not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('Invalid vehicle', 'error', 3000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then
        exports['sb_notify']:Notify('Cannot identify vehicle', 'error', 3000)
        return
    end

    plate = plate:gsub('%s+', ''):upper()

    exports['sb_progressbar']:Start({
        label = 'Searching vehicle...',
        duration = Config.VehicleSearch.SearchDuration,
        icon = 'search',
        canCancel = true,
        animation = Config.Field.Animations.search,
        onComplete = function()
            -- Open vehicle trunk/glovebox via sb_inventory
            local stashId = 'vehicle_' .. plate
            TriggerServerEvent('sb_inventory:server:openInventory', 'stash', stashId, {
                slots = 30,
                label = 'Vehicle Search - ' .. plate
            })
            exports['sb_notify']:Notify('Searching vehicle ' .. plate .. '...', 'info', 3000)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Vehicle search cancelled', 'info', 2000)
        end
    })
end

-- =============================================
-- Police Equipment Use (inventory items)
-- =============================================

-- Flashlight toggle (police-category item, not handled by sb_weapons)
local flashlightActive = false
local flashlightWeapon = `WEAPON_FLASHLIGHT`

RegisterNetEvent('sb_police:client:useFlashlight', function()
    local ped = PlayerPedId()

    if flashlightActive then
        RemoveWeaponFromPed(ped, flashlightWeapon)
        flashlightActive = false
        exports['sb_notify']:Notify('Flashlight holstered', 'info', 2000)
    else
        GiveWeaponToPed(ped, flashlightWeapon, 1, false, true)
        SetCurrentPedWeapon(ped, flashlightWeapon)
        flashlightActive = true
        exports['sb_notify']:Notify('Flashlight equipped', 'success', 2000)
    end
end)

-- NOTE: weapon_nightstick, weapon_stungun, etc. are now handled by sb_weapons EquipWeapon
-- (they have noMagazine=true in Config.Weapons, so they get native ammo directly)

-- Body Armor apply
RegisterNetEvent('sb_police:client:useArmor', function()
    local ped = PlayerPedId()

    exports['sb_progressbar']:Start({
        label = 'Putting on body armor...',
        duration = 3000,
        icon = 'shield',
        canCancel = true,
        onComplete = function()
            SetPedArmour(ped, 100)
            exports['sb_notify']:Notify('Body armor equipped', 'success', 3000)
        end,
        onCancel = function()
            -- Armor was already removed from inventory on server, give it back
            TriggerServerEvent('sb_police:server:returnItem', 'armor', 1)
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end)

-- First Aid Kit use
RegisterNetEvent('sb_police:client:useFirstAid', function()
    local ped = PlayerPedId()

    exports['sb_progressbar']:Start({
        label = 'Using first aid kit...',
        duration = 5000,
        icon = 'heart',
        canCancel = true,
        animation = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
            flag = 49,
        },
        onComplete = function()
            local maxHealth = GetEntityMaxHealth(ped)
            SetEntityHealth(ped, maxHealth)
            exports['sb_notify']:Notify('Healed with first aid kit', 'success', 3000)
        end,
        onCancel = function()
            -- Item was already removed on server, give it back
            TriggerServerEvent('sb_police:server:returnItem', 'firstaid', 1)
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end)

-- Cleanup flashlight on resource stop / death / off-duty
local function CleanupFlashlight()
    if flashlightActive then
        RemoveWeaponFromPed(PlayerPedId(), flashlightWeapon)
        flashlightActive = false
    end
end

-- =============================================
-- Exports
-- =============================================

exports('IsCuffed', function() return isCuffed end)
exports('GetCuffType', function() return cuffType end)
exports('IsBeingEscorted', function() return isBeingEscorted end)
exports('IsEscorting', function() return escortingPlayer ~= nil or isEscortingDummy end)
exports('GetEscortedPlayerId', function() return escortingPlayer end)
exports('GetTestDummyPed', function()
    if testDummy and DoesEntityExist(testDummy) then return testDummy end
    return nil
end)
exports('IsInTransport', function() return isInTransport end)

-- Expose state checker functions for interactions.lua
exports('IsPlayerCuffed', IsPlayerCuffed)
exports('IsPlayerBeingEscorted', IsPlayerBeingEscorted)
exports('IsEscortingPlayer', IsEscortingPlayer)
exports('GetEscortedPlayer', GetEscortedPlayer)

-- Action functions for interactions.lua
exports('StartCuffAction', StartCuffAction)
exports('StartUncuffAction', StartUncuffAction)
exports('StartEscort', StartEscort)
exports('StopEscort', StopEscort)
exports('PutInVehicle', PutInVehicle)
exports('TakeOutOfVehicle', TakeOutOfVehicle)
exports('StartSearch', StartSearch)
exports('StartGSRTest', StartGSRTest)
exports('StartBreathalyzerTest', StartBreathalyzerTest)
exports('StartVehicleSearch', StartVehicleSearch)

-- =============================================
-- Weapon Fire Detection (for GSR tracking)
-- Sends event to server when any player fires
-- =============================================

local lastFireReport = 0
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            local now = GetGameTimer()
            -- Throttle: only report once per 5 seconds
            if now - lastFireReport > 5000 then
                lastFireReport = now
                TriggerServerEvent('sb_police:server:weaponFired')
            end
        end
    end
end)

-- =============================================
-- Cleanup on resource stop
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Reset player state
    if isCuffed then
        local ped = PlayerPedId()
        ClearPedTasks(ped)
        ResetPedMovementClipset(ped, 0.0)
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayAmbientAnims(ped, true)
        DisablePlayerFiring(PlayerId(), false)
        SetPlayerCanDoDriveBy(PlayerId(), true)
    end

    -- Clean up flashlight
    CleanupFlashlight()

    -- Clean up test dummy
    if testDummy and DoesEntityExist(testDummy) then
        DeleteEntity(testDummy)
        testDummy = nil
    end
end)

-- =============================================
-- TEST DUMMY SYSTEM
-- For testing police actions without another player
-- =============================================

testDummy = nil
local testDummyState = {
    cuffed = false,
    cuffType = nil,
    beingEscorted = false
}
-- isEscortingDummy declared at top of file (forward declaration for IsEscortingPlayer scope)
local dummyStashId = 'police_dummy_search'

-- Check if entity is our test dummy
function IsTestDummy(entity)
    return testDummy and entity == testDummy
end

-- Get test dummy cuff state
function IsTestDummyCuffed()
    return testDummyState.cuffed
end

-- Get test dummy escort state
function IsTestDummyBeingEscorted()
    return testDummyState.beingEscorted
end

-- Helper to load anim dict
local function LoadAnimDictAsync(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return HasAnimDictLoaded(dict)
end

-- Spawn test dummy
RegisterCommand('policedummy', function()
    -- Delete existing dummy
    if testDummy and DoesEntityExist(testDummy) then
        exports['sb_target']:RemoveTargetEntity({testDummy})
        DeleteEntity(testDummy)
        testDummy = nil
        testDummyState = { cuffed = false, cuffType = nil, beingEscorted = false }
        isEscortingDummy = false
    end

    -- Spawn position (2m in front of player)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local rad = math.rad(heading)
    local spawnPos = vector3(
        coords.x - math.sin(rad) * 2.0,
        coords.y + math.cos(rad) * 2.0,
        coords.z
    )

    -- Load model
    local model = joaat('a_m_y_skater_01')
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(model) then
        exports['sb_notify']:Notify('Failed to load model', 'error', 3000)
        return
    end

    -- Create ped
    testDummy = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z - 1.0, heading + 180.0, false, true)
    SetEntityInvincible(testDummy, true)
    FreezeEntityPosition(testDummy, true)
    SetBlockingOfNonTemporaryEvents(testDummy, true)
    SetPedCanRagdoll(testDummy, false)
    SetModelAsNoLongerNeeded(model)

    -- Make dummy face the player
    TaskTurnPedToFaceEntity(testDummy, playerPed, -1)

    -- Register target options for the dummy
    RegisterTestDummyTargets()

    -- Setup dummy stash inventory on server
    TriggerServerEvent('sb_police:server:setupDummyStash', dummyStashId)

    exports['sb_notify']:Notify('Police test dummy spawned! Hold ALT to interact.', 'success', 5000)
    print('[sb_police] ^2Test dummy spawned^7 - Entity: ' .. tostring(testDummy))
end, false)

-- Remove test dummy
RegisterCommand('removepolicedummy', function()
    if testDummy and DoesEntityExist(testDummy) then
        exports['sb_target']:RemoveTargetEntity({testDummy})
        DeleteEntity(testDummy)
        testDummy = nil
        testDummyState = { cuffed = false, cuffType = nil, beingEscorted = false }
        isEscortingDummy = false
        exports['sb_notify']:Notify('Test dummy removed', 'info', 3000)
    else
        exports['sb_notify']:Notify('No test dummy to remove', 'error', 3000)
    end
end, false)

-- Register sb_target options for test dummy
function RegisterTestDummyTargets()
    if not testDummy then return end

    exports['sb_target']:AddTargetEntity({testDummy}, {
        -- Soft Cuff (hands in front)
        {
            name = 'dummy_softcuff',
            label = 'Soft Cuff',
            icon = 'fa-hands',
            distance = 2.5,
            canInteract = function(entity)
                return not testDummyState.cuffed
            end,
            action = function(entity)
                DummyCuffAction(entity, 'soft')
            end
        },
        -- Hard Cuff (hands behind back)
        {
            name = 'dummy_hardcuff',
            label = 'Hard Cuff',
            icon = 'fa-handcuffs',
            distance = 2.5,
            canInteract = function(entity)
                return not testDummyState.cuffed
            end,
            action = function(entity)
                DummyCuffAction(entity, 'hard')
            end
        },
        -- Uncuff
        {
            name = 'dummy_uncuff',
            label = 'Uncuff',
            icon = 'fa-unlock',
            distance = 2.5,
            canInteract = function(entity)
                return testDummyState.cuffed
            end,
            action = function(entity)
                DummyUncuffAction(entity)
            end
        },
        -- Escort
        {
            name = 'dummy_escort',
            label = 'Escort',
            icon = 'fa-person-walking-arrow-right',
            distance = 2.5,
            canInteract = function(entity)
                return testDummyState.cuffed and not testDummyState.beingEscorted and not isEscortingDummy
            end,
            action = function(entity)
                DummyStartEscort(entity)
            end
        },
        -- Release
        {
            name = 'dummy_release',
            label = 'Release',
            icon = 'fa-hand',
            distance = 3.0,
            canInteract = function(entity)
                return isEscortingDummy
            end,
            action = function(entity)
                DummyStopEscort(entity)
            end
        },
        -- Search (opens inventory)
        {
            name = 'dummy_search',
            label = 'Search',
            icon = 'fa-magnifying-glass',
            distance = 2.5,
            canInteract = function(entity)
                return testDummyState.cuffed
            end,
            action = function(entity)
                DummySearchAction(entity)
            end
        },
        -- Put in vehicle
        {
            name = 'dummy_put_vehicle',
            label = 'Put In Vehicle',
            icon = 'fa-car-side',
            distance = 3.0,
            canInteract = function(entity)
                if not isEscortingDummy then return false end
                local playerCoords = GetEntityCoords(PlayerPedId())
                local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)
                return vehicle ~= 0 and DoesEntityExist(vehicle)
            end,
            action = function(entity)
                DummyPutInVehicle(entity)
            end
        },
        -- Take out of vehicle
        {
            name = 'dummy_take_out',
            label = 'Take Out',
            icon = 'fa-car-side',
            distance = 3.0,
            canInteract = function(entity)
                return IsPedInAnyVehicle(entity, false) and testDummyState.cuffed
            end,
            action = function(entity)
                DummyTakeOutOfVehicle(entity)
            end
        }
    })
end

-- =============================================
-- CUFFING WITH SYNCED ANIMATIONS
-- =============================================

-- Helper to get ground Z coordinate
local function GetGroundZ(x, y, z)
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if foundGround then
        return groundZ
    end
    return z
end

function DummyCuffAction(entity, cType)
    local playerPed = PlayerPedId()
    local duration = Config.Field.CuffDuration

    -- Get current dummy Z (don't change it)
    local dummyCoords = GetEntityCoords(testDummy)
    local dummyZ = dummyCoords.z

    -- Position dummy in front of officer for cuffing (keep same Z)
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local rad = math.rad(playerHeading)
    local newX = playerCoords.x - math.sin(rad) * 1.0
    local newY = playerCoords.y + math.cos(rad) * 1.0

    -- Use ground Z at new position
    local groundZ = GetGroundZ(newX, newY, playerCoords.z)

    -- Move dummy into position and face away from officer
    FreezeEntityPosition(testDummy, false)
    SetEntityCoordsNoOffset(testDummy, newX, newY, groundZ, false, false, false)
    SetEntityHeading(testDummy, playerHeading) -- Same direction = back to officer
    PlaceObjectOnGroundProperly(testDummy) -- Snap to ground

    -- Load animation dicts
    LoadAnimDictAsync('mp_arrest_paired')

    -- Play synced animations - officer cuffs, dummy gets cuffed
    TaskPlayAnim(playerPed, 'mp_arrest_paired', 'cop_p2_back_right', 8.0, -8.0, -1, 0, 0, false, false, false)
    TaskPlayAnim(testDummy, 'mp_arrest_paired', 'crook_p2_back_right', 8.0, -8.0, -1, 0, 0, false, false, false)

    exports['sb_notify']:Notify(cType == 'soft' and 'Applying soft cuffs...' or 'Applying hard cuffs...', 'info', duration)

    -- Wait for animation to finish
    Wait(duration)

    -- Stop officer animation
    StopAnimTask(playerPed, 'mp_arrest_paired', 'cop_p2_back_right', 1.0)

    -- Apply cuffed state
    testDummyState.cuffed = true
    testDummyState.cuffType = cType

    -- Apply appropriate cuff animation based on type
    if cType == 'soft' then
        -- Soft cuff: hands in front, more mobility
        LoadAnimDictAsync('anim@move_m@prisoner_cuffed')
        SetPedMovementClipset(testDummy, 'anim@move_m@prisoner_cuffed', 0.5)
        -- Idle with hands in front
        LoadAnimDictAsync('mp_arresting')
        TaskPlayAnim(testDummy, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        -- Hard cuff: hands behind back, restricted
        SetEnableHandcuffs(testDummy, true)
        LoadAnimDictAsync('mp_arresting')
        TaskPlayAnim(testDummy, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        SetPedMovementClipset(testDummy, 'move_m@prisoner_cuffed', 0.25)
    end

    exports['sb_notify']:Notify('Suspect cuffed (' .. cType .. ')', 'success', 3000)
    print('[sb_police] ^2Test dummy cuffed^7 - Type: ' .. cType)
end

-- Dummy uncuff action
function DummyUncuffAction(entity)
    local duration = Config.Field.UncuffDuration

    exports['sb_progressbar']:Start({
        label = 'Removing cuffs...',
        duration = duration,
        icon = 'unlock',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            testDummyState.cuffed = false
            testDummyState.cuffType = nil

            -- Stop escort if being escorted
            if isEscortingDummy then
                isEscortingDummy = false
                testDummyState.beingEscorted = false
            end

            -- Reset dummy
            ClearPedTasks(testDummy)
            SetEnableHandcuffs(testDummy, false)
            ResetPedMovementClipset(testDummy, 0.5)
            FreezeEntityPosition(testDummy, true)

            exports['sb_notify']:Notify('Suspect uncuffed', 'success', 3000)
            print('[sb_police] ^2Test dummy uncuffed^7')
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

-- =============================================
-- ESCORT - LIKE ORIGEN_POLICE (ATTACH + WALK ANIM)
-- =============================================

-- Bone index for attachment (officer's left forearm)
local BONE_L_FOREARM = 11816

function DummyStartEscort(entity)
    if not testDummyState.cuffed then
        exports['sb_notify']:Notify('Target must be cuffed first', 'error', 3000)
        return
    end

    isEscortingDummy = true
    testDummyState.beingEscorted = true

    local playerPed = PlayerPedId()

    -- Make sure dummy can move
    FreezeEntityPosition(testDummy, false)
    SetBlockingOfNonTemporaryEvents(testDummy, true)
    SetPedCanRagdoll(testDummy, false)

    -- Clear any tasks on dummy
    ClearPedTasks(testDummy)

    -- Play cuffed idle animation on dummy
    LoadAnimDictAsync('mp_arresting')
    TaskPlayAnim(testDummy, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Attach dummy to officer's arm (like origen_police)
    -- Suspect is attached to officer, positioned slightly in front/beside
    AttachEntityToEntity(
        testDummy,          -- Entity to attach (suspect)
        playerPed,          -- Entity to attach to (officer)
        BONE_L_FOREARM,     -- Officer's left forearm bone
        0.28,               -- X offset (slightly to the side)
        0.43,               -- Y offset (in front)
        0.0,                -- Z offset
        0.0, 0.0, 0.0,      -- Rotation
        false, false, false, false, 2, true
    )

    -- Play officer "holding" animation
    LoadAnimDictAsync('amb@world_human_drinking@coffee@male@base')
    TaskPlayAnim(playerPed, 'amb@world_human_drinking@coffee@male@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)

    exports['sb_notify']:Notify('Escorting suspect - walk to move them', 'info', 3000)
    print('[sb_police] ^2Started escorting test dummy^7')

    -- Escort loop - make dummy "walk" when officer moves (like origen_police)
    CreateThread(function()
        local isWalking = false

        while isEscortingDummy and testDummy and DoesEntityExist(testDummy) do
            local playerPed = PlayerPedId()

            -- Check if officer is moving
            local speed = GetEntitySpeed(playerPed)

            if speed > 0.5 then
                -- Officer is moving - make dummy walk forward
                if not isWalking then
                    isWalking = true
                end

                -- Get dummy's forward direction and issue walk task
                local dummyCoords = GetEntityCoords(testDummy)
                local dummyForward = GetEntityForwardVector(testDummy)
                local targetCoords = dummyCoords + (dummyForward * 5.0)

                -- Walk speed: 1.0 for walk, 2.0 for run
                local walkSpeed = speed > 2.0 and 2.0 or 1.0

                TaskGoStraightToCoord(
                    testDummy,
                    targetCoords.x, targetCoords.y, targetCoords.z,
                    walkSpeed,
                    -1,
                    GetEntityHeading(testDummy),
                    0.0
                )

                -- Re-attach if detached somehow
                if not IsEntityAttachedToEntity(testDummy, playerPed) then
                    AttachEntityToEntity(
                        testDummy, playerPed, BONE_L_FOREARM,
                        0.28, 0.43, 0.0,
                        0.0, 0.0, 0.0,
                        false, false, false, false, 2, true
                    )
                end

            elseif isWalking then
                -- Officer stopped - stop dummy walking, play idle
                isWalking = false
                ClearPedTasks(testDummy)
                LoadAnimDictAsync('mp_arresting')
                TaskPlayAnim(testDummy, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            Wait(100)
        end

        -- Cleanup when escort ends
        ClearPedTasks(PlayerPedId())
    end)
end

-- Dummy escort stop - detach
function DummyStopEscort(entity)
    isEscortingDummy = false
    testDummyState.beingEscorted = false

    local playerPed = PlayerPedId()

    -- Stop officer animation
    ClearPedTasks(playerPed)

    -- Detach the dummy from officer
    if testDummy and DoesEntityExist(testDummy) then
        DetachEntity(testDummy, true, false)
        ClearPedTasks(testDummy)

        -- Place on ground properly
        Wait(100)
        local dummyCoords = GetEntityCoords(testDummy)
        local groundZ = GetGroundZ(dummyCoords.x, dummyCoords.y, dummyCoords.z)
        SetEntityCoordsNoOffset(testDummy, dummyCoords.x, dummyCoords.y, groundZ, false, false, false)
        PlaceObjectOnGroundProperly(testDummy)

        -- Re-apply cuff idle animation
        if testDummyState.cuffed then
            LoadAnimDictAsync('mp_arresting')
            TaskPlayAnim(testDummy, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        end
    end

    exports['sb_notify']:Notify('Released suspect', 'info', 3000)
    print('[sb_police] ^2Stopped escorting test dummy^7')
end

-- =============================================
-- SEARCH - OPENS STASH INVENTORY
-- =============================================

function DummySearchAction(entity)
    local duration = Config.Field.SearchDuration
    local anim = Config.Field.Animations.search

    exports['sb_progressbar']:Start({
        label = 'Searching suspect...',
        duration = duration,
        icon = 'search',  -- Lucide icon
        canCancel = true,
        animation = anim,
        onComplete = function()
            -- Open the dummy's stash inventory
            TriggerServerEvent('sb_inventory:server:openInventory', 'stash', dummyStashId, {})
            exports['sb_notify']:Notify('Searching suspect pockets...', 'info', 2000)
            print('[sb_police] ^2Opened dummy search inventory^7')
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Search cancelled', 'info', 2000)
        end
    })
end

-- =============================================
-- VEHICLE TRANSPORT
-- =============================================

function DummyPutInVehicle(entity)
    if not isEscortingDummy then
        exports['sb_notify']:Notify('You must be escorting the suspect', 'error', 3000)
        return
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)

    if not vehicle or not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('No vehicle nearby', 'error', 3000)
        return
    end

    -- Find empty back seat
    local seat = nil
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for i = 1, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            seat = i
            break
        end
    end

    if not seat then
        exports['sb_notify']:Notify('No empty back seat', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        label = 'Putting suspect in vehicle...',
        duration = 2500,
        icon = 'car',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            -- Stop escort
            isEscortingDummy = false
            testDummyState.beingEscorted = false

            -- Clear tasks and warp dummy into vehicle
            ClearPedTasks(testDummy)
            TaskWarpPedIntoVehicle(testDummy, vehicle, seat)

            exports['sb_notify']:Notify('Suspect placed in vehicle', 'success', 3000)
            print('[sb_police] ^2Test dummy placed in vehicle^7 - Seat: ' .. seat)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

function DummyTakeOutOfVehicle(entity)
    if not IsPedInAnyVehicle(testDummy, false) then
        exports['sb_notify']:Notify('Suspect is not in a vehicle', 'error', 3000)
        return
    end

    exports['sb_progressbar']:Start({
        label = 'Taking suspect out of vehicle...',
        duration = 2000,
        icon = 'car',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            local vehicle = GetVehiclePedIsIn(testDummy, false)
            TaskLeaveVehicle(testDummy, vehicle, 16)

            -- Re-apply cuff animation after exiting
            CreateThread(function()
                Wait(1500)
                if testDummyState.cuffed and testDummy and DoesEntityExist(testDummy) then
                    LoadAnimDictAsync('mp_arresting')
                    TaskPlayAnim(testDummy, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                    if testDummyState.cuffType == 'hard' then
                        SetEnableHandcuffs(testDummy, true)
                    end
                end
            end)

            exports['sb_notify']:Notify('Suspect removed from vehicle', 'success', 3000)
            print('[sb_police] ^2Test dummy removed from vehicle^7')
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

-- Debug command to check dummy state
RegisterCommand('dummystate', function()
    if not testDummy then
        print('[sb_police] No test dummy exists')
        exports['sb_notify']:Notify('No test dummy exists. Use /policedummy to spawn one.', 'info', 3000)
        return
    end

    print('[sb_police] ========== DUMMY STATE ==========')
    print('  Entity:', testDummy)
    print('  Exists:', DoesEntityExist(testDummy))
    print('  Cuffed:', testDummyState.cuffed)
    print('  Cuff Type:', testDummyState.cuffType or 'none')
    print('  Being Escorted:', testDummyState.beingEscorted)
    print('  In Vehicle:', IsPedInAnyVehicle(testDummy, false))
    print('[sb_police] ==================================')

    local stateMsg = string.format('Cuffed: %s (%s) | Escorted: %s | In Vehicle: %s',
        tostring(testDummyState.cuffed),
        testDummyState.cuffType or 'none',
        tostring(testDummyState.beingEscorted),
        tostring(IsPedInAnyVehicle(testDummy, false))
    )
    exports['sb_notify']:Notify(stateMsg, 'info', 5000)
end, false)

-- =============================================
-- TACKLE SYSTEM
-- =============================================

-- Track duty status
RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    isOnDuty = onDuty
    if not onDuty then
        CleanupFlashlight()
    end
end)

-- Get closest player within range
local function GetClosestPlayerInRange(range)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDist = range

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(playerCoords - targetCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = targetPed
                end
            end
        end
    end

    return closestPlayer, closestDist
end

-- Get closest NPC within range
local function GetClosestPedInRange(range)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = range

    local handle, ped = FindFirstPed()
    local success
    repeat
        if ped ~= playerPed and DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestDist = dist
                closestPed = ped
            end
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)

    return closestPed, closestDist
end

-- Perform tackle on target
local function PerformTackle(targetPed)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)

    -- Load animation
    local animDict = Config.Tackle.Animation.dict
    local animName = Config.Tackle.Animation.anim
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end

    -- Calculate direction toward target
    local direction = targetCoords - playerCoords
    local heading = math.deg(math.atan2(-direction.x, direction.y))

    -- Set player heading toward target
    SetEntityHeading(playerPed, heading)

    -- Play dive animation
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, 800, 0, 0, false, false, false)

    -- Apply velocity toward target
    local speed = 10.0
    local normalizedDir = direction / #direction
    SetEntityVelocity(playerPed, normalizedDir.x * speed, normalizedDir.y * speed, 2.0)

    Wait(400)

    -- Check if we're close enough to actually tackle
    local newPlayerCoords = GetEntityCoords(playerPed)
    local newTargetCoords = GetEntityCoords(targetPed)
    local newDist = #(newPlayerCoords - newTargetCoords)

    if newDist < 2.0 then
        -- Successful tackle - apply ragdoll to target
        if IsPedAPlayer(targetPed) then
            -- For players, trigger server event
            local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed))
            TriggerServerEvent('sb_police:server:tacklePlayer', targetServerId)
        else
            -- For NPCs, apply ragdoll directly
            SetPedToRagdoll(targetPed, Config.Tackle.StunDuration, Config.Tackle.StunDuration, 0, false, false, false)
        end

        exports['sb_notify']:Notify('Tackle successful!', 'success', 2000)
    else
        exports['sb_notify']:Notify('Tackle missed!', 'warning', 2000)
    end

    -- Start cooldown
    tackleCooldown = true
    SetTimeout(Config.Tackle.Cooldown, function()
        tackleCooldown = false
        exports['sb_notify']:Notify('Tackle ready', 'info', 2000)
    end)
end

-- Tackle command
RegisterCommand('tackle', function()
    -- Check if on duty
    if not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    -- Check cooldown
    if tackleCooldown then
        exports['sb_notify']:Notify('Tackle on cooldown', 'error', 2000)
        return
    end

    local playerPed = PlayerPedId()

    -- Check if sprinting or moving fast
    local speed = GetEntitySpeed(playerPed)
    if speed < Config.Tackle.MinSpeed then
        exports['sb_notify']:Notify('You must be running to tackle', 'error', 2000)
        return
    end

    -- Check if in vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        exports['sb_notify']:Notify('Cannot tackle from vehicle', 'error', 2000)
        return
    end

    -- Find target (player first, then NPC)
    local targetPlayer, playerDist = GetClosestPlayerInRange(Config.Tackle.Range)
    local targetNpc, npcDist = GetClosestPedInRange(Config.Tackle.Range)

    local target = nil
    if targetPlayer and (not targetNpc or playerDist < npcDist) then
        target = targetPlayer
    elseif targetNpc then
        target = targetNpc
    end

    if not target then
        exports['sb_notify']:Notify('No target in range', 'error', 2000)
        return
    end

    PerformTackle(target)
end, false)

-- Force release escort command + keybind (X key)
RegisterCommand('releaseescort', function()
    if escortingPlayer then
        StopEscort()
        exports['sb_notify']:Notify('Released suspect', 'info', 2000)
    elseif isEscortingDummy then
        DummyStopEscort(testDummy)
    elseif isBeingEscorted then
        -- Do nothing if WE are the one being escorted
        exports['sb_notify']:Notify('You are being escorted', 'error', 2000)
    else
        exports['sb_notify']:Notify('Not escorting anyone', 'info', 2000)
    end
end, false)
RegisterKeyMapping('releaseescort', 'Release Escort', 'keyboard', 'X')

-- Register keybind for tackle (G key by default)
RegisterKeyMapping('tackle', 'Tackle Suspect', 'keyboard', 'G')

-- Event when WE get tackled
RegisterNetEvent('sb_police:client:getTackled', function(officerId)
    local ped = PlayerPedId()

    -- Apply ragdoll
    SetPedToRagdoll(ped, Config.Tackle.StunDuration, Config.Tackle.StunDuration, 0, false, false, false)

    exports['sb_notify']:Notify('You were tackled!', 'warning', 3000)
end)

-- =============================================
-- State Sync from StateBag
-- =============================================

-- Listen for our own state changes (set by server)
AddStateBagChangeHandler('cuffed', nil, function(bagName, key, value)
    local playerId = GetPlayerFromStateBagName(bagName)
    if not playerId then return end

    local myId = GetPlayerServerId(PlayerId())
    local targetId = GetPlayerServerId(playerId)

    -- Only care about our own state
    if targetId ~= myId then return end

    if value then
        -- We got cuffed via state
        if not isCuffed then
            TriggerEvent('sb_police:client:applyCuffs', value)
        end
    else
        -- We got uncuffed via state
        if isCuffed then
            TriggerEvent('sb_police:client:removeCuffs')
        end
    end
end)

-- =============================================
-- VEHICLE TARGETING OPTIONS
-- Put In Vehicle / Take Out of Vehicle
-- =============================================

-- Helper: Check if vehicle has a cuffed player inside
local function GetCuffedPlayerInVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = -1, maxPassengers - 1 do
        if not IsVehicleSeatFree(vehicle, seat) then
            local ped = GetPedInVehicleSeat(vehicle, seat)
            if ped and DoesEntityExist(ped) and IsPedAPlayer(ped) then
                local serverId = GetServerIdFromPed(ped)
                if serverId then
                    local cuffState = Player(serverId).state.cuffed
                    if cuffState then
                        return ped, serverId
                    end
                end
            end
        end
    end
    return nil
end

-- Helper: Check if vehicle has an empty back seat
local function HasEmptyBackSeat(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for i = 1, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            return true
        end
    end
    return false
end

-- Register vehicle targeting for police transport actions
CreateThread(function()
    Wait(2000) -- Wait for sb_target to load

    exports['sb_target']:AddGlobalVehicle({
        -- Put In Vehicle (when escorting)
        {
            name = 'police_put_in_vehicle',
            label = 'Put In Vehicle',
            icon = 'fa-car-side',
            distance = 4.0,
            canInteract = function(entity)
                -- Must be on duty
                if not isOnDuty then return false end
                -- Must be escorting someone (real player or dummy)
                if not escortingPlayer and not isEscortingDummy then return false end
                -- Must have empty back seat
                return HasEmptyBackSeat(entity)
            end,
            action = function(entity)
                if isEscortingDummy then
                    -- Put dummy in vehicle
                    DummyPutInVehicle(testDummy)
                elseif escortingPlayer then
                    -- Put real player in vehicle
                    PutInVehicle(entity)
                end
            end
        },
        -- Take Out of Vehicle (cuffed player inside)
        {
            name = 'police_take_out_vehicle',
            label = 'Take Out',
            icon = 'fa-person-walking-arrow-right',
            distance = 4.0,
            canInteract = function(entity)
                -- Must be on duty
                if not isOnDuty then return false end
                -- Check for cuffed player in vehicle
                local cuffedPed = GetCuffedPlayerInVehicle(entity)
                return cuffedPed ~= nil
            end,
            action = function(entity)
                local cuffedPed, serverId = GetCuffedPlayerInVehicle(entity)
                if cuffedPed and serverId then
                    TakeOutOfVehicle(cuffedPed)
                end
            end
        },
        -- Take Out Dummy (test dummy in vehicle)
        {
            name = 'police_take_out_dummy',
            label = 'Take Out (Dummy)',
            icon = 'fa-person-walking-arrow-right',
            distance = 4.0,
            canInteract = function(entity)
                -- Must be on duty
                if not isOnDuty then return false end
                -- Check if test dummy is in this vehicle
                if not testDummy or not DoesEntityExist(testDummy) then return false end
                if not IsPedInAnyVehicle(testDummy, false) then return false end
                local dummyVehicle = GetVehiclePedIsIn(testDummy, false)
                return dummyVehicle == entity and testDummyState.cuffed
            end,
            action = function(entity)
                DummyTakeOutOfVehicle(testDummy)
            end
        }
    })

    print('[sb_police:field] ^2Vehicle transport targeting registered^7')
end)
