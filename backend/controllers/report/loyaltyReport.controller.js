const { QueryTypes } = require('sequelize');

function normalizeSearch(value) {
    return String(value || '').trim().toLowerCase();
}

exports.getLoyaltyMasterReport = async (req, res) => {
    try {
        const outletId = req.user.outlet_id;
        const search = normalizeSearch(req.query.search);

        const rows = await req.propertyDb.query(
            `
WITH sales_base AS (
  SELECT
    outlet_id,
    CASE
      WHEN COALESCE(REGEXP_REPLACE(customer_phone, '\\D', '', 'g'), '') <> '' THEN 'PHONE:' || REGEXP_REPLACE(customer_phone, '\\D', '', 'g')
      WHEN COALESCE(TRIM(customer_gstin), '') <> '' THEN 'GSTIN:' || UPPER(TRIM(customer_gstin))
      WHEN COALESCE(TRIM(customer_name), '') <> '' THEN 'NAME:' || UPPER(TRIM(customer_name))
      ELSE NULL
    END AS customer_key,
    MAX(NULLIF(TRIM(customer_name), '')) AS customer_name,
    MAX(NULLIF(REGEXP_REPLACE(customer_phone, '\\D', '', 'g'), '')) AS customer_phone,
    MAX(NULLIF(UPPER(TRIM(customer_gstin)), '')) AS customer_gstin,
    COALESCE(SUM(net_amount), 0) AS total_lifetime_purchase
  FROM sales_headers
  WHERE outlet_id = :outlet_id
    AND status = 'COMPLETED'
    AND is_latest = TRUE
    AND is_deleted = FALSE
  GROUP BY outlet_id, customer_key
),
ledger_base AS (
  SELECT
    outlet_id,
    customer_key,
    MAX(NULLIF(TRIM(customer_name), '')) AS customer_name,
    MAX(NULLIF(REGEXP_REPLACE(customer_phone, '\\D', '', 'g'), '')) AS customer_phone,
    MAX(NULLIF(UPPER(TRIM(customer_gstin)), '')) AS customer_gstin,
    COALESCE(SUM(CASE WHEN transaction_type = 'EARNED' THEN points_delta ELSE 0 END), 0) AS total_points_earned,
    COALESCE(SUM(CASE WHEN transaction_type = 'REDEEMED' THEN ABS(points_delta) ELSE 0 END), 0) AS total_points_redeemed,
    COALESCE(SUM(CASE WHEN transaction_type = 'EXPIRED' THEN ABS(points_delta) ELSE 0 END), 0) AS points_expired,
    COALESCE(SUM(CASE WHEN transaction_type = 'EARNED' THEN available_points ELSE 0 END), 0) AS current_active_balance
  FROM customer_loyalty_ledger
  WHERE outlet_id = :outlet_id
  GROUP BY outlet_id, customer_key
),
merged AS (
  SELECT
    COALESCE(l.customer_key, s.customer_key) AS customer_key,
    COALESCE(l.customer_name, s.customer_name, 'Walk-in Customer') AS customer_name,
    COALESCE(l.customer_phone, s.customer_phone, '') AS customer_phone,
    COALESCE(l.customer_gstin, s.customer_gstin, '') AS customer_gstin,
    COALESCE(s.total_lifetime_purchase, 0) AS total_lifetime_purchase,
    COALESCE(l.total_points_earned, 0) AS total_points_earned,
    COALESCE(l.total_points_redeemed, 0) AS total_points_redeemed,
    COALESCE(l.points_expired, 0) AS points_expired,
    COALESCE(l.current_active_balance, 0) AS current_active_balance
  FROM ledger_base l
  FULL OUTER JOIN sales_base s
    ON l.customer_key = s.customer_key
  WHERE COALESCE(l.customer_key, s.customer_key) IS NOT NULL
)
SELECT *
FROM merged
ORDER BY customer_name ASC, customer_key ASC
            `,
            {
                replacements: { outlet_id: outletId },
                type: QueryTypes.SELECT
            }
        );

        const filtered = !search
            ? rows
            : rows.filter((row) => {
                  const haystack = [
                      row.customer_name,
                      row.customer_phone,
                      row.customer_gstin,
                      row.customer_key
                  ]
                      .join(' ')
                      .toLowerCase();
                  return haystack.includes(search);
              });

        res.json({ success: true, data: filtered });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getCustomerLoyaltyLedger = async (req, res) => {
    try {
        const outletId = req.user.outlet_id;
        const customerKey = String(req.query.customer_key || '').trim();
        if (!customerKey) {
            return res.status(400).json({
                success: false,
                message: 'customer_key is required'
            });
        }

        const rows = await req.propertyDb.query(
            `
SELECT
  id,
  transaction_date,
  transaction_type,
  points_delta,
  points_balance_after,
  bill_number,
  sale_id,
  expiry_date,
  customer_name,
  customer_phone,
  customer_gstin,
  meta
FROM customer_loyalty_ledger
WHERE outlet_id = :outlet_id
  AND customer_key = :customer_key
ORDER BY transaction_date ASC, id ASC
            `,
            {
                replacements: {
                    outlet_id: outletId,
                    customer_key: customerKey
                },
                type: QueryTypes.SELECT
            }
        );

        res.json({ success: true, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
