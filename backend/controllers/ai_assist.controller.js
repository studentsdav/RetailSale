const aiService = require('../services/ai.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
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

        const outletId = resolveOutletId(req);
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

        const outletId = resolveOutletId(req);
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
