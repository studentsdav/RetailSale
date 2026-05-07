exports.getStockBalance = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const [rows] = await req.propertyDb.query(`
  SELECT
    im.item_name       AS name,
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

  WHERE im.outlet_id = :outlet_id
    AND im.is_active = TRUE

  GROUP BY
    im.id,
    im.item_name,
    im.item_group,
    im.unit,
    im.min_level,
    im.rate,
    im.opening_balance

  ORDER BY im.item_name
`,
            { replacements: { outlet_id } });


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
