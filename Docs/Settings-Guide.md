# Settings Guide

This guide explains how to configure system settings safely after login.

## 1. Recommended Setup Order

1. Outlet Setup
2. Property Configuration
3. Stock Location
4. Numbering Settings
5. Global Settings
6. Loyalty Settings (if used)
7. Server Config (terminal mapping)
8. User Management and permissions

## 2. Outlet Setup

Use for new business registration and outlet recovery.

What to configure:

- Outlet code
- Outlet name
- Outlet type
- Recovery methods (OTP/recovery flow)

Screen:

- `Settings > Outlet Setup`

## 3. Property Configuration

Use this to set invoice/business identity.

What to configure:

- Property name and legal name
- Address/city/state/PIN
- Contact person/mobile/email
- GST/PAN/FSSAI
- Logo
- Active status

Screen:

- `Settings > Property Configuration`

## 4. Stock Location

Use this to define stores/warehouse/department locations used in transactions.

What to configure:

- Location list
- Active locations for issue/receiving flows

Screen:

- `Settings > Stock Location`

## 5. Numbering Settings

Use this to define document number series per module.

Modules:

- Purchase Order
- Receiving
- Indent
- Sales Bill
- Request
- Damage

Per row fields:

- Start Date
- Start No
- Prefix
- Postfix

Tip:

- You can create multiple date-based rows per module for financial year reset.

Screen:

- `Settings > Numbering Settings`

## 6. Global Settings (Main Settings Screen)

Sections available:

- Data & Security
- Inventory Settings
- Approval Rules
- Audit & Compliance
- Appearance
- Branding
- Printing
- Global Billing
- Default Charges
- Danger Zone (Admin only)

Important options:

- Cloud backup enable/disable
- Auto reorder alert
- Allow negative stock
- Show item images in sales
- Enable audit log
- Theme and startup screen
- Default printer and print mode
- Tax mode and bill format
- Charge rules (amount/percent + taxability)

Admin warning:

- `Clear All Transaction Data` permanently removes transaction records for current DB.

## 7. Loyalty Settings

Use when loyalty module is active.

What to configure:

- Earning/redeem logic
- Constraints/rules for loyalty processing

Screen:

- `Settings > Loyalty Master Config`

## 8. Server Config (Per Terminal)

Use this on each machine/terminal.

What to configure:

- Backend base URL
- Outlet code list mapped to this terminal

Default URL:

- `http://127.0.0.1:3000`

Screen:

- `Dashboard > Server Config`

## 9. Save and Validation Checklist

After changing settings:

1. Click `Save Settings` / `Apply Settings`.
2. Logout/login once for role/theme consistency.
3. Create one test transaction.
4. Print one test invoice.
5. Verify report totals and numbering format.
6. Trigger sync/backup and confirm success.

## 10. Common Mistakes to Avoid

1. Editing numbering without defining prefix/postfix.
2. Enabling direct print without selecting a default printer.
3. Changing outlet/server config on one machine but not others.
4. Running transaction clear without a verified latest backup.
5. Using wrong outlet code during recovery.
