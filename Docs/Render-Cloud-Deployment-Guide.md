# ☁️ Render Cloud Deployment & Environment Guide

This guide provides a comprehensive, step-by-step walkthrough for deploying the **Retail POS Backend** to [Render.com](https://render.com) with PostgreSQL database integration, cloud backup sync, and full multi-tenant SaaS capability.

---

## 📋 Prerequisites

1. A [Render.com](https://render.com) account.
2. A PostgreSQL database on Render (or external provider like Neon, Supabase, AWS RDS).
3. Git repository pushed to GitHub or GitLab.

---

## 🛠️ Step 1: Deploy PostgreSQL Database on Render

1. Log into your **Render Dashboard**.
2. Click **New +** → **PostgreSQL**.
3. Fill in the details:
   - **Name:** `retail-pos-db`
   - **Database:** `retailpos`
   - **User:** `retailadmin`
   - **Region:** Choose nearest region (e.g., Singapore / Frankfurt / Oregon)
4. Click **Create Database**.
5. Once created, copy the **Internal Database URL** (or **External Database URL** if connecting from outside Render).

---

## 🚀 Step 2: Deploy Web Service on Render

1. In Render Dashboard, click **New +** → **Web Service**.
2. Connect your GitHub repository (`RetailSale`).
3. Fill in the deployment configuration:

| Setting | Value |
| :--- | :--- |
| **Name** | `retail-sale-backend` |
| **Language** | `Node` |
| **Region** | Same region as your database |
| **Branch** | `main` |
| **Root Directory** | `backend` *(or leave blank if using Docker)* |
| **Build Command** | `npm install` |
| **Start Command** | `npm start` |

---

## 🔑 Step 3: Comprehensive Environment Variables Reference

In your Web Service, go to the **Environment** tab and add the following key-value pairs:

### 1. Database & Core Server (Required)

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Enables production mode and triggers cloud safety protocols |
| `PORT` | `10000` | Port for Express API server (Render sets automatically) |
| `DATABASE_URL` | `postgresql://user:pass@dpg-xyz.render.com/retailpos?ssl=true` | PostgreSQL Connection URI (Enables Cloud SaaS multi-tenant mode) |
| `DB_SSL` | `true` | Enables SSL encryption required by Cloud PostgreSQL instances |
| `JWT_SECRET` | `super-secret-jwt-key-2026-prod` | Secret key used to sign and verify user JWT authentication tokens |
| `IS_CLOUD` | `true` | Explicitly declares cloud deployment environment |

---

### 2. SMTP Email Service & OTP Delivery (Primary & Add-On)

> [!IMPORTANT]
> Render Web Services block outbound TCP port 587 (`ETIMEDOUT`). For Zoho Mail or custom SMTP on Render, set **`EMAIL_PORT=465`** and **`EMAIL_SECURITY=SSL`** (or use **`RESEND_API_KEY`** over HTTPS port 443).

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `EMAIL_PROVIDER` | `RESEND` | Explicit mode: **`RESEND`** (Resend API), **`GMAIL`** (Gmail OAuth2), **`SMTP`** (SMTP only), or **`AUTO`** |
| `RESEND_API_KEY` | `re_123456789abcdef` | HTTPS Resend API key for 0.1s instant OTP emails over Port 443 |
| `EMAIL_FROM` | `"Retail POS" <noreply@famalth.com>` | Custom verified sender header name & email address |
| `GMAIL_CLIENT_ID` | `123456-xyz.apps.googleusercontent.com` | Google Cloud OAuth2 Client ID (See [Gmail OAuth2 Guide](./Google-Gmail-OAuth2-Setup-Guide.md)) |
| `GMAIL_CLIENT_SECRET` | `GOCSPX-your_client_secret` | Google Cloud OAuth2 Client Secret |
| `GMAIL_REFRESH_TOKEN` | `1//04_your_oauth_refresh_token` | Google OAuth2 Refresh Token (from OAuth Playground) |
| `EMAIL_USER` | `famalth.retail@famalth.com` | Primary Sender Email Address (used for SMTP and Gmail OAuth2) |
| `EMAIL_PASS` | `abcd1234efgh` | App Password generated in Zoho Mail or Gmail Security (for password auth) |
| `EMAIL_HOST` | `smtp.zoho.in` | SMTP Server Host (`smtp.zoho.in` / `smtp.gmail.com`) |
| `EMAIL_PORT` | `587` | SMTP Port (`587` for STARTTLS, `465` for SSL) |
| `EMAIL_SECURITY` | `STARTTLS` | Security Protocol: **`STARTTLS`** (587), **`SSL`** (465), or **`NONE`** (25) |
| `EMAIL_SECURE` | `false` | Set `false` for Port 587 STARTTLS, `true` for Port 465 SSL |
| `EMAIL_TIMEOUT` | `20000` | SMTP Connection timeout in milliseconds (Default: 20000) |

---

### 3. Google Drive Cloud Backups & Sheet Sync (Add-On)

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `ROOT_FOLDER_ID` | `1A2B3C4D5E6F7G8H9I` | Google Drive Root Folder ID for storing automated `.enc` database backups |
| `SCRIPT_URL` | `https://script.google.com/macros/s/exec` | Google Apps Script Sync Endpoint URL for cloud synchronization |
| `SHEET_ID` | `1XYZ2ABC3DEF4GHI5JKL` | Google Sheets Database Spreadsheet ID for real-time audit logging |

---

## ⚡ Cloud Mode Features & Automatic Adaptations

When `DATABASE_URL` or `DB_HOST` is set, the backend automatically adapts:

1. **Automatic Cloud Sync (`Cloud Sync: ON`):** Database backups default to **`ON`** for cloud deployments to protect data against ephemeral container restarts.
2. **Bypasses Disk `.enc` Files:** Local `config.enc` disk existence checks are automatically bypassed in cloud mode while preserving local offline mode for Windows desktop terminals.
3. **Resilient Migrations:** Automatically runs database schema migrations and seed scripts on boot with automatic PostgreSQL transaction `ROLLBACK` error recovery.
4. **IPv4 DNS Lookup:** Uses forced `resolve4` lookup (`family: 4`) for Nodemailer to prevent container IPv6 `ENETUNREACH` socket errors.
5. **Live OTP Console Logging:** Outputs generated OTP codes directly to Render Live Logs (`🔑 [OTP GENERATED] Target: email | Code: 123456`).

---

## 📱 Step 4: Connecting the Flutter Client

1. Launch your Flutter client app.
2. On the **Terminal Setup Screen**:
   - **Server URL:** `https://retail-sale-backend.onrender.com`
   - **Outlet Code (Optional):** Enter your private outlet code (e.g. `OUTLET202608301109`), or leave blank to register a new store.
3. Click **Verify & Connect Outlet** (or **Save & Register New Store**).
