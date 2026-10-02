# 💻 Master Developer Guide

This document is the **comprehensive technical architecture, development, build, and deployment manual** for the complete enterprise Retail & Hospitality Management System.

---

## 🏛️ System Architecture Overview

The system is engineered as a modern, high-performance, multi-tenant POS, ERP, and Hospitality suite consisting of:

```text
Enterprise Architecture
├── 📱 Client Tier (Flutter Desktop / Web / Mobile in `lib/`)
│   ├── State Management: Provider + ChangeNotifiers
│   ├── Network & Cache: HTTP Client + Local SQLite / SharedPreferences
│   ├── Printing Engine: ESC/POS Thermal 80mm/58mm + PDF Vector Engine
│   └── UI Layer: Responsive Adaptive Layout (Desktop, Tablet, Mobile)
│
├── ⚙️ Backend API Tier (Node.js + Express + TypeScript in `backend/`)
│   ├── Middleware Stack: Auth, License, Rate Limiter, Security, Idempotency, Timezone
│   ├── Background Engine: BullMQ Redis Queue, Node-Cron, Distributed Locks
│   ├── Extensibility: Plugin Sandboxing (VM2), Webhooks, Automation Engine
│   └── AI & ML: Famalth Lynx AI Tool Calling, Association Rules Upselling
│
└── 🗄️ Persistence Tier
    ├── Relational Database: PostgreSQL 14+ via Sequelize ORM
    ├── Encryption & Licensing: AES-256-GCM Config Encryption & RSA License Keys
    └── File Storage: Local Assets, Uploads, and Cloud Migration Snapshots
```

---

## 🛠️ Prerequisites & Developer Setup

### 1. Toolchain Requirements
- **Flutter SDK**: `>= 3.4.0` (Supports Windows Desktop, Web, Android, iOS)
- **Dart SDK**: Compatible with Flutter toolchain
- **Node.js**: `18.x` or `20.x LTS`
- **npm**: `9.x+`
- **PostgreSQL**: `14.x` or higher
- **Git**: `2.x+`

### 2. Initial Setup Step-by-Step

#### Step 1: Clone Repository
```bash
git clone <repository_url>
cd RetailSale
```

#### Step 2: Setup Backend Dependencies & Environment
```bash
cd backend
npm install
```

Ensure the runtime license and encryption configuration files are present:
- `backend/license.key`
- `backend/config.enc`
- `backend/sysConfig.enc`
- `backend/client.json`

#### Step 3: Start PostgreSQL & Run Database Migrations
Start your local or cloud PostgreSQL instance:
```bash
# In backend directory
npm run migrate
```

#### Step 4: Start the Backend Development Server
```bash
# In backend directory
npm start
```
The server binds to port `3000` by default (configurable via environment or encrypted config).

#### Step 5: Setup & Run Flutter Client
```bash
# In project root
flutter pub get
flutter run -d windows    # Or -d chrome for web, -d <android-device> for mobile
```

---

## 📂 Project Directory Structure

```text
RetailSale/
├── backend/                               # Node.js + Express + TypeScript Backend
│   ├── config/                            # Database & security configurations
│   ├── controllers/                       # REST endpoint business logic
│   │   ├── finance/                       # Accounting, COA, Loans, Vouchers
│   │   ├── hrms/                          # HRMS, Attendance, Payroll
│   │   ├── restaurant/                    # Tables, Floors, KOTs, KDS, Delivery
│   │   ├── sales/                         # Sales, POS, Lucky Draw, Subscriptions
│   │   └── ...
│   ├── middlewares/                       # Auth, License, RateLimit, AuditAuto, Context
│   ├── models/                            # Sequelize ORM Relational Models
│   ├── routes/                            # 32 modular Express route files
│   ├── services/                          # Business services, AI, TaxEngine, WhatsApp
│   ├── utils/                             # Crypto, distributed locks, timezone, backup
│   └── jobs/                              # Background queue workers & cron jobs
│
├── lib/                                   # Flutter Client Source Code
│   ├── controllers/                       # Provider state management controllers
│   ├── core/                              # AppConfig, theme, constants, API client
│   ├── models/                            # Dart data models & serialization
│   ├── screens/                           # 75+ UI screens organized by feature domain
│   │   ├── accounting/                    # Chart of Accounts, Vouchers, Balance Sheet
│   │   ├── auth/                          # Login, User Management, Customer/Rider Auth
│   │   ├── community/                     # B2B Trade Chat & Marketplace Hub
│   │   ├── dashboard/                     # Main POS, Autonomous Agent, Cloud Migration
│   │   ├── hrms/                          # Attendance, Employees, Payroll
│   │   ├── inventory/                     # POS, BOM Assembly, Barcode Manager, GRN, Transfers
│   │   ├── modify/                        # Audit reprints, sales modifications
│   │   ├── recovery/                      # Disaster recovery, auto-reinstall
│   │   ├── reports/                       # 26+ financial, stock, tax, and sales reports
│   │   ├── restaurant/                    # Floors, Tables, KDS, Captain Tablet, KOTs
│   │   └── settings/                      # Hardware, Tax Groups, WhatsApp, Plugins, Workflows
│   ├── services/                          # Printing service, local storage, notifications
│   ├── utils/                             # Formatters, dialog helpers, sound effects
│   └── widgets/                           # Reusable UI widgets & smart upsell components
│
├── Docs/                                  # Complete Technical & User Documentation
└── installer/                             # InnoSetup & Windows packaging scripts
```

---

## 📚 Feature-by-Feature Dedicated Developer Guides

For in-depth implementation details of each individual subsystem, consult the dedicated technical guides:

| Technical Guide | Target Subsystem & Covered Architecture |
| :--- | :--- |
| ⚙️ **[Backend Guide](./Backend-Guide.md)** | Deep dive into Node.js, Express, Sequelize, Middleware pipeline, Caching, and Security. |
| 📱 **[Frontend Guide](./Frontend-Guide.md)** | Deep dive into Flutter Provider state management, responsive UI, printing engine, and caching. |
| 🍽️ **[Restaurant & Hospitality Guide](./Developer-Guide-Restaurant-Hospitality.md)** | Floor plan JSON, Table state machines, KOT lifecycle, real-time KDS, and Captain tablets. |
| 💰 **[Accounting & Financial Engine](./Developer-Guide-Accounting-Finance.md)** | Double-entry ledger invariants, COA tree, Trial Balance, P&L, Balance Sheet, and Loan EMI algorithms. |
| 👥 **[HRMS & Payroll Architecture](./Developer-Guide-HRMS-Payroll.md)** | HRMS schema, attendance punch logic, shift rules, monthly payroll calculation, and payslips. |
| 🛒 **[POS, Inventory & BOM Engine](./Developer-Guide-POS-Inventory-Manufacturing.md)** | POS transaction atomicity, Stock Ledger FIFO/Average, Barcode rendering, and BOM assembly. |
| 🤖 **[AI Intelligence & Autonomous Agents](./Developer-Guide-AI-Autonomous-Agents.md)** | Lynx AI tool calling schemas, autonomous replenishment background agents, and Smart Upsell engine. |
| 🔌 **[Plugins, Workflows & Automation](./Developer-Guide-Plugins-Workflows-Automation.md)** | Plugin sandboxing (VM2), event bus triggers, WhatsApp BullMQ queue, and Webhook dispatch. |
| 🛡️ **[Developer Security, Cache & Load Balancer](./Developer-Security-Cache-LoadBalancer-Guide.md)** | High-concurrency clustering, Redis caching, AES encryption, and distributed locks. |
| 📡 **[Full REST API Endpoint Reference](./Endpoint-Reference.md)** | 100% complete REST API reference for all 32 backend route modules with request/response schemas. |
| 🚀 **[Windows Installer & Packaging Guide](./Windows-Installer-Developer-Guide.md)** | Complete InnoSetup packaging, bundling PostgreSQL runtime, Node binary, and Flutter executables. |

---

## 🧪 Testing & Code Quality Guidelines

### 1. Flutter Code Analysis & Tests
```bash
flutter analyze
flutter test
```

### 2. Backend TypeScript Compilation & Verification
```bash
cd backend
npm run build     # Compiles TypeScript to dist/
npm test          # Runs automated Jest test suites
```

---

*Maintain code quality, ensure double-entry invariants, and preserve clean separation of concerns across all modules!*
