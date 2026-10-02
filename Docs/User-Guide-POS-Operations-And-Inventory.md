# 🛒 POS Operations, Barcode Labeling & Inventory User Guide

This user guide is written for **cashiers, store supervisors, purchase officers, and warehouse inventory staff**. Learn how to bill customers lightning-fast, design and print custom barcode price stickers, create purchase orders, receive vendor stock (GRN), transfer stock between branches, write off damaged goods, and process vendor returns.

---

## 📑 Table of Contents
1. [Enterprise POS & Fast Counter Billing](#1-enterprise-pos--fast-counter-billing)
2. [Custom Barcode Designer & Label Sticker Printing](#2-custom-barcode-designer--label-sticker-printing)
3. [Purchase Orders (PO) to Suppliers](#3-purchase-orders-po-to-suppliers)
4. [Goods Receiving (GRN) & Inward Stock](#4-goods-receiving-grn--inward-stock)
5. [Multi-Branch Stock Transfers & Approvals](#5-multi-branch-stock-transfers--approvals)
6. [Damage Items & Spoilage Write-Offs](#6-damage-items--spoilage-write-offs)
7. [Supplier Returns & Refund Tracking](#7-supplier-returns--refund-tracking)
8. [Stock Balance & Inventory Auditing](#8-stock-balance--inventory-auditing)

---

## 1. Enterprise POS & Fast Counter Billing

The **Enterprise POS** screen is optimized for high-speed scanning and checkout:

```text
Operations
├── 💻 Enterprise POS Billing Screen
├── 🏷️ Item Barcode Manager & Label Designer
├── 📝 Purchase Order (PO)
├── 📦 Goods Receiving (GRN)
├── 🚚 Stock Transfer & Dispatch
├── 📥 Stock Receive & Approval Center
├── ⚠️ Damage Items Entry
└── 🔄 Supplier Return & Refund
```

### Step-by-Step Counter Checkout Workflow:
1. **Open POS Screen**: Click **Operations > Enterprise POS**.
2. **Scan or Search Items**:
   - Point your USB/Bluetooth barcode scanner at the item barcode. The item is added immediately to the cart.
   - Or type item name / SKU in the search bar and press `Enter`.
3. **Change Quantity / Price / Discounts**:
   - Tap `+` or `-` to adjust quantity.
   - Click the discount button to apply percentage or flat bill discount.
4. **Customer Tagging**:
   - Enter customer phone number to pull existing loyalty points and purchase history.
   - For new customers, type their name to register instantly.
5. **Collect Payment**:
   - Click **Settle (F12 or Pay)**.
   - Select payment mode: **Cash**, **Card**, **UPI QR**, **Store Credit**, or **Split Payment**.
   - If Cash, enter amount tendered; change due will be calculated automatically.
6. **Print & Digital Invoice**:
   - Thermal receipt prints on your 80mm or 58mm printer.
   - If WhatsApp integration is enabled, a digital PDF invoice is automatically messaged to the customer!

---

## 2. Custom Barcode Designer & Label Sticker Printing

Easily print professional barcode price tags and QR stickers for shelf displays or packaged items:

1. Go to **Operations > Item Barcode Manager**.
2. **Select Items**: Pick items individually or filter by *Category* / *Recent GRN Receiving*.
3. **Select Label Format / Size**:
   - Single Column Roll (e.g., 50mm x 25mm).
   - 2-in-1 Dual Column Roll (e.g., 38mm x 25mm x 2).
   - A4 Sheet (e.g., 24 stickers per sheet / 40 stickers per sheet).
   - Jewelry Tag / Garment Hangtag layout.
4. **Customize Label Elements**:
   - Check/uncheck options to show: **Store Name**, **Item Name**, **Barcode Number / 2D QR Code**, **Selling Price / MRP**, **Expiry Date**, **Batch No**, **Size / Color**.
5. Set the number of copies needed for each item.
6. Click **Print Barcode Labels** (supports TSC, Zebra, Xprinter, TVS, Epson, and standard laser/inkjet printers).

---

## 3. Purchase Orders (PO) to Suppliers

Order fresh inventory from wholesale vendors before stock runs dry:

1. Go to **Operations > Purchase Order**.
2. Select your **Supplier / Vendor**.
3. Choose the target **Store / Warehouse Location**.
4. **Add Items**:
   - Manually search and select items.
   - Or click **Auto-suggest Low Stock** to automatically load all items that have fallen below their reorder threshold.
5. Review quantities, vendor unit cost, tax rates, and delivery due date.
6. Click **Save & Submit PO**.
7. Click **Export PDF / Send to Supplier** to email or WhatsApp the purchase order directly.

---

## 4. Goods Receiving (GRN) & Inward Stock

When physical delivery boxes arrive at your warehouse:

1. Go to **Operations > Receive from Vendor (GRN)**.
2. Select the vendor and link the original **Purchase Order (PO)** number.
3. Verify received physical quantities against the vendor's delivery invoice:
   - Enter **Received Qty**.
   - If any boxes arrived damaged, enter **Rejected Qty**.
   - Enter **Batch Number** and **Expiry Date** (for food, pharma, or cosmetics).
   - Enter any **Freight / Shipping Charges** to calculate accurate landed cost.
4. Click **Complete Goods Inward (GRN)**.
5. System stock balances increase immediately across all sales terminals!

---

## 5. Multi-Branch Stock Transfers & Approvals

Move goods between your Central Warehouse and Retail Branch Outlets:

### Step 1: Requesting Stock (Branch Outlet)
1. Branch cashier goes to **Operations > Stock Request**.
2. Select items and requested quantities from Central Warehouse.
3. Click **Submit Stock Request**.

### Step 2: Dispatching Stock (Central Warehouse)
1. Warehouse supervisor opens **Operations > Stock Dispatch**.
2. Select the pending request, pick the physical items, and enter vehicle / driver details.
3. Click **Dispatch Stock**. Goods are marked *'In Transit'*.

### Step 3: Receiving & Verification (Branch Outlet)
1. Branch manager opens **Operations > Stock Receive** (or **Transfer Progress Dashboard**).
2. Verify the physical boxes received against the dispatch manifest.
3. Click **Confirm Receive & Accept Stock**. Stock counts are officially credited to the branch!

---

## 6. Damage Items & Spoilage Write-Offs

Record broken, expired, or spoiled merchandise accurately to keep stock books honest:

1. Go to **Operations > Damage Items**.
2. Select the item, quantity, and damaged location.
3. Select the **Damage Reason**:
   - *Broken / Glass Breakage*
   - *Past Expiry Date*
   - *Water / Moisture Damage*
   - *Manufacturer Transit Defect*
4. Enter optional remarks and supervisor signature.
5. Click **Post Damage Entry**.
6. Physical stock is deducted, and the loss is posted to the *Damage & Spoilage Loss* ledger account.

---

## 7. Supplier Returns & Refund Tracking

Return defective goods back to the vendor for a credit note or cash refund:

1. Go to **Operations > Return Purchase to Vendor (Supplier Return)**.
2. Select the supplier and choose the original GRN / Invoice.
3. Select items to return, reason for return, and return quantity.
4. Click **Submit Supplier Return (Debit Note Generated)**.
5. When the supplier pays the refund or issues a credit adjustment:
   - Go to **Operations > Vendor Return Refund**.
   - Mark the debit note as settled (*Cash Refund* or *Adjust against future supplier bills*).

---

## 8. Stock Balance & Inventory Auditing

Audit your physical stock anytime:
- **Stock Balance**: Go to **Stock View > Stock Balance** to check live quantity on hand, total inventory valuation, and minimum stock alerts.
- **Stock Ledger**: Go to **Reports > Stock Ledger Report** to inspect the full timeline of any item (every purchase, sale, transfer, return, and adjustment).

---

*Maximize store checkout speed and maintain 100% inventory accuracy every single day!*
