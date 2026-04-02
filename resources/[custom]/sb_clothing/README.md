# sb_clothing

Clothing store system for FiveM. Players can browse, preview, and purchase clothing at multiple store types with different price tiers. Supports both vanilla and addon clothing with a full outfit save/load system.

## Features

- Multiple store types with price multipliers: Ponsonbys (2x), Suburban (1x), Binco (0.5x), Discount (0.3x)
- 8 store locations across the map
- NPC-based interaction with sb_target integration
- Full clothing browser with category tabs (Tops, Pants, Shoes, Accessories, Masks, Armor, Hats, Glasses, Watches, Extras)
- Live preview with rotating camera, zoom, and height adjustment
- Component and prop browsing with texture variants
- Addon clothing support - configurable to show only custom clothing (hide vanilla GTA clothes)
- Configurable vanilla drawable counts per gender for accurate addon filtering
- Save and load up to 5 outfits per character
- Free torso component changes (for fixing clipping issues)
- Store reservation system - one player per changing spot
- Cancel reverts to original appearance
- Cash or bank payment
- Clean NUI with price display and category filtering

## Dependencies

- sb_core
- sb_target
- sb_notify
- oxmysql

## Installation

1. Place `sb_clothing` in your resources folder.
2. Add `ensure sb_clothing` to your `server.cfg` after all dependencies.
3. If using addon clothing packs, update the `Config.VanillaDrawables` and `Config.VanillaProps` values in `config.lua` with your exact vanilla counts (see the instructions in the config file).

## MLO / Mapping Dependencies

None. All clothing store locations use vanilla GTA V store interiors. No custom MLO or mapping is required.

## Configuration

All settings are in `config.lua`:

- **Config.Stores** - Store locations with coordinates, type, label, changing spot position, and camera position.
- **Config.PriceMultiplier** - Price multiplier per store type.
- **Config.NPCModel** - Store NPC model.
- **Config.Blip** - Map blip settings.
- **Config.BasePrices** - Base price per clothing component/prop type.
- **Config.Categories** - UI category tabs with associated component/prop IDs.
- **Config.FreeComponents** - Components that are free (e.g. torso for clipping fixes).
- **Config.HideVanillaClothing** - Toggle to only show addon clothing.
- **Config.VanillaDrawables** - Vanilla drawable counts per component per gender (for addon filtering).
- **Config.VanillaProps** - Vanilla prop counts per prop type per gender.
- **Config.Camera** - Camera FOV, zoom speed, rotation speed, and offset settings.
- **Config.MaxSavedOutfits** - Max saved outfits per character.

## Exports

### Client

| Export | Description |
|--------|-------------|
| `GetCurrentAppearance()` | Get the player's current clothing appearance data |
| `ApplyAppearance(appearance)` | Apply a saved appearance to the player |

### Server

| Export | Description |
|--------|-------------|
| `GetPlayerOutfits(citizenid)` | Get all saved outfits for a character |
