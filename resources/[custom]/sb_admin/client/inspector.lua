-- sb_admin/client/inspector.lua
-- Prop Inspector - raycast from camera center, show model info overlay

InspectorActive = false
local inspectorData = {}

function ToggleInspector()
    InspectorActive = not InspectorActive
    SendNUIMessage({
        action = 'inspectorState',
        active = InspectorActive
    })
    if not InspectorActive then
        SendNUIMessage({
            action = 'inspectorData',
            data = nil
        })
    end
end

-- Get entity type as string
local function GetEntityTypeString(entity)
    if not DoesEntityExist(entity) then return 'None' end
    local eType = GetEntityType(entity)
    if eType == 1 then return 'Ped'
    elseif eType == 2 then return 'Vehicle'
    elseif eType == 3 then return 'Object'
    else return 'Unknown' end
end

-- Resolve model name from entity
local function ResolveModelName(entity, hash)
    local eType = GetEntityType(entity)

    -- Vehicles: use display name native
    if eType == 2 then
        local name = GetDisplayNameFromVehicleModel(hash)
        if name and name ~= '' and name ~= 'CARNOTFOUND' then
            return string.lower(name)
        end
    end

    -- Peds: show ped type info
    if eType == 1 then
        local pedType = GetPedType(entity)
        local typeNames = {
            [0] = 'player', [1] = 'male_civil', [2] = 'female_civil',
            [3] = 'cop', [4] = 'gang_albanian', [5] = 'gang_biker',
            [6] = 'gang_italian', [7] = 'gang_russian', [8] = 'gang_jamaican',
            [9] = 'gang_african', [10] = 'gang_korean', [11] = 'gang_chinese',
            [12] = 'gang_pr', [13] = 'dealer', [14] = 'medic',
            [15] = 'fireman', [20] = 'criminal', [21] = 'bum',
            [22] = 'prostitute', [26] = 'special', [27] = 'mission',
            [28] = 'swat', [29] = 'animal'
        }
        return 'ped:' .. (typeNames[pedType] or tostring(pedType))
    end

    -- Objects: no native reverse lookup, show hash
    return string.format("0x%08X", hash)
end

-- Inspector loop
CreateThread(function()
    while true do
        if InspectorActive then
            local camCoord = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)

            -- Direction from camera rotation
            local rX = camRot.x * math.pi / 180.0
            local rZ = camRot.z * math.pi / 180.0
            local dirX = -math.sin(rZ) * math.abs(math.cos(rX))
            local dirY = math.cos(rZ) * math.abs(math.cos(rX))
            local dirZ = math.sin(rX)

            local dest = vector3(
                camCoord.x + dirX * Config.InspectorMaxDistance,
                camCoord.y + dirY * Config.InspectorMaxDistance,
                camCoord.z + dirZ * Config.InspectorMaxDistance
            )

            -- Raycast (1=world, 2=vehicles, 4=peds, 8=objects, 16=foliage)
            local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, 30, PlayerPedId(), 0)
            local _, hit, hitCoord, _, entityHit = GetShapeTestResult(ray)

            -- Draw small marker at hit point only (no laser line)
            if hit == 1 and hitCoord then
                local r, g, b, a = table.unpack(Config.LaserColor)
                DrawMarker(28, hitCoord.x, hitCoord.y, hitCoord.z, 0, 0, 0, 0, 0, 0, 0.03, 0.03, 0.03, r, g, b, a, false, true, 2, nil, nil, false)
            end

            -- Disable attack/aim/melee while inspector is active
            DisableControlAction(0, 24, true)   -- Attack
            DisableControlAction(0, 25, true)   -- Aim
            DisableControlAction(0, 47, true)   -- Weapon (disable weapon fire)
            DisableControlAction(0, 140, true)  -- Melee attack light
            DisableControlAction(0, 141, true)  -- Melee attack heavy
            DisableControlAction(0, 142, true)  -- Melee attack alt
            DisableControlAction(0, 257, true)  -- Attack 2
            DisableControlAction(0, 263, true)  -- Melee attack 1
            DisableControlAction(0, 264, true)  -- Melee attack 2

            if hit == 1 and DoesEntityExist(entityHit) then
                local model = GetEntityModel(entityHit)
                local entityType = GetEntityTypeString(entityHit)
                local entityId = NetworkGetNetworkIdFromEntity(entityHit)
                local modelName = ResolveModelName(entityHit, model)
                local hashHex = string.format("0x%08X", model)

                inspectorData = {
                    modelName = modelName,
                    modelHash = hashHex,
                    entityType = entityType,
                    entityId = entityId or 0,
                    hitX = tonumber(string.format("%.2f", hitCoord.x)),
                    hitY = tonumber(string.format("%.2f", hitCoord.y)),
                    hitZ = tonumber(string.format("%.2f", hitCoord.z)),
                    hasEntity = true
                }
            elseif hit == 1 then
                inspectorData = {
                    modelName = 'world',
                    modelHash = '---',
                    entityType = 'World',
                    entityId = 0,
                    hitX = tonumber(string.format("%.2f", hitCoord.x)),
                    hitY = tonumber(string.format("%.2f", hitCoord.y)),
                    hitZ = tonumber(string.format("%.2f", hitCoord.z)),
                    hasEntity = false
                }
            else
                inspectorData = {
                    modelName = '---',
                    modelHash = '---',
                    entityType = 'None',
                    entityId = 0,
                    hitX = 0, hitY = 0, hitZ = 0,
                    hasEntity = false
                }
            end

            -- Send to NUI overlay
            SendNUIMessage({
                action = 'inspectorData',
                data = inspectorData
            })

            -- Left click: copy all info to clipboard (using disabled control check)
            if IsDisabledControlJustPressed(0, 24) then
                if inspectorData.hasEntity then
                    local copyText = string.format(
                        "%s | %s | ID:%d | vector3(%.2f, %.2f, %.2f)",
                        inspectorData.modelName,
                        inspectorData.modelHash,
                        inspectorData.entityId,
                        inspectorData.hitX, inspectorData.hitY, inspectorData.hitZ
                    )
                    SendNUIMessage({
                        action = 'copyText',
                        text = copyText
                    })
                elseif inspectorData.hitX ~= 0 then
                    -- World hit: copy coords
                    local copyText = string.format(
                        "vector3(%.2f, %.2f, %.2f)",
                        inspectorData.hitX, inspectorData.hitY, inspectorData.hitZ
                    )
                    SendNUIMessage({
                        action = 'copyText',
                        text = copyText
                    })
                end
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
