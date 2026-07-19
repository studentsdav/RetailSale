exports.getClosingReport = async (req, res) => {
  try {
    const outlet_id = req.user.outlet_id;
    const { from_date, to_date } = req.query;

    let startDate = from_date;
    if (!startDate) {
        const d = new Date();
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        startDate = `${y}-${m}-${day}`;
    }
    const endDate = to_date || startDate;

    const [rows] = await req.propertyDb.query(`
      SELECT
        im.item_group AS "group",
        im.item_name  AS name,
        COALESCE(im.brand, '') AS brand,
        im.unit       AS unit,
        COALESCE(AVG(im.rate),0) AS "avgRate",

        /* Opening Balance (Before from_date) */
        (
          COALESCE(im.opening_balance,0)
          +
          COALESCE(SUM(
            CASE WHEN DATE(sl.txn_date) < :startDate
                 THEN COALESCE(sl.qty_in,0) - COALESCE(sl.qty_out,0) ELSE 0 END
          ),0)
        ) AS "opening",

        /* Movement Inside Range */
        COALESCE(SUM(
          CASE WHEN DATE(sl.txn_date) BETWEEN :startDate AND :endDate
               THEN COALESCE(sl.qty_in,0) ELSE 0 END
        ),0) AS "receive",

        COALESCE(SUM(
          CASE WHEN DATE(sl.txn_date) BETWEEN :startDate AND :endDate
               AND sl.txn_type IN (
                 'RETURN','RETURN_UPDATE','RETURN_REVERSE','RETURN_DELETE','RETURN_CANCEL',
                 'SALE_MODIFY_REVERSE','GRN_UPDATE','GRN_MODIFY_IN','DAMAGE_DELETE','DAMAGE_REVERSE',
                 'ISSUE_REVERSE'
               )
               THEN sl.qty_in ELSE 0 END
        ),0) AS "returned",

        COALESCE(SUM(
          CASE WHEN DATE(sl.txn_date) BETWEEN :startDate AND :endDate
               AND sl.txn_type = 'SUPPLIER_RETURN'
               THEN sl.qty_out ELSE 0 END
        ),0) AS "supplierReturnQty",

        COALESCE(SUM(
          CASE WHEN DATE(sl.txn_date) BETWEEN :startDate AND :endDate
               THEN COALESCE(sl.qty_out,0) ELSE 0 END
        ),0) AS "issue",

        COALESCE(SUM(
          CASE WHEN DATE(sl.txn_date) BETWEEN :startDate AND :endDate
               AND sl.txn_type IN ('DAMAGE','DAMAGE_UPDATE')
               THEN sl.qty_out ELSE 0 END
        ),0) AS "damage"

      FROM item_master im
      LEFT JOIN stock_ledger sl
        ON sl.item_code = im.item_code
        AND sl.outlet_id = im.outlet_id

      WHERE im.outlet_id = :outlet_id

      GROUP BY
        im.item_group,
        im.item_name,
        im.brand,
        im.unit,
        im.opening_balance

      ORDER BY im.item_group, im.item_name
    `, {
      replacements: {
        outlet_id,
        startDate,
        endDate
      }
    });

    // calculate closing in JS
    const finalData = rows.map(r => {
      const closing =
        Number(r.opening)
        + Number(r.receive)
        - Number(r.issue);

      return {
        ...r,
        closing
      };
    });

    const [transactionRows] = await req.propertyDb.query(`
      SELECT
        sl.id,
        sl.txn_date AS "txnDate",
        sl.txn_type AS "txnType",
        sl.ref_no AS "refNo",
        sl.item_code AS "itemCode",
        COALESCE(im.item_name, sl.item_code) AS "itemName",
        COALESCE(im.brand, '') AS "brand",
        COALESCE(im.item_group, '') AS "group",
        COALESCE(sl.qty_in, 0) AS "qtyIn",
        COALESCE(sl.qty_out, 0) AS "qtyOut",
        COALESCE(sl.balance, 0) AS "balance"
      FROM stock_ledger sl
      LEFT JOIN item_master im
        ON im.item_code = sl.item_code
       AND im.outlet_id = sl.outlet_id
      WHERE sl.outlet_id = :outlet_id
        AND DATE(sl.txn_date) BETWEEN :startDate AND :endDate
      ORDER BY sl.txn_date ASC, sl.id ASC
    `, {
      replacements: {
        outlet_id,
        startDate,
        endDate
      }
    });

    res.json({
      success: true,
      from_date: startDate,
      to_date: endDate,
      data: finalData,
      transactions: transactionRows
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({
      success: false,
      message: 'Failed to load closing report'
    });
  }
};
