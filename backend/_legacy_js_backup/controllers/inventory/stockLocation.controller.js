const audit = require('../../services/audit.service');

exports.createLocation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        const { location_code, location_name, description, is_active } = req.body;

        const location = await req.propertyDb.models.stock_locations.create({
            outlet_id,
            location_code,
            location_name,
            description,
            is_active
        });

        await audit.log({
            req,
            module: 'STOCK_LOCATION',
            action: 'CREATE',
            table: 'stock_locations',
            recordId: location.id,
            old_data: {},
            new_data: location.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        res.json({ success: true, data: location });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.getLocations = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { q } = req.query;

        const where = { outlet_id };

        if (q) {
            where.$or = [
                { location_code: { $iLike: `%${q}%` } },
                { location_name: { $iLike: `%${q}%` } }
            ];
        }

        const locations = await req.propertyDb.models.stock_locations.findAll({
            where,
            order: [['location_name', 'ASC']]
        });

        res.json({ success: true, data: locations });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.getLocationById = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const id = req.params.id;

        const location = await req.propertyDb.models.stock_locations.findOne({
            where: { id, outlet_id }
        });

        if (!location) {
            return res.status(404).json({ success: false });
        }

        res.json({ success: true, data: location });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.updateLocation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const id = req.params.id;

        const location = await req.propertyDb.models.stock_locations.findOne({
            where: { id, outlet_id }
        });

        if (!location) {
            return res.status(404).json({ success: false });
        }

        const oldData = location.toJSON();

        await location.update(req.body);



        await audit.log({
            req,
            module: 'STOCK_LOCATION',
            action: 'UPDATE',
            table: 'stock_locations',
            recordId: location.id,
            old_data: oldData,
            new_data: location.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        res.json({ success: true, data: location });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.deleteLocation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const id = req.params.id;

        const location = await req.propertyDb.models.stock_locations.findOne({
            where: { id, outlet_id }
        });

        if (!location) {
            return res.status(404).json({ success: false });
        }

        await location.update({ is_active: false });

        await audit.log({
            req,
            module: 'STOCK_LOCATION',
            action: 'DEACTIVATE',
            table: 'stock_locations',
            recordId: location.id,
            old_data: { is_active: true },
            new_data: { is_active: false },
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, message: 'Location deactivated' });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.getNextLocationCode = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const last = await req.propertyDb.models.stock_locations.findOne({
            where: { outlet_id },
            order: [['id', 'DESC']], // IMPORTANT: id, not code
            attributes: ['location_code'],
        });

        let nextNum = 1;

        if (last?.location_code) {
            const num = parseInt(last.location_code.replace(/[^\d]/g, '')) || 0;
            nextNum = num + 1;
        }

        res.json({
            success: true,
            data: `loc${nextNum}`,
        });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
