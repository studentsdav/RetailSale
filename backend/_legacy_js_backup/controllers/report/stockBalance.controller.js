const { resolveOutletScope } = require('../../utils/outletScopeHelper');

exports.getStockBalance = async (req, res) => {
    try {
        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);

        let whereClause = 'WHERE im.outlet_id IN (:outletIds) AND im.is_active = TRUE';
        let replacements = { outletIds: scope.outletIds };

        const [rows] = await req.propertyDb.query(`
  SELECT
    im.item_name       AS name,
    im.brand           AS brand,
    im.item_group      AS category,
    im.unit,
    im.min_level       AS reorder,
    im.rate,

    (
      COALESCE(im.opening_balance, 0)
      +
      COALESCE(SUM(sl.qty_in - sl.qty_out), 0)
    ) AS qty

  FROM item_master im

  LEFT JOIN stock_ledger sl
    ON sl.item_code = im.item_code
   AND sl.outlet_id = im.outlet_id

  ${whereClause}

  GROUP BY
    im.id,
    im.item_name,
    im.brand,
    im.item_group,
    im.unit,
    im.min_level,
    im.rate,
    im.opening_balance

  ORDER BY im.item_name
`,
            { replacements });


        res.json({
            success: true,
            data: rows
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            message: 'Failed to load stock balance'
        });
    }
};
