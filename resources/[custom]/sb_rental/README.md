# sb_rental

Vehicle rental system for FiveM. Players can rent bicycles, scooters, and cars from multiple locations with daily rates, late fees, and damage charges.

## Features

- Three vehicle categories: bicycles, scooters, and cars
- Multiple rental locations with configurable available categories per location
- Daily rental pricing with configurable max rental duration
- Grace period before late fees apply
- Late fee multiplier system with escalating penalties
- Stolen vehicle marking after extended late returns
- Automatic vehicle despawn after excessive late period
- Rental blacklist system (temporary ban after despawn)
- Damage charge system based on vehicle body health
- Lost keys fee if keys are not returned with the vehicle
- Return zone markers at each rental location
- NPC-based interaction with sb_target integration
- Clean NUI with vehicle images and category tabs
- Rental plate prefix system (RNT plates)
- Integration with sb_impound - rental vehicles are excluded from impound tracking

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_inventory
- oxmysql

## Installation

1. Place `sb_rental` in your resources folder.
2. Add `ensure sb_rental` to your `server.cfg` after all dependencies.
3. The script manages rental data through the database. Ensure oxmysql is running.

## MLO / Mapping Dependencies

None. All rental locations (Mirror Park, Airport, Bus Depot) use vanilla GTA V map positions. No custom MLO or mapping is required.

## Configuration

All settings are in `config.lua`:

- **Config.NPCModel** - NPC ped model at rental locations.
- **Config.GameDayMinutes** - Real minutes per in-game day (default: 48).
- **Config.MaxRentalDays** - Maximum rental duration in in-game days.
- **Config.GracePeriodMinutes** - Grace period before late fees (real minutes).
- **Config.LateMultiplier** - Late fee multiplier per day late.
- **Config.StolenThresholdDays** - Days late before vehicle is marked stolen.
- **Config.DespawnThresholdDays** - Days late before automatic despawn.
- **Config.BlacklistHours** - Rental ban duration after despawn (real hours).
- **Config.DamageThreshold / Config.DamageRate** - Damage charge settings.
- **Config.LostKeysFee** - Fee if keys are not returned.
- **Config.Vehicles** - Define available vehicles per category with model, label, daily rate, and image.
- **Config.Locations** - Define rental locations with NPC position, spawn points, return zone, available categories, and blip settings.

## Exports

### Client

| Export | Description |
|--------|-------------|
| `GetCurrentRental()` | Get the current active rental data |
| `GetRentalVehicle()` | Get the current rental vehicle entity |
| `IsInRentalVehicle()` | Check if player is in a rental vehicle |
| `GetVehicleProperties(vehicle)` | Get properties of a vehicle |
| `IsRentalMenuOpen()` | Check if the rental NUI is open |
| `GetCurrentLocation()` | Get the current rental location ID |

### Server

| Export | Description |
|--------|-------------|
| `GetRentalVehicleNetId(rentalId)` | Get the network ID of a rental vehicle |
| `ClearRentalVehicle(rentalId)` | Clear a rental vehicle entry |
| `GetPlayerRentals(citizenid)` | Get all rentals for a player |
| `GetActiveRental(citizenid)` | Get the active rental for a player |
| `GetRentalByPlate(plate)` | Get rental data by plate |
| `IsRentalVehicle(plate)` | Check if a plate belongs to a rental vehicle |
