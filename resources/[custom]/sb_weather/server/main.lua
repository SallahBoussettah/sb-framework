local currentWeather = Config.DefaultWeather

-- ============================================================
-- Helpers
-- ============================================================

local function HasPermission(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.AcePerm)
end

local function Notify(src, msg, msgType)
    if src == 0 then
        print('[sb_weather] ' .. msg)
    else
        TriggerClientEvent('sb_notify:client:notify', src, msg, msgType or 'info', 3000)
    end
end

local function IsValidWeather(name)
    local upper = string.upper(name)
    for _, w in ipairs(Config.WeatherTypes) do
        if w == upper then return true, upper end
    end
    return false, upper
end

-- ============================================================
-- Sync loop — periodically pushes weather to all clients
-- ============================================================

CreateThread(function()
    while true do
        TriggerClientEvent('sb_weather:sync', -1, currentWeather)
        Wait(Config.SyncInterval)
    end
end)

-- ============================================================
-- Player requesting sync (on spawn / resource start)
-- ============================================================

RegisterNetEvent('sb_weather:requestSync', function()
    local src = source
    TriggerClientEvent('sb_weather:sync', src, currentWeather)
end)

-- ============================================================
-- Admin command: /weather [type]
-- ============================================================

RegisterCommand('weather', function(source, args)
    local src = source
    if not HasPermission(src) then
        Notify(src, 'You do not have permission.', 'error')
        return
    end

    if not args[1] then
        Notify(src, 'Current weather: ' .. currentWeather, 'info')
        Notify(src, 'Usage: /weather [type]', 'info')
        Notify(src, 'Types: ' .. table.concat(Config.WeatherTypes, ', '), 'info')
        return
    end

    local valid, upper = IsValidWeather(args[1])
    if not valid then
        Notify(src, 'Invalid weather type: ' .. upper, 'error')
        Notify(src, 'Valid types: ' .. table.concat(Config.WeatherTypes, ', '), 'info')
        return
    end

    currentWeather = upper
    TriggerClientEvent('sb_weather:sync', -1, currentWeather)
    Notify(src, 'Weather set to ' .. currentWeather, 'success')
    print('[sb_weather] Weather changed to ' .. currentWeather .. ' by player ' .. src)
end, false)

-- ============================================================
-- Export so other scripts can read / set weather
-- ============================================================

exports('GetWeather', function()
    return currentWeather
end)

exports('SetWeather', function(weatherType)
    local valid, upper = IsValidWeather(weatherType)
    if not valid then return false end
    currentWeather = upper
    TriggerClientEvent('sb_weather:sync', -1, currentWeather)
    return true
end)
