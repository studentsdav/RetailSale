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
        const { smtp_host, smtp_port, smtp_user, smtp_pass, encryption_type, from_name, from_email, sender_name, security_type, is_active } = req.body;

        const effectiveFromEmail = from_email || smtp_user;
        const effectiveFromName = from_name || sender_name || 'Retail POS';
        const effectiveEncryption = encryption_type || security_type || 'STARTTLS';

        let config = await req.propertyDb.models.email_configurations.findOne({
            where: { outlet_id }
        });

        if (config) {
            await config.update({
                smtp_host,
                smtp_port,
                smtp_user,
                smtp_pass,
                encryption_type: effectiveEncryption,
                from_name: effectiveFromName,
                from_email: effectiveFromEmail,
                is_active: is_active ?? true
            });
        } else {
            config = await req.propertyDb.models.email_configurations.create({
                outlet_id,
                smtp_host,
                smtp_port,
                smtp_user,
                smtp_pass,
                encryption_type: effectiveEncryption,
                from_name: effectiveFromName,
                from_email: effectiveFromEmail,
                is_active: is_active ?? true
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
        const { to_email, smtp_host, smtp_port, smtp_user, smtp_pass, sender_name, security_type } = req.body;

        let host = smtp_host;
        let port = Number(smtp_port) || 587;
        let user = smtp_user;
        let pass = smtp_pass;
        let fromName = sender_name || 'Retail POS';

        if (!host || !user) {
            const config = await req.propertyDb.models.email_configurations.findOne({
                where: { outlet_id }
            });

            if (!config) {
                return res.status(400).json({ success: false, message: 'Email configuration is inactive or not found' });
            }
            host = config.smtp_host;
            port = Number(config.smtp_port) || 587;
            user = config.smtp_user;
            pass = config.smtp_pass;
            fromName = config.from_name || 'Retail POS';
        }

        if (!to_email) {
            return res.status(400).json({ success: false, message: 'Recipient email address is required' });
        }

        const isSecure = port === 465 || (security_type && String(security_type).includes('465'));
        const transporter = nodemailer.createTransport({
            host: host,
            port: Number(port),
            secure: isSecure,
            auth: {
                user: user,
                pass: pass
            },
            tls: {
                rejectUnauthorized: false
            }
        });

        const mailOptions = {
            from: `"${fromName}" <${user}>`,
            to: to_email,
            subject: 'Test Email from Retail POS',
            text: 'Hello, this is a test email confirming that SMTP parameters are working properly.',
            html: '<h3>SMTP Configuration Test</h3><p>Hello, this is a test email confirming that SMTP parameters are working properly on your POS system.</p>'
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
