# sb_burgershot

Burger Shot Job - Full food preparation and sales system for the Burger Shot restaurant.

## Features

- Clock in/out duty system with NPC
- Supply fridge with NUI cart-based purchasing (raw ingredients)
- Multi-stage cooking workflow:
  - Fry Station (potato to fries)
  - Grill Station (raw patty to cooked patty)
  - Burger Assembly (cooked patty + bun + cheese + lettuce + tomato to burger)
  - Drink Station (fountain cola, free to pour)
  - Meal Packing (burger + fries + cola to meal box)
- Service counter with server-side stock tracking
  - Employees stock the counter from their inventory
  - Customers buy items directly (fries, burger, cola, meal)
  - Supports cash and bank payment for customers
- Anti-exploit: operation locks, cooldowns, distance checks, input validation, inventory rollback on failure
- Map blip for Burger Shot location
- Progress bar animations for all cooking actions
- Custom item images for all Burger Shot items

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_progressbar
- sb_inventory
- sb_hud (optional, hides HUD when NUI is open)
- sb_banking (optional, logs bank purchases at the counter)

## Installation

1. Place `sb_burgershot` in your resources folder.
2. Add `ensure sb_burgershot` to your server.cfg (after all dependencies).
3. Register the following items in your sb_inventory item definitions:
   - `bs_raw_patty`, `bs_cooked_patty`, `bs_bun`, `bs_cheese`, `bs_lettuce`, `bs_tomato`, `bs_potato`, `bs_fries`, `bs_burger`, `bs_cola`, `bs_meal`
4. Add the `burgershot` job to your sb_core shared jobs.

## MLO Requirements

**Requires a Burger Shot interior MLO.** The station and interaction coordinates are positioned inside a Burger Shot MLO at the Del Perro Beach location (approximately -1184 to -1201, -894 to -900). You need a Burger Shot MLO that provides an interior at these coordinates. A commonly used one is the Gabz Burger Shot MLO or similar. Without an MLO, the interaction points will be floating in open air.

## Configuration

All configuration is in `config.lua`:

- `Config.Job` - Job name (must match sb_core job definition)
- `Config.Blip` - Map blip coordinates, sprite, color, scale
- `Config.ClockIn` - Clock-in NPC coordinates, model, label
- `Config.SupplyFridge` - Fridge location, items and prices for raw ingredients
- `Config.Stations` - Array of cooking stations, each with coordinates, recipe (inputs/outputs), duration, and animation
- `Config.Counter` - Service counter location and sell prices for finished items

## Exports

None.
