# sb_multicharacter

Character selection, creation, and appearance customization system for SB Framework. Provides a full NUI-based interface for managing multiple characters per player, with live 3D ped preview, heritage/face customization, clothing, and spawn location selection.

## Features

- Character selection screen with slot-based layout
- Full character creation with first name, last name, date of birth, gender, and nationality
- Heritage system (46 parent faces - male, female, and special)
- 20 face feature sliders (nose, eyebrows, cheekbones, jaw, chin, etc.)
- 13 head overlays (blemishes, facial hair, eyebrows, makeup, etc.) with color support
- Hair style, color, and highlight selection
- 32 eye colors
- Full clothing and props customization (12 components, 5 prop slots)
- Option to hide vanilla GTA clothing and show only addon/custom clothing
- Live 3D ped preview with camera controls (zoom, rotate, vertical pan)
- Multiple camera angles (full body, face, torso, legs, feet)
- Preview poses/animations
- Configurable spawn locations (apartments, last location, etc.)
- Character deletion with confirmation text
- Smooth camera transitions between views
- Keyboard and mouse controls for ped rotation and camera movement
- Seamless loading (screen stays black until UI is ready)
- Per-user character slot limits (pulled from the users table)

## Dependencies

- [sb_core](../sb_core) - Core framework (required)
- [oxmysql](https://github.com/overextended/oxmysql) - Database (required)
- `spawnmanager` - FiveM built-in spawn manager

## Installation

1. Ensure `sb_core` and `oxmysql` are running.
2. Place `sb_multicharacter` into your resources folder.
3. Add `ensure sb_multicharacter` to your `server.cfg` (after sb_core).
4. The resource uses the `players` and `users` tables created by sb_core.

## Configuration

All configuration is in `config.lua`:

| Option | Description | Default |
|---|---|---|
| `Config.ServerName` | Branding shown in UI | `"EVERYDAY CHAOS RP"` |
| `Config.ServerTagline` | Tagline below server name | `"Your chaos, your story"` |
| `Config.DefaultSlots` | Default character slots | `3` |
| `Config.AllowDelete` | Allow character deletion | `true` |
| `Config.DeleteConfirmText` | Text required to confirm deletion | `"DELETE"` |
| `Config.MinAge` / `Config.MaxAge` | Character age range | 18 - 80 |
| `Config.MinNameLength` / `Config.MaxNameLength` | Name length limits | 2 - 20 |
| `Config.SpawnLocations` | Available spawn points | Alta St, Integrity Way, Del Perro, Last Location |
| `Config.NewCharacterSpawn` | Spawn for new characters | Alta Street Apartments |
| `Config.PreviewLocation` | Interior coords for ped preview | Underground interior |
| `Config.CameraPositions` | Camera offsets/FOV for each view | Full body, face, torso, legs, feet |
| `Config.CameraTransitionTime` | Camera transition duration (ms) | `500` |
| `Config.CameraRotationSpeed` | Mouse rotation sensitivity | `2.0` |
| `Config.Parents` | Heritage face list (male, female, special) | 46 faces |
| `Config.FaceFeatures` | Face feature slider definitions | 20 sliders |
| `Config.HeadOverlays` | Head overlay definitions | 13 overlays |
| `Config.EyeColors` | Eye color options | 32 colors |
| `Config.Nationalities` | Nationality options | 16 options |
| `Config.DefaultAppearance` | Default male/female appearance | See config |
| `Config.IdleAnimation` | Idle pose for preview ped | Arms crossed |
| `Config.PreviewPoses` | Available preview poses | 7 poses |
| `Config.HideVanillaClothing` | Hide vanilla GTA clothing | `true` |
| `Config.VanillaDrawables` | Vanilla drawable counts per component | Per gender |
| `Config.VanillaProps` | Vanilla prop counts | Per gender |

## Exports

### Client

| Export | Description |
|---|---|
| `IsInCharacterSelect()` | Returns true if character select screen is open |
| `IsCreatingCharacter()` | Returns true if character creation is active |

## No MLO/Mapping Required

This resource uses a standard GTA underground interior for the ped preview. No custom MLO or mapping is needed.

## License

Written by Salah Eddine Boussettah for SB Framework.
