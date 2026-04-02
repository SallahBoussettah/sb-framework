# sb_hud

Custom status circles and vehicle dashboard HUD for FiveM, built for the SB Framework.

## Features

- Circular status indicators for health, armor, hunger, thirst, stamina, and stress
- Vehicle dashboard with speedometer, RPM gauge, gear indicator, fuel level, and engine health
- Separate dashboard styles for cars, motorcycles, and bicycles
- Custom stamina system with sprint drain, jump cost, and regeneration
- Built-in seatbelt system with windshield ejection protection
- Voice range indicator with pma-voice integration (whisper, normal, shout)
- Money display with change detection and auto-fade
- Street name and zone display below the minimap
- Cinematic mode to hide all HUD elements
- Drag-and-drop HUD editor (`/hudeditor`) with persistent layout via KVP storage
- Smart visibility - HUD auto-shows during combat, low stats, vehicle use, and fades when idle
- Hides native GTA health, armor, cash, and weapon HUD elements
- Dirty-checking optimization to minimize NUI updates
- Minimap kept as default rectangular style with radar keepalive

## Dependencies

- `sb_core` (required)
- `sb_notify` (optional, used for seatbelt and editor notifications)
- `sb_metabolism` (optional, stress-based stamina multiplier)
- `pma-voice` (optional, voice range sync)

## Installation

1. Place `sb_hud` in your resources directory.
2. Add `ensure sb_hud` to your `server.cfg` after `sb_core`.
3. Configure `config.lua` to your liking.

## Configuration

All options are in `config.lua`:

- **Position** - HUD placement: `bottom-left` or `bottom-right`
- **StatusIconsOffset** - Fine-tune circle position (x, y pixel offset)
- **UpdateInterval** - How often HUD values refresh (default 200ms)
- **MoneyFadeDelay** - How long money stays visible after a change (default 5000ms)
- **CinematicKey** - Key to toggle cinematic mode (default `Z`)
- **Low thresholds** - LowHealth, LowArmor, LowHunger, LowThirst, HighStress for warning colors
- **Show/hide toggles** - Enable or disable individual elements (health, armor, hunger, thirst, stamina, stress, money, job, voice)
- **SpeedUnit** - `KM/H` or `MPH` with matching multiplier
- **MaxSpeed** - Maximum speed shown on the gauge
- **VoiceRanges** - Labels, distances, and colors for each voice level
- **Colors** - Full theme color customization for every status circle

## Commands

| Command | Description |
|---|---|
| `/togglehud` | Toggle cinematic mode (bound to Z by default) |
| `/hudeditor` | Open drag-and-drop HUD layout editor |
| `/seatbelt` | Toggle seatbelt on/off (bound to B by default) |
| `/voicerange` | Cycle voice proximity range |

## Exports (Client)

| Export | Description |
|---|---|
| `IsHudVisible()` | Returns whether the HUD is currently visible |
| `SetHudVisible(bool)` | Show or hide the HUD |
| `GetVoiceRange()` | Returns current voice range index and range data |
| `ForceShowHud(duration)` | Force HUD visible for a duration in ms |
| `UpdateAmmo(current, capacity, magLabel)` | Update ammo display |
| `HideAmmo()` | Hide ammo display |
| `IsSeatbeltOn()` | Returns whether the seatbelt is currently fastened |

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
