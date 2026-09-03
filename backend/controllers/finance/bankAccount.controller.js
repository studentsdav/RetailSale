const { Op } = require('sequelize');

exports.createBankAccount = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const { bank_name, account_name, account_number, ifsc_code, branch_name, account_type, opening_balance, is_primary } = req.body;

        if (!bank_name || !account_number) {
            return res.status(400).json({ success: false, message: 'Bank name and Account number are required' });
        }

        const opening = Number(opening_balance) || 0;

        if (is_primary === true) {
            await req.propertyDb.models.bank_accounts.update(
                { is_primary: false },
                { where: { outlet_id } }
            );
        }

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
            is_primary: is_primary === true,
            is_active: true,
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
        const includeInactive = req.query.include_inactive === 'true';
        const where = { outlet_id };
        if (!includeInactive) {
            where.is_active = true;
        }

        const list = await req.propertyDb.models.bank_accounts.findAll({
            where,
            order: [['is_primary', 'DESC'], ['bank_name', 'ASC'], ['id', 'ASC']]
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

        const { bank_name, account_name, account_number, ifsc_code, branch_name, account_type, is_active, is_primary, opening_balance } = req.body;

        if (is_primary === true) {
            await req.propertyDb.models.bank_accounts.update(
                { is_primary: false },
                { where: { outlet_id } }
            );
        }

        // Check if transactions are linked to this bank account
        let hasTransactions = false;
        if (req.propertyDb.models.accounting_vouchers) {
            const voucherCount = await req.propertyDb.models.accounting_vouchers.count({
                where: { outlet_id, bank_account_id: id }
            });
            if (voucherCount > 0) hasTransactions = true;
        }

        if (Number(account.current_balance) !== Number(account.opening_balance)) {
            hasTransactions = true;
        }

        let newOpening = account.opening_balance;
        let newCurrent = account.current_balance;

        if (opening_balance !== undefined) {
            const parsedOpening = Number(opening_balance) || 0;
            if (!hasTransactions) {
                // If NO transactions are linked, allow editing opening balance and reset current balance to match
                newOpening = parsedOpening;
                newCurrent = parsedOpening;
            }
        }

        await account.update({
            bank_name: bank_name ? String(bank_name).trim() : account.bank_name,
            account_name: account_name ? String(account_name).trim() : account.account_name,
            account_number: account_number ? String(account_number).trim() : account.account_number,
            ifsc_code: ifsc_code !== undefined ? String(ifsc_code).trim() : account.ifsc_code,
            branch_name: branch_name !== undefined ? String(branch_name).trim() : account.branch_name,
            account_type: account_type || account.account_type,
            opening_balance: newOpening,
            current_balance: newCurrent,
            ...(is_active !== undefined ? { is_active: Boolean(is_active) } : {}),
            ...(is_primary !== undefined ? { is_primary: Boolean(is_primary) } : {})
        });

        res.json({ success: true, data: account, hasTransactions });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.setPrimaryBankAccount = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const account = await req.propertyDb.models.bank_accounts.findOne({ where: { id, outlet_id } });
        if (!account) {
            return res.status(404).json({ success: false, message: 'Bank account not found' });
        }

        await req.propertyDb.models.bank_accounts.update(
            { is_primary: false },
            { where: { outlet_id } }
        );

        await account.update({ is_primary: true, is_active: true });

        res.json({ success: true, message: 'Bank account marked as Primary', data: account });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.toggleBankAccountActive = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const account = await req.propertyDb.models.bank_accounts.findOne({ where: { id, outlet_id } });
        if (!account) {
            return res.status(404).json({ success: false, message: 'Bank account not found' });
        }

        const newStatus = !account.is_active;
        await account.update({ is_active: newStatus });

        res.json({ success: true, message: `Bank account set to ${newStatus ? 'Active' : 'Inactive'}`, data: account });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
