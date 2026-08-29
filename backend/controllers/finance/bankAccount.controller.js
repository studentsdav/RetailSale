const { Op } = require('sequelize');

exports.createBankAccount = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const { bank_name, account_name, account_number, ifsc_code, branch_name, account_type, opening_balance } = req.body;

        if (!bank_name || !account_number) {
            return res.status(400).json({ success: false, message: 'Bank name and Account number are required' });
        }

        const opening = Number(opening_balance) || 0;

        const bankAccount = await req.propertyDb.models.bank_accounts.create({
            outlet_id,
            bank_name: String(bank_name).trim(),
            account_name: String(account_name || bank_name).trim(),
            account_number: String(account_number).trim(),
            ifsc_code: ifsc_code ? String(ifsc_code).trim() : null,
            branch_name: branch_name ? String(branch_name).trim() : null,
            account_type: account_type || 'CURRENT',
            opening_balance: opening,
            current_balance: opening,
            created_by
        });

        res.json({ success: true, data: bankAccount });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getBankAccounts = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const list = await req.propertyDb.models.bank_accounts.findAll({
            where: { outlet_id, is_active: true },
            order: [['bank_name', 'ASC']]
        });
        res.json({ success: true, data: list });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateBankAccount = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const account = await req.propertyDb.models.bank_accounts.findOne({ where: { id, outlet_id } });

        if (!account) {
            return res.status(404).json({ success: false, message: 'Bank account not found' });
        }

        const { bank_name, account_name, account_number, ifsc_code, branch_name, account_type } = req.body;

        await account.update({
            bank_name: bank_name ? String(bank_name).trim() : account.bank_name,
            account_name: account_name ? String(account_name).trim() : account.account_name,
            account_number: account_number ? String(account_number).trim() : account.account_number,
            ifsc_code: ifsc_code !== undefined ? String(ifsc_code).trim() : account.ifsc_code,
            branch_name: branch_name !== undefined ? String(branch_name).trim() : account.branch_name,
            account_type: account_type || account.account_type
        });

        res.json({ success: true, data: account });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
