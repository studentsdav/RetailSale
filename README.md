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

For step-by-step setup details, see the new **[Retailer Installation & Update Guide](./Docs/Retailer-Installation-Guide.md)**.

## 📚 Documentation

- [Retailer Installation & Update Guide](./Docs/Retailer-Installation-Guide.md)
- [User Guide](./Docs/User-Guide.md)
- [Complete Help File](./Docs/Help-File.md)
- [Developer Guide](./Docs/Developer-Guide.md)
- [Init Setup Guide (Dev/Manual)](./Docs/Init-Setup.md)
- [Frontend Developer Guide](./Docs/Frontend-Guide.md)
- [Backend Developer Guide](./Docs/Backend-Guide.md)
- [Own Server Online Deployment Guide](./Docs/Own-Server-Online-Deployment-Guide.md)
- [Endpoint Reference](./Docs/Endpoint-Reference.md)

## Quick Start

1. Install Flutter dependencies with `flutter pub get`.
2. Install backend dependencies with `cd backend && npm install`.
3. Start PostgreSQL and confirm the backend config files are present.
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
- `Docs/` - documentation files
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` - platform targets

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
