-- sb_companies | Shared Catalog
-- Maps company IDs to what they produce and what raw materials each needs

Catalog = {}

-- ===================================================================
-- COMPANY → PRODUCT TYPE MAPPING
-- Which company makes which category of parts
-- ===================================================================
Catalog.CompanyProducts = {
    santos_metal = {
        'engine', 'transmission', 'brakes', 'suspension', 'body',
    },
    pacific_chem = {
        'fluids', 'wheels',
    },
    ls_electronics = {
        'electrical',
    },
}

-- ===================================================================
-- ITEM → COMPANY MAPPING
-- Which company sells which specific item (built from catalog DB at runtime)
-- This is populated by the server from company_catalog table
-- ===================================================================
Catalog.ItemToCompany = {}

-- ===================================================================
-- HELPER: Get company ID for an item name
-- ===================================================================
function Catalog.GetCompanyForItem(itemName)
    return Catalog.ItemToCompany[itemName]
end

-- ===================================================================
-- HELPER: Get all items a company sells (from server-loaded catalog)
-- ===================================================================
Catalog.CompanyItems = {}

function Catalog.GetCompanyItems(companyId)
    return Catalog.CompanyItems[companyId] or {}
end
