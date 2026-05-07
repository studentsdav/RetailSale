const audit = require('../../services/audit.service');

function toWholeNumber(value, fallback = 1) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(1, Math.round(parsed));
}

exports.getSettings = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const settings = await req.propertyDb.models.numbering_settings.findAll({
            where: { outlet_id }
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
        const settings = req.body;
        // expects array [{ module, start_date, start_no, prefix, postfix }]

        const Model = req.propertyDb.models.numbering_settings;

        for (const s of settings) {

            const existing = await Model.findOne({
                where: { outlet_id, module: s.module },
                transaction: t
            });

            const oldData = existing ? existing.toJSON() : null;
            let record;

            const payload = {
                outlet_id,
                module: s.module,
                start_date: s.start_date,
                start_no: toWholeNumber(s.start_no),
                prefix: s.prefix || '',
                postfix: s.postfix || ''
            };

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
    const outlet_id = req.user.outlet_id;
    const { module, date } = req.query;

    const setting = await req.propertyDb.models.numbering_settings.findOne({
        where: { outlet_id, module }
    });

    if (!setting) {
        return res.status(400).json({ success: false, message: 'Numbering not set' });
    }

    const docDate = new Date(date);

    if (docDate < new Date(setting.start_date)) {
        return res.status(400).json({ success: false, message: 'Date before start date' });
    }

    const last = await req.propertyDb.models.purchase_orders.findOne({
        where: { outlet_id },
        order: [['id', 'DESC']]
    });

    let nextNo = toWholeNumber(setting.start_no);

    if (last && last.po_no) {
        // remove prefix & postfix → extract number
        const numericPart = last.po_no
            .replace(setting.prefix, '')
            .replace(setting.postfix ?? '', '');

        const lastNo = parseInt(numericPart, 10);

        if (!isNaN(lastNo)) {
            nextNo = lastNo + 1;
        }
    }

    const number = `${setting.prefix}${nextNo}${setting.postfix ?? ''}`;

    res.json({
        success: true,
        data: {
            number,
            next_no: nextNo
        }
    });
};
