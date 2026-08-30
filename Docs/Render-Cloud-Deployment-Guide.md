# ☁️ Render Cloud Deployment & Environment Guide

This guide provides a comprehensive, step-by-step walkthrough for deploying the **Retail POS Backend** to [Render.com](https://render.com) with PostgreSQL database integration and full Cloud SaaS capability.

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

## 🔑 Step 3: Complete Environment Variables Reference

In your Web Service, go to **Environment** tab and add the following keys:

### 1. Database & Server Core (Required)

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Enables production mode |
| `PORT` | `10000` | Port for Express app (Render sets automatically) |
| `DATABASE_URL` | `postgresql://user:pass@ep-xyz.render.com/retailpos?ssl=true` | PostgreSQL Connection URI (Triggers Cloud SaaS Mode) |
| `DB_SSL` | `true` | Required for SSL connection to Cloud PostgreSQL |
| `JWT_SECRET` | `super-secret-jwt-key-2026-prod` | Secret key used to sign JWT authentication tokens |

### 2. Email Service & OTP Delivery (Optional)

> [!IMPORTANT]
> Render Free Web Services block outbound TCP ports 25, 465, and 587 (`ETIMEDOUT`). For outbound OTP emails on Render, use `RESEND_API_KEY` over HTTPS port 443, or check OTP directly from Render Live Logs (`🔑 [OTP GENERATED]`).

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `RESEND_API_KEY` | `re_123456789abcdef` | HTTPS Resend API key for outbound OTP emails (Recommended for Render) |
| `EMAIL_USER` | `studentsdav6@gmail.com` | SMTP Email address (Gmail / SendGrid / Custom SMTP) |
| `EMAIL_PASS` | `abcd efgh ijkl mnop` | Gmail 16-character App Password |
| `EMAIL_HOST` | `smtp.gmail.com` | SMTP Server Host |
| `EMAIL_PORT` | `587` | SMTP Port (587 TLS or 465 SSL) |
| `EMAIL_TIMEOUT` | `30000` | Connection timeout in milliseconds (Default: 30000) |

---

## ⚡ Cloud Mode Features & Automatic Adaptations

When `DATABASE_URL` or `DB_HOST` is set, the backend automatically adapts:

1. **Bypasses Disk `.enc` Files:** Local `config.enc` disk existence checks are automatically bypassed in cloud mode while preserving local offline mode for Windows desktop terminals.
2. **Resilient Migrations:** Automatically runs database schema migrations and seed scripts on boot with automatic PostgreSQL transaction `ROLLBACK` error recovery.
3. **IPv4 DNS Lookup:** Uses forced `resolve4` lookup (`family: 4`) for Nodemailer to prevent container IPv6 `ENETUNREACH` socket errors.
4. **Live OTP Console Logging:** Outputs generated OTP codes directly to Render Live Logs (`🔑 [OTP GENERATED] Target: email | Code: 123456`).

---

## 📱 Step 4: Connecting the Flutter Client

1. Launch your Flutter client app.
2. On the **Terminal Setup Screen**:
   - **Server URL:** `https://retail-sale-backend.onrender.com`
   - **Outlet Code (Optional):** Enter your private outlet code (e.g. `MUMBAI_STORE`), or leave blank to register a new store.
3. Click **Verify & Connect Outlet** (or **Save & Register New Store**).
