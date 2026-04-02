Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================
Config.Debug = false                     -- Show debug markers on doors
Config.InteractKey = 38                 -- E key
Config.DefaultDistance = 2.5            -- Default interaction distance
Config.UseTarget = true                 -- Use sb_target (false = E key proximity)

-- ============================================================================
-- ADMIN SETTINGS
-- ============================================================================
Config.AdminAccess = true               -- Admins can bypass all doors
Config.AdminPermission = 'command.sb_admin'

-- ============================================================================
-- ANIMATIONS & SOUNDS
-- ============================================================================
Config.Animation = {
    dict = 'mp_common',
    anim = 'givetake1_a',
    duration = 800
}

Config.Sounds = {
    lock = { file = 'door-bolt-4.ogg', volume = 0.5 },
    unlock = { file = 'metallic-creak.ogg', volume = 0.5 }
}

-- ============================================================================
-- DOOR TYPES
-- ============================================================================
-- 'door'          = Single swing door
-- 'double'        = Double swing doors
-- 'sliding'       = Sliding door
-- 'garage'        = Garage/overhead door

-- ============================================================================
-- DOOR LIST
-- ============================================================================
Config.Doors = {

    -- ========================================================================
    -- PACIFIC STANDARD BANK - All doors locked by default
    -- ========================================================================

    -- Pacific Bank - Main Entrance (Street Level)
    {
        id = 'pacific_main_entrance',
        label = 'Pacific Standard - Main Entrance',
        model = 'hei_v_ilev_bk_gate_pris',          -- Prison-style gate
        coords = vector3(257.10, 220.30, 106.28),
        heading = 340.0,
        locked = true,
        distance = 2.5,
        doorType = 'door',
        authorizedJobs = { ['bank'] = 0 },          -- Bank employees only
        heistBypass = true,                         -- Can be bypassed by heist thermite
        pickable = false,                           -- Cannot be lockpicked
    },

    -- Pacific Bank - Second Gate
    {
        id = 'pacific_gate_2',
        label = 'Pacific Standard - Security Gate',
        model = 'hei_v_ilev_bk_gate2_pris',
        coords = vector3(262.35, 223.00, 107.05),
        heading = 250.0,
        locked = true,
        distance = 2.5,
        doorType = 'door',
        authorizedJobs = { ['bank'] = 0 },
        heistBypass = true,
        pickable = false,
    },

    -- Pacific Bank - Vault Gate 1
    {
        id = 'pacific_vault_gate_1',
        label = 'Pacific Standard - Vault Gate',
        model = 'hei_v_ilev_bk_safegate_pris',
        coords = vector3(252.72, 220.95, 101.68),
        heading = 160.0,
        locked = true,
        distance = 2.5,
        doorType = 'door',
        authorizedJobs = { ['bank'] = 2 },          -- Bank manager+ only
        heistBypass = true,
        pickable = false,
    },

    -- Pacific Bank - Vault Gate 2
    {
        id = 'pacific_vault_gate_2',
        label = 'Pacific Standard - Vault Gate',
        model = 'hei_v_ilev_bk_safegate_pris',
        coords = vector3(261.01, 215.01, 101.68),
        heading = 250.0,
        locked = true,
        distance = 2.5,
        doorType = 'door',
        authorizedJobs = { ['bank'] = 2 },          -- Bank manager+ only
        heistBypass = true,
        pickable = false,
    },

    -- Pacific Bank - Main Vault Door
    {
        id = 'pacific_main_vault',
        label = 'Pacific Standard - Main Vault',
        model = 'v_ilev_bk_vaultdoor',
        coords = vector3(253.92, 224.56, 101.88),
        heading = 160.0,
        locked = true,
        distance = 3.0,
        doorType = 'door',
        authorizedJobs = {},                        -- NO ONE can unlock normally
        heistBypass = true,                         -- Only heist can open
        pickable = false,
        special = 'vault',                          -- Special vault door handling
    },

    -- Pacific Bank - Extended Vault Door
    {
        id = 'pacific_extended_vault',
        label = 'Pacific Standard - Extended Vault',
        model = 'ch_prop_ch_vaultdoor01x',
        coords = vector3(256.518, 240.101, 101.701),
        heading = 160.0,
        locked = true,
        distance = 3.0,
        doorType = 'door',
        authorizedJobs = {},                        -- NO ONE can unlock normally
        heistBypass = true,                         -- Only heist can open
        pickable = false,
        special = 'vault',
    },

    -- Pacific Bank - Safe Door (Hexagonal/Diamond pattern)
    {
        id = 'pacific_safe_door',
        label = 'Pacific Standard - Safe Door',
        modelHash = 0x24ACA5B5,                     -- Direct hash from inspector
        coords = vector3(255.36, 229.38, 101.77),
        heading = 160.0,
        locked = true,
        distance = 3.0,
        doorType = 'door',
        authorizedJobs = {},                        -- NO ONE can unlock normally
        heistBypass = true,                         -- Opened by drilling/thermite
        pickable = false,
        special = 'vault',
    },

    -- Pacific Bank - Inner Vault Gate (Hackable)
    {
        id = 'pacific_inner_gate',
        label = 'Pacific Standard - Security Gate',
        modelHash = 0x213D9D3D,                     -- Direct hash from inspector
        coords = vector3(252.51, 236.04, 101.77),
        heading = 160.0,
        locked = true,
        distance = 2.5,
        doorType = 'door',
        authorizedJobs = {},                        -- NO ONE can unlock normally
        heistBypass = true,                         -- Opened by laptop hack
        pickable = false,
        special = 'vault',
    },

    -- ========================================================================
    -- MISSION ROW POLICE DEPARTMENT
    -- ========================================================================

    -- MRPD - Front Entrance
    {
        id = 'mrpd_front',
        label = 'MRPD - Front Entrance',
        model = 'v_ilev_ph_door01',
        coords = vector3(434.7, -982.0, 30.8),
        heading = 90.0,
        locked = false,
        distance = 2.5,
        doorType = 'double',
        doors = {
            { coords = vector3(434.7, -983.0, 30.8), heading = 90.1 },
            { coords = vector3(434.7, -980.7, 30.8), heading = 269.0 }
        },
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Back Door
    {
        id = 'mrpd_back',
        label = 'MRPD - Back Door',
        model = 'v_ilev_ph_door002',
        coords = vector3(469.4, -1014.4, 26.5),
        heading = 270.0,
        locked = true,
        distance = 2.5,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Armory
    {
        id = 'mrpd_armory',
        label = 'MRPD - Armory',
        model = 'v_ilev_ph_door01',
        coords = vector3(452.0, -982.7, 30.7),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 2 },        -- Sergeant+ only
        pickable = false,
    },

    -- ========================================================================
    -- PILLBOX HOSPITAL
    -- ========================================================================

    -- Pillbox - Main Entrance (Usually open)
    {
        id = 'pillbox_main',
        label = 'Pillbox Medical - Main Entrance',
        model = 'v_ilev_hos_door',
        coords = vector3(311.8, -592.5, 43.3),
        heading = 340.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,                       -- Public access
        pickable = false,
    },

    -- Pillbox - Staff Only
    {
        id = 'pillbox_staff',
        label = 'Pillbox Medical - Staff Only',
        model = 'v_ilev_hos_doorsr',
        coords = vector3(330.6, -586.0, 43.3),
        heading = 160.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['ambulance'] = 0, ['doctor'] = 0 },
        pickable = false,
    },

    -- ========================================================================
    -- 24/7 CONVENIENCE STORES (Locked at night / robbery)
    -- ========================================================================

    -- 24/7 Innocence Blvd
    {
        id = '247_innocence',
        label = '24/7 Store',
        model = 'v_ilev_gasdoor',
        coords = vector3(24.5, -1347.3, 29.5),
        textCoords = vector3(28.5, -1353.0, 29.5),  -- Target zone at the actual door (away from counter NPC)
        heading = 270.0,
        locked = false,
        distance = 2.0,
        doorType = 'door',
        allAuthorized = true,
        pickable = true,                            -- Can be lockpicked for robbery
        autoLock = 60000,                           -- Auto-lock after 1 minute
    },

    -- ========================================================================
    -- BENNY'S MOTORWORKS (patoche_bigbenny_original)
    -- ========================================================================

    -- Benny's - Outside Gate 1
    {
        id = 'bennys_outside_gate_1',
        label = "Benny's - Outside Gate",
        model = 'hei_prop_station_gate',
        coords = vector3(-243.9855, -1302.753, 30.30171),
        heading = 0.0,
        locked = false,
        distance = 3.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Outside Gate 2
    {
        id = 'bennys_outside_gate_2',
        label = "Benny's - Outside Gate",
        model = 'hei_prop_station_gate',
        coords = vector3(-143.9193, -1293.708, 30.09915),
        heading = 0.0,
        locked = false,
        distance = 3.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Big Red Door (Main Garage)
    {
        id = 'bennys_red_door_main',
        label = "Benny's - Main Garage Door",
        model = 'lr_prop_supermod_door_01',
        coords = vector3(-205.6828, -1310.683, 30.29572),
        heading = 0.0,
        locked = false,
        distance = 3.0,
        doorType = 'garage',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Big Red Door (Interior Garage)
    {
        id = 'bennys_red_door_interior',
        label = "Benny's - Interior Garage Door",
        model = 'patoche_garageint_door',
        coords = vector3(-214.3858, -1334.704, 31.35946),
        heading = 0.0,
        locked = false,
        distance = 3.0,
        doorType = 'garage',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Sliding Door
    {
        id = 'bennys_sliding',
        label = "Benny's - Sliding Door",
        model = 'v_ilev_bl_doorsl_r',
        coords = vector3(-205.2142, -1328.09, 29.84439),
        heading = 0.0,
        locked = false,
        distance = 1.2,
        doorType = 'sliding',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Green Door (Workshop)
    {
        id = 'bennys_green_door',
        label = "Benny's - Workshop Door",
        model = 'v_ilev_ct_door03',
        coords = vector3(-202.8542, -1330.36, 31.00205),
        heading = 0.0,
        locked = false,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Cloakroom Door
    {
        id = 'bennys_cloakroom',
        label = "Benny's - Cloakroom",
        model = 'v_ilev_ct_door03',
        coords = vector3(-203.6549, -1331.643, 23.20492),
        heading = 0.0,
        locked = false,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Boss Room Door
    {
        id = 'bennys_bossroom',
        label = "Benny's - Boss Room",
        model = 'v_ilev_ph_gendoor002',
        coords = vector3(-202.8535, -1335.839, 34.9894),
        heading = 0.0,
        locked = false,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Billing Room Door
    {
        id = 'bennys_billing',
        label = "Benny's - Billing Room",
        model = 'v_ilev_roc_door3',
        coords = vector3(-206.2629, -1342.296, 35.05238),
        heading = 0.0,
        locked = false,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- Benny's - Billing to Boss Room Door
    {
        id = 'bennys_billing_boss',
        label = "Benny's - Billing Corridor",
        model = 'v_ilev_ph_gendoor002',
        coords = vector3(-203.8305, -1337.708, 35.05075),
        heading = 0.0,
        locked = false,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['bn-mechanic'] = 0 },
        pickable = false,
    },

    -- ========================================================================
    -- BURGER SHOT (burgershot_mlo)
    -- ========================================================================

    -- Burger Shot - Front Entrance Left
    {
        id = 'bs_front_left',
        label = 'Burger Shot - Front Entrance',
        modelHash = 0xCFE9EFF9,
        coords = vector3(-1184.15, -884.34, 13.64),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Burger Shot - Front Entrance Right
    {
        id = 'bs_front_right',
        label = 'Burger Shot - Front Entrance',
        modelHash = 0x17087E25,
        coords = vector3(-1183.81, -884.85, 13.80),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Burger Shot - Kitchen Door Right (Staff Only)
    {
        id = 'bs_kitchen_right',
        label = 'Burger Shot - Kitchen',
        modelHash = 0x7610DF98,
        coords = vector3(-1203.53, -897.32, 13.95),
        heading = 0.0,
        locked = true,
        distance = 1.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 0 },
        pickable = false,
    },

    -- Burger Shot - Kitchen Door Left (Staff Only)
    {
        id = 'bs_kitchen_left',
        label = 'Burger Shot - Kitchen',
        modelHash = 0x7610DF98,
        coords = vector3(-1202.85, -896.86, 13.98),
        heading = 0.0,
        locked = true,
        distance = 1.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 0 },
        pickable = false,
    },

    -- Burger Shot - Cold Room (Staff Only)
    {
        id = 'bs_coldroom',
        label = 'Burger Shot - Cold Room',
        modelHash = 0x57323B8A,
        coords = vector3(-1194.06, -899.85, 14.07),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 0 },
        pickable = false,
    },

    -- Burger Shot - Back Room Door (Staff Only)
    {
        id = 'bs_backroom',
        label = 'Burger Shot - Back Room',
        modelHash = 0x57323B8A,
        coords = vector3(-1194.17, -901.61, 14.07),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 0 },
        pickable = false,
    },

    -- Burger Shot - Staff Door
    {
        id = 'bs_staff',
        label = 'Burger Shot - Staff Only',
        modelHash = 0x9E830AC7,
        coords = vector3(-1178.86, -892.18, 14.06),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 0 },
        pickable = false,
    },

    -- Burger Shot - Boss Room (Manager Only)
    {
        id = 'bs_boss',
        label = 'Burger Shot - Boss Room',
        modelHash = 0xDAA58F29,
        coords = vector3(-1181.95, -895.45, 14.19),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 3 },       -- Manager only
        pickable = false,
    },

    -- Burger Shot - Staff Only Door
    {
        id = 'bs_staff_only',
        label = 'Burger Shot - Staff Only',
        modelHash = 0x4CE0739D,
        coords = vector3(-1184.50, -897.20, 14.42),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['burgershot'] = 0 },
        pickable = false,
    },

    -- Burger Shot - Back Exit Left
    {
        id = 'bs_back_left',
        label = 'Burger Shot - Back Exit',
        modelHash = 0xCFE9EFF9,
        coords = vector3(-1198.25, -884.64, 14.06),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Burger Shot - Back Exit Right
    {
        id = 'bs_back_right',
        label = 'Burger Shot - Back Exit',
        modelHash = 0x17087E25,
        coords = vector3(-1197.50, -884.13, 14.07),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- ========================================================================
    -- MMA FIGHT ARENA (patoche_fight)
    -- ========================================================================

    -- Arena - Outside Door 1 (Left)
    {
        id = 'mma_outside_1',
        label = 'MMA Arena - Entrance',
        model = 'v_ilev_stad_fdoor',
        coords = vector3(2228.314, 19.4381, 101.3554),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Outside Door 2 (Right)
    {
        id = 'mma_outside_2',
        label = 'MMA Arena - Entrance',
        model = 'v_ilev_stad_fdoor',
        coords = vector3(2231.415, 19.4381, 101.3554),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Outside Door 3 (Left)
    {
        id = 'mma_outside_3',
        label = 'MMA Arena - Entrance',
        model = 'v_ilev_stad_fdoor',
        coords = vector3(2233.616, 19.4381, 101.3554),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Outside Door 4 (Right)
    {
        id = 'mma_outside_4',
        label = 'MMA Arena - Entrance',
        model = 'v_ilev_stad_fdoor',
        coords = vector3(2236.716, 19.4381, 101.3554),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Outside Door 5 (Left)
    {
        id = 'mma_outside_5',
        label = 'MMA Arena - Entrance',
        model = 'v_ilev_stad_fdoor',
        coords = vector3(2238.918, 19.4381, 101.3554),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Outside Door 6 (Right)
    {
        id = 'mma_outside_6',
        label = 'MMA Arena - Entrance',
        model = 'v_ilev_stad_fdoor',
        coords = vector3(2242.018, 19.4381, 101.3554),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Entrance Door 1 (Left)
    {
        id = 'mma_arena_entrance_1',
        label = 'MMA Arena - Arena Entrance',
        model = 'patoche_fight_door2',
        coords = vector3(2224.705, 47.6307, 101.0951),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Entrance Door 2 (Right)
    {
        id = 'mma_arena_entrance_2',
        label = 'MMA Arena - Arena Entrance',
        model = 'patoche_fight_door2',
        coords = vector3(2226.963, 46.85623, 101.0951),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Entrance Door 3 (Left)
    {
        id = 'mma_arena_entrance_3',
        label = 'MMA Arena - Arena Entrance',
        model = 'patoche_fight_door2',
        coords = vector3(2243.36, 46.86385, 101.0951),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Entrance Door 4 (Right)
    {
        id = 'mma_arena_entrance_4',
        label = 'MMA Arena - Arena Entrance',
        model = 'patoche_fight_door2',
        coords = vector3(2245.618, 47.6307, 101.0951),
        heading = 0.0,
        locked = false,
        distance = 2.5,
        doorType = 'door',
        allAuthorized = true,
        pickable = false,
    },

    -- Arena - Underground Door 1 (Left)
    {
        id = 'mma_underground_1',
        label = 'MMA Arena - Underground',
        model = 'v_ilev_serv_door01',
        coords = vector3(2259.439, 23.50245, 95.62736),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = {},
        pickable = false,
    },

    -- Arena - Underground Door 2 (Right)
    {
        id = 'mma_underground_2',
        label = 'MMA Arena - Underground',
        model = 'v_ilev_serv_door01',
        coords = vector3(2257.301, 22.41288, 95.62736),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = {},
        pickable = false,
    },

    -- Arena - Cage Door
    {
        id = 'mma_cage_door',
        label = 'MMA Arena - Cage',
        model = 'patoche_fight_mmadoor',
        coords = vector3(2232.224, 70.19965, 101.9678),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = {},
        pickable = false,
    },

    -- ========================================================================
    -- MISSION ROW POLICE DEPARTMENT - HOLDING CELLS
    -- Model Hash: 0x3893FE06 (Cell doors)
    -- ========================================================================

    -- MRPD - Holding Cell 1
    {
        id = 'mrpd_cell_1',
        label = 'MRPD - Holding Cell 1',
        modelHash = 0x3893FE06,
        coords = vector3(490.74, -998.27, 21.36),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Holding Cell 2
    {
        id = 'mrpd_cell_2',
        label = 'MRPD - Holding Cell 2',
        modelHash = 0x3893FE06,
        coords = vector3(497.14, -998.25, 21.38),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Holding Cell 3
    {
        id = 'mrpd_cell_3',
        label = 'MRPD - Holding Cell 3',
        modelHash = 0x3893FE06,
        coords = vector3(502.25, -1001.77, 21.39),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Holding Cell 4
    {
        id = 'mrpd_cell_4',
        label = 'MRPD - Holding Cell 4',
        modelHash = 0x3893FE06,
        coords = vector3(502.85, -1007.32, 21.39),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Holding Cell 5
    {
        id = 'mrpd_cell_5',
        label = 'MRPD - Holding Cell 5',
        modelHash = 0x3893FE06,
        coords = vector3(499.83, -1011.97, 21.38),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Holding Cell 6
    {
        id = 'mrpd_cell_6',
        label = 'MRPD - Holding Cell 6',
        modelHash = 0x3893FE06,
        coords = vector3(493.75, -1013.12, 21.29),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Holding Cell 7
    {
        id = 'mrpd_cell_7',
        label = 'MRPD - Holding Cell 7',
        modelHash = 0x3893FE06,
        coords = vector3(487.12, -1013.05, 21.35),
        heading = 0.0,
        locked = true,
        distance = 2.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- ========================================================================
    -- MISSION ROW POLICE DEPARTMENT - GARAGE & BARRIERS
    -- Vehicle-activated doors (also work on foot)
    -- ========================================================================

    -- MRPD - Front Barrier 1 (raises/lowers) - PROP TYPE
    {
        id = 'mrpd_barrier_1',
        label = 'MRPD - Security Barrier',
        modelHash = 0x08658726,
        coords = vector3(410.31, -1018.09, 29.06),
        heading = 0.0,
        locked = true,
        distance = 5.0,
        doorType = 'barrier',  -- Special type for prop barriers
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
        -- Barrier moves up/down on Z axis
        openOffset = vector3(0, 0, -2.0),  -- Move down 2 units when open
    },

    -- MRPD - Front Barrier 2 (raises/lowers) - PROP TYPE
    {
        id = 'mrpd_barrier_2',
        label = 'MRPD - Security Barrier',
        modelHash = 0x08658726,
        coords = vector3(410.34, -1025.65, 29.07),
        heading = 0.0,
        locked = true,
        distance = 5.0,
        doorType = 'barrier',  -- Special type for prop barriers
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
        -- Barrier moves up/down on Z axis
        openOffset = vector3(0, 0, -2.0),  -- Move down 2 units when open
    },

    -- MRPD - Main Garage Door Left
    {
        id = 'mrpd_garage_main_left',
        label = 'MRPD - Main Garage',
        modelHash = 0xA1F6A0EE,
        coords = vector3(427.90, -1025.28, 26.26),
        heading = 0.0,
        locked = true,
        distance = 8.0,
        doorType = 'garage',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
        linkedDoor = 'mrpd_garage_main_right',
    },

    -- MRPD - Main Garage Door Right
    {
        id = 'mrpd_garage_main_right',
        label = 'MRPD - Main Garage',
        modelHash = 0x742BC559,
        coords = vector3(428.07, -1026.71, 25.00),
        heading = 0.0,
        locked = true,
        distance = 8.0,
        doorType = 'garage',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
        linkedDoor = 'mrpd_garage_main_left',
    },

    -- MRPD - Operation Room (inside parking)
    {
        id = 'mrpd_ops_room',
        label = 'MRPD - Operations Room',
        modelHash = 0xAC5F549E,
        coords = vector3(410.06, -981.44, 21.78),
        heading = 0.0,
        locked = true,
        distance = 3.0,
        doorType = 'door',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
    },

    -- MRPD - Back Garage Exit Left
    {
        id = 'mrpd_garage_back_left',
        label = 'MRPD - Back Garage Exit',
        modelHash = 0x9FA79C50,
        coords = vector3(488.73, -1034.25, 29.05),
        heading = 0.0,
        locked = true,
        distance = 8.0,
        doorType = 'garage',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
        linkedDoor = 'mrpd_garage_back_right',
    },

    -- MRPD - Back Garage Exit Right
    {
        id = 'mrpd_garage_back_right',
        label = 'MRPD - Back Garage Exit',
        modelHash = 0xD1597FB3,
        coords = vector3(488.66, -1037.06, 28.88),
        heading = 0.0,
        locked = true,
        distance = 8.0,
        doorType = 'garage',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
        linkedDoor = 'mrpd_garage_back_left',
    },

    -- MRPD - Back Garage Entrance
    {
        id = 'mrpd_garage_back_entrance',
        label = 'MRPD - Back Garage Entrance',
        modelHash = 0xF229D207,
        coords = vector3(489.50, -1020.83, 29.11),
        heading = 0.0,
        locked = true,
        distance = 8.0,
        doorType = 'garage',
        authorizedJobs = { ['police'] = 0 },
        pickable = false,
        vehicleActivated = true,
    },

    -- ============================================================================
    -- APARTMENT DOORS (managed by sb_apartments — no direct player toggle)
    -- ============================================================================

    -- Del Perro Apartments (Floor 2)
    { id = 'apt_dp_101', label = 'Del Perro - Unit 101', modelHash = 0xDEEFCECE, coords = vector3(-1567.08, -400.64, 48.05), heading = 140.0, locked = true, distance = 2.0, doorType = 'door', enforceState = true },
    { id = 'apt_dp_102', label = 'Del Perro - Unit 102', modelHash = 0xDEEFCECE, coords = vector3(-1559.23, -391.29, 48.06), heading = 140.0, locked = true, distance = 2.0, doorType = 'door', enforceState = true },

    -- Emissary Hotel Floor 3
    { id = 'apt_em_301', label = 'Emissary - Room 301', modelHash = 0x0B9AE8D5, coords = vector3(63.31, -955.01, 47.00), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_302', label = 'Emissary - Room 302', modelHash = 0x0B9AE8D5, coords = vector3(75.79, -959.55, 47.05), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_303', label = 'Emissary - Room 303', modelHash = 0x0B9AE8D5, coords = vector3(77.59, -958.38, 46.94), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_304', label = 'Emissary - Room 304', modelHash = 0x0B9AE8D5, coords = vector3(76.29, -956.45, 47.00), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_305', label = 'Emissary - Room 305', modelHash = 0x0B9AE8D5, coords = vector3(63.43, -951.77, 47.00), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },

    -- Emissary Hotel Floor 4 (Z + 8.5396)
    { id = 'apt_em_401', label = 'Emissary - Room 401', modelHash = 0x0B9AE8D5, coords = vector3(63.31, -955.01, 55.54), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_402', label = 'Emissary - Room 402', modelHash = 0x0B9AE8D5, coords = vector3(75.79, -959.55, 55.55), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_403', label = 'Emissary - Room 403', modelHash = 0x0B9AE8D5, coords = vector3(77.59, -958.38, 55.48), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_404', label = 'Emissary - Room 404', modelHash = 0x0B9AE8D5, coords = vector3(76.29, -956.45, 55.54), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_405', label = 'Emissary - Room 405', modelHash = 0x0B9AE8D5, coords = vector3(63.43, -951.77, 55.54), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },

    -- Emissary Hotel Floor 5 (Z + 17.0792)
    { id = 'apt_em_501', label = 'Emissary - Room 501', modelHash = 0x0B9AE8D5, coords = vector3(63.31, -955.01, 64.08), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_502', label = 'Emissary - Room 502', modelHash = 0x0B9AE8D5, coords = vector3(75.79, -959.55, 64.05), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_503', label = 'Emissary - Room 503', modelHash = 0x0B9AE8D5, coords = vector3(77.59, -958.38, 64.02), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_504', label = 'Emissary - Room 504', modelHash = 0x0B9AE8D5, coords = vector3(76.29, -956.45, 64.08), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_505', label = 'Emissary - Room 505', modelHash = 0x0B9AE8D5, coords = vector3(63.43, -951.77, 64.08), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },

    -- Emissary Hotel Floor 6 (Z + 25.6188)
    { id = 'apt_em_601', label = 'Emissary - Room 601', modelHash = 0x0B9AE8D5, coords = vector3(63.31, -955.01, 72.62), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_602', label = 'Emissary - Room 602', modelHash = 0x0B9AE8D5, coords = vector3(75.79, -959.55, 72.55), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_603', label = 'Emissary - Room 603', modelHash = 0x0B9AE8D5, coords = vector3(77.59, -958.38, 72.56), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_604', label = 'Emissary - Room 604', modelHash = 0x0B9AE8D5, coords = vector3(76.29, -956.45, 72.62), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },
    { id = 'apt_em_605', label = 'Emissary - Room 605', modelHash = 0x0B9AE8D5, coords = vector3(63.43, -951.77, 72.62), heading = 0.0, locked = true, distance = 3, doorType = 'door', enforceState = true },

}

-- ============================================================================
-- DOOR STATE MAPPINGS (for GTA natives)
-- ============================================================================
Config.DoorStates = {
    UNLOCKED = 0,
    LOCKED = 1,
    LOCKED_SOFT = 4
}

-- ============================================================================
-- HELPER: Get door by ID
-- ============================================================================
function Config.GetDoorById(doorId)
    for i, door in ipairs(Config.Doors) do
        if door.id == doorId then
            return door, i
        end
    end
    return nil, nil
end
