# Retailer Store POS & Inventory Management System

A production-ready POS system with a Flutter client and Node.js backend for inventory, sales billing, purchase orders, receiving, suppliers, finance, reporting, and recovery workflows.

---

> [!NOTE]
> This repository is actively maintained and sponsored by **Famalth Technologies**.

---

## 🚀 Retailer Installation & Updates

For automated production deployments on Windows terminals:
* 📥 **[Download Backend Installer (v1.0.0.0)](https://github.com/studentsdav/RetailSale/releases/download/1.0.0.0/backend_Installer.exe)** - Run this **first time** on the main server to setup database, runtimes, and local configurations automatically.
* 📥 **[Download Update Installer (v1.0.0.0)](https://github.com/studentsdav/RetailSale/releases/download/1.0.0.0/Retailpos_Installer.exe)** - Run this to **update** existing terminals, or to install secondary billing clients on the network.

For step-by-step setup details, see the **[Retailer Installation & Update Guide](./Docs/Retailer-Installation-Guide.md)**.

---

## ☁️ Cloud Deployment & Environment Variables

Deploy the backend seamlessly on [Render.com](https://render.com) or custom cloud hosting. For complete deployment steps, read the **[Render Cloud Deployment & Environment Guide](./Docs/Render-Cloud-Deployment-Guide.md)**.

### Environment Variables Reference Table

| Category | Environment Variable | Example Value | Description |
| :--- | :--- | :--- | :--- |
| **Database** | `DATABASE_URL` | `postgresql://user:pass@dpg-xyz.render.com/dbname` | PostgreSQL connection string (Triggers Cloud SaaS mode) |
| | `DB_SSL` | `true` | Required for SSL connection to Cloud PostgreSQL |
| **Authentication**| `JWT_SECRET` | `super-secret-jwt-key-2026-prod` | Secret key used to sign JWT tokens |
| **SMTP / Email** | `EMAIL_PROVIDER` | `RESEND` | Explicit provider mode: **`RESEND`** (Resend API only), **`SMTP`** (SMTP only), or **`AUTO`** (SMTP primary + Resend fallback) |
| | `EMAIL_HOST` | `smtp.zoho.com` | SMTP Server Host (`smtp.zoho.com` / `smtp.gmail.com`) |
| | `EMAIL_PORT` | `465` | SMTP Port (`465` for SSL, `587` for STARTTLS, `25` for None) |
| | `EMAIL_SECURITY` | `SSL` | Security Protocol: **`SSL`** (465), **`STARTTLS`** (587), or **`NONE`** (25) |
| | `EMAIL_SECURE` | `false` | Set `true` for Port 465 SSL, `false` for Port 587 STARTTLS |
| | `EMAIL_USER` | `famalth.retail@famalth.com` | SMTP Sender Email Address |
| | `EMAIL_PASS` | `abcd1234efgh` | Zoho / Gmail 16-character App Password |
| | `EMAIL_TIMEOUT` | `20000` | Connection timeout in milliseconds (Default: 20000) |
| **Resend API** | `RESEND_API_KEY` | `re_123456789abcdef` | HTTPS Resend API key for 0.1s instant OTP emails over Port 443 |
| | `EMAIL_FROM` | `"Retail POS" <noreply@famalth.com>` | Custom verified sender header name & email address |
| **Google Sync** | `ROOT_FOLDER_ID` | `1A2B3C4D5E6F7G8H` | Google Drive Root Folder ID for automated backups |
| | `SCRIPT_URL` | `https://script.google.com/macros/s/exec` | Google Apps Script Sync Endpoint URL |
| | `SHEET_ID` | `1XYZ2ABC3DEF4GHI` | Google Sheets Sync Database Spreadsheet ID |

---

## 📚 Documentation

- [Retailer Installation & Update Guide](./Docs/Retailer-Installation-Guide.md)
- [Render Cloud Deployment & Environment Guide](./Docs/Render-Cloud-Deployment-Guide.md)
- [Own Server Online Deployment Guide](./Docs/Own-Server-Online-Deployment-Guide.md)
- [User Guide](./Docs/User-Guide.md)
- [Complete Help File](./Docs/Help-File.md)
- [Developer Guide](./Docs/Developer-Guide.md)
- [Init Setup Guide (Dev/Manual)](./Docs/Init-Setup.md)
- [Frontend Developer Guide](./Docs/Frontend-Guide.md)
- [Backend Developer Guide](./Docs/Backend-Guide.md)
- [Endpoint Reference](./Docs/Endpoint-Reference.md)

---

## Quick Start

1. Install Flutter dependencies with `flutter pub get`.
2. Install backend dependencies with `cd backend && npm install`.
3. Start PostgreSQL and confirm backend configuration.
4. Run the backend with `cd backend && npm start`.
5. Run the Flutter app with `flutter run`.

## Default API URL

The Flutter app reads its backend URL from `server_config.json`.

Default:

```text
http://127.0.0.1:3000
```

## Project Layout

- `lib/` - Flutter app
- `backend/` - Express API server
- `Docs/` - Documentation files
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` - Platform targets

## Screenshots

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

## Contributing

Please update the relevant guide when setup, runtime behavior, or APIs change.
