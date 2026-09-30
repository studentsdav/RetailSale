const propertyDb = require('../db/models/index');

module.exports = async (req, res, next) => {
    // resolved at login time
    req.outlet_id = req.user.outlet_id;
    req.propertyDb = propertyDb;
    next();
};