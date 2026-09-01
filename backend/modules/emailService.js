const nodemailer = require("nodemailer");
const dns = require("dns");
const https = require("https");
const sysConfig = require('../utils/configManager');

// Force Node.js DNS to prefer IPv4 over IPv6 on cloud hosts like Render
if (dns.setDefaultResultOrder) {
    try {
        dns.setDefaultResultOrder('ipv4first');
    } catch (_) {}
}

function ipv4Lookup(hostname, options, callback) {
    if (typeof options === 'function') {
        callback = options;
        options = {};
    }
    dns.resolve4(hostname, (err, addresses) => {
        if (err || !addresses || addresses.length === 0) {
            return dns.lookup(hostname, { family: 4 }, callback);
        }
        callback(null, addresses[0], 4);
    });
}

function getTransporter(overridePort = null) {
    const emailUser = process.env.EMAIL_USER || process.env.EMAIL_ID || (sysConfig ? sysConfig.emailId : null);
    const emailPass = process.env.EMAIL_PASS || process.env.EMAIL_PASSWORD || (sysConfig ? sysConfig.emailPass : null);
    const emailHost = process.env.EMAIL_HOST || 'smtp.gmail.com';
    const timeoutMs = Number(process.env.EMAIL_TIMEOUT) || 20000;

    // Check for Gmail OAuth2 credentials
    const gmailClientId = process.env.GMAIL_CLIENT_ID || process.env.GMAIL_OAUTH_CLIENT_ID;
    const gmailClientSecret = process.env.GMAIL_CLIENT_SECRET || process.env.GMAIL_OAUTH_CLIENT_SECRET;
    const gmailRefreshToken = process.env.GMAIL_REFRESH_TOKEN || process.env.GMAIL_OAUTH_REFRESH_TOKEN;

    if (emailUser && gmailClientId && gmailClientSecret && gmailRefreshToken) {
        console.log(`[EMAIL OAUTH2] Initializing Gmail OAuth2 transporter for ${emailUser}...`);
        return nodemailer.createTransport({
            service: 'gmail',
            auth: {
                type: 'OAuth2',
                user: emailUser,
                clientId: gmailClientId,
                clientSecret: gmailClientSecret,
                refreshToken: gmailRefreshToken
            },
            lookup: ipv4Lookup,
            family: 4,
            connectionTimeout: timeoutMs,
            greetingTimeout: timeoutMs,
            socketTimeout: timeoutMs,
            dnsTimeout: timeoutMs
        });
    }

    if (!emailUser || !emailPass) {
        return null;
    }

    const isZoho = emailHost.toLowerCase().includes('zoho');
    let emailPort = overridePort || Number(process.env.EMAIL_PORT);

    const secEnv = (process.env.EMAIL_SECURITY || process.env.EMAIL_SECURE_MODE || '').toString().trim().toUpperCase();
    const isSecureEnvBool = process.env.EMAIL_SECURE === 'true' || process.env.EMAIL_SECURE === '1';

    let isSecure = isSecureEnvBool;
    let requireTLS = false;

    if (secEnv === 'SSL' || secEnv === '465') {
        isSecure = true;
        if (!emailPort) emailPort = 465;
    } else if (secEnv === 'STARTTLS' || secEnv === 'TLS' || secEnv === '587') {
        isSecure = false;
        requireTLS = true;
        if (!emailPort) emailPort = 587;
    } else if (secEnv === 'NONE' || secEnv === '25') {
        isSecure = false;
        requireTLS = false;
        if (!emailPort) emailPort = 25;
    } else {
        if (!emailPort) {
            emailPort = isZoho ? 465 : 587;
        }

        // Auto-adjust Zoho port 587 -> 465 for cloud hosting compatibility (Render blocks port 587)
        if (isZoho && emailPort === 587 && !overridePort) {
            console.log(`[EMAIL NOTICE] Auto-adjusting Zoho SMTP port from 587 to 465 (SSL) for Render cloud compatibility.`);
            emailPort = 465;
        }

        isSecure = emailPort === 465;
        requireTLS = emailPort === 587;
    }

    return nodemailer.createTransport({
        host: emailHost,
        port: emailPort,
        secure: isSecure,
        requireTLS: requireTLS,
        auth: {
            user: emailUser,
            pass: emailPass
        },
        lookup: ipv4Lookup,
        family: 4,
        connectionTimeout: timeoutMs,
        greetingTimeout: timeoutMs,
        socketTimeout: timeoutMs,
        dnsTimeout: timeoutMs
    });
}

async function sendViaResendApi(apiKey, to, subject, htmlContent) {
    const fromAddress = process.env.EMAIL_FROM || "Retail POS <onboarding@resend.dev>";
    const postData = JSON.stringify({
        from: fromAddress,
        to: [to],
        subject: subject,
        html: htmlContent
    });

    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: 'api.resend.com',
            path: '/emails',
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            }
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    console.log(`[EMAIL-RESEND] Sent to ${to}: ${data}`);
                    resolve(true);
                } else {
                    reject(new Error(`Resend API error (${res.statusCode}): ${data}`));
                }
            });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
    });
}

/**
 * Core function to send any generic email
 */
async function sendEmail(to, subject, htmlContent) {
    const emailUser = process.env.EMAIL_USER || process.env.EMAIL_ID || (sysConfig ? sysConfig.emailId : null);
    const emailPass = process.env.EMAIL_PASS || process.env.EMAIL_PASSWORD || (sysConfig ? sysConfig.emailPass : null);
    const emailHost = process.env.EMAIL_HOST || 'smtp.gmail.com';
    const emailPort = Number(process.env.EMAIL_PORT) || 587;

    const secEnv = (process.env.EMAIL_SECURITY || process.env.EMAIL_SECURE_MODE || '').toString().trim().toUpperCase();
    const isSecureBool = process.env.EMAIL_SECURE === 'true' || process.env.EMAIL_SECURE === '1' || emailPort === 465 || secEnv === 'SSL';
    const secProtocolStr = isSecureBool ? 'SSL (465)' : (secEnv === 'NONE' ? 'NONE (25)' : 'STARTTLS (587)');

    const providerMode = (process.env.EMAIL_PROVIDER || process.env.EMAIL_DRIVER || '').toString().trim().toUpperCase();
    const useResendOnly = providerMode === 'RESEND' || process.env.USE_RESEND === 'true';
    const useSmtpOnly = providerMode === 'SMTP' || providerMode === 'GMAIL' || providerMode === 'OAUTH' || process.env.USE_SMTP === 'true';

    console.log(`🔍 [EMAIL DEBUG] Target: ${to} | Provider Mode: ${providerMode || 'AUTO'} | User: ${emailUser ? 'YES (' + emailUser + ')' : 'NO'} | Host: ${emailHost}:${emailPort} (${secProtocolStr}) | Resend Key: ${process.env.RESEND_API_KEY ? 'YES' : 'NO'}`);

    // MODE 1: RESEND ONLY (Does NOT request SMTP/OAuth2)
    if (useResendOnly) {
        if (!process.env.RESEND_API_KEY) {
            throw new Error("EMAIL_PROVIDER is set to RESEND, but RESEND_API_KEY is missing in environment variables.");
        }
        console.log(`[EMAIL MODE] Sending strictly via Resend API to ${to}...`);
        return await sendViaResendApi(process.env.RESEND_API_KEY, to, subject, htmlContent);
    }

    // MODE 2: SMTP / GMAIL OAUTH2 ONLY (Does NOT request Resend API)
    if (useSmtpOnly) {
        const gmailClientId = process.env.GMAIL_CLIENT_ID || process.env.GMAIL_OAUTH_CLIENT_ID;
        const gmailRefreshToken = process.env.GMAIL_REFRESH_TOKEN || process.env.GMAIL_OAUTH_REFRESH_TOKEN;
        const hasAuth = (emailUser && emailPass) || (emailUser && gmailClientId && gmailRefreshToken);

        if (!hasAuth) {
            throw new Error("EMAIL_PROVIDER is set to SMTP/GMAIL, but email credentials (EMAIL_USER/EMAIL_PASS or GMAIL OAuth2) are missing.");
        }
        console.log(`[EMAIL MODE] Sending strictly via SMTP/OAuth2 to ${to}...`);
        const transporter = getTransporter();
        if (!transporter) throw new Error("Could not initialize email transporter.");
        const info = await transporter.sendMail({
            from: `"System Admin" <${emailUser}>`,
            to: to,
            subject: subject,
            html: htmlContent
        });
        console.log(`[EMAIL SUCCESS] Sent to ${to}: ${info.messageId}`);
        return true;
    }

    // MODE 3: AUTO / FALLBACK MODE (Tries SMTP first, falls back to Resend API if SMTP fails)
    if (emailUser && emailPass) {
        const transporter = getTransporter();
        if (transporter) {
            try {
                const info = await transporter.sendMail({
                    from: `"System Admin" <${emailUser}>`,
                    to: to,
                    subject: subject,
                    html: htmlContent
                });
                console.log(`[EMAIL SMTP SUCCESS] Sent to ${to}: ${info.messageId}`);
                return true;
            } catch (smtpErr) {
                console.error(`[EMAIL SMTP ERROR] ${smtpErr.message}`);
                // Retry fallback: If port 587 timed out on cloud host, try SSL Port 465
                if ((smtpErr.code === 'ETIMEDOUT' || smtpErr.code === 'ESOCKET' || smtpErr.message.includes('ETIMEDOUT')) && emailPort !== 465) {
                    console.warn(`[EMAIL TIMEOUT FALLBACK] Retrying email to ${to} via SSL Port 465...`);
                    try {
                        const fallbackTransporter = getTransporter(465);
                        if (fallbackTransporter) {
                            const info = await fallbackTransporter.sendMail({
                                from: `"System Admin" <${emailUser}>`,
                                to: to,
                                subject: subject,
                                html: htmlContent
                            });
                            console.log(`[EMAIL SUCCESS via Port 465] Sent to ${to}: ${info.messageId}`);
                            return true;
                        }
                    } catch (fallbackErr) {
                        console.error(`[EMAIL FALLBACK ERROR] ${fallbackErr.message}`);
                    }
                }
            }
        }
    }

    // Secondary Fallback if SMTP fails/not configured in AUTO mode
    if (process.env.RESEND_API_KEY) {
        try {
            return await sendViaResendApi(process.env.RESEND_API_KEY, to, subject, htmlContent);
        } catch (resendErr) {
            console.error(`[EMAIL RESEND ERROR] ${resendErr.message}`);
        }
    }

    if (!emailUser || !emailPass) {
        console.warn(`⚠️ [EMAIL NOTICE] SMTP credentials not configured. Email to ${to} bypassed.`);
        return false;
    }

    throw new Error(`Failed to send email to ${to}`);
}

/**
 * Template 1: Send an OTP Code
 */
async function sendOtpEmail(to, otpCode, purpose = "Verification Request") {
    console.log(`🔑 [OTP GENERATED] Target: ${to} | Verification Code: ${otpCode}`);
    const html = `
        <div style="font-family: sans-serif; padding: 20px; max-width: 600px; border: 1px solid #eee; border-radius: 8px;">
            <h2 style="color: #333;">${purpose}</h2>
            <p style="color: #555;">You recently made a request that requires verification. Your 6-digit code is:</p>
            <div style="background-color: #f4f7f6; padding: 15px; text-align: center; border-radius: 6px; margin: 20px 0;">
                <h1 style="color: #0056b3; letter-spacing: 5px; margin: 0;">${otpCode}</h1>
            </div>
            <p style="color: #777; font-size: 12px;"><i>This code expires in 10 minutes. If you did not request this, please change your password immediately.</i></p>
        </div>
    `;
    try {
        await sendEmail(to, `Your Verification Code: ${otpCode}`, html);
    } catch (err) {
        console.warn(`⚠️ [EMAIL NOTICE] Could not send OTP email to ${to}: ${err.message}. Use OTP: ${otpCode} from logs.`);
    }
    return true;
}

/**
 * Template 2: Send a Password Reset Link (For Local DB Users)
 */
async function sendPasswordResetEmail(to, resetLink, username) {
    const html = `
        <div style="font-family: sans-serif; padding: 20px; max-width: 600px; border: 1px solid #eee; border-radius: 8px;">
            <h2 style="color: #333;">Password Reset Request</h2>
            <p style="color: #555;">Hello <b>${username}</b>,</p>
            <p style="color: #555;">We received a request to reset the password for your local admin account. Click the button below to set a new password:</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="${resetLink}" style="background-color: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Reset Password</a>
            </div>
            <p style="color: #777; font-size: 12px;"><i>If the button doesn't work, copy and paste this link: <br>${resetLink}</i></p>
        </div>
    `;
    return await sendEmail(to, "Reset Your Account Password", html);
}

/**
 * Template 3: System Alert / Notification
 */
async function sendSystemAlert(to, alertMessage) {
    const html = `
        <div style="font-family: sans-serif; padding: 20px; border-left: 4px solid #dc3545; background-color: #fff3f3;">
            <h3 style="color: #dc3545; margin-top: 0;">System Alert</h3>
            <p style="color: #333;">${alertMessage}</p>
        </div>
    `;
    return await sendEmail(to, "Important System Alert", html);
}

async function sendUsernameRecoveryEmail(to, usernames, outletName) {
    const usernameListHtml = usernames.map(un => `<li style="font-size: 16px; font-weight: bold; color: #0056b3; margin-bottom: 5px;">${un}</li>`).join('');

    const html = `
        <div style="font-family: sans-serif; padding: 20px; max-width: 600px; border: 1px solid #eee; border-radius: 8px;">
            <h2 style="color: #333;">Username Recovery</h2>
            <p style="color: #555;">We received a request to recover the usernames for <b>${outletName}</b>.</p>
            <p style="color: #555;">Here are the active usernames associated with this account:</p>
            <ul style="background-color: #f4f7f6; padding: 20px 40px; border-radius: 6px;">
                ${usernameListHtml}
            </ul>
            <p style="color: #777; font-size: 12px; margin-top: 20px;"><i>If you did not request this, you can safely ignore this email.</i></p>
        </div>
    `;
    return await sendEmail(to, "Your Recovered Usernames", html);
}

async function sendOutletRecoveryEmail(to, outlets) {
    const outletListHtml = outlets.map(o => `
        <li style="margin-bottom: 10px;">
            <b>${o.property_name}</b> <br>
            <span style="color: #0056b3; font-family: monospace; font-size: 16px;">${o.outlet_code}</span>
        </li>
    `).join('');

    const html = `
        <div style="font-family: sans-serif; padding: 20px; max-width: 600px; border: 1px solid #eee; border-radius: 8px;">
            <h2 style="color: #333;">Outlet Recovery</h2>
            <p style="color: #555;">We found the following outlets registered to your email address:</p>
            <ul style="background-color: #f4f7f6; padding: 20px 40px; border-radius: 6px;">
                ${outletListHtml}
            </ul>
            <p style="color: #777; font-size: 12px; margin-top: 20px;"><i>Please keep these codes secure.</i></p>
        </div>
    `;
    return await sendEmail(to, "Your Recovered Outlet Codes", html);
}

module.exports = {
    sendEmail,
    sendOtpEmail,
    sendPasswordResetEmail,
    sendSystemAlert,
    sendUsernameRecoveryEmail,
    sendOutletRecoveryEmail
};