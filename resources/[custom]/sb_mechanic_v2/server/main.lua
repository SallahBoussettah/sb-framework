-- sb_mechanic_v2 | Server Main
-- DB table creation, SBMechanic global, resource lifecycle

local SB = exports['sb_core']:GetCoreObject()

-- Global server object for cross-file access
SBMechanic = {
    SB = SB,
    Conditions = {},   -- plate -> condition table (in-memory cache)
    DirtyPlates = {},  -- plate -> true (needs DB save)
    Skills = {},       -- citizenid -> skills table (in-memory cache)
}

-- ===== DATABASE TABLE CREATION =====
local function CreateTables()
    -- Build component columns for vehicle_condition
    local componentCols = ''
    for _, comp in ipairs(Components.List) do
        componentCols = componentCols .. string.format(
            '`%s` FLOAT NOT NULL DEFAULT %.1f,\n',
            comp.name, comp.default
        )
    end

    local createCondition = string.format([[
        CREATE TABLE IF NOT EXISTS `vehicle_condition` (
            `plate` VARCHAR(8) NOT NULL,
            %s
            `total_km` FLOAT NOT NULL DEFAULT 0.0,
            `last_oil_change_km` FLOAT NOT NULL DEFAULT 0.0,
            `last_service_km` FLOAT NOT NULL DEFAULT 0.0,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], componentCols)

    MySQL.query.await(createCondition)
    print('[sb_mechanic_v2] vehicle_condition table ready')

    local createSkills = [[
        CREATE TABLE IF NOT EXISTS `mechanic_skills` (
            `citizenid` VARCHAR(50) NOT NULL,
            `xp_engine` INT NOT NULL DEFAULT 0,
            `xp_transmission` INT NOT NULL DEFAULT 0,
            `xp_brakes` INT NOT NULL DEFAULT 0,
            `xp_suspension` INT NOT NULL DEFAULT 0,
            `xp_body` INT NOT NULL DEFAULT 0,
            `xp_electrical` INT NOT NULL DEFAULT 0,
            `xp_paint` INT NOT NULL DEFAULT 0,
            `xp_wheels` INT NOT NULL DEFAULT 0,
            `xp_crafting` INT NOT NULL DEFAULT 0,
            `xp_diagnostics` INT NOT NULL DEFAULT 0,
            `total_jobs` INT NOT NULL DEFAULT 0,
            `successful_diagnoses` INT NOT NULL DEFAULT 0,
            `failed_diagnoses` INT NOT NULL DEFAULT 0,
            `parts_crafted` INT NOT NULL DEFAULT 0,
            `parts_recycled` INT NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    MySQL.query.await(createSkills)
    print('[sb_mechanic_v2] mechanic_skills table ready')
end

-- ===== PERIODIC DB SAVE =====
local function StartSaveLoop()
    CreateThread(function()
        while true do
            Wait(Config.DBSaveInterval * 1000)
            SaveAllDirty()
        end
    end)
end

-- Save all dirty conditions to DB (called from condition.lua)
function SaveAllDirty()
    -- Swap to new table BEFORE iterating to avoid race condition
    -- New dirty entries during save go into the fresh table
    local snapshot = SBMechanic.DirtyPlates
    SBMechanic.DirtyPlates = {}

    local count = 0
    for plate, _ in pairs(snapshot) do
        local cond = SBMechanic.Conditions[plate]
        if cond then
            SaveConditionToDB(plate, cond)
            count = count + 1
        end
    end
    if count > 0 then
        print('[sb_mechanic_v2] Saved ' .. count .. ' vehicle conditions to DB')
    end
end

-- ===== UTILITY CALLBACK: Check if player has an item =====
SB.Functions.CreateCallback('sb_mechanic_v2:hasItem', function(source, cb, itemName)
    if not itemName or type(itemName) ~= 'string' then return cb(false) end
    local count = exports['sb_inventory']:GetItemCount(source, itemName)
    cb(count and count > 0)
end)

-- ===== RESOURCE LIFECYCLE =====
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateTables()
    CraftItems.RegisterAll()
    StartSaveLoop()
    print('[sb_mechanic_v2] Phase 1A + Phase 2 loaded - Vehicle condition + crafting system active')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Save all dirty conditions before shutdown
    SaveAllDirty()
    print('[sb_mechanic_v2] All conditions saved on shutdown')
end)
