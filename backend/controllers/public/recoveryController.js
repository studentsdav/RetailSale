const fs = require("fs");
const path = require("path");
const bcrypt = require("bcryptjs");
const { sendToGoogleScript } = require("../../modules/driveService");
const { downloadSystemConfigs } = require("../../modules/updownconfig");
const { autoRestoreLatest } = require("../../modules/restore");
const sysConfig = require('../../utils/configManager');
const https = require('https');
const { spawn } = require('child_process');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const SHEET_ID = sysConfig ? sysConfig.sheetId : null;
const ROOT_FOLDER_ID = sysConfig ? sysConfig.rootFolderId : null;

const CLIENT_FILE = path.join(rootDir, "client.json");
const { sendOtpEmail } = require("../../modules/emailService");
const { sendOutletRecoveryEmail } = require("../../modules/emailService");

const OTP_STORE_FILE = path.join(rootDir, "data", "otp_store.json");

function normalizeValue(value) {
    return value ? value.toString().trim().toLowerCase() : "";
}

function readOtpStore() {
    try {
        if (!fs.existsSync(OTP_STORE_FILE)) {
            return {};
        }

        const raw = fs.readFileSync(OTP_STORE_FILE, "utf8");
        const parsed = JSON.parse(raw);
        return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch (error) {
        console.error(`[RECOVERY] OTP store read failed: ${error.message}`);
        return {};
    }
}

function writeOtpStore(store) {
    fs.mkdirSync(path.dirname(OTP_STORE_FILE), { recursive: true });
    fs.writeFileSync(OTP_STORE_FILE, JSON.stringify(store, null, 2));
}

function pruneExpiredOtps(store) {
    const now = Date.now();
    for (const [key, record] of Object.entries(store)) {
        if (!record || !record.expiresAt || now > record.expiresAt) {
            delete store[key];
        }
    }
}

function findStoredOtp(store, outletCode, contactStr) {
    const normalizedOutletCode = normalizeValue(outletCode);
    const normalizedContactStr = normalizeValue(contactStr);

    for (const [emailKey, record] of Object.entries(store)) {
        const recordOutletCode = normalizeValue(record && record.outletCode);
        const recordContactStr = normalizeValue(record && record.contactStr);
        const recordEmail = normalizeValue(record && (record.targetEmail || emailKey));

        if (
            (normalizedOutletCode && recordOutletCode === normalizedOutletCode) ||
            (normalizedContactStr && (
                recordContactStr === normalizedContactStr ||
                recordEmail === normalizedContactStr ||
                normalizeValue(emailKey) === normalizedContactStr
            ))
        ) {
            return { emailKey, record };
        }
    }

    return { emailKey: "", record: null };
}
/**
 * STEP 1: Verifies the Outlet Code AND the Recovery PIN
 */
async function verifyOutletForRecovery(req, res) {
    const { outletCode, pin } = req.body;

    if (!outletCode || !pin) {
        return res.status(400).json({
            success: false,
            message: "Both Outlet Code and Recovery PIN are required."
        });
    }

    try {
        console.log(`[RECOVERY] Requesting cloud verification for: ${outletCode}...`);

        const response = await sendToGoogleScript({
            action: 'verify_and_get_client',
            rootFolderId: ROOT_FOLDER_ID,
            sheetId: SHEET_ID,
            outletCode: outletCode
        });

        // 1. Verify the PIN against the hashed PIN from the cloud
        const storedHash = response.client.recovery_pin_hash;
        if (!storedHash) {
            throw new Error("Security Error: This outlet does not have a valid Recovery PIN configured. Please contact support.");
        }

        const isPinValid = await bcrypt.compare(pin.toString(), storedHash);
        if (!isPinValid) {
            return res.status(401).json({
                success: false,
                message: "Authentication Failed: Incorrect Recovery PIN."
            });
        }

        console.log(`[RECOVERY] PIN verified successfully for ${outletCode}.`);

        // 2. Strip the hash before sending the payload back to the Flutter UI
        delete response.client.recovery_pin_hash;

        return res.json({
            success: true,
            message: `Identity verified. Ready to restore data for ${response.client.property_name}.`,
            folderId: response.folderId,
            clientData: response.client
        });

    } catch (error) {
        console.error(`[RECOVERY] Verification failed: ${error.message}`);
        return res.status(400).json({ success: false, message: error.message });
    }
}

/**
 * STEP 2: Executes the Restore and Saves Extended Config
 */
async function executeFullSystemRecovery(req, res) {
    const { folderId, clientData } = req.body;

    try {
        console.log(`[RECOVERY] Executing system restore for: ${clientData.outlet_code}`);

        // 1. Read existing configuration safely
        let clients = [];
        if (fs.existsSync(CLIENT_FILE)) {
            try {
                const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
                clients = JSON.parse(fileData);
                if (!Array.isArray(clients)) {
                    clients = [clients];
                }
            } catch (err) {
                console.error("[RECOVERY] Existing client.json is corrupted. Rebuilding array.");
                clients = [];
            }
        }

        // 2. Rebuild the restored client object WITH new enterprise fields
        const restoredClientObj = {
            client_id: clientData.client_id,
            folderId: folderId,
            outlet_code: clientData.outlet_code,
            outlet_id: clientData.outlet_id,
            property_name: clientData.property_name,
            db_name: clientData.db_name,
            status: clientData.status,

            // New Identity Fields synced from Google Sheets
            contact_email: clientData.contact_email || "",
            contact_phone: clientData.contact_phone || "",
            tax_id: clientData.tax_id || ""
        };

        // 3. Upsert the restored client into the array
        const clientIndex = clients.findIndex(c => c.outlet_code === restoredClientObj.outlet_code);
        if (clientIndex >= 0) {
            clients[clientIndex] = restoredClientObj;
        } else {
            clients.push(restoredClientObj);
        }

        fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2));
        console.log(`[RECOVERY] Local client.json configuration updated.`);

        // 4. Download external dependencies and restore database
        await downloadSystemConfigs(folderId);
        await autoRestoreLatest(folderId);

        console.log("[RECOVERY] Sequence complete. Awaiting system restart.");

        res.json({
            success: true,
            message: "System recovered successfully!"
        });

    } catch (error) {
        console.error(`[RECOVERY] Critical Failure: ${error.message}`);

        res.status(500).json({
            success: false,
            message: "Restore failed: " + error.message
        });
    }
}

// ============================================================================
// OTP FALLBACK FUNCTIONS (To support your Flutter UI's "Forgot PIN / ID" flow)
// ============================================================================

async function requestRecoveryOtp(req, res) {
    const { outletCode, contactStr, isResend } = req.body;

    try {
        const otpStore = readOtpStore();
        pruneExpiredOtps(otpStore);

        let targetEmail = "";
        let targetOutletCode = outletCode || "";
        let matchedOutlets = [];
        let targetContact = contactStr || "";
        // Scenario A: User knows Outlet Code, forgot PIN
        if (outletCode) {
            const response = await sendToGoogleScript({
                action: 'verify_and_get_client',
                rootFolderId: ROOT_FOLDER_ID,
                sheetId: SHEET_ID,
                outletCode: outletCode
            });
            targetEmail = response.client.contact_email;
            if (!targetEmail) throw new Error("No recovery email is registered to this outlet.");
        }
        // Scenario B: User forgot Outlet Code, provided Email/Phone
        else if (contactStr) {
            const response = await sendToGoogleScript({
                action: 'lookup_outlet_by_contact',
                sheetId: SHEET_ID,
                contact: contactStr
            });
            matchedOutlets = response.outlets;
            targetEmail = matchedOutlets[0].contact_email;
            targetOutletCode = "";
        } else {
            throw new Error("Must provide either Outlet Code or Contact details.");
        }

        const emailKey = targetEmail.toLowerCase();

        // ---------------------------------------------------------
        // SPAM PREVENTION: 3-Minute Cooldown Check
        // ---------------------------------------------------------
        const existingRecord = otpStore[emailKey];
        if (existingRecord && isResend) {
            const timeSinceLastSent = Date.now() - existingRecord.lastSentAt;
            const cooldownMs = 3 * 60 * 1000; // 3 minutes in milliseconds

            if (timeSinceLastSent < cooldownMs) {
                const remainingSecs = Math.ceil((cooldownMs - timeSinceLastSent) / 1000);
                throw new Error(`Please wait ${remainingSecs} seconds before requesting a new OTP.`);
            }
        }

        // 1. Generate 6-digit OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

        // 2. Save OTP to memory
        otpStore[emailKey] = {
            otp: otpCode,
            outletCode: targetOutletCode,
            contactStr: targetContact,
            targetEmail,
            outlets: matchedOutlets,
            expiresAt: Date.now() + 600000, // Valid for 10 minutes
            lastSentAt: Date.now()          // Tracked for 3-minute cooldown
        };

        writeOtpStore(otpStore);

        // 3. Send Email
        await sendOtpEmail(targetEmail, otpCode, "System Recovery Verification");

        res.json({
            success: true,
            message: "OTP sent successfully. Please check your inbox."
        });

    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
}

async function verifyAndRecoverConfig(req, res) {
    try {
        const { outletCode, otp } = req.body;

        if (!outletCode) {
            return res.status(400).json({ success: false, message: "Outlet Code is required." });
        }
        if (!otp) {
            return res.status(400).json({ success: false, message: "OTP is required." });
        }

        console.log(`[RECOVERY] Verifying OTP for Outlet: ${outletCode}...`);

        const cloudResponse = await sendToGoogleScript({
            action: 'verify_and_get_client',
            rootFolderId: ROOT_FOLDER_ID,
            sheetId: SHEET_ID,
            outletCode: outletCode
        });

        if (!cloudResponse || !cloudResponse.client) {
            return res.status(404).json({ success: false, message: "Outlet not found in cloud records." });
        }

        const targetEmail = cloudResponse.client.contact_email;
        const folderId = cloudResponse.folderId;

        if (!targetEmail || !folderId) {
            return res.status(400).json({
                success: false,
                message: "Cloud record is incomplete (missing email or folder ID)."
            });
        }

        const otpStore = readOtpStore();
        pruneExpiredOtps(otpStore);
        const emailKey = targetEmail.toLowerCase();

        // 2. Verify the OTP from the persistent store
        const storedRecord = otpStore[emailKey];

        if (!storedRecord) {
            return res.status(401).json({
                success: false,
                message: "OTP expired or not requested. Please request a new one."
            });
        }

        if (Date.now() > storedRecord.expiresAt) {
            delete otpStore[emailKey]; // Clean up expired OTP immediately
            writeOtpStore(otpStore);
            return res.status(401).json({
                success: false,
                message: "OTP has expired. Please request a new one."
            });
        }

        if (storedRecord.otp !== otp) {
            return res.status(401).json({
                success: false,
                message: "Invalid OTP entered. Please try again."
            });
        }


        delete otpStore[emailKey];
        writeOtpStore(otpStore);
        console.log(`✅ [RECOVERY] OTP Verified! Downloading config.enc from Folder: ${folderId}`);

        const resEnc = await sendToGoogleScript({
            action: 'download_config',
            folderId: folderId,
            filename: "config.enc"
        });

        if (!resEnc || !resEnc.base64) {
            throw new Error("config.enc file is missing in the cloud backup.");
        }

        const configPath = path.join(rootDir, 'config.enc');

        fs.writeFileSync(configPath, Buffer.from(resEnc.base64, 'base64'));

        res.json({
            success: true,
            message: "System configuration recovered successfully! Please restart the System."
        });

    } catch (error) {
        console.error("[RECOVERY_ERROR]", error.message);
        res.status(500).json({
            success: false,
            message: error.message || "Failed to verify OTP or download configuration."
        });
    }
};



// ============================================================================
// 2. VERIFY OTP
// ============================================================================
async function verifyRecoveryOtp(req, res) {
    const { otp, contactStr, outletCode } = req.body;

    try {
        if (!otp) throw new Error("OTP code is required.");

        const otpStore = readOtpStore();
        pruneExpiredOtps(otpStore);
        const { emailKey: storedEmailKey, record: storedRecord } = findStoredOtp(
            otpStore,
            outletCode,
            contactStr
        );

        if (!storedRecord) {
            throw new Error("No active OTP request found. Please request a new code.");
        }

        // 1. Check if expired (past 10 minutes)
        if (Date.now() > storedRecord.expiresAt) {
            delete otpStore[storedEmailKey];
            writeOtpStore(otpStore);
            throw new Error("This OTP has expired. Please request a new one.");
        }

        // 2. Verify Code
        if (storedRecord.otp !== otp.toString().trim()) {
            throw new Error("Invalid OTP code. Please try again.");
        }

        // 3. Success! Delete it so it cannot be reused.
        delete otpStore[storedEmailKey];
        writeOtpStore(otpStore);

        if (storedRecord.outlets && storedRecord.outlets.length > 0) {

            // 1. Send the email with the list of their outlets
            await sendOutletRecoveryEmail(storedEmailKey, storedRecord.outlets);

            // 2. Return the list to Flutter for the Checkbox UI
            return res.json({
                success: true,
                message: "Outlets found! A backup copy has been sent to your email.",
                data: {
                    outlets: storedRecord.outlets,
                    verified_email: storedEmailKey
                }
            });
        }

        // ====================================================================
        // 4. CRITICAL FIX: Fetch the Folder ID from Google Drive!
        // ====================================================================
        console.log(`[OTP VERIFIED] Fetching cloud folder ID for ${storedRecord.outletCode || outletCode}...`);

        const response = await sendToGoogleScript({
            action: 'verify_and_get_client',
            rootFolderId: ROOT_FOLDER_ID,
            sheetId: SHEET_ID,
            outletCode: storedRecord.outletCode || outletCode
        });

        // Strip the pin hash before sending data back to the Flutter UI
        if (response.client && response.client.recovery_pin_hash) {
            delete response.client.recovery_pin_hash;
        }

        // 5. Return everything Flutter needs to execute the restore
        res.json({
            success: true,
            message: "Identity verified successfully.",
            folderId: response.folderId,
            clientData: response.client,
            data: {
                outlet_code: storedRecord.outletCode,
                verified_email: storedEmailKey
            }
        });

    } catch (error) {
        console.error(`[OTP VERIFY ERROR] ${error.message}`);
        res.status(400).json({ success: false, message: error.message });
    }
}


async function triggerAutoReinstall(req, res) {
    const localInstallerPath = path.join(rootDir, 'Inventory_Installer.exe');
    const onlineUrl = "https://wipl.net.in/hms/utility/Inventory_Installer.exe";
    const downloadDest = path.join(rootDir, 'Inventory_Installer_Downloaded.exe');

    // const launchInstaller = (exePath) => {
    //     // Added Inno Setup silent flags to hide the UI and suppress prompts
    //    // const silentArgs = ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'];

    //     const child = spawn(exePath, silentArgs, { detached: true, stdio: 'ignore' });
    //     child.unref();
    // };

    const launchInstaller = (exePath) => {
        // Run detached so Node doesn't block the installer from killing it!
        const child = spawn(exePath, [], { detached: true, stdio: 'ignore' });
        child.unref();
    };

    if (fs.existsSync(localInstallerPath)) {
        console.log("[RECOVERY] Local installer found. Launching silently...");
        res.json({ success: true, message: "Local installer found. Launching recovery in background..." });
        return launchInstaller(localInstallerPath);
    }

    console.log("[RECOVERY] Local installer missing. Downloading from online utility...");

    const file = fs.createWriteStream(downloadDest);

    https.get(onlineUrl, (response) => {
        if (response.statusCode !== 200) {
            return res.status(500).json({
                success: false,
                message: "Not possible to recover automatically. Please contact your provider or manually run Inventory_Installer.exe."
            });
        }

        response.pipe(file);

        file.on('finish', () => {
            file.close(() => {
                console.log("[RECOVERY] Download complete. Waiting for OS file lock release...");

                res.json({
                    success: true,
                    message: "Recovery tool downloaded. Running background repair..."
                });

                setTimeout(() => {
                    console.log("[RECOVERY] Launching installer silently...");
                    launchInstaller(downloadDest);
                }, 1000);
            });
        });

    }).on('error', (err) => {
        console.error("[RECOVERY_ERROR] Download failed:", err.message);
        fs.unlink(downloadDest, () => { });

        return res.status(500).json({
            success: false,
            message: "Not possible to recover automatically. Please contact your provider or manually run Inventory_Installer.exe."
        });
    });
}

module.exports = {
    verifyRecoveryOtp,
    verifyOutletForRecovery,
    executeFullSystemRecovery,
    requestRecoveryOtp,
    triggerAutoReinstall,
    verifyAndRecoverConfig
};
