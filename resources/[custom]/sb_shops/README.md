# sb_shops

General-purpose convenience store (24/7) shop system with NUI interface, category browsing, and cart-based purchasing.

## Features

- NPC shopkeepers spawned at each store location
- NUI shop interface with category tabs (Food, Drinks, Electronics)
- Cart system - add multiple items and purchase in one transaction
- Pays with cash first, falls back to bank
- Carry limit checks before purchase (integrates with sb_inventory)
- Anti-exploit protections: operation locks, cooldowns, cart size limits, input validation
- Map blips for all shop locations
- Phone items get auto-generated serial numbers on purchase
- Bank transactions logged when paying from bank account

## Dependencies

- sb_core
- sb_inventory
- sb_target
- sb_notify
- sb_banking (for bank transaction logging when paying from bank)

## Installation

1. Place `sb_shops` in your resources folder.
2. Add `ensure sb_shops` to your server.cfg (after its dependencies).
3. Items sold in shops must exist in your `sb_items` database table (used by sb_inventory).

## Mapping / Location Notes

All shop locations use standard GTA V 24/7 store interiors. The coordinates in `config.lua` are positioned inside vanilla convenience store interiors - no custom MLO is required. You can add or reposition shops freely.

## Configuration

All settings are in `config.lua`:

- **ShopNPCModel** - Ped model for shopkeepers
- **ShopDistance** - Interaction distance with NPC
- **Blip** - Map blip sprite, color, and scale
- **Shops** - List of shop locations (coords + label)
- **Categories** - Shop category tabs with icons
- **Items** - Items available for sale, each with name, category, and price

To add new items, append to the `Config.Items` table. The item `name` must match an entry in your items database.

## Exports

None. Other scripts interact via the shop NUI or server events.

## License

Part of SB Framework by Salah Eddine Boussettah.
