-- Zone System
-- Sphere and Box zone definitions with point-in-zone math

ZoneRegistry = {
    zones = {},
    zoneCount = 0
}

local zoneIdCounter = 0

-----------------------------------------------------------
-- MATH HELPERS
-----------------------------------------------------------

local function pointInSphere(point, center, radius)
    return #(point - center) <= radius
end

local function pointInBox(point, center, width, length, height, heading)
    -- Translate point to box local space
    local rad = math.rad(-heading)
    local cos = math.cos(rad)
    local sin = math.sin(rad)

    local dx = point.x - center.x
    local dy = point.y - center.y
    local dz = point.z - center.z

    -- Rotate to local axes
    local localX = dx * cos - dy * sin
    local localY = dx * sin + dy * cos
    local localZ = dz

    local hw = width / 2
    local hl = length / 2
    local hh = height / 2

    return localX >= -hw and localX <= hw
       and localY >= -hl and localY <= hl
       and localZ >= -hh and localZ <= hh
end

-----------------------------------------------------------
-- ZONE MANAGEMENT
-----------------------------------------------------------

function ZoneRegistry.AddSphereZone(name, coords, radius, options)
    zoneIdCounter = zoneIdCounter + 1
    local id = name or ('sphere_' .. zoneIdCounter)

    local zone = {
        id = id,
        type = 'sphere',
        coords = vector3(coords.x, coords.y, coords.z),
        radius = radius,
        options = options or {}
    }

    ZoneRegistry.zones[id] = zone
    ZoneRegistry.zoneCount = ZoneRegistry.zoneCount + 1
    return id
end

function ZoneRegistry.AddBoxZone(name, coords, width, length, height, heading, options)
    zoneIdCounter = zoneIdCounter + 1
    local id = name or ('box_' .. zoneIdCounter)

    -- Handle alternative calling convention: (name, coords, width, length, zoneConfig, options)
    -- If height is a table, it's likely a zone config from ox_target style calls
    if type(height) == 'table' then
        local zoneConfig = height
        options = heading -- The 6th param is actually options
        height = zoneConfig.maxZ and (zoneConfig.maxZ - (zoneConfig.minZ or coords.z)) or 2.0
        heading = zoneConfig.heading or 0.0
    end

    local zone = {
        id = id,
        type = 'box',
        coords = vector3(coords.x, coords.y, coords.z),
        width = width,
        length = length,
        height = type(height) == 'number' and height or 2.0,
        heading = type(heading) == 'number' and heading or 0.0,
        options = options or {}
    }

    ZoneRegistry.zones[id] = zone
    ZoneRegistry.zoneCount = ZoneRegistry.zoneCount + 1
    return id
end

function ZoneRegistry.RemoveZone(name)
    if ZoneRegistry.zones[name] then
        ZoneRegistry.zones[name] = nil
        ZoneRegistry.zoneCount = ZoneRegistry.zoneCount - 1
    end
end

-----------------------------------------------------------
-- Get zones the player is inside
-----------------------------------------------------------

function ZoneRegistry.GetZonesAtPoint(point)
    local result = {}
    for id, zone in pairs(ZoneRegistry.zones) do
        local inside = false
        if zone.type == 'sphere' then
            inside = pointInSphere(point, zone.coords, zone.radius)
        elseif zone.type == 'box' then
            inside = pointInBox(point, zone.coords, zone.width, zone.length, zone.height, zone.heading)
        end
        if inside then
            result[#result + 1] = zone
        end
    end
    return result
end

-----------------------------------------------------------
-- Get filtered options from zones at point
-----------------------------------------------------------

function ZoneRegistry.GetOptionsAtPoint(point, playerJob)
    local zones = ZoneRegistry.GetZonesAtPoint(point)
    local options = {}

    for _, zone in ipairs(zones) do
        if zone.options then
            for _, opt in ipairs(zone.options) do
                local dist = #(point - zone.coords)
                local maxDist = opt.distance or Config.DefaultDistance

                if dist <= maxDist then
                    -- Job check
                    local jobPass = true
                    if opt.job then
                        if type(opt.job) == 'string' then
                            jobPass = (playerJob == opt.job)
                        elseif type(opt.job) == 'table' then
                            jobPass = false
                            for _, j in ipairs(opt.job) do
                                if playerJob == j then jobPass = true break end
                            end
                        end
                    end
                    if opt.groups and not opt.job then
                        jobPass = false
                        if type(opt.groups) == 'table' then
                            for _, g in ipairs(opt.groups) do
                                if playerJob == g then jobPass = true break end
                            end
                        end
                    end

                    if jobPass then
                        local canPass = true
                        if opt.canInteract then
                            local ok, result = pcall(opt.canInteract, nil, dist, zone.coords)
                            if ok then canPass = result else canPass = false end
                        end
                        if canPass then
                            options[#options + 1] = opt
                        end
                    end
                end
            end
        end
    end

    return options
end

-----------------------------------------------------------
-- Debug drawing
-----------------------------------------------------------

function ZoneRegistry.DrawDebug()
    for _, zone in pairs(ZoneRegistry.zones) do
        if zone.type == 'sphere' then
            DrawMarker(28, zone.coords.x, zone.coords.y, zone.coords.z,
                0, 0, 0, 0, 0, 0,
                zone.radius * 2, zone.radius * 2, zone.radius * 2,
                249, 115, 22, 50, false, false, 2, false, nil, nil, false)
        elseif zone.type == 'box' then
            DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z,
                0, 0, 0, 0, 0, zone.heading,
                zone.width, zone.length, zone.height,
                249, 115, 22, 50, false, false, 2, false, nil, nil, false)
        end
    end
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('AddSphereZone', function(name, coords, radius, options)
    return ZoneRegistry.AddSphereZone(name, coords, radius, options)
end)

exports('AddBoxZone', function(name, coords, width, length, height, heading, options)
    return ZoneRegistry.AddBoxZone(name, coords, width, length, height, heading, options)
end)

exports('RemoveZone', function(name)
    ZoneRegistry.RemoveZone(name)
end)
