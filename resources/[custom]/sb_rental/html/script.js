/*
    Everyday Chaos RP - Vehicle Rental UI
    Author: Salah Eddine Boussettah
*/

let vehicles = [];
let categories = [];
let categoryLabels = {};
let maxDays = 7;
let selectedVehicle = null;
let selectedDays = 1;
let activeCategory = null;

// Lucide icon names per category
const categoryIcons = {
    bicycle: 'bike',
    scooter: 'zap',
    car: 'car'
};

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openTerminal(data);
            break;
        case 'close':
            closeTerminal();
            break;
        case 'updateMoney':
            updateMoney(data.cash, data.bank);
            break;
    }
});

// ============================================================================
// KEYBOARD HANDLER
// ============================================================================

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeUI();
    }
});

// ============================================================================
// OPEN / CLOSE
// ============================================================================

function openTerminal(data) {
    document.getElementById('location-name').textContent = data.locationLabel || 'Vehicle Rentals';
    vehicles = data.vehicles || [];
    categories = data.categories || [];
    categoryLabels = data.categoryLabels || {};
    maxDays = data.maxDays || 7;

    selectedVehicle = null;
    selectedDays = 1;
    activeCategory = categories[0] || null;

    updateMoney(data.cash || 0, data.bank || 0);
    renderCategoryTabs();
    renderVehicleList();
    showPlaceholder();

    document.getElementById('rental-container').classList.remove('hidden');
    lucide.createIcons();
}

function closeTerminal() {
    document.getElementById('rental-container').classList.add('hidden');
    selectedVehicle = null;
    selectedDays = 1;
}

function closeUI() {
    fetch('https://sb_rental/close', {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function updateMoney(cash, bank) {
    document.getElementById('cash-display').textContent = '$' + formatNumber(cash || 0);
    document.getElementById('bank-display').textContent = '$' + formatNumber(bank || 0);
}

// ============================================================================
// RENDER CATEGORIES
// ============================================================================

function renderCategoryTabs() {
    const container = document.getElementById('category-tabs');
    container.innerHTML = '';

    categories.forEach(cat => {
        const tab = document.createElement('button');
        tab.className = 'tab' + (cat === activeCategory ? ' active' : '');
        const iconName = categoryIcons[cat] || 'car';
        tab.innerHTML = `<i data-lucide="${iconName}"></i> ${categoryLabels[cat] || cat}`;
        tab.addEventListener('click', () => {
            activeCategory = cat;
            selectedVehicle = null;
            selectedDays = 1;
            renderCategoryTabs();
            renderVehicleList();
            showPlaceholder();
            lucide.createIcons();
        });
        container.appendChild(tab);
    });

    lucide.createIcons();
}

// ============================================================================
// RENDER VEHICLE LIST
// ============================================================================

function renderVehicleList() {
    const list = document.getElementById('vehicle-list');
    const emptyState = document.getElementById('empty-state');

    const filtered = vehicles.filter(v => v.category === activeCategory);

    if (filtered.length === 0) {
        list.classList.add('hidden');
        emptyState.classList.remove('hidden');
        lucide.createIcons();
        return;
    }

    list.classList.remove('hidden');
    emptyState.classList.add('hidden');

    list.innerHTML = filtered.map(vehicle => {
        const isSelected = selectedVehicle && selectedVehicle.model === vehicle.model;
        const catLabel = categoryLabels[vehicle.category] || vehicle.category;

        // Image or fallback icon
        const imageHtml = vehicle.image
            ? `<img src="images/${vehicle.image}" alt="${escapeHtml(vehicle.label)}" onerror="this.parentElement.innerHTML='<i data-lucide=\\'${categoryIcons[vehicle.category] || 'car'}\\' class=\\'fallback-icon\\'></i>'">`
            : `<i data-lucide="${categoryIcons[vehicle.category] || 'car'}" class="fallback-icon"></i>`;

        return `
            <div class="rental-card ${isSelected ? 'selected' : ''}" data-model="${escapeHtml(vehicle.model)}">
                <div class="card-image">
                    ${imageHtml}
                </div>
                <div class="card-info">
                    <h3>${escapeHtml(vehicle.label)}</h3>
                    <p>${escapeHtml(catLabel)}</p>
                </div>
                <div class="card-price">
                    $${vehicle.daily}
                    <span>Per Day</span>
                </div>
            </div>
        `;
    }).join('');

    // Add click listeners
    list.querySelectorAll('.rental-card').forEach(card => {
        card.addEventListener('click', () => {
            const model = card.dataset.model;
            const vehicle = filtered.find(v => v.model === model);
            if (vehicle) selectVehicle(vehicle);
        });
    });

    lucide.createIcons();
}

// ============================================================================
// VEHICLE SELECTION
// ============================================================================

function selectVehicle(vehicle) {
    selectedVehicle = vehicle;
    selectedDays = 1;

    // Update selected state in list
    document.querySelectorAll('.rental-card').forEach(card => {
        card.classList.remove('selected');
        if (card.dataset.model === vehicle.model) {
            card.classList.add('selected');
        }
    });

    renderSummary();
}

function showPlaceholder() {
    document.getElementById('summary-panel').classList.add('hidden');
    document.getElementById('no-selection').classList.remove('hidden');
    lucide.createIcons();
}

// ============================================================================
// RENDER SUMMARY
// ============================================================================

function renderSummary() {
    if (!selectedVehicle) {
        showPlaceholder();
        return;
    }

    document.getElementById('no-selection').classList.add('hidden');
    document.getElementById('summary-panel').classList.remove('hidden');

    document.getElementById('sel-name').textContent = selectedVehicle.label;
    document.getElementById('sel-daily').textContent = '$' + selectedVehicle.daily;

    // Duration buttons
    const durationContainer = document.getElementById('duration-buttons');
    durationContainer.innerHTML = '';
    for (let i = 1; i <= maxDays; i++) {
        const btn = document.createElement('button');
        btn.className = 'duration-btn' + (i === selectedDays ? ' active' : '');
        btn.textContent = i;
        btn.addEventListener('click', () => {
            selectedDays = i;
            renderSummary();
        });
        durationContainer.appendChild(btn);
    }

    // Total
    const total = selectedVehicle.daily * selectedDays;
    document.getElementById('sel-total').textContent = '$' + formatNumber(total);

    // Return date
    document.getElementById('return-date').textContent = calculateReturnDate(selectedDays);

    // Rent button
    const rentBtn = document.getElementById('rent-btn');
    rentBtn.onclick = rentVehicle;
    rentBtn.disabled = false;
    rentBtn.innerHTML = `<i data-lucide="check-circle"></i> Confirm Rental - $${formatNumber(total)}`;

    lucide.createIcons();
}

// ============================================================================
// RENT VEHICLE
// ============================================================================

function rentVehicle() {
    if (!selectedVehicle || !selectedDays) return;

    const rentBtn = document.getElementById('rent-btn');
    rentBtn.disabled = true;
    rentBtn.innerHTML = '<i data-lucide="loader-2"></i> Processing...';
    lucide.createIcons();

    fetch('https://sb_rental/rent', {
        method: 'POST',
        body: JSON.stringify({
            vehicle: selectedVehicle.model,
            days: selectedDays
        })
    }).then(response => response.json()).then(data => {
        if (!data.success) {
            rentBtn.disabled = false;
            const total = selectedVehicle.daily * selectedDays;
            rentBtn.innerHTML = `<i data-lucide="check-circle"></i> Confirm Rental - $${formatNumber(total)}`;
            lucide.createIcons();
        }
    }).catch(() => {
        rentBtn.disabled = false;
        const total = selectedVehicle.daily * selectedDays;
        rentBtn.innerHTML = `<i data-lucide="check-circle"></i> Confirm Rental - $${formatNumber(total)}`;
        lucide.createIcons();
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

function calculateReturnDate(days) {
    const realMinutes = days * 48;
    const returnTime = new Date(Date.now() + realMinutes * 60 * 1000);

    const options = {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
    };

    return returnTime.toLocaleDateString('en-US', options);
}

// ============================================================================
// INIT
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons();
});
