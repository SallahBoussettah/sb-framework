--[[
    Everyday Chaos RP - Garage System (Vehicle Properties)
    Author: Salah Eddine Boussettah

    Handles: Vehicle property extraction and application
]]

-- ============================================================================
-- GET VEHICLE PROPERTIES
-- ============================================================================

function GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local props = {}

    -- Basic info
    props.model = GetEntityModel(vehicle)
    props.plate = GetVehicleNumberPlateText(vehicle)
    props.plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    -- Health values
    props.bodyHealth = math.floor(GetVehicleBodyHealth(vehicle))
    props.engineHealth = math.floor(GetVehicleEngineHealth(vehicle))
    props.tankHealth = math.floor(GetVehiclePetrolTankHealth(vehicle))
    props.fuelLevel = GetVehicleFuelLevel(vehicle)
    props.dirtLevel = GetVehicleDirtLevel(vehicle)

    -- Colors
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local interiorColor = GetVehicleInteriorColour(vehicle)
    local dashboardColor = GetVehicleDashboardColour(vehicle)

    props.colors = {
        primary = colorPrimary,
        secondary = colorSecondary,
        pearlescent = pearlescentColor,
        wheel = wheelColor,
        interior = interiorColor,
        dashboard = dashboardColor,
    }

    -- Custom colors (RGB)
    local hasCustomPrimary, customPrimaryR, customPrimaryG, customPrimaryB = GetVehicleCustomPrimaryColour(vehicle)
    local hasCustomSecondary, customSecondaryR, customSecondaryG, customSecondaryB = GetVehicleCustomSecondaryColour(vehicle)

    if hasCustomPrimary then
        props.colors.customPrimary = { customPrimaryR, customPrimaryG, customPrimaryB }
    end

    if hasCustomSecondary then
        props.colors.customSecondary = { customSecondaryR, customSecondaryG, customSecondaryB }
    end

    -- Extras (0-14)
    props.extras = {}
    for i = 0, 14 do
        if DoesExtraExist(vehicle, i) then
            props.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    -- Neon lights
    props.neonEnabled = {
        IsVehicleNeonLightEnabled(vehicle, 0),  -- Left
        IsVehicleNeonLightEnabled(vehicle, 1),  -- Right
        IsVehicleNeonLightEnabled(vehicle, 2),  -- Front
        IsVehicleNeonLightEnabled(vehicle, 3),  -- Back
    }

    local neonR, neonG, neonB = GetVehicleNeonLightsColour(vehicle)
    props.neonColor = { neonR, neonG, neonB }

    -- Tyre smoke
    local tyreSmokeR, tyreSmokeG, tyreSmokeB = GetVehicleTyreSmokeColor(vehicle)
    props.tyreSmokeColor = { tyreSmokeR, tyreSmokeG, tyreSmokeB }

    -- Window tint
    props.windowTint = GetVehicleWindowTint(vehicle)

    -- Livery
    props.livery = GetVehicleLivery(vehicle)
    -- props.livery2 = GetVehicleLivery2(vehicle) -- Not available in all builds

    -- Mods
    props.wheels = GetVehicleWheelType(vehicle)
    props.modSpoilers = GetVehicleMod(vehicle, 0)
    props.modFrontBumper = GetVehicleMod(vehicle, 1)
    props.modRearBumper = GetVehicleMod(vehicle, 2)
    props.modSideSkirt = GetVehicleMod(vehicle, 3)
    props.modExhaust = GetVehicleMod(vehicle, 4)
    props.modFrame = GetVehicleMod(vehicle, 5)
    props.modGrille = GetVehicleMod(vehicle, 6)
    props.modHood = GetVehicleMod(vehicle, 7)
    props.modFender = GetVehicleMod(vehicle, 8)
    props.modRightFender = GetVehicleMod(vehicle, 9)
    props.modRoof = GetVehicleMod(vehicle, 10)
    props.modEngine = GetVehicleMod(vehicle, 11)
    props.modBrakes = GetVehicleMod(vehicle, 12)
    props.modTransmission = GetVehicleMod(vehicle, 13)
    props.modHorns = GetVehicleMod(vehicle, 14)
    props.modSuspension = GetVehicleMod(vehicle, 15)
    props.modArmor = GetVehicleMod(vehicle, 16)
    props.modTurbo = IsToggleModOn(vehicle, 18)
    props.modSmokeEnabled = IsToggleModOn(vehicle, 20)
    props.modXenon = IsToggleModOn(vehicle, 22)
    props.modFrontWheels = GetVehicleMod(vehicle, 23)
    props.modBackWheels = GetVehicleMod(vehicle, 24)
    props.modPlateHolder = GetVehicleMod(vehicle, 25)
    props.modVanityPlate = GetVehicleMod(vehicle, 26)
    props.modTrimA = GetVehicleMod(vehicle, 27)
    props.modOrnaments = GetVehicleMod(vehicle, 28)
    props.modDashboard = GetVehicleMod(vehicle, 29)
    props.modDial = GetVehicleMod(vehicle, 30)
    props.modDoorSpeaker = GetVehicleMod(vehicle, 31)
    props.modSeats = GetVehicleMod(vehicle, 32)
    props.modSteeringWheel = GetVehicleMod(vehicle, 33)
    props.modShifterLeavers = GetVehicleMod(vehicle, 34)
    props.modAPlate = GetVehicleMod(vehicle, 35)
    props.modSpeakers = GetVehicleMod(vehicle, 36)
    props.modTrunk = GetVehicleMod(vehicle, 37)
    props.modHydrolic = GetVehicleMod(vehicle, 38)
    props.modEngineBlock = GetVehicleMod(vehicle, 39)
    props.modAirFilter = GetVehicleMod(vehicle, 40)
    props.modStruts = GetVehicleMod(vehicle, 41)
    props.modArchCover = GetVehicleMod(vehicle, 42)
    props.modAerials = GetVehicleMod(vehicle, 43)
    props.modTrimB = GetVehicleMod(vehicle, 44)
    props.modTank = GetVehicleMod(vehicle, 45)
    props.modWindows = GetVehicleMod(vehicle, 46)
    props.modLivery = GetVehicleMod(vehicle, 48)

    -- Xenon light color
    if props.modXenon then
        props.xenonColor = GetVehicleXenonLightsColour(vehicle)
    end

    -- Tyre burst state
    props.tyresBurst = {}
    for i = 0, 5 do
        props.tyresBurst[tostring(i)] = IsVehicleTyreBurst(vehicle, i, false)
    end

    -- Door damage
    props.doorsBroken = {}
    for i = 0, 5 do
        props.doorsBroken[tostring(i)] = IsVehicleDoorDamaged(vehicle, i)
    end

    -- Window damage
    props.windowsBroken = {}
    for i = 0, 7 do
        props.windowsBroken[tostring(i)] = not IsVehicleWindowIntact(vehicle, i)
    end

    -- Body deformation (sample points across the vehicle to capture dent/crash damage)
    props.deformationPoints = {}
    local offsets = {
        vector3(0.0, 1.5, 0.0),    -- Front center
        vector3(-1.0, 1.0, 0.0),   -- Front left
        vector3(1.0, 1.0, 0.0),    -- Front right
        vector3(0.0, -1.5, 0.0),   -- Rear center
        vector3(-1.0, -1.0, 0.0),  -- Rear left
        vector3(1.0, -1.0, 0.0),   -- Rear right
        vector3(-1.2, 0.0, 0.0),   -- Left side
        vector3(1.2, 0.0, 0.0),    -- Right side
        vector3(0.0, 0.0, 0.8),    -- Roof
    }
    for _, offset in ipairs(offsets) do
        local deformation = GetVehicleDeformationAtPos(vehicle, offset.x, offset.y, offset.z)
        local magnitude = #deformation
        if magnitude > 0.01 then
            props.deformationPoints[#props.deformationPoints + 1] = {
                x = offset.x, y = offset.y, z = offset.z,
                damage = magnitude * 500.0
            }
        end
    end

    return props
end

-- ============================================================================
-- SET VEHICLE PROPERTIES
-- ============================================================================

function SetVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) then return false end
    if not props then return false end

    -- Wait for vehicle to be ready
    local timeout = 0
    while not NetworkHasControlOfEntity(vehicle) do
        NetworkRequestControlOfEntity(vehicle)
        Wait(10)
        timeout = timeout + 10
        if timeout > 2000 then break end
    end

    -- Plate
    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end

    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end

    -- Set mod kit for modifications
    SetVehicleModKit(vehicle, 0)

    -- Extras
    if props.extras then
        for k, v in pairs(props.extras) do
            local extraId = tonumber(k)
            if DoesExtraExist(vehicle, extraId) then
                SetVehicleExtra(vehicle, extraId, not v) -- Inverted API
            end
        end
    end

    -- Neon lights
    if props.neonEnabled then
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, i, props.neonEnabled[i + 1] or false)
        end
    end

    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    -- Tyre smoke
    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    -- Window tint
    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end

    -- Livery
    if props.livery and props.livery >= 0 then
        SetVehicleLivery(vehicle, props.livery)
    end

    -- if props.livery2 then
    --     SetVehicleLivery2(vehicle, props.livery2) -- Not available in all builds
    -- end

    -- Wheel type
    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
    end

    -- All mods (applied BEFORE colors to prevent mod installs from resetting colors)
    local modMap = {
        { 'modSpoilers', 0 },
        { 'modFrontBumper', 1 },
        { 'modRearBumper', 2 },
        { 'modSideSkirt', 3 },
        { 'modExhaust', 4 },
        { 'modFrame', 5 },
        { 'modGrille', 6 },
        { 'modHood', 7 },
        { 'modFender', 8 },
        { 'modRightFender', 9 },
        { 'modRoof', 10 },
        { 'modEngine', 11 },
        { 'modBrakes', 12 },
        { 'modTransmission', 13 },
        { 'modHorns', 14 },
        { 'modSuspension', 15 },
        { 'modArmor', 16 },
        { 'modFrontWheels', 23 },
        { 'modBackWheels', 24 },
        { 'modPlateHolder', 25 },
        { 'modVanityPlate', 26 },
        { 'modTrimA', 27 },
        { 'modOrnaments', 28 },
        { 'modDashboard', 29 },
        { 'modDial', 30 },
        { 'modDoorSpeaker', 31 },
        { 'modSeats', 32 },
        { 'modSteeringWheel', 33 },
        { 'modShifterLeavers', 34 },
        { 'modAPlate', 35 },
        { 'modSpeakers', 36 },
        { 'modTrunk', 37 },
        { 'modHydrolic', 38 },
        { 'modEngineBlock', 39 },
        { 'modAirFilter', 40 },
        { 'modStruts', 41 },
        { 'modArchCover', 42 },
        { 'modAerials', 43 },
        { 'modTrimB', 44 },
        { 'modTank', 45 },
        { 'modWindows', 46 },
        { 'modLivery', 48 },
    }

    for _, mod in ipairs(modMap) do
        local propName = mod[1]
        local modIndex = mod[2]
        if props[propName] and props[propName] >= 0 then
            SetVehicleMod(vehicle, modIndex, props[propName], false)
        end
    end

    -- Toggle mods
    if props.modTurbo ~= nil then
        ToggleVehicleMod(vehicle, 18, props.modTurbo)
    end

    if props.modSmokeEnabled ~= nil then
        ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled)
    end

    if props.modXenon ~= nil then
        ToggleVehicleMod(vehicle, 22, props.modXenon)
    end

    -- Xenon color
    if props.xenonColor then
        SetVehicleXenonLightsColour(vehicle, props.xenonColor)
    end

    -- Tank health (body + engine health moved to ApplyVehicleDamage for correct ordering)
    if props.tankHealth then
        SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0)
    end

    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
    end

    if props.dirtLevel then
        SetVehicleDirtLevel(vehicle, props.dirtLevel)
    end

    -- Tyre burst state
    if props.tyresBurst then
        for k, v in pairs(props.tyresBurst) do
            if v then
                SetVehicleTyreBurst(vehicle, tonumber(k), false, 1000.0)
            end
        end
    end

    -- ========================================================================
    -- COLORS APPLIED AFTER MODS (to prevent mod installs resetting them)
    -- ========================================================================
    ApplyVehicleColors(vehicle, props)

    -- ========================================================================
    -- DAMAGE APPLIED LAST (deformation before health, health resets visual mesh)
    -- ========================================================================
    ApplyVehicleDamage(vehicle, props)

    return true
end

-- ============================================================================
-- APPLY VEHICLE COLORS (standalone helper for re-application)
-- ============================================================================

function ApplyVehicleColors(vehicle, props)
    if not DoesEntityExist(vehicle) then return end
    if not props or not props.colors then return end

    -- Standard colors: only apply if NO custom RGB override exists for that slot
    -- GTA conflicts when both standard index and custom RGB are set
    local hasCustPrimary = props.colors.customPrimary and #props.colors.customPrimary == 3
    local hasCustSecondary = props.colors.customSecondary and #props.colors.customSecondary == 3

    if props.colors.primary ~= nil and props.colors.secondary ~= nil then
        -- Always set the base standard colors first as a foundation
        SetVehicleColours(vehicle, props.colors.primary, props.colors.secondary)
    end

    -- Pearlescent + wheel color (independent of custom RGB)
    if props.colors.pearlescent ~= nil and props.colors.wheel ~= nil then
        SetVehicleExtraColours(vehicle, props.colors.pearlescent, props.colors.wheel)
    end

    if props.colors.interior ~= nil then
        SetVehicleInteriorColour(vehicle, props.colors.interior)
    end

    if props.colors.dashboard ~= nil then
        SetVehicleDashboardColour(vehicle, props.colors.dashboard)
    end

    -- Custom RGB colors OVERRIDE standard colors — applied after SetVehicleColours
    if hasCustPrimary then
        SetVehicleCustomPrimaryColour(vehicle, props.colors.customPrimary[1], props.colors.customPrimary[2], props.colors.customPrimary[3])
    end

    if hasCustSecondary then
        SetVehicleCustomSecondaryColour(vehicle, props.colors.customSecondary[1], props.colors.customSecondary[2], props.colors.customSecondary[3])
    end
end

-- ============================================================================
-- APPLY VEHICLE DAMAGE (standalone helper for re-application)
-- ============================================================================

function ApplyVehicleDamage(vehicle, props)
    if not DoesEntityExist(vehicle) then return end
    if not props then return end

    -- Body deformation MUST be applied BEFORE body health
    -- SetVehicleBodyHealth resets the visual deformation mesh
    if props.deformationPoints and #props.deformationPoints > 0 then
        for _, def in ipairs(props.deformationPoints) do
            SetVehicleDamage(vehicle, def.x, def.y, def.z, def.damage, 100.0, true)
        end
    end

    -- Now set body health (preserves deformation applied above)
    if props.bodyHealth then
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end

    if props.engineHealth then
        SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
    end

    -- Window damage
    if props.windowsBroken then
        for k, v in pairs(props.windowsBroken) do
            if v then
                SmashVehicleWindow(vehicle, tonumber(k))
            end
        end
    end

    -- Door damage
    if props.doorsBroken then
        for k, v in pairs(props.doorsBroken) do
            if v then
                SetVehicleDoorBroken(vehicle, tonumber(k), false)
            end
        end
    end
end

-- Export for other resources if needed
exports('GetVehicleProperties', GetVehicleProperties)
exports('SetVehicleProperties', SetVehicleProperties)
exports('ApplyVehicleColors', ApplyVehicleColors)
exports('ApplyVehicleDamage', ApplyVehicleDamage)
