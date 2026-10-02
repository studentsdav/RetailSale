import { Request, Response } from 'express';
const audit = require('../../services/audit.service');
const { Op, Sequelize } = require('sequelize');
const { normalizeDateKey } = require('../../utils/dateQuery');
const emailService = require('../../services/email.service');

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

export const createPurchaseOrder = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user.outlet_id;
        const user_id = (req as any).user.id;

        const { po_no, manual_no, supplier_id, po_date, items = [] } = req.body;
        const normalizedItems = items.map((item: any) => ({
            ...item,
            line_status: normalizeLineStatus(item.line_status)
        }));

        let total = 0;
        items.forEach((i: any) => total += (Number(i.qty) || 0) * (Number(i.rate) || 0));

        const po = await (req as any).propertyDb.models.purchase_orders.create({
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
            await (req as any).propertyDb.models.purchase_order_items.create({
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
        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
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

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const getPurchaseOrderReport = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;

        const {
            from_date,
            to_date,
            supplier_id,
            status,
            search
        } = req.query as any;

        const where: any = { outlet_id };

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

        const data = await (req as any).propertyDb.models.purchase_orders.findAll({
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
                    model: (req as any).propertyDb.models.supplier_master,
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

    } catch (err: any) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const getPurchaseOrderDetails = async (req: Request, res: Response) => {
    try {
        const po = await (req as any).propertyDb.models.purchase_orders.findByPk(
            req.params.id,
            {
                include: [
                    {
                        model: (req as any).propertyDb.models.purchase_order_items,
                        as: 'items'
                    }
                ]
            }
        );

        res.json({ success: true, data: po });

    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
};

export const getPoByDate = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const { date } = req.query as any;
        const normalizedDate = normalizeDateKey(date);

        const data = await (req as any).propertyDb.models.purchase_orders.findAll({
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

    } catch (err: any) {
        res.status(500).json({ success: false, message: err.message });
    }
};

export const getPurchaseOrderForPrint = async (req: Request, res: Response) => {
    try {
        const po = await (req as any).propertyDb.models.purchase_orders.findByPk(
            req.params.id,
            {
                include: [
                    {
                        model: (req as any).propertyDb.models.purchase_order_items,
                        as: 'items'
                    },
                    {
                        model: (req as any).propertyDb.models.supplier_master,
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

    } catch (err: any) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const modifyPurchaseOrder = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const po = await (req as any).propertyDb.models.purchase_orders.findByPk(req.params.id);

        if (!po)
            return res.status(404).json({ success: false });

        const { supplier_id, items = [] } = req.body;
        const normalizedItems = items.map((item: any) => ({
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

        await (req as any).propertyDb.models.purchase_order_items.destroy({
            where: { po_id: po.id },
            transaction: t
        });

        for (const i of normalizedItems) {
            const amount = (Number(i.qty) || 0) * (Number(i.rate) || 0);
            const tax = Number(i.tax) || 0;
            const tax_amount = amount * tax / 100;
            await (req as any).propertyDb.models.purchase_order_items.create({
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

        await (req as any).propertyDb.models.system_notifications.create({
            outlet_id: (req as any).user.outlet_id,
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

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const listPurchaseOrders = async (req: Request, res: Response) => {
    try {
        const data = await (req as any).propertyDb.models.purchase_orders.findAll({
            where: {
                outlet_id: (req as any).user.outlet_id,
                status: {
                    [Op.in]: ['OPEN', 'PARTIAL']
                }
            },
            order: [['created_at', 'DESC']]
        });

        res.json({ success: true, data });

    } catch (err: any) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

export const getPurchaseOrder = async (req: Request, res: Response) => {
    const po = await (req as any).propertyDb.models.purchase_orders.findByPk(
        req.params.id,
        {
            include: [
                {
                    model: (req as any).propertyDb.models.purchase_order_items,
                    as: 'items'
                }
            ]
        }
    );

    if (!po) return res.status(404).json({ success: false });

    res.json({ success: true, data: po });
};

export const updatePurchaseOrder = async (req: Request, res: Response) => {
    const po = await (req as any).propertyDb.models.purchase_orders.findByPk(req.params.id);
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

export const closePurchaseOrder = async (req: Request, res: Response) => {
    const po = await (req as any).propertyDb.models.purchase_orders.findByPk(req.params.id);

    if (po) {
        await po.update({ status: 'CLOSED' });
        await (req as any).propertyDb.models.purchase_order_items.update(
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
    }

    res.json({ success: true });
};

export const cancelPurchaseOrder = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const po = await (req as any).propertyDb.models.purchase_orders.findByPk(req.params.id, {
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

        await (req as any).propertyDb.models.purchase_order_items.update(
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
    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, message: err.message });
    }
};

export const sendPoEmail = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { to_email, po_no, vendor_name, total_amount, items, pdf_base64, pdf_filename } = req.body;

        if (!to_email) {
            return res.status(400).json({ success: false, message: 'Recipient email address is required.' });
        }

        let attachments: any[] = [];
        if (pdf_base64) {
            attachments.push({
                filename: pdf_filename || `PO_${po_no || 'Document'}.pdf`,
                content: Buffer.from(pdf_base64, 'base64')
            });
        }

        const formattedItems = (items || []).map((i: any) => `
            <tr>
                <td style="padding: 8px; border: 1px solid #ddd;">${i.item_name || i.itemName || 'Item'}</td>
                <td style="padding: 8px; border: 1px solid #ddd; text-align: center;">${i.qty}</td>
                <td style="padding: 8px; border: 1px solid #ddd; text-align: right;">₹${Number(i.unit_rate || i.rate || 0).toFixed(2)}</td>
                <td style="padding: 8px; border: 1px solid #ddd; text-align: right;">${i.tax || 0}%</td>
                <td style="padding: 8px; border: 1px solid #ddd; text-align: right;">₹${Number(i.total || 0).toFixed(2)}</td>
            </tr>
        `).join('');

        const htmlContent = `
            <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                <h2>Purchase Order: ${po_no || 'Draft'}</h2>
                <p>Dear <strong>${vendor_name || 'Vendor'}</strong>,</p>
                <p>Please find attached the official Purchase Order document <strong>${po_no}</strong> for your review and fulfillment.</p>
                <table style="width: 100%; border-collapse: collapse; margin-top: 15px;">
                    <thead>
                        <tr style="background-color: #f2f2f2;">
                            <th style="padding: 8px; border: 1px solid #ddd; text-align: left;">Item</th>
                            <th style="padding: 8px; border: 1px solid #ddd;">Qty</th>
                            <th style="padding: 8px; border: 1px solid #ddd; text-align: right;">Rate</th>
                            <th style="padding: 8px; border: 1px solid #ddd; text-align: right;">Tax %</th>
                            <th style="padding: 8px; border: 1px solid #ddd; text-align: right;">Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${formattedItems}
                    </tbody>
                </table>
                <h3 style="margin-top: 20px;">Grand Total: ₹${Number(total_amount || 0).toFixed(2)}</h3>
                <p style="margin-top: 30px; font-size: 12px; color: #777;">Sent via Store POS System</p>
            </div>
        `;

        const sent = await emailService.sendMail({
            db: (req as any).propertyDb,
            outlet_id,
            to: to_email,
            subject: `Purchase Order ${po_no || ''} - ${vendor_name || 'Store'}`,
            text: `Purchase Order ${po_no} for ${vendor_name}. Total: ₹${Number(total_amount || 0).toFixed(2)}`,
            html: htmlContent,
            attachments
        });

        if (sent) {
            res.json({ success: true, message: `Purchase Order emailed successfully to ${to_email}!` });
        } else {
            res.status(400).json({ success: false, message: 'SMTP settings not configured or inactive. Please check Email Configuration.' });
        }
    } catch (err: any) {
        console.error('[PO EMAIL ERROR]', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

const purchaseOrderController = {
    createPurchaseOrder,
    getPurchaseOrderReport,
    getPurchaseOrderDetails,
    getPoByDate,
    getPurchaseOrderForPrint,
    modifyPurchaseOrder,
    listPurchaseOrders,
    getPurchaseOrder,
    updatePurchaseOrder,
    closePurchaseOrder,
    cancelPurchaseOrder,
    sendPoEmail
};

module.exports = purchaseOrderController;
export default purchaseOrderController;
