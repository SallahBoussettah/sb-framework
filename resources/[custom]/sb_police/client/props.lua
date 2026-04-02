-- =============================================
-- SB_POLICE - Props System
-- Traffic cones, barriers, spike strips, flares
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

-- Local state
local placedProps = {}      -- { entity, type, coords, particle }
local isOnDuty = false
local spikeCheckThread = nil

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

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return HasModelLoaded(hash) and hash or nil
end

local function LoadParticleFx(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local timeout = 0
    while not HasNamedPtfxAssetLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return HasNamedPtfxAssetLoaded(dict)
end

-- =============================================
-- Prop Placement
-- =============================================

function PlaceProp(propType)
    -- Check duty status
    if not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    -- Check prop limit
    if #placedProps >= Config.Props.MaxPerOfficer then
        exports['sb_notify']:Notify('Maximum props placed (' .. Config.Props.MaxPerOfficer .. ')', 'error', 3000)
        return
    end

    -- Get prop data
    local propData = Config.Props.Items[propType]
    if not propData then
        exports['sb_notify']:Notify('Invalid prop type', 'error', 3000)
        return
    end

    local playerPed = PlayerPedId()

    -- Check if in vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        exports['sb_notify']:Notify('Cannot place props from vehicle', 'error', 3000)
        return
    end

    -- Calculate spawn position (1.5m in front of player)
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local rad = math.rad(playerHeading)
    local spawnPos = vector3(
        playerCoords.x - math.sin(rad) * 1.5,
        playerCoords.y + math.cos(rad) * 1.5,
        playerCoords.z - 1.0
    )

    -- Play placement animation
    if propData.placeAnim then
        LoadAnimDict(propData.placeAnim.dict)
        TaskPlayAnim(playerPed, propData.placeAnim.dict, propData.placeAnim.anim, 8.0, -8.0, propData.placeAnim.duration, 0, 0, false, false, false)
        Wait(propData.placeAnim.duration * 0.6)  -- Wait for most of animation
    end

    -- Load and create model
    local modelHash = LoadModel(propData.model)
    if not modelHash then
        exports['sb_notify']:Notify('Failed to load prop model', 'error', 3000)
        return
    end

    local prop = CreateObject(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, true, false, false)
    SetEntityHeading(prop, playerHeading)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(modelHash)

    -- Handle particle effects (flares)
    local particleHandle = nil
    if propData.particle then
        if LoadParticleFx(propData.particle.dict) then
            local propCoords = GetEntityCoords(prop)
            UseParticleFxAssetNextCall(propData.particle.dict)
            particleHandle = StartParticleFxLoopedAtCoord(
                propData.particle.name,
                propCoords.x, propCoords.y, propCoords.z + 0.1,
                0.0, 0.0, 0.0,
                1.0, false, false, false, false
            )

            -- Auto-remove flare after duration
            if propData.particle.duration then
                SetTimeout(propData.particle.duration, function()
                    for i, p in ipairs(placedProps) do
                        if p.entity == prop then
                            RemovePropByIndex(i)
                            break
                        end
                    end
                end)
            end
        end
    end

    -- Store prop data
    local propInfo = {
        entity = prop,
        type = propType,
        coords = GetEntityCoords(prop),
        particle = particleHandle,
        isSpikeStrip = propData.isSpikeStrip or false
    }
    table.insert(placedProps, propInfo)

    exports['sb_notify']:Notify('Placed ' .. propData.label, 'success', 3000)
    print(('[sb_police] ^2Placed prop^7: %s (Entity: %d)'):format(propData.label, prop))

    -- Start spike strip monitoring if needed
    if propData.isSpikeStrip and not spikeCheckThread then
        StartSpikeStripMonitor()
    end

    return prop
end

-- =============================================
-- Prop Removal
-- =============================================

function RemoveNearestProp()
    if not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestIdx = nil
    local closestDist = Config.Props.RemoveDistance

    for i, propData in ipairs(placedProps) do
        if DoesEntityExist(propData.entity) then
            local propCoords = GetEntityCoords(propData.entity)
            local dist = #(playerCoords - propCoords)
            if dist < closestDist then
                closestDist = dist
                closestIdx = i
            end
        end
    end

    if closestIdx then
        RemovePropByIndex(closestIdx)
        exports['sb_notify']:Notify('Prop removed', 'info', 3000)
    else
        exports['sb_notify']:Notify('No props nearby', 'error', 3000)
    end
end

function RemovePropByIndex(idx)
    local propData = placedProps[idx]
    if not propData then return end

    -- Stop particle effect
    if propData.particle then
        StopParticleFxLooped(propData.particle, false)
    end

    -- Delete entity
    if DoesEntityExist(propData.entity) then
        DeleteEntity(propData.entity)
    end

    table.remove(placedProps, idx)
    print(('[sb_police] ^3Removed prop^7 at index %d'):format(idx))

    -- Check if we need to stop spike monitoring
    local hasSpikeStrips = false
    for _, p in ipairs(placedProps) do
        if p.isSpikeStrip then
            hasSpikeStrips = true
            break
        end
    end
    if not hasSpikeStrips then
        spikeCheckThread = nil
    end
end

function RemoveAllProps()
    if not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    local count = #placedProps
    if count == 0 then
        exports['sb_notify']:Notify('No props to remove', 'info', 3000)
        return
    end

    for i = #placedProps, 1, -1 do
        RemovePropByIndex(i)
    end

    exports['sb_notify']:Notify('Removed ' .. count .. ' props', 'success', 3000)
end

-- =============================================
-- Spike Strip System
-- =============================================

function StartSpikeStripMonitor()
    if spikeCheckThread then return end

    spikeCheckThread = CreateThread(function()
        while spikeCheckThread do
            -- Check if any spike strips exist
            local hasSpikeStrips = false
            for _, propData in ipairs(placedProps) do
                if propData.isSpikeStrip and DoesEntityExist(propData.entity) then
                    hasSpikeStrips = true
                    break
                end
            end

            if not hasSpikeStrips then
                spikeCheckThread = nil
                return
            end

            -- Get all nearby vehicles
            local playerCoords = GetEntityCoords(PlayerPedId())
            local vehicles = GetGamePool('CVehicle')

            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) then
                    local vehCoords = GetEntityCoords(vehicle)

                    -- Check against each spike strip
                    for _, propData in ipairs(placedProps) do
                        if propData.isSpikeStrip and DoesEntityExist(propData.entity) then
                            local spikeCoords = GetEntityCoords(propData.entity)
                            local dist = #(vehCoords - spikeCoords)

                            -- Vehicle is over spike strip
                            if dist < 3.5 then
                                local speed = GetEntitySpeed(vehicle)
                                if speed > 2.0 then  -- Only pop tires if moving
                                    -- Pop all tires
                                    for tire = 0, 5 do
                                        if not IsVehicleTyreBurst(vehicle, tire, false) then
                                            SetVehicleTyreBurst(vehicle, tire, true, 1000.0)
                                        end
                                    end

                                    -- Notify driver if it's a player
                                    local driver = GetPedInVehicleSeat(vehicle, -1)
                                    if driver and IsPedAPlayer(driver) then
                                        local driverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(driver))
                                        TriggerServerEvent('sb_police:server:notifySpikeHit', driverId)
                                    end

                                    print(('[sb_police] ^1Spike strip^7 popped tires on vehicle %d'):format(vehicle))
                                end
                            end
                        end
                    end
                end
            end

            Wait(100)  -- Check every 100ms
        end
    end)
end

-- =============================================
-- Commands
-- =============================================

RegisterCommand('cone', function()
    PlaceProp('cone')
end, false)

RegisterCommand('conelighted', function()
    PlaceProp('cone_lighted')
end, false)

RegisterCommand('barrier', function()
    PlaceProp('barrier')
end, false)

RegisterCommand('barrierarrow', function()
    PlaceProp('barrier_arrow')
end, false)

RegisterCommand('flare', function()
    PlaceProp('flare')
end, false)

RegisterCommand('spike', function()
    PlaceProp('spike')
end, false)

RegisterCommand('removeprop', function()
    RemoveNearestProp()
end, false)

RegisterCommand('clearprops', function()
    RemoveAllProps()
end, false)

RegisterCommand('propscount', function()
    exports['sb_notify']:Notify('Props placed: ' .. #placedProps .. '/' .. Config.Props.MaxPerOfficer, 'info', 3000)
end, false)

-- =============================================
-- Props Menu Command
-- =============================================

RegisterCommand('props', function()
    if not isOnDuty then
        exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        return
    end

    -- Show available commands in chat
    local cmdList = {
        '/cone - Traffic Cone',
        '/conelighted - Lighted Cone',
        '/barrier - Road Barrier',
        '/barrierarrow - Arrow Barrier',
        '/flare - Road Flare (5 min)',
        '/spike - Spike Strip',
        '/removeprop - Remove nearest',
        '/clearprops - Remove all',
        '/propscount - Show count'
    }

    for _, cmd in ipairs(cmdList) do
        TriggerEvent('chat:addMessage', {
            color = { 66, 135, 245 },
            args = { 'Props', cmd }
        })
    end

    exports['sb_notify']:Notify('Props: ' .. #placedProps .. '/' .. Config.Props.MaxPerOfficer, 'info', 3000)
end, false)

-- =============================================
-- Duty Status Sync
-- =============================================

RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    isOnDuty = onDuty

    -- If going off duty, clean up props
    if not onDuty then
        local count = #placedProps
        if count > 0 then
            for i = #placedProps, 1, -1 do
                RemovePropByIndex(i)
            end
            exports['sb_notify']:Notify('Props removed (off duty)', 'info', 3000)
        end
    end
end)

-- Server notification for spike strip hit
RegisterNetEvent('sb_police:client:spikeHitNotify', function()
    exports['sb_notify']:Notify('Your tires were shredded by spike strips!', 'error', 5000)
end)

-- =============================================
-- Exports
-- =============================================

exports('PlaceProp', PlaceProp)
exports('RemoveNearestProp', RemoveNearestProp)
exports('RemoveAllProps', RemoveAllProps)
exports('GetPlacedPropsCount', function() return #placedProps end)
exports('GetMaxProps', function() return Config.Props.MaxPerOfficer end)

-- =============================================
-- Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Clean up all placed props
    for i = #placedProps, 1, -1 do
        local propData = placedProps[i]
        if propData.particle then
            StopParticleFxLooped(propData.particle, false)
        end
        if DoesEntityExist(propData.entity) then
            DeleteEntity(propData.entity)
        end
    end
    placedProps = {}
    spikeCheckThread = nil

    print('[sb_police] ^3Props cleaned up on resource stop^7')
end)
