# User Guide: Stock Taking Audits, Item Modifiers, Waiter App & Manual GRN Receiving

This guide explains how to conduct physical inventory stock takes, configure item modifiers (e.g. Extra Cheese), use the Waiter Floor App to post orders directly to the kitchen, and follow the standard **Manual Goods Receiving (GRN)** procedure.

---

## 📑 Table of Contents
1. [Physical Stock Taking & Inventory Variance Audits](#1-physical-stock-taking--inventory-variance-audits)
2. [Managing Modifiers & Add-ons inside Item Master (e.g. Extra Cheese)](#2-managing-modifiers--add-ons-inside-item-master-eg-extra-cheese)
3. [Veg / Non-Veg Dietary Tags in Item Master](#3-veg--non-veg-dietary-tags-in-item-master)
4. [Using the Waiter App for Direct Kitchen KOT Orders](#4-using-the-waiter-app-for-direct-kitchen-kot-orders)
5. [⚠️ Critical Store Rule: Manual Goods Receiving (GRN) Only](#5-️-critical-store-rule-manual-goods-receiving-grn-only)

---

## 1. Physical Stock Taking & Inventory Variance Audits

Periodic stock audits reconcile your on-hand physical warehouse count with system records.

### How to Conduct a Stock Take:
1. Open **Inventory** $\rightarrow$ **Stock Taking** (`stock_taking_screen.dart`).
2. Filter by **Department / Category** (e.g. *Beverages*, *Dairy*, *Bakery*) or search for specific items.
3. Review the audit sheet columns:
   - **Item Name & Unit**: (e.g., *Amul Butter 500g [PCS]*).
   - **Current Balance**: What the system expects on the shelf (e.g. `24 PCS`).
   - **Counted / In Hand (Editable)**: Enter what you physically counted (e.g. `22 PCS`).
   - **Variance**: Automatically calculated (`-2 PCS` shortage highlighted in Red; surplus highlighted in Green).
   - **Reason / Remark**: Select a discrepancy reason (*Damage / Spoilage*, *Physical Count*, *Theft / Pilferage*, *Unrecorded Usage*).
4. Click **Save & Reconcile Stock**.
5. The system automatically creates an inventory adjustment in the stock ledger and archives the audit report with session ID `STK-YYYYMMDD-XXXX`.

---

## 2. Managing Modifiers & Add-ons inside Item Master (e.g. Extra Cheese)

Modifiers and add-ons are managed directly within **Item Master** (no separate screen needed):

1. Open **Operations / Inventory** $\rightarrow$ **Item Master** (`item_master_screen.dart`).
2. Click **+ Add Item** (or edit an existing item):
   - **Item Name**: e.g., *Extra Cheese Block*, *Almond Milk*, *Double Patty*.
   - **Selling Price / Rate**: Enter the extra charge (e.g., `+₹40.00`).
   - **Toggle "Is Modifier / Add-on"**: Enable this toggle chip to display the modifier configuration panel.
   - **Applicable Menu Items**: Select which parent dishes/menu items this add-on applies to (e.g., *Margherita Pizza*, *Farmhouse Pizza*, *Burger*).
   - **Raw Material Stock Deduction (Optional Recipe Link)**: Select the raw inventory item (e.g., *Processed Cheddar Cheese Block*) and enter the deduction quantity (e.g., `0.05 KG` or `50 GM`).
3. Click **Save Item**.
4. **POS & Waiter Operation**: When a waiter, cashier, or QR ordering guest selects *Extra Cheese*, the customer bill increases by ₹40, and 50 grams of cheese is automatically deducted from inventory upon order completion.

---

## 3. Veg / Non-Veg Dietary Tags in Item Master

In **Inventory $\rightarrow$ Item Master**:
- When adding or editing a dish, select the **Dietary Type**:
  - 🟢 **Pure Veg**: Displayed with a green veg indicator on menus, POS, and KDS.
  - 🔴 **Non-Veg**: Displayed with a red non-veg indicator.
  - 🟡 **Contains Egg**: Displayed with an egg indicator.

---

## 4. Using the Waiter App for Direct Kitchen KOT Orders

Floor servers can take orders table-side on any mobile phone or tablet:

1. Sign in with your **Quick PIN** on the Waiter Floor Console.
2. Tap the table number.
3. Tap items to add to the order $\rightarrow$ Select modifiers (e.g. *Extra Cheese*, *Less Spicy*).
4. Tap **Send KOT**.
5. The order appears instantly on the chef's **Kitchen Display System (KDS)** and prints on kitchen thermal printers without any paper running.

---

## 5. ⚠️ Critical Store Rule: Manual Goods Receiving (GRN) Only

> [!IMPORTANT]
> **GOODS RECEIVING NOTES (GRN) ARE NEVER GENERATED AUTOMATICALLY.**
> 
> When you order goods from a supplier or through the B2B Marketplace:
> - Creating a **Purchase Order (PO)** only registers an order request. **Stock is NOT added yet.**
> - Stock is **ONLY** added when your store receiver physically counts the delivery boxes and enters a **Goods Receiving Note (GRN)** manually.
> 
> ### How to Receive Goods Manually:
> 1. Go to **Purchases** $\rightarrow$ **Goods Receiving (GRN)**.
> 2. Select the vendor and pending Purchase Order.
> 3. Enter the **Actual Received Quantity** (e.g., if you ordered 100 boxes but the supplier only delivered 95, enter `95`).
> 4. Verify supplier invoice number and batch expiry dates.
> 5. Click **Save & Receive Stock**.
> 6. Only now does your stock ledger increase by 95 units.
