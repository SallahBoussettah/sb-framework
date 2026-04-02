// sb_mechanic_v2 | Crafting & Supplier NUI JS
// Recipe browser, ingredient validation, supplier shop

(function() {
    'use strict';

    const craftDevice = document.getElementById('craft-device');
    const craftList = document.getElementById('craft-list');
    const craftDetail = document.getElementById('craft-detail');
    const supplierDetail = document.getElementById('supplier-detail');
    const craftSearch = document.getElementById('craft-search');
    const craftBtnClose = document.getElementById('craft-btn-close');
    const craftQualityValue = document.getElementById('craft-quality-value');
    const craftTitle = document.getElementById('craft-title');
    const craftSubtitle = document.getElementById('craft-subtitle');
    const craftBadge = document.getElementById('craft-badge');
    const craftAppName = document.getElementById('craft-app-name');
    const craftBalance = document.getElementById('craft-balance');
    const craftModeLabel = document.getElementById('craft-mode-label');
    const craftQualityChip = document.getElementById('craft-quality-chip');

    let currentMode = null; // 'crafting' or 'supplier'
    let currentRecipes = [];
    let currentStock = [];
    let selectedRecipe = null;
    let selectedSupplierItem = null;
    let selectedQty = 10;
    let paymentType = 'bank';
    let bulkThreshold = 10;
    let bulkDiscount = 0.10;
    let playerCash = 0;
    let playerBank = 0;
    let qualityTier = null;

    // ===== NUI MESSAGE HANDLER =====
    window.addEventListener('message', function(event) {
        const data = event.data;
        switch (data.action) {
            case 'openCrafting':
                openCrafting(data);
                break;
            case 'openSupplier':
                openSupplier(data);
                break;
            case 'closeCrafting':
            case 'closeSupplier':
                closeUI();
                break;
            case 'updateSupplier':
                if (data.playerCash !== undefined) playerCash = data.playerCash;
                if (data.playerBank !== undefined) playerBank = data.playerBank;
                updateBalanceDisplay();
                break;
        }
    });

    // ===== OPEN CRAFTING =====
    function openCrafting(data) {
        currentMode = 'crafting';
        currentRecipes = data.recipes || [];
        qualityTier = data.qualityTier;

        // Update header
        craftBadge.textContent = 'CRAFT';
        craftTitle.textContent = (data.benchLabel || 'WORKBENCH').toUpperCase();
        craftSubtitle.textContent = 'Recipe Browser';
        craftAppName.textContent = data.benchLabel || 'Workbench';
        craftModeLabel.textContent = 'WORKBENCH';
        craftQualityChip.classList.remove('hidden');

        // Quality display
        if (qualityTier) {
            craftQualityValue.textContent = qualityTier.label || 'Standard';
            craftQualityValue.className = 'craft-quality-value quality-' + (qualityTier.name || 'standard');
        }

        // Skill pips
        updateCraftPips(data.craftingLevel || 1);

        // Show crafting detail, hide supplier
        craftDetail.classList.remove('hidden');
        supplierDetail.classList.add('hidden');

        // Render recipe list
        selectedRecipe = null;
        craftSearch.value = '';
        renderRecipeList(currentRecipes);
        showRecipeDetail(null);

        craftDevice.classList.remove('hidden');
    }

    // ===== OPEN SUPPLIER =====
    function openSupplier(data) {
        currentMode = 'supplier';
        currentStock = data.stock || [];
        bulkThreshold = data.bulkThreshold || 10;
        bulkDiscount = data.bulkDiscount || 0.10;
        playerCash = data.playerCash || 0;
        playerBank = data.playerBank || 0;

        // Update header
        craftBadge.textContent = 'SUPPLY';
        craftTitle.textContent = 'MATERIAL SUPPLIER';
        craftSubtitle.textContent = 'Raw Materials Shop';
        craftAppName.textContent = 'Supplier';
        craftModeLabel.textContent = 'SUPPLIER';
        craftQualityChip.classList.add('hidden');

        updateBalanceDisplay();
        updateCraftPips(0); // No skill pips for supplier

        // Show supplier detail, hide crafting
        craftDetail.classList.add('hidden');
        supplierDetail.classList.remove('hidden');

        // Render supplier list
        selectedSupplierItem = null;
        selectedQty = 10;
        craftSearch.value = '';
        renderSupplierList(currentStock);
        updateSupplierDetail();

        // Wire qty buttons
        wireQtyButtons();
        wirePaymentButtons();

        craftDevice.classList.remove('hidden');
    }

    // ===== CLOSE UI =====
    function closeUI() {
        craftDevice.classList.add('hidden');
        currentMode = null;
        selectedRecipe = null;
        selectedSupplierItem = null;
    }

    // ===== RENDER RECIPE LIST =====
    function renderRecipeList(recipes) {
        craftList.innerHTML = '';
        const search = (craftSearch.value || '').toLowerCase();

        const filtered = recipes.filter(r => {
            if (!search) return true;
            return r.label.toLowerCase().includes(search) ||
                   r.resultItem.toLowerCase().includes(search);
        });

        if (filtered.length === 0) {
            craftList.innerHTML = '<div style="padding:20px;text-align:center;color:#444;font-size:11px;">No recipes found</div>';
            return;
        }

        filtered.forEach(recipe => {
            const row = document.createElement('div');
            row.className = 'craft-row' + (selectedRecipe && selectedRecipe.id === recipe.id ? ' selected' : '');

            // Can craft indicator
            const canCraft = recipe.ingredients.every(i => i.have >= i.amount);
            const dot = document.createElement('div');
            dot.className = 'craft-row-cancraft' + (canCraft ? ' can' : '');
            row.appendChild(dot);

            // Name
            const name = document.createElement('span');
            name.className = 'craft-row-name';
            name.textContent = recipe.label;
            row.appendChild(name);

            // Result amount
            if (recipe.resultAmount > 1) {
                const amt = document.createElement('span');
                amt.className = 'craft-row-amount';
                amt.textContent = 'x' + recipe.resultAmount;
                row.appendChild(amt);
            }

            // Skill level badge
            const level = document.createElement('span');
            level.className = 'craft-row-level';
            level.textContent = 'L' + recipe.skillReq;
            row.appendChild(level);

            row.addEventListener('click', function() {
                selectedRecipe = recipe;
                renderRecipeList(currentRecipes);
                showRecipeDetail(recipe);
            });

            craftList.appendChild(row);
        });
    }

    // ===== SHOW RECIPE DETAIL =====
    function showRecipeDetail(recipe) {
        if (!recipe) {
            craftDetail.innerHTML = '<div class="craft-detail-empty">' +
                '<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#333" stroke-width="1.5">' +
                '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>' +
                '</svg><span>Select a recipe</span></div>';
            return;
        }

        let html = '';

        // Header
        html += '<div class="craft-detail-header">';
        html += '<span class="craft-detail-name">' + escapeHtml(recipe.label) + '</span>';
        html += '<span class="craft-detail-result">Produces: ' + recipe.resultAmount + 'x ' + escapeHtml(recipe.resultLabel) + '</span>';
        html += '</div>';

        // Quality preview
        if (qualityTier) {
            html += '<div class="craft-quality-preview">';
            html += '<div class="craft-quality-dot" style="background:' + (qualityTier.color || '#ccc') + '"></div>';
            html += '<span class="craft-quality-text" style="color:' + (qualityTier.color || '#ccc') + '">' + (qualityTier.label || 'Standard') + ' Quality</span>';
            html += '<span class="craft-quality-stats">Restore: ' + qualityTier.maxRestore + '% | Durability: ' + Math.round((2 - qualityTier.degradeMult) * 100) + '%</span>';
            html += '</div>';
        }

        // Ingredients
        html += '<div class="craft-detail-section">';
        html += '<div class="craft-detail-section-title">INGREDIENTS</div>';

        let allHave = true;
        recipe.ingredients.forEach(ing => {
            const has = ing.have >= ing.amount;
            if (!has) allHave = false;
            const icon = has ? '&#10003;' : '&#10007;';
            const cls = has ? 'has' : 'missing';

            html += '<div class="ingredient-row">';
            html += '<div class="ingredient-icon"><span class="ingredient-check ' + cls + '">' + icon + '</span></div>';
            html += '<span class="ingredient-name">' + escapeHtml(ing.label) + '</span>';
            html += '<span class="ingredient-count ' + cls + '">' + ing.have + ' / ' + ing.amount + '</span>';
            html += '</div>';
        });

        html += '</div>';

        // Info
        html += '<div class="craft-detail-section">';
        html += '<div class="craft-detail-section-title">INFO</div>';
        html += '<div class="ingredient-row">';
        html += '<span class="ingredient-name">Craft Time</span>';
        html += '<span class="ingredient-count has">' + (recipe.craftTime / 1000) + 's</span>';
        html += '</div>';
        html += '<div class="ingredient-row">';
        html += '<span class="ingredient-name">XP Reward</span>';
        html += '<span class="ingredient-count has">+' + recipe.xpReward + ' XP</span>';
        html += '</div>';
        html += '<div class="ingredient-row">';
        html += '<span class="ingredient-name">Minigame</span>';
        html += '<span class="ingredient-count has">' + (recipe.hasMinigame ? 'Yes' : 'Progress bar') + '</span>';
        html += '</div>';
        html += '</div>';

        // Craft button
        html += '<button class="craft-btn" id="craft-action-btn" ' + (allHave ? '' : 'disabled') + '>';
        html += allHave ? 'CRAFT' : 'MISSING MATERIALS';
        html += '</button>';

        craftDetail.innerHTML = html;

        // Wire craft button
        const craftBtn = document.getElementById('craft-action-btn');
        if (craftBtn && allHave) {
            craftBtn.addEventListener('click', function() {
                fetch('https://sb_mechanic_v2/craft', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ recipeId: recipe.id }),
                }).catch(function() {});
            });
        }
    }

    // ===== RENDER SUPPLIER LIST =====
    function renderSupplierList(stock) {
        craftList.innerHTML = '';
        const search = (craftSearch.value || '').toLowerCase();

        const filtered = stock.filter(s => {
            if (!search) return true;
            return s.label.toLowerCase().includes(search) ||
                   s.name.toLowerCase().includes(search);
        });

        if (filtered.length === 0) {
            craftList.innerHTML = '<div style="padding:20px;text-align:center;color:#444;font-size:11px;">No items found</div>';
            return;
        }

        filtered.forEach(item => {
            const row = document.createElement('div');
            row.className = 'supplier-row' + (selectedSupplierItem && selectedSupplierItem.name === item.name ? ' selected' : '');

            const name = document.createElement('span');
            name.className = 'supplier-row-name';
            name.textContent = item.label;
            row.appendChild(name);

            const price = document.createElement('span');
            price.className = 'supplier-row-price';
            price.textContent = '$' + item.price;
            row.appendChild(price);

            row.addEventListener('click', function() {
                selectedSupplierItem = item;
                renderSupplierList(currentStock);
                updateSupplierDetail();
            });

            craftList.appendChild(row);
        });
    }

    // ===== UPDATE SUPPLIER DETAIL =====
    function updateSupplierDetail() {
        const nameEl = document.getElementById('supplier-item-name');
        const priceEl = document.getElementById('supplier-item-price');
        const totalEl = document.getElementById('supplier-total-value');
        const discountEl = document.getElementById('supplier-discount');
        const buyBtn = document.getElementById('supplier-buy-btn');

        if (!selectedSupplierItem) {
            nameEl.textContent = 'Select an item';
            priceEl.textContent = '';
            totalEl.textContent = '$0';
            discountEl.textContent = '';
            buyBtn.disabled = true;
            return;
        }

        nameEl.textContent = selectedSupplierItem.label;
        priceEl.textContent = '$' + selectedSupplierItem.price + ' each';

        let total = selectedSupplierItem.price * selectedQty;
        let hasDiscount = selectedQty >= bulkThreshold;

        if (hasDiscount) {
            total = Math.ceil(total * (1 - bulkDiscount));
            discountEl.textContent = '-' + Math.round(bulkDiscount * 100) + '% bulk';
        } else {
            discountEl.textContent = selectedQty < bulkThreshold ?
                ('Buy ' + bulkThreshold + '+ for ' + Math.round(bulkDiscount * 100) + '% off') : '';
        }

        totalEl.textContent = '$' + total;

        const funds = paymentType === 'cash' ? playerCash : playerBank;
        buyBtn.disabled = total > funds || !selectedSupplierItem;

        // Update balance
        updateBalanceDisplay();
    }

    // ===== WIRE QTY BUTTONS =====
    function wireQtyButtons() {
        document.querySelectorAll('.qty-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                document.querySelectorAll('.qty-btn').forEach(b => b.classList.remove('active'));
                this.classList.add('active');
                selectedQty = parseInt(this.dataset.qty) || 1;
                updateSupplierDetail();
            });
        });
    }

    // ===== WIRE PAYMENT BUTTONS =====
    function wirePaymentButtons() {
        const cashBtn = document.getElementById('pay-cash');
        const bankBtn = document.getElementById('pay-bank');

        if (cashBtn) {
            cashBtn.addEventListener('click', function() {
                paymentType = 'cash';
                cashBtn.classList.add('active');
                bankBtn.classList.remove('active');
                updateSupplierDetail();
            });
        }
        if (bankBtn) {
            bankBtn.addEventListener('click', function() {
                paymentType = 'bank';
                bankBtn.classList.add('active');
                cashBtn.classList.remove('active');
                updateSupplierDetail();
            });
        }

        // Buy button
        const buyBtn = document.getElementById('supplier-buy-btn');
        if (buyBtn) {
            buyBtn.addEventListener('click', function() {
                if (!selectedSupplierItem || buyBtn.disabled) return;
                fetch('https://sb_mechanic_v2/buyItem', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        itemName: selectedSupplierItem.name,
                        amount: selectedQty,
                        paymentType: paymentType,
                    }),
                }).catch(function() {});
            });
        }
    }

    // ===== UPDATE BALANCE DISPLAY =====
    function updateBalanceDisplay() {
        if (currentMode === 'supplier') {
            const funds = paymentType === 'cash' ? playerCash : playerBank;
            craftBalance.textContent = (paymentType === 'cash' ? 'Cash' : 'Bank') + ': $' + funds;
        } else {
            craftBalance.textContent = '';
        }
    }

    // ===== UPDATE SKILL PIPS =====
    function updateCraftPips(level) {
        for (let i = 1; i <= 5; i++) {
            const pip = document.getElementById('craft-pip' + i);
            if (pip) pip.classList.toggle('active', i <= level);
        }
    }

    // ===== SEARCH =====
    craftSearch.addEventListener('input', function() {
        if (currentMode === 'crafting') {
            renderRecipeList(currentRecipes);
        } else if (currentMode === 'supplier') {
            renderSupplierList(currentStock);
        }
    });

    // ===== CLOSE BUTTON =====
    craftBtnClose.addEventListener('click', function() {
        const action = currentMode === 'supplier' ? 'closeSupplier' : 'closeCrafting';
        fetch('https://sb_mechanic_v2/' + action, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        }).catch(function() {});
    });

    // ===== ESC KEY =====
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && currentMode) {
            const action = currentMode === 'supplier' ? 'closeSupplier' : 'closeCrafting';
            fetch('https://sb_mechanic_v2/' + action, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({}),
            }).catch(function() {});
        }
    });

    // ===== HELPER =====
    function escapeHtml(str) {
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(str || ''));
        return div.innerHTML;
    }

})();
