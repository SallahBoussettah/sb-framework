# sb_apartments

MLO-direct apartment rental system for FiveM. Players can rent apartments in multi-unit buildings, lock their doors, use personal stashes and wardrobes, share keys with other players, and use building elevators and garages.

## Features

- MLO-direct apartments (no shell teleportation) - walk directly into your room
- Multiple apartment buildings with tiered pricing (budget, standard, premium, luxury)
- Elevator system with floor selection and travel time animation
- Building garage with tenant-only vehicle storage (integrated with sb_garage vehicle property system)
- Per-unit door locking via sb_doorlock integration
- Personal stash per apartment (slot count based on tier)
- Wardrobe access for changing outfits (via sb_clothing)
- Key sharing - give keys to other players (up to 3 per unit)
- Doorbell system - visitors can ring the bell, tenant decides to let them in
- Rental NPC at building lobbies
- Weekly rent cycle with auto-payment from bank
- Missed payment tracking with configurable eviction threshold
- Deposit system with refund tiers based on payment history
- Grace period and payment reminders before rent is due
- Maximum rentals per player (default: 2)
- Map blips for your rented apartments and buildings
- NUI for browsing available units and managing your rentals
- Routing bucket support prepared for future shell-based mode

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_inventory
- sb_clothing (for wardrobe functionality)
- sb_progressbar
- sb_doorlock (for apartment door locking)
- oxmysql

## Installation

1. Place `sb_apartments` in your resources folder.
2. Add `ensure sb_apartments` to your `server.cfg` after all dependencies.
3. The script requires database tables for apartment rentals. Ensure oxmysql is running.

## MLO / Mapping Dependencies

**This script requires specific MLO/mapping resources for each building:**

- **Del Perro Projects** (`del_perro` building) - Requires the **`del_perro_apartments`** mapping from your `[mappings]` folder. Located at coordinates around `-1564, -405, 42`.
- **The Emissary Hotel** (`the_emissary` building) - Requires the **`the_emissary`** mapping from your `[mappings]` folder. Located at coordinates around `65, -964, 29`.
- **Pink Cage Motel** (`pinkcage_motel` building) - Requires the **`cfx-gabz-pinkcage`** mapping from your `[mappings]` folder. Located at coordinates around `313, -225, 54`. Note: This building currently has no units configured (TODO in config).

Ensure the corresponding mapping resources are started before `sb_apartments`.

## Configuration

All settings are in `config.lua`:

- **Config.RentCycle** - Rent cycle duration in milliseconds (default: 7 days).
- **Config.DepositMultiplier** - Deposit as a multiple of rent (default: 2x).
- **Config.MaxMissedPayments** - Missed payments before eviction (default: 2).
- **Config.MaxKeysPerUnit** - Max key holders per apartment (default: 3).
- **Config.MaxRentals** - Max apartments per player (default: 2).
- **Config.RentCheckInterval** - How often rent is checked (ms).
- **Config.GracePeriod** - Grace period after rent is due (seconds).
- **Config.PaymentReminder** - Time before due date to send reminder (seconds).
- **Config.DoorbellTimeout** - Seconds a tenant has to answer the doorbell.
- **Config.DepositRefund** - Refund percentage based on missed payment count.
- **Config.StashSlots** - Stash slot counts per tier.
- **Config.Blips** - Map blip settings for buildings, owned apartments, key access, and garages.
- **Config.Buildings** - Full building definitions including:
  - Building name, description, tier
  - Entrance coordinates
  - Elevator configuration (floors, travel time, interact radius)
  - Garage configuration (NPC, spawn points, store zone, max vehicles)
  - Unit definitions (label, floor, rent, door position, door model hash, stash position, wardrobe position)

## Exports

### Client

| Export | Description |
|--------|-------------|
| `IsInsideApartment()` | Check if the player is inside an apartment |
| `GetCurrentApartment()` | Get the current apartment unit ID |
| `GetMyRentals()` | Get the player's rented apartments |

### Server

| Export | Description |
|--------|-------------|
| `HasAccess(citizenid, unitId)` | Check if a citizen has access to a unit |
| `GetUnitRenter(unitId)` | Get the citizen ID of the unit's renter |
| `IsInsideApartment(src)` | Check if a player source is inside an apartment |
| `GetApartmentBucket(unitId)` | Get the routing bucket for a unit (shell mode) |
