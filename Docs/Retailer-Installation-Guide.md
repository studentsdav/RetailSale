# Retailer Installation and Update Guide

This guide is designed for retail store owners, administrators, and IT technicians to set up, update, and manage the Retail Store Management POS system.

> [!NOTE]
> This system is maintained and sponsored by **Famalth Technologies**.

---

## 💻 System Requirements
* **Operating System**: Windows 10 / Windows 11 (64-bit only).
* **Privileges**: Administrator rights (required for service and firewall configuration).
* **Database**: PostgreSQL 18 (automatically handled by the first-time installer).
* **Hardware**: Minimum 4GB RAM, 1GB free disk space.

---

## 🚀 First-Time Installation (Main Server Setup)

If you are setting up the POS system for the very first time on your primary server machine, you must install the backend environment and database first.

### Step 1: Download the Backend Bootstrapper
Download the full bootstrap installer:
👉 **[Download Backend Installer (v1.0.0.0)](https://github.com/studentsdav/RetailSale/releases/download/1.0.0.0/backend_Installer.exe)**

### Step 2: Install the Backend and Database
1. Locate the downloaded `backend_Installer.exe`.
2. Right-click the file and select **Run as Administrator**.
3. Follow the installation wizard. During this process, the installer will automatically:
   * Install the **Visual C++ Runtime** (required for backend stability).
   * Install **PostgreSQL 18** silently in the background (if not already installed).
   * Wait for the PostgreSQL service to start and automatically create a dedicated database named `retailpos` and a database user named `pos_user` with a secure randomized password.
   * Generate an encrypted configuration (`config.enc`) to securely lock down database credentials.
   * Exclude the installation directory (`C:\Retailpos` by default) from **Windows Defender** scanning to prevent performance lag.
   * Run the POS Frontend User Interface installer silently in the background.

### Step 3: Complete Frontend Setup
Once the backend installer finishes, it triggers the frontend setup which puts the desktop shortcuts in place and registers the backend server service.
1. When prompted by the frontend installer, select **Main Server (Database & User Interface)**.
2. Complete the setup. The app will launch immediately, and the backend server will run silently in the background via a hidden Windows Script Host wrapper (`run_hidden.vbs`).

---

## 🔄 Updating the POS App (or Adding Network Terminals)

When a new version is released, or if you want to connect a secondary cashier terminal on the same network, use the update/frontend installer.

### Step 1: Download the Update Installer
Download the latest application update:
👉 **[Download Retailpos Installer (v1.0.0.0)](https://github.com/studentsdav/RetailSale/releases/download/1.0.0.0/Retailpos_Installer.exe)**

### Step 2: Perform the Update (or Client Setup)
1. Run `Retailpos_Installer.exe` as **Administrator**.
2. Select the appropriate installation type based on your machine:
   * **Main Server (Database & User Interface)**: Use this on your primary machine to upgrade the POS executables and backend binaries without resetting your existing database. The installer will automatically:
     * Safely terminate any running `Retailpos.exe` or `server.exe` processes.
     * Overwrite old files with the updated version.
     * Keep all sales records, inventory data, and settings intact.
     * Re-register the Windows startup task (`INVINS_Server`) to point to the new files.
   * **Network Terminal (User Interface Only)**: Use this on secondary billing counters or client machines.
     * Installs only the POS User Interface.
     * Allows you to configure the connection to the Main Server's backend IP.
3. Finish the installation.

---

## ⚡ Post-Installation Verification

1. **Verify Backend Service**:
   * Open your web browser and navigate to `http://127.0.0.1:3000/health`.
   * You should see a JSON status code confirming the backend is healthy:
     ```json
     { "status": "UP", "database": "connected" }
     ```
2. **Verify Windows Startup Task**:
   * Open the Windows **Task Scheduler** and search for `INVINS_Server`.
   * The task is scheduled to run at user login with "Highest Privileges" to avoid Windows Defender startup delays.
3. **Configure Network Clients**:
   * On client machines, go to **Dashboard > Server Config** (or edit `server_config.json` in the install directory).
   * Change the `baseUrl` from `http://127.0.0.1:3000` to `http://<SERVER_IP_ADDRESS>:3000`.

---

## 🌟 New Features Log (Since Release 1.0.0.0)

The following features and optimizations have been introduced:

### 1. Invoice Format & Customization Upgrades
* **A4 Format Printing**: Built support for full-size A4 invoices alongside standard POS thermal paper rolls. You can switch formats under POS Printing settings.
* **Property Branding Control**: Dynamically customize invoice printouts. You can now define:
  * **Logo Size** (custom scaling for print layout).
  * **Business Email** and **Phone Number** shown directly on receipts.
  * Custom **Footer Text** (e.g., return policies, greetings).
  * Configure these in `Settings > Property Configuration`.

### 2. Finance and Expense Analytics
* **Expense Analytics Dashboard**: Visual graphs and category-wise breakdowns of store expenses to track overheads.
* **Advanced Cash Ledger**: Enhanced transaction filtering, search options, and audit logs inside the ledger reports.
* **Credit Ledger**: Built structured trackers to manage outstanding credits for suppliers, customer accounts, and delivery riders.
* **Taxes Master Model**: Integrated database migrations to support complex, multi-tiered taxation configurations.

### 3. Integrated Delivery System
* **Customer & Rider Authentication**: Added secure registration and login screens for riders and customers.
* **Retailer Delivery Console**: Manage delivery orders, assign riders, and monitor delivery workflows directly from the dashboard.
* **Real-time Order Status**: Visual progress indicators for "Ordered", "Dispatched", "Out for Delivery", and "Delivered".

### 4. Background Stability & Performance
* **Silent Server Boot**: Server execution runs in the background using `run_hidden.vbs` without opening an active command-prompt window.
* **Defender Lag Exclusions**: Auto-whitelisting of execution folders to bypass real-time antivirus inspection latency.
