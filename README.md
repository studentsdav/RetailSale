# Enterprise Retail & Restaurant ERP & POS System

A comprehensive, production-ready ERP and Multi-Module POS solution built with a cross-platform **Flutter** client and high-performance **Node.js / PostgreSQL** backend. Designed for hybrid retail stores, restaurants, multi-branch operations, and enterprise inventory management.

---

> [!NOTE]
> This repository is actively maintained and sponsored by **Famalth Technologies**.

---

## 🌟 Core Enterprise Modules

### 🍽️ 1. Restaurant POS & Dining Suite
- **Interactive Floor & Table Management**: Live visual floor plan, table reservations, occupancy status, and quick table transfers or bill merging.
- **Kitchen Display System (KDS) & KOT**: Instant Kitchen Order Ticket generation, real-time KDS routing by preparation stations, and kitchen status sync.
- **Dine-In, Takeaway & Delivery**: Streamlined order type management supporting dine-in, express takeaway, online order dispatch, and rider tracking.
- **Recipe & Menu Engineering**: Dish variant management, modifier options, item additions, ingredient recipe costing, and automatic inventory deduction per order.

### 🛒 2. Retail POS & Smart Inventory Management
- **High-Speed Barcode Billing**: Rapid checkout terminal supporting barcode scanners, item shortcuts, wholesale/retail pricing, thermal receipt & A4 invoice printing.
- **Advanced Batch & Expiry Tracking**: Batch-wise stock accounting, serial number tracking, manufacturing/expiry dates, and FEFO/FIFO stock dispatch rules.
- **Purchase Orders & GRN**: Purchase order generation, Goods Receiving Notes (GRN), supplier price list comparison, stock return management, and vendor credit ledgers.
- **Multi-Outlet & Warehouse Sync**: Stock transfers between stores/warehouses, low-stock reorder triggers, automated stock adjustments, and live balance audits.

### 💼 3. Financial Accounting & Double-Entry Ledger
- **Complete Double-Entry System**: Chart of Accounts (Assets, Liabilities, Equity, Revenue, Expenses), automated journal posting from sales & purchases.
- **General Ledger & Vouchers**: Journal Vouchers (JV), Payment/Receipt Vouchers, Contra Vouchers, Daybook, and Cash/Bank book management.
- **Financial Statement Reporting**: Real-time Trial Balance, Profit & Loss (P&L) statements, Balance Sheet, GST/Tax breakdown, and financial year-end closing.
- **Debt Recovery & Credit Collections**: Customer credit tracking, aging analysis reports, automated recovery notifications, and payment collection logging.

### 👥 4. HR & Payroll Management (HRMS)
- **Employee Management**: Employee profiles, department mapping, role-based access control, designation tiers, and document records.
- **Attendance & Leave System**: Daily clock-in/out tracking, shift management, leave application workflows, and attendance summary logs.
- **Automated Payroll Processing**: Salary slip generation, base pay calculations, custom allowances/deductions, overtime, advances, and commission tracking.

### 📱 5. Multi-Application Ecosystem
- **Main POS Admin App (`lib/main.dart`)**: Complete administrative suite for managers, cashiers, accountants, and HR officers.
- **Delivery Rider App (`lib/main_rider.dart`)**: Dedicated mobile interface for delivery drivers to receive order dispatches, navigate routes, and collect payments.
- **Customer Self-Ordering App (`main_customer.dart`)**: Digital menu and ordering portal for customers at tables or for online ordering.
- **Supplier Portal (`main_supplier.dart`)**: Dedicated vendor dashboard to track purchase orders, pending deliveries, and invoice reconciliations.

### 💬 6. Automation, AI & Cloud Sync
- **WhatsApp Integration**: Automated instant billing receipts, invoices, order status alerts, and payment reminders via WhatsApp Webhooks.
- **Cloud & Offline Resilience**: Runs locally on Windows POS terminals with offline fallback, and synchronizes automatically with PostgreSQL cloud deployments.
- **Google Drive & Sheets Sync**: Automated database backups to Google Drive and continuous cloud reporting sync via Google Apps Script.
- **Night Audit Engine**: Automatic end-of-day reconciliation, cash drawer audit, and automated daily performance summary reporting.

---

## 🚀 Retailer Installation & Updates

For automated production deployments on Windows terminals:
* 📥 **[Download Backend Installer (v1.0.0.0)](https://github.com/studentsdav/RetailSale/releases/download/1.0.0.0/backend_Installer.exe)** - Run this **first time** on the main server to setup database, runtimes, and local configurations automatically.
* 📥 **[Download Update Installer (v1.0.0.0)](https://github.com/studentsdav/RetailSale/releases/download/1.0.0.0/Retailpos_Installer.exe)** - Run this to **update** existing terminals, or to install secondary billing clients on the network.

For step-by-step setup details, see the **[Retailer Installation & Update Guide](./Docs/Retailer-Installation-Guide.md)**.

---

## ☁️ Cloud Deployment & Environment Variables

Deploy the web application and backend seamlessly on [Render.com](https://render.com) or custom cloud hosting.
* 🌐 **[Web Deployment Guide (Local & Render Cloud)](./Docs/Web-Deployment-Guide.md)** - Step-by-step guide for local web testing and deploying the Web App + Backend on Render.com.
* ☁️ **[Render Cloud Deployment Guide](./Docs/Render-Cloud-Deployment-Guide.md)** - Complete backend environment variables and database reference.

### Environment Variables Reference Table

| Category | Environment Variable | Example Value | Description |
| :--- | :--- | :--- | :--- |
| **Database** | `DATABASE_URL` | `postgresql://user:pass@dpg-xyz.render.com/dbname` | PostgreSQL connection string (Triggers Cloud SaaS mode) |
| | `DB_SSL` | `true` | Required for SSL connection to Cloud PostgreSQL |
| **Authentication**| `JWT_SECRET` | `super-secret-jwt-key-2026-prod` | Secret key used to sign JWT tokens |
| **Email Provider Mode** | `EMAIL_PROVIDER` | `RESEND` | Provider mode: **`RESEND`** (Resend API), **`GMAIL`** (Gmail OAuth2), **`SMTP`** (SMTP only), or **`AUTO`** |
| **Resend API** | `RESEND_API_KEY` | `re_123456789abcdef` | HTTPS Resend API key for 0.1s instant OTP emails over Port 443 |
| | `EMAIL_FROM` | `"Retail POS" <noreply@famalth.com>` | Custom verified sender header name & email address |
| **Gmail OAuth2** | `GMAIL_CLIENT_ID` | `1234567-xyz.apps.googleusercontent.com` | Google Cloud OAuth2 Client ID |
| | `GMAIL_CLIENT_SECRET` | `GOCSPX-your_secret` | Google Cloud OAuth2 Client Secret |
| | `GMAIL_REFRESH_TOKEN` | `1//04_your_token` | Google OAuth2 Refresh Token |
| **SMTP Config** | `EMAIL_HOST` | `smtp.zoho.in` | SMTP Server Host (`smtp.zoho.in` / `smtp.gmail.com`) |
| | `EMAIL_PORT` | `587` | SMTP Port (`587` for STARTTLS, `465` for SSL) |
| | `EMAIL_SECURITY` | `STARTTLS` | Security Protocol: **`STARTTLS`** (587), **`SSL`** (465), or **`NONE`** (25) |
| | `EMAIL_SECURE` | `false` | Set `false` for Port 587 STARTTLS, `true` for Port 465 SSL |
| | `EMAIL_USER` | `famalth.retail@famalth.com` | SMTP / OAuth2 Sender Email Address |
| | `EMAIL_PASS` | `abcd1234efgh` | Zoho / Gmail 16-character App Password (for password auth) |
| | `EMAIL_TIMEOUT` | `20000` | Connection timeout in milliseconds (Default: 20000) |
| **Google Sync** | `ROOT_FOLDER_ID` | `1A2B3C4D5E6F7G8H` | Google Drive Root Folder ID for automated backups |
| | `SCRIPT_URL` | `https://script.google.com/macros/s/exec` | Google Apps Script Sync Endpoint URL |
| | `SHEET_ID` | `1XYZ2ABC3DEF4GHI` | Google Sheets Sync Database Spreadsheet ID |

---

## 📚 Documentation

- [Retailer Installation & Update Guide](./Docs/Retailer-Installation-Guide.md)
- [Render Cloud Deployment & Environment Guide](./Docs/Render-Cloud-Deployment-Guide.md)
- [Google Gmail OAuth2 Setup Guide](./Docs/Google-Gmail-OAuth2-Setup-Guide.md)
- [Own Server Online Deployment Guide](./Docs/Own-Server-Online-Deployment-Guide.md)
- [User Guide](./Docs/User-Guide.md)
- [Complete Help File](./Docs/Help-File.md)
- [Developer Guide](./Docs/Developer-Guide.md)
- [Init Setup Guide (Dev/Manual)](./Docs/Init-Setup.md)
- [Frontend Developer Guide](./Docs/Frontend-Guide.md)
- [Backend Developer Guide](./Docs/Backend-Guide.md)
- [Endpoint Reference](./Docs/Endpoint-Reference.md)

---

## ⚡ Quick Start

1. Install Flutter dependencies with `flutter pub get`.
2. Install backend dependencies with `cd backend && npm install`.
3. Start PostgreSQL and confirm backend configuration.
4. Run the backend with `cd backend && npm start`.
5. Run the Flutter app with `flutter run`.

## 🌐 Default API URL

The Flutter app reads its backend URL from `server_config.json`.

Default:

```text
http://127.0.0.1:3000
```

## 📁 Project Layout

- `lib/` - Flutter application (POS, Restaurant, Accounts, HRMS, Recovery)
  - `main.dart` - Main POS Admin application
  - `main_rider.dart` - Delivery Rider mobile application
  - `main_customer.dart` - Customer Self-Ordering portal
  - `main_supplier.dart` - Supplier & Vendor portal
- `backend/` - Node.js Express API server & PostgreSQL database modules
  - `routes/` - Module endpoints (restaurant, sales, inventory, accounting, hrms, etc.)
  - `controllers/` - Business logic controllers
- `Docs/` - User & Developer documentation guides
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` - Cross-platform build targets

---

## 📸 Screenshots

### Dashboard

![Retail Inventory Dashboard](./assets/Screenshot%202026-07-25%20204731.png)

### Sales Screen

![Sales Screen](./assets/Screenshot%202026-07-25%20204823.png)

### Stock Balance Report

![Stock Balance Report](./assets/Screenshot%202026-07-25%20204843.png)

### Finance & Expense Analytics

![Finance & Expense Analytics](./assets/Screenshot%202026-07-25%20204900.png)

### Brand Analysis

![Brand Analysis](./assets/Screenshot%202026-07-25%20204949.png)

---

## 🤝 Contributing

Please update the relevant guide when setup, runtime behavior, or APIs change.

