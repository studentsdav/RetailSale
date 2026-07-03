const { Op } = require('sequelize');
const { decrypt } = require('../utils/crypto.util');
const { sendMessage } = require('./whatsapp.service');

const APP_PROTOCOL = process.env.APP_PROTOCOL || 'http';
const APP_HOST = process.env.APP_HOST || 'localhost:3000';

/**
 * Automatically queue an invoice checkout alert (Utility message)
 */
async function queueUtilityInvoiceAlert(db, saleId, outletId, recipientPhone, placeholders) {
    if (!recipientPhone) return;

    // Normalize phone number (Meta requires country code, e.g. clean spaces, dashes)
    const normalizedPhone = recipientPhone.replace(/[^0-9+]/g, '');
    if (normalizedPhone.length < 10) return;

    // 1. Fetch WhatsApp Configuration for this outlet
    const config = await db.models.whatsapp_configurations.findOne({
        where: { outlet_id: outletId }
    });
    if (!config || config.allow_automatic_messages === false) {
        console.log(`[WHATSAPP QUEUE] Automatic alerts are disabled or not configured for outlet: ${outletId}`);
        return; 
    }

    // 2. Fetch the approved UTILITY template marked as default for invoice alerts
    const template = await db.models.whatsapp_templates.findOne({
        where: {
            outlet_id: outletId,
            category: 'UTILITY',
            status: 'APPROVED',
            is_default_invoice_template: true
        }
    });

    if (!template) {
        console.log(`[WHATSAPP QUEUE] No approved default UTILITY template found for outlet: ${outletId}`);
        return;
    }

    // 3. Map parameters. We map placeholders in order:
    // e.g. Customer Name, Invoice No, Total Amount
    const parameters = [
        placeholders.customer_name || 'Customer',
        placeholders.sale_no || 'N/A',
        String(placeholders.net_amount || '0.00')
    ];

    // 4. Create Queue Log Record
    await db.models.whatsapp_logs.create({
        outlet_id: outletId,
        recipient_phone: normalizedPhone,
        message_type: 'UTILITY',
        delivery_status: 'queued',
        retry_count: 0,
        next_retry_time: new Date(),
        variables_mapped: {
            sale_id: saleId,
            sale_no: placeholders.sale_no || 'N/A',
            template_id: template.id,
            parameters
        }
    });

    console.log(`[WHATSAPP QUEUE] Successfully queued utility invoice alert for sale ID: ${saleId}`);
}

/**
 * Background worker execution logic
 */
async function processQueue(db) {
    const now = new Date();

    // 1. Fetch pending utility messages (High priority, max 10 per cycle)
    const utilities = await db.models.whatsapp_logs.findAll({
        where: {
            delivery_status: 'queued',
            message_type: 'UTILITY',
            next_retry_time: { [Op.lte]: now }
        },
        limit: 10,
        order: [['id', 'ASC']]
    });

    // 2. Fetch pending marketing messages (Throttled, max 2 per cycle to safeguard health score)
    const marketings = await db.models.whatsapp_logs.findAll({
        where: {
            delivery_status: 'queued',
            message_type: 'MARKETING',
            next_retry_time: { [Op.lte]: now }
        },
        limit: 2,
        order: [['id', 'ASC']]
    });

    const pendingLogs = [...utilities, ...marketings];
    if (pendingLogs.length === 0) return;

    console.log(`[WHATSAPP WORKER] Processing ${pendingLogs.length} messages (Utilities: ${utilities.length}, Marketings: ${marketings.length})...`);

    // Group configuration lookup to avoid repeated DB hits
    const configCache = {};

    for (const log of pendingLogs) {
        try {
            // Find template details
            let templateId = log.variables_mapped?.template_id;
            let template = null;
            if (templateId) {
                template = await db.models.whatsapp_templates.findByPk(templateId);
            }

            if (!template) {
                // Check if we can search for any default template
                template = await db.models.whatsapp_templates.findOne({
                    where: {
                        outlet_id: log.outlet_id,
                        status: 'APPROVED',
                        category: log.message_type
                    }
                });
            }

            if (!template) {
                throw new Error(`Approved template not found for log ${log.id}`);
            }

            // Get Configuration
            if (!configCache[log.outlet_id]) {
                const config = await db.models.whatsapp_configurations.findOne({
                    where: { outlet_id: log.outlet_id }
                });
                if (config) {
                    configCache[log.outlet_id] = {
                        phone_number_id: config.phone_number_id,
                        token: decrypt(config.encrypted_access_token)
                    };
                }
            }

            const activeConfig = configCache[log.outlet_id];
            if (!activeConfig || !activeConfig.token) {
                throw new Error(`WhatsApp Configuration missing or decrypted token invalid for outlet ${log.outlet_id}`);
            }

            // Construct payload
            const components = [];

            // Header Parameter
            if (template.header_type === 'DOCUMENT' && log.variables_mapped?.sale_id) {
                const saleId = log.variables_mapped.sale_id;
                const saleNo = log.variables_mapped.sale_no || 'Invoice';
                const pdfUrl = `${APP_PROTOCOL}://${APP_HOST}/api/public/sales/${saleId}/pdf`;
                
                components.push({
                    type: 'header',
                    parameters: [
                        {
                            type: 'document',
                            document: {
                                link: pdfUrl,
                                filename: `Invoice_${saleNo.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
                            }
                        }
                    ]
                });
            }

            // Body Parameters
            const parameters = log.variables_mapped?.parameters || [];
            if (parameters.length > 0) {
                components.push({
                    type: 'body',
                    parameters: parameters.map(param => ({
                        type: 'text',
                        text: String(param)
                    }))
                });
            }

            const payload = {
                messaging_product: 'whatsapp',
                to: log.recipient_phone,
                type: 'template',
                template: {
                    name: template.template_name,
                    language: {
                        code: template.language
                    },
                    components
                }
            };

            // Call Meta API
            const result = await sendMessage(activeConfig.phone_number_id, activeConfig.token, payload);
            
            // Calculate pricing cost
            const mktRate = Number(process.env.WHATSAPP_MKT_RATE || 0.86);
            const utlRate = Number(process.env.WHATSAPP_UTL_RATE || 0.12);
            const messageCost = log.message_type === 'MARKETING' ? mktRate : utlRate;

            // Mark as sent
            await log.update({
                delivery_status: 'sent',
                meta_message_id: result.messages?.[0]?.id || null,
                error_message: null,
                cost: messageCost
            });

        } catch (err) {
            console.error(`[WHATSAPP WORKER ERROR] Log ID: ${log.id} failed:`, err.message);

            const nextRetryCount = log.retry_count + 1;
            if (nextRetryCount < 3) {
                // Exponential backoff retry timer
                const delayMs = Math.pow(2, nextRetryCount) * 15 * 1000; // 30s, 60s
                await log.update({
                    retry_count: nextRetryCount,
                    next_retry_time: new Date(Date.now() + delayMs),
                    error_message: err.message
                });
            } else {
                // Exhausted retries
                await log.update({
                    delivery_status: 'failed',
                    retry_count: nextRetryCount,
                    error_message: `Exhausted retries. Final failure: ${err.message}`
                });
            }
        }
    }
}

module.exports = {
    queueUtilityInvoiceAlert,
    processQueue
};
