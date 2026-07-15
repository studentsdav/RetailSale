const audit = require('../../services/audit.service');
const { Op, Sequelize } = require('sequelize');
const { normalizeDateKey } = require('../../utils/dateQuery');

function normalizeLineStatus(value) {
    const status = String(value || 'CLOSED').trim().toUpperCase();
    return ['OPEN', 'CLOSED', 'CANCELLED'].includes(status) ? status : 'CLOSED';
}

function deriveHeaderStatus(items) {
    const statuses = items.map(item => normalizeLineStatus(item.line_status));
    const hasOpen = statuses.includes('OPEN');
    const hasClosed = statuses.includes('CLOSED');
    const allCancelled = statuses.length > 0 && statuses.every(status => status === 'CANCELLED');

    if (allCancelled) return 'CANCELLED';
    if (hasOpen && hasClosed) return 'PARTIAL';
    if (hasOpen) return 'OPEN';
    return 'CLOSED';
}

exports.createPurchaseOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        const { po_no, manual_no, supplier_id, po_date, items } = req.body;
        const normalizedItems = items.map(item => ({
            ...item,
            line_status: normalizeLineStatus(item.line_status)
        }));

        let total = 0;
        items.forEach(i => total += (Number(i.qty) || 0) * (Number(i.rate) || 0));

        const po = await req.propertyDb.models.purchase_orders.create({
            outlet_id,
            po_no,
            manual_no,
            supplier_id,
            po_date,
            total_amount: total,
            status: deriveHeaderStatus(normalizedItems),
            created_by: user_id
        }, { transaction: t });

        for (const i of normalizedItems) {
            const amount = (Number(i.qty) || 0) * (Number(i.rate) || 0);
            const tax = Number(i.tax) || 0;
            const tax_amount = amount * tax / 100;
            await req.propertyDb.models.purchase_order_items.create({
                po_id: po.id,
                item_id: i.item_id,
                item_code: i.item_code,
                item_name: i.item_name,
                brand: i.brand,
                unit: i.unit,
                qty: i.qty,
                rate: i.rate,
                tax,
                tax_amount,
                total_after_tax: amount + tax_amount,
                amount,
                department: i.department,
                line_status: i.line_status
            }, { transaction: t });
        }
        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'PURCHASE',
            title: 'New Purchase Order',
            message: `PO #${po.id} created`,
            type: 'INFO',
            entity_id: po.id
        }, { transaction: t });

        await audit.log({
            req,
            module: 'PURCHASE_ORDER',
            action: 'CREATE',
            table: 'purchase_orders',
            recordId: po.id,
            newData: req.body
        });



        await t.commit();
        res.json({ success: true, message: 'Purchase order created' });



    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getPurchaseOrderReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const {
            from_date,
            to_date,
            supplier_id,
            status,
            search
        } = req.query;

        const where = { outlet_id };


        if (from_date && to_date) {
            where.po_date = {
                [Op.between]: [from_date, to_date]
            };
        }


        if (supplier_id) {
            where.supplier_id = supplier_id;
        }


        if (status) {
            where.status = status;
        }


        if (search) {
            where.po_no = {
                [Op.iLike]: `%${search}%`
            };
        }

        const data = await req.propertyDb.models.purchase_orders.findAll({
            where,
            attributes: [
                'id',
                'po_no',
                'manual_no',
                'supplier_id',
                'po_date',
                'total_amount',
                'status',
                [Sequelize.col('supplier.supplier_name'), 'supplier_name']
            ],
            include: [
                {
                    model: req.propertyDb.models.supplier_master,
                    as: 'supplier',
                    attributes: []
                }
            ],
            order: [['po_date', 'DESC']]
        });

        res.json({
            success: true,
            data
        });

    } catch (err) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};



exports.getPurchaseOrderDetails = async (req, res) => {
    try {

        const po = await req.propertyDb.models.purchase_orders.findByPk(
            req.params.id,
            {
                include: [
                    {
                        model: req.propertyDb.models.purchase_order_items,
                        as: 'items'
                    }
                ]
            }
        );

        res.json({ success: true, data: po });

    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.getPoByDate = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { date } = req.query;
        const normalizedDate = normalizeDateKey(date);

        const data = await req.propertyDb.models.purchase_orders.findAll({
            where: {
                outlet_id,
                po_date: normalizedDate || date,
                status: {
                    [Op.in]: ['OPEN', 'PARTIAL']
                }
            },
            attributes: ['id', 'po_no']
        });

        res.json({ success: true, data });

    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.getPurchaseOrderForPrint = async (req, res) => {
    try {

        const po = await req.propertyDb.models.purchase_orders.findByPk(
            req.params.id,
            {
                include: [
                    {
                        model: req.propertyDb.models.purchase_order_items,
                        as: 'items'
                    },
                    {
                        model: req.propertyDb.models.supplier_master,
                        as: 'supplier'
                    }
                ]
            }
        );

        if (!po)
            return res.status(404).json({ success: false });

        await audit.log({
            req,
            module: 'PURCHASE_ORDER',
            action: 'REPRINT',
            table: 'purchase_orders',
            recordId: po.id
        });

        res.json({
            success: true,
            data: po
        });

    } catch (err) {

        res.status(500).json({
            success: false,
            message: err.message
        });

    }
};
exports.modifyPurchaseOrder = async (req, res) => {

    const t = await req.propertyDb.transaction();

    try {

        const po = await req.propertyDb.models.purchase_orders.findByPk(req.params.id);

        if (!po)
            return res.status(404).json({ success: false });

        const { supplier_id, items } = req.body;
        const normalizedItems = items.map(item => ({
            ...item,
            line_status: normalizeLineStatus(item.line_status)
        }));

        let total = 0;

        for (const i of items) {
            total += (Number(i.qty) || 0) * (Number(i.rate) || 0);
        }

        await po.update({
            supplier_id,
            total_amount: total,
            status: deriveHeaderStatus(normalizedItems)
        }, { transaction: t });

        await req.propertyDb.models.purchase_order_items.destroy({
            where: { po_id: po.id },
            transaction: t
        });

        for (const i of normalizedItems) {
            const amount = (Number(i.qty) || 0) * (Number(i.rate) || 0);
            const tax = Number(i.tax) || 0;
            const tax_amount = amount * tax / 100;
            await req.propertyDb.models.purchase_order_items.create({
                po_id: po.id,
                item_id: i.item_id,
                item_code: i.item_code,
                item_name: i.item_name,
                brand: i.brand,
                unit: i.unit,
                qty: i.qty,
                rate: i.rate,
                tax,
                tax_amount,
                total_after_tax: amount + tax_amount,
                amount,
                department: i.department,
                line_status: i.line_status
            }, { transaction: t });
        }

        await audit.log({
            req,
            module: 'PURCHASE_ORDER',
            action: 'MODIFY',
            table: 'purchase_orders',
            recordId: po.id
        });

        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'PURCHASE',
            title: 'Purchase Order Modified',
            message: `PO #${po.id} was modified`,
            type: 'WARNING',
            entity_id: po.id
        }, { transaction: t });

        await t.commit();

        res.json({
            success: true,
            message: 'Purchase order updated'
        });

    } catch (err) {

        await t.rollback();

        res.status(500).json({
            success: false,
            message: err.message
        });

    }
};


exports.listPurchaseOrders = async (req, res) => {
    try {
        const data = await req.propertyDb.models.purchase_orders.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                status: {
                    [Op.in]: ['OPEN', 'PARTIAL']
                }
            },
            order: [['created_at', 'DESC']]
        });

        res.json({ success: true, data });

    } catch (err) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

exports.getPurchaseOrder = async (req, res) => {
    const po = await req.propertyDb.models.purchase_orders.findByPk(
        req.params.id,
        {
            include: [
                {
                    model: req.propertyDb.models.purchase_order_items,
                    as: 'items'
                }
            ]
        }
    );

    if (!po) return res.status(404).json({ success: false });

    res.json({ success: true, data: po });
};

exports.updatePurchaseOrder = async (req, res) => {
    const po = await req.propertyDb.models.purchase_orders.findByPk(req.params.id);
    if (!po || po.status !== 'OPEN')
        return res.status(400).json({ success: false, message: 'PO locked' });

    await po.update(req.body);

    await audit.log({
        req,
        module: 'PURCHASE_ORDER',
        action: 'UPDATE',
        table: 'purchase_orders',
        recordId: po.id
    });

    res.json({ success: true });
};
exports.closePurchaseOrder = async (req, res) => {
    const po = await req.propertyDb.models.purchase_orders.findByPk(req.params.id);

    await po.update({ status: 'CLOSED' });
    await req.propertyDb.models.purchase_order_items.update(
        { line_status: 'CLOSED' },
        { where: { po_id: po.id, line_status: 'OPEN' } }
    );

    await audit.log({
        req,
        module: 'PURCHASE_ORDER',
        action: 'CLOSE',
        table: 'purchase_orders',
        recordId: po.id
    });

    res.json({ success: true });
};

exports.cancelPurchaseOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const po = await req.propertyDb.models.purchase_orders.findByPk(req.params.id, {
            transaction: t
        });

        if (!po) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'PO not found' });
        }

        if (['CLOSED', 'CANCELLED'].includes(String(po.status || '').toUpperCase())) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Only open or partial purchase orders can be cancelled'
            });
        }

        await req.propertyDb.models.purchase_order_items.update(
            { line_status: 'CANCELLED' },
            { where: { po_id: po.id, line_status: 'OPEN' }, transaction: t }
        );

        await po.update({ status: 'CANCELLED' }, { transaction: t });

        await audit.log({
            req,
            module: 'PURCHASE_ORDER',
            action: 'CANCEL',
            table: 'purchase_orders',
            recordId: po.id
        });

        await t.commit();
        res.json({ success: true, message: 'Purchase order cancelled' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, message: err.message });
    }
};
