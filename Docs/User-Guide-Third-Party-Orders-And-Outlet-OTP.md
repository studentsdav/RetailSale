# User Guide: Third-Party Orders Report & Outlet OTP Verification

This guide explains how to track orders imported from third-party delivery platforms (Zomato, Swiggy, UberEats, etc.), how branch onboarding uses **SMS/Email OTP verification**, and how store admins automatically receive their login credentials upon outlet creation.

---

## 📑 Table of Contents
1. [Third-Party Orders Analytics & Audit Report](#1-third-party-orders-analytics--audit-report)
2. [Filtering Aggregator Channels (Zomato, Swiggy, UberEats)](#2-filtering-aggregator-channels-zomato-swiggy-ubereats)
3. [Commission, Net Payout & Reconciliation](#3-commission-net-payout--reconciliation)
4. [Outlet Registration & Phone/Email OTP Verification](#4-outlet-registration--phoneemail-otp-verification)
5. [Automated Email of Admin Credentials](#5-automated-email-of-admin-credentials)

---

## 1. Third-Party Orders Analytics & Audit Report

When you connect external delivery aggregators or e-commerce marketplace plugins, orders flow into your POS system automatically. 

The **Third-Party Orders Report** (`third_party_orders_report_screen.dart`) gives you an audit trail of every external order:
1. Navigate to **Reports** $\rightarrow$ **Third-Party Orders** (`third_party_orders_report_screen.dart`).
2. The summary cards at the top display:
   - **Total Aggregator Gross Sales**
   - **Total Order Count**
   - **Total Platform Commissions / Fees Deducted**
   - **Net Cash Payout Expected**

---

## 2. Filtering Aggregator Channels (Zomato, Swiggy, UberEats)

Use the top filter bar to narrow down orders:
- **Platform Selector**: Choose `ALL`, `Zomato`, `Swiggy`, `UberEats`, `B2B Marketplace`, or any custom delivery plugin.
- **Search Bar**: Search by third-party order ID (e.g. `ZOM-98218`), customer name, or phone number.
- **Date Range**: Select Today, This Week, This Month, or custom date ranges.
- **Sync Now Button**: Click **Sync Orders** to fetch the latest orders immediately from connected marketplace APIs.

---

## 3. Commission, Net Payout & Reconciliation

Each row in the audit grid displays:
- **Order ID & Time**: Platform reference number and placement timestamp.
- **Platform Source**: Brand tag (e.g. `SWIGGY`, `ZOMATO`).
- **Items & Qty**: Ordered items with customer preparation remarks.
- **Gross Order Total**: Total paid by customer.
- **Platform Commission**: Aggregator fee percentage and deducted amount.
- **Net Receivable**: Exact amount the aggregator owes your bank account.
- **Order Status**: `ACCEPTED`, `PREPARING`, `DISPATCHED`, `DELIVERED`, or `CANCELLED`.

You can export this report to **Excel (.xlsx)** or clean **Universal Text (.txt)** format for bank statement reconciliation.

---

## 4. Outlet Registration & Phone/Email OTP Verification

When setting up a new retail branch or franchise location:
1. Open **Settings** $\rightarrow$ **Outlets** $\rightarrow$ **Add New Outlet**.
2. Enter the store details (Outlet Name, Address, Manager Mobile Number, Admin Email).
3. Click **Request Verification OTP**:
   - A 6-digit one-time passcode is sent to the registered mobile number and email.
4. Enter the 6-digit OTP into the verification prompt.
5. Once verified, the branch database schema is automatically provisioned.

---

## 5. Automated Email of Admin Credentials

Upon successful verification and outlet creation:
- The system automatically triggers an onboarding welcome email sent to the store owner's address.
- The email includes:
  - **Outlet Code & Unique Branch Name**
  - **Admin Login ID / Username**
  - **Temporary Secure Password**
  - **Web POS URL & Fast PIN Access Instructions**
- The new branch manager can immediately log in and begin billing.
