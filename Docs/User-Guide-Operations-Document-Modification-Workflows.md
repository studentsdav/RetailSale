# User Guide: Modifying Operations Documents (PO, GRN, Requisitions & Stock Out)

This guide explains how managers and warehouse supervisors can safely edit, revise, and update existing operational documents (Purchase Orders, Goods Receipts, Store Requisitions, and Stock Out notes) without breaking accounting balances or stock ledger integrity.

---

## 📑 Table of Contents
1. [Overview of Document Modification Screens](#1-overview-of-document-modification-screens)
2. [Modifying a Purchase Order (`purchase_modify.dart`)](#2-modifying-a-purchase-order-purchase_modifydart)
3. [Modifying a Goods Receiving Note / GRN (`receiving_modify.dart`)](#3-modifying-a-goods-receiving-note--grn-receiving_modifydart)
4. [Modifying a Material Requisition (`request_modify.dart`)](#4-modifying-a-material-requisition-request_modifydart)
5. [Modifying a Stock Out / Issue Note (`stock_out_modify.dart`)](#5-modifying-a-stock-out--issue-note-stock_out_modifydart)
6. [Audit Trails & Re-Approval Rules](#6-audit-trails--re-approval-rules)

---

## 1. Overview of Document Modification Screens

In enterprise retail operations, supplier invoices or store requests may require corrections (e.g. price corrections, short-shipped items, updated batch numbers, or revised delivery dates). 

Rather than deleting documents and re-entering them, dedicated modification screens allow structured in-place revisions with automated ledger recalculation:

| Screen | Target Document | Typical Scenarios for Modification |
| :--- | :--- | :--- |
| **Purchase Modify** | Purchase Order (PO) | Supplier changed price, added promotional discounts, changed delivery date. |
| **Receiving Modify** | Goods Receiving (GRN) | Corrected physical count, updated supplier invoice number, modified batch/expiry dates. |
| **Request Modify** | Store Requisition | Department increased or decreased requested item quantities. |
| **Stock Out Modify** | Stock Issue / Transfer Out | Changed issuing location, adjusted issued quantities, updated department notes. |

---

## 2. Modifying a Purchase Order (`purchase_modify.dart`)

1. Open **Procurement** $\rightarrow$ **Purchase Orders** $\rightarrow$ select the PO $\rightarrow$ click **Edit / Modify**.
2. **Header Modifications**:
   - Change Supplier or Vendor Contact.
   - Update **Expected Delivery Date** or Payment Terms.
3. **Item Grid Adjustments**:
   - Change Order Quantity or Unit Price.
   - Add new line items or remove unneeded items.
   - Adjust Line Discount (%) or Tax Group.
4. **Totals Verification**:
   - The system recalculates Subtotal, Total Tax (CGST/SGST or VAT), and Net Amount in real time.
5. Click **Update Purchase Order**:
   - If the PO was already approved, the system prompts for a mandatory **Modification Reason**.
   - An updated revision PDF is automatically generated.

---

## 3. Modifying a Goods Receiving Note / GRN (`receiving_modify.dart`)

> [!WARNING]
> Editing an approved GRN adjusts your active on-hand warehouse inventory and updates accounts payable balances. Only users with **Store Manager** or **Inventory Auditor** privileges can access this screen.

1. Open **Operations** $\rightarrow$ **Goods Receiving** $\rightarrow$ select GRN $\rightarrow$ click **Modify**.
2. **Correcting Received Quantities**:
   - If you entered `100 PCS` but actual verified stock was `95 PCS`, adjust the quantity to `95`.
   - The system automatically posts a `STOCK_ADJUSTMENT` in the stock ledger for the `-5 PCS` difference.
3. **Batch & Expiry Date Correction**:
   - Edit the **Batch Number** and **Expiry Date** if recorded incorrectly during receiving.
4. **Supplier Invoice Ref & Taxes**:
   - Update the vendor's invoice number and adjusted invoice amount.
5. Click **Save Modifications**:
   - Both the Stock Ledger and the Accounts Payable voucher sync automatically.

---

## 4. Modifying a Material Requisition (`request_modify.dart`)

1. Open **Operations** $\rightarrow$ **Store Requests** $\rightarrow$ select Requisition $\rightarrow$ click **Modify**.
2. Update the requesting Department (e.g. *Kitchen Bakery* to *Main Kitchen*).
3. Adjust requested quantities or add replacement items.
4. Set Priority Level: **Normal**, **Urgent**, or **Critical**.
5. Click **Save Request**.

---

## 5. Modifying a Stock Out / Issue Note (`stock_out_modify.dart`)

1. Open **Operations** $\rightarrow$ **Stock Issues** $\rightarrow$ select Issue Note $\rightarrow$ click **Modify**.
2. Adjust issued quantities or change the source rack/bin location.
3. If items were returned unused, adjust the issued quantity; inventory automatically returns to available shelf stock.
4. Click **Update Stock Issue**.

---

## 6. Audit Trails & Re-Approval Rules

Every modification records:
- **Modified By**: Username and role.
- **Timestamp**: Exact server date and time.
- **Change Log**: Before-and-after values for every adjusted line.
- **Version Number**: Automatically incremented (e.g. `PO-1002-v2`).
