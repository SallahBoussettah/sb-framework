# sb_impound

Vehicle impound and persistence system for FiveM. Tracks all spawned player vehicles server-side, handles automatic impound on owner disconnect, and provides impound lot retrieval with tiered fees. Also includes stolen vehicle detection.

## Features

- Server-side tracking of all spawned player vehicles
- Automatic impound after owner disconnects (configurable timeout)
- Stolen vehicle detection - vehicles taken by non-owners are left in the world
- Reconnect detection - vehicles are preserved if owner returns within the timeout window
- Multiple impound lot locations with NPC-based interaction
- Tiered fee system: base fee, destroyed vehicle surcharge, and time-based storage fee
- Car key confiscation on impound, keys returned on retrieval
- Offline key removal queue - keys are removed when player next logs in
- Player command to self-impound destroyed vehicles (`/impoundmycar`)
- Admin command to impound any vehicle by plate (`/impound`)
- Server-side vehicle spawning with OneSync persistence on retrieval
- Full vehicle property restoration on retrieval
- NUI with fee breakdown display
- Database auto-migration for impound columns

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_inventory
- sb_garage (for vehicle property functions)
- sb_banking (for bank transaction logging)
- oxmysql

## Installation

1. Place `sb_impound` in your resources folder.
2. Add `ensure sb_impound` to your `server.cfg` after `sb_garage` and other dependencies.
3. The script auto-creates required database columns (`impound_reason`, `impound_time`) on the `player_vehicles` table and creates the `impound_key_removals` table.

## MLO / Mapping Dependencies

None. Both impound lot locations (LSPD near Mission Row and Sandy Shores) use vanilla GTA V map positions. No custom MLO or mapping is required.

## Configuration

All settings are in `config.lua`:

- **Config.DisconnectTimeout** - Seconds before an abandoned vehicle is impounded (default: 60).
- **Config.CheckInterval** - How often the system checks for expired abandoned vehicles (default: 30s).
- **Config.ImpoundFee** - Base impound retrieval fee.
- **Config.DestroyedFee** - Additional fee for destroyed vehicles.
- **Config.DailyStorageFee** - Per-hour storage fee.
- **Config.MaxStorageHours** - Max hours that accumulate storage fees.
- **Config.NPCModel** - NPC model at impound lots.
- **Config.Locations** - Define impound lot locations with NPC position, spawn points, and blip settings.

## Exports

### Server

| Export | Description |
|--------|-------------|
| `ImpoundVehicle(plate, reason, location, props, isDestroyed)` | Impound a vehicle programmatically |
| `RemoveVehicleKeys(citizenid, plate)` | Remove car keys from a player |
| `IsVehicleImpounded(plate)` | Check if a vehicle is impounded |
| `GetImpoundedVehicles(citizenid)` | Get all impounded vehicles for a player |
| `RegisterSpawnedVehicle(plate, citizenid, netId, model, props)` | Register a spawned vehicle for tracking |
| `UnregisterSpawnedVehicle(plate)` | Remove a vehicle from tracking |
| `UpdateVehicleProps(plate, props, netId)` | Update tracked vehicle properties |
| `IsVehicleAbandoned(plate)` | Check if a vehicle is in the abandoned queue |
| `IsVehicleStolen(plate)` | Check if a vehicle has been flagged as stolen |
| `MarkVehicleStolen(plate)` | Mark a vehicle as stolen |
| `IsVehicleTracked(plate)` | Check if a vehicle is being tracked |
| `GetTrackedVehicles()` | Get all currently tracked vehicles |

### Client

| Export | Description |
|--------|-------------|
| `IsImpoundOpen()` | Returns whether the impound UI is open |
| `GetCurrentImpoundLocation()` | Returns the current impound location ID |

## Commands

| Command | Description |
|---------|-------------|
| `/impoundmycar` | Send your nearby destroyed vehicle to impound |
| `/impound [plate] [destroyed]` | Admin: Impound any vehicle by plate |
