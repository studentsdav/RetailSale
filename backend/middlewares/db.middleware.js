const propertyDb = require('../db/models');

module.exports = async (req, res, next) => {
    try {
        req.propertyDb = propertyDb;
        next();
    } catch (err) {
        console.error('DB Middleware Error:', err);
        res.status(500).json({
            success: false,
            message: 'Database connection failed'
        });
    }
};
