# sb_core

Core framework for SB Framework - a custom-built FiveM roleplay framework by Salah Eddine Boussettah. This is the central backbone that all other sb_* resources depend on. It handles player management, character data, money, jobs, gangs, permissions, callbacks, and database initialization.

## Features

- Full player lifecycle management (connect, load, save, disconnect)
- Multi-character support with unique citizen IDs, phone numbers, and account numbers
- Money system with cash, bank, and crypto accounts
- Job system with grades, on-duty status, and paycheck distribution (every 15 minutes)
- Gang system with grades and boss roles
- Player metadata (hunger, thirst, stress, licenses, gym stats, criminal record, etc.)
- Role-based permission system (user, VIP, moderator, admin, superadmin) with wildcard support
- Server callback system (server-to-client and client-to-server)
- Useable item registration
- Ban system with expiration support (license, Discord, and IP matching)
- VIP system with timed expiration
- Vehicle property save/load with full mod support
- Auto-save every 5 minutes
- Auto-reconnect players after resource restart
- Client utility functions (closest player, closest vehicle, spawn vehicle, animations, etc.)
- Locale/translation system
- Whitelist integration (delegates to sb_whitelist when available)
- Shared data tables for items, jobs, gangs, and vehicles
- Automatic database table creation on first run
- Debug mode with extra logging

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Ensure `oxmysql` is installed and configured with your MySQL database.
2. Place `sb_core` into your resources folder.
3. Optionally import `sb_core.sql` into your database for a clean schema setup. The resource also auto-creates tables on startup if they do not exist.
4. Add the following to your `server.cfg`:

```cfg
set mysql_connection_string "mysql://user:password@localhost/everdaychaos?charset=utf8mb4"

ensure oxmysql
ensure sb_core
```

sb_core must start before any other sb_* resource.

## Configuration

All configuration is in `config.lua`:

| Option | Description | Default |
|---|---|---|
| `Config.ServerName` | Server display name | `"Everyday Chaos RP"` |
| `Config.Discord` | Discord invite link | `"discord.gg/everydaychaos"` |
| `Config.MaxCharacters` | Max character slots per player | `5` |
| `Config.EnableMulticharacter` | Enable multi-character system | `true` |
| `Config.DefaultMoney` | Starting money (cash, bank, crypto) | `{cash=500, bank=0, crypto=0}` |
| `Config.DefaultSpawn` | Default spawn coordinates | Legion Square |
| `Config.DefaultJob` | Starting job for new characters | Unemployed |
| `Config.DefaultGang` | Starting gang for new characters | None |
| `Config.DefaultMetadata` | Starting metadata (hunger, thirst, licenses, gym, etc.) | See config |
| `Config.EnableHunger` | Enable hunger system | `true` |
| `Config.EnableThirst` | Enable thirst system | `true` |
| `Config.HungerRate` | Hunger decrease per minute | `4.2` |
| `Config.ThirstRate` | Thirst decrease per minute | `3.8` |
| `Config.EnablePVP` | Allow player-vs-player damage | `true` |
| `Config.EnableWantedLevel` | Enable GTA wanted system | `false` |
| `Config.NotifyPosition` | Notification position | `"top-right"` |
| `Config.NotifyDuration` | Default notification duration (ms) | `5000` |
| `Config.IdentifierTypes` | Identifier priority order | license, discord, fivem, steam |
| `Config.PlayerSlots` | Per-player slot overrides (keyed by license) | `{}` |
| `Config.Debug` | Enable debug logging | `false` |

### Shared Data

Shared data files in `shared/`:

- `jobs.lua` - Job definitions (police, sheriff, ambulance, mechanic, taxi, trucker, burgershot, cardealer, realestate)
- `gangs.lua` - Gang definitions (ballas, families, vagos, marabunta, lostmc, triads, cartel)
- `items.lua` - Item definitions
- `vehicles.lua` - Vehicle catalog with prices and categories (super, sports, muscle, sedan, SUV, motorcycle, compact)

## Usage

### Server-Side

```lua
local SB = exports['sb_core']:GetCoreObject()

-- Get a player
local Player = SB.Functions.GetPlayer(source)

-- Money
Player.Functions.AddMoney('cash', 1000, 'Paycheck')
Player.Functions.RemoveMoney('bank', 500, 'Purchase')

-- Jobs and gangs
Player.Functions.SetJob('police', 2)
Player.Functions.SetGang('ballas', 1)

-- Metadata
Player.Functions.SetMetaData('hunger', 80)

-- User/account level
local hasPermission = SB.Functions.HasPermission(source, 'admin.kick')
local isVIP, vipLevel = SB.Functions.IsVIP(source)

-- Server callbacks
SB.Functions.CreateCallback('myresource:getData', function(source, cb, arg1)
    cb(result)
end)
```

### Client-Side

```lua
local SB = exports['sb_core']:GetCoreObject()

-- Player data
local PlayerData = SB.Functions.GetPlayerData()
local isLoggedIn = SB.Functions.IsLoggedIn()

-- Server callbacks
SB.Functions.TriggerCallback('myresource:getData', function(result)
    print(result)
end, arg1)

-- Utility
local player, dist = SB.Functions.GetClosestPlayer()
local vehicle, dist = SB.Functions.GetClosestVehicle()
SB.Functions.SpawnVehicle('adder', coords, heading, function(veh) end)
```

## Exports

### Server

| Export | Description |
|---|---|
| `GetCoreObject()` | Returns the full SB core object |
| `GetPlayer(source)` | Get player object by server ID |
| `GetPlayerByCitizenId(citizenid)` | Get player object by citizen ID |
| `GetPlayers()` | Get all active player source IDs |
| `CreateCallback(name, cb)` | Register a server callback |
| `CreateUseableItem(item, cb)` | Register a useable item |
| `GetUser(source)` | Get user account data |
| `HasPermission(source, permission)` | Check if user has a permission |
| `IsVIP(source)` | Check VIP status |
| `GetCharacterSlots(source)` | Get character slot count for a user |

### Client

| Export | Description |
|---|---|
| `GetCoreObject()` | Returns the client-side SB core object |
| `GetPlayerData()` | Returns current player data |
| `IsLoggedIn()` | Returns whether the player is logged in |

## Events

### Server

| Event | Description |
|---|---|
| `SB:Server:OnPlayerLoaded` | Fired when a character is loaded (source, PlayerObj) |
| `SB:Server:OnPlayerUnload` | Fired when a character is unloaded (source) |
| `SB:Server:PlayerDropped` | Fired when a player disconnects (Player, reason) |
| `SB:Server:OnMoneyChange` | Fired on money change (source, type, amount, operation, reason) |
| `SB:Server:OnJobUpdate` | Fired on job change (source, newJob, oldJob) |
| `SB:Server:OnGangUpdate` | Fired on gang change (source, newGang, oldGang) |
| `SB:Server:OnDutyChange` | Fired on duty toggle (source, onDuty) |

### Client

| Event | Description |
|---|---|
| `SB:Client:OnPlayerLoaded` | Fired when character data is received (PlayerData) |
| `SB:Client:OnPlayerUnload` | Fired when character is unloaded |
| `SB:Client:OnMoneyChange` | Fired on money change (type, amount, operation, reason) |
| `SB:Client:OnJobUpdate` | Fired on job change (job) |
| `SB:Client:OnGangUpdate` | Fired on gang change (gang) |
| `SB:Client:OnMetaDataChange` | Fired on metadata change (key, value) |

## Database

The resource creates the following tables automatically:

| Table | Description |
|---|---|
| `users` | Account-level data (one per real player) |
| `roles` | Role definitions with permissions |
| `permission_logs` | Audit trail for permission changes |
| `players` | Character data (multiple per user) |
| `player_vehicles` | Owned vehicles |
| `bans` | Ban records |
| `player_houses` | Property ownership (future) |
| `bank_accounts` | Shared/society bank accounts (future) |

A full schema file is provided at `sb_core.sql` for manual import.

### Default Roles

| Role | Priority | Permissions |
|---|---|---|
| user | 0 | play |
| vip | 10 | play, vip.priority, vip.extras |
| moderator | 50 | play, mod.kick, mod.warn, mod.spectate, mod.teleport |
| admin | 80 | play, admin.*, mod.* |
| superadmin | 100 | * (all permissions) |

## Commands

| Command | Description | Permission |
|---|---|---|
| `/myid` | Shows your server ID | Everyone |
| `/money` | Shows your cash, bank, and crypto balance | Everyone |
| `/me [text]` | RP action visible to nearby players | Everyone |
| `/duty` | Toggle on/off duty for your job | Everyone |

Debug-only commands (when `Config.Debug = true`):

| Command | Description |
|---|---|
| `/debugplayer` | Print full player data to server console |
| `/reloadshared` | Reload shared data |

## File Structure

```
sb_core/
  fxmanifest.lua
  config.lua
  sb_core.sql
  locale/
    en.lua
  shared/
    main.lua
    items.lua
    jobs.lua
    gangs.lua
    vehicles.lua
  server/
    main.lua
    player.lua
    functions.lua
    callbacks.lua
    events.lua
    commands.lua
  client/
    main.lua
    functions.lua
    events.lua
```

## License

Written by Salah Eddine Boussettah for SB Framework.
