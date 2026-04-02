# sb_drugs — Full Testing Checklist

Complete step-by-step guide to test every feature of the drug system from scratch.

---

## Pre-Flight

- [X] Run `sql/sb_drugs.sql` on your MySQL database (adds 42 items + progression table)
- [X] Verify `server.cfg` has `ensure bob74_ipl` (line ~54) and `ensure sb_drugs` (line ~181)
- [X] Restart the server
- [X] Check server console for:
  - `[sb_drugs] Drug system initialized`
  - `[sb_drugs] Consumable items registered`
- [X] No errors in console on startup

---

## 1. Shop NPCs (verify all 5 spawn + sell correctly)

### 1A. Flower Shop — Tools & Ingredients
**Coords:** `307.8704, -1286.4707, 30.5306` (Downtown LS, near Pillbox)

- [X] NPC visible (gardener model)
- [X] Blip on map
- [X] ALT → "Browse Flower Shop" opens NUI
- [X] Buy 1x Scissors ($80)
- [X] Buy 1x Trowel ($60)
- [X] Buy 1x Hammer ($100)
- [X] Buy 5x Baking Soda ($25 each)
- [X] Buy 1x Glue ($40)
- [X] Verify cash deducted correctly
- [X] Verify items appear in inventory
- [X] Close shop with ESC or X button

### 1B. Weed Dealer — Access Card & Packaging
**Coords:** `-1301.9567, -775.5922, 19.4695` (West LS) *(coords fixed)*

- [X] NPC visible (dealer model)
- [X] Blip on map
- [X] ALT → "Browse Weed Dealer" opens NUI
- [X] Buy 1x Weed Access Card ($5,000)
- [X] Buy 20x Empty Bag ($50 each)
- [X] Buy 10x Rolling Papers ($20 each)
- [X] Buy 10x Blunt Wrap ($40 each)
- [X] Verify all items in inventory

### 1C. Pharmacist — Chemicals
**Coords:** `75.76, -1622.35, 30.9` (South LS) *(Z fixed)*

- [X] NPC visible (doctor model)
- [X] Blip on map
- [X] ALT → "Browse Pharmacist" opens NUI
- [X] Buy 5x Empty Acid Can ($350 each)
- [X] Buy 10x Ammonia ($200 each)
- [X] Buy 5x Syringe ($100 each)
- [X] Buy 1x Pipe ($75)

### 1D. Comic Shop — Figures
**Coords:** `-143.4897, 229.5289, 94.9352` (Vinewood Hills) *(coords fixed)*

- [X] NPC visible
- [X] Blip on map
- [X] ALT → "Browse Comic Shop" opens NUI
- [X] Buy 5x Action Figure Empty ($150 each)

### 1E. Medicament Dealer — Pills
**Coords:** `819.5451, -2348.8757, 30.3346` (Port of LS) *(coords fixed)*

- [X] NPC visible (dealer model)
- [X] Blip on map
- [X] ALT → "Browse Medicament Dealer" opens NUI
- [X] Buy 2x LSD Tab ($300 each)
- [X] Buy 2x Ecstasy Pill ($250 each)
- [X] Buy 2x Xanax Pill ($200 each)

### Shop Anti-Exploit Tests
- [X] Try buying with no money — should fail with "Not enough money"
- [X] Try spamming checkout — button disables during purchase
- [X] Verify cash deducted from cash first, then bank

---

## 2. Weed Production Chain (3 steps)

### Enter Weed Farm
**Surface entrance:** `2855.56, 4447.03, 48.88` (Grapeseed farm area)
**Underground teleport:** `1066.12, -3183.43, -40.16`

- [X] Blip on map at surface entrance (not underground)
- [X] ALT → "Enter Weed Farm" at surface entrance
- [X] Without access card → "You need an access card for this lab"
- [X] With access card → screen fades, teleports underground
- [X] Interior is loaded (plants visible, furniture present)
- [X] ALT → "Leave Weed Farm" at exit point inside lab → teleports back to surface

### 2A. Pick Weed Buds
**Station:** `1048.0, -3196.0, -38.2` (plant growing area, 5m zone) *(coords fixed from DRC)*

- [X] ALT → "Pick Weed Buds" appears
- [X] Requires Scissors in inventory (not consumed after use)
- [X] Progress bar shows (5 seconds) *(fixed: Show→Start, then fixed callback-based pattern)*
- [X] Animation plays (gardener plant)
- [X] Receive 1x `weed_bud`
- [X] Repeat 15 times → should have 15x `weed_bud`
- [X] 5-second cooldown between actions works

### 2B. Clean Weed Buds
**Station:** `1038.67, -3205.93, -38.3` (trimming table) *(coords fixed from DRC)*

- [X] ALT → "Clean Weed" appears
- [X] Requires 3x `weed_bud`
- [X] Progress bar shows (8 seconds)
- [X] Consumes 3x `weed_bud`, gives 1x `weed_clean`
- [X] Repeat 5 times → should have 5x `weed_clean`

### 2C. Package Weed
**Station:** `1036.35, -3203.13, -38.24` (packaging table) *(coords fixed from DRC)*

- [X] ALT → "Package Weed" appears
- [X] Requires 5x `weed_clean` + 1x `empty_bag`
- [X] Progress bar shows (6 seconds)
- [X] Consumes both inputs, gives 1x `weed_bag`
- [X] **Goal: Produce 20x `weed_bag` for Gerald trade**

### Weed Chain Summary
To make 20 weed bags you need:
- 300x picks (300 buds → 100 clean → 20 bags)
- 20x empty_bag
- Scissors (not consumed)

**Admin shortcut for testing:** `/givecard [id] weed` then give yourself items directly.

---

## 3. Cocaine Access Card Trade

### Visit Gerald
**Coords:** `-59.65, -1530.34, 34.24` (South LS)

- [X] NPC visible (Gerald model)
- [X] Blip on map
- [X] ALT → "Trade 20x Weed Bags for Cocaine Access Card"
- [X] With < 20 weed_bag → should fail with error message
- [X] With 20x weed_bag → removes bags, gives `access_card_coke`
- [X] Try trading again → "You already have this access card"

---

## 4. Cocaine Production Chain (5 steps)

### 4A. Pick Coca Leaves (outdoor field)
**Field:** `2416.58, 4994.11, 46.23` (Grapeseed area)

- [X] Blip on map for "Coca Field"
- [X] ALT in field radius → "Pick Coca Leaves"
- [X] Requires Trowel (not consumed)
- [X] Progress bar (5s), gives 1x `coca_leaf`
- [X] 15% police alert chance — watch for sb_alerts
- [X] Repeat 10+ times

### Enter Cocaine Lab
**Surface entrance:** `1242.16, -3113.78, 6.01` (Elysian Island)

- [X] Blip on map at surface entrance
- [X] ALT → "Enter Cocaine Lockup" → fade + teleport underground
- [X] Requires `access_card_coke`
- [X] ALT → "Leave Cocaine Lockup" inside lab → teleports back

### 4B. Process Coca Leaves
**Station:** `1101.8, -3193.06, -38.98` *(coords fixed from DRC)*

- [X] ALT → "Process Leaves"
- [X] Requires 2x `coca_leaf`
- [X] Progress bar (10s), gives 1x `coca_paste`

### 4C. Extract Cocaine
**Station:** `1093.04, -3196.36, -39.15` *(coords fixed from DRC)*

- [X] ALT → "Extract Cocaine"
- [X] Requires 1x `coca_paste`
- [X] Progress bar (8s), gives 3x `coca_raw`

### 4D. Purify Cocaine
**Station:** `1095.39, -3196.3, -39.15` *(coords fixed from DRC)*

- [X] ALT → "Purify Cocaine"
- [X] Requires 2x `coca_raw`
- [X] Progress bar (10s), gives 1x `coca_pure`

### 4E. Package Figure
**Station:** `1100.43, -3199.39, -39.26` *(coords fixed from DRC)*

- [X] ALT → "Package Figures"
- [X] Requires 5x `coca_pure` + 1x `empty_figure`
- [X] Progress bar (8s), gives 1x `cocaine_figure`
- [X] **Goal: Produce 5x `cocaine_figure` for Madrazo trade**

---

## 5. Meth Access Card Trade

### Visit Madrazo
**Coords:** `-1033.04, 685.97, 161.30` (Vinewood Hills mansion)

- [X] NPC visible
- [X] Blip on map
- [X] ALT → "Trade 5x Cocaine Figures for Meth Access Card"
- [X] With < 5 → fail
- [X] With 5x → removes figures, gives `access_card_meth`

---

## 6. Meth Production Chain (4 steps)

### 6A. Fill Acid Canister (outdoor)
**Chemical Source:** `2718.76, 1558.05, 21.4` (Grand Senora Desert) *(coords fixed from DRC)*

- [X] ALT → "Fill Acid Canister"
- [X] Requires 1x `meth_acid_empty`
- [X] Progress bar (5s), gives 1x `meth_acid`

### Enter Meth Lab
**Surface entrance:** `762.93, -1092.78, 22.58` (Mirror Park)

- [X] Blip on map at surface entrance
- [X] ALT → "Enter Meth Lab" → fade + teleport underground
- [X] Requires `access_card_meth`
- [X] ALT → "Leave Meth Lab" inside lab → teleports back

### 6B. Cook Meth (MINIGAME)
**Station:** `1005.76, -3200.91, -38.1` *(coords fixed from DRC)*

- [X] ALT → "Cook Meth"
- [X] Requires 1x `ammonia` + 1x `meth_acid`
- [X] **Timing minigame appears first** — must succeed
- [X] If minigame fails → "Failed! Try again." (items NOT consumed)
- [X] If minigame succeeds → progress bar (15s), gives 1x `meth_liquid`

### 6C. Crystallize
**Station:** `1007.84, -3201.51, -38.53` *(coords fixed from DRC)*

- [X] ALT → "Crystallize"
- [X] Requires 1x `meth_liquid`
- [X] Progress bar (20s), gives 1x `meth_crystal`

### 6D. Crush & Package
**Station:** `1016.47, -3194.15, -39.01` *(coords fixed from DRC)*

- [X] ALT → "Crush & Package"
- [X] Requires 1x `meth_crystal` + Hammer (not consumed)
- [X] Progress bar (8s), gives 2x `meth_bag`

---

## 7. Heroin Production (2 steps, outdoor)

### 7A. Pick Poppies
**Field:** `2220.0, 5577.0, 54.0` (North Grapeseed)

- [X] Blip on map
- [X] ALT → "Pick Poppies"
- [X] Requires Trowel (not consumed)
- [X] Progress bar (5s), gives 1x `poppy_flower`
- [X] Pick 3+

### 7B. Process Heroin
**Same field location**

- [X] ALT → "Process Heroin"
- [X] Requires 3x `poppy_flower` + 1x `ammonia` + 1x `empty_bag`
- [X] Progress bar (15s), gives 1x `heroin_dose`

---

## 8. Crack Production (1 step, at any field)

- [X] Go to any field zone (e.g. poppy field `2220.0, 5577.0, 54.0`)
- [X] ALT → "Cook Crack"
- [X] Requires 2x `coca_pure` + 1x `baking_soda`
- [X] Progress bar (30s), gives 2x `crack_rock`

---

## 9. Simple Pickups (no tools needed)

### Mushrooms
**Field:** `-1039.0, 4919.0, 209.0` (Mt. Chiliad forest)

- [X] Blip on map
- [ ] ALT → "Pick Mushrooms" *(fixed: zone height 3→15 for hilly terrain, walk around the blip area and press ALT)*
- [ ] No inputs required
- [ ] Progress bar (5s), gives 1x `mushroom_dried`

### Peyote
**Field:** `2570.0, 3880.0, 39.0` (Sandy Shores desert)

- [X] Blip on map
- [ ] ALT → "Pick Peyote" *(fixed: zone height 3→15, walk around the blip area and press ALT)*
- [ ] No inputs required
- [ ] Progress bar (5s), gives 1x `peyote_dried`

---

## 10. Anywhere Crafts (use items from inventory)

### Roll Joint
- [X] Have `weed_clean` + `rolling_papers` in inventory
- [X] Use Rolling Papers from inventory *(fixed: now uses DoProcessStep directly, should show progress bar + craft)*
- [X] Progress bar (4s), gives 1x `weed_joint`
- [X] `weed_clean` and `rolling_papers` consumed

### Roll Blunt
- [X] Have `weed_clean` + `blunt_wrap` in inventory
- [X] Use Blunt Wrap from inventory *(fixed: same fix as rolling papers)*
- [X] Progress bar (4s), gives 1x `weed_blunt`

### Fill Heroin Syringe
- [X] Use `syringe` from inventory while having `heroin_dose` *(fixed: syringe is now a useable item)*
- [X] Requires 1x `heroin_dose` + 1x `syringe`
- [X] Gives 1x `heroin_syringe`

### Fill Meth Syringe
- [X] Use `syringe` from inventory while having `meth_bag` *(syringe picks heroin first, then meth)*
- [X] Requires 1x `meth_bag` + 1x `syringe`
- [X] Gives 1x `meth_syringe`

### Prepare Cocaine Line
- [X] Use `coca_pure` from inventory *(fixed: coca_pure is now a useable item)*
- [X] Requires 1x `coca_pure`
- [X] Gives 2x `cocaine_line`

---

## 11. Drug Consumption Effects (use from inventory)

### Weed Joint
- [X] Use `weed_joint` from inventory
- [X] Item consumed (removed from inventory)
- [X] Smoking animation plays (~5s) *(fixed: anim now 5s instead of 3s, prop attaches BEFORE anim so joint is visible during smoking)*
- [X] Joint prop attached to hand
- [X] Screen effect: CamPushInMichael (blurry/wobbly)
- [X] Movement: slightly drunk walk
- [X] Speed: normal (1.0x)
- [X] Duration: 30 seconds, then auto-clears
- [X] Notification: "Used: Weed Joint" then "Drug effect wore off"

### Weed Blunt
- [X] Use `weed_blunt` — same as joint but 40s duration

### Meth Bag (smoked)
- [X] Use `meth_bag` from inventory
- [X] Screen: DrugsMichaelAliensFightIn (alien visuals)
- [X] Speed: 1.6x (noticeably faster sprinting)
- [X] Duration: 45s
- [X] Health +30, Armor +50

### Cocaine Line
- [X] Use `cocaine_line`
- [X] Screen: BeastLaunch
- [X] Speed: 1.15x *(fixed: reduced from 1.3 to 1.15)*
- [X] Duration: 40s

### Heroin Syringe
- [X] Use `heroin_syringe`
- [X] Syringe prop on hand *(fixed: prop now removed after injection anim, not stuck for whole duration)*
- [X] Screen: DeathFailOut (dark/fading)
- [X] Movement: very drunk
- [X] Speed: 0.8x (slower)
- [X] Duration: 60s *(fixed: changed from 35s to 60s)*

### Meth Syringe
- [X] Use `meth_syringe`
- [X] Syringe prop *(fixed: prop removed after injection anim)*
- [X] Screen: alien visuals
- [X] Speed: 1.6x
- [X] Duration: 45s

### Crack Rock
- [X] Use `crack_rock`
- [X] Screen: alien visuals
- [X] Movement: alien walk
- [X] Speed: 1.4x
- [X] Duration: 30s

### LSD Tab
- [X] Use `lsd_tab`
- [X] Screen: DMT_flight (psychedelic)
- [X] Speed: normal
- [X] Duration: 60s (longest)

### Ecstasy Pill
- [X] Use `ecstasy_pill`
- [X] Screen: alien visuals
- [X] Speed: 1.2x
- [X] Duration: 45s
*(fixed: race condition crash on effects.lua:182 — now uses local capture of activeEffect before accessing .endTime)*

### Xanax Pill
- [X] Use `xanax_pill`
- [X] Screen: DeathFailMichaelIn
- [X] Movement: moderate drunk
- [X] Speed: 0.9x
- [X] Duration: 40s

### Mushroom
- [X] Use `mushroom_dried`
- [X] Screen: DMT_flight
- [X] Movement: moderate drunk
- [X] Duration: 50s

### Peyote
- [X] Use `peyote_dried`
- [X] Screen: DMT_flight
- [X] Duration: 45s

### Effect Edge Cases
- [X] Use same drug while already active → "Already under this effect" *(fixed: server now tracks active effects, blocks RemoveItem if same drug is active)*
- [X] Use different drug while active → previous effect clears, new one starts
- [X] Die while effect active → effect clears immediately
- [X] Effect auto-clears after duration → notification shown

---

## 12. NPC Selling (phone booths)

### Easy Test Locations
- `130.2, -1274.99, 28.24` (Strawberry)
- `-3.72, -1086.34, 25.67` (near Pillbox)
- `45.53, -1011.18, 28.52` (Legion Square)
- `-17.60, -1037.06, 27.90` (Downtown)

### Sell Flow
- [X] Have sellable drugs in inventory (weed_bag, meth_bag, cocaine_figure, heroin_dose, or crack_rock)
- [X] Find a phone booth → ALT → "Call Buyer"
- [X] Notification: "Buyer is on the way..."
- [X] Buyer NPC spawns and walks toward you (max 45s) -- FIXED: NPC now spawns ~30m from player (was spawning at fixed SellLocation coords, often far away). Retasks every 8s to follow player movement.
- [X] Offer notification shows: "[Y] Accept $X for Yx item | [N] Decline | [G] Negotiate"

### Accept (Y key)
- [X] Press Y → items removed, cash received
- [X] Notification: "Sold Xx for $Y"
- [X] Buyer walks away and eventually despawns

### Decline (N key)
- [X] Press N → "Deal declined"
- [X] Buyer walks away, no items/money exchanged

### Negotiate (G key)
- [X] Press G → 30% chance better price (20-50% increase)
- [X] If success → new offer shown, can accept/decline again
- [X] If fail → buyer may walk away (30% chance)

### Sell Edge Cases
- [X] Try selling with no drugs → "You have nothing to sell"
- [X] Try selling again immediately → "Wait Xs before selling again" (120s cooldown)
- [X] 10% chance buyer attacks (pulls weapon) — test by selling multiple times
- [X] Police alert fires (check sb_alerts) — 20% normal, 100% on 3+ items
- [X] Timeout: if you don't press Y/N/G within 15s → "Buyer got impatient and left"

### Price Ranges (verify cash received is within range)
| Drug | Min | Max |
|------|-----|-----|
| weed_bag | $200 | $400 |
| meth_bag | $500 | $1,000 |
| cocaine_figure | $800 | $1,500 |
| heroin_dose | $400 | $800 |
| crack_rock | $300 | $600 |

---

## 13. Anti-Exploit Tests

- [ ] Spam-click a production station → "Already processing something"
- [ ] Try production without required tool → "Missing required tool"
- [ ] Try production without enough materials → "Missing required materials"
- [ ] Remove items from inventory during progress bar → "Materials were removed during processing"
- [ ] Try accessing lab without access card → "You need an access card for this lab"
- [ ] 5-second cooldown between production actions works
- [ ] 120-second cooldown between sells works

---

## 14. Police Integration

- [ ] Field harvesting triggers police alert (30% chance) — try ~10 picks
- [ ] Lab processing triggers alert (10% chance)
- [ ] Selling triggers alert (20% chance, 100% on 3+ items)
- [ ] Alerts appear in sb_alerts for police job
- [ ] Alert shows "Drug Activity" or "Drug Sale" with correct coords

---

## 15. Admin Commands

### /drugstats [serverid]
- [ ] Shows access card status for target player
- [ ] Non-admin → command does nothing
- [ ] Admin → shows "Weed=YES/NO Coke=YES/NO Meth=YES/NO"

### /givecard [serverid] [weed/coke/meth]
- [ ] Gives access card to target player
- [ ] Target receives notification
- [ ] Invalid type → error message

### /drugcooldown [serverid]
- [ ] Clears all production + sell cooldowns for target
- [ ] Player can immediately produce/sell again

---

## 16. Cleanup & Edge Cases

- [ ] `/stop sb_drugs` → all NPCs and blips removed, NUI closed
- [ ] `/ensure sb_drugs` → everything respawns correctly
- [ ] Player disconnect during production → lock cleared (no stuck state)
- [ ] Player disconnect during sell → cooldown cleared
- [ ] Player death during drug effect → effect clears immediately
- [ ] Player death during production → progress bar cancels

---

## Quick Admin Test Path

If you want to skip the grind and test everything fast:

```
/givecard [id] weed
/givecard [id] coke
/givecard [id] meth
```

Then give yourself items directly via your admin/inventory tools to skip the shop buying and production grind. Focus testing on:
1. Each shop NUI opens/closes correctly
2. Each lab station triggers correctly
3. All 12 drug effects work
4. Selling flow at phone booths works
5. Police alerts fire

---

## Expected Item Counts (Full Chain Test)

If you run the complete chain from scratch buying to finished product:

| Purchase | Cost |
|----------|------|
| Weed card | $5,000 |
| 20x Empty Bag | $1,000 |
| Scissors | $80 |
| Trowel | $60 |
| Hammer | $100 |
| 5x Empty Acid Can | $1,750 |
| 10x Ammonia | $2,000 |
| 5x Syringe | $500 |
| 5x Empty Figure | $750 |
| 5x Baking Soda | $125 |
| Pills (2 each) | $1,500 |
| Rolling Papers + Wraps | $600 |
| **Total startup cost** | **~$13,465** |

| Sale (per unit) | Revenue |
|-----------------|---------|
| weed_bag | $200-400 |
| meth_bag | $500-1,000 |
| cocaine_figure | $800-1,500 |
| heroin_dose | $400-800 |
| crack_rock | $300-600 |
