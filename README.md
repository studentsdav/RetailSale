# Enterprise Retail & Restaurant ERP & POS System

A comprehensive, production-ready ERP and Multi-Module POS solution built with a cross-platform **Flutter** client and high-performance **Node.js / PostgreSQL** backend. Designed for hybrid retail stores, restaurants, multi-branch operations, and enterprise inventory management.

---

> [!NOTE]
> This repository is actively maintained and sponsored by **Famalth Technologies** ([www.famalth.com](https://www.famalth.com)).

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
| | `DB_HOST` | `localhost` | PostgreSQL host (Used when `DATABASE_URL` is omitted) |
| | `DB_PORT` | `5432` | PostgreSQL port |
| | `DB_USER` | `postgres` | PostgreSQL username |
| | `DB_PASSWORD` | `postgres` | PostgreSQL password |
| | `DB_NAME` | `retailsale_db` | PostgreSQL database name |
| | `DB_SSL` | `true` | Required for SSL connection to Cloud PostgreSQL (Render, Neon, RDS) |
| **Redis Cache & Performance** | `REDIS_URL` | `rediss://default:password@redis-host:6379` | Redis connection URL for distributed caching, rate-limiting & session store |
| | `REDIS_HOST` | `redis-host` | Redis host (Fallback if `REDIS_URL` is not provided) |
| **Cloud Object Storage (S3 / R2)** | `S3_BUCKET` *(or `R2_BUCKET`)* | `retail-backups-bucket` | Cloud storage bucket name for direct database backup archives & large media (>50MB) |
| | `S3_ENDPOINT` *(or `R2_ENDPOINT`)* | `https://<account_id>.r2.cloudflarestorage.com` | Custom S3/R2 Endpoint URL (Cloudflare R2, MinIO, GCP Storage, AWS) |
| | `S3_REGION` *(or `AWS_REGION`)* | `auto` / `us-east-1` / `ap-south-1` | S3 / R2 storage bucket region |
| | `S3_ACCESS_KEY_ID` | `AKIAIOSFODNN7EXAMPLE` | S3 / Cloudflare R2 / MinIO Access Key ID |
| | `S3_SECRET_ACCESS_KEY` | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | S3 / Cloudflare R2 / MinIO Secret Access Key |
| **Authentication & Security** | `JWT_SECRET` | `super-secret-jwt-key-2026-prod` | Secret key used to sign and verify user JWT authentication tokens |
| | `ENCRYPTION_SECRET` | `aes-256-gcm-secret-key-32-chars!` | Encryption key for securing sensitive store credentials & WhatsApp tokens in DB |
| | `BACKUP_SECRET` | `enterprise-backup-encryption-key-123` | Passphrase used to encrypt automated database backup zip archives |
| **Email Provider Mode** | `EMAIL_PROVIDER` | `RESEND` | Provider mode: **`RESEND`** (Resend API), **`GMAIL`** (Gmail OAuth2), **`SMTP`** (SMTP only), or **`AUTO`** |
| **Resend API** | `RESEND_API_KEY` | `re_123456789abcdef` | HTTPS Resend API key for 0.1s instant OTP emails over Port 443 |
| | `EMAIL_FROM` | `"Retail POS" <help@famalth.com>` | Custom verified sender header name & email address |
| **Gmail OAuth2** | `GMAIL_CLIENT_ID` | `1234567-xyz.apps.googleusercontent.com` | Google Cloud OAuth2 Client ID |
| | `GMAIL_CLIENT_SECRET` | `GOCSPX-your_secret` | Google Cloud OAuth2 Client Secret |
| | `GMAIL_REFRESH_TOKEN` | `1//04_your_token` | Google OAuth2 Refresh Token |
| **SMTP Config** | `EMAIL_HOST` | `smtp.zoho.in` | SMTP Server Host (`smtp.zoho.in` / `smtp.gmail.com`) |
| | `EMAIL_PORT` | `587` | SMTP Port (`587` for STARTTLS, `465` for SSL) |
| | `EMAIL_SECURITY` | `STARTTLS` | Security Protocol: **`STARTTLS`** (587), **`SSL`** (465), or **`NONE`** (25) |
| | `EMAIL_SECURE` | `false` | Set `false` for Port 587 STARTTLS, `true` for Port 465 SSL |
| | `EMAIL_USER` | `help@famalth.com` | SMTP / OAuth2 Sender Email Address |
| | `EMAIL_PASS` | `abcd1234efgh` | Zoho / Gmail 16-character App Password (for password auth) |
| | `EMAIL_TIMEOUT` | `20000` | Connection timeout in milliseconds (Default: 20000) |
| **Google Sync** | `ROOT_FOLDER_ID` | `1A2B3C4D5E6F7G8H` | Google Drive Root Folder ID for automated backups |
| | `SCRIPT_URL` | `https://script.google.com/macros/s/exec` | Google Apps Script Sync Endpoint URL |
| | `SHEET_ID` | `1XYZ2ABC3DEF4GHI` | Google Sheets Sync Database Spreadsheet ID |
| **Server & Cloud** | `PORT` | `3000` | HTTP port for the Express API backend |
| | `NODE_ENV` | `production` | Environment mode (`development` or `production`) |
| | `IS_CLOUD` | `true` | Explicitly declares cloud deployment environment |

> [!NOTE]
> **Global Multi-Tenant Design**: Business-level settings (AI API keys, WhatsApp country rates, currency formats, multi-tax matrices, and local timezones) are configured dynamically inside the application and stored per outlet in the database, requiring no manual environment variable maintenance.

---

## 📚 Complete Documentation Suite

> 🌟 **[Browse the Full Master Wiki (WIKI.md)](./WIKI.md)** — Complete searchable documentation portal covering every architecture diagram, API, user walkthrough, and data model.

### 👤 Store User & Operator Guides (No Coding Required)
- 🚀 **[1-Click Cloud & Offline Store Migration](./Docs/User-Guide-1Click-Cloud-Migration.md)** — Bi-directional sync, store cloning & backup restore
- ⚡ **[Fast Staff Login & PIN Access](./Docs/User-Guide-Fast-Login-And-PIN-Access.md)** — Dropdown quick-login, 4-digit staff PIN & preloading speedup
- 👤 **[Staff PIN Configuration & Mobile Login](./Docs/User-Guide-Staff-PIN-And-Quick-Login.md)** — Setting user PINs & mobile-friendly auth
- 🍽️ **[Captain Console & Floor Table Management](./Docs/User-Guide-Captain-Console-Table-Management.md)** — Multi-client split bills, waiter table assignment & Excel import
- 📱 **[Contactless QR Table Ordering](./Docs/User-Guide-QR-Table-Ordering.md)** — Self-ordering standees, tent cards & digital dining
- 🍳 **[Restaurant & Hospitality Operations](./Docs/User-Guide-Restaurant-And-Hospitality.md)** — Visual floor plan, KDS kitchen display & table transfers
- 🧭 **[System Navigation & Clean Menu Structure](./Docs/User-Guide-Navigation-And-Menu-Structure.md)** — Deduplicated operations menu & role-specific drawer views
- 💼 **[Vendor Purchasing & Supplier Payments](./Docs/User-Guide-Vendor-Purchase-And-Payments.md)** — International vendors, opening balance COA sync, VAT rounding & custom payments
- 📦 **[Stock Taking, Modifiers & GRN Verification](./Docs/User-Guide-Stock-Taking-Modifiers-And-GRN-Verification.md)** — Physical count audit, extra cheese recipes, dietary flags & manual GRN receiving
- 🛒 **[POS Operations & Inventory Management](./Docs/User-Guide-POS-Operations-And-Inventory.md)** — High-speed billing, barcode manager, damage write-offs & stock transfers
- 🏭 **[Manufacturing & BOM Assembly](./Docs/User-Guide-Manufacturing-BOM-And-Assembly.md)** — Recipe configurations, finished goods production & component deductions
- 💰 **[Accounting, COA & Financial Ledgers](./Docs/User-Guide-Accounting-And-Financial-Ledger.md)** — Double-entry vouchers, bank reconciliation, loans/EMI & P&L statements
- 👥 **[HRMS & Staff Payroll Management](./Docs/User-Guide-HRMS-And-Payroll.md)** — Daily attendance punch, shifts, salary structures & automated payslips
- 🎁 **[Promotions, Loyalty & Lucky Draw](./Docs/User-Guide-Promotions-Loyalty-And-LuckyDraw.md)** — Happy hours, bill-value promos, tiered reward points & raffle draws
- 🖨️ **[A5 Invoice & Thermal Template Designer](./Docs/User-Guide-A5-Invoice-And-Template-Designer.md)** — Customizing A5 laser, 80mm & 58mm receipt layouts
- 🌐 **[Auto-Tax Seeding & Tax Integrity](./Docs/User-Guide-Auto-Tax-Seeding-And-Tax-Integrity.md)** — Country tax rules (GST/VAT/Sales Tax) & safe tax replacement
- 🔀 **[Dynamic Workstation Console Routing](./Docs/User-Guide-Dynamic-Console-Routing.md)** — Dispatching orders across Captain, Retailer, and Rider portals
- 🛍️ **[B2B Wholesale Marketplace & Vendor Portal](./Docs/User-Guide-B2B-Marketplace-And-Vendor.md)** — Vendor catalog publishing, direct PO carts & trade directory
- 💬 **[B2B Community Hub & Direct Trade Chat](./Docs/User-Guide-B2B-Community-And-Chat.md)** — Merchant-to-vendor messaging & industry group channels
- 🤖 **[Famalth Lynx AI Assistant & Voice Search](./Docs/User-Guide-Lynx-AI-Assistant.md)** — Natural language store querying & conversational PO drafting
- 📝 **[POS Sticky Notes & Shift Checklists](./Docs/User-Guide-Sticky-Notes.md)** — Pinnable color-coded shift reminders & scratchpads
- 🌍 **[Currency Formats & Tax Matrix](./Docs/User-Guide-Currency-And-Taxes.md)** — Multi-currency formatting & rate management
- ☁️ **[Cloud Features & Server Configuration](./Docs/User-Guide-Cloud-Features-And-Server-Config.md)** — Online hosting URLs, outlet verification & gateway setup
- 🛡️ **[Security, Anti-Hacker & Data Protection](./Docs/User-Guide-Security-And-Data-Protection.md)** — Master recovery PIN, auto-reinstall & disaster recovery
- 📱 **[M-Pesa & Mobile Money Integration](./Docs/User-Guide-Mpesa-Mobile-Money.md)** — Safaricom Daraja STK push configuration & instant checkout reconciliation
- 🏢 **[Multi-Outlet & Warehouse Hierarchy](./Docs/User-Guide-Multi-Outlet-And-Warehouse-Hierarchy.md)** — Central warehouse distribution, branch linking & shelf location bins
- 📊 **[Reports & Business Intelligence Suite](./Docs/User-Guide-Reports-And-Business-Intelligence.md)** — Generating and exporting 26+ financial, stock, and sales analytics
- ❓ **[Complete Store Operations FAQ](./Docs/User-Guide-FAQ.md)** — Frequently asked cashier and manager troubleshooting questions
- 📖 **[Master User Guide & Workflow Index](./Docs/User-Guide.md)** — Universal operational documentation hub

---

### 🛠️ Developer & Technical Architecture Guides
- 📋 **[Master Feature & Documentation Coverage Matrix](./Docs/Feature-Coverage-Checklist.md)** — 100% verified UI & backend feature audit
- 📜 **[System Architecture Upgrades & Changelog (Sept–Oct 2026)](./Docs/System-Architecture-And-Changelog.md)** — Architectural evolution timeline & core invariants
- 📡 **[Master REST API Endpoint Reference](./Docs/Endpoint-Reference.md)** — Comprehensive specification of all 38 backend route modules
- ⚡ **[Fast Login, PIN Authentication & Preloading Architecture](./Docs/Developer-Guide-Fast-Login-And-Preloading.md)** — Benchmark speedups & parallel cache warming
- 👤 **[Staff PIN Security & Dynamic Dropdown Architecture](./Docs/Developer-Guide-Staff-PIN-And-Quick-Login.md)** — Multi-user collision resolution & JWT scoping
- 🍽️ **[Captain Console & Floor Management Architecture](./Docs/Developer-Guide-Captain-Console-Table-Management.md)** — Multi-client split sessions, waiter binding & Excel parser
- 📱 **[QR Contactless Ordering & Real-Time Dining Architecture](./Docs/Developer-Guide-QR-Table-Ordering.md)** — Geometry print engine, customer web app & atomic KOT stream
- 🍳 **[Restaurant & Hospitality Technical Architecture](./Docs/Developer-Guide-Restaurant-Hospitality.md)** — Table state machine, KDS live pipeline & billing settlement
- 🧭 **[Navigation Hierarchy, Menu Layout & Deduplication](./Docs/Developer-Guide-Menu-Layout-And-Deduplication.md)** — Module filtering & route consolidation
- 💼 **[Vendor Lifecycle, Purchase Engine & COA Integration](./Docs/Developer-Guide-Vendor-Purchase-And-COA-Integration.md)** — Opening balance vouchers, VAT integer rounding & payment methods
- 📦 **[Stock Taking, Modifier Recipes & GRN Verification](./Docs/Developer-Guide-Stock-Taking-Modifiers-And-GRN-Verification.md)** — Variance journals, raw stock deductions & manual GRN doctrine
- 🛒 **[POS Engine, Inventory State Machine & BOM Manufacturing](./Docs/Developer-Guide-POS-Inventory-Manufacturing.md)** — Atomic stock deduction & assembly algorithms
- 💰 **[Financial Accounting, COA & Double-Entry Ledger Architecture](./Docs/Developer-Guide-Accounting-Finance.md)** — Voucher invariants, amortization & balance sheet generation
- 👥 **[HRMS, Shift Scheduling & Payroll Processing Engine](./Docs/Developer-Guide-HRMS-Payroll.md)** — Punch calculation logic, tax deductions & payslip generator
- 🤖 **[AI Framework, Autonomous Background Agents & Lynx](./Docs/Developer-Guide-AI-Autonomous-Agents.md)** — Autonomous agent loop, LLM tool definitions & upsell model
- 🧩 **[Plugins, Workflows & WhatsApp Queue Architecture](./Docs/Developer-Guide-Plugins-Workflows-Automation.md)** — Sandbox plugin runtime, webhooks & adaptive backoff queue
- 🖨️ **[A5 Invoice Rendering Pipeline & Template Schema](./Docs/Developer-Guide-A5-Invoice-And-Template-Designer.md)** — Vector PDF generation & JSON block layout engine
- 🌐 **[Auto-Tax Seeding & Tax Integrity Engine](./Docs/Developer-Guide-Auto-Tax-Seeding-And-Tax-Integrity.md)** — Country tax presets & relational integrity safety
- 🔀 **[Dynamic Workstation Console Routing Architecture](./Docs/Developer-Guide-Dynamic-Console-Routing.md)** — Dispatch channels for Captain, Retailer, and Rider consoles
- 🛡️ **[Security, Anti-DDoS, Rate Limiting & Load Balancer Guide](./Docs/Developer-Security-Cache-LoadBalancer-Guide.md)** — Redis rate-limiting, token buckets & intrusion detection
- 📱 **[M-Pesa Mobile Money Integration Architecture](./Docs/Developer-Guide-Mpesa-Mobile-Money.md)** — Safaricom Daraja STK push lifecycle, OAuth token caching & webhooks
- 🏢 **[Multi-Outlet Hierarchy & Scoping Architecture](./Docs/Developer-Guide-Multi-Outlet-Hierarchy.md)** — Multi-tenant database routing, warehouse trees & numbering settings
- 📊 **[Reports, Analytics & BI Engine Architecture](./Docs/Developer-Guide-Reports-And-Analytics.md)** — SQL aggregations, Redis cache warming & vector PDF generation
- 🚀 **[1-Click Relational Store Migration Architecture](./Docs/One-Click-Cloud-Migration-Guide.md)** — Relational ID translation engine & sequence re-alignment
- 🛍️ **[B2B Wholesale Marketplace & Community Chat Architecture](./Docs/B2B-Marketplace-And-Community-Guide.md)** — Real-time chat, vendor publishing & direct PO integration
- 🤖 **[Lynx AI, Sticky Notes & Currency Engine Architecture](./Docs/Lynx-AI-StickyNotes-Currency-Tax-Guide.md)** — Storage schemas, sync routines & AI natural language parser
- 💻 **[Backend Core Developer Guide](./Docs/Backend-Guide.md)** & **[Frontend Developer Guide](./Docs/Frontend-Guide.md)** — Architecture overviews & component standards
- 🖥️ **[Retailer Installation & Update Installer Guide](./Docs/Retailer-Installation-Guide.md)** & **[Windows Inno Setup Guide](./Docs/Windows-Installer-Developer-Guide.md)**
- ☁️ **[Render Cloud Deployment Guide](./Docs/Render-Cloud-Deployment-Guide.md)**, **[Web Deployment Guide](./Docs/Web-Deployment-Guide.md)** & **[Own Server Guide](./Docs/Own-Server-Online-Deployment-Guide.md)**
- ✉️ **[Google Gmail OAuth2 Setup Guide](./Docs/Google-Gmail-OAuth2-Setup-Guide.md)** & **[Settings Master Guide](./Docs/Settings-Guide.md)**
- 📘 **[Complete Help File & Feature Directory](./Docs/Help-File.md)**

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

## 🤝 Contributing & Open Source Community

We welcome open-source contributions from developers of all skill levels!

- 📖 **[Contributor Guidelines](./CONTRIBUTING.md)** - Workflow rules, local setup, coding standards, and PR guidelines.
- 🤝 **[Code of Conduct](./CODE_OF_CONDUCT.md)** - Community pledge and standards (Contributor Covenant v2.1).
- 🔒 **[Security Policy](./SECURITY.md)** - Responsible disclosure instructions for security vulnerabilities.
- 🐛 **[Report a Bug](.github/ISSUE_TEMPLATE/bug_report.md)** - Open a structured bug report.
- ✨ **[Request a Feature](.github/ISSUE_TEMPLATE/feature_request.md)** - Suggest new features or ERP workflow improvements.

### 🏷️ Community Task Labels

Look for the following labels when looking for tasks to work on:
* `good first issue`: Ideal for new contributors (localization, minor UI fixes, tooltips).
* `help wanted`: Features or fixes where maintainers are seeking community assistance.
* `bug`: Reported bugs requiring fixes.
* `enhancement`: Feature enhancements and UI/UX improvements.
* `documentation`: Docs updates and guide improvements.


