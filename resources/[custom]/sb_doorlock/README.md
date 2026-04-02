# sb_doorlock

Door lock system for FiveM with job-based, gang-based, item-based, and citizen ID-based access control. Supports single doors, double doors, garage gates, barriers, and MLO doors with entity-freeze enforcement.

## Features

- Multiple authorization methods: job, gang, citizen ID, item, and public access
- Admin bypass with configurable ACE permission
- Door types: single, double, sliding, garage, and barrier (bollard)
- MLO door enforcement via entity freezing (for doors that ignore the native door system)
- Vehicle horn activation for garage doors (honk near a gate to open/close)
- Linked doors (toggle two doors simultaneously)
- Auto-lock timer per door
- Heist bypass system - doors can be flagged as destructible by thermite
- State enforcement thread to prevent GTA from auto-opening locked doors
- Server-side state sync - all clients see the same door states
- sb_target integration or E-key proximity interaction (configurable)
- Lock/unlock animation
- Admin commands: `/doorlock`, `/doorunlock`, `/doorlist`
- Debug mode with colored markers on all doors

## Dependencies

- sb_core
- sb_target
- sb_notify
- oxmysql

## Installation

1. Place `sb_doorlock` in your resources folder.
2. Add `ensure sb_doorlock` to your `server.cfg` after all dependencies.
3. Configure your doors in `config.lua`.

## MLO / Mapping Dependencies

The default `config.lua` includes doors for several MLO/mapping locations. You will need the corresponding MLOs installed for those doors to function:

- **Pacific Standard Bank** - Requires the `pacific_bank_extended` mapping (or equivalent Pacific Bank interior MLO)
- **Mission Row PD** - Requires the `mission_row_pd` MLO
- **Pillbox Hospital** - Requires the `pillbox_hospital` MLO (or equivalent)

Doors for vanilla GTA interiors (e.g. standard bank branches) work without any custom MLO. Remove or comment out any door entries in `config.lua` that reference MLOs you do not have installed.

## Configuration

All settings are in `config.lua`:

- **Config.Debug** - Show debug markers on all doors.
- **Config.InteractKey** - Key code for E-key interaction (default: 38).
- **Config.DefaultDistance** - Default interaction distance.
- **Config.UseTarget** - Use sb_target (true) or E-key proximity (false).
- **Config.AdminAccess** - Allow admins to bypass all doors.
- **Config.AdminPermission** - ACE permission for admin bypass.
- **Config.Animation** - Lock/unlock animation settings.
- **Config.Doors** - The full list of doors with coordinates, model hashes, access rules, door type, and special flags.

### Door Entry Properties

Each door in `Config.Doors` supports:

| Property | Description |
|----------|-------------|
| `id` | Unique door identifier |
| `model` / `modelHash` | Door model name or hash |
| `coords` | Door position (vector3) |
| `locked` | Initial lock state |
| `doorType` | `door`, `double`, `garage`, `barrier` |
| `authorizedJobs` | Table of `{ ['jobname'] = minGrade }` |
| `authorizedGangs` | Table of `{ ['gangname'] = minGrade }` |
| `authorizedCitizenIDs` | List of citizen IDs with access |
| `items` | List of required item names |
| `allAuthorized` | Public access (anyone can toggle) |
| `vehicleActivated` | Can be toggled by honking vehicle horn |
| `linkedDoor` | ID of a door to toggle simultaneously |
| `autoLock` | Auto-lock delay in ms after unlocking |
| `enforceState` | Use entity freeze for MLO doors |
| `heistBypass` | Allow destruction via heist thermite |
| `distance` | Custom interaction distance |

## Exports

### Client

| Export | Description |
|--------|-------------|
| `GetDoorState(doorId)` | Get current lock state of a door |
| `SetDoorState(doorId, locked)` | Set a door's lock state |
| `ToggleDoor(doorId, skipAnimation)` | Toggle a door's lock state |
| `BypassDoor(doorId)` | Bypass a door (heist) |
| `ResetBypass(doorId)` | Reset a bypassed door |

### Server

| Export | Description |
|--------|-------------|
| `GetDoorState(doorId)` | Get current lock state |
| `SetDoorState(doorId, locked)` | Set and broadcast door state |
| `BypassDoor(doorId)` | Bypass a door |
| `ResetBypass(doorId)` | Reset bypass |
| `IsAuthorized(source, doorId)` | Check if a player is authorized for a door |

## Commands

| Command | Description |
|---------|-------------|
| `/doorlock [door_id]` | Admin: Lock a door |
| `/doorunlock [door_id]` | Admin: Unlock a door |
| `/doorlist` | Admin: List all doors and their states |
