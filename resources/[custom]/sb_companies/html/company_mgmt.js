// sb_companies | Company Management Dashboard NUI JS
// Tabs: Overview, Catalog (pricing), Employees (hire/fire), Finances (withdraw/deposit/log)

(function() {
    'use strict';

    // ===================================================================
    // STATE
    // ===================================================================
    let isVisible = false;
    let activeTab = 'overview';  // overview | catalog | employees | finances
    let companyId = null;
    let companyLabel = '';

    // Overview data
    let overview = {
        balance: 0,
        totalOrders: 0,
        pendingOrders: 0,
        employeeCount: 0,
        todaySales: 0,
        todayExpenses: 0,
        recentActivity: [],
    };

    // Catalog data
    let catalogItems = [];       // { name, label, category, costPrice, sellPrice, originalPrice }
    let catalogEdits = {};       // name -> edited price

    // Employees data
    let employees = [];          // { citizenid, name, role }

    // Finances data
    let transactions = [];       // { id, date, type, description, amount }

    const panel = document.getElementById('management-panel');

    // ===================================================================
    // NUI MESSAGE HANDLER
    // ===================================================================
    window.addEventListener('message', function(event) {
        var data = event.data;
        switch (data.action) {
            case 'openManagement':
                openManagement(data);
                break;
            case 'closeManagement':
                closeManagement();
                break;
        }
    });

    // ===================================================================
    // OPEN MANAGEMENT
    // ===================================================================
    function openManagement(data) {
        companyId = data.companyId || null;
        companyLabel = data.companyLabel || 'Company';

        overview = data.overview || overview;
        catalogItems = data.catalog || [];
        catalogEdits = {};
        employees = data.employees || [];
        transactions = data.transactions || [];

        activeTab = 'overview';

        render();
        panel.classList.remove('hidden');
        isVisible = true;
    }

    // ===================================================================
    // CLOSE MANAGEMENT
    // ===================================================================
    function closeManagement() {
        panel.classList.add('hidden');
        isVisible = false;
    }

    // ===================================================================
    // RENDER
    // ===================================================================
    function render() {
        var html = '';

        // Header
        html += '<div class="mgmt-header">';
        html += '  <div class="mgmt-header-left">';
        html += '    <span class="mgmt-badge">MGMT</span>';
        html += '    <div class="mgmt-title-group">';
        html += '      <span class="mgmt-title">COMPANY MANAGEMENT</span>';
        html += '      <span class="mgmt-subtitle">' + esc(companyLabel) + '</span>';
        html += '    </div>';
        html += '  </div>';
        html += '  <button class="mgmt-close-btn" id="mgmt-close-btn">&times;</button>';
        html += '</div>';

        // Tabs
        html += '<div class="mgmt-tabs">';
        html += '  <button class="mgmt-tab' + (activeTab === 'overview' ? ' active' : '') + '" data-tab="overview">OVERVIEW</button>';
        html += '  <button class="mgmt-tab' + (activeTab === 'catalog' ? ' active' : '') + '" data-tab="catalog">CATALOG</button>';
        html += '  <button class="mgmt-tab' + (activeTab === 'employees' ? ' active' : '') + '" data-tab="employees">EMPLOYEES</button>';
        html += '  <button class="mgmt-tab' + (activeTab === 'finances' ? ' active' : '') + '" data-tab="finances">FINANCES</button>';
        html += '</div>';

        // Content
        html += '<div class="mgmt-content">';

        switch (activeTab) {
            case 'overview':   html += renderOverview(); break;
            case 'catalog':    html += renderCatalog(); break;
            case 'employees':  html += renderEmployees(); break;
            case 'finances':   html += renderFinances(); break;
        }

        html += '</div>';

        panel.innerHTML = html;
        wireEvents();
    }

    // ===================================================================
    // RENDER: OVERVIEW
    // ===================================================================
    function renderOverview() {
        var html = '';

        // Stat cards
        html += '<div class="mgmt-stats-grid">';

        html += '<div class="mgmt-stat-card">';
        html += '  <span class="mgmt-stat-label">BALANCE</span>';
        html += '  <span class="mgmt-stat-value money">$' + formatNum(overview.balance || 0) + '</span>';
        html += '</div>';

        html += '<div class="mgmt-stat-card">';
        html += '  <span class="mgmt-stat-label">TOTAL ORDERS</span>';
        html += '  <span class="mgmt-stat-value">' + (overview.totalOrders || 0) + '</span>';
        html += '  <span class="mgmt-stat-sub">' + (overview.pendingOrders || 0) + ' pending</span>';
        html += '</div>';

        html += '<div class="mgmt-stat-card">';
        html += '  <span class="mgmt-stat-label">EMPLOYEES</span>';
        html += '  <span class="mgmt-stat-value">' + (overview.employeeCount || 0) + '</span>';
        html += '</div>';

        html += '<div class="mgmt-stat-card">';
        html += '  <span class="mgmt-stat-label">TODAY P&L</span>';
        var todayPL = (overview.todaySales || 0) - (overview.todayExpenses || 0);
        html += '  <span class="mgmt-stat-value' + (todayPL >= 0 ? ' money' : '') + '" style="' + (todayPL < 0 ? 'color:#ff4757' : '') + '">$' + formatNum(todayPL) + '</span>';
        html += '  <span class="mgmt-stat-sub">Sales: $' + formatNum(overview.todaySales || 0) + '</span>';
        html += '</div>';

        html += '</div>';

        // Recent activity
        html += '<div class="mgmt-section-title">RECENT ACTIVITY</div>';
        html += '<div class="mgmt-activity-list">';

        var activity = overview.recentActivity || [];
        if (activity.length === 0) {
            html += '<div class="mgmt-empty"><span>No recent activity</span></div>';
        } else {
            activity.forEach(function(item) {
                html += '<div class="mgmt-activity-row">';
                html += '  <span class="mgmt-activity-time">' + esc(item.time || '') + '</span>';
                html += '  <span class="mgmt-activity-text">' + esc(item.text || '') + '</span>';
                if (item.amount !== undefined) {
                    var cls = item.amount >= 0 ? 'income' : 'expense';
                    html += '  <span class="mgmt-activity-amount ' + cls + '">' + (item.amount >= 0 ? '+' : '') + '$' + formatNum(item.amount) + '</span>';
                }
                html += '</div>';
            });
        }

        html += '</div>';
        return html;
    }

    // ===================================================================
    // RENDER: CATALOG
    // ===================================================================
    function renderCatalog() {
        var html = '';

        html += '<div class="mgmt-section-title">PRODUCT PRICING</div>';
        html += '<div class="mgmt-catalog-list">';

        if (catalogItems.length === 0) {
            html += '<div class="mgmt-empty"><span>No catalog items</span></div>';
        } else {
            catalogItems.forEach(function(item) {
                var editedPrice = catalogEdits[item.name] !== undefined ? catalogEdits[item.name] : item.sellPrice;
                var hasChanged = editedPrice !== item.sellPrice;

                html += '<div class="mgmt-catalog-row">';
                html += '  <span class="mgmt-catalog-name">' + esc(item.label || item.name) + '</span>';
                if (item.category) {
                    html += '  <span class="mgmt-catalog-category">' + esc(item.category) + '</span>';
                }
                html += '  <span class="mgmt-catalog-cost">Cost: $' + (item.costPrice || 0) + '</span>';

                // Price adjustment
                html += '  <div class="mgmt-catalog-price-controls">';
                html += '    <button class="mgmt-price-btn" data-item="' + esc(item.name) + '" data-dir="-10">-</button>';
                html += '    <span class="mgmt-catalog-price">$' + editedPrice + '</span>';
                html += '    <button class="mgmt-price-btn" data-item="' + esc(item.name) + '" data-dir="10">+</button>';
                if (hasChanged) {
                    html += '    <button class="mgmt-price-save-btn" data-item="' + esc(item.name) + '" data-price="' + editedPrice + '">SAVE</button>';
                }
                html += '  </div>';

                html += '</div>';
            });
        }

        html += '</div>';
        return html;
    }

    // ===================================================================
    // RENDER: EMPLOYEES
    // ===================================================================
    function renderEmployees() {
        var html = '';

        // Hire form
        html += '<div class="mgmt-employees-header">';
        html += '  <div class="mgmt-section-title" style="margin-bottom:0;">EMPLOYEE ROSTER</div>';
        html += '  <div class="mgmt-hire-form">';
        html += '    <input type="text" class="mgmt-hire-input" id="mgmt-hire-input" placeholder="Citizen ID..." autocomplete="off">';
        html += '    <select class="mgmt-role-select" id="mgmt-role-select">';
        html += '      <option value="worker">Worker</option>';
        html += '      <option value="driver">Driver</option>';
        html += '      <option value="manager">Manager</option>';
        html += '    </select>';
        html += '    <button class="mgmt-hire-btn" id="mgmt-hire-btn">HIRE</button>';
        html += '  </div>';
        html += '</div>';

        html += '<div class="mgmt-employee-list">';

        if (employees.length === 0) {
            html += '<div class="mgmt-empty"><span>No employees</span></div>';
        } else {
            employees.forEach(function(emp) {
                html += '<div class="mgmt-employee-row">';
                html += '  <span class="mgmt-employee-name">' + esc(emp.name || 'Unknown') + '</span>';
                html += '  <span class="mgmt-employee-cid">' + esc(emp.citizenid || '') + '</span>';
                html += '  <span class="mgmt-employee-role mgmt-role-' + esc(emp.role || 'worker') + '">' + esc(emp.role || 'worker') + '</span>';
                html += '  <button class="mgmt-fire-btn" data-cid="' + esc(emp.citizenid || '') + '">FIRE</button>';
                html += '</div>';
            });
        }

        html += '</div>';
        return html;
    }

    // ===================================================================
    // RENDER: FINANCES
    // ===================================================================
    function renderFinances() {
        var html = '';

        // Withdraw / Deposit cards
        html += '<div class="mgmt-finance-actions">';

        // Withdraw
        html += '<div class="mgmt-finance-card">';
        html += '  <span class="mgmt-finance-card-title">WITHDRAW TO BANK</span>';
        html += '  <div class="mgmt-finance-input-row">';
        html += '    <input type="number" class="mgmt-finance-input" id="mgmt-withdraw-amount" placeholder="Amount..." min="1">';
        html += '    <button class="mgmt-withdraw-btn" id="mgmt-withdraw-btn">WITHDRAW</button>';
        html += '  </div>';
        html += '</div>';

        // Deposit
        html += '<div class="mgmt-finance-card">';
        html += '  <span class="mgmt-finance-card-title">DEPOSIT FROM BANK</span>';
        html += '  <div class="mgmt-finance-input-row">';
        html += '    <input type="number" class="mgmt-finance-input" id="mgmt-deposit-amount" placeholder="Amount..." min="1">';
        html += '    <button class="mgmt-deposit-btn" id="mgmt-deposit-btn">DEPOSIT</button>';
        html += '  </div>';
        html += '</div>';

        html += '</div>';

        // Transaction log
        html += '<div class="mgmt-section-title">TRANSACTION HISTORY</div>';
        html += '<div class="mgmt-txn-log">';

        if (transactions.length === 0) {
            html += '<div class="mgmt-empty"><span>No transactions</span></div>';
        } else {
            transactions.forEach(function(txn) {
                var isPositive = txn.amount >= 0;
                html += '<div class="mgmt-txn-row">';
                html += '  <span class="mgmt-txn-date">' + esc(txn.date || '') + '</span>';
                html += '  <span class="mgmt-txn-type ' + esc(txn.type || '') + '">' + esc(formatTxnType(txn.type)) + '</span>';
                html += '  <span class="mgmt-txn-desc">' + esc(txn.description || '') + '</span>';
                html += '  <span class="mgmt-txn-amount ' + (isPositive ? 'positive' : 'negative') + '">' + (isPositive ? '+' : '') + '$' + formatNum(txn.amount || 0) + '</span>';
                html += '</div>';
            });
        }

        html += '</div>';
        return html;
    }

    // ===================================================================
    // WIRE EVENTS
    // ===================================================================
    function wireEvents() {
        // Close
        var closeBtn = document.getElementById('mgmt-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', function() {
                nuiCallback('closeManagement', {});
            });
        }

        // Tabs
        document.querySelectorAll('.mgmt-tab').forEach(function(tab) {
            tab.addEventListener('click', function() {
                activeTab = this.dataset.tab;
                render();
            });
        });

        // Catalog: price adjust
        document.querySelectorAll('.mgmt-price-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var itemName = this.dataset.item;
                var dir = parseInt(this.dataset.dir) || 0;
                var item = catalogItems.find(function(i) { return i.name === itemName; });
                if (!item) return;

                var current = catalogEdits[itemName] !== undefined ? catalogEdits[itemName] : item.sellPrice;
                var newPrice = Math.max(1, current + dir);
                catalogEdits[itemName] = newPrice;
                render();
            });
        });

        // Catalog: save price
        document.querySelectorAll('.mgmt-price-save-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var itemName = this.dataset.item;
                var newPrice = parseInt(this.dataset.price) || 0;

                nuiCallback('adjustPrice', {
                    companyId: companyId,
                    itemName: itemName,
                    newPrice: newPrice,
                });

                // Optimistic update
                var item = catalogItems.find(function(i) { return i.name === itemName; });
                if (item) item.sellPrice = newPrice;
                delete catalogEdits[itemName];
                render();
            });
        });

        // Hire
        var hireBtn = document.getElementById('mgmt-hire-btn');
        if (hireBtn) {
            hireBtn.addEventListener('click', function() {
                var cidInput = document.getElementById('mgmt-hire-input');
                var roleSelect = document.getElementById('mgmt-role-select');
                if (!cidInput || !roleSelect) return;

                var cid = cidInput.value.trim();
                var role = roleSelect.value;
                if (!cid) return;

                nuiCallback('hireEmployee', {
                    companyId: companyId,
                    citizenid: cid,
                    role: role,
                });

                cidInput.value = '';
            });
        }

        // Fire
        document.querySelectorAll('.mgmt-fire-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var cid = this.dataset.cid;
                nuiCallback('fireEmployee', {
                    companyId: companyId,
                    citizenid: cid,
                });

                // Optimistic update
                employees = employees.filter(function(e) { return e.citizenid !== cid; });
                render();
            });
        });

        // Withdraw
        var withdrawBtn = document.getElementById('mgmt-withdraw-btn');
        if (withdrawBtn) {
            withdrawBtn.addEventListener('click', function() {
                var input = document.getElementById('mgmt-withdraw-amount');
                var amount = parseInt(input ? input.value : 0) || 0;
                if (amount <= 0) return;

                nuiCallback('withdrawFunds', {
                    companyId: companyId,
                    amount: amount,
                });

                if (input) input.value = '';
            });
        }

        // Deposit
        var depositBtn = document.getElementById('mgmt-deposit-btn');
        if (depositBtn) {
            depositBtn.addEventListener('click', function() {
                var input = document.getElementById('mgmt-deposit-amount');
                var amount = parseInt(input ? input.value : 0) || 0;
                if (amount <= 0) return;

                nuiCallback('depositFunds', {
                    companyId: companyId,
                    amount: amount,
                });

                if (input) input.value = '';
            });
        }
    }

    // ===================================================================
    // ESCAPE KEY
    // ===================================================================
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isVisible) {
            nuiCallback('closeManagement', {});
        }
    });

    // ===================================================================
    // HELPERS
    // ===================================================================
    function nuiCallback(name, data) {
        fetch('https://sb_companies/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch(function() {});
    }

    function esc(str) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str || ''));
        return div.innerHTML;
    }

    function formatNum(num) {
        num = num || 0;
        var abs = Math.abs(num);
        return abs.toLocaleString('en-US');
    }

    function formatTxnType(type) {
        if (!type) return '--';
        return type.replace(/_/g, ' ');
    }

})();
