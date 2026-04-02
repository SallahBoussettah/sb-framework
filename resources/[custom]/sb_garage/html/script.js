/*
    Everyday Chaos RP - Garage System UI
    Author: Salah Eddine Boussettah
*/

let garageData = {
    garageName: '',
    garageId: '',
    vehicles: [],
    stats: {},
    transferFee: 500,
    maxVehicles: 10,
    cash: 0,
    bank: 0
};

let currentTab = 'this-garage';

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openGarage(data);
            break;
        case 'close':
            closeGarage();
            break;
    }
});

// ============================================================================
// OPEN / CLOSE
// ============================================================================

function openGarage(data) {
    garageData = {
        garageName: data.garageName || 'Garage',
        garageId: data.garageId || '',
        vehicles: data.vehicles || [],
        stats: data.stats || {},
        transferFee: data.transferFee || 500,
        maxVehicles: data.maxVehicles || 10,
        cash: data.cash || 0,
        bank: data.bank || 0
    };

    document.getElementById('garage-name').textContent = garageData.garageName;
    document.getElementById('cash-display').textContent = '$' + formatNumber(garageData.cash);
    document.getElementById('bank-display').textContent = '$' + formatNumber(garageData.bank);

    // Reset to first tab
    currentTab = 'this-garage';
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector('.tab[data-tab="this-garage"]').classList.add('active');

    updateStats();
    renderVehicles();

    document.getElementById('garage-container').classList.remove('hidden');
    lucide.createIcons();
}

function closeGarage() {
    document.getElementById('garage-container').classList.add('hidden');
    fetch('https://sb_garage/close', {
        method: 'POST',
        body: JSON.stringify({})
    });
}

// ============================================================================
// TAB SWITCHING
// ============================================================================

document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', function() {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        this.classList.add('active');
        currentTab = this.dataset.tab;
        renderVehicles();
    });
});

// ============================================================================
// RENDER VEHICLES
// ============================================================================

function renderVehicles() {
    const list = document.getElementById('vehicle-list');
    const emptyState = document.getElementById('empty-state');

    let vehiclesToShow = garageData.vehicles;

    if (currentTab === 'this-garage') {
        vehiclesToShow = garageData.vehicles.filter(v => v.garage === garageData.garageId);
    }

    if (vehiclesToShow.length === 0) {
        list.classList.add('hidden');
        emptyState.classList.remove('hidden');
        lucide.createIcons();
        return;
    }

    list.classList.remove('hidden');
    emptyState.classList.add('hidden');

    list.innerHTML = vehiclesToShow.map(vehicle => createVehicleCard(vehicle)).join('');
    lucide.createIcons();
}

function createVehicleCard(vehicle) {
    const isDifferentGarage = vehicle.garage !== garageData.garageId;
    const bodyPercent = Math.round((vehicle.body / 1000) * 100);
    const enginePercent = Math.round((vehicle.engine / 1000) * 100);
    const fuelPercent = Math.round(vehicle.fuel || 0);

    const bodyClass = bodyPercent >= 70 ? 'good' : bodyPercent >= 40 ? 'warning' : 'danger';
    const engineClass = enginePercent >= 70 ? 'good' : enginePercent >= 40 ? 'warning' : 'danger';

    const garageLabel = getGarageLabel(vehicle.garage);

    return `
        <div class="vehicle-card ${isDifferentGarage ? 'different-garage' : ''}">
            <div class="card-header">
                <div>
                    <h3>${escapeHtml(vehicle.vehicle_label || vehicle.vehicle)}</h3>
                    <span class="vehicle-location">@ ${escapeHtml(garageLabel)}</span>
                    ${isDifferentGarage ? `<div class="transfer-fee">Transfer: $${formatNumber(garageData.transferFee)}</div>` : ''}
                </div>
                <div class="plate-badge">${escapeHtml(vehicle.plate)}</div>
            </div>

            <div class="status-container">
                <div class="status-row">
                    <span class="status-label">Body</span>
                    <div class="progress-bg"><div class="progress-fill ${bodyClass}" style="width: ${bodyPercent}%"></div></div>
                    <span class="status-value">${bodyPercent}%</span>
                </div>
                <div class="status-row">
                    <span class="status-label">Engine</span>
                    <div class="progress-bg"><div class="progress-fill ${engineClass}" style="width: ${enginePercent}%"></div></div>
                    <span class="status-value">${enginePercent}%</span>
                </div>
                <div class="status-row">
                    <span class="status-label">Fuel</span>
                    <div class="progress-bg"><div class="progress-fill fuel" style="width: ${fuelPercent}%"></div></div>
                    <span class="status-value">${fuelPercent}%</span>
                </div>
            </div>

            <button class="btn-retrieve ${isDifferentGarage ? 'transfer' : ''}" onclick="retrieveVehicle('${escapeHtml(vehicle.plate)}')">
                <i data-lucide="key-round"></i>
                ${isDifferentGarage ? `Retrieve ($${formatNumber(garageData.transferFee)})` : 'Retrieve Vehicle'}
            </button>
        </div>
    `;
}

// ============================================================================
// UPDATE STATS
// ============================================================================

function updateStats() {
    const stats = garageData.stats;
    document.getElementById('garage-stats').innerHTML =
        `Stored: <b>${stats.thisGarage || 0}/${stats.maxPerGarage || garageData.maxVehicles}</b>`;
    document.getElementById('total-stats').innerHTML =
        `Total Stored: <b>${stats.totalStored || 0}</b>`;
}

// ============================================================================
// RETRIEVE VEHICLE
// ============================================================================

function retrieveVehicle(plate) {
    document.querySelectorAll('.btn-retrieve').forEach(btn => {
        btn.disabled = true;
    });

    fetch('https://sb_garage/retrieve', {
        method: 'POST',
        body: JSON.stringify({ plate: plate })
    })
    .then(response => response.json())
    .then(data => {
        if (!data.success) {
            document.querySelectorAll('.btn-retrieve').forEach(btn => {
                btn.disabled = false;
            });
        }
    })
    .catch(() => {
        document.querySelectorAll('.btn-retrieve').forEach(btn => {
            btn.disabled = false;
        });
    });
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function getGarageLabel(garageId) {
    const garageLabels = {
        'legion': 'Legion Square',
        'pillbox': 'Pillbox Hill',
        'airport': 'Airport',
        'sandy': 'Sandy Shores',
        'paleto': 'Paleto Bay'
    };
    return garageLabels[garageId] || garageId;
}

// ============================================================================
// KEYBOARD HANDLER
// ============================================================================

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeGarage();
    }
});

// Initialize Lucide icons on load
document.addEventListener('DOMContentLoaded', function() {
    lucide.createIcons();
});
