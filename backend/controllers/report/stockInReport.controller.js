exports.getStockInReport = async (req, res) => {
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
        gr.id AS inwards_no,
        gr.receipt_date AS date,
        gr.supplier_bill_no AS bill_no,
        gr.grn_no,
        sm.supplier_name AS supplier,
        gr.supplier_bill_no AS supplier_bill,
   COALESCE(sm.gstin, '') AS supplier_gstin,
        COALESCE(sm.state, '') AS supplier_state,
        COALESCE(sb.status, 'UNPAID') AS bill_status,
        COALESCE(sb.paid_amount, 0) AS paid_amount,
        COALESCE(sb.bill_amount - sb.paid_amount, 0) AS outstanding_amount,
        im.item_name,
        im.brand,
        im.unit,

        gri.rate,
        gri.qty,
        gri.tax AS gst,
        COALESCE(gri.tax_amount, gri.gst_amount, 0) AS tax_amount,
        COALESCE(gri.total_after_tax, gri.amount + COALESCE(gri.gst_amount, 0), 0) AS total_after_tax

      FROM goods_receipts gr
        JOIN goods_receipt_items gri ON gri.grn_id = gr.id
      JOIN supplier_master sm ON sm.id = gr.supplier_id
      JOIN item_master im ON im.item_code = gri.item_code
      LEFT JOIN supplier_bills sb
        ON sb.outlet_id = gr.outlet_id
       AND sb.supplier_id = gr.supplier_id
       AND sb.bill_no = gr.supplier_bill_no

      WHERE gr.outlet_id = :outlet_id
        AND gr.receipt_date BETWEEN :from_date AND :to_date
        AND (
          im.item_name ILIKE :search
          OR sm.supplier_name ILIKE :search
        )

      ORDER BY gr.id, im.item_name
      `,
            {
                replacements: {
                    outlet_id,
                    from_date,
                    to_date,
                    search: `%${search}%`
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
            message: 'Failed to generate stock in report'
        });
    }
};
