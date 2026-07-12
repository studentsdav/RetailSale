const propertyDb = require('./db/models');

(async () => {
    try {
        await propertyDb.authenticate();
        const sales = await propertyDb.models.sales_headers.findAll({
            where: {
                is_latest: true,
                is_deleted: false
            }
        });
        console.log("Sales list:");
        for (const s of sales) {
            console.log(`Sale #${s.id} (${s.sale_no}): sub_total=${s.sub_total}, total_discount=${s.total_discount}, charge_total=${s.charge_total}, total_tax=${s.total_tax}, net_amount=${s.net_amount}, notes=${s.notes}`);
        }
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
})();
