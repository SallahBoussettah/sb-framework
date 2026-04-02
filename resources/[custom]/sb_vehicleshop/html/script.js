/*
    Everyday Chaos RP - Vehicle Shop UI
    Author: Salah Eddine Boussettah
*/

let shopData = {
    dealershipId: null,
    dealershipName: '',
    vehicles: [],
    categories: [],
    cash: 0,
    bank: 0,
    testDriveEnabled: true,
    selectedVehicle: null,
    activeCategory: 'all'
};

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openShop(data);
            break;
        case 'close':
            hideUI();
            break;
        case 'updateMoney':
            shopData.cash = data.cash;
            shopData.bank = data.bank;
            updateMoneyDisplay();
            break;
    }
});

// ============================================================================
// KEYBOARD HANDLER
// ============================================================================

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeShop();
    }
});

// ============================================================================
// SHOP FUNCTIONS
// ============================================================================

function openShop(data) {
    shopData.dealershipId = data.dealershipId;
    shopData.dealershipName = data.dealershipName;
    shopData.vehicles = data.vehicles || [];
    shopData.categories = data.categories || [];
    shopData.cash = data.cash || 0;
    shopData.bank = data.bank || 0;
    shopData.testDriveEnabled = data.testDriveEnabled !== false;
    shopData.selectedVehicle = null;
    shopData.activeCategory = 'all';

    document.getElementById('dealershipName').textContent = shopData.dealershipName;

    renderCategories();
    renderVehicleList();
    updateMoneyDisplay();
    clearVehicleDetails();

    document.getElementById('app').classList.remove('hidden');

    // Re-initialize Lucide icons for dynamic content
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
}

function hideUI() {
    document.getElementById('app').classList.add('hidden');
}

function closeShop() {
    fetch('https://sb_vehicleshop/close', {
        method: 'POST',
        body: JSON.stringify({})
    });
    hideUI();
}

// ============================================================================
// RENDER FUNCTIONS
// ============================================================================

function renderCategories() {
    const container = document.getElementById('categoryList');
    container.innerHTML = '';

    // Add "All" tab
    const allTab = document.createElement('div');
    allTab.className = 'tab active';
    allTab.textContent = 'All';
    allTab.onclick = () => selectCategory('all');
    container.appendChild(allTab);

    // Add configured categories
    shopData.categories.forEach(cat => {
        const tab = document.createElement('div');
        tab.className = 'tab';
        tab.dataset.category = cat.id;
        tab.textContent = cat.label;
        tab.onclick = () => selectCategory(cat.id);
        container.appendChild(tab);
    });
}

function selectCategory(categoryId) {
    shopData.activeCategory = categoryId;

    // Update active state
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
        if ((categoryId === 'all' && !tab.dataset.category) || tab.dataset.category === categoryId) {
            tab.classList.add('active');
        }
    });

    renderVehicleList();
}

function renderVehicleList() {
    const container = document.getElementById('vehicleList');
    container.innerHTML = '';

    const filtered = shopData.activeCategory === 'all'
        ? shopData.vehicles
        : shopData.vehicles.filter(v => v.category === shopData.activeCategory);

    if (filtered.length === 0) {
        container.innerHTML = '<div style="color: var(--sb-text-tertiary); text-align: center; padding: 40px; font-size: 0.85rem;">No vehicles available</div>';
        return;
    }

    filtered.forEach((vehicle, index) => {
        const item = document.createElement('div');
        item.className = 'car-item';
        item.dataset.model = vehicle.model;
        item.style.animationDelay = `${index * 0.05}s`;

        if (shopData.selectedVehicle && shopData.selectedVehicle.model === vehicle.model) {
            item.classList.add('selected');
        }

        item.innerHTML = `
            <div class="car-info">
                <h3>${vehicle.label}</h3>
                <p>${vehicle.brand} &bull; ${capitalizeFirst(vehicle.category)}</p>
            </div>
            <div class="car-price">$${formatNumber(vehicle.price)}</div>
        `;

        item.onclick = () => selectVehicle(vehicle);
        container.appendChild(item);
    });
}

function selectVehicle(vehicle) {
    shopData.selectedVehicle = vehicle;

    // Update selected state in list
    document.querySelectorAll('.car-item').forEach(item => {
        item.classList.remove('selected');
        if (item.dataset.model === vehicle.model) {
            item.classList.add('selected');
        }
    });

    // Show preview
    fetch('https://sb_vehicleshop/preview', {
        method: 'POST',
        body: JSON.stringify({ model: vehicle.model })
    });

    // Show details in selection panel
    renderVehicleDetails(vehicle);

    // Show preview controls
    document.getElementById('previewControls').classList.remove('hidden');

    // Re-initialize Lucide icons for new dynamic content
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
}

function renderVehicleDetails(vehicle) {
    const noSelection = document.getElementById('noSelection');
    const detailsContainer = document.getElementById('vehicleDetails');
    const canAfford = (shopData.cash >= vehicle.price) || (shopData.bank >= vehicle.price);

    noSelection.classList.add('hidden');
    detailsContainer.classList.remove('hidden');

    detailsContainer.innerHTML = `
        <div class="detail-row">
            <span class="detail-label">Selected Model</span>
            <span class="detail-value">${vehicle.label}</span>
        </div>
        <div class="detail-row">
            <span class="detail-label">Brand</span>
            <span class="detail-value">${vehicle.brand}</span>
        </div>
        <div class="detail-row">
            <span class="detail-label">Vehicle Class</span>
            <span class="detail-value">${vehicle.class || capitalizeFirst(vehicle.category)}</span>
        </div>
        <div class="detail-row">
            <span class="detail-label">Price</span>
            <span class="detail-value price">$${formatNumber(vehicle.price)}</span>
        </div>
        <div class="actions">
            ${shopData.testDriveEnabled ? `
                <button class="btn btn-secondary" onclick="startTestDrive()">
                    <i data-lucide="gauge"></i> Test Drive
                </button>
            ` : ''}
            <button class="btn btn-primary" onclick="purchaseVehicle()" ${!canAfford ? 'disabled' : ''}>
                <i data-lucide="shopping-cart"></i> ${canAfford ? 'Buy Now' : 'Not Enough'}
            </button>
        </div>
    `;

    // Re-initialize Lucide icons for the buttons
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
}

function clearVehicleDetails() {
    const noSelection = document.getElementById('noSelection');
    const detailsContainer = document.getElementById('vehicleDetails');

    noSelection.classList.remove('hidden');
    detailsContainer.classList.add('hidden');
    detailsContainer.innerHTML = '';

    document.getElementById('previewControls').classList.add('hidden');
}

function updateMoneyDisplay() {
    document.getElementById('cashAmount').textContent = formatNumber(shopData.cash);
    document.getElementById('bankAmount').textContent = formatNumber(shopData.bank);
}

// ============================================================================
// ACTIONS
// ============================================================================

function purchaseVehicle() {
    if (!shopData.selectedVehicle) return;

    const vehicle = shopData.selectedVehicle;
    let paymentMethod = 'cash';

    if (shopData.cash >= vehicle.price) {
        paymentMethod = 'cash';
    } else if (shopData.bank >= vehicle.price) {
        paymentMethod = 'bank';
    } else {
        return;
    }

    fetch('https://sb_vehicleshop/purchase', {
        method: 'POST',
        body: JSON.stringify({
            model: vehicle.model,
            paymentMethod: paymentMethod
        })
    });
}

function startTestDrive() {
    if (!shopData.selectedVehicle) return;

    fetch('https://sb_vehicleshop/testDrive', {
        method: 'POST',
        body: JSON.stringify({
            model: shopData.selectedVehicle.model
        })
    });
}

function rotatePreview(direction) {
    fetch('https://sb_vehicleshop/rotatePreview', {
        method: 'POST',
        body: JSON.stringify({ direction: direction })
    });
}

// ============================================================================
// UTILITIES
// ============================================================================

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function capitalizeFirst(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}

// ============================================================================
// INIT - Create Lucide icons on page load
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
});
