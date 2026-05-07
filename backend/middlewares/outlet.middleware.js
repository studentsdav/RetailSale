module.exports = async (req, res, next) => {
    const outlet = await req.propertyDb.models.outlets.findOne({
        where: { is_active: true }
    });

    if (!outlet) {
        return res.status(412).json({
            success: false,
            code: 'OUTLET_NOT_CONFIGURED',
            message: 'Outlet not configured'
        });
    }

    req.outlet = outlet;
    next();
};
