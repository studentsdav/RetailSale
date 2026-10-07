# User Guide: Dynamic Console Routing & Multi-App Order Flow

This guide explains how orders from different channels (Customer App, Waiter Floor App, QR Dining, and Delivery Riders) are automatically routed to the correct staff consoles.

---

## 📑 Table of Contents
1. [How Order Routing Works](#1-how-order-routing-works)
2. [Dining Orders $\rightarrow$ Captain Console](#2-dining-orders--captain-console)
3. [Retail Customer Orders $\rightarrow$ Retailer Console](#3-retail-customer-orders--retailer-console)
4. [Delivery Orders $\rightarrow$ Rider Portal](#4-delivery-orders--rider-portal)
5. [Staff Navigation Tips](#5-staff-navigation-tips)

---

## 1. How Order Routing Works

The system automatically detects where an order was placed and instantly sends it to the dedicated workstation console without manual forwarding:

```
[ Customer Table QR / Waiter App ] ---> 🍽️ Captain / Waiter Console
[ Online Store / Customer Mobile App ] ---> 🛍️ Retailer Operations Console
[ Home Delivery Dispatch ]           ---> 🛵 Rider & Delivery Portal
```

---

## 2. Dining Orders $\rightarrow$ Captain Console

When a customer orders from a table QR code or a waiter sends a KOT from their mobile floor device:
- The order appears immediately on the **Captain Console**.
- Highlights the active **Table Number**, **Occupied Seats**, and **Order Items**.
- Prints or routes the KOT directly to the kitchen display screen (KDS).

---

## 3. Retail Customer Orders $\rightarrow$ Retailer Console

When a shopper places an order through the Retail Consumer mobile app or store web catalog:
- The order notification arrives in the **Retailer Console** (`/retailer-console`).
- Staff can accept, pack items, scan barcodes for verification, and generate final invoices.

---

## 4. Delivery Orders $\rightarrow$ Rider Portal

When an order is ready for delivery:
- It appears in the **Rider Portal** for assigned delivery personnel.
- Shows customer address, turn-by-turn map coordinates, and payment collection mode (COD / Prepaid).
- Secure handover via customer OTP verification.

---

## 5. Staff Navigation Tips

- **Automatic Landing**: When logging in, staff are routed straight to their primary workstation screen according to their assigned role.
- **Top Quick Switcher**: Managers and Admins can switch between the POS Billing terminal, Captain Console, and Retailer Operations Console from the main dashboard at any time.
