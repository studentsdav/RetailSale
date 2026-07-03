const crypto = require('crypto');

/**
 * GET Webhook Verification Handshake
 */
async function verifyWebhook(req, res) {
    try {
        const mode = req.query['hub.mode'];
        const token = req.query['hub.verify_token'];
        const challenge = req.query['hub.challenge'];

        if (mode && token) {
            if (mode === 'subscribe') {
                // Query public DB config (bypassing tenant filter because no auth context exists yet)
                const config = await req.propertyDb.models.whatsapp_configurations.findOne({
                    where: { webhook_verify_token: token },
                    bypassOutletFilter: true
                });

                if (config) {
                    console.log('🛡️ [WHATSAPP WEBHOOK] Webhook verified successfully!');
                    return res.status(200).send(challenge);
                }
            }
        }
        console.warn('🛡️ [WHATSAPP WEBHOOK] Webhook verification failed: verify token mismatch');
        return res.status(403).send('Forbidden');
    } catch (err) {
        console.error('🛡️ [WHATSAPP WEBHOOK] Error during GET verification:', err.message);
        return res.status(500).send('Internal Server Error');
    }
}

/**
 * POST Webhook Event Receiver (Signature Verified)
 */
async function receiveWebhook(req, res) {
    try {
        const body = req.body;
        const entry = body?.entry?.[0];
        if (!entry) {
            return res.status(200).send('No entries');
        }

        const wabaId = entry.id;
        
        // Find configuration mapping to identify the tenant and retrieve the app_secret
        const config = await req.propertyDb.models.whatsapp_configurations.findOne({
            where: { waba_id: wabaId },
            bypassOutletFilter: true
        });

        if (!config) {
            console.warn(`🛡️ [WHATSAPP WEBHOOK] Event received for unknown WABA ID: ${wabaId}`);
            return res.status(200).send('WABA Config Missing');
        }

        // Webhook Signature Verification
        if (config.app_secret) {
            const signature = req.headers['x-hub-signature-256'];
            if (!signature) {
                console.warn('🛡️ [WHATSAPP WEBHOOK] Blocked: X-Hub-Signature-256 header missing');
                return res.status(401).send('Signature missing');
            }

            const parts = signature.split('=');
            if (parts.length !== 2 || parts[0] !== 'sha256') {
                console.warn('🛡️ [WHATSAPP WEBHOOK] Blocked: Invalid signature format');
                return res.status(401).send('Invalid signature format');
            }

            const expectedSignature = parts[1];
            
            // Compute HMAC-SHA256
            const hmac = crypto.createHmac('sha256', config.app_secret);
            // Use the raw body buffer captured in req.rawBody
            hmac.update(req.rawBody || JSON.stringify(req.body));
            const computedSignature = hmac.digest('hex');

            if (computedSignature !== expectedSignature) {
                console.warn('🛡️ [WHATSAPP WEBHOOK] Blocked: Signature mismatch. Body hash does not match App Secret.');
                return res.status(401).send('Signature verification failed');
            }
        }

        // Process changes array
        const changes = entry.changes?.[0];
        if (!changes) {
            return res.status(200).send('No changes');
        }

        const { field, value } = changes;

        // 1. Template Status Updates
        if (field === 'message_template_status_update') {
            const { event, message_template_id, message_template_name, message_template_language } = value;
            
            console.log(`🛡️ [WHATSAPP WEBHOOK] Template Update: ${message_template_name} (${message_template_language}) -> ${event}`);
            
            let rejectionReason = null;
            if (event && event.toUpperCase() === 'REJECTED') {
                const metaReason = value.reason || '';
                const infoReason = value.rejection_info?.reason || '';
                const recommendation = value.rejection_info?.recommendation || '';
                
                const parts = [];
                if (metaReason) parts.push(`Code: ${metaReason}`);
                if (infoReason) parts.push(`Detail: ${infoReason}`);
                if (recommendation) parts.push(`Suggestion: ${recommendation}`);
                
                rejectionReason = parts.join(' | ') || 'Template rejected by Meta review system.';
            }

            await req.propertyDb.models.whatsapp_templates.update({
                status: event.toUpperCase(),
                meta_template_id: message_template_id,
                rejection_reason: rejectionReason
            }, {
                where: {
                    outlet_id: config.outlet_id,
                    template_name: message_template_name,
                    language: message_template_language
                },
                bypassOutletFilter: true
            });
        }

        // 2. Message Telemetry Status Updates
        if (field === 'messages' && Array.isArray(value?.statuses)) {
            for (const status of value.statuses) {
                const messageId = status.id;
                const deliveryStatus = status.status; // sent, delivered, read, failed

                console.log(`🛡️ [WHATSAPP WEBHOOK] Message Telemetry: ${messageId} -> ${deliveryStatus}`);

                const updateData = {
                    delivery_status: deliveryStatus
                };

                if (deliveryStatus === 'failed' && Array.isArray(status.errors)) {
                    const errorMsg = status.errors.map(err => `[${err.code}] ${err.message || err.title}`).join(', ');
                    updateData.error_message = errorMsg;
                }

                await req.propertyDb.models.whatsapp_logs.update(updateData, {
                    where: {
                        outlet_id: config.outlet_id,
                        meta_message_id: messageId
                    },
                    bypassOutletFilter: true
                });
            }
        }

        // Always return 200 OK to Meta
        res.status(200).send('EVENT_RECEIVED');
    } catch (error) {
        console.error('🛡️ [WHATSAPP WEBHOOK ERROR] Public receiver crash:', error.message);
        res.status(200).send('EVENT_ERROR'); // Prevent Meta from locking webhook on crash
    }
}

module.exports = {
    verifyWebhook,
    receiveWebhook
};
