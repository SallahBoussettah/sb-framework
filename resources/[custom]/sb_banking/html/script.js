/**
 * Everyday Chaos RP - Banking System (NUI)
 * Author: Salah Eddine Boussettah
 */

const container = document.getElementById('container');
const bankTerminal = document.getElementById('bank-terminal');
const atmTerminal = document.getElementById('atm-terminal');

let currentMode = null;
let accountData = null;
let atmPin = '';
let hasAccount = false;

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', function(event) {
    const msg = event.data;

    switch (msg.action) {
        case 'open':
            openTerminal(msg.mode);
            break;
        case 'close':
            closeTerminal();
            break;
        case 'showCreate':
            if (currentMode === 'atm') {
                fetchNUI('close', {});
            } else {
                hasAccount = false;
                showPage('create');
            }
            break;
        case 'accountData':
            hasAccount = true;
            accountData = msg.data;
            if (currentMode === 'bank') {
                showPage('dashboard');
                updateBankDisplay();
                fetchNUI('getTransactions', {});
            } else if (currentMode === 'atm') {
                if (msg.data.cardLocked) {
                    showATMScreen('atm-screen-locked');
                } else {
                    resetATMPin();
                    showATMScreen('atm-screen-pin');
                }
            }
            break;
        case 'accountCreated':
            break;
        case 'updateBalance':
            if (accountData) {
                accountData.cash = msg.cash;
                accountData.bank = msg.bank;
                updateBankDisplay();
                if (currentMode === 'atm') {
                    updateATMBalance();
                }
            }
            break;
        case 'pinVerified':
            showATMScreen('atm-screen-menu');
            updateATMBalance();
            break;
        case 'cardLocked':
            if (currentMode === 'atm') {
                showATMScreen('atm-screen-locked');
            }
            break;
        case 'wrongPin':
            showPinError('Wrong PIN. ' + msg.remaining + ' attempts remaining.');
            resetATMPin();
            break;
        case 'transactions':
            renderTransactions(msg.data);
            break;
        case 'societyTransactions':
            renderSocietyTransactions(msg.data);
            break;
        case 'atmSuccess':
            if (accountData) {
                accountData.bank = msg.balance;
                updateATMBalance();
                // Return to menu after successful transaction
                setTimeout(() => showATMScreen('atm-screen-menu'), 600);
            }
            break;
        case 'updateSavings':
            if (accountData) {
                if (typeof msg.savings === 'object') {
                    accountData.savings = msg.savings.savings;
                    accountData.monthlyEarnings = msg.savings.monthlyEarnings;
                    accountData.totalDeposited = msg.savings.totalDeposited;
                } else {
                    accountData.savings = msg.savings;
                }
                updateBankDisplay();
            }
            break;
        case 'cardIssued':
            if (accountData) {
                accountData.cardId = msg.cardId;
                updateBankDisplay();
            }
            break;
    }
});

// ============================================================================
// OPEN / CLOSE
// ============================================================================

function openTerminal(mode) {
    currentMode = mode;
    container.style.display = 'flex';

    if (mode === 'bank') {
        bankTerminal.style.display = 'flex';
        atmTerminal.style.display = 'none';
    } else {
        atmTerminal.style.display = 'flex';
        bankTerminal.style.display = 'none';
    }
}

function closeTerminal() {
    container.style.display = 'none';
    bankTerminal.style.display = 'none';
    atmTerminal.style.display = 'none';
    currentMode = null;
    accountData = null;
    hasAccount = false;
    atmPin = '';
    actionLocked = false;
    resetAll();
}

function resetAll() {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    const dashNav = document.querySelector('.nav-item[data-page="dashboard"]');
    if (dashNav) dashNav.classList.add('active');
    document.querySelectorAll('.atm-screen').forEach(s => s.classList.remove('active'));
    document.querySelectorAll('input').forEach(i => i.value = '');
    document.querySelectorAll('.pin-error').forEach(e => e.style.display = 'none');
}

// ============================================================================
// PAGE NAVIGATION
// ============================================================================

const modalPages = ['deposit', 'withdraw', 'transfer'];

function showPage(pageName) {
    // Block navigation if no account (only allow 'create' page)
    if (!hasAccount && pageName !== 'create') return;

    if (modalPages.includes(pageName)) {
        // Show as modal overlay (keep dashboard visible)
        document.querySelectorAll('.modal-page').forEach(p => p.classList.remove('active'));
        const modal = document.getElementById('page-' + pageName);
        if (modal) modal.classList.add('active');
    } else {
        // Regular page navigation
        document.querySelectorAll('.modal-page').forEach(p => p.classList.remove('active'));
        document.querySelectorAll('.page:not(.modal-page)').forEach(p => p.classList.remove('active'));
        const page = document.getElementById('page-' + pageName);
        if (page) page.classList.add('active');
    }

    // Update nav active state
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    const navBtn = document.querySelector(`.nav-item[data-page="${pageName}"]`);
    if (navBtn) navBtn.classList.add('active');
    if (modalPages.includes(pageName)) {
        const dashNav = document.querySelector('.nav-item[data-page="dashboard"]');
        if (dashNav) dashNav.classList.add('active');
    }

    if (pageName === 'transactions') {
        fetchNUI('getTransactions', {});
    } else if (pageName === 'society') {
        fetchNUI('getSocietyTransactions', {});
    }

    updateBankDisplay();
}

function closeModal() {
    document.querySelectorAll('.modal-page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    const dashNav = document.querySelector('.nav-item[data-page="dashboard"]');
    if (dashNav) dashNav.classList.add('active');
}

// Modal close buttons
document.querySelectorAll('.modal-close').forEach(btn => {
    btn.addEventListener('click', closeModal);
});

// Click modal backdrop to close
document.querySelectorAll('.modal-page').forEach(page => {
    page.addEventListener('click', function(e) {
        if (e.target === this) closeModal();
    });
});

// Sidebar navigation clicks
document.querySelectorAll('.nav-item[data-page]').forEach(btn => {
    btn.addEventListener('click', function() {
        showPage(this.dataset.page);
    });
});

// Dashboard action buttons (open modals)
document.querySelectorAll('[data-modal]').forEach(btn => {
    btn.addEventListener('click', function() {
        showPage(this.dataset.modal);
    });
});

// See all button
document.querySelectorAll('.see-all[data-page]').forEach(btn => {
    btn.addEventListener('click', function() {
        showPage(this.dataset.page);
    });
});

// ============================================================================
// ATM SCREENS
// ============================================================================

function showATMScreen(id) {
    document.querySelectorAll('.atm-screen').forEach(s => s.classList.remove('active'));
    document.getElementById(id).classList.add('active');
}

function updateATMBalance() {
    if (!accountData) return;
    document.getElementById('atm-balance').textContent = formatMoney(accountData.bank);
}

// ============================================================================
// BANK DISPLAY UPDATE
// ============================================================================

function updateBankDisplay() {
    if (!accountData) return;

    const bankStr = formatMoney(accountData.bank);
    const cashStr = formatMoney(accountData.cash);
    const totalStr = formatMoney((accountData.cash || 0) + (accountData.bank || 0));

    // Dashboard - Balance & Stats
    document.getElementById('dash-bank').textContent = bankStr;
    document.getElementById('dash-cash').textContent = cashStr;
    document.getElementById('dash-total').textContent = totalStr;

    const dashSavings = document.getElementById('dash-savings');
    if (dashSavings) dashSavings.textContent = formatMoney(accountData.savings || 0);

    // Card
    if (accountData.cardId) {
        document.getElementById('dash-card-number').textContent = formatCardNumber(accountData.cardId);
    }
    if (accountData.name) {
        document.getElementById('dash-card-name').textContent = accountData.name;
    }

    // Savings page
    const savBal = document.getElementById('savings-balance');
    if (savBal) savBal.textContent = formatMoney(accountData.savings || 0);
    const savBank = document.getElementById('savings-bank-bal');
    if (savBank) savBank.textContent = bankStr;
    const savAvail = document.getElementById('savings-avail');
    if (savAvail) savAvail.textContent = formatMoney(accountData.savings || 0);
    const savEarnings = document.getElementById('savings-earnings');
    if (savEarnings) savEarnings.textContent = formatMoney(accountData.monthlyEarnings || 0);
    const savDeposited = document.getElementById('savings-deposited');
    if (savDeposited) savDeposited.textContent = formatMoney(accountData.totalDeposited || 0);

    // Society page
    const socBank = document.getElementById('society-bank-bal');
    if (socBank) socBank.textContent = bankStr;
    if (accountData.society) {
        document.getElementById('society-empty').style.display = 'none';
        document.getElementById('society-content').style.display = 'flex';
        document.getElementById('society-name').textContent = accountData.society.name || '—';
        document.getElementById('society-role').textContent = accountData.society.role || 'Member';
        document.getElementById('society-balance').textContent = formatMoney(accountData.society.balance || 0);
        const socAvail = document.getElementById('society-avail');
        if (socAvail) socAvail.textContent = formatMoney(accountData.society.balance || 0);
    } else {
        document.getElementById('society-empty').style.display = 'flex';
        document.getElementById('society-content').style.display = 'none';
    }

    // Modal info bars
    document.getElementById('deposit-cash').textContent = cashStr;
    document.getElementById('withdraw-balance').textContent = bankStr;
    document.getElementById('transfer-balance').textContent = bankStr;
}

// ============================================================================
// PIN INPUT HANDLING (Bank Create Account)
// ============================================================================

document.querySelectorAll('.pin-inputs').forEach(container => {
    const inputs = container.querySelectorAll('.pin-digit');
    inputs.forEach((input, index) => {
        input.addEventListener('input', function() {
            if (this.value.length === 1 && index < inputs.length - 1) {
                inputs[index + 1].focus();
            }
        });
        input.addEventListener('keydown', function(e) {
            if (e.key === 'Backspace' && !this.value && index > 0) {
                inputs[index - 1].focus();
            }
        });
        input.addEventListener('keypress', function(e) {
            if (!/[0-9]/.test(e.key)) {
                e.preventDefault();
            }
        });
    });
});

function getPinValue(containerId) {
    const inputs = document.querySelectorAll('#' + containerId + ' .pin-digit');
    let pin = '';
    inputs.forEach(i => pin += i.value);
    return pin;
}

function clearPinInputs(containerId) {
    document.querySelectorAll('#' + containerId + ' .pin-digit').forEach(i => i.value = '');
}

// ============================================================================
// ATM NUMPAD
// ============================================================================

function updatePinDots() {
    const dots = document.querySelectorAll('#atm-pin-dots .pin-dot');
    dots.forEach((dot, index) => {
        if (index < atmPin.length) {
            dot.classList.add('filled');
        } else {
            dot.classList.remove('filled');
        }
    });
}

function resetATMPin() {
    atmPin = '';
    updatePinDots();
}

function showPinError(msg) {
    const el = document.getElementById('atm-pin-error');
    el.textContent = msg;
    el.style.display = 'block';
    setTimeout(() => el.style.display = 'none', 4000);
}

document.querySelectorAll('.num-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        const val = this.dataset.num;
        if (val === 'clear') {
            resetATMPin();
        } else if (val === 'enter') {
            if (atmPin.length === 4) submitATMPin();
        } else {
            if (atmPin.length < 4) {
                atmPin += val;
                updatePinDots();
                if (atmPin.length === 4) {
                    setTimeout(submitATMPin, 300);
                }
            }
        }
    });
});

// ============================================================================
// ACTIONS
// ============================================================================

// Close buttons
document.getElementById('btn-close-bank').addEventListener('click', () => fetchNUI('close', {}));
document.getElementById('btn-close-atm').addEventListener('click', () => fetchNUI('close', {}));
document.getElementById('btn-atm-close-locked').addEventListener('click', () => fetchNUI('close', {}));

// ATM Menu Navigation
document.getElementById('atm-goto-withdraw').addEventListener('click', () => showATMScreen('atm-screen-withdraw'));
document.getElementById('atm-deposit-btn').addEventListener('click', () => showATMScreen('atm-screen-deposit'));
document.getElementById('atm-back-menu').addEventListener('click', () => showATMScreen('atm-screen-menu'));
document.getElementById('atm-back-menu-dep').addEventListener('click', () => showATMScreen('atm-screen-menu'));

// ATM Fast Cash ($100)
document.getElementById('atm-fast-cash').addEventListener('click', function() {
    fetchNUI('atmWithdraw', { amount: 100, pin: atmPin });
});

// Create Account
document.getElementById('btn-create-account').addEventListener('click', function() {
    const pin = getPinValue('create-pin-inputs');
    const confirm = getPinValue('confirm-pin-inputs');

    if (pin.length !== 4) {
        fetchNUI('notify', { msg: 'Enter all 4 digits.', type: 'error' });
        return;
    }
    if (pin !== confirm) {
        fetchNUI('notify', { msg: 'PINs do not match!', type: 'error' });
        clearPinInputs('confirm-pin-inputs');
        return;
    }

    fetchNUI('createAccount', { pin: pin });
    clearPinInputs('create-pin-inputs');
    clearPinInputs('confirm-pin-inputs');
});

// Deposit
document.getElementById('btn-deposit').addEventListener('click', function() {
    const raw = document.getElementById('deposit-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > accountData.cash) {
        fetchNUI('notify', { msg: 'Not enough cash.', type: 'error' });
        return;
    }
    fetchNUI('deposit', { amount: amount });
    document.getElementById('deposit-amount').value = '';
});

// Withdraw
document.getElementById('btn-withdraw').addEventListener('click', function() {
    const raw = document.getElementById('withdraw-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > accountData.bank) {
        fetchNUI('notify', { msg: 'Insufficient bank funds.', type: 'error' });
        return;
    }
    fetchNUI('withdraw', { amount: amount });
    document.getElementById('withdraw-amount').value = '';
});

// Transfer
document.getElementById('btn-transfer').addEventListener('click', function() {
    const target = document.getElementById('transfer-target').value.trim();
    const raw = document.getElementById('transfer-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!target) {
        fetchNUI('notify', { msg: 'Enter a recipient ID.', type: 'error' });
        return;
    }
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > accountData.bank) {
        fetchNUI('notify', { msg: 'Insufficient bank funds.', type: 'error' });
        return;
    }
    fetchNUI('transfer', { target: target, amount: amount });
    document.getElementById('transfer-amount').value = '';
});

// Savings Deposit
document.getElementById('btn-savings-deposit').addEventListener('click', function() {
    const raw = document.getElementById('savings-deposit-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > accountData.bank) {
        fetchNUI('notify', { msg: 'Insufficient bank funds.', type: 'error' });
        return;
    }
    fetchNUI('savingsDeposit', { amount: amount });
    document.getElementById('savings-deposit-amount').value = '';
});

// Savings Withdraw
document.getElementById('btn-savings-withdraw').addEventListener('click', function() {
    const raw = document.getElementById('savings-withdraw-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > (accountData.savings || 0)) {
        fetchNUI('notify', { msg: 'Insufficient savings balance.', type: 'error' });
        return;
    }
    fetchNUI('savingsWithdraw', { amount: amount });
    document.getElementById('savings-withdraw-amount').value = '';
});

// Society Deposit
document.getElementById('btn-society-deposit').addEventListener('click', function() {
    const amount = parseInt(document.getElementById('society-deposit-amount').value);
    if (!amount || amount <= 0) return;
    fetchNUI('societyDeposit', { amount: amount });
    document.getElementById('society-deposit-amount').value = '';
});

// Society Withdraw
document.getElementById('btn-society-withdraw').addEventListener('click', function() {
    const amount = parseInt(document.getElementById('society-withdraw-amount').value);
    if (!amount || amount <= 0) return;
    fetchNUI('societyWithdraw', { amount: amount });
    document.getElementById('society-withdraw-amount').value = '';
});

// Settings: Request Card
document.getElementById('btn-request-card').addEventListener('click', function() {
    fetchNUI('requestCard', {});
});

// Settings: Reset PIN
document.getElementById('btn-reset-pin').addEventListener('click', function() {
    const pin = document.getElementById('settings-new-pin').value.trim();
    if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
        fetchNUI('notify', { msg: 'PIN must be exactly 4 digits.', type: 'error' });
        return;
    }
    fetchNUI('resetPin', { pin: pin });
    document.getElementById('settings-new-pin').value = '';
});

// Settings: Unlock Card
document.getElementById('btn-unlock-card').addEventListener('click', function() {
    fetchNUI('unlockCard', {});
});

// Quick amount buttons (deposit/withdraw)
document.querySelectorAll('.btn-quick[data-action]').forEach(btn => {
    btn.addEventListener('click', function() {
        const action = this.dataset.action;
        const amount = parseInt(this.dataset.amount);
        fetchNUI(action, { amount: amount });
    });
});

// ATM PIN submit
function submitATMPin() {
    if (atmPin.length !== 4) return;
    // Verify PIN on server first
    fetchNUI('verifyPin', { pin: atmPin });
}

// ATM Quick Withdraw
document.querySelectorAll('.atm-quick').forEach(btn => {
    btn.addEventListener('click', function() {
        const amount = parseInt(this.dataset.amount);
        fetchNUI('atmWithdraw', { amount: amount, pin: atmPin });
    });
});

// ATM Custom Withdraw
document.getElementById('btn-atm-withdraw').addEventListener('click', function() {
    const raw = document.getElementById('atm-withdraw-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > accountData.bank) {
        fetchNUI('notify', { msg: 'Insufficient funds.', type: 'error' });
        return;
    }
    fetchNUI('atmWithdraw', { amount: amount, pin: atmPin });
    document.getElementById('atm-withdraw-amount').value = '';
});

// ATM Quick Deposit
document.querySelectorAll('.atm-deposit-quick').forEach(btn => {
    btn.addEventListener('click', function() {
        const amount = parseInt(this.dataset.amount);
        fetchNUI('atmDeposit', { amount: amount });
    });
});

// ATM Custom Deposit
document.getElementById('btn-atm-deposit').addEventListener('click', function() {
    const raw = document.getElementById('atm-deposit-amount').value.trim();
    const amount = Math.floor(Number(raw));
    if (!amount || amount <= 0 || isNaN(amount)) {
        fetchNUI('notify', { msg: 'Enter a valid amount.', type: 'error' });
        return;
    }
    if (accountData && amount > accountData.cash) {
        fetchNUI('notify', { msg: 'Not enough cash.', type: 'error' });
        return;
    }
    fetchNUI('atmDeposit', { amount: amount });
    document.getElementById('atm-deposit-amount').value = '';
});

// ============================================================================
// TRANSACTIONS
// ============================================================================

function renderTransactions(data) {
    const list = document.getElementById('transactions-list');

    // Update dashboard tx count
    const txCount = document.getElementById('dash-tx-count');
    if (txCount) txCount.textContent = (data && data.length) || 0;

    if (!data || data.length === 0) {
        list.innerHTML = '<div class="no-transactions">No transactions yet</div>';
        renderRecentTransactions([]);
        return;
    }

    let html = '';
    data.forEach(tx => {
        const isPositive = ['deposit', 'transfer_in', 'account_open'].includes(tx.type);
        const sign = isPositive ? '+' : '-';
        const amountClass = isPositive ? 'positive' : 'negative';
        const typeLabel = tx.type.replace(/_/g, ' ');
        const date = tx.created_at ? new Date(tx.created_at).toLocaleDateString() : '';

        html += `
            <div class="tx-item">
                <div class="tx-left">
                    <span class="tx-type">${typeLabel}</span>
                    <span class="tx-desc">${tx.description || ''}</span>
                    <span class="tx-date">${date}</span>
                </div>
                <div class="tx-right">
                    <span class="tx-amount ${amountClass}">${sign}${formatMoney(tx.amount)}</span>
                    <div class="tx-balance">Bal: ${formatMoney(tx.balance_after)}</div>
                </div>
            </div>
        `;
    });

    list.innerHTML = html;
    renderRecentTransactions(data);
}

function renderRecentTransactions(data) {
    const txList = document.getElementById('dash-tx-list');
    if (!txList) return;

    if (!data || data.length === 0) {
        txList.innerHTML = '<div class="no-transactions">No recent activity</div>';
        return;
    }

    const recent = data.slice(0, 5);
    let html = '';
    recent.forEach(tx => {
        const isPositive = ['deposit', 'transfer_in', 'account_open'].includes(tx.type);
        const amountClass = isPositive ? 'positive' : 'negative';
        const sign = isPositive ? '+' : '-';

        let icon = 'fa-arrow-down';
        if (tx.type === 'withdraw') icon = 'fa-arrow-up';
        else if (tx.type === 'transfer_out') icon = 'fa-paper-plane';
        else if (tx.type === 'account_open') icon = 'fa-gift';

        const desc = tx.description || tx.type.replace(/_/g, ' ');
        const time = tx.created_at ? new Date(tx.created_at).toLocaleString([], { month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' }) : '';

        html += `
            <div class="tx-feed-item">
                <div class="tx-feed-left">
                    <div class="tx-feed-icon ${amountClass}"><i class="fas ${icon}"></i></div>
                    <div class="tx-feed-info">
                        <p>${desc}</p>
                        <span>${time}</span>
                    </div>
                </div>
                <div class="tx-feed-right">
                    <div class="tx-feed-amount ${amountClass}">${sign}${formatMoney(tx.amount)}</div>
                    <div class="tx-feed-id">ID: ${tx.id || '—'}</div>
                </div>
            </div>
        `;
    });

    txList.innerHTML = html;
}

function renderSocietyTransactions(data) {
    const list = document.getElementById('society-tx-list');
    if (!list) return;

    if (!data || data.length === 0) {
        list.innerHTML = '<div class="no-transactions">No society transactions</div>';
        return;
    }

    let html = '';
    data.forEach(tx => {
        const isPositive = ['deposit'].includes(tx.type);
        const sign = isPositive ? '+' : '-';
        const amountClass = isPositive ? 'positive' : 'negative';
        const date = tx.created_at ? new Date(tx.created_at).toLocaleString([], { month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' }) : '';
        const desc = tx.description || tx.type.replace(/_/g, ' ');

        html += `
            <div class="tx-item">
                <div class="tx-left">
                    <span class="tx-type">${desc}</span>
                    <span class="tx-date">${date}</span>
                </div>
                <div class="tx-right">
                    <span class="tx-amount ${amountClass}">${sign}${formatMoney(tx.amount)}</span>
                </div>
            </div>
        `;
    });

    list.innerHTML = html;
}

// ============================================================================
// HELPERS
// ============================================================================

function formatMoney(amount) {
    if (amount === null || amount === undefined) return '$0';
    return '$' + Math.abs(amount).toLocaleString();
}

function formatCardNumber(num) {
    if (!num) return '**** **** **** ****';
    return num.replace(/(.{4})/g, '$1 ').trim();
}

let actionLocked = false;

function fetchNUI(name, data) {
    // Debounce money operations to prevent double-fire
    const moneyActions = ['deposit', 'withdraw', 'transfer', 'atmWithdraw', 'atmDeposit', 'savingsDeposit', 'savingsWithdraw', 'requestCard', 'replaceCard'];
    if (moneyActions.includes(name)) {
        if (actionLocked) return;
        actionLocked = true;
        setTimeout(() => { actionLocked = false; }, 1500);
    }

    fetch('https://' + GetParentResourceName() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

// ESC to close
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        fetchNUI('close', {});
    }
});
