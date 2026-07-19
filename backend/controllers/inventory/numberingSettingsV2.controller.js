const audit = require('../../services/audit.service');
const { Op } = require('sequelize');

function toWholeNumber(value, fallback = 1) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(1, Math.round(parsed));
}

function normalizeDate(value) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return null;
    return date;
}

function extractNumericPart(value, setting) {
    const raw = String(value || '');
    const prefix = String(setting.prefix || '');
    const postfix = String(setting.postfix || '');
    let middle = raw;

    if (prefix) {
        if (!middle.startsWith(prefix)) return null;
        middle = middle.substring(prefix.length);
    }
    if (postfix) {
        if (!middle.endsWith(postfix)) return null;
        middle = middle.substring(0, middle.length - postfix.length);
    }

    const parsed = parseInt(middle, 10);
    return Number.isNaN(parsed) ? null : parsed;
}

async function getEffectiveSetting({ db, outlet_id, module, date }) {
    const docDate = normalizeDate(date);
    if (!docDate) {
        throw new Error('Invalid date');
    }

    const settings = await db.models.numbering_settings.findAll({
        where: { outlet_id, module },
        order: [['start_date', 'DESC']]
    });

    const effective = settings.find(setting => docDate >= new Date(setting.start_date));
    if (!effective) {
        return null;
    }

    const nextSetting = settings
        .filter(setting => new Date(setting.start_date) > new Date(effective.start_date))
        .sort((a, b) => new Date(a.start_date) - new Date(b.start_date))[0] || null;

    return { effective, nextSetting };
}

async function getExistingNumbersForModule({ req, module, outlet_id }) {
    let Model;
    let numberField;

    switch (module) {
        case 'PO':
            Model = req.propertyDb.models.purchase_orders;
            numberField = 'po_no';
            break;
        case 'RECEIVING':
            Model = req.propertyDb.models.goods_receipts;
            numberField = 'grn_no';
            break;
        case 'INDENT':
            Model = req.propertyDb.models.issue_headers;
            numberField = 'issue_no';
            break;
        case 'REQUEST':
            Model = req.propertyDb.models.request_headers;
            numberField = 'request_no';
            break;
        case 'DAMAGE':
            Model = req.propertyDb.models.damage_headers;
            numberField = 'damage_no';
            break;
        case 'SALES':
            Model = req.propertyDb.models.sales_headers;
            numberField = 'sale_no';
            break;
        default:
            throw new Error(`Unsupported module ${module}`);
    }

    const where = {
        outlet_id
    };

    if (module === 'SALES') {
        where.is_latest = true;
        where.is_deleted = false;
    }

    const rows = await Model.findAll({
        where,
        attributes: [numberField]
    });

    return rows.map(row => row[numberField]).filter(Boolean);
}

async function resolveNextNumber({ req, module, date, outlet_id }) {
    const resolved = await getEffectiveSetting({
        db: req.propertyDb,
        outlet_id,
        module,
        date
    });

    if (!resolved) {
        return null;
    }

    const { effective, nextSetting } = resolved;
    const existingNumbers = await getExistingNumbersForModule({
        req,
        module,
        outlet_id
    });

    let nextNo = toWholeNumber(effective.start_no);
    for (const value of existingNumbers) {
        const numeric = extractNumericPart(value, effective);
        if (numeric !== null) {
            nextNo = Math.max(nextNo, numeric + 1);
        }
    }

    return {
        number: `${effective.prefix || ''}${nextNo}${effective.postfix || ''}`,
        next_no: nextNo
    };
}

exports.getSettings = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const settings = await req.propertyDb.models.numbering_settings.findAll({
            where: { outlet_id },
            order: [['module', 'ASC'], ['start_date', 'DESC']]
        });

        res.json({ success: true, data: settings });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveSettings = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const settings = Array.isArray(req.body) ? req.body : [];
        const Model = req.propertyDb.models.numbering_settings;

        // Enforce mandatory prefix/postfix and global prefix uniqueness.
        const seenIncoming = new Set();
        for (const row of settings) {
            const prefixRaw = String(row?.prefix || '').trim();
            const postfixRaw = String(row?.postfix || '').trim();
            const moduleCode = String(row?.module || '').trim().toUpperCase();

            if (!prefixRaw) {
                throw new Error(`Prefix is required for module ${moduleCode || 'UNKNOWN'}`);
            }
            if (!postfixRaw) {
                throw new Error(`Postfix is required for module ${moduleCode || 'UNKNOWN'}`);
            }

            const normalized = prefixRaw.toUpperCase();
            if (seenIncoming.has(normalized)) {
                throw new Error(`Prefix already used. Try different prefix: ${prefixRaw}`);
            }
            seenIncoming.add(normalized);
        }

        for (const row of settings) {
            const prefixRaw = String(row?.prefix || '').trim();

            const conflictWhere = {
                [Op.and]: [
                    req.propertyDb.where(
                        req.propertyDb.fn('UPPER', req.propertyDb.fn('TRIM', req.propertyDb.col('prefix'))),
                        prefixRaw.toUpperCase()
                    )
                ]
            };
            if (row.id) {
                conflictWhere.id = { [Op.ne]: Number(row.id) || 0 };
            }

            const conflict = await Model.findOne({
                where: conflictWhere,
                transaction: t
            });
            if (conflict) {
                throw new Error(`Prefix already used. Try different prefix: ${prefixRaw}`);
            }
        }

        for (const s of settings) {
            const existing = s.id
                ? await Model.findOne({
                    where: { id: s.id, outlet_id },
                    transaction: t
                })
                : await Model.findOne({
                    where: { outlet_id, module: s.module, start_date: s.start_date },
                    transaction: t
                });

            const oldData = existing ? existing.toJSON() : null;
            const payload = {
                outlet_id,
                module: s.module,
                start_date: s.start_date,
                start_no: toWholeNumber(s.start_no),
                prefix: String(s.prefix || '').trim(),
                postfix: String(s.postfix || '').trim()
            };

            let record;
            if (existing) {
                record = await existing.update(payload, { transaction: t });
            } else {
                record = await Model.create(payload, { transaction: t });
            }

            await audit.log({
                req,
                module: 'NUMBERING_SETTINGS',
                action: existing ? 'UPDATE' : 'CREATE',
                table: 'numbering_settings',
                recordId: record.id,
                oldData,
                newData: record.toJSON(),
                outlet_id: req.user.outlet_id,
                user_id: req.user.id
            });
        }

        await t.commit();
        res.json({ success: true, message: 'Numbering settings saved' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getNextNumber = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { module, date } = req.query;
        const data = await resolveNextNumber({
            req,
            module,
            date,
            outlet_id
        });
        if (!data) {
            return res.status(400).json({
                success: false,
                message: 'Numbering not set for this date'
            });
        }

        res.json({
            success: true,
            data
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getEffectiveSetting = getEffectiveSetting;
exports.extractNumericPart = extractNumericPart;
exports.resolveNextNumber = resolveNextNumber;
