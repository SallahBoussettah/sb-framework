# sb_gym

Gym and Fitness System - Skill progression for strength, stamina, and lung capacity with equipment workouts, free exercises, and passive gains.

## Features

- Three trainable skills: Strength, Stamina, Lung Capacity
- Skills sync to GTA native stats (MP0_STRENGTH, MP0_STAMINA, MP0_LUNG_CAPACITY) affecting gameplay
- **Equipment Workouts** - sb_target interaction on gym props (bench press, pull-up bars, etc.)
- **Free Exercises** - Push-ups, sit-ups, yoga available anywhere via keybind (default: J)
- **Passive Gains** - Automatic skill increases from running, swimming, and melee combat
- **Protein Buff** - Consumable item that gives 2x XP for 5 minutes
- Skills panel UI (default: K) showing current skill levels
- Exercise selection NUI menu
- Cooldown system to prevent spam
- Skill values persist in player metadata
- Map blips for gym locations

## Dependencies

- sb_core
- sb_target
- sb_progressbar
- sb_notify
- sb_inventory (for protein shake item)

## Installation

1. Place `sb_gym` in your resources folder.
2. Add `ensure sb_gym` to your server.cfg (after all dependencies).
3. Register the `protein_shake` item in your sb_inventory item definitions.
4. The script uses GTA V vanilla gym props (prop_muscle_bench_01 through 06). These exist at Muscle Sands Beach by default.

## MLO Requirements

None by default. The default gym location is Muscle Sands Beach, which is a vanilla GTA V outdoor gym with existing props. If you want additional gym locations with indoor equipment, you will need gym MLOs and should add their coordinates to `Config.GymLocations`.

## Configuration

All configuration is in `config.lua`:

- `Config.DefaultSkills` - Starting skill values for new characters
- `Config.MaxSkillLevel` / `Config.MinSkillLevel` - Skill value bounds (0-100)
- `Config.GymLocations` - Gym blip locations
- `Config.Equipment` - Prop model to workout mapping (label, skill, gain, duration, animation)
- `Config.FreeExercises` - Exercises available anywhere (push-ups, sit-ups, yoga)
- `Config.PassiveGains` - Passive skill gains from running, swimming, melee (amount and interval)
- `Config.ProteinItem` - Item name for protein buff
- `Config.ProteinBuffDuration` - Buff duration in ms (default: 5 minutes)
- `Config.ProteinBuffMultiplier` - XP multiplier during buff (default: 2x)
- `Config.WorkoutCooldown` - Cooldown between workouts in ms
- `Config.ExerciseKey` / `Config.SkillsKey` - Keybinds for free exercise menu and skills panel

## Exports

**Client:**

- `exports['sb_gym']:GetSkill(skillName)` - Get a skill value (strength, stamina, lung)
- `exports['sb_gym']:GetAllSkills()` - Get all skill values as a table
- `exports['sb_gym']:SyncAllStats()` - Force sync all skills to GTA native stats
- `exports['sb_gym']:HasProteinBuff()` - Check if protein buff is active
- `exports['sb_gym']:IsExercising()` - Check if player is currently exercising
- `exports['sb_gym']:StartEquipmentWorkout(entity, model)` - Start a workout on equipment
- `exports['sb_gym']:StartFreeExercise(exerciseId)` - Start a free exercise

**Server:**

- `exports['sb_gym']:GetPlayerSkill(source, skillName)` - Get a player's skill value
- `exports['sb_gym']:GetPlayerSkills(source)` - Get all skill values for a player
- `exports['sb_gym']:SetPlayerSkill(source, skillName, value)` - Set a player's skill value
- `exports['sb_gym']:HasProteinBuff(source)` - Check if a player has the protein buff
