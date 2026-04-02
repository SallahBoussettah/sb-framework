-- Get character name from sb_core
local function GetCharacterName(source)
    local Player = exports['sb_core']:GetPlayer(source)
    if Player then
        local charInfo = Player.PlayerData.charinfo
        if charInfo then
            return charInfo.firstname .. ' ' .. charInfo.lastname
        end
    end
    return GetPlayerName(source) or ('Player ' .. source)
end

-- Normal proximity message
RegisterNetEvent('sb_chat:message', function(message)
    local src = source
    if not message or message == '' then return end

    local senderName = GetCharacterName(src)
    local senderPed = GetPlayerPed(src)
    if not senderPed or senderPed == 0 then return end
    local senderCoords = GetEntityCoords(senderPed)

    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local targetId = tonumber(playerId)
        local targetPed = GetPlayerPed(targetId)
        if targetPed and targetPed ~= 0 then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(senderCoords - targetCoords)
            if distance <= Config.ProximityRange then
                TriggerClientEvent('sb_chat:receiveMessage', targetId, {
                    sender = senderName,
                    text = message,
                    color = '#ff6b35',
                    isProximity = true
                })
            end
        end
    end
end)

-- Player joined announcement
RegisterNetEvent('sb_chat:playerLoaded', function()
    local src = source
    local senderName = GetCharacterName(src)
    TriggerClientEvent('sb_chat:receiveMessage', -1, {
        sender = 'SYSTEM',
        text = senderName .. ' has joined the city.',
        color = '#22c55e',
        prefix = 'SYSTEM',
        isSystem = true
    })
end)

-- ============================================================
-- EXPORTS (for other scripts to send messages)
-- ============================================================

-- Send system message to one player
exports('SendSystemMessage', function(targetId, text)
    TriggerClientEvent('sb_chat:receiveMessage', targetId, {
        sender = 'SYSTEM',
        text = text,
        color = '#22c55e',
        prefix = 'SYSTEM',
        isSystem = true
    })
end)

-- Send system message to all players
exports('SendSystemMessageAll', function(text)
    TriggerClientEvent('sb_chat:receiveMessage', -1, {
        sender = 'SYSTEM',
        text = text,
        color = '#22c55e',
        prefix = 'SYSTEM',
        isSystem = true
    })
end)

-- Send staff message
exports('SendStaffMessage', function(targetId, text, senderName)
    TriggerClientEvent('sb_chat:receiveMessage', targetId, {
        sender = senderName or 'STAFF',
        text = text,
        color = '#ef4444',
        prefix = 'STAFF',
        isSystem = true
    })
end)

-- Send custom colored message to a player
exports('SendMessage', function(targetId, sender, text, color, prefix)
    TriggerClientEvent('sb_chat:receiveMessage', targetId, {
        sender = sender or '',
        text = text or '',
        color = color or '#ff6b35',
        prefix = prefix or nil,
        isSystem = prefix and true or false
    })
end)

