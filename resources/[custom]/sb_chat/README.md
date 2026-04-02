# sb_chat

Custom proximity-based chat system for FiveM, built for the SB Framework.

## Features

- Proximity-based messaging using character names from sb_core
- Command execution via `/command` syntax directly in chat
- Auto-detection of all registered server commands as suggestions
- Dynamic command suggestion system with Tab completion and arrow key navigation
- Input history with arrow key recall (up to 50 entries)
- Message types: normal proximity, system, staff, action, and custom colored
- Auto-fade messages after configurable timeout
- Chat container auto-hides when no recent messages and chat is closed
- Clean NUI interface with Poppins font and slide-in animations
- Player join announcements
- Other scripts can register suggestions and send messages via exports and events

## Dependencies

- `sb_core` (required, for character name resolution)
- `sb_notify` (optional)

## Installation

1. Place `sb_chat` in your resources directory.
2. Add `ensure sb_chat` to your `server.cfg`.
3. If replacing the default FiveM chat, remove or disable the built-in `chat` resource.

## Configuration

All options are in `config.lua`:

- **OpenKey** - Control ID to open chat (default 245, T key)
- **MaxMessageLength** - Maximum characters per message (default 256)
- **FadeTime** - How long messages stay visible before fading in ms (default 15000)
- **MaxMessages** - Maximum messages stored in history (default 100)
- **ProximityRange** - Distance in game units for proximity messages (default 30.0)

## Exports (Client)

| Export | Description |
|---|---|
| `AddSuggestion(command, description, params)` | Register a command suggestion |
| `RemoveSuggestion(command)` | Remove a command suggestion |
| `SystemMessage(text)` | Display a local system message |

## Exports (Server)

| Export | Description |
|---|---|
| `SendSystemMessage(targetId, text)` | Send a system message to one player |
| `SendSystemMessageAll(text)` | Send a system message to all players |
| `SendStaffMessage(targetId, text, senderName)` | Send a staff message to a player |
| `SendMessage(targetId, sender, text, color, prefix)` | Send a custom colored message |

## Events (Client)

| Event | Description |
|---|---|
| `chat:addSuggestion` | Compatible with default FiveM chat suggestion format |
| `sb_chat:addSuggestion` | SB-specific suggestion registration |
| `sb_chat:receiveMessage` | Receive and display a message |
| `sb_chat:systemMessage` | Display a system message |
| `sb_chat:staffMessage` | Display a staff message |

## No MLO/Mapping Required

This script works anywhere with no mapping dependencies.

## Author

Salah Eddine Boussettah - SB Framework
