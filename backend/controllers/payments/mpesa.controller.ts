const MpesaService = require('../../services/mpesa.service');

export const getConfig = async (req: any, res: any) => {
    try {
        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id: req.user.outlet_id }
        });

        const rawConfig = settings?.custom_settings?.mpesa || {};
        res.json({
            success: true,
            data: {
                enabled: rawConfig.enabled ?? false,
                env: rawConfig.env || 'sandbox',
                type: rawConfig.type || 'till', // 'till' or 'paybill'
                shortcode: rawConfig.shortcode || '',
                consumer_key: rawConfig.consumer_key || '',
                consumer_secret: rawConfig.consumer_secret ? '********' : '',
                passkey: rawConfig.passkey ? '********' : '',
                has_credentials: Boolean(rawConfig.consumer_key && rawConfig.consumer_secret && rawConfig.passkey)
            }
        });
    } catch (err) {
        console.error('Error fetching M-Pesa config:', err);
        res.status(500).json({ success: false, message: 'Failed to load M-Pesa config' });
    }
};

export const saveConfig = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { enabled, env, type, shortcode, consumer_key, consumer_secret, passkey } = req.body;

        let settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        if (!settings) {
            settings = await req.propertyDb.models.system_settings.create({
                outlet_id,
                custom_settings: {}
            });
        }

        const currentCustom = settings.custom_settings || {};
        const prevMpesa = currentCustom.mpesa || {};

        const updatedMpesa = {
            enabled: enabled ?? prevMpesa.enabled ?? true,
            env: env || prevMpesa.env || 'sandbox',
            type: type || prevMpesa.type || 'till',
            shortcode: shortcode !== undefined ? String(shortcode).trim() : prevMpesa.shortcode,
            consumer_key: consumer_key !== undefined ? String(consumer_key).trim() : prevMpesa.consumer_key,
            consumer_secret: (consumer_secret && !consumer_secret.includes('***')) ? String(consumer_secret).trim() : prevMpesa.consumer_secret,
            passkey: (passkey && !passkey.includes('***')) ? String(passkey).trim() : prevMpesa.passkey,
            updated_at: new Date().toISOString()
        };

        currentCustom.mpesa = updatedMpesa;
        await settings.update({ custom_settings: currentCustom });

        res.json({
            success: true,
            message: 'M-Pesa Daraja configuration updated successfully!',
            data: {
                enabled: updatedMpesa.enabled,
                env: updatedMpesa.env,
                type: updatedMpesa.type,
                shortcode: updatedMpesa.shortcode,
                has_credentials: Boolean(updatedMpesa.consumer_key && updatedMpesa.consumer_secret && updatedMpesa.passkey)
            }
        });
    } catch (err) {
        console.error('Error saving M-Pesa config:', err);
        res.status(500).json({ success: false, message: 'Failed to save M-Pesa config' });
    }
};

export const initiateStkPush = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { phone, amount, bill_no, reference } = req.body;

        if (!phone || !amount) {
            return res.status(400).json({ success: false, message: 'Phone number and amount are required' });
        }

        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        const mpesaConfig = settings?.custom_settings?.mpesa;
        if (!mpesaConfig || !mpesaConfig.consumer_key || !mpesaConfig.consumer_secret || !mpesaConfig.passkey) {
            return res.status(400).json({
                success: false,
                message: 'M-Pesa Daraja API is not configured. Please enter API credentials in Settings.'
            });
        }

        const result = await MpesaService.initiateStkPush({
            config: mpesaConfig,
            phone: String(phone).trim(),
            amount: Number(amount),
            accountRef: reference || bill_no || 'POS Bill',
            transactionDesc: `Bill ${bill_no || ''}`.trim()
        });

        res.json({
            success: true,
            message: result.CustomerMessage || 'STK Push prompt sent to customer phone.',
            checkout_request_id: result.CheckoutRequestID,
            merchant_request_id: result.MerchantRequestID,
            response_code: result.ResponseCode
        });
    } catch (err: any) {
        console.error('Error initiating STK push:', err);
        res.status(500).json({
            success: false,
            message: err.message || 'Failed to initiate M-Pesa STK Push'
        });
    }
};

export const queryStkStatus = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { checkout_request_id } = req.body;

        if (!checkout_request_id) {
            return res.status(400).json({ success: false, message: 'checkout_request_id is required' });
        }

        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        const mpesaConfig = settings?.custom_settings?.mpesa;
        if (!mpesaConfig) {
            return res.status(400).json({ success: false, message: 'M-Pesa not configured' });
        }

        const result = await MpesaService.queryStkStatus({
            config: mpesaConfig,
            checkoutRequestId: checkout_request_id
        });

        res.json({
            success: true,
            result_code: result.ResultCode,
            result_desc: result.ResultDesc,
            data: result
        });
    } catch (err: any) {
        console.error('Error querying STK status:', err);
        res.status(500).json({ success: false, message: err.message || 'Status query failed' });
    }
};

export const handleCallback = async (req: any, res: any) => {
    try {
        console.log('[M-PESA WEBHOOK CALLBACK RECEIVED]:', JSON.stringify(req.body));
        res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
    } catch (err) {
        console.error('[M-PESA CALLBACK ERROR]:', err);
        res.status(500).json({ ResultCode: 1, ResultDesc: 'Internal error' });
    }
};

module.exports = {
    getConfig,
    saveConfig,
    initiateStkPush,
    queryStkStatus,
    handleCallback
};
