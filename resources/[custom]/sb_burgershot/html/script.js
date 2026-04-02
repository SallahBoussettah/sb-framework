/*
    Everyday Chaos RP - Burger Shot Supply Fridge UI
    Author: Salah Eddine Boussettah
*/

let supplyItems = [];
let cart = [];
let playerCash = 0;
let purchasing = false;

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openFridge':
            supplyItems = data.items || [];
            playerCash = data.cash || 0;
            cart = [];
            purchasing = false;
            openFridge();
            break;

        case 'closeFridge':
            closeFridge();
            break;

        case 'purchaseSuccess':
            purchasing = false;
            if (typeof data.cash === 'number') playerCash = data.cash;
            updateBalanceDisplay();
            cart = [];
            renderCart();
            break;

        case 'purchaseFailed':
            purchasing = false;
            renderCart();
            break;
    }
});

// ============================================================================
// OPEN / CLOSE
// ============================================================================

function openFridge() {
    document.getElementById('fridge-container').classList.remove('hidden');
    updateBalanceDisplay();
    renderItems();
    renderCart();
}

function closeFridge() {
    document.getElementById('fridge-container').classList.add('hidden');
}

// ============================================================================
// ITEMS
// ============================================================================

function renderItems() {
    const grid = document.getElementById('items-grid');
    grid.innerHTML = '';

    document.getElementById('item-count').textContent = supplyItems.length + ' items';

    supplyItems.forEach(item => {
        const card = document.createElement('div');
        card.className = 'item-card';
        card.innerHTML = `
            <img src="nui://sb_burgershot/images/${item.name}.png" alt="${item.label}" onerror="this.src='nui://sb_inventory/html/images/default.png'">
            <div class="item-name">${item.label}</div>
            <div class="item-price">$${item.price}</div>
        `;
        card.addEventListener('click', () => addToCart(item));
        grid.appendChild(card);
    });
}

// ============================================================================
// CART
// ============================================================================

function addToCart(item) {
    const existing = cart.find(c => c.name === item.name);
    if (existing) {
        existing.amount++;
    } else {
        cart.push({ name: item.name, label: item.label, price: item.price, amount: 1 });
    }
    renderCart();
}

function removeFromCart(index) {
    cart.splice(index, 1);
    renderCart();
}

function updateQty(index, delta) {
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
                <i class="fas fa-box-open"></i>
                <p>No items selected</p>
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
                <div class="cart-item-name">${item.label}</div>
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
// BALANCE
// ============================================================================

function updateBalanceDisplay() {
    document.getElementById('balance-cash').textContent = playerCash.toLocaleString();
}

// ============================================================================
// EVENT LISTENERS
// ============================================================================

document.getElementById('close-btn').addEventListener('click', () => {
    fetch('https://sb_burgershot/closeFridge', { method: 'POST', body: JSON.stringify({}) });
});

document.getElementById('checkout-btn').addEventListener('click', () => {
    if (cart.length === 0 || purchasing) return;
    purchasing = true;
    document.getElementById('checkout-btn').disabled = true;
    fetch('https://sb_burgershot/purchaseSupplies', {
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
        fetch('https://sb_burgershot/closeFridge', { method: 'POST', body: JSON.stringify({}) });
    }
});
