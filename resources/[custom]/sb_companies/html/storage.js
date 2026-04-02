// sb_companies | Shop Storage & Sell Raw Materials NUI JS
// Dispenser panel: category-filtered item grid with grab controls
// Sell raw panel: miners sell raw materials to companies

(function() {
    'use strict';

    // ===================================================================
    // STATE
    // ===================================================================
    let storageVisible = false;
    let sellRawVisible = false;
    let storageItems = [];
    let storageCategories = [];
    let activeCategory = 'all';
    let selectedGrabQty = {};  // per-item grab quantity keyed by itemName+quality
    let currentShopId = null;

    let sellRawItems = [];
    let sellRawCompanyId = null;
    let sellRawSelectedQty = {};  // per-item sell quantity

    const storagePanel = document.getElementById('storage-panel');
    const sellRawPanel = document.getElementById('sell-raw-panel');

    // ===================================================================
    // NUI MESSAGE HANDLER
    // ===================================================================
    window.addEventListener('message', function(event) {
        const data = event.data;
        switch (data.action) {
            case 'openStorage':
                openStorage(data);
                break;
            case 'closeStorage':
                closeStorage();
                break;
            case 'refreshStorage':
                refreshStorage(data);
                break;
            case 'openSellRaw':
                openSellRaw(data);
                break;
            case 'closeSellRaw':
                closeSellRaw();
                break;
        }
    });

    // ===================================================================
    // OPEN STORAGE
    // ===================================================================
    function openStorage(data) {
        currentShopId = data.shopId || null;
        storageItems = data.items || [];
        storageCategories = data.categories || [];
        activeCategory = 'all';
        selectedGrabQty = {};

        renderStorage();
        storagePanel.classList.remove('hidden');
        storageVisible = true;
    }

    // ===================================================================
    // CLOSE STORAGE
    // ===================================================================
    function closeStorage() {
        storagePanel.classList.add('hidden');
        storageVisible = false;
    }

    // ===================================================================
    // REFRESH STORAGE
    // ===================================================================
    function refreshStorage(data) {
        if (!storageVisible) return;
        storageItems = data.items || storageItems;
        renderStorage();
    }

    // ===================================================================
    // RENDER STORAGE
    // ===================================================================
    function renderStorage() {
        let html = '';

        // Header
        html += '<div class="storage-header">';
        html += '  <div class="storage-header-left">';
        html += '    <span class="storage-badge">PARTS</span>';
        html += '    <div class="storage-title-group">';
        html += '      <span class="storage-title">SHOP STORAGE</span>';
        html += '      <span class="storage-subtitle">Parts Dispenser</span>';
        html += '    </div>';
        html += '  </div>';
        html += '  <button class="storage-close-btn" id="storage-close-btn">&times;</button>';
        html += '</div>';

        // Category filter
        html += '<div class="storage-categories">';
        html += '  <button class="storage-cat-btn' + (activeCategory === 'all' ? ' active' : '') + '" data-cat="all">ALL</button>';
        storageCategories.forEach(function(cat) {
            html += '  <button class="storage-cat-btn' + (activeCategory === cat ? ' active' : '') + '" data-cat="' + escapeHtml(cat) + '">' + escapeHtml(cat.toUpperCase()) + '</button>';
        });
        html += '</div>';

        // Item list
        html += '<div class="storage-list" id="storage-list">';

        const filtered = storageItems.filter(function(item) {
            if (activeCategory === 'all') return true;
            return item.category === activeCategory;
        });

        if (filtered.length === 0) {
            html += '<div class="storage-empty">';
            html += '  <div class="storage-empty-icon">&#9634;</div>';
            html += '  <span class="storage-empty-text">No items in this category</span>';
            html += '</div>';
        } else {
            filtered.forEach(function(item) {
                var key = item.name + '_' + (item.quality || 'standard');
                var qty = selectedGrabQty[key] || 1;
                var qualityName = item.quality || 'standard';
                var qualityLabel = qualityName.charAt(0).toUpperCase() + qualityName.slice(1);

                html += '<div class="storage-item-row">';
                html += '  <span class="storage-item-name">' + escapeHtml(item.label || item.name) + '</span>';
                html += '  <span class="storage-item-qty">x' + item.quantity + '</span>';
                html += '  <span class="storage-quality-badge quality-' + escapeHtml(qualityName) + '">' + escapeHtml(qualityLabel) + '</span>';

                // Grab quantity selector
                html += '  <div class="storage-grab-controls">';
                [1, 5, 10].forEach(function(q) {
                    html += '    <button class="storage-qty-btn' + (qty === q ? ' active' : '') + '" data-item="' + escapeHtml(key) + '" data-qty="' + q + '">' + q + '</button>';
                });
                html += '    <button class="storage-grab-btn" data-item-name="' + escapeHtml(item.name) + '" data-quality="' + escapeHtml(qualityName) + '" data-key="' + escapeHtml(key) + '"' + (item.quantity <= 0 ? ' disabled' : '') + '>GRAB</button>';
                html += '  </div>';

                html += '</div>';
            });
        }

        html += '</div>';

        storagePanel.innerHTML = html;
        wireStorageEvents();
    }

    // ===================================================================
    // WIRE STORAGE EVENTS
    // ===================================================================
    function wireStorageEvents() {
        // Close button
        var closeBtn = document.getElementById('storage-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', function() {
                nuiCallback('closeStorage', {});
            });
        }

        // Category buttons
        document.querySelectorAll('.storage-cat-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                activeCategory = this.dataset.cat;
                renderStorage();
            });
        });

        // Quantity buttons
        document.querySelectorAll('.storage-qty-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var key = this.dataset.item;
                var qty = parseInt(this.dataset.qty) || 1;
                selectedGrabQty[key] = qty;
                renderStorage();
            });
        });

        // Grab buttons
        document.querySelectorAll('.storage-grab-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                if (this.disabled) return;
                var itemName = this.dataset.itemName;
                var quality = this.dataset.quality;
                var key = this.dataset.key;
                var qty = selectedGrabQty[key] || 1;

                nuiCallback('grabFromStorage', {
                    shopId: currentShopId,
                    itemName: itemName,
                    quantity: qty,
                    quality: quality,
                });
            });
        });
    }

    // ===================================================================
    // OPEN SELL RAW
    // ===================================================================
    function openSellRaw(data) {
        sellRawCompanyId = data.companyId || null;
        sellRawItems = data.items || [];
        sellRawSelectedQty = {};

        renderSellRaw(data.companyLabel || 'Company');
        sellRawPanel.classList.remove('hidden');
        sellRawVisible = true;
    }

    // ===================================================================
    // CLOSE SELL RAW
    // ===================================================================
    function closeSellRaw() {
        sellRawPanel.classList.add('hidden');
        sellRawVisible = false;
    }

    // ===================================================================
    // RENDER SELL RAW
    // ===================================================================
    function renderSellRaw(companyLabel) {
        var html = '';

        // Header
        html += '<div class="sell-raw-header">';
        html += '  <div class="sell-raw-header-left">';
        html += '    <span class="sell-raw-badge">SELL</span>';
        html += '    <div class="storage-title-group">';
        html += '      <span class="sell-raw-title">RAW MATERIALS</span>';
        html += '      <span class="sell-raw-company">' + escapeHtml(companyLabel) + '</span>';
        html += '    </div>';
        html += '  </div>';
        html += '  <button class="storage-close-btn" id="sell-raw-close-btn">&times;</button>';
        html += '</div>';

        // Item list
        html += '<div class="sell-raw-list" id="sell-raw-list">';

        if (sellRawItems.length === 0) {
            html += '<div class="storage-empty">';
            html += '  <div class="storage-empty-icon">&#9634;</div>';
            html += '  <span class="storage-empty-text">No raw materials to sell</span>';
            html += '</div>';
        } else {
            sellRawItems.forEach(function(item) {
                var key = item.name;
                var qty = sellRawSelectedQty[key] || 1;
                var sellQty = Math.min(qty, item.have || 0);

                html += '<div class="sell-raw-row">';
                html += '  <span class="sell-raw-name">' + escapeHtml(item.label || item.name) + '</span>';
                html += '  <span class="sell-raw-have">x' + (item.have || 0) + '</span>';
                html += '  <span class="sell-raw-price">$' + item.price + '/ea</span>';

                // Quantity selector
                html += '  <div class="sell-raw-qty-controls">';
                [1, 5, 10].forEach(function(q) {
                    html += '    <button class="sell-raw-qty-btn' + (qty === q ? ' active' : '') + '" data-item="' + escapeHtml(key) + '" data-qty="' + q + '">' + q + '</button>';
                });
                html += '  </div>';

                html += '  <button class="sell-raw-sell-btn" data-item-name="' + escapeHtml(item.name) + '" data-key="' + escapeHtml(key) + '"' + ((item.have || 0) <= 0 ? ' disabled' : '') + '>SELL</button>';
                html += '</div>';
            });
        }

        html += '</div>';

        sellRawPanel.innerHTML = html;
        wireSellRawEvents(companyLabel);
    }

    // ===================================================================
    // WIRE SELL RAW EVENTS
    // ===================================================================
    function wireSellRawEvents(companyLabel) {
        // Close button
        var closeBtn = document.getElementById('sell-raw-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', function() {
                nuiCallback('closeSellRaw', {});
            });
        }

        // Quantity buttons
        document.querySelectorAll('.sell-raw-qty-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var key = this.dataset.item;
                var qty = parseInt(this.dataset.qty) || 1;
                sellRawSelectedQty[key] = qty;
                renderSellRaw(companyLabel);
            });
        });

        // Sell buttons
        document.querySelectorAll('.sell-raw-sell-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                if (this.disabled) return;
                var itemName = this.dataset.itemName;
                var key = this.dataset.key;
                var qty = sellRawSelectedQty[key] || 1;

                nuiCallback('sellRawMaterial', {
                    companyId: sellRawCompanyId,
                    itemName: itemName,
                    quantity: qty,
                });
            });
        });
    }

    // ===================================================================
    // ESCAPE KEY HANDLER
    // ===================================================================
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            if (storageVisible) {
                nuiCallback('closeStorage', {});
            }
            if (sellRawVisible) {
                nuiCallback('closeSellRaw', {});
            }
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
    function escapeHtml(str) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str || ''));
        return div.innerHTML;
    }

})();
