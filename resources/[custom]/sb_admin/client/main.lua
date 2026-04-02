-- sb_admin/client/main.lua
-- Menu toggle and feature orchestration

local isAdmin = false
local menuOpen = false

-- Request permission check on resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('sb_admin:requestPermission')
end)

-- Also check on player spawn
RegisterNetEvent('sb_core:client:playerLoaded', function()
    TriggerServerEvent('sb_admin:requestPermission')
end)

-- Receive permission result
RegisterNetEvent('sb_admin:permissionResult', function(allowed)
    isAdmin = allowed
    if allowed then
        RegisterChatSuggestions()
        print('[sb_admin] Admin access granted')
    end
end)

-- Register chat suggestions (shows usage hints as you type)
function RegisterChatSuggestions()
    TriggerEvent('chat:addSuggestion', '/givemoney', 'Give money to a player', {
        { name = 'id', help = 'Player ID' },
        { name = 'type', help = 'cash / bank / crypto' },
        { name = 'amount', help = 'Amount to give' }
    })

    TriggerEvent('chat:addSuggestion', '/giveitem', 'Give item to a player', {
        { name = 'id', help = 'Player ID' },
        { name = 'item', help = 'Item name (e.g. sandwich, water)' },
        { name = 'amount', help = 'Quantity (default: 1)' }
    })

    TriggerEvent('chat:addSuggestion', '/giveweapon', 'Give weapon kit (weapon + 3 mags + ammo box)', {
        { name = 'id', help = 'Player ID (optional, defaults to self)' },
        { name = 'weapon', help = 'Weapon name (e.g. weapon_pistol)' }
    })

    TriggerEvent('chat:addSuggestion', '/setjob', 'Set a player\'s job', {
        { name = 'id', help = 'Player ID' },
        { name = 'job', help = 'Job name (e.g. police, mechanic)' },
        { name = 'grade', help = 'Grade level (default: 0)' }
    })

    TriggerEvent('chat:addSuggestion', '/setgang', 'Set a player\'s gang', {
        { name = 'id', help = 'Player ID' },
        { name = 'gang', help = 'Gang name' },
        { name = 'grade', help = 'Grade level (default: 0)' }
    })

    TriggerEvent('chat:addSuggestion', '/kick', 'Kick a player from the server', {
        { name = 'id', help = 'Player ID' },
        { name = 'reason', help = 'Kick reason' }
    })

    TriggerEvent('chat:addSuggestion', '/ban', 'Ban a player from the server', {
        { name = 'id', help = 'Player ID' },
        { name = 'hours', help = 'Duration in hours (0 = permanent)' },
        { name = 'reason', help = 'Ban reason' }
    })

    TriggerEvent('chat:addSuggestion', '/revive', 'Revive a player (or yourself)', {
        { name = 'id', help = 'Player ID (optional, defaults to self)' }
    })

    TriggerEvent('chat:addSuggestion', '/heal', 'Full heal: health, hunger, thirst, stress + revive', {
        { name = 'id', help = 'Player ID (optional, defaults to self)' }
    })

    TriggerEvent('chat:addSuggestion', '/goto', 'Teleport to a player', {
        { name = 'id', help = 'Player ID' }
    })

    TriggerEvent('chat:addSuggestion', '/bring', 'Bring a player to you', {
        { name = 'id', help = 'Player ID' }
    })

    TriggerEvent('chat:addSuggestion', '/time', 'Set time of day', {
        { name = 'hour', help = '0-23 (e.g. 12 = noon, 0 = midnight)' },
        { name = 'minute', help = '0-59 (optional, default 0)' }
    })

    TriggerEvent('chat:addSuggestion', '/freezetime', 'Toggle time freeze on/off', {})

    TriggerEvent('chat:addSuggestion', '/removecar', 'Remove vehicle you\'re in or looking at', {})

    TriggerEvent('chat:addSuggestion', '/car', 'Spawn a vehicle by model name', {
        { name = 'model', help = 'Vehicle spawn name (e.g. polbmwm5, 2019chiron)' }
    })

    TriggerEvent('chat:addSuggestion', '/dv', 'Delete vehicle (alias for /removecar)', {})

    TriggerEvent('chat:addSuggestion', '/setadmin', 'Grant admin access to a player (runtime)', {
        { name = 'id', help = 'Player ID' }
    })

    TriggerEvent('chat:addSuggestion', '/removeadmin', 'Revoke admin access from a player', {
        { name = 'id', help = 'Player ID' }
    })

    TriggerEvent('chat:addSuggestion', '/duty', 'Toggle your own duty status on/off', {})

    TriggerEvent('chat:addSuggestion', '/setduty', 'Set a player\'s duty status', {
        { name = 'id', help = 'Player ID' },
        { name = 'status', help = 'on / off' }
    })

    TriggerEvent('chat:addSuggestion', '/tp', 'Teleport to coordinates', {
        { name = 'coords', help = 'x, y, z[, heading] (e.g. -550.47, -192.47, 38.22, 38.24)' }
    })
    TriggerEvent('chat:addSuggestion', '/cp4', 'Copy current vector4 position to clipboard', {})
    TriggerEvent('chat:addSuggestion', '/cp3', 'Copy current vector3 position to clipboard', {})
end

-- Key bindings via RegisterKeyMapping (proper FiveM F-key binding)
RegisterCommand('+sb_admin_menu', function()
    if isAdmin then ToggleMenu() end
end, false)
RegisterCommand('-sb_admin_menu', function() end, false)
RegisterKeyMapping('+sb_admin_menu', 'Admin Menu', 'keyboard', 'F5')

RegisterCommand('+sb_admin_inspector', function()
    if isAdmin then ToggleInspector() end
end, false)
RegisterCommand('-sb_admin_inspector', function() end, false)
RegisterKeyMapping('+sb_admin_inspector', 'Prop Inspector', 'keyboard', 'F7')

function ToggleMenu()
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    SendNUIMessage({
        action = 'toggleMenu',
        show = menuOpen,
        inspectorActive = InspectorActive or false,
        noclipActive = NoclipActive or false,
        godmodeActive = GodmodeActive or false
    })
end

function CloseMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'toggleMenu',
        show = false
    })
end

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('toggleInspector', function(data, cb)
    ToggleInspector()
    cb('ok')
end)

RegisterNUICallback('toggleNoclip', function(data, cb)
    ToggleNoclip()
    cb('ok')
end)

RegisterNUICallback('toggleGodmode', function(data, cb)
    ToggleGodmode()
    cb('ok')
end)

RegisterNUICallback('tpToWaypoint', function(data, cb)
    TeleportToWaypoint()
    cb('ok')
end)

RegisterNUICallback('getCoords', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    cb({
        x = tonumber(string.format("%.2f", coords.x)),
        y = tonumber(string.format("%.2f", coords.y)),
        z = tonumber(string.format("%.2f", coords.z)),
        h = tonumber(string.format("%.2f", heading))
    })
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    SpawnAdminVehicle(data.model)
    cb('ok')
end)

RegisterNUICallback('setTime', function(data, cb)
    ExecuteCommand('time ' .. data.hour .. ' ' .. data.minute)
    cb('ok')
end)

RegisterNUICallback('copyToClipboard', function(data, cb)
    -- Handled in JS side
    cb('ok')
end)

-- Teleport tab
RegisterNUICallback('gotoPlayer', function(data, cb)
    ExecuteCommand('goto ' .. data.id)
    cb('ok')
end)

RegisterNUICallback('bringPlayer', function(data, cb)
    ExecuteCommand('bring ' .. data.id)
    cb('ok')
end)

-- Give tab
RegisterNUICallback('giveWeapon', function(data, cb)
    ExecuteCommand('giveweapon ' .. data.id .. ' ' .. data.weapon)
    cb('ok')
end)

RegisterNUICallback('giveItemCmd', function(data, cb)
    ExecuteCommand('giveitem ' .. data.id .. ' ' .. data.item .. ' ' .. data.amount)
    cb('ok')
end)

RegisterNUICallback('giveMoney', function(data, cb)
    ExecuteCommand('givemoney ' .. data.id .. ' ' .. data.type .. ' ' .. data.amount)
    cb('ok')
end)

-- Players tab
RegisterNUICallback('setJob', function(data, cb)
    ExecuteCommand('setjob ' .. data.id .. ' ' .. data.job .. ' ' .. data.grade)
    cb('ok')
end)

RegisterNUICallback('setGang', function(data, cb)
    ExecuteCommand('setgang ' .. data.id .. ' ' .. data.gang .. ' ' .. data.grade)
    cb('ok')
end)

RegisterNUICallback('revivePlayer', function(data, cb)
    if data.id and data.id ~= '' then
        ExecuteCommand('revive ' .. data.id)
    else
        ExecuteCommand('revive')
    end
    cb('ok')
end)

RegisterNUICallback('kickPlayer', function(data, cb)
    ExecuteCommand('kick ' .. data.id .. ' ' .. data.reason)
    cb('ok')
end)

RegisterNUICallback('banPlayer', function(data, cb)
    ExecuteCommand('ban ' .. data.id .. ' ' .. data.hours .. ' ' .. data.reason)
    cb('ok')
end)

-- Export for other scripts to check admin status
exports('IsAdmin', function()
    return isAdmin
end)
