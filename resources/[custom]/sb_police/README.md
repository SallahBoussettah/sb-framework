# sb_police

Full-featured police system with a React-based MDT, field actions, K9 unit, ALPR, radar gun, siren controls, scene management, and rank-based progression. Built for serious RP servers.

## Tech Stack

- **UI:** React, TypeScript, Tailwind CSS, Zustand (state management), Framer Motion (animations)
- **Backend:** Lua (FiveM client/server), oxmysql

## Features

### Mobile Data Terminal (MDT)

- Full React UI opened with configurable keybind (default F6)
- **Dashboard** - shift timer, on-duty officer list, live alert feed
- **Citizens** - search by name or citizen ID, view detailed profiles with criminal history, citations, notes, vehicles, and mugshots
- **Vehicles** - search by plate or owner, view registration details, flags (stolen, BOLO, wanted owner), and linked owner profile
- **Reports** - create, edit, and manage incident reports with tagging system (open, closed, pending, urgent, cold case)
- **Warrants** - active warrant management
- **BOLOs** - be-on-the-lookout bulletins
- **Penal Code** - full reference with categories (Traffic, Misdemeanor, Felony, Federal) including fine and jail time values
- **Officers** - roster view with on-duty status, rank, and badge number
- **Time Clock** - duty clock-in/out with shift history and statistics
- **Dispatch** - live dispatch alerts feed integrated with sb_alerts

### Field Actions

- **Cuffing** - soft cuff (hands in front) and hard cuff (hands behind back) with synced animations and movement clipsets
- **Escort** - grab and walk cuffed suspects, attach to officer movement
- **Vehicle transport** - put suspects into and take out of vehicles
- **Suspect search** - search players for contraband with progress bar
- **Tackle** - sprint tackle with cooldown, ragdoll stun duration, and minimum speed requirement
- **GSR test** - gunshot residue test with configurable positive window (default 10 minutes after firing)
- **Breathalyzer** - BAC test on suspects
- **Vehicle search** - thorough vehicle search for contraband
- **Citations** - issue traffic/infraction citations from penal code, tracked in database with courthouse fine payment

### K9 Unit

- Spawn and command a German Shepherd K9 companion (K key)
- Commands: follow, stay, search area, attack, return to vehicle
- Drug detection - K9 sniffs for configurable illegal items (weed, cocaine, meth, etc.)
- Vehicle sniff - K9 alerts on vehicles containing contraband
- Grade-locked (Officer III+ by default)
- K9 map blip, death cooldown, and automatic cleanup
- Restricted to SUV-class vehicles (configurable)

### ALPR (Automatic License Plate Reader)

- Automatic front and rear plate scanning while driving ALPR-equipped vehicles
- Real-time plate flag checking (stolen vehicles, wanted owners, BOLOs)
- Lock plate for persistent tracking
- React overlay UI with front/rear camera display, vehicle info, speed, and flag indicators
- Audio alerts on flagged plates
- Configurable scan distance and interval

### Radar Gun (ProLaser 4)

- Inventory-based radar gun item - use from inventory to equip
- Custom LIDAR weapon model (WEAPON_PROLASER4 via streaming resource)
- Aim to scan, left-click to lock speed reading
- Displays speed, direction (approaching/departing), plate, vehicle model, and range
- Configurable speed unit (MPH or KM/H), scan distance (up to 200m), and minimum speed filter
- React overlay UI

### Siren and Lights System

- Network-synced emergency vehicle siren and light controls
- L key - toggle emergency lights
- Semicolon key - cycle siren tones (wail, yelp, hi-lo)
- E key - air horn (hold)
- Supports both native GTA V sounds and custom audio files (.ogg)
- Configurable per-vehicle siren whitelist

### Scene Management (Props)

- Traffic cones (standard and lighted)
- Road barriers and arrow barriers
- Road flares with particle effects (5-minute duration)
- Spike strips with tire-popping functionality
- Per-officer prop limit (configurable, default 10)
- Place and remove with animations

### Station Interactions

- **Duty point** - clock in/out with sb_target interaction
- **Armory** - weapons, items, ammo, and magazines with grade-based access
- **Locker room** - uniform management via sb_clothing, saves/restores civilian appearance
- **Vehicle garage** - NPC-based garage with grade-locked vehicles across 9 categories (patrol, pursuit, motorcycle, SWAT, command, transport, air, marine)
- **Evidence locker** - store and retrieve evidence items
- **Boss menu** - hire, fire, promote, and manage roster (rank 9 only)
- **Holding cells** - 7 configurable cells with door control
- **Impound lot** - retrieve impounded vehicles
- **Helipad and boat dock** - optional, grade-locked

### Rank System

- 10 ranks (grade 0-9): Cadet, Officer I/II/III, Corporal, Sergeant, Lieutenant, Captain, Commander, Chief of Police
- Per-rank salary, hire/fire/promote permissions
- Grade-based vehicle and equipment access
- Configurable garage mode: exact grade match or cumulative

### Evidence System

- Blood samples, bullet casings, footprints, fingerprints, drug residue, photo evidence
- Evidence items stored in inventory, logged in database
- Evidence locker storage at station

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql)
- sb_core
- sb_notify
- sb_target
- sb_progressbar
- sb_inventory
- sb_clothing (for locker room uniform changes)
- sb_alerts (for dispatch integration)
- pma-voice (for radio, referenced in siren sync)
- [LidarGun streaming resource](standalone) (for radar gun weapon model)

## MLO / Mapping Requirements

- **Mission Row Police Department (MRPD)** - the default station coordinates (around 430-505, -960 to -1015) are built for a custom Mission Row PD interior. You will need a compatible MRPD MLO (e.g., Gabz MRPD or similar) that includes the basement cells, booking room, armory, and locker room areas.
- Coordinates for all interaction points are fully configurable in `config.lua` under `Config.Stations`.

## Installation

1. Ensure all dependencies are started before `sb_police` in your `server.cfg`.
2. Place `sb_police` in your resources folder.
3. Add `ensure sb_police` to your `server.cfg`.
4. Import or let the script auto-create the required database tables on first start (`sb_police_citations`, `sb_police_citizen_notes`, `sb_police_criminal_records`).
5. If using the radar gun, ensure the `LidarGun` streaming resource is installed and started.
6. If using custom siren sounds, place `.ogg` files in `html/sounds/` and set `Config.Sirens.SoundMode = 'custom'`.
7. Adjust station coordinates in `config.lua` to match your MRPD MLO.
8. Configure vehicle models in `Config.Vehicles` to match your server's police car pack.

## Configuration

All configuration is in `config.lua`:

- `Config.PoliceJob` - job name (default: `'police'`)
- `Config.MDTKey` - keybind to open MDT (default: `'F6'`)
- `Config.Stations` - full station setup (blips, duty point, armory, locker, garage, cells, impound, helipad, boat dock)
- `Config.Ranks` - rank names, salaries, and permissions for all 10 grades
- `Config.Vehicles` - grade-locked vehicle fleet with categories and images
- `Config.Armory` - weapons, items, ammo, and magazines with grade requirements
- `Config.Sirens` - sound mode, keybinds, vehicle whitelist
- `Config.K9` - model, search radius, grade requirement, K9-enabled vehicles, detectable items
- `Config.ALPR` - scan distance, interval, equipped vehicles
- `Config.Radar` - range, speed unit, weapon hash, minimum speed
- `Config.GSR` - test duration, positive window
- `Config.Breathalyzer` - test duration
- `Config.VehicleSearch` - search duration
- `Config.Field` - cuff/escort/search durations, animations, movement clipsets, tackle settings
- `Config.Props` - max per officer, prop models and animations
- `Config.EvidenceTypes` - configurable evidence categories
- `Config.MDT` - report tags, danger levels
- `Config.Citations` - citation categories
- `Config.General` - interaction distances, duty requirements per feature, garage grade mode

Penal code entries are defined in `shared/penal_code.lua` and auto-seeded to the database on first run.

## Exports

### Client

| Export | Description |
|--------|-------------|
| `IsOnDuty()` | Returns whether the player is on duty |
| `IsMDTOpen()` | Returns whether the MDT is currently open |
| `OpenMDT()` | Opens the MDT programmatically |
| `CloseMDT()` | Closes the MDT |
| `IsCuffed()` | Returns whether the local player is cuffed |
| `GetCuffType()` | Returns `'soft'` or `'hard'` cuff type |
| `IsBeingEscorted()` | Returns whether the local player is being escorted |
| `IsEscorting()` | Returns whether the local player is escorting someone |
| `GetEscortedPlayerId()` | Returns the server ID of the escorted player |
| `GetTestDummyPed()` | Returns the test dummy ped entity (for booking integration) |
| `IsInTransport()` | Returns whether the local player is locked in a transport vehicle |
| `IsPlayerCuffed(ped)` | Check if a specific ped is cuffed |
| `IsPlayerBeingEscorted(ped)` | Check if a specific ped is being escorted |
| `IsEscortingPlayer()` | Check if local player is escorting anyone |
| `GetEscortedPlayer()` | Get the server ID of the escorted target |
| `StartCuffAction(ped, type)` | Initiate cuffing on a target ped |
| `StartUncuffAction(ped)` | Remove cuffs from a target ped |
| `StartEscort(ped)` | Begin escorting a cuffed target |
| `StopEscort()` | Release the escorted target |
| `PutInVehicle(ped)` | Put escorted target into nearest vehicle |
| `TakeOutOfVehicle(ped)` | Remove target from vehicle |
| `StartSearch(ped)` | Search a target for contraband |
| `StartGSRTest(ped)` | Perform GSR test on target |
| `StartBreathalyzerTest(ped)` | Perform breathalyzer test on target |
| `StartVehicleSearch(vehicle)` | Search a vehicle for contraband |
| `HasK9Deployed()` | Returns whether a K9 is currently deployed |
| `GetK9Entity()` | Returns the K9 ped entity |
| `GetK9State()` | Returns K9 state (idle/following/staying/searching/attacking) |
| `DespawnK9()` | Despawn the K9 unit |
| `IsALPRActive()` | Returns whether ALPR is currently active |
| `GetALPRData()` | Returns current ALPR scan data |
| `IsRadarActive()` | Returns whether the radar gun is active |
| `IsRadarLocked()` | Returns whether a speed reading is locked |
| `GetLockedSpeed()` | Returns the locked speed value |
| `GetLockedPlate()` | Returns the locked vehicle plate |
| `GetLockedRange()` | Returns the locked range value |
| `PlaceProp(type)` | Place a scene prop by type |
| `RemoveNearestProp()` | Remove the nearest placed prop |
| `RemoveAllProps()` | Remove all placed props |
| `GetPlacedPropsCount()` | Returns number of placed props |
| `GetMaxProps()` | Returns max props per officer |
| `IsOnDutyStation()` | Returns duty status from station module |
| `GetPlayerGrade()` | Returns the player's rank grade |
| `IsPoliceJob()` | Returns whether the player has the police job |
| `IsBoss()` | Returns whether the player meets boss rank requirement |

### Server

| Export | Description |
|--------|-------------|
| `GetOnDutyOfficers()` | Returns table of on-duty officer data |
| `GetOnDutyCount()` | Returns count of on-duty officers |
| `IsOfficerOnDuty(src)` | Check if a specific source is on duty |
| `AddAlert(alertData)` | Push an alert to on-duty officers |

## Screenshots

Screenshots coming soon.
