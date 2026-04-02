# sb_target

Third-eye targeting system for FiveM, built for the SB Framework.

## Features

- Hold Left Alt to activate targeting mode with a center crosshair
- Raycast-based entity detection with fallback look-direction scanning
- Target types: specific entities, model hashes, global peds/vehicles/objects/players, vehicle bones, and zones
- Sphere and box zone support with point-in-zone math
- Marker-based entity highlight (orange downward arrow above targeted entity)
- Job and group filtering per option
- `canInteract` callback support for dynamic option visibility
- Distance-based filtering per option
- Left-click to open option menu, NUI-driven selection
- Automatic stale entity cleanup
- Debug mode with zone markers (`Config.Debug = true`)

## Dependencies

- `sb_core` (required)

## Installation

1. Place `sb_target` in your resources directory.
2. Add `ensure sb_target` to your `server.cfg` after `sb_core`.
3. Other scripts register targets via exports.

## Configuration

All options are in `config.lua`:

- **ActivateKey** - Control ID to hold for targeting (default 19, Left Alt)
- **RaycastDistance** - How far the raycast reaches (default 10.0)
- **RaycastFlags** - Raycast collision flags (default 511, everything)
- **DefaultDistance** - Default interaction distance if not specified per option (default 2.5)
- **OutlineColor** - RGBA color for the entity highlight marker
- **ZoneCheckInterval** - How often zones are checked in ms (default 100)
- **CleanupInterval** - How often stale entities are cleaned up in ms (default 5000)
- **Debug** - Show zone debug markers (default false)

## Exports (Client)

### Entity Targets

| Export | Description |
|---|---|
| `AddTargetEntity(entities, options)` | Register options on specific entity handles |
| `RemoveTargetEntity(entities, names)` | Remove options (or all) from entities |

### Model Targets

| Export | Description |
|---|---|
| `AddTargetModel(models, options)` | Register options for model hashes or names |
| `RemoveTargetModel(models, names)` | Remove options from models |

### Global Targets

| Export | Description |
|---|---|
| `AddGlobalPed(options)` | Add options to all NPC peds |
| `RemoveGlobalPed(name)` | Remove a global ped option by name |
| `AddGlobalVehicle(options)` | Add options to all vehicles |
| `RemoveGlobalVehicle(name)` | Remove a global vehicle option by name |
| `AddGlobalObject(options)` | Add options to all objects |
| `RemoveGlobalObject(name)` | Remove a global object option by name |
| `AddGlobalPlayer(options)` | Add options to all player peds |
| `RemoveGlobalPlayer(name)` | Remove a global player option by name |

### Bone Targets

| Export | Description |
|---|---|
| `AddTargetBone(bones, options)` | Register options on vehicle bone names |
| `RemoveTargetBone(bones, name)` | Remove bone target options |

### Zone Targets

| Export | Description |
|---|---|
| `AddSphereZone(name, coords, radius, options)` | Create a sphere zone with interaction options |
| `AddBoxZone(name, coords, width, length, height, heading, options)` | Create a box zone with interaction options |
| `RemoveZone(name)` | Remove a zone by name |

### Option Format

Each option in the `options` table should have:

```lua
{
    name = 'unique_name',       -- required, unique identifier
    label = 'Do Something',     -- required, display text
    icon = 'fa-icon-name',      -- FontAwesome icon (default: fa-circle)
    distance = 2.5,             -- max interaction distance (optional)
    job = 'police',             -- job name or table of job names (optional)
    groups = {'police','ems'},  -- alternative to job (optional)
    canInteract = function(entity, distance, coords) return true end, -- optional
    action = function(entity) end,  -- client callback (pick one)
    event = 'eventName',            -- client event (pick one)
    serverEvent = 'eventName',      -- server event (pick one)
}
```

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
