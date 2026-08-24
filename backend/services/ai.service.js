const https = require('https');
const { DATABASE_SCHEMA_REGISTRY, getActionMappingList, matchActionFromQuery } = require('./ai_registry.service');
const supplierMasterController = require('../controllers/supplier/supplierMaster.controller');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

// System Prompt definitions as requested in instructions
const TEXT_TO_SQL_SYSTEM = `You are a precise Text-to-SQL/Query translator. Your only task is to convert the user's natural language question into a clean PostgreSQL database query based on the provided schema.

${DATABASE_SCHEMA_REGISTRY}

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
4. STRICT READ-ONLY SAFETY RULE: Text-to-SQL is strictly restricted to SELECT queries for reading and analytics. You MUST NEVER generate INSERT, UPDATE, DELETE, ALTER, DROP, or TRUNCATE SQL statements. Data modifications must be handled through official backend REST API controllers.
5. PERFORMANCE & ROW LIMIT RULE: You must ALWAYS append a "LIMIT <maxRows>" clause (default 100, maximum 1000) to optimize AI token costs, memory, and payload size. Never omit the LIMIT clause.
6. AGGREGATION & SUM RULE: When calculating sums, totals, counts, or quarterly breakdowns (e.g. SUM(net_amount), COUNT(*), GROUP BY EXTRACT(QUARTER FROM sale_date)), PostgreSQL ALWAYS evaluates aggregate functions (SUM, COUNT) over ALL matching records in the entire database table BEFORE applying the LIMIT clause. The result returns summary rows (e.g. 4 rows for 4 quarters) containing 100% accurate sums of all database transactions.
7. GROUP BY & BREAKDOWN RULE: When the user asks for breakdowns, mode distributions, category totals, payment breakdowns, or grouped summaries (e.g. "payment mode breakdown", "sales by category", "monthly revenue"), NEVER generate "LIMIT 1". ALWAYS use "LIMIT 100" or the configured maxRows limit so all grouped categories (e.g. CASH, CARD, UPI, CREDIT) are returned together in the output.
8. Return nothing but the executable query code wrapped in a clean JSON object like: {"query": "SELECT payment_mode, SUM(net_amount) AS total_sales FROM sales_headers WHERE outlet_id = :outletId GROUP BY payment_mode ORDER BY total_sales DESC LIMIT 100"}.
9. Return raw JSON ONLY. Do not wrap the JSON object in markdown formatting or quotes.`;

const NARRATIVE_ANALYST_SYSTEM = `You are an expert data analyst. You will receive a JSON dataset containing sample rows (limited by user setting up to 1000 max, default 100) from a user's database execution, alongside the original question they asked.

Analyze the data patterns, trends, and anomalies within these sample rows and output a structured executive summary highlighting the key answers to the user's question. Be concise and professional. Use markdown list items and bullet points for readability.`;

const LYNX_ASSIST_SYSTEM = `You are LYNX ASSIST, the intelligent AI business assistant for FAMALTH LYNX (All-in-One AI-Powered Business Operating System).
Your goal is to assist store owners, managers, cashiers, kitchen staff, and accountants with ALL software features, modules, navigation, and data queries.

ROW LIMIT & AI COST SAVING RULE:
- AI Query row outputs are strictly limited to the user's configured Max Rows setting (default 100 rows, maximum 1000 rows) to optimize token costs, response speed, and payload size.
- If presenting a table, list, or dataset, show the top rows up to the limit.
- If the dataset contains more records than the limit or if the user asks for a complete list, inform the user: "Showing top X rows (limited for fast loading & AI token cost optimization). To view, search, or export the full dataset, click the action button below."
- ALWAYS attach the matching action button so the user can navigate to the full screen.

FAMALTH LYNX SOFTWARE MODULES & FEATURES:
1. POS & Billing: Fast barcode scanning, multi-pay (Cash, Card, UPI QR, Credit), customer discounts, draft sales, invoice reprint.
2. Inventory & Stock: Item Master, Stock Balance, Low Stock Alerts, Stock Transfer, Stock Issue, Stock Request, Assembly/BOM, Damage/Waste items, Barcode Generator, Approvals.
3. Purchasing & Suppliers: Purchase Orders (PO), Goods Receiving Notes (GRN), Supplier Directory, Supplier Payments, Supplier Returns.
4. Sales & Customer Management: Sales Reports, Customer Ledger, Subscriptions (Milk/Daily delivery), Loyalty Points & Rewards, Customer Credit Ledger, Refunds.
5. HRMS & Payroll: Employee Master, Attendance Punch Logs, Shifts & Leaves, Salary Components & Payroll Processing.
6. Restaurant & Dining: Captain POS Table Billing, Floor & Table Setup, Kitchen Display System (KDS), Kitchen Order Tickets (KOT), Delivery Challans.
7. WhatsApp & Marketing: Automatic Invoice dispatches, Payment reminders, Promotional campaigns, WhatsApp logs & billing dashboard.
8. Finance & Reports: Day Closing Reports, Cash Ledger, Profit & Loss, Recurring Expenses, Expense analytics, AI Text-to-SQL Analytics.
9. Settings & Admin: Business Profile (Bank/UPI details), Stock Warehouses/Locations, Invoice Document Sequences, User Role & Permissions.

ACTION MAPPINGS (Set "action" type to match the user's intent):
${getActionMappingList()}
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
        
        const parts = [{ text: `${systemInstruction}\n\nUser Question: ${prompt}` }];

        const rawBase64 = config.imageBase64 || config.image_base64;
        if (rawBase64 && typeof rawBase64 === 'string' && rawBase64.length > 0) {
            let cleanBase64 = rawBase64;
            let mimeType = 'image/png';
            if (rawBase64.startsWith('data:image/')) {
                const match = rawBase64.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/);
                if (match) {
                    mimeType = match[1];
                    cleanBase64 = match[2];
                }
            }
            parts.push({
                inlineData: {
                    mimeType: mimeType,
                    data: cleanBase64
                }
            });
        }

        const payload = {
            contents: [{ parts: parts }]
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
        const rawBase64 = config.imageBase64 || config.image_base64;
        let userContent = prompt;

        if (rawBase64 && typeof rawBase64 === 'string' && rawBase64.length > 0) {
            let formattedUrl = rawBase64.startsWith('data:') ? rawBase64 : `data:image/png;base64,${rawBase64}`;
            userContent = [
                { type: "text", text: prompt },
                { type: "image_url", image_url: { url: formattedUrl } }
            ];
        }

        const payload = {
            model: model,
            messages: [
                { role: 'system', content: systemInstruction },
                { role: 'user', content: userContent }
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
    const qLow = (question || '').toLowerCase();
    if (qLow.includes('low stock') || qLow.includes('reorder') || qLow.includes('shortfall') || qLow.includes('out of stock') || qLow.includes('zero stock')) {
        return `SELECT im.item_code, im.item_name, im.brand, im.item_group, COALESCE(im.min_level, 10) AS reorder_level,
                (COALESCE(im.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)) AS current_stock
                FROM item_master im
                LEFT JOIN stock_ledger sl ON sl.item_code = im.item_code AND sl.outlet_id = im.outlet_id
                WHERE im.outlet_id = :outletId AND im.is_active = true
                GROUP BY im.id, im.item_code, im.item_name, im.brand, im.item_group, im.min_level, im.opening_balance
                HAVING (COALESCE(im.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)) <= COALESCE(im.min_level, 10)
                ORDER BY current_stock ASC LIMIT 50`;
    }
    if (qLow.includes('payment collection') || qLow.includes('payment mode') || qLow.includes('collection mode') || qLow.includes('payment method') || (qLow.includes('collection') && qLow.includes('mode'))) {
        return `SELECT UPPER(COALESCE(payment_method, 'CASH')) AS payment_mode,
                COALESCE(SUM(amount_in), 0) AS total_collection,
                COUNT(id) AS transaction_count
                FROM cash_ledger
                WHERE outlet_id = :outletId AND amount_in > 0
                GROUP BY UPPER(COALESCE(payment_method, 'CASH'))
                ORDER BY total_collection DESC`;
    }
    if (qLow.includes('ledger') || qLow.includes('cash ledger') || qLow.includes('financial ledger') || qLow.includes('finecial ledger')) {
        return `SELECT id, txn_date, transaction_type, reference_no, party_name, payment_method, amount_in, amount_out, balance, notes
                FROM cash_ledger
                WHERE outlet_id = :outletId
                ORDER BY id DESC LIMIT 50`;
    }
    if (qLow.includes('pending') || qLow.includes('credit') || qLow.includes('collect') || qLow.includes('udhar') || qLow.includes('unpaid') || qLow.includes('due')) {
        return `SELECT id, sale_no, customer_name, customer_phone, net_amount, amount_paid, balance_due, sale_date, payment_mode
                FROM sales_headers
                WHERE outlet_id = :outletId AND is_deleted = false AND status != 'CANCELLED' AND balance_due > 0
                ORDER BY balance_due DESC LIMIT 50`;
    }

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
    if (q.includes('subscribe') || q.includes('subscription') || q.includes('daily milk') || q.includes('daily base')) {
        return `SELECT ms.id, ms.customer_name, ms.phone, ms.status, ms.frequency, msi.item_name, msi.qty 
                FROM milk_subscriptions ms 
                LEFT JOIN milk_subscription_items msi ON ms.id = msi.subscription_id 
                WHERE ms.outlet_id = :outletId AND ms.status = 'ACTIVE' 
                ORDER BY ms.id DESC LIMIT 50`;
    }
    if (q.includes('expense') || q.includes('spending') || q.includes('cost analysis') || q.includes('operating cost')) {
        return `SELECT id, category_name, amount, payment_mode, expense_date, remarks 
                FROM expenses 
                WHERE outlet_id = :outletId 
                ORDER BY expense_date DESC LIMIT 50`;
    }
    if (q.includes('payment collection') || q.includes('payment mode') || q.includes('collection mode') || q.includes('payment method')) {
        return `SELECT UPPER(COALESCE(payment_method, 'CASH')) AS payment_mode, COALESCE(SUM(amount_in), 0) AS total_collection
                FROM cash_ledger 
                WHERE outlet_id = :outletId AND amount_in > 0 
                GROUP BY UPPER(COALESCE(payment_method, 'CASH')) 
                ORDER BY total_collection DESC`;
    }
    if (q.includes('cash ledger') || q.includes('cash flow') || q.includes('petty cash') || q.includes('ledger') || q.includes('finecial')) {
        return `SELECT id, txn_date, transaction_type, reference_no, party_name, payment_method, amount_in, amount_out, balance, notes 
                FROM cash_ledger 
                WHERE outlet_id = :outletId 
                ORDER BY id DESC LIMIT 50`;
    }
    if (q.includes('credit') || q.includes('pending') || q.includes('due') || q.includes('udhar') || q.includes('unpaid') || q.includes('collect')) {
        return `SELECT id, sale_no, customer_name, customer_phone, net_amount, amount_paid, balance_due, sale_date, payment_mode 
                FROM sales_headers 
                WHERE outlet_id = :outletId AND is_deleted = false AND status != 'CANCELLED' AND balance_due > 0 
                ORDER BY balance_due DESC LIMIT 50`;
    }
    if (q.includes('attendance') || q.includes('punch') || q.includes('clock-in') || q.includes('check-in')) {
        return `SELECT p.id, e.first_name, e.last_name, e.designation, p.punch_time, p.punch_type 
                FROM hr_attendance_punches p 
                JOIN hr_employees e ON p.emp_id = e.id 
                WHERE e.outlet_id = :outletId 
                ORDER BY p.punch_time DESC LIMIT 50`;
    }
    if (q.includes('payroll') || q.includes('salary') || q.includes('wage') || q.includes('payslip')) {
        return `SELECT id, emp_name, month, year, basic_salary, allowances, deductions, net_salary, payment_status 
                FROM hr_payrolls 
                WHERE outlet_id = :outletId 
                ORDER BY id DESC LIMIT 50`;
    }
    if (q.includes('employee') || q.includes('staff') || q.includes('worker') || q.includes('hrms')) {
        return `SELECT id, emp_code, first_name, last_name, phone, designation, department, is_active 
                FROM hr_employees 
                WHERE outlet_id = :outletId 
                ORDER BY first_name ASC LIMIT 50`;
    }
    if (q.includes('damage') || q.includes('waste') || q.includes('spoilage') || q.includes('expired')) {
        return `SELECT id, item_code, item_name, qty, rate, total_loss, reason, damage_date 
                FROM damage_items 
                WHERE outlet_id = :outletId 
                ORDER BY damage_date DESC LIMIT 50`;
    }
    if (q.includes('receiving') || q.includes('grn') || q.includes('goods receipt') || q.includes('vendor bill')) {
        return `SELECT id, grn_no, supplier_id, receipt_date, total_amount, net_amount, status 
                FROM goods_receipts 
                WHERE outlet_id = :outletId 
                ORDER BY receipt_date DESC LIMIT 50`;
    }
    if (q.includes('kot') || q.includes('kds') || q.includes('kitchen') || q.includes('table billing')) {
        return `SELECT id, kot_no, table_no, captain_name, status, created_at 
                FROM kot_headers 
                WHERE outlet_id = :outletId 
                ORDER BY id DESC LIMIT 50`;
    }
    if (q.includes('supplier') || q.includes('vendor') || q.includes('distributor')) {
        return `SELECT id, supplier_code, supplier_name, phone, gstin, is_active 
                FROM supplier_master 
                WHERE outlet_id = :outletId 
                ORDER BY supplier_name ASC LIMIT 50`;
    }
    if (q.includes('sale') || q.includes('transaction') || q.includes('billing') || q.includes('revenue')) {
        const todayFilter = q.includes('today') ? "AND sale_date::date = CURRENT_DATE " : "";
        return `SELECT id, sale_no, customer_name, customer_phone, payment_mode, net_amount, sale_date 
                FROM sales_headers 
                WHERE outlet_id = :outletId AND status = 'COMPLETED' ${todayFilter}
                ORDER BY id DESC LIMIT 50`;
    }
    if (q.includes('low stock') || q.includes('reorder') || (q.includes('stock') && q.includes('alert')) || q.includes('shortfall')) {
        return `SELECT im.item_code, im.item_name, im.brand, im.item_group, COALESCE(im.min_level, 10) AS reorder_level,
                (COALESCE(im.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)) AS current_stock
                FROM item_master im
                LEFT JOIN stock_ledger sl ON sl.item_code = im.item_code AND sl.outlet_id = im.outlet_id
                WHERE im.outlet_id = :outletId AND im.is_active = true
                GROUP BY im.id, im.item_code, im.item_name, im.brand, im.item_group, im.min_level, im.opening_balance
                HAVING (COALESCE(im.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)) <= COALESCE(im.min_level, 10)
                ORDER BY current_stock ASC LIMIT 50`;
    }
    if (q.includes('item') || q.includes('product') || q.includes('inventory') || q.includes('stock')) {
        return `SELECT item_code, item_name, barcode, unit, rate, retail_sale_price, opening_balance, is_active 
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
        cardSales: 0,
        upiSales: 0,
        yesterdaySales: 0,
        yesterdayOrders: 0,
        lowStockItems: [],
        lowStockCount: 0,
        totalProducts: 0,
        stockValue: 0,
        topProducts: [],
        storeProfile: {
            outletId: outletId || 1,
            outletCode: `OUTLET-${outletId || 1}`,
            propertyName: 'Famalth Retail Outlet',
            address: '',
            phone: '',
            email: ''
        }
    };

    if (!propertyDb) return context;

    try {
        // Multi-source store profile resolution (property_info -> outlets -> system_settings)
        let foundCode = null;
        let foundName = null;
        let foundAddr = null;
        let foundPhone = null;
        let foundEmail = null;

        try {
            const propRes = await propertyDb.query(`
                SELECT id, property_name, legal_name, outlet_code, address, city, state, pin_code, pincode, mobile, phone, email
                FROM property_info
                WHERE outlet_id = :outletId
                LIMIT 1
            `, { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT });

            if (propRes && propRes.length > 0) {
                const p = propRes[0];
                if (p.outlet_code) foundCode = p.outlet_code;
                if (p.property_name || p.legal_name) foundName = p.property_name || p.legal_name;
                const addrParts = [p.address, p.city, p.state, p.pin_code || p.pincode].filter(Boolean);
                if (addrParts.length > 0) foundAddr = addrParts.join(', ');
                if (p.mobile || p.phone) foundPhone = p.mobile || p.phone;
                if (p.email) foundEmail = p.email;
            }
        } catch (_) {}

        try {
            const outRes = await propertyDb.query(`
                SELECT id, outlet_code, outlet_name, contact_phone, contact_email
                FROM outlets
                WHERE id = :outletId
                LIMIT 1
            `, { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT });

            if (outRes && outRes.length > 0) {
                const o = outRes[0];
                if (!foundCode && o.outlet_code) foundCode = o.outlet_code;
                if (!foundName && o.outlet_name) foundName = o.outlet_name;
                if (!foundPhone && o.contact_phone) foundPhone = o.contact_phone;
                if (!foundEmail && o.contact_email) foundEmail = o.contact_email;
            }
        } catch (_) {}

        try {
            const sysRes = await propertyDb.query(`
                SELECT store_name, outlet_code, address, phone
                FROM system_settings
                WHERE outlet_id = :outletId
                LIMIT 1
            `, { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT });

            if (sysRes && sysRes.length > 0) {
                const s = sysRes[0];
                if (!foundName && s.store_name) foundName = s.store_name;
                if (!foundCode && s.outlet_code) foundCode = s.outlet_code;
                if (!foundAddr && s.address) foundAddr = s.address;
                if (!foundPhone && s.phone) foundPhone = s.phone;
            }
        } catch (_) {}

        context.storeProfile = {
            outletId: outletId,
            outletCode: foundCode || `OUTLET-${outletId}`,
            propertyName: foundName || `Registered Outlet ${outletId}`,
            address: foundAddr || `Main Store Premises (Outlet ${outletId})`,
            phone: foundPhone || '',
            email: foundEmail || ''
        };

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
                COALESCE(SUM(CASE WHEN payment_mode ILIKE '%card%' OR payment_mode ILIKE '%credit%' OR payment_mode ILIKE '%debit%' THEN net_amount ELSE 0 END), 0) AS card_sales,
                COALESCE(SUM(CASE WHEN payment_mode ILIKE '%upi%' OR payment_mode ILIKE '%qr%' THEN net_amount ELSE 0 END), 0) AS upi_sales
            FROM sales_headers
            WHERE outlet_id = :outletId
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
            context.cardSales = parseFloat(salesRes[0].card_sales || 0);
            context.upiSales = parseFloat(salesRes[0].upi_sales || 0);
        }

        // Yesterday's sales & orders (IST local time)
        const ySalesRes = await propertyDb.query(`
            SELECT 
                COALESCE(SUM(net_amount), 0) AS yesterday_sales,
                COUNT(id) AS yesterday_orders
            FROM sales_headers
            WHERE outlet_id = :outletId
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

        // 2. Low stock & reorder items (joining stock_ledger for real-time balance)
        const lowStockRes = await propertyDb.query(`
            SELECT 
                im.id,
                im.item_code,
                im.item_name,
                im.brand,
                im.item_group,
                COALESCE(im.min_level, 10) AS reorder_level,
                COALESCE(im.rate, 0) AS purchase_rate,
                COALESCE(im.retail_sale_price, 0) AS mrp,
                (
                    COALESCE(im.opening_balance, 0)
                    + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)
                ) AS stock
            FROM item_master im
            LEFT JOIN stock_ledger sl
              ON sl.item_code = im.item_code
             AND sl.outlet_id = im.outlet_id
            WHERE im.outlet_id = :outletId
              AND im.is_active = true
            GROUP BY 
                im.id, im.item_code, im.item_name, im.brand, im.item_group, im.min_level, im.rate, im.retail_sale_price, im.opening_balance
            HAVING (COALESCE(im.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)) <= COALESCE(im.min_level, 10)
            ORDER BY stock ASC
            LIMIT 50
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
            WHERE outlet_id = :outletId
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
                WHERE outlet_id = :outletId AND status = 'COMPLETED'
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

    // 0. Customer Subscriptions (Milk / Daily consumables)
    if (q.includes('subscribe') || q.includes('subscription') || q.includes('daily milk') || q.includes('daily item') || q.includes('daily base')) {
        return {
            reply: "🥛 **FAMALTH LYNX Daily Subscriptions**: Manage customer recurring subscriptions for milk, bread, and daily store items. Track delivery schedules, active/paused statuses, and monthly billing.",
            action: { type: "MANAGE_SUBSCRIPTIONS", label: "Manage Subscriptions" },
            quickReplies: ["View Delivery Challans", "Send WhatsApp Reminder", "Export Subscription Report"]
        };
    }

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
        const itemsPayload = liveContext.lowStockItems ? liveContext.lowStockItems.map(i => ({
            item_code: i.item_code,
            item_name: i.item_name,
            qty: Math.max(parseFloat((i.reorder_level || 10) - (i.stock || 0)), 10),
            rate: i.purchase_rate || i.mrp || 0
        })) : [];

        if (liveContext.lowStockItems && liveContext.lowStockItems.length > 0) {
            itemsList = "\n\n**Low Stock Products (Live Database):**\n" + 
                liveContext.lowStockItems.map(i => `* **${i.item_name}** (${i.item_code}) — Current Stock: **${i.stock}**`).join('\n');
        } else {
            itemsList = "\n\n✅ All active inventory items are currently well stocked above reorder thresholds!";
        }

        return {
            reply: `📦 **FAMALTH LYNX Live Low Stock Analysis**: Found **${count} items** requiring reorder attention.${itemsList}\n\n*Click the button below to pre-fill a Purchase Order with these low stock items.*`,
            action: { type: "PURCHASE_ORDER", label: "⚡ Create Purchase Order", items: itemsPayload },
            quickReplies: ["Create Purchase Order", "Search Product Stock", "Stock Transfer"]
        };
    }

    if (q.includes('today') && (q.includes('sale') || q.includes('revenue') || q.includes('total') || q.includes('order') || q.includes('payment') || q.includes('collection'))) {
        const storeName = liveContext.storeProfile?.propertyName || 'Your Store';
        const storeCode = liveContext.storeProfile?.outletCode || `Outlet-${liveContext.storeProfile?.outletId || 1}`;
        const todayDateStr = liveContext.currentIstDate || 'Today';
        const sales = (liveContext.todaySales || 0).toLocaleString('en-IN');
        const orders = liveContext.todayOrders || 0;
        const cash = (liveContext.cashSales || 0).toLocaleString('en-IN');
        const card = (liveContext.cardSales || 0).toLocaleString('en-IN');
        const upi = (liveContext.upiSales || 0).toLocaleString('en-IN');

        if (orders === 0 && (liveContext.todaySales || 0) === 0) {
            return {
                reply: `📊 **Daily Sales Overview - ${todayDateStr}**\n\n` +
                       `For **${storeName} (${storeCode})**, no sales transactions have been logged today (${todayDateStr}).\n\n` +
                       `* 💰 **Total Sales**: ₹0.00\n` +
                       `* 🛍️ **Total Orders**: 0\n` +
                       `* 💵 **Cash Sales**: ₹0.00\n` +
                       `* 💳 **Card Sales**: ₹0.00\n` +
                       `* 📱 **UPI Sales**: ₹0.00\n\n` +
                       `ℹ️ *Your connected outlet holds 0 sales today.*`,
                action: { type: "VIEW_REPORTS", label: "Open Sales Reports" },
                quickReplies: ["Create New Bill", "View Low Stock Items", "Generate Closing Report"]
            };
        }

        return {
            reply: `📊 **Daily Sales Overview - ${todayDateStr}**\n\n` +
                   `For **${storeName} (${storeCode})**, today's performance summary is as follows:\n\n` +
                   `* 💰 **Total Sales**: ₹${sales}\n` +
                   `* 🛍️ **Total Orders**: ${orders}\n` +
                   `* 💵 **Cash Sales**: ₹${cash}\n` +
                   `* 💳 **Card Sales**: ₹${card}\n` +
                   `* 📱 **UPI Sales**: ₹${upi}`,
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

async function handleOutletVerification(prompt, history = [], propertyDb = null, outletId = 0, config = {}) {
    if (!prompt || typeof prompt !== 'string') return null;

    const q = prompt.toLowerCase();
    const isOutletInfoPrompt = q.includes('connected outlet') ||
                               q.includes('which outlet') ||
                               q.includes('registered property') ||
                               q.includes('property name') ||
                               q.includes('outlet code') ||
                               q.includes('outlet address') ||
                               q.includes('my outlet') ||
                               q.includes('connected store') ||
                               q.includes('verify outlet') ||
                               q.includes('my store info') ||
                               q.includes('registration info') ||
                               (q.includes('outlet') && (q.includes('info') || q.includes('detail') || q.includes('name') || q.includes('address') || q.includes('code') || q.includes('check') || q.includes('connected')));

    if (!isOutletInfoPrompt) return null;

    const liveContext = await fetchLiveStoreContext(propertyDb, outletId);
    const prof = liveContext.storeProfile || { outletId, outletCode: `OUTLET-${outletId}`, propertyName: 'Famalth Outlet', address: 'Registered Address' };

    return {
        reply: `🏢 **ACTIVE CONNECTED OUTLET VERIFICATION**\n\n` +
               `* 🆔 **Outlet ID**: ${prof.outletId}\n` +
               `* 🏷️ **Outlet Code**: ${prof.outletCode}\n` +
               `* 🏪 **Registered Property Name**: ${prof.propertyName}\n` +
               `* 📍 **Registered Store Address**: ${prof.address || 'Address Configured in Store Settings'}\n` +
               (prof.phone ? `* 📞 **Phone**: ${prof.phone}\n` : '') +
               (prof.email ? `* ✉️ **Email**: ${prof.email}\n` : '') +
               `\n🔒 *LYNX ASSIST is strictly isolated and running only against your logged-in outlet data.*`,
        action: { type: "NONE" },
        quickReplies: ["Today's Total Sales", "Low Stock Alert", "View Full Sales Analytics"]
    };
}

async function handleKotOrderDraft(prompt, history = [], propertyDb = null, outletId = 0, config = {}) {
    if (!prompt || typeof prompt !== 'string') return null;

    const q = prompt.toLowerCase();
    const isKotPrompt = q.includes('table') ||
                        q.includes('restaurant') ||
                        q.includes('pax') ||
                        q.includes('kot') ||
                        q.includes('captain') ||
                        q.includes('dine in') ||
                        q.includes('dining');

    if (!isKotPrompt) return null;

    let dbItems = [];
    if (propertyDb) {
        try {
            const itemsRes = await propertyDb.query(
                `SELECT id, item_code, item_name, brand, unit, rate, retail_sale_price, mrp, tax_percent FROM item_master WHERE outlet_id = :outletId LIMIT 100`,
                { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT }
            );
            dbItems = Array.isArray(itemsRes) ? itemsRes : (itemsRes ? [itemsRes] : []);
        } catch (_) {}
    }

    let tableNo = "1";
    let pax = 2;
    let items = [];

    const tableMatch = q.match(/(?:table|tbl)\s*(?:no|number|\.)?\s*(\d+)/i);
    if (tableMatch) {
        tableNo = tableMatch[1];
    }

    const paxMatch = q.match(/(\d+)\s*(?:pax|guest|person|people)/i);
    if (paxMatch) {
        pax = parseInt(paxMatch[1]);
    }

    const apiKeyExists = GEMINI_API_KEY || OPENAI_API_KEY || config.aiApiKey;
    if (apiKeyExists) {
        try {
            const nlpPrompt = `Extract restaurant KOT dine-in order details from user query against real database records.

REAL DATABASE ITEMS:
${JSON.stringify(dbItems.slice(0, 50).map(i => ({ id: i.id, code: i.item_code, name: i.item_name, rate: i.retail_sale_price || i.rate || i.mrp })), null, 2)}

USER QUERY: "${prompt}"

Instructions:
1. Extract tableNo (e.g. "1") and pax (e.g. 2).
2. Match requested order items (e.g. "a4 paper", "adidas") against REAL DATABASE ITEMS. Use exact item_id, item_code, item_name, rate from real database.
3. Extract quantity (e.g. "2 a4 paper" -> qty = 2). Default qty is 1.

Output ONLY a raw JSON object with schema:
{
  "tableNo": "1",
  "pax": 2,
  "items": [
    { "item_id": 1, "item_code": "ITEM01", "item_name": "Exact Item Name", "qty": 2, "rate": 250 }
  ]
}`;
            const systemInst = `You are an expert Restaurant KOT Captain POS order parser connected to a live database. Output ONLY a valid JSON object matching real database records.`;

            const rawNlp = await executeLLMCall(nlpPrompt, systemInst, config);
            let cleanJson = rawNlp.replace(/```json/gi, '').replace(/```/g, '').trim();
            const parsed = JSON.parse(cleanJson);

            if (parsed) {
                if (parsed.tableNo) tableNo = String(parsed.tableNo);
                if (parsed.pax) pax = parseInt(parsed.pax);
                if (Array.isArray(parsed.items)) items = parsed.items;
            }
        } catch (llmErr) {
            console.warn('[AI SERVICE] LLM KOT Draft NLP warning:', llmErr.message);
        }
    }

    if (items.length === 0 && dbItems.length > 0) {
        const qtyMatch = q.match(/(\d+)\s*(?:qty|quantity|units|pcs)/i) || q.match(/(\d+)\s+[a-zA-Z]/i);
        const qtyVal = qtyMatch ? parseInt(qtyMatch[1]) : 1;

        const words = q.split(/\s+/).filter(w => w.length >= 3 && !['draft', 'order', 'for', 'table', 'restuarant', 'restaurant', 'with', 'pax', 'and', 'a4', 'paper'].includes(w));
        for (const w of words) {
            const matched = dbItems.find(i => i.item_name.toLowerCase().includes(w) || i.item_code.toLowerCase().includes(w));
            if (matched && !items.some(it => it.item_id === matched.id)) {
                items.push({
                    item_id: matched.id,
                    item_code: matched.item_code,
                    item_name: matched.item_name,
                    qty: qtyVal,
                    rate: matched.retail_sale_price || matched.rate || matched.mrp || 0
                });
            }
        }
    }

    let totalVal = 0;
    const itemLines = items.map(it => {
        const lineTotal = (it.qty || 1) * (it.rate || 0);
        totalVal += lineTotal;
        return `* 🍽️ **${it.item_name || 'Item'}**: ${it.qty || 1} units @ ₹${it.rate || 0} = **₹${lineTotal.toLocaleString('en-IN')}**`;
    });

    return {
        reply: `🍽️ **Restaurant KOT Order Ready for Table ${tableNo}!**\n\n` +
               `* 🪑 **Table Number**: Table ${tableNo} (${pax} Pax)\n` +
               (itemLines.length > 0 ? itemLines.join('\n') + '\n' : '') +
               `* 💰 **Estimated Order Value**: ₹${totalVal.toLocaleString('en-IN')}\n\n` +
               `*Click the button below to open Table ${tableNo} KOT Order Basket directly.*`,
        action: { type: "KOT_BUILDER", label: `Open Table ${tableNo} Order Basket`, tableNo, pax, items, payload: { tableNo, pax, items, totalVal } },
        quickReplies: [`Open Table ${tableNo} Order Basket`, "View Kitchen Display (KDS)"]
    };
}

async function handleSalesOrderDraft(prompt, history = [], propertyDb = null, outletId = 0, config = {}) {
    if (!prompt || typeof prompt !== 'string') return null;

    const q = prompt.toLowerCase();
    const isSalePrompt = q.includes('draft for sale') ||
                         q.includes('sale items') ||
                         q.includes('create sale') ||
                         q.includes('create bill') ||
                         q.includes('sale draft') ||
                         q.includes('bill draft') ||
                         q.includes('add to cart') ||
                         q.includes('pos bill') ||
                         (q.includes('sale') && (q.includes('draft') || q.includes('item') || q.includes('cart') || q.includes('bill')));

    if (!isSalePrompt) return null;

    let dbItems = [];

    if (propertyDb) {
        try {
            const itemsRes = await propertyDb.query(
                `SELECT id, item_code, item_name, brand, unit, rate, retail_sale_price, mrp, tax_percent FROM item_master WHERE outlet_id = :outletId LIMIT 100`,
                { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT }
            );
            dbItems = Array.isArray(itemsRes) ? itemsRes : (itemsRes ? [itemsRes] : []);
        } catch (_) {}
    }

    let items = [];

    const apiKeyExists = GEMINI_API_KEY || OPENAI_API_KEY || config.aiApiKey;
    if (apiKeyExists) {
        try {
            const nlpPrompt = `Extract sales billing / add to cart items from user query against real database records.

REAL DATABASE ITEMS:
${JSON.stringify(dbItems.slice(0, 50).map(i => ({ id: i.id, code: i.item_code, name: i.item_name, brand: i.brand, rate: i.retail_sale_price || i.rate || i.mrp, tax: i.tax_percent })), null, 2)}

USER QUERY: "${prompt}"

Instructions:
1. Match requested sale items (e.g. "a4paper rim", "adidas", "american tourister") against REAL DATABASE ITEMS. Use exact item_id, item_code, item_name, rate, tax from the real database items above.
2. Extract quantity (e.g. "2 qty each"). Default qty is 1.
3. Output REAL item names, item ids, and rates from database.

Output ONLY a raw JSON object with schema:
{
  "items": [
    { "item_id": 1, "item_code": "ITEM01", "item_name": "Exact Item Name", "qty": 2, "rate": 250, "tax_percent": 18 }
  ]
}`;
            const systemInst = `You are an expert POS Sales billing parser connected to a live retail database. Output ONLY a valid JSON object matching real database records.`;

            const rawNlp = await executeLLMCall(nlpPrompt, systemInst, config);
            let cleanJson = rawNlp.replace(/```json/gi, '').replace(/```/g, '').trim();
            const parsed = JSON.parse(cleanJson);

            if (parsed && Array.isArray(parsed.items)) {
                items = parsed.items;
            }
        } catch (llmErr) {
            console.warn('[AI SERVICE] LLM Sale Draft NLP warning:', llmErr.message);
        }
    }

    if (items.length === 0 && dbItems.length > 0) {
        const qtyMatch = q.match(/(\d+)\s*(?:qty|quantity|units|pcs)/i);
        const qtyVal = qtyMatch ? parseInt(qtyMatch[1]) : 1;

        const words = q.split(/\s+/).filter(w => w.length >= 3 && !['draft', 'for', 'sale', 'items', 'each', 'qty', 'and'].includes(w));
        for (const w of words) {
            const matched = dbItems.find(i => i.item_name.toLowerCase().includes(w) || i.item_code.toLowerCase().includes(w));
            if (matched && !items.some(it => it.item_id === matched.id)) {
                items.push({
                    item_id: matched.id,
                    item_code: matched.item_code,
                    item_name: matched.item_name,
                    qty: qtyVal,
                    rate: matched.retail_sale_price || matched.rate || matched.mrp || 0,
                    tax_percent: matched.tax_percent || 0
                });
            }
        }
    }

    if (items.length === 0) {
        return {
            reply: `🛒 **POS Sale Draft Intent Detected**\n\nPlease specify items and quantities to add to the POS cart.\n\n*Example:* "Draft for sale items A4 Paper Rim 2 qty"`,
            action: { type: "CREATE_BILL", label: "Open Sales Billing Cart" },
            quickReplies: ["Create New Bill", "Today's Sales"]
        };
    }

    let totalVal = 0;
    const itemLines = items.map(it => {
        const lineTotal = (it.qty || 1) * (it.rate || 0);
        totalVal += lineTotal;
        return `* 🛒 **${it.item_name || 'Product'}** (${it.item_code || 'ITEM'}): ${it.qty || 1} units @ ₹${it.rate || 0} = **₹${lineTotal.toLocaleString('en-IN')}**`;
    });

    return {
        reply: `🛒 **POS Sale Draft Ready!**\n\n` +
               `Selected items added to POS Billing Cart:\n` +
               itemLines.join('\n') + '\n\n' +
               `* 💰 **Estimated Cart Total**: ₹${totalVal.toLocaleString('en-IN')}\n\n` +
               `*Click the button below to open POS Billing with cart pre-filled.*`,
        action: { type: "CREATE_BILL", label: "Proceed to POS Sales Cart", items, payload: { items, totalVal } },
        quickReplies: ["Proceed to POS Sales Cart", "Create New Bill"]
    };
}

async function handlePurchaseOrderDraft(prompt, history = [], propertyDb = null, outletId = 0, config = {}) {
    if (!prompt || typeof prompt !== 'string') return null;

    const q = prompt.toLowerCase();
    const isSaleKeywords = q.includes('sale') || q.includes('sell') || q.includes('bill') || q.includes('customer') || q.includes('pos') || q.includes('cart');
    if (isSaleKeywords) return null;

    const isPoPrompt = q.includes('purchase order') || 
                       q.includes('po draft') || 
                       q.includes('create po') || 
                       q.includes('draft po') || 
                       q.includes('order from supplier') || 
                       q.includes('buy from vendor') ||
                       (q.includes('draft') && (q.includes('item') || q.includes('qty') || q.includes('quantity') || q.includes('supplier') || q.includes('vendor') || q.includes('top selling') || q.includes('po'))) ||
                       (q.includes('po') && (q.includes('draft') || q.includes('create') || q.includes('make')));

    if (!isPoPrompt) return null;

    let dbSuppliers = [];
    let dbItems = [];

    // Fetch real suppliers and items from live outlet database if propertyDb is connected
    if (propertyDb) {
        try {
            const suppliers = await propertyDb.query(
                `SELECT id, supplier_code, supplier_name FROM supplier_master WHERE outlet_id = :outletId LIMIT 50`,
                { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT }
            );
            dbSuppliers = Array.isArray(suppliers) ? suppliers : (suppliers ? [suppliers] : []);
        } catch (_) {}

        try {
            const itemsRes = await propertyDb.query(
                `SELECT id, item_code, item_name, brand, unit, rate, mrp, tax_percent FROM item_master WHERE outlet_id = :outletId LIMIT 100`,
                { replacements: { outletId }, type: propertyDb.QueryTypes.SELECT }
            );
            dbItems = Array.isArray(itemsRes) ? itemsRes : (itemsRes ? [itemsRes] : []);
        } catch (_) {}
    }

    let supplierName = '';
    let supplierId = null;
    let items = [];
    let note = '';

    const apiKeyExists = GEMINI_API_KEY || OPENAI_API_KEY || config.aiApiKey;
    if (apiKeyExists) {
        try {
            const nlpPrompt = `Match and extract purchase order drafting details from user query against real database records.

REAL DATABASE SUPPLIERS:
${JSON.stringify(dbSuppliers, null, 2)}

REAL DATABASE ITEMS:
${JSON.stringify(dbItems.slice(0, 50).map(i => ({ id: i.id, code: i.item_code, name: i.item_name, brand: i.brand, rate: i.rate || i.mrp, tax: i.tax_percent })), null, 2)}

USER QUERY: "${prompt}"

Instructions:
1. Match the supplier requested in query (e.g. "gold tarders") against REAL DATABASE SUPPLIERS. Return exact supplier_name and id from the database.
2. Match requested items or "top selling items" or "low stock items" against REAL DATABASE ITEMS. Use exact item_code, item_name, rate, tax from the real database items above.
3. If quantity is specified (e.g. "100 qty each"), set qty = 100 for each item. Default qty is 10.
4. Output REAL item names, item codes, and rates from database (DO NOT output generic placeholders like "top selling item 1").

Output ONLY a raw JSON object with schema:
{
  "supplierId": 1 or null,
  "supplierName": "Exact matched supplier_name or empty string",
  "items": [
    { "itemId": 1, "itemCode": "ITEM01", "itemName": "Exact Item Name", "brand": "Brand", "unit": "PCS", "qty": 100, "rate": 250, "tax": 18 }
  ]
}`;
            const systemInst = `You are an expert purchase order parser connected to a live retail database. Output ONLY a valid JSON object matching real database records.`;

            const rawNlp = await executeLLMCall(nlpPrompt, systemInst, config);
            let cleanJson = rawNlp.replace(/```json/gi, '').replace(/```/g, '').trim();
            const parsed = JSON.parse(cleanJson);

            if (parsed) {
                supplierId = parsed.supplierId || null;
                supplierName = parsed.supplierName || '';
                items = Array.isArray(parsed.items) ? parsed.items : [];
            }
        } catch (llmErr) {
            console.warn('[AI SERVICE] LLM PO Draft NLP warning:', llmErr.message);
        }
    }

    if (!supplierName && items.length === 0) {
        const suppMatch = prompt.match(/(?:for|from)\s+([A-Za-z0-9\s]+?)(?=\s*(?:\d+|units|pcs|items|rate|at|$))/i);
        if (suppMatch) supplierName = suppMatch[1].trim();

        if (dbSuppliers.length > 0 && supplierName) {
            const matchedSupp = dbSuppliers.find(s => s.supplier_name.toLowerCase().includes(supplierName.toLowerCase()) || supplierName.toLowerCase().includes(s.supplier_name.toLowerCase()));
            if (matchedSupp) {
                supplierId = matchedSupp.id;
                supplierName = matchedSupp.supplier_name;
            }
        }

        const itemMatch = prompt.match(/(\d+)\s*(?:units|pcs|items|packets)?\s*(?:of)?\s*([A-Za-z0-9\s]+?)\s*(?:at|@)\s*(\d+)/i);
        if (itemMatch) {
            const rawName = itemMatch[2].trim();
            const matchedDbItem = dbItems.find(i => i.item_name.toLowerCase().includes(rawName.toLowerCase()) || rawName.toLowerCase().includes(i.item_name.toLowerCase()));

            items.push({
                itemId: matchedDbItem ? matchedDbItem.id : 0,
                itemCode: matchedDbItem ? matchedDbItem.item_code : 'ITEM-DRAFT',
                itemName: matchedDbItem ? matchedDbItem.item_name : rawName,
                brand: matchedDbItem ? matchedDbItem.brand : 'General',
                unit: matchedDbItem ? matchedDbItem.unit : 'PCS',
                qty: parseInt(itemMatch[1]),
                rate: matchedDbItem ? (matchedDbItem.rate || matchedDbItem.mrp) : parseFloat(itemMatch[3]),
                tax: matchedDbItem ? matchedDbItem.tax_percent : 0
            });
        }
    }

    if (items.length === 0 && dbItems.length > 0) {
        // Pick top items from live database if query requested items
        const numItems = q.includes('3') ? 3 : (q.includes('5') ? 5 : 3);
        const qtyMatch = q.match(/(\d+)\s*(?:qty|quantity|units|pcs)/i);
        const qtyVal = qtyMatch ? parseInt(qtyMatch[1]) : 100;

        items = dbItems.slice(0, numItems).map(i => ({
            itemId: i.id,
            itemCode: i.item_code,
            itemName: i.item_name,
            brand: i.brand || 'General',
            unit: i.unit || 'PCS',
            qty: qtyVal,
            rate: i.rate || i.mrp || 0,
            tax: i.tax_percent || 0
        }));
    }

    if (!supplierName && dbSuppliers.length > 0) {
        supplierId = dbSuppliers[0].id;
        supplierName = dbSuppliers[0].supplier_name;
    }

    if (!supplierName && items.length === 0) {
        return {
            reply: `📦 **Purchase Order Draft Intent Detected**\n\nPlease provide supplier name, items, quantities, and rates.\n\n*Example:* "Create PO draft for Sunrise Traders 500 units A4 Paper at 250 rate"`,
            action: { type: "NONE" },
            quickReplies: ["Draft PO Sunrise Traders", "View Suppliers"]
        };
    }

    let totalVal = 0;
    const itemLines = items.map(it => {
        const lineTotal = (it.qty || 1) * (it.rate || 0);
        totalVal += lineTotal;
        return `* 📦 **${it.itemName || 'Product'}** (${it.itemCode || 'ITEM'}): ${it.qty || 1} units @ ₹${it.rate || 0} = **₹${lineTotal.toLocaleString('en-IN')}**`;
    });

    return {
        reply: `📝 **Purchase Order Draft Ready!**\n\n` +
               `* 🏭 **Supplier**: ${supplierName || 'Pending Selection'}\n` +
               (itemLines.length > 0 ? itemLines.join('\n') + '\n' : '') +
               `* 💰 **Total Draft Value**: ₹${totalVal.toLocaleString('en-IN')}\n\n` +
               `*Click the button below to review and submit this purchase order in your outlet dashboard.*`,
        action: { type: "OPEN_PURCHASE_ORDER_DRAFT", label: "Review & Submit Purchase Order", supplierId, supplierName, items, payload: { supplierId, supplierName, items, totalVal } },
        quickReplies: ["Review & Submit Purchase Order", "Cancel Draft"]
    };
}

async function handleSupplierCreation(prompt, history = [], propertyDb = null, outletId = 0, config = {}) {
    if (!propertyDb) return null;

    const promptTrim = (prompt || '').trim();
    const promptLower = promptTrim.toLowerCase();

    // 0. Filter out non-supplier-creation feature prompts
    const nonSupplierCreationKeywords = [
        'purchase order', 'create po', 'draft po', 'po', 'directory', 'list supplier', 'show supplier',
        'view supplier', 'sales', 'stock', 'inventory', 'report', 'bill', 'invoice', 'product', 'item', 'analytics'
    ];
    if (nonSupplierCreationKeywords.some(k => promptLower.includes(k)) &&
        !promptLower.includes('add supplier') && !promptLower.includes('create supplier') && !promptLower.includes('register supplier') && !promptLower.includes('new supplier')) {
        return null;
    }

    // 1. Check if user prompt is an explicit APPROVAL or CANCEL command
    const isApprovalCommand = promptLower.includes('approve') || promptLower.includes('confirm') || promptLower.includes('yes') || promptLower.includes('proceed') || promptLower.includes('save');
    const isCancelledCommand = promptLower.includes('cancel') || promptLower.includes('stop') || promptLower.includes('reject');

    // 2. Look for existing pending approval preview in conversation history
    let pendingData = null;
    let isPendingIncompleteState = false;
    const historyText = Array.isArray(history) ? history.slice(-4).map(h => h.content || h.text || '').join(' ') : '';

    if (Array.isArray(history)) {
        for (let i = history.length - 1; i >= 0; i--) {
            const text = history[i].content || history[i].text || '';
            if (text.includes('Vendor Details Incomplete')) {
                isPendingIncompleteState = true;
            }
            if (text.includes('Vendor Registration Pending Approval') || text.includes('Generated Code:')) {
                const nameM = text.match(/\* ✏️ \*\*Vendor Name\*\*: (.*)/) || text.match(/\* \*\*Name\*\*: (.*)/);
                const phoneM = text.match(/\* 📞 \*\*Phone\*\*: (.*)/) || text.match(/\* \*\*Phone\*\*: (.*)/);
                const emailM = text.match(/\* 📧 \*\*Email\*\*: (.*)/) || text.match(/\* \*\*Email\*\*: (.*)/);
                const addrM = text.match(/\* 📍 \*\*Address\*\*: (.*)/) || text.match(/\* \*\*Address\*\*: (.*)/);
                const stateM = text.match(/\* 🏛️ \*\*State\*\*: (.*)/) || text.match(/\* \*\*State\*\*: (.*)/);
                const gstinM = text.match(/\* 🧾 \*\*GSTIN\*\*: (.*)/) || text.match(/\* \*\*GSTIN\*\*: (.*)/);

                if (nameM && addrM && stateM) {
                    pendingData = {
                        supplierName: nameM[1].trim(),
                        phone: phoneM && phoneM[1].trim() !== 'N/A' ? phoneM[1].trim() : '',
                        email: emailM && emailM[1].trim() !== 'N/A' ? emailM[1].trim() : '',
                        address: addrM[1].trim(),
                        state: stateM[1].trim(),
                        gstin: gstinM && gstinM[1].trim() !== 'N/A' ? gstinM[1].trim() : ''
                    };
                    break;
                }
            }
        }
    }

    // 3. Handle Cancel Command
    if (isCancelledCommand && (pendingData || isPendingIncompleteState || promptLower.includes('supplier') || promptLower.includes('vendor'))) {
        return {
            reply: `❌ **Vendor Registration Cancelled**\n\nSupplier creation was cancelled. No records were added or modified in your database.`,
            action: { type: "SUPPLIER_MASTER", label: "View Supplier Directory" },
            quickReplies: ["View Supplier Directory", "Add New Supplier"]
        };
    }

    // 4. Handle Approval Command when pending data exists in history
    if (isApprovalCommand && pendingData) {
        let count = 0;
        try {
            const [res] = await propertyDb.query(`SELECT COUNT(id) AS cnt FROM supplier_master WHERE outlet_id = :outletId`, {
                replacements: { outletId },
                type: propertyDb.QueryTypes.SELECT
            });
            count = res ? parseInt(res.cnt || 0) : 0;
        } catch (e) {
            count = 0;
        }

        const nextCode = `SUP${count + 1}`;

        return new Promise((resolve) => {
            const reqMock = {
                user: { outlet_id: outletId, id: 1 },
                propertyDb,
                body: {
                    supplier_code: nextCode,
                    supplier_name: pendingData.supplierName,
                    phone: pendingData.phone || '',
                    address: pendingData.address,
                    state: pendingData.state,
                    email: pendingData.email,
                    gstin: pendingData.gstin,
                    tax_country_code: 'IN'
                }
            };

            const resMock = {
                status: function(code) {
                    this.statusCode = code;
                    return this;
                },
                json: function(payload) {
                    if (payload && payload.success && payload.data) {
                        const supplier = payload.data;
                        console.log(`[AI SERVICE] Supplier registered via API Controller: ${supplier.supplier_name} (${supplier.supplier_code})`);
                        resolve({
                            reply: `✅ **New Supplier Registered Successfully**\n\nVendor **${supplier.supplier_name}** (${supplier.supplier_code}) has been validated, approved, and created in your live outlet database via the official REST API.\n\n* **Supplier Code**: ${supplier.supplier_code}\n* **Name**: ${supplier.supplier_name}\n* **Phone**: ${supplier.phone || 'N/A'}\n* **Email**: ${supplier.email || 'N/A'}\n* **Address**: ${supplier.address}\n* **State**: ${supplier.state || 'N/A'}\n* **GSTIN**: ${supplier.gstin || 'N/A'}\n* **Status**: Active\n\nYour supplier directory is now synchronized and ready for Purchase Orders and Supplier Payments.`,
                            action: { type: "SUPPLIER_MASTER", label: "View Supplier Directory" },
                            quickReplies: ["Create Purchase Order", "View Supplier Directory", "Add Another Supplier"]
                        });
                    } else {
                        resolve({
                            reply: `⚠️ **Supplier Creation API Validation Warning**: ${payload?.message || payload?.error || 'Vendor validation failed.'}`,
                            action: { type: "SUPPLIER_MASTER", label: "Open Supplier Directory" },
                            quickReplies: ["View Supplier Directory"]
                        });
                    }
                }
            };

            supplierMasterController.createSupplier(reqMock, resMock).catch(err => {
                resolve({
                    reply: `⚠️ **Supplier Creation API Error**: ${err.message}`,
                    action: { type: "SUPPLIER_MASTER", label: "Open Supplier Directory" },
                    quickReplies: ["View Supplier Directory"]
                });
            });
        });
    }

    let supplierName = null;
    let phone = null;
    let email = null;
    let address = null;
    let state = null;
    let gstin = null;

    const apiKeyExists = GEMINI_API_KEY || OPENAI_API_KEY || config.aiApiKey;
    if (apiKeyExists) {
        try {
            const nlpPrompt = `Extract vendor / supplier registration details from user query and context:
Context: "${historyText}"
Query: "${prompt}"

Output ONLY a raw JSON object with schema:
{
  "supplierName": "Vendor Company / Person Name or null",
  "phone": "10-12 digit phone number or null",
  "email": "email address or null",
  "address": "Street address / City / Location or null",
  "state": "Indian State e.g. Uttarakhand, Delhi, Punjab or null",
  "gstin": "GSTIN number or null"
}`;
            const systemInst = `You are a precise NLP supplier registration parser. Output ONLY a valid JSON object without extra text or backticks.`;

            const rawNlp = await executeLLMCall(nlpPrompt, systemInst, config);
            let cleanJson = rawNlp.replace(/```json/gi, '').replace(/```/g, '').trim();
            const parsed = JSON.parse(cleanJson);

            if (parsed) {
                supplierName = parsed.supplierName || null;
                phone = parsed.phone || null;
                email = parsed.email || null;
                address = parsed.address || null;
                state = parsed.state || null;
                gstin = parsed.gstin || null;
            }
        } catch (llmErr) {
            console.warn('[AI SERVICE] LLM Supplier Creation NLP warning:', llmErr.message);
        }
    }

    if (!supplierName || !address || !state) {
        const indianStates = [
            'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
            'Chandigarh', 'Chhattisgarh', 'Dadra and Nagar Haveli', 'Daman and Diu', 'Delhi', 'Goa',
            'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir', 'Jharkhand', 'Karnataka',
            'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
            'Mizoram', 'Nagaland', 'Odisha', 'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
            'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'
        ];

        const historyText = Array.isArray(history) ? history.slice(-4).map(h => h.content || h.text || '').join(' ') : '';
        const combinedText = `${historyText} ${prompt}`.trim();
        const combinedLower = combinedText.toLowerCase();

        if (!email) {
            const emailMatch = combinedText.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/);
            email = emailMatch ? emailMatch[0] : null;
        }

        if (!phone) {
            const phoneMatch = combinedText.match(/\b\d{10,12}\b/);
            phone = phoneMatch ? phoneMatch[0] : null;
        }

        if (!gstin) {
            const gstinDirectMatch = combinedText.match(/gstin[:\s]*([0-9a-z]+)/i);
            if (gstinDirectMatch && gstinDirectMatch[1]) {
                const rawGstin = gstinDirectMatch[1].toUpperCase();
                gstin = rawGstin.startsWith('GSTIN') ? rawGstin : `GSTIN${rawGstin}`;
            } else {
                const stdGstinMatch = combinedText.match(/\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b/i);
                if (stdGstinMatch) gstin = stdGstinMatch[0].toUpperCase();
            }
        }

        if (!state) {
            for (const st of indianStates) {
                if (combinedLower.includes(st.toLowerCase())) {
                    state = st;
                    break;
                }
            }
        }

        const parts = prompt.split(',').map(s => s.trim()).filter(Boolean);
        const textParts = parts.filter(p => {
            const pLow = p.toLowerCase();
            if (email && p.includes(email)) return false;
            if (phone && p.includes(phone)) return false;
            if (gstin && pLow.includes(gstin.toLowerCase())) return false;
            if (pLow.startsWith('gstin')) return false;
            if (state && pLow.includes(state.toLowerCase())) return false;
            if (pLow.includes('add supplier') || pLow.includes('create vendor') || pLow.includes('register supplier')) return false;
            return true;
        });

        if (!supplierName && textParts.length > 0) supplierName = textParts[0];
        if (!address && textParts.length > 1) address = textParts[1];
    }

    // CHECK MISSING MANDATORY FIELDS (Name, Address, State)
    const missingFields = [];
    if (!supplierName || supplierName.toLowerCase() === 'new supplier') missingFields.push('Vendor Name');
    if (!address) missingFields.push('Address / City');
    if (!state) missingFields.push('State (e.g. Uttarakhand, Delhi, Punjab)');

    // IF MANDATORY DETAILS ARE MISSING -> DO NOT CALL API / DO NOT CREATE DATABASE RECORD! ASK USER FOR MISSING DETAILS!
    if (missingFields.length > 0) {
        return {
            reply: `📝 **Vendor Details Incomplete**\n\nBefore I can create this supplier in your database, please provide the missing required information:\n\n` +
                   missingFields.map(f => `* ⚠️ **${f}**: *(Required)*`).join('\n') +
                   `\n\n*Details Captured So Far:*` +
                   (supplierName ? `\n* **Name**: ${supplierName}` : '') +
                   (phone ? `\n* **Phone**: ${phone}` : '') +
                   (email ? `\n* **Email**: ${email}` : '') +
                   (gstin ? `\n* **GSTIN**: ${gstin}` : '') +
                   `\n\n*Please reply with the missing details (e.g., "${missingFields.join(', ')}") to complete vendor registration.*`,
            action: { type: "NONE" },
            quickReplies: ["Provide State & Address", "View Supplier Directory"]
        };
    }

    let count = 0;
    try {
        const [res] = await propertyDb.query(`SELECT COUNT(id) AS cnt FROM supplier_master WHERE outlet_id = :outletId`, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });
        count = res ? parseInt(res.cnt || 0) : 0;
    } catch (err) {
        console.error('[AI SERVICE] Supplier creation execution error:', err.message);
        return null;
    }

    const nextCode = `SUP${count + 1}`;

    // IF NOT CONFIRMED YET -> SHOW APPROVAL PREVIEW CARD & ASK FOR EXPLICIT USER APPROVAL!
    return {
        reply: `📋 **Vendor Registration Pending Approval**\n\nPlease review the vendor details below before confirming creation into your live outlet database:\n\n` +
               `* ✏️ **Vendor Name**: ${supplierName}\n` +
               `* 📞 **Phone**: ${phone || 'N/A'}\n` +
               `* 📧 **Email**: ${email || 'N/A'}\n` +
               `* 📍 **Address**: ${address}\n` +
               `* 🏛️ **State**: ${state}\n` +
               `* 🧾 **GSTIN**: ${gstin || 'N/A'}\n` +
               `* 🏷️ **Generated Code**: ${nextCode}\n` +
               `* 🟢 **Status**: Active\n\n` +
               `*Click the approval button below or reply "Approve" to save this supplier into your database.*`,
        action: { type: "CONFIRM_CREATE_SUPPLIER", label: "Approve & Register Supplier" },
        quickReplies: ["Approve & Register Supplier", "Cancel Registration"]
    };
}

async function handleTaskScheduling(prompt, history = [], propertyDb = null, outletId = 0, config = {}) {
    if (!prompt || typeof prompt !== 'string') return null;

    const q = prompt.toLowerCase();
    const isSchedulePrompt = q.includes('remind me') || 
                             q.includes('schedule task') || 
                             q.includes('shedule task') || 
                             q.includes('schedule reminder') || 
                             q.includes('shedule reminder') || 
                             q.includes('task scheduler') || 
                             q.includes('set reminder') || 
                             q.includes('create reminder') ||
                             q.includes('task for') ||
                             q.includes('alarm for') ||
                             (q.includes('note') && (q.includes('add') || q.includes('create') || q.includes('save') || q.includes('write')));

    if (!isSchedulePrompt) return null;

    let llmSuccess = false;
    let title = '';
    let reminderType = 'SPECIFIC_DATE';
    let targetDateObj = new Date();
    let reminderTime = '09:00 AM';

    const apiKeyExists = GEMINI_API_KEY || OPENAI_API_KEY || config.aiApiKey;
    if (apiKeyExists) {
        try {
            const todayStr = new Date().toISOString().split('T')[0];
            const nlpPrompt = `Extract task scheduling details from user query: "${prompt}".
Today's date is ${todayStr}.
Output ONLY a raw JSON object with schema:
{
  "title": "Clean task title without date or time words",
  "frequency": "DAILY | WEEKLY | MONTHLY | SPECIFIC_DATE",
  "startDate": "YYYY-MM-DD",
  "time": "HH:MM AM/PM"
}`;
            const systemInst = `You are a precise NLP task scheduler parser. Output ONLY a valid JSON object without extra text or backticks.`;

            const rawNlp = await executeLLMCall(nlpPrompt, systemInst, config);
            let cleanJson = rawNlp.replace(/```json/gi, '').replace(/```/g, '').trim();
            const parsed = JSON.parse(cleanJson);

            if (parsed && parsed.title && parsed.startDate && parsed.time) {
                title = parsed.title.charAt(0).toUpperCase() + parsed.title.slice(1);
                reminderType = (parsed.frequency || 'SPECIFIC_DATE').toUpperCase();
                reminderTime = parsed.time;

                const [sYear, sMonth, sDay] = parsed.startDate.split('-').map(Number);
                let pHour = 9, pMin = 0;
                const tMatch = parsed.time.match(/(\d{1,2}):?(\d{2})?\s*(am|pm)/i);
                if (tMatch) {
                    pHour = parseInt(tMatch[1]);
                    pMin = tMatch[2] ? parseInt(tMatch[2]) : 0;
                    const sub = tMatch[3].toLowerCase();
                    if (sub === 'pm' && pHour < 12) pHour += 12;
                    if (sub === 'am' && pHour === 12) pHour = 0;
                }
                targetDateObj = new Date(sYear, sMonth - 1, sDay, pHour, pMin, 0);
                llmSuccess = true;
            }
        } catch (llmErr) {
            console.warn('[AI SERVICE] LLM Task NLP warning, using local NLP rules:', llmErr.message);
        }
    }

    if (!llmSuccess) {
        // 1. Determine Frequency
        reminderType = 'SPECIFIC_DATE';
        if (q.includes('daily') || q.includes('everyday') || q.includes('every day')) {
            reminderType = 'DAILY';
        } else if (q.includes('weekly') || q.includes('every week') || q.includes('every monday') || q.includes('every friday')) {
            reminderType = 'WEEKLY';
        } else if (q.includes('monthly') || q.includes('every month')) {
            reminderType = 'MONTHLY';
        }

        // 2. Parse Start Date
        const now = new Date();
        let targetYear = now.getFullYear();
        let targetMonth = now.getMonth();
        let targetDay = now.getDate() + 1;

        const monthMap = {
            jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2, apr: 3, april: 3,
            may: 4, jun: 5, june: 5, jul: 6, july: 6, aug: 7, august: 7, sep: 8, september: 8,
            oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11
        };

        const dateMatch = q.match(/(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|january|february|march|april|june|july|august|september|october|november|december)\s*(\d{4})?/i);
        if (dateMatch) {
            const dVal = parseInt(dateMatch[1]);
            const mStr = dateMatch[2].toLowerCase();
            const yVal = dateMatch[3] ? parseInt(dateMatch[3]) : targetYear;

            if (monthMap[mStr] !== undefined && dVal >= 1 && dVal <= 31) {
                targetDay = dVal;
                targetMonth = monthMap[mStr];
                targetYear = yVal;
            }
        } else if (q.includes('today')) {
            targetDay = now.getDate();
            targetMonth = now.getMonth();
            targetYear = now.getFullYear();
        }

        // 3. Parse Time
        let hour = 9;
        let minute = 0;
        let ampmStr = 'AM';

        if (q.includes('morning')) { hour = 9; minute = 0; ampmStr = 'AM'; }
        if (q.includes('afternoon')) { hour = 14; minute = 0; ampmStr = 'PM'; }
        if (q.includes('evening')) { hour = 18; minute = 0; ampmStr = 'PM'; }
        if (q.includes('night')) { hour = 21; minute = 0; ampmStr = 'PM'; }

        const allTimeMatches = [...q.matchAll(/(\d{1,2}):?(\d{2})?\s*(am|pm)/gi)];
        if (allTimeMatches.length > 0) {
            const lastMatch = allTimeMatches[allTimeMatches.length - 1];
            let pVal = parseInt(lastMatch[1]);
            let mVal = lastMatch[2] ? parseInt(lastMatch[2]) : 0;
            const subStr = lastMatch[3].toLowerCase();
            if (subStr === 'pm' && pVal < 12) pVal += 12;
            if (subStr === 'am' && pVal === 12) pVal = 0;
            hour = pVal;
            minute = mVal;
            ampmStr = hour >= 12 ? 'PM' : 'AM';
        }

        const displayH = (hour % 12 === 0 ? 12 : hour % 12).toString().padStart(2, '0');
        const displayM = minute.toString().padStart(2, '0');
        reminderTime = `${displayH}:${displayM} ${ampmStr}`;

        targetDateObj = new Date(targetYear, targetMonth, targetDay, hour, minute, 0);

        // 4. Extract Clean Title
        title = prompt
            .replace(/shedule task for/i, '')
            .replace(/schedule task for/i, '')
            .replace(/shedule task/i, '')
            .replace(/schedule task/i, '')
            .replace(/schedule reminder/i, '')
            .replace(/shedule reminder/i, '')
            .replace(/remind me to/i, '')
            .replace(/remind me/i, '')
            .replace(/set reminder for/i, '')
            .replace(/set reminder/i, '')
            .replace(/create reminder/i, '')
            .replace(/task scheduler/i, '')
            .replace(/start from \d{1,2}\s+[a-z]+\s*\d*/i, '')
            .replace(/start from [^0-9]*/i, '')
            .replace(/starting from [^0-9]*/i, '')
            .replace(/at morning/i, '')
            .replace(/at evening/i, '')
            .replace(/\d{1,2}:?\d{0,2}\s*(am|pm)/gi, '')
            .replace(/every day/i, '')
            .replace(/every week/i, '')
            .replace(/every month/i, '')
            .replace(/daily/i, '')
            .replace(/weekly/i, '')
            .replace(/monthly/i, '')
            .replace(/tomorrow/i, '')
            .replace(/today/i, '')
            .replace(/\s+/g, ' ')
            .trim();

        if (!title || title.length === 0) {
            title = 'Business Reminder';
        }
        title = title.charAt(0).toUpperCase() + title.slice(1);
    }

    const reminderDate = targetDateObj.toISOString();

    try {
        if (propertyDb) {
            if (propertyDb.models?.user_notes) {
                await propertyDb.models.user_notes.create({
                    outlet_id: outletId,
                    user_id: 1,
                    title,
                    content: `Scheduled via LYNX ASSIST AI Assistant on ${new Date().toLocaleDateString('en-IN')}`,
                    color_hex: '#FEF08A',
                    is_pinned: true,
                    is_completed: false,
                    reminder_type: reminderType,
                    reminder_date: reminderDate,
                    reminder_time: reminderTime
                });
            } else {
                await propertyDb.query(`
                    INSERT INTO user_notes (outlet_id, user_id, title, content, color_hex, is_pinned, is_completed, reminder_type, reminder_date, reminder_time, "createdAt", "updatedAt")
                    VALUES (:outletId, 1, :title, :content, '#FEF08A', true, false, :reminderType, :reminderDate, :reminderTime, NOW(), NOW())
                `, {
                    replacements: {
                        outletId,
                        title,
                        content: `Scheduled via LYNX ASSIST AI Assistant on ${new Date().toLocaleDateString('en-IN')}`,
                        reminderType,
                        reminderDate,
                        reminderTime
                    },
                    type: propertyDb.QueryTypes.INSERT
                });
            }
        }
    } catch (dbErr) {
        console.warn('[AI SERVICE] Task scheduling DB warning:', dbErr.message);
    }

    let freqLabel = 'Specific Date & Time';
    if (reminderType === 'DAILY') freqLabel = 'Daily (Everyday)';
    if (reminderType === 'WEEKLY') freqLabel = 'Weekly (Every Week)';
    if (reminderType === 'MONTHLY') freqLabel = 'Monthly (Every Month)';

    const dateFormatted = targetDateObj.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });

    return {
        reply: `📅 **Task & Reminder Scheduled Successfully!**\n\n` +
               `* ✏️ **Task Title**: ${title}\n` +
               `* 🔁 **Schedule Frequency**: ${freqLabel}\n` +
               `* 🗓️ **Start Date**: ${dateFormatted}\n` +
               `* ⏰ **Time**: ${reminderTime}\n` +
               `* 🟢 **Status**: Active Alarm\n\n` +
               `📌 *This reminder has been saved persistently to your database and pinned to your Sticky Notes board.*`,
        action: { type: "OPEN_NOTES", label: "Open Sticky Notes Board" },
        quickReplies: ["Open Sticky Notes", "Schedule Daily Reminder", "Today's Sales"]
    };
}

async function handleImageInvoiceExtraction(prompt, history = [], config = {}, propertyDb = null, outletId = 0) {
    const imageBase64 = config.imageBase64 || config.image_base64;
    if (!imageBase64) return null;

    try {
        const provider = (config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null)));
        const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);
        
        if (!apiKey) {
            return {
                reply: "⚠️ **Image Received**: AI API Key is required to perform multimodal bill/invoice OCR extraction. Please configure your AI Key in Settings.",
                action: { type: "NONE" },
                quickReplies: ["Open System Settings", "Create Purchase Order"]
            };
        }

        const visionSystemPrompt = `You are an expert OCR document & invoice parser. Analyze the uploaded bill/invoice image.
Extract all details and return a strict JSON object with this structure:
{
  "supplierName": "<Supplier/Vendor Name>",
  "supplierCode": "<Supplier Code if present>",
  "invoiceNo": "<Invoice/PO Number>",
  "poDate": "<Date if present>",
  "items": [
    {
      "item_code": "<Product Code/HSN if present>",
      "item_name": "<Product Name>",
      "hsn_code": "<HSN code if present>",
      "qty": <Numeric Quantity>,
      "unit": "<Unit e.g. nos, pcs, kg>",
      "rate": <Unit Rate/Cost>,
      "tax_percent": <Tax % e.g. 5, 18>,
      "amount": <Line Total Amount>
    }
  ]
}
STRICT RULE: Return valid JSON ONLY without markdown formatting.`;

        let parsedData = null;
        try {
            let rawResp = "";
            if (provider === 'openai' || provider === 'deepseek' || provider === 'custom') {
                rawResp = await callOpenAICompatible(prompt || "Extract invoice items", visionSystemPrompt, config);
            } else {
                rawResp = await callGemini(prompt || "Extract invoice items", visionSystemPrompt, config);
            }

            const cleanJson = rawResp.replace(/```json/gi, '').replace(/```/gi, '').trim();
            parsedData = JSON.parse(cleanJson);
        } catch (ocrErr) {
            console.error('[OCR PARSE ERROR]:', ocrErr.message);
        }

        if (!parsedData || !parsedData.items || !Array.isArray(parsedData.items) || parsedData.items.length === 0) {
            return {
                reply: "🧾 **Invoice Image Analyzed**: Could not read itemized lines cleanly. Click below to draft a Purchase Order manually.",
                action: { type: "CREATE_PO", label: "Draft Purchase Order" },
                quickReplies: ["Draft Purchase Order", "View Suppliers"]
            };
        }

        const supplier = parsedData.supplierName || "Extracted Vendor";
        const items = parsedData.items;

        let itemsSummary = items.map((it, idx) => 
            `  ${idx + 1}. **${it.item_name}** — Qty: **${it.qty} ${it.unit || 'nos'}** @ ₹${it.rate} (Amt: ₹${it.amount})`
        ).join('\n');

        return {
            reply: `🧾 **Invoice OCR Auto-Extraction Successful!**\n\n` +
                   `* 🏬 **Supplier**: **${supplier}** ${parsedData.supplierCode ? `(${parsedData.supplierCode})` : ''}\n` +
                   `* 📅 **Date**: ${parsedData.poDate || 'Latest Invoice'}\n` +
                   `* 📦 **Extracted Items (${items.length} lines)**:\n${itemsSummary}\n\n` +
                   `Click below to open the Purchase Order screen with all ${items.length} items prefilled for instant drafting.`,
            action: {
                type: "CREATE_PO",
                label: `Open Draft PO (${items.length} Items)`,
                supplierName: supplier,
                supplierCode: parsedData.supplierCode || '',
                items: items
            },
            payload: {
                supplierName: supplier,
                supplierCode: parsedData.supplierCode || '',
                items: items
            },
            quickReplies: ["Draft Purchase Order", "Goods Receiving (GRN)", "View Suppliers"]
        };
    } catch (err) {
        console.error('[AI INVOICE OCR ERROR]:', err);
        return null;
    }
}

async function processLynxAssist(prompt, history = [], config = {}, propertyDb = null, outletId = 0) {
    // 0. Intercept Multimodal Image OCR Invoice Uploads
    const imageOcrResult = await handleImageInvoiceExtraction(prompt, history, config, propertyDb, outletId);
    if (imageOcrResult) {
        return imageOcrResult;
    }

    // 0. Intercept Active Outlet & Registered Property Verification Prompt
    const outletInfoResult = await handleOutletVerification(prompt, history, propertyDb, outletId, config);
    if (outletInfoResult) {
        return outletInfoResult;
    }

    // 1. Task Scheduling & Sticky Notes Reminders (ALLOWED)
    const scheduledTaskResult = await handleTaskScheduling(prompt, history, propertyDb, outletId, config);
    if (scheduledTaskResult) {
        return scheduledTaskResult;
    }

    // 2. Intercept Restaurant KOT Dine-In Order Draft (Direct Jump to Table KOT Basket)
    const kotDraftResult = await handleKotOrderDraft(prompt, history, propertyDb, outletId, config);
    if (kotDraftResult) {
        return kotDraftResult;
    }

    // 3. Intercept Sales Order / Billing Draft (Pre-fills POS Sales Cart)
    const saleDraftResult = await handleSalesOrderDraft(prompt, history, propertyDb, outletId, config);
    if (saleDraftResult) {
        return saleDraftResult;
    }

    // 3. Intercept Purchase Order Draft (Pre-fills PO screen on navigation without DB mutation)
    const poDraftResult = await handlePurchaseOrderDraft(prompt, history, propertyDb, outletId, config);
    if (poDraftResult) {
        return poDraftResult;
    }

    // 3. Data Analysis & Live Store Context (SELECT ONLY)
    const liveContext = await fetchLiveStoreContext(propertyDb, outletId);
    const maxRows = Math.min(Math.max(parseInt(config.maxRows) || 100, 1), 1000);

    const provider = (config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null)));
    const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);

    let sqlQueryResult = null;
    let sqlQueryString = null;

    // Execute dynamic Text-to-SQL if propertyDb is available and LLM key is configured
    if (propertyDb && apiKey) {
        try {
            sqlQueryString = await translateTextToQuery(prompt, { ...config, maxRows });
            if (sqlQueryString) {
                // Enforce Strict Read-Only SELECT Safety for Data Analysis
                if (!sqlQueryString.trim().toLowerCase().startsWith('select')) {
                    console.warn('[AI SERVICE] Blocked non-SELECT SQL query for safety:', sqlQueryString);
                    sqlQueryString = null;
                } else {
                    // Enforce Multi-Tenant SQL Isolation: replace any hardcoded outlet_id = <num> with outlet_id = :outletId
                    sqlQueryString = sqlQueryString.replace(/outlet_id\s*=\s*\d+/gi, 'outlet_id = :outletId');

                    // If query is missing :outletId placeholder, inject WHERE outlet_id = :outletId
                    if (!sqlQueryString.includes(':outletId')) {
                        if (sqlQueryString.toLowerCase().includes('where')) {
                            sqlQueryString = sqlQueryString.replace(/where\s+/i, 'WHERE outlet_id = :outletId AND ');
                        } else if (sqlQueryString.toLowerCase().includes('group by')) {
                            sqlQueryString = sqlQueryString.replace(/group by\s+/i, 'WHERE outlet_id = :outletId GROUP BY ');
                        } else if (sqlQueryString.toLowerCase().includes('order by')) {
                            sqlQueryString = sqlQueryString.replace(/order by\s+/i, 'WHERE outlet_id = :outletId ORDER BY ');
                        } else if (sqlQueryString.toLowerCase().includes('limit')) {
                            sqlQueryString = sqlQueryString.replace(/limit\s+/i, 'WHERE outlet_id = :outletId LIMIT ');
                        } else {
                            sqlQueryString += ' WHERE outlet_id = :outletId';
                        }
                    }

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
                        sqlQueryResult = rows ? rows.slice(0, maxRows) : [];
                    } catch (dbErr) {
                        await t.rollback();
                        console.warn('[LYNX ASSIST SQL EXECUTION WARNING]:', dbErr.message);
                    }
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
QUERY EXECUTED DATASET (Top ${maxRows} Rows): ${sqlQueryResult ? JSON.stringify(sqlQueryResult, null, 2) : 'None'}

Conversation History:
${JSON.stringify(history.slice(-6))}

User Question / Command: ${prompt}`;

        const rawRes = await executeLLMCall(fullPrompt, LYNX_ASSIST_SYSTEM, config);
        let clean = rawRes.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(clean);
        
        let action = parsed.action || { type: "NONE" };
        if (!action || action.type === 'NONE') {
            const matched = matchActionFromQuery(prompt);
            if (matched) {
                action = matched;
            }
        }

        if (action && (action.type === 'CREATE_PO' || action.type === 'PURCHASE_ORDER' || action.type === 'OPEN_PURCHASE_ORDER_DRAFT')) {
            if (!action.items && !action.rows) {
                if (parsed.items && Array.isArray(parsed.items)) {
                    action.items = parsed.items;
                } else if (parsed.payload && parsed.payload.items && Array.isArray(parsed.payload.items)) {
                    action.items = parsed.payload.items;
                } else if (sqlQueryResult && Array.isArray(sqlQueryResult)) {
                    action.items = sqlQueryResult;
                }
            }
            if (!action.supplierName) {
                if (parsed.supplierName) {
                    action.supplierName = parsed.supplierName;
                } else if (parsed.payload && parsed.payload.supplierName) {
                    action.supplierName = parsed.payload.supplierName;
                }
            }
        }

        return {
            reply: parsed.reply || "I am processing your request.",
            action: action,
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
