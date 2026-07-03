const { encrypt, decrypt } = require('../../utils/crypto.util');
const { testConnection, syncTemplatesFromMeta, submitTemplateToMeta, deleteTemplateFromMeta } = require('../../services/whatsapp.service');

/**
 * Fetch WhatsApp Integration Configuration
 */
async function getConfig(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const config = await req.propertyDb.models.whatsapp_configurations.findOne({
            where: { outlet_id: outletId }
        });

        if (!config) {
            return res.json({ success: true, data: null });
        }

        const rawConfig = config.toJSON();
        // Mask the access token for security
        let maskedToken = '';
        if (rawConfig.encrypted_access_token) {
            const token = decrypt(rawConfig.encrypted_access_token) || '';
            maskedToken = token.length > 10 ? '***' + token.slice(-6) : '***';
        }

        res.json({
            success: true,
            data: {
                waba_id: rawConfig.waba_id,
                phone_number_id: rawConfig.phone_number_id,
                webhook_verify_token: rawConfig.webhook_verify_token,
                app_secret: rawConfig.app_secret,
                token: maskedToken,
                allow_automatic_messages: rawConfig.allow_automatic_messages !== false
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Save / Update WhatsApp Configuration
 */
async function saveConfig(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const { waba_id, phone_number_id, token, webhook_verify_token, app_secret, allow_automatic_messages } = req.body;

        if (!waba_id || !phone_number_id || !webhook_verify_token) {
            return res.status(400).json({ success: false, message: 'WABA ID, Phone Number ID and Webhook Verify Token are required' });
        }

        // Check if config already exists
        const existing = await req.propertyDb.models.whatsapp_configurations.findOne({
            where: { outlet_id: outletId }
        });

        let encryptedToken = '';
        if (token && token.startsWith('***') && existing) {
            // Token is masked and unmodified, retain existing token
            encryptedToken = existing.encrypted_access_token;
        } else if (token) {
            // New token provided, encrypt it
            encryptedToken = encrypt(token);
        } else {
            return res.status(400).json({ success: false, message: 'Access Token is required' });
        }

        const updatedData = {
            outlet_id: outletId,
            waba_id,
            phone_number_id,
            encrypted_access_token: encryptedToken,
            webhook_verify_token,
            app_secret: app_secret || null,
            allow_automatic_messages: allow_automatic_messages === true
        };

        if (existing) {
            await existing.update(updatedData);
        } else {
            await req.propertyDb.models.whatsapp_configurations.create(updatedData);
        }

        res.json({ success: true, message: 'Configuration saved successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Test Connection endpoint
 */
async function testCredentials(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const { waba_id, phone_number_id, token, test_number } = req.body;

        if (!phone_number_id || !test_number) {
            return res.status(400).json({ success: false, message: 'Phone Number ID and test number are required' });
        }

        let activeToken = token;
        if (token && token.startsWith('***')) {
            const config = await req.propertyDb.models.whatsapp_configurations.findOne({
                where: { outlet_id: outletId }
            });
            if (config) {
                activeToken = decrypt(config.encrypted_access_token);
            }
        }

        if (!activeToken) {
            return res.status(400).json({ success: false, message: 'Access Token is missing or invalid' });
        }

        const result = await testConnection(phone_number_id, activeToken, test_number);
        res.json({ success: true, message: 'Test message sent successfully!', data: result });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * List templates saved locally
 */
async function listTemplates(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const templates = await req.propertyDb.models.whatsapp_templates.findAll({
            where: { outlet_id: outletId },
            order: [['updated_at', 'DESC']]
        });
        res.json({ success: true, data: templates });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Sync templates from Meta
 */
async function syncTemplates(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const config = await req.propertyDb.models.whatsapp_configurations.findOne({
            where: { outlet_id: outletId }
        });

        if (!config) {
            return res.status(400).json({ success: false, message: 'Please save your WhatsApp settings first before syncing' });
        }

        const token = decrypt(config.encrypted_access_token);
        const metaTemplates = await syncTemplatesFromMeta(config.waba_id, token);

        const syncedNames = [];

        for (const mt of metaTemplates) {
            let bodyText = '';
            let headerType = 'NONE';
            let headerText = null;
            let footerText = null;
            let buttons = null;

            if (mt.components) {
                for (const comp of mt.components) {
                    if (comp.type === 'BODY') {
                        bodyText = comp.text;
                    } else if (comp.type === 'HEADER') {
                        headerType = comp.format || 'TEXT';
                        headerText = comp.text || null;
                    } else if (comp.type === 'FOOTER') {
                        footerText = comp.text || null;
                    } else if (comp.type === 'BUTTONS') {
                        buttons = comp.buttons || null;
                    }
                }
            }

            // Parse placeholders e.g. {{1}}, {{2}}
            const variableMatches = bodyText.match(/\{\{(\d+)\}\}/g) || [];
            const variables = Array.from(new Set(variableMatches.map(m => m.replace(/[{}]/g, ''))));

            // Check if it already exists locally (keep is_default_invoice_template flag)
            const local = await req.propertyDb.models.whatsapp_templates.findOne({
                where: { outlet_id: outletId, template_name: mt.name, language: mt.language }
            });

            const templateData = {
                outlet_id: outletId,
                template_name: mt.name,
                category: mt.category,
                language: mt.language,
                body_text: bodyText,
                status: mt.status,
                meta_template_id: mt.id,
                header_type: headerType,
                header_text: headerText,
                footer_text: footerText,
                buttons: buttons,
                variables: variables,
                rejection_reason: mt.rejected_reason || null
            };

            if (local) {
                await local.update(templateData);
            } else {
                await req.propertyDb.models.whatsapp_templates.create(templateData);
            }
            syncedNames.push(mt.name);
        }

        res.json({ success: true, message: `Successfully synced ${metaTemplates.length} templates from Meta.`, count: metaTemplates.length });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Submit template creator panel data to Meta
 */
async function createTemplate(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const { template_name, category, language, header_type, header_text, body_text, footer_text, buttons, body_text_examples } = req.body;

        if (!template_name || !category || !language || !body_text) {
            return res.status(400).json({ success: false, message: 'Template Name, Category, Language and Body Text are required' });
        }

        // Validate template name (lowercase, alphanumeric, underscores)
        const nameRegex = /^[a-z0-9_]+$/;
        if (!nameRegex.test(template_name)) {
            return res.status(400).json({ success: false, message: 'Template name must be lowercase, alphanumeric and underscores only' });
        }

        const config = await req.propertyDb.models.whatsapp_configurations.findOne({
            where: { outlet_id: outletId }
        });

        if (!config) {
            return res.status(400).json({ success: false, message: 'WhatsApp settings config is missing' });
        }

        const token = decrypt(config.encrypted_access_token);
        
        // Submit payload to Meta
        const metaResult = await submitTemplateToMeta(config.waba_id, token, {
            template_name,
            category,
            language,
            header_type: header_type || 'NONE',
            header_text,
            body_text,
            footer_text,
            buttons,
            body_text_examples
        });

        // Parse placeholders
        const variableMatches = body_text.match(/\{\{(\d+)\}\}/g) || [];
        const variables = Array.from(new Set(variableMatches.map(m => m.replace(/[{}]/g, ''))));

        // Save locally as PENDING
        const localTemplate = await req.propertyDb.models.whatsapp_templates.create({
            outlet_id: outletId,
            template_name,
            category,
            language,
            body_text,
            status: metaResult.status || 'PENDING',
            meta_template_id: metaResult.id || null,
            header_type: header_type || 'NONE',
            header_text,
            footer_text,
            buttons,
            variables
        });

        res.json({ success: true, message: 'Template submitted for approval successfully!', data: localTemplate });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Toggle template default invoice alert status
 */
async function toggleDefaultInvoiceTemplate(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const { template_id } = req.body;

        const template = await req.propertyDb.models.whatsapp_templates.findOne({
            where: { id: template_id, outlet_id: outletId }
        });

        if (!template) {
            return res.status(404).json({ success: false, message: 'Template not found' });
        }

        if (template.status !== 'APPROVED' || template.category !== 'UTILITY') {
            return res.status(400).json({ success: false, message: 'Only APPROVED UTILITY templates can be selected for invoice checkout alerts' });
        }

        const nextVal = !template.is_default_invoice_template;

        if (nextVal === true) {
            // Set all other utility templates to false for this outlet
            await req.propertyDb.models.whatsapp_templates.update(
                { is_default_invoice_template: false },
                { where: { outlet_id: outletId, category: 'UTILITY' } }
            );
        }

        await template.update({ is_default_invoice_template: nextVal });

        res.json({ success: true, message: nextVal ? 'Template set as default invoice alert successfully' : 'Template deactivated as default invoice alert' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Launch Marketing Campaign
 */
async function launchCampaign(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const { campaign_name, template_id, recipients, scheduled_at } = req.body;

        if (!campaign_name || !template_id || !Array.isArray(recipients) || recipients.length === 0) {
            return res.status(400).json({ success: false, message: 'Campaign name, template selection and recipients are required' });
        }

        let scheduledDate = null;
        if (scheduled_at) {
            scheduledDate = new Date(scheduled_at);
            if (isNaN(scheduledDate.getTime())) {
                return res.status(400).json({ success: false, message: 'Invalid scheduled_at date format' });
            }
        }

        const template = await req.propertyDb.models.whatsapp_templates.findOne({
            where: { id: template_id, outlet_id: outletId }
        });

        if (!template) {
            return res.status(404).json({ success: false, message: 'Template not found' });
        }

        if (template.status !== 'APPROVED') {
            return res.status(400).json({ success: false, message: 'Only approved templates can be used to launch campaigns' });
        }

        // 1. Create campaign record
        const campaign = await req.propertyDb.models.whatsapp_campaigns.create({
            outlet_id: outletId,
            template_id,
            campaign_name,
            total_recipients: recipients.length,
            scheduled_at: scheduledDate
        });

        // 2. Queue logs
        const logEntries = recipients.map(r => {
            const cleanPhone = String(r.phone || '').replace(/[^0-9+]/g, '');
            return {
                outlet_id: outletId,
                campaign_id: campaign.id,
                recipient_phone: cleanPhone,
                message_type: 'MARKETING',
                delivery_status: 'queued',
                retry_count: 0,
                next_retry_time: scheduledDate || new Date(),
                variables_mapped: {
                    template_id,
                    parameters: Array.isArray(r.variables) ? r.variables : []
                }
            };
        });

        await req.propertyDb.models.whatsapp_logs.bulkCreate(logEntries);

        res.json({ success: true, message: scheduledDate ? `Campaign broadcast scheduled for ${scheduledDate.toLocaleString()} successfully!` : `Campaign broadcast scheduled successfully! Processing ${recipients.length} messages in background.`, campaign_id: campaign.id });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Fetch Campaign Lists
 */
async function listCampaigns(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const campaigns = await req.propertyDb.models.whatsapp_campaigns.findAll({
            where: { outlet_id: outletId },
            include: [
                {
                    model: req.propertyDb.models.whatsapp_templates,
                    as: 'template',
                    attributes: ['template_name', 'category', 'language']
                }
            ],
            order: [['created_at', 'DESC']]
        });
        res.json({ success: true, data: campaigns });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Fetch WhatsApp execution telemetry log entries
 */
async function listLogs(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const logs = await req.propertyDb.models.whatsapp_logs.findAll({
            where: { outlet_id: outletId },
            order: [['id', 'DESC']],
            limit: 250 // Limit to avoid page bloating
        });
        res.json({ success: true, data: logs });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Fetch audience list with customer statistics
 */
async function getAudienceList(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const query = `
            SELECT 
                customer_phone,
                MAX(customer_name) AS customer_name,
                MAX(sale_date) AS last_purchase_date,
                SUM(net_amount) AS total_spent
            FROM sales_headers
            WHERE outlet_id = :outletId AND customer_phone IS NOT NULL AND customer_phone <> ''
            GROUP BY customer_phone
            ORDER BY total_spent DESC
        `;
        const results = await req.propertyDb.query(query, {
            replacements: { outletId },
            type: req.propertyDb.QueryTypes.SELECT
        });
        
        res.json({ success: true, data: results });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Fetch monthly estimated bill and ROI calculations
 */
async function getBillingDashboard(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        
        // 1. Get monthly stats (Count, Total Cost)
        const statsQuery = `
            SELECT 
                COUNT(*) AS total_sent,
                SUM(cost) AS total_spent,
                COUNT(CASE WHEN message_type = 'MARKETING' THEN 1 END) AS marketing_count,
                COUNT(CASE WHEN message_type = 'UTILITY' THEN 1 END) AS utility_count
            FROM whatsapp_logs
            WHERE outlet_id = :outletId 
              AND delivery_status IN ('sent', 'delivered', 'read')
              AND created_at >= :startOfMonth
        `;
        const [stats] = await req.propertyDb.query(statsQuery, {
            replacements: { outletId, startOfMonth },
            type: req.propertyDb.QueryTypes.SELECT
        });

        // 2. Query ROI: find customers who received marketing templates in the last 30 days
        // and calculate total net sales from those customer phones within 7 days after the log's created_at timestamp
        const startOf30Days = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        const roiQuery = `
            SELECT 
                COALESCE(SUM(sh.net_amount), 0) AS revenue
            FROM whatsapp_logs wl
            JOIN sales_headers sh ON sh.customer_phone = wl.recipient_phone
            WHERE wl.outlet_id = :outletId
              AND wl.message_type = 'MARKETING'
              AND wl.delivery_status IN ('sent', 'delivered', 'read')
              AND wl.created_at >= :startOf30Days
              AND sh.outlet_id = :outletId
              AND sh.status = 'COMPLETED'
              AND sh.sale_date >= wl.created_at
              AND sh.sale_date <= wl.created_at + INTERVAL '7 days'
        `;
        const [roiResult] = await req.propertyDb.query(roiQuery, {
            replacements: { outletId, startOf30Days },
            type: req.propertyDb.QueryTypes.SELECT
        });

        const totalCost = Number(stats?.total_spent || 0);
        const revenue = Number(roiResult?.revenue || 0);
        const roiPercent = totalCost > 0 ? ((revenue - totalCost) / totalCost) * 100 : 0;

        res.json({
            success: true,
            data: {
                total_spent: totalCost,
                messages_sent: Number(stats?.total_sent || 0),
                marketing_count: Number(stats?.marketing_count || 0),
                utility_count: Number(stats?.utility_count || 0),
                revenue_generated: revenue,
                roi_percent: Number(roiPercent.toFixed(2))
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

/**
 * Delete a template from Meta and local DB
 */
async function deleteTemplate(req, res) {
    try {
        const outletId = req.user.outlet_id;
        const { template_name } = req.body;

        if (!template_name) {
            return res.status(400).json({ success: false, message: 'Template Name is required' });
        }

        const config = await req.propertyDb.models.whatsapp_configurations.findOne({
            where: { outlet_id: outletId }
        });

        if (!config) {
            return res.status(400).json({ success: false, message: 'WhatsApp settings config is missing' });
        }

        const token = decrypt(config.encrypted_access_token);
        
        // 1. Delete from Meta first
        try {
            await deleteTemplateFromMeta(config.waba_id, token, template_name);
        } catch (metaErr) {
            console.warn('[WHATSAPP SERVICE] Failed to delete from Meta (might not exist there):', metaErr.message);
        }

        // 2. Delete locally
        await req.propertyDb.models.whatsapp_templates.destroy({
            where: {
                outlet_id: outletId,
                template_name
            }
        });

        res.json({ success: true, message: 'Template deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
}

module.exports = {
    getConfig,
    saveConfig,
    testCredentials,
    listTemplates,
    syncTemplates,
    createTemplate,
    toggleDefaultInvoiceTemplate,
    launchCampaign,
    listCampaigns,
    listLogs,
    getAudienceList,
    getBillingDashboard,
    deleteTemplate
};
