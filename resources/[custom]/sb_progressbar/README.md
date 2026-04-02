# sb_progressbar

NUI-based progress bar utility for SB Framework. Provides a reusable progress bar with animation support, prop attachment, and configurable control disabling. Used by other resources for timed actions like repairing, lockpicking, searching, etc.

## Features

- Clean NUI progress bar with label and optional icon
- Configurable duration
- Optional cancel support (X key)
- Animation playback during progress (any anim dict/anim)
- Prop attachment during progress (bone, position, rotation)
- Automatic control disabling (movement, vehicle, combat)
- Auto-cancel on player death or ragdoll
- Completion and cancellation callbacks
- Export and event-based API
- Only one progress bar active at a time (prevents stacking)
- Automatic cleanup of animations and props on complete/cancel

## Dependencies

None. This is a standalone utility resource. It does not require sb_core to function.

## Installation

1. Place `sb_progressbar` into your resources folder.
2. Add `ensure sb_progressbar` to your `server.cfg`.

## Configuration

All configuration is in `config.lua`:

| Option | Description | Default |
|---|---|---|
| `Config.DisableMovement` | Disable walking/running during progress | `true` |
| `Config.DisableCarMovement` | Disable vehicle input during progress | `true` |
| `Config.DisableCombat` | Disable weapon/attack during progress | `true` |
| `Config.CancelOnDeath` | Cancel progress if player dies | `true` |
| `Config.CancelOnRagdoll` | Cancel progress if player ragdolls | `true` |
| `Config.DisableMovementControls` | GTA control IDs to disable for movement | See config |
| `Config.DisableCarControls` | GTA control IDs to disable for vehicles | See config |
| `Config.DisableCombatControls` | GTA control IDs to disable for combat | See config |

## Exports

### Client

| Export | Description |
|---|---|
| `Start(options)` | Start a progress bar. Returns false if one is already active. |
| `Cancel()` | Cancel the active progress bar |
| `IsActive()` | Returns true if a progress bar is currently running |

**Start options:**

```lua
exports['sb_progressbar']:Start({
    label = 'Repairing Vehicle...',    -- Text displayed on the bar
    duration = 5000,                    -- Duration in milliseconds
    icon = 'wrench',                    -- Optional icon name
    canCancel = true,                   -- Allow cancel with X key
    disableMovement = true,             -- Override config per-call
    disableCarMovement = true,          -- Override config per-call
    disableCombat = true,               -- Override config per-call
    animation = {                       -- Optional animation
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49                       -- Animation flag (default 49)
    },
    prop = {                            -- Optional attached prop
        model = 'prop_tool_wrench',
        bone = 57005,                   -- Ped bone index
        pos = vector3(0.0, 0.0, 0.0),
        rot = vector3(0.0, 0.0, 0.0)
    },
    onComplete = function()             -- Called on successful completion
        print('Done!')
    end,
    onCancel = function()               -- Called if cancelled
        print('Cancelled!')
    end
})
```

## Events

### Client

| Event | Parameters | Description |
|---|---|---|
| `sb_progressbar:start` | options (table) | Start a progress bar via event |
| `sb_progressbar:cancel` | none | Cancel active progress bar via event |

## No MLO/Mapping Required

This is a purely UI-based resource with no in-game world elements.

## License

Written by Salah Eddine Boussettah for SB Framework.
