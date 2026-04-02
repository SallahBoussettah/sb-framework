# sb_minigame

Standalone reusable minigame engine for FiveM, built for the SB Framework.

## Features

- Three minigame types: timing bar, key sequence, and precision
- Configurable difficulty (1-5) and number of rounds
- Callback-based API - call the export, get success/score in the callback
- NUI-driven interface with smooth animations
- Auto-closes on player death or resource stop
- No dependencies on any framework - fully standalone
- Optional label text displayed during the minigame

## Dependencies

None. This script is fully standalone.

Optional integrations:
- `sb_deaths` (if available, prevents starting minigames while dead)
- `sb_notify` (used in test commands only)

## Installation

1. Place `sb_minigame` in your resources directory.
2. Add `ensure sb_minigame` to your `server.cfg`.

## Usage

Call the export from any client script:

```lua
exports['sb_minigame']:Start({
    type = 'timing',       -- 'timing', 'sequence', or 'precision'
    difficulty = 3,         -- 1 (easy) to 5 (hard)
    rounds = 3,             -- number of rounds to complete
    label = 'Lockpicking',  -- optional display label
}, function(success, score)
    if success then
        -- player passed all rounds
    else
        -- player failed
    end
end)
```

### Game Types

- **timing** - A bar moves across a target zone. Press at the right moment.
- **sequence** - A sequence of keys is shown. Repeat the sequence correctly.
- **precision** - A shrinking circle. Press when the circle aligns with the target.

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| type | string | `'timing'` | Minigame type |
| difficulty | number | `3` | Difficulty from 1 to 5 |
| rounds | number | `3` | Number of rounds to pass |
| label | string | `''` | Optional label shown during the game |

### Callback

The callback receives two arguments:
- `success` (boolean) - whether the player passed all rounds
- `score` (number) - numeric score achieved

## Exports (Client)

| Export | Description |
|---|---|
| `Start(options, callback)` | Start a minigame with the given options |

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
