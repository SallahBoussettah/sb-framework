// sb_admin/html/script.js
// Tab-based admin menu with all commands

const menu = document.getElementById('admin-menu');
const inspectorOverlay = document.getElementById('inspector-overlay');

// State
let inspectorActive = false;
let noclipActive = false;
let godmodeActive = false;
let coordsActive = false;

// ============ TAB SYSTEM ============
function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`.tab[data-tab="${tabName}"]`).classList.add('active');

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    document.getElementById(`tab-${tabName}`).classList.add('active');
}

// ============ NUI MESSAGE HANDLER ============
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'toggleMenu':
            if (data.show) {
                menu.classList.remove('hidden');
                if (data.inspectorActive !== undefined) {
                    inspectorActive = data.inspectorActive;
                    updateBadge('inspector', inspectorActive);
                }
                if (data.noclipActive !== undefined) {
                    noclipActive = data.noclipActive;
                    updateBadge('noclip', noclipActive);
                }
                if (data.godmodeActive !== undefined) {
                    godmodeActive = data.godmodeActive;
                    updateBadge('godmode', godmodeActive);
                }
            } else {
                menu.classList.add('hidden');
            }
            break;

        case 'inspectorState':
            inspectorActive = data.active;
            updateBadge('inspector', inspectorActive);
            if (!inspectorActive) {
                inspectorOverlay.classList.add('hidden');
            }
            break;

        case 'inspectorData':
            if (data.data) {
                inspectorOverlay.classList.remove('hidden');
                document.getElementById('insp-model').textContent = data.data.modelName;
                document.getElementById('insp-hash').textContent = data.data.modelHash;
                document.getElementById('insp-type').textContent = data.data.entityType;
                document.getElementById('insp-id').textContent = data.data.entityId;
                document.getElementById('insp-coords').textContent =
                    `${data.data.hitX}, ${data.data.hitY}, ${data.data.hitZ}`;
            } else {
                inspectorOverlay.classList.add('hidden');
            }
            break;

        case 'copyText':
            copyToClipboard(data.text);
            showToast('Copied: ' + data.text, 'success');
            break;

        case 'notify':
            showToast(data.text, data.type || 'info');
            break;
    }
});

// ============ TOOLS TAB ============
function closeMenu() {
    fetch('https://sb_admin/closeMenu', { method: 'POST', body: JSON.stringify({}) });
}

function toggleInspector() {
    fetch('https://sb_admin/toggleInspector', { method: 'POST', body: JSON.stringify({}) });
    inspectorActive = !inspectorActive;
    updateBadge('inspector', inspectorActive);
}

function toggleNoclip() {
    fetch('https://sb_admin/toggleNoclip', { method: 'POST', body: JSON.stringify({}) });
    noclipActive = !noclipActive;
    updateBadge('noclip', noclipActive);
    closeMenu();
}

function toggleGodmode() {
    fetch('https://sb_admin/toggleGodmode', { method: 'POST', body: JSON.stringify({}) });
    godmodeActive = !godmodeActive;
    updateBadge('godmode', godmodeActive);
}

function toggleCoords() {
    fetch('https://sb_admin/toggleCoords', { method: 'POST', body: JSON.stringify({}) })
        .then(r => r.json())
        .then(data => {
            coordsActive = data.active;
            updateBadge('coords', coordsActive);
        });
}

function setTime() {
    const hour = document.getElementById('time-hour').value;
    if (hour === '') return showToast('Enter an hour (0-23)', 'error');
    const minute = document.getElementById('time-minute').value || '0';
    fetch('https://sb_admin/setTime', { method: 'POST', body: JSON.stringify({ hour: hour, minute: minute }) });
    document.getElementById('time-hour').value = '';
    document.getElementById('time-minute').value = '0';
}

function copyCoords(format) {
    fetch('https://sb_admin/getCoords', { method: 'POST', body: JSON.stringify({}) })
        .then(r => r.json())
        .then(data => {
            let text;
            if (format === 'vector4') {
                text = `vector4(${data.x}, ${data.y}, ${data.z}, ${data.h})`;
            } else {
                text = `vector3(${data.x}, ${data.y}, ${data.z})`;
            }
            copyToClipboard(text);
            showToast('Copied: ' + text, 'success');
        });
}

// ============ TELEPORT TAB ============
function tpWaypoint() {
    fetch('https://sb_admin/tpToWaypoint', { method: 'POST', body: JSON.stringify({}) });
    closeMenu();
}

function gotoPlayer() {
    const id = document.getElementById('goto-id').value;
    if (!id) return showToast('Enter a player ID', 'error');
    fetch('https://sb_admin/gotoPlayer', { method: 'POST', body: JSON.stringify({ id: id }) });
    document.getElementById('goto-id').value = '';
    closeMenu();
}

function bringPlayer() {
    const id = document.getElementById('bring-id').value;
    if (!id) return showToast('Enter a player ID', 'error');
    fetch('https://sb_admin/bringPlayer', { method: 'POST', body: JSON.stringify({ id: id }) });
    document.getElementById('bring-id').value = '';
}

// ============ GIVE TAB ============
function spawnVehicle() {
    const model = document.getElementById('vehicle-input').value.trim();
    if (!model) return showToast('Enter a vehicle model', 'error');
    fetch('https://sb_admin/spawnVehicle', { method: 'POST', body: JSON.stringify({ model: model }) });
    document.getElementById('vehicle-input').value = '';
    closeMenu();
}

function giveWeapon() {
    const target = document.getElementById('weapon-target').value;
    const weapon = document.getElementById('weapon-name').value.trim() || 'weapon_pistol';
    if (!target) return showToast('Enter target player ID', 'error');
    fetch('https://sb_admin/giveWeapon', { method: 'POST', body: JSON.stringify({ id: target, weapon: weapon }) });
    document.getElementById('weapon-target').value = '';
    document.getElementById('weapon-name').value = '';
}

function giveItem() {
    const target = document.getElementById('item-target').value;
    const item = document.getElementById('item-input').value.trim();
    const amount = document.getElementById('item-amount').value || '1';
    if (!target) return showToast('Enter target player ID', 'error');
    if (!item) return showToast('Enter an item name', 'error');
    fetch('https://sb_admin/giveItemCmd', { method: 'POST', body: JSON.stringify({ id: target, item: item, amount: amount }) });
    document.getElementById('item-target').value = '';
    document.getElementById('item-input').value = '';
    document.getElementById('item-amount').value = '1';
}

function giveMoney() {
    const target = document.getElementById('money-target').value;
    const type = document.getElementById('money-type').value;
    const amount = document.getElementById('money-amount').value;
    if (!target) return showToast('Enter target player ID', 'error');
    if (!amount) return showToast('Enter an amount', 'error');
    fetch('https://sb_admin/giveMoney', { method: 'POST', body: JSON.stringify({ id: target, type: type, amount: amount }) });
    document.getElementById('money-target').value = '';
    document.getElementById('money-amount').value = '';
}

// ============ PLAYERS TAB ============
function setJob() {
    const target = document.getElementById('job-target').value;
    const job = document.getElementById('job-name').value.trim();
    const grade = document.getElementById('job-grade').value || '0';
    if (!target) return showToast('Enter target player ID', 'error');
    if (!job) return showToast('Enter a job name', 'error');
    fetch('https://sb_admin/setJob', { method: 'POST', body: JSON.stringify({ id: target, job: job, grade: grade }) });
    document.getElementById('job-target').value = '';
    document.getElementById('job-name').value = '';
    document.getElementById('job-grade').value = '0';
}

function setGang() {
    const target = document.getElementById('gang-target').value;
    const gang = document.getElementById('gang-name').value.trim();
    const grade = document.getElementById('gang-grade').value || '0';
    if (!target) return showToast('Enter target player ID', 'error');
    if (!gang) return showToast('Enter a gang name', 'error');
    fetch('https://sb_admin/setGang', { method: 'POST', body: JSON.stringify({ id: target, gang: gang, grade: grade }) });
    document.getElementById('gang-target').value = '';
    document.getElementById('gang-name').value = '';
    document.getElementById('gang-grade').value = '0';
}

function revivePlayer() {
    const target = document.getElementById('revive-target').value || '';
    fetch('https://sb_admin/revivePlayer', { method: 'POST', body: JSON.stringify({ id: target }) });
    document.getElementById('revive-target').value = '';
}

function kickPlayer() {
    const target = document.getElementById('kick-target').value;
    const reason = document.getElementById('kick-reason').value.trim() || 'No reason';
    if (!target) return showToast('Enter target player ID', 'error');
    fetch('https://sb_admin/kickPlayer', { method: 'POST', body: JSON.stringify({ id: target, reason: reason }) });
    document.getElementById('kick-target').value = '';
    document.getElementById('kick-reason').value = '';
}

function banPlayer() {
    const target = document.getElementById('ban-target').value;
    const hours = document.getElementById('ban-hours').value || '0';
    const reason = document.getElementById('ban-reason').value.trim() || 'No reason';
    if (!target) return showToast('Enter target player ID', 'error');
    fetch('https://sb_admin/banPlayer', { method: 'POST', body: JSON.stringify({ id: target, hours: hours, reason: reason }) });
    document.getElementById('ban-target').value = '';
    document.getElementById('ban-hours').value = '';
    document.getElementById('ban-reason').value = '';
}

// ============ UTILITIES ============
function updateBadge(name, active) {
    const badge = document.getElementById(`badge-${name}`);
    if (!badge) return;
    badge.textContent = active ? 'ON' : 'OFF';
    if (active) {
        badge.classList.add('active');
    } else {
        badge.classList.remove('active');
    }
}

function copyToClipboard(text) {
    const area = document.getElementById('copy-area');
    area.value = text;
    area.select();
    document.execCommand('copy');
}

function showToast(message, type) {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    let icon = 'fa-info-circle';
    if (type === 'success') icon = 'fa-check-circle';
    else if (type === 'error') icon = 'fa-exclamation-circle';

    toast.innerHTML = `<i class="fas ${icon}"></i><span>${message}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('toast-out');
        setTimeout(() => toast.remove(), 200);
    }, 3000);
}

// ============ KEY HANDLING ============
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeMenu();
    }
});

// Enter key submits focused input group
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    const el = document.activeElement;
    if (!el || !el.closest('.input-group')) return;

    const group = el.closest('.input-group');
    const btn = group.querySelector('.input-btn');
    if (btn) btn.click();
});
