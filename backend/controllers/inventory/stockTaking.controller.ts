const { resolveOutletScope } = require('../../utils/outletScopeHelper');
const { Op } = require('sequelize');

exports.getStockTakingItems = async (req: any, res: any) => {
    try {
        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);
        const { department, search } = req.query;

        let whereConditions = ['im.outlet_id IN (:outletIds)', 'im.is_active = TRUE'];
        let replacements: any = { outletIds: scope.outletIds };

        if (department && department.trim() !== '' && department !== 'ALL') {
            whereConditions.push('im.item_group = :department');
            replacements.department = department.trim();
        }

        if (search && search.trim() !== '') {
            whereConditions.push('(im.item_name ILIKE :search OR im.item_code ILIKE :search OR im.barcode ILIKE :search)');
            replacements.search = `%${search.trim()}%`;
        }

        const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

        const [rows] = await req.propertyDb.query(`
            SELECT
                im.id,
                im.item_code,
                im.item_name,
                im.unit,
                im.item_group AS department,
                im.rate,
                im.mrp,
                COALESCE(
                    (COALESCE(im.opening_balance, 0) + COALESCE(SUM(sl.qty_in - sl.qty_out), 0)),
                    0
                ) AS current_balance
            FROM item_master im
            LEFT JOIN stock_ledger sl
                ON sl.item_code = im.item_code
                AND sl.outlet_id = im.outlet_id
            ${whereClause}
            GROUP BY
                im.id,
                im.item_code,
                im.item_name,
                im.unit,
                im.item_group,
                im.rate,
                im.mrp,
                im.opening_balance
            ORDER BY im.item_group, im.item_name ASC
        `, { replacements });

        // Also fetch distinct departments for filter dropdown
        const [departments] = await req.propertyDb.query(`
            SELECT DISTINCT item_group AS department
            FROM item_master
            WHERE outlet_id IN (:outletIds) AND is_active = TRUE AND item_group IS NOT NULL AND item_group != ''
            ORDER BY item_group ASC
        `, { replacements: { outletIds: scope.outletIds } });

        res.json({
            success: true,
            data: rows.map((r: any) => ({
                ...r,
                current_balance: Number(r.current_balance || 0),
                counted_qty: Number(r.current_balance || 0),
                variance: 0,
                reason: 'Physical Stock Count'
            })),
            departments: departments.map((d: any) => d.department)
        });
    } catch (err: any) {
        console.error('Error fetching stock taking items:', err);
        res.status(500).json({ success: false, message: 'Failed to load stock taking items' });
    }
};

exports.saveStockTakingAudit = async (req: any, res: any) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user?.outlet_id || req.body.outlet_id;
        const { audit_date, items, notes, reconcile_ledger = true } = req.body;

        if (!items || !Array.isArray(items) || items.length === 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'No items provided for stock taking audit' });
        }

        const dateStr = audit_date || new Date().toISOString().split('T')[0];
        const randomNum = Math.floor(1000 + Math.random() * 9000);
        const auditNo = `STK-${dateStr.replace(/-/g, '')}-${randomNum}`;
        const userName = req.user?.username || req.user?.name || 'System Admin';

        const auditRecords: any[] = [];
        const stockLedgerEntries: any[] = [];

        for (const item of items) {
            const currentBalance = Number(item.current_balance || 0);
            const countedQty = Number(item.counted_qty ?? item.current_balance ?? 0);
            const variance = Number((countedQty - currentBalance).toFixed(2));
            const reason = item.reason || (variance === 0 ? 'Verified - In Balance' : 'Physical Stock Audit');

            auditRecords.push({
                outlet_id,
                audit_no: auditNo,
                audit_date: dateStr,
                item_code: item.item_code,
                item_name: item.item_name,
                unit: item.unit || 'PCS',
                department: item.department || 'General',
                system_balance: currentBalance,
                counted_qty: countedQty,
                variance: variance,
                reason: reason,
                status: 'COMPLETED',
                reconciled_by: userName
            });

            // If ledger reconciliation is requested and there is variance
            if (reconcile_ledger && variance !== 0) {
                if (variance > 0) {
                    stockLedgerEntries.push({
                        outlet_id,
                        item_code: item.item_code,
                        txn_date: dateStr,
                        txn_type: 'STOCK_AUDIT_SURPLUS',
                        ref_no: auditNo,
                        qty_in: variance,
                        qty_out: 0,
                        balance: 0
                    });
                } else {
                    stockLedgerEntries.push({
                        outlet_id,
                        item_code: item.item_code,
                        txn_date: dateStr,
                        txn_type: 'STOCK_AUDIT_SHORTAGE',
                        ref_no: auditNo,
                        qty_in: 0,
                        qty_out: Math.abs(variance),
                        balance: 0
                    });
                }
            }
        }

        // Bulk insert audit records
        if (req.propertyDb.models.stock_taking) {
            await req.propertyDb.models.stock_taking.bulkCreate(auditRecords, { transaction: t });
        }

        // Bulk insert stock ledger adjustments if any
        if (stockLedgerEntries.length > 0 && req.propertyDb.models.stock_ledger) {
            await req.propertyDb.models.stock_ledger.bulkCreate(stockLedgerEntries, { transaction: t });
        }

        await t.commit();

        res.json({
            success: true,
            message: `Stock taking audit ${auditNo} saved successfully. ${stockLedgerEntries.length} inventory variance adjustments reconciled.`,
            audit_no: auditNo,
            total_items: auditRecords.length,
            variance_items_count: stockLedgerEntries.length
        });
    } catch (err: any) {
        await t.rollback();
        console.error('Error saving stock taking audit:', err);
        res.status(500).json({ success: false, message: 'Failed to save stock taking audit' });
    }
};

exports.getStockTakingReports = async (req: any, res: any) => {
    try {
        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);
        const { start_date, end_date, department, audit_no, variance_only } = req.query;

        let whereConditions = ['outlet_id IN (:outletIds)'];
        let replacements: any = { outletIds: scope.outletIds };

        if (start_date) {
            whereConditions.push('audit_date >= :start_date');
            replacements.start_date = start_date;
        }

        if (end_date) {
            whereConditions.push('audit_date <= :end_date');
            replacements.end_date = end_date;
        }

        if (department && department !== 'ALL') {
            whereConditions.push('department = :department');
            replacements.department = department;
        }

        if (audit_no && audit_no.trim() !== '') {
            whereConditions.push('audit_no ILIKE :audit_no');
            replacements.audit_no = `%${audit_no.trim()}%`;
        }

        if (variance_only === 'true' || variance_only === true) {
            whereConditions.push('variance != 0');
        }

        const whereClause = whereConditions.length > 0 ? `WHERE ${whereConditions.join(' AND ')}` : '';

        const [rows] = await req.propertyDb.query(`
            SELECT
                id,
                outlet_id,
                audit_no,
                audit_date,
                item_code,
                item_name,
                unit,
                department,
                system_balance,
                counted_qty,
                variance,
                reason,
                status,
                reconciled_by,
                created_at
            FROM stock_taking
            ${whereClause}
            ORDER BY audit_date DESC, id DESC
        `, { replacements });

        res.json({
            success: true,
            data: rows
        });
    } catch (err: any) {
        console.error('Error fetching stock taking reports:', err);
        res.status(500).json({ success: false, message: 'Failed to load stock taking report' });
    }
};

module.exports = exports;
export default exports;
