# sb_mma

MMA Arena Betting System - Automated NPC fights with pari-mutuel betting, live fight simulation, and bet history.

## Features

- **Automated fight schedule** at configurable in-game hours (default: 20, 22, 0, 2)
- **State machine flow:** IDLE -> BETTING_OPEN -> FIGHT_IN_PROGRESS -> PAYOUT -> COOLDOWN -> IDLE
- **Pari-mutuel betting** - odds calculated from the total bet pool, capped at configurable maximum
- **Slight underdog bias** - fighters with fewer bets have a slightly higher chance of winning
- Bookmaker NPC with sb_target interaction to open the betting UI
- NUI betting panel with live odds updates, fight state, and bet history
- Fighter peds spawn in the ring with randomized names and models
- Full fight simulation: fighters walk to center, engage in combat, loser goes down, winner celebrates, both return to corners
- Bet history stored in database (last 20 bets viewable per player)
- Admin command `/mma start|stop|status` to manually control fights
- Stop/cancel refunds all active bets
- Anti-exploit: operation locks, bet cooldowns, input validation, one bet per fight per player
- Map blip for the fight club location

## Dependencies

- sb_core
- sb_target
- sb_notify
- oxmysql
- sb_hud (optional, hides HUD when NUI is open)

## Installation

1. Place `sb_mma` in your resources folder.
2. Add `ensure sb_mma` to your server.cfg (after all dependencies).
3. The `mma_bet_history` database table is created automatically on first start.
4. Grant admin access to the `/mma` command via ACE permissions (`command.sb_admin`).

## MLO Requirements

**Requires a fight club / MMA arena MLO.** The fight cage center is at approximately (-68, -1268, 22.8) and the bookmaker NPC is at (-53, -1292, 30.9). These coordinates are underground/interior positions that require an MMA or fight club MLO installed at that location. A commonly used option is the `enzo_fightclub` MLO or similar underground fight arena. Without the MLO, fighter peds will fall through the map or spawn in the wrong location.

## Configuration

All configuration is in `config.lua`:

- `Config.Debug` - Enable debug prints
- `Config.Blip` - Map blip coordinates, sprite, color, scale
- `Config.Timers.Betting` - Betting window duration (ms, default: 60s)
- `Config.Timers.MaxFight` - Maximum fight duration (ms, default: 45s)
- `Config.Timers.Cooldown` - Cooldown between fights (ms, default: 120s)
- `Config.Schedule` - In-game hours when fights auto-start
- `Config.MinBet` / `Config.MaxBet` - Bet amount limits
- `Config.MaxPayoutMultiplier` - Cap on pari-mutuel odds (default: 10x)
- `Config.Bookmakers` - Bookmaker NPC positions, models, labels
- `Config.Fighters` - Fighter slot configuration (spawn positions, health, model pool, name pool)
- `Config.CageCenter` / `Config.CageRadius` - Fight area center and radius
- `Config.AdminCommand` - Admin command name (default: mma)

## Exports

None.
