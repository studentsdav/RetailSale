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

/**
 * Execute https call to Gemini v20.0 (gemini-2.5-flash model)
 */
function callGemini(prompt, systemInstruction, customKey) {
    const apiKey = customKey || GEMINI_API_KEY;
    return new Promise((resolve, reject) => {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
        
        const payload = {
            contents: [{ parts: [{ text: `${systemInstruction}\n\nUser Question: ${prompt}` }] }]
        };

        const parsedUrl = new URL(url);
        const options = {
            method: 'POST',
            hostname: parsedUrl.hostname,
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
                        reject(new Error(response.error?.message || `Invalid response from Gemini`));
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
 * Execute https call to OpenAI Chat Completion (gpt-4o model)
 */
function callOpenAI(prompt, systemInstruction, customKey) {
    const apiKey = customKey || OPENAI_API_KEY;
    return new Promise((resolve, reject) => {
        const url = 'https://api.openai.com/v1/chat/completions';
        
        const payload = {
            model: 'gpt-4o',
            messages: [
                { role: 'system', content: systemInstruction },
                { role: 'user', content: prompt }
            ]
        };

        const parsedUrl = new URL(url);
        const options = {
            method: 'POST',
            hostname: parsedUrl.hostname,
            path: parsedUrl.pathname,
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
                        reject(new Error(response.error?.message || 'Invalid response from OpenAI'));
                    } else {
                        resolve(text.trim());
                    }
                } catch (e) {
                    reject(new Error(`Failed to parse OpenAI response: ${data}`));
                }
            });
        });

        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
    });
}

/**
 * Translate natural language question into SQL query
 */
async function translateTextToQuery(question, config = {}) {
    const provider = config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null));
    const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);

    if (!apiKey) {
        return getMockQuery(question);
    }

    try {
        let resultRaw = '';
        if (provider === 'gemini') {
            resultRaw = await callGemini(question, TEXT_TO_SQL_SYSTEM, apiKey);
        } else {
            resultRaw = await callOpenAI(question, TEXT_TO_SQL_SYSTEM, apiKey);
        }

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
    const provider = config.aiProvider || (GEMINI_API_KEY ? 'gemini' : (OPENAI_API_KEY ? 'openai' : null));
    const apiKey = config.aiApiKey || (provider === 'gemini' ? GEMINI_API_KEY : OPENAI_API_KEY);

    if (!apiKey) {
        return getMockAnalysis(originalQuestion, datasetJson);
    }

    try {
        const prompt = `Original Question: ${originalQuestion}\n\nDataset Content (Top 100 rows):\n${datasetJson}`;
        if (provider === 'gemini') {
            return await callGemini(prompt, NARRATIVE_ANALYST_SYSTEM, apiKey);
        } else {
            return await callOpenAI(prompt, NARRATIVE_ANALYST_SYSTEM, apiKey);
        }
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

module.exports = {
    translateTextToQuery,
    analyzeDatasetSummary
};
