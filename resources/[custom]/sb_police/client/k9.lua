-- =============================================
-- SB_POLICE - K9 Unit System
-- Sprint 5 Implementation
-- =============================================

local SB = exports['sb_core']:GetCoreObject()

-- State variables
local k9Dog = nil           -- K9 entity
local k9Vehicle = nil       -- Source vehicle (network ID)
local k9State = 'idle'      -- idle/following/staying/searching/attacking/returning
local isOnDuty = false
local k9Blip = nil
local k9DeathCooldown = 0   -- Timestamp when K9 can be respawned
local k9FollowThreadActive = false  -- Track follow thread

-- Refresh SB object when sb_core restarts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'sb_core' then
        SB = exports['sb_core']:GetCoreObject()
    end
end)

-- =============================================
-- Helper Functions
-- =============================================

local function GetPlayerJob()
    -- Get fresh player data
    if SB and SB.Functions and SB.Functions.GetPlayerData then
        local playerData = SB.Functions.GetPlayerData()
        if playerData and playerData.job then
            return playerData.job
        end
    end
    -- Fallback to cached data
    if SB and SB.PlayerData and SB.PlayerData.job then
        return SB.PlayerData.job
    end
    return nil
end

local function IsPoliceJob()
    local job = GetPlayerJob()
    if not job then return false end
    return job.name == Config.PoliceJob
end

local function GetPlayerGrade()
    local job = GetPlayerJob()
    if not job or not job.grade then return 0 end
    return job.grade.level or 0
end

local function CanUseK9()
    if not IsPoliceJob() then return false end
    if GetPlayerGrade() < Config.K9.MinGrade then return false end
    -- Use export from main.lua for duty status
    local onDuty = exports['sb_police']:IsOnDuty()
    return onDuty
end

local function IsK9Vehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local model = GetEntityModel(vehicle)

    for vehModel, enabled in pairs(Config.K9.Vehicles) do
        if enabled and GetHashKey(vehModel) == model then
            return true
        end
    end
    return false
end

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
    end
end

local function LoadModel(model)
    local hash = GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(10)
        end
    end
    return hash
end

local function CreateK9Blip()
    if k9Blip then
        RemoveBlip(k9Blip)
    end

    if k9Dog and DoesEntityExist(k9Dog) then
        k9Blip = AddBlipForEntity(k9Dog)
        SetBlipSprite(k9Blip, 442) -- Dog paw icon
        SetBlipColour(k9Blip, 38)  -- Blue
        SetBlipScale(k9Blip, 0.7)
        SetBlipAsShortRange(k9Blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("K9 Unit")
        EndTextCommandSetBlipName(k9Blip)
    end
end

local function RemoveK9Blip()
    if k9Blip then
        RemoveBlip(k9Blip)
        k9Blip = nil
    end
end

-- Monitor K9 health (defined early so SpawnK9 can call it)
local function StartK9HealthMonitor()
    CreateThread(function()
        Wait(5000)  -- Wait 5 seconds before starting to monitor (avoid spawn issues)

        while k9Dog and DoesEntityExist(k9Dog) do
            local health = GetEntityHealth(k9Dog)
            local maxHealth = GetEntityMaxHealth(k9Dog)

            -- Only consider dead if health is 0 or entity is actually dead
            if IsEntityDead(k9Dog) and health <= 0 then
                exports['sb_notify']:Notify('K9 is down! Wait 30s to redeploy', 'error', 5000)
                k9DeathCooldown = GetGameTimer() + 30000  -- 30 second cooldown
                DespawnK9()
                return
            end

            -- If K9 health is low, notify officer
            if health > 0 and health < (maxHealth * 0.3) then
                exports['sb_notify']:Notify('K9 health is low!', 'warning', 3000)
            end

            Wait(2000)
        end
    end)
end

-- Better follow system - K9 stays behind/beside player (NO TELEPORT)
local function StartK9FollowThread()
    if k9FollowThreadActive then return end
    k9FollowThreadActive = true

    CreateThread(function()
        local lastTaskTime = 0

        while k9Dog and DoesEntityExist(k9Dog) do
            if k9State == 'following' then
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local k9Coords = GetEntityCoords(k9Dog)
                local dist = #(playerCoords - k9Coords)
                local currentTime = GetGameTimer()

                -- Get position behind and to the right of player
                local targetPos = GetOffsetFromEntityInWorldCoords(playerPed, 0.8, -1.2, 0.0)

                if dist > 10.0 then
                    -- Far - sprint to player (update task every 1.5 seconds)
                    if currentTime - lastTaskTime > 1500 then
                        ClearPedTasks(k9Dog)
                        TaskFollowNavMeshToCoord(k9Dog, playerCoords.x, playerCoords.y, playerCoords.z, 7.0, -1, 1.0, true, 0)
                        lastTaskTime = currentTime
                    end
                elseif dist > 5.0 then
                    -- Medium-far - run to player
                    if currentTime - lastTaskTime > 2000 then
                        ClearPedTasks(k9Dog)
                        TaskFollowNavMeshToCoord(k9Dog, playerCoords.x, playerCoords.y, playerCoords.z, 5.0, -1, 1.0, true, 0)
                        lastTaskTime = currentTime
                    end
                elseif dist > 2.0 then
                    -- Close - walk to position
                    if currentTime - lastTaskTime > 2000 then
                        ClearPedTasks(k9Dog)
                        TaskFollowNavMeshToCoord(k9Dog, targetPos.x, targetPos.y, targetPos.z, 1.5, -1, 0.5, true, 0)
                        lastTaskTime = currentTime
                    end
                else
                    -- Very close - idle
                    if IsPedRunning(k9Dog) or IsPedWalking(k9Dog) then
                        ClearPedTasks(k9Dog)
                    end
                end
            end
            Wait(300)
        end

        k9FollowThreadActive = false
    end)
end

-- =============================================
-- K9 Spawn/Despawn
-- =============================================

local function SpawnK9()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Must be in a K9 vehicle
    if vehicle == 0 then
        exports['sb_notify']:Notify('You must be in a K9 vehicle', 'error', 3000)
        return false
    end

    if not IsK9Vehicle(vehicle) then
        exports['sb_notify']:Notify('This vehicle is not equipped for K9', 'error', 3000)
        return false
    end

    -- Already have a K9
    if k9Dog and DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('K9 is already deployed', 'error', 3000)
        return false
    end

    -- Check death cooldown
    if k9DeathCooldown > GetGameTimer() then
        local remaining = math.ceil((k9DeathCooldown - GetGameTimer()) / 1000)
        exports['sb_notify']:Notify('K9 recovering, wait ' .. remaining .. 's', 'error', 3000)
        return false
    end

    -- Check if vehicle is stopped
    local speed = GetEntitySpeed(vehicle)
    if speed > 1.0 then
        exports['sb_notify']:Notify('Stop the vehicle first', 'error', 3000)
        return false
    end

    -- Store vehicle network ID
    k9Vehicle = NetworkGetNetworkIdFromEntity(vehicle)

    -- Open trunk/rear door
    SetVehicleDoorOpen(vehicle, Config.K9.SpawnDoorIndex, false, false)
    Wait(500)

    -- Load K9 model
    local modelHash = LoadModel(Config.K9.Model)

    -- Spawn K9 to the RIGHT side of vehicle (safer than behind)
    local spawnOffset = GetOffsetFromEntityInWorldCoords(vehicle, 2.5, -1.0, 0.0)
    local vehicleHeading = GetEntityHeading(vehicle)

    k9Dog = CreatePed(28, modelHash, spawnOffset.x, spawnOffset.y, spawnOffset.z, vehicleHeading, true, true)

    if not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('Failed to spawn K9', 'error', 3000)
        SetVehicleDoorShut(vehicle, Config.K9.SpawnDoorIndex, false)
        return false
    end

    -- Configure K9
    SetEntityAsMissionEntity(k9Dog, true, true)
    SetBlockingOfNonTemporaryEvents(k9Dog, true)
    SetPedFleeAttributes(k9Dog, 0, false)
    SetPedCombatAttributes(k9Dog, 17, true)  -- Can fight armed peds
    SetPedCombatAttributes(k9Dog, 46, true)  -- Fight to death

    -- Make K9 invincible for 3 seconds (prevents getting run over)
    SetEntityInvincible(k9Dog, true)

    -- Create relationship groups
    local policedog = GetHashKey('POLICEDOG')
    local cop = GetHashKey('COP')

    AddRelationshipGroup('POLICEDOG', policedog)
    SetPedRelationshipGroupHash(k9Dog, policedog)
    SetPedRelationshipGroupHash(playerPed, cop)

    -- Make K9 respect officers
    SetRelationshipBetweenGroups(0, policedog, cop)  -- Respect
    SetRelationshipBetweenGroups(0, cop, policedog)  -- Respect

    -- Set to follow immediately
    k9State = 'following'
    StartK9FollowThread()

    -- Close door after a moment
    Wait(1000)
    SetVehicleDoorShut(vehicle, Config.K9.SpawnDoorIndex, false)

    -- Remove invincibility after 3 seconds
    CreateThread(function()
        Wait(3000)
        if k9Dog and DoesEntityExist(k9Dog) then
            SetEntityInvincible(k9Dog, false)
        end
    end)

    -- Create blip
    CreateK9Blip()

    -- Start K9 health monitor
    StartK9HealthMonitor()

    SetModelAsNoLongerNeeded(modelHash)

    exports['sb_notify']:Notify('K9 deployed and following', 'success', 3000)
    print('[sb_police] K9 spawned and following officer')

    return true
end

local function DespawnK9()
    if k9Dog and DoesEntityExist(k9Dog) then
        -- Play whimper sound
        PlayAnimalVocalization(k9Dog, 3, "BARK")
        Wait(500)

        DeleteEntity(k9Dog)
        k9Dog = nil
    end

    RemoveK9Blip()
    k9State = 'idle'
    k9Vehicle = nil
    k9FollowThreadActive = false

    print('[sb_police] K9 despawned')
end

-- =============================================
-- K9 Commands
-- =============================================

local function K9Follow()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    local playerPed = PlayerPedId()

    -- Play officer animation
    LoadAnimDict('random@arrests')
    TaskPlayAnim(playerPed, 'random@arrests', 'generic_radio_enter', 8.0, -8.0, 1500, 49, 0, false, false, false)

    ClearPedTasks(k9Dog)
    k9State = 'following'
    -- Follow thread handles the rest

    exports['sb_notify']:Notify('K9: Following', 'info', 2000)
end

local function K9Stay()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    local playerPed = PlayerPedId()

    -- Play officer hand signal
    LoadAnimDict('random@arrests')
    TaskPlayAnim(playerPed, 'random@arrests', 'idle_2_hands_up', 8.0, -8.0, 1500, 49, 0, false, false, false)

    ClearPedTasks(k9Dog)
    k9State = 'staying'

    -- Play sit animation
    LoadAnimDict('creatures@rottweiler@amb@world_dog_sitting@idle_a')
    TaskPlayAnim(k9Dog, 'creatures@rottweiler@amb@world_dog_sitting@idle_a', 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)

    exports['sb_notify']:Notify('K9: Stay', 'info', 2000)
end

local function K9Sit()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    ClearPedTasks(k9Dog)
    k9State = 'staying'

    LoadAnimDict('creatures@rottweiler@amb@world_dog_sitting@idle_a')
    TaskPlayAnim(k9Dog, 'creatures@rottweiler@amb@world_dog_sitting@idle_a', 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)

    exports['sb_notify']:Notify('K9: Sit', 'info', 2000)
end

local function K9LieDown()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    ClearPedTasks(k9Dog)
    k9State = 'staying'

    LoadAnimDict('creatures@rottweiler@amb@sleep_in_kennel@')
    TaskPlayAnim(k9Dog, 'creatures@rottweiler@amb@sleep_in_kennel@', 'sleep_in_kennel', 8.0, -8.0, -1, 1, 0, false, false, false)

    exports['sb_notify']:Notify('K9: Lie down', 'info', 2000)
end

local function K9SearchArea()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    if k9State == 'searching' then
        exports['sb_notify']:Notify('K9 is already searching', 'error', 3000)
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Play officer "search" gesture
    LoadAnimDict('random@arrests')
    TaskPlayAnim(playerPed, 'random@arrests', 'generic_radio_enter', 8.0, -8.0, 1500, 49, 0, false, false, false)

    k9State = 'searching'
    ClearPedTasks(k9Dog)

    exports['sb_notify']:Notify('K9 searching area...', 'info', 3000)

    -- Collect nearby targets
    local targets = {}

    -- Find nearby players
    local players = GetActivePlayers()
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)
            if dist <= Config.K9.SearchRadius then
                table.insert(targets, GetPlayerServerId(playerId))
            end
        end
    end

    -- Find nearby vehicles (get plates)
    local vehicles = {}
    local vehicleHandle, vehicle = FindFirstVehicle()
    local found = true

    while found do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local dist = #(playerCoords - vehCoords)
            if dist <= Config.K9.SearchRadius then
                local plate = GetVehicleNumberPlateText(vehicle)
                if plate then
                    table.insert(vehicles, plate:gsub('%s+', ''))
                end
            end
        end
        found, vehicle = FindNextVehicle(vehicleHandle)
    end
    EndFindVehicle(vehicleHandle)

    -- K9 wander/sniff animation
    local k9Coords = GetEntityCoords(k9Dog)
    TaskWanderInArea(k9Dog, k9Coords.x, k9Coords.y, k9Coords.z, Config.K9.SearchRadius / 2, 2.0, 2.0)

    -- Trigger server search
    SB.Functions.TriggerCallback('sb_police:server:K9Search', function(result)
        if not k9Dog or not DoesEntityExist(k9Dog) then return end

        k9State = 'idle'
        ClearPedTasks(k9Dog)

        if result and result.found then
            -- K9 found something - bark!
            LoadAnimDict('creatures@rottweiler@amb@world_dog_barking@idle_a')
            TaskPlayAnim(k9Dog, 'creatures@rottweiler@amb@world_dog_barking@idle_a', 'idle_a', 8.0, -8.0, 3000, 1, 0, false, false, false)

            PlayAnimalVocalization(k9Dog, 3, "BARK")
            Wait(500)
            PlayAnimalVocalization(k9Dog, 3, "BARK")
            Wait(500)
            PlayAnimalVocalization(k9Dog, 3, "BARK")

            if result.targetType == 'player' then
                exports['sb_notify']:Notify('K9 detected illegal substances on a person!', 'warning', 5000)
            else
                exports['sb_notify']:Notify('K9 detected illegal substances in a vehicle!', 'warning', 5000)
            end

            print(('[sb_police] K9 found illegal items - Type: %s'):format(result.targetType))
        else
            -- Nothing found
            exports['sb_notify']:Notify('K9 search complete - nothing found', 'info', 3000)
        end

        -- Return to following
        k9State = 'following'

    end, { players = targets, vehicles = vehicles })
end

local function K9ReturnToCar()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    if not k9Vehicle then
        exports['sb_notify']:Notify('K9 vehicle not found, dismissing K9', 'info', 3000)
        DespawnK9()
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(k9Vehicle)
    if not DoesEntityExist(vehicle) then
        exports['sb_notify']:Notify('K9 vehicle not found, dismissing K9', 'info', 3000)
        DespawnK9()
        return
    end

    k9State = 'returning'
    ClearPedTasks(k9Dog)

    -- Open door
    SetVehicleDoorOpen(vehicle, Config.K9.SpawnDoorIndex, false, false)

    -- Run to vehicle
    local vehCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)
    TaskGoToCoordAnyMeans(k9Dog, vehCoords.x, vehCoords.y, vehCoords.z, 5.0, 0, false, 786603, 0xbf800000)

    exports['sb_notify']:Notify('K9 returning to vehicle...', 'info', 3000)

    -- Wait for K9 to reach vehicle
    CreateThread(function()
        local timeout = 100  -- 10 seconds max
        while k9Dog and DoesEntityExist(k9Dog) and timeout > 0 do
            local k9Coords = GetEntityCoords(k9Dog)
            local dist = #(k9Coords - vehCoords)

            if dist < 2.0 then
                -- Close door and despawn
                Wait(500)
                DespawnK9()
                SetVehicleDoorShut(vehicle, Config.K9.SpawnDoorIndex, false)
                exports['sb_notify']:Notify('K9 secured in vehicle', 'success', 3000)
                return
            end

            timeout = timeout - 1
            Wait(100)
        end

        -- Timeout - just despawn
        if k9Dog and DoesEntityExist(k9Dog) then
            DespawnK9()
            SetVehicleDoorShut(vehicle, Config.K9.SpawnDoorIndex, false)
        end
    end)
end

local function K9Attack(targetPed)
    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    if not targetPed or not DoesEntityExist(targetPed) then
        exports['sb_notify']:Notify('No valid target', 'error', 3000)
        return
    end

    -- Don't attack self
    local playerPed = PlayerPedId()
    if targetPed == playerPed then return end

    k9State = 'attacking'
    ClearPedTasks(k9Dog)

    -- Make K9 aggressive towards target
    SetPedFleeAttributes(k9Dog, 0, false)
    SetBlockingOfNonTemporaryEvents(k9Dog, true)
    SetPedCombatAttributes(k9Dog, 46, true)  -- Always fight
    SetPedCombatAttributes(k9Dog, 5, true)   -- Can fight armed
    SetPedCombatAttributes(k9Dog, 0, false)  -- Don't use cover

    -- Set relationship to hate target
    SetPedRelationshipGroupHash(targetPed, GetHashKey('HATES_PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('POLICEDOG'), GetHashKey('HATES_PLAYER'))  -- 5 = Hate

    -- Bark first
    PlayAnimalVocalization(k9Dog, 3, "BARK")
    Wait(300)

    -- Use TaskGoToEntityWhileAimingAtEntity for better attack behavior
    -- This makes the K9 chase and attack
    SetPedKeepTask(k9Dog, true)
    TaskGoToEntity(k9Dog, targetPed, -1, 0.0, 8.0, 1073741824, 0)

    Wait(500)

    -- Now set to combat
    TaskCombatPed(k9Dog, targetPed, 0, 16)

    -- Also use native attack
    RegisterTarget(k9Dog, targetPed)
    SetPedAsEnemy(k9Dog, true)

    exports['sb_notify']:Notify('K9: Attack!', 'warning', 3000)
    print('[sb_police] K9 attacking target ped: ' .. tostring(targetPed))

    -- Monitor attack - keep re-engaging if needed
    CreateThread(function()
        local timeout = 150  -- 15 seconds
        while k9Dog and DoesEntityExist(k9Dog) and k9State == 'attacking' and timeout > 0 do
            if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then
                Wait(1500)
                break
            end

            -- Re-engage if K9 stopped attacking
            if not IsPedInCombat(k9Dog) then
                local k9Coords = GetEntityCoords(k9Dog)
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(k9Coords - targetCoords)

                if dist > 2.0 then
                    TaskGoToEntity(k9Dog, targetPed, -1, 0.0, 8.0, 1073741824, 0)
                else
                    TaskCombatPed(k9Dog, targetPed, 0, 16)
                end
            end

            timeout = timeout - 1
            Wait(100)
        end

        -- Return to follow
        if k9Dog and DoesEntityExist(k9Dog) then
            ClearPedTasks(k9Dog)
            SetPedKeepTask(k9Dog, false)
            k9State = 'following'
            exports['sb_notify']:Notify('K9 returning to your side', 'info', 2000)
        end
    end)
end

-- =============================================
-- K9 Radial Menu
-- =============================================

local k9MenuOpen = false

local function OpenK9Menu()
    if not k9Dog or not DoesEntityExist(k9Dog) then
        -- No K9 - try to spawn
        if SpawnK9() then
            return
        end
        return
    end

    -- K9 exists - show radial menu
    k9MenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'k9MenuOpen' })
end

local function CloseK9Menu()
    k9MenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'k9MenuClose' })
end

-- NUI Callback: Menu closed (Escape or right-click)
RegisterNUICallback('k9MenuClosed', function(_, cb)
    k9MenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- NUI Callback: Menu action selected
RegisterNUICallback('k9Action', function(data, cb)
    k9MenuOpen = false
    SetNuiFocus(false, false)

    local action = data.action

    if action == 'follow' then
        K9Follow()
    elseif action == 'stay' then
        K9Stay()
    elseif action == 'sit' then
        K9Sit()
    elseif action == 'lie' then
        K9LieDown()
    elseif action == 'search' then
        K9SearchArea()
    elseif action == 'attack' then
        -- Attack nearest NPC
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestPed = nil
        local nearestDist = 15.0

        local handle, ped = FindFirstPed()
        local found = true

        while found do
            if DoesEntityExist(ped) and ped ~= playerPed and ped ~= k9Dog then
                local pedCoords = GetEntityCoords(ped)
                local dist = #(playerCoords - pedCoords)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPed = ped
                end
            end
            found, ped = FindNextPed(handle)
        end
        EndFindPed(handle)

        if nearestPed then
            K9Attack(nearestPed)
        else
            exports['sb_notify']:Notify('No target nearby', 'error', 3000)
        end
    elseif action == 'return' then
        K9ReturnToCar()
    elseif action == 'dismiss' then
        exports['sb_notify']:Notify('K9 dismissed', 'info', 3000)
        DespawnK9()
    end

    cb('ok')
end)

-- =============================================
-- Attack Detection (when aiming)
-- =============================================

CreateThread(function()
    while true do
        local sleep = 500

        if k9Dog and DoesEntityExist(k9Dog) and k9State ~= 'attacking' then
            local playerPed = PlayerPedId()

            -- Check if player is aiming (weapon or fist)
            if IsPlayerFreeAiming(PlayerId()) or IsAimCamActive() then
                sleep = 0
                local found, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())

                if found and targetEntity and DoesEntityExist(targetEntity) and IsEntityAPed(targetEntity) and targetEntity ~= playerPed and targetEntity ~= k9Dog then
                    -- Show prompt to attack
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to send K9 to attack')
                    EndTextCommandDisplayHelp(0, false, true, -1)

                    if IsControlJustPressed(0, 51) then  -- E key (INPUT_CONTEXT)
                        K9Attack(targetEntity)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- =============================================
-- Duty Sync
-- =============================================

RegisterNetEvent('sb_police:client:updateDuty', function(onDuty)
    local wasOnDuty = isOnDuty
    isOnDuty = onDuty

    -- Despawn K9 when going off duty
    if wasOnDuty and not onDuty then
        if k9Dog and DoesEntityExist(k9Dog) then
            exports['sb_notify']:Notify('K9 dismissed - off duty', 'info', 3000)
            DespawnK9()
        end
    end
end)

-- =============================================
-- Death Handler
-- =============================================

AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]
        local attacker = data[2]
        local isDead = data[4]

        if victim == PlayerPedId() and isDead == 1 then
            -- Officer died - despawn K9
            if k9Dog and DoesEntityExist(k9Dog) then
                DespawnK9()
                print('[sb_police] K9 despawned - officer died')
            end
        end
    end
end)

-- =============================================
-- Resource Cleanup
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DespawnK9()
        if k9MenuOpen then
            SetNuiFocus(false, false)
        end
    end
end)

-- =============================================
-- Commands
-- =============================================

RegisterCommand('k9', function()
    if not CanUseK9() then
        if not IsPoliceJob() then
            exports['sb_notify']:Notify('Police only', 'error', 3000)
        elseif GetPlayerGrade() < Config.K9.MinGrade then
            exports['sb_notify']:Notify('You need Officer III+ rank to use K9', 'error', 3000)
        elseif not isOnDuty then
            exports['sb_notify']:Notify('You must be on duty', 'error', 3000)
        end
        return
    end

    OpenK9Menu()
end, false)

RegisterCommand('k9follow', function()
    if not CanUseK9() then return end
    K9Follow()
end, false)

RegisterCommand('k9stay', function()
    if not CanUseK9() then return end
    K9Stay()
end, false)

RegisterCommand('k9sit', function()
    if not CanUseK9() then return end
    K9Sit()
end, false)

RegisterCommand('k9lie', function()
    if not CanUseK9() then return end
    K9LieDown()
end, false)

RegisterCommand('k9search', function()
    if not CanUseK9() then return end
    K9SearchArea()
end, false)

RegisterCommand('k9return', function()
    if not CanUseK9() then return end
    K9ReturnToCar()
end, false)

RegisterCommand('k9dismiss', function()
    if not CanUseK9() then return end
    if k9Dog and DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('K9 dismissed', 'info', 3000)
        DespawnK9()
    else
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
    end
end, false)

RegisterCommand('k9attack', function()
    if not CanUseK9() then return end

    if not k9Dog or not DoesEntityExist(k9Dog) then
        exports['sb_notify']:Notify('No K9 deployed', 'error', 3000)
        return
    end

    -- Attack nearest ped (not self)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearestPed = nil
    local nearestDist = 10.0

    local handle, ped = FindFirstPed()
    local found = true

    while found do
        if DoesEntityExist(ped) and ped ~= playerPed and ped ~= k9Dog and not IsPedAPlayer(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < nearestDist then
                nearestDist = dist
                nearestPed = ped
            end
        end
        found, ped = FindNextPed(handle)
    end
    EndFindPed(handle)

    if nearestPed then
        K9Attack(nearestPed)
    else
        exports['sb_notify']:Notify('No target nearby', 'error', 3000)
    end
end, false)

RegisterCommand('k9test', function()
    print('[sb_police] ========== K9 DEBUG ==========')
    print('K9 Entity:', k9Dog)
    print('K9 Exists:', k9Dog and DoesEntityExist(k9Dog))
    print('K9 State:', k9State)
    print('K9 Vehicle NetID:', k9Vehicle)
    print('Is On Duty:', isOnDuty)
    print('Can Use K9:', CanUseK9())
    print('Player Grade:', GetPlayerGrade())
    print('Min Grade Required:', Config.K9.MinGrade)
    print('[sb_police] ================================')

    local msg = ('K9: %s | State: %s | Grade: %d/%d'):format(
        k9Dog and DoesEntityExist(k9Dog) and 'Deployed' or 'Not deployed',
        k9State,
        GetPlayerGrade(),
        Config.K9.MinGrade
    )
    exports['sb_notify']:Notify(msg, 'info', 5000)
end, false)

-- Register K keybind
RegisterKeyMapping('k9', 'K9 Menu / Deploy K9', 'keyboard', 'K')

-- =============================================
-- Exports
-- =============================================

exports('HasK9Deployed', function()
    return k9Dog and DoesEntityExist(k9Dog)
end)

exports('GetK9Entity', function()
    return k9Dog
end)

exports('GetK9State', function()
    return k9State
end)

exports('DespawnK9', function()
    DespawnK9()
end)

print('[sb_police] ^2K9 Unit module loaded^7')
