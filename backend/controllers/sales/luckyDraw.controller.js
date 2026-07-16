const { Op } = require('sequelize');

exports.listCampaigns = async (req, res) => {
    try {
        const campaigns = await req.propertyDb.models.lucky_draw_campaigns.findAll({
            include: [{
                model: req.propertyDb.models.draw_vouchers,
                as: 'winner',
                attributes: ['voucher_code', 'customer_name', 'customer_phone', 'sale_id'],
                required: false
            }],
            order: [['created_at', 'DESC']]
        });

        const plainCampaigns = [];
        for (const campaign of campaigns) {
            const plain = campaign.get({ plain: true });
            if (plain.winner) {
                let address = '';
                if (plain.winner.sale_id) {
                    const sale = await req.propertyDb.models.sales_headers.findByPk(plain.winner.sale_id);
                    if (sale) address = sale.customer_address || '';
                }
                if (!address && plain.winner.customer_phone) {
                    const latestSale = await req.propertyDb.models.sales_headers.findOne({
                        where: { customer_phone: plain.winner.customer_phone },
                        order: [['created_at', 'DESC']]
                    });
                    if (latestSale) address = latestSale.customer_address || '';
                }
                plain.winner.customer_address = address;
            }
            plainCampaigns.push(plain);
        }

        res.json({ success: true, data: plainCampaigns });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getActiveCampaign = async (req, res) => {
    try {
        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
            where: {
                status: { [Op.in]: ['ACTIVE', 'PENDING_RESULT', 'PAUSED'] }
            },
            include: [{
                model: req.propertyDb.models.draw_vouchers,
                as: 'winner',
                attributes: ['voucher_code', 'customer_name', 'customer_phone', 'sale_id'],
                required: false
            }]
        });

        if (campaign) {
            const plainCampaign = campaign.get({ plain: true });
            if (plainCampaign.winner) {
                let address = '';
                if (plainCampaign.winner.sale_id) {
                    const sale = await req.propertyDb.models.sales_headers.findByPk(plainCampaign.winner.sale_id);
                    if (sale) address = sale.customer_address || '';
                }
                if (!address && plainCampaign.winner.customer_phone) {
                    const latestSale = await req.propertyDb.models.sales_headers.findOne({
                        where: { customer_phone: plainCampaign.winner.customer_phone },
                        order: [['created_at', 'DESC']]
                    });
                    if (latestSale) address = latestSale.customer_address || '';
                }
                plainCampaign.winner.customer_address = address;
            }
            return res.json({ success: true, data: plainCampaign });
        }

        res.json({ success: true, data: null });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createCampaign = async (req, res) => {
    try {
        const { name, threshold_amount, draw_date, description, allow_creditors } = req.body;

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
            description: description ? description.trim() : null,
            allow_creditors: allow_creditors !== undefined ? Boolean(allow_creditors) : true,
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

        let address = '';
        if (winner.sale_id) {
            const sale = await req.propertyDb.models.sales_headers.findByPk(winner.sale_id, { transaction: t });
            if (sale) address = sale.customer_address || '';
        }
        if (!address) {
            const latestSale = await req.propertyDb.models.sales_headers.findOne({
                where: { customer_phone: winner.customer_phone },
                order: [['created_at', 'DESC']],
                transaction: t
            });
            if (latestSale) address = latestSale.customer_address || '';
        }

        res.json({
            success: true,
            data: {
                voucher_code: winner.voucher_code,
                customer_name: winner.customer_name,
                customer_phone: winner.customer_phone,
                customer_address: address
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
        const { next_campaign_name, next_threshold_amount, next_draw_date, next_description, next_allow_creditors } = req.body;

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
                description: next_description ? next_description.trim() : null,
                allow_creditors: next_allow_creditors !== undefined ? Boolean(next_allow_creditors) : true,
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

exports.getCampaignParticipants = async (req, res) => {
    try {
        const { id } = req.params;

        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findByPk(id);
        if (!campaign) {
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }

        // Fetch all progress records for this campaign
        const progressRecords = await req.propertyDb.models.customer_draw_progress.findAll({
            where: { campaign_id: id },
            order: [['accumulated_spend', 'DESC']]
        });

        const participants = [];
        for (const record of progressRecords) {
            // Find all vouchers for this customer in this campaign
            const vouchers = await req.propertyDb.models.draw_vouchers.findAll({
                where: { campaign_id: id, customer_phone: record.customer_phone }
            });

            // Find the customer's latest address from sales_headers
            const latestSale = await req.propertyDb.models.sales_headers.findOne({
                where: { customer_phone: record.customer_phone },
                attributes: ['customer_address'],
                order: [['created_at', 'DESC']]
            });

            const campaignThreshold = Number(campaign.threshold_amount || 2000.00);
            const accumulated = Number(record.accumulated_spend || 0);
            const voucherCount = vouchers.length;
            const totalPurchase = accumulated + (voucherCount * campaignThreshold);

            participants.push({
                customer_name: record.customer_name || 'Walk-in',
                customer_phone: record.customer_phone,
                accumulated_spend: accumulated,
                voucher_count: voucherCount,
                voucher_codes: vouchers.map(v => v.voucher_code),
                total_purchase: totalPurchase,
                customer_address: latestSale?.customer_address || ''
            });
        }

        res.json({ success: true, data: participants });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getCampaignSalesTrend = async (req, res) => {
    try {
        const { id } = req.params;
        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findByPk(id);
        if (!campaign) {
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }

        const startDate = campaign.start_date;
        const endDate = campaign.status === 'COMPLETED' ? campaign.draw_date : new Date();

        const sequelize = req.propertyDb;
        const sales = await req.propertyDb.models.sales_headers.findAll({
            attributes: [
                [sequelize.fn('DATE', sequelize.col('created_at')), 'date'],
                [sequelize.fn('SUM', sequelize.col('net_amount')), 'total_sales']
            ],
            where: {
                created_at: {
                    [Op.between]: [startDate, endDate]
                },
                status: 'COMPLETED'
            },
            group: [sequelize.fn('DATE', sequelize.col('created_at'))],
            order: [[sequelize.fn('DATE', sequelize.col('created_at')), 'ASC']],
            raw: true
        });

        res.json({ success: true, data: sales });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.pauseCampaign = async (req, res) => {
    try {
        const { id } = req.params;
        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findByPk(id);
        if (!campaign) {
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }
        if (campaign.status !== 'ACTIVE') {
            return res.status(400).json({ success: false, message: 'Only active campaigns can be paused.' });
        }
        await campaign.update({ status: 'PAUSED' });
        res.json({ success: true, message: 'Campaign paused successfully.', data: campaign });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.resumeCampaign = async (req, res) => {
    try {
        const { id } = req.params;
        const campaign = await req.propertyDb.models.lucky_draw_campaigns.findByPk(id);
        if (!campaign) {
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }
        if (campaign.status !== 'PAUSED') {
            return res.status(400).json({ success: false, message: 'Only paused campaigns can be resumed.' });
        }
        await campaign.update({ status: 'ACTIVE' });
        res.json({ success: true, message: 'Campaign resumed successfully.', data: campaign });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.stopCampaign = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { next_campaign_name, next_threshold_amount, next_draw_date, next_description, next_allow_creditors } = req.body;

        const oldCampaign = await req.propertyDb.models.lucky_draw_campaigns.findOne({
            where: { id },
            transaction: t
        });

        if (!oldCampaign) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Campaign not found.' });
        }

        // Mark old as COMPLETED (without winner)
        await oldCampaign.update({ status: 'COMPLETED', winner_voucher_id: null }, { transaction: t });

        let newCampaign = null;
        if (next_campaign_name && next_threshold_amount && next_draw_date) {
            newCampaign = await req.propertyDb.models.lucky_draw_campaigns.create({
                outlet_id: req.user.outlet_id,
                name: next_campaign_name.trim(),
                description: next_description ? next_description.trim() : null,
                allow_creditors: next_allow_creditors !== undefined ? Boolean(next_allow_creditors) : true,
                threshold_amount: Number(next_threshold_amount),
                draw_date: new Date(next_draw_date),
                status: 'ACTIVE'
            }, { transaction: t });
        }

        await t.commit();

        res.json({
            success: true,
            message: 'Campaign stopped successfully without winner.',
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
