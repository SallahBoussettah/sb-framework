-- ============================================================================
-- SB_PACIFICHEIST - Client Main
-- Pacific Standard Bank Heist for sb_core framework
-- Enhanced with synchronized scene animations
-- ============================================================================

local SBCore = exports['sb_core']:GetCoreObject()

-- State variables
local HeistState = {
    started = false,
    inVault = false,
    inExtendedVault = false,
    robber = false,
    busy = false
}

local VaultCheck = {
    laptop = false,
    drill = false
}

-- Inner vault door state (requires laptop hack THEN C4)
local InnerVaultState = {
    laptopHacked = false,
    c4Planted = false,
    doorOpen = false
}

-- Store the inner vault door's original state (captured at resource start)
local InnerDoorOriginal = {
    heading = nil,
    pos = nil
}

local ClientDoors = {}
local CreatedPeds = {}
local CreatedObjects = {}
local C4Objects = {}
local GlassCuttingData = {
    globalObject = nil,
    globalItem = nil
}

-- Heist bag backpack state
local HeistBagVisible = false
local HasBagItem = false
local OriginalBagDrawable = 0
local OriginalBagTexture = 0

-- ============================================================================
-- HEIST BAG BACKPACK SYSTEM (Clothing component - hides during animations)
-- ============================================================================

-- Component 5 = Bags/Parachute slot
local BAG_COMPONENT = 5
local BAG_DRAWABLE = 45  -- Heist-style bag
local BAG_TEXTURE = 0

function ShowHeistBag()
    if HeistBagVisible then return end

    local ped = PlayerPedId()

    -- Save original
    OriginalBagDrawable = GetPedDrawableVariation(ped, BAG_COMPONENT)
    OriginalBagTexture = GetPedTextureVariation(ped, BAG_COMPONENT)

    -- Set heist bag component
    SetPedComponentVariation(ped, BAG_COMPONENT, BAG_DRAWABLE, BAG_TEXTURE, 0)
    HeistBagVisible = true
end

function HideHeistBag()
    if not HeistBagVisible then return end

    local ped = PlayerPedId()

    -- Remove bag (set to 0 = no bag)
    SetPedComponentVariation(ped, BAG_COMPONENT, 0, 0, 0)
    HeistBagVisible = false
end

-- Thread to check for heist bag in inventory
CreateThread(function()
    while true do
        Wait(1500) -- Check every 1.5 seconds

        SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(result)
            HasBagItem = result
        end, Config.RequiredItems.bag)

        Wait(500) -- Wait for callback

        -- Show bag if we have item and not busy with animations
        if HasBagItem and not HeistBagVisible and not HeistState.busy then
            ShowHeistBag()
        -- Hide bag if we don't have item
        elseif not HasBagItem and HeistBagVisible then
            HideHeistBag()
        -- Re-show after animations complete
        elseif not HeistState.busy and HasBagItem and not HeistBagVisible then
            ShowHeistBag()
        end
        -- Note: We don't hide during busy anymore - direct HideHeistBag() calls handle that
        -- This allows mid-animation ShowHeistBag() calls (like in PlantThermite cover_eyes)
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        HideHeistBag()
    end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function LoadModel(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
    end
    return model
end

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
    end
end

local function LoadPtfxAsset(dict)
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeout = 0
        while not HasNamedPtfxAssetLoaded(dict) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
    end
end

local function Notify(msg, type, duration)
    exports['sb_notify']:Notify(msg, type or 'info', duration or 5000)
end

local function FormatNumber(num)
    local formatted = tostring(num)
    local k = 1
    while k ~= 0 do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    end
    return formatted
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Create security guard NPCs
    for i, guard in ipairs(Config.SecurityGuards) do
        LoadModel(guard.model)
        local ped = CreatePed(4, GetHashKey(guard.model), guard.pos.x, guard.pos.y, guard.pos.z - 0.95, guard.heading, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        table.insert(CreatedPeds, ped)
    end

    -- Create blip for heist location
    local blip = AddBlipForCoord(Config.HeistStart.pos)
    SetBlipSprite(blip, Config.HeistStart.blip.sprite)
    SetBlipColour(blip, Config.HeistStart.blip.color)
    SetBlipAsShortRange(blip, true)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.HeistStart.blip.label)
    EndTextCommandSetBlipName(blip)

    -- Ensure vault doors start closed (in case resource restarted mid-heist)
    Wait(2000)
    CloseVaultDoor('main')
    CloseVaultDoor('extended')

    -- Force the inner vault door closed at startup (it spawns open by default)
    local innerDoorPos = Config.InnerVaultDoor.doorPos
    local innerDoor = GetClosestObjectOfType(innerDoorPos.x, innerDoorPos.y, innerDoorPos.z, 5.0, Config.InnerVaultDoor.doorModel, false, false, false)
    if innerDoor ~= 0 then
        -- Store the open heading, then compute closed heading (open = closed + 90)
        local openHeading = GetEntityHeading(innerDoor)
        InnerDoorOriginal.pos = GetEntityCoords(innerDoor)
        InnerDoorOriginal.heading = openHeading - 90.0 -- closed heading

        -- Force close: set to closed heading and freeze
        local timeout = 0
        while not NetworkHasControlOfEntity(innerDoor) and timeout < 50 do
            NetworkRequestControlOfEntity(innerDoor)
            Wait(10)
            timeout = timeout + 1
        end
        SetEntityHeading(innerDoor, InnerDoorOriginal.heading)
        FreezeEntityPosition(innerDoor, true)
    end
end)

-- ============================================================================
-- SB_TARGET SETUP
-- ============================================================================

CreateThread(function()
    Wait(2000) -- Wait for sb_target to initialize

    -- Heist start target (at guards)
    exports['sb_target']:AddSphereZone('pacific_heist_start', Config.HeistStart.pos, 2.0, {
        {
            name = 'start_heist',
            label = 'Start Pacific Heist',
            icon = 'fa-mask',
            distance = 2.0,
            canInteract = function()
                return not HeistState.started
            end,
            action = function()
                StartHeist()
            end
        }
    })

    -- Door targets (thermite or C4 based on config)
    for i, door in ipairs(Config.FreezeDoors) do
        local isC4 = door.action == 'c4'
        exports['sb_target']:AddSphereZone('pacific_door_' .. i, door.pos, 1.5, {
            {
                name = (isC4 and 'plant_c4_door_' or 'plant_thermite_') .. i,
                label = isC4 and 'Plant C4' or 'Plant Thermite',
                icon = isC4 and 'fa-bomb' or 'fa-fire',
                distance = 2.0,
                canInteract = function()
                    return HeistState.started and door.locked ~= false and not HeistState.busy
                end,
                action = function()
                    if isC4 then
                        PlantC4OnDoor(i, door)
                    else
                        PlantThermite(i, door)
                    end
                end
            }
        })
    end

    -- Laptop hack target (smaller zone to avoid overlap with safe door)
    exports['sb_target']:AddSphereZone('pacific_laptop', Config.LaptopHack.pos, 1.0, {
        {
            name = 'hack_laptop',
            label = 'Hack Security System',
            icon = 'fa-laptop-code',
            distance = 1.5,
            canInteract = function()
                return HeistState.started and not VaultCheck.laptop and not HeistState.busy
            end,
            action = function()
                LaptopHackSequence()
            end
        }
    })

    -- Laser drill target (for extended vault)
    exports['sb_target']:AddSphereZone('pacific_laser', Config.LaserDrill.pos, 1.5, {
        {
            name = 'use_laser_drill',
            label = 'Use Laser Drill',
            icon = 'fa-crosshairs',
            distance = 2.0,
            canInteract = function()
                return HeistState.started and not VaultCheck.drill and not HeistState.busy
            end,
            action = function()
                LaserDrillSequence()
            end
        }
    })

    -- Main cash stack target
    exports['sb_target']:AddSphereZone('pacific_main_stack', Config.MainStack.pos, 1.5, {
        {
            name = 'grab_main_stack',
            label = 'Grab Cash',
            icon = 'fa-money-bill-wave',
            distance = 2.0,
            canInteract = function()
                return HeistState.inVault and not Config.MainStack.taken and not HeistState.busy
            end,
            action = function()
                GrabStack('main')
            end
        }
    })

    -- Trolley targets (main vault - indices 5-8)
    for i = 5, #Config.Trolleys do
        local trolley = Config.Trolleys[i]
        exports['sb_target']:AddSphereZone('pacific_trolley_' .. i, trolley.pos, 1.5, {
            {
                name = 'grab_trolley_' .. i,
                label = 'Grab Loot',
                icon = 'fa-dolly',
                distance = 2.0,
                canInteract = function()
                    return HeistState.inVault and not trolley.taken and not HeistState.busy
                end,
                action = function()
                    GrabTrolley(i)
                end
            }
        })
    end

    -- Drill box targets
    for i, drill in ipairs(Config.DrillBoxes) do
        exports['sb_target']:AddSphereZone('pacific_drill_' .. i, drill.pos, 1.5, {
            {
                name = 'use_drill_' .. i,
                label = 'Drill Safe',
                icon = 'fa-cog',
                distance = 2.0,
                canInteract = function()
                    return HeistState.inVault and not drill.taken and not HeistState.busy
                end,
                action = function()
                    DrillSafe(i)
                end
            }
        })
    end

    -- Extended vault targets
    -- Cell gate C4 targets
    for i, gate in ipairs(Config.CellGates) do
        exports['sb_target']:AddSphereZone('pacific_gate_' .. i, gate.pos, 1.5, {
            {
                name = 'plant_c4_' .. i,
                label = 'Plant C4',
                icon = 'fa-bomb',
                distance = 2.0,
                canInteract = function()
                    return HeistState.inExtendedVault and not gate.planted and not HeistState.busy
                end,
                action = function()
                    PlantC4(i, gate)
                end
            }
        })
    end

    -- Extended stacks
    for i, stack in ipairs(Config.Stacks) do
        exports['sb_target']:AddSphereZone('pacific_stack_' .. i, stack.pos, 1.5, {
            {
                name = 'grab_stack_' .. i,
                label = stack.type == 'gold' and 'Grab Gold' or 'Grab Cash',
                icon = stack.type == 'gold' and 'fa-coins' or 'fa-money-bill-wave',
                distance = 2.0,
                canInteract = function()
                    return HeistState.inExtendedVault and not stack.taken and not HeistState.busy
                end,
                action = function()
                    GrabStack(i)
                end
            }
        })
    end

    -- Extended trolleys (indices 1-4)
    for i = 1, 4 do
        local trolley = Config.Trolleys[i]
        exports['sb_target']:AddSphereZone('pacific_ext_trolley_' .. i, trolley.pos, 1.5, {
            {
                name = 'grab_ext_trolley_' .. i,
                label = 'Grab Loot',
                icon = 'fa-dolly',
                distance = 2.0,
                canInteract = function()
                    return HeistState.inExtendedVault and not trolley.taken and not HeistState.busy
                end,
                action = function()
                    GrabTrolley(i)
                end
            }
        })
    end

    -- Glass cutting target
    exports['sb_target']:AddSphereZone('pacific_glass', Config.GlassCutting.displayPos, 1.5, {
        {
            name = 'cut_glass',
            label = 'Cut Glass',
            icon = 'fa-cut',
            distance = 2.0,
            canInteract = function()
                return HeistState.inExtendedVault and not Config.GlassCutting.taken and not HeistState.busy
            end,
            action = function()
                GlassCuttingSequence()
            end
        }
    })

    -- Painting targets
    for i, painting in ipairs(Config.Paintings) do
        exports['sb_target']:AddSphereZone('pacific_painting_' .. i, painting.objectPos, 1.5, {
            {
                name = 'steal_painting_' .. i,
                label = 'Steal Painting',
                icon = 'fa-image',
                distance = 2.0,
                canInteract = function()
                    return HeistState.inExtendedVault and not painting.taken and not HeistState.busy
                end,
                action = function()
                    StealPainting(i)
                end
            }
        })
    end

    -- Inner vault door laptop hack (must be done first)
    exports['sb_target']:AddSphereZone('pacific_inner_laptop', Config.InnerVaultDoor.laptop.pos, 1.0, {
        {
            name = 'hack_inner_laptop',
            label = 'Hack Security Terminal',
            icon = 'fa-laptop-code',
            distance = 1.5,
            canInteract = function()
                return HeistState.inExtendedVault and not InnerVaultState.laptopHacked and not HeistState.busy
            end,
            action = function()
                InnerLaptopHackSequence()
            end
        }
    })

    -- Inner vault door C4 (only available after laptop hack)
    exports['sb_target']:AddSphereZone('pacific_inner_c4', Config.InnerVaultDoor.doorPos, 1.5, {
        {
            name = 'plant_inner_c4',
            label = 'Plant C4',
            icon = 'fa-bomb',
            distance = 2.0,
            canInteract = function()
                return HeistState.inExtendedVault and InnerVaultState.laptopHacked and not InnerVaultState.doorOpen and not HeistState.busy
            end,
            action = function()
                PlantInnerVaultC4()
            end
        }
    })
end)

-- ============================================================================
-- HEIST START
-- ============================================================================

function StartHeist()
    SBCore.Functions.TriggerCallback('sb_pacificheist:checkPoliceCount', function(canStart)
        if not canStart then
            Notify(Config.Strings.needPolice, 'error')
            return
        end

        SBCore.Functions.TriggerCallback('sb_pacificheist:checkCooldown', function(canProceed, remainingTime)
            if not canProceed then
                Notify(string.format(Config.Strings.cooldownActive, math.ceil(remainingTime / 60)), 'error')
                return
            end

            TriggerServerEvent('sb_pacificheist:startHeist')
        end)
    end)
end

RegisterNetEvent('sb_pacificheist:heistStarted', function()
    HeistState.started = true
    Notify(Config.Strings.heistStarted, 'info', 8000)
    Notify(Config.Strings.requiredItems, 'primary', 10000)
end)

-- Check if heist is already active when player loads in (late join / reconnect)
RegisterNetEvent('sb_core:client:playerLoaded', function()
    SBCore.Functions.TriggerCallback('sb_pacificheist:isHeistActive', function(active)
        if active then
            HeistState.started = true
        end
    end)
end)

-- ============================================================================
-- THERMITE PLANTING (Synchronized Scene)
-- ============================================================================

-- Door ID mapping for sb_doorlock integration
local DoorLockMapping = {
    [1] = 'pacific_main_entrance',
    [2] = 'pacific_gate_2',
    [3] = 'pacific_vault_gate_1',
    [4] = 'pacific_vault_gate_2',
    [5] = 'pacific_safe_door',
}

function PlantThermite(index, door)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'Thermite Charge'), 'error')
            return
        end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim@heists@ornate_bank@thermal_charge'
        LoadAnimDict(animDict)

        -- Load bag model
        LoadModel('hei_p_m_bag_var22_arm_s')
        LoadModel('hei_prop_heist_thermite')

        -- Create bag object
        local bag = CreateObject(GetHashKey('hei_p_m_bag_var22_arm_s'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bag, false, true)

        -- Get scene position from door config
        local scenePos = door.scene.pos
        local sceneRot = door.scene.rot

        -- Create synchronized scene for planting
        local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene, animDict, Planting.animations[1][1], 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag, scene, animDict, Planting.animations[1][2], 4.0, -8.0, 1)

        NetworkStartSynchronisedScene(scene)
        Wait(1500)

        -- Create thermite prop and attach to player
        local thermite = CreateObject(GetHashKey('hei_prop_heist_thermite'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(thermite, false, true)
        AttachEntityToEntity(thermite, ped, GetPedBoneIndex(ped, 28422), 0, 0, 0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

        Notify('Planting thermite charge...', 'info', 4000)
        Wait(4000)

        -- Remove item from inventory
        TriggerServerEvent('sb_pacificheist:removeItem', Config.RequiredItems.thermite)

        -- Delete scene bag and show player's backpack for cover_eyes animation
        if DoesEntityExist(bag) then DeleteEntity(bag) end
        ShowHeistBag() -- Show bag during cover eyes (no synced prop anymore)

        -- Detach and freeze thermite in place
        DetachEntity(thermite, true, true)
        FreezeEntityPosition(thermite, true)

        -- Particle effect for thermite burn
        LoadPtfxAsset('scr_ornate_heist')
        UseParticleFxAssetNextCall('scr_ornate_heist')
        local ptfx = StartParticleFxLoopedAtCoord("scr_heist_ornate_thermal_burn", door.scene.ptfx.x, door.scene.ptfx.y, door.scene.ptfx.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)

        -- Tell other players to show the flames too
        TriggerServerEvent('sb_pacificheist:thermiteFlames', index, true)

        -- Cover eyes intro
        TaskPlayAnim(ped, animDict, "cover_eyes_intro", 8.0, 8.0, 1000, 36, 1, 0, 0, 0)
        Wait(1000)

        -- Cover eyes loop (distance-based)
        local thermitePos = vector3(door.scene.ptfx.x, door.scene.ptfx.y, door.scene.ptfx.z)
        local burnTime = 10000
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < burnTime do
            Wait(100)
            local pedPos = GetEntityCoords(ped)
            local distToThermite = #(pedPos - thermitePos)

            if distToThermite < (Config.ThermiteCoverDistance or 5.0) then
                if not IsEntityPlayingAnim(ped, animDict, 'cover_eyes_loop', 3) then
                    TaskPlayAnim(ped, animDict, 'cover_eyes_loop', 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            else
                if IsEntityPlayingAnim(ped, animDict, 'cover_eyes_loop', 3) then
                    ClearPedTasks(ped)
                end
            end
        end

        ClearPedTasks(ped)
        StopParticleFxLooped(ptfx, 0)

        -- Tell other players to stop the flames
        TriggerServerEvent('sb_pacificheist:thermiteFlames', index, false)

        -- Delete thermite prop
        if DoesEntityExist(thermite) then DeleteEntity(thermite) end

        -- Door unlocked
        door.locked = false
        TriggerServerEvent('sb_pacificheist:doorUnlocked', index)

        -- Bypass door in sb_doorlock
        local doorLockId = DoorLockMapping[index]
        if doorLockId then
            TriggerServerEvent('sb_doorlock:bypassDoor', doorLockId)
        end

        -- Model swap for melted door
        if door.swapFrom and door.swapTo then
            CreateModelSwap(door.pos.x, door.pos.y, door.pos.z, 5.0, GetHashKey(door.swapFrom), GetHashKey(door.swapTo), true)
        end

        Notify('Door melted! You can now proceed.', 'success')
        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
    end, Config.RequiredItems.thermite)
end

-- ============================================================================
-- C4 DOOR BREACHING (For specific doors that need C4 instead of thermite)
-- ============================================================================

function PlantC4OnDoor(index, door)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'C4 Explosive'), 'error')
            return
        end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim@heists@ornate_bank@thermal_charge'
        LoadAnimDict(animDict)
        LoadModel('hei_p_m_bag_var22_arm_s')
        LoadModel('prop_bomb_01')

        -- Create bag
        local bag = CreateObject(GetHashKey('hei_p_m_bag_var22_arm_s'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bag, false, true)

        -- Get scene position from door config
        local scenePos = door.scene.pos
        local sceneRot = door.scene.rot

        -- Create synchronized scene for planting
        local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene, animDict, Planting.animations[1][1], 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag, scene, animDict, Planting.animations[1][2], 4.0, -8.0, 1)

        NetworkStartSynchronisedScene(scene)
        Wait(1500)

        -- Create and attach bomb
        local bomb = CreateObject(GetHashKey('prop_bomb_01'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bomb, false, true)
        AttachEntityToEntity(bomb, ped, GetPedBoneIndex(ped, 28422), 0, 0, 0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

        Notify('Planting C4...', 'info', 3000)
        Wait(3000)

        -- Remove item from inventory
        TriggerServerEvent('sb_pacificheist:removeItem', Config.RequiredItems.c4)

        -- Cleanup bag
        if DoesEntityExist(bag) then DeleteEntity(bag) end

        -- Detach and freeze bomb at door
        DetachEntity(bomb, true, true)
        local bombPos = door.scene.ptfx or door.pos
        SetEntityCoords(bomb, bombPos.x, bombPos.y, bombPos.z)
        FreezeEntityPosition(bomb, true)

        Notify('C4 planted! Move back and it will detonate.', 'warning', 3000)

        -- Auto-detonate after player moves away
        CreateThread(function()
            while true do
                Wait(500)
                local playerPos = GetEntityCoords(PlayerPedId())
                local dist = #(playerPos - door.pos)

                if dist > 5.0 then
                    -- Countdown
                    Wait(1000)

                    -- Explosion
                    AddExplosion(bombPos.x, bombPos.y, bombPos.z, 2, 50.0, true, false, 1.0)
                    if DoesEntityExist(bomb) then DeleteEntity(bomb) end

                    -- Door unlocked
                    door.locked = false
                    TriggerServerEvent('sb_pacificheist:doorUnlocked', index)

                    -- Bypass door in sb_doorlock
                    local doorLockId = DoorLockMapping[index]
                    if doorLockId then
                        TriggerServerEvent('sb_doorlock:bypassDoor', doorLockId)
                    end

                    -- Model swap if applicable
                    if door.swapFrom and door.swapTo then
                        CreateModelSwap(door.pos.x, door.pos.y, door.pos.z, 5.0, GetHashKey(door.swapFrom), GetHashKey(door.swapTo), true)
                    end

                    -- Show custom success message or default
                    local msg = door.successMsg or 'Door breached!'
                    Notify(msg, 'success')
                    break
                end
            end
        end)

        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
    end, Config.RequiredItems.c4)
end

-- ============================================================================
-- LAPTOP HACK SEQUENCE (Synchronized Scene with Minigame)
-- ============================================================================

function LaptopHackSequence()
    print('[sb_pacificheist] ========== LAPTOP HACK SEQUENCE ==========')
    print('[sb_pacificheist] LaptopHackSequence() called')

    -- Use a thread to handle sequential checks properly
    CreateThread(function()
        -- Check laptop
        print('[sb_pacificheist] Checking for laptop item: ' .. tostring(Config.RequiredItems.laptop))
        local hasLaptop = nil
        SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(result)
            hasLaptop = result
        end, Config.RequiredItems.laptop)

        -- Wait for callback
        local timeout = 0
        while hasLaptop == nil and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end

        print('[sb_pacificheist] hasLaptop result: ' .. tostring(hasLaptop))

        if not hasLaptop then
            Notify(string.format(Config.Strings.needItem, 'Hacking Laptop'), 'error')
            return
        end

        -- Check USB
        print('[sb_pacificheist] Laptop found! Now checking for USB: ' .. tostring(Config.RequiredItems.usb))
        local hasUsb = nil
        SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(result)
            hasUsb = result
        end, Config.RequiredItems.usb)

        -- Wait for callback
        timeout = 0
        while hasUsb == nil and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end

        print('[sb_pacificheist] hasUsb result: ' .. tostring(hasUsb))

        if not hasUsb then
            Notify(string.format(Config.Strings.needItem, 'Trojan USB'), 'error')
            return
        end

        print('[sb_pacificheist] Both items found, starting laptop hack...')
        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation
        exports['sb_hud']:SetHudVisible(false) -- Hide HUD during hacking
        TriggerServerEvent('sb_pacificheist:vaultAction', 'laptop', true)

            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local animDict = 'anim@heists@ornate_bank@hack'
            LoadAnimDict(animDict)

            -- Player stands here facing the laptop terminal (from config)
            local scenePos = Config.LaptopHack.scenePos
            local sceneRot = vector3(0.0, 0.0, Config.LaptopHack.sceneHeading)
            print('[sb_pacificheist] Using laptop scene pos: ' .. tostring(scenePos))

            -- Create props for synchronized scene
            print('[sb_pacificheist] Creating props...')
            LaptopAnimation.sceneObjects = {}
            for k, v in pairs(LaptopAnimation.objects) do
                LoadModel(v)
                LaptopAnimation.sceneObjects[k] = CreateObject(GetHashKey(v), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
                print('[sb_pacificheist] Created prop ' .. k .. ': ' .. v .. ' = ' .. tostring(LaptopAnimation.sceneObjects[k]))
            end

            -- Create all animation scenes
            print('[sb_pacificheist] Creating animation scenes...')
            LaptopAnimation.scenes = {}
            for i = 1, #LaptopAnimation.animations do
                LaptopAnimation.scenes[i] = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, true, false, 1065353216, 0, 1.3)
                NetworkAddPedToSynchronisedScene(ped, LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][1], 1.5, -4.0, 1, 16, 1148846080, 0)
                NetworkAddEntityToSynchronisedScene(LaptopAnimation.sceneObjects[1], LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][2], 4.0, -8.0, 1)
                NetworkAddEntityToSynchronisedScene(LaptopAnimation.sceneObjects[2], LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][3], 4.0, -8.0, 1)
                NetworkAddEntityToSynchronisedScene(LaptopAnimation.sceneObjects[3], LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][4], 4.0, -8.0, 1)
                print('[sb_pacificheist] Created scene ' .. i)
            end

            -- Play enter animation
            print('[sb_pacificheist] Starting enter animation...')
            NetworkStartSynchronisedScene(LaptopAnimation.scenes[1])
            Notify('Setting up laptop...', 'info', 3000)
            Wait(6300)
            print('[sb_pacificheist] Enter animation done.')

            -- Play hack loop animation
            NetworkStartSynchronisedScene(LaptopAnimation.scenes[2])
            Wait(2000)

            -- Start the hacking minigame (scaleform)
            print('[sb_pacificheist] About to call StartComputer()...')
            print('[sb_pacificheist] StartComputer function exists: ' .. tostring(StartComputer ~= nil))

            StartComputer()

            print('[sb_pacificheist] StartComputer() called, waiting for hackFinished...')
            print('[sb_pacificheist] hackFinished value: ' .. tostring(hackFinished))

            -- Wait for hacking to complete
            local waitCount = 0
            while not hackFinished do
                Wait(100)
                waitCount = waitCount + 1
                if waitCount % 50 == 0 then -- Every 5 seconds
                    print('[sb_pacificheist] Still waiting for hack... hackFinished=' .. tostring(hackFinished) .. ', hackingActive=' .. tostring(hackingActive))
                end
            end
            print('[sb_pacificheist] Hack finished! hackStatus=' .. tostring(hackStatus))
            hackFinished = false

            -- Play exit animation
            NetworkStartSynchronisedScene(LaptopAnimation.scenes[3])
            Wait(4600)

            -- Cleanup props
            for k, v in pairs(LaptopAnimation.sceneObjects) do
                if DoesEntityExist(v) then DeleteEntity(v) end
            end
            LaptopAnimation.sceneObjects = {}

            TriggerServerEvent('sb_pacificheist:vaultAction', 'laptop', false)

            if hackStatus then
                -- Remove USB (consumed on use), laptop stays
                TriggerServerEvent('sb_pacificheist:removeItem', Config.RequiredItems.usb)

                VaultCheck.laptop = true
                SetupMainVault()
                -- Open the door BEFORE notifying other players, so we have entity control
                OpenVaultDoor('main')
                TriggerServerEvent('sb_pacificheist:vaultOpened', 'main')
                TriggerServerEvent('sb_pacificheist:policeAlert', GetEntityCoords(ped))
                Notify('Security bypassed! Vault opening...', 'success')
            else
                Notify('Hack failed!', 'error')
            end

            exports['sb_hud']:SetHudVisible(true) -- Show HUD again
            ShowHeistBag() -- Show bag again after animation
            HeistState.busy = false
    end)
end

-- ============================================================================
-- INNER VAULT LAPTOP HACK (unlocks C4 placement for inner door)
-- ============================================================================

function InnerLaptopHackSequence()
    -- Check for laptop
    CreateThread(function()
        local hasLaptop = nil
        SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(result)
            hasLaptop = result
        end, Config.RequiredItems.laptop)

        local timeout = 0
        while hasLaptop == nil and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end

        if not hasLaptop then
            Notify(string.format(Config.Strings.needItem, 'Hacking Laptop'), 'error')
            return
        end

        -- Check for USB
        local hasUsb = nil
        SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(result)
            hasUsb = result
        end, Config.RequiredItems.usb)

        timeout = 0
        while hasUsb == nil and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end

        if not hasUsb then
            Notify(string.format(Config.Strings.needItem, 'Trojan USB'), 'error')
            return
        end

        HeistState.busy = true
        HideHeistBag()
        exports['sb_hud']:SetHudVisible(false)

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim@heists@ornate_bank@hack'
        LoadAnimDict(animDict)

        -- Use inner vault laptop positions
        local scenePos = Config.InnerVaultDoor.laptop.scenePos
        local sceneRot = vector3(0.0, 0.0, Config.InnerVaultDoor.laptop.sceneHeading)

        -- Create props
        LaptopAnimation.sceneObjects = {}
        for k, v in pairs(LaptopAnimation.objects) do
            LoadModel(v)
            LaptopAnimation.sceneObjects[k] = CreateObject(GetHashKey(v), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        end

        -- Create animation scenes
        LaptopAnimation.scenes = {}
        for i = 1, #LaptopAnimation.animations do
            LaptopAnimation.scenes[i] = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, true, false, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(ped, LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][1], 1.5, -4.0, 1, 16, 1148846080, 0)
            NetworkAddEntityToSynchronisedScene(LaptopAnimation.sceneObjects[1], LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][2], 4.0, -8.0, 1)
            NetworkAddEntityToSynchronisedScene(LaptopAnimation.sceneObjects[2], LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][3], 4.0, -8.0, 1)
            NetworkAddEntityToSynchronisedScene(LaptopAnimation.sceneObjects[3], LaptopAnimation.scenes[i], animDict, LaptopAnimation.animations[i][4], 4.0, -8.0, 1)
        end

        -- Play enter animation
        NetworkStartSynchronisedScene(LaptopAnimation.scenes[1])
        Notify('Hacking security terminal...', 'info', 3000)
        Wait(6300)

        -- Play hack loop animation
        NetworkStartSynchronisedScene(LaptopAnimation.scenes[2])
        Wait(2000)

        -- Start the hacking minigame
        StartComputer()

        -- Wait for hacking to complete
        while not hackFinished do
            Wait(100)
        end
        local success = hackStatus
        hackFinished = false

        -- Play exit animation
        NetworkStartSynchronisedScene(LaptopAnimation.scenes[3])
        Wait(4600)

        -- Cleanup props
        for k, v in pairs(LaptopAnimation.sceneObjects) do
            if DoesEntityExist(v) then DeleteEntity(v) end
        end
        LaptopAnimation.sceneObjects = {}

        if success then
            -- Remove USB (consumed on use)
            TriggerServerEvent('sb_pacificheist:removeItem', Config.RequiredItems.usb)

            InnerVaultState.laptopHacked = true
            TriggerServerEvent('sb_pacificheist:innerVaultLaptopHacked')
            Notify('Security disabled! Plant C4 on the door.', 'success')
        else
            Notify('Hack failed!', 'error')
        end

        exports['sb_hud']:SetHudVisible(true)
        ShowHeistBag()
        HeistState.busy = false
    end)
end

-- ============================================================================
-- INNER VAULT C4 (only available after laptop hack)
-- ============================================================================

function PlantInnerVaultC4()
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'C4 Explosive'), 'error')
            return
        end

        if not InnerVaultState.laptopHacked then
            Notify('Security system is still active! Hack the terminal first.', 'error')
            return
        end

        HeistState.busy = true
        HideHeistBag()

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim@heists@ornate_bank@thermal_charge'
        LoadAnimDict(animDict)
        LoadModel('hei_p_m_bag_var22_arm_s')
        LoadModel('prop_bomb_01')

        -- Create bag
        local bag = CreateObject(GetHashKey('hei_p_m_bag_var22_arm_s'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bag, false, true)

        -- Use inner vault C4 positions
        local scenePos = Config.InnerVaultDoor.c4.scenePos
        local sceneRot = Config.InnerVaultDoor.c4.sceneRot

        -- Create synchronized scene
        local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene, animDict, Planting.animations[1][1], 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag, scene, animDict, Planting.animations[1][2], 4.0, -8.0, 1)

        NetworkStartSynchronisedScene(scene)
        Wait(1500)

        -- Create and attach bomb
        local bomb = CreateObject(GetHashKey('prop_bomb_01'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bomb, false, true)
        AttachEntityToEntity(bomb, ped, GetPedBoneIndex(ped, 28422), 0, 0, 0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

        Notify('Planting C4...', 'info', 3000)
        Wait(3000)

        -- Remove item from inventory
        TriggerServerEvent('sb_pacificheist:removeItem', Config.RequiredItems.c4)

        -- Cleanup bag
        if DoesEntityExist(bag) then DeleteEntity(bag) end

        -- Detach and freeze bomb at door
        DetachEntity(bomb, true, true)
        local bombPos = Config.InnerVaultDoor.c4.explosionPos
        SetEntityCoords(bomb, bombPos.x, bombPos.y, bombPos.z)
        FreezeEntityPosition(bomb, true)

        InnerVaultState.c4Planted = true
        Notify('C4 planted! Move back and it will detonate.', 'warning', 3000)

        -- Auto-detonate when player moves away (only this specific C4)
        CreateThread(function()
            while true do
                Wait(500)
                local playerPos = GetEntityCoords(PlayerPedId())
                local dist = #(playerPos - bombPos)

                if dist > 5.0 then
                    Wait(1000)

                    -- Explosion (only affects this door)
                    AddExplosion(bombPos.x, bombPos.y, bombPos.z, 2, 50.0, true, false, 1.0)
                    if DoesEntityExist(bomb) then DeleteEntity(bomb) end

                    InnerVaultState.doorOpen = true
                    TriggerServerEvent('sb_pacificheist:innerVaultDoorOpened')
                    Notify('Inner vault door breached!', 'success')
                    break
                end
            end
        end)

        ShowHeistBag()
        HeistState.busy = false
    end, Config.RequiredItems.c4)
end

-- ============================================================================
-- LASER DRILL SEQUENCE (Synchronized Scene with Camera)
-- ============================================================================

function LaserDrillSequence()
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'Thermal Drill'), 'error')
            return
        end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation
        exports['sb_hud']:SetHudVisible(false) -- Hide HUD during drilling
        TriggerServerEvent('sb_pacificheist:vaultAction', 'drill', true)

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim_heist@hs3f@ig9_vault_drill@laser_drill@'
        LoadAnimDict(animDict)

        local bagModel = 'hei_p_m_bag_var22_arm_s'
        local laserDrillModel = 'ch_prop_laserdrill_01a'
        LoadModel(bagModel)
        LoadModel(laserDrillModel)

        -- Setup animated camera
        local cam = CreateCam("DEFAULT_ANIMATED_CAMERA", true)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 3000, true, false)

        -- Create props
        local bag = CreateObject(GetHashKey(bagModel), pedCoords.x, pedCoords.y, pedCoords.z, true, false, false)
        local laserDrill = CreateObject(GetHashKey(laserDrillModel), pedCoords.x, pedCoords.y, pedCoords.z, true, false, false)

        local vaultPos = Config.LaserDrill.scene.pos
        local vaultRot = Config.LaserDrill.scene.rot

        -- Create all drill animation scenes
        LaserDrill.scenes = {}
        for i = 1, #LaserDrill.animations do
            LaserDrill.scenes[i] = NetworkCreateSynchronisedScene(vaultPos, vaultRot, 2, true, false, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(ped, LaserDrill.scenes[i], animDict, LaserDrill.animations[i][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
            NetworkAddEntityToSynchronisedScene(bag, LaserDrill.scenes[i], animDict, LaserDrill.animations[i][2], 1.0, -1.0, 1148846080)
            NetworkAddEntityToSynchronisedScene(laserDrill, LaserDrill.scenes[i], animDict, LaserDrill.animations[i][3], 1.0, -1.0, 1148846080)
        end

        -- Intro animation with camera
        NetworkStartSynchronisedScene(LaserDrill.scenes[1])
        PlayCamAnim(cam, 'intro_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'intro') * 1000)

        -- Drill start animation
        NetworkStartSynchronisedScene(LaserDrill.scenes[2])
        PlayCamAnim(cam, 'drill_straight_start_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'drill_straight_start') * 1000)

        -- Drill idle loop with minigame
        NetworkStartSynchronisedScene(LaserDrill.scenes[3])
        PlayCamAnim(cam, 'drill_straight_idle_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)

        Notify('Keep drilling steady! Dont overheat!', 'warning', 5000)

        -- Start drilling minigame
        Drilling.Type = 'VAULT_LASER'
        local drillSuccess = false

        Drilling.Start(function(success)
            drillSuccess = success
        end)

        -- Wait for drilling to complete
        while Drilling.Active do
            Wait(100)
        end

        if drillSuccess then
            -- Success - drill end animation
            NetworkStartSynchronisedScene(LaserDrill.scenes[5])
            PlayCamAnim(cam, 'drill_straight_end_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
            Wait(GetAnimDuration(animDict, 'drill_straight_end') * 1000)

            -- Exit animation
            NetworkStartSynchronisedScene(LaserDrill.scenes[6])
            PlayCamAnim(cam, 'exit_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
            Wait(GetAnimDuration(animDict, 'exit') * 1000)

            RenderScriptCams(false, false, 0, true, false)
            DestroyCam(cam, false)
            ClearPedTasks(ped)

            -- Cleanup props
            if DoesEntityExist(bag) then DeleteEntity(bag) end
            if DoesEntityExist(laserDrill) then DeleteEntity(laserDrill) end

            -- Mark drill complete FIRST, then setup vault, then open door
            VaultCheck.drill = true
            SetupExtendedVault()
            -- Open the door BEFORE notifying other players, so we have entity control
            OpenVaultDoor('extended')
            -- Now tell server (other players will get syncVaultOpened after a delay)
            TriggerServerEvent('sb_pacificheist:vaultOpened', 'extended')
            TriggerServerEvent('sb_pacificheist:policeAlert', GetEntityCoords(ped))
            Notify('Extended vault opened!', 'success')
        else
            -- Failure - fail animation
            NetworkStartSynchronisedScene(LaserDrill.scenes[4])
            PlayCamAnim(cam, 'drill_straight_fail_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
            Wait((GetAnimDuration(animDict, 'drill_straight_fail') * 1000) - 1500)

            RenderScriptCams(false, false, 0, true, false)
            DestroyCam(cam, false)
            ClearPedTasks(ped)

            if DoesEntityExist(bag) then DeleteEntity(bag) end
            if DoesEntityExist(laserDrill) then DeleteEntity(laserDrill) end

            Notify('Drill failed! Try again.', 'error')
        end

        TriggerServerEvent('sb_pacificheist:vaultAction', 'drill', false)
        exports['sb_hud']:SetHudVisible(true) -- Show HUD again
        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
    end, Config.RequiredItems.drill)
end

-- ============================================================================
-- VAULT SETUP
-- ============================================================================

function SetupMainVault()
    HeistState.inVault = true
    -- HeistState.robber is now set only by server via setAsRobber event (first painting/glass looter)

    -- Spawn main vault trolleys (indices 5-8)
    for i = 5, #Config.Trolleys do
        local trolley = Config.Trolleys[i]
        LoadModel(trolley.model)
        local obj = CreateObject(GetHashKey(trolley.model), trolley.pos.x, trolley.pos.y, trolley.pos.z, true, true, false)
        if trolley.heading then
            SetEntityHeading(obj, trolley.heading)
        end
        table.insert(CreatedObjects, obj)
    end

    -- Spawn main stack
    LoadModel(Config.MainStack.model)
    local mainStack = CreateObject(GetHashKey(Config.MainStack.model), Config.MainStack.pos.x, Config.MainStack.pos.y, Config.MainStack.pos.z, true, true, false)
    SetEntityHeading(mainStack, Config.MainStack.heading)
    table.insert(CreatedObjects, mainStack)

    -- Start escape check loop
    CreateThread(function()
        while HeistState.inVault or HeistState.inExtendedVault do
            local pedCoords = GetEntityCoords(PlayerPedId())
            local dist = #(pedCoords - Config.MainStack.pos)

            if dist > 150.0 and HeistState.robber then
                TriggerEscape()
                break
            end

            Wait(1000)
        end
    end)
end

function SetupExtendedVault()
    HeistState.inExtendedVault = true
    -- HeistState.robber is now set only by server via setAsRobber event (first painting/glass looter)

    -- Spawn extended vault stacks
    for i, stack in ipairs(Config.Stacks) do
        LoadModel(stack.model)
        local obj = CreateObject(GetHashKey(stack.model), stack.pos.x, stack.pos.y, stack.pos.z, true, true, false)
        SetEntityHeading(obj, stack.heading)
        table.insert(CreatedObjects, obj)
    end

    -- Spawn trolleys (indices 1-4)
    for i = 1, 4 do
        local trolley = Config.Trolleys[i]
        LoadModel(trolley.model)
        local obj = CreateObject(GetHashKey(trolley.model), trolley.pos.x, trolley.pos.y, trolley.pos.z, true, true, false)
        table.insert(CreatedObjects, obj)
    end

    -- Setup glass cutting display with random reward
    local randomIndex = math.random(1, #Config.GlassCuttingRewards)
    local reward = Config.GlassCuttingRewards[randomIndex]
    GlassCuttingData.globalItem = reward.item
    GlassCuttingData.globalObject = reward.model

    LoadModel('h4_prop_h4_glass_disp_01a')
    local glass = CreateObject(GetHashKey('h4_prop_h4_glass_disp_01a'), Config.GlassCutting.displayPos.x, Config.GlassCutting.displayPos.y, Config.GlassCutting.displayPos.z, true, true, false)
    SetEntityHeading(glass, Config.GlassCutting.displayHeading)
    table.insert(CreatedObjects, glass)

    LoadModel(reward.model)
    local rewardObj = CreateObject(GetHashKey(reward.model), Config.GlassCutting.rewardPos.x, Config.GlassCutting.rewardPos.y, Config.GlassCutting.rewardPos.z, true, true, false)
    table.insert(CreatedObjects, rewardObj)

    TriggerServerEvent('sb_pacificheist:setGlassReward', reward.item, randomIndex)

    -- Spawn paintings
    for i, painting in ipairs(Config.Paintings) do
        LoadModel(painting.model)
        local obj = CreateObjectNoOffset(GetHashKey(painting.model), painting.objectPos.x, painting.objectPos.y, painting.objectPos.z, true, false, false)
        SetEntityRotation(obj, 0, 0, painting.heading, 2, true)
        table.insert(CreatedObjects, obj)
    end
end

function OpenVaultDoor(vaultType)
    if vaultType == 'main' then
        local vault = GetClosestObjectOfType(Config.MainVault.doorPos.x, Config.MainVault.doorPos.y, Config.MainVault.doorPos.z, 2.0, GetHashKey(Config.MainVault.doorModel), false, false, false)
        if vault ~= 0 then
            CreateThread(function()
                -- Request network control so heading changes sync to all players
                local timeout = 0
                while not NetworkHasControlOfEntity(vault) and timeout < 50 do
                    NetworkRequestControlOfEntity(vault)
                    Wait(10)
                    timeout = timeout + 1
                end

                local currentHeading = GetEntityHeading(vault)
                while currentHeading > Config.MainVault.openHeading do
                    currentHeading = currentHeading - 0.2
                    SetEntityHeading(vault, currentHeading)
                    Wait(10)
                end
            end)
        end
    else
        local vault = GetClosestObjectOfType(Config.ExtendedVault.doorPos.x, Config.ExtendedVault.doorPos.y, Config.ExtendedVault.doorPos.z, 2.0, GetHashKey(Config.ExtendedVault.doorModel), false, false, false)
        if vault ~= 0 then
            CreateThread(function()
                -- Request network control so heading changes sync to all players
                local timeout = 0
                while not NetworkHasControlOfEntity(vault) and timeout < 50 do
                    NetworkRequestControlOfEntity(vault)
                    Wait(10)
                    timeout = timeout + 1
                end

                local currentHeading = GetEntityHeading(vault)
                while currentHeading < Config.ExtendedVault.openHeading do
                    currentHeading = currentHeading + 0.2
                    SetEntityHeading(vault, currentHeading)
                    Wait(10)
                end
            end)
        end
    end
end

function CloseVaultDoor(vaultType)
    if vaultType == 'main' then
        local vault = GetClosestObjectOfType(Config.MainVault.doorPos.x, Config.MainVault.doorPos.y, Config.MainVault.doorPos.z, 2.0, GetHashKey(Config.MainVault.doorModel), false, false, false)
        if vault ~= 0 then
            local timeout = 0
            while not NetworkHasControlOfEntity(vault) and timeout < 50 do
                NetworkRequestControlOfEntity(vault)
                Wait(10)
                timeout = timeout + 1
            end
            SetEntityHeading(vault, Config.MainVault.closeHeading)
        end
    else
        local vault = GetClosestObjectOfType(Config.ExtendedVault.doorPos.x, Config.ExtendedVault.doorPos.y, Config.ExtendedVault.doorPos.z, 2.0, GetHashKey(Config.ExtendedVault.doorModel), false, false, false)
        if vault ~= 0 then
            local timeout = 0
            while not NetworkHasControlOfEntity(vault) and timeout < 50 do
                NetworkRequestControlOfEntity(vault)
                Wait(10)
                timeout = timeout + 1
            end
            SetEntityHeading(vault, Config.ExtendedVault.closeHeading)
        end
    end
end

-- ============================================================================
-- GRABBING LOOT (Synchronized Scene)
-- ============================================================================

function GrabStack(index)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'Heist Bag'), 'error')
            return
        end

        -- Server-side claim (prevents double-grab exploit)
        local lootType = index == 'main' and 'mainStack' or 'stack'
        local lootIndex = index == 'main' and 0 or index
        SBCore.Functions.TriggerCallback('sb_pacificheist:canLoot', function(canLoot)
            if not canLoot then
                Notify('Already taken!', 'error')
                return
            end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local isGold = false
        local animDict
        local stackModel

        if index == 'main' then
            stackModel = GetHashKey('h4_prop_h4_cash_stack_01a')
            animDict = 'anim@scripted@heist@ig1_table_grab@cash@male@'
            Config.MainStack.taken = true
        else
            local stack = Config.Stacks[index]
            stack.taken = true
            isGold = stack.type == 'gold'
            stackModel = GetHashKey(stack.model)
            animDict = isGold and 'anim@scripted@heist@ig1_table_grab@gold@male@' or 'anim@scripted@heist@ig1_table_grab@cash@male@'
        end

        LoadAnimDict(animDict)
        LoadModel('hei_p_m_bag_var22_arm_s')

        -- Create bag prop
        local bag = CreateObject(GetHashKey('hei_p_m_bag_var22_arm_s'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)

        -- Find the stack object in the world
        local searchPos = index == 'main' and Config.MainStack.pos or Config.Stacks[index].pos
        local sceneObject = GetClosestObjectOfType(searchPos.x, searchPos.y, searchPos.z, 3.0, stackModel, false, false, false)

        -- Request network control so animation and deletion sync to other players
        local timeout = 0
        while not NetworkHasControlOfEntity(sceneObject) and timeout < 50 do
            NetworkRequestControlOfEntity(sceneObject)
            Wait(10)
            timeout = timeout + 1
        end

        local scenePos = GetEntityCoords(sceneObject)
        local sceneRot = GetEntityRotation(sceneObject)

        -- Create synchronized scenes
        GrabCash.scenes = {}
        for i = 1, #GrabCash.animations do
            GrabCash.scenes[i] = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, true, false, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(ped, GrabCash.scenes[i], animDict, GrabCash.animations[i][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
            NetworkAddEntityToSynchronisedScene(bag, GrabCash.scenes[i], animDict, GrabCash.animations[i][2], 1.0, -1.0, 1148846080)
            if i == 2 then
                local grabAnim = isGold and 'grab_gold' or GrabCash.animations[i][3]
                NetworkAddEntityToSynchronisedScene(sceneObject, GrabCash.scenes[i], animDict, grabAnim, 1.0, -1.0, 1148846080)
            end
        end

        -- Play enter animation
        NetworkStartSynchronisedScene(GrabCash.scenes[1])
        Wait(GetAnimDuration(animDict, 'enter') * 1000)

        -- Play grab animation
        NetworkStartSynchronisedScene(GrabCash.scenes[2])
        Wait((GetAnimDuration(animDict, 'grab') * 1000) - 3000)

        -- Delete the stack object locally (we have network control)
        if DoesEntityExist(sceneObject) then
            DeleteEntity(sceneObject)
        end

        -- Server already synced deletion to other players via canLoot callback

        -- Give reward
        if isGold then
            TriggerServerEvent('sb_pacificheist:rewardItem', Config.RewardItems[1].name, Config.StackRewards.gold, 'item')
        else
            TriggerServerEvent('sb_pacificheist:rewardItem', nil, Config.StackRewards.cash, 'money')
        end

        -- Play exit animation
        NetworkStartSynchronisedScene(GrabCash.scenes[4])
        Wait(GetAnimDuration(animDict, 'exit') * 1000)

        -- Cleanup
        if DoesEntityExist(bag) then DeleteEntity(bag) end
        ClearPedTasks(ped)

        Notify(isGold and 'Grabbed gold bars!' or 'Grabbed cash!', 'success')
        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
        end, lootType, lootIndex)
    end, Config.RequiredItems.bag)
end

function GrabTrolley(index)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'Heist Bag'), 'error')
            return
        end

        -- Server-side claim (prevents double-grab exploit)
        SBCore.Functions.TriggerCallback('sb_pacificheist:canLoot', function(canLoot)
            if not canLoot then
                Notify('Already taken!', 'error')
                return
            end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local trolley = Config.Trolleys[index]
        trolley.taken = true

        local animDict = 'anim@heists@ornate_bank@grab_cash'
        LoadAnimDict(animDict)
        LoadModel('hei_p_m_bag_var22_arm_s')

        -- Determine grab model based on trolley type
        local grabModel
        if trolley.rewardType == 'diamond' then
            grabModel = 'ch_prop_vault_dimaondbox_01a'
        elseif trolley.rewardType == 'gold' then
            grabModel = 'ch_prop_gold_bar_01a'
        elseif trolley.rewardType == 'cocaine' then
            grabModel = 'prop_coke_block_half_a'
        else
            grabModel = 'hei_prop_heist_cash_pile'
        end

        -- Find trolley object
        local sceneObject = GetClosestObjectOfType(trolley.pos.x, trolley.pos.y, trolley.pos.z, 2.0, GetHashKey(trolley.model), false, false, false)

        -- Request network control
        local timeout = 0
        while not NetworkHasControlOfEntity(sceneObject) and timeout < 50 do
            NetworkRequestControlOfEntity(sceneObject)
            Wait(10)
            timeout = timeout + 1
        end

        -- Create bag
        local bag = CreateObject(GetHashKey("hei_p_m_bag_var22_arm_s"), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)

        -- Create synchronized scenes
        TrollyAnimation.scenes = {}
        for i = 1, #TrollyAnimation.animations do
            TrollyAnimation.scenes[i] = NetworkCreateSynchronisedScene(GetEntityCoords(sceneObject), GetEntityRotation(sceneObject), 2, true, false, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(ped, TrollyAnimation.scenes[i], animDict, TrollyAnimation.animations[i][1], 1.5, -4.0, 1, 16, 1148846080, 0)
            NetworkAddEntityToSynchronisedScene(bag, TrollyAnimation.scenes[i], animDict, TrollyAnimation.animations[i][2], 4.0, -8.0, 1)
            if i == 2 then
                NetworkAddEntityToSynchronisedScene(sceneObject, TrollyAnimation.scenes[i], animDict, "cart_cash_dissapear", 4.0, -8.0, 1)
            end
        end

        -- Play intro
        NetworkStartSynchronisedScene(TrollyAnimation.scenes[1])
        Wait(1750)

        -- Start cash appear loop with grab animation
        CashAppear(grabModel, trolley.rewardType, ped)
        NetworkStartSynchronisedScene(TrollyAnimation.scenes[2])
        Wait(37000)

        -- Exit
        NetworkStartSynchronisedScene(TrollyAnimation.scenes[3])
        Wait(2000)

        -- Cleanup
        if DoesEntityExist(bag) then DeleteEntity(bag) end
        ClearPedTasks(ped)

        -- Server already synced trolley removal to other players via canLoot callback

        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
        end, 'trolley', index)
    end, Config.RequiredItems.bag)
end

-- Cash appear effect during trolley grab
function CashAppear(grabModel, rewardType, ped)
    local pedCoords = GetEntityCoords(ped)

    LoadModel(grabModel)
    local grabObj = CreateObject(GetHashKey(grabModel), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)

    FreezeEntityPosition(grabObj, true)
    SetEntityInvincible(grabObj, true)
    SetEntityNoCollisionEntity(grabObj, ped, false)
    SetEntityVisible(grabObj, false, false)
    AttachEntityToEntity(grabObj, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 0, true)

    local startedGrabbing = GetGameTimer()

    CreateThread(function()
        while GetGameTimer() - startedGrabbing < 37000 do
            Wait(1)
            DisableControlAction(0, 73, true)

            if HasAnimEventFired(ped, GetHashKey("CASH_APPEAR")) then
                if not IsEntityVisible(grabObj) then
                    SetEntityVisible(grabObj, true, false)
                end
            end

            if HasAnimEventFired(ped, GetHashKey("RELEASE_CASH_DESTROY")) then
                if IsEntityVisible(grabObj) then
                    SetEntityVisible(grabObj, false, false)

                    -- Give reward
                    if rewardType == 'cash' then
                        TriggerServerEvent('sb_pacificheist:rewardItem', nil, Config.TrolleyMoneyReward, 'money')
                        Notify('Grabbed $' .. FormatNumber(Config.TrolleyMoneyReward), 'success')
                    elseif rewardType == 'gold' then
                        TriggerServerEvent('sb_pacificheist:rewardItem', Config.RewardItems[1].name, 1, 'item')
                        Notify('Grabbed gold bar!', 'success')
                    elseif rewardType == 'diamond' then
                        TriggerServerEvent('sb_pacificheist:rewardItem', Config.RewardItems[2].name, 1, 'item')
                        Notify('Grabbed diamonds!', 'success')
                    elseif rewardType == 'cocaine' then
                        TriggerServerEvent('sb_pacificheist:rewardItem', Config.RewardItems[3].name, 1, 'item')
                        Notify('Grabbed contraband!', 'success')
                    end
                end
            end
        end

        if DoesEntityExist(grabObj) then DeleteEntity(grabObj) end
    end)
end

-- ============================================================================
-- DRILL SAFE (Synchronized Scene with Sound)
-- ============================================================================

function DrillSafe(index)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'Thermal Drill'), 'error')
            return
        end

        -- Server-side claim (prevents double-grab exploit)
        SBCore.Functions.TriggerCallback('sb_pacificheist:canLoot', function(canLoot)
            if not canLoot then
                Notify('Already taken!', 'error')
                return
            end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation
        exports['sb_hud']:SetHudVisible(false) -- Hide HUD during drilling
        local drill = Config.DrillBoxes[index]
        drill.taken = true

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim_heist@hs3f@ig9_vault_drill@laser_drill@'
        LoadAnimDict(animDict)

        local bagModel = 'hei_p_m_bag_var22_arm_s'
        local drillModel = 'hei_prop_heist_drill'
        LoadModel(bagModel)
        LoadModel(drillModel)

        -- Request audio banks
        RequestAmbientAudioBank("DLC_HEIST_FLEECA_SOUNDSET", false)
        RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL", false)
        RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL_2", false)

        local soundId = GetSoundId()

        -- Setup camera
        local cam = CreateCam("DEFAULT_ANIMATED_CAMERA", true)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 3000, true, false)

        -- Create props
        local bag = CreateObject(GetHashKey(bagModel), pedCoords.x, pedCoords.y, pedCoords.z, true, false, false)
        local laserDrill = CreateObject(GetHashKey(drillModel), pedCoords.x, pedCoords.y, pedCoords.z, true, false, false)

        local vaultPos = drill.pos
        local vaultRot = drill.rotation or vector3(0.0, 0.0, 160.0)

        -- Create all animation scenes
        LaserDrill.scenes = {}
        for i = 1, #LaserDrill.animations do
            LaserDrill.scenes[i] = NetworkCreateSynchronisedScene(vaultPos, vaultRot, 2, true, false, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(ped, LaserDrill.scenes[i], animDict, LaserDrill.animations[i][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
            NetworkAddEntityToSynchronisedScene(bag, LaserDrill.scenes[i], animDict, LaserDrill.animations[i][2], 1.0, -1.0, 1148846080)
            NetworkAddEntityToSynchronisedScene(laserDrill, LaserDrill.scenes[i], animDict, LaserDrill.animations[i][3], 1.0, -1.0, 1148846080)
        end

        -- Intro
        NetworkStartSynchronisedScene(LaserDrill.scenes[1])
        PlayCamAnim(cam, 'intro_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'intro') * 1000)

        -- Start drilling
        NetworkStartSynchronisedScene(LaserDrill.scenes[2])
        PlayCamAnim(cam, 'drill_straight_start_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'drill_straight_start') * 1000)

        -- Idle loop with sound
        NetworkStartSynchronisedScene(LaserDrill.scenes[3])
        PlayCamAnim(cam, 'drill_straight_idle_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
        PlaySoundFromEntity(soundId, "Drill", laserDrill, "DLC_HEIST_FLEECA_SOUNDSET", true, 0)

        Notify('Drilling safe... Hold steady!', 'info', 15000)

        -- Drilling duration
        Wait(15000)
        StopSound(soundId)
        ReleaseSoundId(soundId)

        -- Success - end drilling
        NetworkStartSynchronisedScene(LaserDrill.scenes[5])
        PlayCamAnim(cam, 'drill_straight_end_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)

        -- Give random reward
        local randomIndex = math.random(1, #Config.RewardItems)
        TriggerServerEvent('sb_pacificheist:rewardItem', Config.RewardItems[randomIndex].name, Config.DrillRewardCount, 'item')

        Wait(GetAnimDuration(animDict, 'drill_straight_end') * 1000)

        -- Exit
        NetworkStartSynchronisedScene(LaserDrill.scenes[6])
        PlayCamAnim(cam, 'exit_cam', animDict, vaultPos.x, vaultPos.y, vaultPos.z, vaultRot.x, vaultRot.y, vaultRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'exit') * 1000)

        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        ClearPedTasks(ped)

        if DoesEntityExist(bag) then DeleteEntity(bag) end
        if DoesEntityExist(laserDrill) then DeleteEntity(laserDrill) end

        Notify('Safe cracked! Found loot!', 'success')
        exports['sb_hud']:SetHudVisible(true) -- Show HUD again
        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
        end, 'drill', index)
    end, Config.RequiredItems.drill)
end

-- ============================================================================
-- C4 PLANTING
-- ============================================================================

function PlantC4(index, gate)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'C4 Explosive'), 'error')
            return
        end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim@heists@ornate_bank@thermal_charge'
        LoadAnimDict(animDict)
        LoadModel('hei_p_m_bag_var22_arm_s')
        LoadModel('prop_bomb_01')

        -- Create bag and bomb
        local bag = CreateObject(GetHashKey('hei_p_m_bag_var22_arm_s'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bag, false, true)

        -- Create synchronized scene
        local scene = NetworkCreateSynchronisedScene(gate.pos, gate.rot, 2, false, false, 1065353216, 0, 1.3)
        NetworkAddPedToSynchronisedScene(ped, scene, animDict, Planting.animations[1][1], 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(bag, scene, animDict, Planting.animations[1][2], 4.0, -8.0, 1)

        NetworkStartSynchronisedScene(scene)
        Wait(1500)

        -- Create and attach bomb
        local bomb = CreateObject(GetHashKey('prop_bomb_01'), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        SetEntityCollision(bomb, false, true)
        AttachEntityToEntity(bomb, ped, GetPedBoneIndex(ped, 28422), 0, 0, 0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

        Notify('Planting C4...', 'info', 3000)
        Wait(3000)

        -- Remove item
        TriggerServerEvent('sb_pacificheist:removeItem', Config.RequiredItems.c4)
        gate.planted = true
        TriggerServerEvent('sb_pacificheist:c4Planted', index)

        -- Cleanup bag
        if DoesEntityExist(bag) then DeleteEntity(bag) end

        -- Detach and freeze bomb
        DetachEntity(bomb, true, true)
        FreezeEntityPosition(bomb, true)
        table.insert(C4Objects, {obj = bomb, coords = gate.pos, index = index})

        Notify('C4 planted! Move away and detonate.', 'info')

        -- Server handles allPlanted check and broadcasts allC4Planted event

        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
    end, Config.RequiredItems.c4)
end

local detonationActive = false

function SetupDetonation()
    if detonationActive then return end
    detonationActive = true

    CreateThread(function()
        while detonationActive do
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local nearGates = false

            for _, gate in ipairs(Config.CellGates) do
                if #(pedCoords - gate.pos) < 5.0 then
                    nearGates = true
                    break
                end
            end

            if not nearGates then
                DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + 1.0, '~g~[E]~w~ Detonate C4')

                if IsControlJustPressed(0, 38) then
                    -- Tell server to broadcast detonation to all clients
                    TriggerServerEvent('sb_pacificheist:detonateC4')
                    break
                end
            end

            Wait(0)
        end
        detonationActive = false
    end)
end

-- Runs the actual detonation (called on all clients via sync event)
function ExecuteDetonation()
    detonationActive = false

    local ped = PlayerPedId()
    LoadAnimDict('anim@mp_player_intmenu@key_fob@')
    TaskPlayAnim(ped, "anim@mp_player_intmenu@key_fob@", "fob_click_fp", 8.0, 8.0, -1, 48, 1, false, false, false)
    Wait(500)

    -- Protect inner vault door from cell gate explosions (freeze it in place)
    local innerDoorProtected = false
    local innerDoor = nil
    if not InnerVaultState.doorOpen then
        innerDoor = GetClosestObjectOfType(Config.InnerVaultDoor.doorPos.x, Config.InnerVaultDoor.doorPos.y, Config.InnerVaultDoor.doorPos.z, 5.0, Config.InnerVaultDoor.doorModel, false, false, false)
        if innerDoor ~= 0 and DoesEntityExist(innerDoor) then
            NetworkRequestControlOfEntity(innerDoor)
            FreezeEntityPosition(innerDoor, true)
            innerDoorProtected = true
        end
    end

    -- First pass: disable collision on all bomb props so they don't block explosions
    local bombHash = GetHashKey('prop_bomb_01')
    for _, gate in ipairs(Config.CellGates) do
        local bomb = GetClosestObjectOfType(gate.pos.x, gate.pos.y, gate.pos.z, 3.0, bombHash, false, false, false)
        if bomb ~= 0 and DoesEntityExist(bomb) then
            NetworkRequestControlOfEntity(bomb)
            SetEntityCollision(bomb, false, false)
        end
    end

    Wait(100)

    -- Second pass: stagger explosions to avoid engine throttling
    for _, gate in ipairs(Config.CellGates) do
        AddExplosion(gate.pos.x, gate.pos.y, gate.pos.z, 2, 100.0, true, false, 1.0)
        Wait(150)
    end

    Wait(500)

    -- Third pass: clean up bomb props (request control for props created by other players)
    for _, gate in ipairs(Config.CellGates) do
        local bomb = GetClosestObjectOfType(gate.pos.x, gate.pos.y, gate.pos.z, 3.0, bombHash, false, false, false)
        if bomb ~= 0 and DoesEntityExist(bomb) then
            local timeout = 0
            while not NetworkHasControlOfEntity(bomb) and timeout < 30 do
                NetworkRequestControlOfEntity(bomb)
                Wait(10)
                timeout = timeout + 1
            end
            if NetworkHasControlOfEntity(bomb) then
                DeleteEntity(bomb)
            end
        end
    end

    -- Also clean up any remaining local C4Objects
    for _, c4 in ipairs(C4Objects) do
        if DoesEntityExist(c4.obj) then DeleteEntity(c4.obj) end
    end
    C4Objects = {}

    -- Unfreeze inner vault door (keep it closed, but allow proper C4 to open it later)
    if innerDoorProtected and innerDoor and DoesEntityExist(innerDoor) then
        FreezeEntityPosition(innerDoor, false)
    end

    Notify('Boom! Gates destroyed!', 'success')
    ClearPedTasks(ped)
end

-- Sync detonation to all clients
RegisterNetEvent('sb_pacificheist:syncDetonateC4', function()
    ExecuteDetonation()
end)

function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ============================================================================
-- GLASS CUTTING (Synchronized Scene with Effects)
-- ============================================================================

function GlassCuttingSequence()
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasItem)
        if not hasItem then
            Notify(string.format(Config.Strings.needItem, 'Glass Cutter'), 'error')
            return
        end

        -- Server-side claim (prevents double-grab exploit)
        SBCore.Functions.TriggerCallback('sb_pacificheist:canLoot', function(canLoot)
            if not canLoot then
                Notify('Already taken!', 'error')
                return
            end

        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation
        Config.GlassCutting.taken = true

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local animDict = 'anim@scripted@heist@ig16_glass_cut@male@'
        LoadAnimDict(animDict)

        -- Find glass display object
        local sceneObject = GetClosestObjectOfType(Config.GlassCutting.displayPos.x, Config.GlassCutting.displayPos.y, Config.GlassCutting.displayPos.z, 1.0, GetHashKey('h4_prop_h4_glass_disp_01a'), false, false, false)
        local scenePos = GetEntityCoords(sceneObject)
        local sceneRot = GetEntityRotation(sceneObject)

        -- Find reward object
        local globalObj = GetClosestObjectOfType(Config.GlassCutting.displayPos.x, Config.GlassCutting.displayPos.y, Config.GlassCutting.displayPos.z, 5.0, GetHashKey(GlassCuttingData.globalObject), false, false, false)

        -- Request audio bank
        RequestScriptAudioBank('DLC_HEI4/DLCHEI4_GENERIC_01', false)

        -- Setup camera
        local cam = CreateCam("DEFAULT_ANIMATED_CAMERA", true)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 3000, true, false)

        -- Create props
        Overheat.sceneObjects = {}
        for k, v in pairs(Overheat.objects) do
            LoadModel(v)
            Overheat.sceneObjects[k] = CreateObject(GetHashKey(v), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        end

        -- Create cut glass replacement
        local newObj = CreateObject(GetHashKey('h4_prop_h4_glass_disp_01b'), scenePos.x, scenePos.y, scenePos.z, true, true, false)
        SetEntityHeading(newObj, GetEntityHeading(sceneObject))

        -- Create synchronized scenes
        Overheat.scenes = {}
        for i = 1, #Overheat.animations do
            Overheat.scenes[i] = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, true, false, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(ped, Overheat.scenes[i], animDict, Overheat.animations[i][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
            NetworkAddEntityToSynchronisedScene(Overheat.sceneObjects[1], Overheat.scenes[i], animDict, Overheat.animations[i][2], 1.0, -1.0, 1148846080)
            NetworkAddEntityToSynchronisedScene(Overheat.sceneObjects[2], Overheat.scenes[i], animDict, Overheat.animations[i][3], 1.0, -1.0, 1148846080)
            if i ~= 5 then
                NetworkAddEntityToSynchronisedScene(sceneObject, Overheat.scenes[i], animDict, Overheat.animations[i][4], 1.0, -1.0, 1148846080)
            else
                NetworkAddEntityToSynchronisedScene(newObj, Overheat.scenes[i], animDict, Overheat.animations[i][4], 1.0, -1.0, 1148846080)
            end
        end

        local sound1 = GetSoundId()
        local sound2 = GetSoundId()

        -- Enter animation
        NetworkStartSynchronisedScene(Overheat.scenes[1])
        PlayCamAnim(cam, 'enter_cam', animDict, scenePos.x, scenePos.y, scenePos.z, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'enter') * 1000)

        -- Idle
        NetworkStartSynchronisedScene(Overheat.scenes[2])
        PlayCamAnim(cam, 'idle_cam', animDict, scenePos.x, scenePos.y, scenePos.z, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'idle') * 1000)

        -- Cutting loop with effects
        NetworkStartSynchronisedScene(Overheat.scenes[3])
        PlaySoundFromEntity(sound1, "StartCutting", Overheat.sceneObjects[2], 'DLC_H4_anims_glass_cutter_Sounds', true, 80)
        LoadPtfxAsset('scr_ih_fin')
        UseParticleFxAssetNextCall('scr_ih_fin')
        local fire1 = StartParticleFxLoopedOnEntity('scr_ih_fin_glass_cutter_cut', Overheat.sceneObjects[2], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
        PlayCamAnim(cam, 'cutting_loop_cam', animDict, scenePos.x, scenePos.y, scenePos.z, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'cutting_loop') * 1000)
        StopSound(sound1)
        StopParticleFxLooped(fire1, false)

        -- Overheat reaction
        NetworkStartSynchronisedScene(Overheat.scenes[4])
        PlaySoundFromEntity(sound2, "Overheated", Overheat.sceneObjects[2], 'DLC_H4_anims_glass_cutter_Sounds', true, 80)
        UseParticleFxAssetNextCall('scr_ih_fin')
        local fire2 = StartParticleFxLoopedOnEntity('scr_ih_fin_glass_cutter_overheat', Overheat.sceneObjects[2], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
        PlayCamAnim(cam, 'overheat_react_01_cam', animDict, scenePos.x, scenePos.y, scenePos.z, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(GetAnimDuration(animDict, 'overheat_react_01') * 1000)
        StopSound(sound2)
        StopParticleFxLooped(fire2, false)

        -- Success - delete old glass
        if DoesEntityExist(sceneObject) then DeleteEntity(sceneObject) end

        NetworkStartSynchronisedScene(Overheat.scenes[5])
        Wait(2000)

        -- Delete reward object and give item
        if DoesEntityExist(globalObj) then DeleteEntity(globalObj) end
        TriggerServerEvent('sb_pacificheist:rewardItem', GlassCuttingData.globalItem, 1, 'item')

        PlayCamAnim(cam, 'success_cam', animDict, scenePos.x, scenePos.y, scenePos.z, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait((GetAnimDuration(animDict, 'success') * 1000) - 2000)

        -- Cleanup - clear tasks first
        ClearPedTasks(ped)
        Wait(100)

        -- Detach and delete all scene objects
        for k, v in pairs(Overheat.sceneObjects) do
            if DoesEntityExist(v) then
                DetachEntity(v, true, true)
                SetEntityAsNoLongerNeeded(v)
                DeleteEntity(v)
            end
        end
        Overheat.sceneObjects = {}

        -- Extra cleanup - find and delete any leftover props near player
        local playerCoords = GetEntityCoords(ped)
        local propsToClean = {'hei_p_m_bag_var22_arm_s', 'h4_prop_h4_cutter_01a'}

        for _, propModel in ipairs(propsToClean) do
            local prop = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 3.0, GetHashKey(propModel), false, false, false)
            if prop and DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                SetEntityAsNoLongerNeeded(prop)
                DeleteEntity(prop)
            end
        end

        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)

        Notify('Got the display item!', 'success')
        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
        end, 'glass', 0)
    end, Config.RequiredItems.cutter)
end

-- ============================================================================
-- PAINTING THEFT (Synchronized Scene with Cutting Steps)
-- ============================================================================

function StealPainting(index)
    SBCore.Functions.TriggerCallback('sb_pacificheist:hasItem', function(hasSwitchblade)
        if not hasSwitchblade then
            Notify(string.format(Config.Strings.needItem, 'Switchblade'), 'error')
            return
        end

        -- Server-side claim (prevents double-grab exploit)
        SBCore.Functions.TriggerCallback('sb_pacificheist:canLoot', function(canLoot)
            if not canLoot then
                Notify('Already taken!', 'error')
                return
            end

        local ped = PlayerPedId()
        HeistState.busy = true
        HideHeistBag() -- Hide immediately for animation
        local painting = Config.Paintings[index]
        painting.taken = true

        local pedCoords = GetEntityCoords(ped)
        local animDict = "anim_heist@hs3f@ig11_steal_painting@male@"
        LoadAnimDict(animDict)

        -- Find painting object
        local sceneObject = GetClosestObjectOfType(painting.objectPos.x, painting.objectPos.y, painting.objectPos.z, 1.0, GetHashKey(painting.model), false, false, false)
        local scenePos = painting.scenePos
        local sceneRot = painting.sceneRot

        -- Create props
        ArtHeist.sceneObjects = {}
        for k, v in pairs(ArtHeist.objects) do
            LoadModel(v)
            ArtHeist.sceneObjects[k] = CreateObject(GetHashKey(v), pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
        end

        -- Create synchronized scenes
        ArtHeist.scenes = {}
        for i = 1, 10 do
            ArtHeist.scenes[i] = NetworkCreateSynchronisedScene(scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot, 2, true, false, 1065353216, 0, 1065353216)
            NetworkAddPedToSynchronisedScene(ped, ArtHeist.scenes[i], animDict, 'ver_01_' .. ArtHeist.animations[i][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
            NetworkAddEntityToSynchronisedScene(sceneObject, ArtHeist.scenes[i], animDict, 'ver_01_' .. ArtHeist.animations[i][3], 1.0, -1.0, 1148846080)
            NetworkAddEntityToSynchronisedScene(ArtHeist.sceneObjects[1], ArtHeist.scenes[i], animDict, 'ver_01_' .. ArtHeist.animations[i][4], 1.0, -1.0, 1148846080)
            NetworkAddEntityToSynchronisedScene(ArtHeist.sceneObjects[2], ArtHeist.scenes[i], animDict, 'ver_01_' .. ArtHeist.animations[i][5], 1.0, -1.0, 1148846080)
        end

        -- Setup camera
        local cam = CreateCam("DEFAULT_ANIMATED_CAMERA", true)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 3000, true, false)

        local scenes = {false, false, false, false}

        -- Top left enter
        NetworkStartSynchronisedScene(ArtHeist.scenes[1])
        PlayCamAnim(cam, 'ver_01_top_left_enter_cam_ble', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(3000)

        -- Top left idle - wait for E press
        NetworkStartSynchronisedScene(ArtHeist.scenes[2])
        PlayCamAnim(cam, 'ver_01_cutting_top_left_idle_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        while not scenes[1] do
            ShowHelpNotification('Press ~INPUT_CONTEXT~ to cut right')
            if IsControlJustPressed(0, 38) then scenes[1] = true end
            Wait(1)
        end

        -- Cut to right
        NetworkStartSynchronisedScene(ArtHeist.scenes[3])
        PlayCamAnim(cam, 'ver_01_cutting_top_left_to_right_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(3000)

        -- Top right idle
        NetworkStartSynchronisedScene(ArtHeist.scenes[4])
        PlayCamAnim(cam, 'ver_01_cutting_top_right_idle_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        while not scenes[2] do
            ShowHelpNotification('Press ~INPUT_CONTEXT~ to cut down')
            if IsControlJustPressed(0, 38) then scenes[2] = true end
            Wait(1)
        end

        -- Cut down right side
        NetworkStartSynchronisedScene(ArtHeist.scenes[5])
        PlayCamAnim(cam, 'ver_01_cutting_right_top_to_bottom_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(3000)

        -- Bottom right idle
        NetworkStartSynchronisedScene(ArtHeist.scenes[6])
        PlayCamAnim(cam, 'ver_01_cutting_bottom_right_idle_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        while not scenes[3] do
            ShowHelpNotification('Press ~INPUT_CONTEXT~ to cut left')
            if IsControlJustPressed(0, 38) then scenes[3] = true end
            Wait(1)
        end

        -- Cut to left
        NetworkStartSynchronisedScene(ArtHeist.scenes[7])
        PlayCamAnim(cam, 'ver_01_cutting_bottom_right_to_left_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(3000)

        -- Final cut
        while not scenes[4] do
            ShowHelpNotification('Press ~INPUT_CONTEXT~ to finish cutting')
            if IsControlJustPressed(0, 38) then scenes[4] = true end
            Wait(1)
        end

        -- Cut up left side
        NetworkStartSynchronisedScene(ArtHeist.scenes[9])
        PlayCamAnim(cam, 'ver_01_cutting_left_top_to_bottom_cam', animDict, scenePos.x, scenePos.y, scenePos.z - 1.0, sceneRot.x, sceneRot.y, sceneRot.z, false, 2)
        Wait(1500)

        -- Exit with painting
        NetworkStartSynchronisedScene(ArtHeist.scenes[10])
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        Wait(7500)

        -- Give reward
        TriggerServerEvent('sb_pacificheist:rewardItem', Config.PaintingRewards[1].item, 1, 'item')

        -- Cleanup - clear tasks first to stop synced scene
        ClearPedTasks(ped)
        Wait(100) -- Wait a frame for scene to fully stop

        -- Detach and delete all scene objects
        for k, v in pairs(ArtHeist.sceneObjects) do
            if DoesEntityExist(v) then
                -- Detach if attached to anything
                DetachEntity(v, true, true)
                SetEntityAsNoLongerNeeded(v)
                DeleteEntity(v)
            end
        end
        ArtHeist.sceneObjects = {}
        ArtHeist.scenes = {}

        -- Delete the painting prop
        if DoesEntityExist(sceneObject) then
            DetachEntity(sceneObject, true, true)
            SetEntityAsNoLongerNeeded(sceneObject)
            DeleteEntity(sceneObject)
        end

        -- Extra cleanup - find and delete any leftover props near player
        local playerCoords = GetEntityCoords(ped)
        local propsToClean = {'hei_p_m_bag_var22_arm_s', 'w_me_switchblade'}

        for _, propModel in ipairs(propsToClean) do
            local prop = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 3.0, GetHashKey(propModel), false, false, false)
            if prop and DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                SetEntityAsNoLongerNeeded(prop)
                DeleteEntity(prop)
            end
        end

        Wait(100)
        RemoveAnimDict(animDict)

        Notify('Got the painting!', 'success')
        ShowHeistBag() -- Show bag again after animation
        HeistState.busy = false
        end, 'painting', index)
    end, Config.RequiredItems.switchblade)
end

function ShowHelpNotification(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, false, true, -1)
end

-- ============================================================================
-- ESCAPE / BUYER
-- ============================================================================

function TriggerEscape()
    HeistState.robber = false
    HeistState.inVault = false
    HeistState.inExtendedVault = false

    Notify(Config.Strings.deliverToBuyer, 'primary', 10000)

    local blip = AddBlipForCoord(Config.BuyerLocation.pos)
    SetBlipSprite(blip, Config.BuyerLocation.blip.sprite)
    SetBlipColour(blip, Config.BuyerLocation.blip.color)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, Config.BuyerLocation.blip.color)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.BuyerLocation.blip.label)
    EndTextCommandSetBlipName(blip)

    LoadModel(Config.BuyerLocation.vehicleModel)
    local vehicle = CreateVehicle(GetHashKey(Config.BuyerLocation.vehicleModel), Config.BuyerLocation.pos.x + 3.0, Config.BuyerLocation.pos.y, Config.BuyerLocation.pos.z, 269.4, false, false)

    CreateThread(function()
        while true do
            local pedCoords = GetEntityCoords(PlayerPedId())
            local dist = #(pedCoords - Config.BuyerLocation.pos)

            if dist <= 15.0 then
                RemoveBlip(blip)
                if DoesEntityExist(vehicle) then DeleteVehicle(vehicle) end

                DoScreenFadeOut(1000)
                Wait(2000)

                TriggerServerEvent('sb_pacificheist:sellLoot')

                Wait(1000)
                DoScreenFadeIn(1000)

                ResetHeistState()
                break
            end

            Wait(500)
        end
    end)
end

-- ============================================================================
-- POLICE ALERT
-- ============================================================================

RegisterNetEvent('sb_pacificheist:policeAlert', function(coords)
    local playerJob = SBCore.Functions.GetPlayerData().job
    if playerJob and playerJob.name == 'police' and playerJob.onduty then
        Notify(Config.Strings.policeAlert, 'error', 10000)

        local blip = AddBlipForRadius(coords.x, coords.y, coords.z, 100.0)
        SetBlipHighDetail(blip, true)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 200)

        CreateThread(function()
            local alpha = 200
            while alpha > 0 do
                Wait(500)
                alpha = alpha - 2
                SetBlipAlpha(blip, alpha)
            end
            RemoveBlip(blip)
        end)
    end
end)

-- ============================================================================
-- MONEY RECEIVED
-- ============================================================================

RegisterNetEvent('sb_pacificheist:moneyReceived', function(amount)
    Notify(string.format(Config.Strings.totalMoney, FormatNumber(amount)), 'success', 8000)
end)

-- ============================================================================
-- SYNC EVENTS
-- ============================================================================

RegisterNetEvent('sb_pacificheist:syncGlassReward', function(item, index)
    GlassCuttingData.globalItem = item
    GlassCuttingData.globalObject = Config.GlassCuttingRewards[index].model
end)

-- Sync thermite flames for other players
local SyncedThermitePtfx = {}

RegisterNetEvent('sb_pacificheist:syncThermiteFlames', function(doorIndex, active, planterId)
    -- Skip if we are the one who planted (we already have our own ptfx)
    if planterId == GetPlayerServerId(PlayerId()) then return end

    local door = Config.FreezeDoors[doorIndex]
    if not door or not door.scene or not door.scene.ptfx then return end

    if active then
        LoadPtfxAsset('scr_ornate_heist')
        UseParticleFxAssetNextCall('scr_ornate_heist')
        local ptfx = StartParticleFxLoopedAtCoord("scr_heist_ornate_thermal_burn", door.scene.ptfx.x, door.scene.ptfx.y, door.scene.ptfx.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
        SyncedThermitePtfx[doorIndex] = ptfx
    else
        if SyncedThermitePtfx[doorIndex] then
            StopParticleFxLooped(SyncedThermitePtfx[doorIndex], 0)
            SyncedThermitePtfx[doorIndex] = nil
        end
    end
end)

-- Sync door unlock with model swap for all players
RegisterNetEvent('sb_pacificheist:syncDoorUnlock', function(index)
    local door = Config.FreezeDoors[index]
    if not door then return end

    -- Skip if already unlocked on this client
    if door.locked == false then return end

    door.locked = false

    -- Perform model swap so all players see the melted/destroyed door
    if door.swapFrom and door.swapTo then
        CreateModelSwap(door.pos.x, door.pos.y, door.pos.z, 5.0, GetHashKey(door.swapFrom), GetHashKey(door.swapTo), true)
    end
end)

-- Sync vault opened (main or extended) for all players
RegisterNetEvent('sb_pacificheist:syncVaultOpened', function(vaultType)
    if vaultType == 'main' then
        -- Skip if already done on this client (the player who hacked)
        if VaultCheck.laptop then return end

        VaultCheck.laptop = true
        SetupMainVault()  -- This sets HeistState.inVault = true
        -- Small delay to let the hacker's client open the door first via OneSync
        Wait(1500)
        OpenVaultDoor('main')
    elseif vaultType == 'extended' then
        -- Skip if already done on this client (the player who drilled)
        if VaultCheck.drill then return end

        VaultCheck.drill = true
        SetupExtendedVault()  -- This sets HeistState.inExtendedVault = true
        -- Small delay to let the driller's client open the door first via OneSync
        Wait(1500)
        OpenVaultDoor('extended')
    end
end)

-- Helper: request network control then delete an object by model near a position
local function SyncDeleteObject(pos, modelHash, radius)
    if type(modelHash) == 'string' then modelHash = GetHashKey(modelHash) end
    local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, radius or 3.0, modelHash, false, false, false)
    if obj ~= 0 and DoesEntityExist(obj) then
        local timeout = 0
        while not NetworkHasControlOfEntity(obj) and timeout < 30 do
            NetworkRequestControlOfEntity(obj)
            Wait(10)
            timeout = timeout + 1
        end
        DeleteEntity(obj)
    end
end

RegisterNetEvent('sb_pacificheist:syncLootTaken', function(lootType, index)
    if lootType == 'mainStack' then
        Config.MainStack.taken = true
        SyncDeleteObject(Config.MainStack.pos, Config.MainStack.model)
    elseif lootType == 'stack' then
        Config.Stacks[index].taken = true
        SyncDeleteObject(Config.Stacks[index].pos, Config.Stacks[index].model)
    elseif lootType == 'trolley' then
        Config.Trolleys[index].taken = true
        SyncDeleteObject(Config.Trolleys[index].pos, Config.Trolleys[index].model)
    elseif lootType == 'drill' then
        Config.DrillBoxes[index].taken = true
    elseif lootType == 'drill_reset' then
        Config.DrillBoxes[index].taken = false
    elseif lootType == 'glass' then
        Config.GlassCutting.taken = true
    elseif lootType == 'painting' then
        Config.Paintings[index].taken = true
        if Config.Paintings[index] then
            SyncDeleteObject(Config.Paintings[index].objectPos, Config.Paintings[index].model)
        end
    elseif lootType == 'c4' then
        Config.CellGates[index].planted = true
        -- Server handles allPlanted check and broadcasts allC4Planted event
    end
end)

-- Inner vault door sync - laptop hack completed
RegisterNetEvent('sb_pacificheist:syncInnerVaultLaptop', function()
    -- Skip if already done on this client
    if InnerVaultState.laptopHacked then return end
    InnerVaultState.laptopHacked = true
end)

-- Inner vault door sync - door opened with C4
RegisterNetEvent('sb_pacificheist:syncInnerVaultDoor', function()
    -- Skip if already done on this client
    if InnerVaultState.doorOpen then return end

    InnerVaultState.doorOpen = true

    -- Open the inner vault door for all players
    local doorModel = Config.InnerVaultDoor.doorModel
    local doorPos = Config.InnerVaultDoor.doorPos
    local door = GetClosestObjectOfType(doorPos.x, doorPos.y, doorPos.z, 5.0, doorModel, false, false, false)

    if door ~= 0 then
        -- Animate door opening
        CreateThread(function()
            local timeout = 0
            while not NetworkHasControlOfEntity(door) and timeout < 50 do
                NetworkRequestControlOfEntity(door)
                Wait(10)
                timeout = timeout + 1
            end

            -- Unfreeze so we can animate it
            FreezeEntityPosition(door, false)

            -- Use stored closed heading for reliable target (fallback to current if not captured)
            local startHeading = InnerDoorOriginal.heading or GetEntityHeading(door)
            local targetHeading = startHeading + 90.0
            SetEntityHeading(door, startHeading) -- ensure we start from closed position
            local currentHeading = startHeading
            while currentHeading < targetHeading do
                currentHeading = currentHeading + 0.5
                SetEntityHeading(door, currentHeading)
                Wait(10)
            end
        end)
    end
end)

-- Server-authoritative: all C4 planted, enable detonation for ALL players
RegisterNetEvent('sb_pacificheist:allC4Planted', function()
    SetupDetonation()
end)

-- Server tells this client they are the primary robber (first to steal painting/glass)
RegisterNetEvent('sb_pacificheist:setAsRobber', function()
    HeistState.robber = true
end)

-- ============================================================================
-- HEIST RESET
-- ============================================================================

function ResetHeistState()
    HeistState.started = false
    HeistState.inVault = false
    HeistState.inExtendedVault = false
    HeistState.robber = false
    HeistState.busy = false

    VaultCheck.laptop = false
    VaultCheck.drill = false

    -- Reset inner vault door state
    InnerVaultState.laptopHacked = false
    InnerVaultState.c4Planted = false
    InnerVaultState.doorOpen = false

    detonationActive = false

    for _, door in ipairs(Config.FreezeDoors) do
        door.locked = true
    end

    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_main_entrance')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_gate_2')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_vault_gate_1')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_vault_gate_2')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_main_vault')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_extended_vault')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_safe_door')
    TriggerServerEvent('sb_doorlock:resetBypass', 'pacific_inner_gate')

    Config.MainStack.taken = false
    Config.GlassCutting.taken = false

    for _, stack in ipairs(Config.Stacks) do
        stack.taken = false
    end

    for _, trolley in ipairs(Config.Trolleys) do
        trolley.taken = false
    end

    for _, drill in ipairs(Config.DrillBoxes) do
        drill.taken = false
    end

    for _, gate in ipairs(Config.CellGates) do
        gate.planted = false
    end

    for _, painting in ipairs(Config.Paintings) do
        painting.taken = false
    end

    -- Physically close vault doors so they don't stay open from previous heist
    CloseVaultDoor('main')
    CloseVaultDoor('extended')

    -- Close inner vault door: force it back to closed heading and freeze
    local innerDoorModel = Config.InnerVaultDoor.doorModel
    local innerDoorPos = Config.InnerVaultDoor.doorPos
    local innerDoor = GetClosestObjectOfType(innerDoorPos.x, innerDoorPos.y, innerDoorPos.z, 5.0, innerDoorModel, false, false, false)
    if innerDoor ~= 0 and InnerDoorOriginal.heading then
        local timeout = 0
        while not NetworkHasControlOfEntity(innerDoor) and timeout < 50 do
            NetworkRequestControlOfEntity(innerDoor)
            Wait(10)
            timeout = timeout + 1
        end
        -- Reset position and heading to original closed state
        if InnerDoorOriginal.pos then
            SetEntityCoordsNoOffset(innerDoor, InnerDoorOriginal.pos.x, InnerDoorOriginal.pos.y, InnerDoorOriginal.pos.z, false, false, false)
        end
        SetEntityHeading(innerDoor, InnerDoorOriginal.heading)
        FreezeEntityPosition(innerDoor, true)
    end

    for _, obj in ipairs(CreatedObjects) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    CreatedObjects = {}
end

RegisterNetEvent('sb_pacificheist:resetHeist', function()
    -- Stop any synced thermite effects
    for doorIndex, ptfx in pairs(SyncedThermitePtfx) do
        StopParticleFxLooped(ptfx, 0)
    end
    SyncedThermitePtfx = {}

    ResetHeistState()
    Notify(Config.Strings.heistReset, 'info')
end)

-- ============================================================================
-- CLEANUP ON RESOURCE STOP
-- ============================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, ped in ipairs(CreatedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end

    for _, obj in ipairs(CreatedObjects) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
end)
