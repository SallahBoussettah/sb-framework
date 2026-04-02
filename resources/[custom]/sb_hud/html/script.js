// ============================================================================
// SB HUD v2 - Matching UI.html Design
// ============================================================================

const hudContainer = document.getElementById('hud-container');
const statusIcons = document.getElementById('status-icons');
const hudTopRight = document.getElementById('hud-top-right');
const hudBottomLeft = document.getElementById('hud-bottom-left');
const hudVehicle = document.getElementById('hud-vehicle');

// Status rings
const healthRing = document.getElementById('health-ring');
const armorRing = document.getElementById('armor-ring');
const hungerRing = document.getElementById('hunger-ring');
const thirstRing = document.getElementById('thirst-ring');
const staminaRing = document.getElementById('stamina-ring');
const stressRing = document.getElementById('stress-ring');

// Status boxes (for critical class)
const healthBox = document.getElementById('health-box');
const armorBox = document.getElementById('armor-box');
const hungerBox = document.getElementById('hunger-box');
const thirstBox = document.getElementById('thirst-box');
const staminaBox = document.getElementById('stamina-box');
const stressBox = document.getElementById('stress-box');
const voiceBox = document.getElementById('voice-box');

// Economy
const cashValue = document.getElementById('cash-value');
const playerIdEl = document.getElementById('player-id');
const cashDisplay = document.getElementById('cash-display');

// Car dash
const carDash = document.getElementById('car-dash');
const carSpeedValue = document.getElementById('car-speed-value');
const carSpeedUnit = document.getElementById('car-speed-unit');
const carGaugeFill = document.getElementById('car-gauge-fill');
const indSeatbelt = document.getElementById('ind-seatbelt');
const indEngine = document.getElementById('ind-engine');
const carFuelBar = document.getElementById('car-fuel-bar');
const carFuelText = document.getElementById('car-fuel-text');

// Bike dash
const bikeDash = document.getElementById('bike-dash');
const bikeSpeedValue = document.getElementById('bike-speed-value');
const bikeSpeedUnit = document.getElementById('bike-speed-unit');
const bikeRevBar = document.getElementById('bike-rev-bar');
const bikeGear = document.getElementById('bike-gear');
const bikeIndEngine = document.getElementById('bike-ind-engine');
const bikeFuelBar = document.getElementById('bike-fuel-bar');
const bikeFuelText = document.getElementById('bike-fuel-text');

// Ring circumference (2 * PI * 18.5 = ~116.24)
const RING_CIRCUMFERENCE = 116;
const GAUGE_ARC_LENGTH = 170; // SVG path arc length for car gauge (small arc ~122°)
const BIKE_SEGMENTS = 30;
const BIKE_REDLINE = 24;

let config = {};
let lastCash = 0;
let maxSpeed = 260;

// ============================================================================
// INIT
// ============================================================================
function initHUD(hudConfig) {
    config = hudConfig;
    maxSpeed = hudConfig.maxSpeed || 260;
    if (carSpeedUnit) carSpeedUnit.textContent = hudConfig.speedUnit || 'KM/H';
    if (bikeSpeedUnit) bikeSpeedUnit.textContent = hudConfig.speedUnit || 'KM/H';

    // Generate bike rev segments
    if (bikeRevBar) {
        bikeRevBar.innerHTML = '';
        for (let i = 0; i < BIKE_SEGMENTS; i++) {
            const s = document.createElement('div');
            s.className = 'rev-seg' + (i >= BIKE_REDLINE ? ' redline' : '');
            bikeRevBar.appendChild(s);
        }
    }
}

// ============================================================================
// UPDATE
// ============================================================================
function updateHUD(data) {
    // Status rings
    updateRing(healthRing, data.health);
    updateRing(armorRing, data.armor);
    updateRing(hungerRing, data.hunger);
    updateRing(thirstRing, data.thirst);
    updateRing(staminaRing, data.stamina);
    updateRing(stressRing, data.stress);

    // Critical states
    if (healthBox) healthBox.classList.toggle('critical', data.health <= 25);
    if (armorBox) armorBox.classList.toggle('critical', data.armor <= 0);
    if (hungerBox) hungerBox.classList.toggle('critical', data.hunger <= 25);
    if (thirstBox) thirstBox.classList.toggle('critical', data.thirst <= 25);
    if (staminaBox) staminaBox.classList.toggle('critical', data.stamina <= 20);
    if (stressBox) stressBox.classList.toggle('critical', data.stress >= 75);

    // Voice
    updateVoice(data.voiceRange, data.isTalking);

    // Economy
    updateEconomy(data.cash, data.playerId, data.moneyChanged);

    // Vehicle
    updateVehicle(data);

    // Visibility
    updateVisibility(data);
}

function updateRing(ringEl, value) {
    if (!ringEl) return;
    const pct = Math.max(0, Math.min(100, value)) / 100;
    const offset = RING_CIRCUMFERENCE * (1 - pct);
    ringEl.style.strokeDashoffset = offset;
}

function updateVoice(rangeIndex, isTalking) {
    if (!voiceBox) return;
    voiceBox.classList.remove('range-1', 'range-2', 'range-3', 'talking');
    if (rangeIndex >= 1 && rangeIndex <= 3) voiceBox.classList.add('range-' + rangeIndex);
    if (isTalking) voiceBox.classList.add('talking');
}

function updateEconomy(cash, playerId, changed) {
    if (cashValue && cash !== lastCash) {
        cashValue.textContent = cash.toLocaleString('en-US');
        if (cashDisplay) {
            cashDisplay.classList.remove('increase', 'decrease');
            void cashDisplay.offsetWidth;
            if (cash > lastCash) cashDisplay.classList.add('increase');
            else if (cash < lastCash) cashDisplay.classList.add('decrease');
        }
        lastCash = cash;
    }
    if (playerIdEl && playerId) playerIdEl.textContent = playerId;
}

// ============================================================================
// VEHICLE
// ============================================================================
function updateVehicle(data) {
    if (!data.inVehicle) {
        if (carDash) carDash.classList.add('hidden');
        if (bikeDash) bikeDash.classList.add('hidden');
        return;
    }

    if (data.vehicleType === 'bike') {
        if (carDash) carDash.classList.add('hidden');
        if (bikeDash) bikeDash.classList.remove('hidden');
        updateBike(data);
    } else {
        if (bikeDash) bikeDash.classList.add('hidden');
        if (carDash) carDash.classList.remove('hidden');
        updateCar(data);
    }
}

function updateCar(data) {
    if (carSpeedValue) carSpeedValue.textContent = Math.round(data.speed);

    if (carGaugeFill) {
        const pct = Math.min(data.speed / maxSpeed, 1);
        const offset = GAUGE_ARC_LENGTH * (1 - pct);
        carGaugeFill.style.strokeDashoffset = offset;
    }

    updateIndicator(indSeatbelt, data.seatbelt, !data.seatbelt && data.speed > 20);
    updateIndicator(indEngine, data.engineHealth > 300, data.engineHealth <= 300);

    // Fuel bar
    updateFuelBar(carFuelBar, carFuelText, data.fuel);
}

function updateBike(data) {
    if (bikeSpeedValue) bikeSpeedValue.textContent = Math.round(data.speed);
    if (bikeGear) bikeGear.textContent = 'GEAR ' + (data.gear === 0 ? 'N' : data.gear);

    if (bikeRevBar) {
        const active = Math.round((data.rpm || 0) * BIKE_SEGMENTS);
        const segs = bikeRevBar.children;
        for (let i = 0; i < segs.length; i++) {
            segs[i].classList.toggle('active', i < active);
        }
    }

    updateBikeIndicator(bikeIndEngine, data.engineHealth > 300, data.engineHealth <= 300);

    // Fuel bar
    updateFuelBar(bikeFuelBar, bikeFuelText, data.fuel);
}

function updateIndicator(el, isActive, isWarning) {
    if (!el) return;
    el.classList.remove('active', 'warning');
    if (isWarning) el.classList.add('warning');
    else if (isActive) el.classList.add('active');
}

function updateBikeIndicator(el, isActive, isWarning) {
    if (!el) return;
    el.classList.remove('active', 'warning');
    if (isWarning) el.classList.add('warning');
    else if (isActive) el.classList.add('active');
}

function updateFuelBar(barEl, textEl, fuel) {
    if (!barEl || !textEl) return;

    const fuelPct = Math.max(0, Math.min(100, fuel));

    // Update bar width
    barEl.style.width = fuelPct + '%';

    // Update text
    textEl.textContent = Math.round(fuelPct) + '%';

    // Update classes based on fuel level
    barEl.classList.remove('low', 'critical');
    textEl.classList.remove('low', 'critical');

    if (fuelPct <= 10) {
        barEl.classList.add('critical');
        textEl.classList.add('critical');
    } else if (fuelPct <= 25) {
        barEl.classList.add('low');
        textEl.classList.add('low');
    }
}

// ============================================================================
// VISIBILITY
// ============================================================================
function updateVisibility(data) {
    const showStatus = data.showHud || data.health < 100 || data.armor > 0 ||
                       data.inCombat || data.hunger <= 25 || data.thirst <= 25 ||
                       data.stamina < 100 || data.stress > 0 || data.inVehicle;

    if (hudBottomLeft) {
        hudBottomLeft.classList.toggle('hidden-status', !showStatus);
    }
}

// ============================================================================
// AMMO DISPLAY
// ============================================================================
const ammoDisplay = document.getElementById('hud-ammo');
const ammoCurrent = document.getElementById('ammo-current');
const ammoCapacity = document.getElementById('ammo-capacity');
const ammoMagLabel = document.getElementById('ammo-mag-label');

function updateAmmo(data) {
    if (!ammoDisplay) return;
    if (!data.show) {
        ammoDisplay.classList.add('hidden');
        return;
    }
    ammoDisplay.classList.remove('hidden');
    if (ammoCurrent) {
        ammoCurrent.textContent = data.current;
        ammoCurrent.classList.remove('low', 'empty');
        if (data.current <= 0) {
            ammoCurrent.classList.add('empty');
        } else if (data.capacity > 0 && data.current <= Math.ceil(data.capacity * 0.25)) {
            ammoCurrent.classList.add('low');
        }
    }
    if (ammoCapacity) ammoCapacity.textContent = data.capacity;
    if (ammoMagLabel) ammoMagLabel.textContent = data.magLabel || '';
}

// ============================================================================
// STREET NAME DISPLAY
// ============================================================================
const streetNameText = document.getElementById('street-name-text');
const zoneNameText = document.getElementById('zone-name-text');

function updateStreet(data) {
    if (streetNameText) {
        let text = data.street || '';
        if (data.cross && data.cross !== '' && data.cross !== data.street) {
            text += ' / ' + data.cross;
        }
        streetNameText.textContent = text;
    }
    if (zoneNameText) {
        zoneNameText.textContent = data.zone || '';
    }
}

// ============================================================================
// NUI MESSAGES
// ============================================================================
window.addEventListener('message', (event) => {
    const d = event.data;
    switch (d.action) {
        case 'initHUD': initHUD(d.config); break;
        case 'updateHUD': updateHUD(d.data); break;
        case 'updateAmmo': updateAmmo(d); break;
        case 'updateVoice': updateVoice(d.voiceRange, d.isTalking); break;
        case 'updateStreet': updateStreet(d); break;
        case 'showHUD': hudContainer.classList.remove('hidden', 'cinematic'); break;
        case 'hideHUD': hudContainer.classList.add('hidden'); break;
        case 'setCinematicMode': hudContainer.classList.toggle('cinematic', d.enabled); break;
        case 'showNeeds': if (hudBottomLeft) hudBottomLeft.classList.remove('hidden-status'); break;
        case 'openEditor': openEditor(); break;
        case 'loadPositions':
            if (d.positions) {
                try { savedPositions = JSON.parse(d.positions); applyPositions(savedPositions); } catch(e) {}
            }
            break;
    }
});

// ============================================================================
// HUD EDITOR
// ============================================================================
const hudEditor = document.getElementById('hud-editor');
const editorSaveBtn = document.getElementById('editor-save');
const editorCancelBtn = document.getElementById('editor-cancel');
const editorResetBtn = document.getElementById('editor-reset');

let isEditorOpen = false;
let savedPositions = {};

const draggableElements = [
    { id: 'hud-vehicle', label: 'Car Dash' },
    { id: 'bike-dash', label: 'Bike Dash' },
    { id: 'hud-top-right', label: 'Economy' },
    { id: 'hud-ammo', label: 'Ammo' },
    { id: 'street-display', label: 'Street' }
];

// Individual status icon draggables
const iconDraggables = [
    { id: 'health-box', label: 'Health' },
    { id: 'armor-box', label: 'Armor' },
    { id: 'hunger-box', label: 'Hunger' },
    { id: 'thirst-box', label: 'Thirst' },
    { id: 'stamina-box', label: 'Stamina' },
    { id: 'stress-box', label: 'Stress' },
    { id: 'voice-box', label: 'Voice' }
];

function openEditor() {
    isEditorOpen = true;
    hudEditor.classList.remove('hidden');
    if (hudContainer) hudContainer.style.pointerEvents = 'auto';
    if (hudBottomLeft) hudBottomLeft.classList.remove('hidden-status');
    if (carDash) carDash.classList.remove('hidden');
    if (bikeDash) bikeDash.classList.remove('hidden');
    if (ammoDisplay) { ammoDisplay.classList.remove('hidden'); updateAmmo({show:true, current:7, capacity:10, magLabel:'Standard'}); }

    // Make panel-level elements draggable
    draggableElements.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (el) makeDraggable(el, cfg.label);
    });

    // Snapshot each icon's bounding rect and convert to fixed position for individual drag
    iconDraggables.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (!el) return;
        const r = el.getBoundingClientRect();
        el.style.position = 'fixed';
        el.style.left = r.left + 'px';
        el.style.top = r.top + 'px';
        el.style.margin = '0';
        makeDraggable(el, cfg.label);
    });
}

function closeEditor(save) {
    isEditorOpen = false;

    // IMPORTANT: Get positions BEFORE hiding elements (otherwise getBoundingClientRect returns 0)
    let positionsToSave = null;
    if (save) {
        positionsToSave = getCurrentPositions();
    }

    hudEditor.classList.add('hidden');
    if (hudContainer) hudContainer.style.pointerEvents = 'none';
    if (carDash) carDash.classList.add('hidden');
    if (bikeDash) bikeDash.classList.add('hidden');
    if (ammoDisplay) ammoDisplay.classList.add('hidden');

    // Clean up panel draggables
    draggableElements.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (el) {
            el.classList.remove('hud-draggable', 'dragging');
            el.querySelectorAll('.editor-label').forEach(l => l.remove());
        }
    });

    // Clean up icon draggables
    iconDraggables.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (el) {
            el.classList.remove('hud-draggable', 'dragging');
            el.querySelectorAll('.editor-label').forEach(l => l.remove());
        }
    });

    if (save) {
        savedPositions = positionsToSave;
        // Mark icons as custom-positioned
        iconDraggables.forEach(cfg => {
            if (positionsToSave[cfg.id]) {
                const el = document.getElementById(cfg.id);
                if (el) el.classList.add('custom-positioned');
            }
        });
        fetch(`https://${GetParentResourceName()}/editorSave`, {
            method: 'POST', headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ positions: JSON.stringify(savedPositions) })
        });
    } else {
        // Revert unsaved icons back to flex flow
        iconDraggables.forEach(cfg => {
            const el = document.getElementById(cfg.id);
            if (!el) return;
            if (!savedPositions[cfg.id]) {
                // No saved position — return to flex
                el.classList.remove('custom-positioned');
                el.style.position = '';
                el.style.left = '';
                el.style.top = '';
                el.style.margin = '';
                el.style.transform = '';
            }
        });
        applyPositions(savedPositions);
        fetch(`https://${GetParentResourceName()}/editorCancel`, {
            method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'
        });
    }
}

function resetEditor() {
    draggableElements.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (el) {
            el.style.cssText = '';
            el.style.transform = '';
        }
    });
    // Reset individual icons back to flex flow
    iconDraggables.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (el) {
            el.classList.remove('custom-positioned');
            el.style.position = '';
            el.style.left = '';
            el.style.top = '';
            el.style.margin = '';
            el.style.transform = '';
            el._scale = 1;
            // Re-snapshot for continued editing
            const r = el.getBoundingClientRect();
            el.style.position = 'fixed';
            el.style.left = r.left + 'px';
            el.style.top = r.top + 'px';
            el.style.margin = '0';
        }
    });
    savedPositions = {};
    fetch(`https://${GetParentResourceName()}/editorReset`, {
        method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'
    });
}

function getCurrentPositions() {
    const pos = {};
    draggableElements.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (!el) return;
        const r = el.getBoundingClientRect();
        const scale = el._scale || 1;
        pos[cfg.id] = { left: r.left, top: r.top, scale: scale };
    });
    // Individual icons
    iconDraggables.forEach(cfg => {
        const el = document.getElementById(cfg.id);
        if (!el) return;
        const r = el.getBoundingClientRect();
        const scale = el._scale || 1;
        pos[cfg.id] = { left: r.left, top: r.top, scale: scale };
    });
    return pos;
}

function applyPositions(positions) {
    // Check which IDs are icon IDs
    const iconIds = new Set(iconDraggables.map(c => c.id));

    for (const id in positions) {
        const el = document.getElementById(id);
        if (!el) continue;
        const p = positions[id];
        el.style.position = 'fixed';
        el.style.left = p.left + 'px';
        el.style.top = p.top + 'px';
        el.style.bottom = 'auto';
        el.style.right = 'auto';
        if (iconIds.has(id)) {
            el.classList.add('custom-positioned');
            el.style.margin = '0';
        }
        if (p.scale && p.scale !== 1) {
            el._scale = p.scale;
            el.style.transform = 'scale(' + p.scale + ')';
        }
    }
}

function makeDraggable(el, label) {
    el.classList.add('hud-draggable');
    if (!el.querySelector('.editor-label')) {
        const lbl = document.createElement('span');
        lbl.className = 'editor-label';
        lbl.textContent = label;
        el.style.position = el.style.position || 'fixed';
        el.appendChild(lbl);
    }
    if (el._dragInit) return;
    el._dragInit = true;
    if (!el._scale) el._scale = 1;

    let dragging = false, ox, oy;
    el.addEventListener('mousedown', (e) => {
        if (!isEditorOpen) return;
        dragging = true;
        el.classList.add('dragging');
        const r = el.getBoundingClientRect();
        ox = e.clientX - r.left; oy = e.clientY - r.top;
        el.style.position = 'fixed';
        el.style.left = r.left + 'px'; el.style.top = r.top + 'px';
        el.style.bottom = 'auto'; el.style.right = 'auto';

        const move = (e) => { if (!dragging) return; el.style.left = (e.clientX - ox)+'px'; el.style.top = (e.clientY - oy)+'px'; };
        const up = () => { dragging = false; el.classList.remove('dragging'); document.removeEventListener('mousemove', move); document.removeEventListener('mouseup', up); };
        document.addEventListener('mousemove', move);
        document.addEventListener('mouseup', up);
    });

    el.addEventListener('wheel', (e) => {
        if (!isEditorOpen) return;
        e.preventDefault();
        const delta = e.deltaY > 0 ? -0.05 : 0.05;
        el._scale = Math.max(0.5, Math.min(2.0, (el._scale || 1) + delta));
        el.style.transform = 'scale(' + el._scale + ')';
    });
}

if (editorSaveBtn) editorSaveBtn.addEventListener('click', () => closeEditor(true));
if (editorCancelBtn) editorCancelBtn.addEventListener('click', () => closeEditor(false));
if (editorResetBtn) editorResetBtn.addEventListener('click', () => resetEditor());

// Notify ready
fetch(`https://${GetParentResourceName()}/uiReady`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'
});
