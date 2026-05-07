const bcrypt = require("bcryptjs");
const { sendOtpEmail } = require("./emailService");
const { sendUsernameRecoveryEmail } = require("./emailService");


// Key format: "outletCode_username" -> Value: { otp: "123456", expiresAt: 123456789 }
const resetOtpStore = new Map();

// Helper to mask email (e.g., admin@hotel.com -> a***n@hotel.com)
function maskEmail(email) {
    if (!email) return "";
    const [name, domain] = email.split("@");
    if (!name || !domain) return email;
    if (name.length <= 2) return `*@${domain}`;
    return `${name[0]}***${name[name.length - 1]}@${domain}`;
}

// ============================================================================
// 1. REQUEST OTP FOR PASSWORD RESET
// ============================================================================
exports.requestPasswordResetOtp = async (req, res) => {
    const { outletCode, username } = req.body;

    try {
        if (!outletCode || !username) {
            return res.status(400).json({
                success: false,
                message: "Outlet Code and Username are required."
            });
        }

        // 1. Find the outlet in the local database to get the secure registered email
        const outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: outletCode, is_active: true }
        });

        if (!outlet) {
            return res.status(404).json({ success: false, message: "Invalid or inactive Outlet Code." });
        }

        if (!outlet.contact_email) {
            return res.status(400).json({
                success: false,
                message: "No registered email found for this outlet. Cannot perform OTP recovery."
            });
        }

        // 2. Verify the user actually exists in this outlet
        const user = await req.propertyDb.models.users.findOne({
            where: { username: username, outlet_id: outlet.id, is_active: true }
        });

        if (!user) {
            return res.status(404).json({
                success: false,
                message: "Username does not exist for this outlet."
            });
        }

        // 3. Spam Prevention: 2-minute cooldown
        const storeKey = `${outletCode}_${username}`.toLowerCase();
        const existingRecord = resetOtpStore.get(storeKey);

        if (existingRecord) {
            const timeSinceLast = Date.now() - existingRecord.issuedAt;
            if (timeSinceLast < 120000) { // 2 minutes
                const waitSecs = Math.ceil((120000 - timeSinceLast) / 1000);
                throw new Error(`Please wait ${waitSecs} seconds before requesting a new OTP.`);
            }
        }

        // 4. Generate 6-digit OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

        // 5. Store OTP in memory (Valid for 10 minutes)
        resetOtpStore.set(storeKey, {
            otp: otpCode,
            expiresAt: Date.now() + 600000, // 10 mins
            issuedAt: Date.now()
        });

        // 6. Send Email using the emailService
        await sendOtpEmail(
            outlet.contact_email,
            otpCode,
            `Password Reset Request for ${username}`
        );

        const maskedEmail = maskEmail(outlet.contact_email);

        res.json({
            success: true,
            message: `OTP sent successfully to ${maskedEmail}. Please check your inbox.`
        });

    } catch (error) {
        console.error(`[PWD_RECOVERY] OTP Request Error: ${error.message}`);
        res.status(400).json({ success: false, message: error.message });
    }
};

// ============================================================================
// 2. VERIFY OTP & RESET PASSWORD
// ============================================================================
exports.resetPasswordWithOtp = async (req, res) => {

    const { outletCode, username, otp, newPassword } = req.body;

    try {
        if (!outletCode || !username || !otp || !newPassword) {
            return res.status(400).json({
                success: false,
                message: "Outlet Code, Username, OTP, and New Password are required."
            });
        }

        if (newPassword.length < 8) {
            return res.status(400).json({
                success: false,
                message: "New password must be at least 8 characters long."
            });
        }

        const storeKey = `${outletCode}_${username}`.toLowerCase();
        const storedRecord = resetOtpStore.get(storeKey);

        // 1. Validate OTP existence
        if (!storedRecord) {
            return res.status(400).json({
                success: false,
                message: "No active password reset request found. Please request a new OTP."
            });
        }

        // 2. Validate OTP Expiry
        if (Date.now() > storedRecord.expiresAt) {
            resetOtpStore.delete(storeKey);
            return res.status(400).json({
                success: false,
                message: "This OTP has expired. Please request a new one."
            });
        }

        // 3. Validate OTP Match
        if (storedRecord.otp !== otp.toString().trim()) {
            return res.status(401).json({
                success: false,
                message: "Invalid OTP code."
            });
        }

        // 4. Find the user in the database
        const outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: outletCode }
        });

        const user = await req.propertyDb.models.users.findOne({
            where: { username: username, outlet_id: outlet.id }
        });

        if (!user) {
            return res.status(404).json({ success: false, message: "User not found." });
        }

        // 5. Hash the new password and update the database
        const newHash = await bcrypt.hash(newPassword, 10);

        await user.update({
            password_hash: newHash
        });

        // 6. Clear the OTP so it cannot be reused
        resetOtpStore.delete(storeKey);

        console.log(`[PWD_RECOVERY] Password successfully reset for ${username} at ${outletCode}`);

        res.json({
            success: true,
            message: "Password has been reset successfully. You can now log in."
        });

    } catch (error) {
        console.error(`[PWD_RECOVERY] Reset Execution Error: ${error.message}`);
        res.status(500).json({ success: false, message: "An error occurred while resetting the password." });
    }
};

exports.recoverUsername = async (req, res) => {
    const { outletCode, email } = req.body;

    try {
        if (!outletCode || !email) {
            return res.status(400).json({
                success: false,
                message: "Outlet Code and Email are required."
            });
        }

        // 1. Verify the Outlet and Email match exactly in your local DB
        const outlet = await req.propertyDb.models.outlets.findOne({
            where: {
                outlet_code: outletCode,
                is_active: true
            }
        });

        if (!outlet) {
            return res.status(404).json({
                success: false,
                message: "Selected outlet was not found."
            });
        }

        if (!outlet.contact_email) {
            return res.status(400).json({
                success: false,
                message: "No registered email is saved for this outlet."
            });
        }

        if (outlet.contact_email.toLowerCase() !== email.toLowerCase().trim()) {
            return res.status(404).json({
                success: false,
                message: "Entered email is wrong. Please enter the current registered email for this outlet."
            });
        }

        // 3. Find all active users under this outlet
        const users = await req.propertyDb.models.users.findAll({
            where: {
                outlet_id: outlet.id,
                is_active: true
            },
            attributes: ['username'] // Only grab the usernames to save memory
        });

        if (users.length === 0) {
            return res.status(404).json({
                success: false,
                message: "No active usernames were found for this outlet."
            });
        }

        // Extract just the username strings into an array
        const usernameArray = users.map(u => u.username);

        // 4. Send the email
        await sendUsernameRecoveryEmail(outlet.contact_email, usernameArray, outlet.outlet_name);

        const maskedEmail = maskEmail(outlet.contact_email);

        res.json({
            success: true,
            message: `Your usernames have been sent to ${maskedEmail}.`
        });

    } catch (error) {
        console.error(`[USERNAME_RECOVERY] Error: ${error.message}`);
        res.status(500).json({ success: false, message: "An error occurred processing your request." });
    }
};
