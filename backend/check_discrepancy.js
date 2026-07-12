const propertyDb = require('./db/models');
const { Op } = require('sequelize');

(async () => {
    try {
        await propertyDb.authenticate();
        console.log("DB connected successfully");

        const sales = await propertyDb.models.sales_headers.findAll({
            where: {
                is_latest: true,
                is_deleted: false
            }
        });

        let sumSubTotal = 0;
        let sumDiscount = 0;
        let sumCharges = 0;
        let sumTax = 0;
        let sumNetAmount = 0;

        console.log(`Checking ${sales.length} sales...`);
        for (const s of sales) {
            const sub = parseFloat(s.sub_total || 0);
            const disc = parseFloat(s.total_discount || 0);
            const chg = parseFloat(s.charge_total || 0);
            const tax = parseFloat(s.total_tax || 0);
            const net = parseFloat(s.net_amount || 0);

            sumSubTotal += sub;
            sumDiscount += disc;
            sumCharges += chg;
            sumTax += tax;
            sumNetAmount += net;

            const formulaVal = sub - disc + chg + tax;
            const diff = Math.abs(formulaVal - net);
            if (diff > 0.05) {
                console.log(`Discrepancy in Sale #${s.id} (${s.sale_no}):`);
                console.log(`  sub_total: ${sub}`);
                console.log(`  total_discount: ${disc}`);
                console.log(`  charge_total: ${chg}`);
                console.log(`  total_tax: ${tax}`);
                console.log(`  net_amount: ${net}`);
                console.log(`  Formula (sub - disc + chg + tax) = ${formulaVal}`);
                console.log(`  Difference: ${diff}`);
                console.log(`  Notes: ${s.notes}`);
            }
        }

        console.log("\nSUM OF ALL SALES:");
        console.log(`  Sub-Total: ${sumSubTotal.toFixed(2)}`);
        console.log(`  Discount: ${sumDiscount.toFixed(2)}`);
        console.log(`  Charges: ${sumCharges.toFixed(2)}`);
        console.log(`  GST: ${sumTax.toFixed(2)}`);
        console.log(`  Net Amount: ${sumNetAmount.toFixed(2)}`);

        process.exit(0);
    } catch (e) {
        console.error("Error:", e);
        process.exit(1);
    }
})();
