/**
 * LYNX GROW - Recommendation & Customer Intelligence Service
 * Handles basket analysis, cross-sell/upsell recommendations, and customer buying insights.
 */

async function getCartRecommendations(propertyDb, outletId = 0, itemIds = [], itemCodes = []) {
    if (!propertyDb) return [];

    try {
        const cleanIds = (Array.isArray(itemIds) ? itemIds : [])
            .map(id => Number(id))
            .filter(id => !isNaN(id) && id > 0);
            
        const cleanCodes = (Array.isArray(itemCodes) ? itemCodes : [])
            .map(c => String(c).trim())
            .filter(c => c.length > 0);

        // 1. Co-occurrence basket analysis query
        if (cleanIds.length > 0 || cleanCodes.length > 0) {
            const coRes = await propertyDb.query(`
                SELECT 
                    si.item_id,
                    si.item_code,
                    si.item_name,
                    im.retail_sale_price AS rate,
                    im.item_group,
                    COUNT(DISTINCT si.sale_id) AS co_purchase_count
                FROM sales_items si
                JOIN item_master im ON si.item_id = im.id OR si.item_code = im.item_code
                WHERE si.sale_id IN (
                    SELECT sale_id 
                    FROM sales_items 
                    WHERE (item_id IN (:cleanIds) OR item_code IN (:cleanCodes))
                )
                AND (si.item_id NOT IN (:cleanIds) AND si.item_code NOT IN (:cleanCodes))
                AND (:outletId = 0 OR im.outlet_id = :outletId)
                AND im.is_active = true
                GROUP BY si.item_id, si.item_code, si.item_name, im.retail_sale_price, im.item_group
                ORDER BY co_purchase_count DESC, si.item_name ASC
                LIMIT 6
            `, {
                replacements: { 
                    outletId, 
                    cleanIds: cleanIds.length > 0 ? cleanIds : [-1],
                    cleanCodes: cleanCodes.length > 0 ? cleanCodes : ['__NONE__']
                },
                type: propertyDb.QueryTypes.SELECT
            });

            if (coRes && coRes.length > 0) {
                return coRes.map(r => ({
                    id: r.item_id,
                    item_code: r.item_code,
                    item_name: r.item_name,
                    rate: parseFloat(r.rate || 0),
                    item_group: r.item_group || '',
                    reason: `Frequently bought together (${r.co_purchase_count} times)`
                }));
            }
        }

        // 2. Fallback: Top-selling active items in store
        const topRes = await propertyDb.query(`
            SELECT 
                im.id AS item_id,
                im.item_code,
                im.item_name,
                im.retail_sale_price AS rate,
                im.item_group,
                COALESCE(SUM(si.qty), 0) AS total_qty_sold
            FROM item_master im
            LEFT JOIN sales_items si ON im.id = si.item_id OR im.item_code = si.item_code
            WHERE (:outletId = 0 OR im.outlet_id = :outletId)
              AND im.is_active = true
              AND COALESCE(im.opening_balance, 0) > 0
            GROUP BY im.id, im.item_code, im.item_name, im.retail_sale_price, im.item_group
            ORDER BY total_qty_sold DESC, im.item_name ASC
            LIMIT 6
        `, {
            replacements: { outletId },
            type: propertyDb.QueryTypes.SELECT
        });

        return (topRes || []).map(r => ({
            id: r.item_id,
            item_code: r.item_code,
            item_name: r.item_name,
            rate: parseFloat(r.rate || 0),
            item_group: r.item_group || '',
            reason: 'Top Selling Store Popular'
        }));

    } catch (error) {
        console.error('[LYNX GROW RECOMMENDATION ERROR]:', error.message);
        return [];
    }
}

async function getCustomerInsights(propertyDb, outletId = 0, customerId = null, phone = '') {
    const defaultInsights = {
        customerId: customerId || null,
        phone: phone || '',
        customerName: 'Guest Customer',
        totalOrders: 0,
        totalSpent: 0,
        averageOrderValue: 0,
        daysSinceLastPurchase: null,
        churnRisk: 'LOW',
        favoriteItems: [],
        suggestedOffer: 'Welcome Offer: 5% Off Next Purchase'
    };

    if (!propertyDb) return defaultInsights;

    try {
        const cleanPhone = (phone || '').trim();
        const cleanId = Number(customerId) || 0;

        // Query customer sales history
        const sales = await propertyDb.query(`
            SELECT 
                sh.id,
                sh.customer_name,
                sh.customer_phone,
                sh.sale_date,
                sh.net_amount,
                sh.payment_mode
            FROM sales_headers sh
            WHERE (:outletId = 0 OR sh.outlet_id = :outletId)
              AND sh.status = 'COMPLETED'
              AND (
                (:cleanId > 0 AND sh.id IN (SELECT sale_id FROM sales_headers WHERE id = :cleanId))
                OR (:cleanPhone <> '' AND sh.customer_phone = :cleanPhone)
              )
            ORDER BY sh.sale_date DESC
        `, {
            replacements: { outletId, cleanId, cleanPhone },
            type: propertyDb.QueryTypes.SELECT
        });

        if (!sales || sales.length === 0) {
            return defaultInsights;
        }

        const totalOrders = sales.length;
        const totalSpent = sales.reduce((sum, s) => sum + parseFloat(s.net_amount || 0), 0);
        const averageOrderValue = totalOrders > 0 ? (totalSpent / totalOrders) : 0;
        const latestSaleDate = new Date(sales[0].sale_date);
        const daysSinceLastPurchase = Math.floor((new Date() - latestSaleDate) / (1000 * 60 * 60 * 24));

        let churnRisk = 'LOW';
        if (daysSinceLastPurchase > 60) churnRisk = 'HIGH';
        else if (daysSinceLastPurchase > 30) churnRisk = 'MEDIUM';

        // Query favorite items purchased by customer
        const saleIds = sales.map(s => s.id);
        const favRes = await propertyDb.query(`
            SELECT 
                item_name,
                SUM(qty) AS total_qty,
                SUM(line_total) AS total_amount
            FROM sales_items
            WHERE sale_id IN (:saleIds)
            GROUP BY item_name
            ORDER BY total_qty DESC
            LIMIT 3
        `, {
            replacements: { saleIds: saleIds.length > 0 ? saleIds : [-1] },
            type: propertyDb.QueryTypes.SELECT
        });

        let suggestedOffer = 'Standard Loyalty Perk: Earn 1 Point per ₹100 spent';
        if (churnRisk === 'HIGH') {
            suggestedOffer = 'Re-engagement Special: 10% Off to welcome customer back!';
        } else if (churnRisk === 'MEDIUM') {
            suggestedOffer = 'VIP Reminder: 5% Bonus Points on next bill!';
        } else if (totalSpent > 10000) {
            suggestedOffer = 'High-Value VIP: Free Express Home Delivery + Premium Perk';
        }

        return {
            customerId: cleanId || null,
            phone: sales[0].customer_phone || cleanPhone,
            customerName: sales[0].customer_name || 'Valued Customer',
            totalOrders,
            totalSpent: parseFloat(totalSpent.toFixed(2)),
            averageOrderValue: parseFloat(averageOrderValue.toFixed(2)),
            daysSinceLastPurchase,
            churnRisk,
            favoriteItems: (favRes || []).map(f => ({
                itemName: f.item_name,
                qty: parseFloat(f.total_qty || 0),
                amount: parseFloat(f.total_amount || 0)
            })),
            suggestedOffer
        };

    } catch (error) {
        console.error('[LYNX GROW CUSTOMER INSIGHTS ERROR]:', error.message);
        return defaultInsights;
    }
}

module.exports = {
    getCartRecommendations,
    getCustomerInsights
};
