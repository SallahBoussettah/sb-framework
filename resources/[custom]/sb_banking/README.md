# sb_banking

Full-featured banking system with bank NPCs, ATM support, savings accounts, PIN security, and transaction history.

## Features

- Bank account creation with configurable starting bonus
- Deposits, withdrawals, and player-to-player transfers
- ATM system using existing GTA V ATM props (requires bank card)
- 4-digit PIN security with lockout after failed attempts
- Savings account with configurable interest rate and automatic payouts
- Bank card request, replacement, and unlock
- Full transaction history (last 50 transactions)
- NUI interface for both bank teller and ATM interactions
- Map blips for all bank locations
- NPC tellers spawned at each bank location

## Dependencies

- sb_core
- sb_inventory
- sb_target
- sb_notify
- oxmysql

## Installation

1. Place `sb_banking` in your resources folder.
2. Add `ensure sb_banking` to your server.cfg (after its dependencies).
3. The resource automatically creates the required `bank_accounts` and `bank_transactions` database tables on first start.

## Mapping / Location Notes

Bank NPC locations use standard GTA V bank interiors (Fleeca branches, Pacific Standard). The coordinates in `config.lua` correspond to vanilla GTA V bank interiors - no custom MLO is required. One entry at Pacific Standard deletes a chair prop to place the NPC. The ATM system targets built-in GTA V ATM prop models (`prop_atm_01`, `prop_atm_02`, `prop_atm_03`, `prop_fleeca_atm`).

## Configuration

All settings are in `config.lua`:

- **StartingBonus** - Cash bonus when creating a new bank account
- **CardRequestFee / CardReplaceFee** - Fees for bank card operations
- **MaxPinAttempts / PinLength** - PIN security settings
- **QuickWithdrawAmounts** - Preset quick withdrawal amounts for ATMs
- **MaxWithdraw / MaxDeposit** - Single transaction limits
- **MaxSavingsDeposit / MaxSavingsWithdraw** - Savings account limits
- **SavingsInterestRate** - Annual interest rate (default 2.5%)
- **InterestPayoutInterval** - Real-time minutes between interest payouts
- **TransferFee / MinTransfer / MaxTransfer** - Transfer settings
- **BankNPCModel** - Ped model for bank tellers
- **BankLocations** - Bank NPC positions (add, remove, or reposition freely)
- **ATMModels** - GTA V ATM prop hashes to target
- **ATMDistance / BankDistance** - Interaction distances

## Exports

**Server-side:**

- `exports['sb_banking']:AddTransaction(citizenid, txType, amount, balanceAfter, description, targetCitizenid)` - Log a transaction
- `exports['sb_banking']:LogPurchase(citizenid, amount, balanceAfter, description)` - Log a purchase from another script
- `exports['sb_banking']:LogRefund(citizenid, amount, balanceAfter, description)` - Log a refund

## License

Part of SB Framework by Salah Eddine Boussettah.
