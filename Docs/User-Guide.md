# User Guide

This guide is for staff, operators, and day-to-day users of the inventory system.

> [!TIP]
> For instructions on automated installation and software updates, please refer to the **[Retailer Installation & Update Guide](./Retailer-Installation-Guide.md)**.

## How to Use the App

1. Ensure the backend server is running (either started manually or via the automated startup task).
2. Open the POS app from your Desktop shortcut.
3. Log in with your assigned credentials.
4. Use the sidebar to navigate to the modules authorized for your user role.

## Core & Upgraded Modules

- **Inventory Management**: Track stock levels, set reorder points, and perform stock counts.
- **Purchases & Receiving**: Manage Purchase Orders (PO) and process Goods Received Notes (GRN).
- **Sales & Counter POS**: Dynamic sales screen supporting product scanning, discount schemes, and dual-format printing (**A4 Size** and **Standard POS Thermal** formats).
- **Invoice Customization**: Edit logo size, email, phone number, and custom footer texts via `Settings > Property Configuration`.
- **Expense Analytics**: Track overheads and categories with interactive visual charts inside the Finance Hub.
- **Advanced Cash & Credit Ledgers**: Manage double-entry accounting records, customer accounts, and supplier bill payments, as well as Credit tracking for business accounts.
- **Customer & Rider Delivery Console**: Monitor online orders, authenticate riders, and track order fulfillment states in real-time.
- **Notifications**: View system alerts and low-stock warnings.

## Recovery and Setup Screens

Use recovery features only when needed for:

- forgotten login or password
- system configuration recovery
- outlet verification
- reinstall or re-download of configuration

## API URL

If the app cannot connect to the backend, confirm the backend URL in `server_config.json`.

Default backend URL:

```text
http://127.0.0.1:3000
```

## Owner/Admin Recovery and Data Safety

For username recovery, outlet recovery, forgot password, latest sync, and backup/data protection process:

- [Owner-Recovery-Sync-Data-Protection-Guide](./Owner-Recovery-Sync-Data-Protection-Guide.md)

## Settings Guide

For complete setup of outlet, property, document sequence, printing, billing, and system preferences:

- [Settings-Guide](./Settings-Guide.md)

## Config and Sync Files Guide

For `server_config.json`, `sync_status.json`, `client.json`, and `backup_status.json`:

- [Config-And-Sync-Files-Guide](./Config-And-Sync-Files-Guide.md)

