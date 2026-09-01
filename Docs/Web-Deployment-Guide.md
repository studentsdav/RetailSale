# 🌐 Web Deployment Guide (Local & Render Cloud)

This guide provides complete, step-by-step instructions for testing the **Retail POS Web Application** locally and deploying it to [Render.com](https://render.com) so users can access the application from any web browser.

---

## 📋 Table of Contents

- [Overview & Architecture](#-overview--architecture)
- [Prerequisites](#-prerequisites)
- [Phase 1: Local Web Testing](#-phase-1-local-web-testing)
- [Phase 2: Deploying to Render.com](#-phase-2-deploying-to-rendercom)
  - [Option A: Automatic Blueprint Deployment (Recommended)](#option-a-automatic-blueprint-deployment-recommended)
  - [Option B: Manual Docker Web Service Deployment](#option-b-manual-docker-web-service-deployment)
- [Environment Variables Reference](#-environment-variables-reference)
- [Troubleshooting & FAQ](#-troubleshooting--faq)

---

## 🏗️ Overview & Architecture

The web application combines the **Flutter Web** user interface with the **Express.js (Node.js)** backend API into a single unified deployment model:

```
[ Web Browser User ] ──(HTTPS)──> [ Express Backend Server on Render ]
                                        │
                                        ├──> Serves Static Web UI (Flutter SPA)
                                        └──> Handles REST API (/api/v1/...) ──> [ Render PostgreSQL DB ]
```

### Key Highlights:
- **Zero Configuration for Users:** When users visit `https://your-app.onrender.com`, the Flutter Web interface loads automatically and connects to the backend on the same domain (`Uri.base.origin`).
- **Non-Breaking Design:** Desktop (Windows/Linux/macOS) and mobile (Android/iOS) apps continue using offline `server_config.json` without any changes.

---

## 🛠️ Prerequisites

Before deploying, ensure you have:
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) installed locally (v3.x+).
2. [Node.js](https://nodejs.org/) (v20+ LTS) installed locally.
3. A free account on [Render.com](https://render.com).
4. Git installed and your repository pushed to GitHub or GitLab.

---

## 💻 Phase 1: Local Web Testing

Test the web app on your local machine before deploying to Render.

### Step 1: Build Flutter Web Release
Open a terminal in the root project folder (`RetailSale`) and run:

```bash
flutter build web --release
```

This generates compiled web assets in the `build/web/` directory.

### Step 2: Copy Web Build to Backend Static Folder
Copy the output from `build/web/` into `backend/public/`:

#### Windows (PowerShell):
```powershell
if (!(Test-Path "backend\public")) { New-Item -ItemType Directory -Path "backend\public" }
Copy-Item -Path "build\web\*" -Destination "backend\public" -Recurse -Force
```

#### macOS / Linux (Bash):
```bash
mkdir -p backend/public
cp -r build/web/* backend/public/
```

### Step 3: Run the Backend Server Locally
Navigate to the `backend` folder and start the server:

```bash
cd backend
npm install
node server.js
```

### Step 4: Verify in Web Browser
1. Open Google Chrome, Edge, or Safari and go to:
   - **Web UI:** `http://localhost:3000`
   - **API Health Check:** `http://localhost:3000/health`
2. Test user login, registration, dashboard loading, and sales screen.

---

## ☁️ Phase 2: Deploying to Render.com

---

### Option A: Automatic Blueprint Deployment (Recommended)

Render can automatically build and provision both the PostgreSQL database and the unified Web + API service using `render.yaml`.

1. **Push Changes to GitHub:**
   Ensure `render.yaml` and `Dockerfile.web` are committed:
   ```bash
   git add .
   git commit -m "Add Web deployment config"
   git push origin main
   ```

2. **Deploy on Render:**
   - Log into your [Render Dashboard](https://dashboard.render.com).
   - Click **New +** → **Blueprint**.
   - Connect your GitHub repository (`RetailSale`).
   - Render will detect `render.yaml` and prompt you to create:
     - **Database:** `retail-sale-db` (PostgreSQL)
     - **Web Service:** `retail-sale-backend` (using `Dockerfile.web`)
   - Click **Apply**.

3. **Access Your Live Web App:**
   Once the build completes (usually 2-4 minutes), open your service URL:
   `https://<your-app-name>.onrender.com`

---

### Option B: Manual Docker Web Service Deployment

If you prefer setting up services manually on Render:

#### Step 1: Create PostgreSQL Database on Render
1. In Render Dashboard, click **New +** → **PostgreSQL**.
2. **Name:** `retail-sale-db`
3. **Database Name:** `retailsale_db`
4. **User:** `retailsale_user`
5. **Plan:** `Free`
6. Click **Create Database** and copy the **Internal Database URL**.

#### Step 2: Create Web Service on Render
1. In Render Dashboard, click **New +** → **Web Service**.
2. Connect your GitHub repository.
3. Configure the settings:

| Setting | Value |
| :--- | :--- |
| **Name** | `retail-sale-web` |
| **Language / Runtime** | `Docker` |
| **Dockerfile Path** | `./Dockerfile.web` |
| **Docker Context** | `.` |
| **Branch** | `main` |
| **Plan** | `Free` |

4. Under **Environment Variables**, add:

| Key | Value |
| :--- | :--- |
| `NODE_ENV` | `production` |
| `PORT` | `3000` |
| `DATABASE_URL` | *(Paste Internal Database URL from Step 1)* |
| `DB_SSL` | `true` |
| `IS_CLOUD` | `true` |
| `JWT_SECRET` | *(Enter a random secure secret string)* |

5. Click **Create Web Service**.

---

## 🔑 Environment Variables Reference

| Variable | Example / Default | Description |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Enables production mode and cloud safety protocols |
| `PORT` | `3000` | Port assigned by Render for Express web service |
| `DATABASE_URL` | `postgresql://user:pass@dpg-xyz.render.com/retailsale_db` | PostgreSQL Connection URI |
| `DB_SSL` | `true` | Enables SSL encryption for cloud database queries |
| `IS_CLOUD` | `true` | Explicitly declares cloud deployment environment |
| `JWT_SECRET` | `super-secret-jwt-key-2026` | Secret key used to sign authentication tokens |

---

## ❓ Troubleshooting & FAQ

### Q: The page shows 404 when I refresh a sub-route on the web app.
**A:** Ensure `server.js` has the SPA catch-all middleware active. `server.js` automatically redirects non-API GET requests back to `index.html` when `backend/public/` exists.

### Q: Does this break the Windows Desktop or Mobile offline apps?
**A:** **No.** Non-web platforms (Windows, macOS, Linux, Android, iOS) continue reading `server_config.json` and operating offline. The web configuration is strictly isolated inside `if (kIsWeb)` guards.

### Q: Why is the first request slow on Render Free Tier?
**A:** Web services on Render's free tier automatically spin down after 15 minutes of inactivity. The first request after sleep will take 30-50 seconds to start up the container.

---

*Documentation maintained for Retail POS project.*
