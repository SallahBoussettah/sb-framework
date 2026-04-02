--[[
    Everyday Chaos RP - Vehicle Shop System (Client)
    Author: Salah Eddine Boussettah

    Handles: NPC spawning, shop UI, vehicle preview, test drives
]]

local SB = exports['sb_core']:GetCoreObject()
local shopOpen = false
local currentDealership = nil
local spawnedNPCs = {}
local blips = {}

-- Preview state
local previewVehicle = nil
local previewCam = nil

-- Test drive state
local testDriveVehicle = nil
local testDriveActive = false
local testDriveEndTime = 0
local testDriveDealership = nil

-- ============================================================================
-- MAP BLIPS
-- ============================================================================

local function CreateDealershipBlips()
    for dealerId, dealer in pairs(Config.Dealerships) do
        local blip = AddBlipForCoord(dealer.location.x, dealer.location.y, dealer.location.z)
        SetBlipSprite(blip, dealer.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, dealer.blip.scale)
        SetBlipColour(blip, dealer.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(dealer.blip.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- ============================================================================
-- NPC SPAWNING
-- ============================================================================

local function SpawnDealershipNPCs()
    for dealerId, dealer in pairs(Config.Dealerships) do
        local model = GetHashKey(dealer.npcModel)
        RequestModel(model)

        local timeout = 0
        while not HasModelLoaded(model) do
            Wait(10)
            timeout = timeout + 10
            if timeout > 5000 then
                print('[sb_vehicleshop] Failed to load NPC model: ' .. dealer.npcModel)
                goto continue
            end
        end

        local coords = dealer.location
        local npc = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
        SetEntityAsMissionEntity(npc, true, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedCombatAttributes(npc, 46, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)

        -- Add target
        exports['sb_target']:AddTargetEntity(npc, {
            {
                name = 'vehicleshop_browse_' .. dealerId,
                label = 'Browse Vehicles',
                icon = 'fa-car',
                distance = Config.InteractDistance,
                action = function(entity)
                    OpenVehicleShop(dealerId)
                end
            }
        })

        spawnedNPCs[#spawnedNPCs + 1] = npc

        SetModelAsNoLongerNeeded(model)

        ::continue::
    end
end

-- ============================================================================
-- VEHICLE PREVIEW
-- ============================================================================

local function DeletePreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = nil
end

local function CreatePreviewCamera(dealer)
    if previewCam then
        DestroyCam(previewCam, true)
    end

    local spawnPos = dealer.spawnPoint
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    -- Position camera to view the spawn point
    local camPos = vector3(spawnPos.x + 5.0, spawnPos.y + 5.0, spawnPos.z + 2.0)
    SetCamCoord(previewCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(previewCam, spawnPos.x, spawnPos.y, spawnPos.z + 0.5)
    SetCamFov(previewCam, 50.0)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 1000, true, true)
end

local function DestroyPreviewCamera()
    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(previewCam, true)
        previewCam = nil
    end
end

local function SpawnPreviewVehicle(model, dealer)
    DeletePreviewVehicle()

    local hash = GetHashKey(model)
    RequestModel(hash)

    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            return
        end
    end

    local spawnPos = dealer.spawnPoint
    previewVehicle = CreateVehicle(hash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, false, false)

    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetVehicleDoorsLocked(previewVehicle, 2)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)

    SetModelAsNoLongerNeeded(hash)
end

-- ============================================================================
-- OPEN / CLOSE SHOP
-- ============================================================================

function OpenVehicleShop(dealerId)
    if shopOpen then return end
    if testDriveActive then
        exports['sb_notify']:Notify('Return the test drive vehicle first!', 'error', 3000)
        return
    end

    local dealer = Config.Dealerships[dealerId]
    if not dealer then return end

    -- Check license first
    SB.Functions.TriggerCallback('sb_vehicleshop:hasLicense', function(hasLicense)
        if Config.RequireLicense and not hasLicense then
            exports['sb_notify']:Notify('You need a driver\'s license to browse vehicles!', 'error', 4000)
            return
        end

        shopOpen = true
        currentDealership = dealerId

        local ped = PlayerPedId()

        -- Hide HUD
        TriggerEvent('sb_hud:setVisible', false)

        -- Freeze player
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)

        -- Create preview camera
        CreatePreviewCamera(dealer)

        -- Get vehicles and money
        SB.Functions.TriggerCallback('sb_vehicleshop:getVehicles', function(vehicles)
            SB.Functions.TriggerCallback('sb_vehicleshop:getMoney', function(cash, bank)
                SetNuiFocus(true, true)
                SendNUIMessage({
                    action = 'open',
                    dealershipName = dealer.label,
                    dealershipId = dealerId,
                    vehicles = vehicles,
                    categories = Config.Categories,
                    cash = cash,
                    bank = bank,
                    testDriveEnabled = Config.TestDrive.enabled
                })
            end)
        end, dealerId)
    end)
end

function CloseVehicleShop()
    if not shopOpen then return end
    shopOpen = false

    local ped = PlayerPedId()

    -- Cleanup preview
    DeletePreviewVehicle()
    DestroyPreviewCamera()

    -- Unfreeze player
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)

    -- Show HUD
    TriggerEvent('sb_hud:setVisible', true)

    -- Close NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    currentDealership = nil
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseVehicleShop()
    cb('ok')
end)

RegisterNUICallback('preview', function(data, cb)
    if not currentDealership then
        cb('ok')
        return
    end

    local dealer = Config.Dealerships[currentDealership]
    SpawnPreviewVehicle(data.model, dealer)
    cb('ok')
end)

RegisterNUICallback('purchase', function(data, cb)
    if not currentDealership then
        cb('ok')
        return
    end

    TriggerServerEvent('sb_vehicleshop:server:purchase', data.model, currentDealership, data.paymentMethod)
    cb('ok')
end)

RegisterNUICallback('testDrive', function(data, cb)
    if not currentDealership then
        cb('ok')
        return
    end

    if testDriveActive then
        exports['sb_notify']:Notify('You are already on a test drive!', 'error', 3000)
        cb('ok')
        return
    end

    TriggerServerEvent('sb_vehicleshop:server:startTestDrive', data.model, currentDealership)
    CloseVehicleShop()
    cb('ok')
end)

RegisterNUICallback('rotatePreview', function(data, cb)
    if previewVehicle and DoesEntityExist(previewVehicle) then
        local currentHeading = GetEntityHeading(previewVehicle)
        SetEntityHeading(previewVehicle, currentHeading + (data.direction * 15.0))
    end
    cb('ok')
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

-- Setup purchased vehicle (spawned server-side for persistence)
RegisterNetEvent('sb_vehicleshop:client:setupPurchasedVehicle', function(data)
    -- Close shop if open
    CloseVehicleShop()

    -- Wait for server-spawned vehicle to sync
    Wait(1000)

    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    local attempts = 0

    -- Wait for vehicle to become available on client
    while (not vehicle or not DoesEntityExist(vehicle)) and attempts < 30 do
        Wait(100)
        vehicle = NetworkGetEntityFromNetworkId(data.netId)
        attempts = attempts + 1
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('Failed to locate vehicle!', 'error', 3000)
        return
    end

    -- Request network control of the vehicle
    local controlAttempts = 0
    while not NetworkHasControlOfEntity(vehicle) and controlAttempts < 30 do
        NetworkRequestControlOfEntity(vehicle)
        Wait(100)
        controlAttempts = controlAttempts + 1
    end

    -- Wait for vehicle to be fully ready
    Wait(500)

    -- IMPORTANT: Set plate on client side (OneSync server-spawned vehicles may not sync plate properly)
    SetVehicleNumberPlateText(vehicle, data.plate)

    -- Set vehicle on ground properly
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleDoorsLocked(vehicle, 1) -- Start unlocked

    -- Set as owned vehicle for sb_worldcontrol
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', data.plate, true)

    -- Set fuel if sb_fuel available
    if GetResourceState('sb_fuel') == 'started' then
        exports['sb_fuel']:SetFuel(vehicle, 100.0)
    end

    -- Warp player into vehicle
    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    exports['sb_notify']:Notify('Your new ' .. data.label .. ' is ready!', 'success', 5000)
end)

RegisterNetEvent('sb_vehicleshop:client:spawnTestDrive', function(data)
    if not currentDealership then
        currentDealership = 'pdm'
    end

    local dealer = Config.Dealerships[currentDealership]
    local spawnPos = dealer.testDriveSpawn or dealer.spawnPoint

    local hash = GetHashKey(data.model)
    RequestModel(hash)

    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            exports['sb_notify']:Notify('Failed to spawn test drive vehicle!', 'error', 3000)
            return
        end
    end

    local vehicle = CreateVehicle(hash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, data.plate)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleDoorsLocked(vehicle, 1) -- Start unlocked

    -- Mark as owned (for key system) and test drive
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', data.plate, true)
    Entity(vehicle).state:set('sb_testdrive', true, true)

    testDriveVehicle = vehicle
    testDriveActive = true
    testDriveEndTime = GetGameTimer() + (data.duration * 1000)
    testDriveDealership = currentDealership

    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    SetModelAsNoLongerNeeded(hash)

    -- FIX-006: Register vehicle netId with server for cleanup on disconnect
    local netId = VehToNet(vehicle)
    TriggerServerEvent('sb_vehicleshop:server:registerTestDriveVehicle', netId)

    exports['sb_notify']:Notify('Test drive started! You have 10 minutes. Keys given.', 'info', 5000)
end)

-- ============================================================================
-- TEST DRIVE TIMER
-- ============================================================================

CreateThread(function()
    while true do
        Wait(1000)

        if testDriveActive then
            local remaining = math.floor((testDriveEndTime - GetGameTimer()) / 1000)

            if remaining <= 0 then
                -- Time's up
                EndTestDrive(true, false)
            elseif remaining == 30 then
                exports['sb_notify']:Notify('30 seconds remaining on test drive!', 'warning', 3000)
            elseif remaining == 10 then
                exports['sb_notify']:Notify('10 seconds remaining!', 'warning', 3000)
            end
        end
    end
end)

function EndTestDrive(timeout, returned)
    if not testDriveActive then return end

    testDriveActive = false

    if testDriveVehicle and DoesEntityExist(testDriveVehicle) then
        local ped = PlayerPedId()

        -- Get player out of vehicle
        if GetVehiclePedIsIn(ped, false) == testDriveVehicle then
            TaskLeaveVehicle(ped, testDriveVehicle, 0)
            Wait(1500)
        end

        DeleteEntity(testDriveVehicle)
    end

    testDriveVehicle = nil
    testDriveDealership = nil

    TriggerServerEvent('sb_vehicleshop:server:endTestDrive')

    if timeout then
        exports['sb_notify']:Notify('Test drive ended - time expired!', 'error', 3000)
    elseif returned then
        exports['sb_notify']:Notify('Vehicle returned. Talk to the dealer to purchase.', 'success', 3000)
    else
        exports['sb_notify']:Notify('Test drive ended.', 'info', 3000)
    end
end

-- Command to end test drive early
RegisterCommand('endtestdrive', function()
    if testDriveActive then
        EndTestDrive(false, false)
    end
end, false)

-- ============================================================================
-- TEST DRIVE RETURN MARKER
-- ============================================================================

CreateThread(function()
    while true do
        local sleep = 1000

        if testDriveActive and testDriveDealership then
            local dealer = Config.Dealerships[testDriveDealership]
            if dealer then
                local returnPos = dealer.testDriveReturn or dealer.location
                local ped = PlayerPedId()
                local playerCoords = GetEntityCoords(ped)
                local distance = #(playerCoords - vector3(returnPos.x, returnPos.y, returnPos.z))

                if distance < 50.0 then
                    sleep = 0

                    -- Draw marker at return point
                    DrawMarker(
                        1,                                      -- Type (cylinder)
                        returnPos.x, returnPos.y, returnPos.z - 1.0,  -- Position
                        0.0, 0.0, 0.0,                          -- Direction
                        0.0, 0.0, 0.0,                          -- Rotation
                        3.0, 3.0, 1.0,                          -- Scale
                        249, 115, 22, 150,                      -- RGBA (orange)
                        false, false, 2, false, nil, nil, false
                    )

                    -- Check if in vehicle and close enough
                    local currentVehicle = GetVehiclePedIsIn(ped, false)
                    if distance < 5.0 and currentVehicle == testDriveVehicle then
                        -- Show prompt
                        SetTextComponentFormat('STRING')
                        AddTextComponentString('Press ~INPUT_CONTEXT~ to return vehicle')
                        DisplayHelpTextFromStringLabel(0, 0, 1, -1)

                        -- E to return vehicle
                        if IsControlJustPressed(0, 38) then -- E key
                            EndTestDrive(false, true)
                        end
                    elseif distance < 15.0 then
                        -- Show hint to get closer
                        SetTextComponentFormat('STRING')
                        AddTextComponentString('Drive to the marker to return the vehicle')
                        DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

CreateThread(function()
    while true do
        Wait(0)

        if shopOpen then
            DisableAllControlActions(0)
        end
    end
end)

-- ============================================================================
-- CAR KEYS SYSTEM
-- ============================================================================

local function GetNearbyVehicleByPlate(plate, maxDistance)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehPlate = GetVehicleNumberPlateText(vehicle)
            -- Clean and compare plates (trim whitespace)
            vehPlate = vehPlate:gsub('%s+', '')
            local searchPlate = plate:gsub('%s+', '')

            if vehPlate:upper() == searchPlate:upper() then
                local vehCoords = GetEntityCoords(vehicle)
                local distance = #(playerCoords - vehCoords)

                if distance <= (maxDistance or 10.0) then
                    return vehicle, distance
                end
            end
        end
    end

    return nil, nil
end

local function PlayKeyFobAnimation()
    local ped = PlayerPedId()
    local animDict = 'anim@mp_player_intmenu@key_fob@'

    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 2000 then return end
    end

    TaskPlayAnim(ped, animDict, 'fob_click', 8.0, -8.0, 1000, 48, 0, false, false, false)
end

local function ToggleVehicleLock(vehicle)
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    local ped = PlayerPedId()

    -- Play key fob animation
    PlayKeyFobAnimation()

    if lockStatus == 2 then
        -- Currently locked, unlock it
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)

        -- Visual/audio feedback
        SetVehicleLights(vehicle, 2)
        Wait(100)
        SetVehicleLights(vehicle, 0)
        Wait(100)
        SetVehicleLights(vehicle, 2)
        Wait(100)
        SetVehicleLights(vehicle, 0)

        -- Horn beep (unlock = 2 quick beeps)
        StartVehicleHorn(vehicle, 100, GetHashKey('HELDDOWN'), false)
        Wait(150)
        StartVehicleHorn(vehicle, 100, GetHashKey('HELDDOWN'), false)

        exports['sb_notify']:Notify('Vehicle unlocked', 'success', 2000)
    else
        -- Currently unlocked, lock it
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)

        -- Visual/audio feedback
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)

        -- Horn beep (lock = 1 beep)
        StartVehicleHorn(vehicle, 150, GetHashKey('HELDDOWN'), false)

        exports['sb_notify']:Notify('Vehicle locked', 'success', 2000)
    end
end

-- Listen for car_keys usage from inventory
RegisterNetEvent('sb_inventory:client:useItem', function(itemName, slot, metadata, category, shouldClose)
    if itemName ~= 'car_keys' then return end

    -- Get the plate from key metadata
    if not metadata or not metadata.plate then
        exports['sb_notify']:Notify('These keys have no vehicle assigned!', 'error', 3000)
        return
    end

    local plate = metadata.plate
    local vehicle, distance = GetNearbyVehicleByPlate(plate, 15.0)

    if not vehicle then
        exports['sb_notify']:Notify('No matching vehicle nearby', 'error', 3000)
        return
    end

    ToggleVehicleLock(vehicle)
end)

-- ============================================================================
-- KEYBIND: U to lock/unlock nearby vehicle
-- ============================================================================

local function GetNearestOwnedVehicle(maxDistance)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')
    local closestVeh = nil
    local closestDist = maxDistance or 10.0

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local isOwned = Entity(vehicle).state.sb_owned
            if isOwned then
                local vehCoords = GetEntityCoords(vehicle)
                local dist = #(playerCoords - vehCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestVeh = vehicle
                end
            end
        end
    end

    return closestVeh, closestDist
end

local function HasKeyForPlate(plate)
    -- Ask server if player has keys for this plate
    local hasKey = false
    local cleanPlate = plate:gsub('%s+', ''):upper()

    SB.Functions.TriggerCallback('sb_vehicleshop:hasKeyForPlate', function(result)
        hasKey = result
    end, cleanPlate)

    -- Wait for callback (with timeout)
    local timeout = 0
    while hasKey == false and timeout < 1000 do
        Wait(10)
        timeout = timeout + 10
        -- Check if callback returned true
        if hasKey then break end
    end

    return hasKey
end

-- Keybind U to lock/unlock
RegisterCommand('togglevehiclelock', function()
    local ped = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(ped, false)

    -- If inside a vehicle, lock/unlock from inside
    if currentVehicle ~= 0 then
        local isOwned = Entity(currentVehicle).state.sb_owned
        if not isOwned then
            exports['sb_notify']:Notify('This is not your vehicle', 'error', 2000)
            return
        end

        local plate = GetVehicleNumberPlateText(currentVehicle)

        SB.Functions.TriggerCallback('sb_vehicleshop:hasKeyForPlate', function(hasKey)
            if hasKey then
                ToggleVehicleLock(currentVehicle)
            else
                exports['sb_notify']:Notify('You don\'t have keys for this vehicle', 'error', 3000)
            end
        end, plate)
        return
    end

    -- Outside vehicle - find nearby owned vehicle
    local vehicle, distance = GetNearestOwnedVehicle(10.0)

    if not vehicle then
        exports['sb_notify']:Notify('No owned vehicle nearby', 'error', 2000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)

    -- Check if player has keys (via server callback)
    SB.Functions.TriggerCallback('sb_vehicleshop:hasKeyForPlate', function(hasKey)
        if hasKey then
            ToggleVehicleLock(vehicle)
        else
            exports['sb_notify']:Notify('You don\'t have keys for this vehicle', 'error', 3000)
        end
    end, plate)
end, false)

-- Bind U key
RegisterKeyMapping('togglevehiclelock', 'Lock/Unlock Vehicle', 'keyboard', 'U')

-- ============================================================================
-- BLOCK ENTRY TO LOCKED OWNED VEHICLES WITHOUT KEYS
-- FIX-004: Fixed race condition - immediately stop entry, verify async
-- ============================================================================

local isCheckingEntry = false
local entryBlocked = {}  -- Track vehicles we've blocked entry for

CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()

        -- Check if player is trying to enter a vehicle
        if IsPedTryingToEnterALockedVehicle(ped) then
            local vehicle = GetVehiclePedIsTryingToEnter(ped)

            if vehicle and DoesEntityExist(vehicle) then
                local isOwned = Entity(vehicle).state.sb_owned
                local lockStatus = GetVehicleDoorLockStatus(vehicle)

                -- Only check owned vehicles that are locked
                if isOwned and lockStatus == 2 then
                    local vehId = NetworkGetNetworkIdFromEntity(vehicle)

                    -- IMMEDIATELY stop entry attempt - don't wait for callback
                    ClearPedTasksImmediately(ped)

                    -- Only check keys once per vehicle (prevent spam)
                    if not isCheckingEntry and not entryBlocked[vehId] then
                        isCheckingEntry = true
                        entryBlocked[vehId] = true

                        local plate = GetVehicleNumberPlateText(vehicle)

                        -- Check if player has keys
                        SB.Functions.TriggerCallback('sb_vehicleshop:hasKeyForPlate', function(hasKey)
                            if hasKey then
                                -- Player has keys, unlock temporarily for entry
                                if DoesEntityExist(vehicle) then
                                    SetVehicleDoorsLocked(vehicle, 1)
                                    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                                    exports['sb_notify']:Notify('Unlocked with key', 'success', 2000)

                                    -- Re-lock after 3 seconds if player didn't enter
                                    SetTimeout(3000, function()
                                        if DoesEntityExist(vehicle) then
                                            local currentPed = PlayerPedId()
                                            local inVeh = GetVehiclePedIsIn(currentPed, false)
                                            if inVeh ~= vehicle then
                                                -- Player didn't enter, re-lock
                                                SetVehicleDoorsLocked(vehicle, 2)
                                                SetVehicleDoorsLockedForAllPlayers(vehicle, true)
                                            end
                                        end
                                    end)
                                end
                            else
                                exports['sb_notify']:Notify('Vehicle is locked - you need the keys', 'error', 3000)
                            end

                            -- Clear entry block after 2 seconds
                            SetTimeout(2000, function()
                                entryBlocked[vehId] = nil
                            end)

                            isCheckingEntry = false
                        end, plate)
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- KEEP CAR LOCKED WHEN EXITING
-- ============================================================================

local lastVehicle = nil
local lastVehicleWasLocked = false

CreateThread(function()
    while true do
        Wait(100)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            -- Player is in a vehicle - track it
            lastVehicle = vehicle
            lastVehicleWasLocked = GetVehicleDoorLockStatus(vehicle) == 2
        elseif lastVehicle and DoesEntityExist(lastVehicle) then
            -- Player just exited - re-lock if it was locked
            if lastVehicleWasLocked then
                SetVehicleDoorsLocked(lastVehicle, 2)
                SetVehicleDoorsLockedForAllPlayers(lastVehicle, true)
            end
            lastVehicle = nil
            lastVehicleWasLocked = false
        end
    end
end)

-- ============================================================================
-- ENGINE SYSTEM (Requires Keys for ALL Owned Vehicles)
-- FIX-003: Fixed race condition - engine blocked until keys confirmed
-- Owned vehicles, rentals, AND test drives all require keys
-- ============================================================================

local currentVehicleHasKeys = nil  -- nil = checking, true = has keys, false = no keys
local currentVehiclePlate = nil
local lastCheckedVehicle = 0
local isOwnedVehicle = false  -- Track if current vehicle is owned

-- Check keys when entering vehicle
CreateThread(function()
    while true do
        Wait(200)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            -- Only for driver
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                -- New vehicle entered
                if vehicle ~= lastCheckedVehicle then
                    lastCheckedVehicle = vehicle
                    currentVehicleHasKeys = nil  -- Reset to checking state

                    local owned = Entity(vehicle).state.sb_owned

                    -- Owned vehicles (including rentals and test drives): require keys
                    if owned then
                        isOwnedVehicle = true
                        currentVehiclePlate = GetVehicleNumberPlateText(vehicle)

                        -- IMMEDIATELY turn off engine and keep it off until keys confirmed
                        SetVehicleEngineOn(vehicle, false, false, true)

                        -- Check for keys
                        SB.Functions.TriggerCallback('sb_vehicleshop:hasKeyForPlate', function(hasKey)
                            currentVehicleHasKeys = hasKey
                            if not hasKey then
                                exports['sb_notify']:Notify('You need the keys to start this vehicle', 'error', 3000)
                            end
                        end, currentVehiclePlate)
                    else
                        -- Not owned - NPC vehicle, allow everything
                        isOwnedVehicle = false
                        currentVehicleHasKeys = true
                    end
                end
            end
        else
            -- Exited vehicle
            lastCheckedVehicle = 0
            currentVehicleHasKeys = nil
            currentVehiclePlate = nil
            isOwnedVehicle = false
        end
    end
end)

-- Block engine for vehicles without keys (FIX-003: Block while checking too)
CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            -- For owned vehicles (NOT rentals): Block if no keys OR still checking (nil)
            -- This prevents the race condition where engine starts before callback returns
            if isOwnedVehicle and currentVehicleHasKeys ~= true then
                -- Block engine from turning on
                if GetIsVehicleEngineRunning(vehicle) then
                    SetVehicleEngineOn(vehicle, false, false, true)
                end

                -- Show message when pressing W
                if IsControlJustPressed(0, 71) then
                    if currentVehicleHasKeys == nil then
                        exports['sb_notify']:Notify('Checking for keys...', 'info', 1500)
                    else
                        exports['sb_notify']:Notify('You need the keys to start this vehicle', 'error', 3000)
                    end
                end
            end
        end
    end
end)

-- Toggle engine with G key
RegisterCommand('toggleengine', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    -- If no keys, block
    if currentVehicleHasKeys == false then
        exports['sb_notify']:Notify('You need the keys to start this vehicle', 'error', 3000)
        return
    end

    -- Toggle engine
    local engineRunning = GetIsVehicleEngineRunning(vehicle)
    SetVehicleEngineOn(vehicle, not engineRunning, false, true)
end, false)

RegisterKeyMapping('toggleengine', 'Toggle Vehicle Engine', 'keyboard', 'G')

-- ============================================================================
-- VEHICLE TRANSFER / SELL
-- ============================================================================

local function FindNearestOwnedVehiclePlate()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')
    local closestVeh = nil
    local closestDist = 10.0

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local isOwned = Entity(vehicle).state.sb_owned
            if isOwned then
                local vehCoords = GetEntityCoords(vehicle)
                local dist = #(playerCoords - vehCoords)
                if dist < closestDist then
                    closestDist = dist
                    closestVeh = vehicle
                end
            end
        end
    end

    if not closestVeh then
        return nil
    end

    return GetVehicleNumberPlateText(closestVeh)
end

RegisterNetEvent('sb_vehicleshop:client:initTransfer', function(targetId, price)
    local plate = FindNearestOwnedVehiclePlate()

    if not plate then
        exports['sb_notify']:Notify('No owned vehicle nearby', 'error', 3000)
        return
    end

    TriggerServerEvent('sb_vehicleshop:server:transferVehicle', plate, targetId, price)
end)

RegisterNetEvent('sb_vehicleshop:client:initGiveKey', function(targetId)
    local plate = FindNearestOwnedVehiclePlate()

    if not plate then
        exports['sb_notify']:Notify('No owned vehicle nearby', 'error', 3000)
        return
    end

    TriggerServerEvent('sb_vehicleshop:server:giveKey', plate, targetId)
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

CreateThread(function()
    Wait(2000)
    CreateDealershipBlips()
    SpawnDealershipNPCs()

    -- Add chat suggestions for commands
    if exports['sb_chat'] then
        exports['sb_chat']:AddSuggestion('/sellvehicle', 'Sell your nearby vehicle to a player', {
            { name = 'playerid', help = 'Target player ID' },
            { name = 'price', help = 'Sale price ($)' }
        })
        exports['sb_chat']:AddSuggestion('/givekey', 'Give your car key to another player', {
            { name = 'playerid', help = 'Target player ID' }
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Cleanup NPCs
    for _, npc in ipairs(spawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    -- Cleanup blips
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    -- Cleanup preview
    DeletePreviewVehicle()
    DestroyPreviewCamera()

    -- Cleanup test drive
    if testDriveVehicle and DoesEntityExist(testDriveVehicle) then
        DeleteEntity(testDriveVehicle)
    end
    testDriveVehicle = nil
    testDriveActive = false
    testDriveDealership = nil

    if shopOpen then
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetNuiFocus(false, false)
    end
end)
