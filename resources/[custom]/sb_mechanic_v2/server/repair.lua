-- sb_mechanic_v2 | Phase 3: Server Repair Logic
-- Requirement checks, part consumption, tool durability, component restore, XP awards

local SB = SBMechanic.SB

-- Anti-exploit: per-player repair cooldowns { [source] = lastRepairTime }
local RepairCooldowns = {}

-- Concurrent repair lock { ["PLATE:component"] = source }
local ActiveRepairs = {}

-- ===================================================================
-- TOOL DURABILITY
-- ===================================================================
local function ReduceToolDurability(source, toolName)
    if not toolName then return true end

    local items = exports['sb_inventory']:GetItemsByName(source, toolName)
    local slot = items and items[1]
    if not slot then return false end

    local meta = slot.metadata or {}
    local defaultDurability = Config.ToolDurability[toolName] or 50
    meta.durability = (meta.durability or defaultDurability) - 1

    if meta.durability <= 0 then
        exports['sb_inventory']:RemoveItem(source, toolName, 1)
        local itemDef = CraftItems.ByName[toolName]
        local toolLabel = itemDef and itemDef.label or toolName
        TriggerClientEvent('sb_notify:client:Notify', source, toolLabel .. ' broke!', 'error', 4000)
        return true  -- tool consumed but repair still succeeds
    else
        exports['sb_inventory']:SetItemMetadata(source, slot.slot, meta)
        return true
    end
end

-- ===================================================================
-- CALLBACK: Check repair requirements
-- ===================================================================
SB.Functions.CreateCallback('sb_mechanic_v2:checkRepairReqs', function(source, cb, componentName, plate)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return cb({ canRepair = false, reason = 'Player not found' }) end

    -- Verify mechanic job
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then
        return cb({ canRepair = false, reason = 'Not a mechanic' })
    end

    -- Validate repair definition
    local def = Repairs.Definitions[componentName]
    if not def then
        return cb({ canRepair = false, reason = 'Unknown repair' })
    end

    local citizenid = Player.PlayerData.citizenid

    -- Check cooldown (also enforced in repairComponent, but early-reject here for UX)
    local now = os.time()
    if RepairCooldowns[source] and (now - RepairCooldowns[source]) < Config.RepairCooldown then
        local remaining = Config.RepairCooldown - (now - RepairCooldowns[source])
        return cb({ canRepair = false, reason = 'Please wait ' .. remaining .. 's before next repair' })
    end

    -- Check skill level
    local playerLevel = GetLevel(citizenid, def.skillCategory)
    if playerLevel < def.skillReq then
        local categoryLabels = {
            xp_engine = 'Engine', xp_transmission = 'Transmission', xp_brakes = 'Brakes',
            xp_suspension = 'Suspension', xp_body = 'Body', xp_electrical = 'Electrical',
            xp_wheels = 'Wheels',
        }
        local catLabel = categoryLabels[def.skillCategory] or def.skillCategory
        return cb({
            canRepair = false,
            reason = ('Requires %s Level %d (you have %d)'):format(catLabel, def.skillReq, playerLevel),
        })
    end

    -- Check tool (if required)
    if def.tool then
        local hasToolResult = exports['sb_inventory']:HasItem(source, def.tool)
        if not hasToolResult then
            local toolDef = CraftItems.ByName[def.tool]
            local toolLabel = toolDef and toolDef.label or def.tool
            return cb({ canRepair = false, reason = 'Missing: ' .. toolLabel })
        end
    end

    -- Check part (if required)
    local partQuality = nil
    if def.part then
        local partItems = exports['sb_inventory']:GetItemsByName(source, def.part)
        local partSlot = partItems and partItems[1]
        if not partSlot then
            local partDef = CraftItems.ByName[def.part]
            local partLabel = partDef and partDef.label or def.part
            return cb({ canRepair = false, reason = 'Missing: ' .. partLabel })
        end
        -- Read quality metadata
        local meta = partSlot.metadata or {}
        partQuality = {
            name = meta.quality or 'standard',
            label = meta.qualityLabel or 'Standard',
            maxRestore = meta.maxRestore or 85,
            degradeMult = meta.degradeMult or 1.0,
        }
    end

    cb({
        canRepair = true,
        partQuality = partQuality,
    })
end)

-- ===================================================================
-- CALLBACK: Execute repair
-- ===================================================================
SB.Functions.CreateCallback('sb_mechanic_v2:repairComponent', function(source, cb, plate, componentName, failCount, inWorkshop)
    local Player = SB.Functions.GetPlayer(source)
    if not Player then return cb({ success = false }) end

    -- Re-validate everything (anti-exploit)
    if not Config.IsMechanicJob(Player.PlayerData.job.name) then
        return cb({ success = false })
    end

    local def = Repairs.Definitions[componentName]
    if not def then return cb({ success = false }) end

    -- Concurrent repair lock: prevent two players repairing same component on same vehicle
    local lockKey = (plate or '') .. ':' .. componentName
    if ActiveRepairs[lockKey] and ActiveRepairs[lockKey] ~= source then
        return cb({ success = false })
    end
    ActiveRepairs[lockKey] = source

    local citizenid = Player.PlayerData.citizenid

    -- Check skill level
    local playerLevel = GetLevel(citizenid, def.skillCategory)
    if playerLevel < def.skillReq then
        return cb({ success = false })
    end

    -- Check cooldown
    local now = os.time()
    if RepairCooldowns[source] and (now - RepairCooldowns[source]) < Config.RepairCooldown then
        return cb({ success = false })
    end

    -- Validate plate
    if not plate or type(plate) ~= 'string' or #plate == 0 or #plate > 8 then
        return cb({ success = false })
    end

    -- Load condition
    local cond = LoadCondition(plate)
    if not cond then return cb({ success = false }) end

    -- Check tool
    if def.tool then
        local hasToolResult = exports['sb_inventory']:HasItem(source, def.tool)
        if not hasToolResult then return cb({ success = false }) end
    end

    -- Check and read part quality
    local partQuality = nil
    if def.part then
        local partItems = exports['sb_inventory']:GetItemsByName(source, def.part)
        local partSlot = partItems and partItems[1]
        if not partSlot then return cb({ success = false }) end
        local meta = partSlot.metadata or {}
        partQuality = {
            maxRestore = meta.maxRestore or 85,
            degradeMult = meta.degradeMult or 1.0,
            label = meta.qualityLabel or 'Standard',
        }
    end

    -- Determine restore value
    local restoreValue
    if def.isToolOnly then
        -- Alignment: restore based on skill level tier
        local tier = Config.QualityTiers[playerLevel] or Config.QualityTiers[1]
        restoreValue = tier.maxRestore
    elseif partQuality then
        restoreValue = partQuality.maxRestore
    else
        -- Fluid with no quality metadata: default 85
        restoreValue = 85
    end

    -- Cap outside workshop (mobile repair)
    if not inWorkshop and Config.MobileRepair and Config.MobileRepair.maxRestore then
        restoreValue = math.min(restoreValue, Config.MobileRepair.maxRestore)
    end

    -- Apply fail penalty
    failCount = failCount or 0
    if failCount >= 2 then
        restoreValue = math.floor(restoreValue * 0.5)
    end

    -- Get target components
    local targetComponents = Repairs.GetComponents(componentName)

    -- Set component values
    for _, compName in ipairs(targetComponents) do
        if cond[compName] ~= nil then
            cond[compName] = math.max(0.0, math.min(100.0, restoreValue))
        end
    end

    -- Mark dirty for DB save
    SBMechanic.DirtyPlates[plate] = true

    -- Remove part (consume)
    if def.part then
        exports['sb_inventory']:RemoveItem(source, def.part, 1)
    end

    -- Reduce tool durability
    if def.tool then
        ReduceToolDurability(source, def.tool)
    end

    -- Award XP
    local xpGain = def.xpReward or 0
    if xpGain > 0 then
        AddXP(citizenid, def.skillCategory, xpGain)
    end

    -- Increment total_jobs stat
    local skills = SBMechanic.Skills[citizenid]
    if skills then
        skills.total_jobs = (skills.total_jobs or 0) + 1
        SaveSkills(citizenid)
    end

    -- Set cooldown
    RepairCooldowns[source] = now

    -- Release concurrent lock
    ActiveRepairs[lockKey] = nil

    -- Broadcast condition update to ALL clients (so symptoms update for drivers)
    local update = {}
    for _, comp in ipairs(Components.List) do
        update[comp.name] = cond[comp.name]
    end
    TriggerClientEvent('sb_mechanic_v2:conditionUpdate', -1, plate, update)

    cb({
        success = true,
        newValue = restoreValue,
        xpGain = xpGain,
        qualityLabel = partQuality and partQuality.label or (def.isToolOnly and 'Skill-based' or 'Standard'),
    })
end)

-- Cleanup cooldowns and locks on disconnect
AddEventHandler('playerDropped', function()
    RepairCooldowns[source] = nil
    -- Release any active repair locks held by this player
    for key, owner in pairs(ActiveRepairs) do
        if owner == source then
            ActiveRepairs[key] = nil
        end
    end
end)
