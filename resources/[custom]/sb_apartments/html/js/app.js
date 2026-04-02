// sb_apartments v2 NUI

let currentBuilding = null;
let currentUnits = null;
let currentUnit = null;
let playerMoney = { cash: 0, bank: 0 };
let pendingKeyUnit = null;
let shellOptions = [];
let selectedShell = null;
let activeFloor = 'all';
let doorbellTimer = null;

// ============================================
// MESSAGE HANDLER
// ============================================

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'openBuilding':
            openBuildingView(data.building, data.units, data.playerMoney, data.floors, data.shellOptions);
            break;
        case 'openManagement':
            openManagementView(data.unit, data.rental, data.keys, data.isOwner, data.maxKeys);
            break;
        case 'openGarage':
            openGarageView(data.vehicles, data.unitId);
            break;
        case 'showPlayerList':
            showPlayerSelection(data.players, data.unitId);
            break;
        case 'doorbellRing':
            showDoorbellPopup(data.visitorName, data.timeout);
            break;
        case 'doorbellExpired':
        case 'doorbellDenied':
            hideDoorbellPopup();
            break;
        case 'close':
            closeUI();
            break;
    }
});

// ============================================
// BUILDING VIEW
// ============================================

function openBuildingView(building, units, money, floors, shells) {
    currentBuilding = building;
    currentUnits = units;
    playerMoney = money;
    shellOptions = shells || [];
    selectedShell = shells && shells.length > 0 ? shells[0].id : null;
    activeFloor = 'all';

    hideAllPanels();
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('building-view').classList.remove('hidden');

    document.getElementById('building-name').textContent = building.name;
    document.getElementById('building-desc').textContent = building.description;
    document.getElementById('tier-badge').textContent = capitalize(building.tier);

    const availableCount = units.filter(u => !u.isRented).length;
    document.getElementById('available-count').textContent = availableCount + ' Available';
    document.getElementById('player-money').textContent = '$' + formatMoney(money.cash + money.bank);

    // Floor tabs
    const floorTabs = document.getElementById('floor-tabs');
    if (floors && floors.length > 1) {
        floorTabs.classList.remove('hidden');
        floorTabs.innerHTML = '<button class="floor-tab active" onclick="filterFloor(\'all\')">All</button>';
        floors.forEach(f => {
            floorTabs.innerHTML += `<button class="floor-tab" onclick="filterFloor(${f})">Floor ${f}</button>`;
        });
    } else {
        floorTabs.classList.add('hidden');
    }

    renderUnits(units);
}

function filterFloor(floor) {
    activeFloor = floor;

    // Update active tab
    document.querySelectorAll('.floor-tab').forEach(tab => tab.classList.remove('active'));
    event.target.classList.add('active');

    const filtered = floor === 'all' ? currentUnits : currentUnits.filter(u => u.floor === floor);
    renderUnits(filtered);
}

function renderUnits(units) {
    const unitsList = document.getElementById('units-list');
    unitsList.innerHTML = '';

    units.forEach(unit => {
        const card = createUnitCard(unit, currentBuilding);
        unitsList.appendChild(card);
    });
}

function createUnitCard(unit, building) {
    const card = document.createElement('div');
    card.className = 'unit-card';

    if (unit.isOwn) card.classList.add('own');
    else if (unit.hasKey) card.classList.add('has-key');
    else if (unit.isRented) card.classList.add('rented');

    const garageIcon = unit.hasGarage ? '<span><i class="fas fa-car"></i> Garage</span>' : '';
    const floorLabel = unit.floor ? `<span><i class="fas fa-layer-group"></i> Floor ${unit.floor}</span>` : '';

    card.innerHTML = `
        <div class="unit-info">
            <span class="name">${unit.label}</span>
            <div class="details">
                <span><i class="fas fa-dollar-sign"></i> $${formatMoney(unit.rent)}/week</span>
                <span><i class="fas fa-coins"></i> $${formatMoney(unit.deposit)} deposit</span>
                ${floorLabel}
                ${garageIcon}
            </div>
        </div>
        <div class="unit-actions">
            ${getUnitActions(unit, building)}
        </div>
    `;

    return card;
}

function getUnitActions(unit, building) {
    if (unit.isOwn) {
        return `
            <span class="unit-status status-own">Your Unit</span>
            <button class="btn btn-primary btn-small" onclick="enterUnit('${building.id}', '${unit.id}')">
                <i class="fas fa-door-open"></i>
            </button>
            <button class="btn btn-secondary btn-small" onclick="manageUnit('${building.id}', '${unit.id}')">
                <i class="fas fa-cog"></i>
            </button>
        `;
    } else if (unit.hasKey) {
        return `
            <span class="unit-status status-key">Key Access</span>
            <button class="btn btn-primary btn-small" onclick="enterUnit('${building.id}', '${unit.id}')">
                <i class="fas fa-door-open"></i>
            </button>
        `;
    } else if (unit.isRented) {
        return `<span class="unit-status status-rented">Occupied</span>`;
    } else {
        return `
            <span class="unit-status status-available">Available</span>
            <button class="btn btn-success btn-small" onclick="showRentModal('${building.id}', '${unit.id}', ${unit.rent}, ${unit.deposit})">
                <i class="fas fa-key"></i> Rent
            </button>
        `;
    }
}

// ============================================
// RENT MODAL
// ============================================

function showRentModal(buildingId, unitId, rent, deposit) {
    const total = rent + deposit;
    const unit = currentUnits.find(u => u.id === unitId);

    // Shell selection HTML
    let shellHTML = '';
    if (shellOptions.length > 1) {
        shellHTML = `
            <p style="margin-bottom: 8px; margin-top: 15px;">Select interior style:</p>
            <div class="shell-options">
                ${shellOptions.map((s, i) => `
                    <div class="shell-option ${i === 0 ? 'selected' : ''}" data-shell="${s.id}" onclick="selectShell(this)">
                        <div class="shell-name">${s.label}</div>
                        <div class="shell-tier">${capitalize(s.tier)}</div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    document.getElementById('confirm-title').textContent = 'Rent ' + unit.label;
    document.getElementById('confirm-message').innerHTML = `
        <div style="margin-bottom: 15px;">
            <p style="margin-bottom: 10px;">First payment: <strong>$${formatMoney(rent)}</strong> (rent)</p>
            <p style="margin-bottom: 10px;">Security deposit: <strong>$${formatMoney(deposit)}</strong></p>
            <p style="font-size: 16px; color: #4ade80;">Total due: <strong>$${formatMoney(total)}</strong></p>
        </div>
        <p style="margin-bottom: 10px;">Select payment method:</p>
        <div class="payment-options">
            <div class="payment-option selected" data-method="cash" onclick="selectPayment(this)">
                <i class="fas fa-money-bill-wave"></i>
                <div class="method-name">Cash</div>
                <div class="method-balance">$${formatMoney(playerMoney.cash)}</div>
            </div>
            <div class="payment-option" data-method="bank" onclick="selectPayment(this)">
                <i class="fas fa-university"></i>
                <div class="method-name">Bank</div>
                <div class="method-balance">$${formatMoney(playerMoney.bank)}</div>
            </div>
        </div>
        ${shellHTML}
    `;

    document.getElementById('confirm-yes').onclick = function() {
        const selectedMethod = document.querySelector('.payment-option.selected').dataset.method;
        const shellEl = document.querySelector('.shell-option.selected');
        const shellVariant = shellEl ? shellEl.dataset.shell : null;
        rentUnit(buildingId, unitId, selectedMethod, shellVariant);
    };

    document.getElementById('confirm-modal').classList.remove('hidden');
}

function selectPayment(element) {
    document.querySelectorAll('.payment-option').forEach(opt => opt.classList.remove('selected'));
    element.classList.add('selected');
}

function selectShell(element) {
    document.querySelectorAll('.shell-option').forEach(opt => opt.classList.remove('selected'));
    element.classList.add('selected');
}

function rentUnit(buildingId, unitId, paymentMethod, shellVariant) {
    closeConfirmModal();
    fetch(`https://sb_apartments/rentUnit`, {
        method: 'POST',
        body: JSON.stringify({
            buildingId: buildingId,
            unitId: unitId,
            paymentMethod: paymentMethod,
            shellVariant: shellVariant
        })
    });
}

// ============================================
// MANAGEMENT VIEW
// ============================================

function openManagementView(unit, rental, keys, isOwner, maxKeys) {
    currentUnit = unit;

    hideAllPanels();
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('management-view').classList.remove('hidden');

    document.getElementById('mgmt-unit-name').textContent = unit.label;
    document.getElementById('mgmt-building-name').textContent = 'Unit Management';

    document.getElementById('mgmt-rent').textContent = '$' + formatMoney(rental.rent_amount);
    document.getElementById('mgmt-deposit').textContent = '$' + formatMoney(rental.deposit_paid);
    document.getElementById('mgmt-next-payment').textContent = formatDate(rental.next_payment);
    document.getElementById('mgmt-missed').textContent = rental.missed_payments || '0';

    const missedEl = document.getElementById('mgmt-missed');
    missedEl.style.color = rental.missed_payments > 0 ? '#ef4444' : '#4ade80';

    document.getElementById('key-count').textContent = keys.length;
    document.getElementById('max-keys').textContent = maxKeys;

    const keysList = document.getElementById('keys-list');
    keysList.innerHTML = '';

    if (keys.length === 0) {
        keysList.innerHTML = '<p style="color: #8b9cb5; font-size: 13px;">No keys given out yet</p>';
    } else {
        keys.forEach(key => {
            const keyItem = document.createElement('div');
            keyItem.className = 'key-item';
            keyItem.innerHTML = `
                <span class="name">${key.name}</span>
                <button class="btn btn-danger btn-small" onclick="revokeKey('${key.citizenid}')">
                    <i class="fas fa-times"></i> Revoke
                </button>
            `;
            keysList.appendChild(keyItem);
        });
    }

    document.getElementById('keys-section').style.display = isOwner ? 'block' : 'none';

    const giveKeyBtn = document.getElementById('give-key-btn');
    giveKeyBtn.disabled = keys.length >= maxKeys;
    giveKeyBtn.style.opacity = keys.length >= maxKeys ? '0.5' : '1';
}

function enterFromMgmt() {
    if (!currentUnit) return;
    fetch(`https://sb_apartments/enterUnit`, {
        method: 'POST',
        body: JSON.stringify({ buildingId: currentUnit.buildingId, unitId: currentUnit.id })
    });
}

function endRental() {
    if (!currentUnit) return;

    document.getElementById('confirm-title').textContent = 'End Rental';
    document.getElementById('confirm-message').innerHTML = `
        <p>Are you sure you want to end your rental of <strong>${currentUnit.label}</strong>?</p>
        <p style="margin-top: 10px; color: #8b9cb5;">Your deposit refund depends on missed payment history.</p>
    `;

    document.getElementById('confirm-yes').onclick = function() {
        closeConfirmModal();
        fetch(`https://sb_apartments/endRental`, {
            method: 'POST',
            body: JSON.stringify({ unitId: currentUnit.id })
        });
    };

    document.getElementById('confirm-modal').classList.remove('hidden');
}

// ============================================
// GARAGE VIEW
// ============================================

function openGarageView(vehicles, unitId) {
    hideAllPanels();
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('garage-view').classList.remove('hidden');

    const garageList = document.getElementById('garage-list');
    garageList.innerHTML = '';

    if (!vehicles || vehicles.length === 0) {
        garageList.innerHTML = '<p style="color: #8b9cb5; text-align: center; padding: 20px;">No vehicles stored</p>';
        return;
    }

    vehicles.forEach(veh => {
        const card = document.createElement('div');
        card.className = 'unit-card';
        card.innerHTML = `
            <div class="unit-info">
                <span class="name">${veh.vehicle || 'Unknown'}</span>
                <div class="details">
                    <span><i class="fas fa-hashtag"></i> ${veh.plate}</span>
                </div>
            </div>
            <div class="unit-actions">
                <button class="btn btn-primary btn-small" onclick="retrieveVehicle('${unitId}', '${veh.plate}')">
                    <i class="fas fa-car"></i> Retrieve
                </button>
            </div>
        `;
        garageList.appendChild(card);
    });
}

function retrieveVehicle(unitId, plate) {
    fetch(`https://sb_apartments/retrieveVehicle`, {
        method: 'POST',
        body: JSON.stringify({ unitId: unitId, plate: plate })
    });
}

// ============================================
// DOORBELL POPUP
// ============================================

function showDoorbellPopup(visitorName, timeout) {
    document.getElementById('doorbell-visitor-name').textContent = visitorName;
    document.getElementById('doorbell-countdown').textContent = timeout;
    document.getElementById('doorbell-popup').classList.remove('hidden');

    let remaining = timeout;
    clearInterval(doorbellTimer);

    doorbellTimer = setInterval(() => {
        remaining--;
        const countdownEl = document.getElementById('doorbell-countdown');
        countdownEl.textContent = remaining;

        // Color transition: green -> yellow -> red
        if (remaining > 10) {
            countdownEl.style.color = '#4ade80';
        } else if (remaining > 5) {
            countdownEl.style.color = '#facc15';
        } else {
            countdownEl.style.color = '#ef4444';
        }

        if (remaining <= 0) {
            hideDoorbellPopup();
        }
    }, 1000);
}

function hideDoorbellPopup() {
    document.getElementById('doorbell-popup').classList.add('hidden');
    clearInterval(doorbellTimer);
    doorbellTimer = null;
}

function acceptDoorbell() {
    hideDoorbellPopup();
    fetch(`https://sb_apartments/acceptVisitor`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function denyDoorbell() {
    hideDoorbellPopup();
    fetch(`https://sb_apartments/denyVisitor`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

// ============================================
// KEY MANAGEMENT
// ============================================

function giveKey() {
    if (!currentUnit) return;
    fetch(`https://sb_apartments/giveKey`, {
        method: 'POST',
        body: JSON.stringify({ unitId: currentUnit.id })
    });
}

function showPlayerSelection(players, unitId) {
    pendingKeyUnit = unitId;
    const playerList = document.getElementById('player-list');
    playerList.innerHTML = '';

    if (players.length === 0) {
        playerList.innerHTML = '<p style="color: #8b9cb5;">No nearby players found</p>';
    } else {
        players.forEach(player => {
            const item = document.createElement('div');
            item.className = 'player-item';
            item.innerHTML = `
                <span>${player.name}</span>
                <button class="btn btn-success btn-small" onclick="confirmGiveKey(${player.id})">
                    <i class="fas fa-key"></i> Give Key
                </button>
            `;
            playerList.appendChild(item);
        });
    }

    document.getElementById('player-modal').classList.remove('hidden');
}

function confirmGiveKey(playerId) {
    closePlayerModal();
    fetch(`https://sb_apartments/confirmGiveKey`, {
        method: 'POST',
        body: JSON.stringify({ unitId: pendingKeyUnit, playerId: playerId })
    });
}

function revokeKey(citizenid) {
    if (!currentUnit) return;
    fetch(`https://sb_apartments/revokeKey`, {
        method: 'POST',
        body: JSON.stringify({ unitId: currentUnit.id, citizenid: citizenid })
    });
    setTimeout(() => {
        manageUnit(currentUnit.buildingId, currentUnit.id);
    }, 500);
}

// ============================================
// UNIT ACTIONS
// ============================================

function enterUnit(buildingId, unitId) {
    fetch(`https://sb_apartments/enterUnit`, {
        method: 'POST',
        body: JSON.stringify({ buildingId: buildingId, unitId: unitId })
    });
}

function manageUnit(buildingId, unitId) {
    fetch(`https://sb_apartments/manageUnit`, {
        method: 'POST',
        body: JSON.stringify({ buildingId: buildingId, unitId: unitId })
    });
}

// ============================================
// UI CONTROLS
// ============================================

function hideAllPanels() {
    document.getElementById('building-view').classList.add('hidden');
    document.getElementById('management-view').classList.add('hidden');
    document.getElementById('garage-view').classList.add('hidden');
    closeConfirmModal();
    closePlayerModal();
}

function closeUI() {
    document.getElementById('app').classList.add('hidden');
    hideAllPanels();
    hideDoorbellPopup();

    fetch(`https://sb_apartments/closeUI`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function closeConfirmModal() {
    document.getElementById('confirm-modal').classList.add('hidden');
}

function closePlayerModal() {
    document.getElementById('player-modal').classList.add('hidden');
    pendingKeyUnit = null;
}

// ============================================
// UTILITIES
// ============================================

function formatMoney(amount) {
    return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}

// ============================================
// KEYBOARD HANDLER
// ============================================

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeUI();
    }
});
