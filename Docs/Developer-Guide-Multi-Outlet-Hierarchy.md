# ðŸ¢ Developer Guide: Multi-Outlet & Warehouse Hierarchy Architecture

This technical document details the multi-tenant outlet scoping middleware, hierarchical warehouse tree data structures, branch-scoped document numbering sequences, and cross-outlet stock transfer state isolation.

---

## ðŸ—ï¸ Multi-Outlet Scoping & Context Middleware

The system isolates store data while enabling unified enterprise consolidation:

```mermaid
flowchart TD
    Req["Incoming HTTP Request with JWT"] --> AuthMid["auth.middleware extracts req.user.outlet_code"]
    AuthMid --> OutletMid["outlet.middleware / propertyContext.middleware"]
    OutletMid --> ScopeCheck{"Is User Admin / Global Owner?"}
    ScopeCheck -- Yes --> GlobalScope["Allow cross-outlet filters via ?outlet_code=..."]
    ScopeCheck -- No --> BranchScope["Strictly bind queries to WHERE outlet_code = req.user.outlet_code"]
    GlobalScope --> DB["Execute Scoped Sequelize Query"]
    BranchScope --> DB
```

---

## ðŸ—„ï¸ Relational Database Schema & Models

### 1. `Outlet` (Branch Master)
- `id` (PK, Integer)
- `outlet_code` (String, unique, e.g. "OUTLET_01")
- `name` (String, e.g. "Downtown Retail Branch")
- `business_type` (Enum: `RETAIL`, `RESTAURANT`, `SUPERMARKET`, `WAREHOUSE`)
- `parent_outlet_id` (FK -> `Outlet`, nullable for root HQ / Central Warehouse)
- `is_active` (Boolean)
- `tax_number`, `phone`, `email`, `address` (String)

### 2. `StockLocation` (Aisles, Racks, Bins)
- `id` (PK, Integer)
- `outlet_id` (FK -> `Outlet`)
- `location_code` (String, e.g. "RACK-A-BIN-04")
- `zone_type` (Enum: `SALES_FLOOR`, `COLD_STORAGE`, `BACKROOM`, `DAMAGE_HOLD`)
- `is_active` (Boolean)

### 3. `NumberingSetting` (Per-Outlet Document Sequences)
- `id` (PK, Integer)
- `outlet_code` (String)
- `document_type` (Enum: `SALE_INVOICE`, `PURCHASE_ORDER`, `GRN`, `KOT`, `STOCK_TRANSFER`, `VOUCHER`)
- `prefix` (String, e.g. "INV-DT-")
- `suffix` (String, e.g. "/2026")
- `current_number` (Integer, atomic increment)
- `padding_zeros` (Integer, e.g. 5 -> "INV-DT-00042/2026")

---

## ðŸ”„ Cross-Outlet Stock Request & Transfer Protocols

```mermaid
sequenceDiagram
    autonumber
    participant Branch as Branch Outlet (OUTLET_02)
    participant API as Inventory Gateway
    participant DB as PostgreSQL DB
    participant Warehouse as Central Warehouse (OUTLET_01)

    Branch->>API: POST /api/inventory/transfers/request {source: OUTLET_01, target: OUTLET_02, items}
    API->>DB: Insert StockTransferHeader (Status: REQUESTED)
    API-->>Branch: Request Created (ID: TRF-2026-0089)

    Warehouse->>API: POST /api/inventory/transfers/dispatch {transferId, vehicleNo}
    API->>DB: Atomic: Deduct source stock + Mark IN_TRANSIT
    API-->>Warehouse: Dispatched

    Branch->>API: POST /api/inventory/transfers/receive {transferId, verifiedItems}
    API->>DB: Atomic: Credit target stock at OUTLET_02 + Status: COMPLETED
    API-->>Branch: Stock Transferred Successfully!
```

---

## ðŸ“¡ REST API Endpoint Specifications

- `GET /api/public/outlet` â€” List registered outlets.
- `POST /api/public/outlet` â€” Register new outlet terminal.
- `GET /api/inventory/stock-locations` â€” List warehouse aisles and bin locations.
- `POST /api/inventory/stock-locations` â€” Create stock storage zone.
- `GET /api/inventory/numbering-settings` â€” Retrieve sequence formatting for outlet.
- `POST /api/inventory/numbering-settings` â€” Update sequence rules (Prefix/Suffix/Padding).

---

*Document Source: `Docs/Developer-Guide-Multi-Outlet-Hierarchy.md`*
