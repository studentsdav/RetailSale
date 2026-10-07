# User Guide: Vendor Management, Opening Balances, VAT Rounding & Supplier Payments

This guide explains how to add domestic and international vendors, record initial opening balances, round tax-inclusive purchase orders, and settle supplier bills using custom payment methods.

---

## 📑 Table of Contents
1. [Adding Vendors (Domestic & International)](#1-adding-vendors-domestic--international)
2. [Entering Vendor Opening Balances](#2-entering-vendor-opening-balances)
3. [Tax-Inclusive Purchase Orders & Whole Number Rounding](#3-tax-inclusive-purchase-orders--whole-number-rounding)
4. [Linking Payment Methods to Chart of Accounts (COA)](#4-linking-payment-methods-to-chart-of-accounts-coa)
5. [Paying Suppliers with Custom Payment Modes](#5-paying-suppliers-with-custom-payment-modes)

---

## 1. Adding Vendors (Domestic & International)

1. Navigate to **Purchases** $\rightarrow$ **Supplier Master** (or **Vendors**).
2. Click **+ Add Vendor**.
3. Fill in the required details:
   - **Company / Vendor Name**: (e.g. *Metro Food Supplies Ltd*).
   - **Contact Person & Mobile**: (e.g. *John Miller - +1 555-0199*).
   - **Country**: Select vendor's country.
   - **State / Province**: **Optional**. (For international vendors, this can be left blank without blocking form submission).
   - **Tax ID / GSTIN / VAT Number**: (e.g. *VAT987654321*).

---

## 2. Entering Vendor Opening Balances

When migrating to RetailPOS with existing supplier debt:

1. In the **Add / Edit Vendor** form, locate **Opening Balance**.
2. Enter the outstanding amount you owe the vendor (e.g., `₹45,000` or `$1,200.00`).
3. Select the balance date.
4. Click **Save Vendor**.

### What happens in the background:
- An opening payable balance is created in the **Chart of Accounts (COA)** under Accounts Payable.
- An opening bill (`OPN-...`) is automatically generated so you can make payments against it directly.

---

## 3. Tax-Inclusive Purchase Orders & Whole Number Rounding

When entering purchase orders or Goods Receiving Notes (GRN) with **VAT / Tax Inclusive** pricing:
- The system automatically calculates gross amounts and taxes.
- The **Net Payable Amount** is rounded to the nearest integer without fractional cents/paise (e.g., ₹1,450.48 $\rightarrow$ **₹1,450**; $520.80 $\rightarrow$ **$521**).
- Prevents rounding mismatch disputes on vendor commercial invoices.

---

## 4. Linking Payment Methods to Chart of Accounts (COA)

To ensure every supplier payment is credited to the correct bank or cash account:

1. Go to **Settings** $\rightarrow$ **Payment Methods**.
2. Click **Add Payment Method** or **Edit** an existing one (e.g. *HDFC Current Account*, *Chase Bank*, *Petty Cash Safe*).
3. Under **Linked COA Account**, select the corresponding balance sheet asset account:
   - *1010 - Main Cash on Hand*
   - *1020 - Primary Commercial Bank A/c*
   - *1030 - Digital Merchant Wallet*
4. Save.

---

## 5. Paying Suppliers with Custom Payment Modes

1. Open **Purchases** $\rightarrow$ **Supplier Payments**.
2. Select the vendor and pending bill.
3. In the **Payment Method** dropdown, all your customized payment channels (Bank Transfer, Company Cheque, M-Pesa, Corporate Card) are available.
4. Enter the paid amount and reference number.
5. Click **Record Payment**. The vendor sub-ledger and your bank ledger are updated in real time.
