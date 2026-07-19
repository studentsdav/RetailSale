const { Op } = require('sequelize');

function toNumber(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function roundAmount(value) {
    return Number(toNumber(value).toFixed(2));
}

exports.getCommissionReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date, sale_source } = req.query;

        const where = {
            outlet_id,
            status: 'COMPLETED',
            is_deleted: false,
            is_latest: true,
            [Op.or]: [
                { commission_amount: { [Op.gt]: 0 } },
                { tcs_amount: { [Op.gt]: 0 } },
                { tds_amount: { [Op.gt]: 0 } }
            ]
        };

        if (from_date && to_date) {
            where.sale_date = {
                [Op.between]: [new Date(from_date), new Date(to_date)]
            };
        }

        if (sale_source && sale_source !== 'ALL') {
            where.sale_source = sale_source;
        }

        const sales = await req.propertyDb.models.sales_headers.findAll({
            where,
            order: [['sale_date', 'DESC']]
        });

        // Compute summaries
        let totalSalesAmount = 0;
        let totalTaxableAmount = 0;
        let totalCommission = 0;
        let totalCommissionTax = 0;
        let totalTcs = 0;
        let totalTds = 0;
        let totalDeductions = 0;
        let totalNetPayout = 0;
        let totalCommissionPercentageAmount = 0;
        let totalCommissionFixedAmount = 0;

        const data = sales.map(sale => {
            const netAmount = toNumber(sale.net_amount);
            const taxableAmount = toNumber(sale.taxable_amount || sale.sub_total || sale.net_amount);
            const commAmount = toNumber(sale.commission_amount);
            const commTaxAmount = toNumber(sale.commission_tax_amount);
            const tcsAmount = toNumber(sale.tcs_amount);
            const tdsAmount = toNumber(sale.tds_amount);
            const deductions = commAmount + commTaxAmount + tcsAmount + tdsAmount;
            const netPayout = toNumber(sale.net_payout);

            totalSalesAmount += netAmount;
            totalTaxableAmount += taxableAmount;
            totalCommission += commAmount;
            totalCommissionTax += commTaxAmount;
            totalTcs += tcsAmount;
            totalTds += tdsAmount;
            totalDeductions += deductions;
            totalNetPayout += netPayout;
            totalCommissionPercentageAmount += toNumber(sale.commission_percentage_amount);
            totalCommissionFixedAmount += toNumber(sale.commission_fixed_amount);

            return {
                id: sale.id,
                sale_no: sale.sale_no,
                sale_date: sale.sale_date,
                customer_name: sale.customer_name,
                customer_phone: sale.customer_phone,
                sale_source: sale.sale_source,
                net_amount: netAmount,
                taxable_amount: taxableAmount,
                commission_rate: toNumber(sale.commission_rate),
                commission_amount: commAmount,
                gst_rate_on_commission: toNumber(sale.gst_rate_on_commission),
                commission_tax_amount: commTaxAmount,
                tcs_rate: toNumber(sale.tcs_rate),
                tcs_amount: tcsAmount,
                tds_rate: toNumber(sale.tds_rate),
                tds_amount: tdsAmount,
                deductions: roundAmount(deductions),
                net_payout: netPayout,
                applied_rules: sale.applied_rules || 'Platform Fallback',
                commission_percentage_amount: toNumber(sale.commission_percentage_amount),
                commission_fixed_amount: toNumber(sale.commission_fixed_amount)
            };
        });

        res.json({
            success: true,
            summary: {
                total_sales_amount: roundAmount(totalSalesAmount),
                total_taxable_amount: roundAmount(totalTaxableAmount),
                total_commission: roundAmount(totalCommission),
                total_commission_tax: roundAmount(totalCommissionTax),
                total_tcs: roundAmount(totalTcs),
                total_tds: roundAmount(totalTds),
                total_deductions: roundAmount(totalDeductions),
                total_net_payout: roundAmount(totalNetPayout),
                total_commission_percentage_amount: roundAmount(totalCommissionPercentageAmount),
                total_commission_fixed_amount: roundAmount(totalCommissionFixedAmount)
            },
            data
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
