-- =============================================
-- SB_POLICE - Station Interactions
-- Physical interaction points (Duty, Armory, Locker, Garage, Boss)
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

-- Local state
local isOnDuty = false
local playerGrade = 0
local playerJob = nil
local stationBlips = {}
local stationZones = {}
local spawnedVehicle = nil  -- Track spawned vehicle
local savedCivilianAppearance = nil  -- Store civilian clothes before uniform

-- Refresh SB object when sb_core restarts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- =============================================
-- Initialization
-- =============================================

CreateThread(function()
    Wait(2000)  -- Wait for resource to fully load

    -- Create blips and interaction zones for all enabled stations
    for stationId, station in pairs(Config.Stations) do
        if station.enabled then
            CreateStationBlip(stationId, station)
            CreateStationZones(stationId, station)
        end
    end

    print('[sb_police] ^2Station interactions initialized^7')
end)

-- =============================================
-- Blip Creation
-- =============================================

function CreateStationBlip(stationId, station)
    if not station.blip then return end

    local blip = AddBlipForCoord(station.blip.coords)
    SetBlipSprite(blip, station.blip.sprite or 60)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, station.blip.scale or 1.0)
    SetBlipColour(blip, station.blip.color or 29)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(station.blip.label or 'Police Station')
    EndTextCommandSetBlipName(blip)

    stationBlips[stationId] = blip
end

-- =============================================
-- Zone Creation (sb_target interactions)
-- =============================================

function CreateStationZones(stationId, station)
    stationZones[stationId] = {}

    -- Duty Point
    if station.duty and station.duty.coords then
        CreateDutyZone(stationId, station.duty)
    end

    -- Armory
    if station.armory and station.armory.coords then
        CreateArmoryZone(stationId, station.armory)
    end

    -- Locker
    if station.locker and station.locker.coords then
        CreateLockerZone(stationId, station.locker)
    end

    -- Garages (multiple NPC-based)
    if station.garages then
        for i, garageData in ipairs(station.garages) do
            CreateGarageNPC(stationId, garageData, i)
        end
    end

    -- Boss Menu
    if station.boss and station.boss.coords then
        CreateBossZone(stationId, station.boss)
    end

    -- Evidence
    if station.evidence and station.evidence.coords then
        CreateEvidenceZone(stationId, station.evidence)
    end

    -- Impound (NPC-based)
    if station.impound and station.impound.npc then
        CreateImpoundNPC(stationId, station.impound)
    end
end

-- =============================================
-- DUTY ZONE
-- =============================================

function CreateDutyZone(stationId, dutyData)
    -- Skip if coords are not set (0,0,0)
    if dutyData.coords.x == 0.0 and dutyData.coords.y == 0.0 then
        print('[sb_police] ^3Skipping duty zone - coords not configured^7')
        return
    end

    local zoneName = 'police_duty_' .. stationId

    exports['sb_target']:AddSphereZone(zoneName, dutyData.coords, 1.5, {
        {
            name = 'duty_clock_in',
            label = 'Clock In',
            icon = 'fa-clock',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return not isOnDuty and IsPoliceJob()
            end,
            action = function()
                ClockIn()
            end
        },
        {
            name = 'duty_clock_out',
            label = 'Clock Out',
            icon = 'fa-right-from-bracket',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return isOnDuty and IsPoliceJob()
            end,
            action = function()
                ClockOut()
            end
        }
    })

    table.insert(stationZones[stationId], zoneName)
end

function ClockIn()
    exports['sb_progressbar']:Start({
        label = 'Clocking in...',
        duration = 2000,
        icon = 'clock',  -- Lucide icon
        canCancel = false,
        onComplete = function()
            TriggerServerEvent('sb_police:server:toggleDuty', true)
        end
    })
end

function ClockOut()
    exports['sb_progressbar']:Start({
        label = 'Clocking out...',
        duration = 2000,
        icon = 'log-out',  -- Lucide icon
        canCancel = false,
        onComplete = function()
            TriggerServerEvent('sb_police:server:toggleDuty', false)
        end
    })
end

-- =============================================
-- ARMORY ZONE
-- =============================================

function CreateArmoryZone(stationId, armoryData)
    if armoryData.coords.x == 0.0 and armoryData.coords.y == 0.0 then
        print('[sb_police] ^3Skipping armory zone - coords not configured^7')
        return
    end

    local zoneName = 'police_armory_' .. stationId

    exports['sb_target']:AddSphereZone(zoneName, armoryData.coords, 1.5, {
        {
            name = 'armory_open',
            label = 'Open Armory',
            icon = 'fa-gun',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                if Config.General.RequireDutyForArmory and not isOnDuty then
                    return false
                end
                return IsPoliceJob()
            end,
            action = function()
                OpenArmoryMenu()
            end
        }
    })

    table.insert(stationZones[stationId], zoneName)
end

function OpenArmoryMenu()
    if Config.General.RequireDutyForArmory and not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty to access the armory', 'error', 3000)
        return
    end

    -- Ask server to pre-fill armory stash, then it tells us to open it
    TriggerServerEvent('sb_police:server:openArmory', playerGrade)
end

-- Server tells us to open the armory stash via sb_inventory
RegisterNetEvent('sb_police:client:openArmoryStash', function(stashId, slots)
    TriggerServerEvent('sb_inventory:server:openInventory', 'stash', stashId, {
        slots = slots,
        label = 'Armory',
        job = Config.PoliceJob
    })
end)

-- =============================================
-- LOCKER ZONE (Clothing)
-- =============================================

function CreateLockerZone(stationId, lockerData)
    if lockerData.coords.x == 0.0 and lockerData.coords.y == 0.0 then
        print('[sb_police] ^3Skipping locker zone - coords not configured^7')
        return
    end

    local zoneName = 'police_locker_' .. stationId

    exports['sb_target']:AddSphereZone(zoneName, lockerData.coords, 1.5, {
        {
            name = 'locker_uniform',
            label = 'Put On Uniform',
            icon = 'fa-shirt',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return IsPoliceJob()
            end,
            action = function()
                OpenLockerMenu('uniform')
            end
        },
        {
            name = 'locker_civilian',
            label = 'Civilian Clothes',
            icon = 'fa-tshirt',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return IsPoliceJob()
            end,
            action = function()
                OpenLockerMenu('civilian')
            end
        },
        {
            name = 'locker_storage',
            label = 'Personal Locker',
            icon = 'fa-box',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return IsPoliceJob()
            end,
            action = function()
                OpenPersonalLocker()
            end
        }
    })

    table.insert(stationZones[stationId], zoneName)
end

function OpenLockerMenu(outfitType)
    if outfitType == 'uniform' then
        -- Save civilian appearance before changing to uniform
        if exports['sb_clothing'] and exports['sb_clothing'].GetCurrentAppearance then
            savedCivilianAppearance = exports['sb_clothing']:GetCurrentAppearance()
        end

        -- Apply police uniform based on gender
        exports['sb_progressbar']:Start({
            label = 'Changing into uniform...',
            duration = 3000,
            icon = 'shield',  -- Lucide icon
            canCancel = true,
            onComplete = function()
                TriggerServerEvent('sb_police:server:applyUniform')
            end,
            onCancel = function()
                exports['sb_notify']:Notify('Cancelled', 'info', 2000)
            end
        })
    elseif outfitType == 'civilian' then
        -- Restore civilian clothes
        exports['sb_progressbar']:Start({
            label = 'Changing into civilian clothes...',
            duration = 3000,
            icon = 'user',  -- Lucide icon
            canCancel = true,
            onComplete = function()
                RestoreCivilianClothes()
            end,
            onCancel = function()
                exports['sb_notify']:Notify('Cancelled', 'info', 2000)
            end
        })
    end
end

-- Restore civilian clothes using saved appearance or sb_clothing
function RestoreCivilianClothes()
    if savedCivilianAppearance and exports['sb_clothing'] and exports['sb_clothing'].ApplyAppearance then
        -- Restore saved appearance
        exports['sb_clothing']:ApplyAppearance(savedCivilianAppearance)
        exports['sb_notify']:Notify('Civilian clothes restored', 'success', 3000)
    else
        -- Fallback - notify player to use clothing store
        exports['sb_notify']:Notify('Please use /clothing to change clothes', 'info', 3000)
    end
end

function OpenPersonalLocker()
    -- Open personal stash inventory
    local citizenId = SB.PlayerData and SB.PlayerData.citizenid or 'unknown'
    local stashId = 'police_locker_' .. citizenId

    TriggerServerEvent('sb_inventory:server:openInventory', 'stash', stashId, {
        maxweight = 50000,
        slots = 20,
        label = 'Police Locker'
    })
end

-- =============================================
-- GARAGE NPC SYSTEM (Vehicle Spawning)
-- =============================================

local garageNPCs = {}
local currentGarageData = nil

function CreateGarageNPC(stationId, garageData, index)
    if not garageData.npc or not garageData.npc.coords then
        print('[sb_police] ^3Skipping garage ' .. (garageData.id or index) .. ' - NPC coords not configured^7')
        return
    end

    local npcData = garageData.npc

    -- Load NPC model
    local model = GetHashKey(npcData.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    -- Create NPC
    local npc = CreatePed(4, model, npcData.coords.x, npcData.coords.y, npcData.coords.z - 1.0, npcData.heading, false, true)
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedDiesWhenInjured(npc, false)
    SetPedCanBeTargetted(npc, false)
    SetPedCanRagdoll(npc, false)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)

    SetModelAsNoLongerNeeded(model)

    -- Store NPC reference
    table.insert(garageNPCs, npc)

    -- Add sb_target options to NPC
    exports['sb_target']:AddTargetEntity(npc, {
        {
            name = 'garage_spawn_' .. garageData.id,
            label = 'Get Vehicle',
            icon = 'fa-car',
            distance = 3.0,
            canInteract = function()
                if Config.General.RequireDutyForGarage and not isOnDuty then
                    return false
                end
                return IsPoliceJob()
            end,
            action = function()
                OpenGarageMenu(garageData)
            end
        },
        {
            name = 'garage_store_' .. garageData.id,
            label = 'Store Vehicle',
            icon = 'fa-warehouse',
            distance = 3.0,
            canInteract = function()
                local ped = PlayerPedId()
                if not IsPedInAnyVehicle(ped, false) then return false end
                if not IsPoliceJob() then return false end
                -- Only show if it's a police garage vehicle
                local vehicle = GetVehiclePedIsIn(ped, false)
                return Entity(vehicle).state.police_garage_vehicle == true
            end,
            action = function()
                StoreVehicle()
            end
        }
    })

    print('[sb_police] ^2Created garage NPC:^7 ' .. (garageData.label or garageData.id))
end

function OpenGarageMenu(garageData)
    if Config.General.RequireDutyForGarage and not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    -- Store garage data for spawning
    currentGarageData = {
        garageId = garageData.id,
        spawnPoints = garageData.spawnPoints,
        label = garageData.label
    }

    -- Open NUI garage menu
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'openGarage',
        vehicles = Config.Vehicles,
        categories = Config.VehicleCategories,
        playerGrade = playerGrade,
        garageData = currentGarageData,
        ranks = Config.Ranks,
        gradeMode = Config.General.GarageGradeMode
    })

    print('[sb_police] ^2Opened garage menu^7 - Player Grade: ' .. playerGrade .. ' | Mode: ' .. Config.General.GarageGradeMode)
end

-- NUI Callback: Close garage
RegisterNUICallback('closeGarage', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- NUI Callback: Spawn vehicle
RegisterNUICallback('spawnVehicle', function(data, cb)
    SetNuiFocus(false, false)

    if not currentGarageData then
        exports['sb_notify']:Notify('Garage data not found', 'error', 3000)
        cb('error')
        return
    end

    -- Find the vehicle in config
    local vehicleData = nil
    for _, veh in ipairs(Config.Vehicles) do
        if veh.model == data.model then
            vehicleData = veh
            break
        end
    end

    if not vehicleData then
        exports['sb_notify']:Notify('Vehicle not found', 'error', 3000)
        cb('error')
        return
    end

    -- Check grade (respects GarageGradeMode: exact or cumulative)
    if not Config.MeetsGarageGradeRequirement(playerGrade, vehicleData.grade) then
        exports['sb_notify']:Notify('Insufficient rank', 'error', 3000)
        cb('error')
        return
    end

    -- Find available spawn point
    local spawnCoords, heading, spotIndex = FindAvailableSpawnPoint(currentGarageData.spawnPoints)

    if not spawnCoords then
        exports['sb_notify']:Notify('All parking spots are occupied!', 'error', 3000)
        cb('error')
        return
    end

    SpawnPoliceVehicle(vehicleData.model, vehicleData.label, spawnCoords, heading)
    print('[sb_police] Spawned at spot #' .. spotIndex)
    cb('ok')
end)

-- Check if a spawn point is occupied by any vehicle
function IsSpawnPointOccupied(coords, radius)
    radius = radius or 3.0
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(vehicle)
        local dist = #(coords - vehCoords)
        if dist < radius then
            return true
        end
    end

    return false
end

-- Find available spawn point from list
function FindAvailableSpawnPoint(spawnPoints)
    for i, spawnData in ipairs(spawnPoints) do
        if not IsSpawnPointOccupied(spawnData.coords) then
            return spawnData.coords, spawnData.heading, i
        end
    end
    return nil, nil, nil
end

-- Garage spawn command (fallback/quick access)
RegisterCommand('pgarage', function(source, args)
    if not IsPoliceJob() then
        exports['sb_notify']:Notify('Police only', 'error', 3000)
        return
    end

    if Config.General.RequireDutyForGarage and not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    -- If no currentGarageData, find nearest garage
    if not currentGarageData then
        -- Find first garage in config
        for stationId, station in pairs(Config.Stations) do
            if station.enabled and station.garages and #station.garages > 0 then
                currentGarageData = {
                    garageId = station.garages[1].id,
                    spawnPoints = station.garages[1].spawnPoints,
                    label = station.garages[1].label
                }
                break
            end
        end
    end

    if not currentGarageData then
        exports['sb_notify']:Notify('No garage configured', 'error', 3000)
        return
    end

    local vehicles = Config.GetVehiclesForGrade(playerGrade)

    -- No args = open NUI menu
    if #args < 1 then
        OpenGarageMenuDirect()
        return
    end

    -- With number = quick spawn
    local index = tonumber(args[1])
    if not index or index < 1 or index > #vehicles then
        exports['sb_notify']:Notify('Invalid vehicle number (1-' .. #vehicles .. ')', 'error', 3000)
        return
    end

    local vehicleData = vehicles[index]

    -- Find available spawn point
    local spawnCoords, heading, spotIndex = FindAvailableSpawnPoint(currentGarageData.spawnPoints)

    if not spawnCoords then
        exports['sb_notify']:Notify('All parking spots are occupied!', 'error', 3000)
        return
    end

    SpawnPoliceVehicle(vehicleData.model, vehicleData.label, spawnCoords, heading)
    print('[sb_police] Spawned at spot #' .. spotIndex)
end, false)

-- Direct open garage menu (for command)
function OpenGarageMenuDirect()
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'openGarage',
        vehicles = Config.Vehicles,
        categories = Config.VehicleCategories,
        playerGrade = playerGrade,
        garageData = currentGarageData,
        ranks = Config.Ranks,
        gradeMode = Config.General.GarageGradeMode
    })
end

function SpawnPoliceVehicle(model, label, coords, heading)
    -- Delete previous vehicle if exists
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        DeleteEntity(spawnedVehicle)
        spawnedVehicle = nil
    end

    local modelHash = GetHashKey(model)

    -- Request model
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(modelHash) then
        exports['sb_notify']:Notify('Failed to load vehicle model: ' .. model, 'error', 3000)
        return
    end

    -- Create vehicle
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, 'LSPD' .. math.random(100, 999))
    SetVehicleLivery(vehicle, 0)
    SetVehicleDoorsLocked(vehicle, 1)

    -- Set owned state for sb_worldcontrol
    Entity(vehicle).state.sb_owned = true

    -- Mark as police garage vehicle (for store verification)
    Entity(vehicle).state.police_garage_vehicle = true

    -- Give keys via server (adds car_keys item with plate metadata)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('sb_police:server:giveVehicleKeys', plate, label)

    spawnedVehicle = vehicle
    SetModelAsNoLongerNeeded(modelHash)

    exports['sb_notify']:Notify('Spawned: ' .. label, 'success', 3000)
    print('[sb_police] ^2Spawned police vehicle:^7 ' .. model)
end

function StoreVehicle()
    local ped = PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        exports['sb_notify']:Notify('You must be in a vehicle', 'error', 3000)
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    -- Check if this is a police garage vehicle
    if not Entity(vehicle).state.police_garage_vehicle then
        exports['sb_notify']:Notify('This is not a police vehicle from the garage', 'error', 3000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    print(('[sb_police] ^3DEBUG CLIENT: StoreVehicle - plate: %s^7'):format(plate))

    -- Make player exit vehicle first
    TaskLeaveVehicle(ped, vehicle, 0)

    Wait(1500)

    -- Delete the vehicle
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        if spawnedVehicle == vehicle then
            spawnedVehicle = nil
        end
        -- Remove keys from inventory
        print(('[sb_police] ^3DEBUG CLIENT: Triggering removeVehicleKeys for plate: %s^7'):format(plate))
        TriggerServerEvent('sb_police:server:removeVehicleKeys', plate)
        exports['sb_notify']:Notify('Vehicle stored', 'success', 3000)
    end
end

-- =============================================
-- HORN TO STORE SYSTEM (Press E at spawn point)
-- =============================================

local allSpawnPoints = {}
local isNearSpawnPoint = false
local showingStorePrompt = false

-- Collect all spawn points from config
function CollectAllSpawnPoints()
    allSpawnPoints = {}

    for stationId, station in pairs(Config.Stations) do
        if station.enabled and station.garages then
            for _, garageData in ipairs(station.garages) do
                if garageData.spawnPoints then
                    for _, spawnPoint in ipairs(garageData.spawnPoints) do
                        table.insert(allSpawnPoints, {
                            coords = spawnPoint.coords,
                            heading = spawnPoint.heading,
                            garageId = garageData.id,
                            stationId = stationId
                        })
                    end
                end
            end
        end
    end

    print('[sb_police] ^2Collected ' .. #allSpawnPoints .. ' spawn points for horn-to-store^7')
end

-- Check if player is near any spawn point
function GetNearestSpawnPoint(playerCoords, maxDistance)
    maxDistance = maxDistance or 5.0
    local nearest = nil
    local nearestDist = maxDistance

    for _, spawnPoint in ipairs(allSpawnPoints) do
        local dist = #(playerCoords - spawnPoint.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearest = spawnPoint
        end
    end

    return nearest, nearestDist
end

-- Store vehicle instantly (no exit animation for quick store)
function StoreVehicleInstant()
    local ped = PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        return false
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    -- Check if this is a police garage vehicle
    if not Entity(vehicle).state.police_garage_vehicle then
        exports['sb_notify']:Notify('This is not a police vehicle from the garage', 'error', 3000)
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    print(('[sb_police] ^3DEBUG CLIENT: StoreVehicleInstant - plate: %s^7'):format(plate))

    -- Quick exit
    SetEntityAsMissionEntity(vehicle, true, true)
    TaskLeaveVehicle(ped, vehicle, 16) -- 16 = leave immediately

    Wait(800)

    -- Delete the vehicle
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        if spawnedVehicle == vehicle then
            spawnedVehicle = nil
        end
        -- Remove keys from inventory
        print(('[sb_police] ^3DEBUG CLIENT: Triggering removeVehicleKeys for plate: %s^7'):format(plate))
        TriggerServerEvent('sb_police:server:removeVehicleKeys', plate)
        exports['sb_notify']:Notify('Vehicle stored', 'success', 3000)
        return true
    end

    return false
end

-- Thread to monitor spawn point proximity and horn input
CreateThread(function()
    -- Wait for config to load
    Wait(3000)
    CollectAllSpawnPoints()

    while true do
        local sleep = 500
        local ped = PlayerPedId()

        -- Only check if player is police and in a police garage vehicle
        if IsPoliceJob() and IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)

            -- Only allow storing police garage vehicles
            if not Entity(vehicle).state.police_garage_vehicle then
                Wait(sleep)
                goto continue
            end

            local playerCoords = GetEntityCoords(ped)
            local nearestSpawn, distance = GetNearestSpawnPoint(playerCoords)

            if nearestSpawn and distance < 5.0 then
                sleep = 0
                isNearSpawnPoint = true

                -- Show prompt
                if not showingStorePrompt then
                    showingStorePrompt = true
                end

                -- Draw help text
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_VEH_HORN~ to store vehicle')
                EndTextCommandDisplayHelp(0, false, true, -1)

                -- Check for horn (E key)
                if IsControlJustPressed(0, 86) then -- 86 = INPUT_VEH_HORN (E)
                    StoreVehicleInstant()
                end
            else
                isNearSpawnPoint = false
                showingStorePrompt = false
            end
        else
            isNearSpawnPoint = false
            showingStorePrompt = false
        end

        ::continue::
        Wait(sleep)
    end
end)

-- =============================================
-- BOSS ZONE (Management - Rank 9 only per user request)
-- =============================================

function CreateBossZone(stationId, bossData)
    if bossData.coords.x == 0.0 and bossData.coords.y == 0.0 then
        print('[sb_police] ^3Skipping boss zone - coords not configured^7')
        return
    end

    local zoneName = 'police_boss_' .. stationId
    local minGrade = 9  -- User specified rank 9 for boss access

    exports['sb_target']:AddSphereZone(zoneName, bossData.coords, 1.5, {
        {
            name = 'boss_menu',
            label = 'Boss Menu',
            icon = 'fa-user-tie',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return IsPoliceJob() and playerGrade >= minGrade
            end,
            action = function()
                OpenBossMenu()
            end
        }
    })

    table.insert(stationZones[stationId], zoneName)
end

function OpenBossMenu()
    if playerGrade < 9 then
        exports['sb_notify']:Notify('You need rank 9 to access this', 'error', 3000)
        return
    end

    -- Boss menu options
    exports['sb_notify']:Notify('Boss Menu:\n/hire [id] - Hire player\n/fire [id] - Fire employee\n/promote [id] - Promote\n/demote [id] - Demote\n/setgrade [id] [grade] - Set grade', 'info', 10000)
end

-- Boss commands
RegisterCommand('hire', function(source, args)
    if not IsBoss() then
        exports['sb_notify']:Notify('Boss only', 'error', 3000)
        return
    end

    if #args < 1 then
        exports['sb_notify']:Notify('Usage: /hire [player id]', 'info', 3000)
        return
    end

    local targetId = tonumber(args[1])
    TriggerServerEvent('sb_police:server:hirePlayer', targetId)
end, false)

RegisterCommand('fire', function(source, args)
    if not IsBoss() then
        exports['sb_notify']:Notify('Boss only', 'error', 3000)
        return
    end

    if #args < 1 then
        exports['sb_notify']:Notify('Usage: /fire [player id]', 'info', 3000)
        return
    end

    local targetId = tonumber(args[1])
    TriggerServerEvent('sb_police:server:firePlayer', targetId)
end, false)

RegisterCommand('promote', function(source, args)
    if not IsBoss() then
        exports['sb_notify']:Notify('Boss only', 'error', 3000)
        return
    end

    if #args < 1 then
        exports['sb_notify']:Notify('Usage: /promote [player id]', 'info', 3000)
        return
    end

    local targetId = tonumber(args[1])
    TriggerServerEvent('sb_police:server:promotePlayer', targetId)
end, false)

RegisterCommand('demote', function(source, args)
    if not IsBoss() then
        exports['sb_notify']:Notify('Boss only', 'error', 3000)
        return
    end

    if #args < 1 then
        exports['sb_notify']:Notify('Usage: /demote [player id]', 'info', 3000)
        return
    end

    local targetId = tonumber(args[1])
    TriggerServerEvent('sb_police:server:demotePlayer', targetId)
end, false)

RegisterCommand('setgrade', function(source, args)
    if not IsBoss() then
        exports['sb_notify']:Notify('Boss only', 'error', 3000)
        return
    end

    if #args < 2 then
        exports['sb_notify']:Notify('Usage: /setgrade [player id] [grade]', 'info', 3000)
        return
    end

    local targetId = tonumber(args[1])
    local grade = tonumber(args[2])
    TriggerServerEvent('sb_police:server:setPlayerGrade', targetId, grade)
end, false)

-- =============================================
-- EVIDENCE ZONE
-- =============================================

function CreateEvidenceZone(stationId, evidenceData)
    if evidenceData.coords.x == 0.0 and evidenceData.coords.y == 0.0 then
        print('[sb_police] ^3Skipping evidence zone - coords not configured^7')
        return
    end

    local zoneName = 'police_evidence_' .. stationId

    exports['sb_target']:AddSphereZone(zoneName, evidenceData.coords, 1.5, {
        {
            name = 'evidence_locker',
            label = 'Evidence Locker',
            icon = 'fa-box-archive',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function()
                return IsPoliceJob() and isOnDuty
            end,
            action = function()
                OpenEvidenceLocker(stationId)
            end
        }
    })

    table.insert(stationZones[stationId], zoneName)
end

function OpenEvidenceLocker(stationId)
    local stashId = 'police_evidence_' .. stationId

    TriggerServerEvent('sb_inventory:server:openInventory', 'stash', stashId, {
        maxweight = 500000,
        slots = 50,
        label = 'Evidence Locker'
    })
end

-- =============================================
-- IMPOUND NPC SYSTEM
-- =============================================

local impoundNPCs = {}
local currentImpoundData = nil

function CreateImpoundNPC(stationId, impoundData)
    if not impoundData.npc or not impoundData.npc.coords then
        print('[sb_police] ^3Skipping impound - NPC coords not configured^7')
        return
    end

    local npcData = impoundData.npc

    -- Load NPC model
    local model = GetHashKey(npcData.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    -- Create NPC
    local npc = CreatePed(4, model, npcData.coords.x, npcData.coords.y, npcData.coords.z - 1.0, npcData.heading, false, true)
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedDiesWhenInjured(npc, false)
    SetPedCanBeTargetted(npc, false)
    SetPedCanRagdoll(npc, false)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)

    SetModelAsNoLongerNeeded(model)

    -- Store NPC reference
    table.insert(impoundNPCs, npc)

    -- Store impound data for later use
    currentImpoundData = {
        spawnPoints = impoundData.spawnPoints,
        label = impoundData.label
    }

    -- Add sb_target options to NPC
    exports['sb_target']:AddTargetEntity(npc, {
        {
            name = 'impound_vehicle',
            label = 'Impound Nearby Vehicle',
            icon = 'fa-truck-ramp-box',
            distance = 3.0,
            canInteract = function()
                return IsPoliceJob() and isOnDuty
            end,
            action = function()
                ImpoundNearbyVehicle()
            end
        },
        {
            name = 'impound_retrieve',
            label = 'Retrieve Impounded Vehicle',
            icon = 'fa-car',
            distance = 3.0,
            canInteract = function()
                return IsPoliceJob()
            end,
            action = function()
                ViewImpoundedVehicles()
            end
        }
    })

    print('[sb_police] ^2Created impound NPC:^7 ' .. (impoundData.label or 'Police Impound'))
end

function ImpoundNearbyVehicle()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 10.0, 0, 71)

    if not vehicle or not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('No vehicle nearby', 'error', 3000)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)

    exports['sb_progressbar']:Start({
        label = 'Impounding vehicle...',
        duration = 5000,
        icon = 'truck',  -- Lucide icon
        canCancel = true,
        onComplete = function()
            TriggerServerEvent('sb_police:server:impoundVehicle', plate)
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
            exports['sb_notify']:Notify('Vehicle impounded: ' .. plate, 'success', 3000)
        end,
        onCancel = function()
            exports['sb_notify']:Notify('Cancelled', 'info', 2000)
        end
    })
end

function ViewImpoundedVehicles()
    -- Request impounded vehicles from server
    SB.Functions.TriggerCallback('sb_police:server:getImpoundedVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            exports['sb_notify']:Notify('No impounded vehicles', 'info', 3000)
            return
        end

        -- Show list of impounded vehicles
        local vehicleList = {}
        for i, veh in ipairs(vehicles) do
            table.insert(vehicleList, i .. '=' .. veh.plate)
        end

        exports['sb_notify']:Notify('Use /impound [number] to retrieve\n' .. table.concat(vehicleList, ', '), 'info', 10000)

        -- Store for command
        impoundedVehiclesList = vehicles
    end)
end

local impoundedVehiclesList = {}

-- Retrieve impounded vehicle command
RegisterCommand('impound', function(source, args)
    if not IsPoliceJob() then
        exports['sb_notify']:Notify('Police only', 'error', 3000)
        return
    end

    if not currentImpoundData then
        exports['sb_notify']:Notify('Talk to the impound NPC first', 'error', 3000)
        return
    end

    if not impoundedVehiclesList or #impoundedVehiclesList == 0 then
        exports['sb_notify']:Notify('No impounded vehicles. Use the NPC to view list first.', 'error', 3000)
        return
    end

    if #args < 1 then
        exports['sb_notify']:Notify('Usage: /impound [number]', 'info', 3000)
        return
    end

    local index = tonumber(args[1])
    if not index or index < 1 or index > #impoundedVehiclesList then
        exports['sb_notify']:Notify('Invalid vehicle number', 'error', 3000)
        return
    end

    local vehicleData = impoundedVehiclesList[index]

    -- Find available spawn point
    local spawnCoords, heading, spotIndex = FindAvailableSpawnPoint(currentImpoundData.spawnPoints)

    if not spawnCoords then
        exports['sb_notify']:Notify('All impound spots are occupied!', 'error', 3000)
        return
    end

    -- Request server to release vehicle
    TriggerServerEvent('sb_police:server:releaseImpoundedVehicle', vehicleData.plate, spawnCoords, heading)
end, false)

-- Handle released vehicle spawn
RegisterNetEvent('sb_police:client:spawnImpoundedVehicle', function(model, plate, coords, heading)
    local modelHash = GetHashKey(model)

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(modelHash) then
        exports['sb_notify']:Notify('Failed to load vehicle model', 'error', 3000)
        return
    end

    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDoorsLocked(vehicle, 1)

    Entity(vehicle).state.sb_owned = true

    -- Give keys for the released vehicle
    TriggerServerEvent('sb_police:server:giveVehicleKeys', plate, model)

    SetModelAsNoLongerNeeded(modelHash)

    exports['sb_notify']:Notify('Vehicle released: ' .. plate, 'success', 3000)
    print('[sb_police] ^2Released impounded vehicle:^7 ' .. plate)

    -- Refresh list
    impoundedVehiclesList = {}
end)

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

function IsPoliceJob()
    if not playerJob then
        UpdatePlayerJob()
    end
    return playerJob and playerJob.name == Config.PoliceJob
end

function IsBoss()
    return IsPoliceJob() and playerGrade >= 9
end

function UpdatePlayerJob()
    if SB and SB.PlayerData and SB.PlayerData.job then
        playerJob = SB.PlayerData.job
        playerGrade = playerJob.grade and playerJob.grade.level or 0
    end
end

-- =============================================
-- EVENT HANDLERS
-- =============================================

-- Update duty status
RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    isOnDuty = onDuty
end)

-- Update job data
RegisterNetEvent('SB:Client:OnJobUpdate', function(job)
    playerJob = job
    playerGrade = job.grade and job.grade.level or 0
end)

RegisterNetEvent('sb_police:client:setJobData', function(job)
    playerJob = job
    playerGrade = job.grade and job.grade.level or 0
end)

-- Character loaded
RegisterNetEvent('sb_multicharacter:client:SpawnComplete', function()
    Wait(1000)
    UpdatePlayerJob()
end)

RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    Wait(500)
    UpdatePlayerJob()
end)

-- Impounded vehicles list
RegisterNetEvent('sb_police:client:showImpoundedVehicles', function(vehicles)
    if #vehicles == 0 then
        exports['sb_notify']:Notify('No impounded vehicles', 'info', 3000)
        return
    end

    local list = {}
    for _, veh in ipairs(vehicles) do
        table.insert(list, veh.plate .. ' (' .. veh.vehicle .. ')')
    end

    exports['sb_notify']:Notify('Impounded:\n' .. table.concat(list, '\n'), 'info', 10000)
end)

-- Uniform applied
RegisterNetEvent('sb_police:client:uniformApplied', function()
    exports['sb_notify']:Notify('Uniform equipped', 'success', 3000)
end)

-- Civilian clothes applied
RegisterNetEvent('sb_police:client:civilianApplied', function()
    exports['sb_notify']:Notify('Civilian clothes equipped', 'success', 3000)
end)

-- Apply uniform components
RegisterNetEvent('sb_police:client:applyUniformComponents', function(components)
    local ped = PlayerPedId()
    for componentId, data in pairs(components) do
        SetPedComponentVariation(ped, tonumber(componentId), data.drawable, data.texture, 0)
    end
end)

-- Restore civilian clothes (triggered from server if needed)
RegisterNetEvent('sb_police:client:restoreCivilianClothes', function()
    RestoreCivilianClothes()
end)

-- Give weapon natively (fallback for armory)
RegisterNetEvent('sb_police:client:giveWeaponNative', function(weaponName)
    local ped = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    GiveWeaponToPed(ped, weaponHash, 0, false, true)
end)

-- =============================================
-- MARKER DRAWING (Optional visual feedback)
-- =============================================

CreateThread(function()
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())

        -- Only draw markers if player is police
        if IsPoliceJob() then
            for stationId, station in pairs(Config.Stations) do
                if station.enabled then
                    -- Draw duty marker
                    if station.duty and station.duty.marker then
                        local dist = #(playerCoords - station.duty.coords)
                        if dist < Config.General.MarkerDrawDistance then
                            sleep = 0
                            local m = station.duty.marker
                            DrawMarker(m.type, station.duty.coords.x, station.duty.coords.y, station.duty.coords.z - 0.9,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                m.scale, m.scale, m.scale,
                                m.color[1], m.color[2], m.color[3], m.color[4],
                                false, true, 2, false, nil, nil, false)
                        end
                    end

                    -- Draw garage marker
                    if station.garage and station.garage.marker then
                        local dist = #(playerCoords - station.garage.access)
                        if dist < Config.General.MarkerDrawDistance then
                            sleep = 0
                            local m = station.garage.marker
                            DrawMarker(m.type, station.garage.access.x, station.garage.access.y, station.garage.access.z - 0.9,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                m.scale, m.scale, m.scale,
                                m.color[1], m.color[2], m.color[3], m.color[4],
                                false, true, 2, false, nil, nil, false)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- =============================================
-- CLEANUP
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove blips
    for _, blip in pairs(stationBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    -- Delete garage NPCs
    for _, npc in ipairs(garageNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    -- Delete impound NPCs
    for _, npc in ipairs(impoundNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end

    -- Delete spawned vehicle
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        DeleteEntity(spawnedVehicle)
    end
end)

-- =============================================
-- COORDINATE HELPER (for setting up stations)
-- =============================================

RegisterCommand('policecoords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Format for config.lua
    local formatted = string.format('vector3(%.2f, %.2f, %.2f)', coords.x, coords.y, coords.z)
    local headingStr = string.format('%.1f', heading)

    -- Print to console (F8)
    print('===========================================')
    print('[sb_police] CURRENT POSITION:')
    print('  Coords: ' .. formatted)
    print('  Heading: ' .. headingStr)
    print('===========================================')
    print('')
    print('Copy for config.lua:')
    print('  coords = ' .. formatted .. ',')
    print('  heading = ' .. headingStr .. ',')
    print('')

    -- Show on screen
    exports['sb_notify']:Notify(
        'Coords copied to F8 console!\n' ..
        formatted .. '\nHeading: ' .. headingStr,
        'info', 10000
    )

    -- Also copy to clipboard if possible (needs NUI)
    SendNUIMessage({
        type = 'copyToClipboard',
        text = formatted
    })
end, false)

RegisterCommand('policecoords2', function()
    -- Alternative: outputs all station points format
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    print('===========================================')
    print('[sb_police] STATION POINT FORMAT:')
    print('')
    print('-- For duty/armory/locker/evidence/boss/impound:')
    print(string.format('coords = vector3(%.2f, %.2f, %.2f),', coords.x, coords.y, coords.z))
    print(string.format('heading = %.1f,', heading))
    print('')
    print('-- For garage spawn point:')
    print(string.format('spawn = vector3(%.2f, %.2f, %.2f),', coords.x, coords.y, coords.z))
    print(string.format('heading = %.1f,', heading))
    print('')
    print('-- For garage access point (where player stands):')
    print(string.format('access = vector3(%.2f, %.2f, %.2f),', coords.x, coords.y, coords.z))
    print('===========================================')

    exports['sb_notify']:Notify('Full format copied to F8 console!', 'success', 5000)
end, false)

-- =============================================
-- COURTHOUSE (Fine Payment)
-- =============================================

CreateThread(function()
    Wait(3000) -- Wait for resources to load

    if not Config.Courthouse then return end

    local ch = Config.Courthouse

    -- Create courthouse blip
    if ch.blip then
        local blip = AddBlipForCoord(ch.coords)
        SetBlipSprite(blip, ch.blip.sprite or 184)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, ch.blip.scale or 0.8)
        SetBlipColour(blip, ch.blip.color or 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(ch.blip.label or 'Courthouse')
        EndTextCommandSetBlipName(blip)
    end

    -- Add sb_target zone for fine payment
    exports['sb_target']:AddBoxZone('courthouse_fines', ch.coords, 2.0, 2.0, 2.5, 0.0, {
        {
            name = 'pay_fines',
            label = ch.label or 'Pay Fines',
            icon = ch.icon or 'fa-gavel',
            distance = 2.5,
            action = function()
                TriggerServerEvent('sb_police:server:payFines')
            end,
            canInteract = function()
                return true -- Anyone can pay fines
            end
        }
    })
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('IsOnDutyStation', function() return isOnDuty end)
exports('GetPlayerGrade', function() return playerGrade end)
exports('IsPoliceJob', IsPoliceJob)
exports('IsBoss', IsBoss)
