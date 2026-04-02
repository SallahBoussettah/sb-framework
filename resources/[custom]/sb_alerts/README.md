# sb_alerts

Job-based dispatch and alert system with a NUI toast interface, map blips, GPS routing, and server-side export API. Any script can send alerts to on-duty players filtered by job name or job type.

## Tech Stack

- **UI:** HTML/CSS/JS (NUI toast notifications)
- **Backend:** Lua (FiveM client/server)

## Features

### Alert System

- Toast notifications with slide-in/out animations
- Configurable max visible alerts on screen (default: 3)
- Alert auto-expiry with configurable lifetime (default: 5 minutes)
- In-memory alert queue with max capacity (default: 50)
- Priority levels for alert ordering

### Alert Types

- **Police (911)** - blue styling, scanner call sound, flashing blip
- **EMS (Medical)** - red styling, scanner call sound, flashing blip
- **Mechanic (Service)** - orange styling, subtle sound
- **Panic Button** - red with special glow styling, large flashing blip, urgent sound
- **General (Dispatch)** - orange default styling
- Custom alert types can be added in config

### Job Routing

- Route alerts by exact job name (e.g., `'police'`) or by job type (e.g., `'leo'` reaches police + sheriff)
- Configurable job type mapping (`leo` to police style, `ems` to medical style, etc.)
- Only on-duty players receive alerts
- Multi-job alert support - send one alert to multiple job filters simultaneously

### Blip Management

- Automatic map blip creation at alert coordinates
- Per-type blip presets (sprite, color, scale, flash)
- Custom blip overrides per alert
- Auto-remove blips after configurable duration (default: 120 seconds)

### Keybinds

- **H** - set GPS waypoint to focused alert location
- **Y** - accept/respond to alert

### Cooldown System

- Per-source cooldowns to prevent alert spam
- Configurable cooldown per source script (e.g., `sb_robbery` = 120s, `sb_deaths` = 30s, `panic` = 10s)
- Default cooldown for unregistered sources

### Alert Lifecycle

- Alerts persist in server memory until expiry
- Automatic cleanup of expired alerts every 30 seconds
- Responder tracking with configurable max responders per alert
- Cancel and clear operations for programmatic control

## Dependencies

- sb_core

## Installation

1. Ensure `sb_core` is started before `sb_alerts` in your `server.cfg`.
2. Place `sb_alerts` in your resources folder.
3. Add `ensure sb_alerts` to your `server.cfg`.
4. No database required - alerts are ephemeral (memory only).

## Configuration

All configuration is in `config.lua`:

- `Config.MaxAlerts` - max alerts stored in memory (default: 50)
- `Config.AlertExpiry` - seconds before alert auto-expires (default: 300)
- `Config.MaxVisible` - max alerts visible on screen at once (default: 3)
- `Config.ToastDuration` - how long a toast stays visible before sliding out (default: 15 seconds)
- `Config.DefaultBlipDuration` - seconds before blip auto-removes (default: 120)
- `Config.GPSKey` / `Config.AcceptKey` - keybinds
- `Config.AlertTypes` - define alert types with icon, header, color, and sound
- `Config.JobTypeMapping` - map job types to alert type styling
- `Config.SourceCooldowns` - per-source cooldown durations
- `Config.DefaultBlip` - default blip settings (sprite, color, scale, flash, route)
- `Config.BlipPresets` - per-type blip overrides

## Exports

### Server

| Export | Description |
|--------|-------------|
| `SendAlert(jobFilter, data)` | Send an alert to all on-duty players matching the job filter. Returns `alertId`. |
| `SendAlertMulti(jobFilters, data)` | Send an alert to multiple job filters. Returns table of `alertId`s. |
| `SendAlertToPlayer(targetSource, data)` | Send an alert to a specific player. |
| `CancelAlert(alertId)` | Cancel an active alert and remove it from all clients. |
| `ClearJobAlerts(jobFilter)` | Clear all alerts for a specific job filter. |
| `GetActiveAlerts()` | Returns the full table of active alerts. |
| `IsAlertActive(alertId)` | Check if a specific alert is still active. |
| `GetResponderCount(alertId)` | Get the number of responders for an alert. |

### Alert Data Format

```lua
exports['sb_alerts']:SendAlert('police', {
    title = 'Store Robbery',
    description = '24/7 on Route 68 is being robbed',
    location = 'Route 68, Harmony',
    coords = vector3(x, y, z),
    caller = 'Anonymous',
    type = 'police',          -- alert type (matches Config.AlertTypes)
    source = 'sb_robbery',    -- cooldown source key
    priority = 2,             -- 1 = highest
    maxResponders = 4,
    expiry = 300,             -- override default expiry
    blip = {                  -- optional blip overrides
        sprite = 161,
        color = 1,
        scale = 1.2,
        flash = true,
    },
    metadata = {},            -- arbitrary extra data
})
```

## Screenshots

Screenshots coming soon.
