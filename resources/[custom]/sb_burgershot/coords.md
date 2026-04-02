# Burger Shot - Coordinates to Set In-Game

Use F7 inspector to get exact coords. Fill in below, then I'll update all files.

---

## sb_burgershot/config.lua - Targets & Zones

### Blip (map icon position)
- **Blip**: `-1184.02, -884.52, 13.13`

### Clock In NPC
- **NPC Position**: `-1197.1423, -895.8836, 13.9742`
- **NPC Heading**: `120.7354`

### Supply Fridge (employee buys raw ingredients)
- **Fridge**: `-1201.9807, -900.6702, 15.2151`

### Cooking Stations
1. **Fry Station** (fry potatoes into fries): `-1200.8806, -896.7407, 14.8176`
2. **Grill Station** (cook raw patty): `-1198.2487, -895.1503, 14.8829`
3. **Burger Assembly** (combine into burger): `-1197.2905, -898.1119, 14.9123`
4. **Drink Station** (pour drinks): `-1196.9504, -895.0037, 15.3999`
5. **Meal Packing** (pack burger+fries+drink): `-1196.3810, -899.1322, 14.8288`

### Customer Counter (public buys food)
- **Counter**: `-1194.1671, -894.8373, 15.1662`

---

## sb_doorlock/config.lua - Doors

Fill in coords + heading for each door. List which doors you want locked.

1. **Front Entrance Left** (`gn_burger_front_door_prop_l`):
   - Coords: `_____, _____, _____` 0xFFFFFFFFCFE9EFF9 | 0xFFFFFFFFCFE9EFF9 | ID:0 | vector3(-1184.15, -884.34, 13.64)
   - Heading: `_____`

2. **Front Entrance Right** (`gn_burger_front_door_prop_r`):
   - Coords: `_____, _____, _____` 0x17087E25 | 0x17087E25 | ID:0 | vector3(-1183.81, -884.85, 13.80)
   - Heading: `_____`

3. **Kitchen Door** (`gn_burger_wc_door_kitchen`):
   - Coords: `_____, _____, _____` Right : 0x7610DF98 | 0x7610DF98 | ID:0 | vector3(-1203.53, -897.32, 13.95). Left : 0x7610DF98 | 0x7610DF98 | ID:0 | vector3(-1202.85, -896.86, 13.98)
   - Heading: `_____`

4. **Cold Room** (`gn_burger_prop_cold_room_door`): 
   - Coords: `_____, _____, _____` 0x57323B8A | 0x57323B8A | ID:0 | vector3(-1194.06, -899.85, 14.07)
   - Heading: `_____`

5. **Back Door** (`gn_burger_toilet_bacadoor`):
   - Coords: `_____, _____, _____` 0x57323B8A | 0x57323B8A | ID:0 | vector3(-1194.17, -901.61, 14.07)
   - Heading: `_____`

Staff Door : 0xFFFFFFFF9E830AC7 | 0xFFFFFFFF9E830AC7 | ID:0 | vector3(-1178.86, -892.18, 14.06)

Boss Door 0xFFFFFFFFDAA58F29 | 0xFFFFFFFFDAA58F29 | ID:0 | vector3(-1181.95, -895.45, 14.19)

Staff Only door : 0x4CE0739D | 0x4CE0739D | ID:0 | vector3(-1184.50, -897.20, 14.42)

BACK Door left : 0xFFFFFFFFCFE9EFF9 | 0xFFFFFFFFCFE9EFF9 | ID:0 | vector3(-1198.25, -884.64, 14.06)
back door right : 0x17087E25 | 0x17087E25 | ID:0 | vector3(-1197.50, -884.13, 14.07)

6. _(Add any other doors you find in-game below)_:
   - Model: `_____`
   - Coords: `_____, _____, _____`
   - Heading: `_____`
