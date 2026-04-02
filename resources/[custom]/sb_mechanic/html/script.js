/* ============================================================================
   sb_mechanic - NUI Script
   Mode switching, vehicle data display, fetchNUI calls, billing laptop
   ============================================================================ */

// State
let currentMode = null;
let vehicleData = null;
let pricing = {};
let wheelTypes = [];
let gtaColors = [];
let windowTints = [];
let xenonColors = [];
let horns = [];
let plateStyles = [];
let modLabels = {};

// Billing state
let billingVehicles = [];
let selectedBillingPlate = null;
let currentInvoicePlate = null;

// Selected state for body page
let currentColorSlot = 'primary';
let selectedWheelType = 0;
let selectedWheelIndex = -1;

// ============================================================================
// FETCH NUI
// ============================================================================

function fetchNUI(name, data = {}) {
    return fetch(`https://sb_mechanic/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(r => r.json()).catch(() => null);
}

// ============================================================================
// MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (e) => {
    const data = e.data;

    switch (data.action) {
        case 'open':
            openDashboard(data);
            break;
        case 'close':
            closeDashboard();
            break;
        case 'updateVehicle':
            vehicleData = data.vehicle;
            refreshCurrentPage();
            break;
        case 'setWorking':
            setWorkingState(data.working);
            break;
        case 'openBilling':
            openBilling(data);
            break;
        case 'closeBilling':
            closeBilling();
            break;
        case 'refreshBilling':
            billingVehicles = data.vehicles || [];
            renderBillingVehicles();
            break;
        case 'showCustomerInvoice':
            showCustomerInvoice(data);
            break;
        case 'hideCustomerInvoice':
            hideCustomerInvoice();
            break;
    }
});

// ============================================================================
// OPEN / CLOSE STATION DASHBOARD
// ============================================================================

function openDashboard(data) {
    currentMode = data.mode;
    vehicleData = data.vehicle;
    pricing = data.pricing || {};
    wheelTypes = data.wheelTypes || [];
    gtaColors = data.gtaColors || [];
    windowTints = data.windowTints || [];
    xenonColors = data.xenonColors || [];
    horns = data.horns || [];
    plateStyles = data.plateStyles || [];
    modLabels = data.modLabels || {};

    // Set header
    document.getElementById('station-title').textContent = data.stationLabel || 'Station';
    document.getElementById('vehicle-label').textContent =
        vehicleData ? `${vehicleData.label} [${vehicleData.plate}]` : 'No Vehicle';

    // Set pricing labels
    setPricingLabels();

    // Show correct page
    showPage(currentMode);

    // Show app
    document.getElementById('app').classList.remove('hidden');
}

function closeDashboard() {
    document.getElementById('app').classList.add('hidden');
    currentMode = null;
    vehicleData = null;
}

function setPricingLabels() {
    const map = {
        'price-engine-repair': pricing.engineRepair,
        'price-body-repair': pricing.bodyRepair,
        'price-custom-rgb': pricing.customRGB,
        'price-neon': pricing.neonKit,
        'price-tint': pricing.windowTint,
        'price-xenon': pricing.xenonLights,
        'price-horn': pricing.horn,
        'price-plate': pricing.plateStyle,
        'price-interior': pricing.interiorColor,
        'price-dashboard': pricing.dashboardColor,
        'price-wash': pricing.wash,
        'price-wheels': pricing.wheelSet,
    };

    for (const [cls, val] of Object.entries(map)) {
        document.querySelectorAll('.' + cls).forEach(el => {
            el.textContent = val || '0';
        });
    }
}

// ============================================================================
// PAGE SWITCHING
// ============================================================================

function showPage(mode) {
    document.querySelectorAll('.page').forEach(p => p.classList.add('hidden'));
    const page = document.getElementById('page-' + mode);
    if (page) {
        page.classList.remove('hidden');
        populatePage(mode);
    }
}

function refreshCurrentPage() {
    if (currentMode) {
        populatePage(currentMode);
    }
}

function populatePage(mode) {
    switch (mode) {
        case 'engine': populateEngine(); break;
        case 'body': populateBody(); break;
        case 'wheels': populateWheels(); break;
        case 'cosmetic': populateCosmetic(); break;
    }
}

// ============================================================================
// ENGINE PAGE
// ============================================================================

function populateEngine() {
    if (!vehicleData) return;

    // Health bars
    const enginePct = Math.max(0, vehicleData.engineHealth) / 10;
    const bodyPct = Math.max(0, vehicleData.bodyHealth) / 10;

    document.getElementById('engine-health-fill').style.width = enginePct + '%';
    document.getElementById('engine-health-fill').style.background = getHealthColor(enginePct);
    document.getElementById('engine-health-text').textContent = `${Math.max(0, vehicleData.engineHealth)} / 1000`;

    document.getElementById('body-health-fill').style.width = bodyPct + '%';
    document.getElementById('body-health-fill').style.background = getHealthColor(bodyPct);
    document.getElementById('body-health-text').textContent = `${Math.max(0, vehicleData.bodyHealth)} / 1000`;

    // Upgrade grid
    const grid = document.getElementById('upgrade-grid');
    grid.innerHTML = '';

    // Performance mods
    const upgrades = [
        { modType: 11, label: 'Engine', icon: 'fa-solid fa-engine', price: pricing.engineUpgrade },
        { modType: 18, label: 'Turbo', icon: 'fa-solid fa-bolt', price: pricing.turbo, toggle: true },
        { modType: 12, label: 'Brakes', icon: 'fa-solid fa-gauge', price: pricing.brakes },
        { modType: 13, label: 'Transmission', icon: 'fa-solid fa-gears', price: pricing.transmission },
        { modType: 15, label: 'Suspension', icon: 'fa-solid fa-car-side', price: pricing.suspension },
        { modType: 16, label: 'Armor', icon: 'fa-solid fa-shield', price: pricing.armor },
    ];

    for (const upg of upgrades) {
        const card = document.createElement('div');
        card.className = 'upgrade-card';

        if (upg.toggle) {
            // Turbo toggle
            const isOn = vehicleData.turbo;
            card.innerHTML = `
                <div class="upgrade-card-header">
                    <i class="${upg.icon}"></i>
                    <span>${upg.label}</span>
                </div>
                <div class="upgrade-level">Status: <span class="current">${isOn ? 'Installed' : 'Not Installed'}</span></div>
                <button class="btn btn-sm btn-primary" data-upgrade-toggle="18" data-toggle-val="${!isOn}" ${isOn ? 'disabled' : ''}>
                    ${isOn ? 'Already Installed' : `Install — $${upg.price}`}
                </button>
            `;
        } else {
            const modData = vehicleData.mods[String(upg.modType)];
            const current = modData ? modData.current + 1 : 0; // -1 = stock = level 0
            const max = modData ? modData.max + 1 : 0;
            const atMax = current > max || !modData || max === 0;

            let pipsHtml = '';
            for (let i = 0; i < Math.max(max + 1, 1); i++) {
                pipsHtml += `<div class="pip ${i <= current ? 'filled' : ''}"></div>`;
            }

            card.innerHTML = `
                <div class="upgrade-card-header">
                    <i class="${upg.icon}"></i>
                    <span>${upg.label}</span>
                </div>
                <div class="upgrade-level">Level: <span class="current">${current}</span> / ${max + 1}</div>
                <div class="level-pips">${pipsHtml}</div>
                <button class="btn btn-sm btn-primary" data-upgrade-mod="${upg.modType}" data-mod-index="${current}" ${atMax ? 'disabled' : ''}>
                    ${atMax ? 'Max Level' : `Upgrade — $${upg.price}`}
                </button>
            `;
        }

        grid.appendChild(card);
    }
}

function getHealthColor(pct) {
    if (pct > 60) return 'var(--success)';
    if (pct > 30) return 'var(--yellow)';
    return 'var(--danger)';
}

// ============================================================================
// BODY PAGE
// ============================================================================

function populateBody() {
    if (!vehicleData) return;
    populateColorGrid();
    populateLiveryGrid();
}

function populateColorGrid() {
    const grid = document.getElementById('color-grid');
    grid.innerHTML = '';

    for (const color of gtaColors) {
        const swatch = document.createElement('div');
        swatch.className = 'color-swatch';
        swatch.style.background = color.hex;
        swatch.title = color.label;

        // Mark selected
        let currentId = -999;
        if (currentColorSlot === 'primary') currentId = vehicleData.colors.primary;
        else if (currentColorSlot === 'secondary') currentId = vehicleData.colors.secondary;
        else if (currentColorSlot === 'pearlescent') currentId = vehicleData.colors.pearlescent;

        if (color.id === currentId) {
            swatch.classList.add('selected');
        }

        swatch.addEventListener('click', () => {
            // Preview
            fetchNUI('previewColor', { slot: currentColorSlot, colorId: color.id });

            // Update selection
            grid.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
            swatch.classList.add('selected');
        });

        grid.appendChild(swatch);
    }

    // Double-click to apply
    grid.querySelectorAll('.color-swatch').forEach(swatch => {
        swatch.addEventListener('dblclick', () => {
            const colorId = gtaColors.find(c => c.hex === swatch.style.background)?.id;
            applyColorFromGrid(colorId);
        });
    });
}

function applyColorFromGrid(colorId) {
    if (colorId == null) return;
    fetchNUI('applyColor', { slot: currentColorSlot, colorId: colorId });
}

function populateLiveryGrid() {
    const grid = document.getElementById('livery-grid');
    grid.innerHTML = '';

    if (!vehicleData || vehicleData.numLiveries <= 0) {
        grid.innerHTML = '<p class="text-muted">No liveries available</p>';
        return;
    }

    for (let i = 0; i < vehicleData.numLiveries; i++) {
        const item = document.createElement('div');
        item.className = 'livery-item' + (vehicleData.livery === i ? ' selected' : '');
        item.textContent = `Livery ${i + 1}`;
        item.addEventListener('click', () => {
            fetchNUI('previewLivery', { liveryId: i });
            grid.querySelectorAll('.livery-item').forEach(l => l.classList.remove('selected'));
            item.classList.add('selected');
        });
        item.addEventListener('dblclick', () => {
            fetchNUI('applyCosmetic', { cosmeticType: 'livery', value: i });
        });
        grid.appendChild(item);
    }
}

// ============================================================================
// WHEELS PAGE
// ============================================================================

function populateWheels() {
    if (!vehicleData) return;

    selectedWheelType = vehicleData.wheelType || 0;
    selectedWheelIndex = vehicleData.frontWheels || -1;

    populateTireGrid();
    populateWheelTypes();
    populateWheelStyles();
}

function populateTireGrid() {
    const grid = document.getElementById('tire-grid');
    grid.innerHTML = '';

    const tireNames = ['Front Left', 'Front Right', 'Rear Left', 'Rear Right', 'Mid Left', 'Mid Right'];

    for (let i = 0; i < 6; i++) {
        const burst = vehicleData.tyresBurst[String(i)] || false;
        const item = document.createElement('div');
        item.className = 'tire-item';
        item.innerHTML = `
            <div class="tire-icon"><i class="fa-solid fa-circle-dot" style="color: ${burst ? 'var(--danger)' : 'var(--success)'}"></i></div>
            <div class="tire-label">${tireNames[i]}</div>
            <div class="tire-status ${burst ? 'burst' : 'ok'}">${burst ? 'BURST' : 'OK'}</div>
            ${burst ? `<button class="btn btn-sm btn-primary" data-tire-repair="${i}">Fix — $${pricing.tireRepair || 0}</button>` : ''}
        `;
        grid.appendChild(item);
    }
}

function populateWheelTypes() {
    const row = document.getElementById('wheel-type-row');
    row.innerHTML = '';

    for (const wt of wheelTypes) {
        const btn = document.createElement('button');
        btn.className = 'wheel-type-btn' + (wt.id === selectedWheelType ? ' active' : '');
        btn.textContent = wt.label;
        btn.addEventListener('click', () => {
            selectedWheelType = wt.id;
            row.querySelectorAll('.wheel-type-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            fetchNUI('previewWheels', { wheelType: wt.id });
            populateWheelStyles();
        });
        row.appendChild(btn);
    }
}

function populateWheelStyles() {
    const scroller = document.getElementById('wheel-style-scroller');
    scroller.innerHTML = '';

    const count = vehicleData.numFrontWheels || 20;

    for (let i = -1; i < count; i++) {
        const item = document.createElement('div');
        item.className = 'wheel-style-item' + (i === selectedWheelIndex ? ' selected' : '');
        item.innerHTML = `
            <div class="wheel-num">${i === -1 ? 'S' : i}</div>
            <div class="wheel-label">${i === -1 ? 'Stock' : 'Style ' + i}</div>
        `;
        item.addEventListener('click', () => {
            selectedWheelIndex = i;
            scroller.querySelectorAll('.wheel-style-item').forEach(s => s.classList.remove('selected'));
            item.classList.add('selected');
            fetchNUI('previewWheels', { wheelType: selectedWheelType, wheelIndex: i });
        });
        scroller.appendChild(item);
    }
}

// ============================================================================
// COSMETIC PAGE
// ============================================================================

function populateCosmetic() {
    if (!vehicleData) return;

    // Neon state
    document.getElementById('neon-left').checked = vehicleData.neonEnabled[0] || false;
    document.getElementById('neon-right').checked = vehicleData.neonEnabled[1] || false;
    document.getElementById('neon-front').checked = vehicleData.neonEnabled[2] || false;
    document.getElementById('neon-back').checked = vehicleData.neonEnabled[3] || false;

    if (vehicleData.neonColor) {
        document.getElementById('neon-r').value = vehicleData.neonColor[0] || 255;
        document.getElementById('neon-g').value = vehicleData.neonColor[1] || 107;
        document.getElementById('neon-b').value = vehicleData.neonColor[2] || 53;
        document.getElementById('neon-r-val').textContent = vehicleData.neonColor[0] || 255;
        document.getElementById('neon-g-val').textContent = vehicleData.neonColor[1] || 107;
        document.getElementById('neon-b-val').textContent = vehicleData.neonColor[2] || 53;
    }

    // Window tint
    const tintSelect = document.getElementById('tint-select');
    tintSelect.innerHTML = '';
    for (const t of windowTints) {
        const opt = document.createElement('option');
        opt.value = t.id;
        opt.textContent = t.label;
        if (t.id === vehicleData.windowTint) opt.selected = true;
        tintSelect.appendChild(opt);
    }

    // Xenon
    document.getElementById('xenon-toggle').checked = vehicleData.xenon || false;
    const xenonSelect = document.getElementById('xenon-color-select');
    xenonSelect.innerHTML = '';
    for (const x of xenonColors) {
        const opt = document.createElement('option');
        opt.value = x.id;
        opt.textContent = x.label;
        if (x.id === vehicleData.xenonColor) opt.selected = true;
        xenonSelect.appendChild(opt);
    }

    // Horn
    const hornSelect = document.getElementById('horn-select');
    hornSelect.innerHTML = '';
    for (const h of horns) {
        const opt = document.createElement('option');
        opt.value = h.id;
        opt.textContent = h.label;
        if (h.id === vehicleData.horn) opt.selected = true;
        hornSelect.appendChild(opt);
    }

    // Plate style
    const plateSelect = document.getElementById('plate-select');
    plateSelect.innerHTML = '';
    for (const p of plateStyles) {
        const opt = document.createElement('option');
        opt.value = p.id;
        opt.textContent = p.label;
        if (p.id === vehicleData.plateIndex) opt.selected = true;
        plateSelect.appendChild(opt);
    }

    // Extras
    const extrasGrid = document.getElementById('extras-grid');
    extrasGrid.innerHTML = '';
    const extras = vehicleData.extras || {};
    const extraKeys = Object.keys(extras);
    if (extraKeys.length === 0) {
        extrasGrid.innerHTML = '<p class="text-muted">No extras available</p>';
    } else {
        for (const key of extraKeys) {
            const isOn = extras[key];
            const toggle = document.createElement('div');
            toggle.className = 'extra-toggle' + (isOn ? ' active' : '');
            toggle.textContent = `Extra ${parseInt(key) + 1}`;
            toggle.addEventListener('click', () => {
                const newState = !toggle.classList.contains('active');
                toggle.classList.toggle('active');
                fetchNUI('previewExtra', { extraId: parseInt(key), enabled: newState });
            });
            extrasGrid.appendChild(toggle);
        }
    }

    // Interior & Dashboard color grids
    populateSmallColorGrid('interior-color-grid', vehicleData.colors.interior, 'previewInteriorColor');
    populateSmallColorGrid('dashboard-color-grid', vehicleData.colors.dashboard, 'previewDashboardColor');
}

function populateSmallColorGrid(gridId, currentId, previewCallback) {
    const grid = document.getElementById(gridId);
    grid.innerHTML = '';

    // Use first 20 colors for interior/dashboard
    const subset = gtaColors.slice(0, 20);
    for (const color of subset) {
        const swatch = document.createElement('div');
        swatch.className = 'color-swatch' + (color.id === currentId ? ' selected' : '');
        swatch.style.background = color.hex;
        swatch.title = color.label;
        swatch.addEventListener('click', () => {
            grid.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
            swatch.classList.add('selected');
            fetchNUI(previewCallback, { colorId: color.id });
        });
        grid.appendChild(swatch);
    }
}

// ============================================================================
// WORKING STATE (disable buttons during animation)
// ============================================================================

function setWorkingState(working) {
    const app = document.getElementById('app');
    if (!app) return;

    // Disable/enable all action buttons
    const buttons = app.querySelectorAll('button, .btn');
    buttons.forEach(btn => {
        if (working) {
            btn.dataset.wasDisabled = btn.disabled ? 'true' : 'false';
            btn.disabled = true;
        } else {
            // Only re-enable buttons that weren't already disabled
            if (btn.dataset.wasDisabled === 'false') {
                btn.disabled = false;
            }
            delete btn.dataset.wasDisabled;
        }
    });

    // Disable/enable selects and inputs
    const inputs = app.querySelectorAll('select, input');
    inputs.forEach(input => {
        if (working) {
            input.dataset.wasDisabled = input.disabled ? 'true' : 'false';
            input.disabled = true;
        } else {
            if (input.dataset.wasDisabled === 'false') {
                input.disabled = false;
            }
            delete input.dataset.wasDisabled;
        }
    });

    // Show/hide working overlay
    let overlay = document.getElementById('working-overlay');
    if (working) {
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'working-overlay';
            overlay.innerHTML = `
                <div class="working-content">
                    <i class="fa-solid fa-wrench fa-spin"></i>
                    <span>Working...</span>
                </div>
            `;
            app.appendChild(overlay);
        }
        overlay.classList.remove('hidden');
    } else {
        if (overlay) {
            overlay.classList.add('hidden');
        }
    }
}

// ============================================================================
// BILLING LAPTOP
// ============================================================================

function openBilling(data) {
    billingVehicles = data.vehicles || [];
    selectedBillingPlate = null;
    renderBillingVehicles();

    // Reset detail panel
    document.getElementById('billing-detail-content').classList.add('hidden');
    document.querySelector('.billing-detail-empty').classList.remove('hidden');

    document.getElementById('billing-app').classList.remove('hidden');
}

function closeBilling() {
    document.getElementById('billing-app').classList.add('hidden');
    billingVehicles = [];
    selectedBillingPlate = null;
}

function renderBillingVehicles() {
    const container = document.getElementById('billing-vehicles');
    container.innerHTML = '';

    if (billingVehicles.length === 0) {
        container.innerHTML = '<p class="text-muted">No unpaid vehicles</p>';
        return;
    }

    for (const veh of billingVehicles) {
        const card = document.createElement('div');
        card.className = 'billing-vehicle-card' + (veh.plate === selectedBillingPlate ? ' active' : '');
        card.innerHTML = `
            <div class="vehicle-plate">${veh.plate}</div>
            <div class="vehicle-owner">${veh.ownerName}</div>
            <div class="vehicle-meta">
                <span class="vehicle-services">${veh.services} service${veh.services > 1 ? 's' : ''}</span>
                <span class="vehicle-total">$${Number(veh.total).toLocaleString()}</span>
            </div>
        `;
        card.addEventListener('click', () => {
            selectedBillingPlate = veh.plate;
            // Highlight active
            container.querySelectorAll('.billing-vehicle-card').forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            // Fetch worklog
            loadVehicleWorklog(veh.plate, veh.ownerName, veh.total);
        });
        container.appendChild(card);
    }
}

function loadVehicleWorklog(plate, ownerName, total) {
    fetchNUI('selectVehicle', { plate: plate }).then(worklog => {
        if (!worklog) worklog = [];

        document.querySelector('.billing-detail-empty').classList.add('hidden');
        document.getElementById('billing-detail-content').classList.remove('hidden');

        document.getElementById('billing-detail-plate').textContent = plate;
        document.getElementById('billing-detail-owner').textContent = ownerName;

        const container = document.getElementById('billing-worklog');
        container.innerHTML = '';

        let calcTotal = 0;
        for (const item of worklog) {
            calcTotal += item.price || 0;
            const row = document.createElement('div');
            row.className = 'worklog-item';
            row.innerHTML = `
                <span class="worklog-label">${item.service_label}</span>
                <span class="worklog-mechanic">${item.mechanic_name || ''}</span>
                <span class="worklog-price">$${Number(item.price || 0).toLocaleString()}</span>
            `;
            container.appendChild(row);
        }

        document.getElementById('billing-total').textContent = '$' + Number(total || calcTotal).toLocaleString();
    });
}

// ============================================================================
// EVENT LISTENERS
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    // Close / Cancel buttons (station)
    document.getElementById('btn-close').addEventListener('click', () => fetchNUI('close'));
    document.getElementById('btn-cancel').addEventListener('click', () => fetchNUI('cancel'));

    // Close billing
    document.getElementById('btn-close-billing').addEventListener('click', () => fetchNUI('closeBilling'));

    // Send bill
    document.getElementById('btn-send-bill').addEventListener('click', () => {
        if (!selectedBillingPlate) return;
        const btn = document.getElementById('btn-send-bill');
        btn.disabled = true;
        fetchNUI('sendBill', { plate: selectedBillingPlate }).then(res => {
            btn.disabled = false;
        });
    });

    // ESC to close
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!document.getElementById('customer-invoice').classList.contains('hidden')) {
                return;
            }
            if (!document.getElementById('billing-app').classList.contains('hidden')) {
                fetchNUI('closeBilling');
                return;
            }
            if (!document.getElementById('app').classList.contains('hidden')) {
                fetchNUI('cancel');
            }
        }
    });

    // Engine repair buttons
    document.addEventListener('click', (e) => {
        const repairBtn = e.target.closest('[data-repair]');
        if (repairBtn) {
            const type = repairBtn.dataset.repair;
            repairBtn.disabled = true;
            fetchNUI('applyRepair', { repairType: type }).then(res => {
                repairBtn.disabled = false;
            });
        }

        // Upgrade buttons
        const upgBtn = e.target.closest('[data-upgrade-mod]');
        if (upgBtn) {
            const modType = parseInt(upgBtn.dataset.upgradeMod);
            const modIndex = parseInt(upgBtn.dataset.modIndex);
            upgBtn.disabled = true;
            fetchNUI('applyUpgrade', { modType, modIndex }).then(res => {
                upgBtn.disabled = false;
            });
        }

        // Toggle upgrade (turbo)
        const toggleBtn = e.target.closest('[data-upgrade-toggle]');
        if (toggleBtn) {
            const modType = parseInt(toggleBtn.dataset.upgradeToggle);
            const val = toggleBtn.dataset.toggleVal === 'true';
            toggleBtn.disabled = true;
            fetchNUI('applyUpgrade', { modType, modIndex: null, toggle: val }).then(res => {
                toggleBtn.disabled = false;
            });
        }

        // Tire repair
        const tireBtn = e.target.closest('[data-tire-repair]');
        if (tireBtn) {
            const idx = parseInt(tireBtn.dataset.tireRepair);
            tireBtn.disabled = true;
            fetchNUI('applyTireRepair', { tireIndex: idx }).then(res => {
                tireBtn.disabled = false;
            });
        }

        // Collapsible section toggle
        const toggleSection = e.target.closest('.toggle-section');
        if (toggleSection) {
            const targetId = toggleSection.dataset.section;
            const body = document.getElementById(targetId);
            if (body) {
                body.classList.toggle('collapsed');
                toggleSection.classList.toggle('collapsed');
            }
        }
    });

    // Sub-tabs (body page)
    document.querySelectorAll('.sub-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.sub-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            const subtab = tab.dataset.subtab;
            currentColorSlot = subtab;

            // Switch camera angle per sub-tab
            fetchNUI('switchSubCamera', { subtab: subtab });

            if (subtab === 'livery') {
                document.getElementById('color-panel').classList.add('hidden');
                document.getElementById('livery-panel').classList.remove('hidden');
            } else {
                document.getElementById('color-panel').classList.remove('hidden');
                document.getElementById('livery-panel').classList.add('hidden');

                const slotLabel = { primary: 'Primary Color', secondary: 'Secondary Color', pearlescent: 'Pearlescent Color' };
                document.getElementById('color-slot-label').textContent = slotLabel[subtab] || 'Color';

                // Hide custom RGB for pearlescent
                document.getElementById('custom-rgb-panel').style.display =
                    subtab === 'pearlescent' ? 'none' : '';

                populateColorGrid();
            }
        });
    });

    // RGB sliders (body page)
    ['rgb-r', 'rgb-g', 'rgb-b'].forEach(id => {
        const slider = document.getElementById(id);
        slider.addEventListener('input', () => {
            document.getElementById(id + '-val').textContent = slider.value;
            updateRGBPreview();
            const r = parseInt(document.getElementById('rgb-r').value);
            const g = parseInt(document.getElementById('rgb-g').value);
            const b = parseInt(document.getElementById('rgb-b').value);
            fetchNUI('previewColor', { slot: currentColorSlot, r, g, b });
        });
    });

    // Apply custom RGB
    document.getElementById('btn-apply-rgb').addEventListener('click', () => {
        const r = parseInt(document.getElementById('rgb-r').value);
        const g = parseInt(document.getElementById('rgb-g').value);
        const b = parseInt(document.getElementById('rgb-b').value);
        fetchNUI('applyColor', { slot: currentColorSlot, r, g, b });
    });

    // Apply wheels
    document.getElementById('btn-apply-wheels').addEventListener('click', () => {
        fetchNUI('applyWheels', {
            wheelType: selectedWheelType,
            wheelIndex: selectedWheelIndex
        });
    });

    // Neon sliders
    ['neon-r', 'neon-g', 'neon-b'].forEach(id => {
        const slider = document.getElementById(id);
        slider.addEventListener('input', () => {
            document.getElementById(id + '-val').textContent = slider.value;
            previewNeonLive();
        });
    });

    // Neon checkboxes
    ['neon-left', 'neon-right', 'neon-front', 'neon-back'].forEach(id => {
        document.getElementById(id).addEventListener('change', previewNeonLive);
    });

    // Apply neon
    document.getElementById('btn-apply-neon').addEventListener('click', () => {
        fetchNUI('applyCosmetic', { cosmeticType: 'neon', value: null });
    });

    // Tint select preview
    document.getElementById('tint-select').addEventListener('change', (e) => {
        fetchNUI('previewTint', { tintId: parseInt(e.target.value) });
    });

    // Apply tint
    document.getElementById('btn-apply-tint').addEventListener('click', () => {
        fetchNUI('applyCosmetic', { cosmeticType: 'tint', value: parseInt(document.getElementById('tint-select').value) });
    });

    // Xenon toggle preview
    document.getElementById('xenon-toggle').addEventListener('change', (e) => {
        fetchNUI('previewXenon', { enabled: e.target.checked });
    });

    // Xenon color preview
    document.getElementById('xenon-color-select').addEventListener('change', (e) => {
        fetchNUI('previewXenon', { colorId: parseInt(e.target.value) });
    });

    // Apply xenon
    document.getElementById('btn-apply-xenon').addEventListener('click', () => {
        const enabled = document.getElementById('xenon-toggle').checked;
        const colorId = parseInt(document.getElementById('xenon-color-select').value);
        fetchNUI('applyCosmetic', { cosmeticType: 'xenon', value: { enabled, colorId } });
    });

    // Horn preview
    document.getElementById('horn-select').addEventListener('change', (e) => {
        fetchNUI('previewHorn', { hornId: parseInt(e.target.value) });
    });

    // Apply horn
    document.getElementById('btn-apply-horn').addEventListener('click', () => {
        fetchNUI('applyCosmetic', { cosmeticType: 'horn', value: parseInt(document.getElementById('horn-select').value) });
    });

    // Plate preview
    document.getElementById('plate-select').addEventListener('change', (e) => {
        fetchNUI('previewPlateStyle', { plateId: parseInt(e.target.value) });
    });

    // Apply plate
    document.getElementById('btn-apply-plate').addEventListener('click', () => {
        fetchNUI('applyCosmetic', { cosmeticType: 'plate', value: parseInt(document.getElementById('plate-select').value) });
    });

    // Apply interior
    document.getElementById('btn-apply-interior').addEventListener('click', () => {
        const selected = document.querySelector('#interior-color-grid .color-swatch.selected');
        if (!selected) return;
        const colorId = gtaColors.find(c => c.hex === selected.style.background)?.id;
        fetchNUI('applyCosmetic', { cosmeticType: 'interior', value: colorId });
    });

    // Apply dashboard
    document.getElementById('btn-apply-dashboard').addEventListener('click', () => {
        const selected = document.querySelector('#dashboard-color-grid .color-swatch.selected');
        if (!selected) return;
        const colorId = gtaColors.find(c => c.hex === selected.style.background)?.id;
        fetchNUI('applyCosmetic', { cosmeticType: 'dashboard', value: colorId });
    });

    // Wash
    document.getElementById('btn-wash').addEventListener('click', () => {
        fetchNUI('applyWash');
    });

    // Customer invoice buttons
    document.getElementById('btn-accept-invoice').addEventListener('click', () => {
        fetchNUI('respondInvoice', { plate: currentInvoicePlate, accept: true });
    });

    document.getElementById('btn-decline-invoice').addEventListener('click', () => {
        fetchNUI('respondInvoice', { plate: currentInvoicePlate, accept: false });
    });
});

// ============================================================================
// HELPERS
// ============================================================================

function previewNeonLive() {
    const enabled = [
        document.getElementById('neon-left').checked,
        document.getElementById('neon-right').checked,
        document.getElementById('neon-front').checked,
        document.getElementById('neon-back').checked,
    ];
    const r = parseInt(document.getElementById('neon-r').value);
    const g = parseInt(document.getElementById('neon-g').value);
    const b = parseInt(document.getElementById('neon-b').value);
    fetchNUI('previewNeon', { enabled, r, g, b });
}

function updateRGBPreview() {
    const r = document.getElementById('rgb-r').value;
    const g = document.getElementById('rgb-g').value;
    const b = document.getElementById('rgb-b').value;
    document.getElementById('rgb-preview-box').style.background = `rgb(${r}, ${g}, ${b})`;
}

function capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

// ============================================================================
// CUSTOMER INVOICE (popup for vehicle owner)
// ============================================================================

function showCustomerInvoice(data) {
    currentInvoicePlate = data.plate;

    document.getElementById('popup-plate').textContent = `Invoice for ${data.plate || 'Vehicle'}`;
    document.getElementById('popup-mechanic-name').textContent = `From: ${data.mechanicName || 'Mechanic'}`;

    const itemsContainer = document.getElementById('popup-items');
    itemsContainer.innerHTML = '';

    let total = 0;
    for (const item of (data.items || [])) {
        total += item.price || 0;
        const div = document.createElement('div');
        div.className = 'popup-item';
        div.innerHTML = `
            <span>${item.label}</span>
            <span class="popup-item-price">$${item.price || 0}</span>
        `;
        itemsContainer.appendChild(div);
    }

    document.getElementById('popup-total').textContent = '$' + total.toLocaleString();
    document.getElementById('customer-invoice').classList.remove('hidden');
}

function hideCustomerInvoice() {
    document.getElementById('customer-invoice').classList.add('hidden');
    currentInvoicePlate = null;
}
