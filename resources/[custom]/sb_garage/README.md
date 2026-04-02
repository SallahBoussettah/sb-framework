# sb_garage

Vehicle garage system for FiveM. Store and retrieve owned vehicles at multiple garage locations across the map. Supports vehicle property persistence, damage tracking, cross-garage transfers, and car key management.

## Features

- Multiple garage locations (Legion Square, Pillbox Hill, Airport, Sandy Shores, Paleto Bay)
- NPC-based interaction with sb_target integration
- Store vehicles by exiting near the garage NPC (tracks recently exited vehicle)
- Retrieve vehicles with full property restoration (colors, mods, damage, deformation)
- Cross-garage transfer with configurable fee
- Vehicle property system that saves and restores all mods, colors, neons, liveries, tyre smoke, extras, window tint, and body deformation
- Car keys removed on store, given back on retrieve
- Prevents storing rental vehicles, test drive vehicles, or vehicles with passengers
- Server-side vehicle spawning with OneSync persistence
- Vehicles hidden during property application to prevent visual pop-in
- Safety passes to re-apply colors and damage that GTA resets on freshly spawned vehicles
- Server restart detection - returns all "out" vehicles to their garages automatically
- Clean NUI with vehicle health bars, transfer fee display, and tab filtering
- Admin commands for fixing stuck vehicles and giving keys

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_vehicleshop (for key checking callbacks)
- sb_impound (for persistence tracking)
- sb_fuel (optional)
- oxmysql

## Installation

1. Place `sb_garage` in your resources folder.
2. Add `ensure sb_garage` to your `server.cfg` after all dependencies.
3. Requires the `player_vehicles` table in your database with columns: `plate`, `vehicle`, `vehicle_label`, `citizenid`, `state`, `garage`, `fuel`, `body`, `engine`, `mods`.

## MLO / Mapping Dependencies

None. All garage locations use vanilla GTA V map positions. No custom MLO or mapping is required.

## Configuration

All settings are in `config.lua`:

- **Config.NPCModel** - NPC ped model at garage locations.
- **Config.MaxVehiclesPerGarage** - Max vehicles stored per garage per player.
- **Config.TransferFee** - Fee to retrieve a vehicle from a different garage.
- **Config.StoreCooldown** - Cooldown between store/retrieve operations (ms).
- **Config.RecentExitTime** - Time window to track a recently exited vehicle (ms).
- **Config.KeysItem** - Item name for car keys.
- **Config.TakeKeysOnStore / Config.GiveKeysOnRetrieve** - Key management toggles.
- **Config.Garages** - Define garage locations with NPC position, spawn points, store zone, and blip settings.

## Exports

### Client

| Export | Description |
|--------|-------------|
| `IsGarageOpen()` | Returns whether the garage UI is currently open |
| `GetCurrentGarage()` | Returns the current garage ID |
| `GetVehicleProperties(vehicle)` | Extract all properties from a vehicle entity |
| `SetVehicleProperties(vehicle, props)` | Apply saved properties to a vehicle entity |
| `ApplyVehicleColors(vehicle, props)` | Apply color data to a vehicle |
| `ApplyVehicleDamage(vehicle, props)` | Apply damage data to a vehicle |

### Server

| Export | Description |
|--------|-------------|
| `GetPlayerVehicles(citizenid, garageId?)` | Get all vehicles for a player |
| `GetStoredVehicles(citizenid)` | Get stored vehicles for a player |
| `IsVehicleStored(plate)` | Check if a vehicle is stored |
| `SetVehicleState(plate, state, garageId?)` | Set a vehicle's state |

## Commands

| Command | Description |
|---------|-------------|
| `/fixvehicle [plate] [state]` | Admin: Fix a stuck vehicle state |
| `/givekeys [playerid] [plate]` | Admin: Give keys for a vehicle to a player |
