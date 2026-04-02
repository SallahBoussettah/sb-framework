# SB_POLICE Implementation Checklist

A prioritized feature list for building a complete police system inspired by Origen Police.
Each feature is marked with its current status and implementation priority.

---

## Status Legend
- [x] **DONE** - Feature is complete and working
- [ ] **TODO** - Feature needs to be implemented
- [~] **PARTIAL** - Feature is started but incomplete
- [COMING SOON] - Planned for future, shown in UI as placeholder

---

## PHASE 1: Core Foundation (PRIORITY: CRITICAL)
*These are required for a functional police system*

### MDT Interface
- [x] MDT menu opens/closes with keybind (F6)
- [x] Modern dark theme UI matching Origen style
- [x] Sidebar navigation with icons
- [x] Dashboard showing officer info
- [x] "Coming Soon" placeholders for unfinished features
- [x] NUI focus management (cursor shows/hides properly)
- [x] Escape key closes MDT
- [x] Premium full-screen MDT with bg.jpg, LSPD badge, tile home screen ✅ Sprint 8
- [x] Orange accent design system (#ff6b35) ✅ Sprint 8
- [x] Font Awesome icons, bankgothic heading font ✅ Sprint 8

### Duty System
- [x] Clock in/out functionality
- [x] Duty status saved to database
- [x] On-duty officers list in MDT
- [x] Duration tracking (minutes on duty)
- [x] Duty history page (Time Clock in MDT) ✅ Sprint 7
- [x] Weekly/monthly duty stats ✅ Sprint 7
- [x] Live current shift counter ✅ Sprint 7
- [x] Boss "All Officers" duty overview (last 7 days) ✅ Sprint 7
- [x] Duty pay every 15 minutes (sb_core paycheck system, synced via SetJobDuty) ✅ Sprint 7.1
- [x] Dashboard shift timer (shows start time + live duration) ✅ Sprint 7.1
- [x] Duty requirements for certain actions ✅ Sprint 8
- [x] Duty persistence across resource restarts (RestoreDutyState) ✅ Sprint 8

### Job Detection
- [x] Detects if player has police job
- [x] Updates when job changes (via event)
- [x] Blocks non-police from opening MDT
- [x] Grade/rank restrictions for certain features (grade >= 5 for boss actions in MDT)

---

## PHASE 2: Search & Records (PRIORITY: HIGH)
*Core MDT functionality for police work*

### Citizen Search
- [x] Search citizens by name
- [x] Search citizens by citizen ID
- [x] Display search results in MDT
- [x] Detailed citizen profile view (React component with 3 tabs)
- [x] Criminal history display (Criminal Records tab)
- [x] Licenses display (driver's license, weapons permit)
- [x] Add notes to citizen records ✅ Sprint 8
- [x] Warrants system (active warrants flag) ✅ Sprint 7
- [x] Employment history (shows job in profile)

### Vehicle Search
- [x] Search vehicles by plate number
- [x] Display owner information
- [x] Detailed vehicle profile view (React component)
- [x] Vehicle registration status
- [x] Insurance status
- [x] Vehicle flags (stolen, BOLO)
- [ ] Registration history

### Criminal Records
- [x] Penal code database (40+ charges)
- [x] Categories: Traffic, Misdemeanor, Felony, Weapons, Drugs, Financial, Government
- [x] Fine amounts and jail times defined
- [x] Add charges to citizen record (Add Charges tab in profile)
- [x] Multiple counts of same charge (e.g. 3x Speeding) ✅ Sprint 7.1
- [x] Real-time profile update after applying charges ✅ Sprint 7.1
- [x] Calculate total fine/jail time (auto-calculated)
- [x] Record conviction history (sb_police_criminal_records table)
- [x] Charges deduct money from citizen (cash then bank, online + offline) ✅ Sprint 8
- [x] amount_paid tracking on criminal records ✅ Sprint 8
- [ ] Expunge records (admin only)

---

## PHASE 3: Reports System (PRIORITY: HIGH)
*Documentation and record keeping*

### Basic Reports
- [x] Create new report (database entry)
- [x] Report author tracking
- [x] Report editor (title, description, location)
- [x] Add involved citizens to report (suspects & victims via SearchPopup) ✅ Sprint 7
- [x] Add involved vehicles to report (plate search via SearchPopup) ✅ Sprint 7
- [x] Add evidence to report (text entries) ✅ Sprint 7
- [x] Add officers to report (+ "Add Self" button) ✅ Sprint 7
- [x] Remove items from report sections (X button per item) ✅ Sprint 7
- [x] Report status (open/closed/pending) - functional buttons ✅ Sprint 7
- [x] Report filtering by status
- [x] Report search functionality

### Advanced Reports
- [ ] Report templates (arrest, incident, traffic stop)
- [ ] Report sharing between officers
- [ ] Report approval workflow
- [ ] Report PDF export
- [ ] Report history/audit log

---

## PHASE 4: Dispatch & Alerts (PRIORITY: HIGH)
*Integration with sb_alerts for emergency calls*

### Alert System
- [x] Receive alerts from sb_alerts
- [x] Display alerts in MDT
- [x] Alert priority levels (low/medium/high)
- [x] Alert GPS waypoint (mark on map) ✅ Sprint 8
- [x] Alert response (accept/decline) ✅ Sprint 8
- [x] Alert status tracking ✅ Sprint 8
- [x] Multiple officers per alert (responder tracking) ✅ Sprint 8

### Dispatch Board
- [x] Live dispatch board in MDT (Dispatch.tsx, 2-column layout) ✅ Sprint 8
- [x] Active incidents list (priority filtering) ✅ Sprint 8
- [ ] Assign units to incidents
- [x] Incident status updates (accept/decline/resolve) ✅ Sprint 8
- [x] Clear incidents (resolve button) ✅ Sprint 8

---

## PHASE 5: Field Actions (PRIORITY: MEDIUM) ✅ SPRINT 2 COMPLETE
*In-game police interactions*

### Cuffing System ✅
- [x] Soft cuff (hands in front)
- [x] Hard cuff (hands behind back)
- [x] Cuff animation (synced officer/target)
- [x] Movement restriction when cuffed
- [x] Uncuff action
- [ ] Cuff escape attempt (minigame?)
- [x] Cuff item requirement (optional config)

### Escort & Transport ✅
- [x] Escort grabbed citizen (attach + walk together)
- [x] Put in vehicle (back seat)
- [x] Take out of vehicle
- [x] Vehicle targeting (aim at vehicle to put in/take out)
- [ ] Seat position selection
- [ ] Transport to jail
- [ ] Transport to hospital

### Search & Seizure ✅
- [x] Pat down (quick search with animation)
- [x] Full search (opens sb_inventory)
- [ ] Seize items
- [ ] Evidence logging
- [ ] Return seized items

### Test Dummy System ✅ (NEW)
- [x] /policedummy - Spawn test NPC
- [x] /removepolicedummy - Remove test NPC
- [x] /dummystate - Check dummy state
- [x] Full interaction support (cuff, escort, search)

### Citations & Fines ✅ Sprint 8
- [x] Write traffic citation (/cite command + NUI form) ✅ Sprint 8
- [x] Calculate fine from penal code ✅ Sprint 8
- [x] Issue citation to citizen ✅ Sprint 8
- [x] Pay fine at court (Courthouse at vector3(242.0, -1072.0, 29.0)) ✅ Sprint 8
- [x] Outstanding fines tracking (criminal records + citations) ✅ Sprint 8

### Investigation Tools ✅ Sprint 9
- [x] Radar gun (/radar, speed detection, lock, direction) ✅ Sprint 9
- [x] GSR test (gunshot residue, checks recent weapon fire) ✅ Sprint 9
- [x] Breathalyzer test (BAC check, future alcohol hook) ✅ Sprint 9
- [x] Vehicle search (opens trunk/glovebox inventory) ✅ Sprint 9

---

## PHASE 6: Vehicle Features (PRIORITY: MEDIUM)
*Police vehicle functionality*

### Sirens & Lights ✅ SPRINT 4 COMPLETE
- [x] Siren controller (3 tones: wail, yelp, hi-lo)
- [x] Light toggle (L key)
- [x] Siren cycle (; key)
- [x] Air horn (E key hold)
- [x] Network sync (all players hear/see same state)
- [x] Native GTA sounds mode (like Origen)
- [x] Custom NUI sounds mode (optional .ogg files)
- [x] Auto-cleanup on vehicle exit

### ALPR (Automatic License Plate Reader) ✅ SPRINT 6 COMPLETE
- [x] Scan nearby vehicles (front/rear raycast)
- [x] Display plate on HUD (React overlay)
- [x] Check plate against database (sb_police_vehicle_flags)
- [x] Alert on wanted/stolen vehicle (audio + notification)
- [x] Lock plate feature (NUMPAD8)
- [ ] ALPR history log (future)

### Radar Gun ✅ Sprint 9
- [x] Item-based (`radar_gun` from armory) ✅ Sprint 9
- [x] Aim-to-scan (right-click to activate scanning) ✅ Sprint 9
- [x] Speed detection (raycast target vehicle) ✅ Sprint 9
- [x] Lock target speed (/radarlock) ✅ Sprint 9
- [x] Display on HUD (NUI overlay, shows on aim) ✅ Sprint 9
- [x] Direction detection (approaching/receding/crossing) ✅ Sprint 9
- [x] Works on foot and in vehicle ✅ Sprint 9

### Spike Strips ✅ (Moved to Props System)
- [x] Deploy spike strip (/spike)
- [x] Spike strip prop (p_ld_stinger_s)
- [x] Vehicle tire damage on contact
- [x] Pick up spike strip (/removeprop)
- [x] Limited props per officer (10)

---

## PHASE 7: Evidence System (PRIORITY: MEDIUM)
*Crime scene investigation*

### Evidence Collection
- [ ] Evidence markers
- [ ] Collect evidence items
- [ ] Evidence types (blood, casings, weapons, drugs, fingerprints)
- [ ] Evidence bag items
- [ ] Evidence locker storage

### Evidence Processing
- [ ] Fingerprint analysis
- [ ] DNA matching
- [ ] Ballistics matching
- [ ] Evidence chain of custody
- [ ] Evidence report generation

---

## PHASE 8: Props & Equipment (PRIORITY: LOW) ✅ SPRINT 3 COMPLETE & TESTED
*Visual props for roleplay*

### Barriers & Cones ✅ TESTED
- [x] Place traffic cone (/cone, /conelighted) ✓
- [x] Place barrier (/barrier, /barrierarrow) ✓
- [ ] Place police tape
- [x] Remove props (/removeprop, /clearprops) ✓
- [x] Prop limit per officer (10) ✓

### Other Props ✅ TESTED
- [ ] Speed limit sign
- [ ] Road closed sign
- [ ] Police tent
- [ ] Evidence tent
- [x] Flares (/flare - with particle effect) ✓

---

## PHASE 9: Advanced Features (PRIORITY: LOW)
*Features from origen_police reference*

### Tackling (Sprint 3) ✅ COMPLETE & TESTED
- [x] Tackle suspect (diving animation, G key when sprinting) ✓
- [x] Tackle cooldown (10 seconds) ✓
- [x] Tackle distance check (3m range) ✓
- [x] Tackle stun effect (ragdoll target 3 seconds) ✓
- [x] Works on players and NPCs ✓

### Props System (Sprint 3) ✅ COMPLETE & TESTED
- [x] Place traffic cones (/cone, /conelighted) ✓
- [x] Place barriers (/barrier, /barrierarrow) ✓
- [x] Deploy spike strips (/spike - bursts tires) ✓
- [x] Place road flares (/flare - with particle) ✓
- [x] Remove props (/removeprop, /clearprops) ✓
- [x] Per-officer prop limit (10) ✓
- [x] Props auto-removed when going off duty ✓

### K9 Unit (Sprint 5) ✅ COMPLETE
- [x] K9 spawn/despawn from K9 vehicles
- [x] K9 follow command
- [x] K9 stay command
- [x] K9 sit command
- [x] K9 lie down command
- [x] K9 attack suspect (aim + E key, or /k9attack)
- [x] K9 search area (detects drugs in player inventory/vehicle stash)
- [x] K9 return to car command
- [x] K9 menu (K keybind)
- [x] Grade requirement (Officer III+)
- [x] K9-only vehicles (SUVs)
- [ ] K9 track scent (future)

### Helicopter Camera (Future)
- [ ] Thermal vision toggle
- [ ] Night vision toggle
- [ ] Spotlight control
- [ ] Camera zoom (1x-15x)
- [ ] Target lock and tracking

### SWAT Features (Future)
- [ ] Breaching charges
- [ ] Flashbang
- [ ] Shield
- [ ] Rappelling

---

## PHASE 10: Administration (PRIORITY: LOW)
*Management and configuration*

### Officer Management ✅ Sprint 7
- [x] View all officers (full roster in MDT Officers page) ✅ Sprint 7
- [x] On-duty officers with live status (available/busy/responding/unavailable) ✅ Sprint 7
- [x] Promote/demote officers (/promote, /demote, /setgrade + MDT roster)
- [x] Fire officers (/fire + MDT roster) - works for online + offline ✅ Sprint 7
- [x] Hire officers (/hire)
- [x] Duty history reports (Time Clock page with personal history) ✅ Sprint 7
- [x] Boss "All Officers" duty view (last 7 days, grouped) ✅ Sprint 7
- [ ] Performance stats

### Configuration
- [ ] In-game penal code editor
- [ ] Fine/jail time adjustments
- [ ] Add/remove charges
- [ ] Vehicle whitelist management

---

## Current Server Integration Status

### Working Integrations
- [x] sb_core - Player data, job system
- [x] sb_notify - Notifications
- [x] oxmysql - Database operations
- [x] sb_alerts - Dispatch alerts (full integration, real-time push) ✅ Sprint 8
- [x] sb_target - Third-eye interactions (cuff, search, escort, GSR, breathalyzer) ✅
- [x] sb_progressbar - Action progress bars ✅
- [x] sb_inventory - Search suspect inventory ✅

### Planned Integrations
- [ ] sb_jail/sb_prison - Jail system (when created)
- [ ] sb_metabolism - Alcohol system for breathalyzer (when alcohol added)

---

## Database Tables

### Existing Tables
- [x] `sb_police_penal_code` - Criminal charges
- [x] `sb_police_duty_clock` - Duty tracking
- [x] `sb_police_reports` - Police reports
- [x] `sb_police_citations` - Traffic citations ✅ Sprint 8
- [x] `sb_police_citizen_notes` - Officer notes on citizens ✅ Sprint 8
- [x] `sb_police_warrants` - Active warrants ✅ Sprint 7
- [x] `sb_police_criminal_records` - Conviction history (+ amount_paid) ✅ Sprint 8
- [x] `sb_police_bolos` - Be On Lookout alerts ✅ Sprint 7
- [x] `sb_police_vehicle_flags` - Stolen/wanted vehicles

### Needed Tables
- [ ] `sb_police_evidence` - Evidence items (future)

---

## Implementation Order (Recommended)

### Sprint 1: Complete MDT Core ✅ DONE
1. ✅ Citizen profile detail view
2. ✅ Vehicle profile detail view
3. ✅ Add charges to citizens
4. ✅ Basic report editing

### Sprint 2: Field Basics ✅ DONE
1. ✅ Cuffing system (soft/hard with synced animations)
2. ✅ Escort system (attach-based, walks with officer)
3. ✅ Put in/out of vehicle
4. ✅ Pat down search (opens inventory)
5. ✅ Test dummy system for solo testing

### Sprint 3: Tackle & Props ✅ DONE & TESTED
1. ✅ Tackle system (G key when sprinting, 3m range, 10s cooldown) ✓
2. ✅ Traffic cones (/cone, /conelighted), barriers (/barrier, /barrierarrow) ✓
3. ✅ Spike strips (/spike) - bursts all tires when vehicle drives over ✓
4. ✅ Road flares (/flare) - with particle effect, auto-remove after 5 min ✓
5. ✅ Prop limit per officer (10), auto-cleanup on off-duty ✓

### Sprint 3.5: Station Interactions ✅ DONE
1. ✅ Physical Duty clock in/out point (sb_target)
2. ✅ Armory system (weapons/items by grade, /armory command)
3. ✅ Locker system (uniform, civilian clothes, personal storage)
4. ✅ Police Garage - React NUI menu with categories
5. ✅ 24 police vehicles from carpacks (10-grade system)
6. ✅ NPC-based garage interaction (2 garage NPCs)
7. ✅ Spawn point occupation checking (finds available spots)
8. ✅ Horn-to-store system (press E at spawn point to store)
9. ✅ Vehicle keys integration (keys given on spawn, removed on store)
10. ✅ Boss Menu (rank 9 only: /hire, /fire, /promote, /demote, /setgrade)
11. ✅ Evidence Locker (shared stash)
12. ✅ Impound system (impound vehicles, view impounded)
13. ✅ Duty sync with /duty command (sb_admin integration)

### Sprint 4: Sirens & Lights ✅ DONE
1. ✅ Toggle emergency lights (L key)
2. ✅ Cycle siren tones (; key) - 3 tones
3. ✅ Air horn (E key hold)
4. ✅ Network sync for all players
5. ✅ Dual mode: native GTA sounds or custom .ogg files

### Sprint 5: K9 Unit ✅ DONE
1. ✅ Spawn K9 from K9 vehicles (K key in vehicle, opens trunk)
2. ✅ K9 follow/stay/sit/lie down commands
3. ✅ K9 attack suspect (aim + E, or /k9attack)
4. ✅ K9 drug search (checks player inventories + vehicle stashes)
5. ✅ K9 return to car (runs back and despawns)
6. ✅ Grade restriction (Officer III+)
7. [ ] K9 track scent (future enhancement)

### Sprint 6: ALPR System ✅ DONE
1. ✅ ALPR toggle (/alpr command)
2. ✅ Front vehicle scanning (raycast)
3. ✅ Rear vehicle scanning (raycast)
4. ✅ Plate display with real GTA plate images (6 styles)
5. ✅ Database check for stolen/BOLO flags
6. ✅ Visual alert on flagged vehicles (red glow + STOLEN/BOLO badge)
7. ✅ Lock plate feature (F9 / /alprlock)
8. ✅ React HUD overlay (minimalist floating plates)
9. ✅ Auto-disable on vehicle exit
10. ✅ Police vehicle restriction (ALPR-equipped only)
11. ✅ Duplicate flag prevention (can't mark stolen twice)
12. ✅ Real-time flag sync (other cops marking stolen updates your ALPR instantly)
13. ✅ Alert sound plays once per plate (no spam during chases)
14. ✅ Plate text color matches GTA plate style index

### Sprint 7: Warrants/BOLO, Officers, Time Clock & Report Improvements ✅ DONE
1. ✅ Warrants page (3 tabs: warrants, person BOLOs, vehicle flags)
2. ✅ Issue/close warrants with citizen search, charges, priority
3. ✅ Create/close person BOLOs (name, description, reason, last seen)
4. ✅ Vehicle flags read-only tab (from existing sb_police_vehicle_flags)
5. ✅ Citizen WANTED badge now functional (driven by active warrants count)
6. ✅ Officers page (2 tabs: on-duty with status, full roster)
7. ✅ Officer status updates (available/busy/responding/unavailable)
8. ✅ Boss roster actions: promote/demote/fire (grade >= 5, works online + offline)
9. ✅ Time Clock page (week/month stats, current shift live counter)
10. ✅ Duty history table (personal records)
11. ✅ Boss "All Officers" duty view (last 7 days, grouped by officer)
12. ✅ Reports: add/remove suspects, victims, vehicles, evidence, officers
13. ✅ Reports: functional status buttons (open/pending/closed)
14. ✅ SearchPopup reusable component (citizen/vehicle search modal)
15. ✅ 2 new DB tables: sb_police_warrants, sb_police_bolos

### Sprint 8: Charges, Citations, Dispatch, Notes, Visual Redesign ✅ DONE
1. ✅ Charges & Fines rework (cash→bank deduction, online+offline, amount_paid tracking)
2. ✅ Citations system (sb_police_citations table, /cite command, NUI form)
3. ✅ Courthouse fine payment (criminal records + citations, cash→bank)
4. ✅ Dispatch page (2-column layout, accept/decline/GPS/resolve, priority filtering)
5. ✅ sb_alerts integration (no duplicate tracking, real-time push to React)
6. ✅ Citizen notes (add/delete, officer attribution, boss delete permission)
7. ✅ Duty enforcement (server checks onDutyOfficers for all sensitive actions)
8. ✅ MDT visual redesign (full-screen, bg.jpg, tile home, orange accent, glass tiles)
9. ✅ Duty persistence across resource restarts (RestoreDutyState, timer continuity)
10. ✅ 2 new DB tables: sb_police_citations, sb_police_citizen_notes

### Sprint 9: Radar Gun, GSR Test, Investigation Tools ✅ DONE
1. ✅ Radar gun (/radar toggle, speed detection, lock speed, direction)
2. ✅ GSR test (gunshot residue check via sb_target)
3. ✅ Breathalyzer test (BAC check, future alcohol hook)
4. ✅ Vehicle search (opens trunk inventory via sb_target)
5. ✅ Radar NUI overlay (speed, direction, lock indicator)

### Future Sprints
- ALPR history log
- Helicopter camera (thermal/night vision, spotlight, zoom)
- Evidence system (markers, collection, processing)
- Bodycam system
- Ankle monitor/tracker

---

## Notes

- All features should work WITHOUT Origen code - we build from scratch
- Use Origen only as REFERENCE for UI/UX design and feature inspiration
- Reference scripts available at: `[future-use]/police/origin_police/`
- Prioritize features that enable basic police roleplay first
- "Coming Soon" features keep the UI polished while incomplete
- Test each feature thoroughly before moving to next
- Integrate with existing sb_* scripts where possible
- Test dummy (/policedummy) available for solo testing

## Origin Police Feature Reference

The following features from `origin_police` have been identified for implementation:

| Module | File | Status |
|--------|------|--------|
| Cuffing | interaction.lua | ✅ Implemented |
| Escort | interaction.lua | ✅ Implemented |
| Tackle | tackle.lua | ✅ Implemented (Sprint 3) |
| Props | props.lua | ✅ Implemented (Sprint 3) |
| Station Duty | duty.lua | ✅ Implemented (Sprint 3.5) |
| Armory | armory.lua | ✅ Implemented (Sprint 3.5) |
| Locker | locker.lua | ✅ Implemented (Sprint 3.5) |
| Garage | garage.lua | ✅ Implemented (Sprint 3.5) |
| Boss Menu | boss.lua | ✅ Implemented (Sprint 3.5) |
| Sirens | sirens.lua | ✅ Implemented (Sprint 4) |
| K9 | k9.lua | ✅ Implemented (Sprint 5) |
| ALPR | alpr.lua | ✅ Implemented (Sprint 6) |
| Radar | radar.lua | ✅ Implemented (Sprint 9) |
| Helicam | helicam.lua | Future |
| Evidence | evidences.lua | Future |
| Vehicle Interact | vehicleinteract.lua | Future |

---

## Sprint 3 Commands Reference

| Command | Description |
|---------|-------------|
| G (keybind) | Tackle suspect (must be sprinting) |
| /props | Show all prop commands |
| /cone | Place traffic cone |
| /conelighted | Place lighted cone |
| /barrier | Place road barrier |
| /barrierarrow | Place arrow barrier |
| /flare | Place road flare (5 min duration) |
| /spike | Deploy spike strip |
| /removeprop | Remove nearest prop |
| /clearprops | Remove all your props |
| /propscount | Show placed props count |

## Sprint 4 Siren Controls

| Key/Command | Description |
|-------------|-------------|
| L (keybind) | Toggle emergency lights on/off |
| ; (keybind) | Cycle siren tones (3 tones, then off) |
| E (hold) | Air horn (hold to sound) |
| /sirenoff | Force turn off all sirens |
| /sirenstate | Debug: show current siren state |
| /testsiren | Debug: manually trigger siren cycle |

## Sprint 5: K9 Commands

| Key/Command | Description |
|-------------|-------------|
| K (keybind) | Open K9 menu / Deploy K9 if in K9 vehicle |
| /k9 | Same as K keybind |
| /k9follow | K9 follows you |
| /k9stay | K9 sits and stays |
| /k9sit | K9 sits |
| /k9lie | K9 lies down |
| /k9search | K9 searches area for drugs (30m radius) |
| /k9return | K9 returns to vehicle and despawns |
| /k9dismiss | Immediately despawn K9 |
| /k9attack | Attack nearest NPC |
| E (when aiming) | Send K9 to attack aimed target |
| /k9test | Debug: show K9 state |

## Sprint 6: ALPR Commands

| Key/Command | Description |
|-------------|-------------|
| /alpr | Toggle ALPR on/off |
| F9 (keybind) | Lock/unlock current plate |
| /alprlock | Lock/unlock plate (same as keybind) |
| /alprstop | Force stop ALPR |
| /alprtest | Debug: show ALPR state |
| /clearstolen [plate] | Remove stolen flag (testing) |
| /clearbolo [plate] | Remove BOLO flag (testing) |

## Sprint 9: Investigation Commands

| Key/Command | Description |
|-------------|-------------|
| /radar | Toggle radar gun on/off |
| /radarlock | Lock/unlock current speed reading |
| /radartest | Debug: show radar state |

**Radar Requirements:**
- Must be on duty
- Works on foot or in any police vehicle

**ALPR Requirements:**
- Must be on duty
- Must be in ALPR-equipped vehicle (most patrol/pursuit vehicles)

**K9 Requirements:**
- Must be Officer III+ (grade 3+)
- Must be on duty
- Must be in K9-enabled vehicle (Silverado, Durango, SWAT SUVs)

## Utility Commands

| Command | Description |
|---------|-------------|
| /refreshjob | Manually refresh job data (if MDT not working) |
| /policedebug | Show debug info (job, duty, MDT state) |

## Station Commands

| Command | Description |
|---------|-------------|
| /armory [number] | Take weapon from armory (by number) |
| /pgarage [number] | Spawn police vehicle (by number) |

## Boss Commands (Rank 9 Only)

| Command | Description |
|---------|-------------|
| /hire [id] | Hire player as Police Cadet |
| /fire [id] | Fire police employee |
| /promote [id] | Promote officer one rank |
| /demote [id] | Demote officer one rank |
| /setgrade [id] [grade] | Set specific grade (0-7) |

---

## What's Next - Remaining Work

### High Priority (Core Police RP)
| Feature | Phase | Notes |
|---------|-------|-------|
| ~~Warrants system~~ | ~~Phase 2~~ | ~~✅ Sprint 7~~ |
| ~~Report improvements~~ | ~~Phase 3~~ | ~~✅ Sprint 7~~ |
| ~~Citizen notes~~ | ~~Phase 2~~ | ~~✅ Sprint 8~~ |
| ~~Dispatch & Alerts~~ | ~~Phase 4~~ | ~~✅ Sprint 8~~ |
| ~~Citations & Fines~~ | ~~Phase 5~~ | ~~✅ Sprint 8~~ |
| ~~Radar gun~~ | ~~Phase 6~~ | ~~✅ Sprint 9~~ |
| Assign units to dispatch | Phase 4 | Unit assignment for incidents |
| Report templates | Phase 3 | Arrest, incident, traffic stop templates |

### Medium Priority (Enhanced RP)
| Feature | Phase | Notes |
|---------|-------|-------|
| ALPR history log | Phase 6 | Log all scanned plates with timestamps |
| Helicopter camera | Phase 9 | Thermal/night vision, spotlight, zoom, target lock |
| Evidence system | Phase 7 | Markers, collection, bagging, locker, processing |
| Bodycam system | Phase 9 | Record interactions for evidence |

### Low Priority (Polish & Future)
| Feature | Phase | Notes |
|---------|-------|-------|
| Cuff escape minigame | Phase 5 | Suspect can attempt escape |
| Transport to jail | Phase 5 | Requires sb_jail (not yet created) |
| SWAT features | Phase 9 | Breaching, flashbang, shield, rappel |
| K9 track scent | Phase 9 | Follow suspect trail |
| Officer performance stats | Phase 10 | Arrest counts, activity metrics |
| In-game penal code editor | Phase 10 | Admin tool for charges |
| Ankle monitor/tracker | Phase 9 | GPS tracking for suspects |
| Police tape & signs | Phase 8 | Scene management props |

### Integrations Still Needed
| Integration | Purpose |
|-------------|---------|
| sb_jail/sb_prison | Jail system (needs to be created first) |
| sb_metabolism | Alcohol system for breathalyzer integration |

---

*Last Updated: February 6, 2026 - Sprint 9 (Radar Gun, GSR, Breathalyzer, Vehicle Search) Complete*
*Developer: Salah Eddine Boussettah*
