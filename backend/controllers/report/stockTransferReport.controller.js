exports.getStockTransferReport = async (req, res) => {
    try {
        const { from_date, to_date, search = '' } = req.query;
        const outlet_id = req.user.outlet_id;

        if (!from_date || !to_date) {
            return res.status(400).json({
                success: false,
                message: 'from_date and to_date required'
            });
        }

        const [rows] = await req.propertyDb.query(
            `
            SELECT
                sl.ref_no,
                MIN(sl.txn_date) AS transfer_date,
                MAX(CASE WHEN sl.qty_out > 0 THEN sl.item_code END) AS source_item_code,
                MAX(CASE WHEN sl.qty_out > 0 THEN im.item_name END) AS source_item_name,
                MAX(CASE WHEN sl.qty_out > 0 THEN im.brand END) AS source_brand,
                MAX(CASE WHEN sl.qty_out > 0 THEN im.unit END) AS source_unit,
                COALESCE(MAX(CASE WHEN sl.qty_out > 0 THEN sl.qty_out END), 0) AS pack_count,
                MAX(CASE WHEN sl.qty_in > 0 THEN sl.item_code END) AS loose_item_code,
                MAX(CASE WHEN sl.qty_in > 0 THEN im.item_name END) AS loose_item_name,
                MAX(CASE WHEN sl.qty_in > 0 THEN im.brand END) AS loose_brand,
                MAX(CASE WHEN sl.qty_in > 0 THEN im.unit END) AS loose_unit,
                COALESCE(MAX(CASE WHEN sl.qty_in > 0 THEN sl.qty_in END), 0) AS loose_qty
            FROM stock_ledger sl
            JOIN item_master im
              ON im.item_code = sl.item_code
             AND im.outlet_id = sl.outlet_id
            WHERE sl.outlet_id = :outlet_id
              AND sl.txn_type = 'OPEN_PACK'
              AND sl.txn_date BETWEEN :from_date AND :to_date
              AND (
                :search = ''
                OR sl.ref_no ILIKE :search
                OR im.item_name ILIKE :search
                OR im.item_code ILIKE :search
              )
            GROUP BY sl.ref_no
            ORDER BY transfer_date DESC, sl.ref_no DESC
            `,
            {
                replacements: {
                    outlet_id,
                    from_date,
                    to_date,
                    search: search ? `%${search}%` : ''
                }
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
            message: 'Failed to generate stock transfer report'
        });
    }
};
