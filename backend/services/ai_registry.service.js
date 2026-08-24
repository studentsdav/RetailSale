/**
 * AI Registry Service - FAMALTH LYNX
 * Centralized schema, status filtering, screen action mapping, and system prompt generator.
 * Makes AI Navigation and Text-to-SQL extensible whenever new screens or tables are added in the future.
 */

const SCREEN_NAVIGATION_REGISTRY = [
    {
        actionType: 'OPEN_NOTES',
        label: 'Open Sticky Notes',
        keywords: ['note', 'sticky note', 'reminder', 'todo', 'schedule note', 'task note'],
        description: 'Business Sticky Notes & Schedule Reminders Board'
    },
    {
        actionType: 'SCHEDULE_TASK',
        label: 'View Scheduled Tasks',
        keywords: ['schedule task', 'schedule reminder', 'remind me', 'alarm', 'task schedule'],
        description: 'AI Task & Reminder Scheduler'
    },
    {
        actionType: 'MANAGE_SUBSCRIPTIONS',
        label: 'Open Subscriptions',
        keywords: ['subscription', 'daily milk', 'milk delivery', 'daily subscribe', 'daily item', 'recurring order', 'customer subscribe'],
        description: 'Customer daily subscription dashboard (milk, bread, daily consumables)'
    },
    {
        actionType: 'SUBSCRIPTION_REPORTS',
        label: 'View Subscription Logs',
        keywords: ['subscription log', 'delivery challan subscription', 'daily delivery log', 'skipped delivery'],
        description: 'Daily subscription consumption logs and delivery receipts'
    },
    {
        actionType: 'CREATE_BILL',
        label: 'Open POS Billing',
        keywords: ['bill', 'invoice', 'pos', 'checkout', 'cashier', 'new sale', 'billing'],
        description: 'Point of Sale (POS) billing screen'
    },
    {
        actionType: 'ENTERPRISE_POS',
        label: 'Open Enterprise POS',
        keywords: ['enterprise pos', 'touch pos', 'quick pos'],
        description: 'Touch-screen enterprise billing counter'
    },
    {
        actionType: 'SEARCH_ITEM',
        label: 'Open Item Master',
        keywords: ['item', 'product', 'inventory', 'stock search', 'catalog', 'price list'],
        description: 'Item Master product list and pricing catalog'
    },
    {
        actionType: 'LOW_STOCK_ALERT',
        label: 'View Low Stock Items',
        keywords: ['low stock', 'reorder', 'out of stock', 'shortage', 'stock alert'],
        description: 'Stock balance and low stock reorder screen'
    },
    {
        actionType: 'STOCK_TRANSFER',
        label: 'Open Stock Transfer',
        keywords: ['transfer', 'warehouse transfer', 'inter-store transfer', 'location transfer'],
        description: 'Inter-warehouse inventory stock transfer'
    },
    {
        actionType: 'STOCK_ISSUE',
        label: 'Open Stock Issue',
        keywords: ['issue', 'stock issue', 'department issue', 'raw material issue'],
        description: 'Internal department stock issuing'
    },
    {
        actionType: 'STOCK_REQUEST',
        label: 'Open Stock Request',
        keywords: ['request', 'stock request', 'requisition', 'indent'],
        description: 'Sub-store stock requisitions'
    },
    {
        actionType: 'DAMAGE_ITEMS',
        label: 'Open Damage & Waste Log',
        keywords: ['damage', 'waste', 'expired', 'broken', 'loss', 'spoilage'],
        description: 'Damaged and expired goods tracking'
    },
    {
        actionType: 'ASSEMBLY_BOM',
        label: 'Open Product Assembly',
        keywords: ['bom', 'assembly', 'recipe', 'manufacturing', 'production', 'bundle'],
        description: 'Bill of Materials (BOM) & Product Assembly'
    },
    {
        actionType: 'ITEM_BARCODE',
        label: 'Open Barcode Manager',
        keywords: ['barcode', 'barcode print', 'label print', 'generate barcode'],
        description: 'Item barcode sticker generator & printer'
    },
    {
        actionType: 'APPROVAL_CENTER',
        label: 'Open Approval Center',
        keywords: ['approval', 'approve request', 'pending approval', 'manager approval'],
        description: 'Inventory & workflow approval queue'
    },
    {
        actionType: 'CREATE_PO',
        label: 'Draft Purchase Order',
        keywords: ['purchase order', 'create po', 'draft purchase order', 'draft po', 'restock order', 'need to order', 'supplier order', 'procurement', 'vendor order', 'reorder items'],
        description: 'Purchase orders management screen & automated reorder drafting'
    },
    {
        actionType: 'GRN',
        label: 'Open Goods Receiving (GRN)',
        keywords: ['grn', 'receive goods', 'goods receipt', 'vendor invoice', 'supplier bill'],
        description: 'Goods Receiving Note (GRN) entry & verification'
    },
    {
        actionType: 'SUPPLIER_MASTER',
        label: 'Open Supplier Directory',
        keywords: ['supplier', 'vendor', 'distributor', 'supplier list'],
        description: 'Supplier directory & contact database'
    },
    {
        actionType: 'SUPPLIER_PAYMENTS',
        label: 'Open Supplier Payments',
        keywords: ['supplier payment', 'pay vendor', 'vendor due', 'supplier ledger'],
        description: 'Supplier payments and outstanding dues'
    },
    {
        actionType: 'SUPPLIER_RETURN',
        label: 'Open Supplier Return',
        keywords: ['supplier return', 'purchase return', 'return to vendor'],
        description: 'Return defective stock to suppliers'
    },
    {
        actionType: 'SALES_RETURN',
        label: 'Open Customer Sales Return',
        keywords: ['sales return', 'customer return', 'refund bill'],
        description: 'Customer bill return and credit memo'
    },
    {
        actionType: 'VIEW_REPORTS',
        label: 'Open Sales Reports',
        keywords: ['sales report', 'revenue report', 'daily sales', 'total sales', 'profit'],
        description: 'Sales performance analytics & reports'
    },
    {
        actionType: 'CLOSING_REPORT',
        label: 'Open Day Closing Report',
        keywords: ['closing report', 'day close', 'shift close', 'end of day', 'cash tally'],
        description: 'Day end register reconciliation & closing report'
    },
    {
        actionType: 'CASH_LEDGER',
        label: 'Open Cash Ledger',
        keywords: ['cash ledger', 'cash drawer', 'petty cash', 'cash flow', 'cash entry'],
        description: 'Cash drawer register & petty cash ledger'
    },
    {
        actionType: 'STOCK_LEDGER_REPORT',
        label: 'Open Stock Ledger',
        keywords: ['stock ledger', 'item movement', 'inventory log', 'stock audit'],
        description: 'Historical stock movement audit log'
    },
    {
        actionType: 'CREDIT_ANALYSIS',
        label: 'Open Customer Credit Report',
        keywords: ['credit', 'customer due', 'pending balance', 'credit analysis', 'udhar'],
        description: 'Customer credit ledger and outstanding dues'
    },
    {
        actionType: 'LOYALTY_REPORT',
        label: 'Open Loyalty Points Report',
        keywords: ['loyalty', 'points', 'rewards', 'customer points'],
        description: 'Customer rewards program & points ledger'
    },
    {
        actionType: 'EXPENSE_ANALYTICS',
        label: 'Open Expense Analytics',
        keywords: ['expense report', 'spending', 'cost analysis', 'expense breakdown'],
        description: 'Business expense breakdown & analytics'
    },
    {
        actionType: 'EMPLOYEES',
        label: 'Open Employee Directory',
        keywords: ['employee', 'staff', 'worker', 'hrms', 'staff directory'],
        description: 'Staff directory & employment records'
    },
    {
        actionType: 'ATTENDANCE',
        label: 'Open Attendance Logs',
        keywords: ['attendance', 'punch clock', 'check-in', 'present', 'absent', 'shift log'],
        description: 'Employee punch clock attendance records'
    },
    {
        actionType: 'PAYROLL',
        label: 'Open Payroll Center',
        keywords: ['payroll', 'salary', 'pay slip', 'wage', 'payslip'],
        description: 'Monthly payroll processing & salary dispatches'
    },
    {
        actionType: 'HRMS_MASTERS',
        label: 'Open HRMS Masters',
        keywords: ['designation', 'shifts', 'leave policy', 'hr setup'],
        description: 'HRMS shift schedules and leave master settings'
    },
    {
        actionType: 'CAPTAIN_POS',
        label: 'Open Captain POS',
        keywords: ['table pos', 'captain', 'dining', 'waiter', 'order taking', 'floor plan'],
        description: 'Restaurant table billing & Captain POS'
    },
    {
        actionType: 'KDS',
        label: 'Open Kitchen Display (KDS)',
        keywords: ['kot', 'kitchen', 'kds', 'chef', 'cook', 'kitchen order'],
        description: 'Kitchen Order Tickets (KOT) live screen'
    },
    {
        actionType: 'DELIVERY_CHALLAN',
        label: 'Open Delivery Challans',
        keywords: ['delivery challan', 'dispatch note', 'delivery receipt'],
        description: 'Restaurant & order delivery challans'
    },
    {
        actionType: 'RESTAURANT_SETUP',
        label: 'Open Restaurant Setup',
        keywords: ['floor setup', 'table layout', 'dining setup', 'tables config'],
        description: 'Dining area floors and table configurator'
    },
    {
        actionType: 'RECURRING_EXPENSES',
        label: 'Open Recurring Expenses',
        keywords: ['recurring expense', 'rent', 'electricity', 'utility bill', 'monthly expense'],
        description: 'Automated recurring store expenses'
    },
    {
        actionType: 'WHATSAPP',
        label: 'Open WhatsApp Dashboard',
        keywords: ['whatsapp', 'campaign', 'broadcast', 'text message', 'reminder'],
        description: 'WhatsApp gateway and bulk promotion hub'
    },
    {
        actionType: 'USER_MANAGEMENT',
        label: 'Open User Management',
        keywords: ['user', 'permission', 'role', 'admin access', 'security'],
        description: 'User logins and module security roles'
    },
    {
        actionType: 'SYSTEM_SETTINGS',
        label: 'Open System Settings',
        keywords: ['settings', 'config', 'thermal printer', 'backup', 'system setup'],
        description: 'System hardware and software preferences'
    },
    {
        actionType: 'PROPERTY_INFO',
        label: 'Open Business Profile',
        keywords: ['store profile', 'upi id', 'bank details', 'gstin', 'address', 'header print'],
        description: 'Store business profile, bank account, and UPI details'
    },
    {
        actionType: 'AI_ANALYTICS',
        label: 'Open AI Query Analytics',
        keywords: ['ai analytics', 'sql query', 'custom analytics', 'database search'],
        description: 'Text-to-SQL deep analytics reporting'
    },
    {
        actionType: 'OPERATIONS_INTELLIGENCE',
        label: 'Open Operations Intelligence',
        keywords: ['operations', 'intelligence', 'business insight', 'store health'],
        description: 'AI operational health & automated insights'
    },
    {
        actionType: 'WORKFLOW_AUTOMATION',
        label: 'Open Workflow Automation',
        keywords: ['workflow', 'automation', 'auto trigger', 'rules engine'],
        description: 'Automated event triggers and rules'
    },
    {
        actionType: 'CUSTOMER_LOOKUP',
        label: 'Open Customer Directory',
        keywords: ['customer directory', 'customer app', 'all customers', 'customer list'],
        description: 'Customer list and app directory'
    },
    {
        actionType: 'HELP_SUPPORT',
        label: 'Open Help & User Guide',
        keywords: ['help', 'guide', 'manual', 'support', 'documentation'],
        description: 'User manual and software video guides'
    }
];

const DATABASE_SCHEMA_REGISTRY = `
Schema definitions for Text-to-SQL translation:

1. Table "sales_headers"
   Columns: id (INTEGER, PK), outlet_id (INTEGER), sale_no (VARCHAR), sale_date (TIMESTAMP), customer_id (INTEGER), customer_name (VARCHAR), customer_phone (VARCHAR), customer_address (TEXT), customer_gstin (VARCHAR), payment_mode (VARCHAR), net_amount (DECIMAL), status (VARCHAR)
   Info: Bill receipts. Status can be 'COMPLETED', 'CUSTOMER', 'DRAFT', 'CANCELLED'.

2. Table "sales_items"
   Columns: id (INTEGER, PK), sale_id (INTEGER, FK), item_id (INTEGER, FK), item_code (VARCHAR), item_name (VARCHAR), qty (DECIMAL), rate (DECIMAL), line_total (DECIMAL), net_amount (DECIMAL)
   Info: Bill items. Connects sales_headers.id = sales_items.sale_id and item_master.id = sales_items.item_id.

3. Table "item_master"
   Columns: id (INTEGER, PK), outlet_id (INTEGER), item_code (VARCHAR), item_name (VARCHAR), barcode (VARCHAR), unit (VARCHAR), rate (DECIMAL), retail_sale_price (DECIMAL), item_group (VARCHAR), sub_category (VARCHAR), brand (VARCHAR), min_level (DECIMAL), opening_balance (DECIMAL), is_active (BOOLEAN)
   Info: Catalog products list. "min_level" is reorder stock threshold, "rate" is purchase cost, "retail_sale_price" is selling price, "is_active" is active flag (true/false).

4. Table "milk_subscriptions" (Daily Customer Subscriptions)
   Columns: id (INTEGER, PK), outlet_id (INTEGER), customer_id (INTEGER, FK), customer_name (VARCHAR), phone (VARCHAR), address (TEXT), status (VARCHAR), frequency (VARCHAR), start_date (DATEONLY), end_date (DATEONLY), created_at (TIMESTAMP)
   Info: Customer daily subscriptions for milk, bread, and shop consumables. Status can be 'ACTIVE', 'PAUSED', 'CANCELLED', 'EXPIRED'. Frequency can be 'DAILY', 'ALTERNATE_DAYS', 'WEEKLY'.

5. Table "milk_subscription_items" (Subscription Item Lines)
   Columns: id (INTEGER, PK), subscription_id (INTEGER, FK), item_id (INTEGER, FK), item_code (VARCHAR), item_name (VARCHAR), qty (DECIMAL), rate (DECIMAL), line_total (DECIMAL)
   Info: Items subscribed per customer subscription. Connects to milk_subscriptions.id.

6. Table "milk_subscription_consumptions" (Subscription Daily Delivery Logs)
   Columns: id (INTEGER, PK), subscription_id (INTEGER, FK), delivery_date (DATEONLY), qty_delivered (DECIMAL), status (VARCHAR), remarks (TEXT)
   Info: Daily delivery records for subscription items. Status can be 'DELIVERED', 'SKIPPED', 'CANCELLED'.

7. Table "stock_ledger"
   Columns: id (INTEGER, PK), outlet_id (INTEGER), item_code (VARCHAR), qty_in (DECIMAL), qty_out (DECIMAL), balance (DECIMAL), txn_date (DATEONLY), txn_type (VARCHAR)
   Info: Stock movements audit ledger. Real-time current stock quantity = (COALESCE(item_master.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)). Low stock / reorder items MUST be queried by joining stock_ledger sl ON sl.item_code = im.item_code AND sl.outlet_id = im.outlet_id and checking HAVING net_balance <= COALESCE(im.min_level, 10).

8. Table "goods_receipts" (GRN Purchase Receipts)
   Columns: id (INTEGER, PK), outlet_id (INTEGER), grn_no (VARCHAR), supplier_id (INTEGER, FK), receipt_date (DATEONLY), total_amount (DECIMAL), net_amount (DECIMAL), status (VARCHAR)
   Info: Purchase receiving receipts. Status can be 'SUBMITTED', 'DRAFT', 'CANCELLED'.

9. Table "goods_receipt_items" (GRN Item Details & Expiry)
   Columns: id (INTEGER, PK), grn_id (INTEGER, FK), item_id (INTEGER, FK), item_code (VARCHAR), item_name (VARCHAR), brand (VARCHAR), unit (VARCHAR), qty (DECIMAL), rate (DECIMAL), amount (DECIMAL), expiry_date (DATEONLY)
   Info: Items in GRN receipts containing expiry dates.

10. Table "purchase_orders" (PO to Suppliers)
    Columns: id (INTEGER, PK), outlet_id (INTEGER), po_no (VARCHAR), supplier_id (INTEGER, FK), po_date (DATEONLY), total_amount (DECIMAL), status (VARCHAR)
    Info: Vendor Purchase Orders. Status can be 'OPEN', 'APPROVED', 'CLOSED', 'CANCELLED'.

11. Table "supplier_master"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), supplier_code (VARCHAR), supplier_name (VARCHAR), phone (VARCHAR), gstin (VARCHAR), is_active (BOOLEAN)
    Info: Supplier/Vendor directory.

12. Table "delivery_customers" / "customers"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), first_name (VARCHAR), last_name (VARCHAR), phone (VARCHAR), email (VARCHAR), address (TEXT), is_active (BOOLEAN)
    Info: Store customer directory profiles.

13. Table "hr_employees"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), emp_code (VARCHAR), first_name (VARCHAR), last_name (VARCHAR), phone (VARCHAR), designation (VARCHAR), department (VARCHAR), is_active (BOOLEAN)
    Info: Employee directory. "is_active" flag determines active staff.

14. Table "hr_attendance_punches"
    Columns: id (INTEGER, PK), emp_id (INTEGER, FK), punch_time (TIMESTAMP), punch_type (VARCHAR)
    Info: Staff attendance punch clock log (punch_type: 'IN', 'OUT').

15. Table "whatsapp_logs"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), recipient_phone (VARCHAR), message_type (VARCHAR), delivery_status (VARCHAR), cost (DECIMAL), created_at (TIMESTAMP)
    Info: WhatsApp message dispatches log (delivery_status: 'DELIVERED', 'FAILED', 'PENDING', 'SENT').

16. Table "expenses"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), category_name (VARCHAR), amount (DECIMAL), payment_mode (VARCHAR), expense_date (DATEONLY), remarks (TEXT)
    Info: Operating expenses log.

17. Table "damage_items" / "damaged_stock"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), item_code (VARCHAR), item_name (VARCHAR), qty (DECIMAL), rate (DECIMAL), total_loss (DECIMAL), reason (VARCHAR), damage_date (DATEONLY)
    Info: Damaged, broken, expired, or spoiled inventory items tracking.

18. Table "hr_payrolls" / "salary_dispatches"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), emp_id (INTEGER, FK), emp_name (VARCHAR), month (VARCHAR), year (INTEGER), basic_salary (DECIMAL), allowances (DECIMAL), deductions (DECIMAL), net_salary (DECIMAL), payment_status (VARCHAR)
    Info: Staff monthly salary dispatches and payroll records (payment_status: 'PAID', 'PENDING').

19. Table "cash_ledger" / "cash_entries"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), txn_date (TIMESTAMP), amount_in (DECIMAL), amount_out (DECIMAL), balance (DECIMAL), category (VARCHAR), notes (TEXT)
    Info: Daily cash register transactions, petty cash, and drawer balance entries.

20. Table "kot_headers" / "kitchen_orders"
    Columns: id (INTEGER, PK), outlet_id (INTEGER), kot_no (VARCHAR), table_no (VARCHAR), captain_name (VARCHAR), status (VARCHAR), created_at (TIMESTAMP)
    Info: Restaurant Kitchen Order Tickets (status: 'PENDING', 'COOKING', 'READY', 'SERVED', 'CANCELLED').
`;

function getActionMappingList() {
    return SCREEN_NAVIGATION_REGISTRY.map(s => `- "${s.actionType}" (${s.description})`).join('\n');
}

function matchActionFromQuery(query) {
    const q = (query || '').toLowerCase().trim();
    for (const screen of SCREEN_NAVIGATION_REGISTRY) {
        for (const kw of screen.keywords) {
            if (q.includes(kw)) {
                return {
                    type: screen.actionType,
                    label: screen.label
                };
            }
        }
    }
    return { type: 'NONE' };
}

module.exports = {
    SCREEN_NAVIGATION_REGISTRY,
    DATABASE_SCHEMA_REGISTRY,
    getActionMappingList,
    matchActionFromQuery
};
