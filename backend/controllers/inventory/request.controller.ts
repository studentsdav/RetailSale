import { Request, Response } from 'express';
const audit = require('../../services/audit.service');
const { Op } = require('sequelize');
const { normalizeDateKey } = require('../../utils/dateQuery');

function normalizeLineStatus(value: any) {
    const status = String(value || 'CLOSED').trim().toUpperCase();
    return ['OPEN', 'CLOSED', 'CANCELLED'].includes(status) ? status : 'CLOSED';
}

function deriveHeaderStatus(items: any[]) {
    const statuses = items.map(item => normalizeLineStatus(item.line_status));
    const hasOpen = statuses.includes('OPEN');
    const hasClosed = statuses.includes('CLOSED');
    const allCancelled = statuses.length > 0 && statuses.every(status => status === 'CANCELLED');

    if (allCancelled) return 'CANCELLED';
    if (hasOpen && hasClosed) return 'PARTIAL';
    if (hasOpen) return 'OPEN';
    return 'CLOSED';
}

export const createRequest = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const {
            department,
            request_date,
            open_request_no,
            items = []
        } = req.body;

        const outlet_id = (req as any).user.outlet_id;
        const user_id = (req as any).user.id;

        // 1️⃣ Create header
        const header = await (req as any).propertyDb.models.request_headers.create({
            request_no: open_request_no,
            department,
            request_date,
            open_request_no,
            status: 'OPEN',
            approval_status: 'PENDING',
            outlet_id,
            created_by: user_id
        }, { transaction: t });

        // 2️⃣ Create items
        for (const it of items) {
            await (req as any).propertyDb.models.request_items.create({
                request_id: header.id,
                item_id: it.item_id,
                item_code: it.code,
                qty: it.qty,
                rate: it.rate
            }, { transaction: t });
        }

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
            module: 'REQUEST',
            title: 'New Item Request',
            message: `Request #${header.id} created`,
            type: 'INFO',
            entity_id: header.id
        }, { transaction: t });

        await audit.log({
            req,
            module: 'request_item',
            action: 'CREATE_REQUEST',
            table: 'request_headers',
            recordId: header.id,
            newData: header.toJSON()
        }, { transaction: t });

        await t.commit();
        res.json({ success: true, message: 'Request saved successfully' });

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const getNextRequestNo = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;

        const last = await (req as any).propertyDb.models.request_headers.findOne({
            where: { outlet_id },
            order: [['id', 'DESC']]
        });

        let nextNo = last ? last.id + 1 : 1;

        res.json({
            success: true,
            data: `REQ-${nextNo}`
        });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const updateRequest = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const { id } = req.params;
        const outlet_id = (req as any).user.outlet_id;
        const user_id = (req as any).user.id;

        const header = await (req as any).propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });

        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        const oldData = header.toJSON();

        await header.update(req.body, { transaction: t });

        await (req as any).propertyDb.models.audit_logs.create({
            user_id,
            outlet_id: outlet_id,
            module: 'REQUEST',
            action: 'UPDATE',
            table_name: 'request_headers',
            record_id: header.id,
            old_data: oldData,
            new_data: header.toJSON()
        }, { transaction: t });

        await t.commit();
        res.json({ success: true, message: 'Request updated' });

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const updateRequestItem = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const { id } = req.params;
        const { qty, rate } = req.body;
        const user_id = (req as any).user.id;

        const item = await (req as any).propertyDb.models.request_items.findByPk(id);

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const oldData = item.toJSON();

        await item.update({ qty, rate }, { transaction: t });

        await (req as any).propertyDb.models.audit_logs.create({
            user_id,
            module: 'REQUEST',
            action: 'UPDATE_ITEM',
            table_name: 'request_items',
            record_id: item.id,
            old_data: oldData,
            new_data: item.toJSON()
        }, { transaction: t });

        await t.commit();
        res.json({ success: true });

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const deleteRequestItem = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const { id } = req.params;
        const user_id = (req as any).user.id;

        const item = await (req as any).propertyDb.models.request_items.findByPk(id);

        if (!item) {
            return res.status(404).json({ success: false });
        }

        const oldData = item.toJSON();

        await item.destroy({ transaction: t });

        await (req as any).propertyDb.models.audit_logs.create({
            user_id,
            module: 'REQUEST',
            action: 'DELETE_ITEM',
            table_name: 'request_items',
            record_id: id,
            old_data: oldData
        }, { transaction: t });

        await t.commit();
        res.json({ success: true });

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const cancelRequest = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const { id } = req.params;
        const outlet_id = (req as any).user.outlet_id;
        const user_id = (req as any).user.id;

        const header = await (req as any).propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });

        if (!header) {
            return res.status(404).json({ success: false });
        }

        const oldData = header.toJSON();

        await header.update({ status: 'CANCELLED' }, { transaction: t });

        await (req as any).propertyDb.models.audit_logs.create({
            user_id,
            module: 'REQUEST',
            action: 'CANCEL',
            table_name: 'request_headers',
            record_id: header.id,
            old_data: oldData,
            new_data: { status: 'CANCELLED' }
        }, { transaction: t });

        await t.commit();
        res.json({ success: true, message: 'Request cancelled' });

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const listRequests = async (req: Request, res: Response) => {
    try {
        const statusFilter = req.query.status;

        const data = await (req as any).propertyDb.models.request_headers.findAll({
            where: {
                outlet_id: (req as any).user.outlet_id,
                approval_status: 'APPROVED',
                status: {
                    [Op.in]: statusFilter ? [statusFilter] : ['OPEN', 'PARTIAL']
                },
            },
            attributes: [
                'id',
                'request_no',
                'department',
                'request_date',
                'status',
                'approval_status',
                'approved_at'
            ],
            order: [['request_date', 'DESC'], ['id', 'DESC']]
        });

        res.json({ success: true, data });
    } catch (err: any) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const getRequestsByDate = async (req: Request, res: Response) => {
    try {
        const { date } = req.query as any;
        const outlet_id = (req as any).user.outlet_id;
        const normalizedDate = normalizeDateKey(date);

        const data = await (req as any).propertyDb.models.request_headers.findAll({
            where: {
                outlet_id,
                request_date: normalizedDate || date,
                approval_status: 'APPROVED',
                status: {
                    [Op.in]: ['OPEN', 'PARTIAL']
                }
            },
            attributes: [
                'id',
                'request_no',
                'department',
                'request_date',
                'status',
                'approval_status'
            ],
            order: [['created_at', 'DESC']]
        });

        res.json({
            success: true,
            data
        });

    } catch (err: any) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const modifyRequest = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const { id } = req.params;
        const { department, items = [] } = req.body;
        const outlet_id = (req as any).user.outlet_id;

        const header = await (req as any).propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });

        if (!header) {
            return res.status(404).json({ success: false });
        }

        if (header.status === 'CLOSED') {
            return res.status(400).json({
                success: false,
                message: 'Request closed'
            });
        }

        /// UPDATE DEPARTMENT
        await header.update({ department }, { transaction: t });

        /// GET EXISTING ITEMS
        const existingItems = await (req as any).propertyDb.models.request_items.findAll({
            where: { request_id: id },
            transaction: t
        });

        const existingIds = existingItems.map((i: any) => i.id);
        const incomingIds = items.map((i: any) => i.id).filter((i: any) => i);

        /// DELETE REMOVED ITEMS
        const deleteIds = existingIds.filter((existingId: any) => !incomingIds.includes(existingId));

        if (deleteIds.length > 0) {
            await (req as any).propertyDb.models.request_items.destroy({
                where: {
                    id: deleteIds
                },
                transaction: t
            });
        }

        /// UPDATE EXISTING ITEMS
        for (const item of items) {
            await (req as any).propertyDb.models.request_items.update(
                {
                    qty: item.qty,
                    rate: item.rate
                },
                {
                    where: { id: item.id },
                    transaction: t
                }
            );
        }

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
            module: 'REQUEST',
            title: 'Item Request Modified',
            message: `Request #${id} was modified`,
            type: 'WARNING',
            entity_id: id
        }, { transaction: t });

        await t.commit();

        res.json({
            success: true,
            message: 'Request modified successfully'
        });

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const getRequestDetails = async (req: Request, res: Response) => {
    const { id } = req.params;

    const header = await (req as any).propertyDb.models.request_headers.findOne({
        where: {
            id,
            outlet_id: (req as any).user.outlet_id
        },
        include: [{
            model: (req as any).propertyDb.models.request_items,
            as: 'items',
            include: [{
                model: (req as any).propertyDb.models.item_master,
                as: 'item_master',
                attributes: ['item_name', 'unit']
            }]
        }]
    });

    if (!header) {
        return res.status(404).json({ success: false, message: 'Not found' });
    }

    res.json({ success: true, data: header });
};

export const approveRequest = async (req: Request, res: Response) => {
    if ((req as any).user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Only admin can approve requests'
        });
    }

    const t = await (req as any).propertyDb.transaction();

    try {
        const header = await (req as any).propertyDb.models.request_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: (req as any).user.outlet_id
            },
            transaction: t
        });

        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        await header.update({
            approval_status: 'APPROVED',
            approved_by: (req as any).user.id,
            approved_at: new Date(),
            rejected_by: null,
            rejected_at: null,
            rejection_reason: null
        }, { transaction: t });

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
            module: 'REQUEST',
            title: 'Request Approved',
            message: `Request ${header.request_no} approved`,
            type: 'SUCCESS',
            entity_id: header.id
        }, { transaction: t });

        await audit.log({
            req,
            module: 'request_item',
            action: 'APPROVE_REQUEST',
            table: 'request_headers',
            recordId: header.id,
            newData: { approval_status: 'APPROVED' }
        }, { transaction: t });

        await t.commit();

        res.json({ success: true, message: 'Request approved successfully' });
    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const rejectRequest = async (req: Request, res: Response) => {
    if ((req as any).user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Only admin can reject requests'
        });
    }

    const t = await (req as any).propertyDb.transaction();

    try {
        const rejectionReason = String(req.body.rejection_reason || '').trim();

        if (!rejectionReason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }

        const header = await (req as any).propertyDb.models.request_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: (req as any).user.outlet_id
            },
            transaction: t
        });

        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        await header.update({
            approval_status: 'REJECTED',
            rejected_by: (req as any).user.id,
            rejected_at: new Date(),
            rejection_reason: rejectionReason,
            approved_by: null,
            approved_at: null
        }, { transaction: t });

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
            module: 'REQUEST',
            title: 'Request Rejected',
            message: `Request ${header.request_no} rejected`,
            type: 'WARNING',
            entity_id: header.id
        }, { transaction: t });

        await audit.log({
            req,
            module: 'request_item',
            action: 'REJECT_REQUEST',
            table: 'request_headers',
            recordId: header.id,
            newData: {
                approval_status: 'REJECTED',
                rejection_reason: rejectionReason
            }
        }, { transaction: t });

        await t.commit();

        res.json({ success: true, message: 'Request rejected successfully' });
    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export default {
    createRequest,
    getNextRequestNo,
    updateRequest,
    updateRequestItem,
    deleteRequestItem,
    cancelRequest,
    listRequests,
    getRequestsByDate,
    modifyRequest,
    getRequestDetails,
    approveRequest,
    rejectRequest
};
