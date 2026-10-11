import express from 'express';
import jwt from 'jsonwebtoken';
const router = express.Router();
const defaultDb = require('../db/models');

function getDb(req: any) {
    return req.propertyDb || defaultDb;
}

/**
 * Authentication Middleware: Supports BOTH X-API-Key and OAuth 2.0 Bearer Token
 */
function verifyOpenApiAuth(requiredScope?: string) {
    return async (req: any, res: any, next: any) => {
        try {
            const db = getDb(req);
            let outletId = 0;
            let authorizedScopes: string[] = [];
            let keyName = '';

            // Check Method 1: X-API-Key Header or Query Param
            const apiKeyHeader = req.headers['x-api-key'] || req.query.api_key;

            // Check Method 2: OAuth 2.0 Authorization: Bearer <token>
            const authHeader = req.headers['authorization'];
            const bearerToken = authHeader && authHeader.startsWith('Bearer ') ? authHeader.substring(7).trim() : null;

            if (apiKeyHeader) {
                const keyStr = String(apiKeyHeader).trim();
                let keyRecord: any = null;

                if (db) {
                    try {
                        const rows = await db.query(
                            `SELECT id, outlet_id, key_name, scopes, is_active FROM developer_api_keys WHERE api_key = $1`,
                            { bind: [keyStr] }
                        );
                        if (rows[0] && rows[0].length > 0) {
                            keyRecord = rows[0][0];
                        }
                    } catch (_) {}
                }

                if (!keyRecord) {
                    return res.status(401).json({
                        success: false,
                        error: 'INVALID_API_KEY',
                        message: 'The provided API Key is invalid or does not exist.'
                    });
                }

                if (!keyRecord.is_active) {
                    return res.status(403).json({
                        success: false,
                        error: 'KEY_REVOKED',
                        message: 'This API Key has been revoked or deactivated.'
                    });
                }

                outletId = Number(keyRecord.outlet_id) || 0;
                authorizedScopes = Array.isArray(keyRecord.scopes)
                    ? keyRecord.scopes
                    : (typeof keyRecord.scopes === 'string' ? JSON.parse(keyRecord.scopes) : []);
                keyName = keyRecord.key_name;

                // Update last_used_at in background
                if (db) {
                    db.query(
                        `UPDATE developer_api_keys SET last_used_at = CURRENT_TIMESTAMP WHERE id = $1`,
                        { bind: [keyRecord.id] }
                    ).catch(() => {});
                }
            } else if (bearerToken) {
                const jwtSecret = process.env.JWT_SECRET || 'lynx_enterprise_dev_secret_2026';
                let decoded: any;
                try {
                    decoded = jwt.verify(bearerToken, jwtSecret);
                } catch (jwtErr: any) {
                    return res.status(401).json({
                        success: false,
                        error: 'INVALID_TOKEN',
                        message: `Bearer token verification failed: ${jwtErr.message}`
                    });
                }

                outletId = Number(decoded.outlet_id) || 0;
                authorizedScopes = Array.isArray(decoded.scopes) ? decoded.scopes : [];
                keyName = decoded.key_name || 'OAuth Client';
            } else {
                return res.status(401).json({
                    success: false,
                    error: 'UNAUTHORIZED',
                    message: 'Missing authentication credentials. Provide either "X-API-Key" header or "Authorization: Bearer <token>".',
                    docs: '/api/v1/developer/ecosystem/info'
                });
            }

            // Check Scope Permissions
            if (requiredScope && !authorizedScopes.includes(requiredScope) && !authorizedScopes.includes('*')) {
                return res.status(403).json({
                    success: false,
                    error: 'INSUFFICIENT_SCOPE',
                    message: `This endpoint requires scope "${requiredScope}". Your credentials only have: [${authorizedScopes.join(', ')}]`
                });
            }

            req.openApi = {
                outletId,
                scopes: authorizedScopes,
                keyName
            };

            next();
        } catch (err: any) {
            console.error('[OPEN API AUTH ERROR]:', err.message);
            return res.status(500).json({
                success: false,
                error: 'INTERNAL_AUTH_ERROR',
                message: err.message
            });
        }
    };
}

// -------------------------------------------------------------
// 1. ORDERS API (orders:read, orders:write)
// -------------------------------------------------------------

// GET /api/v1/open/orders - Fetch store sales / orders
router.get('/orders', verifyOpenApiAuth('orders:read'), async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletId = req.openApi.outletId;
        const limit = Math.min(Number(req.query.limit) || 25, 100);
        const offset = Number(req.query.offset) || 0;
        const status = req.query.status;

        let query = `
            SELECT id, outlet_id, sale_no, sale_date, customer_name, customer_phone, 
                   payment_mode, total_qty, sub_total, total_discount, net_amount, status, created_at
            FROM sales_headers
            WHERE (outlet_id = $1 OR $1 = 0)
        `;
        const binds: any[] = [outletId];

        if (status) {
            binds.push(status);
            query += ` AND status = $${binds.length}`;
        }

        query += ` ORDER BY sale_date DESC LIMIT $${binds.length + 1} OFFSET $${binds.length + 2}`;
        binds.push(limit, offset);

        const rows = await db.query(query, { bind: binds });
        const orders = rows[0] || [];

        return res.json({
            success: true,
            outletId,
            count: orders.length,
            limit,
            offset,
            data: orders.map((o: any) => ({
                id: o.id,
                orderNumber: o.sale_no,
                saleDate: o.sale_date,
                customer: {
                    name: o.customer_name || 'Walk-in Customer',
                    phone: o.customer_phone || ''
                },
                paymentMode: o.payment_mode,
                totalQty: Number(o.total_qty || 0),
                subTotal: Number(o.sub_total || 0),
                totalDiscount: Number(o.total_discount || 0),
                grandTotal: Number(o.net_amount || 0),
                status: o.status || 'COMPLETED',
                createdAt: o.created_at
            }))
        });
    } catch (err: any) {
        console.error('[OPEN API ORDERS GET ERROR]:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
});

// GET /api/v1/open/orders/:id - Get specific order details
router.get('/orders/:id', verifyOpenApiAuth('orders:read'), async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletId = req.openApi.outletId;
        const orderId = req.params.id;

        const headerRows = await db.query(
            `SELECT * FROM sales_headers WHERE id = $1 AND (outlet_id = $2 OR $2 = 0) LIMIT 1`,
            { bind: [orderId, outletId] }
        );

        if (!headerRows[0] || headerRows[0].length === 0) {
            return res.status(404).json({ success: false, message: `Order #${orderId} not found.` });
        }

        const o = headerRows[0][0];

        // Fetch line items
        const itemRows = await db.query(
            `SELECT id, item_id, item_code, item_name, barcode, unit, qty, selling_price, net_amount 
             FROM sales_items WHERE sale_id = $1`,
            { bind: [orderId] }
        );

        return res.json({
            success: true,
            data: {
                id: o.id,
                orderNumber: o.sale_no,
                saleDate: o.sale_date,
                customer: {
                    name: o.customer_name || 'Walk-in Customer',
                    phone: o.customer_phone || ''
                },
                paymentMode: o.payment_mode,
                totalQty: Number(o.total_qty || 0),
                subTotal: Number(o.sub_total || 0),
                totalDiscount: Number(o.total_discount || 0),
                grandTotal: Number(o.net_amount || 0),
                status: o.status,
                items: (itemRows[0] || []).map((it: any) => ({
                    itemId: it.item_id,
                    itemCode: it.item_code,
                    itemName: it.item_name,
                    barcode: it.barcode,
                    unit: it.unit,
                    quantity: Number(it.qty || 0),
                    unitPrice: Number(it.selling_price || 0),
                    totalPrice: Number(it.net_amount || 0)
                }))
            }
        });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
});

// POST /api/v1/open/orders - Inject external order into POS
router.post('/orders', verifyOpenApiAuth('orders:write'), async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletId = req.openApi.outletId > 0 ? req.openApi.outletId : (Number(req.body.outletId) || 1);
        const {
            customerName = 'External Order',
            customerPhone = '',
            paymentMode = 'ONLINE',
            items = [],
            notes = 'Ingested via Open API'
        } = req.body;

        if (!Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ success: false, error: 'At least one item is required in items array.' });
        }

        const saleNo = `EXT_${Date.now().toString().substring(5)}`;
        let totalQty = 0;
        let subTotal = 0;

        for (const item of items) {
            const qty = Number(item.quantity || item.qty || 1);
            const price = Number(item.unitPrice || item.price || 0);
            totalQty += qty;
            subTotal += (qty * price);
        }

        const netAmount = subTotal;

        // Insert header
        const headerRes = await db.query(
            `INSERT INTO sales_headers (
                outlet_id, sale_no, sale_date, customer_name, customer_phone, 
                payment_mode, total_qty, sub_total, total_discount, net_amount, notes, status, created_at, updated_at
            ) VALUES ($1, $2, CURRENT_TIMESTAMP, $3, $4, $5, $6, $7, 0, $8, $9, 'COMPLETED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id`,
            { bind: [outletId, saleNo, customerName, customerPhone, paymentMode, totalQty, subTotal, netAmount, notes] }
        );

        const newSaleId = headerRes[0][0].id;

        // Insert items
        for (const it of items) {
            const qty = Number(it.quantity || it.qty || 1);
            const price = Number(it.unitPrice || it.price || 0);
            const lineTotal = qty * price;

            await db.query(
                `INSERT INTO sales_items (
                    sale_id, item_id, item_code, item_name, barcode, unit, qty, selling_price, net_amount
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
                {
                    bind: [
                        newSaleId,
                        it.itemId || 1,
                        it.itemCode || 'EXT_ITEM',
                        it.itemName || it.title || 'Online Product',
                        it.barcode || '',
                        it.unit || 'PCS',
                        qty,
                        price,
                        lineTotal
                    ]
                }
            );
        }

        return res.status(201).json({
            success: true,
            message: 'Order created and ingested into POS successfully.',
            data: {
                id: newSaleId,
                orderNumber: saleNo,
                outletId,
                totalQty,
                grandTotal: netAmount,
                status: 'COMPLETED'
            }
        });
    } catch (err: any) {
        console.error('[OPEN API ORDER CREATE ERROR]:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
});

// -------------------------------------------------------------
// 2. BILLING & INVOICES API (billing:read)
// -------------------------------------------------------------

// GET /api/v1/open/billing/invoices - Invoices and financial ledger summaries
router.get('/billing/invoices', verifyOpenApiAuth('billing:read'), async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletId = req.openApi.outletId;
        const limit = Math.min(Number(req.query.limit) || 25, 100);
        const offset = Number(req.query.offset) || 0;

        const rows = await db.query(
            `SELECT id, outlet_id, sale_no, sale_date, customer_name, payment_mode, 
                    sub_total, total_discount, net_amount, status, created_at
             FROM sales_headers
             WHERE (outlet_id = $1 OR $1 = 0)
             ORDER BY sale_date DESC
             LIMIT $2 OFFSET $3`,
            { bind: [outletId, limit, offset] }
        );

        return res.json({
            success: true,
            count: (rows[0] || []).length,
            data: (rows[0] || []).map((b: any) => ({
                invoiceId: b.id,
                invoiceNumber: b.sale_no,
                date: b.sale_date,
                customer: b.customer_name || 'Walk-in',
                paymentMethod: b.payment_mode,
                subTotal: Number(b.sub_total || 0),
                discount: Number(b.total_discount || 0),
                taxAmount: 0,
                netPayable: Number(b.net_amount || 0),
                status: b.status
            }))
        });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
});

// -------------------------------------------------------------
// 3. REPORTS & ANALYTICS API (reports:read)
// -------------------------------------------------------------

// GET /api/v1/open/reports/sales-summary - Revenue, order counts, payment breakdowns
router.get('/reports/sales-summary', verifyOpenApiAuth('reports:read'), async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletId = req.openApi.outletId;

        // Aggregate today's or overall revenue
        const summaryRows = await db.query(
            `SELECT 
                COUNT(*) as total_orders,
                COALESCE(SUM(net_amount), 0) as total_revenue,
                COALESCE(SUM(total_discount), 0) as total_discounts,
                COALESCE(AVG(net_amount), 0) as avg_order_value
             FROM sales_headers
             WHERE (outlet_id = $1 OR $1 = 0)`,
            { bind: [outletId] }
        );

        // Payment method breakdown
        const paymentRows = await db.query(
            `SELECT payment_mode, COUNT(*) as count, COALESCE(SUM(net_amount), 0) as total
             FROM sales_headers
             WHERE (outlet_id = $1 OR $1 = 0)
             GROUP BY payment_mode`,
            { bind: [outletId] }
        );

        const summary = summaryRows[0]?.[0] || {};
        const payments = (paymentRows[0] || []).map((p: any) => ({
            mode: p.payment_mode || 'OTHER',
            count: Number(p.count || 0),
            amount: Number(p.total || 0)
        }));

        return res.json({
            success: true,
            outletId,
            generatedAt: new Date().toISOString(),
            data: {
                totalOrders: Number(summary.total_orders || 0),
                totalRevenue: Number(summary.total_revenue || 0),
                totalDiscounts: Number(summary.total_discounts || 0),
                averageOrderValue: Math.round(Number(summary.avg_order_value || 0) * 100) / 100,
                paymentBreakdown: payments
            }
        });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
});

// -------------------------------------------------------------
// 4. INVENTORY & PRODUCTS API (inventory:read)
// -------------------------------------------------------------

// GET /api/v1/open/inventory/items - Real-time product catalog & stock
router.get('/inventory/items', verifyOpenApiAuth('inventory:read'), async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletId = req.openApi.outletId;
        const limit = Math.min(Number(req.query.limit) || 50, 200);

        const rows = await db.query(
            `SELECT id, item_code, item_name, item_group, sub_category, unit, rate, opening_balance, is_active
             FROM item_master
             WHERE (outlet_id = $1 OR $1 = 0) AND is_active = TRUE
             ORDER BY item_name ASC
             LIMIT $2`,
            { bind: [outletId, limit] }
        );

        return res.json({
            success: true,
            count: (rows[0] || []).length,
            data: (rows[0] || []).map((it: any) => ({
                id: it.id,
                itemCode: it.item_code,
                name: it.item_name,
                category: it.item_group || it.sub_category || 'General',
                unit: it.unit || 'PCS',
                sellingPrice: Number(it.rate || 0),
                currentStock: Number(it.opening_balance || 0)
            }))
        });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
export default router;
