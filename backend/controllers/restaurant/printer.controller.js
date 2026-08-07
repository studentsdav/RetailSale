const audit = require('../../services/audit.service');

exports.listPrinters = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const printers = await req.propertyDb.models.restaurant_printers.findAll({
            where: { outlet_id },
            order: [['printer_name', 'ASC']]
        });
        res.json({ success: true, data: printers });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createPrinter = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { printer_name, printer_type, ip_address, port, status } = req.body;
        const printer = await req.propertyDb.models.restaurant_printers.create({
            outlet_id,
            printer_name,
            printer_type: printer_type || 'NETWORK',
            ip_address,
            port,
            status: status || 'ACTIVE'
        });
        res.json({ success: true, data: printer });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updatePrinter = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { printer_name, printer_type, ip_address, port, status } = req.body;
        const printer = await req.propertyDb.models.restaurant_printers.findOne({ where: { id, outlet_id } });
        if (!printer) return res.status(404).json({ success: false, message: 'Printer not found' });

        await printer.update({ printer_name, printer_type, ip_address, port, status });
        res.json({ success: true, data: printer });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.deletePrinter = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const printer = await req.propertyDb.models.restaurant_printers.findOne({ where: { id, outlet_id } });
        if (!printer) return res.status(404).json({ success: false, message: 'Printer not found' });

        await printer.destroy();
        res.json({ success: true, message: 'Printer deleted successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.listKitchenStations = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const stations = await req.propertyDb.models.kitchen_stations.findAll({
            where: { outlet_id },
            include: [{ model: req.propertyDb.models.restaurant_printers, as: 'printer', attributes: ['printer_name'] }],
            order: [['station_name', 'ASC']]
        });
        res.json({ success: true, data: stations });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createKitchenStation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { station_name, printer_id, status } = req.body;
        const station = await req.propertyDb.models.kitchen_stations.create({
            outlet_id,
            station_name,
            printer_id,
            status: status || 'ACTIVE'
        });
        res.json({ success: true, data: station });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateKitchenStation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { station_name, printer_id, status } = req.body;
        const station = await req.propertyDb.models.kitchen_stations.findOne({ where: { id, outlet_id } });
        if (!station) return res.status(404).json({ success: false, message: 'Kitchen Station not found' });

        await station.update({ station_name, printer_id, status });
        res.json({ success: true, data: station });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.deleteKitchenStation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const station = await req.propertyDb.models.kitchen_stations.findOne({ where: { id, outlet_id } });
        if (!station) return res.status(404).json({ success: false, message: 'Kitchen Station not found' });

        await station.destroy();
        res.json({ success: true, message: 'Kitchen Station deleted successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};
