const { QueryTypes } = require('sequelize');

const SEGMENT_ORDER = ['Champions', 'At-Risk', 'Churned', 'New'];
const analyticsCache = new Map();
const inFlight = new Map();

function toNumber(value) {
    if (value === null || value === undefined) return 0;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function formatDateKey(date) {
    return date.toISOString().slice(0, 10);
}

function buildLastNDays(n) {
    const today = new Date();
    const days = [];
    for (let i = n - 1; i >= 0; i -= 1) {
        const date = new Date(today);
        date.setDate(today.getDate() - i);
        days.push(formatDateKey(date));
    }
    return days;
}

async function buildRfmSegments(db, outletId) {
    const rows = await db.query(
        `
        WITH customer_base AS (
            SELECT
                COALESCE(NULLIF(TRIM(customer_phone), ''), NULLIF(TRIM(customer_name), ''), CONCAT('CUST#', id::text)) AS customer_key,
                MAX(DATE(sale_date)) AS last_purchase_date,
                MIN(DATE(sale_date)) AS first_purchase_date,
                COUNT(*)::int AS purchase_count,
                COALESCE(SUM(net_amount), 0)::numeric AS total_spend
            FROM sales_headers
            WHERE outlet_id = :outletId
              AND COALESCE(is_deleted, FALSE) = FALSE
              AND UPPER(COALESCE(status, '')) NOT IN ('DRAFT', 'CANCELLED', 'DELETED', 'VOID')
              AND sale_date IS NOT NULL
            GROUP BY 1
        ),
        scored AS (
            SELECT
                customer_key,
                purchase_count,
                total_spend,
                first_purchase_date,
                last_purchase_date,
                GREATEST((CURRENT_DATE - last_purchase_date), 0) AS recency_days
            FROM customer_base
        )
        SELECT
            CASE
                WHEN purchase_count <= 2 AND recency_days <= 30 THEN 'New'
                WHEN recency_days <= 30 AND purchase_count >= 5 AND total_spend >= 5000 THEN 'Champions'
                WHEN recency_days > 90 THEN 'Churned'
                ELSE 'At-Risk'
            END AS segment,
            COUNT(*)::int AS customer_count
        FROM scored
        GROUP BY 1
        `,
        {
            replacements: { outletId },
            type: QueryTypes.SELECT
        }
    );

    const countMap = new Map(rows.map((row) => [row.segment, toNumber(row.customer_count)]));
    return SEGMENT_ORDER.map((segment) => ({
        segment,
        customerCount: countMap.get(segment) || 0
    }));
}

async function buildSalesTrend(db, outletId) {
    const lastThirtyDays = buildLastNDays(30);
    const startDate = lastThirtyDays[0];

    const revenueRows = await db.query(
        `
        SELECT
            DATE(sale_date) AS day_key,
            COALESCE(SUM(net_amount), 0)::numeric AS revenue
        FROM sales_headers
        WHERE outlet_id = :outletId
          AND COALESCE(is_deleted, FALSE) = FALSE
          AND UPPER(COALESCE(status, '')) NOT IN ('DRAFT', 'CANCELLED', 'DELETED', 'VOID')
          AND DATE(sale_date) >= :startDate
        GROUP BY 1
        `,
        {
            replacements: { outletId, startDate },
            type: QueryTypes.SELECT
        }
    );

    const subscriptionRows = await db.query(
        `
        SELECT
            txn_date AS day_key,
            COALESCE(SUM(cart_qty), 0)::numeric AS subscription_volume
        FROM milk_subscription_consumptions
        WHERE outlet_id = :outletId
          AND txn_date >= :startDate
        GROUP BY 1
        `,
        {
            replacements: { outletId, startDate },
            type: QueryTypes.SELECT
        }
    );

    const revenueByDay = new Map(
        revenueRows.map((row) => [formatDateKey(new Date(row.day_key)), toNumber(row.revenue)])
    );
    const subscriptionsByDay = new Map(
        subscriptionRows.map((row) => [formatDateKey(new Date(row.day_key)), toNumber(row.subscription_volume)])
    );

    return lastThirtyDays.map((day) => ({
        date: day,
        revenue: revenueByDay.get(day) || 0,
        subscriptionVolume: subscriptionsByDay.get(day) || 0
    }));
}

async function buildMarketBasket(db, outletId) {
    const rows = await db.query(
        `
        WITH pair_rows AS (
            SELECT
                LEAST(COALESCE(NULLIF(TRIM(i1.item_name), ''), 'Item A'), COALESCE(NULLIF(TRIM(i2.item_name), ''), 'Item B')) AS item_a,
                GREATEST(COALESCE(NULLIF(TRIM(i1.item_name), ''), 'Item A'), COALESCE(NULLIF(TRIM(i2.item_name), ''), 'Item B')) AS item_b,
                i1.sale_id
            FROM sales_items i1
            INNER JOIN sales_items i2
                ON i1.sale_id = i2.sale_id
               AND i1.item_id < i2.item_id
            INNER JOIN sales_headers sh
                ON sh.id = i1.sale_id
            WHERE sh.outlet_id = :outletId
              AND COALESCE(sh.is_deleted, FALSE) = FALSE
              AND UPPER(COALESCE(sh.status, '')) NOT IN ('DRAFT', 'CANCELLED', 'DELETED', 'VOID')
        )
        SELECT
            item_a,
            item_b,
            COUNT(DISTINCT sale_id)::int AS occurrence_count
        FROM pair_rows
        GROUP BY item_a, item_b
        ORDER BY occurrence_count DESC, item_a ASC, item_b ASC
        LIMIT 10
        `,
        {
            replacements: { outletId },
            type: QueryTypes.SELECT
        }
    );

    return rows.map((row) => ({
        pairName: `${row.item_a} + ${row.item_b}`,
        occurrenceCount: toNumber(row.occurrence_count)
    }));
}

async function buildTopCustomerItems(db, outletId) {
    const rows = await db.query(
        `
        SELECT
            COALESCE(NULLIF(TRIM(sh.customer_name), ''), NULLIF(TRIM(sh.customer_phone), ''), 'Walk-in') AS customer_name,
            COALESCE(NULLIF(TRIM(si.item_name), ''), 'Unknown Item') AS item_name,
            COALESCE(SUM(si.qty), 0)::numeric AS total_qty,
            COUNT(DISTINCT sh.id)::int AS bill_count
        FROM sales_items si
        INNER JOIN sales_headers sh ON sh.id = si.sale_id
        WHERE sh.outlet_id = :outletId
          AND COALESCE(sh.is_deleted, FALSE) = FALSE
          AND UPPER(COALESCE(sh.status, '')) NOT IN ('DRAFT', 'CANCELLED', 'DELETED', 'VOID')
        GROUP BY 1, 2
        ORDER BY total_qty DESC, bill_count DESC, customer_name ASC, item_name ASC
        LIMIT 10
        `,
        {
            replacements: { outletId },
            type: QueryTypes.SELECT
        }
    );

    return rows.map((row) => ({
        customerName: row.customer_name || '',
        itemName: row.item_name || '',
        totalQty: toNumber(row.total_qty),
        billCount: toNumber(row.bill_count),
        label: `${row.customer_name || 'Walk-in'} - ${row.item_name || 'Unknown Item'}`
    }));
}

async function computeAnalyticsBundle(db, outletId) {
    const [rfmSegments, salesTrend, marketBasket, topCustomerItems] = await Promise.all([
        buildRfmSegments(db, outletId),
        buildSalesTrend(db, outletId),
        buildMarketBasket(db, outletId),
        buildTopCustomerItems(db, outletId)
    ]);

    return {
        rfmSegments,
        salesTrend,
        marketBasket,
        topCustomerItems
    };
}

async function refreshOutletAnalytics(db, outletId) {
    const data = await computeAnalyticsBundle(db, outletId);
    analyticsCache.set(String(outletId), {
        generatedAt: new Date().toISOString(),
        data
    });
    return data;
}

async function getOrBuildOutletAnalytics(db, outletId) {
    const key = String(outletId);
    const cached = analyticsCache.get(key);
    if (cached?.data) {
        return cached.data;
    }

    if (inFlight.has(key)) {
        return inFlight.get(key);
    }

    const pending = refreshOutletAnalytics(db, outletId)
        .finally(() => inFlight.delete(key));

    inFlight.set(key, pending);
    return pending;
}

async function refreshAllAnalytics(db) {
    const outletRows = await db.query(
        `
        SELECT DISTINCT outlet_id::int AS outlet_id
        FROM (
            SELECT outlet_id FROM sales_headers WHERE outlet_id IS NOT NULL
            UNION
            SELECT outlet_id FROM milk_subscription_consumptions WHERE outlet_id IS NOT NULL
        ) AS outlet_union
        `,
        { type: QueryTypes.SELECT }
    );

    for (const row of outletRows) {
        const outletId = toNumber(row.outlet_id);
        if (outletId > 0) {
            // sequential by design to reduce DB contention during nightly refresh
            // eslint-disable-next-line no-await-in-loop
            await refreshOutletAnalytics(db, outletId);
        }
    }
}

async function getRfmSegments(db, outletId) {
    const data = await getOrBuildOutletAnalytics(db, outletId);
    return data.rfmSegments || [];
}

async function getSalesTrend(db, outletId) {
    const data = await getOrBuildOutletAnalytics(db, outletId);
    return data.salesTrend || [];
}

async function getMarketBasket(db, outletId) {
    const data = await getOrBuildOutletAnalytics(db, outletId);
    return data.marketBasket || [];
}

async function getTopCustomerItems(db, outletId) {
    const data = await getOrBuildOutletAnalytics(db, outletId);
    return data.topCustomerItems || [];
}

module.exports = {
    getRfmSegments,
    getSalesTrend,
    getMarketBasket,
    getTopCustomerItems,
    refreshAllAnalytics
};
