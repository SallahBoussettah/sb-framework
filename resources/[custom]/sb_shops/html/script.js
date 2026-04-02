/*
    Everyday Chaos RP - Shop System UI
    Author: Salah Eddine Boussettah
*/

let shopData = { categories: [], items: [] };
let cart = [];
let activeCategory = 'food';
let playerCash = 0;
let playerBank = 0;
let purchasing = false; // Lock during checkout
let carryLimits = {};   // { itemName: maxCanCarry }

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            shopData.categories = data.categories || [];
            shopData.items = data.items || [];
            playerCash = data.cash || 0;
            playerBank = data.bank || 0;
            carryLimits = data.carryLimits || {};
            cart = [];
            purchasing = false;
            activeCategory = shopData.categories.length > 0 ? shopData.categories[0].id : 'food';
            openShop(data.shopName);
            break;

        case 'close':
            closeShop();
            break;

        case 'purchaseSuccess':
            purchasing = false;
            if (typeof data.cash === 'number') playerCash = data.cash;
            if (typeof data.bank === 'number') playerBank = data.bank;
            updateBalanceDisplay();
            // Reduce carry limits by purchased amounts
            cart.forEach(item => {
                if (carryLimits[item.name] !== undefined) {
                    carryLimits[item.name] = Math.max(0, carryLimits[item.name] - item.amount);
                }
            });
            cart = [];
            renderCart();
            break;

        case 'purchaseFailed':
            purchasing = false;
            renderCart(); // Re-enable checkout button
            break;
    }
});

// ============================================================================
// SHOP OPEN / CLOSE
// ============================================================================

function openShop(shopName) {
    document.getElementById('shop-name').textContent = shopName || '24/7 Store';
    document.getElementById('shop-container').classList.remove('hidden');
    updateBalanceDisplay();
    renderCategories();
    renderItems();
    renderCart();
}

function closeShop() {
    document.getElementById('shop-container').classList.add('hidden');
}

// ============================================================================
// CATEGORIES
// ============================================================================

function renderCategories() {
    const container = document.getElementById('category-list');
    container.innerHTML = '';

    shopData.categories.forEach(cat => {
        const btn = document.createElement('button');
        btn.className = 'category-btn' + (cat.id === activeCategory ? ' active' : '');
        btn.innerHTML = `<i class="fas ${cat.icon}"></i><span>${cat.label}</span>`;
        btn.addEventListener('click', () => {
            activeCategory = cat.id;
            renderCategories();
            renderItems();
        });
        container.appendChild(btn);
    });
}

// ============================================================================
// ITEMS
// ============================================================================

function renderItems() {
    const grid = document.getElementById('items-grid');
    grid.innerHTML = '';

    const filtered = shopData.items.filter(item => item.category === activeCategory);
    const catLabel = shopData.categories.find(c => c.id === activeCategory);

    document.getElementById('category-title').textContent = catLabel ? catLabel.label : 'Items';
    document.getElementById('item-count').textContent = filtered.length + ' items';

    filtered.forEach(item => {
        const card = document.createElement('div');
        card.className = 'item-card';
        card.innerHTML = `
            <img src="nui://sb_inventory/html/images/${item.name}.png" alt="${item.name}" onerror="this.src='nui://sb_inventory/html/images/default.png'">
            <div class="item-name">${formatItemName(item.name)}</div>
            <div class="item-price">$${item.price}</div>
        `;
        card.addEventListener('click', () => addToCart(item));
        grid.appendChild(card);
    });
}

function formatItemName(name) {
    return name.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

// ============================================================================
// CART
// ============================================================================

function getCartAmount(itemName) {
    const entry = cart.find(c => c.name === itemName);
    return entry ? entry.amount : 0;
}

function addToCart(item) {
    const maxCarry = carryLimits[item.name];
    if (maxCarry !== undefined && maxCarry <= 0) {
        fetch('https://sb_shops/notify', {
            method: 'POST',
            body: JSON.stringify({ msg: "Can't carry any more " + formatItemName(item.name) + "!", type: 'error', duration: 3000 })
        });
        return;
    }

    const currentInCart = getCartAmount(item.name);
    if (maxCarry !== undefined && currentInCart >= maxCarry) {
        fetch('https://sb_shops/notify', {
            method: 'POST',
            body: JSON.stringify({ msg: 'Can only carry ' + maxCarry + ' more ' + formatItemName(item.name) + '!', type: 'error', duration: 3000 })
        });
        return;
    }

    const existing = cart.find(c => c.name === item.name);
    if (existing) {
        existing.amount++;
    } else {
        cart.push({ name: item.name, price: item.price, amount: 1 });
    }
    renderCart();
}

function removeFromCart(index) {
    cart.splice(index, 1);
    renderCart();
}

function updateQty(index, delta) {
    if (delta > 0) {
        const item = cart[index];
        const maxCarry = carryLimits[item.name];
        if (maxCarry !== undefined && item.amount >= maxCarry) {
            fetch('https://sb_shops/notify', {
                method: 'POST',
                body: JSON.stringify({ msg: 'Can only carry ' + maxCarry + ' more ' + formatItemName(item.name) + '!', type: 'error', duration: 3000 })
            });
            return;
        }
    }
    cart[index].amount += delta;
    if (cart[index].amount <= 0) {
        cart.splice(index, 1);
    }
    renderCart();
}

function renderCart() {
    const container = document.getElementById('cart-items');
    const totalEl = document.getElementById('cart-total');
    const countEl = document.getElementById('cart-count');
    const checkoutBtn = document.getElementById('checkout-btn');

    if (cart.length === 0) {
        container.innerHTML = `
            <div class="cart-empty">
                <i class="fas fa-basket-shopping"></i>
                <p>Your cart is empty</p>
            </div>
        `;
        totalEl.textContent = '$0';
        countEl.textContent = '0';
        checkoutBtn.disabled = true;
        return;
    }

    let total = 0;
    let totalItems = 0;
    container.innerHTML = '';

    cart.forEach((item, index) => {
        const lineTotal = item.price * item.amount;
        total += lineTotal;
        totalItems += item.amount;

        const el = document.createElement('div');
        el.className = 'cart-item';
        el.innerHTML = `
            <div class="cart-item-info">
                <div class="cart-item-name">${formatItemName(item.name)}</div>
                <div class="cart-item-price">$${item.price} each &middot; $${lineTotal}</div>
            </div>
            <div class="cart-item-controls">
                <button class="qty-btn" data-action="minus" data-index="${index}">-</button>
                <span class="cart-item-qty">${item.amount}</span>
                <button class="qty-btn" data-action="plus" data-index="${index}">+</button>
                <button class="cart-item-remove" data-action="remove" data-index="${index}">
                    <i class="fas fa-xmark"></i>
                </button>
            </div>
        `;
        container.appendChild(el);
    });

    totalEl.textContent = '$' + total;
    countEl.textContent = totalItems.toString();
    checkoutBtn.disabled = purchasing;
}

// ============================================================================
// BALANCE DISPLAY
// ============================================================================

function updateBalanceDisplay() {
    document.getElementById('balance-cash').textContent = playerCash.toLocaleString();
    document.getElementById('balance-bank').textContent = playerBank.toLocaleString();
}

// ============================================================================
// EVENT LISTENERS
// ============================================================================

document.getElementById('close-btn').addEventListener('click', () => {
    fetch('https://sb_shops/close', { method: 'POST', body: JSON.stringify({}) });
});

document.getElementById('checkout-btn').addEventListener('click', () => {
    if (cart.length === 0 || purchasing) return;
    purchasing = true;
    document.getElementById('checkout-btn').disabled = true;
    fetch('https://sb_shops/purchase', {
        method: 'POST',
        body: JSON.stringify({ cart: cart })
    });
});

// Delegated click for cart controls
document.getElementById('cart-items').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-action]');
    if (!btn) return;

    const action = btn.dataset.action;
    const index = parseInt(btn.dataset.index);

    if (action === 'minus') updateQty(index, -1);
    else if (action === 'plus') updateQty(index, 1);
    else if (action === 'remove') removeFromCart(index);
});

// Close on Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        fetch('https://sb_shops/close', { method: 'POST', body: JSON.stringify({}) });
    }
});
