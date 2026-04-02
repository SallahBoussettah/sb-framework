-- sb_mechanic_v2 | Server Skills
-- Mechanic XP CRUD, level calculation

local SB = SBMechanic.SB

-- ===== LOAD SKILLS FROM DB =====
function LoadSkills(citizenid)
    if SBMechanic.Skills[citizenid] then
        return SBMechanic.Skills[citizenid]
    end

    local row = MySQL.single.await('SELECT * FROM mechanic_skills WHERE citizenid = ?', { citizenid })

    if not row then
        -- Auto-create record
        MySQL.insert.await('INSERT INTO mechanic_skills (citizenid) VALUES (?)', { citizenid })
        row = {
            citizenid = citizenid,
            xp_engine = 0, xp_transmission = 0, xp_brakes = 0, xp_suspension = 0,
            xp_body = 0, xp_electrical = 0, xp_paint = 0, xp_wheels = 0,
            xp_crafting = 0, xp_diagnostics = 0,
            total_jobs = 0, successful_diagnoses = 0, failed_diagnoses = 0,
            parts_crafted = 0, parts_recycled = 0,
        }
    end

    SBMechanic.Skills[citizenid] = row
    return row
end

-- ===== SAVE SKILLS TO DB =====
function SaveSkills(citizenid)
    local skills = SBMechanic.Skills[citizenid]
    if not skills then return end

    MySQL.update.await([[
        UPDATE mechanic_skills SET
            xp_engine = ?, xp_transmission = ?, xp_brakes = ?, xp_suspension = ?,
            xp_body = ?, xp_electrical = ?, xp_paint = ?, xp_wheels = ?,
            xp_crafting = ?, xp_diagnostics = ?,
            total_jobs = ?, successful_diagnoses = ?, failed_diagnoses = ?,
            parts_crafted = ?, parts_recycled = ?
        WHERE citizenid = ?
    ]], {
        skills.xp_engine, skills.xp_transmission, skills.xp_brakes, skills.xp_suspension,
        skills.xp_body, skills.xp_electrical, skills.xp_paint, skills.xp_wheels,
        skills.xp_crafting, skills.xp_diagnostics,
        skills.total_jobs, skills.successful_diagnoses, skills.failed_diagnoses,
        skills.parts_crafted, skills.parts_recycled,
        citizenid,
    })
end

-- ===== LEVEL CALCULATION =====
function GetLevel(citizenid, category)
    local skills = SBMechanic.Skills[citizenid]
    if not skills then return 1 end

    local xp = skills[category] or 0
    local level = 1
    for lvl, threshold in pairs(Config.XP.levels) do
        if xp >= threshold and lvl > level then
            level = lvl
        end
    end
    return level
end

-- ===== ADD XP =====
function AddXP(citizenid, category, amount)
    local skills = LoadSkills(citizenid)
    if not skills[category] then return false end

    skills[category] = skills[category] + amount
    SaveSkills(citizenid)
    return true
end

-- ===== SERVER EXPORTS =====
exports('GetSkills', function(citizenid)
    return LoadSkills(citizenid)
end)

exports('AddXP', function(citizenid, category, amount)
    return AddXP(citizenid, category, amount)
end)

exports('GetLevel', function(citizenid, category)
    return GetLevel(citizenid, category)
end)

-- ===== CALLBACKS =====
SB.Functions.CreateCallback('sb_mechanic_v2:getSkills', function(source, cb, citizenid)
    local skills = LoadSkills(citizenid)
    cb(skills)
end)

-- ===== CLEANUP ON CHARACTER SWITCH =====
-- When a player switches characters, save and clear the old character's skills cache
AddEventHandler('SB:Server:OnPlayerUnload', function(src)
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    if citizenid and SBMechanic.Skills[citizenid] then
        SaveSkills(citizenid)
        SBMechanic.Skills[citizenid] = nil
    end
end)

-- ===== CLEANUP ON PLAYER DROP =====
AddEventHandler('playerDropped', function()
    local src = source
    local Player = SB.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    if citizenid and SBMechanic.Skills[citizenid] then
        SaveSkills(citizenid)
        SBMechanic.Skills[citizenid] = nil
    end
end)
