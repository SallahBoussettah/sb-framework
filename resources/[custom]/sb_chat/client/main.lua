local chatOpen = false
local chatLoaded = false
local suggestions = {}

-- Initialize chat
CreateThread(function()
    Wait(1000)
    chatLoaded = true

    -- Welcome message
    Wait(2000)
    SendNUIMessage({
        type = 'addMessage',
        message = {
            sender = 'SYSTEM',
            text = 'Welcome to Everyday Chaos RP. Press T to chat.',
            color = '#22c55e',
            prefix = 'SYSTEM',
            isSystem = true
        }
    })

    TriggerServerEvent('sb_chat:playerLoaded')
end)

-- Internal FiveM commands to hide from suggestions
local hiddenPrefixes = {
    'radiophone', 'profiler', 'netgraph', 'net_', 'cl_', 'sv_', 'con_',
    'strmem', 'strlist', 'rmstack', 'restack', 'loadlevel', 'invokelevel',
    'test_', 'debug_', 'internal_', 'quit', 'disconnect'
}

local function IsHiddenCommand(name)
    local lower = string.lower(name)
    for _, prefix in ipairs(hiddenPrefixes) do
        if string.find(lower, '^' .. prefix) then
            return true
        end
    end
    return false
end

-- Auto-detect registered commands and add them as suggestions
CreateThread(function()
    Wait(5000) -- Wait for all scripts to load
    local registeredCommands = GetRegisteredCommands()
    for _, cmd in ipairs(registeredCommands) do
        if not IsHiddenCommand(cmd.name) then
            local exists = false
            for _, sug in ipairs(suggestions) do
                if sug.command == ('/' .. cmd.name) then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(suggestions, {
                    command = '/' .. cmd.name,
                    description = '',
                    params = {}
                })
            end
        end
    end
    SendSuggestionsToNUI()
end)

-- Open chat with T key
CreateThread(function()
    while true do
        Wait(0)
        if chatLoaded and not chatOpen then
            DisableControlAction(0, 245, true)
            if IsDisabledControlJustPressed(0, 245) then
                OpenChat()
            end
        end
    end
end)

function OpenChat(defaultText)
    if chatOpen then return end
    chatOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open',
        defaultText = defaultText or ''
    })
end

function CloseChat()
    if not chatOpen then return end
    chatOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'close'
    })
end

-- NUI Callbacks
RegisterNUICallback('chatMessage', function(data, cb)
    local message = data.message
    if not message or message == '' then
        CloseChat()
        cb('ok')
        return
    end

    -- Check max length
    if #message > Config.MaxMessageLength then
        message = string.sub(message, 1, Config.MaxMessageLength)
    end

    -- Check if it's a command
    if string.sub(message, 1, 1) == '/' then
        -- Execute as FiveM command (strips the /)
        ExecuteCommand(string.sub(message, 2))
    else
        -- Normal proximity message
        TriggerServerEvent('sb_chat:message', message)
    end

    CloseChat()
    cb('ok')
end)

RegisterNUICallback('closeChat', function(data, cb)
    CloseChat()
    cb('ok')
end)

-- ============================================================
-- DYNAMIC SUGGESTION SYSTEM
-- Other scripts register their commands here
-- ============================================================

-- Add a suggestion (called by other scripts via export or event)
-- command: '/commandname'
-- description: 'What this command does'
-- params: (optional) table of { name = 'param', help = 'description' }
local function AddSuggestion(command, description, params)
    if not command then return end
    -- Normalize: ensure starts with /
    if string.sub(command, 1, 1) ~= '/' then
        command = '/' .. command
    end

    -- Check if already exists, update if so
    for i, sug in ipairs(suggestions) do
        if sug.command == command then
            suggestions[i] = { command = command, description = description or '', params = params or {} }
            SendSuggestionsToNUI()
            return
        end
    end

    table.insert(suggestions, {
        command = command,
        description = description or '',
        params = params or {}
    })
    SendSuggestionsToNUI()
end

-- Remove a suggestion
local function RemoveSuggestion(command)
    if not command then return end
    if string.sub(command, 1, 1) ~= '/' then
        command = '/' .. command
    end
    for i, sug in ipairs(suggestions) do
        if sug.command == command then
            table.remove(suggestions, i)
            SendSuggestionsToNUI()
            return
        end
    end
end

function SendSuggestionsToNUI()
    SendNUIMessage({
        type = 'setSuggestions',
        suggestions = suggestions
    })
end

-- Exports for other scripts
exports('AddSuggestion', AddSuggestion)
exports('RemoveSuggestion', RemoveSuggestion)

-- Event-based registration (compatible with default chat pattern)
RegisterNetEvent('chat:addSuggestion', function(command, description, params)
    AddSuggestion(command, description, params)
end)

RegisterNetEvent('sb_chat:addSuggestion', function(command, description, params)
    AddSuggestion(command, description, params)
end)

-- ============================================================
-- MESSAGE RECEIVING
-- ============================================================

RegisterNetEvent('sb_chat:receiveMessage', function(msgData)
    SendNUIMessage({
        type = 'addMessage',
        message = msgData
    })
end)

-- System message (from any script)
RegisterNetEvent('sb_chat:systemMessage', function(text)
    SendNUIMessage({
        type = 'addMessage',
        message = {
            sender = 'SYSTEM',
            text = text,
            color = '#22c55e',
            prefix = 'SYSTEM',
            isSystem = true
        }
    })
end)

-- Staff message
RegisterNetEvent('sb_chat:staffMessage', function(text, senderName)
    SendNUIMessage({
        type = 'addMessage',
        message = {
            sender = senderName or 'STAFF',
            text = text,
            color = '#ef4444',
            prefix = 'STAFF',
            isSystem = true
        }
    })
end)

-- Export: Send a system message locally
exports('SystemMessage', function(text)
    SendNUIMessage({
        type = 'addMessage',
        message = {
            sender = 'SYSTEM',
            text = text,
            color = '#22c55e',
            prefix = 'SYSTEM',
            isSystem = true
        }
    })
end)
