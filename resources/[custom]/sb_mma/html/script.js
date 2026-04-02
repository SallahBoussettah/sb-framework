/* ============================================================================
   MMA Arena Betting - NUI Script
   Author: Salah Eddine Boussettah
   ============================================================================ */

let selectedFighter = null;
let currentOdds = [2.0, 2.0];
let currentCash = 0;
let timerInterval = null;
let bettingEndTime = 0;
let currentStateStr = 'IDLE';

// ============================================================================
// fetchNUI
// ============================================================================

function fetchNUI(eventName, data) {
    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

// ============================================================================
// MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openPanel(data);
            break;
        case 'close':
            closePanel();
            break;
        case 'stateUpdate':
            updateState(data.state);
            if (data.cash !== undefined) currentCash = data.cash;
            updateCashDisplay();
            break;
        case 'fightResult':
            showResult(data.winner, data.winnerName);
            break;
    }
});

// ============================================================================
// KEYBOARD
// ============================================================================

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        fetchNUI('close');
    }
});

// ============================================================================
// OPEN / CLOSE
// ============================================================================

function openPanel(data) {
    document.getElementById('app').classList.remove('hidden');
    currentCash = data.cash || 0;
    selectedFighter = null;
    document.getElementById('betAmount').value = '';

    updateCashDisplay();
    updateSelectedDisplay();

    if (data.state) {
        updateState(data.state);
    }

    if (data.history) {
        renderHistory(data.history);
    }

    // Reset result section
    document.getElementById('resultSection').classList.add('hidden');
    document.getElementById('betSection').style.display = '';
}

function closePanel() {
    document.getElementById('app').classList.add('hidden');
    stopTimer();
    selectedFighter = null;
}

// ============================================================================
// STATE UPDATE
// ============================================================================

function updateState(state) {
    if (!state) return;
    currentStateStr = state.state;

    // Update badge
    const badge = document.getElementById('stateBadge');
    badge.className = 'status-badge';

    switch (state.state) {
        case 'IDLE':
            badge.textContent = 'IDLE';
            disableBetting();
            stopTimer();
            document.getElementById('timerText').textContent = '--:--';
            break;
        case 'BETTING_OPEN':
            badge.textContent = 'BETTING';
            badge.classList.add('betting');
            enableBetting();
            if (state.bettingEndTime) {
                startTimer(state.bettingEndTime);
            }
            break;
        case 'FIGHT_IN_PROGRESS':
            badge.textContent = 'FIGHTING';
            badge.classList.add('fighting');
            disableBetting();
            stopTimer();
            document.getElementById('timerText').textContent = 'LIVE';
            break;
        case 'PAYOUT':
            badge.textContent = 'PAYOUT';
            badge.classList.add('fighting');
            disableBetting();
            break;
        case 'COOLDOWN':
            badge.textContent = 'COOLDOWN';
            badge.classList.add('cooldown');
            disableBetting();
            stopTimer();
            document.getElementById('timerText').textContent = '--:--';
            break;
    }

    // Update fighters
    // Lua 1-indexed tables become 0-indexed JS arrays via JSON
    if (state.fighters) {
        document.getElementById('fighter1Name').textContent = state.fighters[0] ? state.fighters[0].name : '---';
        document.getElementById('fighter2Name').textContent = state.fighters[1] ? state.fighters[1].name : '---';
    }

    // Update odds
    if (state.odds) {
        currentOdds = state.odds;
        document.getElementById('fighter1Odds').textContent = state.odds[0].toFixed(2) + 'x';
        document.getElementById('fighter2Odds').textContent = state.odds[1].toFixed(2) + 'x';
    }

    // Update pools
    if (state.pools) {
        document.getElementById('fighter1Pool').textContent = '$' + formatNumber(state.pools[0]);
        document.getElementById('fighter2Pool').textContent = '$' + formatNumber(state.pools[1]);
    }

    if (state.totalPool !== undefined) {
        document.getElementById('totalPool').textContent = '$' + formatNumber(state.totalPool);
    }

    // Update winner display on cards
    if (state.winner && (state.state === 'PAYOUT' || state.state === 'FIGHT_IN_PROGRESS')) {
        const winCard = document.getElementById('fighter' + state.winner + 'Card');
        const loseCard = document.getElementById('fighter' + (state.winner === 1 ? 2 : 1) + 'Card');
        winCard.classList.add('winner');
        loseCard.classList.add('loser');
    } else {
        document.getElementById('fighter1Card').classList.remove('winner', 'loser');
        document.getElementById('fighter2Card').classList.remove('winner', 'loser');
    }

    updatePotentialPayout();
}

// ============================================================================
// BETTING CONTROLS
// ============================================================================

function enableBetting() {
    document.getElementById('betFighter1').disabled = false;
    document.getElementById('betFighter2').disabled = false;
    document.getElementById('placeBetBtn').disabled = false;
    document.getElementById('betAmount').disabled = false;
    document.getElementById('betSection').style.display = '';
    document.getElementById('resultSection').classList.add('hidden');
}

function disableBetting() {
    document.getElementById('betFighter1').disabled = true;
    document.getElementById('betFighter2').disabled = true;
    document.getElementById('placeBetBtn').disabled = true;
    document.getElementById('betAmount').disabled = true;
}

function selectFighter(index) {
    if (currentStateStr !== 'BETTING_OPEN') return;

    selectedFighter = index;
    updateSelectedDisplay();
    updatePotentialPayout();

    // Visual feedback
    document.getElementById('fighter1Card').classList.toggle('selected', index === 1);
    document.getElementById('fighter2Card').classList.toggle('selected', index === 2);
}

function updateSelectedDisplay() {
    const display = document.getElementById('selectedFighterDisplay');
    if (selectedFighter) {
        const name = document.getElementById('fighter' + selectedFighter + 'Name').textContent;
        display.textContent = 'Betting on: ' + name;
        display.classList.add('active');
    } else {
        display.textContent = 'Select a fighter above';
        display.classList.remove('active');
    }
}

function setAmount(amount) {
    document.getElementById('betAmount').value = amount;
    updatePotentialPayout();
}

function updatePotentialPayout() {
    const amount = parseInt(document.getElementById('betAmount').value) || 0;
    const odds = selectedFighter ? currentOdds[selectedFighter - 1] : 0;
    const payout = Math.floor(amount * odds);
    document.getElementById('potentialPayout').innerHTML =
        'Potential payout: <strong>$' + formatNumber(payout) + '</strong>';
}

function placeBet() {
    if (!selectedFighter) {
        return;
    }

    const amount = parseInt(document.getElementById('betAmount').value);
    if (!amount || amount < 50) {
        return;
    }

    if (amount > currentCash) {
        return;
    }

    fetchNUI('placeBet', {
        fighter: selectedFighter,
        amount: amount
    });

    // Optimistic UI update
    currentCash -= amount;
    updateCashDisplay();
    document.getElementById('betAmount').value = '';
    selectedFighter = null;
    updateSelectedDisplay();
    document.getElementById('fighter1Card').classList.remove('selected');
    document.getElementById('fighter2Card').classList.remove('selected');

    // Disable further betting for this fight
    disableBetting();
}

// ============================================================================
// RESULT DISPLAY
// ============================================================================

function showResult(winner, winnerName) {
    document.getElementById('resultSection').classList.remove('hidden');
    document.getElementById('resultTitle').textContent = 'Winner!';
    document.getElementById('resultName').textContent = winnerName;
}

// ============================================================================
// TIMER
// ============================================================================

function startTimer(endTime) {
    stopTimer();
    bettingEndTime = endTime;

    timerInterval = setInterval(function() {
        const now = Date.now();
        // endTime is a game timer value, estimate remaining
        const remaining = Math.max(0, Math.ceil((bettingEndTime - now) / 1000));

        if (remaining <= 0) {
            document.getElementById('timerText').textContent = '0:00';
            stopTimer();
            return;
        }

        const mins = Math.floor(remaining / 60);
        const secs = remaining % 60;
        document.getElementById('timerText').textContent =
            mins + ':' + (secs < 10 ? '0' : '') + secs;
    }, 250);
}

function stopTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
}

// ============================================================================
// HISTORY
// ============================================================================

function renderHistory(history) {
    const list = document.getElementById('historyList');
    if (!history || history.length === 0) {
        list.innerHTML = '<div class="history-empty">No bet history yet</div>';
        return;
    }

    list.innerHTML = '';
    history.forEach(function(item) {
        const won = item.won === 1;
        const el = document.createElement('div');
        el.className = 'history-item';
        el.innerHTML = `
            <div class="hi-left">
                <div class="hi-dot ${won ? 'win' : 'loss'}"></div>
                <span class="hi-fighter">${escapeHtml(item.fighter_name)}</span>
                <span class="hi-amount">$${formatNumber(item.bet_amount)}</span>
            </div>
            <div class="hi-right ${won ? 'win' : 'loss'}">
                ${won ? '+$' + formatNumber(item.payout) : '-$' + formatNumber(item.bet_amount)}
            </div>
        `;
        list.appendChild(el);
    });
}

// ============================================================================
// HELPERS
// ============================================================================

function updateCashDisplay() {
    document.getElementById('cashDisplay').innerHTML =
        '<i class="fas fa-wallet"></i> $' + formatNumber(currentCash);
}

function formatNumber(num) {
    return (num || 0).toLocaleString('en-US');
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str || '';
    return div.innerHTML;
}

// Input event for potential payout update
document.getElementById('betAmount').addEventListener('input', updatePotentialPayout);
