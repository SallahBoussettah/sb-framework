--[[
    Everyday Chaos RP - English Locale
    Author: Salah Eddine Boussettah
]]

Locale = {}

Locale.Lang = {
    -- ========================================================================
    -- GENERAL
    -- ========================================================================
    ['general_yes'] = 'Yes',
    ['general_no'] = 'No',
    ['general_confirm'] = 'Confirm',
    ['general_cancel'] = 'Cancel',
    ['general_close'] = 'Close',
    ['general_loading'] = 'Loading...',
    ['general_error'] = 'Error',
    ['general_success'] = 'Success',

    -- ========================================================================
    -- MONEY
    -- ========================================================================
    ['money_received'] = 'You received %s',
    ['money_removed'] = 'You paid %s',
    ['money_not_enough'] = 'Not enough money',
    ['money_cash'] = 'Cash',
    ['money_bank'] = 'Bank',
    ['money_crypto'] = 'Crypto',

    -- ========================================================================
    -- JOB
    -- ========================================================================
    ['job_changed'] = 'Your job has been changed to %s',
    ['job_on_duty'] = 'You are now on duty',
    ['job_off_duty'] = 'You are now off duty',
    ['job_paycheck'] = 'You received your paycheck: %s',

    -- ========================================================================
    -- GANG
    -- ========================================================================
    ['gang_changed'] = 'Your gang has been changed to %s',

    -- ========================================================================
    -- PLAYER
    -- ========================================================================
    ['player_loaded'] = 'Welcome back, %s!',
    ['player_new'] = 'Welcome to Everyday Chaos RP!',
    ['player_kicked'] = 'You have been kicked: %s',
    ['player_banned'] = 'You are banned: %s',

    -- ========================================================================
    -- INVENTORY
    -- ========================================================================
    ['inventory_received'] = 'You received %sx %s',
    ['inventory_removed'] = 'You lost %sx %s',
    ['inventory_full'] = 'Inventory is full',
    ['inventory_not_enough'] = 'You don\'t have enough %s',

    -- ========================================================================
    -- COMMANDS
    -- ========================================================================
    ['command_no_permission'] = 'You don\'t have permission to use this command',
    ['command_invalid_id'] = 'Invalid player ID',
    ['command_player_not_found'] = 'Player not found',
    ['command_invalid_amount'] = 'Invalid amount',

    -- ========================================================================
    -- ADMIN
    -- ========================================================================
    ['admin_gave_money'] = 'Admin gave you %s %s',
    ['admin_set_job'] = 'Admin set your job to %s',
    ['admin_set_gang'] = 'Admin set your gang to %s',
}

-- Get locale string with formatting
function Lang(key, ...)
    if Locale.Lang[key] then
        return string.format(Locale.Lang[key], ...)
    end
    return 'MISSING: ' .. key
end
