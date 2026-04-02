# sb_inventory

Slot-based inventory system with NUI interface, supporting player inventories, vehicle trunks/gloveboxes, stashes, and ground drops.

## Features

- Slot-based inventory with configurable slot counts per inventory type
- Drag-and-drop NUI with item moving, splitting, using, dropping, and giving
- Hotbar system (slots 1-5) with keyboard shortcuts and auto-hiding HUD
- Vehicle trunk and glovebox access with per-vehicle-class capacity
- Ground drop system with world props and automatic despawn
- Stash support for persistent shared/personal storage
- Item use animations per category (food, drink, medical)
- Weapon ammo mapping for integration with sb_weapons
- Item definitions loaded from database (`sb_items` table)
- Full server-side validation - client only sends requests
- Stack support with configurable max stack sizes

## Dependencies

- sb_core
- sb_target
- oxmysql

## Installation

1. Place `sb_inventory` in your resources folder.
2. Add `ensure sb_inventory` to your server.cfg (after its dependencies).
3. Create the `sb_items` table in your database and populate it with your item definitions. Each item needs: `name`, `label`, `type`, `category`, `image`, `stackable`, `max_stack`, `useable`, `shouldClose`, `description`.
4. Item images should be placed in `html/images/` as PNG files.

## Mapping / Location Notes

No specific MLO or mapping required. Vehicle trunk/glovebox access uses GTA V native bone detection. Drop props use the `prop_med_bag_01b` model.

## Configuration

All settings are in `config.lua`:

- **OpenKey** - Keybind to open inventory (default: I)
- **MaxSlots** - Default player inventory slots
- **HotbarSlots** - Number of hotbar slots (keys 1-5)
- **InventoryTypes** - Slot counts per inventory type (player, stash, trunk, glovebox, drop, shop)
- **VehicleClasses** - Trunk slot capacity per GTA V vehicle class
- **GloveboxDefault** - Default glovebox slot count
- **Drops** - Drop prop model, despawn time, max render distance
- **Distances** - Interaction distances for give, drop, trunk, glovebox, stash
- **UI** - Screen blur, animations, hotbar auto-hide timeout
- **UseAnimations** - Per-category item use animations (dict, clip, duration, prop)
- **WeaponAmmo** - Weapon-to-ammo-item mapping for the weapon system

## Exports

**Server-side:**

- `exports['sb_inventory']:AddItem(source, itemName, amount, metadata, slot, silent)` - Add item to player inventory
- `exports['sb_inventory']:RemoveItem(source, itemName, amount, slot)` - Remove item from player inventory
- `exports['sb_inventory']:HasItem(source, itemName, amount)` - Check if player has item
- `exports['sb_inventory']:GetItemCount(source, itemName)` - Get total count of an item
- `exports['sb_inventory']:GetItemData(itemName)` - Get item definition from database
- `exports['sb_inventory']:GetItemsByName(source, itemName)` - Get all instances of an item (with slot and metadata)
- `exports['sb_inventory']:GetCanCarryAmount(source, itemName)` - Check how many more of an item can be carried
- `exports['sb_inventory']:GetFreeSlot(source)` - Get first empty slot number
- `exports['sb_inventory']:SetItemMetadata(source, slot, metadata)` - Update metadata for item at slot
- `exports['sb_inventory']:LoadStash(stashId, slots)` - Load or create a stash
- `exports['sb_inventory']:SaveStash(stashId)` - Save stash to database
- `exports['sb_inventory']:PurgeItemGlobal(itemName)` - Remove an item from all inventories
- `exports['sb_inventory']:SetStashItems(stashId, items)` - Overwrite stash contents

## License

Part of SB Framework by Salah Eddine Boussettah.
