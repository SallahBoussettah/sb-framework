# sb_prison - Development Checklist

Inspired by rcore_prison reference, built from scratch for sb_core.
Reference coordinates from Prompt Interiors Bolingbroke MLO (rcore preset).

## Status Legend
- [x] DONE
- [ ] TODO
- [~] PARTIAL

---

## Phase 1: Core Infrastructure (Sprint 1) [DONE]

### Database & Resource
- [x] fxmanifest.lua with dependencies
- [x] config.lua (time conversion, locations, outfits, perimeter)
- [x] Auto-create 3 DB tables on startup (sentences, confiscated, bookings) + mugshots table
- [x] Load active sentences into memory cache on startup (incl. on_hold, releasing)
- [x] Auto-release expired sentences on startup
- [x] Auto-migrate: `served` column on criminal_records, `on_hold`/`releasing` status ENUM

### Booking System (MRPD) — React NUI Dashboard
- [x] Booking terminal BoxZone at MRPD PC (no NPC — area scan for cuffed player)
- [x] Mugshot camera station (fixed cam, rotate/zoom, W/S/A/D + scroll, E capture)
- [x] 4-step React dashboard: Suspect Lookup → Profile & Charges → Arrest File → Confirmation
- [x] Mugshot flow: NUI closes → camera → 2 shots (front + side) → NUI reopens with thumbnails
- [x] Mugshot gallery picker (recent photos from DB)
- [x] Sentence calculation (sum unserved jail_months × MonthToSeconds)
- [x] Auto-route: < 15min → MRPD, >= 15min → Bolingbroke (on_hold)
- [x] **No teleport after booking** — officer manually escorts suspect

### MRPD Cells (Short Sentences)
- [x] Officer escorts suspect to cell manually (notification: "Escort to MRPD cell")
- [ ] Cell door lock via sb_doorlock
- [x] Sentence timer starts immediately on booking
- [x] Auto-release when timer expires (teleport to MRPD front door)
- [x] Inventory + appearance confiscated at booking, restored on release

### Bolingbroke Transport (Long Sentences)
- [x] Officer notification: "Transport suspect to Bolingbroke"
- [x] ON HOLD status + HUD text while awaiting transport
- [x] Officer physically drives suspect to Bolingbroke
- [x] Check-in NPC at Bolingbroke (area scan — no escort required to NPC)
- [x] "Check In Prisoner" scans 8m radius for cuffed player

### Bolingbroke Intake (4-Step Process)
- [x] Step 1: Deposit — items confiscated, appearance saved (sent with event), stripped to underwear
- [x] Step 2: Shower — water PTFX particle effect, player frozen 5s
- [x] Step 3: Prison outfit — DLC collection-based orange jumpsuit (immune to clothing packs)
- [x] Step 4: Enter yard — **instant** (no progress bar), timer starts, perimeter on
- [x] Yellow cylinder markers + HUD text per step
- [x] Appearance saved BEFORE stripping (no race condition — data passed with intakeDeposit event)

### Bolingbroke Release (3-Step Walkout)
- [x] Triggered by timer expiry or /unjail
- [x] Step 1: Strip to underwear (client-side)
- [x] Step 2: Restore civilian clothes + collect items (server: releaseClothes + releaseItems)
- [x] Step 3: Walk to exit — **instant**, **no teleport** (walk out naturally)
- [x] Green cylinder markers + HUD text per step
- [x] Items marked `returned = 1` BEFORE giving back (prevents duplication on reconnect)
- [x] Timer HUD suppressed during release (release HUD takes over)

### Sentence Serving
- [x] Prisoner outfit (DLC collection-based resolver — immune to clothing pack changes)
- [x] Inventory confiscation (MRPD: at booking / Bolingbroke: at intake step 1)
- [x] Weapon removal (at booking for both)
- [x] Timer countdown HUD (native DrawText, top center, MM:SS)
- [x] Auto-release on time served (server-authoritative, 10s check loop)
- [x] Prison perimeter boundary (Bolingbroke only, point-in-polygon every 2s)
- [x] Disable combat/weapon controls while jailed (fists allowed)

### Persistence & Reconnect
- [x] Save time_remaining on disconnect
- [x] Re-jail on reconnect with remaining time (teleport to cell/yard)
- [x] Handle sentence expiry while offline
- [x] Reconnect during intake (transporting) → reset to on_hold
- [x] Reconnect during release → check `returned` flag:
  - returned=0 → full release process from step 1
  - returned=1 → skip to exit (step 3), appearance restored
- [x] **No item duplication** on reconnect (returned flag + status checks)

### Admin/Test Bypass
- [x] /jail [id] [months] [reason] — teleport directly, bypass booking/intake
- [x] /unjail [id] — Bolingbroke: triggers release walkout / MRPD: instant release
- [x] /prisontest — debug: show prison state info

### NPCs & Blips
- [x] 3 static guard NPCs at Bolingbroke (invincible, frozen, armed)
- [x] Check-in NPC at Bolingbroke (seated, sb_target entity)
- [x] Bolingbroke blip on map
- [x] No booking NPC at MRPD (replaced by terminal BoxZone)

### Exports & Integration
- [x] Server: IsPlayerJailed(cid), GetSentence(cid), GetBookingRecord(cid)
- [x] Client: IsJailed(), GetSentenceData()
- [x] sb_police: "Send to Jail" ALT-target on cuffed players
- [x] Resource cleanup on stop (delete guard peds, check-in NPC, zones, reset state)

---

## Phase 2: Prison Life (Sprint 2)

### Prison Credits Economy
- [ ] sb_prison_credits DB table (citizenid, balance)
- [ ] Warden NPC: check balance, check remaining sentence
- [ ] Earn credits from prison jobs
- [ ] Spend credits at canteen

### Canteen System
- [ ] Canteen NPC at vec3(1738.12, 2589.1, 45.42) model cs_guadalope
- [ ] Buy food/drinks with prison credits
- [ ] Restores hunger/thirst (sb_metabolism integration)
- [ ] Items: water, fries, sprunk, cigarettes (with prices)

### Prison Jobs
- [ ] Job Manager NPC at vec3(1780.69, 2554.73, 45.78)
- [ ] Electrician: 7 repair points (sb_minigame timing)
- [ ] Kitchen Cook: 6 cooking points (sb_progressbar sequences)
- [ ] Yard Cleanup: 8 pickup points (collect/deliver loop)
- [ ] Janitor: 8 cleaning points
- [ ] Bush Trimming: outdoor maintenance
- [ ] Laundry: 3 service points
- [ ] Job cooldown between jobs (2 min)
- [ ] Job rewards: credits + sentence reduction

### Sentence Reduction
- [ ] Working reduces sentence (configurable: e.g., 1 min work = 30s off)
- [ ] Maximum reducible percentage (e.g., 50% of total sentence)
- [ ] Good behavior bonus: no incidents = auto-reduction

---

## Phase 3: Prison Break (Sprint 3)

### Escape Mechanics
- [ ] Wire cutter item required (from dealer NPC)
- [ ] Inner wall breach: 3 fence locations (prop_fnclink_10d)
- [ ] Outer wall breach: 10 fence locations
- [ ] Wall cutting minigame (sb_minigame sequence)
- [ ] Wall repair by police (/repairwall command)

### Guard System
- [ ] 7 patrolling guards (waypoint walking routes)
- [ ] Guard view cone detection (160deg, 30m)
- [ ] Guards armed with pistols
- [ ] Auto-catch: detected player sent to solitary
- [ ] Guard alert on wall breach

### Alarm & Dispatch
- [ ] Prison alarm on escape/breach (sound + visual)
- [ ] sb_alerts dispatch to police: "Prison Break in Progress"
- [ ] /stopalarm command for police
- [ ] Auto-reset after 30 minutes
- [ ] Minimum police online requirement for escape attempts

### Consequences
- [ ] Escaped status in DB (status = 'escaped')
- [ ] Auto-create warrant on escape
- [ ] Additional sentence time if caught
- [ ] Solitary confinement for caught escapees

---

## Phase 4: Social & Community Service (Sprint 4)

### Phone Booths
- [ ] 2 phone booth locations at vec3(1758.491, 2568.952) and vec3(1762.021, 2568.468)
- [ ] Call contacts from prison (sb_phone integration)
- [ ] Time-limited calls

### Visitation
- [ ] Visitation area at Bolingbroke
- [ ] Civilians can visit inmates (designated area)
- [ ] Visitation hours/schedule
- [ ] Visitor registration

### Community Service (Alternative)
- [ ] Short sentences can opt for community service instead
- [ ] Community service locations in LS (park cleanup, trash pickup)
- [ ] Community service outfit (orange vest)
- [ ] GPS boundary for community service zones
- [ ] Completion = sentence served

### Letters/Messages
- [ ] Send messages to contacts from prison
- [ ] Receive messages from outside

---

## Phase 5: Advanced Features (Sprint 5)

### Solitary Confinement
- [ ] 7 solitary cells at vec3(1638-1656, 2578, 45.61)
- [ ] Triggered by guards/admin for rule violations
- [ ] Isolated: no jobs, no canteen
- [ ] Configurable duration (3-5 minutes)
- [ ] Auto-release from solitary to general population

### Prison Gym
- [ ] 6 sit-up bench locations
- [ ] 2 pull-up bar locations
- [ ] sb_gym integration (maintain strength/stamina)
- [ ] Gym benefits during sentence

### Contraband
- [ ] Dealer NPC at vec3(1789.81, 2487.96, 45.65)
- [ ] Buy smuggled items: knife, wire cutter, phone
- [ ] Shiv crafting (combine items)
- [ ] Risk of guard search/confiscation

### Other
- [ ] Gang territories in prison yard (future sb_gangs)
- [ ] Inmate fights with injury system
- [ ] Medical bay NPC for healing
- [ ] Inmate reputation system (tracked across sentences)
- [ ] Cigar/cigarette production minigame

---

## Phase 6: Administration (Sprint 6)

### Warden Dashboard (NUI)
- [ ] View all current inmates
- [ ] View sentence details, time remaining
- [ ] View booking records with mugshots
- [ ] Transfer prisoners between MRPD/Bolingbroke

### Management
- [ ] Sentence modification (admin only): add/reduce time
- [ ] Prison lockdown mode (all inmates to cells)
- [ ] Guard patrol route management
- [ ] Statistics: total inmates, avg sentence, escape rate

### MDT Integration
- [ ] View inmate status from sb_police MDT
- [ ] View mugshots in citizen profile
- [ ] Booking history tab in citizen records

### Parole & Bail
- [ ] Parole system: early release with GPS monitoring
- [ ] Bail system: pay at courthouse for pre-trial release
- [ ] Ankle monitor item for parolees
- [ ] Parole violation -> re-arrest

---

## Phase 7: Booking Enhancements (Sprint 7) [MOSTLY DONE]

### Realistic Booking Process
- [ ] Fingerprint scan (progress bar + animation)
- [x] Mugshot: front + side profile (2 photos, camera station)
- [x] Personal property inventory (confiscated items saved to DB as JSON)
- [x] Change into prison uniform at intake (Bolingbroke) or booking (MRPD)
- [x] Booking desk NUI dashboard (React 4-step wizard)
- [x] Realistic intake process: deposit → shower → outfit → yard (4 steps)
- [x] Realistic release process: strip → dress → collect → exit (3 steps)

### Mugshot Gallery
- [x] Mugshots stored in DB (sb_prison_mugshots + booking record)
- [x] Mugshot picker in dashboard (recent photos)
- [ ] Mugshots viewable in MDT citizen profile
- [ ] Mugshot history (all previous bookings)
- [ ] Mugshot printed on prisoner ID card item

### Transport Enhancements
- [ ] Prison bus vehicle for mass transport
- [ ] Transport route GPS waypoint assistance
- [ ] Transport log (who transported, when, which vehicle)
- [x] Prisoner cuffed during transport (officer escorts manually)

---

## Integration Points

### Current
- [x] sb_core — player data, money, jobs, callbacks
- [x] sb_police — charges (jail_time), cuffing, escort, "Send to Jail" target, test dummy
- [x] sb_inventory — confiscate/restore items (AddItem/RemoveItem)
- [x] sb_clothing — save/restore appearance (GetCurrentAppearance/ApplyAppearance)
- [x] sb_notify — notifications (client event, no server export)
- [x] sb_target — BoxZone (terminal) + AddTargetEntity (check-in NPC)
- [x] sb_progressbar — intake/release/check-in progress bars
- [x] screenshot-basic — mugshot capture + fivemanager upload
- [ ] sb_doorlock — MRPD cell doors
- [x] oxmysql — database (4 tables + migration)

### Future
- [ ] sb_alerts -- prison break dispatch (Phase 3)
- [ ] sb_phone -- phone booth calls (Phase 4)
- [ ] sb_metabolism -- canteen food/drink (Phase 2)
- [ ] sb_minigame -- prison jobs & escape (Phase 2/3)
- [ ] sb_gym -- prison gym (Phase 5)
- [ ] sb_gangs -- gang territories (Phase 5)

---

## Bolingbroke Coordinates (Prompt Interiors MLO)

### Key Locations
- Release/Gate: vec4(1833.82, 2584.97, 45.89, 271.249)
- Yard Center: vec4(1696.727, 2565.864, 45.564, 170.0)
- Canteen NPC: vec3(1738.12, 2589.1, 45.42) -- cs_guadalope
- Warden NPC: vec3(1767.28, 2577.0, 46.0) -- s_m_m_prisguard_01
- Job Manager: vec3(1780.69, 2554.73, 45.78) -- s_m_m_prisguard_01
- Lobby Guard: vec3(1838.02, 2581.45, 45.89) -- s_m_m_prisguard_01
- Dealer NPC: vec3(1789.81, 2487.96, 45.65) -- s_m_y_prismuscl_01

### Solitary Cells (7)
- vec3(1638.96, 2578.99, 45.61) through vec3(1656.21, 2578.69, 45.61)

### Guard Patrol Positions (7)
- vec3(1770.100, 2538.464, 45.564) through vec3(1757.549, 2431.591, 45.502)

### Prison Break Walls
- Inner (3): around vec3(1660-1772, 2487-2534, 44.537)
- Outer (10): along perimeter edges

### Job Locations
- Electrician: 7 points in yard area
- Cooking: 6 points near canteen
- Yard Cleanup: 8 points across yard

### Gym
- Sit-ups: 6 benches near vec3(1635-1642, 2522-2535, 45.95)
- Pull-ups: 2 bars near vec3(1643-1649, 2527-2530, 45.56)

### Phone Booths
- Booth 1: vec3(1758.491, 2568.952, 45.564)
- Booth 2: vec3(1762.021, 2568.468, 45.564)

---

*Last Updated: February 9, 2026*
*Developer: Salah Eddine Boussettah*
