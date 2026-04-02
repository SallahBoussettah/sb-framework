/*
    Everyday Chaos RP - Wardrobe UI Script
    Author: Salah Eddine Boussettah
    Design: Split Panel Layout
*/

// ============================================================================
// STATE
// ============================================================================

let storeData = {
    storeName: 'Clothing Store',
    storeType: 'suburban',
    priceMultiplier: 1.0,
    categories: [],
    basePrices: {},
    clothingData: {},
    freeComponents: {},
    ownedClothing: {},
    cash: 0,
    bank: 0,
    playerName: 'Unknown',
    citizenId: 'EC-00000'
};

let currentCategory = null;
let currentComponentKey = null;  // e.g., 'comp_11', 'prop_0'
let currentDrawable = 0;         // Relative index (0-based)
let currentTexture = 0;
let maxDrawables = 0;
let maxTextures = 1;
let startDrawable = 0;           // Vanilla offset

let cart = [];
let viewingWardrobe = false;     // Are we in "My Wardrobe" view?
let equippedItems = {};          // Track currently equipped items { 'comp_11': {drawable, texture}, 'prop_0': {drawable, texture} }

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openStore(data);
            break;
        case 'close':
            hideUI();
            break;
        case 'updateMoney':
            storeData.cash = data.cash;
            storeData.bank = data.bank;
            updateMoneyDisplay();
            break;
        case 'updateOwnedClothing':
            storeData.ownedClothing = data.ownedClothing || {};
            if (viewingWardrobe) renderWardrobe();
            break;
    }
});

// ============================================================================
// OPEN/CLOSE STORE
// ============================================================================

function openStore(data) {
    storeData = {
        storeName: data.storeName || 'Clothing Store',
        storeType: data.storeType || 'suburban',
        priceMultiplier: data.priceMultiplier || 1.0,
        categories: data.categories || [],
        basePrices: data.basePrices || {},
        clothingData: data.clothingData || {},
        freeComponents: data.freeComponents || {},
        ownedClothing: data.ownedClothing || {},
        cash: data.cash || 0,
        bank: data.bank || 0,
        playerName: data.playerName || 'Unknown',
        citizenId: data.citizenId || 'EC-00000'
    };

    // Reset state
    currentCategory = null;
    currentComponentKey = null;
    cart = [];
    viewingWardrobe = false;
    equippedItems = {};

    // Initialize equipped items from current clothing data
    Object.keys(storeData.clothingData).forEach(key => {
        const data = storeData.clothingData[key];
        if (data.currentDrawable !== undefined) {
            equippedItems[key] = {
                drawable: data.currentDrawable,
                texture: data.currentTexture || 0
            };
        }
    });

    // Update UI
    document.getElementById('playerName').textContent = storeData.playerName;
    document.getElementById('playerCitizenId').textContent = storeData.citizenId;
    document.getElementById('storeName').textContent = storeData.storeName;

    renderCategoryTabs();
    updateMoneyDisplay();
    updateCartDisplay();

    // Select first category by default
    if (storeData.categories.length > 0) {
        selectCategory(storeData.categories[0]);
    }

    // Show UI
    document.getElementById('app').classList.remove('hidden');
}

function hideUI() {
    document.getElementById('app').classList.add('hidden');
}

function cancelShopping() {
    fetch('https://sb_clothing/close', {
        method: 'POST',
        body: JSON.stringify({ revert: true })
    });
}

// ============================================================================
// CATEGORY TABS
// ============================================================================

function renderCategoryTabs() {
    const container = document.getElementById('categoryTabs');
    container.innerHTML = '';

    // Add "My Wardrobe" tab first
    const wardrobeTab = document.createElement('div');
    wardrobeTab.className = 'category-tab wardrobe-tab';
    wardrobeTab.dataset.categoryId = 'wardrobe';
    wardrobeTab.innerHTML = `<i class="fas fa-box-open"></i><span>My Wardrobe</span>`;
    wardrobeTab.onclick = () => openWardrobe();
    container.appendChild(wardrobeTab);

    // Add regular category tabs
    storeData.categories.forEach(cat => {
        const tab = document.createElement('div');
        tab.className = 'category-tab';
        tab.dataset.categoryId = cat.id;
        tab.innerHTML = `<i class="fas ${cat.icon}"></i><span>${cat.label}</span>`;
        tab.onclick = () => selectCategory(cat);
        container.appendChild(tab);
    });
}

function selectCategory(category) {
    currentCategory = category;
    viewingWardrobe = false;

    // Update active state
    document.querySelectorAll('.category-tab').forEach(tab => {
        tab.classList.toggle('active', tab.dataset.categoryId === category.id);
    });

    // Show store UI, hide wardrobe UI
    document.getElementById('storeContent').classList.remove('hidden');
    document.getElementById('wardrobeContent').classList.add('hidden');

    // Render component tabs for this category
    renderComponentTabs(category);
}

// ============================================================================
// COMPONENT TABS (within category)
// ============================================================================

function renderComponentTabs(category) {
    const container = document.getElementById('componentTabs');
    container.innerHTML = '';

    let items = [];

    // Add component tabs
    if (category.components) {
        category.components.forEach(compId => {
            const key = 'comp_' + compId;
            const data = storeData.clothingData[key];
            if (data && data.maxDrawables > 0) {
                items.push({ key, name: data.name, type: 'component', id: compId });
            }
        });
    }

    // Add prop tabs
    if (category.props) {
        category.props.forEach(propId => {
            const key = 'prop_' + propId;
            const data = storeData.clothingData[key];
            // Props always show (can set to -1 for "none")
            if (data) {
                items.push({ key, name: data.name, type: 'prop', id: propId });
            }
        });
    }

    items.forEach((item, index) => {
        const tab = document.createElement('div');
        tab.className = 'component-tab' + (index === 0 ? ' active' : '');
        tab.dataset.key = item.key;
        tab.textContent = item.name;
        tab.onclick = () => selectComponent(item.key, tab);
        container.appendChild(tab);
    });

    // Select first component
    if (items.length > 0) {
        selectComponent(items[0].key, container.querySelector('.component-tab'));
    }
}

function selectComponent(key, tabElement) {
    currentComponentKey = key;

    // Update active tab
    document.querySelectorAll('.component-tab').forEach(t => t.classList.remove('active'));
    if (tabElement) tabElement.classList.add('active');

    // Get component data
    const data = storeData.clothingData[key];
    if (!data) return;

    maxDrawables = data.maxDrawables || 0;
    startDrawable = data.startDrawable || 0;

    // For props, start at -1 (none); for components, start at 0
    if (data.type === 'prop') {
        currentDrawable = -1;
    } else {
        currentDrawable = 0;
    }
    currentTexture = 0;

    updateTexturesForDrawable();
    updateDrawableDisplay();
    updatePrice();
    renderClothingGrid();
    previewItem();
}

// ============================================================================
// DRAWABLE CONTROL
// ============================================================================

function changeDrawable(delta) {
    if (!currentComponentKey) return;

    const data = storeData.clothingData[currentComponentKey];
    const isProp = data && data.type === 'prop';
    const minVal = isProp ? -1 : 0;

    currentDrawable += delta;

    // Wrap around
    if (currentDrawable >= maxDrawables) {
        currentDrawable = minVal;
    } else if (currentDrawable < minVal) {
        currentDrawable = maxDrawables - 1;
    }

    currentTexture = 0;
    updateTexturesForDrawable();
    updateDrawableDisplay();
    updatePrice();
    renderClothingGrid();
    previewItem();
}

function updateDrawableDisplay() {
    const data = storeData.clothingData[currentComponentKey];
    const isProp = data && data.type === 'prop';

    // Slider fill
    const fill = document.getElementById('sliderFill');
    if (maxDrawables > 0) {
        const pct = ((currentDrawable + (isProp ? 1 : 0)) / (maxDrawables + (isProp ? 1 : 0))) * 100;
        fill.style.width = Math.max(5, pct) + '%';
    } else {
        fill.style.width = '0%';
    }

    // Label
    document.getElementById('drawableLabel').textContent = data ? data.name : 'Style';

    // Value
    let valueText;
    if (isProp && currentDrawable < 0) {
        valueText = 'None';
    } else {
        valueText = `${currentDrawable + 1} / ${maxDrawables}`;
    }
    document.getElementById('drawableValue').textContent = valueText;
}

// ============================================================================
// TEXTURE CONTROL
// ============================================================================

function updateTexturesForDrawable() {
    if (!currentComponentKey) return;

    const data = storeData.clothingData[currentComponentKey];
    const isProp = data && data.type === 'prop';
    const actualDrawable = currentDrawable >= 0 ? currentDrawable + startDrawable : currentDrawable;

    if (isProp && currentDrawable < 0) {
        maxTextures = 1;
        updateTextureDisplay();
        return;
    }

    fetch('https://sb_clothing/getTextures', {
        method: 'POST',
        body: JSON.stringify({
            isProp: isProp,
            id: data.id,
            drawable: actualDrawable
        })
    })
    .then(resp => resp.json())
    .then(result => {
        maxTextures = result.textures ? result.textures.length : 1;
        if (maxTextures < 1) maxTextures = 1;
        updateTextureDisplay();
    })
    .catch(() => {
        maxTextures = 1;
        updateTextureDisplay();
    });
}

function changeTexture(delta) {
    if (!currentComponentKey) return;

    const data = storeData.clothingData[currentComponentKey];
    if (data && data.type === 'prop' && currentDrawable < 0) return;

    currentTexture += delta;

    if (currentTexture >= maxTextures) currentTexture = 0;
    if (currentTexture < 0) currentTexture = maxTextures - 1;

    updateTextureDisplay();
    previewItem();
}

function updateTextureDisplay() {
    document.getElementById('textureValue').textContent = `${currentTexture + 1} / ${maxTextures}`;
}

// ============================================================================
// CLOTHING GRID
// ============================================================================

function renderClothingGrid() {
    const container = document.getElementById('clothingGrid');
    container.innerHTML = '';

    const data = storeData.clothingData[currentComponentKey];
    const isProp = data && data.type === 'prop';
    const gridSize = 6; // Show 6 items around current

    // Calculate range
    let start = Math.max(isProp ? -1 : 0, currentDrawable - 2);
    let end = Math.min(maxDrawables - 1, start + gridSize - 1);

    // Adjust start if end is capped
    if (end === maxDrawables - 1) {
        start = Math.max(isProp ? -1 : 0, end - gridSize + 1);
    }

    for (let i = start; i <= end; i++) {
        const item = document.createElement('div');
        item.className = 'grid-item' + (i === currentDrawable ? ' selected' : '');
        item.onclick = () => selectDrawableFromGrid(i);

        if (isProp && i < 0) {
            item.innerHTML = `
                <div class="grid-icon"><i class="fas fa-ban"></i></div>
                <span class="grid-label">NONE</span>
            `;
        } else {
            item.innerHTML = `
                <div class="grid-number">${i + 1}</div>
            `;
        }

        container.appendChild(item);
    }
}

function selectDrawableFromGrid(drawable) {
    currentDrawable = drawable;
    currentTexture = 0;
    updateTexturesForDrawable();
    updateDrawableDisplay();
    updatePrice();
    renderClothingGrid();
    previewItem();
}

// ============================================================================
// PREVIEW
// ============================================================================

function previewItem() {
    if (!currentComponentKey) return;

    const data = storeData.clothingData[currentComponentKey];
    const isProp = data && data.type === 'prop';
    const actualDrawable = currentDrawable >= 0 ? currentDrawable + startDrawable : currentDrawable;

    if (isProp) {
        fetch('https://sb_clothing/previewProp', {
            method: 'POST',
            body: JSON.stringify({
                propId: data.id,
                drawable: actualDrawable,
                texture: currentTexture
            })
        });
    } else {
        fetch('https://sb_clothing/previewComponent', {
            method: 'POST',
            body: JSON.stringify({
                componentId: data.id,
                drawable: actualDrawable,
                texture: currentTexture
            })
        });
    }
}

// ============================================================================
// PRICING
// ============================================================================

function isCurrentItemFree() {
    if (!currentComponentKey) return false;
    const data = storeData.clothingData[currentComponentKey];
    if (!data) return false;

    // "None" option (removing item) is always FREE
    if (data.type === 'prop' && currentDrawable < 0) {
        return true;
    }

    // Check if this component is in the free list
    if (data.type === 'component' && storeData.freeComponents[data.id]) {
        return true;
    }

    // Also check if category is marked as free
    if (currentCategory && currentCategory.free) {
        return true;
    }

    return false;
}

function getItemPrice() {
    if (!currentComponentKey) return 0;

    // Check if item is free
    if (isCurrentItemFree()) return 0;

    const data = storeData.clothingData[currentComponentKey];
    if (!data) return 0;

    let basePrice;
    if (data.type === 'prop') {
        basePrice = storeData.basePrices['prop_' + data.id] || 100;
    } else {
        basePrice = storeData.basePrices[data.id] || 100;
    }

    return Math.floor(basePrice * storeData.priceMultiplier);
}

function updatePrice() {
    const price = getItemPrice();
    const priceElement = document.getElementById('itemPrice');

    if (isCurrentItemFree()) {
        priceElement.textContent = 'FREE';
        priceElement.classList.add('free-price');
    } else {
        priceElement.textContent = '$' + formatMoney(price);
        priceElement.classList.remove('free-price');
    }
}

// ============================================================================
// CART
// ============================================================================

function addToCart() {
    if (!currentComponentKey) return;

    const data = storeData.clothingData[currentComponentKey];
    if (!data) return;

    const actualDrawable = currentDrawable >= 0 ? currentDrawable + startDrawable : currentDrawable;
    const price = getItemPrice();

    // Check if already in cart
    const existingIndex = cart.findIndex(c => c.key === currentComponentKey);
    if (existingIndex >= 0) {
        cart[existingIndex].drawable = actualDrawable;
        cart[existingIndex].displayDrawable = currentDrawable;
        cart[existingIndex].texture = currentTexture;
        cart[existingIndex].price = price;
    } else {
        cart.push({
            key: currentComponentKey,
            type: data.type,
            id: data.id,
            name: data.name,
            drawable: actualDrawable,
            displayDrawable: currentDrawable,
            texture: currentTexture,
            price: price
        });
    }

    updateCartDisplay();
}

function removeFromCart(index) {
    cart.splice(index, 1);
    updateCartDisplay();
}

function updateCartDisplay() {
    const container = document.getElementById('cartItems');

    if (cart.length === 0) {
        container.innerHTML = '<div class="empty-cart">No items selected</div>';
    } else {
        let html = '';
        cart.forEach((item, index) => {
            const displayNum = item.displayDrawable !== undefined ? item.displayDrawable : item.drawable;
            const detail = item.type === 'prop' && displayNum < 0 ? 'None' : `#${displayNum + 1}`;

            html += `
                <div class="cart-item">
                    <span class="cart-item-name">${item.name} ${detail}</span>
                    <span class="cart-item-price">$${formatMoney(item.price)}</span>
                    <button class="cart-item-remove" onclick="removeFromCart(${index})">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
            `;
        });
        container.innerHTML = html;
    }

    // Update totals
    const total = cart.reduce((sum, item) => sum + item.price, 0);
    const totalMoney = storeData.cash + storeData.bank;
    const balanceAfter = totalMoney - total;

    document.getElementById('totalCost').textContent = '$' + formatMoney(total);
    document.getElementById('balanceAfter').textContent = '$' + formatMoney(Math.max(0, balanceAfter));

    // Enable/disable purchase button
    const purchaseBtn = document.querySelector('.btn-purchase');
    purchaseBtn.disabled = cart.length === 0 || total > totalMoney;
}

// ============================================================================
// MONEY DISPLAY
// ============================================================================

function updateMoneyDisplay() {
    const cash = storeData.cash;
    const bank = storeData.bank;
    const total = cash + bank;
    const maxDisplay = Math.max(total, 50000); // Cap for bar display

    document.getElementById('cashDisplay').textContent = '$' + formatMoney(cash);
    document.getElementById('bankDisplay').textContent = '$' + formatMoney(bank);

    // Update bars
    document.getElementById('cashBar').style.width = Math.min(100, (cash / maxDisplay) * 100) + '%';
    document.getElementById('bankBar').style.width = Math.min(100, (bank / maxDisplay) * 100) + '%';

    updateCartDisplay();
}

// ============================================================================
// PURCHASE
// ============================================================================

function checkout() {
    if (cart.length === 0) return;

    const items = cart.map(item => ({
        type: item.type,
        id: item.id,
        drawable: item.drawable,
        texture: item.texture
    }));

    fetch('https://sb_clothing/purchase', {
        method: 'POST',
        body: JSON.stringify({ items })
    });

    // Clear cart
    cart = [];
    updateCartDisplay();
}

// ============================================================================
// CAMERA CONTROLS
// ============================================================================

// Mouse drag rotation (right-click or left-click in center area)
let isDragging = false;
let lastMouseX = 0;

document.addEventListener('mousedown', (e) => {
    // Only start drag if clicking in center area (not on panels)
    const isOnPanel = e.target.closest('.panel, .panel-left, .panel-right');
    if (!isOnPanel && (e.button === 0 || e.button === 2)) {
        isDragging = true;
        lastMouseX = e.clientX;
        e.preventDefault();
    }
});

document.addEventListener('mousemove', (e) => {
    if (!isDragging) return;

    const deltaX = e.clientX - lastMouseX;
    lastMouseX = e.clientX;

    if (deltaX !== 0) {
        fetch('https://sb_clothing/rotatePlayer', {
            method: 'POST',
            body: JSON.stringify({ deltaX: deltaX })
        });
    }
});

document.addEventListener('mouseup', (e) => {
    isDragging = false;
});

// Prevent context menu on right-click
document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
});

// Scroll wheel zoom
document.addEventListener('wheel', (e) => {
    // Don't zoom if scrolling inside panels
    const isInsidePanel = e.target.closest('.panel, .panel-left, .panel-right, .items-list, .clothing-grid, .category-tabs, .component-tabs');
    if (isInsidePanel) return;

    const delta = e.deltaY > 0 ? 1 : -1;
    fetch('https://sb_clothing/zoomCamera', {
        method: 'POST',
        body: JSON.stringify({ delta })
    });
});

// ============================================================================
// KEYBOARD SHORTCUTS
// ============================================================================

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        cancelShopping();
    }
});

// ============================================================================
// MY WARDROBE (Owned Clothing)
// ============================================================================

function openWardrobe() {
    viewingWardrobe = true;
    currentCategory = null;

    // Update active tab
    document.querySelectorAll('.category-tab').forEach(tab => {
        tab.classList.toggle('active', tab.dataset.categoryId === 'wardrobe');
    });

    // Hide store content, show wardrobe content
    document.getElementById('storeContent').classList.add('hidden');
    document.getElementById('wardrobeContent').classList.remove('hidden');

    renderWardrobe();
}

function isItemEquipped(type, id, drawable, texture) {
    const key = type === 'component' ? 'comp_' + id : 'prop_' + id;
    const equipped = equippedItems[key];
    if (!equipped) return false;
    return equipped.drawable === drawable && equipped.texture === texture;
}

function renderWardrobe() {
    const container = document.getElementById('wardrobeItems');
    const owned = storeData.ownedClothing;
    const keys = Object.keys(owned);

    if (keys.length === 0) {
        container.innerHTML = '<div class="empty-wardrobe">No purchased items yet</div>';
        return;
    }

    // Group by type
    const components = {};
    const props = {};

    keys.forEach(key => {
        const item = owned[key];
        if (item.type === 'component') {
            if (!components[item.id]) components[item.id] = [];
            components[item.id].push(item);
        } else if (item.type === 'prop') {
            if (!props[item.id]) props[item.id] = [];
            props[item.id].push(item);
        }
    });

    let html = '';

    // Render components
    const compIds = Object.keys(components);
    if (compIds.length > 0) {
        html += '<div class="wardrobe-section"><h4>Clothing</h4>';
        compIds.forEach(compId => {
            const compName = storeData.clothingData['comp_' + compId]?.name || 'Component ' + compId;
            html += `<div class="wardrobe-group"><span class="wardrobe-group-name">${compName}</span>`;
            components[compId].forEach(item => {
                const isEquipped = isItemEquipped('component', item.id, item.drawable, item.texture);
                html += `
                    <div class="wardrobe-item ${isEquipped ? 'equipped' : ''}" onclick="toggleOwnedItem('component', ${item.id}, ${item.drawable}, ${item.texture})">
                        <span class="wardrobe-item-label">#${item.drawable + 1} / Var ${item.texture + 1}</span>
                        <i class="fas ${isEquipped ? 'fa-times-circle' : 'fa-check-circle'}"></i>
                    </div>
                `;
            });
            html += '</div>';
        });
        html += '</div>';
    }

    // Render props
    const propIds = Object.keys(props);
    if (propIds.length > 0) {
        html += '<div class="wardrobe-section"><h4>Accessories</h4>';
        propIds.forEach(propId => {
            const propName = storeData.clothingData['prop_' + propId]?.name || 'Prop ' + propId;
            html += `<div class="wardrobe-group"><span class="wardrobe-group-name">${propName}</span>`;
            props[propId].forEach(item => {
                const isEquipped = isItemEquipped('prop', item.id, item.drawable, item.texture);
                html += `
                    <div class="wardrobe-item ${isEquipped ? 'equipped' : ''}" onclick="toggleOwnedItem('prop', ${item.id}, ${item.drawable}, ${item.texture})">
                        <span class="wardrobe-item-label">#${item.drawable + 1} / Var ${item.texture + 1}</span>
                        <i class="fas ${isEquipped ? 'fa-times-circle' : 'fa-check-circle'}"></i>
                    </div>
                `;
            });
            html += '</div>';
        });
        html += '</div>';
    }

    container.innerHTML = html;
}

function toggleOwnedItem(type, id, drawable, texture) {
    const key = type === 'component' ? 'comp_' + id : 'prop_' + id;
    const isEquipped = isItemEquipped(type, id, drawable, texture);

    if (isEquipped) {
        // Unequip - set to none/default
        if (type === 'prop') {
            // Use the same callback as store preview
            fetch('https://sb_clothing/previewProp', {
                method: 'POST',
                body: JSON.stringify({ propId: id, drawable: -1, texture: 0 })
            });
            equippedItems[key] = { drawable: -1, texture: 0 };
        } else {
            // Set to default (naked) - use same callback as store
            const nakedDefaults = {
                1: 0,   // Mask
                3: 15,  // Torso
                4: 21,  // Pants (shorts)
                5: 0,   // Bag
                6: 34,  // Shoes (barefoot)
                7: 0,   // Accessory
                8: 15,  // Undershirt
                9: 0,   // Armor
                10: 0,  // Decal
                11: 15  // Top
            };
            const defaultDrawable = nakedDefaults[id] || 0;
            fetch('https://sb_clothing/previewComponent', {
                method: 'POST',
                body: JSON.stringify({ componentId: id, drawable: defaultDrawable, texture: 0 })
            });
            equippedItems[key] = { drawable: defaultDrawable, texture: 0 };
        }
    } else {
        // Equip - use the SAME callbacks that the store preview uses
        if (type === 'prop') {
            fetch('https://sb_clothing/previewProp', {
                method: 'POST',
                body: JSON.stringify({ propId: id, drawable: drawable, texture: texture })
            });
        } else {
            fetch('https://sb_clothing/previewComponent', {
                method: 'POST',
                body: JSON.stringify({ componentId: id, drawable: drawable, texture: texture })
            });
        }
        equippedItems[key] = { drawable, texture };
    }

    // Re-render to show updated state
    renderWardrobe();
}

function saveWardrobeChanges() {
    fetch('https://sb_clothing/saveOwnedAppearance', {
        method: 'POST',
        body: JSON.stringify({})
    });
}

// ============================================================================
// UTILITIES
// ============================================================================

function formatMoney(amount) {
    return Math.floor(amount).toLocaleString();
}
