const audit = require('../../services/audit.service');

const defaultBranding = {
    company_name: 'Famalth Technologies',
    product_name: 'Famalth Inventory',
    support_email: 'support@famalth.com',
    support_website: 'www.famalth.com',
    support_phone: '+91-00000-00000',
    open_source_notice:
        'Famalth Technologies branding is applied across the product. Third-party packages remain available under their respective open-source licenses.',
    powered_by_label: 'Powered by Famalth Technologies',
    theme_key: 'famalth_classic'
};

exports.getBranding = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const branding = await req.propertyDb.models.app_branding.findOne({
            where: { outlet_id }
        });

        if (!branding) {
            return res.json({
                success: true,
                data: defaultBranding
            });
        }

        res.json({ success: true, data: branding });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveBranding = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const Model = req.propertyDb.models.app_branding;

        const existing = await Model.findOne({
            where: { outlet_id },
            transaction: t
        });

        const oldData = existing ? existing.toJSON() : null;
        const companyName = String(
            req.body.company_name || defaultBranding.company_name
        ).trim() || defaultBranding.company_name;

        const payload = {
            outlet_id,
            company_name: companyName,
            product_name: String(
                req.body.product_name || defaultBranding.product_name
            ).trim() || defaultBranding.product_name,
            support_email: String(
                req.body.support_email || defaultBranding.support_email
            ).trim() || defaultBranding.support_email,
            support_website: String(
                req.body.support_website || defaultBranding.support_website
            ).trim() || defaultBranding.support_website,
            support_phone: String(
                req.body.support_phone || defaultBranding.support_phone
            ).trim() || defaultBranding.support_phone,
            open_source_notice: String(
                req.body.open_source_notice || defaultBranding.open_source_notice
            ).trim() || defaultBranding.open_source_notice,
            powered_by_label: String(req.body.powered_by_label || '').trim() ||
                `Powered by ${companyName}`,
            theme_key: String(
                req.body.theme_key || defaultBranding.theme_key
            ).trim() || defaultBranding.theme_key
        };

        let record;
        if (existing) {
            record = await existing.update(payload, { transaction: t });
        } else {
            record = await Model.create(payload, { transaction: t });
        }

        await audit.log({
            req,
            module: 'APP_BRANDING',
            action: existing ? 'UPDATE' : 'CREATE',
            table: 'app_branding',
            recordId: record.id,
            oldData,
            newData: record.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({
            success: true,
            message: 'Application branding saved successfully',
            data: record
        });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
