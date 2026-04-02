-- =============================================
-- SB_POLICE - Target Interactions
-- Registers sb_target options for field actions
-- =============================================

local SB = exports['sb_core']:GetCoreObject()
local isOnDuty = false

-- =============================================
-- Duty State Tracking
-- =============================================

RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    isOnDuty = onDuty

    if onDuty then
        RegisterFieldTargets()
    else
        UnregisterFieldTargets()
    end
end)

-- Also check on resource start if already on duty
CreateThread(function()
    Wait(2000)  -- Wait for other scripts to load
    if exports['sb_police']:IsOnDuty() then
        isOnDuty = true
        RegisterFieldTargets()
    end
end)

-- =============================================
-- Register Field Target Options
-- =============================================

function RegisterFieldTargets()
    -- Global player options (when looking at another player)
    exports['sb_target']:AddGlobalPlayer({
        -- Soft Cuff
        {
            name = 'police_softcuff',
            label = 'Soft Cuff',
            icon = 'fa-hands',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return not IsPlayerCuffed(entity)
            end,
            action = function(entity)
                StartCuffAction(entity, 'soft')
            end
        },
        -- Hard Cuff
        {
            name = 'police_hardcuff',
            label = 'Hard Cuff',
            icon = 'fa-handcuffs',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return not IsPlayerCuffed(entity)
            end,
            action = function(entity)
                StartCuffAction(entity, 'hard')
            end
        },
        -- Uncuff
        {
            name = 'police_uncuff',
            label = 'Uncuff',
            icon = 'fa-unlock',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return IsPlayerCuffed(entity)
            end,
            action = function(entity)
                StartUncuffAction(entity)
            end
        },
        -- Escort
        {
            name = 'police_escort',
            label = 'Escort',
            icon = 'fa-person-walking-arrow-right',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                if IsEscortingPlayer() then return false end  -- Already escorting someone
                return IsPlayerCuffed(entity) and not IsPlayerBeingEscorted(entity)
            end,
            action = function(entity)
                StartEscort(entity)
            end
        },
        -- Release Escort (shows on any player when escorting — only one escort at a time)
        {
            name = 'police_release_escort',
            label = 'Release',
            icon = 'fa-hand',
            distance = 5.0,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return IsEscortingPlayer()
            end,
            action = function(entity)
                StopEscort()
            end
        },
        -- Search / Pat Down
        {
            name = 'police_search',
            label = 'Search',
            icon = 'fa-magnifying-glass',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return IsPlayerCuffed(entity)
            end,
            action = function(entity)
                StartSearch(entity)
            end
        },
        -- Take out of vehicle
        {
            name = 'police_takeout',
            label = 'Take Out',
            icon = 'fa-car-side',
            distance = 3.0,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                if not IsPedInAnyVehicle(entity, false) then return false end
                return IsPlayerCuffed(entity)
            end,
            action = function(entity)
                TakeOutOfVehicle(entity)
            end
        },
        -- GSR Test
        {
            name = 'police_gsr_test',
            label = 'GSR Test',
            icon = 'fa-hand-dots',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return not IsPedInAnyVehicle(entity, false)
            end,
            action = function(entity)
                StartGSRTest(entity)
            end
        },
        -- Breathalyzer
        {
            name = 'police_breathalyzer',
            label = 'Breathalyzer',
            icon = 'fa-wine-glass',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return not IsPedInAnyVehicle(entity, false)
            end,
            action = function(entity)
                StartBreathalyzerTest(entity)
            end
        },
        -- Send to Jail (sb_prison booking)
        {
            name = 'police_send_to_jail',
            label = 'Send to Jail',
            icon = 'fa-building-lock',
            distance = 2.5,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return IsPlayerCuffed(entity) and not IsPedInAnyVehicle(entity, false)
            end,
            action = function(entity)
                local targetId = GetServerIdFromPed(entity)
                if targetId then
                    TriggerServerEvent('sb_prison:server:jailFromField', targetId)
                end
            end
        }
    })

    -- Vehicle bone targets (for putting suspect in vehicle)
    exports['sb_target']:AddTargetBone({'door_pside_r', 'door_dside_r'}, {
        {
            name = 'police_put_in_vehicle',
            label = 'Put In Vehicle',
            icon = 'fa-car-side',
            distance = 3.0,
            job = Config.PoliceJob,
            canInteract = function(entity, distance, coords, bone)
                if not isOnDuty then return false end
                if not IsEscortingPlayer() then return false end
                -- Must be a valid vehicle
                return IsEntityAVehicle(entity) and GetVehicleMaxNumberOfPassengers(entity) > 1
            end,
            action = function(entity)
                PutInVehicle(entity)
            end
        }
    })

    -- Vehicle search target (trunk area)
    exports['sb_target']:AddTargetBone({'boot'}, {
        {
            name = 'police_vehicle_search',
            label = 'Search Vehicle',
            icon = 'fa-magnifying-glass',
            distance = 3.0,
            job = Config.PoliceJob,
            canInteract = function(entity)
                if not isOnDuty then return false end
                return IsEntityAVehicle(entity)
            end,
            action = function(entity)
                StartVehicleSearch(entity)
            end
        }
    })

    print('[sb_police] ^2Field targets registered^7')
end

-- =============================================
-- Unregister Field Target Options
-- =============================================

function UnregisterFieldTargets()
    exports['sb_target']:RemoveGlobalPlayer('police_softcuff')
    exports['sb_target']:RemoveGlobalPlayer('police_hardcuff')
    exports['sb_target']:RemoveGlobalPlayer('police_uncuff')
    exports['sb_target']:RemoveGlobalPlayer('police_escort')
    exports['sb_target']:RemoveGlobalPlayer('police_release_escort')
    exports['sb_target']:RemoveGlobalPlayer('police_search')
    exports['sb_target']:RemoveGlobalPlayer('police_takeout')
    exports['sb_target']:RemoveGlobalPlayer('police_gsr_test')
    exports['sb_target']:RemoveGlobalPlayer('police_breathalyzer')
    exports['sb_target']:RemoveGlobalPlayer('police_send_to_jail')
    exports['sb_target']:RemoveTargetBone({'door_pside_r', 'door_dside_r'}, 'police_put_in_vehicle')
    exports['sb_target']:RemoveTargetBone({'boot'}, 'police_vehicle_search')

    print('[sb_police] ^3Field targets unregistered^7')
end

-- =============================================
-- Helper Functions (accessible to this file)
-- =============================================

function GetServerIdFromPed(ped)
    if not DoesEntityExist(ped) then return nil end
    if not IsPedAPlayer(ped) then return nil end
    local player = NetworkGetPlayerIndexFromPed(ped)
    if player == -1 then return nil end
    return GetPlayerServerId(player)
end

-- =============================================
-- Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    UnregisterFieldTargets()
end)
