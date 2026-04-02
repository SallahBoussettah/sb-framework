// sb_companies | Production Tablet NUI JS
// Company workers: view pending orders, craft items from recipes

(function() {
    'use strict';

    // ===================================================================
    // STATE
    // ===================================================================
    let isVisible = false;
    let activeTab = 'orders'; // 'orders' or 'craft'
    let pendingOrders = [];
    let selectedOrder = null;
    let craftableRecipes = [];   // recipes available at this company
    let craftSearch = '';
    let companyId = null;
    let companyLabel = '';

    const panel = document.getElementById('production-panel');

    // ===================================================================
    // NUI MESSAGE HANDLER
    // ===================================================================
    window.addEventListener('message', function(event) {
        var data = event.data;
        switch (data.action) {
            case 'openProduction':
                openProduction(data);
                break;
            case 'closeProduction':
                closeProduction();
                break;
        }
    });

    // ===================================================================
    // OPEN PRODUCTION
    // ===================================================================
    function openProduction(data) {
        companyId = data.companyId || null;
        companyLabel = data.companyLabel || 'Production';
        pendingOrders = data.pendingOrders || [];
        craftableRecipes = data.recipes || [];
        selectedOrder = null;
        activeTab = 'orders';
        craftSearch = '';

        render();
        panel.classList.remove('hidden');
        isVisible = true;
    }

    // ===================================================================
    // CLOSE PRODUCTION
    // ===================================================================
    function closeProduction() {
        panel.classList.add('hidden');
        isVisible = false;
    }

    // ===================================================================
    // RENDER
    // ===================================================================
    function render() {
        var html = '';

        // Header
        html += '<div class="prod-header">';
        html += '  <div class="prod-header-left">';
        html += '    <span class="prod-badge">PROD</span>';
        html += '    <div class="prod-title-group">';
        html += '      <span class="prod-title">PRODUCTION TERMINAL</span>';
        html += '      <span class="prod-subtitle">' + esc(companyLabel) + '</span>';
        html += '    </div>';
        html += '  </div>';
        html += '  <button class="prod-close-btn" id="prod-close-btn">&times;</button>';
        html += '</div>';

        // Tab bar
        html += '<div class="prod-tabs">';
        html += '  <button class="prod-tab' + (activeTab === 'orders' ? ' active' : '') + '" data-tab="orders">PENDING ORDERS</button>';
        html += '  <button class="prod-tab' + (activeTab === 'craft' ? ' active' : '') + '" data-tab="craft">CRAFT ITEMS</button>';
        html += '</div>';

        // Content
        html += '<div class="prod-content">';

        if (activeTab === 'orders') {
            html += renderOrders();
        } else {
            html += renderCraft();
        }

        html += '</div>';

        panel.innerHTML = html;
        wireEvents();
    }

    // ===================================================================
    // RENDER PENDING ORDERS
    // ===================================================================
    function renderOrders() {
        var html = '';

        // Orders list (left)
        html += '<div class="prod-orders-panel">';
        html += '  <div class="prod-orders-header">';
        html += '    <span class="prod-orders-title">ORDERS</span>';
        html += '    <span class="prod-orders-count">' + pendingOrders.length + '</span>';
        html += '  </div>';
        html += '  <div class="prod-orders-list">';

        if (pendingOrders.length === 0) {
            html += '<div class="prod-orders-empty"><span>No pending orders</span></div>';
        } else {
            pendingOrders.forEach(function(order, idx) {
                var isSelected = selectedOrder && selectedOrder.id === order.id;
                html += '<div class="prod-order-row' + (isSelected ? ' selected' : '') + '" data-order-idx="' + idx + '">';
                html += '  <div class="prod-order-top">';
                html += '    <span class="prod-order-id">#' + order.id + '</span>';
                html += '    <span class="prod-order-shop">' + esc(order.shopLabel || order.shop_id || '--') + '</span>';
                html += '    <span class="prod-order-status ' + esc(order.status || 'pending') + '">' + esc(order.status || 'pending') + '</span>';
                html += '  </div>';
                html += '  <span class="prod-order-items">' + esc(order.summary || '--') + '</span>';
                html += '</div>';
            });
        }

        html += '  </div>';
        html += '</div>';

        // Selected order detail (right) - shows items to craft for this order
        html += '<div class="prod-craft-panel">';

        if (!selectedOrder) {
            html += '<div class="prod-craft-empty"><span>Select an order to see required items</span></div>';
        } else {
            html += '<div class="prod-craft-header">';
            html += '  <span style="font-family:\'JetBrains Mono\',monospace;font-size:10px;font-weight:600;color:#555;letter-spacing:1px;">ORDER #' + selectedOrder.id + ' ITEMS</span>';
            html += '</div>';
            html += '<div class="prod-craft-list">';

            var items = selectedOrder.items || [];
            if (items.length === 0) {
                html += '<div class="prod-craft-empty"><span>No items in this order</span></div>';
            } else {
                items.forEach(function(item) {
                    var fulfilled = item.fulfilled || 0;
                    var needed = item.quantity - fulfilled;
                    var isDone = needed <= 0;

                    html += '<div class="prod-craft-row">';
                    html += '  <span class="prod-craft-can-dot' + (isDone ? ' can' : '') + '"></span>';
                    html += '  <span class="prod-craft-name">' + esc(item.label || item.name) + '</span>';
                    html += '  <span class="prod-craft-result">' + fulfilled + '/' + item.quantity + '</span>';
                    html += '  <button class="prod-craft-btn" data-recipe-id="' + esc(item.recipeId || item.name) + '" data-order-id="' + selectedOrder.id + '"' + (isDone ? ' disabled' : '') + '>' + (isDone ? 'DONE' : 'CRAFT') + '</button>';
                    html += '</div>';
                });
            }

            html += '</div>';
        }

        html += '</div>';

        return html;
    }

    // ===================================================================
    // RENDER CRAFT LIST
    // ===================================================================
    function renderCraft() {
        var filtered = craftableRecipes.filter(function(recipe) {
            if (!craftSearch) return true;
            var s = craftSearch.toLowerCase();
            return recipe.label.toLowerCase().indexOf(s) !== -1 ||
                   recipe.resultItem.toLowerCase().indexOf(s) !== -1;
        });

        var html = '<div class="prod-craft-panel" style="width:100%;">';

        // Search
        html += '<div class="prod-craft-header">';
        html += '  <span style="color:#444;font-size:11px;">&#128269;</span>';
        html += '  <input type="text" class="prod-craft-search" id="prod-craft-search" placeholder="Search recipes..." value="' + esc(craftSearch) + '" autocomplete="off">';
        html += '</div>';

        html += '<div class="prod-craft-list">';

        if (filtered.length === 0) {
            html += '<div class="prod-craft-empty"><span>No recipes available</span></div>';
        } else {
            filtered.forEach(function(recipe) {
                var canCraft = recipe.canCraft !== undefined ? recipe.canCraft : true;

                html += '<div class="prod-craft-row">';
                html += '  <span class="prod-craft-can-dot' + (canCraft ? ' can' : '') + '"></span>';
                html += '  <span class="prod-craft-name">' + esc(recipe.label) + '</span>';
                html += '  <span class="prod-craft-result">x' + (recipe.resultAmount || 1) + '</span>';
                html += '  <span class="prod-craft-level">L' + (recipe.skillReq || 1) + '</span>';
                html += '  <span class="prod-craft-time">' + ((recipe.craftTime || 0) / 1000) + 's</span>';
                html += '  <button class="prod-craft-btn" data-recipe-id="' + esc(recipe.id) + '"' + (!canCraft ? ' disabled' : '') + '>' + (canCraft ? 'CRAFT' : 'MISSING') + '</button>';
                html += '</div>';

                // Ingredient hints
                if (recipe.ingredients && recipe.ingredients.length > 0) {
                    html += '<div class="prod-craft-needed">';
                    recipe.ingredients.forEach(function(ing) {
                        var has = ing.have !== undefined ? (ing.have >= ing.amount) : true;
                        var cls = has ? 'has' : 'missing';
                        html += '<span class="prod-craft-ingredient ' + cls + '">' + esc(ing.label || ing.item) + ' ' + (ing.have !== undefined ? ing.have : '?') + '/' + ing.amount + '</span>';
                    });
                    html += '</div>';
                }
            });
        }

        html += '</div>';
        html += '</div>';

        return html;
    }

    // ===================================================================
    // WIRE EVENTS
    // ===================================================================
    function wireEvents() {
        // Close
        var closeBtn = document.getElementById('prod-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', function() {
                nuiCallback('closeProduction', {});
            });
        }

        // Tabs
        document.querySelectorAll('.prod-tab').forEach(function(tab) {
            tab.addEventListener('click', function() {
                activeTab = this.dataset.tab;
                render();
            });
        });

        // Order rows
        document.querySelectorAll('.prod-order-row').forEach(function(row) {
            row.addEventListener('click', function() {
                var idx = parseInt(this.dataset.orderIdx);
                if (idx >= 0 && idx < pendingOrders.length) {
                    selectedOrder = pendingOrders[idx];
                    render();
                }
            });
        });

        // Craft search
        var searchInput = document.getElementById('prod-craft-search');
        if (searchInput) {
            searchInput.addEventListener('input', function() {
                craftSearch = this.value;
                render();
                var newInput = document.getElementById('prod-craft-search');
                if (newInput) {
                    newInput.focus();
                    newInput.setSelectionRange(newInput.value.length, newInput.value.length);
                }
            });
        }

        // Craft buttons
        document.querySelectorAll('.prod-craft-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                if (this.disabled) return;
                var recipeId = this.dataset.recipeId;
                var orderId = this.dataset.orderId ? parseInt(this.dataset.orderId) : null;

                nuiCallback('startCraft', {
                    companyId: companyId,
                    recipeId: recipeId,
                    orderId: orderId,
                });
            });
        });
    }

    // ===================================================================
    // ESCAPE KEY
    // ===================================================================
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isVisible) {
            nuiCallback('closeProduction', {});
        }
    });

    // ===================================================================
    // NUI CALLBACK HELPER
    // ===================================================================
    function nuiCallback(name, data) {
        fetch('https://sb_companies/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch(function() {});
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
