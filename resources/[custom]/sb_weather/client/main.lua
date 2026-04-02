local currentWeather = Config.DefaultWeather

-- ============================================================
-- Apply weather — clears GTA randomisation, forces our type
-- ============================================================

local function ApplyWeather(weatherType)
    currentWeather = weatherType

    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weatherType)
    SetWeatherTypeNow(weatherType)
    SetWeatherTypeNowPersist(weatherType)
    SetOverrideWeather(weatherType)

    -- Snow rendering
    local isSnow = (weatherType == 'SNOW' or weatherType == 'SNOWLIGHT'
                    or weatherType == 'BLIZZARD' or weatherType == 'XMAS')
    SetForceVehicleTrails(isSnow)
    SetForcePedFootstepsTracks(isSnow)
end

-- ============================================================
-- Receive sync from server
-- ============================================================

RegisterNetEvent('sb_weather:sync', function(weatherType)
    ApplyWeather(weatherType)
end)

-- ============================================================
-- On resource start / player spawn — request current weather
-- ============================================================

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('sb_weather:requestSync')
end)

-- ============================================================
-- Continuous override loop
-- Keeps GTA from reverting weather between server syncs
-- ============================================================

CreateThread(function()
    while true do
        SetOverrideWeather(currentWeather)
        Wait(1000)
    end
end)
