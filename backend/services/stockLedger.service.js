exports.insertLedger = async ({
    db,
    outlet_id,
    item_code,
    txn_date,
    txn_type,
    ref_no,
    qty_in = 0,
    qty_out = 0,
    transaction,
    allow_negative = false
}) => {
    // 1️⃣ Get last balance
    const last = await db.models.stock_ledger.findOne({
        where: { outlet_id, item_code },
        order: [['id', 'DESC']],
        transaction
    });

    let lastBalance = 0;

    if (last && last.balance !== null) {
        lastBalance = Number(last.balance);
    } else {
        const item = await db.models.item_master.findOne({
            where: { outlet_id, item_code },
            attributes: ['opening_balance'],
            transaction
        });

        lastBalance = item?.opening_balance
            ? Number(item.opening_balance)
            : 0;
    }

    const inQty = Number(qty_in) || 0;
    const outQty = Number(qty_out) || 0;

    const newBalance = lastBalance + inQty - outQty;


    console.log(inQty, outQty, lastBalance, newBalance)
    // 2️⃣ Check negative stock rule
    const settings = await db.models.system_settings.findOne({
        where: { outlet_id },
        transaction
    });

    if (
        !allow_negative &&
        !settings?.allow_negative_stock &&
        newBalance < 0
    ) {
        const item = await db.models.item_master.findOne({
            where: { outlet_id, item_code },
            attributes: ['id', 'item_name', 'min_level'],
            transaction
        });

        throw {
            status: 400,
            message: `Insufficient stock for item ${item.item_name}. Available: ${lastBalance}`
        };
    }

    // 3️⃣ Insert ledger
    await db.models.stock_ledger.create(
        {
            outlet_id,
            item_code,
            txn_date,
            txn_type,
            ref_no,
            qty_in: inQty,
            qty_out: outQty,
            balance: newBalance
        },
        { transaction }
    );

    const item = await db.models.item_master.findOne({
        where: { outlet_id, item_code },
        attributes: ['id', 'item_name', 'min_level'],
        transaction
    });

    if (
        item &&
        item.min_level &&
        newBalance <= Number(item.min_level)
    ) {

        await db.models.system_notifications.create({
            outlet_id,
            module: 'STOCK',
            title: 'Low Stock Alert',
            message: `${item.item_name} stock is low (${newBalance})`,
            type: 'WARNING',
            entity_id: item.id
        }, { transaction });

    }

};
