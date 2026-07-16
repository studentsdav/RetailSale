const Sequelize = require('sequelize');

exports.listSaleSources = async (req, res) => {
    try {
        const sources = await req.propertyDb.models.sale_sources.findAll({
            order: [['is_system', 'DESC'], ['name', 'ASC']]
        });
        res.json({ success: true, data: sources });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createSaleSource = async (req, res) => {
    try {
        const { name, commission_rate, gst_rate_on_commission, tds_rate, tcs_rate } = req.body;
        if (!name || name.trim().length === 0) {
            return res.status(400).json({ success: false, message: 'Name is required' });
        }
        const trimmedName = name.trim();
        const existing = await req.propertyDb.models.sale_sources.findOne({
            where: { name: trimmedName }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Source already exists' });
        }
        const created = await req.propertyDb.models.sale_sources.create({
            name: trimmedName,
            is_system: false,
            is_active: true,
            commission_rate: parseFloat(commission_rate || 0),
            gst_rate_on_commission: parseFloat(gst_rate_on_commission || 0),
            tds_rate: parseFloat(tds_rate || 0),
            tcs_rate: parseFloat(tcs_rate || 0)
        });
        res.json({ success: true, data: created });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateSaleSource = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, is_active, commission_rate, gst_rate_on_commission, tds_rate, tcs_rate } = req.body;
        const source = await req.propertyDb.models.sale_sources.findByPk(id);
        if (!source) {
            return res.status(404).json({ success: false, message: 'Source not found' });
        }
        if (source.is_system) {
            return res.status(400).json({ success: false, message: 'System sources cannot be modified' });
        }
        
        const trimmedName = name ? name.trim() : source.name;
        const nameChanged = trimmedName !== source.name;

        if (nameChanged) {
            // Check if any bills are made with this source name
            const usedInBills = await req.propertyDb.models.sales_headers.findOne({
                where: { sale_source: source.name }
            });
            if (usedInBills) {
                return res.status(400).json({ success: false, message: 'Cannot edit source name as it has already been used in sales' });
            }

            const existing = await req.propertyDb.models.sale_sources.findOne({
                where: { name: trimmedName }
            });
            if (existing) {
                return res.status(400).json({ success: false, message: 'Source name already exists' });
            }
        }

        await source.update({
            name: trimmedName,
            is_active: is_active !== undefined ? is_active : source.is_active,
            commission_rate: commission_rate !== undefined ? parseFloat(commission_rate || 0) : source.commission_rate,
            gst_rate_on_commission: gst_rate_on_commission !== undefined ? parseFloat(gst_rate_on_commission || 0) : source.gst_rate_on_commission,
            tds_rate: tds_rate !== undefined ? parseFloat(tds_rate || 0) : source.tds_rate,
            tcs_rate: tcs_rate !== undefined ? parseFloat(tcs_rate || 0) : source.tcs_rate
        });
        res.json({ success: true, data: source });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteSaleSource = async (req, res) => {
    try {
        const { id } = req.params;
        const source = await req.propertyDb.models.sale_sources.findByPk(id);
        if (!source) {
            return res.status(404).json({ success: false, message: 'Source not found' });
        }
        if (source.is_system) {
            return res.status(400).json({ success: false, message: 'System sources cannot be deleted' });
        }
        // Check if any bills are made with this source
        const usedInBills = await req.propertyDb.models.sales_headers.findOne({
            where: { sale_source: source.name }
        });
        if (usedInBills) {
            return res.status(400).json({ success: false, message: 'Cannot delete source as it has already been used in sales' });
        }
        await source.destroy();
        res.json({ success: true, message: 'Source deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listPaymentMethods = async (req, res) => {
    try {
        const methods = await req.propertyDb.models.payment_methods.findAll({
            order: [['is_system', 'DESC'], ['name', 'ASC']]
        });
        res.json({ success: true, data: methods });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createPaymentMethod = async (req, res) => {
    try {
        const { name } = req.body;
        if (!name || name.trim().length === 0) {
            return res.status(400).json({ success: false, message: 'Name is required' });
        }
        const uppercaseName = name.trim().toUpperCase();
        const existing = await req.propertyDb.models.payment_methods.findOne({
            where: { name: uppercaseName }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Payment method already exists' });
        }
        const created = await req.propertyDb.models.payment_methods.create({
            name: uppercaseName,
            is_system: false,
            is_active: true
        });
        res.json({ success: true, data: created });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updatePaymentMethod = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, is_active } = req.body;
        const method = await req.propertyDb.models.payment_methods.findByPk(id);
        if (!method) {
            return res.status(404).json({ success: false, message: 'Payment method not found' });
        }
        if (method.is_system) {
            return res.status(400).json({ success: false, message: 'System payment methods cannot be modified' });
        }
        // Check if any bills are made with this payment method
        const usedInBills = await req.propertyDb.models.sales_headers.findOne({
            where: { payment_mode: method.name }
        });
        if (usedInBills) {
            return res.status(400).json({ success: false, message: 'Cannot edit payment method as it has already been used in sales' });
        }
        const uppercaseName = name ? name.trim().toUpperCase() : method.name;
        if (name && uppercaseName !== method.name) {
            const existing = await req.propertyDb.models.payment_methods.findOne({
                where: { name: uppercaseName }
            });
            if (existing) {
                return res.status(400).json({ success: false, message: 'Payment method name already exists' });
            }
        }
        await method.update({
            name: uppercaseName,
            is_active: is_active !== undefined ? is_active : method.is_active
        });
        res.json({ success: true, data: method });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deletePaymentMethod = async (req, res) => {
    try {
        const { id } = req.params;
        const method = await req.propertyDb.models.payment_methods.findByPk(id);
        if (!method) {
            return res.status(404).json({ success: false, message: 'Payment method not found' });
        }
        if (method.is_system) {
            return res.status(400).json({ success: false, message: 'System payment methods cannot be deleted' });
        }
        // Check if any bills are made with this payment method
        const usedInBills = await req.propertyDb.models.sales_headers.findOne({
            where: { payment_mode: method.name }
        });
        if (usedInBills) {
            return res.status(400).json({ success: false, message: 'Cannot delete payment method as it has already been used in sales' });
        }
        await method.destroy();
        res.json({ success: true, message: 'Payment method deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
