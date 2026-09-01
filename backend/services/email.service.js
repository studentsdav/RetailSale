const nodemailer = require('nodemailer');
const https = require('https');

/**
 * Helper function to fetch OAuth2 Access Token from Google
 */
async function getGmailAccessToken(clientId, clientSecret, refreshToken) {
    const postData = new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: 'refresh_token'
    }).toString();

    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: 'oauth2.googleapis.com',
            path: '/token',
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': Buffer.byteLength(postData)
            }
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    if (res.statusCode >= 200 && res.statusCode < 300 && parsed.access_token) {
                        resolve(parsed.access_token);
                    } else {
                        reject(new Error(`OAuth2 Token error (${res.statusCode}): ${parsed.error_description || parsed.error || data}`));
                    }
                } catch (e) {
                    reject(new Error(`Failed to parse OAuth2 token response: ${e.message}`));
                }
            });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
    });
}

/**
 * Send email strictly via Gmail OAuth2 REST API (HTTPS Port 443)
 */
async function sendViaGmailOAuthApi({ clientId, clientSecret, refreshToken, user, fromName, to, subject, htmlContent }) {
    console.log(`[EMAIL SERVICE] Fetching OAuth2 access token for ${user} (Gmail REST API)...`);
    const accessToken = await getGmailAccessToken(clientId, clientSecret, refreshToken);

    const senderHeader = fromName ? `"${fromName}" <${user}>` : user;
    const utf8Subject = `=?utf-8?B?${Buffer.from(subject).toString('base64')}?=`;
    const messageParts = [
        `From: ${senderHeader}`,
        `To: ${to}`,
        `Subject: ${utf8Subject}`,
        'MIME-Version: 1.0',
        'Content-Type: text/html; charset=utf-8',
        '',
        htmlContent
    ];
    const message = messageParts.join('\r\n');

    const encodedMessage = Buffer.from(message)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');

    const postData = JSON.stringify({ raw: encodedMessage });

    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: 'gmail.googleapis.com',
            path: '/gmail/v1/users/me/messages/send',
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            }
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    console.log(`[GMAIL API PO SUCCESS] Sent to ${to}: ${data}`);
                    resolve(true);
                } else {
                    reject(new Error(`Gmail REST API error (${res.statusCode}): ${data}`));
                }
            });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
    });
}

/**
 * Helper service to send email via database-configured or environment email credentials
 */
exports.sendMail = async ({ db, outlet_id, to, subject, text, html, attachments }) => {
    try {
        let config = null;

        if (db && db.models && db.models.email_configurations && outlet_id) {
            config = await db.models.email_configurations.findOne({
                where: { outlet_id }
            });
        }

        const providerType = (config?.provider_type || process.env.EMAIL_PROVIDER || '').toString().toUpperCase();
        const gmailClientId = config?.gmail_client_id || process.env.GMAIL_CLIENT_ID || process.env.GMAIL_OAUTH_CLIENT_ID;
        const gmailClientSecret = config?.gmail_client_secret || process.env.GMAIL_CLIENT_SECRET || process.env.GMAIL_OAUTH_CLIENT_SECRET;
        const gmailRefreshToken = config?.gmail_refresh_token || process.env.GMAIL_REFRESH_TOKEN || process.env.GMAIL_OAUTH_REFRESH_TOKEN;
        const emailUser = config?.smtp_user || config?.from_email || process.env.EMAIL_USER || process.env.EMAIL_ID;

        const isGmailOAuth = providerType === 'GMAIL_OAUTH' || providerType === 'GMAIL' || (gmailClientId && gmailRefreshToken);

        const fromEmail = config?.from_email || config?.smtp_user || emailUser || 'noreply@retail.com';
        const fromName = config?.from_name || config?.sender_name || process.env.EMAIL_FROM_NAME || 'Retail POS';
        const htmlContent = html || `<p>${text || subject}</p>`;

        // MODE 1: GMAIL OAUTH2 REST API (HTTPS Port 443 - Ultra fast)
        if (isGmailOAuth && gmailClientId && gmailRefreshToken) {
            console.log(`[EMAIL SERVICE] Sending PO/Invoice via Gmail OAuth2 REST API (Port 443) to ${to}...`);
            return await sendViaGmailOAuthApi({
                clientId: gmailClientId,
                clientSecret: gmailClientSecret,
                refreshToken: gmailRefreshToken,
                user: emailUser || fromEmail,
                fromName: fromName,
                to: to,
                subject: subject,
                htmlContent: htmlContent
            });
        }

        // MODE 2: STANDARD SMTP FALLBACK
        const isSecure = Number(config?.smtp_port) === 465 || (config?.encryption_type && String(config.encryption_type).includes('SSL'));
        const transporter = nodemailer.createTransport({
            host: config?.smtp_host || process.env.EMAIL_HOST || 'smtp.gmail.com',
            port: Number(config?.smtp_port) || Number(process.env.EMAIL_PORT) || 587,
            secure: isSecure,
            auth: {
                user: emailUser,
                pass: config?.smtp_pass || process.env.EMAIL_PASS
            },
            tls: { rejectUnauthorized: false }
        });

        const mailOptions = {
            from: `"${fromName}" <${fromEmail}>`,
            to,
            subject,
            text,
            html: htmlContent,
            attachments
        };

        const info = await transporter.sendMail(mailOptions);
        console.log(`[EMAIL SERVICE SMTP SUCCESS] Message sent to ${to}: ${info.messageId}`);
        return true;
    } catch (error) {
        console.error(`[EMAIL SERVICE ERROR] Error sending email to ${to}:`, error);
        return false;
    }
};
