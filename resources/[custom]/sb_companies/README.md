# sb_companies

Supply chain economy system with company management, raw material purchasing, crafting/production, ordering, delivery logistics, and shop storage for mechanic workshops.

## Features

- Three companies: Santos Metal Works (heavy manufacturing), Pacific Chemical Solutions (fluids/rubber), LS Electronics Corp (electronics)
- Raw material purchasing - any player can mine open-world nodes and sell to companies
- Crafting/production system with recipes, benches, minigames, and quality tiers (Poor through Superior)
- Order terminal for mechanic workshops to order parts from companies
- Delivery system - drivers pick up orders from company loading docks and deliver to workshops
- NPC fallback - if no player drivers are available, NPC auto-dispatches after a configurable delay (with quality/speed penalties)
- Shop storage with category-based dispensers at workshops (engine, brakes, electrical, fluids, wheels, etc.)
- Company management dashboard for owners/managers
- Role-based access: Worker (craft), Driver (deliver), Manager (craft + deliver + manage)
- Company economy: raw material buy prices, delivery payments, NPC surcharges
- NUI interfaces for order terminal, storage, production, and company management
- Open-world mining spots scattered across the map (quarry, construction, scrapyard, oil fields, chemical plants)

## Dependencies

- sb_core
- sb_notify
- sb_target
- sb_progressbar
- sb_inventory
- sb_minigame
- sb_mechanic_v2
- oxmysql

## Installation

1. Place `sb_companies` in your resources folder.
2. Add `ensure sb_companies` to your server.cfg (after its dependencies).
3. The resource expects database tables for company data, employees, orders, deliveries, and catalog. Run the provided SQL or let the resource create them on first start.
4. All raw material and crafted part items must exist in your `sb_items` database table.
5. The company catalog (items, prices) is loaded from the `company_catalog` database table.

## Mapping / Location Notes

**Company locations use generic GTA V open-world coordinates - no custom MLO is required.**

- Santos Metal Works: La Mesa industrial area (~714, -965)
- Pacific Chemical Solutions: Elysian Island / Port area (~-233, -2438)
- LS Electronics Corp: Cypress Flats area (~897, -1058)

**Workshop (Benny's):** The order terminal and parts dispensers are positioned inside the vanilla Benny's Original Motorworks interior. The coordinates reference the standard Benny's location at (~-197, -1339). No custom MLO needed.

**Open-world mining nodes** are placed at public outdoor locations: Sandy Shores quarry, a LS construction site, La Puerta scrapyard, oil fields near the refinery, and a chemical plant area. All use standard GTA V terrain.

## Configuration

All settings are in `config.lua`:

- **Companies** - Company definitions: id, label, type, location, interaction points (receiving dock, production area, loading dock, management desk), van spawn, and which raw materials they buy
- **Shops** - Workshop definitions with order terminal position and parts dispenser locations/categories
- **RawMaterialPrices** - Buy prices for all raw materials (what companies pay miners)
- **NPCRestockMarkup** - Markup multiplier when NPC companies auto-restock
- **Delivery** - Van model, driver payment, NPC surcharge, NPC delivery time range, quality cap
- **Production** - NPC auto-production delay, quality, speed multiplier
- **Roles** - Permission matrix for worker, driver, manager
- **ItemCategories** - Maps item names to dispenser categories
- **OpenWorldMining** - Respawn time, interaction radius, mining duration, and node definitions with coordinates and yields

Additional shared files:
- `shared/enums.lua` - Order/delivery status, quality tiers, roles, transaction types
- `shared/catalog.lua` - Company-to-product mapping
- `shared/recipes.lua` - Crafting recipes organized by bench type

## Exports

**Server-side:**

- `exports['sb_companies']:GetShopStorage(shopId)` - Get storage contents for a workshop
- `exports['sb_companies']:AddToShopStorage(shopId, itemName, quantity, quality)` - Add parts to workshop storage
- `exports['sb_companies']:GetEmployeeData(citizenid)` - Get employee info (company, role)
- `exports['sb_companies']:GetCompanyData(companyId)` - Get full company data
- `exports['sb_companies']:GetCatalogPrices(companyId)` - Get catalog item prices for a company

## License

Part of SB Framework by Salah Eddine Boussettah.
