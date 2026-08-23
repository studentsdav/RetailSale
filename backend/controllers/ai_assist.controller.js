const aiService = require('../services/ai.service');

async function resolveOutletIdAsync(req) {
    const bodyOutletId = Number(req?.body?.outletId ?? req?.body?.outlet_id);
    if (!isNaN(bodyOutletId) && bodyOutletId > 0) {
        return bodyOutletId;
    }

    const headerOutletId = Number(req?.headers?.['x-outlet-id'] ?? req?.headers?.['outlet_id'] ?? req?.headers?.['outlet-id']);
    if (!isNaN(headerOutletId) && headerOutletId > 0) {
        return headerOutletId;
    }

    const queryOutletId = Number(req?.query?.outlet_id ?? req?.query?.outletId);
    if (!isNaN(queryOutletId) && queryOutletId > 0) {
        return queryOutletId;
    }

    const rawCode = req?.body?.outletCode ?? req?.body?.outlet_code ?? 
                    req?.headers?.['x-outlet-code'] ?? req?.headers?.['outlet_code'] ?? 
                    req?.query?.outlet_code;

    if (rawCode && req?.propertyDb) {
        try {
            const cleanCode = String(rawCode).trim();
            const outRes = await req.propertyDb.query(`
                SELECT id FROM outlets WHERE outlet_code = :cleanCode OR outlet_name ILIKE :cleanCode LIMIT 1
            `, {
                replacements: { cleanCode },
                type: req.propertyDb.QueryTypes.SELECT
            });
            if (outRes && outRes.length > 0 && outRes[0].id) {
                return Number(outRes[0].id);
            }
        } catch (_) {}
    }

    const userOutletId = Number(req?.user?.outlet_id ?? req?.user?.outletId ?? req?.user?.property_id ?? req?.user?.propertyId);
    if (!isNaN(userOutletId) && userOutletId > 0) {
        return userOutletId;
    }

    return 1;
}

exports.chatWithLynxAssist = async (req, res) => {
    try {
        const { message, history, aiProvider, aiModelName, aiBaseUrl, aiApiKey, maxRows } = req.body;

        if (!message || typeof message !== 'string' || message.trim().length === 0) {
            return res.status(400).json({
                success: false,
                message: 'User message is required.'
            });
        }

        const outletId = await resolveOutletIdAsync(req);
        const aiConfig = { aiProvider, aiModelName, aiBaseUrl, aiApiKey, maxRows };
        const result = await aiService.processLynxAssist(message, [], aiConfig, req.propertyDb, outletId);

        return res.json({
            success: true,
            data: result
        });
    } catch (error) {
        console.error('[LYNX ASSIST CONTROLLER ERROR]:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to process LYNX Assist message.'
        });
    }
};

exports.handleVoiceCommand = async (req, res) => {
    try {
        const { transcript, history, aiProvider, aiModelName, aiBaseUrl, aiApiKey, maxRows } = req.body;

        if (!transcript || typeof transcript !== 'string' || transcript.trim().length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Speech transcript is required.'
            });
        }

        const outletId = await resolveOutletIdAsync(req);
        const aiConfig = { aiProvider, aiModelName, aiBaseUrl, aiApiKey, maxRows };
        const result = await aiService.processLynxAssist(transcript, [], aiConfig, req.propertyDb, outletId);

        return res.json({
            success: true,
            isVoice: true,
            transcript,
            data: result
        });
    } catch (error) {
        console.error('[LYNX ASSIST VOICE CONTROLLER ERROR]:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to process voice command.'
        });
    }
};
