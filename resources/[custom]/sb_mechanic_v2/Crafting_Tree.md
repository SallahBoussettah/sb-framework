# Crafting Tree — sb_mechanic_v2

> **Everyday Chaos RP** | Author: Salah Eddine Boussettah
> Full dependency map for every craftable item — from raw supplier materials to endgame upgrade kits.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| `[S]` | **Supplier** — purchased from supplier NPC |
| `[R]` | **Refined** — crafted from raw materials (Tier 1) |
| `[P]` | **Part** — crafted from refined + raw materials (Tier 2) |
| `[F]` | **Fluid** — mixed at fluid station (Tier 1) |
| `[T]` | **Tool** — crafted from refined materials (Tier 2) |
| `[U]` | **Upgrade Kit** — endgame crafting from finished parts (Tier 3) |
| `L#` | Minimum crafting skill level required |

---

## Tier 0 — Raw Materials (32 items, bought from Supplier)

### Metals (9)
| Item | Label | Price | Used In |
|------|-------|-------|---------|
| `raw_steel` | Steel Stock | $15 | steel_plate, friction_pad, bearing_set, brake_rotors, tire, tire_performance, tire_offroad, springs |
| `raw_aluminum` | Aluminum Ingot | $20 | aluminum_sheet |
| `raw_copper` | Copper Rod | $25 | copper_wire |
| `raw_iron` | Cast Iron Block | $18 | engine_block, brake_rotors |
| `raw_titanium` | Titanium Bar | $120 | upgrade_turbo, upgrade_exhaust |
| `raw_chrome` | Chrome Stock | $35 | chrome_finish |
| `raw_zinc` | Zinc Ingot | $12 | chrome_finish |
| `raw_lead` | Lead Block | $10 | battery |
| `raw_bearing_steel` | Bearing Steel | $30 | bearing_set |

### Non-Metals (7)
| Item | Label | Price | Used In |
|------|-------|-------|---------|
| `raw_rubber` | Rubber Compound | $12 | rubber_sheet |
| `raw_plastic` | ABS Plastic Pellets | $8 | plastic_housing, wire_harness |
| `raw_glass` | Glass Blank | $18 | glass_panel |
| `raw_ceramic` | Ceramic Compound | $22 | spark_plugs |
| `raw_carbon` | Carbon Fiber Sheet | $80 | carbon_panel, tire_performance |
| `raw_fiberglass` | Fiberglass Mat | $25 | body_panel |
| `raw_kevlar` | Kevlar Fabric | $90 | tire_offroad |

### Electrical (5)
| Item | Label | Price | Used In |
|------|-------|-------|---------|
| `raw_electrode` | Electrode Wire | $15 | spark_plugs |
| `raw_silicon` | Silicon Wafer | $40 | circuit_assembly |
| `raw_circuit_board` | Blank PCB | $45 | circuit_assembly |
| `raw_magnet` | Rare Earth Magnet | $35 | alternator, starter |
| `raw_solder` | Solder Wire | $10 | circuit_assembly |

### Chemical / Fluid Base (5)
| Item | Label | Price | Used In |
|------|-------|-------|---------|
| `raw_oil` | Base Oil | $8 | fluid_motor_oil, fluid_trans, fluid_power_steering |
| `raw_glycol` | Ethylene Glycol | $10 | fluid_coolant |
| `raw_brake_fluid` | DOT4 Fluid Base | $12 | fluid_brake |
| `raw_additive` | Oil Additive Pack | $15 | fluid_motor_oil, fluid_trans, fluid_power_steering |
| `raw_dye` | UV Dye Concentrate | $5 | fluid_coolant |

### Consumable Craft (6)
| Item | Label | Price | Used In |
|------|-------|-------|---------|
| `raw_filter_media` | Filter Media | $10 | air_filter |
| `raw_friction_material` | Friction Material | $18 | friction_pad |
| `raw_gasket_material` | Gasket Sheet | $14 | gasket_set |
| `raw_adhesive` | Industrial Adhesive | $12 | carbon_panel, chrome_finish, windshield |
| `raw_sandpaper` | Abrasive Paper Pack | $6 | body_panel, fender |
| `raw_paint_base` | Paint Base | $20 | fender |

---

## Tier 1 — Refined Materials (13 items)

Each refined material is crafted from raw materials at a workbench.

```
raw_steel x3 ──────────────────────────> steel_plate x2          [L1] Metal Bench
raw_aluminum x3 ───────────────────────> aluminum_sheet x2       [L1] Metal Bench
raw_copper x2 ─────────────────────────> copper_wire x3          [L1] Electronics Bench
raw_rubber x3 ─────────────────────────> rubber_sheet x2         [L1] Metal Bench
raw_plastic x3 ────────────────────────> plastic_housing x2      [L1] Metal Bench
raw_glass x2 ──────────────────────────> glass_panel x1          [L2] Metal Bench
raw_carbon x2 + raw_adhesive x1 ──────> carbon_panel x1         [L3] Metal Bench
raw_friction_material x2 + raw_steel x1 > friction_pad x4       [L1] Metal Bench
raw_gasket_material x2 ───────────────> gasket_set x2            [L1] Metal Bench
raw_bearing_steel x2 + raw_steel x1 ──> bearing_set x2          [L2] Metal Bench
raw_circuit_board + raw_silicon         circuit_assembly x1      [L2] Electronics Bench
  + raw_solder x2 ────────────────────>
raw_chrome x2 + raw_zinc x1            chrome_finish x1         [L2] Metal Bench
  + raw_adhesive x1 ──────────────────>
copper_wire x3 + raw_plastic x1 ──────> wire_harness x1         [L2] Electronics Bench
```

---

## Tier 1 — Fluids (5 items, Fluid Station, no minigame)

```
raw_oil x3 + raw_additive x1 ─────────> fluid_motor_oil x2      [L1]
raw_glycol x3 + raw_dye x1 ───────────> fluid_coolant x2        [L1]
raw_brake_fluid x3 ───────────────────> fluid_brake x2           [L1]
raw_oil x2 + raw_additive x2 ─────────> fluid_trans x2           [L1]
raw_oil x2 + raw_additive x1 ─────────> fluid_power_steering x2  [L1]
```

---

## Tier 2 — Finished Parts (37 items)

### Engine Parts (11) — Engine Bench

```
part_spark_plugs          [L1]  5s
├── raw_ceramic x4
├── raw_electrode x2
└── copper_wire x1 [R]

part_air_filter           [L1]  3s
├── raw_filter_media x3
└── rubber_sheet x1 [R]

part_water_pump           [L2]  7s
├── aluminum_sheet x2 [R]
├── gasket_set x1 [R]
└── rubber_sheet x1 [R]

part_timing_belt          [L2]  6s
├── rubber_sheet x2 [R]
├── steel_plate x1 [R]
└── bearing_set x1 [R]

part_oil_pump             [L3]  8s
├── steel_plate x2 [R]
├── gasket_set x1 [R]
└── bearing_set x1 [R]

part_fuel_pump            [L3]  8s
├── steel_plate x1 [R]
├── copper_wire x2 [R]
├── plastic_housing x1 [R]
└── rubber_sheet x1 [R]

part_intake               [L3]  8s
├── aluminum_sheet x3 [R]
├── rubber_sheet x2 [R]
└── gasket_set x1 [R]

part_radiator             [L3]  10s
├── aluminum_sheet x4 [R]
├── copper_wire x2 [R]
├── plastic_housing x2 [R]
└── gasket_set x1 [R]

part_turbo                [L4]  15s
├── steel_plate x3 [R]
├── aluminum_sheet x2 [R]
├── bearing_set x2 [R]
└── gasket_set x1 [R]

part_engine_block         [L5]  20s
├── raw_iron x4 [S]
├── steel_plate x4 [R]
├── aluminum_sheet x4 [R]
├── gasket_set x3 [R]
├── bearing_set x2 [R]
└── copper_wire x2 [R]
```

### Exhaust — Metal Bench

```
part_exhaust              [L3]  10s
├── steel_plate x4 [R]
├── aluminum_sheet x2 [R]
└── gasket_set x2 [R]
```

### Transmission Parts (2) — Engine Bench

```
part_clutch               [L3]  10s
├── steel_plate x3 [R]
├── friction_pad x4 [R]
├── bearing_set x1 [R]
└── gasket_set x1 [R]

part_transmission         [L5]  20s
├── steel_plate x5 [R]
├── aluminum_sheet x3 [R]
├── bearing_set x3 [R]
└── gasket_set x2 [R]
```

### Electrical Parts (5) — Electronics Bench

```
part_battery              [L2]  6s
├── raw_lead x3 [S]
├── plastic_housing x2 [R]
└── copper_wire x1 [R]

part_alternator           [L3]  8s
├── copper_wire x4 [R]
├── raw_magnet x2 [S]
├── steel_plate x1 [R]
└── bearing_set x1 [R]

part_starter              [L3]  8s
├── copper_wire x3 [R]
├── raw_magnet x2 [S]
├── steel_plate x1 [R]
└── plastic_housing x1 [R]

part_wiring               [L3]  8s
├── wire_harness x2 [R]
├── copper_wire x2 [R]
└── plastic_housing x1 [R]

part_ecu                  [L4]  12s
├── circuit_assembly x2 [R]
├── copper_wire x3 [R]
└── plastic_housing x1 [R]
```

### Brake Parts (3) — Metal Bench

```
part_brake_pads           [L1]  5s
├── friction_pad x4 [R]
└── steel_plate x1 [R]

part_brake_rotors         [L2]  8s
├── raw_iron x3 [S]
├── steel_plate x2 [R]
└── raw_steel x2 [S]

part_brake_caliper        [L3]  10s
├── aluminum_sheet x3 [R]
├── steel_plate x2 [R]
├── rubber_sheet x1 [R]
└── gasket_set x1 [R]
```

### Suspension Parts (7) — Metal Bench

```
part_tie_rod              [L2]  5s
├── steel_plate x2 [R]
└── rubber_sheet x1 [R]

part_springs              [L2]  7s
├── raw_steel x4 [S]
└── steel_plate x2 [R]

part_wheel_bearings       [L2]  6s
├── bearing_set x2 [R]
└── rubber_sheet x1 [R]

part_ball_joint           [L2]  6s
├── steel_plate x2 [R]
├── bearing_set x1 [R]
└── rubber_sheet x1 [R]

part_shocks               [L2]  8s
├── steel_plate x3 [R]
├── rubber_sheet x2 [R]
└── gasket_set x1 [R]

part_cv_joint             [L3]  8s
├── steel_plate x2 [R]
├── bearing_set x1 [R]
└── rubber_sheet x2 [R]

part_control_arm          [L3]  8s
├── steel_plate x3 [R]
├── rubber_sheet x2 [R]
└── bearing_set x1 [R]
```

### Body & Lights (5) — Metal/Electronics Bench

```
part_body_panel           [L2]  8s   Metal Bench
├── steel_plate x4 [R]
├── raw_fiberglass x2 [S]
└── raw_sandpaper x2 [S]

part_fender               [L2]  7s   Metal Bench
├── steel_plate x3 [R]
├── raw_paint_base x1 [S]
└── raw_sandpaper x1 [S]

part_windshield           [L3]  8s   Metal Bench
├── glass_panel x2 [R]
├── rubber_sheet x2 [R]
└── raw_adhesive x1 [S]

part_headlights           [L2]  7s   Electronics Bench
├── glass_panel x1 [R]
├── plastic_housing x1 [R]
├── copper_wire x2 [R]
└── chrome_finish x1 [R]

part_taillights           [L2]  6s   Electronics Bench
├── plastic_housing x2 [R]
├── copper_wire x1 [R]
└── circuit_assembly x1 [R]
```

### Tires (3) — Tire Machine

```
part_tire                 [L1]  6s
├── rubber_sheet x4 [R]
└── raw_steel x1 [S]

part_tire_offroad         [L2]  7s
├── rubber_sheet x5 [R]
├── raw_kevlar x1 [S]
└── raw_steel x1 [S]

part_tire_performance     [L3]  8s
├── rubber_sheet x4 [R]
├── raw_carbon x1 [S]
└── raw_steel x1 [S]
```

---

## Tier 2 — Tools (11 items)

### Metal Bench Tools (7)

```
tool_tire_machine         [L1]  5s
├── steel_plate x3 [R]
└── chrome_finish x1 [R]

tool_brake_bleeder        [L2]  6s
├── plastic_housing x2 [R]
└── rubber_sheet x2 [R]

tool_wrench_set           [L2]  8s
├── steel_plate x4 [R]
└── chrome_finish x1 [R]

tool_jack                 [L2]  8s
├── steel_plate x5 [R]
├── rubber_sheet x2 [R]
└── gasket_set x1 [R]

tool_torque_wrench        [L3]  10s
├── steel_plate x3 [R]
├── chrome_finish x1 [R]
└── rubber_sheet x1 [R]

tool_welding_kit          [L3]  10s
├── steel_plate x3 [R]
├── copper_wire x3 [R]
└── rubber_sheet x1 [R]

tool_compression_tester   [L3]  8s
├── steel_plate x2 [R]
├── rubber_sheet x2 [R]
└── gasket_set x1 [R]

tool_paint_gun            [L3]  8s
├── aluminum_sheet x2 [R]
├── chrome_finish x1 [R]
└── rubber_sheet x1 [R]
```

### Electronics Bench Tools (3)

```
tool_multimeter           [L3]  8s
├── circuit_assembly x1 [R]
├── plastic_housing x1 [R]
└── copper_wire x2 [R]

tool_alignment_gauge      [L3]  8s
├── circuit_assembly x1 [R]
├── aluminum_sheet x2 [R]
└── glass_panel x1 [R]

tool_diagnostic           [L4]  12s
├── circuit_assembly x2 [R]
├── plastic_housing x1 [R]
└── copper_wire x2 [R]
```

---

## Tier 3 — Upgrade Kits (8 items, endgame)

These are the final crafting tier. Each requires a finished part + premium materials.

```
upgrade_exhaust           [L3]  10s  Metal Bench
├── part_exhaust x1 [P]
├── raw_titanium x1 [S]
├── steel_plate x3 [R]
└── chrome_finish x2 [R]

upgrade_intake            [L3]  10s  Engine Bench
├── part_intake x1 [P]
├── carbon_panel x1 [R]
└── aluminum_sheet x2 [R]

upgrade_brakes            [L4]  12s  Metal Bench
├── part_brake_rotors x2 [P]
├── part_brake_caliper x2 [P]
└── carbon_panel x1 [R]

upgrade_suspension        [L4]  12s  Metal Bench
├── part_shocks x2 [P]
├── part_springs x2 [P]
└── steel_plate x3 [R]

upgrade_engine            [L5]  20s  Engine Bench
├── part_engine_block x1 [P]
├── carbon_panel x2 [R]
└── steel_plate x4 [R]

upgrade_transmission      [L5]  18s  Engine Bench
├── part_transmission x1 [P]
├── carbon_panel x1 [R]
└── bearing_set x3 [R]

upgrade_turbo             [L5]  18s  Engine Bench
├── part_turbo x1 [P]
├── raw_titanium x2 [S]
├── carbon_panel x2 [R]
└── aluminum_sheet x3 [R]

upgrade_ecu               [L5]  15s  Electronics Bench
├── part_ecu x1 [P]
├── circuit_assembly x3 [R]
└── copper_wire x2 [R]
```

---

## Full Dependency Chains (Supplier-to-Upgrade)

The deepest crafting chains traced from raw materials to endgame upgrades.

### upgrade_engine (deepest: 3 tiers)

```
UPGRADE_ENGINE [L5]
└── part_engine_block [L5]
│   ├── raw_iron x4 ..................... $18 ea = $72
│   ├── steel_plate x4 [R]
│   │   └── raw_steel x6 ............... $15 ea = $90
│   ├── aluminum_sheet x4 [R]
│   │   └── raw_aluminum x6 ............ $20 ea = $120
│   ├── gasket_set x3 [R]
│   │   └── raw_gasket_material x4 ..... $14 ea = $56
│   ├── bearing_set x2 [R]
│   │   ├── raw_bearing_steel x2 ....... $30 ea = $60
│   │   └── raw_steel x1 ............... $15 ea = $15
│   └── copper_wire x2 [R]
│       └── raw_copper x2 .............. $25 ea = $50
├── carbon_panel x2 [R]
│   ├── raw_carbon x4 .................. $80 ea = $320
│   └── raw_adhesive x2 ................ $12 ea = $24
└── steel_plate x4 [R]
    └── raw_steel x6 ................... $15 ea = $90
                              RAW COST TOTAL ≈ $897
```

### upgrade_transmission

```
UPGRADE_TRANSMISSION [L5]
└── part_transmission [L5]
│   ├── steel_plate x5 [R]
│   │   └── raw_steel x8 ............... $15 ea = $120
│   ├── aluminum_sheet x3 [R]
│   │   └── raw_aluminum x5 ............ $20 ea = $100
│   ├── bearing_set x3 [R]
│   │   ├── raw_bearing_steel x4 ....... $30 ea = $120
│   │   └── raw_steel x2 ............... $15 ea = $30
│   └── gasket_set x2 [R]
│       └── raw_gasket_material x2 ..... $14 ea = $28
├── carbon_panel x1 [R]
│   ├── raw_carbon x2 .................. $80 ea = $160
│   └── raw_adhesive x1 ................ $12 ea = $12
└── bearing_set x3 [R]
    ├── raw_bearing_steel x4 ........... $30 ea = $120
    └── raw_steel x2 ................... $15 ea = $30
                              RAW COST TOTAL ≈ $720
```

### upgrade_turbo

```
UPGRADE_TURBO [L5]
└── part_turbo [L4]
│   ├── steel_plate x3 [R]
│   │   └── raw_steel x5 ............... $15 ea = $75
│   ├── aluminum_sheet x2 [R]
│   │   └── raw_aluminum x3 ............ $20 ea = $60
│   ├── bearing_set x2 [R]
│   │   ├── raw_bearing_steel x2 ....... $30 ea = $60
│   │   └── raw_steel x1 ............... $15 ea = $15
│   └── gasket_set x1 [R]
│       └── raw_gasket_material x1 ..... $14 ea = $14
├── raw_titanium x2 .................... $120 ea = $240
├── carbon_panel x2 [R]
│   ├── raw_carbon x4 .................. $80 ea = $320
│   └── raw_adhesive x2 ................ $12 ea = $24
└── aluminum_sheet x3 [R]
    └── raw_aluminum x5 ................ $20 ea = $100
                              RAW COST TOTAL ≈ $908
```

### upgrade_ecu

```
UPGRADE_ECU [L5]
└── part_ecu [L4]
│   ├── circuit_assembly x2 [R]
│   │   ├── raw_circuit_board x2 ....... $45 ea = $90
│   │   ├── raw_silicon x2 ............. $40 ea = $80
│   │   └── raw_solder x4 .............. $10 ea = $40
│   ├── copper_wire x3 [R]
│   │   └── raw_copper x2 .............. $25 ea = $50
│   └── plastic_housing x1 [R]
│       └── raw_plastic x2 ............. $8 ea  = $16
├── circuit_assembly x3 [R]
│   ├── raw_circuit_board x3 ........... $45 ea = $135
│   ├── raw_silicon x3 ................. $40 ea = $120
│   └── raw_solder x6 .................. $10 ea = $60
└── copper_wire x2 [R]
    └── raw_copper x2 .................. $25 ea = $50
                              RAW COST TOTAL ≈ $641
```

### upgrade_brakes

```
UPGRADE_BRAKES [L4]
├── part_brake_rotors x2 [P]
│   ├── raw_iron x6 .................... $18 ea = $108
│   ├── steel_plate x4 [R]
│   │   └── raw_steel x6 ............... $15 ea = $90
│   └── raw_steel x4 ................... $15 ea = $60
├── part_brake_caliper x2 [P]
│   ├── aluminum_sheet x6 [R]
│   │   └── raw_aluminum x9 ............ $20 ea = $180
│   ├── steel_plate x4 [R]
│   │   └── raw_steel x6 ............... $15 ea = $90
│   ├── rubber_sheet x2 [R]
│   │   └── raw_rubber x3 .............. $12 ea = $36
│   └── gasket_set x2 [R]
│       └── raw_gasket_material x2 ..... $14 ea = $28
└── carbon_panel x1 [R]
    ├── raw_carbon x2 .................. $80 ea = $160
    └── raw_adhesive x1 ................ $12 ea = $12
                              RAW COST TOTAL ≈ $764
```

### upgrade_suspension

```
UPGRADE_SUSPENSION [L4]
├── part_shocks x2 [P]
│   ├── steel_plate x6 [R]
│   │   └── raw_steel x9 ............... $15 ea = $135
│   ├── rubber_sheet x4 [R]
│   │   └── raw_rubber x6 .............. $12 ea = $72
│   └── gasket_set x2 [R]
│       └── raw_gasket_material x2 ..... $14 ea = $28
├── part_springs x2 [P]
│   ├── raw_steel x8 ................... $15 ea = $120
│   └── steel_plate x4 [R]
│       └── raw_steel x6 ............... $15 ea = $90
└── steel_plate x3 [R]
    └── raw_steel x5 ................... $15 ea = $75
                              RAW COST TOTAL ≈ $520
```

### upgrade_exhaust

```
UPGRADE_EXHAUST [L3]
├── part_exhaust [L3]
│   ├── steel_plate x4 [R]
│   │   └── raw_steel x6 ............... $15 ea = $90
│   ├── aluminum_sheet x2 [R]
│   │   └── raw_aluminum x3 ............ $20 ea = $60
│   └── gasket_set x2 [R]
│       └── raw_gasket_material x2 ..... $14 ea = $28
├── raw_titanium x1 .................... $120 ea = $120
├── steel_plate x3 [R]
│   └── raw_steel x5 ................... $15 ea = $75
└── chrome_finish x2 [R]
    ├── raw_chrome x4 .................. $35 ea = $140
    ├── raw_zinc x2 .................... $12 ea = $24
    └── raw_adhesive x2 ................ $12 ea = $24
                              RAW COST TOTAL ≈ $561
```

### upgrade_intake

```
UPGRADE_INTAKE [L3]
├── part_intake [L3]
│   ├── aluminum_sheet x3 [R]
│   │   └── raw_aluminum x5 ............ $20 ea = $100
│   ├── rubber_sheet x2 [R]
│   │   └── raw_rubber x3 .............. $12 ea = $36
│   └── gasket_set x1 [R]
│       └── raw_gasket_material x1 ..... $14 ea = $14
├── carbon_panel x1 [R]
│   ├── raw_carbon x2 .................. $80 ea = $160
│   └── raw_adhesive x1 ................ $12 ea = $12
└── aluminum_sheet x2 [R]
    └── raw_aluminum x3 ................ $20 ea = $60
                              RAW COST TOTAL ≈ $382
```

---

## Upgrade Kit Cost Rankings

| Rank | Upgrade Kit | Raw Cost | Skill Req | Craft Time |
|------|-------------|----------|-----------|------------|
| 1 | upgrade_turbo | ~$908 | L5 | 18s |
| 2 | upgrade_engine | ~$897 | L5 | 20s |
| 3 | upgrade_brakes | ~$764 | L4 | 12s |
| 4 | upgrade_transmission | ~$720 | L5 | 18s |
| 5 | upgrade_ecu | ~$641 | L5 | 15s |
| 6 | upgrade_exhaust | ~$561 | L3 | 10s |
| 7 | upgrade_suspension | ~$520 | L4 | 12s |
| 8 | upgrade_intake | ~$382 | L3 | 10s |

> Costs assume buying every raw material from the supplier at base price (no bulk discount).
> Actual cost may be lower with 10%+ bulk discount on 10+ items.

---

## Bench Assignment Summary

### Metal Bench (37 recipes)
- **Refined:** steel_plate, aluminum_sheet, rubber_sheet, plastic_housing, glass_panel, carbon_panel, friction_pad, gasket_set, bearing_set, chrome_finish
- **Parts:** brake_pads, brake_rotors, brake_caliper, shocks, springs, wheel_bearings, cv_joint, tie_rod, ball_joint, control_arm, body_panel, fender, windshield, exhaust
- **Tools:** wrench_set, torque_wrench, jack, welding_kit, compression_tester, brake_bleeder, tire_iron, paint_gun
- **Upgrades:** upgrade_brakes, upgrade_suspension, upgrade_exhaust

### Engine Bench (14 recipes)
- **Parts:** spark_plugs, air_filter, radiator, turbo, engine_block, oil_pump, water_pump, fuel_pump, intake, timing_belt, clutch, transmission
- **Upgrades:** upgrade_engine, upgrade_transmission, upgrade_turbo, upgrade_intake

### Electronics Bench (12 recipes)
- **Refined:** copper_wire, circuit_assembly, wire_harness
- **Parts:** alternator, battery, ecu, wiring, starter, headlights, taillights
- **Tools:** diagnostic, multimeter, alignment_gauge
- **Upgrades:** upgrade_ecu

### Fluid Station (5 recipes)
- **Fluids:** motor_oil, coolant, brake_fluid, trans_fluid, power_steering

### Tire Machine (3 recipes)
- **Parts:** tire, tire_performance, tire_offroad

---

## Skill Level Progression

What unlocks at each crafting level:

### Level 1 — Apprentice (0 XP)
- All refined materials (steel_plate, aluminum_sheet, copper_wire, rubber_sheet, plastic_housing, friction_pad, gasket_set)
- Basic parts (spark_plugs, air_filter, brake_pads, tire)
- All 5 fluids
- tool_tire_machine

### Level 2 — Journeyman (500 XP)
- Refined: glass_panel, bearing_set, circuit_assembly, chrome_finish, wire_harness
- Parts: water_pump, timing_belt, battery, brake_rotors, shocks, springs, wheel_bearings, tie_rod, ball_joint, body_panel, fender, headlights, taillights, tire_offroad
- Tools: brake_bleeder, wrench_set, jack

### Level 3 — Mechanic (1,500 XP)
- Refined: carbon_panel
- Parts: oil_pump, fuel_pump, intake, radiator, exhaust, alternator, starter, wiring, clutch, brake_caliper, cv_joint, control_arm, windshield, tire_performance
- Tools: torque_wrench, welding_kit, compression_tester, multimeter, alignment_gauge, paint_gun
- Upgrades: upgrade_exhaust, upgrade_intake

### Level 4 — Expert (3,500 XP)
- Parts: turbo, ecu
- Tools: diagnostic (OBD2 scanner)
- Upgrades: upgrade_brakes, upgrade_suspension

### Level 5 — Master (7,000 XP)
- Parts: engine_block, transmission
- Upgrades: upgrade_engine, upgrade_transmission, upgrade_turbo, upgrade_ecu

---

## Phase 1 Legacy Items (3 items, already in DB)

These items exist in `sb_inventory.sql` from Phase 1. They are registered in the crafting item registry but have no crafting recipes (purchased or awarded through other systems).

| Item | Label | Notes |
|------|-------|-------|
| `upgrade_kit` | Upgrade Kit | Generic Phase 1 upgrade — replaced by 8 specific upgrade kits |
| `paint_supplies` | Paint Supplies | Reserved for Phase 4 paint bench |
| `wash_supplies` | Wash Supplies | Reserved for Phase 4 detailing bench |

---

## Item Count Summary

| Category | Count |
|----------|-------|
| Raw Materials (Supplier) | 32 |
| Refined Materials | 13 |
| Finished Parts | 37 |
| Fluids | 5 |
| Tools | 11 |
| Upgrade Kits | 8 |
| Phase 1 Legacy | 3 |
| **Total Items** | **109** |
| **Total Recipes** | **77** |

---

*sb_mechanic_v2 v2.0.0 — Phase 2: Crafting System*