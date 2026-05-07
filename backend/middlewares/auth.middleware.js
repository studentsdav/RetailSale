const jwt = require('../utils/jwt.util');

module.exports = (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        if (!token) {
            return res.status(401).json({
                success: false,
                message: "No token provided"
            });
        }

        // If the token is invalid/expired, this line will throw an error and jump to the catch block
        const data = jwt.verify(token);

        req.user = data;
        req.outlet_id = data.outlet_id;
        req.outlet_code = data.outlet_code;
        next();

    } catch (error) {
        // 🚨 Catch the JWT error safely!
        console.error("JWT Verification Failed:", error.message);

        return res.status(401).json({
            success: false,
            // Tell Flutter exactly what went wrong
            error: error.name === 'TokenExpiredError' ? 'SESSION_EXPIRED' : 'INVALID_TOKEN',
            message: "Session expired or invalid. Please log in again."
        });
    }
};