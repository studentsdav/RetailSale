const { sendToGoogleScript } = require("../../modules/driveService");
const sysConfig = require('../../utils/configManager');


const SHEET_ID = sysConfig ? sysConfig.sheetId : null;



// In-memory cache for verified licenses: outletCode -> { data, timestamp }
const licenseCache = new Map();
const LICENSE_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour cache

async function verifyLicenseOnline(outletCode) {
    if (!outletCode) {
        return { license_status: 'EXPIRED', days_remaining: 0 };
    }

    // Check memory cache first to eliminate repetitive cloud network round trips
    const cached = licenseCache.get(outletCode);
    if (cached && (Date.now() - cached.timestamp < LICENSE_CACHE_TTL_MS)) {
        return cached.data;
    }

    try {
        // Enforce a strict 2-second timeout so a slow cloud script cannot hang user login
        const timeoutPromise = new Promise((_, reject) =>
            setTimeout(() => reject(new Error("LICENSE_CHECK_TIMEOUT")), 2000)
        );

        const fetchPromise = sendToGoogleScript({
            action: 'check_license',
            sheetId: SHEET_ID,
            outletCode: outletCode
        });

        const res = await Promise.race([fetchPromise, timeoutPromise]);

        const rawStatus = res.license_status ? String(res.license_status).trim().toUpperCase() : 'UNKNOWN';

        if (rawStatus !== 'ACTIVE' || !res.expiry_date) {
            const expiredResult = { license_status: 'EXPIRED', days_remaining: 0 };
            licenseCache.set(outletCode, { data: expiredResult, timestamp: Date.now() });
            return expiredResult;
        }

        const currentDate = new Date();
        const expiryDate = new Date(res.expiry_date);

        if (isNaN(expiryDate.getTime())) {
            const expiredResult = { license_status: 'EXPIRED', days_remaining: 0 };
            licenseCache.set(outletCode, { data: expiredResult, timestamp: Date.now() });
            return expiredResult;
        }

        const daysRemaining = Math.ceil((expiryDate.getTime() - currentDate.getTime()) / (1000 * 60 * 60 * 24));

        let licenseState = 'VALID';
        if (daysRemaining <= 0) {
            licenseState = 'EXPIRED';
        } else if (daysRemaining <= 10) {
            licenseState = 'WARNING';
        }

        const result = {
            license_status: licenseState,
            days_remaining: daysRemaining
        };

        licenseCache.set(outletCode, { data: result, timestamp: Date.now() });
        return result;

    } catch (error) {
        // If timed out or offline, fall back to cached data if available, or return valid offline status
        if (cached) {
            return cached.data;
        }
        throw new Error("OFFLINE");
    }
}

module.exports = { verifyLicenseOnline };
export default { verifyLicenseOnline };