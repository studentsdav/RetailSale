# User Guide: Multi-Gateway Setup & Virtual Payment Simulator

This guide covers how to set up payment gateways (Razorpay, Stripe, Square, PayPal, M-Pesa, UPI QR) and how cashiers use the **Virtual Payment Simulator** during POS checkout to test or simulate digital transactions without physical card machines.

---

## 📑 Table of Contents
1. [Overview of Supported Payment Methods](#1-overview-of-supported-payment-methods)
2. [Configuring Payment Gateways](#2-configuring-payment-gateways)
3. [Using the Virtual Payment Simulator in POS Billing](#3-using-the-virtual-payment-simulator-in-pos-billing)
4. [Settlement Modes: Direct vs. Hold](#4-settlement-modes-direct-vs-hold)
5. [Troubleshooting & Payment FAQ](#5-troubleshooting--payment-faq)

---

## 1. Overview of Supported Payment Methods

Your POS terminal supports omnichannel payments configured per outlet:

| Gateway / Method | Supported Regions | Features |
| :--- | :--- | :--- |
| **UPI Dynamic QR** | India | Instant zero-fee QR code printed on invoice or displayed on customer-facing screen. |
| **Razorpay** | India / Global | Credit/Debit Cards, Netbanking, UPI, Wallets, and Auto-Refunds. |
| **Stripe** | US / EU / Global | Credit/Debit Cards, Apple Pay, Google Pay, SEPA. |
| **Square POS** | US / CA / UK / AU | Square Terminal hardware sync, tap-to-pay, chip cards. |
| **PayPal** | Global | Web checkout, international card payments. |
| **Safaricom M-Pesa** | Kenya / East Africa | Direct STK Push to customer's mobile phone and C2B Till verification. |
| **Bank Transfer / Cash** | Global | Cash drawer settlement and direct bank reference logging. |

---

## 2. Configuring Payment Gateways

To configure payment gateways for your store:

1. Open **Settings** $\rightarrow$ **Payment Gateways** (`payment_gateways_screen.dart`).
2. You will see tabs for each supported gateway:
   - **UPI / Dynamic QR**:
     - Enter your **UPI ID / VPA** (e.g. `merchant@okhdfcbank`).
     - Enter your registered **Payee Legal Name** (e.g. `Retail Store Private Limited`).
     - Toggle **Print Dynamic QR on Invoices** ON.
   - **Razorpay**:
     - Toggle **Enable Razorpay** ON.
     - Select Environment: **Test Mode (Sandbox)** or **Live / Production**.
     - Enter **Key ID** (e.g. `rzp_test_...` or `rzp_live_...`).
     - Enter **Key Secret**.
   - **Stripe**:
     - Toggle **Enable Stripe** ON.
     - Select Environment (**Test** or **Live**).
     - Enter **Publishable Key** (`pk_test_...` or `pk_live_...`).
     - Enter **Secret Key** (`sk_test_...` or `sk_live_...`).
   - **Square**:
     - Enter **Application ID**, **Location ID**, and **OAuth Access Token**.
   - **M-Pesa (Kenya)**:
     - Select Type: **Till Number** or **Paybill**.
     - Enter **Shortcode**, **Consumer Key**, **Consumer Secret**, and **Lipa Na M-Pesa Passkey**.
3. Click **Save Gateway Configuration**.

---

## 3. Using the Virtual Payment Simulator in POS Billing

The **Virtual Payment Simulator** (`virtual_payment_simulator_dialog.dart`) allows cashiers to test, demo, or simulate digital card and UPI transactions when training staff, testing POS workflows, or when internet card terminals are offline.

### Step-by-Step Checkout Flow:
1. Ring up items on the **POS Billing Screen** (`salescreen.dart`).
2. Tap **Pay / Checkout**.
3. In the payment methods bar, click **Card**, **UPI**, or **Simulate Digital Pay**:
4. The **Virtual Payment Simulator** modal pops up:
   - **Dynamic QR Code Tab**:
     - Displays a live generated QR code embedded with merchant UPI/bill details and total payable amount.
     - Click **Simulate Customer Scan & Pay** to simulate a successful mobile payment callback.
   - **Credit / Debit Card Tab**:
     - Shows a virtual terminal interface.
     - Choose Card Type: Visa, MasterCard, RuPay, or Amex.
     - Click **Simulate Card Tap / Chip Insert**.
     - You can simulate **Approved** (with simulated Auth Code & RRN) or test **Decline / Insufficient Funds** responses.
   - **M-Pesa STK Push Tab**:
     - Enter the customer's phone number (`2547XXXXXXXX`).
     - Click **Send STK Push**.
     - Watch live status polling until the customer enters their PIN.
5. Once approved, the dialog returns a verified `VirtualPaymentResult` containing:
   - `referenceId` (e.g. `TXN_984729184`)
   - `authCode` (e.g. `AUTH8921`)
   - `rrn` (Retrieval Reference Number)
   - `cardBrand` & `last4`
6. The POS invoice automatically records the transaction reference, prints the receipt, and deducts the inventory.

---

## 4. Settlement Modes: Direct vs. Hold

In **Payment Settings**, you can choose between two restaurant/retail settlement modes:
- **DIRECT Settlement**: Payments immediately close the order, deduct stock, and record the invoice into the accounting ledger.
- **HOLD / Pre-Auth Mode**: Card pre-authorizations place a temporary hold on the customer's card (common in bar tabs and fine dining). The bill can be adjusted with tips or extra drinks before final settlement.

---

## 5. Troubleshooting & Payment FAQ

### Q1: Can I run POS billing in Test Mode without real bank credentials?
**Yes.** Keep gateways in **Test / Sandbox** mode or use the Virtual Payment Simulator. The simulator generates realistic approval codes and test receipts without debiting real bank accounts.

### Q2: What happens if a customer card transaction fails?
The simulator and live gateways show an instant red alert with the bank reason code (e.g., *Declined: Insufficient Funds*, *Expired Card*, or *Network Timeout*). The POS order remains on hold, allowing the cashier to retry or switch to cash.

### Q3: Where can I see payment reference numbers for accounting reconciliation?
Open **Reports** $\rightarrow$ **Cash & Payment Ledger** or **Daily Shift Summary**. Every digital payment lists its Gateway Name, Transaction ID, RRN, and timestamp.
