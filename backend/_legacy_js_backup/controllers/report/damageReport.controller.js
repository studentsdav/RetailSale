const { resolveOutletScope } = require('../../utils/outletScopeHelper');

exports.getDamageReport = async (req, res) => {
  try {
    const reqOutlet = req.query.outlet_id || req.query.outletId;
    const scope = await resolveOutletScope(req, reqOutlet);
    const { from, to } = req.query;

    const [rows] = await req.propertyDb.query(
      `
      SELECT
        dh.damage_date   AS date,
        im.item_name     AS item,
        im.brand         AS brand,
        im.item_group    AS category,
        di.qty           AS qty,
        di.rate          AS rate,
        di.remarks       AS reason,
        u.username       AS "user"

      FROM damage_items di
      JOIN damage_headers dh
        ON dh.id = di.damage_id

      JOIN item_master im
        ON im.id = di.item_id

      LEFT JOIN users u
        ON u.id = dh.created_by

      WHERE dh.outlet_id IN (:outletIds)
        AND dh.damage_date BETWEEN :from AND :to

      ORDER BY dh.damage_date DESC
      `,
      {
        replacements: { outletIds: scope.outletIds, from, to }
      }
    );

    res.json({
      success: true,
      data: rows
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({
      success: false,
      message: 'Failed to load damage report'
    });
  }
};
