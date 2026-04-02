# sb_jobs

Job Center v2 - Public jobs with XP progression and boss-managed RP job listings.

## Features

- NPC-based Job Center with sb_target interaction
- Map blip for the Job Center location
- **Public Jobs** with XP progression, leveling, and vehicle upgrades per level:
  - Pizza Delivery
  - Taxi Driver
  - Bus Driver
  - Trash Collector
  - Mining
  - Newspaper Delivery
- **RP Job Listings** - bosses can post hiring listings for their organization
- Job application system with SMS notifications to bosses via sb_phone
- Boss management panel: toggle hiring, review applications, update status (pending, interviewing, accepted, rejected)
- NUI interface for browsing jobs, viewing progress, and applying
- Database-backed: player XP/level progress, listings, and applications persist
- Automatic cleanup of old applications (30 days) and stale listings (14 days)
- Rate limiting on applications
- Requires ID card and phone to apply for RP jobs

## Dependencies

- sb_core
- sb_target
- sb_notify
- sb_progressbar
- sb_minigame
- sb_phone
- sb_inventory (used server-side for ID card checks)
- sb_hud (optional, hides HUD when NUI is open)
- oxmysql

## Installation

1. Place `sb_jobs` in your resources folder.
2. Add `ensure sb_jobs` to your server.cfg (after all dependencies).
3. The required database tables (`job_public_progress`, `job_listings`, `job_applications`) are created automatically on first start.
4. Public job definitions live in `shared/jobs/` and their client/server handlers in `client/jobs/` and `server/jobs/`. Add new public jobs by creating files in those directories and registering them in `fxmanifest.lua`.

## MLO Requirements

None. The Job Center NPC spawns at the default City Hall area (-551, -190) which is a vanilla GTA V location.

## Configuration

All configuration is in `config.lua`:

- `Config.NPCModel` - NPC ped model at the Job Center
- `Config.InteractDistance` - Target interaction range
- `Config.Location` - Job Center coordinates, blip sprite/color/scale
- `Config.SystemPhone` - Phone number used for system SMS to bosses
- `Config.RPJobs` - List of RP job definitions (id, label, description, category, icon, pay range)
- `Config.Categories` - Category labels and colors for the UI

Public job configs (XP tables, pay rates, vehicles, routes) are defined in `shared/jobs/*.lua`.

## Exports

**Client:**

- `exports['sb_jobs']:HasActivePublicJob()` - Returns true if the player has an active public job
- `exports['sb_jobs']:GetActivePublicJob()` - Returns the active public job data or nil
