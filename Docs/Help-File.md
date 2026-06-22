# Complete Help File (Step-by-Step)

This document is the complete user help file for the **Retail Store Management System**.
It is written for store operators, inventory staff, accountants, supervisors, and administrators.

## 1. Purpose of This Software

Use this software to manage:

- Item master and stock locations
- Purchase orders and stock receiving
- Stock out to departments and stock returns
- Sales billing and customer activity
- Supplier management and supplier return/refund
- Cash/finance entries and business reporting
- User/permission control and system settings
- Backup, sync, and recovery workflows

## 2. Before You Start

Keep these ready:

- Working backend server
- Stable internet (recommended for sync/backup)
- Valid username and password
- Correct API server address in `server_config.json`

Default API URL:

```text
http://127.0.0.1:3000
```

## 3. Start the System

### Step 1: Start Backend

1. Open terminal in `backend`.
2. Run:

```bash
npm start
```

3. Confirm backend is healthy at:

```text
GET /health
```

### Step 2: Start App

1. Open terminal in project root.
2. Run:

```bash
flutter run
```

3. Wait for login screen.

## 4. Login and Session

### Login Steps

1. Enter username.
2. Enter password.
3. Click **Login**.
4. Wait for Dashboard load.

### If Login Fails

1. Check credentials.
2. Check backend connection.
3. Confirm server URL from server config screen.
4. Use password recovery (admin/security flow) if needed.

## 5. Dashboard Overview

After login, dashboard shows:

- Today In
- Today Out
- Low Stock
- Stock Value
- Charts for stock movement and damage trend
- Low-stock reorder alerts

Daily checks:

1. Verify low-stock alerts.
2. Review stock in/out trend.
3. Review supplier payment/unpaid values.
4. Review notification bell for pending actions.
5. Check **Damage Summary** for loss patterns.

## 6. Step-by-Step Core Workflows

## 6.1 Item Master Setup (First Activity)

Use screen: **Item Master**

1. Open **Inventory > Item Master**.
2. Create item with code, name, unit, category, tax, rates.
3. Set reorder/minimum stock values.
4. Save item.
5. Repeat for all products.
6. Verify item appears in list/search.

## 6.2 Supplier Setup

Use screen: **Supplier Master**

1. Open **Inventory > Supplier Master**.
2. Click add supplier.
3. Enter name, phone, GST/tax details, address.
4. Save.
5. Check supplier appears in dropdowns during purchase.

## 6.3 Stock Location Setup

Use screen: **Stock Location**

1. Open **Settings > Stock Location**.
2. Add store/warehouse/department locations.
3. Save each location.
4. Confirm locations are selectable in stock transactions.

## 6.4 Purchase Order Creation

Use screen: **Purchase Order**

1. Open **Inventory > Purchase Order**.
2. Select supplier.
3. Add item rows with quantity and rates.
4. Verify tax and totals.
5. Save/submit PO.
6. Share PO reference with supplier.

## 6.5 Receiving (Stock In)

Use screen: **Receiving**

1. Open **Inventory > Receiving**.
2. Choose supplier and PO reference (if available).
3. Enter received quantities item-wise.
4. Verify rate, tax, batch/date details if required.
5. Save receiving entry.
6. Confirm stock balance increased.

## 6.6 Stock Out (Issue to Department)

Use screen: **Stock Out / Issue**

1. Open **Inventory > Stock Out / Issue**.
2. Select department/location.
3. Add items and quantities.
4. Verify availability.
5. Save issue entry.
6. Confirm stock reduced from source location.

## 6.7 Department Return (Stock In Back)

Use screen: **Return Issue Item**

1. Open **Inventory > Return**.
2. Select department/source issue reference.
3. Add return quantities.
4. Save return.
5. Confirm stock added back to store.

## 6.8 Damage Entry

Use screen: **Damage Entry**

1. Open **Inventory > Damage**.
2. Select item and location.
3. Enter damaged quantity and reason.
4. Save damage record.
5. Confirm damage reflects in damage reports.

## 6.9 Sales Billing (POS/Counter)

Use screen: **Sale Screen / Enterprise POS**

1. Open **Inventory > Sales**.
2. Search/scan item barcode.
3. Add quantity for each item.
4. Apply discount/scheme if applicable.
5. Select customer (optional/required by setup).
6. Choose payment mode.
7. Save bill and print/reprint invoice if needed.

## 6.10 Supplier Return and Refund

Use screens: **Supplier Return** and **Supplier Return Refund**

1. Create supplier return for damaged/excess stock.
2. Select supplier and items.
3. Save supplier return note.
4. Open supplier refund/payment adjustment screen.
5. Record refund or credit settlement.
6. Verify outstanding supplier amount updates.

## 7. Modify/Correction Workflows

Use modify screens for controlled edits:

- Purchase Modify
- Receiving Modify
- Request Modify
- Stock Out Modify
- Sales Reprint/Modify

Steps:

1. Open required modify screen.
2. Search document by date/reference.
3. Open record and update permitted fields.
4. Save changes.
5. Re-check affected reports/stock.

Important:

- Do not delete records directly unless policy permits.
- Use corrections with proper reason/audit comments.

## 8. Finance and Accounts Workflows

Common screens:

- Supplier Payment
- Cash Ledger
- Finance Hub (dashboard/API-backed)
- Closing Report

Daily process:

1. Record supplier payments.
2. Verify credit/debit entries.
3. Check customer/supplier outstanding amounts.
4. Close daily books from closing report.
5. Keep variance notes if mismatch found.

## 9. Reports (Step-by-Step)

Open **Reports** section and use filters (date, item, supplier, location).

Main reports:

- Stock Balance
- Stock In Report
- Stock Out Report
- Stock Ledger
- Purchase Report
- Sales Report
- Return Report
- Request Report
- Damage Report
- Cash Ledger
- Store Analysis
- Loyalty/Scheme/Subscription reports (if enabled)

Standard report process:

1. Select report name.
2. Choose date range.
3. Apply supplier/item/location filters.
4. Click view/search.
5. Verify totals and drill into rows.
6. Export/print if required by process.

## 10. Settings and Administration

Common settings:

- Property/Outlet information
- Document sequence settings
- Stock locations
- Loyalty master config
- Notifications preference
- Theme/UI preference
- User management

### User Management Steps

1. Open **User Management**.
2. Create user account.
3. Assign role and permissions.
4. Save.
5. Test login with new user.

### Password Change Steps

1. Open account/security option.
2. Enter current password.
3. Enter new password (minimum policy).
4. Confirm new password.
5. Save.
6. Login again using new password.

### Logout Steps

1. Open left menu.
2. Click **Logout**.
3. Confirm logout if prompted.
4. Verify login screen appears before leaving shared terminal.

### Check for Updates

1. Open left menu.
2. Click **Check for Updates**.
3. Wait for version check result.
4. If update is available, follow installer prompt/policy from admin.

## 11. Backup, Sync, and Recovery

System includes backup/recovery utilities.

### Recommended Daily Backup Routine

1. Ensure internet is active.
2. Trigger sync/backup from dashboard/settings.
3. Wait for success confirmation.
4. Check last sync timestamp.

### If Sync Warning Appears

1. Verify internet.
2. Retry sync.
3. Check server and authentication status.
4. Contact support if it still fails.

### Recovery Tools (Use Carefully)

- Config recovery
- Full recovery
- Auto reinstall/re-download setup
- Password recovery

Use recovery only with admin approval.

## 12. Troubleshooting Guide

### Problem: App cannot connect to server

1. Confirm backend is running.
2. Check `server_config.json` URL.
3. Test `/health` endpoint.
4. Check firewall/port restrictions.

### Problem: Stock mismatch

1. Check pending modify entries.
2. Verify receiving and issue posting dates.
3. Check damage and return entries.
4. Run stock ledger for item/location.

### Problem: Permission denied

1. Confirm user role rights.
2. Ask admin to update permission set.
3. Logout and login again.

### Problem: Report totals not matching

1. Use same date range and filters.
2. Check whether cancelled/modified entries are included.
3. Compare stock ledger vs transaction report.

## 13. Best Practices

- Complete master setup before live billing.
- Post receiving and stock out on same day.
- Avoid back-dated entries unless approved.
- Review low-stock and outstanding daily.
- Run closing report every day.
- Keep at least one tested backup.
- Limit high-privilege access to admins only.

## 14. Daily End-of-Day Checklist

1. All sales bills posted.
2. All receiving and stock out posted.
3. Damage entries completed.
4. Supplier/customer outstanding checked.
5. Cash ledger reviewed.
6. Closing report generated.
7. Backup/sync successful.
8. Logout all shared terminals.

## 15. Quick Navigation Index

- Login: `Auth > Inventory Login`
- Dashboard: `Dashboard`
- Item Master: `Inventory > Item Master`
- Purchase: `Inventory > Purchase Order`
- Receiving: `Inventory > Receiving`
- Stock Out: `Inventory > Issue/Stock Out`
- Return: `Inventory > Return Issue`
- Damage: `Inventory > Damage`
- Sales: `Inventory > Sales`
- Supplier: `Inventory > Supplier Master`
- Reports: `Reports`
- Settings: `Settings`
- Help: `Settings > Help & Support`
- Change Password: `System > Change Password`
- Logout: `System > Logout`
- Check for Updates: `System > Check for Updates`

## 17. Feature Coverage Checklist

To verify sidebar menu coverage against documentation:

- [Feature-Coverage-Checklist](./Feature-Coverage-Checklist.md)

## 16. Support Information

Use the in-app **Help & Support** page for:

- Support phone
- Support email
- Support website/knowledge base

If issue is critical, share:

- Screenshot
- Error message text
- Username and outlet
- Transaction reference number
- Time of issue

---

Document version: `1.0`
Last updated: `2026-05-07`
