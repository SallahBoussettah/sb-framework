# sb_admin

Developer and admin utility menu for FiveM, built for the SB Framework.

## Features

- NUI-based admin panel with tabbed interface (Tools, Teleport, Give, Players)
- Prop Inspector with raycast-based model/hash/type/coords display (F7)
- NoClip free camera flight with adjustable speed (Shift/Ctrl/scroll wheel)
- God mode toggle
- Coordinate display overlay with copy-to-clipboard (vector3/vector4)
- Vehicle spawning with automatic key assignment via sb_inventory
- Vehicle deletion (in-vehicle or raycast look-at)
- Teleport to waypoint, to player (`/goto`), bring player (`/bring`), or coordinates (`/tp`)
- Time of day control with freeze toggle
- Give money, items, and weapon kits to players
- Set job and gang with grade validation
- Revive and full heal (health, hunger, thirst, stress)
- Kick and ban with reason logging
- Runtime admin grant/revoke (`/setadmin`, `/removeadmin`)
- Duty toggle for yourself or other players
- ACE permission based (`command.sb_admin`)
- Toast notification system in the NUI panel
- All actions logged to server console

## Dependencies

- `sb_core` (required)
- `sb_weapons` (required, for weapon kit giving)
- `sb_inventory` (required, for item giving and car keys)
- `sb_notify` (optional, for in-game notifications)
- `sb_deaths` (optional, revive integration)
- `sb_police` (optional, duty sync for police job)

## Installation

1. Place `sb_admin` in your resources directory.
2. Add `ensure sb_admin` to your `server.cfg` after its dependencies.
3. Grant admin access via ACE permissions in your `server.cfg`:

```cfg
add_ace identifier.license:your_license command.sb_admin allow
```

Or assign to a group:

```cfg
add_ace group.admin command.sb_admin allow
add_principal identifier.license:your_license group.admin
```

## Configuration

All options are in `config.lua`:

- **AcePerm** - ACE permission string required for access (default `command.sb_admin`)
- **NoClipBaseSpeed** - Base noclip movement speed (default 1.0)
- **NoClipFastMultiplier** - Speed multiplier when holding Shift (default 3.0)
- **NoClipSlowMultiplier** - Speed multiplier when holding Ctrl (default 0.3)
- **InspectorMaxDistance** - Max raycast distance for prop inspector (default 100.0)
- **LaserColor** - RGBA color for the inspector hit marker (default orange)
- **DeletePreviousVehicle** - Auto-delete previous admin-spawned vehicle on new spawn (default true)

## Key Bindings

| Key | Action |
|---|---|
| F5 | Toggle admin menu |
| F7 | Toggle prop inspector |

## Commands

| Command | Description |
|---|---|
| `/car [model]` | Spawn a vehicle by model name |
| `/dv` | Delete vehicle you are in or looking at |
| `/removecar` | Same as /dv |
| `/tp x, y, z[, heading]` | Teleport to coordinates |
| `/goto [id]` | Teleport to a player |
| `/bring [id]` | Bring a player to you |
| `/givemoney [id] [cash/bank/crypto] [amount]` | Give money |
| `/giveitem [id] [item] [amount]` | Give an item |
| `/giveweapon [id] [weapon]` | Give a weapon kit (weapon + 3 mags + ammo box) |
| `/setjob [id] [job] [grade]` | Set a player's job |
| `/setgang [id] [gang] [grade]` | Set a player's gang |
| `/revive [id]` | Revive a player (or self if no ID) |
| `/heal [id]` | Full heal a player (or self if no ID) |
| `/kick [id] [reason]` | Kick a player |
| `/ban [id] [hours] [reason]` | Ban a player (0 hours = permanent) |
| `/time [hour] [minute]` | Set time of day |
| `/freezetime` | Toggle time freeze |
| `/setadmin [id]` | Grant admin access at runtime |
| `/removeadmin [id]` | Revoke admin access |
| `/duty` | Toggle your own duty status |
| `/setduty [id] [on/off]` | Set another player's duty |
| `/listjobs` | List all available jobs |
| `/cp3` | Copy current vector3 to clipboard |
| `/cp4` | Copy current vector4 to clipboard |

## Exports (Client)

| Export | Description |
|---|---|
| `IsAdmin()` | Returns whether the current player has admin access |

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
