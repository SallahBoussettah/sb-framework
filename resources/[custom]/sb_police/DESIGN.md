# sb_police - Police System Design Document

**Version:** 1.0.0
**Status:** In Development
**Developer:** Salah Eddine Boussettah
**Last Updated:** February 3, 2026

---

## Overview

A comprehensive police system for Everyday Chaos RP, featuring a modern MDT (Mobile Data Terminal), dispatch integration, civilian interactions, evidence collection, and full integration with existing sb_* scripts.

---

## Feature Roadmap

### Phase 1: MDT/Menu System (Current Priority)

| Feature | Status | Description |
|---------|--------|-------------|
| Dashboard/Home | In Progress | Main hub with duty toggle, officer count, quick actions |
| Citizen Search | Coming Soon | Search citizens by name/ID, view profile & history |
| Vehicle Lookup | Coming Soon | Plate search, owner info, wanted status |
| Criminal Code | Coming Soon | Browse charges, fines, jail times |
| Reports System | Coming Soon | Create/edit incident reports with evidence |
| Dispatch Center | Coming Soon | Live 911 calls, officer status, GPS waypoints |
| Officer Management | Coming Soon | Roster, clock in/out, badge generation |
| BOLO System | Coming Soon | Be On Lookout alerts for suspects/vehicles |
| Debtors List | Coming Soon | Citizens with unpaid fines |
| Federal Prison | Coming Soon | Long-term inmate management |
| Security Cameras | Coming Soon | View business/vehicle/bodycam feeds |
| Time Control | Coming Soon | Officer duty hours tracking |

### Phase 2: Civilian Interactions

| Feature | Status | Description |
|---------|--------|-------------|
| Handcuff System | Coming Soon | Cuff/uncuff with animations, soft/hard cuffs |
| Search Player | Coming Soon | Pat down for weapons/items |
| Escort/Drag | Coming Soon | Move cuffed players |
| Vehicle Seat | Coming Soon | Put suspects in vehicles |
| ID Check | Coming Soon | Request citizen ID |
| Tackle | Coming Soon | Tackle fleeing suspects |

### Phase 3: Vehicle Systems

| Feature | Status | Description |
|---------|--------|-------------|
| Siren Controls | Coming Soon | Multiple siren modes, air horn, PA system |
| ALPR System | Coming Soon | Automatic license plate reader |
| Spike Strips | Coming Soon | Deploy to stop vehicles |
| Vehicle Spawn | Coming Soon | Spawn department vehicles |
| Impound | Coming Soon | Impound civilian vehicles |

### Phase 4: Props & Scene Management

| Feature | Status | Description |
|---------|--------|-------------|
| Traffic Cones | Coming Soon | Place/pickup traffic cones |
| Barriers | Coming Soon | Road barriers for scene control |
| Police Tape | Coming Soon | Crime scene tape |
| Flares | Coming Soon | Road flares |

### Phase 5: Evidence & Investigation

| Feature | Status | Description |
|---------|--------|-------------|
| Evidence Collection | Coming Soon | Collect blood, casings, footprints |
| Evidence Photos | Coming Soon | Take photos with instant camera |
| GSR Test | Coming Soon | Gunshot residue testing |
| Breathalyzer | Coming Soon | DUI testing |

### Phase 6: Additional Features

| Feature | Status | Description |
|---------|--------|-------------|
| Helicopter Cam | Coming Soon | Thermal/night vision from heli |
| K9 Unit | Coming Soon | Police dog companion |
| Megaphone/PA | Coming Soon | Vehicle PA system |
| Radio System | Coming Soon | Internal police radio channels |

---

## Database Schema

```sql
-- Penal Code (Criminal charges)
CREATE TABLE `sb_police_penal_code` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `fine` INT(11) NOT NULL DEFAULT 0,
    `jail_time` INT(11) NOT NULL DEFAULT 0,
    `category` VARCHAR(50) DEFAULT 'Misdemeanor',
    PRIMARY KEY (`id`)
);

-- Officer Notes on Citizens
CREATE TABLE `sb_police_notes` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizen_id` INT(11) NOT NULL,
    `officer_id` INT(11) NOT NULL,
    `officer_name` VARCHAR(100) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `content` TEXT,
    `pinned` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

-- Incident Reports
CREATE TABLE `sb_police_reports` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `location` VARCHAR(255),
    `author_id` INT(11) NOT NULL,
    `author_name` VARCHAR(100) NOT NULL,
    `officers` JSON DEFAULT '[]',
    `suspects` JSON DEFAULT '[]',
    `victims` JSON DEFAULT '[]',
    `vehicles` JSON DEFAULT '[]',
    `evidence` JSON DEFAULT '[]',
    `tags` JSON DEFAULT '["Open Case"]',
    `status` VARCHAR(50) DEFAULT 'open',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

-- Citations/Fines
CREATE TABLE `sb_police_citations` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizen_id` INT(11) NOT NULL,
    `officer_id` INT(11) NOT NULL,
    `officer_name` VARCHAR(100) NOT NULL,
    `charges` JSON NOT NULL,
    `total_fine` INT(11) NOT NULL DEFAULT 0,
    `total_jail` INT(11) NOT NULL DEFAULT 0,
    `paid` TINYINT(1) DEFAULT 0,
    `report_id` INT(11) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

-- Warrants/BOLO
CREATE TABLE `sb_police_warrants` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `type` ENUM('arrest', 'search', 'bolo') NOT NULL,
    `target_type` ENUM('citizen', 'vehicle') NOT NULL,
    `target_id` INT(11) DEFAULT NULL,
    `target_plate` VARCHAR(20) DEFAULT NULL,
    `target_name` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `issued_by` INT(11) NOT NULL,
    `issued_by_name` VARCHAR(100) NOT NULL,
    `active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

-- Duty Clock
CREATE TABLE `sb_police_duty_clock` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `officer_id` INT(11) NOT NULL,
    `officer_name` VARCHAR(100) NOT NULL,
    `clock_in` TIMESTAMP NOT NULL,
    `clock_out` TIMESTAMP DEFAULT NULL,
    `duration_minutes` INT(11) DEFAULT 0,
    PRIMARY KEY (`id`)
);

-- Federal Prison (Long-term inmates)
CREATE TABLE `sb_police_federal` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizen_id` INT(11) NOT NULL,
    `citizen_name` VARCHAR(100) NOT NULL,
    `sentence_months` INT(11) NOT NULL,
    `remaining_months` INT(11) NOT NULL,
    `danger_level` VARCHAR(20) DEFAULT 'Normal',
    `facility` VARCHAR(50) DEFAULT 'Bolingbroke',
    `admitted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);
```

---

## Integration Points

### sb_core
- Job checking: `sb_core:getPlayerJob()`
- Player data: `sb_core:getPlayerData()`
- Money handling for fines

### sb_alerts
- Receive 911 dispatch calls
- Send officer location updates
- `exports['sb_alerts']:SendAlert()`

### sb_notify
- Toast notifications for actions
- `exports['sb_notify']:Notify(msg, type, duration)`

### sb_target
- Third-eye interactions for cuffing, searching
- `exports['sb_target']:AddTargetEntity()`

### sb_inventory
- Store evidence items
- Check for weapons during search
- Access police equipment

### sb_progressbar
- Progress bars for actions (cuffing, searching)
- `exports['sb_progressbar']:Show(duration, label)`

### sb_doorlock
- Police station door access
- `job = 'police'` restrictions

### sb_deaths
- Check if target is dead before interactions
- `exports['sb_deaths']:IsPlayerDead(source)`

### sb_vehicleshop
- Police vehicle spawning
- Vehicle key management

---

## Keybinds

| Key | Action | Context |
|-----|--------|---------|
| F6 | Open MDT | On foot or in vehicle |
| E | Interact (context-based) | Near cuffed player |
| G | Toggle siren mode | In police vehicle |
| L | Toggle lights | In police vehicle |
| H | Air horn | In police vehicle |
| Shift+E | Spike strip | On foot, police job |

---

## Configuration Options

```lua
Config = {}

-- Job name
Config.PoliceJob = 'police'

-- MDT key
Config.MDTKey = 'F6'

-- Police stations
Config.Stations = {
    {
        name = 'Mission Row PD',
        coords = vector3(441.0, -982.0, 30.7),
        blip = { sprite = 60, color = 29, scale = 1.0 },
        armory = vector3(452.0, -980.0, 30.7),
        garage = vector3(447.0, -1024.0, 28.5),
        locker = vector3(460.0, -985.0, 30.7),
    }
}

-- Police vehicles
Config.Vehicles = {
    { model = 'police', label = 'Police Cruiser', rank = 0 },
    { model = 'police2', label = 'Police Buffalo', rank = 2 },
    { model = 'police3', label = 'Police Interceptor', rank = 3 },
    { model = 'policeb', label = 'Police Bike', rank = 1 },
    { model = 'polmav', label = 'Police Maverick', rank = 5 },
}

-- Armory items
Config.Armory = {
    { name = 'weapon_combatpistol', label = 'Combat Pistol', price = 0 },
    { name = 'weapon_stungun', label = 'Taser', price = 0 },
    { name = 'weapon_nightstick', label = 'Nightstick', price = 0 },
    { name = 'weapon_flashlight', label = 'Flashlight', price = 0 },
    { name = 'radio', label = 'Radio', price = 0 },
    { name = 'handcuffs', label = 'Handcuffs', price = 0 },
}

-- Ranks
Config.Ranks = {
    { grade = 0, name = 'Cadet', canHire = false, canFire = false },
    { grade = 1, name = 'Officer', canHire = false, canFire = false },
    { grade = 2, name = 'Senior Officer', canHire = false, canFire = false },
    { grade = 3, name = 'Sergeant', canHire = true, canFire = false },
    { grade = 4, name = 'Lieutenant', canHire = true, canFire = true },
    { grade = 5, name = 'Captain', canHire = true, canFire = true },
    { grade = 6, name = 'Chief', canHire = true, canFire = true },
}
```

---

## UI Design Guidelines

### Color Scheme
```css
:root {
    --primary: #1a2634;      /* Dark blue background */
    --secondary: #243447;    /* Lighter panel background */
    --accent: #4a90d9;       /* Blue accent */
    --success: #4ade80;      /* Green for online/success */
    --danger: #ef4444;       /* Red for alerts/danger */
    --warning: #f59e0b;      /* Orange for warnings */
    --text-primary: #ffffff;
    --text-secondary: #94a3b8;
}
```

### Typography
- Primary font: 'Quicksand' (clean, modern)
- Headers: Uppercase, light weight
- Body: Regular weight, good readability

### Layout
- Sidebar navigation
- Tabbed interface for multitasking
- Responsive panels
- Smooth animations (no blur effects)

---

## File Structure

```
sb_police/
├── DESIGN.md              # This document
├── fxmanifest.lua
├── config.lua
├── client/
│   ├── main.lua           # Core client logic, keybinds, job checks
│   ├── mdt.lua            # MDT NUI handling
│   ├── interactions.lua   # Cuff, search, escort (Coming Soon)
│   ├── vehicles.lua       # Sirens, ALPR (Coming Soon)
│   ├── props.lua          # Cones, barriers (Coming Soon)
│   └── evidence.lua       # Evidence collection (Coming Soon)
├── server/
│   ├── main.lua           # Core server logic
│   ├── mdt.lua            # MDT data handling
│   ├── database.lua       # Database queries
│   └── callbacks.lua      # Server callbacks
├── shared/
│   └── penal_code.lua     # Default penal code entries
└── html/
    ├── index.html
    ├── css/
    │   └── style.css
    ├── js/
    │   ├── app.js
    │   └── mdt.js
    ├── img/
    │   ├── logo.png
    │   └── icons/
    ├── fonts/
    └── sounds/
```

---

## Development Notes

1. **No blur effects** - Per project guidelines, avoid `backdrop-filter: blur()` which causes black backgrounds in NUI
2. **Server-side validation** - All MDT actions must be validated server-side
3. **Integrate with sb_alerts** - Use existing dispatch system rather than creating new one
4. **Minimal client code** - Keep security-sensitive logic on server

---

## Changelog

### v1.0.0 (In Development)
- Initial MDT structure
- Database schema design
- Feature roadmap defined
