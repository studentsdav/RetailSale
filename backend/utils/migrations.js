const migrations = [
  {
    version: 1,
    description: "Initial schema",
    up: async (db) => {

      await db.query(`
BEGIN;

-- -- =========================
-- -- OUTLETS 
-- -- =========================
CREATE TABLE IF NOT EXISTS outlets (
  id SERIAL PRIMARY KEY,
  outlet_code VARCHAR(20) UNIQUE,
  outlet_name VARCHAR(100),
  outlet_type VARCHAR(50),
  contact_email VARCHAR(150),          -- Used to send password reset links or OTPs
  contact_phone VARCHAR(20),           -- Used for SMS verification
  recovery_pin_hash VARCHAR(255),      -- A hashed 4 or 6-digit PIN set during initial setup specifically for recovery
  tax_id VARCHAR(50),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- USERS
-- ===============================

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  mobile VARCHAR(15),
  role VARCHAR(30) NOT NULL,  -- ADMIN, STORE, ACCOUNTS
  is_active BOOLEAN DEFAULT TRUE,
  last_login TIMESTAMP,
  reset_token VARCHAR(255),
  reset_token_expires TIMESTAMP,
  contact_email VARCHAR(150),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ===============================
-- SUPPLIER MASTER
-- ===============================
CREATE TABLE IF NOT EXISTS supplier_master (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),

  supplier_code VARCHAR(30) NOT NULL,
  supplier_name VARCHAR(150) NOT NULL,
  address TEXT,
  phone VARCHAR(20),
  is_active BOOLEAN DEFAULT TRUE,
  tax_id_number VARCHAR(100),
  tax_id_type VARCHAR(50),
   tax_country_code VARCHAR(10),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id, supplier_code)
);


-- ===============================
-- ITEM MASTER
-- ===============================

CREATE TABLE IF NOT EXISTS item_groups (
    id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL,
    group_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS item_subcategories (
    id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL REFERENCES item_groups(id),
    subcategory_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS brands (
    id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL,
    brand_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS item_master (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),

  item_code VARCHAR(30) NOT NULL,
  item_name VARCHAR(150) NOT NULL,

  item_group VARCHAR(100) NOT NULL,
  sub_category VARCHAR(100) NOT NULL,
  brand VARCHAR(100),

  unit VARCHAR(20) NOT NULL,

  rate NUMERIC(12,2) DEFAULT 0,
  opening_balance NUMERIC(12,2) DEFAULT 0,

  min_level INT DEFAULT 0,
  max_level INT DEFAULT 0,

  stockable BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  group_id INTEGER REFERENCES item_groups(id),
  subcategory_id INTEGER REFERENCES item_subcategories(id),
  brand_id INTEGER REFERENCES brands(id),

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id, item_code)
);


-- ===============================
-- SUPPLIER BILL
-- ===============================

CREATE TABLE IF NOT EXISTS supplier_bills (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),
  supplier_id INT NOT NULL REFERENCES supplier_master(id),

  bill_no VARCHAR(50) NOT NULL,
  bill_date DATE NOT NULL,

  bill_amount NUMERIC(12,2) NOT NULL,
  paid_amount NUMERIC(12,2) DEFAULT 0,

  status VARCHAR(20) 
    CHECK (status IN ('PAID','UNPAID','PARTIAL'))
    DEFAULT 'UNPAID',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id, supplier_id, bill_no)
);

-- ===============================
-- SUPPLIER PAYMENT
-- ===============================

CREATE TABLE IF NOT EXISTS supplier_payments (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),
  supplier_id INT NOT NULL REFERENCES supplier_master(id),
  bill_id INT NOT NULL REFERENCES supplier_bills(id),

  payment_date DATE NOT NULL,
  amount NUMERIC(12,2) NOT NULL,

  payment_mode VARCHAR(20)
    CHECK (payment_mode IN ('CASH','CARD','UPI','BANK')),

  reference_no VARCHAR(50),
  created_by INT REFERENCES users(id),

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- STOCK LOCATION MASTER
-- ===============================
CREATE TABLE IF NOT EXISTS stock_locations (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),

  location_code VARCHAR(30) NOT NULL,
  location_name VARCHAR(150) NOT NULL,
  description TEXT,

  is_active BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id, location_code)
);

-- ===============================
-- NUMBERING SETTINGS
-- ===============================
CREATE TABLE IF NOT EXISTS numbering_settings (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),

  module VARCHAR(50) NOT NULL,
  start_date DATE NOT NULL,

  start_no INT NOT NULL,
  prefix VARCHAR(20),
  postfix VARCHAR(20),

  last_used_no INT DEFAULT 0,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id, module)
);

-- ===============================
-- PROPERTY INFORMATION
-- ===============================
CREATE TABLE IF NOT EXISTS property_info (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),

  property_name VARCHAR(150) NOT NULL,
  legal_name VARCHAR(150),

  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  pin_code VARCHAR(10),

  contact_person VARCHAR(100),
  mobile VARCHAR(20),
  email VARCHAR(100),

  gst_no VARCHAR(20),
  pan_no VARCHAR(20),
  fssai_no VARCHAR(30),
  drug_license_no VARCHAR(50),

  logo_path TEXT,

  is_active BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id)
);

-- ===============================
-- SYSTEM / INVENTORY SETTINGS
-- ===============================
CREATE TABLE IF NOT EXISTS system_settings (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL REFERENCES outlets(id),

  auto_reorder BOOLEAN DEFAULT TRUE,
  allow_negative_stock BOOLEAN DEFAULT FALSE,
  damage_approval_required BOOLEAN DEFAULT TRUE,
  enable_audit_log BOOLEAN DEFAULT TRUE,
  auto_print_on_save BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (outlet_id)
);


-- ===============================
-- PERMISSIONS
-- ===============================

CREATE TABLE IF NOT EXISTS permissions (
  id SERIAL PRIMARY KEY,
  perm_key VARCHAR(50) UNIQUE NOT NULL,
  perm_label VARCHAR(100) NOT NULL
);

-- ===============================
-- USER PERMISSIONS
-- ===============================

CREATE TABLE IF NOT EXISTS user_permissions (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  perm_key VARCHAR(50)
);
-- ===============================
-- AUDIT LOG
-- ===============================

CREATE TABLE IF NOT EXISTS audit_logs (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL,
  user_id INT REFERENCES users(id),

  module VARCHAR(50),          -- ITEM_MASTER, ISSUE, RECEIVING, LOGIN, etc
  action VARCHAR(50),          -- CREATE, UPDATE, DELETE, LOGIN, LOGOUT
  table_name VARCHAR(50),
  record_id INT,

  old_data JSONB,              -- before change
  new_data JSONB,              -- after change

  ip_address VARCHAR(45),
  user_agent TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_module ON audit_logs(module);
CREATE INDEX IF NOT EXISTS idx_audit_date ON audit_logs(created_at);



-- ===============================
-- PURCHASE ORDER
-- ===============================

CREATE TABLE IF NOT EXISTS purchase_orders (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL,
  po_no VARCHAR(30) UNIQUE NOT NULL,
  manual_no VARCHAR(30),

  supplier_id INT REFERENCES supplier_master(id),
  po_date DATE NOT NULL,

  total_amount NUMERIC(12,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'OPEN', -- OPEN / CLOSED / CANCELLED

  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- PURCHASE ORDER ITEMS
-- ===============================

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id SERIAL PRIMARY KEY,
  po_id INT REFERENCES purchase_orders(id) ON DELETE CASCADE,
  item_id INT REFERENCES item_master(id),
  item_code VARCHAR(30),
  item_name VARCHAR(150),
  brand VARCHAR(100),
  unit VARCHAR(20),
  qty NUMERIC(12,2) NOT NULL,
  rate NUMERIC(12,2) NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  department VARCHAR(150)
);

-- ===============================
-- RECEIVING RECEIVING
-- ===============================



CREATE TABLE IF NOT EXISTS goods_receipts (
  id SERIAL PRIMARY KEY,

  outlet_id INT NOT NULL,
  grn_no VARCHAR(30) UNIQUE NOT NULL,
  manual_no VARCHAR(30),

  po_no VARCHAR(30),
  supplier_id INT REFERENCES supplier_master(id),

  receipt_date DATE NOT NULL,
  supplier_bill_no VARCHAR(50),

  total_amount NUMERIC(12,2) DEFAULT 0,
  total_gst NUMERIC(12,2) DEFAULT 0,
  net_amount NUMERIC(12,2) DEFAULT 0,

  status VARCHAR(20) DEFAULT 'OPEN', -- OPEN / CLOSE

  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ===============================
-- RECEIVING RECEIVING ITEMS
-- ===============================

CREATE TABLE IF NOT EXISTS goods_receipt_items (
  id SERIAL PRIMARY KEY,

  grn_id INT REFERENCES goods_receipts(id) ON DELETE CASCADE,
  item_code VARCHAR(30),
  item_name VARCHAR(150),
  brand VARCHAR(100),
  unit VARCHAR(20),

  qty NUMERIC(12,2) NOT NULL,
  rate NUMERIC(12,2) NOT NULL,
  tax NUMERIC(5,2) NOT NULL,

  amount NUMERIC(12,2) NOT NULL,
  gst_amount NUMERIC(12,2) NOT NULL,
  expiry_date DATE
);

-- ===============================
-- STOCK LEDGER
-- ===============================


CREATE TABLE IF NOT EXISTS stock_ledger (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL,
  item_code VARCHAR(30),
  txn_date DATE,
  txn_type VARCHAR(20), -- IN / OUT / RETURN / DAMAGE
  ref_no VARCHAR(30),

  qty_in NUMERIC(12,2) DEFAULT 0,
  qty_out NUMERIC(12,2) DEFAULT 0,
  balance NUMERIC(12,2),

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ===============================
-- ISSUE HEADER
-- ===============================

CREATE TABLE IF NOT EXISTS issue_headers (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL,
  issue_no VARCHAR(30) UNIQUE NOT NULL,
  department VARCHAR(100),
  indent_no VARCHAR(50),
  issue_type VARCHAR(30),
  issue_date DATE NOT NULL,
  open_request_no VARCHAR(50),
  status VARCHAR(20) DEFAULT 'OPEN',
  created_by INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- ISSUE ITEMS
-- ===============================

CREATE TABLE IF NOT EXISTS issue_items (
  id SERIAL PRIMARY KEY,
  issue_id INT REFERENCES issue_headers(id) ON DELETE CASCADE,
  item_id INT REFERENCES item_master(id),
  qty NUMERIC(12,2) NOT NULL CHECK (qty > 0),
  rate NUMERIC(12,2) NOT NULL,
  tax NUMERIC(5,2) DEFAULT 0,
  amount NUMERIC(12,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- DAMAGE HEADER
-- ===============================

CREATE TABLE IF NOT EXISTS damage_headers (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL,
  damage_no VARCHAR(30) UNIQUE NOT NULL,
  damage_date DATE NOT NULL,
  total_value NUMERIC(12,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'OPEN',
  created_by INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- DAMAGE ITEMS
-- ===============================

CREATE TABLE IF NOT EXISTS damage_items (
  id SERIAL PRIMARY KEY,
  damage_id INT REFERENCES damage_headers(id) ON DELETE CASCADE,
  item_id INT REFERENCES item_master(id),
  qty NUMERIC(12,2) NOT NULL CHECK (qty > 0),
  rate NUMERIC(12,2) NOT NULL,
  remarks TEXT,
  amount NUMERIC(12,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- RETURN HEADERS
-- ===============================


CREATE TABLE IF NOT EXISTS return_headers (
  id SERIAL PRIMARY KEY,
  return_no VARCHAR(30) UNIQUE NOT NULL,
  issue_id INT NOT NULL REFERENCES issue_headers(id),
  return_date DATE NOT NULL,
  outlet_id INT NOT NULL,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================
-- RETURN ITEMS
-- ===============================

CREATE TABLE IF NOT EXISTS return_items (
  id SERIAL PRIMARY KEY,
  return_id INT NOT NULL REFERENCES return_headers(id) ON DELETE CASCADE,
  issue_item_id INT NOT NULL REFERENCES issue_items(id),
  item_id INT NOT NULL REFERENCES item_master(id),
  qty NUMERIC(12,2) NOT NULL CHECK (qty > 0),
  rate NUMERIC(12,2) NOT NULL
);

-- ===============================
-- REQUEST ITEMS
-- ===============================


CREATE TABLE IF NOT EXISTS request_headers (
  id SERIAL PRIMARY KEY,
  request_no VARCHAR(30) UNIQUE NOT NULL,
  department VARCHAR(100) NOT NULL,
  request_date DATE NOT NULL,
  open_request_no VARCHAR(30),
  status VARCHAR(20) DEFAULT 'OPEN',
  outlet_id INT NOT NULL,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS system_notifications (
    id SERIAL PRIMARY KEY,
    outlet_id INT,
    module VARCHAR(50),
    title VARCHAR(150),
    message TEXT,
    type VARCHAR(30), -- INFO | WARNING | ERROR | SUCCESS
    entity_id INT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);
-- ===============================
-- REQUEST ITEMS
-- ===============================


-- CREATE OR REPLACE FUNCTION notify_low_stock()
-- RETURNS trigger AS $$
-- BEGIN
--    IF NEW.qty < NEW.min_level THEN
--       INSERT INTO system_notifications
--       (outlet_id,module,title,message,type)
--       VALUES
--       (NEW.outlet_id,'STOCK','Low Stock Alert',
--        NEW.item_name || ' below minimum level','WARNING');
--    END IF;

--    RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_low_stock
-- AFTER UPDATE ON stock_balance
-- FOR EACH ROW
-- EXECUTE FUNCTION notify_low_stock();

CREATE TABLE IF NOT EXISTS request_items (
  id SERIAL PRIMARY KEY,
  request_id INT NOT NULL REFERENCES request_headers(id) ON DELETE CASCADE,
  item_id INT NOT NULL REFERENCES item_master(id),
  item_code VARCHAR(30),
  qty NUMERIC(12,2) NOT NULL CHECK (qty > 0),
  rate NUMERIC(12,2) NOT NULL
);


-- ALTER TABLE item_master
-- ADD COLUMN group_id INTEGER REFERENCES item_groups(id),
-- ADD COLUMN subcategory_id INTEGER REFERENCES item_subcategories(id),
-- ADD COLUMN brand_id INTEGER REFERENCES brands(id);

COMMIT;

      `);

    }
  },
  {
    version: 2,
    description: "Add retail item fields",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE item_master
ADD COLUMN IF NOT EXISTS barcode VARCHAR(64),
ADD COLUMN IF NOT EXISTS retail_sale_price NUMERIC(12,2) DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_item_master_barcode
ON item_master(barcode);

COMMIT;
      `);
    }
  },
  {
    version: 3,
    description: "Add sales and sales scheme tables",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE TABLE IF NOT EXISTS sales_headers (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  sale_no VARCHAR(30) NOT NULL,
  sale_date TIMESTAMP NOT NULL,
  customer_name VARCHAR(150),
  customer_phone VARCHAR(20),
  payment_mode VARCHAR(20) DEFAULT 'CASH',
  payment_reference VARCHAR(100),
  scheme_id INT,
  scheme_name VARCHAR(150),
  scheme_discount NUMERIC(12,2) DEFAULT 0,
  manual_discount_type VARCHAR(20),
  manual_discount_value NUMERIC(12,2) DEFAULT 0,
  manual_discount_amount NUMERIC(12,2) DEFAULT 0,
  total_qty NUMERIC(12,2) DEFAULT 0,
  sub_total NUMERIC(12,2) DEFAULT 0,
  total_discount NUMERIC(12,2) DEFAULT 0,
  net_amount NUMERIC(12,2) DEFAULT 0,
  notes TEXT,
  status VARCHAR(20) DEFAULT 'COMPLETED',
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (outlet_id, sale_no)
);

CREATE TABLE IF NOT EXISTS sales_items (
  id SERIAL PRIMARY KEY,
  sale_id INT NOT NULL REFERENCES sales_headers(id) ON DELETE CASCADE,
  item_id INT NOT NULL REFERENCES item_master(id),
  item_code VARCHAR(30) NOT NULL,
  item_name VARCHAR(150) NOT NULL,
  barcode VARCHAR(64),
  unit VARCHAR(20),
  qty NUMERIC(12,2) NOT NULL CHECK (qty > 0),
  rate NUMERIC(12,2) NOT NULL,
  line_discount NUMERIC(12,2) DEFAULT 0,
  amount NUMERIC(12,2) NOT NULL,
  net_amount NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sales_schemes (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  scheme_name VARCHAR(150) NOT NULL,
  scheme_type VARCHAR(20) NOT NULL,
  discount_type VARCHAR(20) NOT NULL,
  discount_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  start_time VARCHAR(5),
  end_time VARCHAR(5),
  min_qty NUMERIC(12,2) DEFAULT 0,
  min_amount NUMERIC(12,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sales_headers_sale_date
ON sales_headers(sale_date);

CREATE INDEX IF NOT EXISTS idx_sales_items_item_code
ON sales_items(item_code);

COMMIT;
      `);
    }
  },
  {
    version: 4,
    description: "Add request approval workflow and sales reporting fields",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE request_headers
ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS approved_by INT REFERENCES users(id),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS rejected_by INT REFERENCES users(id),
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

UPDATE request_headers
SET approval_status = COALESCE(approval_status, 'PENDING')
WHERE approval_status IS NULL;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS customer_address TEXT;

CREATE INDEX IF NOT EXISTS idx_request_headers_approval_status
ON request_headers(approval_status);

CREATE INDEX IF NOT EXISTS idx_request_headers_request_date
ON request_headers(request_date);

CREATE INDEX IF NOT EXISTS idx_sales_headers_customer_phone
ON sales_headers(customer_phone);

CREATE INDEX IF NOT EXISTS idx_sales_headers_customer_name
ON sales_headers(customer_name);

COMMIT;
      `);
    }
  },
  {
    version: 5,
    description: "Add sales order tax and draft support",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS customer_gstin VARCHAR(20),
ADD COLUMN IF NOT EXISTS order_type VARCHAR(20) DEFAULT 'B2C',
ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(7,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS taxable_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS cgst_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS sgst_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS igst_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_tax NUMERIC(12,2) DEFAULT 0;

UPDATE sales_headers
SET order_type = COALESCE(order_type, 'B2C'),
    tax_percent = COALESCE(tax_percent, 0),
    taxable_amount = COALESCE(taxable_amount, net_amount, sub_total, 0),
    cgst_amount = COALESCE(cgst_amount, 0),
    sgst_amount = COALESCE(sgst_amount, 0),
    igst_amount = COALESCE(igst_amount, 0),
    total_tax = COALESCE(total_tax, 0),
    status = COALESCE(status, 'COMPLETED');

CREATE INDEX IF NOT EXISTS idx_sales_headers_status
ON sales_headers(status);

CREATE INDEX IF NOT EXISTS idx_sales_headers_order_type
ON sales_headers(order_type);

COMMIT;
      `);
    }
  },
  {
    version: 6,
    description: "Add global billing tax metadata and default charge settings",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE item_master
ADD COLUMN IF NOT EXISTS tax_type VARCHAR(20) DEFAULT 'GST',
ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(7,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_applicable BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS scheme_applicable BOOLEAN DEFAULT TRUE;

UPDATE item_master
SET tax_type = COALESCE(tax_type, 'GST'),
    tax_percent = COALESCE(tax_percent, 0),
    discount_applicable = COALESCE(discount_applicable, TRUE),
    scheme_applicable = COALESCE(scheme_applicable, TRUE);

ALTER TABLE system_settings
ADD COLUMN IF NOT EXISTS billing_country VARCHAR(80) DEFAULT 'India',
ADD COLUMN IF NOT EXISTS billing_tax_mode VARCHAR(30) DEFAULT 'CGST_SGST',
ADD COLUMN IF NOT EXISTS bill_format VARCHAR(20) DEFAULT 'A4',
ADD COLUMN IF NOT EXISTS default_charges JSONB DEFAULT '[]'::jsonb;

UPDATE system_settings
SET billing_country = COALESCE(billing_country, 'India'),
    billing_tax_mode = COALESCE(billing_tax_mode, 'CGST_SGST'),
    bill_format = COALESCE(bill_format, 'A4'),
    default_charges = COALESCE(default_charges, '[]'::jsonb);

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS billing_country VARCHAR(80) DEFAULT 'India',
ADD COLUMN IF NOT EXISTS billing_tax_mode VARCHAR(30) DEFAULT 'CGST_SGST',
ADD COLUMN IF NOT EXISTS bill_format VARCHAR(20) DEFAULT 'A4',
ADD COLUMN IF NOT EXISTS tax_breakup JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS charges JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS charge_total NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS charge_tax_total NUMERIC(12,2) DEFAULT 0;

UPDATE sales_headers
SET billing_country = COALESCE(billing_country, 'India'),
    billing_tax_mode = COALESCE(billing_tax_mode, 'CGST_SGST'),
    bill_format = COALESCE(bill_format, 'A4'),
    tax_breakup = COALESCE(tax_breakup, '[]'::jsonb),
    charges = COALESCE(charges, '[]'::jsonb),
    charge_total = COALESCE(charge_total, 0),
    charge_tax_total = COALESCE(charge_tax_total, 0);

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS tax_type VARCHAR(20) DEFAULT 'GST',
ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(7,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_applicable BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS scheme_applicable BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS taxable_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS line_total NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_breakup JSONB DEFAULT '[]'::jsonb;

UPDATE sales_items
SET tax_type = COALESCE(tax_type, 'GST'),
    tax_percent = COALESCE(tax_percent, 0),
    discount_applicable = COALESCE(discount_applicable, TRUE),
    scheme_applicable = COALESCE(scheme_applicable, TRUE),
    taxable_amount = COALESCE(taxable_amount, net_amount, amount, 0),
    tax_amount = COALESCE(tax_amount, 0),
    line_total = COALESCE(line_total, net_amount, amount, 0),
    tax_breakup = COALESCE(tax_breakup, '[]'::jsonb);

CREATE INDEX IF NOT EXISTS idx_item_master_tax_type
ON item_master(tax_type);

CREATE INDEX IF NOT EXISTS idx_sales_headers_tax_mode
ON sales_headers(billing_tax_mode);

COMMIT;
      `);
    }
  },
  {
    version: 7,
    description: "Add damage approval workflow",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE damage_headers
ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS approved_by INT REFERENCES users(id),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS rejected_by INT REFERENCES users(id),
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

UPDATE damage_headers
SET approval_status = COALESCE(approval_status, 'PENDING')
WHERE approval_status IS NULL;

CREATE INDEX IF NOT EXISTS idx_damage_headers_approval_status
ON damage_headers(approval_status);

CREATE INDEX IF NOT EXISTS idx_damage_headers_damage_date
ON damage_headers(damage_date);

COMMIT;
      `);
    }
  },

  {
    version: 9,
    description: "Add hsncode item fields",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE item_master
ADD COLUMN IF NOT EXISTS hsn_sac_code VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_hsn_sac_code
ON item_master(hsn_sac_code);

COMMIT;
      `);
    }
  },

  {
    version: 10,
    description: "Add HSN/SAC support to sales items",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS hsn_sac_code VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_sales_items_hsn_sac_code
ON sales_items(hsn_sac_code);

COMMIT;
      `);
    }
  },
  {
    version: 11,
    description: "Add voucher persistence and sales voucher fields",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE system_settings
ADD COLUMN IF NOT EXISTS voucher_rules JSONB DEFAULT '[]'::jsonb;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS voucher_code VARCHAR(80),
ADD COLUMN IF NOT EXISTS voucher_label VARCHAR(150);

CREATE INDEX IF NOT EXISTS idx_sales_headers_voucher_code
ON sales_headers(voucher_code);

COMMIT;
      `);
    }
  },
  {
    version: 12,
    description: "Add printer settings to system settings",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE system_settings
ADD COLUMN IF NOT EXISTS print_mode VARCHAR(30) DEFAULT 'PRINT_DIALOG',
ADD COLUMN IF NOT EXISTS default_printer_name VARCHAR(255) DEFAULT '',
ADD COLUMN IF NOT EXISTS default_printer_url VARCHAR(500) DEFAULT '';

COMMIT;
      `);
    }
  },
  {
    version: 13,
    description: "Add vendor, finance ledger, expense, and tax consistency fields",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE supplier_master
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS gstin VARCHAR(20);

UPDATE supplier_master
SET gstin = COALESCE(NULLIF(TRIM(gstin), ''), NULLIF(TRIM(tax_id_number), ''))
WHERE gstin IS NULL;

ALTER TABLE supplier_master
ALTER COLUMN address SET NOT NULL;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS change_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS balance_due NUMERIC(12,2) DEFAULT 0;

UPDATE sales_headers
SET amount_paid = COALESCE(amount_paid, CASE WHEN COALESCE(payment_mode, 'CASH') = 'CREDIT' THEN 0 ELSE COALESCE(net_amount, 0) END),
    change_amount = COALESCE(change_amount, 0),
    balance_due = COALESCE(balance_due, CASE WHEN COALESCE(payment_mode, 'CASH') = 'CREDIT' THEN COALESCE(net_amount, 0) ELSE 0 END);

ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS tax NUMERIC(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_after_tax NUMERIC(12,2) DEFAULT 0;

UPDATE purchase_order_items
SET tax = COALESCE(tax, 0),
    tax_amount = COALESCE(tax_amount, (COALESCE(qty, 0) * COALESCE(rate, 0)) * COALESCE(tax, 0) / 100),
    total_after_tax = COALESCE(total_after_tax, (COALESCE(qty, 0) * COALESCE(rate, 0)) + COALESCE(tax_amount, 0));

ALTER TABLE goods_receipt_items
ADD COLUMN IF NOT EXISTS item_id INT REFERENCES item_master(id),
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_after_tax NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS department VARCHAR(150);

UPDATE goods_receipt_items gri
SET item_id = COALESCE(gri.item_id, im.id),
    tax_amount = COALESCE(gri.tax_amount, COALESCE(gri.gst_amount, 0)),
    total_after_tax = COALESCE(gri.total_after_tax, COALESCE(gri.amount, 0) + COALESCE(gri.gst_amount, 0))
FROM item_master im
WHERE im.item_code = gri.item_code;

CREATE TABLE IF NOT EXISTS cash_ledger (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  txn_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  transaction_type VARCHAR(50) NOT NULL,
  reference_type VARCHAR(50),
  reference_id INT,
  reference_no VARCHAR(50),
  party_name VARCHAR(150),
  payment_method VARCHAR(20),
  amount_in NUMERIC(12,2) DEFAULT 0,
  amount_out NUMERIC(12,2) DEFAULT 0,
  adjustment_amount NUMERIC(12,2) DEFAULT 0,
  balance NUMERIC(12,2) DEFAULT 0,
  notes TEXT,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cash_ledger_outlet_date
ON cash_ledger(outlet_id, txn_date);

CREATE TABLE IF NOT EXISTS expense_entries (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  expense_date DATE NOT NULL,
  category VARCHAR(100) NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  note TEXT,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expense_entries_outlet_date
ON expense_entries(outlet_id, expense_date);

CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_master_name
ON supplier_master(outlet_id, lower(supplier_name));

CREATE UNIQUE INDEX IF NOT EXISTS uq_item_master_name
ON item_master(outlet_id, lower(item_name));

CREATE UNIQUE INDEX IF NOT EXISTS uq_item_groups_name
ON item_groups(outlet_id, lower(group_name));

CREATE UNIQUE INDEX IF NOT EXISTS uq_item_subcategories_name
ON item_subcategories(outlet_id, group_id, lower(subcategory_name));

CREATE UNIQUE INDEX IF NOT EXISTS uq_brands_name
ON brands(outlet_id, lower(brand_name));

COMMIT;
      `);
    }
  },
  {
    version: 14,
    description: "Add supplier purchase return and refund tracking",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE TABLE IF NOT EXISTS supplier_return_headers (
  id SERIAL PRIMARY KEY,
  return_no VARCHAR(30) NOT NULL,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  supplier_id INT NOT NULL REFERENCES supplier_master(id),
  grn_id INT NOT NULL REFERENCES goods_receipts(id),
  return_date DATE NOT NULL,
  total_amount NUMERIC(12,2) DEFAULT 0,
  refunded_amount NUMERIC(12,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'PENDING'
    CHECK (status IN ('PENDING','PARTIAL','REFUNDED','CANCELLED')),
  notes TEXT,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_return_no
ON supplier_return_headers(outlet_id, return_no);

CREATE INDEX IF NOT EXISTS idx_supplier_return_headers_date
ON supplier_return_headers(outlet_id, return_date);

CREATE TABLE IF NOT EXISTS supplier_return_items (
  id SERIAL PRIMARY KEY,
  return_id INT NOT NULL REFERENCES supplier_return_headers(id) ON DELETE CASCADE,
  receipt_item_id INT NOT NULL REFERENCES goods_receipt_items(id),
  item_id INT REFERENCES item_master(id),
  item_code VARCHAR(30),
  item_name VARCHAR(150),
  unit VARCHAR(20),
  qty NUMERIC(12,2) NOT NULL,
  rate NUMERIC(12,2) NOT NULL,
  amount NUMERIC(12,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_supplier_return_items_return
ON supplier_return_items(return_id);

CREATE TABLE IF NOT EXISTS supplier_return_refunds (
  id SERIAL PRIMARY KEY,
  return_id INT NOT NULL REFERENCES supplier_return_headers(id) ON DELETE CASCADE,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  supplier_id INT NOT NULL REFERENCES supplier_master(id),
  refund_date DATE NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  payment_mode VARCHAR(20)
    CHECK (payment_mode IN ('CASH','CARD','UPI','BANK')),
  reference_no VARCHAR(50),
  notes TEXT,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_supplier_return_refunds_return
ON supplier_return_refunds(return_id, refund_date);

COMMIT;
      `);
    }
  },
  {
    version: 15,
    description: "Add sales bill revision tracking for reprint and modify flow",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS original_sale_id INT REFERENCES sales_headers(id),
ADD COLUMN IF NOT EXISTS previous_sale_id INT REFERENCES sales_headers(id),
ADD COLUMN IF NOT EXISTS replaced_by_sale_id INT REFERENCES sales_headers(id),
ADD COLUMN IF NOT EXISTS version_no INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS is_latest BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS modified_by INT REFERENCES users(id),
ADD COLUMN IF NOT EXISTS modified_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS modification_note TEXT;

UPDATE sales_headers
SET original_sale_id = COALESCE(original_sale_id, id),
    version_no = COALESCE(version_no, 1),
    is_latest = COALESCE(is_latest, TRUE),
    is_deleted = COALESCE(is_deleted, FALSE);

ALTER TABLE sales_headers
DROP CONSTRAINT IF EXISTS sales_headers_outlet_id_sale_no_key;

CREATE INDEX IF NOT EXISTS idx_sales_headers_original_sale
ON sales_headers(original_sale_id);

CREATE INDEX IF NOT EXISTS idx_sales_headers_latest_lookup
ON sales_headers(outlet_id, is_latest, is_deleted, sale_date DESC);

CREATE INDEX IF NOT EXISTS idx_sales_headers_sale_no_lookup
ON sales_headers(outlet_id, sale_no);

COMMIT;
      `);
    }
  },
  {
    version: 16,
    description: "Add customer repayments, day opening balances, and credit finance fields",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS initial_amount_paid NUMERIC(12,2) DEFAULT 0;

UPDATE sales_headers
SET initial_amount_paid = COALESCE(initial_amount_paid, amount_paid, 0)
WHERE initial_amount_paid IS NULL
   OR initial_amount_paid = 0;

CREATE TABLE IF NOT EXISTS customer_repayments (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  sale_id INT NOT NULL REFERENCES sales_headers(id) ON DELETE CASCADE,
  payment_date DATE NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_mode VARCHAR(20) NOT NULL,
  reference_no VARCHAR(100),
  note TEXT,
  created_by INT REFERENCES users(id),
  updated_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_customer_repayments_sale
ON customer_repayments(sale_id, payment_date, id);

CREATE INDEX IF NOT EXISTS idx_customer_repayments_outlet_date
ON customer_repayments(outlet_id, payment_date);

CREATE TABLE IF NOT EXISTS daily_opening_balances (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  balance_date DATE NOT NULL,
  opening_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
  note TEXT,
  created_by INT REFERENCES users(id),
  updated_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (outlet_id, balance_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_opening_balances_outlet_date
ON daily_opening_balances(outlet_id, balance_date);

CREATE INDEX IF NOT EXISTS idx_sales_headers_balance_due
ON sales_headers(outlet_id, balance_due, sale_date);

COMMIT;
      `);
    }
  },
  {
    version: 17,
    description: "Expand payment reference storage for multi payment entries",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_headers
ALTER COLUMN payment_reference TYPE TEXT;

COMMIT;
      `);
    }
  },
  {
    version: 18,
    description: "Add customer advances for extra payment carry forward",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE TABLE IF NOT EXISTS customer_advances (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  source_sale_id INT REFERENCES sales_headers(id) ON DELETE SET NULL,
  customer_name VARCHAR(150),
  customer_phone VARCHAR(20),
  customer_gstin VARCHAR(20),
  advance_date DATE NOT NULL,
  original_amount NUMERIC(12,2) NOT NULL CHECK (original_amount > 0),
  available_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (available_amount >= 0),
  payment_mode VARCHAR(20) NOT NULL,
  reference_no VARCHAR(100),
  note TEXT,
  created_by INT REFERENCES users(id),
  updated_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_customer_advances_customer
ON customer_advances(outlet_id, customer_phone, customer_gstin, advance_date, id);

CREATE INDEX IF NOT EXISTS idx_customer_advances_available
ON customer_advances(outlet_id, available_amount, advance_date);

COMMIT;
      `);
    }
  },
  {
    version: 19,
    description: "Add per-item open close status for purchase orders and requests",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS line_status VARCHAR(20) DEFAULT 'CLOSED';

UPDATE purchase_order_items
SET line_status = COALESCE(line_status, 'CLOSED');

ALTER TABLE request_items
ADD COLUMN IF NOT EXISTS line_status VARCHAR(20) DEFAULT 'CLOSED';

UPDATE request_items
SET line_status = COALESCE(line_status, 'CLOSED');

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_line_status
ON purchase_order_items(po_id, line_status);

CREATE INDEX IF NOT EXISTS idx_request_items_line_status
ON request_items(request_id, line_status);

COMMIT;
      `);
    }
  },
  {
    version: 20,
    description: "Allow multiple numbering rows per module by start date",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE numbering_settings
DROP CONSTRAINT IF EXISTS numbering_settings_outlet_id_module_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_numbering_settings_module_start
ON numbering_settings(outlet_id, module, start_date);

COMMIT;
      `);
    }
  },

  {
    version: 21,
    description: "Retailer item-cycle schemes and item advancese",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS scheme_scope VARCHAR(20) DEFAULT 'ORDER',
ADD COLUMN IF NOT EXISTS item_id INT REFERENCES item_master(id),
ADD COLUMN IF NOT EXISTS free_qty NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS cycle_days INT DEFAULT 30,
ADD COLUMN IF NOT EXISTS require_no_gaps BOOLEAN DEFAULT FALSE;

-- Older installs may have sales_schemes without is_active; keep queries/indexes stable.
ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_sales_schemes_scope
ON sales_schemes(outlet_id, scheme_scope, scheme_type, is_active);

COMMIT;
      `);
    }
  },



  {
    version: 22,
    description: "Retailer item-cycle schemes and item advances",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE TABLE IF NOT EXISTS sales_scheme_customers (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  scheme_id INT NOT NULL REFERENCES sales_schemes(id) ON DELETE CASCADE,
  customer_name VARCHAR(150),
  customer_phone VARCHAR(20),
  customer_gstin VARCHAR(20),
  start_date DATE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);



CREATE TABLE IF NOT EXISTS customer_item_advances (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  source_sale_id INT REFERENCES sales_headers(id) ON DELETE SET NULL,
  customer_name VARCHAR(150),
  customer_phone VARCHAR(20),
  customer_gstin VARCHAR(20),
  item_id INT NOT NULL REFERENCES item_master(id),
  advance_date DATE NOT NULL,
  original_qty NUMERIC(12,2) NOT NULL CHECK (original_qty > 0),
  available_qty NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (available_qty >= 0),
  rate NUMERIC(12,2) DEFAULT 0,
  note TEXT,
  created_by INT REFERENCES users(id),
  updated_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMIT;
      `);
    }
  },

  {
    version: 23,
    description: "Retailer item-cycle schemes and item advancese",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE INDEX IF NOT EXISTS idx_sales_scheme_customers_lookup
ON sales_scheme_customers(outlet_id, scheme_id, is_active, customer_phone, customer_gstin, customer_name);

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS is_scheme_free BOOLEAN DEFAULT FALSE;

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS applied_scheme_id INT REFERENCES sales_schemes(id);

CREATE INDEX IF NOT EXISTS idx_sales_items_scheme_free
ON sales_items(sale_id, is_scheme_free, applied_scheme_id);

CREATE INDEX IF NOT EXISTS idx_customer_item_advances_customer
ON customer_item_advances(outlet_id, customer_phone, customer_gstin, advance_date, id);

CREATE INDEX IF NOT EXISTS idx_customer_item_advances_available
ON customer_item_advances(outlet_id, item_id, available_qty, advance_date);

COMMIT;
      `);
    }
  },

  {
    version: 24,
    description: "Track item-advance consumption in sales items",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS is_advance_free BOOLEAN DEFAULT FALSE;

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS item_advance_qty DECIMAL(12, 2) DEFAULT 0;

ALTER TABLE sales_items
ADD COLUMN IF NOT EXISTS item_advance_amount DECIMAL(12, 2) DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_sales_items_advance_free
ON sales_items(sale_id, is_advance_free);

COMMIT;
      `);
    }
  },
  {
    version: 25,
    description: "Item images and sales image toggle",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE item_master
ADD COLUMN IF NOT EXISTS image_path TEXT;

ALTER TABLE system_settings
ADD COLUMN IF NOT EXISTS enable_item_images_in_sales BOOLEAN DEFAULT FALSE;

COMMIT;
      `);
    }
  },
  {
    version: 26,
    description: "Alter system_settings",
    up: async (db) => {
      await db.query(`
        BEGIN;
        -- Changed to snake_case to match your other columns
        ALTER TABLE system_settings ADD COLUMN is_cloud_enabled BOOLEAN DEFAULT FALSE;
        COMMIT;
      `);
    }
  },
  {
    version: 27,
    description: "Milk subscription billing and settlement",
    up: async (db) => {
      await db.query(`
        BEGIN;
      
CREATE TABLE IF NOT EXISTS milk_subscriptions (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  customer_name VARCHAR(150),
  customer_phone VARCHAR(20),
  customer_gstin VARCHAR(20),
  customer_address TEXT,
  item_id INT NOT NULL REFERENCES item_master(id),
  item_name VARCHAR(150),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  daily_allowed_qty NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (daily_allowed_qty >= 0),
  total_payment_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_payment_amount >= 0),
  scheme_discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  bonus_qty NUMERIC(12,2) NOT NULL DEFAULT 0,
  selected_schemes JSONB NOT NULL DEFAULT '[]'::jsonb,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  active_subscription BOOLEAN NOT NULL DEFAULT TRUE,
  settled_at TIMESTAMP,
  created_by INT REFERENCES users(id),
  updated_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS milk_subscription_schemes (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  subscription_id INT NOT NULL REFERENCES milk_subscriptions(id) ON DELETE CASCADE,
  scheme_type VARCHAR(40) NOT NULL,
  scheme_name VARCHAR(150),
  scheme_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  bonus_qty NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
        COMMIT;
      `);
    }
  },

  {
    version: 28,
    description: "Milk subscription billing and settlement",
    up: async (db) => {
      await db.query(`
        BEGIN;
      
CREATE TABLE IF NOT EXISTS milk_subscription_settlements (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  subscription_id INT NOT NULL REFERENCES milk_subscriptions(id) ON DELETE CASCADE,
  settlement_no VARCHAR(50),
  settlement_date DATE NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  gross_excess_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  scheme_discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  bonus_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_due NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
        COMMIT;
      `);
    }
  },

  {
    version: 29,
    description: "Milk subscription billing and settlement",
    up: async (db) => {
      await db.query(`
BEGIN;


CREATE TABLE IF NOT EXISTS milk_subscription_consumptions (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  subscription_id INT NOT NULL REFERENCES milk_subscriptions(id) ON DELETE CASCADE,
  sale_id INT REFERENCES sales_headers(id) ON DELETE SET NULL,
  sale_no VARCHAR(50),
  txn_date DATE NOT NULL,
  item_id INT NOT NULL REFERENCES item_master(id),
  item_name VARCHAR(150),
  cart_qty NUMERIC(12,2) NOT NULL DEFAULT 0,
  covered_qty NUMERIC(12,2) NOT NULL DEFAULT 0,
  excess_qty NUMERIC(12,2) NOT NULL DEFAULT 0,
  daily_allowed_qty NUMERIC(12,2) NOT NULL DEFAULT 0,
  rate NUMERIC(12,2) NOT NULL DEFAULT 0,
  covered_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  excess_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  settlement_id INT REFERENCES milk_subscription_settlements(id) ON DELETE SET NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMIT;
      `);
    }
  },
  {
    version: 30,
    description: "Milk subscription billing and settlement",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE INDEX IF NOT EXISTS idx_milk_subscriptions_customer
ON milk_subscriptions(outlet_id, customer_phone, customer_gstin, customer_name, status, active_subscription);

CREATE INDEX IF NOT EXISTS idx_milk_subscriptions_item
ON milk_subscriptions(outlet_id, item_id, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_milk_subscription_consumptions_lookup
ON milk_subscription_consumptions(outlet_id, subscription_id, txn_date, item_id, status);

CREATE INDEX IF NOT EXISTS idx_milk_subscription_consumptions_sale
ON milk_subscription_consumptions(outlet_id, sale_id);

CREATE INDEX IF NOT EXISTS idx_milk_subscription_settlements_lookup
ON milk_subscription_settlements(outlet_id, subscription_id, settlement_date);

COMMIT;
      `);
    }
  },
  {
    version: 31,
    description: "Scheme repeat and per-day quantity controls",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS required_daily_qty NUMERIC(12,2) DEFAULT 0;

ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS repeat_mode VARCHAR(20) DEFAULT 'REPEAT';

ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS apply_timing VARCHAR(20) DEFAULT 'CURRENT_BILL';

ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS auto_select_on_customer BOOLEAN DEFAULT TRUE;

ALTER TABLE sales_schemes
ADD COLUMN IF NOT EXISTS next_purchase_valid_days INT DEFAULT 7;

UPDATE sales_schemes
SET required_daily_qty = COALESCE(required_daily_qty, 0),
    repeat_mode = COALESCE(repeat_mode, 'REPEAT'),
    apply_timing = COALESCE(apply_timing, 'CURRENT_BILL'),
    auto_select_on_customer = COALESCE(auto_select_on_customer, TRUE),
    next_purchase_valid_days = COALESCE(next_purchase_valid_days, 7);

COMMIT;
      `);
    }
  },
  {
    version: 32,
    description: "Track scheme cycle grants for one-time schemes",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_scheme_customers
ADD COLUMN IF NOT EXISTS last_applied_cycle_start DATE;

ALTER TABLE sales_scheme_customers
ADD COLUMN IF NOT EXISTS last_applied_cycle_end DATE;

COMMIT;
      `);
    }
  },
  {
    version: 33,
    description: "Track single-use customer schemes",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_scheme_customers
ADD COLUMN IF NOT EXISTS usage_type VARCHAR(30) DEFAULT 'reusable';

ALTER TABLE sales_scheme_customers
ADD COLUMN IF NOT EXISTS is_consumed BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_sales_scheme_customers_consumed
ON sales_scheme_customers(outlet_id, scheme_id, usage_type, is_consumed, customer_phone, customer_gstin, customer_name);

COMMIT;
      `);
    }
  },
  {
    version: 34,
    description: "Add subscription settlement payment tracking",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE milk_subscription_settlements
ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(20) DEFAULT 'CASH';

ALTER TABLE milk_subscription_settlements
ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(12,2) DEFAULT 0;

ALTER TABLE milk_subscription_settlements
ADD COLUMN IF NOT EXISTS balance_due NUMERIC(12,2) DEFAULT 0;

ALTER TABLE milk_subscription_settlements
ADD COLUMN IF NOT EXISTS advance_amount NUMERIC(12,2) DEFAULT 0;

UPDATE milk_subscription_settlements
SET payment_mode = COALESCE(payment_mode, 'CASH'),
    amount_paid = COALESCE(amount_paid, 0),
    balance_due = COALESCE(balance_due, 0),
    advance_amount = COALESCE(advance_amount, 0);

COMMIT;
      `);
    }
  },
  {
    version: 35,
    description: "Add sales round-off tracking column",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS round_off_amount NUMERIC(12,2) DEFAULT 0;

UPDATE sales_headers
SET round_off_amount = COALESCE(round_off_amount, 0);

COMMIT;
      `);
    }
  },
  {
    version: 36,
    description: "Loyalty program configuration, ledger, and sales loyalty fields",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE TABLE IF NOT EXISTS loyalty_master_config (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  program_status BOOLEAN NOT NULL DEFAULT FALSE,
  start_date DATE,
  end_date DATE,
  min_purchase_threshold NUMERIC(12,2) NOT NULL DEFAULT 0,
  earning_ratio NUMERIC(12,2) NOT NULL DEFAULT 1000,
  redemption_value NUMERIC(12,2) NOT NULL DEFAULT 1,
  max_redeem_per_bill INT NOT NULL DEFAULT 0,
  point_expiry_days INT NOT NULL DEFAULT 90,
  created_by INT REFERENCES users(id),
  updated_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (outlet_id)
);

CREATE TABLE IF NOT EXISTS customer_loyalty_ledger (
  id SERIAL PRIMARY KEY,
  outlet_id INT NOT NULL REFERENCES outlets(id),
  customer_name VARCHAR(150),
  customer_phone VARCHAR(20),
  customer_gstin VARCHAR(20),
  customer_key VARCHAR(220) NOT NULL,
  transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  transaction_type VARCHAR(20) NOT NULL
    CHECK (transaction_type IN ('EARNED','REDEEMED','EXPIRED')),
  points_delta INT NOT NULL,
  points_balance_after INT NOT NULL DEFAULT 0,
  bill_number VARCHAR(50),
  sale_id INT REFERENCES sales_headers(id) ON DELETE SET NULL,
  expiry_date DATE,
  available_points INT NOT NULL DEFAULT 0,
  source_ledger_id INT REFERENCES customer_loyalty_ledger(id) ON DELETE SET NULL,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by INT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_loyalty_customer_lookup
ON customer_loyalty_ledger(outlet_id, customer_key, transaction_date, id);

CREATE INDEX IF NOT EXISTS idx_loyalty_expiry_lookup
ON customer_loyalty_ledger(outlet_id, transaction_type, expiry_date, available_points);

CREATE INDEX IF NOT EXISTS idx_loyalty_sale_lookup
ON customer_loyalty_ledger(outlet_id, sale_id, transaction_type);

CREATE UNIQUE INDEX IF NOT EXISTS uq_loyalty_sale_earned_once
ON customer_loyalty_ledger(outlet_id, sale_id, transaction_type)
WHERE transaction_type IN ('EARNED', 'REDEEMED') AND sale_id IS NOT NULL;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS loyalty_points_earned INT NOT NULL DEFAULT 0;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS loyalty_points_redeemed INT NOT NULL DEFAULT 0;

ALTER TABLE sales_headers
ADD COLUMN IF NOT EXISTS loyalty_discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0;

COMMIT;
      `);
    }
  },
  {
    version: 37,
    description: "Pack to loose stock conversion support for item master",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE item_master
ADD COLUMN IF NOT EXISTS pack_qty NUMERIC(12,2) NOT NULL DEFAULT 0;

ALTER TABLE item_master
ADD COLUMN IF NOT EXISTS loose_item_code VARCHAR(30);

CREATE INDEX IF NOT EXISTS idx_item_master_loose_item_code
ON item_master(loose_item_code);

UPDATE item_master
SET pack_qty = COALESCE(pack_qty, 0),
    loose_item_code = NULLIF(TRIM(loose_item_code), '');

COMMIT;
      `);
    }
  },
  {
    version: 38,
    description: "Receiving item remarks support",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE goods_receipt_items
ADD COLUMN IF NOT EXISTS remarks TEXT;

COMMIT;
      `);
    }
  },
  {
    version: 39,
    description: "Add credit_adjusted to supplier_payments and allow CREDIT payment mode",
    up: async (db) => {
      await db.query(`
BEGIN;

ALTER TABLE supplier_payments ADD COLUMN IF NOT EXISTS credit_adjusted NUMERIC(12,2) DEFAULT 0;

ALTER TABLE supplier_payments DROP CONSTRAINT IF EXISTS supplier_payments_payment_mode_check;
ALTER TABLE supplier_payments ADD CONSTRAINT supplier_payments_payment_mode_check CHECK (payment_mode IN ('CASH','CARD','UPI','BANK','CREDIT'));

ALTER TABLE supplier_return_refunds DROP CONSTRAINT IF EXISTS supplier_return_refunds_payment_mode_check;
ALTER TABLE supplier_return_refunds ADD CONSTRAINT supplier_return_refunds_payment_mode_check CHECK (payment_mode IN ('CASH','CARD','UPI','BANK','CREDIT'));

COMMIT;
      `);
    }
  },
  {
    version: 40,
    description: "Add tables for item BOMs and product assembly tracking",
    up: async (db) => {
      await db.query(`
BEGIN;

CREATE TABLE IF NOT EXISTS item_boms (
    id SERIAL PRIMARY KEY,
    outlet_id INT NOT NULL,
    parent_item_id INT NOT NULL REFERENCES item_master(id) ON DELETE CASCADE,
    component_item_id INT NOT NULL REFERENCES item_master(id) ON DELETE CASCADE,
    quantity NUMERIC(12,4) NOT NULL DEFAULT 1.0000,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_item_boms UNIQUE(outlet_id, parent_item_id, component_item_id)
);

CREATE TABLE IF NOT EXISTS assembly_headers (
    id SERIAL PRIMARY KEY,
    outlet_id INT NOT NULL,
    assembly_no VARCHAR(50) NOT NULL,
    assembly_date DATE NOT NULL,
    parent_item_id INT NOT NULL REFERENCES item_master(id),
    qty NUMERIC(12,2) NOT NULL,
    composite_cost NUMERIC(12,2) NOT NULL,
    total_cost NUMERIC(12,2) NOT NULL,
    notes TEXT,
    created_by INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS assembly_items (
    id SERIAL PRIMARY KEY,
    outlet_id INT NOT NULL,
    assembly_id INT NOT NULL REFERENCES assembly_headers(id) ON DELETE CASCADE,
    component_item_id INT NOT NULL REFERENCES item_master(id),
    qty_required NUMERIC(12,4) NOT NULL,
    qty_used NUMERIC(12,4) NOT NULL,
    rate NUMERIC(12,2) NOT NULL,
    total_cost NUMERIC(12,2) NOT NULL
);

COMMIT;
      `);
    }
  },
  {
    version: 41,
    description: "Add status column to assembly_headers",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE assembly_headers ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'RUNNING';
        COMMIT;
      `);
    }
  },
  {
    version: 42,
    description: "Add sales_credit_notes table for sales returns and credit notes",
    up: async (db) => {
      await db.query(`
        BEGIN;
        CREATE TABLE IF NOT EXISTS sales_credit_notes (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id),
            sale_id INTEGER NOT NULL REFERENCES sales_headers(id) ON DELETE CASCADE,
            credit_note_no VARCHAR(50) NOT NULL UNIQUE,
            credit_note_date DATE NOT NULL,
            customer_name VARCHAR(150),
            customer_phone VARCHAR(20),
            customer_gstin VARCHAR(20),
            items JSONB NOT NULL,
            total_qty DECIMAL(12, 2) NOT NULL DEFAULT 0,
            sub_total DECIMAL(12, 2) NOT NULL DEFAULT 0,
            taxable_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
            cgst_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
            sgst_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
            igst_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
            total_tax DECIMAL(12, 2) NOT NULL DEFAULT 0,
            net_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
            reason VARCHAR(100),
            status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
            notes TEXT,
            created_by INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_sales_credit_notes_sale_id ON sales_credit_notes(sale_id);
        CREATE INDEX IF NOT EXISTS idx_sales_credit_notes_outlet_id ON sales_credit_notes(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_sales_credit_notes_credit_note_date ON sales_credit_notes(credit_note_date);
        COMMIT;
      `);
    }
  },
  {
    version: 43,
    description: "Add is_saleable column to item_master",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_saleable BOOLEAN DEFAULT TRUE;
        COMMIT;
      `);
    }
  },
  {
    version: 44,
    description: "Add delivery partner and customer order tables",
    up: async (db) => {
      await db.query(`
        BEGIN;

        CREATE TABLE IF NOT EXISTS delivery_partners (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id),
            name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NOT NULL,
            status VARCHAR(20) DEFAULT 'AVAILABLE',
            latitude DECIMAL(10, 6) DEFAULT 0.000000,
            longitude DECIMAL(10, 6) DEFAULT 0.000000,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS customer_orders (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id),
            customer_name VARCHAR(150) NOT NULL,
            customer_phone VARCHAR(20) NOT NULL,
            customer_address TEXT NOT NULL,
            items JSONB NOT NULL,
            sub_total DECIMAL(12, 2) DEFAULT 0.00,
            tax_amount DECIMAL(12, 2) DEFAULT 0.00,
            delivery_charge DECIMAL(12, 2) DEFAULT 0.00,
            net_amount DECIMAL(12, 2) DEFAULT 0.00,
            payment_status VARCHAR(20) DEFAULT 'UNPAID',
            status VARCHAR(30) DEFAULT 'PENDING',
            assigned_partner_id INTEGER REFERENCES delivery_partners(id) ON DELETE SET NULL,
            assigned_at TIMESTAMP,
            picked_up_at TIMESTAMP,
            delivered_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_delivery_partners_outlet ON delivery_partners(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_customer_orders_outlet ON customer_orders(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_customer_orders_status ON customer_orders(status);

        COMMIT;
      `);
    }
  },
  {
    version: 45,
    description: "Add delivery customers table for customer login and history tracking",
    up: async (db) => {
      await db.query(`
        BEGIN;

        CREATE TABLE IF NOT EXISTS delivery_customers (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id),
            name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            address TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_delivery_customers UNIQUE (outlet_id, phone)
        );

        CREATE INDEX IF NOT EXISTS idx_delivery_customers_phone ON delivery_customers(phone);

        COMMIT;
      `);
    }
  },
  {
    version: 46,
    description: "Add payment_mode, commission_amount, and commission_status to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(20) DEFAULT 'CASH';
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS commission_amount DECIMAL(12, 2) DEFAULT 20.00;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS commission_status VARCHAR(30) DEFAULT 'UNPAID';
        COMMIT;
      `);
    }
  },
  {
    version: 47,
    description: "Add return_status, return_type, and refund_status to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS return_status VARCHAR(50) DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS return_type VARCHAR(50) DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS refund_status VARCHAR(50) DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 48,
    description: "Add return_item_id and return_item_name to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS return_item_id INTEGER DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS return_item_name VARCHAR(255) DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 49,
    description: "Add returned_items JSONB column to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS returned_items JSONB DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 50,
    description: "Add password_hash column to delivery_partners table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 51,
    description: "Add b2b_rate to item_master and gstin to customer_orders",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS b2b_rate NUMERIC(12, 2) DEFAULT 0;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS gstin VARCHAR(50) DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 52,
    description: "Add return_window_days to item_master for per-item return window control",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS return_window_days INTEGER DEFAULT 7;
        COMMIT;
      `);
    }
  },
  {
    version: 53,
    description: "Create outlet_settings table for store settings",
    up: async (db) => {
      await db.query(`
        BEGIN;
        CREATE TABLE IF NOT EXISTS outlet_settings (
          id SERIAL PRIMARY KEY,
          outlet_id INT NOT NULL REFERENCES outlets(id),
          meta_data JSONB DEFAULT '{}',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE (outlet_id)
        );
        COMMIT;
      `);
    }
  },
  {
    version: 54,
    description: "Add charges jsonb column to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS charges JSONB DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 55,
    description: "Add notes column to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 56,
    description: "Add cancellation_reason and feedback columns to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS feedback JSONB DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 57,
    description: "Add return_rejection_reason column to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS return_rejection_reason TEXT DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 58,
    description: "Add received_items, original_net_amount, and modification_reason to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS received_items JSONB DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS original_net_amount DECIMAL(12, 2) DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS modification_reason TEXT DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 59,
    description: "Add refund_payment_mode, refund_paid_at, and is_prepaid to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS refund_payment_mode VARCHAR(50) DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS refund_paid_at TIMESTAMP DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS is_prepaid BOOLEAN DEFAULT FALSE;
        COMMIT;
      `);
    }
  },
  {
    version: 60,
    description: "Create WhatsApp configuration, templates, campaigns and message logs tables",
    up: async (db) => {
      await db.query(`
        BEGIN;
        CREATE TABLE IF NOT EXISTS whatsapp_configurations (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          waba_id VARCHAR(255) NOT NULL,
          phone_number_id VARCHAR(255) NOT NULL,
          encrypted_access_token TEXT NOT NULL,
          webhook_verify_token VARCHAR(255) NOT NULL,
          app_secret VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(outlet_id)
        );

        CREATE TABLE IF NOT EXISTS whatsapp_templates (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          template_name VARCHAR(255) NOT NULL,
          category VARCHAR(50) NOT NULL,
          language VARCHAR(50) NOT NULL,
          body_text TEXT NOT NULL,
          status VARCHAR(50) DEFAULT 'DRAFT',
          meta_template_id VARCHAR(255),
          header_type VARCHAR(50) DEFAULT 'NONE',
          header_text TEXT,
          footer_text TEXT,
          buttons JSONB DEFAULT NULL,
          variables JSONB DEFAULT NULL,
          is_default_invoice_template BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(outlet_id, template_name, language)
        );

        CREATE TABLE IF NOT EXISTS whatsapp_campaigns (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          template_id INTEGER NOT NULL REFERENCES whatsapp_templates(id) ON DELETE CASCADE,
          campaign_name VARCHAR(255) NOT NULL,
          total_recipients INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS whatsapp_logs (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          campaign_id INTEGER REFERENCES whatsapp_campaigns(id) ON DELETE SET NULL,
          recipient_phone VARCHAR(50) NOT NULL,
          message_type VARCHAR(50) NOT NULL,
          delivery_status VARCHAR(50) DEFAULT 'queued',
          meta_message_id VARCHAR(255),
          error_message TEXT,
          retry_count INTEGER DEFAULT 0,
          next_retry_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          variables_mapped JSONB DEFAULT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        COMMIT;
      `);
    }
  },
  {
    version: 61,
    description: "Add cost column to whatsapp_logs table for billing dashboard",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE whatsapp_logs ADD COLUMN IF NOT EXISTS cost DECIMAL(6, 2) DEFAULT 0.00;
        COMMIT;
      `);
    }
  },
  {
    version: 62,
    description: "Create product templates, attributes, and variant mapping tables",
    up: async (db) => {
      await db.query(`
        BEGIN;

        -- 1. Create product_templates table
        CREATE TABLE IF NOT EXISTS product_templates (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
            name VARCHAR(150) NOT NULL,
            item_group VARCHAR(100) NOT NULL,
            sub_category VARCHAR(100) NOT NULL,
            brand VARCHAR(100),
            hsn_sac_code VARCHAR(30),
            tax_type VARCHAR(20) DEFAULT 'GST',
            tax_percent DECIMAL(7, 2) DEFAULT 0.00,
            discount_applicable BOOLEAN DEFAULT TRUE,
            scheme_applicable BOOLEAN DEFAULT TRUE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 2. Create attributes table
        CREATE TABLE IF NOT EXISTS attributes (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
            name VARCHAR(50) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_outlet_attribute_name UNIQUE (outlet_id, name)
        );

        -- 3. Create attribute_values table
        CREATE TABLE IF NOT EXISTS attribute_values (
            id SERIAL PRIMARY KEY,
            attribute_id INTEGER NOT NULL REFERENCES attributes(id) ON DELETE CASCADE,
            value VARCHAR(100) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_attribute_value UNIQUE (attribute_id, value)
        );

        -- 4. Add product_template_id column to item_master
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS product_template_id INTEGER REFERENCES product_templates(id) ON DELETE SET NULL;

        -- 5. Create variant_attribute_values join table
        CREATE TABLE IF NOT EXISTS variant_attribute_values (
            id SERIAL PRIMARY KEY,
            item_id INTEGER NOT NULL REFERENCES item_master(id) ON DELETE CASCADE,
            attribute_value_id INTEGER NOT NULL REFERENCES attribute_values(id) ON DELETE CASCADE,
            CONSTRAINT uq_variant_attribute UNIQUE (item_id, attribute_value_id)
        );

        -- 6. Create indexes
        CREATE INDEX IF NOT EXISTS idx_product_templates_outlet ON product_templates(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_attributes_outlet ON attributes(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_variant_attribute_values_item ON variant_attribute_values(item_id);
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 56,
    description: "Add cancellation_reason and feedback columns to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS feedback JSONB DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 57,
    description: "Add return_rejection_reason column to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS return_rejection_reason TEXT DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 58,
    description: "Add received_items, original_net_amount, and modification_reason to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS received_items JSONB DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS original_net_amount DECIMAL(12, 2) DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS modification_reason TEXT DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 59,
    description: "Add refund_payment_mode, refund_paid_at, and is_prepaid to customer_orders table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS refund_payment_mode VARCHAR(50) DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS refund_paid_at TIMESTAMP DEFAULT NULL;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS is_prepaid BOOLEAN DEFAULT FALSE;
        COMMIT;
      `);
    }
  },
  {
    version: 60,
    description: "Create WhatsApp configuration, templates, campaigns and message logs tables",
    up: async (db) => {
      await db.query(`
        BEGIN;
        CREATE TABLE IF NOT EXISTS whatsapp_configurations (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          waba_id VARCHAR(255) NOT NULL,
          phone_number_id VARCHAR(255) NOT NULL,
          encrypted_access_token TEXT NOT NULL,
          webhook_verify_token VARCHAR(255) NOT NULL,
          app_secret VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(outlet_id)
        );

        CREATE TABLE IF NOT EXISTS whatsapp_templates (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          template_name VARCHAR(255) NOT NULL,
          category VARCHAR(50) NOT NULL,
          language VARCHAR(50) NOT NULL,
          body_text TEXT NOT NULL,
          status VARCHAR(50) DEFAULT 'DRAFT',
          meta_template_id VARCHAR(255),
          header_type VARCHAR(50) DEFAULT 'NONE',
          header_text TEXT,
          footer_text TEXT,
          buttons JSONB DEFAULT NULL,
          variables JSONB DEFAULT NULL,
          is_default_invoice_template BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(outlet_id, template_name, language)
        );

        CREATE TABLE IF NOT EXISTS whatsapp_campaigns (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          template_id INTEGER NOT NULL REFERENCES whatsapp_templates(id) ON DELETE CASCADE,
          campaign_name VARCHAR(255) NOT NULL,
          total_recipients INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS whatsapp_logs (
          id SERIAL PRIMARY KEY,
          outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
          campaign_id INTEGER REFERENCES whatsapp_campaigns(id) ON DELETE SET NULL,
          recipient_phone VARCHAR(50) NOT NULL,
          message_type VARCHAR(50) NOT NULL,
          delivery_status VARCHAR(50) DEFAULT 'queued',
          meta_message_id VARCHAR(255),
          error_message TEXT,
          retry_count INTEGER DEFAULT 0,
          next_retry_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          variables_mapped JSONB DEFAULT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        COMMIT;
      `);
    }
  },
  {
    version: 61,
    description: "Add cost column to whatsapp_logs table for billing dashboard",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE whatsapp_logs ADD COLUMN IF NOT EXISTS cost DECIMAL(6, 2) DEFAULT 0.00;
        COMMIT;
      `);
    }
  },
  {
    version: 62,
    description: "Create product templates, attributes, and variant mapping tables",
    up: async (db) => {
      await db.query(`
        BEGIN;

        -- 1. Create product_templates table
        CREATE TABLE IF NOT EXISTS product_templates (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
            name VARCHAR(150) NOT NULL,
            item_group VARCHAR(100) NOT NULL,
            sub_category VARCHAR(100) NOT NULL,
            brand VARCHAR(100),
            hsn_sac_code VARCHAR(30),
            tax_type VARCHAR(20) DEFAULT 'GST',
            tax_percent DECIMAL(7, 2) DEFAULT 0.00,
            discount_applicable BOOLEAN DEFAULT TRUE,
            scheme_applicable BOOLEAN DEFAULT TRUE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 2. Create attributes table
        CREATE TABLE IF NOT EXISTS attributes (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
            name VARCHAR(50) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_outlet_attribute_name UNIQUE (outlet_id, name)
        );

        -- 3. Create attribute_values table
        CREATE TABLE IF NOT EXISTS attribute_values (
            id SERIAL PRIMARY KEY,
            attribute_id INTEGER NOT NULL REFERENCES attributes(id) ON DELETE CASCADE,
            value VARCHAR(100) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_attribute_value UNIQUE (attribute_id, value)
        );

        -- 4. Add product_template_id column to item_master
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS product_template_id INTEGER REFERENCES product_templates(id) ON DELETE SET NULL;

        -- 5. Create variant_attribute_values join table
        CREATE TABLE IF NOT EXISTS variant_attribute_values (
            id SERIAL PRIMARY KEY,
            item_id INTEGER NOT NULL REFERENCES item_master(id) ON DELETE CASCADE,
            attribute_value_id INTEGER NOT NULL REFERENCES attribute_values(id) ON DELETE CASCADE,
            CONSTRAINT uq_variant_attribute UNIQUE (item_id, attribute_value_id)
        );

        -- 6. Create indexes
        CREATE INDEX IF NOT EXISTS idx_product_templates_outlet ON product_templates(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_attributes_outlet ON attributes(outlet_id);
        CREATE INDEX IF NOT EXISTS idx_variant_attribute_values_item ON variant_attribute_values(item_id);

        COMMIT;
      `);
    }
  },
  {
    version: 63,
    description: "Add drug_license_no column to property_info table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS drug_license_no VARCHAR(50);
        COMMIT;
      `);
    }
  },
  {
    version: 64,
    description: "Add doctor_name and patient_name columns to sales_headers table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS doctor_name VARCHAR(150);
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS patient_name VARCHAR(150);
        COMMIT;
      `);
    }
  },
  {
    version: 65,
    description: "Add delivery_type to milk_subscriptions and enable_app_subscription to system_settings",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE milk_subscriptions ADD COLUMN IF NOT EXISTS delivery_type VARCHAR(20) DEFAULT 'PICKUP';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_app_subscription BOOLEAN DEFAULT FALSE;
        COMMIT;
      `);
    }
  },
  {
    version: 66,
    description: "Add rejection_reason column to whatsapp_templates table",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE whatsapp_templates ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
        COMMIT;
      `);
    }
  },
  {
    version: 67,
    description: "Add allow_automatic_messages to whatsapp_configurations and scheduled_at to whatsapp_campaigns",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE whatsapp_configurations ADD COLUMN IF NOT EXISTS allow_automatic_messages BOOLEAN DEFAULT TRUE;
        ALTER TABLE whatsapp_campaigns ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMP;
        COMMIT;
      `);
    }
  },
  {
    version: 68,
    description: "Add payment gateway settings to system_settings and payment_gateway_details to customer_orders",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_payment_gateway BOOLEAN DEFAULT FALSE;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS payment_gateway_provider VARCHAR(50) DEFAULT 'SANDBOX';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS payment_gateway_api_key VARCHAR(255) DEFAULT '';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS payment_gateway_secret_key VARCHAR(255) DEFAULT '';
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS payment_gateway_details JSONB DEFAULT NULL;
        COMMIT;
      `);
    }
  },
  {
    version: 69,
    description: "Add subscription_allocation snapshot to customer_orders",
    up: async (db) => {
      await db.query(`
        BEGIN;
        ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS subscription_allocation JSONB DEFAULT NULL;
        COMMIT;
      `);
    }
  }
];

module.exports = migrations;
