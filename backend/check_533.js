const propertyDb = require('./db/models');

(async () => {
    try {
        await propertyDb.authenticate();
        const order = await propertyDb.models.customer_orders.findOne({ where: { id: 271 } });
        if (order) console.log("ORDER 271:", order.toJSON());
        const sale = await propertyDb.models.sales_headers.findOne({ where: { id: 533 } });
        if (sale) console.log("SALE 533:", sale.toJSON());
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
})();
