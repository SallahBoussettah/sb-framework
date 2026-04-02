# sb_prison

Booking, sentencing, and jail system with a React-based booking dashboard, multi-step intake/release process, prison jobs, credits economy, and canteen. Supports both MRPD holding cells (short sentences) and Bolingbroke Penitentiary (long sentences).

## Tech Stack

- **UI:** React, TypeScript, Tailwind CSS, Zustand (state management)
- **Backend:** Lua (FiveM client/server), oxmysql

## Features

### Booking Dashboard (React UI)

- Step-by-step booking workflow with progress indicator
- **Suspect Lookup** - search by name or citizen ID, auto-detect cuffed player in holding area
- **Suspect Profile** - view full criminal history, prior bookings, and mugshot gallery
- **Arrest File** - select charges from penal code, auto-calculate sentence (months to real seconds), add officer notes
- **Confirmation** - review and finalize booking with summary of charges, sentence, and location assignment
- Mugshot picker - browse and attach mugshots taken at the camera station

### Mugshot Camera Station

- Fixed camera at booking room with pan, tilt, and zoom controls
- Rotation limits and configurable FOV range
- Screenshots uploaded via fivemanager (configurable upload method)
- Mugshots stored in database and linked to citizen profiles
- Accessible from both the booking dashboard and MDT citizen profiles

### Sentencing System

- Configurable month-to-seconds conversion (default: 1 month = 30 real seconds)
- **Short sentences** (under 15 minutes real time) - served in MRPD holding cells
- **Long sentences** (15+ minutes) - served at Bolingbroke Penitentiary
- Persistent sentences survive server restarts and disconnects
- On-screen countdown timer during sentence
- Admin commands: `/jail` and `/unjail` (admin-only configurable)

### MRPD Holding Cells

- 7 configurable holding cells with coordinates
- Release point at MRPD front door
- Reconnect placement - prisoners respawn in their assigned cell

### Bolingbroke Penitentiary

- **Check-in system** - intake officer NPC, officer interacts to register transported prisoner
- **Multi-step intake process:**
  1. Deposit personal items (confiscated and stored in database)
  2. Shower (with particle effects)
  3. Change into prison uniform (DLC-based outfit with variant randomization)
  4. Enter the yard
- **Multi-step release process:**
  1. Remove prison uniform
  2. Change into civilian clothes and collect confiscated belongings
  3. Walk to exit gate
- **Perimeter boundary** - polygon-based point-in-polygon check covering full facility
- Static guard NPCs at lobby, warden office, and job manager
- Map blip for the facility

### Prison Outfit System

- Uses GTA V Heist DLC prison outfits (built-in, no custom clothing required)
- Male and female variants with random selection (50/50)
- DLC collection-based index resolution (auto-adapts regardless of clothing packs)
- Optional MPW retexture support (plain orange or corrections circles)
- Underwear outfit for shower step

### Prison Jobs (Credits Economy)

- **Laundry Room** - 4-step flow: sort dirty laundry, load washing machine (with minigame), fold clean laundry, deliver to hanging rack
- **Woodwork Shop** - 3-step flow: pick up lumber, cut and shape at workbench (with minigame), deliver to storage
- **Metalwork Shop** - 4-step flow: gather scrap, grind at machine (timing minigame), cut at drill press (precision minigame), deliver to storage
- Each job awards credits and reduces sentence time
- Cooldown between job completions
- Random station selection per step (prevents repetition)
- Minigame integration via sb_minigame (timing and precision types)
- Multi-step walk-between-stations flow with HUD indicators and markers

### Credits Economy

- Earned through prison jobs
- Spent at the canteen for food and drink
- Starting balance, max balance configurable
- On-screen credits HUD below sentence timer
- Persistent in database (`sb_prison_credits`)

### Canteen

- NPC vendor at Bolingbroke cafeteria
- Purchase food and drinks using prison credits
- Items restore hunger and thirst (integrates with metabolism system)
- Configurable menu: bread, apple, prison meal, water, juice, coffee
- sb_target interaction with large radius

### Transport System

- Officers escort cuffed prisoners from MRPD to Bolingbroke
- On-hold HUD displayed for prisoners awaiting transport
- Check-in area at Bolingbroke entrance detects cuffed prisoners

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql)
- sb_core
- sb_notify
- sb_target
- sb_progressbar
- sb_inventory
- sb_clothing (for outfit changes during intake/release)
- sb_police (for cuff state detection, test dummy, and field action exports)
- sb_minigame (for prison job minigames)

## MLO / Mapping Requirements

- **Mission Row Police Department (MRPD)** - booking terminal and holding cells use coordinates inside a custom MRPD interior (around 474, -1010). A compatible MRPD MLO is required (e.g., Gabz MRPD).
- **Bolingbroke Penitentiary** - uses the default GTA V Bolingbroke prison exterior/interior. A custom Bolingbroke MLO is **strongly recommended** for the intake area, laundry room, woodwork shop, metalwork shop, and canteen (coordinates in the 1560-1840, 2390-2770 range). The script coordinates are designed for a specific Bolingbroke interior layout.

## Installation

1. Ensure all dependencies are started before `sb_prison` in your `server.cfg`.
2. Place `sb_prison` in your resources folder.
3. Add `ensure sb_prison` to your `server.cfg`.
4. The script auto-creates all required database tables on first start (`sb_prison_sentences`, `sb_prison_confiscated`, `sb_prison_bookings`, `sb_prison_mugshots`, `sb_prison_credits`).
5. Configure the fivemanager upload token for mugshots (or change `Config.UploadMethod`).
6. Adjust coordinates in `config.lua` to match your MRPD and Bolingbroke MLOs.

## Configuration

All configuration is in `config.lua`:

- `Config.MonthToSeconds` - conversion rate for penal code months to real seconds (default: 30)
- `Config.ShortSentenceThreshold` - threshold in seconds for MRPD vs Bolingbroke routing (default: 900 / 15 minutes)
- `Config.BookingPC` - booking terminal interaction zone coordinates
- `Config.HoldingArea` - holding area zone for suspect detection
- `Config.MugshotStation` / `Config.MugshotCam` - camera position, rotation limits, FOV, zoom settings
- `Config.MRPD` - cell spawn positions and release point
- `Config.Bolingbroke` - entrance, yard spawn, release point, check-in NPC, intake/release step coordinates, guard NPCs, perimeter polygon
- `Config.PrisonerOutfit` - DLC collection-based outfit definitions for male/female with variants
- `Config.UnderwearOutfit` - shower step appearance
- `Config.PrisonJobs` - job definitions (laundry, woodwork, metalwork) with step coordinates, animations, minigame settings, credits/time rewards
- `Config.Credits` - starting balance, max balance
- `Config.CanteenItems` - food/drink menu with prices and hunger/thirst restore values
- `Config.CanteenNPC` - vendor NPC model and position
- `Config.UploadMethod` - screenshot upload service (`'fivemanager'`, `'imgur'`, `'discord'`, `'custom'`)
- `Config.AdminOnly` - restrict `/jail` and `/unjail` to admins
- `Config.Debug` - enable debug prints

## Exports

### Client

| Export | Description |
|--------|-------------|
| `IsJailed()` | Returns whether the local player is currently jailed |
| `GetSentenceData()` | Returns current sentence data (time remaining, location, charges) |

### Server

| Export | Description |
|--------|-------------|
| `IsPlayerJailed(citizenid)` | Check if a citizen is currently jailed |
| `GetSentence(citizenid)` | Get the full sentence record for a citizen |
| `GetBookingRecord(citizenid)` | Get the most recent booking record |
| `GetPrisonerCredits(citizenid)` | Get the prisoner's current credit balance |

## Screenshots

Screenshots coming soon.
