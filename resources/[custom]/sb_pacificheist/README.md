# sb_pacificheist

Pacific Standard Bank heist with multi-stage vault breaching, minigames, and synchronized scene animations.

## Features

- **Multi-stage heist flow** - Thermite doors, C4 breaching, laptop hacking, laser drilling, vault entry, loot grabbing, and buyer delivery
- **Scaleform minigames** - Laser drill minigame (scaleform-based) and laptop brute force hacking minigame with lives system
- **Dual vault system** - Main vault and extended vault with separate door mechanics and loot pools
- **Inner vault** - Requires laptop hack followed by C4 to breach the inner vault door
- **Diverse loot types** - Cash stacks, gold stacks, diamond trolleys, cocaine trolleys, drill boxes with random reward items, glass display cases, and paintings
- **Glass cutting and painting theft** - Specialized interactions for high-value display items (panther statue, diamond necklace, vintage wine, rare watch, vault paintings)
- **Heist bag backpack** - Visual clothing component (bag slot) that shows/hides based on inventory and animation state
- **Security guards** - NPC guards at the heist start location
- **Buyer NPC** - Deliver stolen loot to a buyer NPC who converts items to cash or dirty money
- **Server-authoritative loot** - Server-side loot state tracking prevents double-grab exploits
- **Synchronized scene animations** - All heist actions use synchronized scenes for proper player positioning
- **Police count requirement** - Configurable minimum police on duty to start the heist
- **Heist cooldown** - Configurable cooldown between heists (default 2 hours)
- **Door state syncing** - Thermite-melted and C4-destroyed doors sync across all clients
- **Black money mode** - Optional dirty money rewards instead of direct cash

## Dependencies

- `sb_core` - Core framework
- `sb_target` - Interaction targeting
- `sb_notify` - Notification system
- `sb_progressbar` - Progress bar UI
- `sb_inventory` - Inventory system
- `sb_doorlock` - Door lock system
- `oxmysql` - Database

## MLO / Mapping Requirements

- **pacific_bank_extended** (or equivalent Pacific Standard Bank interior MLO) - Required. The heist uses interior coordinates for the Pacific Standard Bank vault area, including an extended vault section with coordinates in the ~250-270 X range. The standard GTA V Pacific Standard interior may not include all areas used by this script. Verify that your Pacific Bank MLO provides both the main vault and extended vault areas.

## Installation

1. Ensure all dependencies are installed and running
2. Ensure you have a Pacific Standard Bank extended interior MLO installed
3. Place `sb_pacificheist` in your resources folder
4. Import `sb_pacificheist.sql` into your database
5. Register all heist items in your inventory system (see Required Items and Reward Items in config)
6. Add `ensure sb_pacificheist` to your server.cfg (after all dependencies)

## Required Items

These items must be registered in your inventory system:

| Config Key | Item Name | Purpose |
|-----------|-----------|---------|
| drill | heist_drill | Laser drill minigame |
| bag | heist_bag | Grabbing loot (also shows backpack) |
| cutter | glass_cutter | Glass cutting and paintings |
| c4 | c4_explosive | Cell gates and vault doors |
| thermite | thermite_charge | Thermite door melting |
| laptop | hacking_laptop | Laptop hacking minigame |
| usb | trojan_usb | Keypad hacking |
| switchblade | switchblade | Painting theft |

## Reward Items

| Item | Sell Price |
|------|-----------|
| gold_bar | $2,500 |
| diamond_pouch | $3,500 |
| cocaine_brick | $1,500 |
| panther_statue | $15,000 |
| diamond_necklace | $12,000 |
| vintage_wine | $8,000 |
| rare_watch | $10,000 |
| vault_painting | $20,000 |

## Configuration

All configuration is in `config.lua`:

- **Heist settings** - Required police count, cooldown (7200s), black money toggle
- **Required items** - Item names for each heist tool
- **Reward items** - Loot items with sell prices, glass cutting rewards, painting rewards, stack rewards, trolley money, drill box count
- **Locations** - Heist start position, buyer location, security guard positions
- **Vault doors** - Thermite/C4 door definitions with positions, swap models, and scene data
- **Vault interactions** - Laptop hack, laser drill, main vault door, extended vault door, inner vault door positions
- **Loot spawns** - Positions for stacks, trolleys, drill boxes, cell gates, glass cutting display, paintings
- **Strings** - All player-facing messages (customizable)
- **Animation dictionaries** - All animation references used during heist actions

## Exports

This script does not expose any exports.
