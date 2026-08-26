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

        const infoObj = info ? info.toJSON() : {};
        if (actualOutletId && req.propertyDb.models.outlets) {
            const outletObj = await req.propertyDb.models.outlets.findByPk(actualOutletId);
            if (outletObj) {
                infoObj.outlet_module = outletObj.business_module || outletObj.outlet_module || 'ALL';
                infoObj.business_module = outletObj.business_module || outletObj.outlet_module || 'ALL';
            }
        }

        res.json({ success: true, data: infoObj });
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
            drug_license_no: req.body.drug_license_no,
            logo_path: req.body.logo_path,
            website: req.body.website,
            print_mobile: req.body.print_mobile !== undefined ? req.body.print_mobile : true,
            print_email: req.body.print_email !== undefined ? req.body.print_email : true,
            print_website: req.body.print_website !== undefined ? req.body.print_website : true,
            thermal_footer_note: req.body.thermal_footer_note,
            is_active: req.body.is_active,
            terms_and_conditions: req.body.terms_and_conditions !== undefined ? req.body.terms_and_conditions : '',
            bank_name: req.body.bank_name !== undefined ? req.body.bank_name : '',
            bank_acc_no: req.body.bank_acc_no !== undefined ? req.body.bank_acc_no : '',
            bank_ifsc: req.body.bank_ifsc !== undefined ? req.body.bank_ifsc : '',
            upi_id: req.body.upi_id !== undefined ? req.body.upi_id : '',
            upi_payee_name: req.body.upi_payee_name !== undefined ? req.body.upi_payee_name : '',
            print_bank_details: req.body.print_bank_details !== undefined ? req.body.print_bank_details : false,
            print_upi_qr: req.body.print_upi_qr !== undefined ? req.body.print_upi_qr : false,
            print_digital_signature: req.body.print_digital_signature !== undefined ? req.body.print_digital_signature : false
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

        if (req.propertyDb.models.outlets) {
            const outletObj = await req.propertyDb.models.outlets.findOne({
                where: { id: outlet_id },
                transaction: t
            });
            if (outletObj) {
                const outletUpdates = {};
                if (req.body.property_name) outletUpdates.property_name = req.body.property_name;
                if (req.body.business_type) outletUpdates.business_type = req.body.business_type;
                if (req.body.outlet_module) outletUpdates.outlet_module = req.body.outlet_module;
                if (req.body.recovery_pin) outletUpdates.recovery_pin = req.body.recovery_pin;
                if (req.body.mobile) outletUpdates.contact_phone = req.body.mobile;
                if (req.body.email) outletUpdates.contact_email = req.body.email;
                if (Object.keys(outletUpdates).length > 0) {
                    await outletObj.update(outletUpdates, { transaction: t }).catch(() => {});
                }
            }
        }

        await upsertClient({
            outlet_id: req.user.outlet_id,
            outlet_code: req.user.outlet_code || req.body.outlet_code || "",
            property_name: req.body.property_name,
            db_name: loadConfig().db_database,
            machine_id: require("os").hostname(),
            created_at: oldData?.created_at || new Date().toISOString(),
            expiry_date: oldData?.expiry_date || "",
            status: "ACTIVE",
            contact_email: req.body.email || "",
            contact_phone: req.body.mobile || "",
            tax_id: req.body.gst_no || req.body.pan_no || "",
            pin: req.body.recovery_pin || ""
        });

        await t.commit();
        res.json({ success: true, message: 'Property information saved' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
        console.log(err.message)
    }
};
