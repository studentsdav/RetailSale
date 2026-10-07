# User Guide: Contactless QR Table Ordering for Restaurants & Cafes

This guide walks you through designing Table QR Codes, placing QR standees on tables, and managing live customer orders from dining tables.

---

## 📑 Table of Contents
1. [What is QR Table Ordering?](#1-what-is-qr-table-ordering)
2. [Designing & Printing Table QR Codes](#2-designing--printing-table-qr-codes)
3. [The Guest Dining Experience (How Customers Order)](#3-the-guest-dining-experience-how-customers-order)
4. [How Staff Receive & Manage QR Table Orders](#4-how-staff-receive--manage-qr-table-orders)
5. [Adding Items, Splitting Bills & Settlement](#5-adding-items-splitting-bills--settlement)
6. [Frequently Asked Questions (FAQ)](#6-frequently-asked-questions-faq)

---

## 1. What is QR Table Ordering?

QR Table Ordering allows guests at your restaurant, cafe, or bar to scan a QR code placed on their table using their smartphone camera.

### Key Benefits:
- **No App Installation Needed**: Opens instantly in any web browser (Safari, Chrome, Firefox).
- **Faster Ordering**: Customers can view full dish photos, descriptions, and dietary indicators (Veg/Non-Veg) immediately.
- **Customizations & Add-ons**: Guests can select portion sizes, toppings, spice levels, and add kitchen instructions (e.g. *"extra crispy"*, *"no onions"*).
- **Direct Kitchen Flow**: Orders generate instant Kitchen Order Tickets (KOT) on kitchen displays or thermal receipt printers.

---

## 2. Designing & Printing Table QR Codes

Navigate to **Restaurant / Dining** $\rightarrow$ **Table QR Designer** (`table_qr_designer_screen.dart`):

```
+------------------------------------------------------------------------+
| 🎨 Table QR Designer & Print Studio                                    |
|------------------------------------------------------------------------|
| Layout Format: [ Google Standee | Tent Card | Acrylic Stand | Sticker ]|
| Color Theme:   [ Google Modern | Royal Indigo | Luxury Dark | Amber ]  |
| Options:       [X] Center Logo   [X] Wi-Fi Badge   [X] Cutting Guides  |
| Wi-Fi SSID:    "CafeDelight_5G"       Wi-Fi Password: "coffee123"      |
|                                                                        |
| [ Preview Table: Table 5 - AC Dining ]       [ Bulk Print All Tables ] |
+------------------------------------------------------------------------+
```

### Supported Print Formats:
1. **Google Style Standee Poster**: Premium modern layout with restaurant branding and Wi-Fi credentials badge.
2. **Tabletop Tent Card**: Double-sided foldable card for freestanding table display.
3. **Acrylic Standee Insert**: Sized for standard $4 \times 6\text{ inch}$ or A6 clear acrylic holders.
4. **Coaster / Table Corner Sticker**: Compact round or square stickers for outdoor or bar seating.
5. **A4 Multi-Table Sheet**: Prints multiple tables on a single A4 page for cost-effective mass production.

---

## 3. The Guest Dining Experience (How Customers Order)

When a customer sits at Table 5:

1. **Scan QR Code**: The guest points their smartphone camera at the table QR standee.
2. **Explore Menu**:
   - Filter by categories (*Starters*, *Main Course*, *Mocktails*, *Desserts*).
   - Filter by dietary preference with **Pure Veg (🟢)** or **Non-Veg (🔴)** switches.
3. **Customize Items**:
   - Tap an item to choose modifiers (e.g. *Add Extra Cheese +₹30*, *Almond Milk +₹40*).
   - Enter special kitchen instructions.
4. **Submit Order**:
   - Tap **Place Order**.
   - A digital token is generated, and the table order is sent to the kitchen.
5. **Live Status Tracking**:
   - Guests can watch their order status change in real time from **Accepted** to **Preparing in Kitchen** to **Served**.

---

## 4. How Staff Receive & Manage QR Table Orders

When a guest places an order from their phone:

- **Captain Console (`captain_dashboard_screen.dart`)**:
  - The table icon lights up and pulses with a yellow **"New Order"** indicator.
  - A subtle notification chime sounds on floor tablets.
- **Kitchen KDS & Printers**:
  - The Kitchen Display System immediately displays the new KOT with table number, quantities, and modifier notes.
  - Kitchen thermal printers print a physical KOT slip automatically.

---

## 5. Adding Items, Splitting Bills & Settlement

- **Repeat / Continuous Ordering**: Guests can scan the QR code again during their meal to order additional appetizers, drinks, or desserts. All new items are automatically merged into their active table bill.
- **Calling the Waiter**: Guests can tap **"Call Waiter"** on their digital menu to request assistance.
- **Bill Settlement**:
  - When guests are ready to leave, the waiter or cashier opens the table in the POS, prints the pre-check bill, and settles the transaction via Cash, Card, or UPI QR code.
  - Clearing the table in POS automatically resets the table status to **Available** for the next guests.

---

## 6. Frequently Asked Questions (FAQ)

#### Q1: Does the guest need to create an account to order?
> **No.** Guests can immediately browse and order as anonymous table guests. They can optionally enter their name or mobile number for loyalty points and digital SMS receipts.

#### Q2: Can staff still take orders manually on the same table?
> **Yes.** Waiters can add or edit dishes on any table from their mobile Captain Console at the same time guests are ordering from their phones.

#### Q3: Does QR ordering work offline on local Wi-Fi?
> **Yes.** Because the POS server runs locally on your store network (e.g. `http://192.168.1.100:3000`), guests connected to your restaurant's Wi-Fi can order even if the internet connection is temporarily down.
