/**
 * LYNX OPERATE - Operations Excellence Service
 * Handles operational health monitoring, sales velocity reorder calculations, expiry tracking, and collection alerts.
 */

async function getOperationalHealthSnapshot(propertyDb, outletId = 0) {
    const context = {
        totalActiveProducts: 0,
        lowStockCount: 0,
        expiringItemCount: 0,
        pendingSupplierBillsCount: 0,
        pendingSupplierAmount: 0,
        pendingCustomerBalance: 0,
        todayCogs: 0,
        todayGrossProfit: 0,
        stockoutRiskItems: []
    };

    if (!propertyDb) return context;

    try {
        // 1. Stock & Product counts
        const stockRes = await propertyDb.query(`
            SELECT 
                COUNT(id) AS total_products,
                COALESCE(SUM(CASE WHEN COALESCE(opening_balance, 0) <= 10 THEN 1 ELSE 0 END), 0) AS low_stock_count
            FROM item_master
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND is_active = true
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        if (stockRes && stockRes.length > 0) {
            context.totalActiveProducts = parseInt(stockRes[0].total_products || 0);
            context.lowStockCount = parseInt(stockRes[0].low_stock_count || 0);
        }

        // 2. Near-expiry batch items (expiring within 60 days)
        const expiryRes = await propertyDb.query(`
            SELECT COUNT(gri.id) AS expiring_count
            FROM goods_receipt_items gri
            JOIN goods_receipts gr ON gri.grn_id = gr.id
            WHERE (:outletId = 0 OR gr.outlet_id = :outletId)
              AND gri.expiry_date IS NOT NULL
              AND gri.expiry_date <= (CURRENT_DATE + INTERVAL '60 days')
              AND COALESCE(gri.qty, 0) > 0
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        if (expiryRes && expiryRes.length > 0) {
            context.expiringItemCount = parseInt(expiryRes[0].expiring_count || 0);
        }

        // 3. Pending supplier bills & outstanding total
        const suppRes = await propertyDb.query(`
            SELECT 
                COUNT(id) AS pending_bills,
                COALESCE(SUM(COALESCE(net_amount, 0)), 0) AS pending_amount
            FROM goods_receipts
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND (status ILIKE '%pending%' OR status ILIKE '%unpaid%' OR status ILIKE '%draft%')
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        if (suppRes && suppRes.length > 0) {
            context.pendingSupplierBillsCount = parseInt(suppRes[0].pending_bills || 0);
            context.pendingSupplierAmount = parseFloat(suppRes[0].pending_amount || 0);
        }

        // 4. Low stock risk items list (top 5)
        const lowList = await propertyDb.query(`
            SELECT item_code, item_name, item_group, COALESCE(opening_balance, 0) AS stock
            FROM item_master
            WHERE (:outletId = 0 OR outlet_id = :outletId)
              AND is_active = true
              AND COALESCE(opening_balance, 0) <= 10
            ORDER BY opening_balance ASC
            LIMIT 5
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        context.stockoutRiskItems = lowList || [];

    } catch (error) {
        console.error('[LYNX OPERATE HEALTH SNAPSHOT ERROR]:', error.message);
    }

    return context;
}

async function getReorderAlerts(propertyDb, outletId = 0) {
    if (!propertyDb) return [];

    try {
        // Compute 30-day sales velocity and suggested reorder quantity
        const reorderRes = await propertyDb.query(`
            SELECT 
                im.id AS item_id,
                im.item_code,
                im.item_name,
                im.item_group,
                COALESCE(im.opening_balance, 0) AS current_stock,
                COALESCE(SUM(si.qty), 0) AS sales_last_30_days,
                ROUND(COALESCE(SUM(si.qty), 0) / 30.0, 2) AS daily_velocity,
                GREATEST(ROUND((COALESCE(SUM(si.qty), 0) / 30.0) * 15 - COALESCE(im.opening_balance, 0)), 10) AS suggested_reorder_qty
            FROM item_master im
            LEFT JOIN sales_items si ON (im.id = si.item_id OR im.item_code = si.item_code)
            LEFT JOIN sales_headers sh ON (si.sale_id = sh.id AND sh.status = 'COMPLETED' AND sh.sale_date >= NOW() - INTERVAL '30 days')
            WHERE (:outletId = 0 OR im.outlet_id = :outletId)
              AND im.is_active = true
              AND COALESCE(im.opening_balance, 0) <= 15
            GROUP BY im.id, im.item_code, im.item_name, im.item_group, im.opening_balance
            ORDER BY daily_velocity DESC, im.opening_balance ASC
            LIMIT 25
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        return (reorderRes || []).map(r => ({
            itemId: r.item_id,
            itemCode: r.item_code,
            itemName: r.item_name,
            itemGroup: r.item_group || '',
            currentStock: parseFloat(r.current_stock || 0),
            salesLast30Days: parseFloat(r.sales_last_30_days || 0),
            dailyVelocity: parseFloat(r.daily_velocity || 0),
            suggestedReorderQty: parseInt(r.suggested_reorder_qty || 10)
        }));
    } catch (error) {
        console.error('[LYNX OPERATE REORDER ALERTS ERROR]:', error.message);
        return [];
    }
}

async function getExpiryAlerts(propertyDb, outletId = 0, days = 60) {
    if (!propertyDb) return [];

    try {
        const expiryRes = await propertyDb.query(`
            SELECT 
                gri.id AS receipt_item_id,
                gri.item_code,
                gri.item_name,
                gri.brand,
                gri.unit,
                gri.qty,
                gri.rate,
                gri.expiry_date,
                (gri.expiry_date - CURRENT_DATE) AS days_until_expiry,
                gr.grn_no,
                sm.supplier_name
            FROM goods_receipt_items gri
            JOIN goods_receipts gr ON gri.grn_id = gr.id
            LEFT JOIN supplier_master sm ON gr.supplier_id = sm.id
            WHERE (:outletId = 0 OR gr.outlet_id = :outletId)
              AND gri.expiry_date IS NOT NULL
              AND gri.expiry_date <= (CURRENT_DATE + (:days || ' days')::INTERVAL)
              AND COALESCE(gri.qty, 0) > 0
            ORDER BY gri.expiry_date ASC
            LIMIT 25
        `, {
            replacements: { outletId, days: Number(days) || 60 },
            type: propertyDb.QueryTypes.SELECT
        });

        return (expiryRes || []).map(r => ({
            receiptItemId: r.receipt_item_id,
            itemCode: r.item_code,
            itemName: r.item_name,
            brand: r.brand || '',
            unit: r.unit || '',
            qty: parseFloat(r.qty || 0),
            rate: parseFloat(r.rate || 0),
            expiryDate: r.expiry_date,
            daysUntilExpiry: parseInt(r.days_until_expiry || 0),
            grnNo: r.grn_no || '',
            supplierName: r.supplier_name || 'N/A'
        }));
    } catch (error) {
        console.error('[LYNX OPERATE EXPIRY ALERTS ERROR]:', error.message);
        return [];
    }
}

module.exports = {
    getOperationalHealthSnapshot,
    getReorderAlerts,
    getExpiryAlerts
};
