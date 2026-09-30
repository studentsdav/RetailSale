const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const { createLedgerEntry } = require('../../services/cashLedger.service');
const { Op } = require('sequelize');
const { normalizeDateKey } = require('../../utils/dateQuery');

function deriveRefundStatus(total, refunded) {
    const totalAmount = Number(total) || 0;
    const refundedAmount = Number(refunded) || 0;

    if (refundedAmount <= 0) return 'PENDING';
    if (refundedAmount >= totalAmount) return 'REFUNDED';
    return 'PARTIAL';
}

exports.getGrnsByDate = async (req, res) => {
    try {
        const { date } = req.query;
        const outlet_id = req.user.outlet_id;
        const normalizedDate = normalizeDateKey(date);

        const where = { outlet_id };
        if (date) {
            where.receipt_date = normalizedDate || date;
        }

        const grns = await req.propertyDb.models.goods_receipts.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.supplier_master,
                    as: 'supplier',
                    attributes: ['supplier_name']
                }
            ],
            order: [['receipt_date', 'DESC'], ['id', 'DESC']]
        });

        res.json({ success: true, data: grns });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getReceivedItems = async (req, res) => {
    try {
        const { grnId } = req.params;

        const items = await req.propertyDb.models.goods_receipt_items.findAll({
            where: { grn_id: grnId },
            order: [['id', 'ASC']]
        });

        res.json({ success: true, data: items });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getReturnedQty = async (req, res) => {
    try {
        const sum = await req.propertyDb.models.supplier_return_items.sum('qty', {
            where: { receipt_item_id: req.params.receiptItemId }
        }) || 0;

        res.json({
            success: true,
            data: { returned_qty: sum }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.saveSupplierReturn = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const {
            grn_id,
            supplier_id,
            return_date,
            notes,
            items = []
        } = req.body;

        if (!grn_id || !supplier_id || !return_date || items.length === 0) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'GRN, supplier, return date and items are required'
            });
        }

        const return_no = `SPR-${Date.now()}`;
        let total_amount = 0;

        const header = await req.propertyDb.models.supplier_return_headers.create({
            return_no,
            outlet_id,
            supplier_id,
            grn_id,
            return_date,
            notes: notes || null,
            created_by: user_id
        }, { transaction: t });

        for (const item of items) {
            const receiptItem = await req.propertyDb.models.goods_receipt_items.findByPk(
                item.receipt_item_id,
                { transaction: t }
            );

            if (!receiptItem) {
                throw new Error('Invalid received item selected');
            }

            const returnedSum = await req.propertyDb.models.supplier_return_items.sum('qty', {
                where: { receipt_item_id: item.receipt_item_id },
                transaction: t
            }) || 0;

            const remainingQty = Number(receiptItem.qty) - Number(returnedSum);
            const qty = Number(item.qty) || 0;
            const rate = Number(item.rate ?? receiptItem.rate) || 0;

            if (qty <= 0) {
                throw new Error(`Return qty must be greater than 0 for ${receiptItem.item_name}`);
            }

            if (qty > remainingQty) {
                throw new Error(`Return qty exceeds allowed for ${receiptItem.item_name}. Remaining: ${remainingQty}`);
            }

            const amount = qty * rate;
            total_amount += amount;

            await req.propertyDb.models.supplier_return_items.create({
                return_id: header.id,
                receipt_item_id: receiptItem.id,
                item_id: receiptItem.item_id,
                item_code: receiptItem.item_code,
                item_name: receiptItem.item_name,
                unit: receiptItem.unit,
                qty,
                rate,
                amount
            }, { transaction: t });

            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: receiptItem.item_code,
                txn_date: return_date,
                txn_type: 'SUPPLIER_RETURN',
                ref_no: return_no,
                qty_out: qty,
                transaction: t
            });
        }

        await header.update({
            total_amount,
            refunded_amount: 0,
            status: 'PENDING'
        }, { transaction: t });

        await audit.log({
            req,
            module: 'SUPPLIER_RETURN',
            action: 'CREATE',
            table: 'supplier_return_headers',
            recordId: header.id,
            newData: req.body
        });

        await t.commit();

        res.json({
            success: true,
            message: 'Supplier return saved successfully',
            data: { id: header.id, return_no }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listSupplierReturns = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date, status } = req.query;
        const where = { outlet_id };

        if (from_date && to_date) {
            where.return_date = { [Op.between]: [from_date, to_date] };
        }
        if (status) {
            where.status = status;
        }

        const rows = await req.propertyDb.models.supplier_return_headers.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.supplier_master,
                    as: 'supplier',
                    attributes: ['supplier_name']
                },
                {
                    model: req.propertyDb.models.goods_receipts,
                    as: 'grn',
                    attributes: ['grn_no', 'supplier_bill_no']
                }
            ],
            order: [['return_date', 'DESC'], ['id', 'DESC']]
        });

        res.json({ success: true, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getRefunds = async (req, res) => {
    try {
        const data = await req.propertyDb.models.supplier_return_refunds.findAll({
            where: { return_id: req.params.returnId, outlet_id: req.user.outlet_id },
            order: [['refund_date', 'DESC'], ['id', 'DESC']]
        });

        res.json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.receiveRefund = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const { id } = req.params;
        const {
            amount,
            refund_date,
            payment_mode,
            reference_no,
            notes
        } = req.body;

        const header = await req.propertyDb.models.supplier_return_headers.findOne({
            where: { id, outlet_id },
            include: [
                {
                    model: req.propertyDb.models.supplier_master,
                    as: 'supplier',
                    attributes: ['supplier_name']
                }
            ],
            transaction: t
        });

        if (!header) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Supplier return not found' });
        }

        const pendingAmount = Number(header.total_amount) - Number(header.refunded_amount);
        const refundAmount = Number(amount) || 0;

        if (refundAmount <= 0 || refundAmount > pendingAmount) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid refund amount' });
        }

        await req.propertyDb.models.supplier_return_refunds.create({
            return_id: header.id,
            outlet_id,
            supplier_id: header.supplier_id,
            refund_date,
            amount: refundAmount,
            payment_mode,
            reference_no: reference_no || null,
            notes: notes || null,
            created_by: user_id
        }, { transaction: t });

        const refundedAmount = Number(header.refunded_amount) + refundAmount;

        await header.update({
            refunded_amount: refundedAmount,
            status: deriveRefundStatus(header.total_amount, refundedAmount)
        }, { transaction: t });

        if (payment_mode !== 'CREDIT') {
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id,
                txn_date: refund_date,
                transaction_type: 'SUPPLIER_RETURN_REFUND',
                reference_type: 'SUPPLIER_RETURN',
                reference_id: header.id,
                reference_no: header.return_no,
                party_name: header.supplier?.supplier_name || null,
                payment_method: payment_mode,
                amount_in: refundAmount,
                notes: notes || `Refund received for supplier return ${header.return_no}`,
                created_by: user_id,
                transaction: t
            });
        }

        await audit.log({
            req,
            module: 'SUPPLIER_RETURN',
            action: 'RECEIVE_REFUND',
            table: 'supplier_return_headers',
            recordId: header.id,
            newData: req.body
        });

        await t.commit();

        res.json({ success: true, message: 'Refund received successfully' });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};
