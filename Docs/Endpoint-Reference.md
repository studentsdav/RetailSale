# Full API Documentation

This document describes the complete HTTP API for the Retail Store Management System backend.

## 1. Base URL and Transport

- Local default: `http://127.0.0.1:3000`
- Health check: `GET /health`
- Content type: `application/json`

## 2. Authentication and Authorization

## 2.1 Login

- Endpoint: `POST /api/auth/login`
- Returns JWT token in response body.
- Send token in header for protected APIs:

```http
Authorization: Bearer <token>
```

## 2.2 License Module Guards

Protected routes require both:

- valid JWT (`auth.middleware`)
- active license + licensed module (`license.middleware`)

Modules by route group:

- `INVENTORY`: `/api/inventory`, `/api/receiving`, `/api/sales`, `/api/notifications`
- `PURCHASE`: `/api/purchase-orders`
- `SUPPLIER`: `/api/suppliers`
- `REPORTS`: `/api/reports`, `/api/analytics`, `/api/finance`
- `ADMIN`: `/api/users`

## 2.3 Common Auth Errors

- `401` no/invalid/expired token
- `403` license expired / module not licensed / license file issue

Typical auth error body:

```json
{
  "success": false,
  "error": "SESSION_EXPIRED",
  "message": "Session expired or invalid. Please log in again."
}
```

## 3. Common Conventions

- `:id`, `:billId`, `:itemCode` etc. are path parameters.
- Most list endpoints support query filters (date range/search/pagination) based on controller logic.
- Response shape varies slightly by module but usually includes `success` and data payload.

## 4. Public and Recovery APIs (No JWT)

## 4.1 Outlet and Property

- `POST /api/public/outlet/check`
- `POST /api/public/outlet`
- `GET /api/public/property-info`

## 4.2 Recovery and Emergency

- `POST /api/public/recovery/verify-pin`
- `POST /api/public/recovery/execute`
- `POST /api/public/recovery/request-otp`
- `POST /api/public/recovery/verify-otp`
- `POST /api/public/emergency-reset/recover-username`
- `POST /api/public/emergency-reset/request-otp`
- `POST /api/public/emergency-reset/verify-and-reset`

## 4.3 Setup / Update / Reinstall

- `POST /api/public/system/check-update`
- `POST /api/public/setup/request-otp`
- `POST /api/public/setup/verify-otp`
- `POST /api/public/verify-and-download`
- `POST /api/public/trigger-reinstall`

## 5. Auth API

- `POST /api/auth/login`

Minimum login body:

```json
{
  "username": "admin",
  "password": "your-password",
  "role": "ADMIN",
  "outlet_code": "OUTLET202604212159"
}
```

Success response includes:

- `token`
- `license_status`, `days_remaining`
- `user` (username, role, outlet, permissions, etc.)

## 6. Inventory APIs (`/api/inventory`)

Requires: JWT + `INVENTORY` license module.

## 6.1 Property

- `GET /property-info`
- `POST /property-info`

## 6.2 Item Master

- `GET /items/can-import`
- `GET /items/next-code`
- `POST /items`
- `GET /items`
- `GET /items/:id`
- `PUT /items/:id`
- `DELETE /items/:id`
- `POST /items/:id/image`
- `DELETE /items/:id/image`
- `POST /items/bulk-import`
- `POST /items/generate-barcodes`

## 6.3 Settings and Branding

- `GET /settings`
- `POST /settings`
- `POST /settings/clear-transaction-data`
- `GET /branding`
- `POST /branding`
- `GET /status`
- `POST /toggle`
- `GET /sync-latest`

## 6.4 Stock Locations

- `GET /locations/next-code`
- `POST /locations`
- `GET /locations`
- `GET /locations/:id`
- `PUT /locations/:id`
- `DELETE /locations/:id`

## 6.5 Supplier (Inventory Module)

- `GET /suppliers/can-import`
- `GET /suppliers/next-code`
- `POST /suppliers/bulk-import`
- `POST /suppliers`
- `GET /suppliers`
- `PUT /suppliers/:id`
- `DELETE /suppliers/:id`
- `GET /suppliers/bills/list`
- `POST /suppliers/bills/pay`
- `GET /suppliers/bills/:billId/payments`

## 6.6 Document Sequencing

- `GET /numbering`
- `POST /numbering`
- `GET /numbering/next`

## 6.7 Issue / Stock Out

- `GET /issue/next-issue-no`
- `GET /issue/departments`
- `GET /issue/by-date`
- `GET /issue/:id`
- `PUT /issue/:id`
- `POST /issue`
- `GET /issue/stock/:itemCode`

## 6.8 Group / Subcategory / Brand

- `POST /groups`
- `GET /groups`
- `PUT /groups/:id`
- `DELETE /groups/:id`
- `POST /subcategories`
- `GET /subcategories`
- `PUT /subcategories/:id`
- `DELETE /subcategories/:id`
- `POST /brands`
- `GET /brands`
- `PUT /brands/:id`
- `DELETE /brands/:id`

## 6.9 Damage

- `GET /damage/next-no`
- `POST /damage`
- `GET /damage/:id`
- `PUT /damage/:id/approve`
- `PUT /damage/:id/reject`
- `PUT /damage/item/:id`
- `DELETE /damage/item/:id`

## 6.10 Returns (Department Return)

- `GET /returns/returned-sum/:issueItemId`
- `GET /returns/indents`
- `GET /returns/issued-items/:issueId`
- `POST /returns`
- `PUT /returns/item/:id`
- `DELETE /returns/item/:id`
- `PUT /returns/:id/cancel`

## 6.11 Supplier Returns

- `GET /supplier-returns/grns`
- `GET /supplier-returns/received-items/:grnId`
- `GET /supplier-returns/returned-sum/:receiptItemId`
- `POST /supplier-returns`
- `GET /supplier-returns`
- `GET /supplier-returns/:returnId/refunds`
- `POST /supplier-returns/:id/refunds`

## 6.12 Requests Workflow

- `GET /requests/by-date`
- `GET /requests/next-no`
- `POST /requests`
- `GET /requests`
- `GET /requests/:id`
- `PUT /requests/:id/approve`
- `PUT /requests/:id/reject`
- `PUT /requests/:id/modify`
- `PUT /requests/:id/cancel`

## 7. Purchase Order APIs (`/api/purchase-orders`)

Requires: JWT + `PURCHASE` license module.

- `POST /`
- `GET /`
- `GET /by-date`
- `GET /:id/print`
- `GET /:id/details`
- `PUT /:id/modify`
- `GET /:id`
- `PUT /:id`
- `POST /:id/close`
- `POST /:id/cancel`

## 8. Receiving APIs (`/api/receiving`)

Requires: JWT + `INVENTORY` license module.

- `GET /next-grn`
- `GET /by-date`
- `GET /:id`
- `PUT /:id`
- `POST /`
- `GET /`
- `PUT /item/:id`
- `DELETE /item/:id`
- `POST /:id/cancel`

## 9. Supplier APIs (`/api/suppliers`)

Requires: JWT + `SUPPLIER` license module.

- `POST /`
- `GET /`
- `PUT /:id`
- `DELETE /:id`
- `GET /bills/list`
- `POST /bills/pay`
- `GET /bills/:billId/payments`

## 10. Sales APIs (`/api/sales`)

Requires: JWT + `INVENTORY` license module.

## 10.1 Sales Core

- `GET /next-sale-no`
- `POST /`
- `GET /`
- `GET /:id`
- `PUT /:id`
- `DELETE /drafts/:id`

## 10.2 Customers

- `GET /customers`
- `POST /customers`
- `PUT /customers/:id`
- `DELETE /customers/:id`

## 10.3 Vouchers

- `GET /vouchers`
- `POST /vouchers`
- `PUT /vouchers/:code`
- `DELETE /vouchers/:code`
- `POST /validate-voucher`

## 10.4 Loyalty

- `GET /loyalty/config`
- `POST /loyalty/config`
- `GET /loyalty/customer-summary`

## 10.5 Schemes

- `GET /schemes`
- `POST /schemes`
- `PUT /schemes/:id`
- `DELETE /schemes/:id`
- `GET /schemes/:id/customers`
- `POST /schemes/:id/customers`
- `PUT /schemes/:id/customers/:customerId`
- `GET /schemes/:id/progress`

## 10.6 Subscriptions

- `GET /subscriptions`
- `GET /subscriptions/customer`
- `GET /subscriptions/:id`
- `GET /subscriptions/:id/ledger`
- `POST /subscriptions`
- `POST /subscriptions/:id/final-settlement`

## 10.7 Item Advances

- `GET /item-advances`
- `POST /item-advances`
- `PUT /item-advances/:id`
- `DELETE /item-advances/:id`
- `GET /item-advances/summary`
- `GET /item-advances/ledger`

## 11. Analytics APIs (`/api/analytics`)

Requires: JWT + `REPORTS` license module.

- `GET /rfm-segments`
- `GET /sales-trend`
- `GET /market-basket`
- `GET /top-customer-items`

## 12. User/Admin APIs (`/api/users`)

Requires: JWT + `ADMIN` license module.

- `GET /`
- `POST /`
- `PUT /:id`
- `PUT /:id/status`
- `PUT /:id/reset-password`
- `POST /:username/change-password`
- `GET /:id/permissions`
- `PUT /:id/permissionsupdate`

## 13. Reports APIs (`/api/reports`)

Requires: JWT + `REPORTS` license module.

- `GET /inventory-dashboard`
- `GET /purchase-orders`
- `GET /return`
- `GET /request`
- `GET /sales`
- `GET /scheme`
- `GET /scheme-report`
- `GET /scheme-cycle-detail`
- `GET /loyalty/master`
- `GET /loyalty/ledger`
- `GET /stock-in`
- `GET /stock-out`
- `GET /stock-balance`
- `GET /damage`
- `GET /closing`
- `GET /dmgsummery`

## 14. Finance APIs (`/api/finance`)

Requires: JWT + `REPORTS` license module.

- `POST /expenses`
- `PUT /expenses/:id`
- `GET /expenses`
- `POST /income`
- `PUT /income/:id`
- `GET /income`
- `POST /withdrawals`
- `PUT /withdrawals/:id`
- `GET /withdrawals`
- `GET /ledger`
- `POST /repayments`
- `PUT /repayments/:id`
- `POST /advances`
- `PUT /advances/:id`
- `POST /advances/apply`
- `GET /repayments`
- `POST /opening-balance`
- `GET /opening-balance`
- `GET /credit-report`
- `GET /delivery-report`
- `GET /expiry-report`
- `GET /payment-flow`

## 15. Notification APIs (`/api/notifications`)

Requires: JWT + `INVENTORY` license module.

- `GET /`
- `PUT /:id/read`

## 16. Example Calls

## 16.1 Login

```bash
curl -X POST http://127.0.0.1:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username":"admin",
    "password":"your-password",
    "role":"ADMIN",
    "outlet_code":"OUTLET202604212159"
  }'
```

## 16.2 Protected GET

```bash
curl http://127.0.0.1:3000/api/reports/stock-balance \
  -H "Authorization: Bearer <token>"
```

## 16.3 Create Item

```bash
curl -X POST http://127.0.0.1:3000/api/inventory/items \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "item_name":"Sample Item",
    "unit":"PCS"
  }'
```

## 17. Notes for Integrators

- Keep token refresh/login handling on `401` with `SESSION_EXPIRED`.
- Handle license errors (`403`) separately from auth errors.
- Use server-side validation messages directly in client UX where possible.
- For report and list APIs, pass explicit date filters to keep response sizes manageable.

---

Last updated: `2026-05-07`
Source of truth: `backend/routes/*.routes.js`
