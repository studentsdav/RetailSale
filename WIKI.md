# 📖 RetailPOS ERP & POS Suite — Master Documentation Wiki

Welcome to the **RetailPOS ERP & POS Suite Master Wiki**. This wiki serves as the central documentation portal for store owners, cashiers, kitchen staff, accountants, system administrators, and software engineers.

---

## 🧭 Master Wiki Table of Contents

```mermaid
mindmap
  root((RetailPOS Wiki))
    Architecture & Tech
      System Architecture & Changelog
      Feature Coverage Matrix
      Master REST API Reference
      Backend & Frontend Guides
      Security & Rate Limiting
    Hospitality & Dining
      Captain Console & Floor Tables
      Contactless QR Ordering
      KDS & KOT Pipeline
      Restaurant & Hospitality Guide
    Retail, Stock & Procurement
      Enterprise POS Billing
      Stock Taking & Cycle Count
      Item Modifiers & Recipes
      Purchase Orders & Manual GRN
      Vendor & COA Sync
    Accounting & HRMS
      Chart of Accounts & Vouchers
      Bank Reconciliation & Loans
      HRMS Directory & Shifts
      Monthly Payroll & Payslips
    Cloud, AI & Automation
      1-Click Cloud Migration
      Lynx AI Assistant
      WhatsApp Queue & Automation
      Dynamic Console Routing
      A5 & Thermal Template Designer
```

---

## 1. 🚀 Quick Start, Deployment & Infrastructure

| Document | Audience | Purpose | Link |
| :--- | :--- | :--- | :--- |
| **System Overview & Readme** | Everyone | Project introduction, stack overview, screenshots & quick setup | [README.md](../README.md) |
| **Retailer Installation Guide** | Store Owners | Automated Windows installation for backend & billing clients | [`docs/Retailer-Installation-Guide.md`](./docs/Retailer-Installation-Guide.md) |
| **Windows Installer Dev Guide** | Engineers | Building production Inno Setup exe installers | [`docs/Windows-Installer-Developer-Guide.md`](./docs/Windows-Installer-Developer-Guide.md) |
| **Web Deployment Guide** | SysAdmins | Compiling Flutter web and hosting on Node.js/Render | [`docs/Web-Deployment-Guide.md`](./docs/Web-Deployment-Guide.md) |
| **Render Cloud Deployment** | DevOps | Deploying PostgreSQL and backend services on Render.com | [`docs/Render-Cloud-Deployment-Guide.md`](./docs/Render-Cloud-Deployment-Guide.md) |
| **Own Server Deployment** | DevOps | Self-hosting on private VPS (Ubuntu/Debian/Windows Server) | [`docs/Own-Server-Online-Deployment-Guide.md`](./docs/Own-Server-Online-Deployment-Guide.md) |
| **Google Gmail OAuth2 Setup** | Admins | Setting up OAuth2 credentials for secure OTP/bill emailing | [`docs/Google-Gmail-OAuth2-Setup-Guide.md`](./docs/Google-Gmail-OAuth2-Setup-Guide.md) |
| **Settings & Config Guide** | Admins | Configuration options and multi-tenant parameters | [`docs/Settings-Guide.md`](./docs/Settings-Guide.md) |

---

## 2. 👤 Store Operator & Cashier Guides (No Coding Required)

Step-by-step illustrated workflows written for store operators, cashiers, restaurant captains, and inventory managers.

### 🔐 Authentication, Navigation & Fast Login
- ⚡ **[Fast Staff Login & PIN Access User Guide](./docs/User-Guide-Fast-Login-And-PIN-Access.md)**: Dropdown quick-login, 4-digit staff PIN, and rapid post-login preloading.
- 👤 **[Staff PIN Configuration & Mobile Login](./docs/User-Guide-Staff-PIN-And-Quick-Login.md)**: Enabling quick login in User Management and setting personal staff PINs.
- 🧭 **[System Navigation & Clean Menu Structure](./docs/User-Guide-Navigation-And-Menu-Structure.md)**: Cleaned-up left sidebar, deduplicated Operations menu, and role-based permissions.

### 🍽️ Restaurant, Dining & Floor Management
- 🍽️ **[Captain Console & Floor Table Management User Guide](./docs/User-Guide-Captain-Console-Table-Management.md)**: Multi-client separate table orders, assigning tables to waiters, and bulk Excel table import.
- 📱 **[Contactless QR Table Ordering User Guide](./docs/User-Guide-QR-Table-Ordering.md)**: Printing table standees, tent cards, and managing incoming digital orders.
- 🍳 **[Restaurant & Hospitality Operations Guide](./docs/User-Guide-Restaurant-And-Hospitality.md)**: Visual floor plan, KDS kitchen screens, course management, and bill splitting.

### 🛒 Retail POS, Procurement & Inventory
- 🛒 **[POS Operations & Inventory Management Guide](./docs/User-Guide-POS-Operations-And-Inventory.md)**: High-speed barcode scanning, holding carts, receipt printing, and transfers.
- 📦 **[Stock Taking, Modifiers & GRN Verification User Guide](./docs/User-Guide-Stock-Taking-Modifiers-And-GRN-Verification.md)**: Cycle counts, extra cheese add-ons, dietary tags, and strictly manual GRN verification.
- 💼 **[Vendor Purchasing & Supplier Payments User Guide](./docs/User-Guide-Vendor-Purchase-And-Payments.md)**: International vendors (optional state), opening balance COA sync, VAT rounding & custom payment methods.
- 🏭 **[Manufacturing BOM & Product Assembly User Guide](./docs/User-Guide-Manufacturing-BOM-And-Assembly.md)**: Bill of Materials recipes, raw material consumption, and batch packaging.

### 💰 Accounting, HRMS & Promotions
- 💰 **[Accounting & Financial Ledger User Guide](./docs/User-Guide-Accounting-And-Financial-Ledger.md)**: Double-entry vouchers (JV, PV, RV, CV), bank reconciliation, and balance sheets.
- 👥 **[HRMS & Staff Payroll User Guide](./docs/User-Guide-HRMS-And-Payroll.md)**: Employee profiles, daily attendance punch, overtime, shift setups, and monthly payslips.
- 🎁 **[Promotions, Loyalty & Lucky Draw User Guide](./docs/User-Guide-Promotions-Loyalty-And-LuckyDraw.md)**: Happy hour rules, bill-value promotions, loyalty point rules, and raffle campaigns.

### 🖨️ Invoicing, Tax & Workstations
- 🖨️ **[A5 Invoice & Template Designer User Guide](./docs/User-Guide-A5-Invoice-And-Template-Designer.md)**: Half-page A5 invoice printing, thermal receipts, and header/footer customization.
- 🌐 **[Auto-Tax Seeding & Regional Tax Integrity](./docs/User-Guide-Auto-Tax-Seeding-And-Tax-Integrity.md)**: International tax setups (GST, VAT, Sales Tax) and safe tax group replacement.
- 🔀 **[Dynamic Workstation Console Routing Guide](./docs/User-Guide-Dynamic-Console-Routing.md)**: Directing orders to Captain, Retailer, and Rider consoles.

### 🤖 AI, B2B Trade & Cloud
- 🤖 **[Famalth Lynx AI Assistant User Guide](./docs/User-Guide-Lynx-AI-Assistant.md)**: Natural language store insights, voice queries, and automatic PO draft creation.
- 📝 **[POS Sticky Notes & Shift Scratchpad](./docs/User-Guide-Sticky-Notes.md)**: Color-coded shift checklists and pinned store reminders.
- 🛍️ **[B2B Marketplace & Vendor Portal User Guide](./docs/User-Guide-B2B-Marketplace-And-Vendor.md)**: Supplier discovery, B2B wholesale orders, and catalog publishing.
- 💬 **[B2B Community Hub & Trade Chat User Guide](./docs/User-Guide-B2B-Community-And-Chat.md)**: Direct trade messaging and group channels.
- 🚀 **[1-Click Cloud Migration User Guide](./docs/User-Guide-1Click-Cloud-Migration.md)**: 2-way offline-to-online and online-to-offline store cloning.
- ☁️ **[Cloud Features & Server Config User Guide](./docs/User-Guide-Cloud-Features-And-Server-Config.md)**: Configuring VPS and verifying cloud licenses.
- 🛡️ **[Security & Disaster Recovery User Guide](./docs/User-Guide-Security-And-Data-Protection.md)**: Master PIN recovery and database backups.
- ❓ **[Complete Store Operations FAQ](./docs/User-Guide-FAQ.md)**: Universal troubleshooting manual.

---

## 3. 🛠️ Developer & Technical Architecture Guides

In-depth technical references featuring data models, state machines, Sequence Diagrams, and core system invariants.

```mermaid
sequenceDiagram
    autonumber
    actor Staff as Cashier / Waiter
    participant Client as Flutter Client
    participant API as Node.js Gateway
    participant Cache as Redis Cache
    participant DB as PostgreSQL DB
    participant Printer as Hardware Thermal / A5

    Staff->>Client: PIN Login / Select User
    Client->>API: POST /api/auth/pin-login {outlet_id, username, pin}
    API->>DB: Query user by outlet & username
    DB-->>API: User record + hashed PIN
    API-->>Client: JWT Token + Permissions
    
    par Parallel Preloading
        Client->>API: GET /api/settings/taxes
        Client->>API: GET /api/payment-methods
        Client->>API: GET /api/inventory/categories
    end
    
    Staff->>Client: Place Order / Add Modifiers (Extra Cheese)
    Client->>API: POST /api/sales or /api/restaurant/kots
    API->>DB: Atomic Transaction: Commit Sale + Deduct Stock + COA Journal
    DB-->>API: Success
    API-->>Client: Bill / KOT Payload
    Client->>Printer: Render Vector PDF / ESC-POS Thermal
```

### Core Architecture Reference Documents:
- 📋 **[Master Feature & Documentation Coverage Matrix](./docs/Feature-Coverage-Checklist.md)**: Comprehensive 100% audit of all 85+ screens and 38 backend routes.
- 📜 **[System Architecture Upgrades & Changelog (Sept–Oct 2026)](./docs/System-Architecture-And-Changelog.md)**: Technical timeline of major refactors, cloud migrations, and optimizations.
- 📡 **[Master REST API Endpoint Reference](./docs/Endpoint-Reference.md)**: Complete parameter, header, and response schema definitions for all backend endpoints.
- ⚡ **[Fast Login & Preloading Architecture Guide](./docs/Developer-Guide-Fast-Login-And-Preloading.md)**: Parallel cache warming, asynchronous startup, and benchmark optimizations.
- 👤 **[Staff PIN & Quick Login Architecture Guide](./docs/Developer-Guide-Staff-PIN-And-Quick-Login.md)**: Multi-user PIN collision handling and outlet-scoped authentication.
- 🍽️ **[Captain Console & Table Management Architecture](./docs/Developer-Guide-Captain-Console-Table-Management.md)**: Multi-client table session schemas, waiter bindings, and Excel parser algorithms.
- 📱 **[QR Table Ordering & Digital Dining Architecture](./docs/Developer-Guide-QR-Table-Ordering.md)**: Vector QR geometry designer, public ordering gateway, and real-time KDS dispatch.
- 🍳 **[Restaurant & Hospitality Technical Architecture](./docs/Developer-Guide-Restaurant-Hospitality.md)**: Floor state machines, KOT item lifecycle, and bill merging algorithms.
- 🧭 **[Navigation Hierarchy & Menu Deduplication Architecture](./docs/Developer-Guide-Menu-Layout-And-Deduplication.md)**: Dynamic drawer filtering and route deduplication protocols.
- 💼 **[Vendor Lifecycle, Purchase Engine & COA Integration](./docs/Developer-Guide-Vendor-Purchase-And-COA-Integration.md)**: Opening balance double-entry automation, VAT integer rounding, and payment method COA mappings.
- 📦 **[Stock Taking, Modifier Recipes & GRN Verification Architecture](./docs/Developer-Guide-Stock-Taking-Modifiers-And-GRN-Verification.md)**: Variance audit journals, raw material deductions, and operator-only manual GRN doctrine.
- 🛒 **[POS Engine, Inventory State Machine & BOM Manufacturing](./docs/Developer-Guide-POS-Inventory-Manufacturing.md)**: Concurrency-safe stock ledger, barcode generation, and assembly production.
- 💰 **[Financial Accounting, COA & Double-Entry Ledger](./docs/Developer-Guide-Accounting-Finance.md)**: Balanced voucher validation, amortized loan calculations, and real-time financial reporting.
- 👥 **[HRMS, Shift Scheduling & Payroll Processing Engine](./docs/Developer-Guide-HRMS-Payroll.md)**: Biometric punch algorithms, shift rules, overtime tiers, and payslip calculation.
- 🤖 **[AI Framework, Autonomous Background Agents & Lynx](./docs/Developer-Guide-AI-Autonomous-Agents.md)**: Autonomous agent loops, tool declarations, and recommendation engines.
- 🧩 **[Plugins, Workflows & WhatsApp Queue Architecture](./docs/Developer-Guide-Plugins-Workflows-Automation.md)**: Event hooks, isolated VM sandbox runtimes, and WhatsApp queue worker with adaptive backoff.
- 🖨️ **[A5 Invoice Rendering Pipeline & Template Schema](./docs/Developer-Guide-A5-Invoice-And-Template-Designer.md)**: JSON template schema, vector PDF generation, and thermal ESC/POS commands.
- 🌐 **[Auto-Tax Seeding & Tax Integrity Engine](./docs/Developer-Guide-Auto-Tax-Seeding-And-Tax-Integrity.md)**: Country-specific seeders and relational foreign key replacement guards.
- 🔀 **[Dynamic Workstation Console Routing Architecture](./docs/Developer-Guide-Dynamic-Console-Routing.md)**: Multi-workstation message routing and event dispatching.
- 🛡️ **[Developer Security, Anti-DDoS, Rate Limiting & Load Balancer Guide](./docs/Developer-Security-Cache-LoadBalancer-Guide.md)**: Redis sliding-window limiters, token buckets, and cryptographic storage.
- 🚀 **[1-Click Relational Store Migration Architecture](./docs/One-Click-Cloud-Migration-Guide.md)**: In-memory relational ID translation engine and sequence re-alignment.
- 🛍️ **[B2B Wholesale Marketplace & Community Chat Architecture](./docs/B2B-Marketplace-And-Community-Guide.md)**: WebSocket chat protocols, vendor discovery, and direct PO translation.
- 🤖 **[Lynx AI, Sticky Notes & Currency Engine Architecture](./docs/Lynx-AI-StickyNotes-Currency-Tax-Guide.md)**: Natural language parser, draggable sticky notes model, and multi-currency exchange matrix.
- 💻 **[Backend Developer Guide](./docs/Backend-Guide.md)** & **[Frontend Developer Guide](./docs/Frontend-Guide.md)**: Codebase layout, styling conventions, and controller standards.

---

## 4. 🌐 Web Application & Public Portals

- **Web Release Output**: `backend/public/`
- **Customer Self-Ordering Portal**: `http://<server-ip>:3000/#/dining?outlet_id=1&table_id=5`
- **Delivery Rider Portal**: `http://<server-ip>:3000/#/rider`
- **Retailer Operations Console**: `http://<server-ip>:3000/#/retailer`

---

## 5. 🤝 Contributing & Community Standards

- **[Contributing Guidelines](../CONTRIBUTING.md)**: Git branching model, pull request guidelines, and TypeScript/Flutter formatting rules.
- **[Code of Conduct](../CODE_OF_CONDUCT.md)**: Community standards and participant expectations.
- **[Security Policy](../SECURITY.md)**: Responsible vulnerability disclosure process.

---

*Wiki Maintained by Famalth Technologies Engineering Team. Last Updated: October 2026.*
