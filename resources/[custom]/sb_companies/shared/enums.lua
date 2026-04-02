-- sb_companies | Shared Enums
-- Status enums, quality tiers, role permissions

Enums = {}

-- ===================================================================
-- ORDER STATUS
-- ===================================================================
Enums.OrderStatus = {
    PENDING     = 'pending',
    PROCESSING  = 'processing',
    READY       = 'ready',
    IN_TRANSIT  = 'in_transit',
    DELIVERED   = 'delivered',
    CANCELLED   = 'cancelled',
}

-- ===================================================================
-- DELIVERY STATUS
-- ===================================================================
Enums.DeliveryStatus = {
    WAITING        = 'waiting',
    CLAIMED        = 'claimed',
    IN_TRANSIT     = 'in_transit',
    COMPLETED      = 'completed',
    NPC_DISPATCHED = 'npc_dispatched',
}

-- ===================================================================
-- QUALITY TIERS (mirrors sb_mechanic_v2 Config.QualityTiers)
-- ===================================================================
Enums.Quality = {
    POOR     = { name = 'poor',      label = 'Poor',      color = '#888888', maxRestore = 70,  degradeMult = 1.3 },
    STANDARD = { name = 'standard',  label = 'Standard',  color = '#cccccc', maxRestore = 85,  degradeMult = 1.0 },
    GOOD     = { name = 'good',      label = 'Good',      color = '#2ed573', maxRestore = 95,  degradeMult = 0.9 },
    EXCELLENT= { name = 'excellent', label = 'Excellent', color = '#4a9eff', maxRestore = 100, degradeMult = 0.8 },
    SUPERIOR = { name = 'superior',  label = 'Superior',  color = '#a855f7', maxRestore = 100, degradeMult = 0.7 },
}

-- Map crafting level -> quality
Enums.QualityByLevel = {
    [1] = Enums.Quality.POOR,
    [2] = Enums.Quality.STANDARD,
    [3] = Enums.Quality.GOOD,
    [4] = Enums.Quality.EXCELLENT,
    [5] = Enums.Quality.SUPERIOR,
}

-- Map quality name -> tier data
Enums.QualityByName = {}
for _, tier in pairs(Enums.Quality) do
    Enums.QualityByName[tier.name] = tier
end

-- ===================================================================
-- EMPLOYEE ROLES
-- ===================================================================
Enums.Role = {
    WORKER  = 'worker',
    DRIVER  = 'driver',
    MANAGER = 'manager',
}

-- ===================================================================
-- TRANSACTION TYPES
-- ===================================================================
Enums.TransactionType = {
    SALE            = 'sale',
    PURCHASE        = 'purchase',
    SALARY          = 'salary',
    DELIVERY_FEE    = 'delivery_fee',
    RAW_PURCHASE    = 'raw_purchase',
    TAX             = 'tax',
    OWNER_WITHDRAW  = 'owner_withdraw',
    OWNER_DEPOSIT   = 'owner_deposit',
}
