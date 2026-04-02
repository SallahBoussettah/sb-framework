# sb_whitelist

Whitelist and server password system for SB Framework. Controls access to the server during development or private phases. Works together with sb_core's connection flow to gate player access using adaptive cards in the FiveM connection screen.

## Features

- Master whitelist toggle (enable/disable without restart)
- Server password requirement for non-whitelisted players
- Admin bypass via configurable identifier list
- Whitelist status stored in the `users` table (`is_whitelisted` column)
- Full admin command set for managing whitelist
- Online player whitelist management (by server ID)
- Offline player whitelist management (by license)
- Whitelist status checking
- Runtime password changes
- List all whitelisted players
- Console and in-game command support
- ACE permission integration for admin checks

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql) - Database
- [sb_core](../sb_core) - Creates the `users` table and handles the connection flow

**Important:** sb_whitelist provides exports that sb_core calls during `playerConnecting`. The whitelist check, password card, and waiting screen are all handled inside sb_core's connection events. sb_whitelist only provides the data and admin commands.

## Installation

1. Ensure `oxmysql` and `sb_core` are running.
2. Place `sb_whitelist` into your resources folder.
3. Add `ensure sb_whitelist` to your `server.cfg` (before sb_core, so exports are available when sb_core starts).
4. Edit `config.lua` to set your password and admin identifiers.

## Configuration

All configuration is in `config.lua`:

| Option | Description | Default |
|---|---|---|
| `Config.WhitelistEnabled` | Master toggle for whitelist | `true` |
| `Config.ServerPassword` | Password required for new players to register | `"EChaos2026"` |
| `Config.AdminIdentifiers` | FiveM identifiers that bypass whitelist and password | `{}` |

Set `Config.WhitelistEnabled = false` to run as an open server.
Set `Config.ServerPassword` to `nil` or `""` to disable the password requirement.

## Commands

All commands require admin permission (ACE `command` or matching admin identifier).

| Command | Description |
|---|---|
| `/whitelist add [id]` | Whitelist an online player by server ID |
| `/whitelist remove [id]` | Remove whitelist from an online player |
| `/whitelist addlicense [license]` | Whitelist by license identifier (offline) |
| `/whitelist removelicense [license]` | Remove whitelist by license (offline) |
| `/whitelist check [id]` | Check a player's whitelist status |
| `/whitelist on` | Enable whitelist at runtime |
| `/whitelist off` | Disable whitelist at runtime |
| `/whitelist list` | List all whitelisted players |
| `/whitelist password [newpass]` | View or change the server password |

## Exports

### Server

| Export | Description |
|---|---|
| `IsEnabled()` | Returns whether whitelist is currently enabled |
| `GetPassword()` | Returns the current server password |
| `IsAdminIdentifier(identifiers)` | Checks if any identifier matches the admin list |

## No MLO/Mapping Required

This is a server-side only resource with no in-game world elements.

## License

Written by Salah Eddine Boussettah for SB Framework.
