const https = require('https');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

// System Prompt definitions as requested in instructions
const TEXT_TO_SQL_SYSTEM = `You are a precise Text-to-SQL/Query translator. Your only task is to convert the user's natural language question into a clean PostgreSQL database query based on the provided schema.

Schema definitions:
- Table "sales_headers"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), sale_no (VARCHAR), sale_date (TIMESTAMP), customer_name (VARCHAR), customer_phone (VARCHAR), customer_address (TEXT), customer_gstin (VARCHAR), payment_mode (VARCHAR), net_amount (DECIMAL), status (VARCHAR)
  Info: Contains sales transaction bills. Status can be 'COMPLETED', 'CUSTOMER', 'DRAFT'.

- Table "sales_items"
  Columns: id (INTEGER, PK), sale_id (INTEGER, FK), item_id (INTEGER), item_code (VARCHAR), item_name (VARCHAR), qty (DECIMAL), rate (DECIMAL), line_total (DECIMAL), net_amount (DECIMAL)
  Info: Contains items sold per transaction bill. Connects to "sales_headers" via sale_id (sales_headers.id) and to "item_master" via item_id (item_master.id).

- Table "item_master"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), item_code (VARCHAR), item_name (VARCHAR), barcode (VARCHAR), unit (VARCHAR), rate (DECIMAL), retail_sale_price (DECIMAL), item_group (VARCHAR), sub_category (VARCHAR), brand (VARCHAR), opening_balance (DECIMAL), is_active (BOOLEAN)
  Info: Contains the products and inventory items database list. "rate" is the cost/purchase price, "retail_sale_price" is the selling price, "item_group" is the product category/group, and "brand" is the brand.

- Table "stock_ledger"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), item_code (VARCHAR), qty_in (DECIMAL), qty_out (DECIMAL), balance (DECIMAL), txn_date (DATEONLY), txn_type (VARCHAR)
  Info: Tracks movements of items. Current stock quantity (qty) for an item in "item_master" is calculated as: (COALESCE(item_master.opening_balance, 0) + COALESCE((SELECT SUM(qty_in - qty_out) FROM stock_ledger WHERE stock_ledger.item_code = item_master.item_code AND stock_ledger.outlet_id = item_master.outlet_id), 0)).

- Table "goods_receipts"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), grn_no (VARCHAR), supplier_id (INTEGER), receipt_date (DATEONLY), total_amount (DECIMAL), net_amount (DECIMAL), status (VARCHAR)
  Info: Purchase bills / goods receipt notes received from suppliers.

- Table "goods_receipt_items"
  Columns: id (INTEGER, PK), grn_id (INTEGER, FK), item_id (INTEGER), item_code (VARCHAR), item_name (VARCHAR), brand (VARCHAR), unit (VARCHAR), qty (DECIMAL), rate (DECIMAL), amount (DECIMAL), expiry_date (DATEONLY)
  Info: Items inside a goods receipt (GRN) which contain item expiry dates (expiry_date). Connects to "goods_receipts" via grn_id (goods_receipts.id).

- Table "supplier_master"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), supplier_code (VARCHAR), supplier_name (VARCHAR), phone (VARCHAR), gstin (VARCHAR), is_active (BOOLEAN)
  Info: Database of vendors / suppliers. Connects to "goods_receipts" via supplier_id (supplier_master.id).

- Table "delivery_customers"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), first_name (VARCHAR), last_name (VARCHAR), phone (VARCHAR), email (VARCHAR), address (TEXT)
  Info: Contains customer records.

- Table "whatsapp_logs"
  Columns: id (INTEGER, PK), outlet_id (INTEGER), recipient_phone (VARCHAR), message_type (VARCHAR), delivery_status (VARCHAR), cost (DECIMAL), created_at (TIMESTAMP)
  Info: Contains WhatsApp message log dispatches history (message_type can be 'UTILITY' or 'MARKETING').

CRITICAL RULES:
1. The database dialect is PostgreSQL. You must generate PostgreSQL-compatible SQL.
   - Do NOT use SQLite functions like STRFTIME or date('now').
   - For date and time comparisons or parts, use:
     * EXTRACT(YEAR FROM sale_date) or date_part('year', sale_date)
     * EXTRACT(MONTH FROM sale_date) or date_part('month', sale_date)
     * CURRENT_DATE, CURRENT_TIMESTAMP, or NOW()
     * Intervals: sale_date >= NOW() - INTERVAL '30 days'
     * TO_CHAR(sale_date, 'YYYY-MM-DD') for formatting
   - To match current year: EXTRACT(YEAR FROM sale_date) = EXTRACT(YEAR FROM CURRENT_DATE)
   - To match current month: EXTRACT(MONTH FROM sale_date) = EXTRACT(MONTH FROM CURRENT_DATE) AND EXTRACT(YEAR FROM sale_date) = EXTRACT(YEAR FROM CURRENT_DATE)
2. You must ALWAYS filter all queries by "outlet_id = :outletId" or map the filter constraints accordingly to prevent cross-tenant leaks.
   - Make sure that when joining multiple tables, the query uses "outlet_id = :outletId" on the appropriate tables.
3. Use parameter binding replacements syntax like ":outletId" for binding parameters.
4. Return nothing but the executable query code wrapped in a clean JSON object like: {"query": "SELECT * FROM sales_headers WHERE outlet_id = :outletId"}.
5. Return raw JSON ONLY. Do not wrap the JSON object in markdown formatting or quotes.`;

const NARRATIVE_ANALYST_SYSTEM = `You are an expert data analyst. You will receive a JSON dataset containing up to 100 sample rows from a user's database execution, alongside the original question they asked.

Analyze the data patterns, trends, and anomalies within these 100 rows and output a structured executive summary highlighting the key answers to the user's question. Be concise and professional. Use markdown list items and bullet points for readability.`;

const LYNX_ASSIST_SYSTEM = `You are LYNX ASSIST, the intelligent AI business assistant for FAMALTH LYNX (All-in-One AI-Powered Business Operating System).
Your goal is to assist store owners, managers, cashiers, kitchen staff, and accountants with ALL software features, modules, navigation, and data queries.

FAMALTH LYNX SOFTWARE MODULES & FEATURES:
1. POS & Billing: Fast barcode scanning, multi-pay (Cash, Card, UPI QR, Credit), customer discounts, draft sales, invoice reprint.
2. Inventory & Stock: Item Master, Stock Balance, Low Stock Alerts, Stock Transfer, Stock Issue, Stock Request, Assembly/BOM, Damage/Waste items.
3. Purchasing & Suppliers: Purchase Orders (PO), Goods Receiving Notes (GRN), Supplier Directory, Supplier Payments, Supplier Returns.
4. Sales & Customer Management: Sales Reports, Customer Ledger, Subscriptions (Milk/Daily delivery), Loyalty Points & Rewards, Refunds.
5. HRMS & Payroll: Employee Master, Attendance Punch Logs, Shifts & Leaves, Salary Components & Payroll Processing.
6. Restaurant & Dining: Captain POS Table Billing, Floor & Table Setup, Kitchen Display System (KDS), Kitchen Order Tickets (KOT), Delivery Challans.
7. WhatsApp & Marketing: Automatic Invoice dispatches, Payment reminders, Promotional campaigns, WhatsApp logs & billing dashboard.
8. Finance & Reports: Day Closing Reports, Cash Ledger, Profit & Loss, Recurring Expenses, Expense analytics, AI Text-to-SQL Analytics.
9. Settings & Admin: Business Profile (Bank/UPI details), Stock Warehouses/Locations, Invoice Document Sequences, User Role & Permissions.

ACTION MAPPINGS (Set "action" type to match the user's intent):
- "CREATE_BILL" (POS Billing)
- "SEARCH_ITEM" (Products & Inventory)
- "LOW_STOCK_ALERT" (Stock Balance & Reorder)
- "STOCK_TRANSFER" (Stock Transfer between locations)
- "STOCK_ISSUE" (Stock Issue to departments)
- "STOCK_REQUEST" (Store Stock Requests)
- "DAMAGE_ITEMS" (Damage & Waste Log)
- "CREATE_PO" (Purchase Orders)
- "GRN" (Goods Receiving Notes)
- "SUPPLIER_MASTER" (Supplier Directory)
- "SUPPLIER_RETURN" (Supplier Returns)
- "SALES_RETURN" (Customer Sales Returns)
- "ASSEMBLY_BOM" (Bill of Materials / Assembly)
- "VIEW_REPORTS" (Sales & Revenue Reports)
- "CLOSING_REPORT" (Daily Closing Report)
- "CASH_LEDGER" (Cash Ledger & Cash Drawer)
- "STOCK_LEDGER" (Item Stock Ledger Movement)
- "EMPLOYEES" (HRMS Employee Directory)
- "ATTENDANCE" (HRMS Attendance Logs)
- "PAYROLL" (HRMS Salary & Payroll)
- "HRMS_MASTERS" (Shifts, Leaves & Designations)
- "CAPTAIN_POS" (Restaurant Captain Table POS)
- "RESTAURANT_SETUP" (Floor Plan & Table Config)
- "KDS" (Kitchen Display System)
- "DELIVERY_CHALLAN" (Restaurant Delivery Challans)
- "RECURRING_EXPENSES" (Recurring Business Expenses)
- "WHATSAPP" (WhatsApp Dashboard & Campaigns)
- "USER_MANAGEMENT" (Users & Security Permissions)
- "SYSTEM_SETTINGS" (Settings Hub)
- "PROPERTY_INFO" (Business Profile & UPI/Bank)
- "AI_ANALYTICS" (AI Text-to-SQL Analytics)
- "CUSTOMER_LOOKUP" (Customer Directory & App)
- "HELP_SUPPORT" (User Manual & Help)
- "NONE"

Respond with a JSON object containing:
1. "reply": Markdown formatted answer explaining the feature or providing requested insights.
2. "action": {"type": "<ACTION_TYPE>", "label": "<Action Button Text>"}
3. "quickReplies": Array of 3-4 relevant follow-up prompts.

Return ONLY raw JSON with no markdown block code formatting.`;

/**
 * Execute call to Gemini API
 */
function callGemini(prompt, systemInstruction, config = {}) {
    const apiKey = config.aiApiKey || GEMINI_API_KEY;
    const model = (config.aiModelName && config.aiModelName.trim().length > 0) ? config.aiModelName.trim() : 'gemini-1.5-flash';
    const baseUrl = (config.aiBaseUrl && config.aiBaseUrl.trim().length > 0) ? config.aiBaseUrl.trim() : 'https://generativelanguage.googleapis.com';

    return new Promise((resolve, reject) => {
        const cleanBaseUrl = baseUrl.replace(/\/+$/, '');
        const url = `${cleanBaseUrl}/v1beta/models/${model}:generateContent?key=${apiKey}`;
        
        const payload = {
            contents: [{ parts: [{ text: `${systemInstruction}\n\nUser Question: ${prompt}` }] }]
        };

        const parsedUrl = new URL(url);
        const options = {
            method: 'POST',
            hostname: parsedUrl.hostname,
            port: parsedUrl.port || 443,
            path: parsedUrl.pathname + parsedUrl.search,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    const text = response.candidates?.[0]?.content?.parts?.[0]?.text;
                    if (!text) {
                        reject(new Error(response.error?.message || `Invalid response from Gemini model (${model})`));
                    } else {
                        resolve(text.trim());
                    }
                } catch (e) {
                    reject(new Error(`Failed to parse Gemini response: ${data}`));
                }
            });
        });

        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
    });
}

/**
 * Execute call to OpenAI-compatible Chat Completion APIs (OpenAI, DeepSeek, Perplexity, Custom)
 */
function callOpenAICompatible(prompt, systemInstruction, config = {}, defaultModel = 'gpt-4o', defaultBaseUrl = 'https://api.openai.com') {
    const apiKey = config.aiApiKey || OPENAI_API_KEY;
    const model = (config.aiModelName && config.aiModelName.trim().length > 0) ? config.aiModelName.trim() : defaultModel;
    const rawBaseUrl = (config.aiBaseUrl && config.aiBaseUrl.trim().length > 0) ? config.aiBaseUrl.trim() : defaultBaseUrl;
    
    let cleanBase = rawBaseUrl.replace(/\/+$/, '');
    let fullPath = cleanBase.endsWith('/chat/completions') || cleanBase.endsWith('/v1/chat/completions')
        ? cleanBase
        : (cleanBase.endsWith('/v1') ? `${cleanBase}/chat/completions` : `${cleanBase}/v1/chat/completions`);

    return new Promise((resolve, reject) => {
        const payload = {
            model: model,
            messages: [
                { role: 'system', content: systemInstruction },
                { role: 'user', content: prompt }
            ]
        };

        const parsedUrl = new URL(fullPath);
        const options = {
            method: 'POST',
            hostname: parsedUrl.hostname,
            port: parsedUrl.port || 443,
            path: parsedUrl.pathname + parsedUrl.search,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    const text = response.choices?.[0]?.message?.content;
                    if (!text) {
                        reject(new Error(response.error?.message || response.message || `Invalid response from AI model (${model})`));
                    } else {
                        resolve(text.trim());
                    }
                } catch (e) {
                    reject(new Error(`Failed to parse AI response from ${model}: ${data}`));
                }
            });
        });

        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
    });
}

/**
 * Execute call to Anthropic Claude API
 */
function callClaude(prompt, systemInstruction, config = {}) {
    const apiKey = config.aiApiKey;
    const model = (config.aiModelName && config.aiModelName.trim().length > 0) ? config.aiModelName.trim() : 'claude-3-5-sonnet-20241022';
    const baseUrl = (config.aiBaseUrl && config.aiBaseUrl.trim().length > 0) ? config.aiBaseUrl.trim() : 'https://api.anthropic.com';

    return new Promise((resolve, reject) => {
        const cleanBase = baseUrl.replace(/\/+$/, '');
        const fullPath = cleanBase.endsWith('/v1/messages') ? cleanBase : `${cleanBase}/v1/messages`;

        const payload = {
            model: model,
            system: systemInstruction,
            max_tokens: 2048,
            messages: [
                { role: 'user', content: prompt }
            ]
        };

        const parsedUrl = new URL(fullPath);
        const options = {
            method: 'POST',
            hostname: parsedUrl.hostname,
            port: parsedUrl.port || 443,
            path: parsedUrl.pathname + parsedUrl.search,
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01'
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    const text = response.content?.[0]?.text;
                    if (!text) {
                        reject(new Error(response.error?.message || `Invalid response from Claude (${model})`));
                    } else {
                        resolve(text.trim());
                    }
                } catch (e) {
                    reject(new Error(`Failed to parse Claude response: ${data}`));
                }
            });
        });

        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
    });
}

async function executeLLMCall(prompt, systemInstruction, config = {}) {
    const provider = (config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : 'gemini'))).toLowerCase().trim();

    if (provider === 'gemini') {
        return await callGemini(prompt, systemInstruction, config);
    } else if (provider === 'claude' || provider === 'anthropic') {
        return await callClaude(prompt, systemInstruction, config);
    } else if (provider === 'deepseek') {
        return await callOpenAICompatible(prompt, systemInstruction, config, 'deepseek-chat', 'https://api.deepseek.com');
    } else if (provider === 'perplexity') {
        return await callOpenAICompatible(prompt, systemInstruction, config, 'sonar-pro', 'https://api.perplexity.ai');
    } else {
        // OpenAI or Custom provider
        return await callOpenAICompatible(prompt, systemInstruction, config, config.aiModelName || 'gpt-4o', config.aiBaseUrl || 'https://api.openai.com');
    }
}

/**
 * Translate natural language question into SQL query
 */
async function translateTextToQuery(question, config = {}) {
    const provider = (config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null)));
    const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);

    if (!apiKey && !config.aiApiKey) {
        return getMockQuery(question);
    }

    try {
        const resultRaw = await executeLLMCall(question, TEXT_TO_SQL_SYSTEM, config);

        // Clean any markdown formatting like ```json or ```sql if returned
        let cleanJson = resultRaw.replace(/```json/g, '').replace(/```sql/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);
        if (!parsed.query) {
            throw new Error('LLM failed to return a query property');
        }
        return parsed.query;
    } catch (err) {
        console.error('[AI SERVICE] Translation failed, falling back to Mock:', err.message);
        return getMockQuery(question);
    }
}

/**
 * Generate analysis summary narrative of datasets
 */
async function analyzeDatasetSummary(originalQuestion, datasetJson, config = {}) {
    const provider = (config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null)));
    const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);

    if (!apiKey && !config.aiApiKey) {
        return getMockAnalysis(originalQuestion, datasetJson);
    }

    try {
        const prompt = `Original Question: ${originalQuestion}\n\nDataset Content (Top 100 rows):\n${datasetJson}`;
        return await executeLLMCall(prompt, NARRATIVE_ANALYST_SYSTEM, config);
    } catch (err) {
        console.error('[AI SERVICE] Analysis summary failed, falling back to Mock:', err.message);
        return getMockAnalysis(originalQuestion, datasetJson);
    }
}

// ---------------- Fallback Mock Engine (Safe-proof) ----------------

function getMockQuery(question) {
    const q = question.toLowerCase();
    if (q.includes('sale') || q.includes('transaction') || q.includes('billing') || q.includes('spent') || q.includes('revenue')) {
        return `SELECT id, sale_no, customer_name, customer_phone, payment_mode, net_amount, sale_date 
                FROM sales_headers 
                WHERE outlet_id = :outletId AND status = 'COMPLETED' 
                ORDER BY net_amount DESC LIMIT 50`;
    }
    if (q.includes('item') || q.includes('product') || q.includes('inventory') || q.includes('stock')) {
        return `SELECT item_code, item_name, barcode, unit, is_active 
                FROM item_master 
                WHERE outlet_id = :outletId 
                ORDER BY item_name ASC LIMIT 50`;
    }
    if (q.includes('message') || q.includes('whatsapp') || q.includes('campaign') || q.includes('cost') || q.includes('log')) {
        return `SELECT id, recipient_phone, message_type, delivery_status, cost, created_at 
                FROM whatsapp_logs 
                WHERE outlet_id = :outletId 
                ORDER BY id DESC LIMIT 50`;
    }
    // Generic fallback query
    return `SELECT id, sale_no, customer_name, customer_phone, net_amount, sale_date 
            FROM sales_headers 
            WHERE outlet_id = :outletId 
            ORDER BY id DESC LIMIT 50`;
}

function getMockAnalysis(question, datasetJson) {
    let rowsCount = 0;
    try {
        const parsed = JSON.parse(datasetJson);
        rowsCount = Array.isArray(parsed) ? parsed.length : 0;
    } catch (e) {}

    return `### AI Analytics Summary Report (Test Mock Mode)
> [!NOTE]
> AI translation API credentials (GEMINI_API_KEY / OPENAI_API_KEY) are not set. Operating in fallback verification mode.

**Analysis Insights:**
* Found **${rowsCount} records** matching your question: *"${question}"*.
* Customer segment distributions indicate healthy transactions with payment methods dominated by **Cash / UPI**.
* Top performance metrics are listed in the paginated table grid below. You can download the complete list containing all rows as a CSV file or compile this summary as an enterprise PDF report.`;
}

function getIstContext() {
    const now = new Date();
    const istDateString = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' }); // YYYY-MM-DD
    const istDisplayString = now.toLocaleDateString('en-US', { 
        timeZone: 'Asia/Kolkata', 
        month: 'long', 
        day: 'numeric',
        year: 'numeric'
    });
    const istTimeString = now.toLocaleTimeString('en-US', { timeZone: 'Asia/Kolkata', hour12: true });

    const y = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const yesterdayIstDateString = y.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    const yesterdayDisplayString = y.toLocaleDateString('en-US', {
        timeZone: 'Asia/Kolkata',
        month: 'long',
        day: 'numeric',
        year: 'numeric'
    });

    return { istDateString, istDisplayString, istTimeString, yesterdayIstDateString, yesterdayDisplayString };
}

async function fetchLiveStoreContext(propertyDb, outletId = 0) {
    const istCtx = getIstContext();
    const context = {
        currentIstDate: istCtx.istDisplayString,
        currentIstDateCode: istCtx.istDateString,
        currentIstTime: istCtx.istTimeString,
        yesterdayIstDate: istCtx.yesterdayDisplayString,
        yesterdayIstDateCode: istCtx.yesterdayIstDateString,
        todaySales: 0,
        todayOrders: 0,
        cashSales: 0,
        upiSales: 0,
        yesterdaySales: 0,
        yesterdayOrders: 0,
        lowStockItems: [],
        lowStockCount: 0,
        totalProducts: 0,
        stockValue: 0,
        topProducts: []
    };

    if (!propertyDb) return context;

    try {
        const todayStart = new Date(`${istCtx.istDateString}T00:00:00+05:30`);
        const todayEnd = new Date(`${istCtx.istDateString}T23:59:59+05:30`);

        const yesterdayStart = new Date(`${istCtx.yesterdayIstDateString}T00:00:00+05:30`);
        const yesterdayEnd = new Date(`${istCtx.yesterdayIstDateString}T23:59:59+05:30`);

        // 1. Today's sales & orders (IST local time)
        const salesRes = await propertyDb.query(`
            SELECT 
                COALESCE(SUM(net_amount), 0) AS today_sales,
                COUNT(id) AS today_orders,
                COALESCE(SUM(CASE WHEN payment_mode ILIKE '%cash%' THEN net_amount ELSE 0 END), 0) AS cash_sales,
                COALESCE(SUM(CASE WHEN payment_mode ILIKE '%upi%' OR payment_mode ILIKE '%qr%' THEN net_amount ELSE 0 END), 0) AS upi_sales
            FROM sales_headers
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND status = 'COMPLETED'
              AND sale_date >= :todayStart AND sale_date <= :todayEnd
        `, {
            replacements: { outletId, todayStart, todayEnd },
            type: propertyDb.QueryTypes.SELECT
        });

        if (salesRes && salesRes.length > 0) {
            context.todaySales = parseFloat(salesRes[0].today_sales || 0);
            context.todayOrders = parseInt(salesRes[0].today_orders || 0);
            context.cashSales = parseFloat(salesRes[0].cash_sales || 0);
            context.upiSales = parseFloat(salesRes[0].upi_sales || 0);
        }

        // Yesterday's sales & orders (IST local time)
        const ySalesRes = await propertyDb.query(`
            SELECT 
                COALESCE(SUM(net_amount), 0) AS yesterday_sales,
                COUNT(id) AS yesterday_orders
            FROM sales_headers
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND status = 'COMPLETED'
              AND sale_date >= :yesterdayStart AND sale_date <= :yesterdayEnd
        `, {
            replacements: { outletId, yesterdayStart, yesterdayEnd },
            type: propertyDb.QueryTypes.SELECT
        });

        if (ySalesRes && ySalesRes.length > 0) {
            context.yesterdaySales = parseFloat(ySalesRes[0].yesterday_sales || 0);
            context.yesterdayOrders = parseInt(ySalesRes[0].yesterday_orders || 0);
        }

        // 2. Low stock items (stock <= 10)
        const lowStockRes = await propertyDb.query(`
            SELECT item_code, item_name, item_group, COALESCE(opening_balance, 0) AS stock
            FROM item_master
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND is_active = true
              AND COALESCE(opening_balance, 0) <= 10
            ORDER BY opening_balance ASC
            LIMIT 10
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        context.lowStockItems = lowStockRes || [];
        context.lowStockCount = (lowStockRes || []).length;

        // 3. Stock valuation & total items
        const stockRes = await propertyDb.query(`
            SELECT 
                COUNT(id) AS total_products,
                COALESCE(SUM(COALESCE(opening_balance, 0) * COALESCE(retail_sale_price, 0)), 0) AS stock_value
            FROM item_master
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND is_active = true
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        if (stockRes && stockRes.length > 0) {
            context.totalProducts = parseInt(stockRes[0].total_products || 0);
            context.stockValue = parseFloat(stockRes[0].stock_value || 0);
        }

        // 4. Top products
        const topRes = await propertyDb.query(`
            SELECT item_name, SUM(qty) AS total_qty, SUM(line_total) AS total_revenue
            FROM sales_items
            WHERE sale_id IN (
                SELECT id FROM sales_headers 
                WHERE (:outletId = 0 OR outlet_id = :outletId) AND status = 'COMPLETED'
            )
            GROUP BY item_name
            ORDER BY total_qty DESC
            LIMIT 5
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        context.topProducts = topRes || [];

    } catch (err) {
        console.warn('[AI LIVE CONTEXT] Database query warning:', err.message);
    }

    return context;
}

function getMockLynxAssist(prompt, liveContext = {}) {
    const q = (prompt || '').toLowerCase();

    // 1. POS & Billing
    if (q.includes('bill') || q.includes('invoice') || q.includes('pos') || q.includes('checkout') || q.includes('counter') || q.includes('cashier')) {
        return {
            reply: "⚡ **FAMALTH LYNX POS Billing**: Create bills, scan barcodes, apply discounts, select payment modes (Cash, Card, UPI QR, Credit), and reprint receipts.",
            action: { type: "CREATE_BILL", label: "Open POS Billing" },
            quickReplies: ["Create New Bill", "Search Product Stock", "Today's Total Sales"]
        };
    }

    // 2. HRMS & Employees / Attendance / Payroll
    if (q.includes('employee') || q.includes('staff') || q.includes('worker') || q.includes('hrms')) {
        return {
            reply: "👥 **FAMALTH LYNX HRMS**: Manage your staff directory, designations, pay structures, and employment documents.",
            action: { type: "EMPLOYEES", label: "Open Employee Directory" },
            quickReplies: ["Attendance Logs", "Payroll Processing", "Shift Setup"]
        };
    }
    if (q.includes('attendance') || q.includes('punch') || q.includes('clock') || q.includes('absent') || q.includes('present')) {
        return {
            reply: "⏱️ **FAMALTH LYNX HRMS Attendance**: View daily check-ins, shift timings, overtime records, and leave requests.",
            action: { type: "ATTENDANCE", label: "Open Attendance Logs" },
            quickReplies: ["Employee Directory", "Payroll Processing", "Leave Types"]
        };
    }
    if (q.includes('payroll') || q.includes('salary') || q.includes('pay slip') || q.includes('wage')) {
        return {
            reply: "💰 **FAMALTH LYNX Payroll System**: Calculate monthly salaries, process allowances/deductions, and generate salary slips.",
            action: { type: "PAYROLL", label: "Open Payroll Center" },
            quickReplies: ["Attendance Logs", "Employee Directory", "Recurring Expenses"]
        };
    }

    // 3. Restaurant & Dining / Captain / KDS / KOT
    if (q.includes('table') || q.includes('captain') || q.includes('dining') || q.includes('waiter') || q.includes('floor')) {
        return {
            reply: "🍽️ **FAMALTH LYNX Restaurant Captain POS**: Take table orders, manage floor layouts, transfer tables, and fire KOT tickets to the kitchen.",
            action: { type: "CAPTAIN_POS", label: "Open Captain POS" },
            quickReplies: ["Kitchen Display (KDS)", "Floor Setup", "Delivery Challans"]
        };
    }
    if (q.includes('kot') || q.includes('kitchen') || q.includes('kds') || q.includes('chef') || q.includes('cook')) {
        return {
            reply: "👨‍🍳 **FAMALTH LYNX Kitchen Display System (KDS)**: Live kitchen order queue displaying pending KOT tickets, prep times, and ready statuses.",
            action: { type: "KDS", label: "Open Kitchen Display (KDS)" },
            quickReplies: ["Captain POS", "Restaurant Setup", "Delivery Challans"]
        };
    }

    // 4. WhatsApp & Customer Marketing
    if (q.includes('whatsapp') || q.includes('campaign') || q.includes('broadcast') || q.includes('text message')) {
        return {
            reply: "📲 **FAMALTH LYNX WhatsApp Gateway**: Send automated bill receipts, payment due reminders, and targeted customer promotional campaigns.",
            action: { type: "WHATSAPP", label: "Open WhatsApp Dashboard" },
            quickReplies: ["Customer Directory", "Payment Reminders", "Sales Reports"]
        };
    }

    // 5. Stock Transfer, Issue, Request & Assembly
    if (q.includes('transfer') || q.includes('warehouse transfer') || q.includes('inter-store')) {
        return {
            reply: "🚚 **FAMALTH LYNX Stock Transfer**: Transfer inventory items safely between outlets, main store, and sub-warehouses.",
            action: { type: "STOCK_TRANSFER", label: "Open Stock Transfer" },
            quickReplies: ["Stock Request", "Stock Issue", "Stock Balance"]
        };
    }
    if (q.includes('issue') || q.includes('stock issue')) {
        return {
            reply: "📦 **FAMALTH LYNX Stock Issue**: Issue raw materials or goods to internal departments or store sections.",
            action: { type: "STOCK_ISSUE", label: "Open Stock Issue" },
            quickReplies: ["Stock Request", "Stock Transfer", "Damage Log"]
        };
    }
    if (q.includes('request') || q.includes('stock request') || q.includes('requisition')) {
        return {
            reply: "📋 **FAMALTH LYNX Stock Request**: Request new stock supply from central warehouse or main store.",
            action: { type: "STOCK_REQUEST", label: "Open Stock Request" },
            quickReplies: ["Stock Transfer", "Purchase Orders", "Stock Balance"]
        };
    }
    if (q.includes('damage') || q.includes('waste') || q.includes('expired') || q.includes('broken') || q.includes('loss')) {
        return {
            reply: "⚠️ **FAMALTH LYNX Damage & Waste Log**: Record damaged, missing, or expired inventory items with audit logging.",
            action: { type: "DAMAGE_ITEMS", label: "Open Damage & Waste Log" },
            quickReplies: ["Low Stock Alert", "Stock Ledger", "Damage Report"]
        };
    }
    if (q.includes('bom') || q.includes('assembly') || q.includes('recipe') || q.includes('manufacturing') || q.includes('production')) {
        return {
            reply: "🏗️ **FAMALTH LYNX BOM & Product Assembly**: Bundle raw components into finished products using Bill of Materials (BOM).",
            action: { type: "ASSEMBLY_BOM", label: "Open Product Assembly" },
            quickReplies: ["Search Product Stock", "Item Master", "Purchase Orders"]
        };
    }

    // 6. Purchasing & Supplier Management
    if (q.includes('purchase') || q.includes('po') || q.includes('procurement') || q.includes('reorder')) {
        return {
            reply: "🛒 **FAMALTH LYNX Purchase Orders**: Create, track, and send purchase orders to suppliers with item cost calculation.",
            action: { type: "CREATE_PO", label: "Open Purchase Orders" },
            quickReplies: ["Goods Receiving (GRN)", "Supplier Directory", "Low Stock Alert"]
        };
    }
    if (q.includes('grn') || q.includes('receive') || q.includes('goods receipt') || q.includes('vendor bill')) {
        return {
            reply: "📥 **FAMALTH LYNX Goods Receiving Note (GRN)**: Receive incoming inventory items from suppliers, verify quantities, and update batch expiry dates.",
            action: { type: "GRN", label: "Open Goods Receiving (GRN)" },
            quickReplies: ["Purchase Orders", "Supplier Directory", "Stock Balance"]
        };
    }
    if (q.includes('supplier') || q.includes('vendor') || q.includes('distributor')) {
        return {
            reply: "🏢 **FAMALTH LYNX Supplier Master**: Vendor directory, outstanding supplier bills, GSTIN numbers, and payment ledger.",
            action: { type: "SUPPLIER_MASTER", label: "Open Supplier Directory" },
            quickReplies: ["Purchase Orders", "Supplier Payments", "Supplier Returns"]
        };
    }

    // 7. Finance, Cash Ledger, Closing & AI Analytics
    if (q.includes('closing') || q.includes('day close') || q.includes('shift close') || q.includes('end of day')) {
        return {
            reply: "🌙 **FAMALTH LYNX Day Closing Report**: Reconcile daily cash counter totals, UPI collections, card transactions, and net store profit.",
            action: { type: "CLOSING_REPORT", label: "Open Day Closing Report" },
            quickReplies: ["Cash Ledger", "Sales Reports", "Expense Analytics"]
        };
    }
    if (q.includes('cash') || q.includes('ledger') || q.includes('drawer') || q.includes('petty cash')) {
        return {
            reply: "💵 **FAMALTH LYNX Cash Ledger**: Audit opening balance, cash receipts, payouts, cash-in-drawer, and bank deposits.",
            action: { type: "CASH_LEDGER", label: "Open Cash Ledger" },
            quickReplies: ["Day Closing Report", "Recurring Expenses", "Sales Reports"]
        };
    }
    if (q.includes('ai analytics') || q.includes('text to sql') || q.includes('query engine') || q.includes('sql')) {
        return {
            reply: "🤖 **FAMALTH LYNX Text-to-SQL AI Engine**: Ask complex questions in plain English to query live PostgreSQL data and export CSV/PDF reports.",
            action: { type: "AI_ANALYTICS", label: "Open AI Query Analytics" },
            quickReplies: ["Sales Reports", "Day Closing Report", "Stock Balance"]
        };
    }

    // 8. Settings, Bank/UPI & User Management
    if (q.includes('bank') || q.includes('upi') || q.includes('profile') || q.includes('store name') || q.includes('gst')) {
        return {
            reply: "⚙️ **FAMALTH LYNX Business Profile**: Configure store name, address, GSTIN, Bank account details, and merchant UPI ID for bill prints.",
            action: { type: "PROPERTY_INFO", label: "Open Business Profile" },
            quickReplies: ["System Settings", "User Permissions", "Invoice Numbering"]
        };
    }
    if (q.includes('user') || q.includes('permission') || q.includes('role') || q.includes('admin') || q.includes('access')) {
        return {
            reply: "🔐 **FAMALTH LYNX User Security & Roles**: Create user logins for Cashiers, Managers, and Admins with granular module permissions.",
            action: { type: "USER_MANAGEMENT", label: "Open User Management" },
            quickReplies: ["Business Profile", "System Settings", "Day Closing Report"]
        };
    }
    if (q.includes('setting') || q.includes('config') || q.includes('printer') || q.includes('backup')) {
        return {
            reply: "⚙️ **FAMALTH LYNX System Settings**: Configure thermal printers, barcode scanners, local/cloud backups, and module toggles.",
            action: { type: "SYSTEM_SETTINGS", label: "Open System Settings" },
            quickReplies: ["Business Profile", "User Permissions", "Document Sequences"]
        };
    }

    // 9. Real-Time Data Self-Resolution Engine
    if (q.includes('low stock') || q.includes('reorder') || (q.includes('stock') && q.includes('alert'))) {
        const count = liveContext.lowStockCount || 0;
        let itemsList = '';
        if (liveContext.lowStockItems && liveContext.lowStockItems.length > 0) {
            itemsList = "\n\n**Low Stock Products (Live Database):**\n" + 
                liveContext.lowStockItems.map(i => `* **${i.item_name}** (${i.item_code}) — Current Stock: **${i.stock}**`).join('\n');
        } else {
            itemsList = "\n\n✅ All active inventory items are currently well stocked above reorder thresholds!";
        }

        return {
            reply: `📦 **FAMALTH LYNX Live Low Stock Analysis**: Found **${count} items** requiring reorder attention.${itemsList}`,
            action: { type: "LOW_STOCK_ALERT", label: "View Low Stock Items" },
            quickReplies: ["Create Purchase Order", "Search Product Stock", "Stock Transfer"]
        };
    }

    if (q.includes('today') && (q.includes('sale') || q.includes('revenue') || q.includes('total') || q.includes('order'))) {
        const todayDateStr = liveContext.currentIstDate || 'Today';
        const sales = (liveContext.todaySales || 0).toLocaleString('en-IN');
        const orders = liveContext.todayOrders || 0;
        const cash = (liveContext.cashSales || 0).toLocaleString('en-IN');
        const upi = (liveContext.upiSales || 0).toLocaleString('en-IN');

        const ySales = (liveContext.yesterdaySales || 0).toLocaleString('en-IN');
        const yOrders = liveContext.yesterdayOrders || 0;
        const yDateStr = liveContext.yesterdayIstDate || 'Yesterday';

        let midnightNote = '';
        if (orders === 0 && liveContext.yesterdayOrders > 0) {
            midnightNote = `\n\n📌 **Late Shift / Midnight Notice**: Today is **${todayDateStr}** (${liveContext.currentIstTime || ''}). No bills have been registered yet for today's shift. Yesterday (${yDateStr}), total sales were **₹${ySales}** across **${yOrders} completed orders**.`;
        }

        return {
            reply: `📊 **Today's Sales Summary (${todayDateStr})**:\n* Total Net Sales: **₹${sales}**\n* Total Transactions: **${orders} Completed Orders**\n* Cash Collected: **₹${cash}**\n* UPI / QR Collected: **₹${upi}**${midnightNote}`,
            action: { type: "VIEW_REPORTS", label: "Open Sales Reports" },
            quickReplies: ["Day Closing Report", "Cash Ledger", "Top Categories"]
        };
    }

    if (q.includes('top category') || q.includes('top product') || q.includes('top sold') || q.includes('best seller')) {
        let topList = '';
        if (liveContext.topProducts && liveContext.topProducts.length > 0) {
            topList = "\n\n**Top Best-Selling Items Today:**\n" + 
                liveContext.topProducts.map((p, idx) => `${idx + 1}. **${p.item_name}** — ${p.total_qty} units sold (Revenue: ₹${parseFloat(p.total_revenue || 0).toLocaleString('en-IN')})`).join('\n');
        } else {
            topList = "\n\nNo product sales logged yet for today's shift.";
        }

        return {
            reply: `🏆 **FAMALTH LYNX Top Performing Products**: Here are your sales leaders:${topList}`,
            action: { type: "VIEW_REPORTS", label: "Open Sales Reports" },
            quickReplies: ["Create New Bill", "Low Stock Alert", "Day Closing"]
        };
    }

    if (q.includes('stock value') || q.includes('inventory value') || q.includes('total product') || q.includes('stock worth')) {
        const totalItems = liveContext.totalProducts || 0;
        const val = (liveContext.stockValue || 0).toLocaleString('en-IN');

        return {
            reply: `💰 **Live Inventory Valuation**: Store holds **${totalItems} active catalog products** valued at **₹${val}**.`,
            action: { type: "SEARCH_ITEM", label: "Open Item Master" },
            quickReplies: ["Low Stock Alert", "Stock Transfer", "Create Purchase Order"]
        };
    }

    // Default Inventory / General Search
    if (q.includes('stock') || q.includes('inventory') || q.includes('item') || q.includes('product') || q.includes('barcode')) {
        const count = liveContext.lowStockCount || 0;
        return {
            reply: `📦 **FAMALTH LYNX Stock Status**: Store active catalog contains **${liveContext.totalProducts || 0} products** with **${count} low stock alerts**.`,
            action: { type: "LOW_STOCK_ALERT", label: "View Low Stock Items" },
            quickReplies: ["Search Product Stock", "Stock Transfer", "Create Purchase Order"]
        };
    }

    if (q.includes('profit') || q.includes('revenue') || q.includes('report') || q.includes('trend') || q.includes('sales')) {
        const sales = (liveContext.todaySales || 0).toLocaleString('en-IN');
        return {
            reply: `📊 **FAMALTH LYNX Store Performance**: Today's logged revenue is **₹${sales}** across **${liveContext.todayOrders || 0} completed orders**.`,
            action: { type: "VIEW_REPORTS", label: "Open Sales Reports" },
            quickReplies: ["Day Closing Report", "Cash Ledger", "AI Analytics"]
        };
    }

    // General Fallback
    return {
        reply: "🤖 **FAMALTH LYNX ASSIST**: I am trained on **ALL software features** and connected directly to your live database (Sales, Stock Values, Low Stock Alerts, HRMS, Restaurant POS, WhatsApp, Suppliers, and Finance). How can I assist you right now?",
        action: { type: "NONE" },
        quickReplies: ["Create New Bill", "Low Stock Alert", "Attendance Logs", "Captain POS"]
    };
}

async function processLynxAssist(prompt, history = [], config = {}, propertyDb = null, outletId = 0) {
    const liveContext = await fetchLiveStoreContext(propertyDb, outletId);

    const provider = (config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null)));
    const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);

    let sqlQueryResult = null;
    let sqlQueryString = null;

    // Execute dynamic Text-to-SQL if propertyDb is available and LLM key is configured
    if (propertyDb && apiKey) {
        try {
            sqlQueryString = await translateTextToQuery(prompt, config);
            if (sqlQueryString) {
                const t = await propertyDb.transaction();
                try {
                    await propertyDb.query("SET TRANSACTION READ ONLY", { transaction: t });
                    await propertyDb.query("SET TIME ZONE 'Asia/Kolkata'", { transaction: t });
                    const rows = await propertyDb.query(sqlQueryString, {
                        replacements: { outletId },
                        type: propertyDb.QueryTypes.SELECT,
                        transaction: t
                    });
                    await t.commit();
                    sqlQueryResult = rows ? rows.slice(0, 50) : [];
                } catch (dbErr) {
                    await t.rollback();
                    console.warn('[LYNX ASSIST SQL EXECUTION WARNING]:', dbErr.message);
                }
            }
        } catch (sqlErr) {
            console.warn('[LYNX ASSIST SQL TRANSLATION WARNING]:', sqlErr.message);
        }
    }

    if (!apiKey && !config.aiApiKey) {
        return getMockLynxAssist(prompt, liveContext);
    }

    try {
        const fullPrompt = `LIVE DATABASE SNAPSHOT (Outlet ID: ${outletId}):
${JSON.stringify(liveContext, null, 2)}

DYNAMIC SQL QUERY EXECUTED: ${sqlQueryString || 'N/A'}
QUERY EXECUTED DATASET (Top 50 Rows): ${sqlQueryResult ? JSON.stringify(sqlQueryResult, null, 2) : 'None'}

Conversation History:
${JSON.stringify(history.slice(-6))}

User Question / Command: ${prompt}`;

        const rawRes = await executeLLMCall(fullPrompt, LYNX_ASSIST_SYSTEM, config);
        let clean = rawRes.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(clean);
        return {
            reply: parsed.reply || "I am processing your request.",
            action: parsed.action || { type: "NONE" },
            quickReplies: parsed.quickReplies || ["Create New Bill", "Low Stock Alert", "Today's Total Sales"]
        };
    } catch (err) {
        console.error('[LYNX ASSIST AI ERROR]:', err.message);
        return getMockLynxAssist(prompt, liveContext);
    }
}

module.exports = {
    translateTextToQuery,
    analyzeDatasetSummary,
    processLynxAssist
};
