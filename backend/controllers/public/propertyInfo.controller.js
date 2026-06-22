const audit = require('../../services/audit.service');
const { upsertClient } = require("../../modules/driveService");
const loadConfig = require("../../utils/decryptConfig");

exports.getPropertyInfo = async (req, res) => {
    try {
        let actualOutletId = req.user?.outlet_id || req.query?.outlet_id || req.body?.outlet_id;

        // If it's a string code (like OUTLET001), resolve it to integer id
        if (typeof actualOutletId === 'string' && actualOutletId.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({
                where: { outlet_code: actualOutletId }
            });
            if (outlet) {
                actualOutletId = outlet.id;
            }
        }

        // Fallback: if still null/undefined, find the first active outlet
        if (!actualOutletId) {
            const defaultOutlet = await req.propertyDb.models.outlets.findOne({
                where: { is_active: true }
            });
            if (defaultOutlet) {
                actualOutletId = defaultOutlet.id;
            }
        }

        const info = await req.propertyDb.models.property_info.findOne({
            where: { outlet_id: actualOutletId }
        });

        res.json({ success: true, data: info });
    } catch (err) {
        console.error("GET PROPERTY INFO ERROR STACK:", err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.savePropertyInfo = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;

        const Model = req.propertyDb.models.property_info;

        const existing = await Model.findOne({
            where: { outlet_id },
            transaction: t
        });

        const oldData = existing ? existing.toJSON() : null;

        const payload = {
            outlet_id,
            property_name: req.body.property_name,
            legal_name: req.body.legal_name,
            address: req.body.address,
            city: req.body.city,
            state: req.body.state,
            pin_code: req.body.pin_code,
            contact_person: req.body.contact_person,
            mobile: req.body.mobile,
            email: req.body.email,
            gst_no: req.body.gst_no,
            pan_no: req.body.pan_no,
            fssai_no: req.body.fssai_no,
            logo_path: req.body.logo_path,
            is_active: req.body.is_active
        };

        let record;

        if (existing) {
            record = await existing.update(payload, { transaction: t });
        } else {
            record = await Model.create(payload, { transaction: t });
        }

        await audit.log({
            req,
            module: 'PROPERTY_INFO',
            action: existing ? 'UPDATE' : 'CREATE',
            table: 'property_info',
            recordId: req.user.id,
            old_data: oldData,
            newData: record.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await upsertClient({
            outlet_id: req.user.outlet_id,
            property_name: req.body.property_name,
            db_name: loadConfig().db_database,
            machine_id: require("os").hostname(),
            created_at: oldData?.created_at || new Date().toISOString(),
            expiry_date: oldData?.expiry_date || "",
            status: "ACTIVE"
        });

        await t.commit();
        res.json({ success: true, message: 'Property information saved' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
        console.log(err.message)
    }
};
