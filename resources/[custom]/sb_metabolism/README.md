# sb_metabolism

Metabolism System - Hunger, thirst, and stress mechanics with configurable decay, damage, and relief.

## Features

- **Hunger and Thirst** decay over time at configurable rates
- Damage ticks when hunger or thirst drops below a threshold
- Screen effects when values are critically low
- Food and drink items restore hunger/thirst (configurable per item)
- Supports Burger Shot items (bs_fries, bs_burger, bs_cola, bs_meal)
- **Stress System** with multiple triggers:
  - Shooting, getting shot, speeding (>120 km/h), police chase, low health, critical needs, falling
- Stress effects: camera shake (intensity scales with stress level), increased stamina drain
- Stress decays naturally over time with a cooldown after the last stress event
- Stress relief items (joint, cigarette, whiskey)
- Metadata-based: hunger, thirst, and stress stored in player metadata via sb_core
- Integrates with sb_hud for display (HUD reads PlayerData.metadata)

## Dependencies

- sb_core
- sb_inventory (listens to item usage events)

## Installation

1. Place `sb_metabolism` in your resources folder.
2. Add `ensure sb_metabolism` to your server.cfg (after sb_core and sb_inventory).
3. Register food, drink, and stress relief items in your sb_inventory item definitions. The item names must match those in `Config.FoodItems`, `Config.DrinkItems`, and `Config.StressReliefItems`.

## MLO Requirements

None.

## Configuration

All configuration is in `config.lua`:

- `Config.DecayInterval` - How often hunger/thirst decays (ms)
- `Config.HungerDecay` / `Config.ThirstDecay` - Amount lost per interval
- `Config.DamageThreshold` - Value below which damage ticks start
- `Config.DamageAmount` / `Config.DamageInterval` - HP lost and tick interval when starving/dehydrated
- `Config.ScreenEffectThreshold` - Value below which screen effects appear
- `Config.FoodItems` - Table of item names to hunger restore values
- `Config.DrinkItems` - Table of item names to thirst restore values
- `Config.StressGain` - Stress amounts per trigger type
- `Config.StressCheckIntervals` - Check intervals per trigger type (ms)
- `Config.StressEffectThreshold` / `Config.StressHighThreshold` - Stress levels for effects
- `Config.StressShakeIntensity` / `Config.StressShakeHighIntensity` - Camera shake strength
- `Config.StressStaminaMultiplier` - Stamina drain multiplier when stressed
- `Config.StressDecayRate` / `Config.StressDecayInterval` / `Config.StressDecayCooldown` - Stress natural decay settings
- `Config.StressReliefItems` - Table of item names to stress reduction values

## Exports

**Client:**

- `exports['sb_metabolism']:GetStressStaminaMultiplier()` - Returns the stamina drain multiplier based on stress (1.0 when not stressed, configurable when stressed)
- `exports['sb_metabolism']:GetStress()` - Returns the current stress value
