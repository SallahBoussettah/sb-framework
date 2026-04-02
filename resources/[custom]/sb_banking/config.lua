Config = {}

-- Account creation bonus
Config.StartingBonus = 2000

-- Card request fee (from settings)
Config.CardRequestFee = 100

-- Card replacement fee (legacy)
Config.CardReplaceFee = 100

-- PIN system
Config.MaxPinAttempts = 3          -- Lockout after X wrong PINs
Config.PinLength = 4               -- 4-digit PIN

-- Withdraw limits
Config.QuickWithdrawAmounts = {100, 500, 1000, 2000, 5000}
Config.MaxWithdraw = 50000         -- Max single withdrawal
Config.MaxDeposit = 100000         -- Max single deposit

-- Savings limits
Config.MaxSavingsDeposit = 500000
Config.MaxSavingsWithdraw = 500000

-- Savings interest
Config.SavingsInterestRate = 0.025     -- 2.5% annual interest
Config.InterestPayoutInterval = 60     -- Pay interest every 60 minutes (real time)

-- Cooldown between operations (ms)
Config.Cooldown = 1000

-- Transfer settings
Config.TransferFee = 0             -- % fee on transfers (0 = free)
Config.MinTransfer = 1
Config.MaxTransfer = 1000000

-- Bank NPC settings
Config.BankNPCModel = 'a_f_y_business_01'

-- Bank locations (NPC positions)
Config.BankLocations = {
    {
        coords = vector4(149.4810, -1042.1470, 29.3680, 340.0),
        label = "Fleeca Bank",
    },
    {
        coords = vector4(313.7534, -280.5081, 54.1570, 342.0518),
        label = "Fleeca Bank",
    },
    {
        coords = vector4(-351.5417, -51.2782, 49.0365, 332.6970),
        label = "Fleeca Bank",
    },
    {
        coords = vector4(-1212.0369, -332.0890, 37.7809, 25.7773),
        label = "Fleeca Bank",
    },
    {
        coords = vector4(-111.1482, 6470.0356, 31.6267, 135.2996),
        label = "Blaine County Savings",
    },
    {
        coords = vector4(-634.4620, -236.1314, 37.9939, 127.5071),
        label = "For Robbery",
    },
    {
        coords = vector4(247.1127, 225.0742, 106.2875, 161.9122),
        label = "Pacific Standard Bank",
        deleteProps = {
            { model = 0x2326B354, coords = vector3(248.87, 224.85, 106.36), radius = 2.0 },
        },
    },
}

-- ATM props (existing GTA V models)
Config.ATMModels = {
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03',
    'prop_fleeca_atm',
}

-- ATM interaction distance
Config.ATMDistance = 1.5

-- Bank NPC interaction distance
Config.BankDistance = 2.0
