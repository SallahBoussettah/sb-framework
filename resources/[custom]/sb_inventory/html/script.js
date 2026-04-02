/**
 * Everyday Chaos RP - Inventory UI Script (Redesign)
 * Author: Salah Eddine Boussettah
 *
 * Select-then-act paradigm, drag-and-drop, mouse tooltip, action buttons.
 */

// ========================================================================
// STATE
// ========================================================================
let playerInv = null;
let secondaryInv = null;
let itemDefs = {};
let selectedSlot = null;     // { slot, panel, invId }
let dragState = null;
let amountCallback = null;
const resourceName = (typeof GetParentResourceName !== 'undefined') ? GetParentResourceName() : 'sb_inventory';

// DOM Elements
const inventoryContainer = document.getElementById('inventory-container');
const playerGrid = document.getElementById('player-grid');
const secondaryGrid = document.getElementById('secondary-grid');
const tooltip = document.getElementById('tooltip');
const amountModal = document.getElementById('amount-modal');
const amountInput = document.getElementById('amount-input');

// ========================================================================
// NUI MESSAGE HANDLER
// ========================================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openInventory':
            openInventory(data);
            break;
        case 'closeInventory':
            closeInventory();
            break;
        case 'updateSlot':
            updateSlot(data.slot, data.item);
            break;
        case 'refreshInventory':
            refreshInventory(data);
            break;
        case 'updateGround':
            updateGround(data);
            break;
        case 'showHotbar':
            showHotbar(data.items, data.activeSlot);
            break;
        case 'hideHotbar':
            hideHotbar();
            break;
    }
});

// ========================================================================
// INVENTORY OPEN/CLOSE
// ========================================================================
function openInventory(data) {
    playerInv = data.playerInv;
    secondaryInv = data.secondaryInv;
    itemDefs = data.items || {};
    selectedSlot = null;

    // Update player stats
    if (data.playerStats) {
        document.getElementById('stat-wallet').textContent = '$' + formatMoney(data.playerStats.cash || 0);
        document.getElementById('stat-bank').textContent = '$' + formatMoney(data.playerStats.bank || 0);
        document.getElementById('stat-id').textContent = '#' + (data.playerStats.cid || '000');
    }

    // Render player inventory
    renderGrid(playerGrid, playerInv, 'player');
    updateSlotInfo('player', playerInv);

    // Render secondary (ground/trunk/stash/drop)
    if (secondaryInv) {
        document.getElementById('secondary-title').textContent = secondaryInv.label || 'Ground';
        document.getElementById('secondary-subtitle').textContent = getSecondarySubtitle(secondaryInv.type);
        renderGrid(secondaryGrid, secondaryInv, 'secondary');
        updateSlotInfo('secondary', secondaryInv);
    } else {
        // Show empty ground panel
        document.getElementById('secondary-title').textContent = 'Ground';
        document.getElementById('secondary-subtitle').textContent = 'Nearby items';
        document.getElementById('secondary-slot-info').innerHTML = '&infin;';
        document.getElementById('secondary-weight-bar').style.width = '0%';
        secondaryGrid.innerHTML = '';
        renderEmptyGround();
    }

    inventoryContainer.classList.remove('hidden');
}

function closeInventory() {
    inventoryContainer.classList.add('hidden');
    amountModal.classList.add('hidden');
    document.getElementById('context-menu').classList.add('hidden');
    hideTooltip();
    selectedSlot = null;
    playerInv = null;
    secondaryInv = null;
    dragState = null;
}

function getSecondarySubtitle(type) {
    const map = {
        'ground': 'Nearby items',
        'drop': 'Nearby items',
        'trunk': 'Vehicle trunk',
        'glovebox': 'Glovebox',
        'stash': 'Personal stash',
        'shop': 'Store'
    };
    return map[type] || 'Container';
}

// ========================================================================
// GRID RENDERING
// ========================================================================
function renderGrid(gridEl, inv, panelType) {
    gridEl.innerHTML = '';
    const slots = inv.slots || 40;
    const items = inv.items || {};

    for (let i = 1; i <= slots; i++) {
        const slot = createSlotElement(i, items[i], panelType, inv.id);
        gridEl.appendChild(slot);
    }
}

function renderEmptyGround() {
    // Render 30 empty slots for ground
    const slots = 30;
    for (let i = 1; i <= slots; i++) {
        const slot = createSlotElement(i, null, 'secondary', 'ground_empty');
        secondaryGrid.appendChild(slot);
    }
}

function createSlotElement(slotNum, item, panelType, invId) {
    const slot = document.createElement('div');
    slot.className = 'slot';
    slot.dataset.slot = slotNum;
    slot.dataset.panel = panelType;
    slot.dataset.invId = invId;

    // Mark slots 1-5 as quick-use in player inventory
    if (panelType === 'player' && slotNum <= 5) {
        slot.classList.add('quickslot');
    }

    // Slot number label
    const numLabel = document.createElement('span');
    numLabel.className = 'slot-number';
    numLabel.textContent = slotNum;
    slot.appendChild(numLabel);

    // Render item content if present
    if (item) {
        renderSlotContent(slot, item);
    }

    // Event listeners
    slot.addEventListener('click', (e) => onSlotClick(e, slot, slotNum, panelType, invId));
    slot.addEventListener('mouseenter', (e) => onSlotHover(e, slot, slotNum, panelType));
    slot.addEventListener('mouseleave', () => hideTooltip());
    slot.addEventListener('mousedown', (e) => onSlotMouseDown(e, slot, slotNum, panelType, invId));
    slot.addEventListener('contextmenu', (e) => onSlotRightClick(e, slot, slotNum, panelType));

    return slot;
}

function renderSlotContent(slot, item) {
    const def = itemDefs[item.name] || {};

    slot.dataset.hasItem = 'true';
    slot.dataset.itemName = item.name;

    // Item image
    const img = document.createElement('img');
    img.className = 'item-img';
    img.src = `images/${def.image || item.name + '.png'}`;
    img.alt = def.label || item.name;
    img.onerror = () => { img.style.display = 'none'; };
    img.draggable = false;
    slot.appendChild(img);

    // Item count (only if > 1)
    if (item.amount > 1) {
        const count = document.createElement('span');
        count.className = 'item-count';
        count.textContent = 'x' + item.amount;
        slot.appendChild(count);
    }

    // Item name (hover reveal)
    const name = document.createElement('div');
    name.className = 'item-name';
    name.textContent = def.label || item.name;
    slot.appendChild(name);

    // Durability bar
    if (item.metadata && item.metadata.durability !== undefined) {
        const durBar = document.createElement('div');
        durBar.className = 'slot-durability';
        const durFill = document.createElement('div');
        durFill.className = 'slot-durability-fill';
        durFill.style.width = item.metadata.durability + '%';
        if (item.metadata.durability < 25) durFill.style.background = '#ef4444';
        else if (item.metadata.durability < 50) durFill.style.background = '#fbbf24';
        durBar.appendChild(durFill);
        slot.appendChild(durBar);
    }

    // Jerry can fuel level display
    if (item.metadata && item.metadata.fuel !== undefined && item.name === 'jerrycan') {
        const maxCap = 20;
        const fuelPct = Math.round((item.metadata.fuel / maxCap) * 100);
        const fuelColor = fuelPct > 50 ? '#22c55e' : fuelPct > 20 ? '#fbbf24' : '#ef4444';

        // Fuel bar (like durability but at bottom)
        const fuelBar = document.createElement('div');
        fuelBar.className = 'slot-durability';
        const fuelFill = document.createElement('div');
        fuelFill.className = 'slot-durability-fill';
        fuelFill.style.width = fuelPct + '%';
        fuelFill.style.background = fuelColor;
        fuelBar.appendChild(fuelFill);
        slot.appendChild(fuelBar);

        // Fuel text label
        const fuelLabel = document.createElement('span');
        fuelLabel.className = 'item-fuel-label';
        fuelLabel.textContent = item.metadata.fuel.toFixed(1) + 'L';
        fuelLabel.style.color = fuelColor;
        slot.appendChild(fuelLabel);
    }
}

// ========================================================================
// SLOT INFO (weight bar / slot counter)
// ========================================================================
function updateSlotInfo(panelType, inv) {
    const items = inv.items || {};
    let usedSlots = 0;
    for (const key in items) {
        if (items.hasOwnProperty(key) && items[key]) usedSlots++;
    }
    const totalSlots = inv.slots || 40;
    const pct = Math.round((usedSlots / totalSlots) * 100);

    if (panelType === 'player') {
        document.getElementById('player-slot-info').textContent = usedSlots + ' / ' + totalSlots;
        document.getElementById('player-weight-bar').style.width = pct + '%';
    } else {
        document.getElementById('secondary-slot-info').textContent = usedSlots + ' / ' + totalSlots;
        document.getElementById('secondary-weight-bar').style.width = pct + '%';
    }
}

// ========================================================================
// SLOT CLICK (Select)
// ========================================================================
function onSlotClick(e, slot, slotNum, panelType, invId) {
    if (dragState && dragState.started) return;

    // Deselect if clicking same slot
    if (selectedSlot && selectedSlot.slot === slotNum && selectedSlot.panel === panelType) {
        slot.classList.remove('active');
        selectedSlot = null;
        return;
    }

    // Deselect previous
    document.querySelectorAll('.slot.active').forEach(s => s.classList.remove('active'));

    if (slot.dataset.hasItem) {
        slot.classList.add('active');
        selectedSlot = { slot: slotNum, panel: panelType, invId: invId };
    } else {
        selectedSlot = null;
    }
}

// ========================================================================
// DOUBLE-CLICK TO USE
// ========================================================================
let lastClickTime = 0;
let lastClickSlot = null;
let lastClickPanel = null;

function checkDoubleClick(slotNum, panelType) {
    const now = Date.now();
    if (lastClickSlot === slotNum && lastClickPanel === panelType && (now - lastClickTime) < 400) {
        lastClickTime = 0;
        lastClickSlot = null;
        lastClickPanel = null;
        return true;
    }
    lastClickTime = now;
    lastClickSlot = slotNum;
    lastClickPanel = panelType;
    return false;
}

// ========================================================================
// TOOLTIP (mouse-following)
// ========================================================================
function onSlotHover(e, slot, slotNum, panelType) {
    if (dragState) return;
    if (!slot.dataset.hasItem) return;

    const item = getItemFromInv(panelType, slotNum);
    if (!item) return;

    const def = itemDefs[item.name] || {};

    document.getElementById('tt-name').textContent = def.label || item.name;
    document.getElementById('tt-desc').textContent = def.description || 'No description available.';

    // Build details
    let detailsHtml = '';
    if (def.stackable && def.max_stack) {
        detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Stack</span><span class="td-value">${item.amount}/${def.max_stack}</span></div>`;
    }
    if (def.category) {
        detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Type</span><span class="td-value">${def.category}</span></div>`;
    }
    if (item.metadata) {
        if (item.metadata.durability !== undefined) {
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Durability</span><span class="td-value">${item.metadata.durability}%</span></div>`;
        }
        if (item.metadata.serial) {
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Serial</span><span class="td-value">${item.metadata.serial}</span></div>`;
        }
        if (item.metadata.ammo !== undefined) {
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Ammo</span><span class="td-value">${item.metadata.ammo}</span></div>`;
        }
        if (item.metadata.loaded !== undefined) {
            const loadedColor = item.metadata.loaded > 0 ? '#22c55e' : '#ef4444';
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Loaded</span><span class="td-value" style="color:${loadedColor}">${item.metadata.loaded} rounds</span></div>`;
        }
        if (item.metadata.rounds !== undefined) {
            const roundsColor = item.metadata.rounds > 0 ? '#22c55e' : '#ef4444';
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Contents</span><span class="td-value" style="color:${roundsColor}">${item.metadata.rounds}/100</span></div>`;
        }
        if (item.metadata.ownerName) {
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Owner</span><span class="td-value">${item.metadata.ownerName}</span></div>`;
        }
        if (item.metadata.phoneNumber) {
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Number</span><span class="td-value" style="color:#34c759">${item.metadata.phoneNumber}</span></div>`;
        }
        // Car keys metadata
        if (item.metadata.label && item.metadata.plate) {
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Vehicle</span><span class="td-value" style="color:#f97316">${item.metadata.label}</span></div>`;
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Plate</span><span class="td-value" style="color:#22c55e">${item.metadata.plate}</span></div>`;
        }
        // Jerry can fuel metadata
        if (item.metadata.fuel !== undefined) {
            const maxCapacity = 20; // Jerry can max capacity
            const fuelPct = Math.round((item.metadata.fuel / maxCapacity) * 100);
            const fuelColor = fuelPct > 50 ? '#22c55e' : fuelPct > 20 ? '#fbbf24' : '#ef4444';
            detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Fuel</span><span class="td-value" style="color:${fuelColor}">${item.metadata.fuel.toFixed(1)}L / ${maxCapacity}L</span></div>`;
        }
    }
    if (def.useable) {
        detailsHtml += `<div class="tooltip-detail-row"><span class="td-label">Useable</span><span class="td-value" style="color:#22c55e">Yes</span></div>`;
    }
    document.getElementById('tt-details').innerHTML = detailsHtml;

    tooltip.classList.remove('hidden');
}

function hideTooltip() {
    tooltip.classList.add('hidden');
}

// Follow mouse
document.addEventListener('mousemove', (e) => {
    if (!tooltip.classList.contains('hidden')) {
        let x = e.clientX + 15;
        let y = e.clientY + 15;

        // Keep tooltip on screen
        const rect = tooltip.getBoundingClientRect();
        if (x + 220 > window.innerWidth) x = e.clientX - 235;
        if (y + rect.height > window.innerHeight) y = e.clientY - rect.height - 15;

        tooltip.style.left = x + 'px';
        tooltip.style.top = y + 'px';
    }
});

// ========================================================================
// DRAG AND DROP
// ========================================================================
let ghostEl = null;
let dragStartPos = null;
const DRAG_THRESHOLD = 5;

function onSlotMouseDown(e, slot, slotNum, panelType, invId) {
    if (e.button !== 0) return;
    if (!slot.dataset.hasItem) return;

    // Check for double-click
    if (checkDoubleClick(slotNum, panelType)) {
        onDoubleClick(slotNum, panelType, invId);
        return;
    }

    const item = getItemFromInv(panelType, slotNum);
    if (!item) return;

    dragStartPos = { x: e.clientX, y: e.clientY };
    dragState = {
        fromSlot: slotNum,
        fromPanel: panelType,
        fromInvId: invId,
        item: item,
        started: false,
        sourceSlot: slot
    };

    document.addEventListener('mousemove', onDragMove);
    document.addEventListener('mouseup', onDragEnd);
}

function onDragMove(e) {
    if (!dragState) return;

    if (!dragState.started) {
        const dx = e.clientX - dragStartPos.x;
        const dy = e.clientY - dragStartPos.y;
        if (Math.abs(dx) < DRAG_THRESHOLD && Math.abs(dy) < DRAG_THRESHOLD) return;
        dragState.started = true;
        dragState.sourceSlot.classList.add('dragging');
        hideTooltip();

        // Create ghost
        ghostEl = document.createElement('div');
        ghostEl.className = 'drag-ghost';
        const def = itemDefs[dragState.item.name] || {};
        ghostEl.innerHTML = `<img src="images/${def.image || dragState.item.name + '.png'}" onerror="this.style.display='none'">`;
        document.body.appendChild(ghostEl);
    }

    if (ghostEl) {
        ghostEl.style.left = e.clientX + 'px';
        ghostEl.style.top = e.clientY + 'px';
    }

    // Highlight target slot
    document.querySelectorAll('.slot.drag-over').forEach(s => s.classList.remove('drag-over'));
    const target = getSlotUnderCursor(e);
    if (target) target.classList.add('drag-over');
}

function onDragEnd(e) {
    if (!dragState) {
        cleanupDrag();
        return;
    }

    if (dragState.started) {
        const targetSlot = getSlotUnderCursor(e);

        if (targetSlot) {
            const toSlot = parseInt(targetSlot.dataset.slot);
            const toInvId = targetSlot.dataset.invId;
            const fromServerSlot = dragState.item.slot || dragState.fromSlot;

            // Don't move to same position
            if (!(dragState.fromInvId === toInvId && fromServerSlot === toSlot)) {
                // If dragging to empty ground, create a drop instead
                if (toInvId === 'ground_empty') {
                    fetch(`https://${resourceName}/dropItem`, {
                        method: 'POST',
                        body: JSON.stringify({
                            slot: fromServerSlot,
                            amount: dragState.item.amount
                        })
                    });
                } else {
                    fetch(`https://${resourceName}/moveItem`, {
                        method: 'POST',
                        body: JSON.stringify({
                            fromInv: dragState.fromInvId,
                            toInv: toInvId,
                            fromSlot: fromServerSlot,
                            toSlot: toSlot,
                            amount: dragState.item.amount
                        })
                    });
                }
            }
        }
    }

    cleanupDrag();
}

function getSlotUnderCursor(e) {
    if (ghostEl) ghostEl.style.display = 'none';
    const elements = document.elementsFromPoint(e.clientX, e.clientY);
    if (ghostEl) ghostEl.style.display = '';
    return elements.find(el => el.classList.contains('slot'));
}

function cleanupDrag() {
    if (ghostEl) {
        ghostEl.remove();
        ghostEl = null;
    }
    document.querySelectorAll('.slot.dragging').forEach(s => s.classList.remove('dragging'));
    document.querySelectorAll('.slot.drag-over').forEach(s => s.classList.remove('drag-over'));
    document.removeEventListener('mousemove', onDragMove);
    document.removeEventListener('mouseup', onDragEnd);
    dragState = null;
    dragStartPos = null;
}

// ========================================================================
// DOUBLE-CLICK TO USE
// ========================================================================
function onDoubleClick(slotNum, panelType, invId) {
    if (panelType !== 'player') return; // Can only use from player inv

    const item = getItemFromInv(panelType, slotNum);
    if (!item) return;

    const def = itemDefs[item.name] || {};
    if (!def.useable) return;

    const serverSlot = item.slot || slotNum;
    fetch(`https://${resourceName}/useItem`, {
        method: 'POST',
        body: JSON.stringify({ slot: serverSlot })
    });
}

// ========================================================================
// ACTION BUTTONS
// ========================================================================
document.getElementById('btn-use').addEventListener('click', () => {
    if (!selectedSlot) return;
    if (selectedSlot.panel !== 'player') return;

    const item = getItemFromInv(selectedSlot.panel, selectedSlot.slot);
    if (!item) return;

    const def = itemDefs[item.name] || {};
    if (!def.useable) return;

    const serverSlot = item.slot || selectedSlot.slot;
    fetch(`https://${resourceName}/useItem`, {
        method: 'POST',
        body: JSON.stringify({ slot: serverSlot })
    });

    deselectSlot();
});

document.getElementById('btn-give').addEventListener('click', () => {
    if (!selectedSlot) return;
    if (selectedSlot.panel !== 'player') return;

    const item = getItemFromInv(selectedSlot.panel, selectedSlot.slot);
    if (!item) return;

    const serverSlot = item.slot || selectedSlot.slot;

    if (item.amount > 1) {
        showAmountModal('Give Amount', item.amount, (amount) => {
            fetch(`https://${resourceName}/giveItem`, {
                method: 'POST',
                body: JSON.stringify({ slot: serverSlot, amount: amount })
            });
        });
    } else {
        fetch(`https://${resourceName}/giveItem`, {
            method: 'POST',
            body: JSON.stringify({ slot: serverSlot, amount: 1 })
        });
    }

    deselectSlot();
});

document.getElementById('btn-split').addEventListener('click', () => {
    if (!selectedSlot) return;
    if (selectedSlot.panel !== 'player') return;

    const item = getItemFromInv(selectedSlot.panel, selectedSlot.slot);
    if (!item) return;

    const def = itemDefs[item.name] || {};
    if (item.amount <= 1 || !def.stackable) return;

    const serverSlot = item.slot || selectedSlot.slot;
    const emptySlot = findEmptySlot();
    if (!emptySlot) return;

    showAmountModal('Split Amount', item.amount - 1, (amount) => {
        fetch(`https://${resourceName}/splitItem`, {
            method: 'POST',
            body: JSON.stringify({
                fromInv: selectedSlot.invId,
                fromSlot: serverSlot,
                toSlot: emptySlot,
                amount: amount
            })
        });
    });

    deselectSlot();
});

document.getElementById('btn-drop').addEventListener('click', () => {
    if (!selectedSlot) return;
    if (selectedSlot.panel !== 'player') return;

    const item = getItemFromInv(selectedSlot.panel, selectedSlot.slot);
    if (!item) return;

    const serverSlot = item.slot || selectedSlot.slot;

    if (item.amount > 1) {
        showAmountModal('Drop Amount', item.amount, (amount) => {
            fetch(`https://${resourceName}/dropItem`, {
                method: 'POST',
                body: JSON.stringify({ slot: serverSlot, amount: amount })
            });
        });
    } else {
        fetch(`https://${resourceName}/dropItem`, {
            method: 'POST',
            body: JSON.stringify({ slot: serverSlot, amount: 1 })
        });
    }

    deselectSlot();
});

function deselectSlot() {
    document.querySelectorAll('.slot.active').forEach(s => s.classList.remove('active'));
    selectedSlot = null;
}

// ========================================================================
// AMOUNT MODAL
// ========================================================================
function showAmountModal(title, maxAmount, callback) {
    document.getElementById('modal-title').textContent = title;
    amountModal.classList.remove('hidden');
    amountInput.max = maxAmount;
    amountInput.value = Math.floor(maxAmount / 2) || 1;
    amountInput.focus();
    amountInput.select();
    amountCallback = callback;
}

document.getElementById('amount-confirm').addEventListener('click', () => {
    const amount = Math.max(1, Math.min(parseInt(amountInput.value) || 1, parseInt(amountInput.max)));
    amountModal.classList.add('hidden');
    if (amountCallback) {
        amountCallback(amount);
        amountCallback = null;
    }
});

document.getElementById('amount-cancel').addEventListener('click', () => {
    amountModal.classList.add('hidden');
    amountCallback = null;
});

amountInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('amount-confirm').click();
    else if (e.key === 'Escape') document.getElementById('amount-cancel').click();
});

// ========================================================================
// SLOT UPDATES
// ========================================================================
function updateSlot(slotNum, item) {
    if (!playerInv) return;

    if (item) {
        playerInv.items[slotNum] = item;
    } else {
        delete playerInv.items[slotNum];
    }

    // Re-render the specific slot in player grid
    const slotEl = playerGrid.querySelector(`[data-slot="${slotNum}"]`);
    if (slotEl) {
        // Keep slot number, clear the rest
        const numLabel = slotEl.querySelector('.slot-number');
        slotEl.innerHTML = '';
        delete slotEl.dataset.hasItem;
        delete slotEl.dataset.itemName;
        if (numLabel) slotEl.appendChild(numLabel);

        if (item) {
            renderSlotContent(slotEl, item);
        }

        // Deselect if this was the selected slot
        if (selectedSlot && selectedSlot.slot === slotNum && selectedSlot.panel === 'player') {
            slotEl.classList.remove('active');
            selectedSlot = null;
        }
    }

    updateSlotInfo('player', playerInv);
}

function refreshInventory(data) {
    if (playerInv && data.fromInv === playerInv.id) {
        playerInv.items = data.fromItems;
        renderGrid(playerGrid, playerInv, 'player');
        updateSlotInfo('player', playerInv);
    }
    if (playerInv && data.toInv === playerInv.id) {
        playerInv.items = data.toItems;
        renderGrid(playerGrid, playerInv, 'player');
        updateSlotInfo('player', playerInv);
    }
    if (secondaryInv && data.fromInv === secondaryInv.id) {
        secondaryInv.items = data.fromItems;
        renderGrid(secondaryGrid, secondaryInv, 'secondary');
        updateSlotInfo('secondary', secondaryInv);
    }
    if (secondaryInv && data.toInv === secondaryInv.id) {
        secondaryInv.items = data.toItems;
        renderGrid(secondaryGrid, secondaryInv, 'secondary');
        updateSlotInfo('secondary', secondaryInv);
    }

    // Clear selection after move
    deselectSlot();
}

function updateGround(data) {
    // Server sent updated ground drop data (after player dropped an item)
    if (data.secondaryInv) {
        secondaryInv = data.secondaryInv;
        document.getElementById('secondary-title').textContent = secondaryInv.label || 'Ground';
        document.getElementById('secondary-subtitle').textContent = getSecondarySubtitle(secondaryInv.type);
        renderGrid(secondaryGrid, secondaryInv, 'secondary');
        updateSlotInfo('secondary', secondaryInv);
    }
}

// ========================================================================
// HELPERS
// ========================================================================
function getItemFromInv(panelType, slot) {
    if (panelType === 'player' && playerInv) {
        return playerInv.items[slot] || null;
    } else if (panelType === 'secondary' && secondaryInv) {
        return secondaryInv.items[slot] || null;
    }
    return null;
}

function findEmptySlot() {
    if (!playerInv) return null;
    for (let i = 1; i <= playerInv.slots; i++) {
        if (!playerInv.items[i]) return i;
    }
    return null;
}

function formatMoney(amount) {
    return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// ========================================================================
// HOTBAR HUD
// ========================================================================
const hotbarEl = document.getElementById('hotbar');

function showHotbar(items, activeSlot) {
    for (let i = 1; i <= 5; i++) {
        const slotEl = document.getElementById('hb-' + i);
        if (!slotEl) continue;

        // Clear previous content (keep the key label)
        const keyLabel = slotEl.querySelector('.hb-key');
        slotEl.innerHTML = '';
        if (keyLabel) slotEl.appendChild(keyLabel);

        // Remove active state
        slotEl.classList.remove('active');

        // Mark active slot (the one just used)
        if (activeSlot && activeSlot === i) {
            slotEl.classList.add('active');
        }

        // Render item if present
        const item = items[i] || items[String(i)];
        if (item) {
            const def = itemDefs[item.name] || {};
            const img = document.createElement('img');
            img.className = 'hb-img';
            img.src = `images/${def.image || item.name + '.png'}`;
            img.onerror = () => { img.style.display = 'none'; };
            img.draggable = false;
            slotEl.appendChild(img);

            if (item.amount > 1) {
                const count = document.createElement('span');
                count.className = 'hb-count';
                count.textContent = 'x' + item.amount;
                slotEl.appendChild(count);
            }
        }
    }

    hotbarEl.classList.remove('hidden');
    hotbarEl.classList.add('visible');
}

function hideHotbar() {
    hotbarEl.classList.remove('visible');
    hotbarEl.classList.add('hidden');
}

// ========================================================================
// CONTEXT MENU (Magazine / Ammo Box right-click)
// ========================================================================
const contextMenu = document.getElementById('context-menu');
const ctxLoad = document.getElementById('ctx-load');
const ctxUnload = document.getElementById('ctx-unload');
const ctxFill = document.getElementById('ctx-fill');
const ctxEmpty = document.getElementById('ctx-empty');
let contextSlot = null; // slot number for pending context action
let contextType = null; // 'magazine' or 'ammobox'

function onSlotRightClick(e, slot, slotNum, panelType) {
    e.preventDefault();
    if (panelType !== 'player') return;
    if (!slot.dataset.hasItem) return;

    const item = getItemFromInv(panelType, slotNum);
    if (!item) return;

    const def = itemDefs[item.name] || {};

    // Hide all options first
    ctxLoad.classList.add('hidden');
    ctxUnload.classList.add('hidden');
    ctxFill.classList.add('hidden');
    ctxEmpty.classList.add('hidden');

    if (def.category === 'magazine') {
        contextType = 'magazine';
        const loaded = item.metadata && item.metadata.loaded ? item.metadata.loaded : 0;
        ctxLoad.classList.toggle('hidden', loaded > 0);
        ctxUnload.classList.toggle('hidden', loaded <= 0);
    } else if (item.name === 'p_ammobox') {
        contextType = 'ammobox';
        const rounds = item.metadata && item.metadata.rounds ? item.metadata.rounds : 0;
        ctxFill.classList.toggle('hidden', rounds >= 100);
        ctxEmpty.classList.toggle('hidden', rounds <= 0);
    } else {
        return; // No context menu for this item
    }

    // Position at cursor
    contextMenu.style.left = e.clientX + 'px';
    contextMenu.style.top = e.clientY + 'px';
    contextMenu.classList.remove('hidden');

    contextSlot = item.slot || slotNum;
}

// Hide context menu on click elsewhere
document.addEventListener('click', (e) => {
    if (!contextMenu.contains(e.target)) {
        contextMenu.classList.add('hidden');
        contextSlot = null;
        contextType = null;
    }
});

ctxLoad.addEventListener('click', () => {
    if (contextSlot === null) return;
    fetch(`https://${resourceName}/magazineAction`, {
        method: 'POST',
        body: JSON.stringify({ slot: contextSlot, action: 'load' })
    });
    contextMenu.classList.add('hidden');
    contextSlot = null;
    contextType = null;
});

ctxUnload.addEventListener('click', () => {
    if (contextSlot === null) return;
    fetch(`https://${resourceName}/magazineAction`, {
        method: 'POST',
        body: JSON.stringify({ slot: contextSlot, action: 'unload' })
    });
    contextMenu.classList.add('hidden');
    contextSlot = null;
    contextType = null;
});

ctxFill.addEventListener('click', () => {
    if (contextSlot === null) return;
    fetch(`https://${resourceName}/ammoboxAction`, {
        method: 'POST',
        body: JSON.stringify({ slot: contextSlot, action: 'fill' })
    });
    contextMenu.classList.add('hidden');
    contextSlot = null;
    contextType = null;
});

ctxEmpty.addEventListener('click', () => {
    if (contextSlot === null) return;
    fetch(`https://${resourceName}/ammoboxAction`, {
        method: 'POST',
        body: JSON.stringify({ slot: contextSlot, action: 'empty' })
    });
    contextMenu.classList.add('hidden');
    contextSlot = null;
    contextType = null;
});

// ========================================================================
// KEYBOARD SHORTCUTS
// ========================================================================
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!amountModal.classList.contains('hidden')) {
            amountModal.classList.add('hidden');
            amountCallback = null;
            return;
        }
        fetch(`https://${resourceName}/closeInventory`, { method: 'POST', body: '{}' });
    }
});
