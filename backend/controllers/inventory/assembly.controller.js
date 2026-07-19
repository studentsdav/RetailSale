const { Op } = require('sequelize');
const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');

async function getStockBalance(db, outlet_id, item_code) {
    const last = await db.models.stock_ledger.findOne({
        where: { outlet_id, item_code },
        order: [['id', 'DESC']]
    });

    if (last && last.balance !== null) {
        return Number(last.balance);
    }

    const item = await db.models.item_master.findOne({
        where: { outlet_id, item_code },
        attributes: ['opening_balance']
    });

    return item?.opening_balance ? Number(item.opening_balance) : 0;
}

exports.getNextAssemblyNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const nowAsm = new Date();
        const todayStr = `${nowAsm.getFullYear()}${String(nowAsm.getMonth() + 1).padStart(2, '0')}${String(nowAsm.getDate()).padStart(2, '0')}`; // YYYYMMDD
        
        const count = await req.propertyDb.models.assembly_headers.count({
            where: {
                outlet_id,
                assembly_date: new Date()
            }
        });

        const seq = String(count + 1).padStart(4, '0');
        const nextNo = `ASM-${todayStr}-${seq}`;

        res.json({
            success: true,
            data: nextNo
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createAssembly = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.user_id || req.user.id;
        const { parent_item_id, qty, notes, assembly_date } = req.body;

        const producedQty = Number(qty);
        if (!parent_item_id || !producedQty || producedQty <= 0) {
            throw new Error('Valid parent item ID and positive quantity are required');
        }

        const asmDate = assembly_date || new Date();

        // 1. Fetch parent item
        const parentItem = await req.propertyDb.models.item_master.findOne({
            where: { id: parent_item_id, outlet_id, is_active: true },
            transaction: t
        });

        if (!parentItem) {
            throw new Error('Finished product item not found');
        }

        // Check if there is already a running assembly for this parent item
        const existingRunning = await req.propertyDb.models.assembly_headers.findOne({
            where: {
                outlet_id,
                parent_item_id,
                status: 'RUNNING'
            },
            transaction: t
        });

        if (existingRunning) {
            throw new Error('Running already, first stop');
        }

        // 2. Fetch BOM
        const bomComponents = await req.propertyDb.models.item_boms.findAll({
            where: { outlet_id, parent_item_id },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'component_item',
                    where: { is_active: true }
                }
            ],
            transaction: t
        });

        if (!bomComponents || bomComponents.length === 0) {
            throw new Error('Please configure a Bill of Materials (BOM) for this item first');
        }

        // 3. Verify stock availability and settings
        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id },
            transaction: t
        });
        const allowNegativeStock = settings?.allow_negative_stock ?? false;

        let compositeCost = 0;
        const componentUsageList = [];

        for (const bomComp of bomComponents) {
            const compItem = bomComp.component_item;
            if (!compItem) continue;

            const qtyRequiredPerUnit = Number(bomComp.quantity);
            const totalQtyNeeded = qtyRequiredPerUnit * producedQty;
            const currentRate = Number(compItem.rate || 0);
            
            // Check current stock of component (disabled as stock is not adjusted on assembly run)
            // const availableStock = await getStockBalance(req.propertyDb, outlet_id, compItem.item_code);
            // if (!allowNegativeStock && availableStock < totalQtyNeeded) {
            //     throw new Error(`Insufficient stock for component "${compItem.item_name}". Needed: ${totalQtyNeeded}, Available: ${availableStock}`);
            // }

            compositeCost += currentRate * qtyRequiredPerUnit;

            componentUsageList.push({
                component_item_id: compItem.id,
                item_code: compItem.item_code,
                item_name: compItem.item_name,
                qty_required: totalQtyNeeded,
                qty_used: totalQtyNeeded,
                rate: currentRate,
                total_cost: totalQtyNeeded * currentRate
            });
        }

        const totalCost = compositeCost * producedQty;

        // 4. Generate Assembly Number
        const nowAsm = new Date();
        const todayStr = `${nowAsm.getFullYear()}${String(nowAsm.getMonth() + 1).padStart(2, '0')}${String(nowAsm.getDate()).padStart(2, '0')}`;
        const count = await req.propertyDb.models.assembly_headers.count({
            where: {
                outlet_id,
                assembly_date: asmDate
            },
            transaction: t
        });
        const seq = String(count + 1).padStart(4, '0');
        const assembly_no = `ASM-${todayStr}-${seq}`;

        // 5. Create Assembly Header
        const header = await req.propertyDb.models.assembly_headers.create({
            outlet_id,
            assembly_no,
            assembly_date: asmDate,
            parent_item_id,
            qty: producedQty,
            composite_cost: Number(compositeCost.toFixed(2)),
            total_cost: Number(totalCost.toFixed(2)),
            notes,
            created_by: user_id,
            status: 'RUNNING'
        }, { transaction: t });

        // 6. Create Assembly Items (No Stock Reversals/Deductions for Components on Assembly Run)
        for (const usage of componentUsageList) {
            await req.propertyDb.models.assembly_items.create({
                outlet_id,
                assembly_id: header.id,
                component_item_id: usage.component_item_id,
                qty_required: usage.qty_required,
                qty_used: usage.qty_used,
                rate: usage.rate,
                total_cost: usage.total_cost
            }, { transaction: t });
        }

        // 8. Log Audit
        await audit.log({
            req,
            module: 'ASSEMBLY',
            action: 'CREATE',
            table: 'assembly_headers',
            recordId: header.id,
            newData: header.toJSON(),
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

exports.listAssemblies = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const data = await req.propertyDb.models.assembly_headers.findAll({
            where: { outlet_id },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'parent_item',
                    attributes: ['item_code', 'item_name', 'brand', 'unit']
                }
            ],
            order: [['created_at', 'DESC']]
        });

        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getAssemblyDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const data = await req.propertyDb.models.assembly_headers.findOne({
            where: { id, outlet_id },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'parent_item',
                    attributes: ['item_code', 'item_name', 'brand', 'unit']
                },
                {
                    model: req.propertyDb.models.assembly_items,
                    as: 'items',
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'component_item',
                            attributes: ['item_code', 'item_name', 'brand', 'unit']
                        }
                    ]
                }
            ]
        });

        if (!data) {
            return res.status(404).json({ success: false, message: 'Assembly transaction not found' });
        }

        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.stopAssembly = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const assembly = await req.propertyDb.models.assembly_headers.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!assembly) {
            throw new Error('Assembly not found');
        }

        if (assembly.status !== 'RUNNING') {
            throw new Error('Assembly is not currently running');
        }

        await assembly.update({ status: 'STOPPED' }, { transaction: t });

        await audit.log({
            req,
            module: 'ASSEMBLY',
            action: 'STOP',
            table: 'assembly_headers',
            recordId: assembly.id,
            newData: { status: 'STOPPED' },
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, message: 'Assembly stopped successfully' });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};
