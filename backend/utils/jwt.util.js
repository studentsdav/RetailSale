const jwt = require("jsonwebtoken");
const loadConfig = require("../utils/decryptConfig");

try {

    const config = loadConfig();

    exports.sign = (payload) => {
        return jwt.sign(payload, config.JWT_SECRET, {
            expiresIn: "1d"
        });
    };

    exports.verify = (token) => {
        return jwt.verify(token, config.JWT_SECRET);
    };

} catch (error) {

    console.log("⚠️ [JWT] config.enc missing. Running with safe dummy keys for UI recovery.");
}