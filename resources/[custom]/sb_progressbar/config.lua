Config = {}

-- Default disable controls while progress bar is active
Config.DisableMovement = true       -- Disable walking/running
Config.DisableCarMovement = true    -- Disable vehicle input
Config.DisableCombat = true         -- Disable weapon/attack

-- Cancel conditions
Config.CancelOnDeath = true         -- Cancel if player dies
Config.CancelOnRagdoll = true       -- Cancel if player ragdolls

-- Controls to disable (GTA control IDs)
Config.DisableMovementControls = {
    21,  -- Sprint
    24,  -- Attack
    25,  -- Aim
    30,  -- Move LR
    31,  -- Move UD
    36,  -- Stealth
    44,  -- Cover
    47,  -- Weapon
    264, -- Melee
    257, -- Attack 2
    140, -- Melee alt
    141, -- Melee alt 2
    142, -- Melee alt 3
    143, -- Melee alt 4
}

Config.DisableCarControls = {
    63,  -- Veh Move LR
    64,  -- Veh Move UD
    71,  -- Veh Accelerate
    72,  -- Veh Brake
    75,  -- Veh Exit
}

Config.DisableCombatControls = {
    24,  -- Attack
    25,  -- Aim
    47,  -- Weapon
    58,  -- Weapon select
    257, -- Attack 2
    263, -- Melee
}
