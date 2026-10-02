# 💰 Accounting & Financial Ledger User Guide

This user guide is written for **store owners, accountants, bookkeepers, and managers**. Learn how to maintain your general ledger, record vouchers (Journal, Payment, Receipt, Contra), manage bank accounts, track loans and EMIs, and generate real-time financial statements (Profit & Loss, Balance Sheet, Trial Balance) without complex accounting jargon.

---

## 📑 Table of Contents
1. [Overview & Navigation](#1-overview--navigation)
2. [Chart of Accounts (COA) Tree Setup](#2-chart-of-accounts-coa-tree-setup)
3. [Double-Entry Accounting Vouchers](#3-double-entry-accounting-vouchers)
   - [Journal Voucher (JV)](#journal-voucher-jv)
   - [Payment Voucher (PV)](#payment-voucher-pv)
   - [Receipt Voucher (RV)](#receipt-voucher-rv)
   - [Contra Voucher (CV)](#contra-voucher-cv)
4. [Bank Accounts & Bank Reconciliation](#4-bank-accounts--bank-reconciliation)
5. [Loan, Capital Asset & EMI Management](#5-loan-capital-asset--emi-management)
6. [Cash Ledger & Daily Cashbook](#6-cash-ledger--daily-cashbook)
7. [Financial Statements & Reports](#7-financial-statements--reports)
   - [Trial Balance](#trial-balance)
   - [Profit & Loss Statement (P&L)](#profit--loss-statement-pl)
   - [Balance Sheet](#balance-sheet)

---

## 1. Overview & Navigation

Access the financial system from the left navigation under **Accounting**:

```text
Accounting
├── 📊 Accounting Dashboard
├── 🌳 Chart of Accounts (COA)
├── 🧾 Accounting Vouchers
├── 🏦 Bank Accounts
├── 💳 Loan & EMI Management
├── ⚖️ Trial Balance
├── 📈 Profit & Loss Statement
└── 🏛️ Balance Sheet
```

---

## 2. Chart of Accounts (COA) Tree Setup

The **Chart of Accounts** organizes every rupee/dollar in your business into 5 master accounting groups:

1. **Assets**: Cash, Bank balances, Inventory stock, Shop furniture, POS computers.
2. **Liabilities**: Supplier unpaid balances, Bank loans, Outstanding taxes (GST/VAT payable).
3. **Equity**: Owner's initial capital investment, Retained earnings.
4. **Income / Revenue**: Retail sales revenue, Restaurant sales, Delivery charges collected.
5. **Expenses**: Rent, Staff salaries, Electricity, Packaging, Petty cash items.

### Creating a New Ledger Account
1. Go to **Accounting > Chart of Accounts**.
2. Click **Add New Account ➕**.
3. Enter Details:
   - **Account Name**: e.g., *'Store Electricity Expense'* or *'HDFC Current Account'*.
   - **Parent Group**: Select the category (e.g., *Direct Expenses*, *Bank Accounts*, *Current Assets*).
   - **Opening Balance**: Starting amount if transferring from another system.
4. Click **Save Account**.

---

## 3. Double-Entry Accounting Vouchers

Every financial event is recorded with an automated double-entry voucher where **Total Debits = Total Credits**:

### Journal Voucher (JV)
Used for adjustments, depreciation, opening balances, and non-cash transfers:
1. Go to **Accounting > Accounting Vouchers > New Voucher**.
2. Select **Voucher Type: Journal**.
3. Select the **Debit Account** and amount.
4. Select the **Credit Account** and amount.
5. Add a clear **Narration / Description** (e.g., *'Monthly shop depreciation adjustment for October'*).
6. Click **Post Voucher**.

### Payment Voucher (PV)
Used whenever money leaves your cash drawer or bank account (e.g., paying shop rent, vendor balance, electricity):
1. Select **Voucher Type: Payment**.
2. Select the **Paid From Account** (*Cash Drawer* or *Bank Account*).
3. Select the **Expense / Supplier Account** (*Shop Rent Expense*).
4. Enter the amount paid.
5. Click **Post Voucher**.

### Receipt Voucher (RV)
Used whenever you receive money from customers, incentives, or scrap sales:
1. Select **Voucher Type: Receipt**.
2. Select the **Deposit Account** (*Cash Drawer* or *Bank Account*).
3. Select the **Received From Account** (*Customer Name* or *Other Income*).
4. Enter amount and click **Post Voucher**.

### Contra Voucher (CV)
Used strictly for transfers between your own cash drawers and bank accounts:
- **Cash Deposit**: Moving money from cash drawer to bank account.
- **Cash Withdrawal**: Withdrawing cash from bank ATM to store cash drawer.
- **Bank to Bank Transfer**: Moving funds between your two company bank accounts.

---

## 4. Bank Accounts & Bank Reconciliation

Manage company bank accounts and reconcile monthly bank statements:

1. Go to **Accounting > Bank Accounts**.
2. Add your bank accounts (Account Number, Bank Name, Branch, IFSC/SWIFT code).
3. Set your primary operational bank account.
4. **Reconciliation**:
   - Compare system ledger transactions against your bank passbook statement.
   - Match dates and amounts and click **Mark Reconciled**.
   - Review unreconciled cheques and uncleared deposits with 1 click.

---

## 5. Loan, Capital Asset & EMI Management

Track bank business loans, equipment financing, and monthly installments:

### Adding a Loan
1. Go to **Accounting > Loan & EMI Management**.
2. Click **New Business Loan ➕**.
3. Enter:
   - **Lender Bank / Institution**.
   - **Principal Loan Amount** (e.g., \$50,000).
   - **Annual Interest Rate (%)** (e.g., 9.5%).
   - **Tenure in Months** (e.g., 36 months).
   - **Start Date**.
4. The system automatically computes the **Monthly EMI**, total interest, and amortization schedule.

### Recording Monthly EMI Payment
1. Open the active loan profile.
2. Click **Pay EMI**.
3. Select payment bank account.
4. The software automatically splits the installment into **Principal Repayment (Liability reduction)** and **Interest Paid (Expense)** in your general ledger.

---

## 6. Cash Ledger & Daily Cashbook

Monitor real-time cash inflows and outflows:
- Open **Accounting > Cash Ledger** (or **Reports > Cash Ledger**).
- View starting cash balance, sales cash receipts, expense payouts, vendor payments, and ending cash balance.
- Filter by date range or specific cashier terminal.

---

## 7. Financial Statements & Reports

Generate certified financial statements anytime for your accountant or tax filings:

### Trial Balance
- Go to **Accounting > Trial Balance**.
- Displays summary debit and credit totals for all ledger accounts.
- Ensures books are balanced (**Debits = Credits**).

### Profit & Loss Statement (P&L)
- Go to **Accounting > Profit & Loss Statement**.
- Select the financial period (e.g., *Current Month*, *Quarter*, *Financial Year*).
- Displays:
  - **Revenue / Gross Sales**
  - **Cost of Goods Sold (COGS)**
  - **Gross Profit**
  - **Operating Expenses (Rent, Salaries, Utilities)**
  - **Net Profit / Loss**

### Balance Sheet
- Go to **Accounting > Balance Sheet**.
- Provides an exact snapshot of company net worth:
  - **Total Assets = Total Liabilities + Owner's Equity**
- Export as PDF or Excel for bank loan audits or tax returns.

---

*Take control of your store's finances with complete ease and zero guesswork!*
