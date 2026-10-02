# 🚀 1-Click Bi-Directional Cloud & Offline Migration Guide

## 📋 Overview

The **1-Click Store Migration System** provides an enterprise-grade, bi-directional data synchronization pipeline between **Local Offline POS Terminals** and **Multi-Tenant Online Cloud Servers**.

It solves the fundamental challenge of **multi-tenant row ID collisions**: when migrating an offline store into a shared cloud server where other merchants already occupy database IDs (`id = 1, 2, 3...`), the system executes a **Dynamic Relational ID Translation Engine** to remap all primary and foreign keys on the fly without any data loss or constraint violations.

---

## 🏛️ Architecture & Migration Workflows

### 1. Offline ➔ Online Cloud Migration (Dynamic Relational ID Translation)

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Store Administrator
    participant Terminal as POS Terminal (Flutter UI)
    participant LocalBackend as Local Offline Node
    participant CloudBackend as Cloud Server (Express/Postgres)

    Admin->>Terminal: Selects "Offline ➔ Online Cloud" & enters Cloud URL
    Terminal->>CloudBackend: 1. GET /api/public/migration/ping
    CloudBackend-->>Terminal: ✅ Cloud Gateway Active (Version 2.0)
    Terminal->>LocalBackend: 2. POST /api/public/migration/export-bundle
    LocalBackend-->>Terminal: 📦 Returns Complete Scoped Store Bundle
    Terminal->>CloudBackend: 3. POST /api/public/migration/import-bundle (MERGE_OUTLET)
    Note over CloudBackend: ⚡ Dynamic Relational ID Translation:<br/>• userMap, taxGroupMap, groupMap<br/>• itemMap (Barcode/SKU matching)<br/>• customerMap & supplierMap (Phone/Name)<br/>• salesMap: remaps sale_id & item_id in sales_items<br/>• poMap: remaps po_id & item_id in po_items<br/>• voucherMap & kotMap<br/>• Synchronizes Postgres setval(max(id))
    CloudBackend-->>Terminal: 🎉 Migration Success (Outlet Code, JWT Token, Statistics)
    Terminal->>Terminal: 4. Updates AppConfig.baseUrl to Cloud URL & sets Cloud Session
    Terminal-->>Admin: Displays Migrated Counts & Launches Cloud POS
```

---

### 2. Online Cloud ➔ Offline Station Migration (Clean Cascade Purge & Fresh Restore)

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Store Administrator
    participant Terminal as POS Terminal (Flutter UI)
    participant LocalBackend as Local Offline Node
    participant CloudBackend as Cloud Server (Express/Postgres)

    Admin->>Terminal: Selects "Online Cloud ➔ Offline" & enters Cloud URL + Outlet Code
    Terminal->>LocalBackend: 1. POST /api/public/migration/sync-online-to-offline
    LocalBackend->>CloudBackend: 2. POST /api/public/migration/export-bundle
    CloudBackend-->>LocalBackend: 📦 Transmits Cloud Store Dataset
    Note over LocalBackend: 🧹 Clean Cascade Purge:<br/>• Truncates child tables (voucher_lines, sales_items, kot_items)<br/>• Truncates parent tables (sales_headers, customers, items)<br/>• Re-ingests cloud store snapshot cleanly<br/>• Resets Postgres auto-increment sequences
    LocalBackend-->>Terminal: ✅ Local Database Mirror Ready
    Terminal->>Terminal: 3. Sets AppConfig.baseUrl = http://127.0.0.1:3000
    Terminal-->>Admin: Launches Local Offline POS
```

---

## 🗺️ Relational ID Translation Engine

When inserting local rows into a shared cloud database, IDs cannot be hardcoded. The engine builds in-memory translation hash maps during ingestion:

```mermaid
flowchart LR
    subgraph Local_Offline_Entities["Local Offline Entities"]
        L_Item["Item (Local ID: 7)"]
        L_Cust["Customer (Local ID: 15)"]
        L_Sale["Sale Header (Local ID: 42)"]
        L_SaleItem["Sale Item (sale_id: 42, item_id: 7)"]
    end

    subgraph Translation_Maps["ID Translation Maps"]
        ItemMap["itemMap: 7 ➔ 2084"]
        CustMap["customerMap: 15 ➔ 1190"]
        SaleMap["salesMap: 42 ➔ 5831"]
    end

    subgraph Cloud_Database_Entities["Cloud Multi-Tenant Database"]
        C_Item["Item (Cloud ID: 2084)"]
        C_Cust["Customer (Cloud ID: 1190)"]
        C_Sale["Sale Header (Cloud ID: 5831)"]
        C_SaleItem["Sale Item (sale_id: 5831, item_id: 2084)"]
    end

    L_Item --> ItemMap --> C_Item
    L_Cust --> CustMap --> C_Cust
    L_Sale --> SaleMap --> C_Sale
    L_SaleItem --> Translation_Maps --> C_SaleItem
```

---

## 📊 Full Table Compatibility Matrix

The migration engine guarantees 100% data integrity across all 11 enterprise domains:

| Domain | Database Tables | Foreign Key Translation in Offline $\to$ Online | Online $\to$ Offline Clean Restore |
| :--- | :--- | :--- | :--- |
| **1. Core & Tenant** | `outlets`, `users`, `user_permissions`, `user_notes` | Remapped to `targetOutletId` and `userMap[oldUserId] = newCloudUserId` | Recreates outlet tenant and admin credentials |
| **2. Settings & Branding** | `system_settings`, `app_branding`, `property_info`, `numbering_settings` | Scoped by `outlet_id`, sequence numbers continue after highest existing bill | Cleanly overwrites with cloud store branding & sequences |
| **3. Taxes & Master Data** | `tax_groups`, `tax_group_components`, `taxes_master`, `tax_profiles` | Matches by name or inserts new $\to$ `taxGroupMap[oldId] = newId` | Replaces local tax configurations |
| **4. Catalog & Inventory** | `item_groups`, `subcategories`, `brands`, `item_master`, `product_templates`, `stock_locations`, `stock_ledger` | Products remapped with `group_id`, `tax_group_id`, `brand_id`. Matched by barcode/SKU $\to$ `itemMap`. Stock remapped with `locationMap` | Clean truncate & reload of master catalog & inventory ledger |
| **5. CRM & Parties** | `customers`, `customer_advances`, `customer_repayments`, `supplier_master`, `supplier_bills`, `supplier_payments` | Matched per outlet by phone/name $\to$ `customerMap` and `supplierMap` | Cleanly mirrors customer credit & vendor ledgers |
| **6. Sales & Billing** | `sales_headers`, `sales_items`, `payment_methods`, `sale_sources` | `sales_headers` inserted $\to$ `salesMap`. `sales_items` inserted with `sale_id = salesMap[oldId]` & `item_id = itemMap[oldId]` | Clean truncate of past bills, restores all cloud invoices |
| **7. Purchases & GRN** | `purchase_orders`, `purchase_order_items`, `goods_receipts`, `goods_receipt_items` | `purchase_orders` remapped with `supplier_id = supplierMap[oldId]` $\to$ `poMap`. `items` remapped with `po_id` & `item_id` | Cleanly syncs purchase orders and vendor receipts |
| **8. Finance & Accounting** | `chart_of_accounts`, `bank_accounts`, `accounting_vouchers`, `voucher_lines`, `expenses`, `expense_categories` | `bank_account_id = bankMap`, `voucher_id = voucherMap`, `account_id = accountMap`, `category_id = expenseCatMap` | Mirrors chart of accounts, bank balances, and vouchers |
| **9. Restaurant & Dining** | `floors`, `dining_areas`, `restaurant_tables`, `kitchen_stations`, `kot_headers`, `kot_items` | `floor_id = floorMap`, `area_id = areaMap`, `table_id = tableMap`, `kot_id = kotMap` | Recreates floor layouts, table grids, and KOT logs |
| **10. Subscriptions & Delivery** | `milk_subscriptions`, `delivery_customers`, `delivery_partners` | `customer_id = customerMap[oldId]`, `outlet_id = targetOutletId` | Restores delivery routes and recurring milk subscriptions |
| **11. HRMS & Payroll** | `hr_employees`, `hr_designations`, `hr_shifts` | Scoped by `outlet_id = targetOutletId` | Restores staff profiles, shifts, and designation tiers |

---

## 🔒 Post-Migration Sequence Auto-Increment Synchronization

After inserting records with new primary keys, PostgreSQL auto-increment sequence counters must be aligned with the highest ID to prevent future collision:

```sql
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT c.table_name, c.column_name, pg_get_serial_sequence(c.table_name, c.column_name) AS seq_name
        FROM information_schema.columns c
        WHERE c.table_schema = 'public' AND pg_get_serial_sequence(c.table_name, c.column_name) IS NOT NULL
    ) LOOP
        EXECUTE format('SELECT setval(''%s'', COALESCE((SELECT MAX(%I) FROM %I), 1), true)', r.seq_name, r.column_name, r.table_name);
    END LOOP;
END $$;
```

---

## 📱 User Interface & Navigation

### 1. Launching from Server Configuration
* Navigate to **Server Configuration Screen** (`ServerConfigScreen`).
* Click **"Launch 1-Click Migration Wizard"**.

### 2. Launching from Settings
* Open **Settings $\to$ Data & Security**.
* Under **1-Click Migrate Store to Cloud**, click **"Start Migration Wizard"**.

### 3. Launching from Cloud Feature Gate
* Open any cloud feature (e.g. B2B Chat, Rider Portal, Customer App, Vendor Marketplace).
* In offline mode, click **"1-Click Migrate Store to Cloud"**.

---

## 🔌 API Endpoint Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET / POST` | `/api/public/migration/ping` | Health check and compatibility test |
| `POST` | `/api/public/migration/export-bundle` | Exports local store bundle and `.enc` snapshot |
| `POST` | `/api/public/migration/import-bundle` | Ingests store bundle on Cloud with relational ID translation |
| `POST` | `/api/public/migration/sync-online-to-offline` | Cleanly purges local database and pulls down cloud store |
