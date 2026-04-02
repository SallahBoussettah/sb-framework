let shopItems = [];
let cart = [];
let playerCash = 0;
let playerBank = 0;
let purchasing = false;
let carryLimits = {};

const container = document.getElementById('shop-container');
const itemsList = document.getElementById('items-list');
const cartItems = document.getElementById('cart-items');
const cartCount = document.getElementById('cart-count');
const cartTotal = document.getElementById('cart-total');
const checkoutBtn = document.getElementById('checkout-btn');
const closeBtn = document.getElementById('close-btn');
const shopName = document.getElementById('shop-name');

// NUI message handler
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.type === 'open') {
        shopItems = data.items || [];
        playerCash = data.cash || 0;
        playerBank = data.bank || 0;
        carryLimits = data.carryLimits || {};
        shopName.textContent = data.shopName || 'Dealer';
        cart = [];
        purchasing = false;
        renderItems();
        renderCart();
        updateBalance();
        container.classList.remove('hidden');
    }

    if (data.type === 'close') {
        container.classList.add('hidden');
    }

    if (data.type === 'purchaseSuccess') {
        playerCash = data.cash;
        playerBank = data.bank;
        carryLimits = data.carryLimits || carryLimits;
        cart = [];
        purchasing = false;
        checkoutBtn.disabled = false;
        checkoutBtn.innerHTML = '<i class="fas fa-money-bill-wave"></i> Purchase';
        renderCart();
        updateBalance();
    }

    if (data.type === 'purchaseFailed') {
        purchasing = false;
        checkoutBtn.disabled = false;
        checkoutBtn.innerHTML = '<i class="fas fa-money-bill-wave"></i> Purchase';
    }
});

function renderItems() {
    itemsList.innerHTML = '';
    shopItems.forEach(item => {
        const el = document.createElement('div');
        el.className = 'shop-item';
        el.innerHTML = `
            <div class="shop-item-icon"><i class="fas fa-box"></i></div>
            <div class="shop-item-info">
                <div class="shop-item-name">${item.label}</div>
                <div class="shop-item-price">$${item.price.toLocaleString()}</div>
            </div>
            <button class="shop-item-add"><i class="fas fa-plus"></i></button>
        `;
        el.querySelector('.shop-item-add').addEventListener('click', (e) => {
            e.stopPropagation();
            addToCart(item);
        });
        el.addEventListener('click', () => addToCart(item));
        itemsList.appendChild(el);
    });
}

function addToCart(item) {
    const existing = cart.find(c => c.item === item.item);
    const currentQty = existing ? existing.amount : 0;

    // Check carry limit
    const limit = carryLimits[item.item];
    if (limit !== undefined && currentQty >= limit) {
        notify("Can't carry any more of this item", 'error');
        return;
    }

    // Check total quantity cap
    if (currentQty >= 50) {
        notify("Maximum quantity reached", 'error');
        return;
    }

    if (existing) {
        existing.amount++;
    } else {
        cart.push({ item: item.item, label: item.label, price: item.price, amount: 1 });
    }
    renderCart();
}

function renderCart() {
    if (cart.length === 0) {
        cartItems.innerHTML = '<div class="cart-empty"><i class="fas fa-basket-shopping"></i><p>Your cart is empty</p></div>';
        cartCount.textContent = '0';
        cartTotal.textContent = '$0';
        checkoutBtn.disabled = true;
        return;
    }

    let total = 0;
    let count = 0;
    cartItems.innerHTML = '';

    cart.forEach((entry, index) => {
        total += entry.price * entry.amount;
        count += entry.amount;

        const el = document.createElement('div');
        el.className = 'cart-item';
        el.innerHTML = `
            <div class="cart-item-info">
                <div class="cart-item-name">${entry.label}</div>
                <div class="cart-item-price">$${(entry.price * entry.amount).toLocaleString()}</div>
            </div>
            <div class="cart-qty">
                <button class="qty-minus"><i class="fas fa-minus"></i></button>
                <span>${entry.amount}</span>
                <button class="qty-plus"><i class="fas fa-plus"></i></button>
            </div>
            <button class="cart-item-remove"><i class="fas fa-xmark"></i></button>
        `;

        el.querySelector('.qty-minus').addEventListener('click', () => {
            entry.amount--;
            if (entry.amount <= 0) cart.splice(index, 1);
            renderCart();
        });

        el.querySelector('.qty-plus').addEventListener('click', () => {
            const limit = carryLimits[entry.item];
            if (limit !== undefined && entry.amount >= limit) {
                notify("Can't carry any more", 'error');
                return;
            }
            if (entry.amount >= 50) return;
            entry.amount++;
            renderCart();
        });

        el.querySelector('.cart-item-remove').addEventListener('click', () => {
            cart.splice(index, 1);
            renderCart();
        });

        cartItems.appendChild(el);
    });

    cartCount.textContent = count;
    cartTotal.textContent = '$' + total.toLocaleString();
    checkoutBtn.disabled = purchasing;
}

function updateBalance() {
    document.getElementById('balance-cash').textContent = playerCash.toLocaleString();
    document.getElementById('balance-bank').textContent = playerBank.toLocaleString();
}

function closeShop() {
    container.classList.add('hidden');
    cart = [];
    fetch('https://sb_drugs/closeShop', { method: 'POST', body: JSON.stringify({}) });
}

checkoutBtn.addEventListener('click', () => {
    if (purchasing || cart.length === 0) return;
    purchasing = true;
    checkoutBtn.disabled = true;
    checkoutBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';
    fetch('https://sb_drugs/purchaseShop', {
        method: 'POST',
        body: JSON.stringify({ cart: cart.map(c => ({ name: c.item, price: c.price, amount: c.amount })) })
    });
});

closeBtn.addEventListener('click', closeShop);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!container.classList.contains('hidden')) {
            closeShop();
        }
    }
});

function notify(msg, type) {
    fetch('https://sb_drugs/notify', {
        method: 'POST',
        body: JSON.stringify({ msg, type, duration: 3000 })
    });
}
