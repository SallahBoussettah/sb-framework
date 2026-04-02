# sb_prison Phase 2 — Coords Needed

Use NoClip or walk to each spot, then run in F8 console:
```
GetEntityCoords(PlayerPedId())
```

---

## 1. LAUNDRY JOB — DONE

```
1. Sorting bins (3): vector3(1591.18, 2543.02, 45.95), vector3(1592.81, 2542.87, 45.83), vector3(1594.26, 2542.89, 45.83)
2. Washing machines (4): vector3(1596.76, 2538.41, 45.63), vector3(1596.78, 2540.49, 45.63), vector3(1588.77, 2540.50, 45.63), vector3(1588.74, 2538.46, 45.63)
3. Folding tables (2): vector3(1591.96, 2539.92, 45.63), vector3(1593.90, 2539.69, 45.63)
4. Hanging rack: vector3(1593.35, 2546.22, 45.63)
```

---

## 2. CANTEEN NPC — DONE

```
vector4(1736.57, 2589.47, 44.42, 183.10)
```

---

## 3. PERIMETER — DONE (9 towers)

---

## 4. WOODWORK JOB (4 stations — stand at each, get coords)

Entry zone = same as Station 1. Stand at each spot in the woodwork room.

```
Station 1 — Lumber storage (where raw planks/wood are stacked):
vector3(x, y, z) = 1567.13, 2547.89, 45.63

Station 2 — Workbench / Saw (where cutting happens):
vector3(x, y, z) = 1570.86, 2549.34, 45.64
vector3(x, y, z) = 1574.78, 2549.33, 45.64
vector3(x, y, z) = 1578.29, 2549.20, 45.64
vector3(x, y, z) = 1581.95, 2549.15, 45.64
vector3(x, y, z) = 1582.11, 2546.66, 45.64
vector3(x, y, z) = 1578.33, 2546.92, 45.64
vector3(x, y, z) = 1574.68, 2546.80, 45.64
vector3(x, y, z) = 1570.81, 2546.80, 45.64

Station 3 — Assembly table (where sanding/building happens): -- I dont have it.
vector3(x, y, z) =

Station 4 — Delivery shelf (where finished pieces go):
vector3(x, y, z) = 1579.49, 2553.74, 45.63 this is the storage room
```

If any station has MULTIPLE spots (like 2 workbenches), list them all separated by commas.

---

## 5. METALWORK JOB (4 stations — stand at each, get coords)

Entry zone = same as Station 1. Stand at each spot in the metalwork room.

```
Station 1 — Scrap bin / raw metal storage: -- Pick them from the ground
vector3(x, y, z) = 1585.04, 2558.46, 45.63
vector3(x, y, z) = 1585.12, 2562.43, 45.63

Station 2 — Furnace / forge (where metal is heated): -- I dont think its heating maching u will see screenshots
vector3(x, y, z) = 1591.49, 2562.38, 45.64
vector3(x, y, z) = 1593.14, 2562.32, 45.64
vector3(x, y, z) = 1594.59, 2562.34, 45.64
vector3(x, y, z) = 1596.30, 2562.21, 45.64
vector3(x, y, z) = 1596.18, 2558.42, 45.64
vector3(x, y, z) = 1594.53, 2558.42, 45.64
vector3(x, y, z) = 1593.10, 2558.42, 45.64
vector3(x, y, z) = 1591.58, 2558.94, 45.63

Station 3 — Anvil / workbench (where hammering/shaping happens): its kinda a cutting machine??
vector4(x, y, z, h) = 1588.68, 2563.36, 45.64, 270.48
vector4(x, y, z, h) = 1586.01, 2563.23, 45.63, 272.34
vector4(x, y, z, h) = 1589.73, 2558.49, 45.63, 179.42

Station 4 — Cooling rack / delivery (where finished pieces go): -- to storage room
vector3(x, y, z) = 1581.32, 2558.87, 45.63
```

If any station has MULTIPLE spots, list them all separated by commas.
