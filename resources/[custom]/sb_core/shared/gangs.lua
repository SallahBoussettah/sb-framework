--[[
    Everyday Chaos RP - Gang Definitions
    Author: Salah Eddine Boussettah

    Gang Structure:
    {
        label = 'Gang Name',
        grades = {
            ['0'] = { name = 'grade_name' },
            ['1'] = { name = 'grade_name', isboss = true }
        }
    }
]]

SBShared.Gangs = {
    -- ========================================================================
    -- NO GANG (Default)
    -- ========================================================================
    ['none'] = {
        label = 'No Gang',
        grades = {
            ['0'] = { name = 'Unaffiliated' }
        }
    },

    -- ========================================================================
    -- STREET GANGS
    -- ========================================================================
    ['ballas'] = {
        label = 'Ballas',
        grades = {
            ['0'] = { name = 'Recruit' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Enforcer' },
            ['3'] = { name = 'Shot Caller' },
            ['4'] = { name = 'OG', isboss = true }
        }
    },
    ['families'] = {
        label = 'The Families',
        grades = {
            ['0'] = { name = 'Recruit' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Enforcer' },
            ['3'] = { name = 'Shot Caller' },
            ['4'] = { name = 'OG', isboss = true }
        }
    },
    ['vagos'] = {
        label = 'Los Santos Vagos',
        grades = {
            ['0'] = { name = 'Recruit' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Enforcer' },
            ['3'] = { name = 'Lieutenant' },
            ['4'] = { name = 'El Jefe', isboss = true }
        }
    },
    ['marabunta'] = {
        label = 'Marabunta Grande',
        grades = {
            ['0'] = { name = 'Recruit' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Enforcer' },
            ['3'] = { name = 'Lieutenant' },
            ['4'] = { name = 'El Jefe', isboss = true }
        }
    },

    -- ========================================================================
    -- ORGANIZATIONS
    -- ========================================================================
    ['lostmc'] = {
        label = 'The Lost MC',
        grades = {
            ['0'] = { name = 'Prospect' },
            ['1'] = { name = 'Member' },
            ['2'] = { name = 'Road Captain' },
            ['3'] = { name = 'Vice President' },
            ['4'] = { name = 'President', isboss = true }
        }
    },
    ['triads'] = {
        label = 'Triads',
        grades = {
            ['0'] = { name = 'Blue Lantern' },
            ['1'] = { name = '49er' },
            ['2'] = { name = 'Red Pole' },
            ['3'] = { name = 'Incense Master' },
            ['4'] = { name = 'Dragon Head', isboss = true }
        }
    },
    ['cartel'] = {
        label = 'Madrazo Cartel',
        grades = {
            ['0'] = { name = 'Halcon' },
            ['1'] = { name = 'Sicario' },
            ['2'] = { name = 'Lieutenant' },
            ['3'] = { name = 'Underboss' },
            ['4'] = { name = 'El Patron', isboss = true }
        }
    },
}
