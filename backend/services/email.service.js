const nodemailer = require('nodemailer');

/**
 * Helper service to send email via database-configured SMTP credentials
 * @param {Object} db Sequelize instance
 * @param {Number} outlet_id Target outlet ID
 * @param {String} to Recipient email address
 * @param {String} subject Subject line
 * @param {String} text Plain text body
 * @param {String} html HTML body
 * @param {Array} attachments Attachment arrays formatted for Nodemailer
 */
exports.sendMail = async ({ db, outlet_id, to, subject, text, html, attachments }) => {
    try {
        const config = await db.models.email_configurations.findOne({
            where: { outlet_id, is_active: true }
        });

        if (!config) {
            console.warn(`[EMAIL] No active SMTP configuration found for outlet: ${outlet_id}`);
            return false;
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
            to,
            subject,
            text,
            html,
            attachments
        };

        const info = await transporter.sendMail(mailOptions);
        console.log(`[EMAIL] Message sent to ${to}: ${info.messageId}`);
        return true;
    } catch (error) {
        console.error(`[EMAIL] Error sending email to ${to}:`, error);
        return false;
    }
};
