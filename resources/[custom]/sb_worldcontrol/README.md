# sb_worldcontrol

RP world management script for FiveM, built for the SB Framework.

## Features

- **NPC Vehicle Locking** - All NPC-spawned vehicles are locked (lock state 2). Player-owned and rental vehicles are excluded via state bag detection. Prevents window smashing (task 121 blocked).
- **Density Control** - Configurable ped, vehicle, parked vehicle, and scenario ped density multipliers applied per-frame.
- **Police/Wanted System** - Disable wanted levels, police dispatch, and make police ignore the player. Optional cop spawn multiplier.
- **Random Event Suppression** - Disable GTA random events, ambient sirens, stunt jumps, and the idle camera.
- **Player Controls** - Disable health regeneration, auto weapon swap on pickup, and optionally drive-by and cover actions.
- **Friendly Fire** - Enabled by default for RP purposes.
- **State Bag Integration** - Recognizes `sb_owned` and `sb_rental` state bags to exclude owned/rented vehicles from NPC locking.
- **Batched Processing** - Vehicle locking is spread across frames (10 per frame) to prevent performance spikes.
- **Clean Cleanup** - On resource stop, all locked vehicles are unlocked and all world overrides are reverted.

## Dependencies

None required. This is a client-side only script.

Optional integrations:
- Recognizes `sb_owned` state bag set by other scripts (sb_admin, sb_garage, etc.)
- Recognizes `sb_rental` state bag from sb_rental
- Uses `SB:Client:Notify` event for lock notifications

## Installation

1. Place `sb_worldcontrol` in your resources directory.
2. Add `ensure sb_worldcontrol` to your `server.cfg`.
3. Adjust density and feature toggles in `config.lua`.

## Configuration

All options are in `config.lua`:

### NPC Vehicles

- **LockNPCVehicles** - Lock all NPC vehicles (default true)
- **LockNotifyMessage** - Message shown when player tries to enter a locked vehicle

### Police and Wanted System

- **DisableWantedSystem** - Set max wanted level to 0 (default true)
- **DisableDispatch** - Disable all dispatch services (default true)
- **PoliceIgnorePlayer** - Police NPCs ignore the player (default true)
- **DisableCops** - Prevent cop NPCs from spawning entirely (default false)
- **CopSpawnMultiplier** - Multiplier for cop spawn rate (default 0.3)

### NPC and Traffic Density

- **PedDensity** - Pedestrian density multiplier, 0.0-1.0 (default 0.4)
- **VehicleDensity** - Traffic density multiplier (default 0.4)
- **ParkedVehicleDensity** - Parked vehicle density (default 0.5)
- **ScenarioPedDensity** - Scenario ped density (default 0.3)

### Random Events and Ambient

- **DisableRandomEvents** - Disable GTA random events (default true)
- **DisableAmbientSirens** - Disable distant cop sirens (default true)
- **DisableIdleCamera** - Disable AFK camera (default true)
- **DisableStuntJumps** - Cancel stunt jump triggers (default true)

### Player Controls

- **DisableHealthRegen** - Disable passive health regeneration (default true)
- **DisableAutoWeaponSwap** - Prevent weapon drop on death (default true)
- **DisableWeaponDriveBy** - Disable drive-by shooting (default false)
- **DisableCoverAction** - Disable cover system (default false)

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
