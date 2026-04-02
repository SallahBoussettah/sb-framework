# sb_dmv

DMV Driving School - Three-stage driving license system with theory exam, parking test, and driving test.

## Features

- **Three-stage license process:**
  1. **Theory Exam** - 10 random questions from a pool of 25+, taken at a desk with NUI. Passing score: 7/10. Costs $500.
  2. **Parking Test** - Drive to a sequence of parking zones with correct heading alignment.
  3. **Driving Test** - Full route through Los Santos with speed limits, stop signs, traffic lights, and seatbelt checks.
- Penalty point system during practical tests (speeding, running stop signs/lights, vehicle damage, missed checkpoints, no seatbelt)
- Auto-fail when penalty points exceed the threshold
- Auto-detection of stop signs and traffic lights from world props
- Speed limits based on road density (highway, main road, city street, residential)
- Speed limiter toggle (X key) locks vehicle to the road speed limit
- Test vehicle spawned automatically for practical tests
- Full stop checkpoints that require the player to come to a complete stop
- Cooldowns on failed attempts (5 min theory, 10 min practical)
- Progress tracked via inventory items (theory cert, parking cert, driver's license)
- License reissue for lost licenses ($1000, requires DB record of passing)
- License card display NUI when using the item
- Receptionist NPC for theory exam and license reissue
- Instructor NPC for practical tests
- Database persistence for license records
- NUI for theory exam questions, results, and license card display

## Dependencies

- oxmysql
- sb_core
- sb_inventory
- sb_target
- sb_notify
- sb_progressbar
- sb_hud (optional, hides HUD when NUI is open)

## Installation

1. Place `sb_dmv` in your resources folder.
2. Add `ensure sb_dmv` to your server.cfg (after all dependencies).
3. The `dmv_licenses` database table is created automatically on first start.
4. Register the following items in your sb_inventory item definitions:
   - `dmv_theory_cert` - Theory exam certificate (temporary progress item)
   - `dmv_parking_cert` - Parking test certificate (temporary progress item)
   - `car_license` - Driver's license (metadata item with citizenid, name, license number, etc.)
   - `car_keys` - Used for test vehicle keys (metadata item)

## MLO Requirements

**Requires a DMV / Driving School MLO.** The receptionist NPC is positioned at approximately (-1101, -1269, 5.2) and the instructor at (-1087, -1260, 5.3), with desk seating, a parking lot, and a test vehicle spawn point in the same area. These coordinates correspond to the Del Perro area and require a DMV MLO installed at that location. Without one, the NPCs and desks will be outdoors or floating. A commonly used option is the `mlo-dmv` or similar DMV driving school MLO.

## Configuration

All configuration is in `config.lua`:

- `Config.TestCost` - Fee for the theory exam ($500)
- `Config.ReissueCost` - Fee to reissue a lost license ($1000)
- `Config.TheoryCooldown` / `Config.PracticalCooldown` - Fail cooldown in seconds
- `Config.PassingScore` - Minimum correct answers to pass theory (7/10)
- `Config.MaxPenaltyPoints` - Practical test fail threshold (30)
- `Config.TestVehicle` - Vehicle model for practical tests (asea)
- `Config.Penalties` - Penalty points per violation type
- `Config.SpeedLimiterKey` - Key to toggle speed limiter (X)
- `Config.AutoDetect` - Stop sign and traffic light detection radii and thresholds
- `Config.SpeedLimits` - Speed limits by road density category
- `Config.Receptionist` - Receptionist NPC model, coordinates, blip
- `Config.Desks` - Seat positions for theory exam
- `Config.Instructor` - Instructor NPC model and coordinates
- `Config.TestVehicleSpawn` - Test vehicle spawn point
- `Config.ParkingZones` - Parking test zone positions, headings, and tolerances
- `Config.RouteCheckpoints` - Driving test route checkpoint positions
- `Config.FullStopCheckpoints` - Indices of checkpoints requiring a full stop
- `Config.Questions` - Pool of theory exam questions with options and correct answers

## Exports

None.
