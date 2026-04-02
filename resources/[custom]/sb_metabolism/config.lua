--[[
    Everyday Chaos RP - Metabolism Configuration
    Author: Salah Eddine Boussettah
]]

Config = {}

-- ========================================================================
-- DECAY SETTINGS
-- ========================================================================
Config.DecayInterval = 60000         -- How often to decay (ms) - every 60 seconds
Config.HungerDecay = 0.8             -- Hunger lost per interval
Config.ThirstDecay = 1.0             -- Thirst lost per interval (thirst decays faster)

-- ========================================================================
-- DAMAGE SETTINGS
-- ========================================================================
Config.DamageThreshold = 10          -- Below this value, start taking damage
Config.DamageAmount = 1              -- HP lost per damage tick
Config.DamageInterval = 10000        -- Damage tick interval (ms) when starving/dehydrated

-- ========================================================================
-- EFFECTS
-- ========================================================================
Config.ScreenEffectThreshold = 20    -- Below this, show screen effects
Config.ScreenEffect = 'DrugsMichaelAliensFightIn'  -- Screen effect name

-- ========================================================================
-- FOOD RESTORE VALUES (hunger restored per use)
-- ========================================================================
Config.FoodItems = {
    ['apple']       = 15,
    ['banana']      = 15,
    ['burger']      = 40,
    ['bread']       = 20,
    ['bacon']       = 30,
    ['chips']       = 15,
    ['cookie']      = 10,
    ['croissant']   = 20,
    ['donut']       = 15,
    ['hotdog']      = 35,
    ['pizza']       = 45,
    ['fries']       = 20,
    ['muffin']      = 15,
    ['bagel']       = 20,
    ['brownie']     = 10,
    -- Burger Shot
    ['bs_fries']    = 25,
    ['bs_burger']   = 45,
    ['bs_meal']     = 70,
}

-- ========================================================================
-- DRINK RESTORE VALUES (thirst restored per use)
-- ========================================================================
Config.DrinkItems = {
    ['water_bottle'] = 35,
    ['cola']         = 25,
    ['coffee']       = 20,
    ['juice']        = 30,
    ['beer']         = 15,
    ['milk']         = 30,
    ['sprite']       = 25,
    ['redbull']      = 20,
    ['pepsi']        = 25,
    ['monster']      = 20,
    -- Burger Shot
    ['bs_cola']      = 30,
    ['bs_meal']      = 25,
}

-- ========================================================================
-- STRESS SYSTEM
-- ========================================================================
Config.StressDecayRate = 1.0           -- Stress reduced per decay tick
Config.StressDecayInterval = 10000     -- Decay tick interval (ms)
Config.StressDecayCooldown = 30000     -- No decay until this long after last gain (ms)
Config.StressMax = 100
Config.StressMin = 0

-- Stress gain per trigger
Config.StressGain = {
    shooting    = 3,    -- Per shot fired
    gettingShot = 5,    -- Per hit taken
    speeding    = 0.5,  -- Per tick when >120 km/h
    policeChase = 2,    -- Per tick when wanted
    lowHealth   = 1,    -- Per tick when health <25%
    criticalNeeds = 0.5,-- Per tick when hunger/thirst <10%
    falling     = 4,    -- Per fall with damage
}

-- Check intervals for stress triggers (ms)
Config.StressCheckIntervals = {
    shooting    = 200,
    gettingShot = 500,
    speeding    = 10000,
    policeChase = 10000,
    lowHealth   = 10000,
    criticalNeeds = 10000,
    falling     = 500,
}

-- Stress effects
Config.StressEffectThreshold = 50      -- Above this, effects start
Config.StressHighThreshold = 80        -- Above this, effects intensify
Config.StressShakeIntensity = 0.02     -- Camera shake amplitude
Config.StressShakeHighIntensity = 0.04 -- Camera shake at high stress
Config.StressStaminaMultiplier = 1.5   -- Stamina drains faster when stressed

-- Stress relief items (item name = amount reduced)
Config.StressReliefItems = {
    ['joint']     = 25,
    ['cigarette'] = 10,
    ['whiskey']   = 15,
}
