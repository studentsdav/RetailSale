const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const numberingHelper = require('./numberingSettingsV2.controller');

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

async function syncItemPricing({ req, itemCode, purchaseRate, saleRate, transaction }) {
    if (!itemCode) return;
    const payload = {
        rate: Number(purchaseRate) || 0
    };

    if (saleRate !== undefined && saleRate !== null) {
        payload.retail_sale_price = Number(saleRate) || 0;
    }
    await req.propertyDb.models.item_master.update(
        payload,
        {
            where: {
                outlet_id: req.user.outlet_id,
                item_code: itemCode
            },
            transaction
        }
    );
}

exports.createReceiving = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        const {
            grn_no,
            manual_no,
            po_no,
            supplier_id,
            receipt_date,
            supplier_bill_no,
            status,
            items
        } = req.body;

        const billNo = String(supplier_bill_no || '').trim();
        if (!billNo || billNo === '0') {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Supplier bill no cannot be 0 or blank'
            });
        }

        let total = 0, gst = 0;

        items.forEach(i => {
            total += i.qty * i.rate;
            gst += (i.qty * i.rate) * i.tax / 100;
        });

        const netAmount = total + gst;
        const existingBill = await req.propertyDb.models.supplier_bills.findOne({
            where: {
                outlet_id,
                supplier_id,
                bill_no: supplier_bill_no
            },
            transaction: t
        });

        if (existingBill) {
            await t.rollback();
            return res.status(409).json({
                success: false,
                message: `Supplier bill no ${supplier_bill_no} already exists for this vendor`
            });
        }

        // 1️⃣ CREATE GRN
        const grn = await req.propertyDb.models.goods_receipts.create({
            outlet_id,
            grn_no,
            manual_no,
            po_no,
            supplier_id,
            receipt_date,
            supplier_bill_no,
            total_amount: total,
            total_gst: gst,
            net_amount: netAmount,
            status: status || 'CLOSED',
            created_by: user_id
        }, { transaction: t });

        // 2️⃣ GRN ITEMS + STOCK LEDGER
        for (const i of items) {
            const amount = (Number(i.qty) || 0) * (Number(i.rate) || 0);
            const taxAmount = amount * (Number(i.tax) || 0) / 100;
            await req.propertyDb.models.goods_receipt_items.create({
                grn_id: grn.id,
                item_id: i.item_id || null,
                item_code: i.code,
                item_name: i.name,
                brand: i.brand,
                unit: i.unit,
                qty: i.qty,
                rate: i.rate,
                tax: i.tax,
                amount,
                gst_amount: taxAmount,
                tax_amount: taxAmount,
                total_after_tax: amount + taxAmount,
                department: i.department || null,
                expiry_date: i.expiry_date
            }, { transaction: t });
            await syncItemPricing({
                req,
                itemCode: i.code,
                purchaseRate: i.rate,
                saleRate: Number(i.sale_rate ?? i.rate) || 0,
                transaction: t
            });


            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: i.code,
                txn_date: receipt_date,
                txn_type: 'IN',
                ref_no: grn_no,
                qty_in: i.qty,
                transaction: t
            });
        }




        // 3️⃣ CREATE SUPPLIER BILL (UNPAID)
        await req.propertyDb.models.supplier_bills.create({
            outlet_id,
            supplier_id,
            bill_no: supplier_bill_no,
            bill_date: receipt_date,
            bill_amount: netAmount,
            paid_amount: 0,
            status: 'UNPAID'
        }, { transaction: t });

        if (po_no && po_no.toString().trim() !== '') {
            for (const item of items) {
                const itemId = Number(item.item_id);

                if (!Number.isFinite(itemId)) continue;

                await req.propertyDb.models.purchase_order_items.update(
                    { line_status: normalizeLineStatus(item.line_status, 'CLOSED') },
                    {
                        where: {
                            po_id: po_no,
                            item_id: itemId,
                            line_status: 'OPEN'
                        },
                        transaction: t
                    }
                );
            }

            const poItems = await req.propertyDb.models.purchase_order_items.findAll({
                where: { po_id: po_no },
                transaction: t
            });

            await req.propertyDb.models.purchase_orders.update(
                { status: deriveHeaderStatus(poItems) },
                {
                    where: {
                        id: po_no,
                        outlet_id
                    },
                    transaction: t
                }
            );
        }
        await audit.log({
            req,
            module: 'RECEIVING',
            action: 'CREATE',
            table: 'goods_receipts',
            recordId: grn.id,
            newData: req.body
        });
        await t.commit();

        res.json({
            success: true,
            message: 'Stock received & supplier bill created'
        });

    } catch (err) {
        console.error("❌ FULL ERROR:", err);

        if (err.errors) {
            console.error("❌ VALIDATION DETAILS:");
            err.errors.forEach(e => {
                console.error("Field:", e.path);
                console.error("Message:", e.message);
                console.error("Value:", e.value);
            });
        }

        await t.rollback();

        if (
            err?.name === 'SequelizeUniqueConstraintError' &&
            err?.table === 'supplier_bills'
        ) {
            return res.status(409).json({
                success: false,
                message: `Supplier bill no ${req.body?.supplier_bill_no || ''} already exists for this vendor`
            });
        }

        res.status(500).json({
            success: false,
            error: err.message,
            details: err.errors || null
        });
    }

};


exports.updateReceivingItem = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const { qty, rate, tax, expiry_date, sale_rate } = req.body;

        const item = await req.propertyDb.models.goods_receipt_items.findByPk(req.params.id);

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const oldQty = item.qty;
        const diffQty = qty - oldQty;

        await item.update({
            qty,
            rate,
            tax,
            amount: qty * rate,
            gst_amount: (qty * rate) * tax / 100,
            tax_amount: (qty * rate) * tax / 100,
            total_after_tax: (qty * rate) + ((qty * rate) * tax / 100),
            expiry_date
        }, { transaction: t });

        await syncItemPricing({
            req,
            itemCode: item.item_code,
            purchaseRate: rate,
            saleRate: sale_rate,
            transaction: t
        });

        // STOCK LEDGER ADJUSTMENT
        if (diffQty !== 0) {
            if (diffQty > 0) {
                // MORE RECEIVED → STOCK IN
                await req.propertyDb.models.stock_ledger.create({
                    outlet_id: item.outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'GRN_UPDATE',
                    ref_no: `GRN-UPD-${item.grn_id}`,
                    qty_in: diffQty,
                    qty_out: 0
                }, { transaction: t });
            } else {
                // LESS RECEIVED → STOCK OUT (REVERSAL)
                await req.propertyDb.models.stock_ledger.create({
                    outlet_id: item.outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'GRN_REVERSE',
                    ref_no: `GRN-UPD-${item.grn_id}`,
                    qty_in: 0,
                    qty_out: Math.abs(diffQty)
                }, { transaction: t });
            }
        }

        await t.commit();

        await audit.log({
            req,
            module: 'RECEIVING',
            action: 'UPDATE_ITEM',
            table: 'goods_receipt_items',
            recordId: item.id,
            oldData: { qty: oldQty },
            newData: { qty }
        });

        res.json({ success: true });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.modifyReceiving = async (req, res) => {

    const t = await req.propertyDb.transaction();

    try {

        const { id } = req.params;
        const { supplier_id, items } = req.body;

        const outlet_id = req.user.outlet_id;

        const grn = await req.propertyDb.models.goods_receipts.findOne({
            where: { id, outlet_id }
        });

        if (!grn) {
            return res.status(404).json({ success: false });
        }

        if (grn.status === 'CANCELLED') {
            return res.status(400).json({
                success: false,
                message: 'GRN cancelled'
            });
        }

        /// UPDATE SUPPLIER
        await grn.update(
            { supplier_id },
            { transaction: t }
        );

        let total = 0;
        let gst = 0;

        for (const i of items) {

            const item = await req.propertyDb.models.goods_receipt_items.findByPk(i.id);

            if (!item) continue;

            const oldQty = item.qty;
            const diffQty = i.qty - oldQty;

            /// UPDATE ITEM
            await item.update({
                qty: i.qty,
                rate: i.rate,
                tax: i.tax,
                amount: i.qty * i.rate,
                gst_amount: (i.qty * i.rate) * i.tax / 100,
                tax_amount: (i.qty * i.rate) * i.tax / 100,
                total_after_tax: (i.qty * i.rate) + ((i.qty * i.rate) * i.tax / 100)
            }, { transaction: t });

            await syncItemPricing({
                req,
                itemCode: item.item_code,
                purchaseRate: i.rate,
                saleRate: Number(i.sale_rate ?? i.rate) || 0,
                transaction: t
            });


            /// LEDGER ADJUSTMENT
            if (diffQty !== 0) {

            if (diffQty > 0) {

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: item.item_code,
                        txn_date: new Date(),
                        txn_type: 'GRN_MODIFY_IN',
                        ref_no: grn.grn_no,
                        qty_in: diffQty,
                        transaction: t
                    });

                } else {

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: item.item_code,
                        txn_date: new Date(),
                        txn_type: 'GRN_MODIFY_OUT',
                        ref_no: grn.grn_no,
                        qty_out: Math.abs(diffQty),
                        transaction: t
                    });

                }

            }

            total += i.qty * i.rate;
            gst += (i.qty * i.rate) * i.tax / 100;

        }

        const netAmount = total + gst;

        /// UPDATE GRN TOTAL
        await grn.update({
            total_amount: total,
            total_gst: gst,
            net_amount: netAmount
        }, { transaction: t });
        const Bill = req.propertyDb.models.supplier_bills;


        const bill = await Bill.findOne({
            where: {
                bill_no: grn.supplier_bill_no,
                supplier_id: supplier_id
            },
            transaction: t
        });

        if (!bill) {
            throw new Error('Supplier bill not found');
        }

        // 2️⃣ Calculate status
        const totalPaid = Number(bill.paid_amount || 0);
        const totalBill = Number(netAmount);

        let status = 'UNPAID';

        if (totalPaid >= totalBill) {
            status = 'PAID';
        } else if (totalPaid > 0) {
            status = 'PARTIAL';
        }
        /// UPDATE SUPPLIER BILL
        await req.propertyDb.models.supplier_bills.update({
            bill_amount: netAmount,
            status: status
        }, {
            where: {
                bill_no: grn.supplier_bill_no,
                supplier_id: supplier_id
            },
            transaction: t
        });


        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'RECEIVING',
            title: 'Receiving Modified',
            message: `GRN #${grn.grn_no} was modified`,
            type: 'WARNING',
            entity_id: 0
        }, { transaction: t });

        await t.commit();

        res.json({
            success: true,
            message: 'Receiving modified successfully'
        });

    } catch (err) {

        await t.rollback();

        res.status(500).json({
            success: false,
            error: err.message
        });

    }

};


exports.getReceivingByDate = async (req, res) => {

    try {

        const outlet_id = req.user.outlet_id;
        const { date } = req.query;

        if (!date) {
            return res.status(400).json({
                success: false,
                message: 'Date required'
            });
        }

        const data = await req.propertyDb.models.goods_receipts.findAll({
            where: {
                outlet_id,
                receipt_date: date,
                status: {
                    [require('sequelize').Op.ne]: 'CANCELLED'
                }
            },
            attributes: [
                'id',
                'grn_no',
                'supplier_id',
                'receipt_date'
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

exports.getReceivingDetails = async (req, res) => {

    try {

        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const grn = await req.propertyDb.models.goods_receipts.findOne({
            where: { id, outlet_id },
            include: [
                {
                    model: req.propertyDb.models.goods_receipt_items,
                    as: 'items'
                }
            ]
        });

        if (!grn) {
            return res.status(404).json({
                success: false,
                message: 'GRN not found'
            });
        }

        res.json({
            success: true,
            data: grn
        });

    } catch (err) {

        res.status(500).json({
            success: false,
            error: err.message
        });

    }

};
exports.deleteReceivingItem = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const item = await req.propertyDb.models.goods_receipt_items.findByPk(req.params.id);

        if (!item) {
            return res.status(404).json({ success: false });
        }

        // REVERSE STOCK
        await req.propertyDb.models.stock_ledger.create({
            outlet_id: item.outlet_id,
            item_code: item.item_code,
            txn_date: new Date(),
            txn_type: 'GRN_DELETE',
            ref_no: `GRN-DEL-${item.grn_id}`,
            qty_in: 0,
            qty_out: item.qty
        }, { transaction: t });

        await item.destroy({ transaction: t });
        await t.commit();

        await audit.log({
            req,
            module: 'RECEIVING',
            action: 'DELETE_ITEM',
            table: 'goods_receipt_items',
            recordId: item.id,
            oldData: item.toJSON()
        });

        res.json({ success: true });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.updateReceiving = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const grn = await req.propertyDb.models.goods_receipts.findByPk(req.params.id);

        if (!grn) {
            return res.status(404).json({ success: false });
        }

        const oldData = grn.toJSON();

        if (req.body.supplier_bill_no !== undefined) {
            const billNo = String(req.body.supplier_bill_no || '').trim();
            if (!billNo || billNo === '0') {
                await t.rollback();
                return res.status(400).json({
                    success: false,
                    message: 'Supplier bill no cannot be 0 or blank'
                });
            }
        }

        await grn.update(req.body, { transaction: t });
        await t.commit();

        await audit.log({
            req,
            module: 'RECEIVING',
            action: 'UPDATE',
            table: 'goods_receipts',
            recordId: grn.id,
            oldData,
            newData: grn.toJSON()
        });

        res.json({ success: true });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.cancelReceiving = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const grn = await req.propertyDb.models.goods_receipts.findByPk(req.params.id, {
            include: [{ model: req.propertyDb.models.goods_receipt_items }]
        });

        if (!grn) {
            return res.status(404).json({ success: false });
        }

        for (const item of grn.goods_receipt_items) {
            await req.propertyDb.models.stock_ledger.create({
                outlet_id: grn.outlet_id,
                item_code: item.item_code,
                txn_date: new Date(),
                txn_type: 'GRN_CANCEL',
                ref_no: grn.grn_no,
                qty_in: 0,
                qty_out: item.qty
            }, { transaction: t });
        }

        await grn.update({ status: 'CANCELLED' }, { transaction: t });
        await t.commit();

        await audit.log({
            req,
            module: 'RECEIVING',
            action: 'CANCEL',
            table: 'goods_receipts',
            recordId: grn.id
        });

        res.json({ success: true, message: 'GRN cancelled successfully' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.listReceiving = async (req, res) => {
    const data = await req.propertyDb.models.goods_receipts.findAll({
        where: { outlet_id: req.outlet_id },
        order: [['created_at', 'DESC']]
    });

    res.json({ success: true, data });
};
exports.getReceiving = async (req, res) => {
    const grn = await req.propertyDb.models.goods_receipts.findByPk(req.params.id, {
        include: [{ model: req.propertyDb.models.goods_receipt_items }]
    });

    if (!grn) return res.status(404).json({ success: false });

    res.json({ success: true, data: grn });
};


exports.getNextGrnNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { date } = req.query;

        if (!date) {
            return res.status(400).json({
                success: false,
                message: 'Date is required'
            });
        }

        // 1️⃣ Load numbering setting
        const setting = await req.propertyDb.models.numbering_settings.findOne({
            where: {
                outlet_id,
                module: 'RECEIVING'
            }
        });

        if (!setting) {
            return res.status(400).json({
                success: false,
                message: 'GRN numbering not configured'
            });
        }

        const docDate = new Date(date);
        const startDate = new Date(setting.start_date);

        if (docDate < startDate) {
            return res.status(400).json({
                success: false,
                message: 'Date is before GRN start date'
            });
        }

        // 2️⃣ Get last GRN for this outlet
        const last = await req.propertyDb.models.goods_receipts.findOne({
            where: { outlet_id },
            order: [['id', 'DESC']]
        });

        let nextNo;

        if (!last) {
            // First GRN
            nextNo = setting.start_no;
        } else {
            // Extract number from GRN (example: GRN-12)
            const regex = new RegExp(`${setting.prefix}(\\d+)`);
            const match = last.grn_no.match(regex);

            if (match && match[1]) {
                nextNo = parseInt(match[1], 10) + 1;
            } else {
                nextNo = setting.start_no;
            }
        }

        const number = `${setting.prefix}${nextNo}${setting.postfix ?? ''}`;

        res.json({
            success: true,
            data: {
                number,
                next_no: nextNo
            }
        });

    } catch (err) {
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};
