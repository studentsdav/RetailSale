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
        const { smtp_host, smtp_port, smtp_user, smtp_pass, encryption_type, from_name, from_email, is_active } = req.body;

        let config = await req.propertyDb.models.email_configurations.findOne({
            where: { outlet_id }
        });

        if (config) {
            await config.update({
                smtp_host,
                smtp_port,
                smtp_user,
                smtp_pass,
                encryption_type,
                from_name,
                from_email,
                is_active
            });
        } else {
            config = await req.propertyDb.models.email_configurations.create({
                outlet_id,
                smtp_host,
                smtp_port,
                smtp_user,
                smtp_pass,
                encryption_type,
                from_name,
                from_email,
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
        const outlet_id = req.user.outlet_id;
        const { to_email } = req.body;

        const config = await req.propertyDb.models.email_configurations.findOne({
            where: { outlet_id, is_active: true }
        });

        if (!config) {
            return res.status(400).json({ success: false, message: 'Email configuration is inactive or not found' });
        }

        const transporter = nodemailer.createTransport({
            host: config.smtp_host,
            port: Number(config.smtp_port),
            secure: config.encryption_type === 'SSL',
            auth: {
                user: config.smtp_user,
                pass: config.smtp_pass
            }
        });

        const mailOptions = {
            from: `"${config.from_name || 'Retail POS'}" <${config.from_email}>`,
            to: to_email,
            subject: 'Test Email from Retail POS',
            text: 'Hello, this is a test email confirming that SMTP is working properly.',
            html: '<p>Hello, this is a test email confirming that SMTP is working properly.</p>'
        };

        await transporter.sendMail(mailOptions);
        res.json({ success: true, message: 'Test email sent successfully' });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
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
