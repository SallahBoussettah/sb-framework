# sb_mechanic

Benny's Original Motorworks - full-service mechanic shop with elevator system, repair stations, vehicle customization, mobile repairs, and invoicing.

**Status:** Superseded by `sb_mechanic_v2`. This version uses a simpler repair model (GTA native health values) without per-component degradation. Kept for reference.

## Features

- **Functional elevator system** - Animated platform with doors, vehicle attachment, wall-mounted and cabin controls, auto-close timer
- **4 workshop stations** - Engine Bay, Body & Paint, Wheels & Tires, Cosmetic Shop, each with dedicated vehicle spots and camera angles
- **Full vehicle customization** - Engine upgrades, turbo, brakes, transmission, suspension, armor (leveled), paint (primary, secondary, pearlescent, custom RGB), liveries, wheel types/styles, neon kits, xenon lights, horns, plate styles, window tint, extras, interior/dashboard colors
- **Duty system** - Clock in/out via NPC, work clothes locker with male/female outfits
- **Parts shelf** - Buy consumable parts (engine parts, body panels, tire kits, upgrade kits, paint/wash supplies) required for services
- **Mobile repair** - On-location engine, body, and tire repairs with reduced max health caps
- **Billing/invoicing** - Laptop-based billing system for customer invoices
- **Service animations** - Per-service-type animations with hand props, hood opening, timed progress bars
- **NUI interface** - HTML/CSS/JS interface for station interactions
- **Worklog tracking** - All services logged to database with mechanic name, plate, price, invoice status

## Dependencies

- `sb_core` - Core framework
- `sb_target` - Interaction targeting
- `sb_notify` - Notifications
- `sb_progressbar` - Progress bars
- `sb_inventory` - Item management
- `sb_alerts` - Alert dialogs
- `sb_garage` - Garage integration
- `oxmysql` - MySQL async queries

## MLO/Mapping Requirements

Designed for **Patoche's Big Benny's Original Motorworks** MLO (or similar Benny's interior). The script references:

- Elevator props: `patoche_elevatorb`, `patoche_elevatorb_door`
- Two-floor layout with upper showroom and lower workshop
- Specific MLO object targeting (e.g., `0x0DD75614` for engine bay station)

Coordinates are centered around `vector3(-205.0, -1310.0, 30.0)` (Benny's Original Motorworks location in South Los Santos).

## Installation

1. Place `sb_mechanic` in your resources folder.
2. Import `sql/mechanic_worklog.sql` into your database.
3. Ensure all dependencies are started before this resource.
4. Add required items (`engine_parts`, `body_panel`, `tire_kit`, `upgrade_kit`, `paint_supplies`, `wash_supplies`) to your items database.
5. Create the `bn-mechanic` job in your job system.
6. Add `ensure sb_mechanic` to your server config.

## Configuration

All configuration is in `config.lua`:

- `Config.JobName` - Mechanic job name (default: `bn-mechanic`)
- `Config.Blip` - Map blip settings
- `Config.Elevators` - Elevator positions, timing, movement parameters
- `Config.DutyNPC` - Duty clock-in NPC model and position
- `Config.WorkClothes` - Work outfit components per gender
- `Config.PartsShelf` - Parts shop items and prices
- `Config.Stations` - Workshop station positions, vehicle spots, camera offsets
- `Config.Pricing` - Service prices for all repair/upgrade/cosmetic types
- `Config.RequiredItems` - Item consumption per service type
- `Config.ServiceAnimations` - Animation dictionaries, props, durations per service
- `Config.MobileRepair` - Max health caps and distance for field repairs

## Database Tables

| Table | Purpose |
|-------|---------|
| `mechanic_worklog` | Service history - plate, service type, price, mechanic, invoice status |

## File Structure

```
sb_mechanic/
  fxmanifest.lua
  config.lua
  client/
    main.lua        - Elevator system, vehicle detection
    duty.lua        - Clock in/out, work clothes
    stations.lua    - Workshop station interactions, NUI bridge
    mobile.lua      - Mobile repair targeting
  server/
    main.lua        - Elevator state management, movement orchestration
    duty.lua        - Duty state persistence
    invoice.lua     - Billing/invoicing logic
    stations.lua    - Service execution, item consumption, mod application
    mobile.lua      - Mobile repair validation
  html/
    index.html      - NUI interface
    style.css       - Styling
    script.js       - Client-side NUI logic
  sql/
    mechanic_worklog.sql
```
