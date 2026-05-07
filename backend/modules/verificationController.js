const { sendOtpEmail } = require("./emailService");


const setupOtpStore = new Map();

exports.requestSetupOtp = async (req, res) => {
    const { email } = req.body;

    try {
        if (!email || !email.includes("@")) {
            return res.status(400).json({ success: false, message: "Valid email is required." });
        }

        const emailKey = email.toLowerCase().trim();


        const existingRecord = setupOtpStore.get(emailKey);
        if (existingRecord) {
            const timeSinceLast = Date.now() - existingRecord.lastSentAt;
            if (timeSinceLast < 60000) {
                const waitSecs = Math.ceil((60000 - timeSinceLast) / 1000);
                throw new Error(`Please wait ${waitSecs} seconds before requesting a new code.`);
            }
        }


        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();


        setupOtpStore.set(emailKey, {
            otp: otpCode,
            expiresAt: Date.now() + 600000,
            lastSentAt: Date.now()
        });


        await sendOtpEmail(emailKey, otpCode, "Outlet Setup Verification");

        res.json({ success: true, message: "Verification code sent to your email." });

    } catch (error) {
        console.error(`[SETUP_VERIFY] Request Error: ${error.message}`);
        res.status(400).json({ success: false, message: error.message });
    }
};

// ============================================================================
// 2. VERIFY SETUP OTP
// ============================================================================
exports.verifySetupOtp = async (req, res) => {
    const { email, otp } = req.body;

    try {
        if (!email || !otp) {
            return res.status(400).json({ success: false, message: "Email and OTP are required." });
        }

        const emailKey = email.toLowerCase().trim();
        const storedRecord = setupOtpStore.get(emailKey);

        if (!storedRecord) {
            return res.status(400).json({ success: false, message: "No active verification request found for this email." });
        }

        if (Date.now() > storedRecord.expiresAt) {
            setupOtpStore.delete(emailKey);
            return res.status(400).json({ success: false, message: "This code has expired. Please request a new one." });
        }

        if (storedRecord.otp !== otp.toString().trim()) {
            return res.status(401).json({ success: false, message: "Invalid verification code." });
        }

        setupOtpStore.delete(emailKey);

        res.json({ success: true, message: "Email verified successfully." });

    } catch (error) {
        console.error(`[SETUP_VERIFY] Verify Error: ${error.message}`);
        res.status(500).json({ success: false, message: "An error occurred during verification." });
    }
};