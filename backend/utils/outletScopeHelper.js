const { Op } = require('sequelize');

/**
 * Resolves outlet scoping for database queries.
 * - Single outlet (e.g. '1'): strictly restricts query to outlet_id = 1.
 * - 'ALL': strictly restricts query to only the current session outlet and its linked cluster (outlet_id IN (linkedIds)).
 * - null/undefined/'null': defaults strictly to the current session outlet (outlet_id = sessionOutletId).
 */
async function getLinkedOutletIds(req, sessionOutletId) {
    if (!sessionOutletId) return [];

    try {
        const models = req.propertyDb?.models;
        if (!models || !models.outlets) return [sessionOutletId];

        const rawOutlets = await models.outlets.findAll({
            attributes: ['id', 'parent_outlet_id', 'is_master', 'outlet_role'],
            where: { is_active: true },
            bypassOutletFilter: true,
            raw: true
        });

        const currentOutlet = rawOutlets.find(o => Number(o.id) === Number(sessionOutletId));
        if (!currentOutlet) return [Number(sessionOutletId)];

        const linkedSet = new Set();
        linkedSet.add(Number(sessionOutletId));

        const isCurrentMaster = Boolean(currentOutlet.is_master) || String(currentOutlet.is_master) === '1' || currentOutlet.outlet_role === 'MASTER';

        if (isCurrentMaster) {
            rawOutlets.forEach(o => {
                const oid = Number(o.id);
                const pid = o.parent_outlet_id ? Number(o.parent_outlet_id) : null;
                if (pid === Number(sessionOutletId)) {
                    linkedSet.add(oid);
                }
            });
        }

        return Array.from(linkedSet);
    } catch (err) {
        console.error('Error resolving linked outlet IDs:', err.message);
        return [sessionOutletId];
    }
}

/**
 * Resolves outlet scoping for database queries.
 * - queryOutletId: 'ALL', 'all', '-1', -1 -> returns scope for ALL linked outlets (e.g. outlet_id IN [1, 2]).
 * - queryOutletId: specific ID (e.g. '1', 1) -> if linked/permitted, returns outlet_id = 1.
 * - queryOutletId: null/undefined/'null'/'undefined'/0/'0' -> defaults strictly to current login outlet (outlet_id = sessionOutletId).
 */
async function resolveOutletScope(req, queryOutletId) {
    const sessionOutletId = Number(req.outlet?.id || req.user?.outlet_id || 0);

    const isAll = (
        queryOutletId === 'ALL' ||
        queryOutletId === 'all' ||
        queryOutletId === '-1' ||
        queryOutletId === -1 ||
        queryOutletId === 'true'
    );

    const linkedIds = await getLinkedOutletIds(req, sessionOutletId);

    if (isAll) {
        const outletIds = linkedIds.length > 0 ? linkedIds : (sessionOutletId ? [sessionOutletId] : []);
        const outlet_id = outletIds.length === 1 ? outletIds[0] : (outletIds.length > 1 ? { [Op.in]: outletIds } : sessionOutletId);
        return {
            isAll: true,
            targetOutletId: null,
            outlet_id,
            outletWhere: { outlet_id },
            outletIds
        };
    }

    const hasSpecific = (
        queryOutletId !== undefined &&
        queryOutletId !== null &&
        queryOutletId !== '' &&
        queryOutletId !== 'null' &&
        queryOutletId !== 'undefined' &&
        queryOutletId !== '0' &&
        queryOutletId !== 0
    );

    let targetId = sessionOutletId;
    if (hasSpecific) {
        const parsed = Number(queryOutletId);
        if (!isNaN(parsed) && parsed > 0) {
            targetId = parsed;
        }
    }

    return {
        isAll: false,
        targetOutletId: targetId,
        outlet_id: targetId,
        outletWhere: { outlet_id: targetId },
        outletIds: [targetId]
    };
}

module.exports = {
    resolveOutletScope,
    getLinkedOutletIds
};
