const { Op } = require('sequelize');

function formatDisplayName(item_name, brand, item_code) {
    const rawName = String(item_name || '').trim() || String(item_code || '').trim();
    const rawBrand = String(brand || '').trim();
    if (rawBrand && !rawName.toLowerCase().includes(rawBrand.toLowerCase())) {
        return `${rawName} (${rawBrand})`;
    }
    return rawName;
}

/**
 * Insert a stock ledger entry for a single outlet item.
 * For inserting multiple items in one sale, prefer `batchInsertLedger`
 * which does it in 3 queries total instead of N*3.
 *
 * @param {object}  options
 * @param {object}  options.db               - Sequelize DB instance
 * @param {number}  options.outlet_id
 * @param {string}  options.item_code
 * @param {string}  options.txn_date
 * @param {string}  options.txn_type
 * @param {string}  options.ref_no
 * @param {number}  [options.qty_in=0]
 * @param {number}  [options.qty_out=0]
 * @param {object}  [options.transaction]    - Sequelize transaction
 * @param {boolean} [options.allow_negative=false]
 * @param {object}  [options.cachedSettings] - Pre-fetched system_settings row.
 * @param {string}  [options.item_name]
 * @param {string}  [options.brand]
 * @param {boolean} [options.is_bom_component]
 * @param {string}  [options.parent_item_code]
 * @param {string}  [options.parent_item_name]
 * @param {string}  [options.parent_brand]
 */
exports.insertLedger = async (options) => {
    const {
        db,
        outlet_id,
        item_code,
        txn_date,
        txn_type,
        ref_no,
        qty_in = 0,
        qty_out = 0,
        transaction,
        allow_negative = false,
        cachedSettings = null,
        item_name = null,
        brand = null,
        is_bom_component = false,
        parent_item_code = null,
        parent_item_name = null,
        parent_brand = null
    } = options;

    // 1️⃣ Get last balance
    const last = await db.models.stock_ledger.findOne({
        where: { outlet_id, item_code },
        order: [['id', 'DESC']],
        attributes: ['balance'],
        transaction
    });

    let lastBalance = 0;

    if (last && last.balance !== null) {
        lastBalance = Number(last.balance);
    } else {
        const itemForBalance = await db.models.item_master.findOne({
            where: { outlet_id, item_code },
            attributes: ['opening_balance'],
            transaction
        });
        lastBalance = itemForBalance?.opening_balance
            ? Number(itemForBalance.opening_balance)
            : 0;
    }

    const inQty = Number(qty_in) || 0;
    const outQty = Number(qty_out) || 0;
    const newBalance = lastBalance + inQty - outQty;

    // 2️⃣ Check negative stock rule
    const settings = cachedSettings ?? await db.models.system_settings.findOne({
        where: { outlet_id },
        transaction
    });

    if (!allow_negative && !settings?.allow_negative_stock && newBalance < 0) {
        let nameToDisplay = item_name;
        let brandToDisplay = brand;
        if (!nameToDisplay) {
            const itemForError = await db.models.item_master.findOne({
                where: { outlet_id, item_code },
                attributes: ['item_name', 'brand'],
                transaction
            });
            nameToDisplay = itemForError?.item_name || item_code;
            if (!brandToDisplay) brandToDisplay = itemForError?.brand;
        }

        const formattedName = formatDisplayName(nameToDisplay, brandToDisplay, item_code);
        const isBom = is_bom_component || Boolean(parent_item_name || parent_item_code);
        let msg = '';
        if (isBom) {
            const formattedParentName = formatDisplayName(parent_item_name, parent_brand, parent_item_code);
            const parentStr = parent_item_name 
                ? `"${formattedParentName}"${parent_item_code ? ` (${parent_item_code})` : ''}`
                : `(${parent_item_code || 'unknown'})`;
            msg = `Insufficient stock for BOM Component "${formattedName}" (${item_code}) linked to parent item ${parentStr}. Required: ${outQty}, Available: ${lastBalance}`;
        } else {
            msg = `Insufficient stock for item "${formattedName}" (${item_code}). Required: ${outQty}, Available: ${lastBalance}`;
        }

        throw {
            status: 400,
            message: msg
        };
    }

    // 3️⃣ Insert ledger
    await db.models.stock_ledger.create(
        { outlet_id, item_code, txn_date, txn_type, ref_no, qty_in: inQty, qty_out: outQty, balance: newBalance },
        { transaction }
    );

    // 4️⃣ Low-stock notification
    const itemForNotify = await db.models.item_master.findOne({
        where: { outlet_id, item_code },
        attributes: ['id', 'item_name', 'min_level'],
        transaction
    });
    if (itemForNotify?.min_level && newBalance <= Number(itemForNotify.min_level)) {
        await db.models.system_notifications.create({
            outlet_id,
            module: 'STOCK',
            title: 'Low Stock Alert',
            message: `${itemForNotify.item_name} stock is low (${newBalance})`,
            type: 'WARNING',
            entity_id: itemForNotify.id
        }, { transaction });
    }
};

/**
 * ⚡ Batch-insert stock ledger entries for multiple items in a single sale.
 *
 * @param {object}  options
 * @param {object}  options.db
 * @param {number}  options.outlet_id
 * @param {string}  options.txn_date
 * @param {string}  options.txn_type
 * @param {string}  options.ref_no
 * @param {object}  [options.transaction]
 * @param {object}  [options.cachedSettings] - Pre-fetched system_settings row.
 * @param {Array}   options.lines            - Array of { item_code, item_name?, brand?, qty_in?, qty_out?, is_bom_component?, parent_item_code?, parent_item_name?, parent_brand? }
 */
exports.batchInsertLedger = async ({
    db,
    outlet_id,
    txn_date,
    txn_type,
    ref_no,
    transaction,
    cachedSettings = null,
    lines = []
}) => {
    if (lines.length === 0) return;

    const itemCodes = [...new Set(lines.map(l => l.item_code))];

    // ── Step 1: Get last balance & item_name + brand for each item_code ──
    const recentRows = await db.models.stock_ledger.findAll({
        where: { outlet_id, item_code: { [Op.in]: itemCodes } },
        order: [['id', 'DESC']],
        attributes: ['item_code', 'balance', 'id'],
        transaction
    });

    const lastBalanceMap = new Map();
    for (const row of recentRows) {
        if (!lastBalanceMap.has(row.item_code)) {
            lastBalanceMap.set(row.item_code, Number(row.balance));
        }
    }

    const itemMasterMap = new Map();
    const allItemMasters = await db.models.item_master.findAll({
        where: { outlet_id, item_code: { [Op.in]: itemCodes } },
        attributes: ['item_code', 'item_name', 'brand', 'opening_balance'],
        transaction
    });
    for (const im of allItemMasters) {
        itemMasterMap.set(im.item_code, im);
        if (!lastBalanceMap.has(im.item_code)) {
            lastBalanceMap.set(im.item_code, im.opening_balance ? Number(im.opening_balance) : 0);
        }
    }

    // Any code still missing: default 0
    for (const code of itemCodes) {
        if (!lastBalanceMap.has(code)) lastBalanceMap.set(code, 0);
    }

    // ── Step 2: Calculate new balances & check negative stock ────────────
    const settings = cachedSettings ?? await db.models.system_settings.findOne({
        where: { outlet_id },
        transaction
    });

    const ledgerRows = [];
    const newBalanceMap = new Map();

    // Process lines preserving order so multi-line same item accumulates correctly
    for (const line of lines) {
        const {
            item_code,
            qty_in = 0,
            qty_out = 0,
            allow_negative = false,
            item_name = null,
            brand = null,
            is_bom_component = false,
            parent_item_code = null,
            parent_item_name = null,
            parent_brand = null
        } = line;
        const inQty = Number(qty_in) || 0;
        const outQty = Number(qty_out) || 0;
        const lastBalance = newBalanceMap.has(item_code)
            ? newBalanceMap.get(item_code)
            : (lastBalanceMap.get(item_code) ?? 0);
        const newBalance = lastBalance + inQty - outQty;

        if (!allow_negative && !settings?.allow_negative_stock && newBalance < 0) {
            const dbItem = itemMasterMap.get(item_code);
            const nameToDisplay = item_name || dbItem?.item_name || item_code;
            const brandToDisplay = brand || dbItem?.brand;
            const formattedName = formatDisplayName(nameToDisplay, brandToDisplay, item_code);

            const isBom = is_bom_component || Boolean(parent_item_name || parent_item_code);
            let msg = '';
            if (isBom) {
                const formattedParentName = formatDisplayName(parent_item_name, parent_brand, parent_item_code);
                const parentStr = parent_item_name 
                    ? `"${formattedParentName}"${parent_item_code ? ` (${parent_item_code})` : ''}`
                    : `(${parent_item_code || 'unknown'})`;
                msg = `Insufficient stock for BOM Component "${formattedName}" (${item_code}) linked to parent item ${parentStr}. Required: ${outQty}, Available: ${lastBalance}`;
            } else {
                msg = `Insufficient stock for item "${formattedName}" (${item_code}). Required: ${outQty}, Available: ${lastBalance}`;
            }
            throw {
                status: 400,
                message: msg
            };
        }

        newBalanceMap.set(item_code, newBalance);
        ledgerRows.push({ outlet_id, item_code, txn_date, txn_type, ref_no, qty_in: inQty, qty_out: outQty, balance: newBalance });
    }

    // ── Step 3: Bulk insert all ledger rows ──────────────────────────────
    await db.models.stock_ledger.bulkCreate(ledgerRows, { transaction });

    // ── Step 4: Low-stock notifications (single findAll) ─────────────────
    const itemDetails = await db.models.item_master.findAll({
        where: { outlet_id, item_code: { [Op.in]: itemCodes } },
        attributes: ['id', 'item_code', 'item_name', 'min_level'],
        transaction
    });

    const notifyRows = [];
    for (const item of itemDetails) {
        const balance = newBalanceMap.get(item.item_code);
        if (item.min_level && balance != null && balance <= Number(item.min_level)) {
            notifyRows.push({
                outlet_id,
                module: 'STOCK',
                title: 'Low Stock Alert',
                message: `${item.item_name} stock is low (${balance})`,
                type: 'WARNING',
                entity_id: item.id
            });
        }
    }
    if (notifyRows.length > 0) {
        await db.models.system_notifications.bulkCreate(notifyRows, { transaction });
    }
};
