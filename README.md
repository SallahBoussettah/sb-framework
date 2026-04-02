# SB Framework - Custom FiveM Roleplay Server

**A complete FiveM RP server built from scratch by Salah Eddine Boussettah**

SB Framework is a fully custom FiveM roleplay server framework with 42 hand-written scripts. It is not based on QBCore, ESX, or any other existing framework - every system was designed and built from the ground up. The UI across all scripts uses React with TypeScript, styled with Tailwind CSS and animated with Framer Motion.

---

## Scripts

| Script | Description | MLO Required |
|--------|-------------|--------------|
| sb_core | Core framework - shared API, player data, callbacks, events | No |
| sb_loadingscreen | Custom loading screen with server branding | No |
| sb_multicharacter | Character selection and creation system | No |
| sb_whitelist | Adaptive card whitelist system with password gate | No |
| sb_hud | Arc HUD - health, armor, hunger, thirst, money, vehicle dashboard | No |
| sb_notify | Modern toast notification system | No |
| sb_chat | Custom chat system with commands and proximity | No |
| sb_target | Third-eye targeting system | No |
| sb_progressbar | Shared progress bar utility | No |
| sb_doorlock | Door lock system with job-based access control | No |
| sb_inventory | Drag-and-drop inventory with hotbar | No |
| sb_metabolism | Hunger and thirst decay with effects | No |
| sb_deaths | Death screen, respawn, emergency call system | Yes - Hospital MLO |
| sb_banking | Bank accounts, ATM, transactions | No |
| sb_shops | NPC stores - 24/7, food, drinks | No |
| sb_clothing | Clothing stores - Ponsonbys, Suburban, Binco | No |
| sb_id | Government ID card system - City Hall NPC, ID issuance | No |
| sb_dmv | DMV driving school - theory exam, practical test, license | Yes - DMV MLO |
| sb_weapons | Weapon equip/holster with magazine-based reload | No |
| sb_gym | Gym skills, equipment workouts, free exercises, passive gains | No |
| sb_admin | Developer admin utility menu (F5/F7) | No |
| sb_worldcontrol | RP world management - NPC vehicles, density, police control | No |
| sb_weather | Weather sync for all players | No |
| sb_pacificheist | Pacific Standard Bank heist | Yes - Pacific Bank MLO |
| sb_garage | Vehicle storage and retrieval | No |
| sb_vehicleshop | Vehicle dealership - buy/sell with license requirement | Yes - Car Dealer MLO |
| sb_fuel | Gas stations, fuel consumption, jerry cans, syphoning | No |
| sb_rental | Vehicle rental - bicycles, scooters, cars | No |
| sb_impound | Vehicle impound with disconnect persistence | No |
| sb_mechanic | Benny's elevator mechanic system (v1) | Yes - Benny's MLO |
| sb_mechanic_v2 | Realistic 32-component vehicle condition and damage system | Yes - Benny's/Evo Motors MLO |
| sb_minigame | Standalone minigame engine - timing bar, sequence, precision | No |
| sb_companies | Supply chain economy - companies, orders, delivery, mining | Yes - Mine Shafts MLO (for mining) |
| sb_mma | MMA arena betting with scheduled fights | Yes - Fight Club MLO |
| sb_alerts | Job-based dispatch alerts for police, EMS, mechanic | No |
| sb_burgershot | Burger Shot job - cooking, counter sales | Yes - Burger Shot MLO |
| sb_phone | Smartphone - calls, messages, contacts, bank, social, camera | No |
| sb_jobs | Job Center - public jobs with XP progression, boss-managed listings | No |
| sb_police | Police MDT, duty system, interactions, evidence | Yes - Police Station MLO |
| sb_drugs | Drug manufacturing, distribution, and consumption | No |
| sb_apartments | Shell-based apartment rental system with door locking | Yes - Shell MLOs + Apartment MLOs |
| sb_prison | Booking dashboard, sentencing, and jail system | Yes - Prison MLO |

---

## Tech Stack

- **Server/Client scripting:** Lua 5.4
- **UI framework:** React 18 with TypeScript
- **UI styling:** Tailwind CSS
- **UI state management:** Zustand
- **UI animations:** Framer Motion
- **Database:** MySQL via oxmysql
- **Voice:** pma-voice

---

## Installation

1. Clone or download this repository
2. Set up a MySQL database and import the SQL files from scripts that include them
3. Copy the `resources` folder into your FiveM server directory
4. Edit `resources/server.cfg`:
   - Set your `sv_licenseKey` (get one from [Cfx.re Keymaster](https://keymaster.fivem.net))
   - Set your `steam_webApiKey`
   - Update the `mysql_connection_string` with your database credentials
   - Update the `sb_phone_fivemanager_token` if using FiveManage for phone camera
   - Add your admin identifiers at the bottom
5. Install required dependencies in `[standalone]`:
   - [oxmysql](https://github.com/overextended/oxmysql)
   - [pma-voice](https://github.com/AvarianKnight/pma-voice)
   - screenshot-basic (included with FiveM artifacts)
   - bob74_ipl
6. Provide your own MLO resources for scripts that require them (see below)
7. Provide your own vehicle packs and clothing packs
8. Start the server via txAdmin or directly

---

## Excluded Assets

The following asset categories are **not included** in this release. You need to source and install your own:

- **Car packs** - Police vehicles, EMS vehicles, premium/civilian cars
- **Mappings/MLOs** - Interior map modifications (hospitals, police stations, etc.)
- **Shell packs** - Interior shells for the apartment system (K4MB1, Lynx, Envi, etc.)
- **Clothing packs** - Addon clothing resources

These are paid or third-party assets that cannot be redistributed.

---

## Scripts That Require MLOs

The following scripts depend on specific MLO types to function correctly. Without the corresponding MLO, the script may still load but the associated locations will not have proper interiors.

| Script | MLO Type Needed | Notes |
|--------|----------------|-------|
| sb_deaths | Hospital MLO | Pillbox Hill or similar hospital interior |
| sb_dmv | DMV MLO | Interior for theory/practical tests |
| sb_pacificheist | Bank MLO | Pacific Standard Bank extended interior |
| sb_vehicleshop | Car Dealer MLO | Premium Deluxe Motorsport or similar |
| sb_mechanic | Benny's MLO | Benny's Original Motorworks or similar |
| sb_mechanic_v2 | Mechanic Shop MLO | Benny's or Evo Motors interior |
| sb_companies | Mine Shafts MLO | Only needed for the mining job route |
| sb_mma | Fight Club MLO | Underground fight club interior |
| sb_burgershot | Burger Shot MLO | Burger Shot restaurant interior |
| sb_police | Police Station MLO | Mission Row PD or similar |
| sb_apartments | Shell MLOs + Apartment Building MLOs | Shell packs for interiors, building MLOs for lobbies |
| sb_prison | Prison MLO | Bolingbroke Penitentiary or similar |

The `server.cfg` includes commented-out `ensure` lines for all the MLO resources used in the original development environment. Uncomment and adjust them to match your own MLO resource names.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Author

**Salah Eddine Boussettah**

Built entirely from scratch - no QBCore, no ESX, no pre-made frameworks. Every script, every UI, every system designed and coded by hand.
