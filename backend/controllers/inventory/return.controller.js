const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const { normalizeDateKey } = require('../../utils/dateQuery');

exports.getIndentsByDate = async (req, res) => {
    const { date } = req.query;
    const outlet_id = req.user.outlet_id;
    const normalizedDate = normalizeDateKey(date);

    const indents = await req.propertyDb.models.issue_headers.findAll({
        where: { issue_date: normalizedDate || date, outlet_id },
        attributes: ['id', 'issue_no']
    });

    res.json({ success: true, data: indents });
};
exports.getIssuedItems = async (req, res) => {
    const { issueId } = req.params;

    const items = await req.propertyDb.models.issue_items.findAll({
        where: { issue_id: issueId },
        include: [
            {
                model: req.propertyDb.models.item_master,
                as: 'item_master', // ✅ REQUIRED
                attributes: ['item_name', 'unit', 'item_code']
            }
        ]
    });

    res.json({ success: true, data: items });
};


exports.getReturnedQty = async (req, res) => {
    const sum =
        await req.propertyDb.models.return_items.sum('qty', {
            where: { issue_item_id: req.params.issueItemId }
        }) || 0;

    res.json({
        success: true,
        data: { returned_qty: sum }
    });
};

exports.saveReturn = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { issue_id, return_date, items } = req.body;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        // 1️⃣ Create return header
        const header = await req.propertyDb.models.return_headers.create({
            return_no: `RET-${Date.now()}`,
            issue_id,
            return_date,
            outlet_id,
            created_by: user_id
        }, { transaction: t });

        // 2️⃣ Loop items
        for (const it of items) {

            // 1️⃣ Get issued qty
            const issueItem = await req.propertyDb.models.issue_items.findByPk(
                it.issue_item_id
            );

            if (!issueItem) {
                throw new Error("Invalid issue item");
            }

            // 2️⃣ Get already returned qty
            const returnedSum = await req.propertyDb.models.return_items.sum('qty', {
                where: { issue_item_id: it.issue_item_id }
            }) || 0;

            const remainingQty = issueItem.qty - returnedSum;

            if (it.qty > remainingQty) {
                throw new Error(
                    `Return qty exceeds allowed. Remaining: ${remainingQty}`
                );
            }

            // 3️⃣ Now safe to insert
            await req.propertyDb.models.return_items.create({
                return_id: header.id,
                issue_item_id: it.issue_item_id,
                item_id: it.item_id,
                qty: it.qty,
                rate: it.rate
            }, { transaction: t });

            await insertLedger({
                db: req.propertyDb,
                outlet_id: outlet_id,
                item_code: it.item_code,
                txn_date: return_date,
                txn_type: 'RETURN',
                ref_no: header.return_no,
                qty_in: it.qty,
                transaction: t
            });
        }


        await req.propertyDb.models.system_notifications.create({
            outlet_id: outlet_id,
            module: 'RETURN',
            title: 'Items Returned',
            message: `Return #${header.return_no} recorded`,
            type: 'SUCCESS',
            entity_id: header.id
        }, { transaction: t });

        await audit.log({
            req,
            module: 'RETURN_ITEMS',
            action: 'RETURN_ITEMS',
            table: 'RETURN_ITEMS',
            recordId: header.outlet_id,
            newData: req.body
        });


        await t.commit();
        res.json({ success: true, message: 'Return saved successfully' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getReturn = async (req, res) => {
    const ret = await req.propertyDb.models.return_headers.findByPk(
        req.params.id,
        {
            include: [{ model: req.propertyDb.models.return_items }]
        }
    );

    if (!ret) {
        return res.status(404).json({ success: false });
    }

    res.json({ success: true, data: ret });
};
exports.updateReturnItem = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const { qty, rate } = req.body;
        const user_id = req.user.id;

        const item = await req.propertyDb.models.return_items.findByPk(req.params.id);

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const oldQty = item.qty;
        const diffQty = qty - oldQty;

        await item.update({
            qty,
            rate
        }, { transaction: t });

        // 🔁 STOCK LEDGER ADJUSTMENT
        if (diffQty !== 0) {
            if (diffQty > 0) {
                // MORE RETURN → STOCK IN
                await req.propertyDb.models.stock_ledger.create({
                    outlet_id: req.user.outlet_id,
                    item_id: item.item_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'RETURN_UPDATE',
                    ref_no: `RET-UPD-${item.return_id}`,
                    qty_in: diffQty,
                    qty_out: 0
                }, { transaction: t });
            } else {
                // LESS RETURN → STOCK OUT (REVERSAL)
                await req.propertyDb.models.stock_ledger.create({
                    outlet_id: req.user.outlet_id,
                    item_id: item.item_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'RETURN_REVERSE',
                    ref_no: `RET-UPD-${item.return_id}`,
                    qty_in: 0,
                    qty_out: Math.abs(diffQty)
                }, { transaction: t });
            }
        }

        await t.commit();

        await req.propertyDb.models.audit_logs.create({
            user_id,
            module: 'RETURN',
            action: 'UPDATE_ITEM',
            table_name: 'return_items',
            record_id: item.id,
            old_data: { qty: oldQty },
            new_data: { qty }
        });

        res.json({ success: true });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.deleteReturnItem = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const user_id = req.user.id;
        const item = await req.propertyDb.models.return_items.findByPk(req.params.id);

        if (!item) {
            return res.status(404).json({ success: false });
        }

        // 🔄 REVERSE STOCK
        await req.propertyDb.models.stock_ledger.create({
            outlet_id: req.user.outlet_id,
            item_id: item.item_id,
            item_code: item.item_code,
            txn_date: new Date(),
            txn_type: 'RETURN_DELETE',
            ref_no: `RET-DEL-${item.return_id}`,
            qty_in: 0,
            qty_out: item.qty
        }, { transaction: t });

        await item.destroy({ transaction: t });
        await t.commit();

        await req.propertyDb.models.audit_logs.create({
            user_id,
            module: 'RETURN',
            action: 'DELETE_ITEM',
            table_name: 'return_items',
            record_id: item.id,
            old_data: item.toJSON()
        });

        res.json({ success: true });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.cancelReturn = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const user_id = req.user.id;

        const header = await req.propertyDb.models.return_headers.findByPk(
            req.params.id,
            {
                include: [{ model: req.propertyDb.models.return_items }]
            }
        );

        if (!header) {
            return res.status(404).json({ success: false });
        }

        // 🔄 Reverse entire return
        for (const item of header.return_items) {
            await req.propertyDb.models.stock_ledger.create({
                outlet_id: header.outlet_id,
                item_id: item.item_id,
                item_code: item.item_code,
                txn_date: new Date(),
                txn_type: 'RETURN_CANCEL',
                ref_no: header.return_no,
                qty_in: 0,
                qty_out: item.qty
            }, { transaction: t });
        }

        await header.update({ status: 'CANCELLED' }, { transaction: t });
        await t.commit();

        await req.propertyDb.models.audit_logs.create({
            user_id,
            module: 'RETURN',
            action: 'CANCEL',
            table_name: 'return_headers',
            record_id: header.id
        });

        res.json({ success: true, message: 'Return cancelled successfully' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
