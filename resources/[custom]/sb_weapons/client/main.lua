--[[
    Everyday Chaos RP - Weapons Client (V2 Magazine System)
    Author: Salah Eddine Boussettah

    Handles: weapon equip/holster, magazine reload, ammo HUD, weapon wheel disable, death auto-holster.
]]

local SBCore = exports['sb_core']:GetCoreObject()

-- State
local equippedWeapon = nil    -- weapon item name (e.g. 'weapon_pistol')
local equippedSlot = nil      -- inventory slot of equipped weapon
local equippedHash = nil      -- weapon hash for native calls
local isEquipping = false     -- prevent spam during animations
local ammoSyncActive = false  -- whether ammo sync thread is running

-- Magazine state
local currentAmmo = 0         -- total rounds remaining (our tracker, can exceed native clip)
local currentMagCapacity = 0  -- capacity of last loaded magazine
local currentMagLabel = ''    -- label for HUD display
local currentMagName = nil    -- item name of mag currently in weapon (nil = no mag loaded)
local hasExtendedClip = false -- whether extended clip component is active (visual only)
local magEmptyTriggered = false -- prevent double-triggering magEmpty event
local lastNativeClip = 0     -- native clip ammo last tick (for shot detection)
local lastRKeyPress = 0      -- R key cooldown timestamp (prevent spam)

-- ============================================================================
-- EQUIP / HOLSTER
-- ============================================================================

--- Equip a weapon from inventory
---@param weaponName string
---@param slot number
---@param metadata table
function EquipWeapon(weaponName, slot, metadata)
    if isEquipping then return end

    local weaponConfig = Config.Weapons[weaponName]
    if not weaponConfig then
        -- Not in sb_weapons config — let CreateUseableItem handlers in other scripts handle it
        return
    end

    -- If same weapon already equipped, holster it
    if equippedWeapon == weaponName and equippedSlot == slot then
        HolsterWeapon()
        return
    end

    -- If different weapon equipped, holster first
    if equippedWeapon then
        HolsterWeapon(true) -- silent holster
    end

    isEquipping = true

    local ped = PlayerPedId()

    -- Draw animation
    local animDict = 'reaction@intimidation@1h'
    local animClip = 'intro'
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 3000 do
        Wait(10)
        timeout = timeout + 10
    end

    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, weaponConfig.drawTime, 48, 0, false, false, false)
        Wait(weaponConfig.drawTime)
        ClearPedTasks(ped)
    end

    if weaponConfig.noMagazine then
        -- Simple weapon: give with native ammo (melee, taser, or temp firearms)
        local ammo = weaponConfig.nativeAmmo or 0
        GiveWeaponToPed(ped, weaponConfig.hash, ammo, false, true)
        SetCurrentPedWeapon(ped, weaponConfig.hash)

        -- Store state
        equippedWeapon = weaponName
        equippedSlot = slot
        equippedHash = weaponConfig.hash
        currentAmmo = ammo
        currentMagCapacity = ammo
        currentMagLabel = ''
        currentMagName = nil
        hasExtendedClip = false
        magEmptyTriggered = false
        lastNativeClip = ammo

        isEquipping = false

        -- Start ammo sync for ranged weapons (taser, shotgun, etc.)
        if ammo > 0 then
            SetWeaponsNoAutoreload(true)
            if not ammoSyncActive then
                ammoSyncActive = true
                CreateThread(AmmoSyncLoop)
            end
            UpdateAmmoHUD()
        else
            HideAmmoHUD()
        end

        exports['sb_notify']:Notify(weaponConfig.label .. ' equipped', 'success', 2000)
    else
        -- Magazine-based weapon: give with 0 ammo (must reload with magazine)
        GiveWeaponToPed(ped, weaponConfig.hash, 0, false, true)
        SetCurrentPedWeapon(ped, weaponConfig.hash)
        SetPedAmmo(ped, weaponConfig.hash, 0)
        SetAmmoInClip(ped, weaponConfig.hash, 0)

        -- Disable auto-reload
        SetWeaponsNoAutoreload(true)

        -- Store state
        equippedWeapon = weaponName
        equippedSlot = slot
        equippedHash = weaponConfig.hash
        currentAmmo = 0
        currentMagCapacity = 0
        currentMagLabel = ''
        currentMagName = nil
        hasExtendedClip = false
        magEmptyTriggered = false
        lastNativeClip = 0

        isEquipping = false

        -- Start ammo sync
        if not ammoSyncActive then
            ammoSyncActive = true
            CreateThread(AmmoSyncLoop)
        end

        -- HUD stays hidden until player loads a magazine
        HideAmmoHUD()

        exports['sb_notify']:Notify('Weapon equipped - load a magazine', 'success', 2000)
    end
end

--- Holster the currently equipped weapon
---@param silent boolean|nil
function HolsterWeapon(silent)
    if not equippedWeapon then return end
    if isEquipping then return end

    isEquipping = true

    local ped = PlayerPedId()
    local weaponConfig = Config.Weapons[equippedWeapon]

    -- Remove extended clip component if active
    if hasExtendedClip and weaponConfig then
        local compHash = GetHashKey(weaponConfig.extendedClipComponent)
        RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
        hasExtendedClip = false
    end

    -- Holster animation (only if alive)
    if not IsEntityDead(ped) and weaponConfig then
        local animDict = 'reaction@intimidation@1h'
        local animClip = 'outro'
        RequestAnimDict(animDict)
        local timeout = 0
        while not HasAnimDictLoaded(animDict) and timeout < 3000 do
            Wait(10)
            timeout = timeout + 10
        end

        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, weaponConfig.holsterTime, 48, 0, false, false, false)
            Wait(weaponConfig.holsterTime)
            ClearPedTasks(ped)
        end
    end

    -- Return magazine to inventory if one was loaded
    if currentMagName then
        if currentAmmo > 0 then
            -- Holstering with rounds remaining: return loaded mag
            TriggerServerEvent('sb_weapons:server:magEject', currentMagName, currentAmmo)
        else
            -- Mag is empty: return empty mag
            TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
        end
    end

    -- Remove weapon from ped
    RemoveWeaponFromPed(ped, equippedHash)

    -- Clear state
    equippedWeapon = nil
    equippedSlot = nil
    equippedHash = nil
    currentAmmo = 0
    currentMagCapacity = 0
    currentMagLabel = ''
    currentMagName = nil
    ammoSyncActive = false
    magEmptyTriggered = false
    lastNativeClip = 0

    isEquipping = false

    -- Hide HUD
    HideAmmoHUD()

    if not silent then
        exports['sb_notify']:Notify('Weapon holstered', 'info', 2000)
    end
end

-- ============================================================================
-- MAGAZINE RELOAD
-- ============================================================================

--- Reload weapon with a loaded magazine
---@param magName string
---@param slot number
---@param metadata table
function ReloadWithMagazine(magName, slot, metadata)
    if isEquipping then return end
    if not equippedWeapon then
        exports['sb_notify']:Notify('Equip a weapon first', 'warning', 2000)
        return
    end

    local magConfig = Config.Magazines[magName]
    if not magConfig then return end

    local weaponConfig = Config.Weapons[equippedWeapon]
    if not weaponConfig then return end

    -- noMagazine weapons don't accept magazines
    if weaponConfig.noMagazine then
        exports['sb_notify']:Notify('This weapon doesn\'t use magazines', 'warning', 2000)
        return
    end

    -- Check compatibility
    local compatible = false
    for _, compatMag in ipairs(weaponConfig.compatibleMags or {}) do
        if compatMag == magName then
            compatible = true
            break
        end
    end
    if not compatible then
        exports['sb_notify']:Notify('Incompatible magazine', 'error', 2000)
        return
    end

    -- Check if magazine is loaded
    local loaded = metadata and metadata.loaded or 0
    if loaded <= 0 then
        exports['sb_notify']:Notify('Load this magazine first', 'warning', 2000)
        return
    end

    isEquipping = true

    local ped = PlayerPedId()
    local isSwapping = currentMagName ~= nil

    -- Eject current magazine if one is already in the weapon
    if currentMagName then
        -- Remove extended clip component before ejecting
        if hasExtendedClip then
            local compHash = GetHashKey(weaponConfig.extendedClipComponent)
            RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
            hasExtendedClip = false
        end

        -- Return old mag to inventory
        if currentAmmo > 0 then
            TriggerServerEvent('sb_weapons:server:magEject', currentMagName, currentAmmo)
        else
            TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
        end
        currentMagName = nil
        currentMagCapacity = 0
        currentMagLabel = ''
        currentAmmo = 0
        magEmptyTriggered = false
    end

    -- Clear ammo and trigger one reload animation
    SetPedAmmo(ped, equippedHash, 0)
    SetAmmoInClip(ped, equippedHash, 0)
    Wait(0)
    SetPedAmmo(ped, equippedHash, 1)
    SetAmmoInClip(ped, equippedHash, 0)
    MakePedReload(ped)
    Wait(magConfig.reloadTime)

    -- Tell server to consume the loaded mag
    SBCore.Functions.TriggerCallback('sb_weapons:server:reloadMag', function(success, roundsLoaded)
        if not success then
            isEquipping = false
            return
        end

        -- Safety: weapon may have been holstered/removed during animation
        if not equippedWeapon or not equippedHash then
            isEquipping = false
            return
        end

        local actualRounds = roundsLoaded or loaded

        -- Extended clip component (visual only - ammo managed in script)
        if actualRounds > weaponConfig.nativeClipSize then
            if not hasExtendedClip then
                local compHash = GetHashKey(weaponConfig.extendedClipComponent)
                GiveWeaponComponentToPed(ped, equippedHash, compHash)
                hasExtendedClip = true
            end
        else
            if hasExtendedClip then
                local compHash = GetHashKey(weaponConfig.extendedClipComponent)
                RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
                hasExtendedClip = false
            end
        end

        -- Set native clip to min of rounds and native clip size
        -- Overflow is managed by our script (auto-refills native clip when empty)
        local nativeClip = math.min(actualRounds, weaponConfig.nativeClipSize)
        SetPedAmmo(ped, equippedHash, nativeClip)
        SetAmmoInClip(ped, equippedHash, nativeClip)

        -- Our tracker holds the FULL round count (can exceed native clip)
        currentAmmo = actualRounds
        lastNativeClip = nativeClip
        currentMagCapacity = magConfig.capacity
        currentMagLabel = magConfig.label
        currentMagName = magName
        magEmptyTriggered = false

        -- Update HUD
        UpdateAmmoHUD()

        isEquipping = false
        exports['sb_notify']:Notify('Reloaded', 'success', 1500)
    end, magName, slot)
end

-- ============================================================================
-- AMMO SYNC (detect shots, update HUD, prevent auto-unequip)
-- ============================================================================

function AmmoSyncLoop()
    while ammoSyncActive do
        Wait(0) -- Every tick for instant feedback

        if not ammoSyncActive or not equippedWeapon or not equippedHash then
            break
        end

        -- Disable R key (INPUT_RELOAD = 45) + melee controls to prevent pistol whip
        DisableControlAction(0, 45, true)   -- INPUT_RELOAD
        DisableControlAction(0, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT
        DisableControlAction(0, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY
        DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE

        -- R key: auto-find compatible loaded magazine and reload
        local now = GetGameTimer()
        if IsDisabledControlJustPressed(0, 45) and (now - lastRKeyPress) > 2000 and not isEquipping then
            local weaponConfig = Config.Weapons[equippedWeapon]
            if weaponConfig and not weaponConfig.noMagazine then
                lastRKeyPress = now
                SBCore.Functions.TriggerCallback('sb_weapons:server:findCompatibleMag', function(found, magName, magSlot, metadata)
                    if found and magName and magSlot then
                        ReloadWithMagazine(magName, magSlot, metadata)
                    else
                        exports['sb_notify']:Notify('No loaded magazine available', 'warning', 2000)
                    end
                end, equippedWeapon)
            end
        end

        local ped = PlayerPedId()

        -- Auto-holster on death
        if IsEntityDead(ped) then
            if hasExtendedClip then
                local weaponConfig = Config.Weapons[equippedWeapon]
                if weaponConfig then
                    local compHash = GetHashKey(weaponConfig.extendedClipComponent)
                    RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
                end
            end

            -- Return empty mag on death (rounds are lost)
            if currentMagName then
                TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
            end

            local hash = equippedHash
            equippedWeapon = nil
            equippedSlot = nil
            equippedHash = nil
            currentAmmo = 0
            currentMagCapacity = 0
            currentMagLabel = ''
            currentMagName = nil
            ammoSyncActive = false
            isEquipping = false
            hasExtendedClip = false
            magEmptyTriggered = false
            lastNativeClip = 0
            RemoveWeaponFromPed(ped, hash)
            HideAmmoHUD()
            break
        end

        -- Force weapon to stay selected (GTA auto-switches at 0 ammo)
        SetCurrentPedWeapon(ped, equippedHash)

        local weaponConfig = Config.Weapons[equippedWeapon]
        local nativeClipSize = weaponConfig and weaponConfig.nativeClipSize or 12

        -- Get current native clip ammo
        local success, nativeClip = GetAmmoInClip(ped, equippedHash)
        if success then
            -- Detect shots fired (native clip decreased from last tick)
            if nativeClip < lastNativeClip then
                local shotsFired = lastNativeClip - nativeClip
                currentAmmo = math.max(0, currentAmmo - shotsFired)
                lastNativeClip = nativeClip
                UpdateAmmoHUD()
            end

            -- Native clip empty but we have more rounds: refill from our pool
            if nativeClip <= 0 and currentAmmo > 0 then
                local refill = math.min(currentAmmo, nativeClipSize)
                SetPedAmmo(ped, equippedHash, refill)
                SetAmmoInClip(ped, equippedHash, refill)
                lastNativeClip = refill
            end

            -- Keep total ammo = native clip (prevent GTA from using reserve)
            if nativeClip > 0 then
                local totalAmmo = GetAmmoInPedWeapon(ped, equippedHash)
                if totalAmmo ~= nativeClip then
                    SetPedAmmo(ped, equippedHash, nativeClip)
                end
            end

            -- Mag fully depleted: return empty mag to inventory
            if currentAmmo <= 0 and currentMagName and not magEmptyTriggered then
                magEmptyTriggered = true
                TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
                currentMagName = nil
                currentMagCapacity = 0
                currentMagLabel = ''
                exports['sb_notify']:Notify('Magazine empty', 'warning', 1500)
            end
        end
    end
end

-- ============================================================================
-- AMMO HUD (NUI)
-- ============================================================================

function UpdateAmmoHUD()
    if currentMagCapacity <= 0 then return end -- No mag loaded yet, don't show
    exports['sb_hud']:UpdateAmmo(currentAmmo, currentMagCapacity, currentMagLabel)
end

function HideAmmoHUD()
    exports['sb_hud']:HideAmmo()
end

-- ============================================================================
-- NOTE: R key (INPUT_RELOAD = 45) triggers auto-reload inside AmmoSyncLoop
-- Melee controls (140, 141, 142) also disabled to prevent pistol whip
-- ============================================================================

-- ============================================================================
-- INVENTORY USE EVENT
-- ============================================================================

--- Listen for item use from inventory/hotbar
RegisterNetEvent('sb_inventory:client:useItem', function(itemName, slot, metadata, category, shouldClose)
    if category == 'weapon' then
        EquipWeapon(itemName, slot, metadata)
    elseif category == 'magazine' then
        -- Using a loaded magazine while weapon equipped = reload
        ReloadWithMagazine(itemName, slot, metadata)
    end
end)

-- ============================================================================
-- INVENTORY SLOT MONITORING (auto-holster if weapon removed from inv)
-- ============================================================================

RegisterNetEvent('sb_inventory:client:updateSlot', function(slot, itemData)
    if not equippedWeapon then return end
    if slot ~= equippedSlot then return end

    -- If the slot is now empty or contains a different item, holster
    if not itemData or itemData.name ~= equippedWeapon then
        local ped = PlayerPedId()
        if hasExtendedClip then
            local weaponConfig = Config.Weapons[equippedWeapon]
            if weaponConfig then
                local compHash = GetHashKey(weaponConfig.extendedClipComponent)
                RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
            end
        end

        -- Return magazine if one was loaded
        if currentMagName then
            if currentAmmo > 0 then
                TriggerServerEvent('sb_weapons:server:magEject', currentMagName, currentAmmo)
            else
                TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
            end
        end

        RemoveWeaponFromPed(ped, equippedHash)
        equippedWeapon = nil
        equippedSlot = nil
        equippedHash = nil
        currentAmmo = 0
        currentMagCapacity = 0
        currentMagLabel = ''
        currentMagName = nil
        ammoSyncActive = false
        isEquipping = false
        hasExtendedClip = false
        magEmptyTriggered = false
        lastNativeClip = 0
        HideAmmoHUD()
    end
end)

-- ============================================================================
-- WEAPON WHEEL DISABLE
-- ============================================================================

if Config.DisableWeaponWheel then
    CreateThread(function()
        while true do
            Wait(0)
            -- Weapon wheel
            DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON (Tab)
            -- Vehicle weapon switch
            DisableControlAction(0, 99, true)   -- INPUT_VEH_SELECT_NEXT_WEAPON
            DisableControlAction(0, 100, true)  -- INPUT_VEH_SELECT_PREV_WEAPON
        end
    end)
end

-- ============================================================================
-- DEATH / RESOURCE CLEANUP
-- ============================================================================

--- Remove weapon when player respawns (from sb_deaths revive event)
RegisterNetEvent('SB:Client:Revive', function()
    if equippedWeapon then
        local ped = PlayerPedId()
        if hasExtendedClip then
            local weaponConfig = Config.Weapons[equippedWeapon]
            if weaponConfig then
                local compHash = GetHashKey(weaponConfig.extendedClipComponent)
                RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
            end
        end

        -- Return empty mag on revive (rounds lost on death)
        if currentMagName then
            TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
        end

        RemoveWeaponFromPed(ped, equippedHash)
        equippedWeapon = nil
        equippedSlot = nil
        equippedHash = nil
        currentAmmo = 0
        currentMagCapacity = 0
        currentMagLabel = ''
        currentMagName = nil
        ammoSyncActive = false
        isEquipping = false
        hasExtendedClip = false
        magEmptyTriggered = false
        lastNativeClip = 0
        HideAmmoHUD()
    end
end)

--- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if equippedHash then
        local ped = PlayerPedId()
        if hasExtendedClip then
            local weaponConfig = Config.Weapons[equippedWeapon]
            if weaponConfig then
                local compHash = GetHashKey(weaponConfig.extendedClipComponent)
                RemoveWeaponComponentFromPed(ped, equippedHash, compHash)
            end
        end
        RemoveWeaponFromPed(ped, equippedHash)
    end

    -- Return mag to inventory if resource is being restarted
    if currentMagName then
        if currentAmmo > 0 then
            TriggerServerEvent('sb_weapons:server:magEject', currentMagName, currentAmmo)
        else
            TriggerServerEvent('sb_weapons:server:magEmpty', currentMagName)
        end
    end

    currentMagName = nil
    magEmptyTriggered = false
    HideAmmoHUD()
end)

--- Remove all weapons on spawn (prevent native weapon persistence)
RegisterNetEvent('SB:Client:OnPlayerLoaded', function()
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    SetWeaponsNoAutoreload(true)
    HideAmmoHUD()
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

--- Get currently equipped weapon name
exports('GetEquippedWeapon', function()
    return equippedWeapon
end)

--- Check if player has weapon equipped
exports('IsArmed', function()
    return equippedWeapon ~= nil
end)

--- Force holster (for other scripts like handcuffs, etc.)
exports('ForceHolster', function()
    if equippedWeapon then
        HolsterWeapon(true)
    end
end)
