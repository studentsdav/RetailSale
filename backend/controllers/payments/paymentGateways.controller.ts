import { Request, Response } from 'express';
const MpesaService = require('../../services/mpesa.service');

function safeParseJson(data: any, defaultVal: any = {}) {
    if (!data) return defaultVal;
    if (typeof data === 'object') return data;
    if (typeof data === 'string') {
        try {
            return JSON.parse(data);
        } catch (e) {
            return defaultVal;
        }
    }
    return defaultVal;
}

export const getGatewaysConfig = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const settings = await (req as any).propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        const propInfo = (req as any).propertyDb.models.property_info ? await (req as any).propertyDb.models.property_info.findOne({
            where: { outlet_id }
        }).catch(() => null) : null;

        const custom = safeParseJson(settings?.custom_settings);
        const gateways = safeParseJson(custom.payment_gateways);
        const mpesa = safeParseJson(gateways.mpesa || custom.mpesa);
        const upi = safeParseJson(gateways.upi);
        const stripe = safeParseJson(gateways.stripe);
        const razorpay = safeParseJson(gateways.razorpay);
        const square = safeParseJson(gateways.square);
        const paypal = safeParseJson(gateways.paypal);
        const india_pos = safeParseJson(gateways.india_pos);

        const resolvedUpiId = upi.upi_id || propInfo?.upi_id || settings?.merchant_upi_id || '';
        const resolvedPayeeName = upi.payee_name || propInfo?.upi_payee_name || propInfo?.legal_name || propInfo?.property_name || '';
        const resolvedPrintUpiQr = upi.print_upi_qr ?? propInfo?.print_upi_qr ?? true;
        const resolvedUpiEnabled = upi.enabled !== undefined ? Boolean(upi.enabled) : Boolean(resolvedUpiId || true);

        // Razorpay (check custom_settings or root fallback)
        const isRazorpayRoot = settings?.payment_gateway_provider === 'RAZORPAY';
        const razorpayKeyId = razorpay.key_id || (isRazorpayRoot ? (settings?.payment_gateway_api_key || '') : '');
        const razorpayHasSecret = Boolean(razorpay.key_secret || (isRazorpayRoot && settings?.payment_gateway_secret_key));
        const razorpayEnabled = razorpay.enabled !== undefined ? Boolean(razorpay.enabled) : Boolean(isRazorpayRoot && settings?.enable_payment_gateway);

        // Stripe
        const isStripeRoot = settings?.payment_gateway_provider === 'STRIPE';
        const stripePub = stripe.publishable_key || (isStripeRoot ? (settings?.payment_gateway_api_key || '') : '');
        const stripeHasSecret = Boolean(stripe.secret_key || (isStripeRoot && settings?.payment_gateway_secret_key));
        const stripeEnabled = stripe.enabled !== undefined ? Boolean(stripe.enabled) : Boolean(isStripeRoot && settings?.enable_payment_gateway);

        // M-Pesa
        const mpesaShortcode = mpesa.shortcode || '';
        const mpesaKey = mpesa.consumer_key || '';
        const mpesaHasCreds = Boolean(mpesa.consumer_key && mpesa.consumer_secret && mpesa.passkey);
        const mpesaEnabled = Boolean(mpesa.enabled);

        res.json({
            success: true,
            data: {
                enable_payment_gateway: Boolean(settings?.enable_payment_gateway),
                settlement_mode: settings?.restaurant_settlement_mode || 'DIRECT',
                active_methods: safeParseJson(settings?.payment_modes, [
                    { id: 'CASH', name: 'Cash', enabled: true },
                    { id: 'CARD', name: 'Credit / Debit Card', enabled: true },
                    { id: 'UPI', name: 'UPI / QR Pay', enabled: true },
                    { id: 'STRIPE', name: 'Stripe / Apple Pay', enabled: false },
                    { id: 'SQUARE', name: 'Square POS', enabled: false },
                    { id: 'MPESA', name: 'M-Pesa (Kenya)', enabled: mpesaEnabled },
                    { id: 'RAZORPAY', name: 'Razorpay', enabled: false },
                    { id: 'PAYPAL', name: 'PayPal', enabled: false },
                    { id: 'BANK', name: 'Bank Transfer', enabled: true },
                    { id: 'CREDIT', name: 'Customer Credit', enabled: true }
                ]),
                upi: {
                    enabled: resolvedUpiEnabled,
                    upi_id: resolvedUpiId,
                    payee_name: resolvedPayeeName,
                    print_upi_qr: resolvedPrintUpiQr
                },
                razorpay: {
                    enabled: razorpayEnabled,
                    env: razorpay.env || 'test',
                    key_id: razorpayKeyId,
                    key_secret: razorpayHasSecret ? '********' : '',
                    has_secret: razorpayHasSecret
                },
                stripe: {
                    enabled: stripeEnabled,
                    env: stripe.env || 'test',
                    publishable_key: stripePub,
                    secret_key: stripeHasSecret ? '********' : '',
                    has_secret: stripeHasSecret
                },
                square: {
                    enabled: Boolean(square.enabled),
                    env: square.env || 'sandbox',
                    app_id: square.app_id || '',
                    location_id: square.location_id || '',
                    access_token: square.access_token ? '********' : '',
                    has_token: Boolean(square.access_token)
                },
                paypal: {
                    enabled: Boolean(paypal.enabled),
                    env: paypal.env || 'sandbox',
                    client_id: paypal.client_id || '',
                    client_secret: paypal.client_secret ? '********' : '',
                    has_secret: Boolean(paypal.client_secret)
                },
                mpesa: {
                    enabled: mpesaEnabled,
                    env: mpesa.env || 'sandbox',
                    type: mpesa.type || 'till',
                    shortcode: mpesaShortcode,
                    consumer_key: mpesaKey,
                    consumer_secret: mpesa.consumer_secret ? '********' : '',
                    passkey: mpesa.passkey ? '********' : '',
                    has_credentials: mpesaHasCreds
                },
                india_pos: {
                    enabled: Boolean(india_pos.enabled),
                    provider: india_pos.provider || 'pinelabs',
                    device_ip: india_pos.device_ip || '',
                    pos_id: india_pos.pos_id || '',
                    auto_push: india_pos.auto_push ?? true
                }
            }
        });
    } catch (err: any) {
        console.error('[GATEWAYS CONFIG ERROR]', err);
        res.status(500).json({ success: false, message: 'Failed to load payment gateways config' });
    }
};

export const saveGatewaysConfig = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const {
            settlement_mode,
            active_methods,
            upi,
            mpesa,
            stripe,
            razorpay,
            square,
            paypal,
            india_pos
        } = req.body;

        let settings = await (req as any).propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        if (!settings) {
            settings = await (req as any).propertyDb.models.system_settings.create({
                outlet_id,
                custom_settings: {}
            });
        }

        const currentCustom = safeParseJson(settings.custom_settings);
        const prevGateways = safeParseJson(currentCustom.payment_gateways);
        const prevMpesa = safeParseJson(currentCustom.mpesa || prevGateways.mpesa);
        const prevStripe = safeParseJson(prevGateways.stripe);
        const prevRazorpay = safeParseJson(prevGateways.razorpay);
        const prevSquare = safeParseJson(prevGateways.square);
        const prevPaypal = safeParseJson(prevGateways.paypal);
        const prevUpi = safeParseJson(prevGateways.upi);
        const prevIndiaPos = safeParseJson(prevGateways.india_pos);

        // Helper to resolve secrets without overwriting existing on masked submission
        const resolveSecret = (incoming: any, existing: any) => {
            if (incoming === undefined) return existing || '';
            const str = String(incoming).trim();
            if (str.includes('***')) return existing || '';
            return str;
        };

        // 1. Process M-Pesa
        const updatedMpesa = mpesa ? {
            enabled: Boolean(mpesa.enabled),
            env: mpesa.env || prevMpesa.env || 'sandbox',
            type: mpesa.type || prevMpesa.type || 'till',
            shortcode: mpesa.shortcode !== undefined ? String(mpesa.shortcode).trim() : (prevMpesa.shortcode || ''),
            consumer_key: mpesa.consumer_key !== undefined ? String(mpesa.consumer_key).trim() : (prevMpesa.consumer_key || ''),
            consumer_secret: resolveSecret(mpesa.consumer_secret, prevMpesa.consumer_secret),
            passkey: resolveSecret(mpesa.passkey, prevMpesa.passkey),
            updated_at: new Date().toISOString()
        } : prevMpesa;

        // 2. Process UPI
        const updatedUpi = upi ? {
            enabled: Boolean(upi.enabled ?? true),
            upi_id: String(upi.upi_id || '').trim(),
            payee_name: String(upi.payee_name || '').trim(),
            print_upi_qr: upi.print_upi_qr ?? true,
            updated_at: new Date().toISOString()
        } : prevUpi;

        // 3. Process Stripe
        const updatedStripe = stripe ? {
            enabled: Boolean(stripe.enabled),
            env: stripe.env || prevStripe.env || 'test',
            publishable_key: stripe.publishable_key !== undefined ? String(stripe.publishable_key).trim() : (prevStripe.publishable_key || ''),
            secret_key: resolveSecret(stripe.secret_key, prevStripe.secret_key),
            updated_at: new Date().toISOString()
        } : prevStripe;

        // 4. Process Razorpay
        const updatedRazorpay = razorpay ? {
            enabled: Boolean(razorpay.enabled),
            env: razorpay.env || prevRazorpay.env || 'test',
            key_id: razorpay.key_id !== undefined ? String(razorpay.key_id).trim() : (prevRazorpay.key_id || ''),
            key_secret: resolveSecret(razorpay.key_secret, prevRazorpay.key_secret),
            updated_at: new Date().toISOString()
        } : prevRazorpay;

        // 5. Process Square
        const updatedSquare = square ? {
            enabled: Boolean(square.enabled),
            env: square.env || prevSquare.env || 'sandbox',
            app_id: square.app_id !== undefined ? String(square.app_id).trim() : (prevSquare.app_id || ''),
            location_id: square.location_id !== undefined ? String(square.location_id).trim() : (prevSquare.location_id || ''),
            access_token: resolveSecret(square.access_token, prevSquare.access_token),
            updated_at: new Date().toISOString()
        } : prevSquare;

        // 6. Process PayPal
        const updatedPaypal = paypal ? {
            enabled: Boolean(paypal.enabled),
            env: paypal.env || prevPaypal.env || 'sandbox',
            client_id: paypal.client_id !== undefined ? String(paypal.client_id).trim() : (prevPaypal.client_id || ''),
            client_secret: resolveSecret(paypal.client_secret, prevPaypal.client_secret),
            updated_at: new Date().toISOString()
        } : prevPaypal;

        // 7. Process India Smart POS Card Machine (PineLabs / Ezetap / Mosambee)
        const updatedIndiaPos = india_pos ? {
            enabled: Boolean(india_pos.enabled),
            provider: india_pos.provider || prevIndiaPos.provider || 'pinelabs',
            device_ip: india_pos.device_ip !== undefined ? String(india_pos.device_ip).trim() : (prevIndiaPos.device_ip || ''),
            pos_id: india_pos.pos_id !== undefined ? String(india_pos.pos_id).trim() : (prevIndiaPos.pos_id || ''),
            auto_push: india_pos.auto_push ?? prevIndiaPos.auto_push ?? true,
            updated_at: new Date().toISOString()
        } : prevIndiaPos;

        const updatedGateways = {
            upi: updatedUpi,
            mpesa: updatedMpesa,
            stripe: updatedStripe,
            razorpay: updatedRazorpay,
            square: updatedSquare,
            paypal: updatedPaypal,
            india_pos: updatedIndiaPos,
            updated_at: new Date().toISOString()
        };

        const newCustomSettings = {
            ...currentCustom,
            payment_gateways: updatedGateways,
            mpesa: updatedMpesa
        };

        settings.set('custom_settings', newCustomSettings);
        settings.changed('custom_settings', true);

        if (settlement_mode) {
            settings.set('restaurant_settlement_mode', settlement_mode);
        }
        if (active_methods && Array.isArray(active_methods)) {
            settings.set('payment_modes', active_methods);
            settings.changed('payment_modes', true);
        }
        if (updatedUpi.upi_id !== undefined) {
            settings.set('merchant_upi_id', updatedUpi.upi_id);
        }

        // Sync root columns
        if (req.body.enable_payment_gateway !== undefined) {
            settings.set('enable_payment_gateway', Boolean(req.body.enable_payment_gateway));
        } else if (updatedRazorpay.enabled || updatedStripe.enabled || updatedSquare.enabled || updatedPaypal.enabled || updatedMpesa.enabled || updatedIndiaPos.enabled) {
            settings.set('enable_payment_gateway', true);
        } else {
            settings.set('enable_payment_gateway', false);
        }

        if (updatedRazorpay.enabled) {
            settings.set('payment_gateway_provider', 'RAZORPAY');
            if (updatedRazorpay.key_id) settings.set('payment_gateway_api_key', updatedRazorpay.key_id);
            if (updatedRazorpay.key_secret) settings.set('payment_gateway_secret_key', updatedRazorpay.key_secret);
        } else if (updatedStripe.enabled) {
            settings.set('payment_gateway_provider', 'STRIPE');
            if (updatedStripe.publishable_key) settings.set('payment_gateway_api_key', updatedStripe.publishable_key);
            if (updatedStripe.secret_key) settings.set('payment_gateway_secret_key', updatedStripe.secret_key);
        }

        await settings.save();

        // Bi-directional sync with property_info
        if ((req as any).propertyDb.models.property_info) {
            const propInfo = await (req as any).propertyDb.models.property_info.findOne({
                where: { outlet_id }
            });
            if (propInfo) {
                const propUpdates: any = {};
                if (updatedUpi.upi_id !== undefined) propUpdates.upi_id = updatedUpi.upi_id;
                if (updatedUpi.payee_name !== undefined && updatedUpi.payee_name !== '') {
                    propUpdates.upi_payee_name = updatedUpi.payee_name;
                }
                if (updatedUpi.print_upi_qr !== undefined) propUpdates.print_upi_qr = updatedUpi.print_upi_qr;
                if (Object.keys(propUpdates).length > 0) {
                    await propInfo.update(propUpdates).catch((e: any) => console.warn('Could not sync to property_info:', e.message));
                }
            } else if (updatedUpi.upi_id || updatedUpi.payee_name) {
                await (req as any).propertyDb.models.property_info.create({
                    outlet_id,
                    property_name: 'Store',
                    upi_id: updatedUpi.upi_id || '',
                    upi_payee_name: updatedUpi.payee_name || '',
                    print_upi_qr: updatedUpi.print_upi_qr ?? true
                }).catch((e: any) => console.warn('Could not create property_info:', e.message));
            }
        }

        res.json({
            success: true,
            message: 'Global payment gateways & settlement rules updated successfully!'
        });
    } catch (err: any) {
        console.error('[SAVE GATEWAYS CONFIG ERROR]', err);
        res.status(500).json({ success: false, message: 'Failed to save payment gateways config: ' + err.message });
    }
};

module.exports = {
    getGatewaysConfig,
    saveGatewaysConfig
};

export default {
    getGatewaysConfig,
    saveGatewaysConfig
};
