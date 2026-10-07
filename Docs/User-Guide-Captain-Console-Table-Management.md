# User Guide: Separate Table Bills, Waiter Assignment & Excel Table Import

This guide explains how to handle **separate client transactions on a single table**, **assign tables to specific staff members**, and **bulk import tables from an Excel spreadsheet**.

---

## 📑 Table of Contents
1. [Separate Client Transactions & Split Bills per Table](#1-separate-client-transactions--split-bills-per-table)
2. [Assigning Tables to Waiters / Captains](#2-assigning-tables-to-waiters--captains)
3. [Bulk Importing Tables from Excel](#3-bulk-importing-tables-from-excel)
4. [Settling Individual Client Bills](#4-settling-individual-client-bills)
5. [Frequently Asked Questions (FAQ)](#5-frequently-asked-questions-faq)

---

## 1. Separate Client Transactions & Split Bills per Table

When a group of friends or corporate clients sit at the same table and request individual checks:

### How to Split into Separate Bills:
1. On the **Captain Dashboard**, tap the occupied table (e.g. *Table 4*).
2. Tap **+ New Client Bill / Split Sub-Order**.
3. Select items for **Client 1 (Seat A)** and send KOT.
4. Tap **Client 2 (Seat B)**, add their distinct dishes/drinks, and send KOT.
5. The table displays multiple order tabs (`Bill #1: ₹450`, `Bill #2: ₹720`), allowing you to manage each client independently.

```
+-------------------------------------------------------+
| 🍽️ Table 04 (Occupied) - AC Dining Hall               |
| Server: Rahul Sharma                                  |
|-------------------------------------------------------|
| [ Client 1 (₹450) ]  [ Client 2 (₹720) ]  [ + Add ]   |
|-------------------------------------------------------|
| Active Tab: Client 2                                  |
|  • 1x Chicken Tikka Biryani .............. ₹380.00    |
|  • 1x Fresh Lime Soda .................... ₹120.00    |
|  • 1x Chocolate Lava Cake ................ ₹220.00    |
|                                                       |
| Subtotal: ₹720.00 | Tax (5%): ₹36.00 | Total: ₹756.00 |
|                                                       |
|   [ Print Client 2 Bill ]     [ Settle Client 2 ]     |
+-------------------------------------------------------+
```

---

## 2. Assigning Tables to Waiters / Captains

Assigning floor tables to specific staff members ensures clear table accountability and tracks sales per waiter:

1. Open **Restaurant Floor Plan** or **Table Setup**.
2. Tap on any table and click **Edit / Assign**.
3. In the **Assigned Waiter** dropdown, select the staff member (e.g. *Rahul Sharma*).
4. Save. The table card on the floor grid will show the waiter's name badge.
5. On mobile floor devices, waiters can filter the grid to view **"My Assigned Tables"**.

---

## 3. Bulk Importing Tables from Excel

If you are setting up a new restaurant with 50+ tables across multiple dining areas (AC Hall, Rooftop, Garden, Bar), you can import them all in seconds using Excel:

1. Go to **Settings** $\rightarrow$ **Restaurant Setup** $\rightarrow$ **Tables & Areas**.
2. Click **Import from Excel (📊)**.
3. Click **Download Sample Template** to get the formatted spreadsheet.
4. Fill in your table names, capacities, and area names in Excel:

| Table Name | Area / Zone | Capacity | Shape | Assigned Waiter |
| :--- | :--- | :--- | :--- | :--- |
| Table 01 | Main Hall | 4 | SQUARE | waiter_rahul |
| Table 02 | Main Hall | 4 | SQUARE | waiter_rahul |
| Table T1 | Rooftop Terrace | 6 | ROUND | captain_anita |
| Table VIP | VIP Lounge | 8 | RECTANGLE | captain_anita |

5. Drag & drop the `.xlsx` file and click **Import Tables**.
6. The system creates all dining zones and table cards instantly.

---

## 4. Settling Individual Client Bills

- When **Client 1** wants to leave early, open their tab and click **Settle Bill**.
- Process payment (Cash, Card, or UPI).
- **Client 1's** receipt prints, while **Client 2** remains active at the table.
- When the final client pays, the table resets to **Available**.

---

## 5. Frequently Asked Questions (FAQ)

#### Q1: Can one client pay Cash and another pay with Credit Card?
> **Yes.** Each sub-bill is a completely separate financial transaction with its own invoice number, receipt, and payment method.

#### Q2: Can dishes be moved between clients at the same table?
> **Yes.** Tap the dish, click **Move to Client**, and select the target client's tab.
