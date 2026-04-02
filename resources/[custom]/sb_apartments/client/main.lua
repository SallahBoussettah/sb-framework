-- sb_apartments Client
-- MLO-direct apartment system with door locking

local SBCore = exports['sb_core']:GetCoreObject()

-- ============================================
-- STATE
-- ============================================
local PlayerData = {}
local myRentals = {}
local myKeys = {}
local currentUnit = nil
local currentBuilding = nil
local isInsideApartment = false
local isVisitor = false
local buildingBlips = {}
local myApartmentBlips = {}
local interiorZones = {}
local elevatorZones = {}
local garageNPCs = {}
local currentFloor = nil
local pendingDoorbell = nil  -- { unitId, visitorSrc, visitorName }

-- ============================================
-- INITIALIZATION
-- ============================================

CreateThread(function()
    while not SBCore do
        Wait(100)
        SBCore = exports['sb_core']:GetCoreObject()
    end

    while not SBCore.Functions.GetPlayerData().citizenid do
        Wait(500)
    end

    PlayerData = SBCore.Functions.GetPlayerData()
    TriggerServerEvent('sb_apartments:server:getMyRentals')

    Wait(1000)
    SetupBuildingBlips()
    SetupTargetZones()
    SetupGarageNPCs()
    SetupRentalNPCs()
end)

RegisterNetEvent('SBCore:Client:OnPlayerLoaded', function()
    PlayerData = SBCore.Functions.GetPlayerData()
    TriggerServerEvent('sb_apartments:server:getMyRentals')
end)

RegisterNetEvent('SBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    myRentals = {}
    myKeys = {}
    RemoveMyApartmentBlips()
end)

-- ============================================
-- BLIP SYSTEM
-- ============================================

function SetupBuildingBlips()
    for buildingId, building in pairs(Config.Buildings) do
        -- Building blip
        local blip = AddBlipForCoord(building.blip.x, building.blip.y, building.blip.z)
        SetBlipSprite(blip, Config.Blips.building.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blips.building.scale)
        SetBlipColour(blip, Config.Blips.building.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(building.name)
        EndTextCommandSetBlipName(blip)
        buildingBlips[buildingId] = blip

        -- Garage blip
        if building.hasGarage and building.garage then
            local gBlip = AddBlipForCoord(building.garage.blipPos.x, building.garage.blipPos.y, building.garage.blipPos.z)
            SetBlipSprite(gBlip, Config.Blips.garage.sprite)
            SetBlipDisplay(gBlip, 4)
            SetBlipScale(gBlip, Config.Blips.garage.scale)
            SetBlipColour(gBlip, Config.Blips.garage.color)
            SetBlipAsShortRange(gBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(building.name .. ' Parking')
            EndTextCommandSetBlipName(gBlip)
            buildingBlips[buildingId .. '_garage'] = gBlip
        end
    end
end

function UpdateMyApartmentBlips()
    RemoveMyApartmentBlips()

    for _, rental in ipairs(myRentals) do
        local buildingId, building = Config.GetBuildingByUnit(rental.unit_id)
        if building then
            local unit = building.units[rental.unit_id]
            local blipCoords = (unit and unit.door) or building.blip
            local blip = AddBlipForCoord(blipCoords.x, blipCoords.y, blipCoords.z)
            SetBlipSprite(blip, Config.Blips.myApartment.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blips.myApartment.scale)
            SetBlipColour(blip, Config.Blips.myApartment.color)
            SetBlipAsShortRange(blip, false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString('My Apartment - ' .. (unit and unit.label or rental.unit_id))
            EndTextCommandSetBlipName(blip)
            table.insert(myApartmentBlips, blip)
        end
    end

    for _, key in ipairs(myKeys) do
        local buildingId, building = Config.GetBuildingByUnit(key.unit_id)
        if building then
            local unit = building.units[key.unit_id]
            local blipCoords = (unit and unit.door) or building.blip
            local blip = AddBlipForCoord(blipCoords.x, blipCoords.y, blipCoords.z)
            SetBlipSprite(blip, Config.Blips.keyAccess.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blips.keyAccess.scale)
            SetBlipColour(blip, Config.Blips.keyAccess.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString('Key Access - ' .. (unit and unit.label or key.unit_id))
            EndTextCommandSetBlipName(blip)
            table.insert(myApartmentBlips, blip)
        end
    end
end

function RemoveMyApartmentBlips()
    for _, blip in ipairs(myApartmentBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    myApartmentBlips = {}
end

-- ============================================
-- TARGET ZONES (building entrance + unit doors)
-- Correct API: AddBoxZone(name, coords, width, length, height, heading, optionsArray)
-- Each option needs: name, label, icon (fa-X without 'fas'), distance, action
-- ============================================

function SetupTargetZones()
    for buildingId, building in pairs(Config.Buildings) do
        -- Building entrance zone
        exports['sb_target']:AddBoxZone(
            'apt_building_' .. buildingId,
            building.entrance.coords,
            2.0, 2.0, 3.0,
            building.entrance.heading,
            {
                {
                    name = 'apt_view_' .. buildingId,
                    icon = 'fa-building',
                    label = 'View Available Apartments',
                    distance = 2.5,
                    action = function()
                        OpenBuildingMenu(buildingId)
                    end
                }
            }
        )

        -- Elevator zones
        if building.hasElevator and building.elevator then
            SetupElevatorZones(buildingId, building)
        end

        -- Unit door zones (for doorbell + quick enter)
        for unitId, unit in pairs(building.units) do
            if unit.door and unit.door.x ~= 0 then
                local doorOptions = {
                    {
                        name = 'apt_enter_' .. unitId,
                        icon = 'fa-door-open',
                        label = 'Enter Apartment',
                        distance = 2.0,
                        action = function()
                            EnterApartment(buildingId, unitId)
                        end,
                        canInteract = function()
                            return PlayerHasAccess(unitId)
                        end
                    },
                    {
                        name = 'apt_lock_' .. unitId,
                        icon = 'fa-lock',
                        label = 'Lock Door',
                        distance = 2.0,
                        action = function()
                            TriggerServerEvent('sb_apartments:server:toggleDoorLock', unitId)
                        end,
                        canInteract = function()
                            return PlayerHasAccess(unitId) and not IsDoorLocked(unitId)
                        end
                    },
                    {
                        name = 'apt_unlock_' .. unitId,
                        icon = 'fa-lock-open',
                        label = 'Unlock Door',
                        distance = 2.0,
                        action = function()
                            TriggerServerEvent('sb_apartments:server:toggleDoorLock', unitId)
                        end,
                        canInteract = function()
                            return PlayerHasAccess(unitId) and IsDoorLocked(unitId)
                        end
                    },
                    {
                        name = 'apt_knock_' .. unitId,
                        icon = 'fa-hand',
                        label = 'Knock',
                        distance = 2.0,
                        action = function()
                            RingDoorbell(unitId)
                        end,
                        canInteract = function()
                            return not PlayerHasAccess(unitId)
                        end
                    }
                }

                exports['sb_target']:AddBoxZone(
                    'apt_door_' .. unitId,
                    unit.door,
                    1.5, 1.5, 3.0,
                    unit.doorHeading or 0.0,
                    doorOptions
                )
            end
        end
    end
end

-- ============================================
-- ELEVATOR SYSTEM
-- Correct API: AddSphereZone(name, coords, radius, optionsArray)
-- ============================================

function SetupElevatorZones(buildingId, building)
    local elevator = building.elevator
    if not elevator or not elevator.floors then return end

    for floorNum, floorData in pairs(elevator.floors) do
        local zoneName = 'elevator_' .. buildingId .. '_floor_' .. floorNum
        local radius = elevator.interactRadius or 1.5

        local options = {}
        for targetFloor, targetData in pairs(elevator.floors) do
            if targetFloor ~= floorNum then
                local icon = targetFloor > floorNum and 'fa-arrow-up' or 'fa-arrow-down'
                table.insert(options, {
                    name = 'elevator_' .. buildingId .. '_' .. floorNum .. '_to_' .. targetFloor,
                    label = 'Go to ' .. targetData.label,
                    icon = icon,
                    distance = 2.5,
                    action = function()
                        UseElevator(buildingId, floorNum, targetFloor)
                    end
                })
            end
        end

        exports['sb_target']:AddSphereZone(
            zoneName,
            floorData.coords,
            radius,
            options
        )
        table.insert(elevatorZones, zoneName)
    end
end

function UseElevator(buildingId, fromFloor, toFloor)
    local building = Config.Buildings[buildingId]
    if not building or not building.elevator then return end

    local targetFloor = building.elevator.floors[toFloor]
    if not targetFloor then return end

    local travelTime = building.elevator.travelTime or 2000
    local ped = PlayerPedId()
    local exitPos = targetFloor.exit or targetFloor.coords
    local exitHeading = targetFloor.exitHeading or targetFloor.heading

    -- Fade + progress bar
    DoScreenFadeOut(500)
    Wait(600)

    exports['sb_notify']:Notify('Elevator moving to ' .. targetFloor.label .. '...', 'info', travelTime)

    -- Play elevator ding sound
    PlaySoundFrontend(-1, 'ELEVATOR_OPEN', 'MP_MISSION_COUNTDOWN_SOUNDSET', false)

    Wait(travelTime)

    SetEntityCoordsNoOffset(ped, exitPos.x, exitPos.y, exitPos.z, false, false, false)
    SetEntityHeading(ped, exitHeading)

    -- Wait for collision
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 50 do
        RequestCollisionAtCoord(exitPos.x, exitPos.y, exitPos.z)
        Wait(50)
        timeout = timeout + 1
    end

    Wait(300)
    currentFloor = toFloor

    -- Play arrival ding
    PlaySoundFrontend(-1, 'ELEVATOR_OPEN', 'MP_MISSION_COUNTDOWN_SOUNDSET', false)

    DoScreenFadeIn(500)
end

-- ============================================
-- GARAGE NPCS
-- Correct API: AddTargetEntity(entity, optionsArray)
-- ============================================

function SetupGarageNPCs()
    for buildingId, building in pairs(Config.Buildings) do
        if building.hasGarage and building.garage then
            local garage = building.garage
            SpawnGarageNPC(buildingId, garage)
        end
    end
end

function SpawnGarageNPC(buildingId, garage)
    local model = GetHashKey(garage.npcModel or 's_m_y_valet_01')
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then return end

    local npc = CreatePed(4, model, garage.npcPos.x, garage.npcPos.y, garage.npcPos.z - 1.0, garage.npcHeading, false, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    SetModelAsNoLongerNeeded(model)

    garageNPCs[buildingId] = npc

    -- Target options on NPC
    exports['sb_target']:AddTargetEntity(npc, {
        {
            name = 'apt_garage_store_' .. buildingId,
            icon = 'fa-car',
            label = 'Store Vehicle',
            distance = 3.0,
            action = function()
                StoreVehicleAtApartment(buildingId)
            end,
            canInteract = function()
                return PlayerHasAnyRentalInBuilding(buildingId) and IsPedInAnyVehicle(PlayerPedId(), false)
            end
        },
        {
            name = 'apt_garage_get_' .. buildingId,
            icon = 'fa-key',
            label = 'Get Vehicle',
            distance = 3.0,
            action = function()
                OpenGarageMenu(buildingId)
            end,
            canInteract = function()
                return PlayerHasAnyRentalInBuilding(buildingId) and not IsPedInAnyVehicle(PlayerPedId(), false)
            end
        }
    })
end

-- ============================================
-- RENTAL NPCs (lobby concierge for renting)
-- ============================================

local rentalNPCs = {}

function SetupRentalNPCs()
    for buildingId, building in pairs(Config.Buildings) do
        if building.rentalNPC then
            SpawnRentalNPC(buildingId, building)
        end
    end
end

function SpawnRentalNPC(buildingId, building)
    local npcCfg = building.rentalNPC
    local model = GetHashKey(npcCfg.model or 'a_f_y_business_04')
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then return end

    local npc = CreatePed(4, model, npcCfg.pos.x, npcCfg.pos.y, npcCfg.pos.z - 1.0, npcCfg.heading, false, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    SetModelAsNoLongerNeeded(model)

    rentalNPCs[buildingId] = npc

    exports['sb_target']:AddTargetEntity(npc, {
        {
            name = 'apt_rental_npc_' .. buildingId,
            icon = 'fa-building',
            label = 'View Available Apartments',
            distance = 5.0,
            action = function()
                OpenBuildingMenu(buildingId)
            end
        }
    })
end

function StoreVehicleAtApartment(buildingId)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        exports['sb_notify']:Notify('You are not in a vehicle', 'error', 3000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local unitId = GetPlayerRentalInBuilding(buildingId)
    if not unitId then
        exports['sb_notify']:Notify('You don\'t have an apartment here', 'error', 3000)
        return
    end

    -- Check vehicle is owned
    if not Entity(vehicle).state.sb_owned then
        exports['sb_notify']:Notify('This is not your vehicle', 'error', 3000)
        return
    end

    SBCore.Functions.TriggerCallback('sb_apartments:server:storeVehicle', function(success)
        if success then
            -- Exit vehicle first
            TaskLeaveVehicle(ped, vehicle, 0)
            Wait(1500)

            -- Fade out and delete
            DoScreenFadeOut(500)
            Wait(500)
            DeleteEntity(vehicle)
            Wait(300)
            DoScreenFadeIn(500)

            exports['sb_notify']:Notify('Vehicle stored in apartment garage', 'success', 3000)
        end
    end, unitId, plate)
end

function OpenGarageMenu(buildingId)
    local unitId = GetPlayerRentalInBuilding(buildingId)
    if not unitId then
        exports['sb_notify']:Notify('You don\'t have an apartment here', 'error', 3000)
        return
    end

    SBCore.Functions.TriggerCallback('sb_apartments:server:getGarageVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            exports['sb_notify']:Notify('No vehicles stored', 'info', 3000)
            return
        end

        -- Send to NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openGarage',
            vehicles = vehicles,
            unitId = unitId
        })
    end, unitId)
end

-- ============================================
-- DOOR LOCK INTEGRATION (via sb_doorlock)
-- All apartment doors registered in sb_doorlock config.
-- sb_apartments server manages temp unlocks and owner toggles.
-- ============================================

function IsDoorLocked(unitId)
    if GetResourceState('sb_doorlock') ~= 'started' then return true end
    local state = exports['sb_doorlock']:GetDoorState('apt_' .. unitId)
    if state == nil then return true end  -- not found = treat as locked
    return state
end

-- Server notify helper (sb_notify has no server export)
RegisterNetEvent('sb_apartments:client:notify', function(msg, notifType, duration)
    exports['sb_notify']:Notify(msg, notifType, duration)
end)

-- ============================================
-- ENTRY / EXIT SYSTEM (MLO-direct mode)
-- ============================================

function EnterApartment(buildingId, unitId)
    SBCore.Functions.TriggerCallback('sb_apartments:server:enterApartment', function(data)
        if not data then
            exports['sb_notify']:Notify('Access denied', 'error', 3000)
            return
        end

        local building = Config.Buildings[buildingId]
        local unit = building and building.units[unitId]

        -- Store state
        currentBuilding = buildingId
        currentUnit = unitId
        isInsideApartment = true
        isVisitor = (data.accessType == 'visitor')

        -- Server already temp-unlocked the door via sb_doorlock
        PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_MISSION_COUNTDOWN_SOUNDSET', false)

        -- Setup stash/wardrobe targets at fixed MLO positions
        SetupInteriorTargets(data)

        exports['sb_notify']:Notify('Welcome to ' .. (unit and unit.label or unitId), 'success', 3000)
    end, buildingId, unitId)
end

function ExitApartment()
    if not isInsideApartment then return end

    local savedUnit = currentUnit

    -- Tell server
    TriggerServerEvent('sb_apartments:server:exitApartment')

    -- Clear interior targets
    ClearInteriorTargets()

    -- Reset state
    currentBuilding = nil
    currentUnit = nil
    isInsideApartment = false
    isVisitor = false
end

-- Force exit (from server - eviction, key revoke, etc.)
function ForceExit()
    if not isInsideApartment then return end

    local savedUnit = currentUnit

    ClearInteriorTargets()

    -- Reset state
    currentBuilding = nil
    currentUnit = nil
    isInsideApartment = false
    isVisitor = false

end

-- ============================================
-- INTERIOR TARGETS (fixed world coords from config)
-- ============================================

function SetupInteriorTargets(data)
    local building = Config.Buildings[data.buildingId]
    if not building then return end
    local unit = building.units[data.unitId]
    if not unit then return end

    -- Exit zone near door (from inside)
    exports['sb_target']:AddBoxZone(
        'apt_exit_' .. data.unitId,
        unit.door,
        1.5, 1.5, 2.0,
        unit.doorHeading or 0.0,
        {
            {
                name = 'apt_leave_' .. data.unitId,
                icon = 'fa-door-open',
                label = 'Leave Apartment',
                distance = 2.0,
                action = function()
                    ExitApartment()
                end
            }
        }
    )
    table.insert(interiorZones, 'apt_exit_' .. data.unitId)

    -- Stash zone (owner/keyholder only, not visitors)
    if unit.stashPos and not isVisitor then
        exports['sb_target']:AddBoxZone(
            'apt_stash_' .. data.unitId,
            unit.stashPos,
            1.0, 1.0, 1.5,
            0.0,
            {
                {
                    name = 'apt_stash_open_' .. data.unitId,
                    icon = 'fa-box',
                    label = 'Open Storage',
                    distance = 1.5,
                    action = function()
                        OpenApartmentStash(data.unitId, data.tier)
                    end
                }
            }
        )
        table.insert(interiorZones, 'apt_stash_' .. data.unitId)
    end

    -- Wardrobe zone (owner/keyholder only, not visitors)
    if unit.wardrobePos and not isVisitor then
        exports['sb_target']:AddBoxZone(
            'apt_wardrobe_' .. data.unitId,
            unit.wardrobePos,
            1.0, 1.0, 1.5,
            0.0,
            {
                {
                    name = 'apt_wardrobe_open_' .. data.unitId,
                    icon = 'fa-tshirt',
                    label = 'Open Wardrobe',
                    distance = 1.5,
                    action = function()
                        OpenApartmentWardrobe(data.unitId)
                    end
                }
            }
        )
        table.insert(interiorZones, 'apt_wardrobe_' .. data.unitId)
    end
end

function ClearInteriorTargets()
    for _, zoneName in ipairs(interiorZones) do
        exports['sb_target']:RemoveZone(zoneName)
    end
    interiorZones = {}
end

-- ============================================
-- STASH & WARDROBE
-- ============================================

function OpenApartmentStash(unitId, tier)
    local stashId = 'apartment_' .. unitId
    local slots = Config.GetStashSlots(tier)
    TriggerServerEvent('sb_inventory:server:openInventory', 'stash', stashId, {
        slots = slots,
        label = 'Apartment Storage'
    })
end

function OpenApartmentWardrobe(unitId)
    exports['sb_notify']:Notify('Wardrobe coming soon!', 'info', 3000)
end

-- ============================================
-- DOORBELL SYSTEM (Client side)
-- ============================================

function RingDoorbell(unitId)
    -- Play doorbell sound
    PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_MISSION_COUNTDOWN_SOUNDSET', false)
    TriggerServerEvent('sb_apartments:server:ringDoorbell', unitId)
end

-- Received doorbell ring (as apartment occupant/owner)
RegisterNetEvent('sb_apartments:client:doorbellRing', function(unitId, visitorSrc, visitorName)
    pendingDoorbell = { unitId = unitId, visitorSrc = visitorSrc, visitorName = visitorName }

    -- Play doorbell sound
    PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_MISSION_COUNTDOWN_SOUNDSET', false)

    -- Show NUI doorbell popup
    SendNUIMessage({
        action = 'doorbellRing',
        visitorName = visitorName,
        timeout = Config.DoorbellTimeout
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('acceptVisitor', function(data, cb)
    SetNuiFocus(false, false)
    if pendingDoorbell then
        TriggerServerEvent('sb_apartments:server:acceptVisitor', pendingDoorbell.unitId, pendingDoorbell.visitorSrc)
        pendingDoorbell = nil
    end
    cb('ok')
end)

RegisterNUICallback('denyVisitor', function(data, cb)
    SetNuiFocus(false, false)
    if pendingDoorbell then
        TriggerServerEvent('sb_apartments:server:denyVisitor', pendingDoorbell.unitId, pendingDoorbell.visitorSrc)
        pendingDoorbell = nil
    end
    cb('ok')
end)

RegisterNetEvent('sb_apartments:client:doorbellExpired', function(unitId)
    pendingDoorbell = nil
    SendNUIMessage({ action = 'doorbellExpired' })
end)

RegisterNetEvent('sb_apartments:client:doorbellDenied', function(unitId)
    SendNUIMessage({ action = 'doorbellDenied' })
end)

-- Visitor enters apartment (after doorbell accepted) - MLO direct mode
RegisterNetEvent('sb_apartments:client:visitorEnter', function(data)
    local building = Config.Buildings[data.buildingId]
    local unit = building and building.units[data.unitId]

    -- Play door sound
    PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_MISSION_COUNTDOWN_SOUNDSET', false)

    -- Set state
    currentBuilding = data.buildingId
    currentUnit = data.unitId
    isInsideApartment = true
    isVisitor = true

    -- Setup interior targets (visitor mode - no stash/wardrobe)
    SetupInteriorTargets(data)

    exports['sb_notify']:Notify('You are visiting this apartment', 'info', 3000)
end)

-- ============================================
-- BUILDING MENU (NUI)
-- ============================================

function OpenBuildingMenu(buildingId)
    local building = Config.Buildings[buildingId]
    if not building then return end

    SBCore.Functions.TriggerCallback('sb_apartments:server:getBuildingUnits', function(unitsData)
        local units = {}
        local floors = {}

        for unitId, unit in pairs(building.units) do
            local unitInfo = {
                id = unitId,
                label = unit.label,
                floor = unit.floor or 1,
                rent = unit.rent,
                deposit = unit.rent * Config.DepositMultiplier,
                hasGarage = building.hasGarage or false,
                isRented = false,
                isOwn = false,
                hasKey = false
            }

            for _, rental in pairs(unitsData) do
                if rental.unit_id == unitId then
                    unitInfo.isRented = true
                    if rental.citizenid == PlayerData.citizenid then
                        unitInfo.isOwn = true
                    end
                    break
                end
            end

            for _, key in ipairs(myKeys) do
                if key.unit_id == unitId then
                    unitInfo.hasKey = true
                    break
                end
            end

            table.insert(units, unitInfo)

            -- Track floors
            if unit.floor and not floors[unit.floor] then
                floors[unit.floor] = true
            end
        end

        table.sort(units, function(a, b) return a.rent < b.rent end)

        -- Build floor list
        local floorList = {}
        for f in pairs(floors) do
            table.insert(floorList, f)
        end
        table.sort(floorList)

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openBuilding',
            building = {
                id = buildingId,
                name = building.name,
                description = building.description,
                tier = building.tier,
                hasGarage = building.hasGarage or false
            },
            units = units,
            floors = floorList,
            playerMoney = {
                cash = PlayerData.money.cash,
                bank = PlayerData.money.bank
            }
        })
    end, buildingId)
end

-- ============================================
-- MANAGEMENT MENU
-- ============================================

function OpenManagementMenu(buildingId, unitId)
    local building = Config.Buildings[buildingId]
    if not building then return end

    local unit = building.units[unitId]
    if not unit then return end

    SBCore.Functions.TriggerCallback('sb_apartments:server:getUnitDetails', function(details)
        if not details then
            exports['sb_notify']:Notify('Could not load unit details', 'error', 3000)
            return
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openManagement',
            unit = {
                id = unitId,
                buildingId = buildingId,
                label = unit.label,
                rent = unit.rent,
                hasGarage = building.hasGarage or false
            },
            rental = details.rental,
            keys = details.keys,
            isOwner = details.isOwner,
            maxKeys = Config.MaxKeysPerUnit
        })
    end, buildingId, unitId)
end

-- ============================================
-- NUI CALLBACKS
-- ============================================

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    pendingDoorbell = nil
    cb('ok')
end)

RegisterNUICallback('rentUnit', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('sb_apartments:server:rentUnit', data.buildingId, data.unitId, data.paymentMethod)
    cb('ok')
end)

RegisterNUICallback('enterUnit', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    EnterApartment(data.buildingId, data.unitId)
    cb('ok')
end)

RegisterNUICallback('manageUnit', function(data, cb)
    -- Don't close NUI focus here — OpenManagementMenu re-opens it after server callback
    OpenManagementMenu(data.buildingId, data.unitId)
    cb('ok')
end)

RegisterNUICallback('setGPS', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    local buildingId, building = Config.GetBuildingByUnit(data.unitId)
    if building then
        SetNewWaypoint(building.blip.x, building.blip.y)
        exports['sb_notify']:Notify('GPS set to apartment building', 'info', 3000)
    end
    cb('ok')
end)

RegisterNUICallback('giveKey', function(data, cb)
    local nearbyPlayers = SBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 5.0)
    local playerList = {}

    for _, player in ipairs(nearbyPlayers) do
        if player ~= PlayerId() then
            table.insert(playerList, {
                id = GetPlayerServerId(player),
                name = GetPlayerName(player)
            })
        end
    end

    if #playerList == 0 then
        exports['sb_notify']:Notify('No nearby players to give keys to', 'error', 3000)
        cb('ok')
        return
    end

    SendNUIMessage({
        action = 'showPlayerList',
        players = playerList,
        unitId = data.unitId
    })
    cb('ok')
end)

RegisterNUICallback('confirmGiveKey', function(data, cb)
    TriggerServerEvent('sb_apartments:server:giveKey', data.unitId, data.playerId)
    cb('ok')
end)

RegisterNUICallback('revokeKey', function(data, cb)
    TriggerServerEvent('sb_apartments:server:revokeKey', data.unitId, data.citizenid)
    cb('ok')
end)

RegisterNUICallback('endRental', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('sb_apartments:server:endRental', data.unitId)
    cb('ok')
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    SBCore.Functions.TriggerCallback('sb_apartments:server:retrieveVehicle', function(success, netId)
        if success then
            exports['sb_notify']:Notify('Vehicle delivered', 'success', 3000)
        else
            exports['sb_notify']:Notify('Could not retrieve vehicle', 'error', 3000)
        end
    end, data.unitId, data.plate)

    cb('ok')
end)

-- ============================================
-- SERVER EVENTS
-- ============================================

RegisterNetEvent('sb_apartments:client:updateRentals', function(rentals, keys)
    myRentals = rentals or {}
    myKeys = keys or {}
    UpdateMyApartmentBlips()
end)

RegisterNetEvent('sb_apartments:client:rentalSuccess', function(buildingId, unitId)
    exports['sb_notify']:Notify('Rental confirmed! Welcome to your new apartment.', 'success', 5000)
    TriggerServerEvent('sb_apartments:server:getMyRentals')

    Wait(500)
    EnterApartment(buildingId, unitId)
end)

RegisterNetEvent('sb_apartments:client:rentalEnded', function(unitId)
    if currentUnit == unitId then
        exports['sb_notify']:Notify('Your rental has ended.', 'warning', 5000)
        ForceExit()
    end
    TriggerServerEvent('sb_apartments:server:getMyRentals')
end)

RegisterNetEvent('sb_apartments:client:forceExit', function(unitId)
    if currentUnit == unitId then
        ForceExit()
    end
end)

RegisterNetEvent('sb_apartments:client:keyReceived', function(unitId, ownerName)
    exports['sb_notify']:Notify(ownerName .. ' gave you keys to their apartment', 'info', 5000)
    TriggerServerEvent('sb_apartments:server:getMyRentals')
end)

RegisterNetEvent('sb_apartments:client:keyRevoked', function(unitId)
    exports['sb_notify']:Notify('Your access to an apartment has been revoked', 'warning', 5000)
    if currentUnit == unitId then
        ForceExit()
    end
    TriggerServerEvent('sb_apartments:server:getMyRentals')
end)

RegisterNetEvent('sb_apartments:client:rentDue', function(unitId, amount, daysOverdue)
    if daysOverdue > 0 then
        exports['sb_notify']:Notify('RENT OVERDUE: $' .. amount .. ' owed (' .. daysOverdue .. ' missed)', 'error', 10000)
    else
        exports['sb_notify']:Notify('Rent due soon: $' .. amount, 'warning', 7000)
    end
end)

RegisterNetEvent('sb_apartments:client:evicted', function(unitId)
    exports['sb_notify']:Notify('You have been evicted for missed rent payments!', 'error', 10000)
    if currentUnit == unitId then
        ForceExit()
    end
    TriggerServerEvent('sb_apartments:server:getMyRentals')
end)

-- ============================================
-- DEATH INSIDE APARTMENT (sb_deaths integration)
-- ============================================

CreateThread(function()
    while true do
        Wait(1000)
        if isInsideApartment then
            -- Check if player died inside apartment
            if GetResourceState('sb_deaths') == 'started' then
                local isDead = exports['sb_deaths']:IsPlayerDead(PlayerId())
                if isDead then
                    ExitApartment()
                end
            end
        end
    end
end)

-- ============================================
-- RESOURCE RESTART CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    ClearInteriorTargets()

    -- Remove blips
    for _, blip in pairs(buildingBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    RemoveMyApartmentBlips()

    -- Remove garage NPCs
    for _, npc in pairs(garageNPCs) do
        if DoesEntityExist(npc) then DeleteEntity(npc) end
    end

    -- Remove rental NPCs
    for _, npc in pairs(rentalNPCs) do
        if DoesEntityExist(npc) then DeleteEntity(npc) end
    end

    -- Remove elevator zones
    for _, zoneName in ipairs(elevatorZones) do
        exports['sb_target']:RemoveZone(zoneName)
    end
end)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

function PlayerHasAccess(unitId)
    for _, rental in ipairs(myRentals) do
        if rental.unit_id == unitId then return true end
    end
    for _, key in ipairs(myKeys) do
        if key.unit_id == unitId then return true end
    end
    return false
end

function PlayerHasAnyRentalInBuilding(buildingId)
    local building = Config.Buildings[buildingId]
    if not building then return false end

    for _, rental in ipairs(myRentals) do
        if building.units[rental.unit_id] then
            return true
        end
    end
    return false
end

function GetPlayerRentalInBuilding(buildingId)
    local building = Config.Buildings[buildingId]
    if not building then return nil end

    for _, rental in ipairs(myRentals) do
        if building.units[rental.unit_id] then
            return rental.unit_id
        end
    end
    return nil
end

-- ============================================
-- EXPORTS
-- ============================================

exports('IsInsideApartment', function()
    return isInsideApartment
end)

exports('GetCurrentApartment', function()
    return currentBuilding, currentUnit
end)

exports('GetMyRentals', function()
    return myRentals
end)
