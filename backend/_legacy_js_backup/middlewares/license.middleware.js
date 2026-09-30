const fs = require('fs');
const path = require('path');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const LICENSE_PATH = path.join(rootDir, 'license.key');

function loadLicense() {
    if (!fs.existsSync(LICENSE_PATH)) {
        throw new Error('LICENSE_FILE_MISSING');
    }

    try {
        return JSON.parse(fs.readFileSync(LICENSE_PATH, 'utf8'));
    } catch (e) {
        throw new Error('INVALID_LICENSE_FORMAT');
    }
}

function isExpired(validTill) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const expiry = new Date(validTill);
    expiry.setHours(23, 59, 59, 999);

    return today > expiry;
}

// ✅ EXPORT A FUNCTION (IMPORTANT)
module.exports = function license(requiredModule) {
    return (req, res, next) => {
        try {
            const licenseData = loadLicense();

            if (isExpired(licenseData.valid_till)) {
                return res.status(403).json({
                    success: false,
                    code: 'LICENSE_EXPIRED',
                    message: 'License expired'
                });
            }

            if (
                requiredModule &&
                Array.isArray(licenseData.modules) &&
                !licenseData.modules.includes(requiredModule)
            ) {
                return res.status(403).json({
                    success: false,
                    code: 'MODULE_NOT_LICENSED',
                    message: `${requiredModule} module not licensed`
                });
            }

            req.license = licenseData;
            next();

        } catch (err) {
            console.log(err.message);
            console.log(err);
            return res.status(403).json({
                success: false,
                code: err.message,
                message: 'License validation failed'
            });
        }
    };
};
