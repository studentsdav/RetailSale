const {
    normalizeCustomerIdentity,
    resolveCustomerKey,
    getOutletConfig,
    getCustomerBalance,
    isConfigActive
} = require('../../services/loyalty.service');

function toAmount(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function toWhole(value, fallback = 0) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(0, Math.floor(parsed));
}

exports.getConfig = async (req, res) => {
    try {
        const row = await req.propertyDb.models.loyalty_master_config.findOne({
            where: { outlet_id: req.user.outlet_id }
        });
        const config = await getOutletConfig(req.propertyDb, req.user.outlet_id);
        const now = new Date();

        res.json({
            success: true,
            data: {
                id: row?.id || null,
                ...config,
                active_now: isConfigActive(config, now),
                current_date: now.toISOString()
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.saveConfig = async (req, res) => {
    const transaction = await req.propertyDb.transaction();
    try {
        const payload = {
            program_status: req.body.program_status === true,
            start_date: req.body.start_date || null,
            end_date: req.body.end_date || null,
            min_purchase_threshold: toAmount(req.body.min_purchase_threshold, 0),
            earning_ratio: toAmount(req.body.earning_ratio, 1000),
            redemption_value: toAmount(req.body.redemption_value, 1),
            max_redeem_per_bill: toWhole(req.body.max_redeem_per_bill, 0),
            point_expiry_days: toWhole(req.body.point_expiry_days, 90),
            updated_by: req.user.id
        };

        if (payload.earning_ratio <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Earning ratio must be greater than 0.'
            });
        }
        if (payload.redemption_value <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Redemption value must be greater than 0.'
            });
        }

        const existing = await req.propertyDb.models.loyalty_master_config.findOne({
            where: { outlet_id: req.user.outlet_id },
            transaction
        });

        let saved;
        if (existing) {
            saved = await existing.update(payload, { transaction });
        } else {
            saved = await req.propertyDb.models.loyalty_master_config.create({
                outlet_id: req.user.outlet_id,
                created_by: req.user.id,
                ...payload
            }, { transaction });
        }

        await transaction.commit();
        res.json({ success: true, data: saved });
    } catch (error) {
        await transaction.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getCustomerSummary = async (req, res) => {
    try {
        const config = await getOutletConfig(req.propertyDb, req.user.outlet_id);
        const identity = normalizeCustomerIdentity(req.query);
        const customerKey = resolveCustomerKey(identity);
        if (!customerKey) {
            return res.json({
                success: true,
                data: {
                    customer_key: null,
                    available_points: 0,
                    redemption_value: config.redemption_value,
                    max_redeem_per_bill: config.max_redeem_per_bill,
                    program_status: config.program_status,
                    active_now: false
                }
            });
        }

        const balance = await getCustomerBalance(
            req.propertyDb,
            req.user.outlet_id,
            identity
        );

        res.json({
            success: true,
            data: {
                customer_key: balance.customer_key,
                available_points: balance.available_points,
                redemption_value: config.redemption_value,
                max_redeem_per_bill: config.max_redeem_per_bill,
                program_status: config.program_status,
                active_now: isConfigActive(config, new Date())
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
