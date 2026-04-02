# sb_id

Government ID Card System - City Hall NPC, ID issuance with mugshot, show ID to nearby players.

## Features

- City Hall NPC with sb_target interaction
- ID application with progress bar animation and mugshot capture
- Mugshot uses GTA native headshot system, converted to base64 for persistent storage
- ID card stores: name, citizen ID, date of birth, gender, sex, hair color, eye color, height, weight, blood type, nationality, address, issue/expiry date, mugshot photo
- Physical characteristics auto-detected from ped model (gender, hair color, eye color, height, weight)
- Player enters their address during application
- Card theme selection (stored in metadata)
- ID card expires after configurable days and can be renewed
- View own ID by using the item from inventory
- Show ID to nearest player via `/showid` command
- Using the ID card item auto-shows it to all nearby players within range
- ID purged globally when a new one is issued (prevents duplicates)
- Map blip for City Hall
- NUI card display with mugshot

## Dependencies

- sb_core
- sb_inventory
- sb_target
- sb_notify
- sb_progressbar
- sb_hud (optional, hides HUD when NUI is open)

## Installation

1. Place `sb_id` in your resources folder.
2. Add `ensure sb_id` to your server.cfg (after all dependencies).
3. Register the `id_card` item in your sb_inventory item definitions. It should be a unique/metadata item.

## MLO Requirements

None. The City Hall NPC is placed at the Rockford Hills City Hall area (-553, -191) which is a vanilla GTA V location.

## Configuration

All configuration is in `config.lua`:

- `Config.NPCModel` - NPC ped model at City Hall
- `Config.InteractDistance` - Target interaction range
- `Config.IDCost` - Cost to apply for or renew an ID ($50)
- `Config.ExpiryDays` - Real-world days until the ID expires
- `Config.ShowDistance` - Maximum distance to show ID to another player
- `Config.AutoCloseTime` - Seconds before a shown ID auto-closes
- `Config.Location` - City Hall coordinates and blip settings
- `Config.BloodTypes` - List of possible blood types

## Exports

None.
