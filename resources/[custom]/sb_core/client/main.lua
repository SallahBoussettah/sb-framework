--[[
    Everyday Chaos RP - Client Main
    Author: Salah Eddine Boussettah
]]

-- ============================================================================
-- CORE OBJECT INITIALIZATION
-- ============================================================================
SB = {}
SB.Config = Config
SB.Shared = SBShared
SB.PlayerData = {}
SB.ServerCallbacks = {}
SB.ClientCallbacks = {}
SB.Functions = {}

local isLoggedIn = false

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Get core object
exports('GetCoreObject', function()
    return SB
end)

-- Get player data
exports('GetPlayerData', function()
    return SB.PlayerData
end)

-- Check if logged in
exports('IsLoggedIn', function()
    return isLoggedIn
end)

-- ============================================================================
-- STATE
-- ============================================================================

function SB.Functions.IsLoggedIn()
    return isLoggedIn
end

function SB.Functions.SetLoggedIn(state)
    isLoggedIn = state
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Wait for network to be ready
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    SBShared.Debug('Client initialized, waiting for player load...')
end)

-- ============================================================================
-- RESOURCE EVENTS
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    SBShared.Debug('SB_CORE client started')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Clean up
    SB.PlayerData = {}
    isLoggedIn = false
end)
