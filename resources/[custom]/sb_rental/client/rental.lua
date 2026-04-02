-- sb_rental Client Rental Management
-- Vehicle spawning, tracking, warnings

local currentRental = nil
local rentalVehicle = nil
local warningShown = {}

-- Find available spawn point at location
local function FindSpawnPoint(locationId)
    local location = Config.Locations[locationId]
    if not location then return nil end

    for _, point in ipairs(location.spawnPoints) do
        local coords = vector3(point.x, point.y, point.z)
        local foundVehicle = false

        -- Check if spot is clear
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehCoords = GetEntityCoords(veh)
                if #(coords - vehCoords) < 3.0 then
                    foundVehicle = true
                    break
                end
            end
        end

        if not foundVehicle then
            return point
        end
    end

    -- Use first spawn point if all occupied
    return location.spawnPoints[1]
end

-- Request server to spawn rental vehicle (server-side spawn for persistence)
function SpawnRentalVehicle(vehicleModel, plate, rentalId, locationId)
    local location = Config.Locations[locationId]
    if not location then return end

    -- Find available spawn point
    local spawnPoint = FindSpawnPoint(locationId)
    if not spawnPoint then
        exports['sb_notify']:Notify('No spawn points available', 'error', 3000)
        return
    end

    -- Request SERVER to spawn the vehicle (server-side spawn = persists on disconnect)
    TriggerServerEvent('sb_rental:server:spawnRentalVehicle',
        vehicleModel,
        plate,
        rentalId,
        locationId,
        vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z),
        spawnPoint.w
    )
end

-- Setup server-spawned rental vehicle
RegisterNetEvent('sb_rental:client:setupRentalVehicle', function(data)
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
        exports['sb_notify']:Notify('Failed to locate rental vehicle', 'error', 3000)
        return
    end

    -- Request network control
    local controlAttempts = 0
    while not NetworkHasControlOfEntity(vehicle) and controlAttempts < 30 do
        NetworkRequestControlOfEntity(vehicle)
        Wait(100)
        controlAttempts = controlAttempts + 1
    end

    Wait(500)

    -- Set vehicle properties
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 1) -- Unlocked

    -- Set fuel if sb_fuel is available
    if GetResourceState('sb_fuel') == 'started' then
        exports['sb_fuel']:SetFuel(vehicle, 100.0)
    end

    -- Set state bags for vehicle system integration
    Entity(vehicle).state:set('sb_owned', true, true)
    Entity(vehicle).state:set('sb_plate', data.plate, true)

    -- Additional rental-specific state bags
    Entity(vehicle).state:set('sb_rental', true, true)
    Entity(vehicle).state:set('sb_rental_id', data.rentalId, true)
    Entity(vehicle).state:set('sb_rental_plate', data.plate, true)

    -- Store reference
    rentalVehicle = vehicle
    currentRental = {
        rentalId = data.rentalId,
        plate = data.plate,
        vehicle = data.vehicle,
        netId = data.netId
    }

    -- Draw marker to vehicle
    local vehicleCoords = GetEntityCoords(vehicle)
    SetNewWaypoint(vehicleCoords.x, vehicleCoords.y)

    exports['sb_notify']:Notify('Your rental is ready!', 'success', 4000)
end)

-- Event to spawn vehicle from server (legacy/fallback)
RegisterNetEvent('sb_rental:client:spawnVehicle', function(vehicleModel, plate, rentalId, locationId)
    SpawnRentalVehicle(vehicleModel, plate, rentalId, locationId)
end)

-- Event when rental is updated
RegisterNetEvent('sb_rental:client:rentalUpdated', function(rental)
    if rental then
        currentRental = {
            rentalId = rental.rental_id,
            plate = rental.plate,
            vehicle = rental.vehicle,
            rental_end = rental.rental_end,
            status = rental.status
        }
    else
        currentRental = nil
        rentalVehicle = nil
    end
end)

-- Rental warning thread
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        if currentRental then
            -- Request current rental status
            TriggerServerEvent('sb_rental:server:requestRentalUpdate')
        end

        Wait(0)
    end
end)

-- Warning notification handler
RegisterNetEvent('sb_rental:client:warning', function(warningType, data)
    if warningType == 'expiring_soon' then
        if not warningShown['expiring_' .. data.minutes] then
            warningShown['expiring_' .. data.minutes] = true
            exports['sb_notify']:Notify(string.format('Your rental expires in %d minutes!', data.minutes), 'warning', 5000)
        end
    elseif warningType == 'overdue' then
        exports['sb_notify']:Notify('Your rental is OVERDUE! Return immediately to avoid fees!', 'error', 8000)
    elseif warningType == 'stolen' then
        exports['sb_notify']:Notify('Your rental is now marked as STOLEN! Police may impound the vehicle!', 'error', 10000)
    end
end)

-- Check if player is in rental vehicle
CreateThread(function()
    while true do
        Wait(5000)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle and vehicle ~= 0 then
            local state = Entity(vehicle).state
            if state.sb_rental and currentRental then
                -- Player is in their rental vehicle
                -- Could show HUD timer here if desired
            end
        end

        Wait(0)
    end
end)

-- Format timestamp to readable date (client-side helper)
function FormatTimestamp(timestamp)
    if not timestamp then return 'N/A' end

    -- If it's already a formatted string (contains letters), return as-is
    if type(timestamp) == 'string' and timestamp:match('%a') then
        return timestamp
    end

    -- Handle milliseconds
    local ts = tonumber(timestamp)
    if ts and ts > 1000000000000 then
        ts = math.floor(ts / 1000)
    end

    if ts then
        -- Lua's os.date works on client too
        return os.date('%b %d, %Y %I:%M %p', ts)
    end

    return tostring(timestamp)
end

-- Handle rental license item use
RegisterNetEvent('sb_rental:client:showLicense', function(metadata)
    if not metadata then return end

    -- Calculate status
    local status = 'VALID'
    local statusColor = 'success'

    if metadata.status then
        if metadata.status == 'late' then
            status = 'OVERDUE'
            statusColor = 'warning'
        elseif metadata.status == 'stolen' then
            status = 'STOLEN'
            statusColor = 'error'
        elseif metadata.status == 'returned' then
            status = 'RETURNED'
            statusColor = 'info'
        end
    end

    -- Format dates for display
    local rentalStart = FormatTimestamp(metadata.rental_start)
    local rentalEnd = FormatTimestamp(metadata.rental_end)

    -- Show formatted license info
    local msg = string.format([[
RENTAL LICENSE
--------------
ID: %s
Vehicle: %s
Plate: %s
Renter: %s
Location: %s
Rented: %s
Due: %s
Status: %s
    ]],
        metadata.rental_id or 'N/A',
        metadata.vehicle_label or 'N/A',
        metadata.plate or 'N/A',
        metadata.renter_name or 'N/A',
        metadata.location or 'N/A',
        rentalStart,
        rentalEnd,
        status
    )

    exports['sb_notify']:Notify('Showing rental license...', 'info', 3000)

    -- Could also trigger a NUI display here for a nicer format
    TriggerEvent('chat:addMessage', {
        color = { 255, 165, 0 },
        multiline = true,
        args = { 'Rental License', msg }
    })
end)

-- Force despawn rental (called by server when overdue)
RegisterNetEvent('sb_rental:client:despawnRental', function(plate)
    local vehicles = GetGamePool('CVehicle')

    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if string.gsub(vehPlate, ' ', '') == string.gsub(plate, ' ', '') then
                -- Check if it's a rental
                local state = Entity(veh).state
                if state.sb_rental then
                    -- Unregister from sb_impound before deleting
                    TriggerServerEvent('sb_impound:server:vehicleStored', plate)

                    -- Despawn with fade effect
                    local alpha = 255
                    while alpha > 0 do
                        alpha = alpha - 5
                        SetEntityAlpha(veh, alpha, false)
                        Wait(50)
                    end
                    DeleteEntity(veh)
                    break
                end
            end
        end
    end

    currentRental = nil
    rentalVehicle = nil
    warningShown = {}
end)

-- Get vehicle properties (similar to sb_garage)
function GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local color1, color2 = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local customColor1 = { GetVehicleCustomPrimaryColour(vehicle) }
    local customColor2 = { GetVehicleCustomSecondaryColour(vehicle) }
    local dashColor = GetVehicleDashboardColour(vehicle)
    local interiorColor = GetVehicleInteriorColour(vehicle)

    local extras = {}
    for i = 0, 15 do
        if DoesExtraExist(vehicle, i) then
            extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    local modLivery = GetVehicleMod(vehicle, 48)
    if GetVehicleMod(vehicle, 48) == -1 and GetVehicleLivery(vehicle) ~= -1 then
        modLivery = GetVehicleLivery(vehicle)
    end

    local props = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        color1 = color1,
        color2 = color2,
        customColor1 = customColor1,
        customColor2 = customColor2,
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        dashColor = dashColor,
        interiorColor = interiorColor,
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
        extras = extras,
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
        modPlateHolder = GetVehicleMod(vehicle, 25),
        modVanityPlate = GetVehicleMod(vehicle, 26),
        modTrimA = GetVehicleMod(vehicle, 27),
        modOrnaments = GetVehicleMod(vehicle, 28),
        modDashboard = GetVehicleMod(vehicle, 29),
        modDial = GetVehicleMod(vehicle, 30),
        modDoorSpeaker = GetVehicleMod(vehicle, 31),
        modSeats = GetVehicleMod(vehicle, 32),
        modSteeringWheel = GetVehicleMod(vehicle, 33),
        modShifterLeavers = GetVehicleMod(vehicle, 34),
        modAPlate = GetVehicleMod(vehicle, 35),
        modSpeakers = GetVehicleMod(vehicle, 36),
        modTrunk = GetVehicleMod(vehicle, 37),
        modHydrolic = GetVehicleMod(vehicle, 38),
        modEngineBlock = GetVehicleMod(vehicle, 39),
        modAirFilter = GetVehicleMod(vehicle, 40),
        modStruts = GetVehicleMod(vehicle, 41),
        modArchCover = GetVehicleMod(vehicle, 42),
        modAerials = GetVehicleMod(vehicle, 43),
        modTrimB = GetVehicleMod(vehicle, 44),
        modTank = GetVehicleMod(vehicle, 45),
        modWindows = GetVehicleMod(vehicle, 46),
        modLivery = modLivery
    }

    return props
end

-- Exports
exports('GetCurrentRental', function()
    return currentRental
end)

exports('GetRentalVehicle', function()
    return rentalVehicle
end)

exports('IsInRentalVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then
        return Entity(vehicle).state.sb_rental == true
    end
    return false
end)

exports('GetVehicleProperties', function(vehicle)
    return GetVehicleProperties(vehicle)
end)
