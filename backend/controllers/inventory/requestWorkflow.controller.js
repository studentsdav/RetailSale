const audit = require('../../services/audit.service');
const { Op } = require('sequelize');
const numberingHelper = require('./numberingSettingsV2.controller');

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

exports.createRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { department, request_date, open_request_no, items } = req.body;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const normalizedItems = items.map(item => ({
            ...item,
            line_status: normalizeLineStatus(item.line_status)
        }));

        const header = await req.propertyDb.models.request_headers.create({
            request_no: open_request_no,
            department,
            request_date,
            open_request_no,
            status: deriveHeaderStatus(normalizedItems),
            approval_status: 'PENDING',
            outlet_id,
            created_by: user_id
        }, { transaction: t });

        for (const it of normalizedItems) {
            await req.propertyDb.models.request_items.create({
                request_id: header.id,
                item_id: it.item_id,
                item_code: it.code,
                qty: it.qty,
                rate: it.rate,
                line_status: it.line_status
            }, { transaction: t });
        }

        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
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
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getNextRequestNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const date = req.query.date || new Date().toISOString();
        const data = await numberingHelper.resolveNextNumber({
            req,
            module: 'REQUEST',
            date,
            outlet_id
        });

        if (!data) {
            return res.status(400).json({
                success: false,
                message: 'Request numbering not configured'
            });
        }

        res.json({ success: true, data: data.number });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.cancelRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const header = await req.propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });

        if (!header) {
            return res.status(404).json({ success: false });
        }

        if (['CLOSED', 'CANCELLED'].includes(String(header.status || '').toUpperCase())) {
            return res.status(400).json({
                success: false,
                message: 'Only open or partial requests can be cancelled'
            });
        }

        const oldData = header.toJSON();

        await req.propertyDb.models.request_items.update(
            { line_status: 'CANCELLED' },
            { where: { request_id: header.id, line_status: 'OPEN' }, transaction: t }
        );

        await header.update({ status: 'CANCELLED' }, { transaction: t });

        await audit.log({
            req,
            module: 'REQUEST',
            action: 'CANCEL',
            table: 'request_headers',
            recordId: header.id,
            oldData,
            newData: { status: 'CANCELLED' },
            outlet_id,
            user_id
        });

        await t.commit();
        res.json({ success: true, message: 'Request cancelled' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.listRequests = async (req, res) => {
    try {
        const statusFilter = req.query.status;
        const data = await req.propertyDb.models.request_headers.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                approval_status: 'APPROVED',
                status: {
                    [Op.in]: statusFilter ? [statusFilter] : ['OPEN', 'PARTIAL']
                }
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
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.getRequestsByDate = async (req, res) => {
    try {
        const { date } = req.query;
        const outlet_id = req.user.outlet_id;
        const data = await req.propertyDb.models.request_headers.findAll({
            where: {
                outlet_id,
                request_date: date,
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
        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.modifyRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { department, items } = req.body;
        const outlet_id = req.user.outlet_id;
        const normalizedItems = items.map(item => ({
            ...item,
            line_status: normalizeLineStatus(item.line_status)
        }));

        const header = await req.propertyDb.models.request_headers.findOne({
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

        await header.update({
            department,
            status: deriveHeaderStatus(normalizedItems)
        }, { transaction: t });

        const existingItems = await req.propertyDb.models.request_items.findAll({
            where: { request_id: id },
            transaction: t
        });

        const existingIds = existingItems.map(i => i.id);
        const incomingIds = normalizedItems.map(i => i.id).filter(i => i);
        const deleteIds = existingIds.filter(existingId => !incomingIds.includes(existingId));

        if (deleteIds.length > 0) {
            await req.propertyDb.models.request_items.destroy({
                where: { id: deleteIds },
                transaction: t
            });
        }

        for (const item of normalizedItems) {
            if (item.id) {
                await req.propertyDb.models.request_items.update(
                    {
                        qty: item.qty,
                        rate: item.rate,
                        line_status: item.line_status
                    },
                    {
                        where: { id: item.id },
                        transaction: t
                    }
                );
            } else {
                await req.propertyDb.models.request_items.create({
                    request_id: id,
                    item_id: item.item_id,
                    item_code: item.code,
                    qty: item.qty,
                    rate: item.rate,
                    line_status: item.line_status
                }, { transaction: t });
            }
        }

        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'REQUEST',
            title: 'Item Request Modified',
            message: `Request #${id} was modified`,
            type: 'WARNING',
            entity_id: id
        }, { transaction: t });

        await t.commit();
        res.json({ success: true, message: 'Request modified successfully' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.getRequestDetails = async (req, res) => {
    const { id } = req.params;
    const header = await req.propertyDb.models.request_headers.findOne({
        where: {
            id,
            outlet_id: req.user.outlet_id
        },
        include: [{
            model: req.propertyDb.models.request_items,
            as: 'items',
            include: [{
                model: req.propertyDb.models.item_master,
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

exports.approveRequest = async (req, res) => {
    if (req.user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Only admin can approve requests'
        });
    }

    const t = await req.propertyDb.transaction();
    try {
        const header = await req.propertyDb.models.request_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });

        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        await header.update({
            approval_status: 'APPROVED',
            approved_by: req.user.id,
            approved_at: new Date(),
            rejected_by: null,
            rejected_at: null,
            rejection_reason: null
        }, { transaction: t });

        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
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
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.rejectRequest = async (req, res) => {
    if (req.user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Only admin can reject requests'
        });
    }

    const t = await req.propertyDb.transaction();
    try {
        const rejectionReason = String(req.body.rejection_reason || '').trim();

        if (!rejectionReason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }

        const header = await req.propertyDb.models.request_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });

        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        await header.update({
            approval_status: 'REJECTED',
            rejected_by: req.user.id,
            rejected_at: new Date(),
            rejection_reason: rejectionReason,
            approved_by: null,
            approved_at: null
        }, { transaction: t });

        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
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
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
