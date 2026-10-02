class MpesaService {
    /**
     * Get OAuth Access Token from Safaricom Daraja
     */
    static async getAccessToken(config) {
        const { consumer_key, consumer_secret, env = 'sandbox' } = config;
        const baseUrl = env === 'production' 
            ? 'https://api.safaricom.co.ke' 
            : 'https://sandbox.safaricom.co.ke';

        const authHeader = Buffer.from(`${consumer_key}:${consumer_secret}`).toString('base64');

        try {
            const response = await fetch(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
                method: 'GET',
                headers: {
                    Authorization: `Basic ${authHeader}`
                }
            });
            const data = await response.json();
            if (!response.ok) {
                throw new Error(data.errorMessage || 'Failed to authenticate with Safaricom Daraja API');
            }
            return data.access_token;
        } catch (err) {
            console.error('[M-PESA AUTH ERROR]:', err.message);
            throw new Error(err.message || 'Failed to authenticate with Safaricom Daraja API');
        }
    }

    /**
     * Initiate STK Push (Lipa na M-Pesa Online)
     */
    static async initiateStkPush({
        config,
        phone,
        amount,
        accountRef = 'RetailSale POS',
        transactionDesc = 'POS Payment',
        callbackUrl
    }) {
        const { shortcode, passkey, env = 'sandbox', type = 'paybill' } = config;
        const baseUrl = env === 'production' 
            ? 'https://api.safaricom.co.ke' 
            : 'https://sandbox.safaricom.co.ke';

        const token = await this.getAccessToken(config);

        // Format timestamp YYYYMMDDHHmmss
        const date = new Date();
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        const seconds = String(date.getSeconds()).padStart(2, '0');
        const timestamp = `${year}${month}${day}${hours}${minutes}${seconds}`;

        const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');

        // Normalize phone number to 254XXXXXXXXX
        let formattedPhone = phone.replace(/[^0-9]/g, '');
        if (formattedPhone.startsWith('0')) {
            formattedPhone = '254' + formattedPhone.substring(1);
        } else if (formattedPhone.startsWith('+')) {
            formattedPhone = formattedPhone.substring(1);
        } else if (formattedPhone.length === 9) {
            formattedPhone = '254' + formattedPhone;
        }

        const transactionType = type === 'till' ? 'CustomerBuyGoodsOnline' : 'CustomerPayBillOnline';
        const roundedAmount = Math.max(1, Math.round(Number(amount)));

        const payload = {
            BusinessShortCode: shortcode,
            Password: password,
            Timestamp: timestamp,
            TransactionType: transactionType,
            Amount: roundedAmount,
            PartyA: formattedPhone,
            PartyB: shortcode,
            PhoneNumber: formattedPhone,
            CallBackURL: callbackUrl || 'https://api.retailsale.app/api/payments/mpesa/callback',
            AccountReference: (accountRef || 'RetailSale').substring(0, 12),
            TransactionDesc: (transactionDesc || 'Sale Payment').substring(0, 13)
        };

        try {
            const response = await fetch(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });
            const data = await response.json();
            if (!response.ok && !data.CheckoutRequestID) {
                throw new Error(data.errorMessage || data.ResponseDescription || 'M-Pesa STK Push request failed');
            }
            return data;
        } catch (err) {
            console.error('[M-PESA STK PUSH ERROR]:', err.message);
            throw new Error(err.message || 'M-Pesa STK Push request failed');
        }
    }

    /**
     * Query STK Push status
     */
    static async queryStkStatus({ config, checkoutRequestId }) {
        const { shortcode, passkey, env = 'sandbox' } = config;
        const baseUrl = env === 'production' 
            ? 'https://api.safaricom.co.ke' 
            : 'https://sandbox.safaricom.co.ke';

        const token = await this.getAccessToken(config);

        const date = new Date();
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        const seconds = String(date.getSeconds()).padStart(2, '0');
        const timestamp = `${year}${month}${day}${hours}${minutes}${seconds}`;

        const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');

        const payload = {
            BusinessShortCode: shortcode,
            Password: password,
            Timestamp: timestamp,
            CheckoutRequestID: checkoutRequestId
        };

        try {
            const response = await fetch(`${baseUrl}/mpesa/stkpushquery/v1/query`, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });
            const data = await response.json();
            if (!response.ok && data.ResultCode === undefined) {
                throw new Error(data.errorMessage || 'M-Pesa STK status query failed');
            }
            return data;
        } catch (err) {
            console.error('[M-PESA QUERY ERROR]:', err.message);
            throw new Error(err.message || 'M-Pesa STK status query failed');
        }
    }
}

module.exports = MpesaService;
