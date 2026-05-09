# Feature Coverage Checklist (Menu vs Guides)

This checklist verifies the sidebar features shown in UI screenshots are covered in documentation.

## 1. Operations

- Purchase Order: covered
- Item Request: covered
- Receive from Vendor (GRN): covered
- Retail Sales: covered
- Stock Out: covered
- Return Department Items: covered
- Return Purchase to Vendor: covered
- Damage Items: covered
- Vendor Payment: covered
- Vendor Return Refund: covered

## 2. Modify

- Modify Request: covered
- Modify Purchase Order: covered
- Modify Receiving (GRN): covered
- Reprint / Modify Sales Bill: covered
- Modify Stock Out: covered

## 3. Masters

- Item Master: covered
- Vendor Master: covered
- Numbering Settings: covered
- Property Information: covered
- Location: covered
- User Management: covered
- Loyalty Program: covered

## 4. Stock View

- Stock Balance: covered
- Damage Summary: covered

## 5. Reports

- Purchase Report: covered
- Stock Out Report: covered
- Retail Sales Report: covered
- Subscription Report: covered
- Scheme Report: covered
- Loyalty Report: covered
- Store Analysis: covered
- Closing Report: covered
- Stock Ledger Report: covered
- Vendor Purchase Order: covered
- Finance & Reports: covered
- Return Report: covered
- Request Report: covered
- Damage Report: covered

## 6. System

- Help: covered
- Settings: covered
- Change Password: added explicitly
- Logout: added explicitly
- Check for Updates: added explicitly

## 7. Gaps Found and Fixed

The following items were commonly implied before and are now explicitly documented:

1. Change Password workflow
2. Logout step and session safety
3. Check for Updates workflow
4. Damage Summary under Stock View

## 8. Source of Truth Docs

- End-user workflows:
  - `Docs/Help-File.md`
- Admin/owner recovery + sync:
  - `Docs/Owner-Recovery-Sync-Data-Protection-Guide.md`
- Settings:
  - `Docs/Settings-Guide.md`
- Config/sync files:
  - `Docs/Config-And-Sync-Files-Guide.md`
