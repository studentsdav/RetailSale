module.exports = async (req, res, next) => {
    // resolved at login time
    req.outlet_id = req.user.outlet_id;
    req.propertyDb = getPropertyDb(req.user.property_db);
    next();
};