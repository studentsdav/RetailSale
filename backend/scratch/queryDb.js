const db = require('../db/models');

async function check() {
    try {
        await db.authenticate();
        const kots = await db.models.kot_headers.findAll({
            include: [
                { model: db.models.kot_items, as: 'items' },
                { model: db.models.restaurant_tables, as: 'table' }
            ]
        });
        
        console.log("=== KOT HEADERS & ITEMS IN DB ===");
        console.log(JSON.stringify(kots.map(k => k.toJSON()), null, 2));
        
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

check();
