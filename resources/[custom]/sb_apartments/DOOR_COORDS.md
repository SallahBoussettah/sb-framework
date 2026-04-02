# sb_apartments - Door Models & Interior Coords

Paste F7 inspector output directly. Format per line:
```
doorModel | doorModel | ID:X | vector3(x, y, z)
```

Example: `0xFFFFFFFFB614B4EF | 0xFFFFFFFFB614B4EF | ID:0 | vector3(-1571.71, -407.71, 42.76)`

For stash/wardrobe just paste: `vector3(x, y, z)`

---

## Del Perro Apartments (2 units)

## Garage
- Center of the garage : -1563.3556, -394.5420, 41.9886
- Only people who rent a room out of the 2 can drive in and press E to store their vehicle with keys,
- NPC To retrive vehicle : -1567.8047, -398.0757, 41.9899, 295.8109
- Npc should retrieve vehocles from the garage itself
- retrieved vehicle spawn and should check if place is filled then go to another pos, if 4 are filled it should refuse until a place is empty.
- Pos 1 : -1559.89, -391.02, 41.27, 139.36
- Pos 2 : -1563.44, -388.08, 41.27, 138.84
- Pos 3 : -1556.19, -393.30, 41.27, 141.31
- Pos 4 : -1570.20, -388.28, 41.27, 228.07

### dp_101 - Unit 101
- door: 0xFFFFFFFFDEEFCECE | 0xFFFFFFFFDEEFCECE | ID:0 | vector3(-1567.08, -400.64, 48.05)
- stash: -1560.10, -400.91, 48.05
- wardrobe: -1560.92, -404.54, 49.18

### dp_102 - Unit 102
- door: 0xFFFFFFFFDEEFCECE | 0xFFFFFFFFDEEFCECE | ID:0 | vector3(-1559.23, -391.29, 48.06)
- stash: -1556.81, -397.36, 48.05
- wardrobe: -1553.51, -395.90, 49.23

## Unavailable we only got 2 rooms
<!-- ### dp_201 - Unit 201
- door:
- stash:
- wardrobe:

### dp_202 - Unit 202
- door:
- stash:
- wardrobe: -->

---

## Pink Cage Motel (TODO)

### pc_101 - Unit 101
- door: 
- stash: 
- wardrobe: 
### pc_102 - Unit 102
- door: 
- stash: 
- wardrobe: 
### pc_103 - Unit 103
- door: 
- stash: 
- wardrobe: 


---

## The Emissary Hotel (20 rooms, floors 3-6)

Floor 2 = restaurant (elevator skips it).
All 4 room floors share the same 5 room positions. Upper floors = Z + 8.5396 per floor.

### Floor 3 (base floor - F7 data collected)

### em_301 - Room 301
- door: 0x0B9AE8D5 | 0x0B9AE8D5 | ID:0 | vector3(63.31, -955.01, 47.00)
- stash: 67.33, -957.80, 46.89
- wardrobe: 61.8015, -959.1164, 46.8864, 293.0240

### em_302 - Room 302
- door: 0x0B9AE8D5 | 0x0B9AE8D5 | ID:0 | vector3(76.18, -959.69, 47.02)
- stash: 70.2207, -959.1690, 46.8864
- wardrobe: 73.63, -963.27, 46.89, 30.79

### em_303 - Room 303
- door: 0x0B9AE8D5 | 0x0B9AE8D5 | ID:0 | vector3(77.59, -958.38, 46.94)
- stash: 80.6981, -954.3013, 46.8865
- wardrobe: 81.7434, -959.7578, 46.8864, 26.7392

### em_304 - Room 304
- door: 0x0B9AE8D5 | 0x0B9AE8D5 | ID:0 | vector3(76.29, -956.45, 47.00)
- stash: 72.9730, -951.5517, 46.8864
- wardrobe: 78.4024, -950.5906, 46.8865, 132.8342

### em_305 - Room 305
- door: 0x0B9AE8D5 | 0x0B9AE8D5 | ID:0 | vector3(63.43, -951.77, 47.00)
- stash: 70.1353, -950.4483, 46.8865
- wardrobe: 66.4409, -946.0709, 46.8865, 208.3464

### Floors 4-6 (computed from floor 3)
3 floors above, each has 5 rooms sharing the same XY, just Z + 8.5396 per floor:
- Floor 4: Z + 8.5396
- Floor 5: Z + 17.0792
- Floor 6: Z + 25.6188

All 20 rooms now in config.lua with computed coords.
