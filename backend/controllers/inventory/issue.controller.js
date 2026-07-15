const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const numberingHelper = require('./numberingSettingsV2.controller');
const { normalizeDateKey } = require('../../utils/dateQuery');

function deriveHeaderStatus(items) {
    const statuses = items.map(item => String(item.line_status || 'CLOSED').trim().toUpperCase());
    const hasOpen = statuses.includes('OPEN');
    const hasClosed = statuses.includes('CLOSED');
    const allCancelled = statuses.length > 0 && statuses.every(status => status === 'CANCELLED');

    if (allCancelled) return 'CANCELLED';
    if (hasOpen && hasClosed) return 'PARTIAL';
    if (hasOpen) return 'OPEN';
    return 'CLOSED';
}

function normalizeLineStatus(value, fallback = 'CLOSED') {
    const normalized = String(value || fallback).trim().toUpperCase();
    return normalized === 'OPEN' ? 'OPEN' : 'CLOSED';
}
exports.createIssue = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const { header, items } = req.body;
        let total = 0;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        let linkedRequest = null;

        if (header.open_request_no) {
            linkedRequest = await req.propertyDb.models.request_headers.findOne({
                where: {
                    id: header.open_request_no,
                    outlet_id,
                    approval_status: 'APPROVED',
                    status: {
                        [require('sequelize').Op.in]: ['OPEN', 'PARTIAL']
                    }
                },
                include: [{
                    model: req.propertyDb.models.request_items,
                    as: 'items'
                }],
                transaction: t
            });

            if (!linkedRequest) {
                await t.rollback();
                return res.status(400).json({
                    success: false,
                    message: 'Only approved requests can be issued'
                });
            }
        }

        const issue = await req.propertyDb.models.issue_headers.create({
            issue_no: header.issue_no,
            issue_date: header.issue_date,
            department: header.department,
            indent_no: header.indent_no,
            issue_type: header.issue_type,
            open_request_no: header.open_request_no,
            outlet_id: outlet_id,
            created_by: user_id,
            status: header.status || 'CLOSED'
        }, { transaction: t });

        for (const row of items) {
            const amount = row.qty * row.rate;
            total += amount;

            await req.propertyDb.models.issue_items.create({
                issue_id: issue.id,
                item_id: row.item_id,
                item_code: row.item_code,
                qty: row.qty,
                rate: row.rate,
                tax: row.tax,
                amount
            }, { transaction: t });

            // STOCK OUT
            await insertLedger({
                db: req.propertyDb,
                outlet_id: outlet_id,
                item_code: row.item_code,
                txn_date: header.issue_date,
                txn_type: 'ISSUE',
                ref_no: header.issue_no,
                qty_out: row.qty,
                transaction: t
            });
        }

        if (header.open_request_no) {
            for (const row of items) {
                const itemId = Number(row.item_id);

                if (!Number.isFinite(itemId)) continue;

                await req.propertyDb.models.request_items.update(
                    { line_status: normalizeLineStatus(row.line_status, 'CLOSED') },
                    {
                        where: {
                            request_id: header.open_request_no,
                            item_id: itemId,
                            line_status: 'OPEN'
                        },
                        transaction: t
                    }
                );
            }

            const requestItems = await req.propertyDb.models.request_items.findAll({
                where: { request_id: header.open_request_no },
                transaction: t
            });

            await linkedRequest.update(
                { status: deriveHeaderStatus(requestItems) },
                { transaction: t }
            );
        }

        await issue.update(
            { total_value: total },
            { transaction: t }
        );

        await audit.log({
            req,
            module: 'ISSUE',
            action: 'CREATE',
            table: 'issue_headers',
            recordId: issue.id,
            newData: issue.toJSON()
        });



        await t.commit();
        res.json({ success: true, issue_id: issue.id });

    } catch (e) {
        await t.rollback();
        res.status(500).json({ success: false, error: e.message });
    }
};

exports.modifyIssue = async (req, res) => {

    const t = await req.propertyDb.transaction();

    try {

        const { id } = req.params;
        const { department, items } = req.body;

        const outlet_id = req.user.outlet_id;

        const issue = await req.propertyDb.models.issue_headers.findOne({
            where: { id, outlet_id }
        });

        if (!issue) {
            return res.status(404).json({ success: false });
        }

        /// UPDATE DEPARTMENT
        await issue.update(
            { department },
            { transaction: t }
        );

        let total = 0;

        for (const row of items) {

            const item = await req.propertyDb.models.issue_items.findByPk(row.id);

            if (!item) continue;

            const oldQty = item.qty;
            const diffQty = row.qty - oldQty;

            await item.update({

                qty: row.qty,
                rate: row.rate,
                amount: row.qty * row.rate

            }, { transaction: t });

            /// LEDGER ADJUSTMENT
            if (diffQty !== 0) {

                if (diffQty > 0) {

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: row.item_master.item_code,
                        txn_date: new Date(),
                        txn_type: 'ISSUE_MODIFY',
                        ref_no: issue.issue_no,
                        qty_out: diffQty,
                        transaction: t
                    });

                } else {

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: row.item_master.item_code,
                        txn_date: new Date(),
                        txn_type: 'ISSUE_REVERSE',
                        ref_no: issue.issue_no,
                        qty_in: Math.abs(diffQty),
                        transaction: t
                    });

                }

            }

            total += row.qty * row.rate;
        }

        await issue.update(
            { total_value: total },
            { transaction: t }
        );

        await audit.log({
            req,
            module: 'ISSUE',
            action: 'MODIFY',
            table: 'issue_headers',
            recordId: issue.id,
            newData: req.body
        });


        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'ISSUE',
            title: 'Stock Issue Modified',
            message: `Issue #${issue.id} was modified`,
            type: 'WARNING',
            entity_id: issue.id
        }, { transaction: t });

        await t.commit();

        res.json({
            success: true,
            message: "Issue modified successfully"
        });

    } catch (err) {

        await t.rollback();

        res.status(500).json({
            success: false,
            error: err.message
        });

    }

};
exports.getIssueDetails = async (req, res) => {

    try {

        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const issue = await req.propertyDb.models.issue_headers.findOne({

            where: { id, outlet_id },

            include: [
                {
                    model: req.propertyDb.models.issue_items,
                    as: 'items',
                    attributes: ['id', 'item_id', 'qty', 'rate', 'tax'],
                    include: [
                        {
                            as: 'item_master',
                            model: req.propertyDb.models.item_master,
                            attributes: ['item_code', 'item_name', 'unit']
                        }
                    ]
                }
            ]
        });

        if (!issue) {
            return res.status(404).json({
                success: false
            });
        }

        res.json({
            success: true,
            data: issue
        });

    } catch (err) {

        res.status(500).json({
            success: false,
            error: err.message
        });

    }

};
exports.getIssueByDate = async (req, res) => {

    try {

        const outlet_id = req.user.outlet_id;
        const { date } = req.query;
        const normalizedDate = normalizeDateKey(date);

        const data = await req.propertyDb.models.issue_headers.findAll({

            where: {
                outlet_id,
                issue_date: normalizedDate || date,
                status: {
                    [require('sequelize').Op.ne]: 'CANCELLED'
                }
            },

            attributes: [
                'id',
                'issue_no',
                'department',
                'issue_date'
            ],

            order: [['created_at', 'DESC']]
        });

        res.json({
            success: true,
            data
        });

    } catch (err) {

        res.status(500).json({
            success: false,
            error: err.message
        });

    }

};

exports.getDepartments = async (req, res) => {
    try {
        const data = await req.propertyDb.models.stock_locations.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                is_active: true
            },
            order: [['location_name', 'ASC']]
        });

        res.json({ success: true, data });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getAvailableStock = async (req, res) => {
    const { itemCode } = req.params;

    const [result] = await req.propertyDb.query(`
    SELECT
      COALESCE(im.opening_balance, 0)
      +
      COALESCE(SUM(sl.qty_in - sl.qty_out), 0)
      AS qty
    FROM item_master im
    LEFT JOIN stock_ledger sl
      ON sl.item_code = im.item_code
      AND sl.outlet_id = im.outlet_id
    WHERE im.outlet_id = :outlet_id
      AND im.item_code = :itemCode
    GROUP BY im.opening_balance
  `, {
        replacements: {
            outlet_id: req.user.outlet_id,
            itemCode
        }
    });
    console.log(result[0].qty)
    res.json({
        success: true,
        qty: result.length ? Number(result[0].qty) : 0
    });
};



exports.updateIssueItem = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const { qty, rate, tax } = req.body;
        const item = await req.propertyDb.models.issue_items.findByPk(req.params.id);

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const oldQty = item.qty;
        const diffQty = qty - oldQty;

        await item.update({
            qty,
            rate,
            tax,
            amount: qty * rate
        }, { transaction: t });

        // STOCK ADJUSTMENT
        if (diffQty !== 0) {
            if (diffQty > 0) {
                // MORE ISSUE → STOCK OUT
                await insertLedger({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'ISSUE_UPDATE',
                    ref_no: `ISS-UPD-${item.issue_id}`,
                    qty_out: diffQty,
                    transaction: t
                });
            } else {
                // LESS ISSUE → STOCK IN (REVERSAL)
                await insertLedger({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'ISSUE_REVERSE',
                    ref_no: `ISS-UPD-${item.issue_id}`,
                    qty_in: Math.abs(diffQty),
                    transaction: t
                });
            }
        }

        await t.commit();

        await auditLog(req, {
            module: 'ISSUE',
            action: 'UPDATE_ITEM',
            entity: 'issue_items',
            entity_id: item.id,
            old_data: { qty: oldQty },
            new_data: { qty }
        });

        res.json({ success: true });

    } catch (e) {
        await t.rollback();
        res.status(500).json({ success: false, error: e.message });
    }
};
exports.deleteIssueItem = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const item = await req.propertyDb.models.issue_items.findByPk(req.params.id);

        if (!item) {
            return res.status(404).json({ success: false });
        }

        // STOCK REVERSAL
        await insertLedger({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            item_code: item.item_code,
            txn_date: new Date(),
            txn_type: 'ISSUE_DELETE',
            ref_no: `ISS-DEL-${item.issue_id}`,
            qty_in: item.qty,
            transaction: t
        });

        await item.destroy({ transaction: t });
        await t.commit();

        await auditLog(req, {
            module: 'ISSUE',
            action: 'DELETE_ITEM',
            entity: 'issue_items',
            entity_id: item.id,
            old_data: item.toJSON()
        });

        res.json({ success: true });

    } catch (e) {
        await t.rollback();
        res.status(500).json({ success: false, error: e.message });
    }
};
exports.getIssue = async (req, res) => {
    const issue = await req.propertyDb.models.issue_headers.findByPk(
        req.params.id,
        {
            include: [{ model: req.propertyDb.models.issue_items, as: 'items' }]
        }
    );

    if (!issue) {
        return res.status(404).json({ success: false });
    }

    res.json({ success: true, data: issue });
};

exports.getNextIssueNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { date } = req.query;
        const resolved = await numberingHelper.getEffectiveSetting({
            db: req.propertyDb,
            outlet_id,
            module: 'INDENT',
            date
        });

        if (!resolved) {
            return res.status(400).json({ success: false, message: 'Numbering not set' });
        }

        const { effective, nextSetting } = resolved;
        const rows = await req.propertyDb.models.issue_headers.findAll({
            where: {
                outlet_id,
                issue_date: nextSetting?.start_date
                    ? {
                        [require('sequelize').Op.gte]: effective.start_date,
                        [require('sequelize').Op.lt]: nextSetting.start_date
                    }
                    : { [require('sequelize').Op.gte]: effective.start_date }
            },
            attributes: ['issue_no']
        });

        let nextNo = Number(effective.start_no) || 1;
        for (const row of rows) {
            const numeric = numberingHelper.extractNumericPart(row.issue_no, effective);
            if (numeric !== null) {
                nextNo = Math.max(nextNo, numeric + 1);
            }
        }

        res.json({
            success: true,
            data: {
                number: `${effective.prefix || ''}${nextNo}${effective.postfix || ''}`
            }
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

