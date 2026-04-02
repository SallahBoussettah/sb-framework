--[[
    Everyday Chaos RP - Shared Utilities
    Author: Salah Eddine Boussettah
]]

SBShared = {}

-- ============================================================================
-- STRING UTILITIES
-- ============================================================================

-- Generate random string
function SBShared.RandomStr(length)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local str = ''
    for i = 1, length do
        local rand = math.random(#chars)
        str = str .. string.sub(chars, rand, rand)
    end
    return str
end

-- Generate random integer
function SBShared.RandomInt(length)
    local nums = '0123456789'
    local str = ''
    for i = 1, length do
        local rand = math.random(#nums)
        str = str .. string.sub(nums, rand, rand)
    end
    return str
end

-- Split string by delimiter
function SBShared.SplitStr(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in string.gmatch(str, pattern) do
        result[#result + 1] = match
    end
    return result
end

-- Trim whitespace
function SBShared.Trim(str)
    if not str then return nil end
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

-- First letter uppercase
function SBShared.FirstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

-- ============================================================================
-- TABLE UTILITIES
-- ============================================================================

-- Check if value exists in table
function SBShared.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Get table length (works with non-sequential tables)
function SBShared.TableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Deep copy table
function SBShared.DeepCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            copy[k] = SBShared.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- ============================================================================
-- VALIDATION UTILITIES
-- ============================================================================

-- Check if function
function SBShared.IsFunction(func)
    return type(func) == 'function'
end

-- Check if table
function SBShared.IsTable(tbl)
    return type(tbl) == 'table'
end

-- Check if string
function SBShared.IsString(str)
    return type(str) == 'string'
end

-- Check if number
function SBShared.IsNumber(num)
    return type(num) == 'number'
end

-- ============================================================================
-- MATH UTILITIES
-- ============================================================================

-- Round number to decimal places
function SBShared.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Clamp value between min and max
function SBShared.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- ============================================================================
-- FORMAT UTILITIES
-- ============================================================================

-- Format money with commas
function SBShared.FormatMoney(amount)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return '$' .. formatted
end

-- Format phone number
function SBShared.FormatPhone(number)
    if not number or #number ~= 7 then return number end
    return string.sub(number, 1, 3) .. '-' .. string.sub(number, 4, 7)
end

-- ============================================================================
-- BLOOD TYPES
-- ============================================================================
SBShared.BloodTypes = {
    "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"
}

function SBShared.GetRandomBloodType()
    return SBShared.BloodTypes[math.random(#SBShared.BloodTypes)]
end

-- ============================================================================
-- DEBUG
-- ============================================================================
function SBShared.Debug(...)
    if Config.Debug then
        print('[SB_CORE]', ...)
    end
end
