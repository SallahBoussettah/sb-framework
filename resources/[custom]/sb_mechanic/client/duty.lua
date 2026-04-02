-- ============================================================================
-- sb_mechanic - Client: Duty System
-- Duty NPC spawn, clock in/out, parts shelf
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()
local dutyNPC = 0
local laptopProp = 0
local isOnDuty = false
local wearingWorkClothes = false
local savedCivilianAppearance = nil
local billingOpen = false

-- ============================================================================
-- Helpers
-- ============================================================================

local function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(0)
        timeout = timeout + 1
    end
    return hash
end

local function IsMechanic()
    local playerData = SB.Functions.GetPlayerData()
    return playerData and playerData.job and playerData.job.name == Config.JobName
end

local function GetGradeLevel()
    local playerData = SB.Functions.GetPlayerData()
    if playerData and playerData.job and playerData.job.grade then
        return playerData.job.grade.level or 0
    end
    return 0
end

-- ============================================================================
-- Spawn Duty NPC
-- ============================================================================

local function SpawnDutyNPC()
    local cfg = Config.DutyNPC
    local hash = LoadModel(cfg.model)

    dutyNPC = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.heading, false, true)
    SetEntityAsMissionEntity(dutyNPC, true, true)
    SetBlockingOfNonTemporaryEvents(dutyNPC, true)
    SetPedDiesWhenInjured(dutyNPC, false)
    SetPedCanBeTargetted(dutyNPC, false)
    FreezeEntityPosition(dutyNPC, true)
    SetEntityInvincible(dutyNPC, true)
    SetPedFleeAttributes(dutyNPC, 0, false)
    SetPedCombatAttributes(dutyNPC, 17, true)
    SetModelAsNoLongerNeeded(hash)

    -- Register target on duty NPC
    exports['sb_target']:AddTargetEntity(dutyNPC, {
        {
            name = 'mechanic_duty',
            label = cfg.label,
            icon = cfg.icon,
            distance = cfg.distance,
            canInteract = function()
                return IsMechanic()
            end,
            action = function()
                TriggerServerEvent('sb_mechanic:toggleDuty')
            end
        }
    })
end

-- ============================================================================
-- Spawn Parts Shelf
-- ============================================================================

local function SetupPartsShelf()
    local cfg = Config.PartsShelf

    -- Build target options — one per item for direct purchase
    local options = {}
    for _, item in ipairs(cfg.items) do
        table.insert(options, {
            name = 'buy_' .. item.name,
            label = item.label .. ' — $' .. item.price,
            icon = 'fa-box',
            distance = cfg.distance,
            canInteract = function()
                return IsMechanic() and isOnDuty
            end,
            action = function()
                SB.Functions.TriggerCallback('sb_mechanic:buyPart', function(success, msg)
                    if success then
                        exports['sb_notify']:Notify(msg, 'success', 3000)
                    else
                        exports['sb_notify']:Notify(msg, 'error', 3000)
                    end
                end, item.name, item.price)
            end
        })
    end

    -- Use sb_target sphere zone at the existing MLO prop location
    exports['sb_target']:AddSphereZone(
        'mechanic_parts_shelf',
        cfg.coords,
        1.5,
        options
    )
end

-- ============================================================================
-- Work Clothes (locker room target)
-- ============================================================================

local function GetGender()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if model == `mp_f_freemode_01` then return 'female' end
    return 'male'
end

local function WearWorkClothes()
    if wearingWorkClothes then return end

    -- Save current appearance so we can restore it later
    savedCivilianAppearance = exports['sb_clothing']:GetCurrentAppearance()

    local ped = PlayerPedId()
    local gender = GetGender()
    local outfit = Config.WorkClothes[gender]
    if not outfit then return end

    for compId, data in pairs(outfit) do
        SetPedComponentVariation(ped, compId, data.drawable, data.texture, 0)
    end

    wearingWorkClothes = true
    exports['sb_notify']:Notify('Changed into work clothes', 'success', 3000)
end

local function RemoveWorkClothes()
    if not wearingWorkClothes then return end

    if savedCivilianAppearance then
        exports['sb_clothing']:ApplyAppearance(savedCivilianAppearance)
        savedCivilianAppearance = nil
    end

    wearingWorkClothes = false
    exports['sb_notify']:Notify('Changed back to civilian clothes', 'info', 3000)
end

local function SetupWorkClothes()
    local cfg = Config.WorkClothes
    if not cfg or not cfg.coords then return end

    exports['sb_target']:AddSphereZone(
        'mechanic_work_clothes',
        cfg.coords,
        cfg.radius or 1.5,
        {
            {
                name = 'mechanic_wear_clothes',
                label = 'Wear Work Clothes',
                icon = 'fa-shirt',
                distance = cfg.distance or 2.0,
                canInteract = function()
                    return IsMechanic() and not wearingWorkClothes
                end,
                action = function()
                    WearWorkClothes()
                end
            },
            {
                name = 'mechanic_remove_clothes',
                label = 'Remove Work Clothes',
                icon = 'fa-shirt',
                distance = cfg.distance or 2.0,
                canInteract = function()
                    return IsMechanic() and wearingWorkClothes
                end,
                action = function()
                    RemoveWorkClothes()
                end
            }
        }
    )
end

-- ============================================================================
-- Billing Laptop (spawns prop + sb_target)
-- ============================================================================

-- Forward declarations (needed because SpawnBillingLaptop references these
-- in target callbacks before they're defined)
local OpenBillingLaptop
local CloseBillingLaptop

local function SpawnBillingLaptop()
    local cfg = Config.BillingLaptop
    if not cfg then return end

    local hash = LoadModel(cfg.model)
    laptopProp = CreateObject(hash, cfg.coords.x, cfg.coords.y, cfg.coords.z, false, false, true)
    SetEntityAsMissionEntity(laptopProp, true, true)
    SetEntityHeading(laptopProp, cfg.heading)
    FreezeEntityPosition(laptopProp, true)
    PlaceObjectOnGroundProperly(laptopProp)
    SetModelAsNoLongerNeeded(hash)

    exports['sb_target']:AddTargetEntity(laptopProp, {
        {
            name = 'mechanic_billing',
            label = cfg.label,
            icon = cfg.icon,
            distance = cfg.distance,
            canInteract = function()
                return IsMechanic() and isOnDuty
            end,
            action = function()
                OpenBillingLaptop()
            end
        }
    })
end

OpenBillingLaptop = function()
    if billingOpen then return end

    -- Fetch unpaid vehicles from server
    SB.Functions.TriggerCallback('sb_mechanic:getUnpaidVehicles', function(vehicles)
        if not vehicles then vehicles = {} end

        billingOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openBilling',
            vehicles = vehicles,
        })
    end)
end

CloseBillingLaptop = function()
    if not billingOpen then return end
    billingOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeBilling' })
end

-- NUI Callbacks for billing
RegisterNUICallback('closeBilling', function(data, cb)
    CloseBillingLaptop()
    cb('ok')
end)

RegisterNUICallback('selectVehicle', function(data, cb)
    local plate = data.plate
    if not plate then return cb({}) end

    SB.Functions.TriggerCallback('sb_mechanic:getVehicleWorklog', function(worklog)
        cb(worklog or {})
    end, plate)
end)

RegisterNUICallback('sendBill', function(data, cb)
    local plate = data.plate
    if not plate then return cb({success = false, msg = 'No plate'}) end

    SB.Functions.TriggerCallback('sb_mechanic:sendBill', function(success, msg)
        if success then
            exports['sb_notify']:Notify(msg, 'success', 3000)
        else
            exports['sb_notify']:Notify(msg, 'error', 3000)
        end
        cb({success = success, msg = msg})
    end, plate)
end)

-- ============================================================================
-- Mechanic Bill Response Events (received by mechanic)
-- ============================================================================

RegisterNetEvent('sb_mechanic:billPaid')
AddEventHandler('sb_mechanic:billPaid', function(plate, total)
    exports['sb_notify']:Notify('Bill paid for ' .. plate .. '! You earned $' .. total, 'success', 5000)
    -- Refresh billing laptop if open
    if billingOpen then
        SB.Functions.TriggerCallback('sb_mechanic:getUnpaidVehicles', function(vehicles)
            SendNUIMessage({ action = 'refreshBilling', vehicles = vehicles or {} })
        end)
    end
end)

RegisterNetEvent('sb_mechanic:billDeclined')
AddEventHandler('sb_mechanic:billDeclined', function(plate)
    exports['sb_notify']:Notify('Bill declined for ' .. plate .. '. You can resend later.', 'error', 5000)
end)

-- ============================================================================
-- Customer Invoice Popup (received by vehicle owner)
-- ============================================================================

RegisterNetEvent('sb_mechanic:showCustomerInvoice')
AddEventHandler('sb_mechanic:showCustomerInvoice', function(plate, items, total, mechanicName)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showCustomerInvoice',
        plate = plate,
        items = items,
        total = total,
        mechanicName = mechanicName,
    })
end)

RegisterNUICallback('respondInvoice', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideCustomerInvoice' })
    TriggerServerEvent('sb_mechanic:respondBill', data.plate, data.accept)
    cb('ok')
end)

-- ============================================================================
-- Save vehicle mods request (from server after payment)
-- ============================================================================

RegisterNetEvent('sb_mechanic:saveVehicleMods')
AddEventHandler('sb_mechanic:saveVehicleMods', function(plate)
    -- Find the vehicle with this plate nearby
    local handle, vehicle = FindFirstVehicle()
    local found = true
    while found do
        if DoesEntityExist(vehicle) then
            local vehPlate = GetVehicleNumberPlateText(vehicle)
            if vehPlate and vehPlate:gsub('%s+', '') == plate:gsub('%s+', '') then
                local props = exports['sb_garage']:GetVehicleProperties(vehicle)
                if props then
                    TriggerServerEvent('sb_mechanic:saveVehicleModsResponse', plate, props)
                end
                EndFindVehicle(handle)
                return
            end
        end
        found, vehicle = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)
end)

-- ============================================================================
-- Duty state sync
-- ============================================================================

RegisterNetEvent('sb_mechanic:dutyToggled')
AddEventHandler('sb_mechanic:dutyToggled', function(onDuty)
    isOnDuty = onDuty
    if onDuty then
        exports['sb_notify']:Notify('You are now on duty as a mechanic', 'success', 3000)
    else
        exports['sb_notify']:Notify('You are now off duty', 'info', 3000)
    end
end)

-- ============================================================================
-- Exports
-- ============================================================================

exports('IsOnDuty', function()
    return isOnDuty
end)

exports('IsMechanic', function()
    return IsMechanic()
end)

exports('GetGradeLevel', function()
    return GetGradeLevel()
end)

-- ============================================================================
-- Init
-- ============================================================================

Citizen.CreateThread(function()
    Wait(2000) -- Wait for sb_target to be ready
    SpawnDutyNPC()
    SpawnBillingLaptop()
    SetupPartsShelf()
    SetupWorkClothes()

    -- Sync duty state on join
    local playerData = SB.Functions.GetPlayerData()
    if playerData and playerData.job then
        isOnDuty = playerData.job.onduty or false
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if DoesEntityExist(dutyNPC) then
        DeleteEntity(dutyNPC)
    end
    if DoesEntityExist(laptopProp) then
        DeleteEntity(laptopProp)
    end
    if billingOpen then
        CloseBillingLaptop()
    end
end)
