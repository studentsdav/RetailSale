import { Request, Response } from 'express';
const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const numberingHelper = require('./numberingSettingsV2.controller');

function createAuditLog(payload: any) {
    if (audit && typeof audit.log === 'function') {
        return audit.log(payload);
    }
    return Promise.resolve();
}

function ensureAdmin(req: any, action: string) {
    if (req.user.role !== 'ADMIN') {
        const err: any = new Error(`Only admin can ${action} damage entries`);
        err.status = 403;
        throw err;
    }
}

async function getItemCode(req: any, itemId: any, transaction?: any) {
    const item = await req.propertyDb.models.item_master.findOne({
        where: {
            id: itemId,
            outlet_id: req.user.outlet_id
        },
        attributes: ['item_code'],
        transaction
    });

    return item?.item_code || null;
}

export const createDamage = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const { header, items } = req.body;

        let total = 0;

        const damage = await (req as any).propertyDb.models.damage_headers.create({
            damage_no: header.damage_no,
            damage_date: header.damage_date,
            outlet_id: (req as any).user.outlet_id,
            created_by: (req as any).user.id,
            status: 'OPEN',
            approval_status: header.approval_status || 'PENDING'
        }, { transaction: t });

        for (const row of items) {
            const amount = row.qty * row.rate;
            total += amount;

            await (req as any).propertyDb.models.damage_items.create({
                damage_id: damage.id,
                item_id: row.item_id,
                qty: row.qty,
                rate: row.rate,
                remarks: row.remarks,
                amount
            }, { transaction: t });

            await (req as any).propertyDb.models.system_notifications.create({
                outlet_id: (req as any).user.outlet_id,
                module: 'DAMAGE',
                title: 'Damage Item Entry',
                message: `Damage #${damage.id} recorded`,
                type: 'WARNING',
                entity_id: damage.id
            }, { transaction: t });
        }

        await damage.update({ total_value: total }, { transaction: t });

        await createAuditLog({
            req,
            module: 'DAMAGE_CREATE',
            action: 'damage_headers',
            table: 'damage_headers',
            recordId: damage.id,
            newData: {
                ...req.body,
                approval_status: damage.approval_status
            }
        });

        await t.commit();
        res.json({
            success: true,
            damage_id: damage.id,
            approval_status: damage.approval_status
        });
    } catch (e: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: e.message });
    }
};

export const updateDamageItem = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const { qty, rate, remarks } = req.body;
        const item = await (req as any).propertyDb.models.damage_items.findByPk(req.params.id, {
            transaction: t
        });

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const damageHeader = await (req as any).propertyDb.models.damage_headers.findOne({
            where: {
                id: item.damage_id,
                outlet_id: (req as any).user.outlet_id
            },
            transaction: t
        });

        if (!damageHeader) {
            return res.status(404).json({ success: false, message: 'Damage entry not found' });
        }

        const oldQty = item.qty;
        const diffQty = qty - oldQty;

        // ---------------- UPDATE DAMAGE ITEM ----------------
        await item.update(
            {
                qty,
                rate,
                remarks,
                amount: qty * rate
            },
            { transaction: t }
        );

        // ---------------- STOCK LEDGER ADJUSTMENT ----------------
        if (damageHeader.approval_status === 'APPROVED' && diffQty !== 0) {
            const itemCode = await getItemCode(req, item.item_id, t);

            if (!itemCode) {
                throw new Error('Item code not found for damage entry');
            }

            if (diffQty > 0) {
                // MORE DAMAGE → STOCK OUT
                await insertLedger({
                    db: (req as any).propertyDb,
                    outlet_id: (req as any).user.outlet_id,
                    item_code: itemCode,
                    txn_date: new Date(),
                    txn_type: 'DAMAGE_UPDATE',
                    ref_no: damageHeader.damage_no,
                    qty_out: diffQty,
                    transaction: t
                });
            } else {
                // LESS DAMAGE → STOCK IN (REVERSAL)
                await insertLedger({
                    db: (req as any).propertyDb,
                    outlet_id: (req as any).user.outlet_id,
                    item_code: itemCode,
                    txn_date: new Date(),
                    txn_type: 'DAMAGE_REVERSE',
                    ref_no: damageHeader.damage_no,
                    qty_in: Math.abs(diffQty),
                    transaction: t
                });
            }
        }

        await t.commit();

        await createAuditLog({
            req,
            module: 'DAMAGE',
            action: 'UPDATE_ITEM',
            table: 'damage_items',
            recordId: item.id,
            oldData: { qty: oldQty },
            newData: { qty, rate, remarks }
        });

        res.json({ success: true });

    } catch (e: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: e.message });
    }
};

export const getDamage = async (req: Request, res: Response) => {
    const damage = await (req as any).propertyDb.models.damage_headers.findByPk(
        req.params.id,
        {
            include: [
                {
                    model: (req as any).propertyDb.models.damage_items,
                    as: 'items'
                }
            ]
        }
    );

    if (!damage) {
        return res.status(404).json({ success: false });
    }

    res.json({ success: true, data: damage });
};

export const deleteDamageItem = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const item = await (req as any).propertyDb.models.damage_items.findByPk(req.params.id, {
            transaction: t
        });

        if (!item) {
            return res.status(404).json({ success: false });
        }

        const damageHeader = await (req as any).propertyDb.models.damage_headers.findOne({
            where: {
                id: item.damage_id,
                outlet_id: (req as any).user.outlet_id
            },
            transaction: t
        });

        if (!damageHeader) {
            return res.status(404).json({ success: false, message: 'Damage entry not found' });
        }

        if (damageHeader.approval_status === 'APPROVED') {
            const itemCode = await getItemCode(req, item.item_id, t);

            if (!itemCode) {
                throw new Error('Item code not found for damage entry');
            }

            await insertLedger({
                db: (req as any).propertyDb,
                outlet_id: (req as any).user.outlet_id,
                item_code: itemCode,
                txn_date: new Date(),
                txn_type: 'DAMAGE_DELETE',
                ref_no: damageHeader.damage_no,
                qty_in: item.qty,
                transaction: t
            });
        }

        await item.destroy({ transaction: t });

        await t.commit();

        await createAuditLog({
            req,
            module: 'DAMAGE',
            action: 'DELETE_ITEM',
            table: 'damage_items',
            recordId: item.id,
            oldData: item.toJSON()
        });

        res.json({ success: true });

    } catch (e: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: e.message });
    }
};

export const getNextDamageNo = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const date = (req.query.date as string) || new Date().toISOString();
        const data = await numberingHelper.resolveNextNumber({
            req,
            module: 'DAMAGE',
            date,
            outlet_id
        });

        if (!data) {
            return res.status(400).json({
                success: false,
                message: 'Damage numbering not configured'
            });
        }

        res.json({
            success: true,
            data: {
                next_no: data.next_no,
                damage_no: data.number
            }
        });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const approveDamage = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        ensureAdmin(req, 'approve');

        const damage = await (req as any).propertyDb.models.damage_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: (req as any).user.outlet_id
            },
            transaction: t
        });

        if (!damage) {
            return res.status(404).json({
                success: false,
                message: 'Damage entry not found'
            });
        }

        const currentStatus = String(damage.approval_status || 'PENDING').toUpperCase();
        if (currentStatus === 'APPROVED') {
            return res.status(400).json({
                success: false,
                message: 'Damage entry is already approved'
            });
        }

        if (currentStatus === 'REJECTED') {
            return res.status(400).json({
                success: false,
                message: 'Rejected damage entry cannot be approved'
            });
        }

        const damageItems = await (req as any).propertyDb.models.damage_items.findAll({
            where: { damage_id: damage.id },
            transaction: t
        });

        for (const row of damageItems) {
            const itemCode = await getItemCode(req, row.item_id, t);

            if (!itemCode) {
                throw new Error('Item code not found for damage entry');
            }

            await insertLedger({
                db: (req as any).propertyDb,
                outlet_id: (req as any).user.outlet_id,
                item_code: itemCode,
                txn_date: damage.damage_date,
                txn_type: 'DAMAGE',
                ref_no: damage.damage_no,
                qty_out: row.qty,
                transaction: t
            });
        }

        await damage.update({
            approval_status: 'APPROVED',
            approved_by: (req as any).user.id,
            approved_at: new Date(),
            rejected_by: null,
            rejected_at: null,
            rejection_reason: null
        }, { transaction: t });

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
            module: 'DAMAGE',
            title: 'Damage Approved',
            message: `Damage ${damage.damage_no} approved`,
            type: 'SUCCESS',
            entity_id: damage.id
        }, { transaction: t });

        await createAuditLog({
            req,
            module: 'DAMAGE',
            action: 'APPROVE',
            table: 'damage_headers',
            recordId: damage.id,
            newData: { approval_status: 'APPROVED' }
        });

        await t.commit();

        res.json({
            success: true,
            message: 'Damage approved successfully'
        });
    } catch (e: any) {
        await t.rollback();
        res.status(e.status || 500).json({ success: false, error: e.message });
    }
};

export const rejectDamage = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        ensureAdmin(req, 'reject');

        const rejectionReason = String(req.body.rejection_reason || '').trim();
        if (!rejectionReason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }

        const damage = await (req as any).propertyDb.models.damage_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: (req as any).user.outlet_id
            },
            transaction: t
        });

        if (!damage) {
            return res.status(404).json({
                success: false,
                message: 'Damage entry not found'
            });
        }

        const currentStatus = String(damage.approval_status || 'PENDING').toUpperCase();
        if (currentStatus === 'APPROVED') {
            return res.status(400).json({
                success: false,
                message: 'Approved damage entry cannot be rejected'
            });
        }

        if (currentStatus === 'REJECTED') {
            return res.status(400).json({
                success: false,
                message: 'Damage entry is already rejected'
            });
        }

        await damage.update({
            approval_status: 'REJECTED',
            rejected_by: (req as any).user.id,
            rejected_at: new Date(),
            rejection_reason: rejectionReason,
            approved_by: null,
            approved_at: null
        }, { transaction: t });

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
            module: 'DAMAGE',
            title: 'Damage Rejected',
            message: `Damage ${damage.damage_no} rejected`,
            type: 'WARNING',
            entity_id: damage.id
        }, { transaction: t });

        await createAuditLog({
            req,
            module: 'DAMAGE',
            action: 'REJECT',
            table: 'damage_headers',
            recordId: damage.id,
            newData: {
                approval_status: 'REJECTED',
                rejection_reason: rejectionReason
            }
        });

        await t.commit();

        res.json({
            success: true,
            message: 'Damage rejected successfully'
        });
    } catch (e: any) {
        await t.rollback();
        res.status(e.status || 500).json({ success: false, error: e.message });
    }
};

const damageController = {
    createDamage,
    updateDamageItem,
    getDamage,
    deleteDamageItem,
    getNextDamageNo,
    approveDamage,
    rejectDamage
};

module.exports = damageController;
export default damageController;
