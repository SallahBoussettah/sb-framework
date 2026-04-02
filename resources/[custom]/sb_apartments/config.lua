Config = {}

-- ============================================
-- GENERAL SETTINGS
-- ============================================
Config.RentCycle = 7 * 24 * 60 * 60 * 1000  -- 7 days in ms (real time)
Config.DepositMultiplier = 2                 -- 2x rent as deposit
Config.MaxMissedPayments = 2                 -- Eviction after 2 missed payments
Config.MaxKeysPerUnit = 3                    -- Max people with keys
Config.InteractDistance = 2.0                -- Distance for door interaction
Config.MaxRentals = 2                        -- Max apartments per player
Config.RentCheckInterval = 300000            -- 5 minutes (ms) between rent checks
Config.GracePeriod = 2 * 24 * 60 * 60       -- 2 days grace period (seconds)
Config.PaymentReminder = 1 * 24 * 60 * 60   -- Notify 1 day before rent due (seconds)
Config.DoorbellTimeout = 15                  -- Seconds to answer doorbell

-- Deposit refund tiers based on missed payments
Config.DepositRefund = {
    [0] = 1.0,   -- 100% refund
    [1] = 0.5,   -- 50% refund
}
-- 2+ missed = 0% refund (default)

-- Stash settings per tier
Config.StashSlots = {
    budget = 30,
    standard = 50,
    premium = 75,
    luxury = 100
}

-- ============================================
-- BLIP SETTINGS
-- ============================================
Config.Blips = {
    building = { sprite = 475, color = 0, scale = 0.7, label = 'Apartment Building' },   -- White
    myApartment = { sprite = 40, color = 3, scale = 0.9 },                               -- Blue house
    keyAccess = { sprite = 40, color = 5, scale = 0.7 },                                 -- Yellow house
    garage = { sprite = 357, color = 0, scale = 0.7 },                                   -- Garage
}

-- ============================================
-- APARTMENT BUILDINGS
-- ============================================
Config.Buildings = {
    -- ==========================================
    -- DEL PERRO APARTMENTS (2 rooms, elevator access)
    -- ==========================================
    ['del_perro'] = {
        name = 'Del Perro Projects',
        description = 'Urban apartments with elevator access',
        tier = 'budget',
        useShells = false,

        blip = vector3(-1564.84, -405.90, 42.39),
        entrance = {
            coords = vector3(-1564.8424, -405.9015, 42.3881),
            heading = 226.73
        },

        -- Elevator (ground floor to room floor)
        hasElevator = true,
        elevator = {
            floors = {
                [1] = {
                    label = 'Ground Floor',
                    coords = vector3(-1572.0822, -409.3045, 42.3902),
                    heading = 331.06,
                    exit = vector3(-1571.6362, -408.9172, 42.3901),
                    exitHeading = 323.27
                },
                [2] = {
                    label = 'Floor 2',
                    coords = vector3(-1572.3483, -409.4543, 49.0557),
                    heading = 318.92,
                    exit = vector3(-1570.9958, -407.9524, 48.0559),
                    exitHeading = 322.80
                }
            },
            interactRadius = 1.5,
            travelTime = 2000
        },

        -- Garage (tenants only, 4 vehicle slots)
        hasGarage = true,
        garage = {
            npcPos = vector3(-1567.80, -398.08, 41.99),
            npcHeading = 295.81,
            npcModel = 's_m_y_valet_01',
            blipPos = vector3(-1563.36, -394.54, 41.99),
            maxVehicles = 4,
            spawnPoints = {
                { coords = vector3(-1559.89, -391.02, 41.27), heading = 139.36 },
                { coords = vector3(-1563.44, -388.08, 41.27), heading = 138.84 },
                { coords = vector3(-1556.19, -393.30, 41.27), heading = 141.31 },
                { coords = vector3(-1570.20, -388.28, 41.27), heading = 228.07 },
            },
            storeZone = {
                coords = vector3(-1563.36, -394.54, 41.99),
                radius = 8.0
            }
        },

        -- Units (both on floor 2, reached via elevator)
        units = {
            ['dp_101'] = {
                label = 'Unit 101', floor = 2, rent = 800,
                door = vector3(-1567.08, -400.64, 48.05), doorHeading = 140.0,
                doorModel = 0xDEEFCECE,
                stashPos = vector3(-1560.10, -400.91, 48.05),
                wardrobePos = vector3(-1560.92, -404.54, 49.18),
            },
            ['dp_102'] = {
                label = 'Unit 102', floor = 2, rent = 800,
                door = vector3(-1559.23, -391.29, 48.06), doorHeading = 140.0,
                doorModel = 0xDEEFCECE,
                stashPos = vector3(-1556.81, -397.36, 48.05),
                wardrobePos = vector3(-1553.51, -395.90, 49.23),
            },
        }
    },

    -- ==========================================
    -- PINK CAGE MOTEL (TODO - needs F7 data)
    -- ==========================================
    ['pinkcage_motel'] = {
        name = 'Pink Cage Motel',
        description = 'Budget motel rooms - weekly rentals available',
        tier = 'budget',
        useShells = false,

        blip = vector3(313.38, -225.20, 54.21),
        entrance = {
            coords = vector3(313.38, -225.20, 54.21),
            heading = 340.0
        },

        hasElevator = false,
        hasGarage = false,

        -- TODO: Add rooms after collecting F7 inspector data in-game
        units = {}
    },

    -- ==========================================
    -- THE EMISSARY HOTEL (20 rooms, floors 3-6)
    -- Floor 2 = restaurant (elevator skips it)
    -- Each floor has same 5 room positions, Z + 8.5396 per floor
    -- ==========================================
    ['the_emissary'] = {
        name = 'The Emissary Hotel',
        description = 'Downtown hotel with restaurant and city views - floors 3-6',
        tier = 'standard',
        useShells = false,

        blip = vector3(65.89, -964.62, 29.36),
        entrance = {
            coords = vector3(65.89, -964.62, 29.36),
            heading = 250.0
        },

        -- Rental NPC (lobby concierge)
        rentalNPC = {
            pos = vector3(66.90, -947.94, 29.81),
            heading = 147.25,
            model = 'a_f_y_business_04',
        },

        -- Elevator: Lobby -> Floor 3-6 (Floor 2 is restaurant, no stop)
        hasElevator = true,
        elevator = {
            floors = {
                [1] = { label = 'Lobby',   coords = vector3(60.93, -945.21, 29.81), heading = 250.0, exit = vector3(62.0, -946.0, 29.81), exitHeading = 250.0 },
                [3] = { label = 'Floor 3', coords = vector3(60.93, -945.21, 46.88), heading = 250.0, exit = vector3(62.0, -946.0, 46.88), exitHeading = 250.0 },
                [4] = { label = 'Floor 4', coords = vector3(60.93, -945.21, 55.42), heading = 250.0, exit = vector3(62.0, -946.0, 55.42), exitHeading = 250.0 },
                [5] = { label = 'Floor 5', coords = vector3(60.93, -945.21, 63.96), heading = 250.0, exit = vector3(62.0, -946.0, 63.96), exitHeading = 250.0 },
                [6] = { label = 'Floor 6', coords = vector3(60.93, -945.21, 72.51), heading = 250.0, exit = vector3(62.0, -946.0, 72.51), exitHeading = 250.0 },
            },
            interactRadius = 1.5,
            travelTime = 2500
        },

        hasGarage = false,

        -- 5 rooms per floor, 4 room floors (3-6) = 20 rooms
        -- Base positions from F7 inspector (floor 3), upper floors = Z + 8.5396 per floor
        units = {
            -- ========== Floor 3 (base Z from F7 inspector) ==========
            ['em_301'] = {
                label = 'Room 301', floor = 3, rent = 1200,
                door = vector3(63.31, -955.01, 47.00), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(67.33, -957.80, 46.89),
                wardrobePos = vector3(61.80, -959.12, 46.89),
            },
            ['em_302'] = {
                label = 'Room 302', floor = 3, rent = 1200,
                door = vector3(75.79, -959.55, 47.05), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.22, -959.17, 46.89),
                wardrobePos = vector3(73.63, -963.27, 46.89),
            },
            ['em_303'] = {
                label = 'Room 303', floor = 3, rent = 1200,
                door = vector3(77.59, -958.38, 46.94), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(80.70, -954.30, 46.89),
                wardrobePos = vector3(81.74, -959.76, 46.89),
            },
            ['em_304'] = {
                label = 'Room 304', floor = 3, rent = 1200,
                door = vector3(76.29, -956.45, 47.00), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(72.97, -951.55, 46.89),
                wardrobePos = vector3(78.40, -950.59, 46.89),
            },
            ['em_305'] = {
                label = 'Room 305', floor = 3, rent = 1200,
                door = vector3(63.43, -951.77, 47.00), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.14, -950.45, 46.89),
                wardrobePos = vector3(66.44, -946.07, 46.89),
            },

            -- ========== Floor 4 (Z + 8.5396) ==========
            ['em_401'] = {
                label = 'Room 401', floor = 4, rent = 1400,
                door = vector3(63.31, -955.01, 55.54), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(67.33, -957.80, 55.43),
                wardrobePos = vector3(61.80, -959.12, 55.43),
            },
            ['em_402'] = {
                label = 'Room 402', floor = 4, rent = 1400,
                door = vector3(75.79, -959.55, 55.55), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.22, -959.17, 55.43),
                wardrobePos = vector3(73.63, -963.27, 55.43),
            },
            ['em_403'] = {
                label = 'Room 403', floor = 4, rent = 1400,
                door = vector3(77.59, -958.38, 55.48), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(80.70, -954.30, 55.43),
                wardrobePos = vector3(81.74, -959.76, 55.43),
            },
            ['em_404'] = {
                label = 'Room 404', floor = 4, rent = 1400,
                door = vector3(76.29, -956.45, 55.54), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(72.97, -951.55, 55.43),
                wardrobePos = vector3(78.40, -950.59, 55.43),
            },
            ['em_405'] = {
                label = 'Room 405', floor = 4, rent = 1400,
                door = vector3(63.43, -951.77, 55.54), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.14, -950.45, 55.43),
                wardrobePos = vector3(66.44, -946.07, 55.43),
            },

            -- ========== Floor 5 (Z + 17.0792) ==========
            ['em_501'] = {
                label = 'Room 501', floor = 5, rent = 1600,
                door = vector3(63.31, -955.01, 64.08), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(67.33, -957.80, 63.97),
                wardrobePos = vector3(61.80, -959.12, 63.97),
            },
            ['em_502'] = {
                label = 'Room 502', floor = 5, rent = 1600,
                door = vector3(75.79, -959.55, 64.05), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.22, -959.17, 63.97),
                wardrobePos = vector3(73.63, -963.27, 63.97),
            },
            ['em_503'] = {
                label = 'Room 503', floor = 5, rent = 1600,
                door = vector3(77.59, -958.38, 64.02), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(80.70, -954.30, 63.97),
                wardrobePos = vector3(81.74, -959.76, 63.97),
            },
            ['em_504'] = {
                label = 'Room 504', floor = 5, rent = 1600,
                door = vector3(76.29, -956.45, 64.08), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(72.97, -951.55, 63.97),
                wardrobePos = vector3(78.40, -950.59, 63.97),
            },
            ['em_505'] = {
                label = 'Room 505', floor = 5, rent = 1600,
                door = vector3(63.43, -951.77, 64.08), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.14, -950.45, 63.97),
                wardrobePos = vector3(66.44, -946.07, 63.97),
            },

            -- ========== Floor 6 (Z + 25.6188) ==========
            ['em_601'] = {
                label = 'Room 601', floor = 6, rent = 1800,
                door = vector3(63.31, -955.01, 72.62), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(67.33, -957.80, 72.51),
                wardrobePos = vector3(61.80, -959.12, 72.51),
            },
            ['em_602'] = {
                label = 'Room 602', floor = 6, rent = 1800,
                door = vector3(75.79, -959.55, 72.55), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.22, -959.17, 72.51),
                wardrobePos = vector3(73.63, -963.27, 72.51),
            },
            ['em_603'] = {
                label = 'Room 603', floor = 6, rent = 1800,
                door = vector3(77.59, -958.38, 72.56), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(80.70, -954.30, 72.51),
                wardrobePos = vector3(81.74, -959.76, 72.51),
            },
            ['em_604'] = {
                label = 'Room 604', floor = 6, rent = 1800,
                door = vector3(76.29, -956.45, 72.62), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(72.97, -951.55, 72.51),
                wardrobePos = vector3(78.40, -950.59, 72.51),
            },
            ['em_605'] = {
                label = 'Room 605', floor = 6, rent = 1800,
                door = vector3(63.43, -951.77, 72.62), doorHeading = 0.0,
                doorModel = 0x0B9AE8D5,
                stashPos = vector3(70.14, -950.45, 72.51),
                wardrobePos = vector3(66.44, -946.07, 72.51),
            },
        }
    }
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

function Config.GetBuildingByUnit(unitId)
    for buildingId, building in pairs(Config.Buildings) do
        if building.units[unitId] then
            return buildingId, building
        end
    end
    return nil, nil
end

function Config.GetUnit(buildingId, unitId)
    local building = Config.Buildings[buildingId]
    if building and building.units[unitId] then
        return building.units[unitId]
    end
    return nil
end

function Config.GetStashSlots(tier)
    return Config.StashSlots[tier] or Config.StashSlots.standard
end
