# 📡 Master REST API Endpoint Reference

This document is the **complete, exhaustive HTTP REST API reference** for all 32 route modules in the backend server.

---

## 📑 Table of Contents
1. [Base URL, Headers & Authentication](#1-base-url-headers--authentication)
2. [Public & System Recovery APIs (`/api/public`)](#2-public--system-recovery-apis-apipublic)
3. [Authentication APIs (`/api/auth`)](#3-authentication-apis-apiauth)
4. [Enterprise Sales & POS APIs (`/api/sales`)](#4-enterprise-sales--pos-apis-apisales)
5. [Inventory, Items & Transfers (`/api/inventory`)](#5-inventory-items--transfers-apiinventory)
6. [Purchase Orders (`/api/purchase-orders`)](#6-purchase-orders-apipurchase-orders)
7. [Goods Receiving / GRN (`/api/receiving`)](#7-goods-receiving--grn-apireceiving)
8. [Suppliers & Vendors (`/api/suppliers`)](#8-suppliers--vendors-apisuppliers)
9. [Restaurant, Tables, KOTs & KDS (`/api/restaurant`)](#9-restaurant-tables-kots--kds-apirestaurant)
10. [Accounting, COA, Vouchers & Loans (`/api/accounting`)](#10-accounting-coa-vouchers--loans-apiaccounting)
11. [Finance & Ledgers (`/api/finance`)](#11-finance--ledgers-apifinance)
12. [HRMS & Staff Payroll (`/api/hrms`)](#12-hrms--staff-payroll-apihrms)
13. [Customer App & Rider Delivery (`/api/delivery`)](#13-customer-app--rider-delivery-apidelivery)
14. [Lucky Draw & Raffle Campaigns (`/api/lucky-draw`)](#14-lucky-draw--raffle-campaigns-apilucky-draw)
15. [Night Audit & EOD Reconciliation (`/api/night-audit`)](#15-night-audit--eod-reconciliation-apinight-audit)
16. [B2B Marketplace & Trade Chat (`/api/community`)](#16-b2b-marketplace--trade-chat-apicommunity)
17. [Famalth Lynx AI Assistant (`/api/ai-assist`)](#17-famalth-lynx-ai-assistant-apiai-assist)
18. [Autonomous Background Agents (`/api/v1/agent`)](#18-autonomous-background-agents-apiv1agent)
19. [AI Cart Intelligence & Recommendations (`/api/v1/intelligence`)](#19-ai-cart-intelligence--recommendations-apiv1intelligence)
20. [Plugin Marketplace & Sandbox (`/api/v1/plugins`)](#20-plugin-marketplace--sandbox-apiv1plugins)
21. [Workflow Automation Engine (`/api/v1/workflows`)](#21-workflow-automation-engine-apiv1workflows)
22. [Developer API Keys & Webhooks (`/api/v1/developer`)](#22-developer-api-keys--webhooks-apiv1developer)
23. [WhatsApp Cloud API & Queue (`/api/whatsapp`)](#23-whatsapp-cloud-api--queue-apiwhatsapp)
24. [WhatsApp Webhooks (`/api/whatsapp-webhook`)](#24-whatsapp-webhooks-apiwhatsapp-webhook)
25. [Sticky Notes System (`/api/user-notes`)](#25-sticky-notes-system-apiuser-notes)
26. [Multi-Tax Groups (`/api/tax-groups`)](#26-multi-tax-groups-apitax-groups)
27. [User & Role Management (`/api/users`)](#27-user--role-management-apiusers)
28. [Reports & Analytics (`/api/reports`, `/api/analytics`)](#28-reports--analytics-apireports-apianalytics)
29. [Operations & Audit Trail (`/api/operations`, `/api/audit`)](#29-operations--audit-trail-apioperations-apiaudit)
30. [Notifications (`/api/notifications`)](#30-notifications-apinotifications)
31. [System Server Time (`/api/system`)](#31-system-server-time-apisystem)
32. [1-Click Cloud Migration Gateway (`/api/public/migration`)](#32-1-click-cloud-migration-gateway-apipublicmigration)

---

## 1. Base URL, Headers & Authentication

- **Default Local Base URL**: `http://127.0.0.1:3000`
- **Health Check**: `GET /health`
- **Protected Request Headers**:
```http
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
Idempotency-Key: <UUID> (Optional for safe retries)
```

---

## 2. Public & System Recovery APIs (`/api/public`)

*No JWT required.*

- `POST /api/public/outlet/check` — Check outlet registration status.
- `POST /api/public/outlet` — Register new outlet terminal.
- `GET /api/public/property-info` — Retrieve public store branding.
- `POST /api/public/recovery/verify-pin` — Verify owner master recovery PIN.
- `POST /api/public/recovery/execute` — Execute automated database recovery.
- `POST /api/public/emergency-reset/request-otp` — Send SMS/Email password reset OTP.
- `POST /api/public/emergency-reset/verify-and-reset` — Set new admin password with OTP.
- `POST /api/public/system/check-update` — Check for new software version binaries.

---

## 3. Authentication APIs (`/api/auth`)

- `POST /api/auth/login` — Authenticate store user (email/password) and issue JWT token.
- `POST /api/auth/pin-login` — High-speed PIN login for waiters/cashiers with outlet & username resolution.
- `GET /api/auth/quick-users` — List quick-login staff enabled for dropdown PIN selection.
- `POST /api/auth/refresh` — Refresh expired JWT token.
- `POST /api/auth/change-password` — Change current user password.
- `POST /api/auth/logout` — Invalidate user session.

---

## 4. Enterprise Sales & POS APIs (`/api/sales`)

*Requires: JWT + `INVENTORY` License Module.*

- `GET /api/sales` — List sales invoices with date range, cashier, and customer filters.
- `POST /api/sales` — Commit new POS sale transaction (atomic stock deduction & loyalty credit).
- `GET /api/sales/:id` — Retrieve full sale details, tax split, and payment records.
- `PUT /api/sales/:id` — Update sale bill details (Admin only).
- `POST /api/sales/:id/void` — Void/cancel sales invoice and restore stock.
- `POST /api/sales/:id/reprint` — Generate audited receipt reprint payload.
- `GET /api/sales/customer/:phone` — Retrieve sales history for customer.

---

## 5. Inventory, Items, Modifiers & Stock Taking (`/api/inventory`)

- `GET /api/inventory/items` — List items with search, category, Veg/Non-Veg, and low stock filters.
- `POST /api/inventory/items` — Create new item master record.
- `PUT /api/inventory/items/:id` — Update item details, pricing, dietary flags, and barcode.
- `DELETE /api/inventory/items/:id` — Deactivate item.
- `GET /api/inventory/categories` — List item categories.
- `POST /api/inventory/categories` — Create item category.
- `GET /api/inventory/modifiers` — List item modifiers and add-on groups (e.g. Extra Cheese).
- `POST /api/inventory/modifiers` — Create modifier with price and optional raw material recipe link.
- `PUT /api/inventory/modifiers/:id` — Edit modifier properties and pricing.
- `DELETE /api/inventory/modifiers/:id` — Remove modifier.
- `GET /api/stock-taking` — Retrieve stock audit sheet with current balances and variances.
- `POST /api/stock-taking/reconcile` — Commit physical count and post adjustment variance journal.
- `GET /api/inventory/stock-locations` — List warehouse locations & racks.
- `POST /api/inventory/transfers/request` — Create multi-branch stock transfer request.
- `POST /api/inventory/transfers/dispatch` — Dispatch stock to target branch.
- `POST /api/inventory/transfers/receive` — Accept inward transfer at target outlet.
- `POST /api/inventory/damages` — Record damaged inventory write-off.
- `POST /api/inventory/assembly/produce` — Run BOM assembly production batch.

---

## 6. Purchase Orders (`/api/purchase-orders`)

*Requires: JWT + `PURCHASE` License Module.*

- `GET /api/purchase-orders` — List purchase orders with status filter.
- `POST /api/purchase-orders` — Create new purchase order (supports integer net rounding for VAT-inclusive).
- `GET /api/purchase-orders/:id` — Retrieve purchase order details.
- `PUT /api/purchase-orders/:id` — Update pending purchase order.
- `POST /api/purchase-orders/:id/approve` — Manager approval of PO.
- `POST /api/purchase-orders/:id/cancel` — Cancel purchase order.

---

## 7. Goods Receiving / GRN (`/api/receiving`)

> **DOCTRINE**: GRNs are **NEVER auto-generated**. They require manual operator physical counting and inward verification.

- `GET /api/receiving` — List Goods Receiving Notes (GRNs).
- `POST /api/receiving` — Commit manual operator-verified GRN and credit stock into inventory.
- `GET /api/receiving/:id` — Retrieve GRN details and linked PO.
- `PUT /api/receiving/:id` — Modify receiving entry (Admin audit).

---

## 8. Suppliers & Vendors (`/api/suppliers`, `/api/payment-methods`)

- `GET /api/suppliers` — List suppliers with outstanding balances.
- `POST /api/suppliers` — Create supplier master profile (state is optional; opening balance auto-syncs to COA).
- `PUT /api/suppliers/:id` — Update supplier details & credit limit.
- `POST /api/suppliers/:id/payments` — Settle supplier invoice using custom payment methods.
- `POST /api/suppliers/return` — Process return to supplier (Debit Note).
- `POST /api/suppliers/return-refund` — Settle supplier refund/adjustment.
- `GET /api/payment-methods` — List payment methods with linked `coa_account_id`.
- `POST /api/payment-methods` — Create custom payment method linked to COA Asset account.
- `PUT /api/payment-methods/:id` — Update payment method and COA binding.

---

## 9. Restaurant, Tables, KOTs & KDS (`/api/restaurant`)

- `GET /api/restaurant/floors` — List floors and dining areas.
- `POST /api/restaurant/floors` — Create dining floor.
- `GET /api/restaurant/tables` — List tables with live availability status and assigned staff.
- `POST /api/restaurant/tables` — Create new dining table.
- `POST /api/restaurant/tables/bulk-import` — Bulk import dining tables from Excel/CSV template.
- `POST /api/restaurant/tables/:id/assign` — Assign table or section to specific waiter/captain.
- `PUT /api/restaurant/tables/:id/status` — Update table status (`OCCUPIED`, `AVAILABLE`).
- `POST /api/restaurant/tables/transfer` — Transfer active order to another table.
- `POST /api/restaurant/tables/merge` — Merge multiple tables for group dining.
- `GET /api/restaurant/kots/active` — Live active KOTs stream for KDS.
- `POST /api/restaurant/kots` — Create & fire new KOT to kitchen (supports multi-client tickets per table).
- `PUT /api/restaurant/kots/:id/items/:itemId/status` — Bump-bar update (`COOKING` -> `DONE`).
- `POST /api/restaurant/kots/:id/settle` — Settle table and generate POS invoice.
- `POST /api/restaurant/reservations` — Create table reservation.
- `POST /api/v1/qr-order` — Public customer QR code table self-ordering submission.

---

## 10. Accounting, COA, Vouchers & Loans (`/api/accounting`)

- `GET /api/accounting/coa` — Retrieve hierarchical Chart of Accounts tree.
- `POST /api/accounting/coa` — Create ledger account.
- `POST /api/accounting/coa/seed` — Seed default retail/restaurant accounts.
- `GET /api/accounting/vouchers` — Search accounting vouchers (JV, PV, RV, CV).
- `POST /api/accounting/vouchers` — Post balanced double-entry voucher.
- `GET /api/accounting/banks` — List company bank accounts.
- `POST /api/accounting/banks` — Register bank account.
- `GET /api/accounting/loans-assets` — List loans and amortized asset schedules.
- `POST /api/accounting/loans` — Register business loan.
- `POST /api/accounting/loans/pay-emi` — Post monthly EMI installment.

---

## 11. Finance & Ledgers (`/api/finance`)

- `GET /api/finance/cash-ledger` — Retrieve daily cashbook transactions.
- `POST /api/finance/expenses` — Record expense entry.
- `GET /api/finance/recurring-expenses` — List recurring expense templates.

---

## 12. HRMS & Staff Payroll (`/api/hrms`)

- `GET /api/hrms/employees` — List employee directory.
- `POST /api/hrms/employees` — Onboard new employee.
- `GET /api/hrms/shifts` — List work shifts.
- `POST /api/hrms/shifts` — Create work shift.
- `POST /api/hrms/attendance/punch` — Record employee punch-in / punch-out.
- `GET /api/hrms/attendance/daily-grid` — Daily employee attendance grid.
- `POST /api/hrms/payroll/calculate` — Run monthly gross-to-net payroll engine.
- `POST /api/hrms/payroll/finalize` — Finalize payroll and generate payslips.

---

## 13. Customer App & Rider Delivery (`/api/delivery`)

- `GET /api/delivery/catalog` — Public customer shopping catalog.
- `POST /api/delivery/orders` — Place online delivery order.
- `GET /api/delivery/orders/:id/track` — Real-time order delivery tracking.
- `POST /api/delivery/rider/login` — Rider mobile authentication.
- `PUT /api/delivery/rider/orders/:id/status` — Rider updates delivery status (`PICKED_UP`, `DELIVERED`).

---

## 14. Lucky Draw & Raffle Campaigns (`/api/lucky-draw`)

- `GET /api/lucky-draw/campaigns` — List lucky draw campaigns.
- `POST /api/lucky-draw/campaigns` — Create new raffle campaign.
- `GET /api/lucky-draw/campaigns/:id/stats` — Retrieve participant counts and ticket stats.
- `POST /api/lucky-draw/campaigns/:id/draw` — Execute certified random winner draw.

---

## 15. Night Audit & EOD Reconciliation (`/api/night-audit`)

- `GET /api/night-audit/status` — Check day-end closing status.
- `POST /api/night-audit/validate` — Validate open registers, unbilled KOTs, and cash.
- `POST /api/night-audit/execute` — Finalize day-end closing and lock daily ledger.

---

## 16. B2B Marketplace & Trade Chat (`/api/community`)

- `GET /api/community/conversations` — Fetch 1-on-1 chats and trade channels.
- `POST /api/community/conversations` — Initiate new supplier conversation.
- `GET /api/community/messages` — Retrieve chat history.
- `POST /api/community/messages` — Send direct message or PO reference.
- `GET /api/community/merchants` — List verified marketplace suppliers.

---

## 17. Famalth Lynx AI Assistant (`/api/ai-assist`)

- `POST /api/ai-assist/chat` — Conversational natural language query and actions.
- `POST /api/ai-assist/voice-command` — Handle transcribed voice shortcuts.

---

## 18. Autonomous Background Agents (`/api/v1/agent`)

- `GET /api/v1/agent/proposals` — List pending autonomous agent proposals.
- `POST /api/v1/agent/proposals/:id/approve` — Approve and execute proposal.
- `POST /api/v1/agent/proposals/:id/reject` — Reject proposal.
- `GET /api/v1/agent/audit-logs` — Audit log of autonomous agent activities.

---

## 19. AI Cart Intelligence & Recommendations (`/api/v1/intelligence`)

- `GET /api/v1/intelligence/recommendations` — Fetch live basket cross-sell suggestions.
- `GET /api/v1/intelligence/customer-insights/:id` — RFM customer lifetime analytics.

---

## 20. Plugin Marketplace & Sandbox (`/api/v1/plugins`)

- `GET /api/v1/plugins/marketplace` — Discover available plugins.
- `GET /api/v1/plugins/installed` — List installed plugins.
- `POST /api/v1/plugins/install` — Install plugin.
- `POST /api/v1/plugins/:id/toggle` — Enable or disable plugin.

---

## 21. Workflow Automation Engine (`/api/v1/workflows`)

- `GET /api/v1/workflows/rules` — List workflow trigger rules.
- `POST /api/v1/workflows/rules/:id/toggle` — Toggle workflow active state.
- `POST /api/v1/workflows/trigger` — Emit manual event into workflow engine.

---

## 22. Developer API Keys & Webhooks (`/api/v1/developer`)

- `GET /api/v1/developer/ecosystem/info` — Ecosystem telemetry & version.
- `GET /api/v1/developer/api-keys` — List integration API keys.
- `POST /api/v1/developer/api-keys` — Generate new developer API key.
- `GET /api/v1/developer/webhooks` — List registered webhook URLs.
- `POST /api/v1/developer/webhooks` — Register new outbound webhook.

---

## 23. WhatsApp Cloud API & Queue (`/api/whatsapp`)

- `GET /api/whatsapp/config` — Retrieve WhatsApp API credentials.
- `POST /api/whatsapp/config` — Configure Meta Cloud API token and phone number ID.
- `POST /api/whatsapp/config/test` — Test WhatsApp connectivity.
- `GET /api/whatsapp/templates` — List approved WhatsApp message templates.
- `POST /api/whatsapp/send-invoice` — Enqueue digital invoice PDF message.

---

## 24. WhatsApp Webhooks (`/api/whatsapp-webhook`)

- `GET /api/whatsapp-webhook` — Meta webhook verification challenge.
- `POST /api/whatsapp-webhook` — Ingest inbound customer message events.

---

## 25. Sticky Notes System (`/api/user-notes`)

- `GET /api/user-notes` — List user notes & pinned memos.
- `POST /api/user-notes` — Create new sticky note.
- `PUT /api/user-notes/:id` — Update note content, color, or pin status.
- `PUT /api/user-notes/:id/trash` — Move note to trash.
- `PUT /api/user-notes/:id/restore` — Restore note from trash.
- `DELETE /api/user-notes/:id/permanent` — Permanently delete note.

---

## 26. Multi-Tax Groups (`/api/tax-groups`)

- `GET /api/tax-groups` — List tax groups (GST, VAT, Sales Tax, CESS).
- `POST /api/tax-groups` — Create new flat or compound tax group.
- `PUT /api/tax-groups/:id` — Update tax group components.
- `DELETE /api/tax-groups/:id` — Deactivate tax group.

---

## 27. User & Role Management (`/api/users`)

- `GET /api/users` — List store users and assigned roles.
- `POST /api/users` — Create new cashier/staff user.
- `PUT /api/users/:id` — Update user details or permissions.
- `POST /api/users/:id/reset-password` — Reset staff password.

---

## 28. Reports & Analytics (`/api/reports`, `/api/analytics`)

- `GET /api/reports/sales` — Comprehensive sales report with tax splits.
- `GET /api/reports/stock-balance` — Current inventory balance & valuation.
- `GET /api/reports/stock-ledger` — Historical transaction stock ledger.
- `GET /api/reports/trial-balance` — Real-time Trial Balance statement.
- `GET /api/reports/profit-loss` — Period Profit & Loss statement.
- `GET /api/reports/balance-sheet` — Certified Balance Sheet.
- `GET /api/reports/cashier-handover` — Cashier shift handover audit.
- `GET /api/analytics/dashboard-summary` — Real-time sales, gross profit, and visitor metrics.

---

## 29. Operations & Audit Trail (`/api/operations`, `/api/audit`)

- `GET /api/audit/logs` — Immutable audit trail of all system mutations.
- `GET /api/operations/summary` — Operations intelligence overview.

---

## 30. Notifications (`/api/notifications`)

- `GET /api/notifications` — Retrieve user notifications.
- `PUT /api/notifications/:id/read` — Mark notification as read.

---

## 31. System Server Time (`/api/system`)

- `GET /api/system/server-time` — Synchronize client clock with database server time.

---

## 32. 1-Click Cloud Migration Gateway (`/api/public/migration`)

- `GET /api/public/migration/ping` — Verify cloud migration gateway reachability.
- `POST /api/public/migration/export-bundle` — Export complete local store database snapshot.
- `POST /api/public/migration/import-bundle` — Ingest snapshot onto cloud server with ID translation.
- `POST /api/public/migration/sync-online-to-offline` — Pull down cloud database to local offline node.

---


## 33. Quick Users & PIN Authentication (`/api/auth`)

- `GET /api/auth/quick-users?outlet_code=...&role=...` — Pre-login active staff members configured for fast dropdown selection.
- `POST /api/auth/pin-login` — Scoped authentication using `outlet_code`, `username`, `pin`, and `role`.

---

## 34. Multi-Country Tax Seeding & Integrity (`/api/settings/tax-groups`)

- `POST /api/settings/tax-groups/seed-country` — Auto-seed legal fiscal tax slabs for detected country (IN, DE, US, KE, BR, GB).
- `POST /api/settings/tax-groups/replace-and-delete` — Atomic reassignment of linked items to target tax group before deleting old group.
- `DELETE /api/settings/tax-groups/:id` — Safe delete tax group with linked item count protection.

---


## 35. Contactless QR Table Dining (`/api/restaurant/dining`)

- `GET /api/restaurant/dining/catalog?outlet_id=...&table_id=...` — Retrieve live public menu, categories, and active table session metadata for guest devices.
- `POST /api/restaurant/dining/place-order` — Place dining order from QR web client, generate kitchen KOT tickets, and notify floor captain.
- `GET /api/restaurant/dining/active-orders?table_id=...` — Poll live table order status and kitchen preparation updates.

---

## 36. M-Pesa & Mobile Money Gateway (`/api/mpesa`)

- `POST /api/mpesa/callback` — Public asynchronous webhook callback for Safaricom Daraja STK push results.
- `GET /api/mpesa/config` — Retrieve outlet M-Pesa Till / Paybill credentials.
- `POST /api/mpesa/config` — Save encrypted M-Pesa shortcode, passkey, and Daraja API keys (Admin only).
- `POST /api/mpesa/stk-push` — Trigger instant M-Pesa STK push prompt on customer mobile device.
- `POST /api/mpesa/stk-query` — Poll real-time status of initiated STK push transaction.

---

*Last Updated: October 2026 | Covers 100% of all 33 Express Route Modules & Payment Gateways*
