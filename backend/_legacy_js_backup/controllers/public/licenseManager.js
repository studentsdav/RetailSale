const { sendToGoogleScript } = require("../../modules/driveService");
const sysConfig = require('../../utils/configManager');


const SHEET_ID = sysConfig ? sysConfig.sheetId : null;



async function verifyLicenseOnline(outletCode) {

    if (!outletCode) {
        return { license_status: 'EXPIRED', days_remaining: 0 };
    }

    try {
        const res = await sendToGoogleScript({
            action: 'check_license',
            sheetId: SHEET_ID,
            outletCode: outletCode
        });

        const rawStatus = res.license_status ? String(res.license_status).trim().toUpperCase() : 'UNKNOWN';

        if (rawStatus !== 'ACTIVE' || !res.expiry_date) {
            return { license_status: 'EXPIRED', days_remaining: 0 };
        }
        const currentDate = new Date();
        const expiryDate = new Date(res.expiry_date);

        if (isNaN(expiryDate.getTime())) {
            return { license_status: 'EXPIRED', days_remaining: 0 };
        }


        const daysRemaining = Math.ceil((expiryDate - currentDate) / (1000 * 60 * 60 * 24));

        let licenseState = 'VALID';

        if (daysRemaining <= 0) {

            licenseState = 'EXPIRED';
        } else if (daysRemaining <= 10) {

            licenseState = 'WARNING';
        } else {
            console.log("DEBUG: License is fully VALID.");
        }

        return {
            license_status: licenseState,
            days_remaining: daysRemaining
        };

    } catch (error) {
        throw new Error("OFFLINE");
    }
}

module.exports = { verifyLicenseOnline };