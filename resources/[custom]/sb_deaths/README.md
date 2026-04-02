# sb_deaths

Death and Respawn System - Bleedout timer, death screen NUI, hospital respawn, EMS call, and admin revive.

## Features

- Detects player death and enters downed state with ragdoll
- NUI death screen with vignette effect and bleedout timer
- Displays killer name (player name, "Suicide", or "Unknown")
- Configurable bleedout timer before respawn button appears
- Hospital bill deducted on respawn (cash first, then bank, can go into debt)
- Hunger and thirst reset to 50% on respawn
- "Call Emergency" button alerts on-duty EMS players
- Admin `/revive` command support (revives in place)
- Destroyed owned vehicles are auto-sent to impound on death
- Death state persists across reconnects (metadata.isdead)
- Disables movement and combat controls while dead
- Death visual via timecycle modifier

## Dependencies

- sb_core
- oxmysql
- sb_notify (optional, used for vehicle impound notification)
- sb_impound (optional, auto-impounds destroyed vehicles)
- sb_garage (optional, reads vehicle properties for impound)

## Installation

1. Place `sb_deaths` in your resources folder.
2. Add `ensure sb_deaths` to your server.cfg (after sb_core).
3. No database tables needed - uses sb_core player metadata.

## MLO Requirements

None. The default respawn location is at Pillbox Hill Medical Center (299, -574, 43), which is a vanilla GTA V location. If you use a custom Pillbox hospital MLO, adjust `Config.RespawnCoords` to a valid position inside or outside that MLO.

## Configuration

All configuration is in `config.lua`:

- `Config.BleedoutTime` - Seconds before respawn button appears (default: 30, recommended 300 for production)
- `Config.HospitalBill` - Money deducted on respawn (default: $500)
- `Config.CashLossPercent` - Additional cash loss percentage on death (default: 0)
- `Config.RespawnCoords` - Hospital respawn position (vector4)
- `Config.DisabledControls` - GTA control IDs disabled while dead
- `Config.DeathTimecycle` / `Config.DeathTimecycleStrength` - Visual effect settings
- `Config.Text` - UI text strings (title, subtitle, killed by, etc.)

## Exports

**Client:**

- `exports['sb_deaths']:IsPlayerDead()` - Returns true if the player is currently dead
- `exports['sb_deaths']:RevivePlayer()` - Revives the local player (triggers the revive event)
