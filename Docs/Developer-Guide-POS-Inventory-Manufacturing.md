# ðŸ›’ Developer Guide: POS, Inventory & Manufacturing Engine

This technical document details the transactional mechanics, stock ledger calculation algorithms, multi-level Bill of Materials (BOM) assembly processing, custom barcode rendering engine, and multi-outlet stock transfer state machine.

---

## ðŸ—ï¸ Core Subsystems & Architecture

```text
Inventory Subsystems
â”œâ”€â”€ âš¡ Enterprise POS Transaction Engine (Atomicity & Concurrency)
â”œâ”€â”€ ðŸ“¦ Stock Ledger & Valuation Engine (FIFO / Weighted Average)
â”œâ”€â”€ ðŸ­ Manufacturing & Bill of Materials (BOM) Assembly Engine
â”œâ”€â”€ ðŸ·ï¸ Custom Barcode & QR Code Rendering Pipeline
â””â”€â”€ ðŸšš Multi-Outlet Stock Transfer & Verification State Machine
```

---

## âš¡ POS Transaction Lifecycle & ACID Guarantees

Every sale checkout executed in `SalesController.createSale` runs inside an isolated PostgreSQL transaction with row-level locks on stock rows:

```mermaid
sequenceDiagram
    autonumber
    actor POS as Flutter POS Client
    participant API as Sales Controller
    participant Lock as Distributed Lock (Redis/DB)
    participant DB as PostgreSQL Transaction
    participant Ledger as Stock Ledger Service
    participant Loyalty as Loyalty Engine
    
    POS->>API: POST /api/sales (Cart, Customer, Payments)
    API->>Lock: Acquire Lock on Outlet Stock
    API->>DB: BEGIN TRANSACTION (SERIALIZABLE)
    API->>DB: Verify & Deduct Stock (SELECT FOR UPDATE)
    API->>DB: Insert SaleHeader & SaleItems
    API->>Ledger: Insert StockLedger (Type: 'SALE_OUT')
    API->>Loyalty: Credit Loyalty Points to Customer Wallet
    API->>DB: COMMIT TRANSACTION
    API->>Lock: Release Lock
    API-->>POS: HTTP 201 Created (Invoice JSON + Receipt Hash)
```

---

## ðŸ­ Manufacturing & Bill of Materials (BOM) Engine

The BOM subsystem enables conversion of multiple raw component stocks into single finished sellable units.

### 1. Multi-Component Assembly Transaction
When `AssemblyController.produceBatch` is called:
1. Load the active BOM for `finished_item_code`.
2. For each raw component item $i$:
   $$\text{Required Qty}_i = \text{Batch Size} \times \text{BOM Component Qty}_i$$
3. Verify that $\text{Available Stock}_i \ge \text{Required Qty}_i$. If any component is insufficient, abort with `INSUFFICIENT_RAW_MATERIAL_STOCK`.
4. Deduct raw components:
   - Decrease `Stock.quantity` by $\text{Required Qty}_i$.
   - Insert `StockLedger` record with transaction type `ASSEMBLY_CONSUMPTION`.
5. Credit finished product:
   - Increase `Stock.quantity` of finished item by $\text{Batch Size}$.
   - Insert `StockLedger` record with transaction type `ASSEMBLY_PRODUCTION`.
6. Compute finished unit cost:
   $$\text{Unit Cost} = \sum_{i} (\text{Component Unit Cost}_i \times \text{Component Qty}_i) + \text{Labor/Overhead}$$

---

## ðŸ·ï¸ Custom Barcode & QR Rendering Pipeline

Barcode generation is handled on the client using the vector layout engine:
- **Code128 / EAN-13 / UPC-A**: Rendered into high-resolution 1D raster buffers.
- **QR Code (2D)**: Supports dynamic GS1 digital link formatting and tax invoice cryptographic signatures.
- **Label Designer Layout Engine**:
  - Dynamically calculates label grid coordinates based on DPI (203 DPI for standard thermal vs 300/600 DPI for laser sheets).
  - Handles column spacing, margins, and label pitch without clipping text or barcodes.

---

## ðŸšš Multi-Outlet Stock Transfer State Machine

```mermaid
stateDiagram-v2
    [*] --> DRAFT
    DRAFT --> REQUESTED : Branch submits Stock Request
    REQUESTED --> APPROVED : Warehouse Manager approves
    REQUESTED --> REJECTED : Insufficient stock / cancelled
    
    APPROVED --> DISPATCHED : Warehouse packs & dispatches (Stock marked IN_TRANSIT)
    DISPATCHED --> RECEIVED : Destination Branch verifies & accepts (Stock credited to branch)
    DISPATCHED --> DISCREPANCY : Damaged in transit / quantity mismatch
    DISCREPANCY --> RECEIVED : Adjusted with Damaged Goods write-off
```

---

## ðŸ“¡ REST API Endpoint Specifications

Mounted under `/api/inventory`, `/api/sales`, `/api/receiving`, `/api/purchase-orders`:

- `POST /api/sales` â€” Atomically commit POS sale transaction.
- `GET /api/sales/:id` â€” Retrieve sale details with tax splits and payment records.
- `POST /api/inventory/assembly/produce` â€” Execute BOM assembly batch.
- `POST /api/inventory/transfers/request` â€” Create multi-branch stock request.
- `POST /api/inventory/transfers/dispatch` â€” Dispatch stock transfer (locks goods in transit).
- `POST /api/inventory/transfers/receive` â€” Accept stock transfer at destination outlet.
- `POST /api/purchase-orders` â€” Create purchase order to vendor.
- `POST /api/receiving` â€” Commit Goods Receiving Note (GRN) against vendor PO.
- `POST /api/inventory/damages` â€” Record damaged inventory write-off.

---

*Document Source: `Docs/Developer-Guide-POS-Inventory-Manufacturing.md`*
