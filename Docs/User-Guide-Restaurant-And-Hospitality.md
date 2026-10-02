# 🍽️ Restaurant & Hospitality Module User Guide

This guide is written for **restaurant owners, captains, waitstaff, chefs, cashiers, and delivery managers**. Learn how to configure dining areas, take table orders, dispatch KOTs to the kitchen, track cooking times on the KDS, settle bills, and manage takeaway deliveries step-by-step.

---

## 📑 Table of Contents
1. [Overview & Navigation](#1-overview--navigation)
2. [Setting Up Floors, Dining Areas & Tables](#2-setting-up-floors-dining-areas--tables)
3. [Visual Floor Plan & Table Reservations](#3-visual-floor-plan--table-reservations)
4. [Captain Dashboard & Taking Table Orders (KOT)](#4-captain-dashboard--taking-table-orders-kot)
5. [Kitchen Display System (KDS) for Chefs](#5-kitchen-display-system-kds-for-chefs)
6. [Managing Running Orders, Table Transfers & Merging](#6-managing-running-orders-table-transfers--merging)
7. [Bill Settlement & Payment Checkout](#7-bill-settlement--payment-checkout)
8. [Takeaway Orders & Delivery Challan Dispatch](#8-takeaway-orders--delivery-challan-dispatch)
9. [Restaurant Expenses & Petty Cash](#9-restaurant-expenses--petty-cash)
10. [Restaurant Analytics & Sales Reports](#10-restaurant-analytics--sales-reports)

---

## 1. Overview & Navigation

The Restaurant & Hospitality module is accessible from the main left sidebar under **Restaurant**:

```text
Restaurant
├── 🗺️ Floor Plan Configurator
├── 📅 Table Reservation
├── 📋 KOT Builder
├── 📜 KOTs History
├── 📺 Kitchen Display System (KDS)
├── 📱 Captain Dashboard
├── 🏃 Running Orders
├── 🚚 Delivery Challan
├── 💵 Expense Entry & Recurring Expenses
└── 📊 Restaurant Analytics Reports
```

---

## 2. Setting Up Floors, Dining Areas & Tables

Before opening for business, configure your restaurant's physical layout:

### Step 1: Create Dining Floors / Areas
1. Go to **Restaurant > Restaurant Setup** (or **Floor Plan Configurator**).
2. Click **Add Floor / Area**.
3. Enter the Area Name (e.g., *Ground Floor Dining*, *AC Family Hall*, *Rooftop Lounge*, *Outdoor Garden*).
4. Save the area.

### Step 2: Add Dining Tables
1. Select the Floor/Area.
2. Click **Add Table**.
3. Configure Table Details:
   - **Table Number / Code**: e.g., `T-01`, `T-02`, `VIP-1`, `BAR-3`.
   - **Seating Capacity**: e.g., 2 Seats, 4 Seats, 8 Seats.
   - **Table Shape**: Round, Square, Rectangle.
   - **Table Type**: Dine-in, Bar, VIP, Booth.
4. Click **Save Table**.

---

## 3. Visual Floor Plan & Table Reservations

### Visual Floor Plan Configurator
- Open **Restaurant > Floor Plan Configurator**.
- Drag and arrange tables visually to match your restaurant layout.
- Color codes explain current table status at a glance:
  - 🟢 **Green (Available)**: Table is empty and ready for guests.
  - 🟠 **Orange / Red (Occupied)**: Table currently has seated guests with active orders.
  - 🔵 **Blue (Reserved)**: Table is booked for an upcoming reservation.
  - 🟡 **Yellow (Billed / Awaiting Payment)**: Food finished, bill printed, awaiting settlement.

### Table Reservations
1. Go to **Restaurant > Table Reservation**.
2. Click **New Reservation 📅**.
3. Fill in the guest details:
   - **Customer Name & Phone Number**.
   - **Date & Time Slot** (e.g., 8:00 PM).
   - **Number of Guests** (e.g., 6 Guests).
   - **Assigned Table** (e.g., Table 5 or VIP-2).
   - **Special Notes** (e.g., *Birthday anniversary, high chair needed*).
4. Click **Confirm Reservation**. The table on the floor plan will turn blue with a reservation tag.

---

## 4. Captain Dashboard & Taking Table Orders (KOT)

Waitstaff and Captains can use mobile tablets or POS terminals to take orders tableside:

1. Open **Restaurant > Captain Dashboard** (or **KOT Builder**).
2. Tap the table where the customer is seated (e.g., **Table 4**).
3. Tap food categories (e.g., *Starters*, *Main Course*, *Beverages*, *Desserts*).
4. Tap items to add to the order.
5. **Adding Item Modifiers / Notes**:
   - Tap an item to add kitchen instructions: *'Less spicy'*, *'No onions'*, *'Extra cheese'*, *'Serve warm'*.
6. Click **Fire KOT / Send to Kitchen 🍳**.
   - The Kitchen printer prints the physical KOT ticket with Table Number, Time, Waiter Name, and Item details.
   - The order immediately appears on the **Kitchen Display Screen (KDS)**.

---

## 5. Kitchen Display System (KDS) for Chefs

Replace paper slips in the hot kitchen with interactive touchscreens:

1. Open **Restaurant > Kitchen Display System (KDS)** on kitchen monitors or tablets.
2. New orders appear instantly with audible alert chimes.
3. Cards display ordered items, special modifiers, table numbers, and live elapsed timers:
   - 🟢 **Fresh (0–10 mins)**: Normal cooking pace.
   - 🟡 **Warning (10–20 mins)**: Attention required.
   - 🔴 **Delayed (>20 mins)**: Flashing urgent alert to kitchen supervisor.
4. When a dish is prepared, the chef taps **Item Ready** or **Complete KOT**.
5. The Captain receives an instant notification that food is ready for pickup!

---

## 6. Managing Running Orders, Table Transfers & Merging

### Adding More Items to an Existing Table
1. Open **Restaurant > Running Orders**.
2. Tap the active table (e.g., Table 4).
3. Add the additional items and tap **Send Supplementary KOT**.
4. Kitchen receives a supplementary ticket marked *'Running Order Add-on'*.

### Transferring Guests to Another Table
If guests request a move (e.g., from Table 2 to outdoor Table 12):
1. On the Floor Plan or Running Orders screen, select **Table 2**.
2. Click **Transfer Table**.
3. Choose **Table 12** and confirm. All active items and billing move automatically.

### Merging Tables for Group Dining
1. Click **Merge Tables**.
2. Select Primary Table (e.g., Table 7) and Secondary Table (e.g., Table 8).
3. Confirm merge. Both tables are locked together, and all items accumulate onto one master bill.

---

## 7. Bill Settlement & Payment Checkout

When guests ask for the check:

1. In **Running Orders**, tap the table and click **Print Bill / Check**.
   - A proforma guest check prints with subtotal, taxes (GST/VAT), service charge, and discounts.
   - Table turns yellow (*Awaiting Payment*).
2. When payment is received, click **Settle & Close Table**.
3. Choose Payment Method:
   - **Cash**: Enter received amount; the software shows exact change to return.
   - **Credit/Debit Card**: Enter card reference.
   - **UPI / QR Code**: Scan store dynamic QR code.
   - **Split Payment**: Split between cash and card.
4. Click **Complete Payment**.
5. The final Tax Invoice prints, the table turns green (*Available*), and cash accounts update instantly!

---

## 8. Takeaway Orders & Delivery Challan Dispatch

Manage online delivery orders (Swiggy, Zomato, UberEats, Direct phone orders):

1. Go to **Restaurant > Delivery Challan**.
2. Click **New Takeaway / Delivery Order**.
3. Select Order Type:
   - **Takeaway / Counter Pickup**
   - **Direct Home Delivery**
4. Enter customer delivery address, contact number, and food items.
5. Click **Generate Delivery Challan**.
6. Assign an available Rider from your staff.
7. Hand over the sealed food package with the delivery challan slip.
8. When the rider returns with payment, click **Mark Delivered & Settle Cash**.

---

## 9. Restaurant Expenses & Petty Cash

Track daily kitchen ingredient purchases (fresh vegetables, milk, gas cylinders):

1. Go to **Restaurant > Expense Entry**.
2. Select the Expense Category (e.g., *Daily Vegetables*, *Dairy & Milk*, *Cleaning Supplies*, *Gas Refill*).
3. Enter amount paid, vendor name, and payment mode (*Petty Cash Drawer* or *Bank*).
4. Click **Save Expense**.
5. For regular recurring bills (monthly rent, water cans), use **Recurring Expenses** to automate monthly reminders.

---

## 10. Restaurant Analytics & Sales Reports

Monitor restaurant performance under **Restaurant > Restaurant Analytics Reports**:

- **Top Selling Dishes**: Identify your most popular appetizers, main courses, and desserts.
- **Table Turnover Rate**: Average time guests spend at tables.
- **Hourly Peak Rush**: Discover your busiest dining hours (lunch vs dinner rush).
- **Captain Performance**: Sales volume and orders taken per waiter.
- **Kitchen Preparation Speed**: Average KOT cooking time from order fire to completion.

---

*Enjoy seamless restaurant management! For fast lookups, ask **Lynx AI 🤖** or consult the Store FAQ.*
