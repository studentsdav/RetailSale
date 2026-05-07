# Endpoint Reference

This document lists the HTTP API surface exposed by the backend.

## Base Paths

- Health check: `/health`
- All application APIs: `/api`

## Authentication

- `POST /api/auth/login`

## Public and Recovery

- `POST /api/public/outlet/check`
- `POST /api/public/outlet`
- `GET /api/public/property-info`
- `POST /api/public/recovery/verify-pin`
- `POST /api/public/recovery/execute`
- `POST /api/public/recovery/request-otp`
- `POST /api/public/recovery/verify-otp`
- `POST /api/public/system/check-update`
- `POST /api/public/emergency-reset/recover-username`
- `POST /api/public/emergency-reset/request-otp`
- `POST /api/public/emergency-reset/verify-and-reset`
- `POST /api/public/setup/request-otp`
- `POST /api/public/setup/verify-otp`
- `POST /api/public/verify-and-download`
- `POST /api/public/trigger-reinstall`

## Inventory

- `GET /api/inventory/property-info`
- `POST /api/inventory/property-info`
- `GET /api/inventory/items/can-import`
- `GET /api/inventory/items/next-code`
- `POST /api/inventory/items`
- `GET /api/inventory/items`
- `GET /api/inventory/items/:id`
- `PUT /api/inventory/items/:id`
- `DELETE /api/inventory/items/:id`
- `POST /api/inventory/items/:id/image`
- `DELETE /api/inventory/items/:id/image`
- `POST /api/inventory/items/bulk-import`
- `POST /api/inventory/items/generate-barcodes`
- `GET /api/inventory/settings`
- `POST /api/inventory/settings`
- `POST /api/inventory/settings/clear-transaction-data`
- `GET /api/inventory/branding`
- `POST /api/inventory/branding`
- `GET /api/inventory/status`
- `POST /api/inventory/toggle`
- `GET /api/inventory/sync-latest`
- `GET /api/inventory/locations/next-code`
- `POST /api/inventory/locations`
- `GET /api/inventory/locations`
- `GET /api/inventory/locations/:id`
- `PUT /api/inventory/locations/:id`
- `DELETE /api/inventory/locations/:id`
- `GET /api/inventory/suppliers/can-import`
- `GET /api/inventory/suppliers/next-code`
- `POST /api/inventory/suppliers/bulk-import`
- `POST /api/inventory/suppliers`
- `GET /api/inventory/suppliers`
- `PUT /api/inventory/suppliers/:id`
- `DELETE /api/inventory/suppliers/:id`
- `GET /api/inventory/suppliers/bills/list`
- `POST /api/inventory/suppliers/bills/pay`
- `GET /api/inventory/suppliers/bills/:billId/payments`
- `GET /api/inventory/numbering`
- `POST /api/inventory/numbering`
- `GET /api/inventory/numbering/next`
- `GET /api/inventory/issue/next-issue-no`
- `GET /api/inventory/issue/departments`
- `GET /api/inventory/issue/by-date`
- `GET /api/inventory/issue/:id`
- `PUT /api/inventory/issue/:id`
- `POST /api/inventory/issue`
- `GET /api/inventory/issue/stock/:itemCode`
- `POST /api/inventory/groups`
- `GET /api/inventory/groups`
- `PUT /api/inventory/groups/:id`
- `DELETE /api/inventory/groups/:id`
- `POST /api/inventory/subcategories`
- `GET /api/inventory/subcategories`
- `PUT /api/inventory/subcategories/:id`
- `DELETE /api/inventory/subcategories/:id`
- `POST /api/inventory/brands`
- `GET /api/inventory/brands`
- `PUT /api/inventory/brands/:id`
- `DELETE /api/inventory/brands/:id`
- `GET /api/inventory/damage/next-no`
- `POST /api/inventory/damage`
- `GET /api/inventory/damage/:id`
- `PUT /api/inventory/damage/:id/approve`
- `PUT /api/inventory/damage/:id/reject`
- `PUT /api/inventory/damage/item/:id`
- `DELETE /api/inventory/damage/item/:id`
- `GET /api/inventory/returns/returned-sum/:issueItemId`
- `GET /api/inventory/returns/indents`
- `GET /api/inventory/returns/issued-items/:issueId`
- `POST /api/inventory/returns`
- `PUT /api/inventory/returns/item/:id`
- `DELETE /api/inventory/returns/item/:id`
- `PUT /api/inventory/returns/:id/cancel`
- `GET /api/inventory/supplier-returns/grns`
- `GET /api/inventory/supplier-returns/received-items/:grnId`
- `GET /api/inventory/supplier-returns/returned-sum/:receiptItemId`
- `POST /api/inventory/supplier-returns`
- `GET /api/inventory/supplier-returns`
- `GET /api/inventory/supplier-returns/:returnId/refunds`
- `POST /api/inventory/supplier-returns/:id/refunds`
- `GET /api/inventory/requests/by-date`
- `GET /api/inventory/requests/next-no`
- `POST /api/inventory/requests`
- `GET /api/inventory/requests`
- `GET /api/inventory/requests/:id`
- `PUT /api/inventory/requests/:id/approve`
- `PUT /api/inventory/requests/:id/reject`
- `PUT /api/inventory/requests/:id/modify`
- `PUT /api/inventory/requests/:id/cancel`

## Purchase Orders

- `POST /api/purchase-orders/`
- `GET /api/purchase-orders/`
- `GET /api/purchase-orders/by-date`
- `GET /api/purchase-orders/:id/print`
- `GET /api/purchase-orders/:id/details`
- `PUT /api/purchase-orders/:id/modify`
- `GET /api/purchase-orders/:id`
- `PUT /api/purchase-orders/:id`
- `POST /api/purchase-orders/:id/close`
- `POST /api/purchase-orders/:id/cancel`

## Receiving

- `GET /api/receiving/next-grn`
- `GET /api/receiving/by-date`
- `GET /api/receiving/:id`
- `PUT /api/receiving/:id`
- `POST /api/receiving/`
- `GET /api/receiving/`
- `PUT /api/receiving/item/:id`
- `DELETE /api/receiving/item/:id`
- `POST /api/receiving/:id/cancel`

## Suppliers

- `POST /api/suppliers/`
- `GET /api/suppliers/`
- `PUT /api/suppliers/:id`
- `DELETE /api/suppliers/:id`
- `GET /api/suppliers/bills/list`
- `POST /api/suppliers/bills/pay`
- `GET /api/suppliers/bills/:billId/payments`

## Sales

- `GET /api/sales/next-sale-no`
- `GET /api/sales/customers`
- `POST /api/sales/customers`
- `PUT /api/sales/customers/:id`
- `DELETE /api/sales/customers/:id`
- `GET /api/sales/vouchers`
- `GET /api/sales/loyalty/config`
- `POST /api/sales/loyalty/config`
- `GET /api/sales/loyalty/customer-summary`
- `GET /api/sales/schemes`
- `GET /api/sales/schemes/:id/customers`
- `POST /api/sales/schemes/:id/customers`
- `PUT /api/sales/schemes/:id/customers/:customerId`
- `GET /api/sales/schemes/:id/progress`
- `GET /api/sales/subscriptions`
- `GET /api/sales/subscriptions/customer`
- `GET /api/sales/subscriptions/:id/ledger`
- `GET /api/sales/subscriptions/:id`
- `POST /api/sales/subscriptions`
- `POST /api/sales/subscriptions/:id/final-settlement`
- `GET /api/sales/item-advances`
- `POST /api/sales/item-advances`
- `PUT /api/sales/item-advances/:id`
- `DELETE /api/sales/item-advances/:id`
- `GET /api/sales/item-advances/summary`
- `GET /api/sales/item-advances/ledger`
- `POST /api/sales/vouchers`
- `PUT /api/sales/vouchers/:code`
- `DELETE /api/sales/vouchers/:code`
- `POST /api/sales/validate-voucher`
- `POST /api/sales/schemes`
- `PUT /api/sales/schemes/:id`
- `PUT /api/sales/:id`
- `DELETE /api/sales/schemes/:id`
- `POST /api/sales/`
- `GET /api/sales/`
- `DELETE /api/sales/drafts/:id`
- `GET /api/sales/:id`

## Analytics

- `GET /api/analytics/rfm-segments`
- `GET /api/analytics/sales-trend`
- `GET /api/analytics/market-basket`
- `GET /api/analytics/top-customer-items`

## Users

- `GET /api/users/`
- `POST /api/users/`
- `PUT /api/users/:id`
- `PUT /api/users/:id/status`
- `PUT /api/users/:id/reset-password`
- `POST /api/users/:username/change-password`
- `GET /api/users/:id/permissions`
- `PUT /api/users/:id/permissionsupdate`

## Reports

- `GET /api/reports/inventory-dashboard`
- `GET /api/reports/purchase-orders`
- `GET /api/reports/return`
- `GET /api/reports/request`
- `GET /api/reports/sales`
- `GET /api/reports/scheme`
- `GET /api/reports/scheme-report`
- `GET /api/reports/scheme-cycle-detail`
- `GET /api/reports/loyalty/master`
- `GET /api/reports/loyalty/ledger`
- `GET /api/reports/stock-in`
- `GET /api/reports/stock-out`
- `GET /api/reports/stock-balance`
- `GET /api/reports/damage`
- `GET /api/reports/closing`
- `GET /api/reports/dmgsummery`

## Finance

- `POST /api/finance/expenses`
- `PUT /api/finance/expenses/:id`
- `GET /api/finance/expenses`
- `POST /api/finance/income`
- `PUT /api/finance/income/:id`
- `GET /api/finance/income`
- `POST /api/finance/withdrawals`
- `PUT /api/finance/withdrawals/:id`
- `GET /api/finance/withdrawals`
- `GET /api/finance/ledger`
- `POST /api/finance/repayments`
- `PUT /api/finance/repayments/:id`
- `POST /api/finance/advances`
- `PUT /api/finance/advances/:id`
- `POST /api/finance/advances/apply`
- `GET /api/finance/repayments`
- `POST /api/finance/opening-balance`
- `GET /api/finance/opening-balance`
- `GET /api/finance/credit-report`
- `GET /api/finance/delivery-report`
- `GET /api/finance/expiry-report`
- `GET /api/finance/payment-flow`

## Notifications

- `GET /api/notifications/`
- `PUT /api/notifications/:id/read`

