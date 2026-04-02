# sb_vehicleshop

Vehicle dealership and car key system for FiveM. Players can browse, preview, test drive, and purchase vehicles. Includes a full car key and lock/unlock system.

## Features

- NPC-based vehicle dealership with browsable vehicle catalog
- Vehicle preview with rotating camera in the showroom
- Test drive system with configurable duration and return marker
- License plate generation with configurable format
- Car keys system with lock/unlock (U key), engine toggle (G key), and key fob animation
- Prevents entry to locked owned vehicles without keys
- Engine block for owned vehicles until keys are confirmed
- Vehicle transfer and key sharing between players
- Cash or bank payment support
- Clean NUI with category filtering, vehicle details, and wallet display
- Server-side vehicle spawning with OneSync persistence

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_inventory
- sb_hud
- sb_fuel (optional, for fuel level sync)
- sb_impound (optional, for persistence tracking)
- sb_chat (optional, for command suggestions)
- oxmysql

## Installation

1. Place `sb_vehicleshop` in your resources folder.
2. Add `ensure sb_vehicleshop` to your `server.cfg` after all dependencies.
3. The script uses the `player_vehicles` and `vehicle_history` database tables. Ensure your database schema includes these.

## MLO / Mapping Dependencies

None. The default dealership location at Premium Deluxe Motorsport uses the vanilla GTA V map position (`-54.20, -1104.71, 26.43`). No custom MLO or mapping is required.

## Configuration

All settings are in `config.lua`:

- **Config.RequireLicense** - Whether a driver's license item is required to browse vehicles.
- **Config.LicenseItem** - The item name for the driver's license (default: `car_license`).
- **Config.GiveKeys** - Whether to give car keys on purchase.
- **Config.TestDrive** - Enable/disable test drives, set duration and return radius.
- **Config.Dealerships** - Add or modify dealership locations, NPC models, spawn points, and blips.
- **Config.Vehicles** - Define vehicles available for sale with label, brand, price, category, and which dealerships they appear at.
- **Config.Categories** - Category tabs shown in the UI.
- **Config.PlateFormat** - License plate format (`X` = letter, `0` = digit).
- **Config.InteractDistance** - NPC interaction distance.

## Exports

None exposed. The script communicates via events and callbacks.

## Commands

| Command | Description |
|---------|-------------|
| `/endtestdrive` | End an active test drive early |
| `/togglevehiclelock` (U key) | Lock/unlock nearest owned vehicle |
| `/toggleengine` (G key) | Toggle vehicle engine on/off |
| `/sellvehicle [id] [price]` | Sell your nearby vehicle to another player |
| `/givekey [id]` | Give a copy of your car key to another player |
