# ⚙️ Manufacturing, Bill of Materials (BOM) & Assembly User Guide

This user guide is written for **manufacturers, workshop managers, bakery/kitchen production leads, and retail packagers**. Learn how to create Bill of Materials (BOM) recipes, assemble finished goods from raw materials, deduct component stocks automatically, and calculate accurate production costs.

---

## 📑 Table of Contents
1. [What is BOM & Assembly?](#1-what-is-bom--assembly)
2. [Setting Up Raw Materials & Finished Products](#2-setting-up-raw-materials--finished-products)
3. [Creating a Bill of Materials (BOM) Recipe](#3-creating-a-bill-of-materials-bom-recipe)
4. [Running an Assembly / Production Batch](#4-running-an-assembly--production-batch)
5. [Disassembly / De-kitting Finished Bundles](#5-disassembly--de-kitting-finished-bundles)
6. [Stock Ledger & Cost Accounting Impact](#6-stock-ledger--cost-accounting-impact)
7. [Troubleshooting & Best Practices](#7-troubleshooting--best-practices)

---

## 1. What is BOM & Assembly?

If your business packages, manufactures, or prepares products out of raw ingredients or individual components, the **Assembly & BOM** module handles this with zero manual math:

- **Example 1 (Bakery / Restaurant)**: 1 Chocolate Cake = 500g Flour + 200g Cocoa + 4 Eggs + 150g Butter.
- **Example 2 (Electronics / Computer Store)**: 1 Gaming PC Build = 1 Cabinet + 1 Motherboard + 1 CPU + 1 GPU + 2x RAM + 1 Power Supply.
- **Example 3 (Gift Hamper / Combo Kit)**: 1 Festival Hamper = 1 Gift Box + 2 Wine Bottles + 1 Box of Chocolates + 1 Scented Candle.

When you assemble the finished product, the system automatically **deducts the exact raw material quantities** from inventory and **adds the finished units** into your sellable stock!

---

## 2. Setting Up Raw Materials & Finished Products

1. Go to **Masters > Item Master**.
2. Create your **Raw Materials / Components**:
   - Item Type: *Raw Material / Component*.
   - Enter Purchase Price, Unit of Measurement (e.g., *KG*, *Grams*, *PCS*, *Litre*), and Opening Stock.
3. Create your **Finished Good / Bundle**:
   - Item Type: *Finished Good / Assembled Item*.
   - Enter Selling Price, Barcode, and Tax category.

---

## 3. Creating a Bill of Materials (BOM) Recipe

Define the precise formula required to manufacture 1 unit of the finished product:

1. Go to **Operations > Assembly / BOM Setup** (or click **BOM Setup** from Item Master).
2. Select the **Finished Product** (e.g., *'Artisan Gift Hamper'*).
3. Under **Component Items**, click **Add Component ➕**:
   - Select Raw Material (e.g., *'Wicker Hamper Box'*), Quantity: `1 PCS`.
   - Select Raw Material (e.g., *'Dry Fruit Mix'*), Quantity: `500 GMS`.
   - Select Raw Material (e.g., *'Decorative Ribbon'*), Quantity: `1.5 METERS`.
4. (Optional) Add **Labor & Overhead Cost** (e.g., Packaging labor \$3.50).
5. Review the **Calculated Unit Cost** (sum of all raw materials + overhead).
6. Click **Save BOM Formula**.

---

## 4. Running an Assembly / Production Batch

When production is completed on the shop floor or kitchen:

1. Go to **Operations > Assembly Screen**.
2. Click **New Production Batch 🛠️**.
3. Select the **Finished Item** with the configured BOM.
4. Enter the **Quantity to Produce** (e.g., Produce `50` units).
5. The system instantly calculates and previews:
   - Total raw materials required for this batch.
   - Current stock availability of all raw components.
   - Any raw material shortages highlighted in red.
6. Select the **Source Warehouse / Location** (where raw materials are stored) and **Destination Location** (where finished goods will be placed).
7. Click **Confirm Assembly & Produce Stock**.
8. **What Happens Automatically**:
   - Raw material stocks decrease instantly.
   - Finished product stock increases by 50 units.
   - An audited assembly production entry is logged.

---

## 5. Disassembly / De-kitting Finished Bundles

If a customer returns a combo gift kit or you need to dismantle assembled units back into raw parts:

1. In the **Assembly Screen**, click **Disassembly / De-kit**.
2. Select the assembled item and enter quantity to dismantle.
3. Click **Execute De-kit**.
4. The system reduces finished good stock and returns all component parts back into raw material inventory at their appropriate valuation.

---

## 6. Stock Ledger & Cost Accounting Impact

Every production run is fully audited:
- Check **Reports > Stock Ledger Report** to view clear transactions marked as `ASSEMBLY_OUT` (for raw components consumed) and `ASSEMBLY_IN` (for finished products manufactured).
- The Cost of Goods Sold (COGS) in your **Profit & Loss Statement** accurately reflects actual raw material production costs.

---

## 7. Troubleshooting & Best Practices

| Issue | Solution |
| :--- | :--- |
| **"Cannot assemble: Insufficient raw material stock"** | Check the highlighted component in red. Create a Purchase Order (PO) or perform a Goods Receiving (GRN) for the missing raw material before running the batch. |
| **Component price changed from vendor** | When raw material purchase prices change, the BOM unit cost updates automatically based on current weighted average inventory cost. |
| **Batch / Expiry tracking for food manufacturing** | When confirming the assembly batch, enter the batch number (e.g., `BATCH-OCT-02`) and expiry date for the finished food units. |

---

*Take control of manufacturing and kit bundling with full inventory precision!*
