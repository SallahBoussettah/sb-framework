# sb_fuel

Immersive fuel system with gas station refueling, jerry cans, vehicle syphoning, and persistent fuel levels.

## Features

- Realistic fuel consumption based on RPM, vehicle class, and per-vehicle multipliers
- Low fuel and critical fuel warnings with sound effects
- Engine stall when fuel runs out (vehicle becomes undriveable)
- Gas station pump interaction via sb_target (nozzle prop, attach to vehicle)
- Pre-authorization payment system (money reserved before refueling, unused portion refunded)
- Jerry can system - carry fuel, pour into vehicles, refill at pumps
- Vehicle syphoning - steal fuel from parked vehicles (requires syphon kit item)
- Fuel persistence via database for player-owned vehicles
- Electric vehicle list (future charging support prepared)
- Per-vehicle-class consumption multipliers (motorcycles are efficient, planes burn fast)
- Map blips for all gas stations
- Admin commands: `/setfuel`, `/givejerrycan`
- Bank transaction logging for fuel purchases

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_progressbar
- sb_inventory
- sb_banking (for bank transaction logging)
- oxmysql

## Installation

1. Place `sb_fuel` in your resources folder.
2. Add `ensure sb_fuel` to your server.cfg (after its dependencies).
3. Your `player_vehicles` database table must have a `fuel` column (FLOAT or DECIMAL). If it does not exist, add it: `ALTER TABLE player_vehicles ADD COLUMN fuel FLOAT DEFAULT 100.0;`
4. The `jerrycan` and `syphon_kit` items must exist in your `sb_items` database table.

## Mapping / Location Notes

Gas station locations use standard GTA V gas station positions across Los Santos and Blaine County. Pump interaction targets built-in GTA V pump prop models (`prop_gas_pump_1a` through `prop_gas_pump_1d`, plus vintage and short variants). **No custom MLO is required.**

## Configuration

All settings are in `config.lua`:

- **FuelPrice** - Price per liter at pumps
- **DefaultFuel** - Default fuel for newly spawned vehicles
- **RefuelRate** - Liters per second when refueling at a pump
- **LowFuelWarning / CriticalFuelWarning** - Warning thresholds (percentage)
- **EngineStallThreshold** - Below this percentage, engine stalls
- **BaseConsumption / IdleConsumption** - Fuel burn rates
- **ConsumptionInterval** - How often consumption is calculated (ms)
- **ClassMultipliers** - Per-vehicle-class fuel consumption multipliers
- **JerryCan** - Item name, max capacity, pour rate, refill price, prop model, animation
- **Syphon** - Enable/disable, required item, duration, restrictions (owned vehicles, occupied vehicles)
- **Nozzle** - Prop model, bone attachment, max distance from pump, attach distance to vehicle
- **PumpModels** - GTA V pump prop models to target
- **Stations** - Gas station locations with id, label, coords, blip toggle, and type (gas/electric)
- **Blip** - Map blip sprite, color, scale
- **Sounds** - Sound effects for nozzle, refueling, low fuel, payment, engine stall
- **ElectricVehicles** - List of electric vehicle model names
- **Electric** - Future electric charging settings (disabled by default)

## Exports

**Client-side:**

- `exports['sb_fuel']:GetFuel(vehicle)` - Get fuel level for a vehicle (percentage)
- `exports['sb_fuel']:SetFuel(vehicle, level)` - Set fuel level for a vehicle
- `exports['sb_fuel']:AddFuel(vehicle, amount)` - Add fuel to a vehicle
- `exports['sb_fuel']:IsOutOfFuel(vehicle)` - Check if vehicle is out of fuel
- `exports['sb_fuel']:GetCurrentVehicleFuel()` - Get fuel level of the vehicle the player is currently driving

**Server-side:**

- `exports['sb_fuel']:GetVehicleFuel(netId)` - Get vehicle fuel from server cache
- `exports['sb_fuel']:SetVehicleFuel(netId, fuel)` - Set vehicle fuel in server cache

## License

Part of SB Framework by Salah Eddine Boussettah.
