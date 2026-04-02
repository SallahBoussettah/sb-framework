# sb_notify

Modern NUI-based notification system for SB Framework. Provides styled toast notifications with sound effects, deduplication, and configurable positioning.

## Features

- Clean, modern notification UI with NUI
- Notification types: success, error, warning, info, primary
- Configurable screen position (top-right, top-left, top-center, bottom-right, bottom-left, bottom-center)
- Configurable max simultaneous notifications
- Sound effects per notification type (using GTA native sounds)
- Automatic deduplication (same message suppressed within 2-second window)
- Smooth enter/exit animations
- Integrates with sb_core's notification events automatically
- Export and event-based API
- Test command included

## Dependencies

- [sb_core](../sb_core) - Core framework

## Installation

1. Ensure `sb_core` is running.
2. Place `sb_notify` into your resources folder.
3. Add `ensure sb_notify` to your `server.cfg` (after sb_core).

When sb_notify is running, sb_core automatically routes all notifications through it instead of using native GTA notifications.

## Configuration

All configuration is in `config.lua`:

| Option | Description | Default |
|---|---|---|
| `Config.Position` | Screen position for notifications | `"top-right"` |
| `Config.DefaultDuration` | Default display duration (ms) | `5000` |
| `Config.MaxNotifications` | Max notifications visible at once | `3` |
| `Config.AnimationDuration` | Enter/exit animation duration (ms) | `300` |
| `Config.EnableSounds` | Play sound effects | `true` |
| `Config.Sounds` | Sound name and set per notification type | See config |

## Exports

### Client

| Export | Description |
|---|---|
| `Notify(message, type, duration)` | Show a notification |
| `ShowNotification(message, type, duration)` | Alias for Notify |

**Parameters:**
- `message` (string) - Notification text
- `type` (string) - One of: `"success"`, `"error"`, `"warning"`, `"info"`, `"primary"`
- `duration` (number, optional) - Display time in milliseconds

**Example:**
```lua
exports['sb_notify']:Notify('Vehicle repaired!', 'success', 5000)
```

## Events

### Client

| Event | Parameters | Description |
|---|---|---|
| `SB:Client:Notify` | message, type, duration | Triggered by sb_core server-side notifications |
| `sb_notify:client:Notify` | message, type, duration | Alternative event name |

## Commands

| Command | Description |
|---|---|
| `/notify [type] [message]` | Send yourself a test notification |

## No MLO/Mapping Required

This is a purely UI-based resource with no in-game world elements.

## License

Written by Salah Eddine Boussettah for SB Framework.
