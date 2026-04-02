--[[
    Everyday Chaos RP - ATM System (Client)
    Author: Salah Eddine Boussettah

    Handles: ATM model targeting, card check, open ATM interface
]]

-- ============================================================================
-- ATM TARGET REGISTRATION
-- ============================================================================

CreateThread(function()
    Wait(2500)

    -- Remove any existing ATM targets first (prevents duplicates on restart)
    for _, model in ipairs(Config.ATMModels) do
        exports['sb_target']:RemoveTargetModel(model, {'use_atm'})
    end

    local atmOptions = {
        {
            name = 'use_atm',
            label = 'Use ATM',
            icon = 'fa-credit-card',
            distance = Config.ATMDistance,
            action = function(entity)
                TriggerServerEvent('sb_banking:server:checkCard')
            end
        }
    }

    for _, model in ipairs(Config.ATMModels) do
        exports['sb_target']:AddTargetModel(model, atmOptions)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, model in ipairs(Config.ATMModels) do
        exports['sb_target']:RemoveTargetModel(model, {'use_atm'})
    end
end)

-- Server response: card check
RegisterNetEvent('sb_banking:client:cardCheckResult', function(hasCard)
    if hasCard then
        OpenATM()
    else
        exports['sb_notify']:Notify('You need a bank card to use the ATM. Visit the bank to request one.', 'error', 5000)
    end
end)

-- Debug command: aim at an entity and get its model hash
RegisterCommand('atmmodel', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    -- Test GetClosestObjectOfType for each ATM model
    for _, model in ipairs(Config.ATMModels) do
        local hash = type(model) == 'string' and GetHashKey(model) or model
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, 5.0, hash, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            local objModel = GetEntityModel(obj)
            local hexStr = string.format('%X', objModel & 0xFFFFFFFF)
            print('[sb_banking] Found: hash=' .. objModel .. ' (0x' .. hexStr .. ') from model=' .. tostring(model))
            exports['sb_notify']:Notify('Found: ' .. tostring(model) .. ' = ' .. objModel, 'success', 8000)
            return
        end
    end

    -- Fallback: raycast
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rad = math.rad
    local dx = -math.sin(rad(rot.z)) * math.cos(rad(rot.x))
    local dy = math.cos(rad(rot.z)) * math.cos(rad(rot.x))
    local dz = math.sin(rad(rot.x))
    local dest = cam + vector3(dx, dy, dz) * 15.0

    local ray = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 16, ped, 0)
    local _, hitResult, _, _, hitEntity = GetShapeTestResult(ray)

    if hitResult == 1 and hitEntity ~= 0 and DoesEntityExist(hitEntity) then
        local model = GetEntityModel(hitEntity)
        local hexStr = string.format('%X', model & 0xFFFFFFFF)
        print('[sb_banking] Raycast found: hash=' .. model .. ' (0x' .. hexStr .. ')')
        exports['sb_notify']:Notify('Raycast: ' .. model .. ' (0x' .. hexStr .. ')', 'info', 10000)
    else
        exports['sb_notify']:Notify('No ATM found nearby or via raycast.', 'error', 4000)
    end
end, false)
