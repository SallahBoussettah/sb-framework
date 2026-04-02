--[[
    Everyday Chaos RP - Client Functions
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- PLAYER DATA FUNCTIONS
-- ============================================================================

-- Get player data
function SB.Functions.GetPlayerData()
    return SB.PlayerData
end

-- Get specific player data field
function SB.Functions.GetPlayerDataField(field)
    return SB.PlayerData[field]
end

-- ============================================================================
-- CALLBACK FUNCTIONS
-- ============================================================================

-- Trigger server callback
function SB.Functions.TriggerCallback(name, cb, ...)
    SB.ServerCallbacks[name] = cb
    TriggerServerEvent('SB:Server:TriggerCallback', name, ...)
end

-- Create client callback (for server->client calls)
function SB.Functions.CreateClientCallback(name, cb)
    SB.ClientCallbacks[name] = cb
end

-- ============================================================================
-- ENTITY FUNCTIONS
-- ============================================================================

-- Get closest player
function SB.Functions.GetClosestPlayer(coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local closestPlayer = -1
    local closestDistance = -1

    local players = GetActivePlayers()
    for _, player in pairs(players) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= PlayerPedId() then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)

            if closestDistance == -1 or distance < closestDistance then
                closestPlayer = player
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

-- Get players in area
function SB.Functions.GetPlayersFromCoords(coords, radius)
    coords = coords or GetEntityCoords(PlayerPedId())
    radius = radius or 5.0
    local players = {}

    local activePlayers = GetActivePlayers()
    for _, player in pairs(activePlayers) do
        local targetPed = GetPlayerPed(player)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(coords - targetCoords)

        if distance <= radius then
            players[#players + 1] = {
                player = player,
                ped = targetPed,
                coords = targetCoords,
                distance = distance
            }
        end
    end

    return players
end

-- Get closest vehicle
function SB.Functions.GetClosestVehicle(coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local closestVehicle = nil
    local closestDistance = -1

    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in pairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(coords - vehicleCoords)

        if closestDistance == -1 or distance < closestDistance then
            closestVehicle = vehicle
            closestDistance = distance
        end
    end

    return closestVehicle, closestDistance
end

-- Get closest object
function SB.Functions.GetClosestObject(coords, objects)
    coords = coords or GetEntityCoords(PlayerPedId())
    local closestObject = nil
    local closestDistance = -1

    local pool = objects or GetGamePool('CObject')
    for _, object in pairs(pool) do
        local objectCoords = GetEntityCoords(object)
        local distance = #(coords - objectCoords)

        if closestDistance == -1 or distance < closestDistance then
            closestObject = object
            closestDistance = distance
        end
    end

    return closestObject, closestDistance
end

-- Get closest ped
function SB.Functions.GetClosestPed(coords, ignoreList)
    coords = coords or GetEntityCoords(PlayerPedId())
    ignoreList = ignoreList or {}
    local closestPed = nil
    local closestDistance = -1

    local peds = GetGamePool('CPed')
    for _, ped in pairs(peds) do
        if not IsPedAPlayer(ped) and not SBShared.TableContains(ignoreList, ped) then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)

            if closestDistance == -1 or distance < closestDistance then
                closestPed = ped
                closestDistance = distance
            end
        end
    end

    return closestPed, closestDistance
end

-- ============================================================================
-- VEHICLE FUNCTIONS
-- ============================================================================

-- Get vehicle properties (for saving)
function SB.Functions.GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    local props = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = SBShared.Round(GetVehicleBodyHealth(vehicle), 1),
        engineHealth = SBShared.Round(GetVehicleEngineHealth(vehicle), 1),
        tankHealth = SBShared.Round(GetVehiclePetrolTankHealth(vehicle), 1),
        fuelLevel = SBShared.Round(GetVehicleFuelLevel(vehicle), 1),
        dirtLevel = SBShared.Round(GetVehicleDirtLevel(vehicle), 1),
        color1 = colorPrimary,
        color2 = colorSecondary,
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = {
            IsVehicleNeonLightEnabled(vehicle, 0),
            IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2),
            IsVehicleNeonLightEnabled(vehicle, 3)
        },
        neonColor = table.pack(GetVehicleNeonLightsColour(vehicle)),
        extras = {},
        tyreSmokeColor = table.pack(GetVehicleTyreSmokeColor(vehicle)),
        modSpoilers = GetVehicleMod(vehicle, 0),
        modFrontBumper = GetVehicleMod(vehicle, 1),
        modRearBumper = GetVehicleMod(vehicle, 2),
        modSideSkirt = GetVehicleMod(vehicle, 3),
        modExhaust = GetVehicleMod(vehicle, 4),
        modFrame = GetVehicleMod(vehicle, 5),
        modGrille = GetVehicleMod(vehicle, 6),
        modHood = GetVehicleMod(vehicle, 7),
        modFender = GetVehicleMod(vehicle, 8),
        modRightFender = GetVehicleMod(vehicle, 9),
        modRoof = GetVehicleMod(vehicle, 10),
        modEngine = GetVehicleMod(vehicle, 11),
        modBrakes = GetVehicleMod(vehicle, 12),
        modTransmission = GetVehicleMod(vehicle, 13),
        modHorns = GetVehicleMod(vehicle, 14),
        modSuspension = GetVehicleMod(vehicle, 15),
        modArmor = GetVehicleMod(vehicle, 16),
        modTurbo = IsToggleModOn(vehicle, 18),
        modSmokeEnabled = IsToggleModOn(vehicle, 20),
        modXenon = IsToggleModOn(vehicle, 22),
        modFrontWheels = GetVehicleMod(vehicle, 23),
        modBackWheels = GetVehicleMod(vehicle, 24),
        modLivery = GetVehicleMod(vehicle, 48) == -1 and GetVehicleLivery(vehicle) or GetVehicleMod(vehicle, 48)
    }

    -- Get extras
    for i = 0, 12 do
        if DoesExtraExist(vehicle, i) then
            props.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    return props
end

-- Set vehicle properties (for loading)
function SB.Functions.SetVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or not props then return end

    SetVehicleModKit(vehicle, 0)

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end

    if props.color1 and props.color2 then
        SetVehicleColours(vehicle, props.color1, props.color2)
    end

    if props.pearlescentColor and props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
    end

    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    if props.neonEnabled then
        SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
        SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
        SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
        SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
    end

    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end

    if props.modSmokeEnabled then ToggleVehicleMod(vehicle, 20, true) end
    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
    if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
    if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
    if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
    if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
    if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
    if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
    if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
    if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
    if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
    if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end
    if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
    if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
    if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
    if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
    if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
    if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end
    if props.modTurbo then ToggleVehicleMod(vehicle, 18, props.modTurbo) end
    if props.modXenon then ToggleVehicleMod(vehicle, 22, props.modXenon) end
    if props.modFrontWheels then SetVehicleMod(vehicle, 23, props.modFrontWheels, false) end
    if props.modBackWheels then SetVehicleMod(vehicle, 24, props.modBackWheels, false) end

    if props.modLivery then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
        SetVehicleLivery(vehicle, props.modLivery)
    end

    if props.extras then
        for id, enabled in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id), not enabled)
        end
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Play animation
function SB.Functions.PlayAnim(animDict, animName, upperbodyOnly, duration)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end

    local ped = PlayerPedId()
    local flag = upperbodyOnly and 49 or 0

    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, duration or -1, flag, 0, false, false, false)
end

-- Stop animation
function SB.Functions.StopAnim(animDict, animName)
    StopAnimTask(PlayerPedId(), animDict, animName, 1.0)
end

-- Load model
function SB.Functions.LoadModel(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    if not IsModelValid(model) then
        return false
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    return true
end

-- Spawn vehicle
function SB.Functions.SpawnVehicle(model, coords, heading, cb, networked)
    local hash = type(model) == 'string' and GetHashKey(model) or model

    if not SB.Functions.LoadModel(hash) then
        if cb then cb(nil) end
        return
    end

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, networked ~= false, false)

    SetModelAsNoLongerNeeded(hash)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')

    if cb then
        cb(vehicle)
    end

    return vehicle
end

-- Delete vehicle
function SB.Functions.DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

-- Get vehicle plate
function SB.Functions.GetPlate(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    return SBShared.Trim(GetVehicleNumberPlateText(vehicle))
end

-- ============================================================================
-- NOTIFICATION FUNCTION
-- ============================================================================

-- Show notification (uses sb_notify if available, otherwise native)
function SB.Functions.Notify(message, type, duration)
    type = type or 'primary'
    duration = duration or Config.NotifyDuration or 5000

    -- Use sb_notify if available
    if GetResourceState('sb_notify') == 'started' then
        exports['sb_notify']:Notify(message, type, duration)
    else
        -- Fallback to native GTA notification
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end

    SBShared.Debug('Notification: ' .. message)
end
