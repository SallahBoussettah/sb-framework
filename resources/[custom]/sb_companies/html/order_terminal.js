// sb_companies | Order Terminal NUI JS
// 3 company tabs + order history, product grid, cart, payment

(function() {
    'use strict';

    // ===================================================================
    // STATE
    // ===================================================================
    let isVisible = false;
    let activeTab = 'santos_metal';  // company id or 'history'
    let companies = [];              // { id, label, products: [...] }
    let cart = [];                   // { name, label, price, category, quantity, stock }
    let paymentType = 'bank';
    let playerCash = 0;
    let playerBank = 0;
    let orderHistory = [];
    let searchText = '';
    let currentShopId = null;

    const panel = document.getElementById('order-panel');

    // ===================================================================
    // NUI MESSAGE HANDLER
    // ===================================================================
    window.addEventListener('message', function(event) {
        var data = event.data;
        switch (data.action) {
            case 'openOrderTerminal':
                openTerminal(data);
                break;
            case 'closeOrderTerminal':
                closeTerminal();
                break;
            case 'refreshOrderTerminal':
                if (data.companies) companies = data.companies;
                if (data.playerCash !== undefined) playerCash = data.playerCash;
                if (data.playerBank !== undefined) playerBank = data.playerBank;
                render();
                break;
        }
    });

    // ===================================================================
    // OPEN TERMINAL
    // ===================================================================
    function openTerminal(data) {
        currentShopId = data.shopId || null;
        companies = data.companies || [];
        playerCash = data.playerCash || 0;
        playerBank = data.playerBank || 0;
        cart = [];
        paymentType = 'bank';
        searchText = '';
        orderHistory = [];
        activeTab = companies.length > 0 ? companies[0].id : 'history';

        render();
        panel.classList.remove('hidden');
        isVisible = true;
    }

    // ===================================================================
    // CLOSE TERMINAL
    // ===================================================================
    function closeTerminal() {
        panel.classList.add('hidden');
        isVisible = false;
    }

    // ===================================================================
    // RENDER
    // ===================================================================
    function render() {
        var html = '';

        // Header
        html += '<div class="order-header">';
        html += '  <div class="order-header-left">';
        html += '    <span class="order-badge">ORDER</span>';
        html += '    <span class="order-title">PARTS TERMINAL</span>';
        html += '  </div>';
        html += '  <button class="order-close-btn" id="order-close-btn">&times;</button>';
        html += '</div>';

        // Company tabs
        html += '<div class="order-company-tabs">';
        companies.forEach(function(company) {
            html += '<button class="order-company-tab' + (activeTab === company.id ? ' active' : '') + '" data-tab="' + esc(company.id) + '">' + esc(company.label) + '</button>';
        });
        html += '<button class="order-company-tab history-tab' + (activeTab === 'history' ? ' active' : '') + '" data-tab="history">HISTORY</button>';
        html += '</div>';

        // Content
        if (activeTab === 'history') {
            html += renderHistory();
        } else {
            html += renderShop();
        }

        panel.innerHTML = html;
        wireEvents();
    }

    // ===================================================================
    // RENDER SHOP (products + cart)
    // ===================================================================
    function renderShop() {
        var company = companies.find(function(c) { return c.id === activeTab; });
        var products = company ? (company.products || []) : [];
        var filtered = products.filter(function(p) {
            if (!searchText) return true;
            return p.label.toLowerCase().indexOf(searchText.toLowerCase()) !== -1 ||
                   p.name.toLowerCase().indexOf(searchText.toLowerCase()) !== -1 ||
                   (p.category || '').toLowerCase().indexOf(searchText.toLowerCase()) !== -1;
        });

        var html = '<div class="order-content">';

        // Products (left)
        html += '<div class="order-products">';
        html += '  <div class="order-products-header">';
        html += '    <span class="order-search-icon">&#128269;</span>';
        html += '    <input type="text" class="order-search" id="order-search" placeholder="Search products..." value="' + esc(searchText) + '" autocomplete="off">';
        html += '  </div>';
        html += '  <div class="order-product-list">';

        if (filtered.length === 0) {
            html += '    <div class="order-history-empty"><span>No products found</span></div>';
        } else {
            filtered.forEach(function(product) {
                var inStock = (product.stock === undefined || product.stock === null || product.stock > 0);
                html += '<div class="order-product-row">';
                html += '  <span class="order-product-name">' + esc(product.label) + '</span>';
                if (product.category) {
                    html += '  <span class="order-product-category">' + esc(product.category) + '</span>';
                }
                html += '  <span class="order-product-stock' + (!inStock ? ' out' : '') + '">' + (inStock ? (product.stock !== undefined && product.stock !== null ? 'x' + product.stock : 'IN') : 'OUT') + '</span>';
                html += '  <span class="order-product-price">$' + product.price + '</span>';
                html += '  <button class="order-add-btn" data-name="' + esc(product.name) + '" data-label="' + esc(product.label) + '" data-price="' + product.price + '" data-category="' + esc(product.category || '') + '" data-stock="' + (product.stock !== undefined && product.stock !== null ? product.stock : -1) + '"' + (!inStock ? ' disabled' : '') + '>+ADD</button>';
                html += '</div>';
            });
        }

        html += '  </div>';
        html += '</div>';

        // Cart (right)
        html += '<div class="order-cart">';
        html += '  <div class="order-cart-header">';
        html += '    <span class="order-cart-title">CART</span>';
        html += '    <span class="order-cart-count">' + cart.length + ' items</span>';
        html += '  </div>';

        if (cart.length === 0) {
            html += '  <div class="order-cart-empty"><span>Cart is empty</span></div>';
        } else {
            html += '  <div class="order-cart-items">';
            cart.forEach(function(item, idx) {
                html += '<div class="order-cart-row">';
                html += '  <span class="order-cart-item-name">' + esc(item.label) + '</span>';
                html += '  <div class="order-cart-item-qty">';
                html += '    <button class="order-cart-qty-btn" data-idx="' + idx + '" data-dir="-1">-</button>';
                html += '    <span class="order-cart-qty-display">' + item.quantity + '</span>';
                html += '    <button class="order-cart-qty-btn" data-idx="' + idx + '" data-dir="1">+</button>';
                html += '  </div>';
                html += '  <span class="order-cart-item-total">$' + (item.price * item.quantity) + '</span>';
                html += '  <button class="order-cart-remove" data-idx="' + idx + '">&times;</button>';
                html += '</div>';
            });
            html += '  </div>';
        }

        // Cart footer
        var total = cart.reduce(function(sum, item) { return sum + (item.price * item.quantity); }, 0);
        html += '  <div class="order-cart-footer">';
        html += '    <div class="order-cart-total">';
        html += '      <span class="order-cart-total-label">TOTAL</span>';
        html += '      <span class="order-cart-total-value">$' + total + '</span>';
        html += '    </div>';

        // Payment
        html += '    <div class="order-payment">';
        html += '      <button class="order-pay-btn' + (paymentType === 'cash' ? ' active' : '') + '" data-pay="cash">Cash ($' + playerCash + ')</button>';
        html += '      <button class="order-pay-btn' + (paymentType === 'bank' ? ' active' : '') + '" data-pay="bank">Bank ($' + playerBank + ')</button>';
        html += '    </div>';

        var funds = paymentType === 'cash' ? playerCash : playerBank;
        var canOrder = cart.length > 0 && total <= funds;
        html += '    <button class="order-place-btn" id="order-place-btn"' + (!canOrder ? ' disabled' : '') + '>PLACE ORDER</button>';
        html += '  </div>';

        html += '</div>'; // cart
        html += '</div>'; // content

        return html;
    }

    // ===================================================================
    // RENDER HISTORY
    // ===================================================================
    function renderHistory() {
        var html = '<div class="order-history">';
        html += '  <div class="order-history-list" id="order-history-list">';

        if (orderHistory.length === 0) {
            html += '<div class="order-history-empty">';
            html += '  <span>Loading order history...</span>';
            html += '</div>';
        } else {
            orderHistory.forEach(function(order) {
                html += '<div class="order-history-row">';
                html += '  <span class="order-history-id">#' + order.id + '</span>';
                html += '  <span class="order-history-items-summary">' + esc(order.summary || order.items_summary || '--') + '</span>';
                html += '  <span class="order-history-total">$' + (order.total || 0) + '</span>';
                html += '  <span class="order-history-status order-status-' + esc(order.status || 'pending') + '">' + esc(order.status || 'pending') + '</span>';
                html += '  <span class="order-history-date">' + esc(order.date || '') + '</span>';

                // Only show cancel for pending orders
                if (order.status === 'pending') {
                    html += '  <button class="order-history-cancel-btn" data-order-id="' + order.id + '">CANCEL</button>';
                }

                html += '</div>';
            });
        }

        html += '  </div>';
        html += '</div>';

        return html;
    }

    // ===================================================================
    // WIRE EVENTS
    // ===================================================================
    function wireEvents() {
        // Close
        var closeBtn = document.getElementById('order-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', function() {
                nuiCallback('closeOrderTerminal', {});
            });
        }

        // Company tabs
        document.querySelectorAll('.order-company-tab').forEach(function(tab) {
            tab.addEventListener('click', function() {
                var tabId = this.dataset.tab;
                activeTab = tabId;
                searchText = '';
                if (tabId === 'history') {
                    fetchOrderHistory();
                }
                render();
            });
        });

        // Search
        var searchInput = document.getElementById('order-search');
        if (searchInput) {
            searchInput.addEventListener('input', function() {
                searchText = this.value;
                render();
                // Restore focus after re-render
                var newInput = document.getElementById('order-search');
                if (newInput) {
                    newInput.focus();
                    newInput.setSelectionRange(newInput.value.length, newInput.value.length);
                }
            });
        }

        // Add to cart
        document.querySelectorAll('.order-add-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                if (this.disabled) return;
                var name = this.dataset.name;
                var label = this.dataset.label;
                var price = parseInt(this.dataset.price) || 0;
                var category = this.dataset.category;
                var stock = parseInt(this.dataset.stock);

                // Check if already in cart
                var existing = cart.find(function(c) { return c.name === name; });
                if (existing) {
                    if (stock >= 0 && existing.quantity >= stock) return;
                    existing.quantity++;
                } else {
                    cart.push({
                        name: name,
                        label: label,
                        price: price,
                        category: category,
                        quantity: 1,
                        stock: stock,
                    });
                }
                render();
            });
        });

        // Cart quantity buttons
        document.querySelectorAll('.order-cart-qty-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var idx = parseInt(this.dataset.idx);
                var dir = parseInt(this.dataset.dir);
                if (idx < 0 || idx >= cart.length) return;

                cart[idx].quantity += dir;
                if (cart[idx].quantity <= 0) {
                    cart.splice(idx, 1);
                } else if (cart[idx].stock >= 0 && cart[idx].quantity > cart[idx].stock) {
                    cart[idx].quantity = cart[idx].stock;
                }
                render();
            });
        });

        // Cart remove
        document.querySelectorAll('.order-cart-remove').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var idx = parseInt(this.dataset.idx);
                if (idx >= 0 && idx < cart.length) {
                    cart.splice(idx, 1);
                    render();
                }
            });
        });

        // Payment buttons
        document.querySelectorAll('.order-pay-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                paymentType = this.dataset.pay;
                render();
            });
        });

        // Place order
        var placeBtn = document.getElementById('order-place-btn');
        if (placeBtn) {
            placeBtn.addEventListener('click', function() {
                if (this.disabled || cart.length === 0) return;

                var items = cart.map(function(item) {
                    return {
                        name: item.name,
                        label: item.label,
                        quantity: item.quantity,
                        price: item.price,
                    };
                });

                var total = cart.reduce(function(sum, item) { return sum + (item.price * item.quantity); }, 0);

                nuiCallback('placeOrder', {
                    shopId: currentShopId,
                    companyId: activeTab,
                    items: items,
                    total: total,
                    paymentType: paymentType,
                });

                // Clear cart after placing
                cart = [];
                render();
            });
        }

        // Cancel order buttons
        document.querySelectorAll('.order-history-cancel-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var orderId = parseInt(this.dataset.orderId);
                nuiCallback('cancelOrder', { orderId: orderId });

                // Optimistic update
                var order = orderHistory.find(function(o) { return o.id === orderId; });
                if (order) order.status = 'cancelled';
                render();
            });
        });
    }

    // ===================================================================
    // FETCH ORDER HISTORY
    // ===================================================================
    function fetchOrderHistory() {
        nuiCallback('getOrderHistory', { shopId: currentShopId }, function(data) {
            if (data && data.orders) {
                orderHistory = data.orders;
                if (activeTab === 'history') render();
            }
        });
    }

    // ===================================================================
    // ESCAPE KEY
    // ===================================================================
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isVisible) {
            nuiCallback('closeOrderTerminal', {});
        }
    });

    // ===================================================================
    // NUI CALLBACK HELPER
    // ===================================================================
    function nuiCallback(name, data, onResponse) {
        fetch('https://sb_companies/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        })
        .then(function(resp) { return resp.json(); })
        .then(function(result) {
            if (onResponse) onResponse(result);
        })
        .catch(function() {
            if (onResponse) onResponse(null);
        });
    }

    // ===================================================================
    // HTML ESCAPE HELPER
    // ===================================================================
    function esc(str) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str || ''));
        return div.innerHTML;
    }

})();
