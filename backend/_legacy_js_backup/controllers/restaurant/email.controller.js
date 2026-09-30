const nodemailer = require('nodemailer');
const audit = require('../../services/audit.service');

exports.getEmailConfig = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const config = await req.propertyDb.models.email_configurations.findOne({
            where: { outlet_id }
        });
        res.json({ success: true, data: config });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveEmailConfig = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const {
            smtp_host,
            smtp_port,
            smtp_user,
            smtp_pass,
            encryption_type,
            from_name,
            from_email,
            sender_name,
            security_type,
            provider_type,
            gmail_client_id,
            gmail_client_secret,
            gmail_refresh_token,
            resend_api_key,
            is_active
        } = req.body;

        const effectiveFromEmail = from_email || smtp_user;
        const effectiveFromName = from_name || sender_name || 'Retail POS';
        const effectiveEncryption = encryption_type || security_type || 'STARTTLS';
        const effectiveProvider = provider_type || 'SMTP';

        let config = await req.propertyDb.models.email_configurations.findOne({
            where: { outlet_id }
        });

        const updateData = {
            smtp_host: smtp_host || 'smtp.gmail.com',
            smtp_port: Number(smtp_port) || 587,
            smtp_user,
            smtp_pass,
            encryption_type: effectiveEncryption,
            from_name: effectiveFromName,
            from_email: effectiveFromEmail,
            provider_type: effectiveProvider,
            gmail_client_id,
            gmail_client_secret,
            gmail_refresh_token,
            resend_api_key,
            is_active: is_active ?? true
        };

        if (config) {
            await config.update(updateData);
        } else {
            config = await req.propertyDb.models.email_configurations.create({
                outlet_id,
                ...updateData
            });
        }

        res.json({ success: true, data: config });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.testEmail = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id;
        const {
            to_email,
            smtp_host,
            smtp_port,
            smtp_user,
            smtp_pass,
            sender_name,
            security_type,
            provider_type,
            gmail_client_id,
            gmail_client_secret,
            gmail_refresh_token,
            resend_api_key
        } = req.body;

        if (!to_email) {
            return res.status(400).json({ success: false, message: 'Recipient email address is required' });
        }

        let provider = provider_type || 'SMTP';
        let user = smtp_user;
        let pass = smtp_pass;
        let host = smtp_host || 'smtp.gmail.com';
        let port = Number(smtp_port) || 587;
        let fromName = sender_name || 'Retail POS';
        let clientId = gmail_client_id;
        let clientSecret = gmail_client_secret;
        let refreshToken = gmail_refresh_token;

        if (!user && !resend_api_key && outlet_id) {
            const config = await req.propertyDb.models.email_configurations.findOne({
                where: { outlet_id }
            });

            if (config) {
                provider = config.provider_type || 'SMTP';
                host = config.smtp_host || 'smtp.gmail.com';
                port = Number(config.smtp_port) || 587;
                user = config.smtp_user;
                pass = config.smtp_pass;
                fromName = config.from_name || 'Retail POS';
                clientId = config.gmail_client_id;
                clientSecret = config.gmail_client_secret;
                refreshToken = config.gmail_refresh_token;
            }
        }

        if (provider === 'GMAIL_OAUTH' || (clientId && refreshToken)) {
            console.log(`[TEST EMAIL] Testing via Gmail OAuth2 REST API (Port 443) for ${user}...`);
            const emailService = require('../../services/email.service');
            await emailService.sendViaGmailOAuthApi({
                clientId: clientId,
                clientSecret: clientSecret,
                refreshToken: refreshToken,
                user: user,
                fromName: fromName,
                to: to_email,
                subject: 'Test Email from Retail POS',
                htmlContent: '<h3>Email Configuration Test</h3><p>Hello, this is a test email confirming that your Gmail OAuth2 parameters are working properly on your POS system over HTTPS Port 443.</p>'
            });
            return res.json({ success: true, message: 'Test email sent successfully via Gmail OAuth2 REST API! Please check recipient inbox.' });
        }

        console.log(`[TEST EMAIL] Testing via SMTP ${host}:${port} for ${user}...`);
        const isSecure = port === 465 || (security_type && String(security_type).includes('465'));
        const transporter = nodemailer.createTransport({
            host: host,
            port: Number(port),
            secure: isSecure,
            auth: {
                user: user,
                pass: pass
            },
            tls: { rejectUnauthorized: false }
        });

        const mailOptions = {
            from: `"${fromName}" <${user}>`,
            to: to_email,
            subject: 'Test Email from Retail POS',
            text: 'Hello, this is a test email confirming that email configuration parameters are working properly.',
            html: '<h3>Email Configuration Test</h3><p>Hello, this is a test email confirming that email configuration parameters are working properly on your POS system.</p>'
        };

        await transporter.sendMail(mailOptions);
        res.json({ success: true, message: 'Test email sent successfully! Please check recipient inbox.' });
    } catch (err) {
        console.error('[TEST EMAIL ERROR]', err);
        res.status(500).json({ success: false, message: `Email test failed: ${err.message}` });
    }
};

exports.listTemplates = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const templates = await req.propertyDb.models.email_templates.findAll({
            where: { outlet_id }
        });
        res.json({ success: true, data: templates });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveTemplate = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { template_type, subject, body_html, is_active } = req.body;

        let template = await req.propertyDb.models.email_templates.findOne({
            where: { outlet_id, template_type }
        });

        if (template) {
            await template.update({ subject, body_html, is_active });
        } else {
            template = await req.propertyDb.models.email_templates.create({
                outlet_id,
                template_type,
                subject,
                body_html,
                is_active: is_active ?? true
            });
        }

        res.json({ success: true, data: template });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};
