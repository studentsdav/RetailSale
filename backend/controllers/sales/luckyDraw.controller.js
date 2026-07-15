const { Op } = require('sequelize');

exports.listCampaigns = async (req, res) => {
    try {
        const campaigns = await req.propertyDb.models.lucky_draw_campaigns.findAll({
            include: [{
                model: req.propertyDb.models.draw_vouchers,
                as: 'winner',
                attributes: ['voucher_code', 'customer_name', 'customer_phone'],
                required: false
            }],
            order: [['created_at', 'DESC']]
        });
        res.json({ success: true, data: campaigns });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getActiveCampaign = async (req, res) => {
    try {
        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
            where: {
                status: { [Op.in]: ['ACTIVE', 'PENDING_RESULT'] }
            },
            include: [{
                model: req.propertyDb.models.draw_vouchers,
                as: 'winner',
                attributes: ['voucher_code', 'customer_name', 'customer_phone'],
                required: false
            }]
        });
        res.json({ success: true, data: campaign });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createCampaign = async (req, res) => {
    try {
        const { name, threshold_amount, draw_date } = req.body;

        if (!name || !threshold_amount || !draw_date) {
            return res.status(400).json({ success: false, message: 'Name, threshold amount, and draw date are required.' });
        }

        // Check for existing active/pending campaigns
        const existing = await req.propertyDb.models.lucky_draw_campaigns.findOne({
            where: {
                status: { [Op.in]: ['ACTIVE', 'PENDING_RESULT'] }
            }
        });

        if (existing) {
            return res.status(400).json({
                success: false,
                message: `There is already an ongoing campaign: "${existing.name}". Please complete it first.`
            });
        }

        const campaign = await req.propertyDb.models.lucky_draw_campaigns.create({
            outlet_id: req.user.outlet_id,
            name: name.trim(),
            threshold_amount: Number(threshold_amount),
            draw_date: new Date(draw_date),
            status: 'ACTIVE'
        });

        res.json({ success: true, data: campaign });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getDrawStats = async (req, res) => {
    try {
        const { id } = req.params;

        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findByPk(id);
        if (!campaign) {
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }

        // 1. Total Tickets
        const totalTickets = await req.propertyDb.models.draw_vouchers.count({
            where: { campaign_id: id }
        });

        // 2. Participating Customers (Distinct phones)
        const participatingCustomers = await req.propertyDb.models.draw_vouchers.count({
            distinct: true,
            col: 'customer_phone',
            where: { campaign_id: id }
        });

        // 3. Total Revenue Driven (sum of net_amount of associated sales)
        const vouchers = await req.propertyDb.models.draw_vouchers.findAll({
            where: { campaign_id: id, sale_id: { [Op.ne]: null } },
            attributes: ['sale_id'],
            raw: true
        });

        const saleIds = [...new Set(vouchers.map(v => v.sale_id))];
        let totalRevenue = 0;
        if (saleIds.length > 0) {
            totalRevenue = await req.propertyDb.models.sales_headers.sum('net_amount', {
                where: { id: { [Op.in]: saleIds } }
            }) || 0;
        }

        res.json({
            success: true,
            data: {
                campaign_id: campaign.id,
                name: campaign.name,
                status: campaign.status,
                threshold_amount: campaign.threshold_amount,
                draw_date: campaign.draw_date,
                total_tickets: totalTickets,
                participating_customers: participatingCustomers,
                total_revenue: Number(totalRevenue)
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.drawWinner = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;

        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
            where: { id },
            transaction: t
        });

        if (!campaign) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }

        if (campaign.status === 'COMPLETED') {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Campaign is already completed.' });
        }

        // Pick a random voucher code from draw_vouchers for this campaign
        const winner = await req.propertyDb.models.draw_vouchers.findOne({
            where: { campaign_id: id },
            order: req.propertyDb.random(),
            transaction: t
        });

        if (!winner) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'No tickets generated in this campaign. Cannot pick a winner.' });
        }

        // Reset previous winners of this campaign if any (just in case they redraw)
        await req.propertyDb.models.draw_vouchers.update(
            { is_winner: false },
            { where: { campaign_id: id, is_winner: true }, transaction: t }
        );

        // Mark this voucher as winner
        await winner.update({ is_winner: true }, { transaction: t });

        // Update campaign status to PENDING_RESULT and winner_voucher_id
        await campaign.update({
            status: 'PENDING_RESULT',
            winner_voucher_id: winner.id
        }, { transaction: t });

        await t.commit();

        res.json({
            success: true,
            data: {
                voucher_code: winner.voucher_code,
                customer_name: winner.customer_name,
                customer_phone: winner.customer_phone
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.completeCampaign = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { next_campaign_name, next_threshold_amount, next_draw_date } = req.body;

        const oldCampaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
            where: { id },
            transaction: t
        });

        if (!oldCampaign) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }

        // Mark old as COMPLETED
        await oldCampaign.update({ status: 'COMPLETED' }, { transaction: t });

        let newCampaign = null;
        if (next_campaign_name && next_threshold_amount && next_draw_date) {
            // Create next ACTIVE campaign automatically
            newCampaign = await req.propertyDb.models.lucky_draw_campaigns.create({
                outlet_id: req.user.outlet_id,
                name: next_campaign_name.trim(),
                threshold_amount: Number(next_threshold_amount),
                draw_date: new Date(next_draw_date),
                status: 'ACTIVE'
            }, { transaction: t });
        }

        await t.commit();

        res.json({
            success: true,
            message: 'Campaign completed successfully.',
            data: {
                old_campaign: oldCampaign,
                new_campaign: newCampaign
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};
