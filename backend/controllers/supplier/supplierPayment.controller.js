const { Op } = require('sequelize');
const audit = require('../../services/audit.service');
const { createLedgerEntry, dateKey } = require('../../services/cashLedger.service');
exports.getSupplierBills = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { fromDate, toDate, supplierId, status } = req.query;

        const where = { outlet_id };

        if (supplierId && supplierId !== '' && supplierId !== 'null') {
            where.supplier_id = Number(supplierId);
        }

        if (status && status !== '' && status !== 'null') {
            where.status = status;
        }

        if (fromDate && toDate) {
            where.bill_date = {
                [Op.between]: [fromDate, toDate]
            };
        }

        const bills = await req.propertyDb.models.supplier_bills.findAll({
            where,
            include: [{
                model: req.propertyDb.models.supplier_master,
                as: 'supplier',
                attributes: ['supplier_name']
            }],
            order: [['bill_date', 'DESC']]
        });

        console.log("BILLS LENGTH:", bills.length);

        const totalPurchase = bills.reduce(
            (s, b) => s + Number(b.bill_amount), 0
        );

        const totalPaid = bills.reduce(
            (s, b) => s + Number(b.paid_amount), 0
        );

        const totalUnpaid = bills.reduce(
            (s, b) =>
                s + (Number(b.bill_amount) - Number(b.paid_amount)), 0
        );

        res.json({
            success: true,
            summary: {
                totalPurchase,
                totalPaid,
                totalUnpaid
            },
            data: bills
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};

exports.getSupplierBillDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const billId = Number(req.params.billId);

        if (!Number.isFinite(billId) || billId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid bill id'
            });
        }

        const bill = await req.propertyDb.models.supplier_bills.findOne({
            where: { id: billId, outlet_id },
            include: [{
                model: req.propertyDb.models.supplier_master,
                as: 'supplier',
                attributes: ['supplier_name', 'phone', 'address']
            }]
        });

        if (!bill) {
            return res.status(404).json({
                success: false,
                message: 'Supplier bill not found'
            });
        }

        const grn = await req.propertyDb.models.goods_receipts.findOne({
            where: {
                outlet_id,
                supplier_id: bill.supplier_id,
                supplier_bill_no: bill.bill_no
            },
            include: [{
                model: req.propertyDb.models.goods_receipt_items,
                as: 'items'
            }],
            order: [[{ model: req.propertyDb.models.goods_receipt_items, as: 'items' }, 'id', 'ASC']]
        });

        res.json({
            success: true,
            data: {
                bill: bill.toJSON(),
                grn: grn ? grn.toJSON() : null,
                items: grn?.items?.map((item) => item.toJSON()) || []
            }
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.paySupplierBill = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;

        const { bill_id, amount } = req.body;
        const paymentMode = String(req.body.payment_mode || 'CASH').trim().toUpperCase();
        const referenceNo = String(req.body.reference_no || '').trim() || null;
        const paymentDate = dateKey(req.body.payment_date || new Date());
        const note = String(req.body.note || '').trim() || null;

        const Bill = req.propertyDb.models.supplier_bills;

        const bill = await Bill.findOne({
            where: { id: bill_id, outlet_id },
            transaction: t
        });

        if (!bill) {
            await t.rollback();
            return res.status(404).json({ success: false });
        }

        const balance = bill.bill_amount - bill.paid_amount;

        if (amount <= 0 || amount > balance) {
            await t.rollback();
            return res.status(400).json({
                message: 'Invalid payment amount'
            });
        }

        const oldBillData = bill.toJSON();

        bill.paid_amount =
            Number(bill.paid_amount) + Number(amount);


        const totalPaid = Number(bill.paid_amount);
        const totalBill = Number(bill.bill_amount);

        bill.status =
            totalPaid >= totalBill
                ? 'PAID'
                : totalPaid > 0
                    ? 'PARTIAL'
                    : 'UNPAID';
        console.log("Before Save:", bill.paid_amount);

        await bill.save({ transaction: t });
        console.log("After Save:", bill.paid_amount);

        await req.propertyDb.models.supplier_payments.create({
            outlet_id,
            supplier_id: bill.supplier_id,
            bill_id: bill.id,
            payment_date: paymentDate,
            amount,
            payment_mode: paymentMode,
            reference_no: referenceNo,
            created_by: req.user.id
        }, { transaction: t });

        const supplier = await req.propertyDb.models.supplier_master.findByPk(
            bill.supplier_id,
            { transaction: t }
        );

        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: paymentDate,
            transaction_type: 'SUPPLIER_PAYMENT',
            reference_type: 'SUPPLIER_BILL',
            reference_id: bill.id,
            reference_no: bill.bill_no,
            party_name: supplier?.supplier_name || null,
            payment_method: paymentMode,
            amount_out: amount,
            notes: note || `Supplier payment for bill ${bill.bill_no}`,
            created_by: req.user.id,
            transaction: t
        });

        await audit.log({
            req,
            module: 'SUPPLIER_PAYMENT',
            action: 'PAY',
            table: 'supplier_bills',
            recordId: bill.id,
            old_data: oldBillData,
            new_data: bill.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();

        res.json({ success: true });

    } catch (err) {

        if (!t.finished) {
            await t.rollback();
        }

        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};


exports.getBillPayments = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const billId = req.params.billId;

        const payments = await req.propertyDb.models.supplier_payments.findAll({
            where: { bill_id: billId, outlet_id },
            order: [['payment_date', 'ASC']]
        });

        res.json({ success: true, data: payments });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
