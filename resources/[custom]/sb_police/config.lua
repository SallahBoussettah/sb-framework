Config = {}

-- Job Configuration
Config.PoliceJob = 'police'
Config.MDTKey = 'F6' -- Key to open MDT

-- ============================================================================
-- POLICE STATIONS
-- Use /policecoords in-game to get your current position for easy setup!
-- ============================================================================
Config.Stations = {
    ['mrpd'] = {
        id = 'mrpd',
        name = 'Mission Row Police Department',
        enabled = true,  -- Set to false to disable this station

        -- ============================
        -- MAP BLIP (main station marker)
        -- ============================
        blip = {
            coords = vector3(432.62, -980.81, 30.72),  -- TODO: Get coords with /policecoords
            sprite = 60,
            color = 29,
            scale = 1.0,
            label = 'Police Station'
        },

        -- ============================
        -- DUTY POINT (clock in/out)
        -- ============================
        duty = {
            coords = vector3(448.13, -983.09, 30.80),  -- TODO: Stand at duty point, use /policecoords
            heading = 0.0,
            label = 'Clock In/Out',
            -- marker = { type = 21, color = { 66, 135, 245, 100 }, scale = 0.5 } -- No marker its an object they gotta interact with if they have job it will show duty toggle, if they dont it should show register and we will work on it later it will for registering players to be police
        },

        -- ============================
        -- ARMORY (weapons locker)
        -- ============================
        armory = {
            coords = vector3(464.2141, -1010.1857, 30.7094),  -- TODO: Stand at armory, use /policecoords
            heading =  359.1918,
            label = 'Armory',
            marker = { type = 21, color = { 255, 100, 100, 100 }, scale = 0.5 }
        },

        -- ============================
        -- LOCKER ROOM (clothing)
        -- ============================
        locker = {
            coords = vector3(458.32, -999.60, 30.71),  -- TODO: Stand at lockers, use /policecoords
            heading = 8,
            label = 'Locker Room',
            marker = { type = 21, color = { 100, 255, 100, 100 }, scale = 0.5 }
        },

        -- ============================
        -- EVIDENCE LOCKER
        -- ============================
        evidence = {
            coords = vector3(462.78, -1009.18, 21.95),
            heading = 269.2,
            label = 'Evidence Locker',
            marker = { type = 21, color = { 255, 255, 100, 100 }, scale = 0.5 }
        },

        -- ============================
        -- BOSS OFFICE (rank 9 only)
        -- ============================
        boss = {
            coords = vector3(467.21, -1008.63, 30.74),  -- TODO: Stand at boss desk, use /policecoords
            heading = 0.0,
            label = 'Boss Menu',
            minGrade = 9,  -- Only rank 9 can access
            marker = { type = 21, color = { 255, 200, 0, 100 }, scale = 0.5 }
        },

        -- ============================
        -- HOLDING CELLS (array of cells)
        -- Door Model: 0x3893FE06 - needs to be added to sb_doorlock with police job
        -- ============================
        cells = {
            {
                coords = vector3(488.7525, -995.6929, 21.1494),
                label = 'Holding Cell 1',
                door = { model = 0x3893FE06, coords = vector3(490.74, -998.27, 21.36) }
            },
            {
                coords = vector3(495.6721, -995.8752, 21.1494),
                label = 'Holding Cell 2',
                door = { model = 0x3893FE06, coords = vector3(497.14, -998.25, 21.38) }
            },
            {
                coords = vector3(502.73, -999.14, 21.15),
                label = 'Holding Cell 3',
                door = { model = 0x3893FE06, coords = vector3(502.25, -1001.77, 21.39) }
            },
            {
                coords = vector3(504.78, -1005.53, 21.15),
                label = 'Holding Cell 4',
                door = { model = 0x3893FE06, coords = vector3(502.85, -1007.32, 21.39) }
            },
            {
                coords = vector3(501.96, -1012.01, 21.15),
                label = 'Holding Cell 5',
                door = { model = 0x3893FE06, coords = vector3(499.83, -1011.97, 21.38) }
            },
            {
                coords = vector3(495.19, -1015.23, 21.15),
                label = 'Holding Cell 6',
                door = { model = 0x3893FE06, coords = vector3(493.75, -1013.12, 21.29) }
            },
            {
                coords = vector3(488.61, -1014.91, 21.15),
                label = 'Holding Cell 7',
                door = { model = 0x3893FE06, coords = vector3(487.12, -1013.05, 21.35) }
            }
        },

        -- ============================
        -- VEHICLE GARAGES (Multiple NPC points)
        -- Each garage has an NPC and multiple spawn locations
        -- ============================
        garages = {
            {
                id = 'garage_1',
                label = 'Police Garage 1',
                npc = {
                    model = 's_m_y_cop_01',  -- Police NPC model
                    coords = vector3(427.41, -998.74, 21.45),
                    heading = 359.0
                },
                spawnPoints = {
                    { coords = vector3(427.28, -988.46, 20.73), heading = 270.07 },
                    { coords = vector3(427.35, -985.44, 20.73), heading = 269.86 }
                }
            },
            {
                id = 'garage_2',
                label = 'Police Garage 2',
                npc = {
                    model = 's_m_y_cop_01',
                    coords = vector3(426.23, -966.46, 21.45),
                    heading = 268.87
                },
                spawnPoints = {
                    { coords = vector3(427.26, -968.71, 20.73), heading = 270.58 },
                    { coords = vector3(427.26, -971.50, 20.73), heading = 270.58 }  -- Second spot
                }
            }
        },

        -- ============================
        -- HELIPAD (optional)
        -- ============================
        helipad = {
            enabled = false,
            spawn = vector3(0.0, 0.0, 0.0),
            heading = 0.0,
            access = vector3(0.0, 0.0, 0.0),
            minGrade = 5,
            label = 'Helipad'
        },

        -- ============================
        -- BOAT DOCK (optional)
        -- ============================
        boatdock = {
            enabled = false,
            spawn = vector3(0.0, 0.0, 0.0),
            heading = 0.0,
            access = vector3(0.0, 0.0, 0.0),
            minGrade = 4,
            label = 'Boat Dock'
        },

        -- ============================
        -- IMPOUND LOT
        -- ============================
        impound = {
            npc = {
                model = 's_m_y_cop_01',
                coords = vector3(452.42, -958.24, 21.45),
                heading = 91.28
            },
            label = 'Police Impound',
            spawnPoints = {
                { coords = vector3(454.94, -961.85, 20.73), heading = 88.52 },
                { coords = vector3(455.14, -968.03, 20.73), heading = 90.19 }
            }
        }
    }
}

-- Police Ranks (10 grades: 0-9)
Config.Ranks = {
    { grade = 0, name = 'Cadet', salary = 500, canHire = false, canFire = false, canPromote = false },
    { grade = 1, name = 'Officer I', salary = 750, canHire = false, canFire = false, canPromote = false },
    { grade = 2, name = 'Officer II', salary = 900, canHire = false, canFire = false, canPromote = false },
    { grade = 3, name = 'Officer III', salary = 1100, canHire = false, canFire = false, canPromote = false },
    { grade = 4, name = 'Corporal', salary = 1300, canHire = false, canFire = false, canPromote = false },
    { grade = 5, name = 'Sergeant', salary = 1500, canHire = true, canFire = false, canPromote = true },
    { grade = 6, name = 'Lieutenant', salary = 1800, canHire = true, canFire = true, canPromote = true },
    { grade = 7, name = 'Captain', salary = 2200, canHire = true, canFire = true, canPromote = true },
    { grade = 8, name = 'Commander', salary = 2800, canHire = true, canFire = true, canPromote = true },
    { grade = 9, name = 'Chief of Police', salary = 3500, canHire = true, canFire = true, canPromote = true },
}

-- Police Vehicles (grade = exact rank required in 'exact' mode)
-- Categories: patrol, pursuit, motorcycle, swat, air, marine, command, transport
--
-- RESOURCES NEEDED (move from [cars-to-add] and ensure in server.cfg):
--   ensure qbcorestore-govpack_lore   -- polvictoria, poltaurus, polcharger, poltahoe, polexplorer,
--                                     -- polcamaro, polvette, polram, polraptor, polbike, polbike2, polmav
--                                     -- WARNING: also has poldurango/polmustang — delete those .yft/.ytd
--                                     -- from its stream/ to avoid conflicts with police_tier2
--   ensure lspdpack                   -- code3cvpi, code318charg, code3mustang, code3bmw, code3camero, polp1
--   ensure np-chall                   -- npolchal
--   ensure lspdhelicopter             -- as350
--
Config.Vehicles = {
    -- ===== GRADE 0: Cadet — Basic patrol, classic cruisers =====
    { model = 'polsilverado19', label = 'Police Silverado',   grade = 0, category = 'patrol', image = 'polsilverado19' },
    { model = 'polvictoria',    label = 'Crown Victoria',     grade = 0, category = 'patrol', image = 'polvictoria' },
    { model = 'poltaurus',      label = 'Police Taurus',      grade = 0, category = 'patrol', image = 'poltaurus' },

    -- ===== GRADE 1: Officer I — Standard patrol =====
    { model = 'code3cvpi',      label = 'Crown Vic Interceptor', grade = 1, category = 'patrol', image = 'code3cvpi' },
    { model = 'polcharger',     label = 'Police Charger',        grade = 1, category = 'patrol', image = 'polcharger' },
    { model = 'poltahoe',       label = 'Police Tahoe',          grade = 1, category = 'patrol', image = 'poltahoe' },

    -- ===== GRADE 2: Officer II — Modern patrol =====
    { model = 'buffalosxpolun', label = 'Buffalo SX (Unmarked)', grade = 2, category = 'patrol',  image = 'buffalosxpolun' },
    { model = 'polmustang',     label = 'Police Mustang',        grade = 2, category = 'pursuit', image = 'polmustang' },
    { model = 'code318charg',   label = 'Charger 2018',          grade = 2, category = 'patrol',  image = 'code318charg' },
    { model = 'polexplorer',    label = 'Police Explorer',       grade = 2, category = 'patrol',  image = 'polexplorer' },

    -- ===== GRADE 3: Officer III — SUVs + pursuit muscle =====
    { model = 'poldurango',     label = 'Police Durango',    grade = 3, category = 'patrol',     image = 'poldurango' },
    { model = 'polbmwm3',       label = 'BMW M3 Pursuit',   grade = 3, category = 'pursuit',    image = 'polbmwm3' },
    { model = 'polcamaro',      label = 'Police Camaro',     grade = 3, category = 'pursuit',    image = 'polcamaro' },
    { model = 'valorharley',    label = 'Harley Davidson',   grade = 3, category = 'motorcycle', image = 'valorharley' },

    -- ===== GRADE 4: Corporal — Pursuit-focused =====
    { model = 'polbmwm5',       label = 'BMW M5 Pursuit',       grade = 4, category = 'pursuit',    image = 'polbmwm5' },
    { model = 'npolchal',       label = 'Challenger Pursuit',    grade = 4, category = 'pursuit',    image = 'npolchal' },
    { model = 'code3mustang',   label = 'Mustang Interceptor',   grade = 4, category = 'pursuit',    image = 'code3mustang' },
    { model = 'mtbike',         label = 'Police Dirt Bike',      grade = 4, category = 'motorcycle', image = 'mtbike' },

    -- ===== GRADE 5: Sergeant — Command & high-performance =====
    { model = 'polbmwm7',       label = 'BMW M7 Command',   grade = 5, category = 'command',    image = 'polbmwm7' },
    { model = 'polgt63',        label = 'AMG GT63 Pursuit',  grade = 5, category = 'pursuit',    image = 'polgt63' },
    { model = 'polrs6',         label = 'Audi RS6 Pursuit',  grade = 5, category = 'pursuit',    image = 'polrs6' },
    { model = 'Prisonvan2rb',   label = 'Prison Transport',  grade = 5, category = 'transport',  image = 'Prisonvan2rb' },
    { model = '25rnbrt',        label = 'KTM Police Bike',   grade = 5, category = 'motorcycle', image = '25rnbrt' },

    -- ===== GRADE 6: Lieutenant — Special/Detective + bike =====
    { model = 'unmarkedjl',     label = 'Unmarked Detective', grade = 6, category = 'command',    image = 'unmarkedjl' },
    { model = 'sw_charg',       label = 'SWAT Charger',       grade = 6, category = 'swat',       image = 'sw_charg' },
    { model = 'sw_durango',     label = 'SWAT Durango',       grade = 6, category = 'swat',       image = 'sw_durango' },
    { model = 'polvette',       label = 'Corvette Pursuit',   grade = 6, category = 'pursuit',    image = 'polvette' },
    { model = 'polcoach',       label = 'Police Coach',        grade = 6, category = 'transport',  image = 'polcoach' },
    { model = 'policeboat',     label = 'Police Boat',         grade = 6, category = 'marine',     image = 'policeboat' },
    { model = 'polbike',        label = 'Police Harley',       grade = 6, category = 'motorcycle', image = 'polbike' },

    -- ===== GRADE 7: Captain — Tactical + air + bike =====
    { model = 'sw_subrb',       label = 'SWAT Suburban',       grade = 7, category = 'swat',       image = 'sw_subrb' },
    { model = 'sw_sprinter',    label = 'SWAT Sprinter',       grade = 7, category = 'transport',  image = 'sw_sprinter' },
    { model = 'polram',         label = 'Police RAM Truck',    grade = 7, category = 'command',    image = 'polram' },
    { model = 'polheli',        label = 'Police Helicopter',   grade = 7, category = 'air',        image = 'polheli' },
    { model = 'polbike2',       label = 'Police BMW Bike',     grade = 7, category = 'motorcycle', image = 'polbike2' },

    -- ===== GRADE 8: Commander — Heavy tactical + air + bike =====
    { model = 'sw_bearcat',     label = 'SWAT Bearcat',        grade = 8, category = 'swat',       image = 'sw_bearcat' },
    { model = 'polraptor',      label = 'Police Raptor',       grade = 8, category = 'command',    image = 'polraptor' },
    { model = 'polmav',         label = 'Police Maverick',     grade = 8, category = 'air',        image = 'polmav' },
    { model = 'code3bmw',       label = 'BMW Police Bike',     grade = 8, category = 'motorcycle', image = 'code3bmw' },

    -- ===== GRADE 9: Chief of Police — Exotic + premium air =====
    { model = 'polp1',          label = 'McLaren P1 Police',   grade = 9, category = 'pursuit',    image = 'polp1' },
    { model = 'code3camero',    label = 'Camaro Interceptor',  grade = 9, category = 'pursuit',    image = 'code3camero' },
    { model = 'polchallenger',  label = 'Challenger Command',  grade = 9, category = 'command',    image = 'polchallenger' },
    { model = 'as350',          label = 'AS350 Helicopter',    grade = 9, category = 'air',        image = 'as350' },
}

-- Vehicle Categories (for menu filtering)
Config.VehicleCategories = {
    { id = 'all', label = 'All Vehicles', icon = 'fa-car' },
    { id = 'patrol', label = 'Patrol', icon = 'fa-car-side' },
    { id = 'pursuit', label = 'Pursuit', icon = 'fa-gauge-high' },
    { id = 'motorcycle', label = 'Motorcycles', icon = 'fa-motorcycle' },
    { id = 'swat', label = 'SWAT', icon = 'fa-shield-halved' },
    { id = 'command', label = 'Command', icon = 'fa-star' },
    { id = 'transport', label = 'Transport', icon = 'fa-bus' },
    { id = 'air', label = 'Air Unit', icon = 'fa-helicopter' },
    { id = 'marine', label = 'Marine', icon = 'fa-ship' },
}

-- Armory Equipment
Config.Armory = {
    -- Weapons available in armory stash
    -- Firearms need sb_weapons Config.Weapons to fire (magazine system)
    -- Melee/taser work standalone via native GTA weapons
    weapons = {
        { name = 'weapon_pistol', label = 'Pistol', price = 0, grade = 0 },
        { name = 'weapon_combatpistol', label = 'Combat Pistol', price = 0, grade = 0 },     -- TODO: add to sb_weapons for magazine system
        { name = 'weapon_stungun', label = 'Taser', price = 0, grade = 0 },                   -- Works standalone (native taser)
        { name = 'weapon_nightstick', label = 'Nightstick', price = 0, grade = 0 },            -- Works standalone (melee)
        { name = 'weapon_pumpshotgun', label = 'Pump Shotgun', price = 0, grade = 2 },         -- TODO: add to sb_weapons for magazine system
        { name = 'weapon_smg', label = 'SMG', price = 0, grade = 3 },                          -- TODO: add to sb_weapons for magazine system
        { name = 'weapon_carbinerifle', label = 'Carbine Rifle', price = 0, grade = 4 },       -- TODO: add to sb_weapons for magazine system
    },
    items = {
        { name = 'radio', label = 'Radio', price = 0, amount = 1 },
        { name = 'handcuffs', label = 'Handcuffs', price = 0, amount = 1 },
        { name = 'armor', label = 'Body Armor', price = 0, amount = 1 },
        { name = 'firstaid', label = 'First Aid Kit', price = 0, amount = 2 },
        { name = 'radar_gun', label = 'Radar Gun', price = 0, amount = 1 },
        { name = 'flashlight', label = 'Flashlight', price = 0, amount = 1 },
    },
    ammo = {
        { name = 'pistol_ammo', label = 'Pistol Ammo', price = 0, amount = 60 },
        { name = 'smg_ammo', label = 'SMG Ammo', price = 0, amount = 90 },
        { name = 'shotgun_ammo', label = 'Shotgun Ammo', price = 0, amount = 24 },
        { name = 'rifle_ammo', label = 'Rifle Ammo', price = 0, amount = 90 },
    },
    -- Magazines available in armory (loaded with full capacity)
    magazines = {
        { name = 'p_stand_mag', label = 'Standard Mag', price = 0, amount = 3 },
        { name = 'p_extended_mag', label = 'Extended Mag', price = 0, amount = 1 },
    }
}

-- ============================================================================
-- SIREN & LIGHTS SYSTEM
-- L = Toggle lights, ; = Cycle siren tones, E = Air horn (hold)
-- ============================================================================
Config.Sirens = {
    Enabled = true,

    -- Sound Mode: 'native' = GTA V sounds, 'custom' = NUI audio files
    -- Use 'native' for built-in GTA sounds (no files needed)
    -- Use 'custom' to use your own .ogg files in html/sounds/
    SoundMode = 'native',

    -- Keybinds (avoiding pma-voice radio keys: Q, comma, period)
    LightsKey = 'L',          -- Toggle emergency lights
    SirenKey = 'SEMICOLON',   -- Cycle siren tones (;)
    HornKey = 86,             -- Air horn (E key - INPUT_VEH_HORN, same as native horn)

    -- Native GTA V siren sounds (when SoundMode = 'native')
    NativeSounds = {
        'VEHICLES_HORNS_SIREN_1',    -- Wail
        'VEHICLES_HORNS_SIREN_2',    -- Yelp
        'VEHICLES_HORNS_POLICE_WARNING'  -- Hi-Lo/Priority
    },
    NativeHorn = 'SIRENS_AIRHORN',

    -- Custom sound files (when SoundMode = 'custom')
    -- Place files in html/sounds/: siren1.ogg, siren2.ogg, siren3.ogg, horn.ogg
    CustomSounds = {
        'siren1',
        'siren2',
        'siren3'
    },
    CustomHorn = 'horn',

    -- Vehicles that can use sirens (model name = true)
    Vehicles = {
        -- Standard Police
        ['police'] = true,
        ['police2'] = true,
        ['police3'] = true,
        ['police4'] = true,
        ['policeb'] = true,      -- Motorcycle
        ['sheriff'] = true,
        ['sheriff2'] = true,
        -- Unmarked/FBI
        ['fbi'] = true,
        ['fbi2'] = true,
        -- EMS
        ['ambulance'] = true,
        -- Fire
        ['firetruk'] = true,
        -- Custom vehicles from server (must match Config.Vehicles model names)
        -- Grade 0: Cadet
        ['polsilverado19'] = true,
        ['polvictoria'] = true,
        ['poltaurus'] = true,
        -- Grade 1: Officer I
        ['code3cvpi'] = true,
        ['polcharger'] = true,
        ['poltahoe'] = true,
        -- Grade 2: Officer II
        ['buffalosxpolun'] = true,
        ['polmustang'] = true,
        ['code318charg'] = true,
        ['polexplorer'] = true,
        -- Grade 3: Officer III
        ['poldurango'] = true,
        ['polbmwm3'] = true,
        ['polcamaro'] = true,
        ['valorharley'] = true,
        -- Grade 4: Corporal
        ['polbmwm5'] = true,
        ['npolchal'] = true,
        ['code3mustang'] = true,
        ['mtbike'] = true,
        -- Grade 5: Sergeant
        ['polbmwm7'] = true,
        ['polgt63'] = true,
        ['polrs6'] = true,
        ['Prisonvan2rb'] = true,
        ['25rnbrt'] = true,
        -- Grade 6: Lieutenant
        ['unmarkedjl'] = true,
        ['sw_charg'] = true,
        ['sw_durango'] = true,
        ['polvette'] = true,
        ['polcoach'] = true,
        ['policeboat'] = true,
        ['polbike'] = true,
        -- Grade 7: Captain
        ['sw_subrb'] = true,
        ['sw_sprinter'] = true,
        ['polram'] = true,
        ['polheli'] = true,
        ['polbike2'] = true,
        -- Grade 8: Commander
        ['sw_bearcat'] = true,
        ['polraptor'] = true,
        ['polmav'] = true,
        ['code3bmw'] = true,
        -- Grade 9: Chief
        ['polp1'] = true,
        ['code3camero'] = true,
        ['polchallenger'] = true,
        ['as350'] = true,
    }
}

-- ============================================================================
-- COURTHOUSE (Fine Payment)
-- ============================================================================
Config.Courthouse = {
    coords = vector3(242.0, -1072.0, 29.0),  -- Near MRPD
    label = 'Pay Fines',
    icon = 'fa-gavel',
    blip = {
        sprite = 184,
        color = 3,
        scale = 0.8,
        label = 'Courthouse'
    }
}

-- Citation Config
Config.Citations = {
    -- Traffic offenses for citation dropdown (subset of penal code)
    categories = { 'Traffic', 'Infraction' },
}

-- Evidence Types
Config.EvidenceTypes = {
    { id = 'blood', label = 'Blood Sample', item = 'evidence_blood', icon = 'droplet' },
    { id = 'casing', label = 'Bullet Casing', item = 'evidence_casing', icon = 'bullet' },
    { id = 'footprint', label = 'Footprint', item = 'evidence_footprint', icon = 'shoe' },
    { id = 'fingerprint', label = 'Fingerprint', item = 'evidence_fingerprint', icon = 'fingerprint' },
    { id = 'drugs', label = 'Drug Residue', item = 'evidence_drugs', icon = 'pills' },
    { id = 'photo', label = 'Photo Evidence', item = 'evidence_photo', icon = 'camera' },
}

-- MDT Configuration
Config.MDT = {
    -- Report tags
    tags = {
        { id = 'open', label = 'Open Case', color = '#4ade80' },
        { id = 'closed', label = 'Closed', color = '#94a3b8' },
        { id = 'pending', label = 'Pending Review', color = '#f59e0b' },
        { id = 'urgent', label = 'Urgent', color = '#ef4444' },
        { id = 'cold', label = 'Cold Case', color = '#60a5fa' },
    },
    -- Danger levels for federal inmates
    dangerLevels = {
        { id = 'low', label = 'Low', color = '#4ade80' },
        { id = 'medium', label = 'Medium', color = '#f59e0b' },
        { id = 'high', label = 'High', color = '#ef4444' },
        { id = 'extreme', label = 'Extreme', color = '#dc2626' },
    }
}

-- Duty status options
Config.DutyStatus = {
    { id = 'available', label = 'Available', color = '#4ade80' },
    { id = 'busy', label = 'Busy', color = '#f59e0b' },
    { id = 'responding', label = 'Responding', color = '#60a5fa' },
    { id = 'unavailable', label = 'Unavailable', color = '#ef4444' },
}

-- Field Actions Configuration
Config.Field = {
    -- Durations (milliseconds)
    CuffDuration = 3000,      -- Time to apply cuffs
    UncuffDuration = 2000,    -- Time to remove cuffs
    SearchDuration = 5000,    -- Time to search suspect
    PutInVehicleDuration = 2500,  -- Time to put in vehicle
    TakeOutDuration = 2000,   -- Time to take out of vehicle

    -- Escort settings
    EscortDistance = 1.0,     -- Distance behind officer when escorted

    -- Animation definitions
    Animations = {
        cuff_officer = {
            dict = 'mp_arrest_paired',
            anim = 'cop_p2_back_right',
            flag = 0
        },
        cuff_target = {
            dict = 'mp_arrest_paired',
            anim = 'crook_p2_back_right',
            flag = 0
        },
        cuffed_idle = {
            dict = 'mp_arresting',
            anim = 'idle',
            flag = 49
        },
        search = {
            dict = 'mini@repair',
            anim = 'youmechanic_base_side_2_a',
            flag = 49
        }
    },

    -- Movement clipsets for cuffed players
    MovementClipsets = {
        soft = 'move_m@prisoner_cuffed',  -- Hands in front, can walk
        hard = 'move_m@prisoner_cuffed'   -- Hands behind, slower
    },

    -- Item requirements (optional)
    RequireCuffsItem = false,  -- Set true to require handcuffs item
    CuffsItem = 'handcuffs'    -- Item name if RequireCuffsItem is true
}

-- Tackle Configuration
Config.Tackle = {
    Cooldown = 10000,           -- 10 seconds between tackles
    Range = 3.0,                -- Max distance to tackle
    StunDuration = 3000,        -- How long target is stunned (ragdoll)
    MinSpeed = 3.0,             -- Minimum speed to tackle (must be sprinting)
    Animation = {
        dict = 'swimming@scuba',
        anim = 'dive_idle',
        flag = 0
    }
}

-- ============================================================================
-- K9 UNIT CONFIGURATION
-- ============================================================================
Config.K9 = {
    Model = 'a_c_shepherd',      -- German Shepherd
    SearchRadius = 30.0,         -- meters
    SearchDuration = 8000,       -- ms
    MinGrade = 3,                -- Officer III+ can use K9

    -- K9-enabled vehicles (SUVs only - easy to update when changing police pack)
    Vehicles = {
        ['polsilverado19'] = true,  -- Police Silverado
        ['poldurango'] = true,      -- Police Durango
        ['sw_subrb'] = true,        -- SWAT Suburban
        ['sw_durango'] = true,      -- SWAT Durango
        -- Add more K9 vehicles here when changing police pack
    },

    -- Items K9 can detect (drugs only)
    IllegalItems = {
        -- Weed
        ['weed_bag'] = true,
        ['weed_brick'] = true,
        ['joint'] = true,
        -- Cocaine
        ['cocaine_bag'] = true,
        ['cocaine_brick'] = true,
        ['coke_brick'] = true,
        -- Meth
        ['meth_bag'] = true,
        ['meth_brick'] = true,
        -- Other drugs
        ['heroin'] = true,
        ['ecstasy'] = true,
        ['oxy'] = true,
        ['crack_baggy'] = true,
        -- Add more drug items as needed
    },

    SpawnDoorIndex = 5,  -- Vehicle door to open when spawning (5 = trunk)
}

-- ============================================================================
-- ALPR CONFIGURATION (Automatic License Plate Reader)
-- ============================================================================
Config.ALPR = {
    Enabled = true,
    Key = '',                  -- Toggle ALPR on/off (use /alpr command)
    LockKey = 'F9',            -- Lock/unlock current plate
    ScanDistance = 50.0,       -- How far to scan (meters)
    ScanInterval = 100,        -- ms between scans

    -- Police vehicles that have ALPR installed
    Vehicles = {
        ['polsilverado19'] = true,
        ['poldurango'] = true,
        ['buffalosxpolun'] = true,
        ['polmustang'] = true,
        ['polbmwm3'] = true,
        ['polbmwm5'] = true,
        ['polbmwm7'] = true,
        ['polgt63'] = true,
        ['polrs6'] = true,
        ['sw_charg'] = true,
        ['sw_durango'] = true,
        ['sw_subrb'] = true,
        ['unmarkedjl'] = true,
    },
}

-- ============================================================================
-- RADAR GUN CONFIGURATION
-- ============================================================================
Config.Radar = {
    Enabled = true,
    Item = 'radar_gun',          -- Item name required in inventory
    ScanDistance = 200.0,        -- Max range in meters (~656 feet)
    ScanInterval = 100,          -- ms between scans
    SpeedUnit = 'mph',           -- 'mph' or 'kmh'
    MinSpeed = 5,                -- Minimum speed to register (filters parked cars)

    -- Custom weapon defined via meta files in [standalone]/LidarGun (NonViolent — NPCs don't react)
    WeaponHash = `WEAPON_PROLASER4`,

    -- Conversion factors
    MPS_TO_MPH = 2.236936,
    MPS_TO_KMH = 3.6,
}

-- ============================================================================
-- GSR (GUNSHOT RESIDUE) TEST CONFIGURATION
-- ============================================================================
Config.GSR = {
    TestDuration = 5000,        -- ms progress bar
    PositiveWindow = 600,       -- seconds (10 minutes) - how long GSR stays positive after firing
}

-- ============================================================================
-- BREATHALYZER CONFIGURATION
-- ============================================================================
Config.Breathalyzer = {
    TestDuration = 3000,        -- ms progress bar
}

-- ============================================================================
-- VEHICLE SEARCH CONFIGURATION
-- ============================================================================
Config.VehicleSearch = {
    SearchDuration = 8000,      -- ms progress bar (thorough search)
}

-- Scene Props Configuration (expanded)
Config.Props = {
    MaxPerOfficer = 10,         -- Max props an officer can place
    RemoveDistance = 5.0,       -- Max distance to remove a prop

    -- Prop definitions
    Items = {
        cone = {
            model = 'prop_mp_cone_02',
            label = 'Traffic Cone',
            placeAnim = { dict = 'anim@mp_snowball', anim = 'pickup_snowball', duration = 1000 }
        },
        cone_lighted = {
            model = 'prop_air_conelight',
            label = 'Lighted Cone',
            placeAnim = { dict = 'anim@mp_snowball', anim = 'pickup_snowball', duration = 1000 }
        },
        barrier = {
            model = 'prop_barrier_work05',
            label = 'Road Barrier',
            placeAnim = { dict = 'anim@mp_snowball', anim = 'pickup_snowball', duration = 1500 }
        },
        barrier_arrow = {
            model = 'prop_mp_arrow_barrier_01',
            label = 'Arrow Barrier',
            placeAnim = { dict = 'anim@mp_snowball', anim = 'pickup_snowball', duration = 1500 }
        },
        flare = {
            model = 'prop_flare_01',
            label = 'Road Flare',
            placeAnim = { dict = 'anim@mp_snowball', anim = 'pickup_snowball', duration = 800 },
            particle = { dict = 'core', name = 'ent_ray_flare', duration = 300000 }  -- 5 min flare
        },
        spike = {
            model = 'p_ld_stinger_s',
            label = 'Spike Strip',
            placeAnim = { dict = 'anim@mp_snowball', anim = 'pickup_snowball', duration = 2000 },
            isSpikeStrip = true
        }
    }
}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================
Config.General = {
    -- Interaction distances
    InteractionDistance = 2.5,      -- Default interaction distance
    MarkerDrawDistance = 10.0,      -- Distance to draw markers
    BlipDrawDistance = 500.0,       -- Distance for blip visibility

    -- Debug mode (shows extra prints)
    Debug = false,

    -- Require duty for actions
    RequireDutyForMDT = false,      -- Must be on duty to open MDT
    RequireDutyForArmory = true,    -- Must be on duty to access armory
    RequireDutyForGarage = true,    -- Must be on duty to spawn vehicles
    RequireDutyForLocker = false,   -- Must be on duty to access locker

    -- Auto features
    AutoClockOutOnDisconnect = true,
    AutoRemovePropsOnOffDuty = true,

    -- Notifications
    NotifyOnDutyChange = true,
    NotifyOnGradeRestriction = true,

    -- Garage grade mode: 'exact' = only vehicles matching your grade, 'cumulative' = your grade and below
    GarageGradeMode = 'exact',
}

-- ============================================================================
-- HELPER FUNCTION: Get station by ID
-- ============================================================================
function Config.GetStation(stationId)
    return Config.Stations[stationId]
end

-- ============================================================================
-- HELPER FUNCTION: Get rank info by grade
-- ============================================================================
function Config.GetRankByGrade(grade)
    for _, rank in ipairs(Config.Ranks) do
        if rank.grade == grade then
            return rank
        end
    end
    return nil
end

-- ============================================================================
-- HELPER FUNCTION: Check if grade meets minimum requirement
-- ============================================================================
function Config.MeetsGradeRequirement(playerGrade, requiredGrade)
    return playerGrade >= requiredGrade
end

function Config.MeetsGarageGradeRequirement(playerGrade, vehicleGrade)
    if Config.General.GarageGradeMode == 'exact' then
        return playerGrade == vehicleGrade
    end
    return playerGrade >= vehicleGrade
end

-- ============================================================================
-- HELPER FUNCTION: Get vehicles available for grade
-- ============================================================================
function Config.GetVehiclesForGrade(grade)
    local available = {}
    for _, vehicle in ipairs(Config.Vehicles) do
        if Config.General.GarageGradeMode == 'exact' then
            if grade == vehicle.grade then
                table.insert(available, vehicle)
            end
        else
            if grade >= vehicle.grade then
                table.insert(available, vehicle)
            end
        end
    end
    return available
end

-- ============================================================================
-- HELPER FUNCTION: Get weapons available for grade
-- ============================================================================
function Config.GetWeaponsForGrade(grade)
    local available = {}
    for _, weapon in ipairs(Config.Armory.weapons) do
        if grade >= weapon.grade then
            table.insert(available, weapon)
        end
    end
    return available
end
