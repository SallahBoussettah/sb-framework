-- Default Penal Code Entries
-- These are loaded into the database on first run if empty

PenalCode = {
    -- Traffic Violations
    {
        category = 'Traffic',
        title = 'Speeding',
        description = 'Exceeding the posted speed limit',
        fine = 250,
        jail_time = 0
    },
    {
        category = 'Traffic',
        title = 'Reckless Driving',
        description = 'Operating a vehicle with willful disregard for safety',
        fine = 500,
        jail_time = 5
    },
    {
        category = 'Traffic',
        title = 'Running a Red Light',
        description = 'Failure to stop at a red traffic signal',
        fine = 350,
        jail_time = 0
    },
    {
        category = 'Traffic',
        title = 'Driving Without License',
        description = 'Operating a vehicle without a valid license',
        fine = 750,
        jail_time = 10
    },
    {
        category = 'Traffic',
        title = 'Evading Police',
        description = 'Fleeing from law enforcement in a vehicle',
        fine = 2500,
        jail_time = 20
    },
    {
        category = 'Traffic',
        title = 'DUI',
        description = 'Driving under the influence of alcohol or drugs',
        fine = 1500,
        jail_time = 15
    },
    {
        category = 'Traffic',
        title = 'Hit and Run',
        description = 'Leaving the scene of an accident',
        fine = 2000,
        jail_time = 15
    },

    -- Misdemeanors
    {
        category = 'Misdemeanor',
        title = 'Disorderly Conduct',
        description = 'Engaging in disruptive behavior in public',
        fine = 500,
        jail_time = 5
    },
    {
        category = 'Misdemeanor',
        title = 'Trespassing',
        description = 'Entering private property without permission',
        fine = 750,
        jail_time = 10
    },
    {
        category = 'Misdemeanor',
        title = 'Petty Theft',
        description = 'Theft of property valued under $500',
        fine = 500,
        jail_time = 10
    },
    {
        category = 'Misdemeanor',
        title = 'Vandalism',
        description = 'Intentional destruction of property',
        fine = 1000,
        jail_time = 10
    },
    {
        category = 'Misdemeanor',
        title = 'Resisting Arrest',
        description = 'Actively resisting lawful arrest',
        fine = 1500,
        jail_time = 15
    },
    {
        category = 'Misdemeanor',
        title = 'Obstruction of Justice',
        description = 'Interfering with police investigation',
        fine = 1000,
        jail_time = 10
    },
    {
        category = 'Misdemeanor',
        title = 'Public Intoxication',
        description = 'Being visibly intoxicated in public',
        fine = 300,
        jail_time = 5
    },

    -- Felonies
    {
        category = 'Felony',
        title = 'Grand Theft',
        description = 'Theft of property valued over $500',
        fine = 3000,
        jail_time = 25
    },
    {
        category = 'Felony',
        title = 'Grand Theft Auto',
        description = 'Theft of a motor vehicle',
        fine = 5000,
        jail_time = 30
    },
    {
        category = 'Felony',
        title = 'Armed Robbery',
        description = 'Robbery committed with a weapon',
        fine = 7500,
        jail_time = 45
    },
    {
        category = 'Felony',
        title = 'Assault',
        description = 'Causing physical harm to another person',
        fine = 2500,
        jail_time = 20
    },
    {
        category = 'Felony',
        title = 'Assault with Deadly Weapon',
        description = 'Assault committed with a weapon',
        fine = 5000,
        jail_time = 35
    },
    {
        category = 'Felony',
        title = 'Assault on LEO',
        description = 'Assault on a law enforcement officer',
        fine = 7500,
        jail_time = 45
    },
    {
        category = 'Felony',
        title = 'Attempted Murder',
        description = 'Attempt to unlawfully kill another person',
        fine = 15000,
        jail_time = 60
    },
    {
        category = 'Felony',
        title = 'Murder',
        description = 'Unlawful killing of another person',
        fine = 25000,
        jail_time = 120
    },
    {
        category = 'Felony',
        title = 'Kidnapping',
        description = 'Unlawful restraint and transport of a person',
        fine = 10000,
        jail_time = 50
    },

    -- Weapons
    {
        category = 'Weapons',
        title = 'Illegal Firearm Possession',
        description = 'Possessing a firearm without license',
        fine = 3500,
        jail_time = 25
    },
    {
        category = 'Weapons',
        title = 'Illegal Weapon Discharge',
        description = 'Discharging a firearm in public',
        fine = 2500,
        jail_time = 20
    },
    {
        category = 'Weapons',
        title = 'Brandishing a Weapon',
        description = 'Displaying a weapon in a threatening manner',
        fine = 1500,
        jail_time = 15
    },
    {
        category = 'Weapons',
        title = 'Concealed Weapon (No Permit)',
        description = 'Carrying a concealed weapon without permit',
        fine = 2000,
        jail_time = 15
    },

    -- Drugs
    {
        category = 'Drugs',
        title = 'Drug Possession',
        description = 'Possession of controlled substances',
        fine = 2000,
        jail_time = 15
    },
    {
        category = 'Drugs',
        title = 'Drug Possession (Intent to Sell)',
        description = 'Possession with intent to distribute',
        fine = 7500,
        jail_time = 40
    },
    {
        category = 'Drugs',
        title = 'Drug Trafficking',
        description = 'Large-scale distribution of controlled substances',
        fine = 15000,
        jail_time = 60
    },
    {
        category = 'Drugs',
        title = 'Drug Manufacturing',
        description = 'Production of controlled substances',
        fine = 20000,
        jail_time = 75
    },

    -- Financial Crimes
    {
        category = 'Financial',
        title = 'Fraud',
        description = 'Deception for financial gain',
        fine = 5000,
        jail_time = 25
    },
    {
        category = 'Financial',
        title = 'Money Laundering',
        description = 'Concealing the origins of illegally obtained money',
        fine = 15000,
        jail_time = 50
    },
    {
        category = 'Financial',
        title = 'Bank Robbery',
        description = 'Robbery of a financial institution',
        fine = 25000,
        jail_time = 90
    },

    -- Government
    {
        category = 'Government',
        title = 'Bribery',
        description = 'Offering money to influence official action',
        fine = 10000,
        jail_time = 30
    },
    {
        category = 'Government',
        title = 'Impersonating LEO',
        description = 'Pretending to be a law enforcement officer',
        fine = 5000,
        jail_time = 30
    },
    {
        category = 'Government',
        title = 'Tampering with Evidence',
        description = 'Altering or destroying evidence',
        fine = 7500,
        jail_time = 35
    },
    {
        category = 'Government',
        title = 'Perjury',
        description = 'Lying under oath',
        fine = 5000,
        jail_time = 25
    },
}
