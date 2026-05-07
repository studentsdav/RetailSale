exports.getStockOutReport = async (req, res) => {
    try {
        const { from_date, to_date, type, department, item_id } = req.query;
        const outlet_id = req.user.outlet_id;

        if (!from_date || !to_date) {
            return res.status(400).json({
                success: false,
                message: 'from_date and to_date required'
            });
        }

        let departmentFilter = '';
        let itemFilter = '';

        if (department) {
            departmentFilter = 'AND ih.department = :department';
        }

        if (item_id) {
            itemFilter = 'AND im.id = :item_id';
        }

        // ================= SUMMARY REPORT =================
        if (type === 'summary') {

            const [rows] = await req.propertyDb.query(
                `
                SELECT
                    im.id,
                    im.item_name,
                    im.brand,
                im.unit,
                    SUM(ii.qty) AS total_qty,
                    AVG(ii.rate) AS avg_rate,
                    AVG(ii.tax) AS tax,
                    SUM((ii.qty * ii.rate) * ii.tax / 100) AS tax_amount,
                    SUM(ii.qty * ii.rate) AS total_amount,
                    SUM((ii.qty * ii.rate) + ((ii.qty * ii.rate) * ii.tax / 100)) AS total_after_tax
                FROM issue_headers ih
                JOIN issue_items ii ON ii.issue_id = ih.id
                JOIN item_master im ON im.id = ii.item_id
                WHERE ih.outlet_id = :outlet_id
                  AND ih.issue_date BETWEEN :from_date AND :to_date
                  ${departmentFilter}
                  ${itemFilter}
                GROUP BY im.id, im.item_name, im.brand, im.unit
                ORDER BY im.item_name
                `,
                {
                    replacements: { outlet_id, from_date, to_date, department, item_id }
                }
            );

            return res.json({
                success: true,
                type: 'summary',
                data: rows
            });
        }

        // ================= DETAIL REPORT =================
        const [rows] = await req.propertyDb.query(
            `
            SELECT
                ih.issue_no,
                ih.issue_date,
                ih.department,
                im.item_name,
                im.brand,
                im.unit,
                    ii.rate,
                ii.qty,
                ii.tax,
                ((ii.qty * ii.rate) * ii.tax / 100) AS tax_amount,
                (ii.qty * ii.rate) AS amount,
                (ii.qty * ii.rate) + ((ii.qty * ii.rate) * ii.tax / 100) AS total_after_tax
            FROM issue_headers ih
            JOIN issue_items ii ON ii.issue_id = ih.id
            JOIN item_master im ON im.id = ii.item_id
            WHERE ih.outlet_id = :outlet_id
              AND ih.issue_date BETWEEN :from_date AND :to_date
              ${departmentFilter}
              ${itemFilter}
            ORDER BY ih.issue_date, ih.issue_no
            `,
            {
                replacements: { outlet_id, from_date, to_date, department, item_id }
            }
        );

        res.json({
            success: true,
            type: 'detail',
            data: rows
        });



    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            message: 'Failed to generate stock out report'
        });
    }
};