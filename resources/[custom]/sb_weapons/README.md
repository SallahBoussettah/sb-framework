# sb_weapons

Weapon equip/holster system with a magazine-based reload mechanic, ammo tracking, and HUD integration.

## Features

- Weapon equip and holster with draw/holster animations
- Magazine-based reload system for pistols (extensible to other weapon types)
- Magazine types with different capacities and reload speeds (Quick, Standard, Extended)
- Ammo tracked per-round in script, not relying on GTA V native ammo pool
- Extended clip component applied visually when magazine exceeds native clip size
- Ammo box system for storing and dispensing loose rounds
- Load/unload magazines from inventory context menu
- R key triggers auto-reload (finds compatible loaded magazine in inventory)
- Auto-holster on death, auto-cleanup on revive
- Weapon wheel and melee controls disabled to enforce inventory-only weapon use
- Server-side magazine tracking prevents item loss on disconnect or resource restart
- Anti-exploit: operation locks, cooldowns, slot and amount validation
- Weapon serial number generation

## Dependencies

- sb_core
- sb_inventory
- sb_hud

## Installation

1. Place `sb_weapons` in your resources folder.
2. Add `ensure sb_weapons` to your server.cfg (after its dependencies).
3. Weapon and magazine items must exist in your `sb_items` database table. Weapon items should have category `weapon`, magazine items should have category `magazine`.
4. Ammo items (`pistol_ammo`, `smg_ammo`, etc.) and ammo box item (`p_ammobox`) must also exist in `sb_items`.

## Mapping / Location Notes

No specific MLO or mapping required. This is a pure gameplay system.

## Configuration

All settings are in `config.lua`:

- **Weapons** - Weapon definitions including hash, type, ammo item, compatible magazines, clip size, draw/holster times. Supports `noMagazine` flag for melee, tasers, and weapons with built-in ammo.
- **Magazines** - Magazine definitions with capacity, reload time, weapon type, and label.
- **AmmoBox** - Ammo box item name, capacity, and ammo type.
- **DefaultDurability** - Starting durability for new weapons.
- **AmmoSyncInterval** - How often ammo count is checked (ms).
- **DisableWeaponWheel** - Whether to block the native weapon wheel.

To add new weapons, add an entry to `Config.Weapons`. To add magazine types, add to `Config.Magazines` and reference them in the weapon's `compatibleMags` list.

## Exports

**Client-side:**

- `exports['sb_weapons']:GetEquippedWeapon()` - Returns the currently equipped weapon name (or nil)
- `exports['sb_weapons']:IsArmed()` - Returns true if player has a weapon equipped
- `exports['sb_weapons']:ForceHolster()` - Force-holster the current weapon (for handcuffs, etc.)

**Server-side:**

- `exports['sb_weapons']:GiveWeaponKit(targetId, weaponName)` - Give weapon + 3 loaded mags + ammo box
- `exports['sb_weapons']:GiveWeapon(source, weaponName, durability)` - Give a single weapon with serial number

## License

Part of SB Framework by Salah Eddine Boussettah.
