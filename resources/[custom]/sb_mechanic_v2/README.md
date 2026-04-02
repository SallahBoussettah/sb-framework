# sb_mechanic_v2

Realistic vehicle condition system with 32-component degradation, OBD-II diagnostic trouble codes, a physics-based symptom engine, skill progression, and bone-targeted repairs.

This is not a typical FiveM mechanic script. Every vehicle tracks 32 individual components that degrade independently based on driving behavior - distance, RPM, hard braking, off-road use, and collisions. Damage cascades between related systems (low oil ruins the engine block, bad wiring kills the ECU). Drivers never see numbers - they feel the car breaking down through handling modifications, engine stalls, steering pull, and brake fade. Mechanics diagnose problems using OBD-II scanners and physical inspections, where their skill level determines what they can detect, understand, and repair.

## The 32-Component Model

Every vehicle condition is stored per-plate in the database with these components, each ranging from 0% to 100%:

**Engine (8):** Engine Block, Spark Plugs, Air Filter, Oil Level, Oil Quality, Coolant Level, Radiator, Turbo

**Transmission (3):** Clutch, Transmission, Transmission Fluid

**Brakes (4):** Front Brake Pads, Rear Brake Pads, Brake Rotors, Brake Fluid

**Suspension (4):** Front Shocks, Rear Shocks, Springs, Wheel Bearings

**Wheels (5):** Alignment, Tire FL, Tire FR, Tire RL, Tire RR

**Body (4):** Body Panels, Windshield, Headlights, Taillights

**Electrical (4):** Alternator, Battery, ECU, Wiring

## Features

### Degradation System

- **Distance-based wear** - Oil, filters, spark plugs, tires, brake pads, coolant, bearings all degrade per kilometer driven
- **High RPM stress** - Engine block, clutch, transmission, oil, coolant, and turbo degrade faster above 80% RPM
- **Hard braking events** - Brake pads, rotors, and fluid degrade on speed drops exceeding 30 km/h
- **Off-road driving** - Shocks, springs, tires, alignment, body panels, and bearings degrade on unpaved surfaces
- **Collision damage** - Dual system: GTA native health sync for engine/body/tires/windshield plus velocity-based crash detection for custom cars with low `fCollisionDamageMult`
- **Splash damage** - Crashes spread damage to radiator, coolant, headlights, taillights, alignment, battery, ECU, wiring, and windshield proportionally
- **Vehicle class multipliers** - 23 GTA vehicle classes each have a degradation multiplier (Super cars at 1.4x, Off-Road at 0.7x, Military at 0.4x, Open Wheel at 1.5x)

### Cascading Damage

Components affect each other when they fall below critical thresholds:

- Bad oil quality damages the engine block and wheel bearings
- Low oil level damages the engine block and turbo
- Low coolant damages the engine block and radiator
- Failing alternator drains the battery
- Degraded transmission fluid damages the transmission and clutch
- Low brake fluid accelerates brake pad wear
- Bad wiring damages the ECU and alternator

### Symptom Engine

Drivers experience damage through physics, not UI elements. The system modifies actual vehicle handling floats proportionally to each car's base values:

- **Power loss** - `fInitialDriveForce` scales down based on engine block, oil level, oil quality, and air filter condition. Limp mode at 5% engine health locks power to 15%.
- **Brake fade** - `fBrakeForce` scales based on brake pads, rotors, and fluid. Severe fluid loss drops braking to 15%.
- **Suspension failure** - `fSuspensionForce`, `fAntiRollBarForce`, and roll center heights change based on shock and spring condition, causing body roll.
- **Traction loss** - `fTractionCurveMin`/`fTractionCurveMax` scale from tire and wheel bearing damage.
- **Steering pull** - `SetVehicleSteerBias` applies a random directional pull when alignment is bad.
- **Gear slip** - `fClutchChangeRateScaleUpShift`/`DownShift` slow down and a momentary power dip fires on every gear change when the clutch is worn.
- **Engine stalls** - Random stalls from bad spark plugs, overheating, or engine damage. Frequency increases with severity.
- **Overheat steam** - Particle effects on the hood when coolant is critically low.
- **Dim/flickering lights** - Battery drains dim headlights, wiring issues cause random flickers.
- **Tire blowouts** - Tires below 8% condition risk blowouts at speed.

All handling modifications are captured on vehicle entry and fully restored on exit.

### Diagnostics (OBD-II Scanner)

- **58 DTC codes** mapped to all 32 components using real OBD-II prefixes (P for powertrain, C for chassis, B for body, U for network/electrical)
- **Skill-gated detection** - Level 1 mechanics detect 40% of active codes, Level 5 detects 100%
- **Progressive detail** - Level 1-2 see vague descriptions ("Engine issue detected"), Level 3+ see specific labels ("Random Misfire Detected"), Level 4+ see severity ratings, Level 5 sees exact condition percentages
- **Repair guidance** - Scanner results show required parts (Level 1+), required tools (Level 2+), skill requirements and location (Level 3+)
- **Obvious damage bypass** - Flat tires, smashed windshields, and crushed body panels are always detected regardless of skill level
- **Pre-scan sync** - Before scanning, the client syncs GTA native state (tire burst, windshield damage) to the server so the scan matches what the mechanic sees

### Physical Inspection

- **7 inspection zones** - Engine, exhaust, undercarriage, body, brakes, suspension, tires
- **Skill-tiered descriptions** - Low skill gets sensory observations ("The engine sounds rough"), mid skill gets specific assessments ("Engine has significant wear"), high skill gets precise technical readouts with percentage values
- **Per-component text** - Every component has unique descriptions at 4 severity tiers (mild, moderate, severe, critical) across 3 skill levels
- **XP-gated by zone category** - Inspecting brakes earns brakes XP, inspecting electrical earns electrical XP

### Repair System

- **30 repair definitions** covering all 32 components (oil change covers both oil_level and oil_quality)
- **Bone-targeted repairs** - Each repair targets a specific vehicle bone (bonnet, wheel_lf, wheel_rf, door_dside_f, windscreen, headlight_l, taillight_l) or the chassis for global access
- **Part + tool requirements** - Most repairs need a specific crafted part and a specific tool. Fluids need only the fluid item. Alignment is tool-only (no part consumed).
- **Skill requirements** - Each repair has a minimum skill level (1-5) in its category
- **Quality-tiered parts** - Parts have 5 quality tiers (Poor to Superior) affecting max restore value (70%-100%) and future degradation rate (1.3x to 0.7x)
- **Workshop vs. field repairs** - Workshop-only repairs require being in the workshop zone. Field repairs are capped at 80% max restore.
- **Minigame integration** - Repairs use timing, precision, or sequence minigames at varying difficulty and round counts
- **Tool durability** - Tools have per-use durability and break after exhaustion
- **Concurrent repair locking** - Two mechanics cannot repair the same component on the same vehicle simultaneously
- **Repair VFX** - Hand props (wrenches, welding torches, jerry cans, tablets), particle effects (welding sparks, electrical sparks, fluid pours)
- **Car jack system** - Lifts vehicle for undercarriage and wheel repairs

### Skill Progression

- **10 XP categories** - Engine, Transmission, Brakes, Suspension, Body, Electrical, Paint, Wheels, Crafting, Diagnostics
- **5 skill levels** per category with increasing XP thresholds (0, 500, 1500, 3500, 7000)
- **XP from all activities** - Repairs, diagnostics scans, physical inspections, crafting
- **Anti-exploit cooldowns** - XP from scans throttled per plate (60s), inspections per plate+zone (30s)
- **Career tracking** - Total jobs completed, successful/failed diagnoses, parts crafted, parts recycled

### Elevator System

- Animated platform with door open/close sequences
- Wall-mounted and cabin controls on each floor
- Vehicle detection and attachment during transit
- Queue system with dwell time
- Configurable movement speed, door animation steps, and timing

### Item System

- **~110 items** across 7 categories: raw materials (32), refined materials (13), finished parts (40+), fluids (5), tools (11), upgrade kits (8), legacy items
- Items auto-register in the database on resource start
- Raw materials include metals (steel, aluminum, copper, iron, titanium, chrome, zinc, lead, bearing steel), non-metals (rubber, plastic, glass, ceramic, carbon fiber, fiberglass, kevlar), electrical (electrode wire, silicon, PCBs, magnets, solder), chemicals (base oil, glycol, brake fluid, additives, UV dye, filter media, friction material, gaskets, adhesive, sandpaper, paint base)

## Dependencies

- `sb_core` - Core framework
- `sb_notify` - Notifications
- `sb_target` - Bone-targeted interactions
- `sb_progressbar` - Repair progress bars
- `sb_inventory` - Item/tool/part management, metadata, durability
- `sb_minigame` - Timing, precision, and sequence minigames for repairs
- `oxmysql` - MySQL async queries

Optional integrations:
- `sb_companies` - Supply chain system for ordering parts (replaces built-in crafting/supplier)
- `sb_admin` - Admin permission checks for `/resetcondition`

## MLO/Mapping Requirements

Designed for **Patoche's Big Benny's Original Motorworks** MLO (or compatible). The script references:

- Elevator props: `patoche_elevatorb`, `patoche_elevatorb_door`
- Two-floor workshop layout (upper floor ~31.0 Z, lower floor ~18.5 Z)
- Workshop zone centered at `vector3(-224.0, -1335.0, 18.5)` with 25m radius

Coordinates are built around the Benny's location at `vector3(-205.0, -1310.0, 30.0)` in South Los Santos.

## Installation

1. Place `sb_mechanic_v2` in your resources folder.
2. Ensure all dependencies are started before this resource.
3. The resource auto-creates its database tables on first start (`vehicle_condition`, `mechanic_skills`).
4. Items are auto-registered in `sb_items` on resource start via `CraftItems.RegisterAll()`.
5. Create mechanic jobs in your job system. Default: `bn-mechanic` and `mechanic` (configurable in `Config.MechanicJobs`).
6. Add `ensure sb_mechanic_v2` to your server config.

If using crafting (original system), also import `items.sql` for item images.

## Configuration

All configuration is in `config.lua`:

- `Config.TelemetryInterval` / `Config.TelemetrySampleRate` / `Config.SymptomTickRate` - Performance tuning for data collection and symptom application
- `Config.DBSaveInterval` - Auto-save frequency for dirty conditions (default 30s)
- `Config.Degradation` - Per-component wear rates for distance, high RPM, hard braking, and off-road driving
- `Config.Collision` - Minimum impact speed, cooldown, splash amplification, velocity crash detection thresholds
- `Config.EngineDegradation` - Safeguard floor (limp mode at 5%), cascading threshold (65% power at 20%)
- `Config.VehicleClassMultiplier` - Degradation scaling per GTA vehicle class (23 entries)
- `Config.Cascading` - Source-to-target damage rules with thresholds and per-second rates
- `Config.Symptoms` - Per-component symptom activation thresholds and effect types
- `Config.Stall` - Stall frequency range and duration
- `Config.XP` - Level thresholds and XP category definitions
- `Config.MechanicJobs` - Table of job names that can use mechanic features
- `Config.QualityTiers` - 5 quality levels with max restore, degradation multiplier, and display colors
- `Config.ToolDurability` - Default durability per tool type
- `Config.MobileRepair` - Max restore cap for outside-workshop repairs
- `Config.RepairCooldown` - Anti-spam cooldown between repairs
- `Config.WorkshopZone` - Center and radius for workshop-only repair validation
- `Config.Blip` / `Config.Elevators` - Map blip and elevator configuration

Repair definitions, DTC codes, component lists, item registries, and repair zones are in `shared/` and can be extended without touching core logic.

## Exports

### Server

| Export | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `GetVehicleCondition` | `plate` | condition table | Get full 32-component condition for a plate |
| `SetComponent` | `plate, component, value` | boolean | Set a specific component to a value (0-100) |
| `DamageComponent` | `plate, component, amount` | boolean | Reduce a component by amount |
| `GetSkills` | `citizenid` | skills table | Get all XP categories and career stats |
| `AddXP` | `citizenid, category, amount` | boolean | Award XP in a category |
| `GetLevel` | `citizenid, category` | number (1-5) | Get skill level for a category |

### Server Callbacks

| Callback | Description |
|----------|-------------|
| `sb_mechanic_v2:getCondition` | Get full condition for a plate |
| `sb_mechanic_v2:setComponent` | Set a component value |
| `sb_mechanic_v2:damageComponent` | Damage a component |
| `sb_mechanic_v2:getSkills` | Get player's skill data |
| `sb_mechanic_v2:scanVehicle` | Run OBD scan, returns DTC results + XP |
| `sb_mechanic_v2:inspectZone` | Physical inspection, returns descriptive texts + XP |
| `sb_mechanic_v2:checkRepairReqs` | Validate repair requirements before starting |
| `sb_mechanic_v2:repairComponent` | Execute a repair (consume parts, restore component, award XP) |
| `sb_mechanic_v2:hasItem` | Check if player has a specific item |
| `sb_mechanic_v2:preScanSyncCB` | Sync native vehicle state before scan |

## Admin Commands

| Command | Description |
|---------|-------------|
| `/resetcondition [plate]` | Reset all components to 100% (admin only, or from server console) |

## Database Tables

| Table | Purpose |
|-------|---------|
| `vehicle_condition` | Per-plate storage of all 32 component values, total km, last oil change km, last service km. Auto-created on start. |
| `mechanic_skills` | Per-citizen XP in 10 categories, career stats (total jobs, diagnoses, parts crafted/recycled). Auto-created on start. |

## File Structure

```
sb_mechanic_v2/
  fxmanifest.lua
  config.lua
  shared/
    components.lua      - 32-component definitions, categories, defaults, lookup tables
    dtc_codes.lua       - 58 OBD-II DTC codes, inspection zones, vague labels
    items_registry.lua  - ~110 item definitions (raw, refined, parts, fluids, tools, upgrades)
    repairs.lua         - 30 repair definitions with parts, tools, bones, skills, minigames, VFX
    repair_zones.lua    - Zone positioning, bone-to-zone mapping, hand prop defaults
  client/
    main.lua            - Vehicle tracking, telemetry collection, condition state management
    degradation.lua     - Client-side native health monitoring, splash damage calculation
    symptoms.lua        - Handling modification engine (power, brakes, suspension, traction, stalls)
    diagnostics.lua     - OBD scanner NUI, physical inspection triggers
    elevator.lua        - Elevator platform, doors, vehicle attachment
    repair.lua          - Repair flow orchestration, minigame integration
    repair_targets.lua  - sb_target bone registration for repairs
    repair_props.lua    - Hand prop attachment and ground prop management
    repair_vfx.lua      - Particle effects (welding sparks, electrical sparks, fluid pours)
    car_jack.lua        - Vehicle lift system for undercarriage/wheel access
  server/
    main.lua            - DB table creation, save loop, resource lifecycle
    condition.lua       - Condition CRUD, telemetry processing, degradation, native sync, exports
    skills.lua          - XP CRUD, level calculation, exports
    diagnostics.lua     - OBD scan logic, physical inspection, skill-gated detection
    repair.lua          - Repair execution, part consumption, tool durability, XP awards
    elevator.lua        - Elevator state management and movement orchestration
  html/
    index.html          - NUI container
    diagnostics.css     - OBD scanner display styling
    diagnostics.js      - Scanner result rendering
```
