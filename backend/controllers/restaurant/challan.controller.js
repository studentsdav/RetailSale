const { Op } = require('sequelize');
const { insertLedger } = require('../../services/stockLedger.service');
const audit = require('../../services/audit.service');

exports.listChallans = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const challans = await req.propertyDb.models.delivery_challan_headers.findAll({
            where: { outlet_id },
            order: [['challan_date', 'DESC']]
        });
        res.json({ success: true, data: challans });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getChallanDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const challan = await req.propertyDb.models.delivery_challan_headers.findOne({
            where: { id, outlet_id },
            include: [{ model: req.propertyDb.models.delivery_challan_items, as: 'items' }]
        });

        if (!challan) return res.status(404).json({ success: false, message: 'Challan not found' });
        res.json({ success: true, data: challan });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createChallan = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.user_id || req.user.id;
        const { customer_name, customer_phone, items } = req.body;

        if (!items || items.length === 0) throw new Error('Cannot create Challan without items');

        // Generate Challan Number
        const today = new Date();
        const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
        const count = await req.propertyDb.models.delivery_challan_headers.count({
            where: {
                outlet_id,
                created_at: {
                    [Op.gte]: new Date(today.setHours(0, 0, 0, 0))
                }
            },
            transaction: t
        });
        const seq = String(count + 1).padStart(4, '0');
        const challan_no = `DC-${dateStr}-${seq}`;

        let totalQty = 0;
        const itemsToCreate = [];

        for (const item of items) {
            const itemDef = await req.propertyDb.models.item_master.findOne({
                where: { id: item.item_id, outlet_id },
                transaction: t
            });
            if (!itemDef) throw new Error(`Item ${item.item_name} not found`);

            const qty = Number(item.qty) || 1.00;
            totalQty += qty;

            itemsToCreate.push({
                item_id: item.item_id,
                item_code: itemDef.item_code,
                item_name: itemDef.item_name,
                qty,
                unit: itemDef.unit || 'PCS'
            });
        }

        // Create Header
        const header = await req.propertyDb.models.delivery_challan_headers.create({
            outlet_id,
            challan_no,
            challan_date: new Date(),
            customer_name,
            customer_phone,
            total_qty: totalQty,
            status: 'Issued',
            created_by: user_id
        }, { transaction: t });

        // Save items and write to Stock Ledger
        for (const item of itemsToCreate) {
            await req.propertyDb.models.delivery_challan_items.create({
                challan_id: header.id,
                item_id: item.item_id,
                item_code: item.item_code,
                item_name: item.item_name,
                qty: item.qty,
                unit: item.unit
            }, { transaction: t });

            // Deduct stock instantly
            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: item.item_code,
                txn_date: today,
                txn_type: 'CHALLAN_OUT',
                ref_no: challan_no,
                qty_out: item.qty,
                transaction: t,
                allow_negative: true // Allow negative on dispatch, checks settings inside insertLedger
            });
        }

        await audit.log({
            req,
            module: 'INVENTORY',
            action: 'CHALLAN_CREATE',
            table: 'delivery_challan_headers',
            recordId: header.id,
            description: `Issued Delivery Challan ${challan_no} to ${customer_name}`,
            outlet_id,
            user_id
        });

        await t.commit();
        res.json({ success: true, data: header });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateChallanStatus = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { status } = req.body;

        const challan = await req.propertyDb.models.delivery_challan_headers.findOne({
            where: { id, outlet_id }
        });
        if (!challan) return res.status(404).json({ success: false, message: 'Challan not found' });

        await challan.update({ status });
        res.json({ success: true, data: challan });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};
