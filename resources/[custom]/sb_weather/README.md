# sb_weather

Server-synced weather control for FiveM, built for the SB Framework.

## Features

- Server-authoritative weather sync across all players
- Periodic re-sync to catch late joiners (configurable interval)
- Automatic sync on player join and resource start
- Client-side continuous override to prevent GTA from reverting weather
- Snow rendering support (vehicle trails and footstep tracks for snow types)
- Admin command to change weather with validation
- Server exports for other scripts to read or set weather programmatically
- Supports all GTA V weather types including holiday types (XMAS, HALLOWEEN)

## Dependencies

None required.

Optional integrations:
- `sb_notify` (for admin command feedback)
- Uses the same ACE permission as sb_admin (`command.sb_admin`)

## Installation

1. Place `sb_weather` in your resources directory.
2. Add `ensure sb_weather` to your `server.cfg`.

## Configuration

All options are in `config.lua`:

- **AcePerm** - ACE permission required for the `/weather` command (default `command.sb_admin`)
- **DefaultWeather** - Weather type on server start (default `CLEAR`)
- **SyncInterval** - How often weather is re-synced to all clients in ms (default 10000)
- **WeatherTypes** - List of valid weather types

### Available Weather Types

`EXTRASUNNY`, `CLEAR`, `CLEARING`, `CLOUDS`, `OVERCAST`, `SMOG`, `FOGGY`, `NEUTRAL`, `RAIN`, `THUNDER`, `SNOW`, `SNOWLIGHT`, `BLIZZARD`, `XMAS`, `HALLOWEEN`

## Commands

| Command | Description |
|---|---|
| `/weather` | Show current weather and list valid types |
| `/weather [type]` | Set weather for all players |

## Exports (Server)

| Export | Description |
|---|---|
| `GetWeather()` | Returns the current weather type string |
| `SetWeather(weatherType)` | Set weather for all players, returns true on success |

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
