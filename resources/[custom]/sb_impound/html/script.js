/*
    Everyday Chaos RP - Impound System UI
    Author: Salah Eddine Boussettah
*/

let currentLocation = null;
let currentVehicles = [];
let selectedVehicle = null;

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'openImpound':
            openImpound(data.location, data.vehicles, data.cash, data.bank);
            break;
        case 'closeImpound':
            closeImpound();
            break;
    }
});

// ============================================================================
// KEYBOARD HANDLER
// ============================================================================

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        if (!document.getElementById('confirm-modal').classList.contains('hidden')) {
            closeModal();
        } else {
            closeUI();
        }
    }
});

// ============================================================================
// OPEN/CLOSE FUNCTIONS
// ============================================================================

function openImpound(location, vehicles, cash, bank) {
    currentLocation = location;
    currentVehicles = vehicles || [];

    document.getElementById('location-name').textContent = location.label;
    document.getElementById('cash-display').textContent = '$' + formatNumber(cash || 0);
    document.getElementById('bank-display').textContent = '$' + formatNumber(bank || 0);

    renderVehicles();

    document.getElementById('impound-container').classList.remove('hidden');
    lucide.createIcons();
}

function closeImpound() {
    document.getElementById('impound-container').classList.add('hidden');
    document.getElementById('confirm-modal').classList.add('hidden');
    currentLocation = null;
    currentVehicles = [];
    selectedVehicle = null;
}

function closeUI() {
    fetch('https://sb_impound/closeUI', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// ============================================================================
// RENDER VEHICLES
// ============================================================================

function renderVehicles() {
    const listEl = document.getElementById('vehicles-list');
    const noVehiclesEl = document.getElementById('no-vehicles');

    if (currentVehicles.length === 0) {
        listEl.classList.add('hidden');
        noVehiclesEl.classList.remove('hidden');
        lucide.createIcons();
        return;
    }

    listEl.classList.remove('hidden');
    noVehiclesEl.classList.add('hidden');

    listEl.innerHTML = currentVehicles.map(vehicle => {
        const isDestroyed = vehicle.isDestroyed;
        const statusClass = isDestroyed ? 'status-destroyed' : 'status-impounded';
        const statusText = isDestroyed ? 'Destroyed' : 'Impounded';
        const cardClass = isDestroyed ? 'destroyed' : '';

        const timeSince = vehicle.impound_time ? formatTimeSince(vehicle.impound_time) : 'Unknown';

        return `
            <div class="impound-card ${cardClass}" data-plate="${escapeHtml(vehicle.plate)}">
                <div class="card-header">
                    <div class="car-title">
                        <h3>${escapeHtml(vehicle.vehicle_label || vehicle.vehicle)}</h3>
                        <p>${escapeHtml(formatPlate(vehicle.plate))}</p>
                    </div>
                    <div class="status-badge ${statusClass}">${statusText}</div>
                </div>

                <div class="stats-grid">
                    <div class="stat-item"><i data-lucide="heart"></i> Body: ${Math.round((vehicle.body || 1000) / 10)}%</div>
                    <div class="stat-item"><i data-lucide="settings"></i> Engine: ${Math.round((vehicle.engine || 1000) / 10)}%</div>
                    <div class="stat-item"><i data-lucide="fuel"></i> Fuel: ${Math.round(vehicle.fuel || 0)}%</div>
                    <div class="stat-item"><i data-lucide="clock"></i> ${timeSince}</div>
                </div>

                <div class="reason-box">
                    <i data-lucide="info"></i>
                    ${escapeHtml(vehicle.impound_reason || 'Unknown reason')}
                </div>

                <div class="price-footer">
                    <div class="price-display">
                        <span>Total Release Fee</span>
                        $${formatNumber(vehicle.totalFee)}
                    </div>
                    <button class="btn-retrieve" onclick="showRetrieveModal('${escapeHtml(vehicle.plate)}')">
                        <i data-lucide="key-round"></i> Retrieve
                    </button>
                </div>
            </div>
        `;
    }).join('');

    lucide.createIcons();
}

// ============================================================================
// RETRIEVE MODAL
// ============================================================================

function showRetrieveModal(plate) {
    selectedVehicle = currentVehicles.find(v => v.plate === plate);
    if (!selectedVehicle) return;

    document.getElementById('confirm-vehicle-name').textContent =
        selectedVehicle.vehicle_label || selectedVehicle.vehicle;

    const breakdownEl = document.getElementById('fee-breakdown');
    let breakdownHTML = `
        <div class="fee-row">
            <span>Base Impound Fee</span>
            <span>$${formatNumber(selectedVehicle.baseFee)}</span>
        </div>
    `;

    if (selectedVehicle.destroyedFee > 0) {
        breakdownHTML += `
            <div class="fee-row">
                <span>Destroyed Vehicle Fee</span>
                <span>$${formatNumber(selectedVehicle.destroyedFee)}</span>
            </div>
        `;
    }

    if (selectedVehicle.storageFee > 0) {
        breakdownHTML += `
            <div class="fee-row">
                <span>Storage Fee</span>
                <span>$${formatNumber(selectedVehicle.storageFee)}</span>
            </div>
        `;
    }

    breakdownEl.innerHTML = breakdownHTML;
    document.getElementById('confirm-total-fee').textContent = '$' + formatNumber(selectedVehicle.totalFee);

    document.getElementById('confirm-retrieve-btn').onclick = function() {
        retrieveVehicle(plate);
    };

    document.getElementById('confirm-modal').classList.remove('hidden');
    lucide.createIcons();
}

function closeModal() {
    document.getElementById('confirm-modal').classList.add('hidden');
    selectedVehicle = null;
}

// ============================================================================
// RETRIEVE VEHICLE
// ============================================================================

function retrieveVehicle(plate) {
    const btn = document.getElementById('confirm-retrieve-btn');
    btn.disabled = true;
    btn.innerHTML = '<i data-lucide="loader-2" class="spin-icon"></i> Processing...';
    lucide.createIcons();

    fetch('https://sb_impound/retrieveVehicle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plate: plate })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            closeModal();
        } else {
            btn.disabled = false;
            btn.innerHTML = '<i data-lucide="check"></i> Pay & Retrieve';
            lucide.createIcons();
        }
    })
    .catch(() => {
        btn.disabled = false;
        btn.innerHTML = '<i data-lucide="check"></i> Pay & Retrieve';
        lucide.createIcons();
    });
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function formatPlate(plate) {
    return plate.toUpperCase().replace(/\s+/g, '');
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatTimeSince(timeStr) {
    if (!timeStr) return 'Unknown';

    try {
        const impoundTime = new Date(timeStr);
        const now = new Date();
        const diffMs = now - impoundTime;
        const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
        const diffDays = Math.floor(diffHours / 24);

        if (diffDays > 0) {
            return diffDays + ' day' + (diffDays > 1 ? 's' : '') + ' ago';
        } else if (diffHours > 0) {
            return diffHours + ' hour' + (diffHours > 1 ? 's' : '') + ' ago';
        } else {
            const diffMins = Math.floor(diffMs / (1000 * 60));
            return diffMins + ' min' + (diffMins > 1 ? 's' : '') + ' ago';
        }
    } catch (e) {
        return 'Unknown';
    }
}

// ============================================================================
// INIT
// ============================================================================

document.addEventListener('DOMContentLoaded', function() {
    lucide.createIcons();
});
