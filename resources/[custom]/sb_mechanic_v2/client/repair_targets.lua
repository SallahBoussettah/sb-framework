-- sb_mechanic_v2 | Repair Targets
-- ALT-click target registration: player holds a part, walks to vehicle, sees repair option

local SB = exports['sb_core']:GetCoreObject()

-- Track registered target names so we can clean up
local RegisteredBoneTargets = {}   -- { boneName = { targetName1, targetName2 } }
local RegisteredGlobalTargets = {} -- { targetName1, targetName2 }
local TargetsRegistered = false

-- ===== HELPER: Check if player is in workshop zone =====
local function IsInWorkshop()
    local pos = GetEntityCoords(PlayerPedId())
    local dist = #(pos - Config.WorkshopZone.coords)
    return dist <= Config.WorkshopZone.radius
end

-- ===== HELPER: Shared canInteract for repair targets =====
local function MakeCanInteract(repairKey)
    return function(entity)
        if RepairBusy then return false end
        if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
        if not entity or not DoesEntityExist(entity) then return false end
        if not Entity(entity).state.sb_plate then return false end

        local Player = SB.Functions.GetPlayerData()
        if not Player or not Config.IsMechanicJob(Player.job.name) then return false end

        local def = Repairs.Definitions[repairKey]
        if not def then return false end

        -- Check workshop requirement
        if def.location == 'workshop' and not IsInWorkshop() then
            return false
        end

        -- Check lift requirement for wheel/undercarriage zones
        local zone, zoneName = RepairZones.GetZoneForRepair(repairKey)
        if zone and zone.requiresLift then
            if not CarJack.IsLifted(entity) then
                return false
            end
        end

        return true
    end
end

-- ===== REGISTER ALL REPAIR TARGETS =====
-- Called once on resource start
local function RegisterRepairTargets()
    if TargetsRegistered then return end
    TargetsRegistered = true

    -- Group repairs by bone for efficient target registration
    -- Each bone gets ONE target per repair that uses it
    for repairKey, def in pairs(Repairs.Definitions) do
        local targetName = 'mechv2_repair_' .. repairKey

        if def.bone then
            -- Bone-specific target
            local boneName = def.bone
            exports['sb_target']:AddTargetBone({ boneName }, {
                {
                    name = targetName,
                    label = def.label,
                    icon = 'fa-wrench',
                    distance = 2.0,
                    canInteract = MakeCanInteract(repairKey),
                    action = function(entity)
                        PerformRepair(entity, repairKey)
                    end,
                },
            })

            if not RegisteredBoneTargets[boneName] then
                RegisteredBoneTargets[boneName] = {}
            end
            table.insert(RegisteredBoneTargets[boneName], targetName)
        else
            -- No bone = undercarriage/chassis (global vehicle target)
            exports['sb_target']:AddGlobalVehicle({
                {
                    name = targetName,
                    label = def.label,
                    icon = 'fa-wrench',
                    distance = 2.5,
                    canInteract = MakeCanInteract(repairKey),
                    action = function(entity)
                        PerformRepair(entity, repairKey)
                    end,
                },
            })
            table.insert(RegisteredGlobalTargets, targetName)
        end
    end
end

-- ===== INIT =====
CreateThread(function()
    -- Wait for sb_target to be ready
    Wait(2000)
    RegisterRepairTargets()
end)

-- ===== CLEANUP =====
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove all bone targets
    for boneName, targets in pairs(RegisteredBoneTargets) do
        for _, targetName in ipairs(targets) do
            exports['sb_target']:RemoveTargetBone({ boneName }, targetName)
        end
    end
    RegisteredBoneTargets = {}

    -- Remove all global vehicle targets
    for _, targetName in ipairs(RegisteredGlobalTargets) do
        exports['sb_target']:RemoveGlobalVehicle(targetName)
    end
    RegisteredGlobalTargets = {}

    TargetsRegistered = false
end)
