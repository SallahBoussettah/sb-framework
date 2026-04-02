-- Target Registry
-- Manages all target definitions: entity, model, global, bone

TargetRegistry = {
    entities = {},   -- [netId/handle] = {options}
    models = {},     -- [modelHash] = {options}
    bones = {},      -- [boneName] = {options}
    globalPed = {},
    globalVehicle = {},
    globalObject = {},
    globalPlayer = {}
}

-- Helper: normalize options table
local function normalizeOptions(options)
    local result = {}
    if options then
        for _, opt in ipairs(options) do
            if opt.name and opt.label then
                result[#result + 1] = {
                    name = opt.name,
                    label = opt.label,
                    icon = opt.icon or 'fa-circle',
                    distance = opt.distance or Config.DefaultDistance,
                    canInteract = opt.canInteract,
                    action = opt.action,
                    event = opt.event,
                    serverEvent = opt.serverEvent,
                    job = opt.job,
                    groups = opt.groups,
                    item = opt.item
                }
            end
        end
    end
    return result
end

-- Helper: remove options by name from a list
local function removeByName(optionsList, names)
    if not names then return {} end
    if type(names) == 'string' then names = {names} end
    local nameSet = {}
    for _, n in ipairs(names) do nameSet[n] = true end
    local result = {}
    for _, opt in ipairs(optionsList) do
        if not nameSet[opt.name] then
            result[#result + 1] = opt
        end
    end
    return result
end

-----------------------------------------------------------
-- ENTITY TARGETS
-----------------------------------------------------------

function TargetRegistry.AddTargetEntity(entities, options)
    if type(entities) ~= 'table' then entities = {entities} end
    local opts = normalizeOptions(options)
    for _, entity in ipairs(entities) do
        if not TargetRegistry.entities[entity] then
            TargetRegistry.entities[entity] = {}
        end
        for _, opt in ipairs(opts) do
            TargetRegistry.entities[entity][#TargetRegistry.entities[entity] + 1] = opt
        end
    end
end

function TargetRegistry.RemoveTargetEntity(entities, names)
    if type(entities) ~= 'table' then entities = {entities} end
    for _, entity in ipairs(entities) do
        if TargetRegistry.entities[entity] then
            if names then
                TargetRegistry.entities[entity] = removeByName(TargetRegistry.entities[entity], names)
                if #TargetRegistry.entities[entity] == 0 then
                    TargetRegistry.entities[entity] = nil
                end
            else
                TargetRegistry.entities[entity] = nil
            end
        end
    end
end

-----------------------------------------------------------
-- MODEL TARGETS
-----------------------------------------------------------

function TargetRegistry.AddTargetModel(models, options)
    if type(models) ~= 'table' then models = {models} end
    local opts = normalizeOptions(options)
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and joaat(model) or model
        if not TargetRegistry.models[hash] then
            TargetRegistry.models[hash] = {}
        end
        for _, opt in ipairs(opts) do
            TargetRegistry.models[hash][#TargetRegistry.models[hash] + 1] = opt
        end
    end
end

function TargetRegistry.RemoveTargetModel(models, names)
    if type(models) ~= 'table' then models = {models} end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and joaat(model) or model
        if TargetRegistry.models[hash] then
            if names then
                TargetRegistry.models[hash] = removeByName(TargetRegistry.models[hash], names)
                if #TargetRegistry.models[hash] == 0 then
                    TargetRegistry.models[hash] = nil
                end
            else
                TargetRegistry.models[hash] = nil
            end
        end
    end
end

-----------------------------------------------------------
-- GLOBAL TARGETS
-----------------------------------------------------------

function TargetRegistry.AddGlobalPed(options)
    local opts = normalizeOptions(options)
    for _, opt in ipairs(opts) do
        TargetRegistry.globalPed[#TargetRegistry.globalPed + 1] = opt
    end
end

function TargetRegistry.RemoveGlobalPed(name)
    TargetRegistry.globalPed = removeByName(TargetRegistry.globalPed, name)
end

function TargetRegistry.AddGlobalVehicle(options)
    local opts = normalizeOptions(options)
    for _, opt in ipairs(opts) do
        TargetRegistry.globalVehicle[#TargetRegistry.globalVehicle + 1] = opt
    end
end

function TargetRegistry.RemoveGlobalVehicle(name)
    TargetRegistry.globalVehicle = removeByName(TargetRegistry.globalVehicle, name)
end

function TargetRegistry.AddGlobalObject(options)
    local opts = normalizeOptions(options)
    for _, opt in ipairs(opts) do
        TargetRegistry.globalObject[#TargetRegistry.globalObject + 1] = opt
    end
end

function TargetRegistry.RemoveGlobalObject(name)
    TargetRegistry.globalObject = removeByName(TargetRegistry.globalObject, name)
end

function TargetRegistry.AddGlobalPlayer(options)
    local opts = normalizeOptions(options)
    for _, opt in ipairs(opts) do
        TargetRegistry.globalPlayer[#TargetRegistry.globalPlayer + 1] = opt
    end
end

function TargetRegistry.RemoveGlobalPlayer(name)
    TargetRegistry.globalPlayer = removeByName(TargetRegistry.globalPlayer, name)
end

-----------------------------------------------------------
-- BONE TARGETS
-----------------------------------------------------------

function TargetRegistry.AddTargetBone(bones, options)
    if type(bones) ~= 'table' then bones = {bones} end
    local opts = normalizeOptions(options)
    for _, bone in ipairs(bones) do
        if not TargetRegistry.bones[bone] then
            TargetRegistry.bones[bone] = {}
        end
        for _, opt in ipairs(opts) do
            TargetRegistry.bones[bone][#TargetRegistry.bones[bone] + 1] = opt
        end
    end
end

function TargetRegistry.RemoveTargetBone(bones, name)
    if type(bones) ~= 'table' then bones = {bones} end
    for _, bone in ipairs(bones) do
        if TargetRegistry.bones[bone] then
            if name then
                TargetRegistry.bones[bone] = removeByName(TargetRegistry.bones[bone], name)
                if #TargetRegistry.bones[bone] == 0 then
                    TargetRegistry.bones[bone] = nil
                end
            else
                TargetRegistry.bones[bone] = nil
            end
        end
    end
end

-----------------------------------------------------------
-- Get options for a given entity
-----------------------------------------------------------

function TargetRegistry.GetOptionsForEntity(entity, playerCoords, playerJob)
    local options = {}
    local entityType = GetEntityType(entity)

    -- Skip invalid entities (world geometry, etc.)
    if entityType == 0 then return options end

    local entityCoords = GetEntityCoords(entity)
    local distance = #(playerCoords - entityCoords)
    local modelHash = GetEntityModel(entity)

    -- Specific entity targets
    if TargetRegistry.entities[entity] then
        for _, opt in ipairs(TargetRegistry.entities[entity]) do
            options[#options + 1] = opt
        end
    end

    -- Model targets
    if TargetRegistry.models[modelHash] then
        for _, opt in ipairs(TargetRegistry.models[modelHash]) do
            options[#options + 1] = opt
        end
    end

    -- Global targets based on entity type
    local globalList
    if entityType == 1 then
        -- Ped: check if player or NPC
        local isPlayer = IsPedAPlayer(entity)
        if isPlayer then
            globalList = TargetRegistry.globalPlayer
        else
            globalList = TargetRegistry.globalPed
        end
    elseif entityType == 2 then
        globalList = TargetRegistry.globalVehicle
    elseif entityType == 3 then
        globalList = TargetRegistry.globalObject
    end

    if globalList then
        for _, opt in ipairs(globalList) do
            options[#options + 1] = opt
        end
    end

    -- Bone targets (vehicles only)
    if entityType == 2 then
        for boneName, boneOpts in pairs(TargetRegistry.bones) do
            local boneIndex = GetEntityBoneIndexByName(entity, boneName)
            if boneIndex ~= -1 then
                local bonePos = GetWorldPositionOfEntityBone(entity, boneIndex)
                local boneDist = #(playerCoords - bonePos)
                for _, opt in ipairs(boneOpts) do
                    local boneOpt = {}
                    for k, v in pairs(opt) do boneOpt[k] = v end
                    boneOpt._boneDist = boneDist
                    options[#options + 1] = boneOpt
                end
            end
        end
    end

    -- Filter options
    local filtered = {}
    for _, opt in ipairs(options) do
        local optDist = opt._boneDist or distance
        local maxDist = opt.distance or Config.DefaultDistance
        if optDist <= maxDist then
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
                -- canInteract check
                local canPass = true
                if opt.canInteract then
                    local ok, result = pcall(opt.canInteract, entity, optDist, entityCoords)
                    if ok then canPass = result else canPass = false end
                end
                if canPass then
                    filtered[#filtered + 1] = opt
                end
            end
        end
    end

    return filtered
end

-----------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------

exports('AddTargetEntity', function(entities, options)
    TargetRegistry.AddTargetEntity(entities, options)
end)

exports('RemoveTargetEntity', function(entities, names)
    TargetRegistry.RemoveTargetEntity(entities, names)
end)

exports('AddTargetModel', function(models, options)
    TargetRegistry.AddTargetModel(models, options)
end)

exports('RemoveTargetModel', function(models, names)
    TargetRegistry.RemoveTargetModel(models, names)
end)

exports('AddGlobalPed', function(options)
    TargetRegistry.AddGlobalPed(options)
end)

exports('RemoveGlobalPed', function(name)
    TargetRegistry.RemoveGlobalPed(name)
end)

exports('AddGlobalVehicle', function(options)
    TargetRegistry.AddGlobalVehicle(options)
end)

exports('RemoveGlobalVehicle', function(name)
    TargetRegistry.RemoveGlobalVehicle(name)
end)

exports('AddGlobalObject', function(options)
    TargetRegistry.AddGlobalObject(options)
end)

exports('RemoveGlobalObject', function(name)
    TargetRegistry.RemoveGlobalObject(name)
end)

exports('AddGlobalPlayer', function(options)
    TargetRegistry.AddGlobalPlayer(options)
end)

exports('RemoveGlobalPlayer', function(name)
    TargetRegistry.RemoveGlobalPlayer(name)
end)

exports('AddTargetBone', function(bones, options)
    TargetRegistry.AddTargetBone(bones, options)
end)

exports('RemoveTargetBone', function(bones, name)
    TargetRegistry.RemoveTargetBone(bones, name)
end)
