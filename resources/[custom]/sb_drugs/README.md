# sb_drugs

Drug manufacturing, distribution, and consumption system for FiveM.

## Features

- **Multi-drug production chains** - Weed (3 steps), Cocaine (5 steps), Meth (4 steps), Heroin (2 steps), Crack (1 step), plus simple pickups for Mushrooms and Peyote
- **Underground lab interiors** - Weed Farm, Cocaine Lockup, and Meth Lab using bob74_ipl MC Business interiors with access card gating
- **Field harvesting** - Outdoor coca, poppy, mushroom, peyote, and chemical source locations
- **Weed planting system** - 9 plantable zones inside the weed farm with growth stages (small, medium, grown)
- **NPC shop system** - 5 dealer NPCs selling tools, supplies, access cards, and pre-made consumables (LSD, Ecstasy, Xanax)
- **Access card progression** - Trade bulk product to NPCs (Gerald, Madrazo) to unlock higher-tier lab access cards
- **NPC street selling** - Use phone booths across the map to call buyers, negotiate prices, risk NPC attacks or police alerts
- **Drug consumption effects** - Screen effects, movement clipsets, speed modifiers, health/armor boosts, stress relief, prop attachments (joints, syringes, pipes)
- **Consumable crafting** - Roll joints/blunts, fill syringes (heroin/meth), prepare cocaine lines - all craftable anywhere
- **NUI shop interface** - HTML/CSS/JS shop UI for purchasing supplies
- **Police alert system** - Configurable chance of police alerts during harvesting, processing, and selling
- **Anti-exploit protection** - Server-side operation locks, cooldowns, distance checks, and database-backed progression tracking
- **Data-driven design** - All drugs, production chains, shops, and effects defined in a single config file

## Dependencies

- `sb_core` - Core framework
- `sb_inventory` - Inventory system
- `sb_target` - Interaction targeting
- `sb_notify` - Notification system
- `sb_progressbar` - Progress bar UI
- `sb_alerts` - Police alert dispatch
- `bob74_ipl` - MC Business interiors (weed farm, cocaine lockup, meth lab)
- `oxmysql` - Database (drug progression tracking)

## MLO / Mapping Requirements

- **bob74_ipl** (required) - Provides the underground MC Business interiors used as drug labs. The script automatically configures weed farm, cocaine lockup, and meth lab styles/upgrades/security via bob74_ipl exports on startup.

No additional MLOs are needed. Field locations use existing GTA V world positions.

## Installation

1. Ensure all dependencies are installed and running
2. Place `sb_drugs` in your resources folder
3. Add `ensure sb_drugs` to your server.cfg (after all dependencies)
4. The script auto-creates the `sb_drug_progression` database table on first start
5. Register all drug/tool items in your inventory system (see production chains and shop items in config)

## Configuration

All configuration is in `config.lua`:

- **General** - Debug mode, production cooldown (5s), sell cooldown (120s), police alert chances per action type
- **Plant growth** - Stage time (45s per stage, 90s total grow time)
- **Labs** - Interior IDs, surface entrance/exit coords, underground coords, required access cards, processing station positions
- **Weed groups** - 9 harvesting zones mapped to bob74_ipl plant entity sets with configurable yield
- **Fields** - 5 outdoor harvesting locations (coca, poppy, mushroom, peyote, acid) with radius and blip settings
- **Production chains** - 17 production steps, each with inputs, outputs, duration, animation, location binding, and alert chance
- **Shops** - 5 NPC dealers with position, model, blip, and item lists with prices
- **Trade NPCs** - 2 progression traders (Gerald: 20 weed bags for coke card, Madrazo: 5 cocaine figures for meth card)
- **Selling** - Money type, max sell amount, negotiate/fail/attack/alert chances, drug price ranges (min/max)
- **Phone booths** - 8 phone booth model hashes, 66 buyer spawn locations
- **Drug effects** - Per-drug screen effects, clipsets, speed multipliers, durations, stress relief, health/armor boosts, consumption animations and props

## Drug Production Overview

| Drug | Steps | Final Product |
|------|-------|---------------|
| Weed | Pick buds, Clean, Package | weed_bag |
| Cocaine | Pick coca, Process, Extract, Purify, Package into figure | cocaine_figure |
| Meth | Fill acid, Cook, Crystallize, Crush and package | meth_bag |
| Heroin | Pick poppies, Process | heroin_dose |
| Crack | Cook (requires purified cocaine + baking soda) | crack_rock |
| Mushrooms | Pick | mushroom_dried |
| Peyote | Pick | peyote_dried |

## Exports

This script does not expose any exports. It uses exports from its dependencies (sb_core, sb_inventory, sb_target, sb_notify, sb_progressbar, sb_alerts, bob74_ipl).
