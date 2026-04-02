# sb_prison — Full Testing Checklist (v2)

Complete step-by-step guide to test the prison system.
**Solo testing** uses `/policedummy` — the dummy acts as the suspect.
**2 players**: Player A = Officer (police, on duty). Player B = Suspect (civilian).

---

## Pre-Flight

- [x] `ensure sb_prison` in server.cfg (after sb_apartments)
- [x] `screenshot-basic` running
- [x] `sb_phone_fivemanager_token` convar set
- [ ] F8 console on startup:
  - `[sb_prison] Database tables ready, loaded X active sentences`
  - `[sb_prison] Booking station zone registered`
  - `[sb_prison] Check-in NPC spawned at Bolingbroke intake`
- [ ] No errors in F8
- [ ] Bolingbroke blip visible on map (red, Sandy Shores area)

---

## 1. World Setup

### 1A. Booking Terminal at MRPD
**Zone:** `474.02, -1010.76, 22.34` (PC interaction BoxZone)
**Holding area:** `476.18, -1009.74, 21.95` (8m radius scan)

- [x] ALT near terminal → "Booking Terminal" + "Mugshot Camera" options
- [x] Options only appear for police on duty
- [x] No escort required — scans holding area for cuffed player

### 1B. Bolingbroke NPCs
- [x] Check-in NPC seated at `1687.36, 2587.64, 45.36` (Intake Officer)
- [x] Lobby Guard seated at visitor registration
- [x] Warden seated inside
- [x] Job Manager standing in yard
- [x] All guards invincible + armed

### 1C. Check-in NPC (Area Scan)
**Check-in area:** `1695.87, 2588.21, 45.92` (8m radius)

- [x] ALT on NPC → "Check In Prisoner" (police only)
- [x] No escort required — scans area for cuffed player
- [x] If no cuffed player in area → "No cuffed prisoner found"

---

## 2. Admin Commands (Solo Test)

### 2A. /jail — Short Sentence (MRPD)
```
/jail [your-id] 5 Testing short sentence
```

- [x] Teleported to random MRPD cell
- [x] Orange prison jumpsuit (DLC collection-based)
- [x] Timer: `SENTENCE: 02:30` (5 months x 30s)
- [x] No weapons, can punch with fists
- [x] Inventory confiscated

### 2B. Auto-Release (MRPD)
- [x] Timer reaches 00:00 → released
- [x] Teleported to MRPD front door
- [x] Civilian clothes + inventory restored

### 2C. /jail — Long Sentence (Bolingbroke)
```
/jail [your-id] 60 Testing long sentence
```

- [x] Teleported to Bolingbroke yard (bypass — skips intake)
- [x] Orange jumpsuit, timer running
- [x] Perimeter enforced (teleported back if leaving)

### 2D. /unjail (Bolingbroke)
```
/unjail [your-id]
```

- [x] Release walkout starts (3-step process)
- [x] Step 1: Strip to underwear at outfit area
- [x] Step 2: Civilian clothes + items restored at deposit area
- [x] Step 3: Walk to exit (instant, no progress bar)
- [x] Released — can walk/drive normally

### 2E. /unjail (MRPD / ON HOLD)
- [x] Instant release — teleport to MRPD front door
- [x] Clothes + items restored

---

## 3. Dashboard Booking Flow (2 Players)

### Setup
1. Player A: police, on duty
2. Player B: has criminal records with jail_time (via MDT F6)
3. Player A cuffs Player B near MRPD booking terminal
4. Player B stands cuffed in holding area (8m radius of terminal)

### 3A. Open Terminal
- [x] Player A: ALT on terminal → "Booking Terminal"
- [x] React NUI opens (dark overlay + terminal window)
- [x] 4-step wizard: Suspect Lookup → Profile & Charges → Arrest File → Confirmation

### 3B. Step 1 — Suspect Lookup
- [x] Search by name or citizen ID
- [x] Results list with name, CID, DOB, gender
- [x] Click suspect → Step 2

### 3C. Step 2 — Profile & Charges
- [x] Left: suspect info (name, CID, DOB, job)
- [x] Right: criminal records table (pending in red)
- [x] Bottom: pending sentence summary (months, real time, facility)
- [x] "Create Arrest File" button

### 3D. Step 3 — Arrest File
- [x] Charges table + sentence summary
- [x] Mugshot section with "Take Mugshot" button
- [x] Camera opens → front + side photos → NUI reopens with thumbnails
- [x] "Register & Sentence" button

### 3E. Step 4 — Confirmation
- [x] Green checkmark + booking summary
- [x] MRPD: blue status box
- [x] Bolingbroke: orange status box
- [x] "Close Terminal" button

### 3F. After Booking — Short Sentence (< 15 min)
- [x] **NO teleport** — suspect stays in place (officer escorts manually)
- [x] Officer notification: "Escort suspect to an MRPD cell"
- [x] Suspect: timer starts immediately, jail controls active
- [x] Inventory confiscated, weapons removed, orange jumpsuit
- [x] Officer manually walks suspect to a cell

### 3G. After Booking — Long Sentence (>= 15 min)
- [x] **NO teleport** — suspect stays in place (officer escorts to transport)
- [x] Officer notification: "Transport suspect to Bolingbroke"
- [x] Suspect: ON HOLD HUD text, jail controls active
- [x] Weapons removed (items kept until Bolingbroke intake)
- [x] Timer has NOT started (starts after Bolingbroke intake)
- [x] Officer escorts suspect to car → drives to Bolingbroke

---

## 4. Bolingbroke Intake (4-Step Process)

Continuing from 3G — officer drives suspect to Bolingbroke.

### 4A. Check-In
- [x] Officer leaves suspect cuffed in check-in area (8m radius)
- [x] Officer walks to NPC → ALT → "Check In Prisoner"
- [x] Progress bar: "Checking in prisoner..." (3s)
- [x] Suspect: intake process starts, ON HOLD text replaced by intake HUD

### 4B. Step 1 — Deposit Items (yellow marker)
- [x] HUD: "INTAKE - Go to Deposit Area"
- [x] Suspect walks to marker → progress bar → items confiscated
- [x] Appearance saved BEFORE stripping (sent with intakeDeposit event)
- [x] Stripped to underwear
- [x] Notification: "Items confiscated"

### 4C. Step 2 — Shower (yellow marker)
- [x] HUD: "INTAKE - Go to Shower"
- [x] Water particle effect for 5 seconds, player frozen
- [x] Notification: "Shower complete"

### 4D. Step 3 — Prison Outfit (yellow marker)
- [x] HUD: "INTAKE - Get Prison Uniform"
- [x] Orange jumpsuit applied (DLC collection resolver)
- [x] Notification: "Prison uniform issued"

### 4E. Step 4 — Enter Yard (yellow marker)
- [x] HUD: "INTAKE - Enter the Yard"
- [x] **Instant** — no progress bar, triggers on walk-through
- [x] Sentence timer starts, perimeter enforcement on
- [x] Notification: "Intake complete — serving X months"

---

## 5. Bolingbroke Release (3-Step Walkout)

Timer expires or `/unjail` triggers the release process.

### 5A. Step 1 — Remove Prison Uniform (green marker)
- [x] HUD: "RELEASE - Remove Prison Uniform"
- [x] Stripped to underwear (client-side)
- [x] Notification: "Prison uniform removed"

### 5B. Step 2 — Change & Collect Belongings (green marker)
- [x] HUD: "RELEASE - Change & Collect Belongings"
- [x] Server restores civilian clothes (appearance from confiscated record)
- [x] Server restores items (marks `returned = 1` immediately to prevent duplication)
- [x] Notification: "Belongings collected"

### 5C. Step 3 — Walk to Exit (green marker)
- [x] HUD: "RELEASE - Walk to Exit"
- [x] **Instant** — no progress bar, triggers on walk-through
- [x] **No teleport** — suspect walks out naturally
- [x] Jail state cleared, controls restored
- [x] Notification: "You have been released from Bolingbroke"

---

## 6. Persistence & Reconnect

### 6A. Disconnect While Serving
- [x] time_remaining saved to DB on disconnect

### 6B. Reconnect While Serving (MRPD)
- [x] Re-jailed in random MRPD cell (teleported)
- [x] Timer resumes with remaining time
- [x] Jumpsuit re-applied, controls restricted

### 6C. Reconnect While Serving (Bolingbroke)
- [x] Re-jailed at Bolingbroke yard (teleported)
- [x] Timer resumes, perimeter active, jumpsuit re-applied

### 6D. Reconnect While ON HOLD
- [x] Re-placed in MRPD cell (teleported for reconnect only)
- [x] ON HOLD HUD text reappears
- [x] Timer has NOT started

### 6E. Reconnect During Intake (transporting)
- [x] Status reset to on_hold
- [x] Must be re-escorted and checked in again

### 6F. Reconnect During Release
- [x] Server checks `confiscated.returned`:
  - `returned = 0` → full release process (step 1)
  - `returned = 1` → skip to exit (step 3), civilian clothes restored
- [x] **No item duplication** — returned flag prevents double-giving

### 6G. Sentence Expires While Offline
- [x] Released on next login (not re-jailed)

### 6H. Server Restart
- [x] Active sentences loaded from DB
- [x] ON HOLD + releasing sentences preserved

---

## 7. Inventory & Appearance

### 7A. Confiscation
- [x] MRPD: items + appearance confiscated at booking time
- [x] Bolingbroke: weapons removed at booking, items + appearance at intake Step 1
- [x] Appearance saved client-side BEFORE stripping (passed with intakeDeposit event)

### 7B. Restoration
- [x] MRPD: instant restore on release (items + appearance)
- [x] Bolingbroke: restored during release walkout (step 2)
- [x] `returned = 1` set BEFORE giving items (prevents duplication)

---

## 8. Edge Cases

### 8A. Double Jail
- [x] Already jailed → "Suspect is already serving a sentence"

### 8B. No Pending Charges
- [x] Booking without jail_time → "No pending jail time"

### 8C. Non-Police Access
- [x] /jail, /unjail require admin
- [x] Terminal + camera + check-in NPC: police only

### 8D. Resource Stop/Start
- [x] NPCs deleted, zones removed, jail state cleared
- [x] On restart: NPCs respawn, sentences reload from DB

---

## Config Reference

| Setting | Value | Meaning |
|---------|-------|---------|
| `MonthToSeconds` | 30 | 1 jail month = 30 real seconds |
| `ShortSentenceThreshold` | 900 | < 15 min = MRPD, >= 15 min = Bolingbroke |
| Sentence 5 months | 2:30 | MRPD |
| Sentence 30 months | 15:00 | Bolingbroke (first cutoff) |
| Sentence 60 months | 30:00 | Bolingbroke |

---

*Last Updated: February 9, 2026*
*Developer: Salah Eddine Boussettah*
