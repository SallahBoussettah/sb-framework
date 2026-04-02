--[[
    Everyday Chaos RP - Job Definitions
    Author: Salah Eddine Boussettah

    Job Structure:
    {
        label = 'Job Name',
        type = 'job_type',       -- 'leo', 'ems', 'mechanic', 'civ', etc.
        defaultDuty = true,      -- Start on duty
        offDutyPay = false,      -- Pay while off duty
        grades = {
            ['0'] = { name = 'grade_name', payment = 50 },
            ['1'] = { name = 'grade_name', payment = 75, isboss = true }
        }
    }
]]

SBShared.Jobs = {
    -- ========================================================================
    -- UNEMPLOYED (Default)
    -- ========================================================================
    ['unemployed'] = {
        label = 'Unemployed',
        type = 'civ',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Freelancer', payment = 0 }
        }
    },

    -- ========================================================================
    -- LAW ENFORCEMENT
    -- ========================================================================
    ['police'] = {
        label = 'Los Santos Police Department',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Cadet', payment = 250 },
            ['1'] = { name = 'Officer', payment = 350 },
            ['2'] = { name = 'Senior Officer', payment = 400 },
            ['3'] = { name = 'Corporal', payment = 450 },
            ['4'] = { name = 'Sergeant', payment = 500 },
            ['5'] = { name = 'Lieutenant', payment = 600 },
            ['6'] = { name = 'Captain', payment = 700 },
            ['7'] = { name = 'Commander', payment = 800 },
            ['8'] = { name = 'Assistant Chief', payment = 900 },
            ['9'] = { name = 'Chief of Police', payment = 1000, isboss = true }
        }
    },
    ['sheriff'] = {
        label = 'Blaine County Sheriff',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee', payment = 250 },
            ['1'] = { name = 'Deputy', payment = 350 },
            ['2'] = { name = 'Senior Deputy', payment = 400 },
            ['3'] = { name = 'Corporal', payment = 450 },
            ['4'] = { name = 'Sergeant', payment = 500 },
            ['5'] = { name = 'Lieutenant', payment = 600 },
            ['6'] = { name = 'Captain', payment = 700 },
            ['7'] = { name = 'Undersheriff', payment = 850 },
            ['8'] = { name = 'Sheriff', payment = 1000, isboss = true }
        }
    },

    -- ========================================================================
    -- EMERGENCY MEDICAL SERVICES
    -- ========================================================================
    ['ambulance'] = {
        label = 'Emergency Medical Services',
        type = 'ems',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee', payment = 200 },
            ['1'] = { name = 'EMT', payment = 300 },
            ['2'] = { name = 'Paramedic', payment = 400 },
            ['3'] = { name = 'Senior Paramedic', payment = 500 },
            ['4'] = { name = 'Doctor', payment = 600 },
            ['5'] = { name = 'Surgeon', payment = 750 },
            ['6'] = { name = 'Chief of Medicine', payment = 900, isboss = true }
        }
    },

    -- ========================================================================
    -- MECHANICS
    -- ========================================================================
    ['mechanic'] = {
        label = 'Los Santos Customs',
        type = 'mechanic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee', payment = 150 },
            ['1'] = { name = 'Mechanic', payment = 250 },
            ['2'] = { name = 'Senior Mechanic', payment = 350 },
            ['3'] = { name = 'Lead Mechanic', payment = 450 },
            ['4'] = { name = 'Manager', payment = 550, isboss = true }
        }
    },
    ['bn-mechanic'] = {
        label = "Benny's Original Motorworks",
        type = 'mechanic',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 150 },
            ['1'] = { name = 'Mechanic', payment = 250 },
            ['2'] = { name = 'Senior Mechanic', payment = 350 },
            ['3'] = { name = 'Lead Mechanic', payment = 450 },
            ['4'] = { name = 'Shop Manager', payment = 600, isboss = true }
        }
    },

    -- ========================================================================
    -- CIVILIAN JOBS
    -- ========================================================================
    ['taxi'] = {
        label = 'Downtown Cab Co.',
        type = 'civ',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Driver', payment = 100 },
            ['1'] = { name = 'Senior Driver', payment = 150 },
            ['2'] = { name = 'Supervisor', payment = 200 },
            ['3'] = { name = 'Manager', payment = 300, isboss = true }
        }
    },
    ['trucker'] = {
        label = 'Trucking Co.',
        type = 'civ',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Driver', payment = 100 },
            ['1'] = { name = 'Experienced Driver', payment = 150 },
            ['2'] = { name = 'Senior Driver', payment = 200 },
            ['3'] = { name = 'Logistics Manager', payment = 300, isboss = true }
        }
    },
    ['realestate'] = {
        label = 'Dynasty 8 Real Estate',
        type = 'civ',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee', payment = 150 },
            ['1'] = { name = 'Agent', payment = 300 },
            ['2'] = { name = 'Senior Agent', payment = 450 },
            ['3'] = { name = 'Broker', payment = 600, isboss = true }
        }
    },
    ['cardealer'] = {
        label = 'Premium Deluxe Motorsport',
        type = 'civ',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee', payment = 150 },
            ['1'] = { name = 'Salesperson', payment = 250 },
            ['2'] = { name = 'Senior Salesperson', payment = 400 },
            ['3'] = { name = 'Sales Manager', payment = 550, isboss = true }
        }
    },

    -- ========================================================================
    -- FOOD SERVICE
    -- ========================================================================
    ['burgershot'] = {
        label = 'Burger Shot',
        type = 'civ',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee', payment = 30 },
            ['1'] = { name = 'Worker', payment = 50 },
            ['2'] = { name = 'Shift Manager', payment = 75 },
            ['3'] = { name = 'Manager', payment = 100, isboss = true }
        }
    },
}
