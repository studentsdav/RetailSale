const { Op, Sequelize } = require('sequelize');
const { resolveOutletScope } = require('../../utils/outletScopeHelper');

const DEFAULT_COA_SEEDS = [
    // ASSETS
    { account_code: '1001', account_name: 'Main Cash Drawer', group_name: 'Current Assets', nature: 'ASSET', is_system: true },
    { account_code: '1002', account_name: 'Petty Cash', group_name: 'Current Assets', nature: 'ASSET', is_system: false },
    { account_code: '1010', account_name: 'M-Pesa / Mobile Money Clearing', group_name: 'Bank Accounts', nature: 'ASSET', is_system: false },
    { account_code: '1020', account_name: 'Main Operating Bank Account', group_name: 'Bank Accounts', nature: 'ASSET', is_system: false },
    { account_code: '1100', account_name: 'Sundry Debtors (Customer Receivables)', group_name: 'Current Assets', nature: 'ASSET', is_system: true },
    { account_code: '1200', account_name: 'Closing Stock (Inventory Asset)', group_name: 'Stock / Inventory', nature: 'ASSET', is_system: true },
    { account_code: '1300', account_name: 'Input VAT / GST (Tax Credit)', group_name: 'Duties & Taxes', nature: 'ASSET', is_system: true },
    { account_code: '1500', account_name: 'POS Equipment & Computers', group_name: 'Fixed Assets', nature: 'ASSET', is_system: false },
    { account_code: '1510', account_name: 'Furniture & Fixtures', group_name: 'Fixed Assets', nature: 'ASSET', is_system: false },

    // LIABILITIES
    { account_code: '2001', account_name: 'Sundry Creditors (Vendor Payables)', group_name: 'Current Liabilities', nature: 'LIABILITY', is_system: true },
    { account_code: '2010', account_name: 'Customer Advances & Subscriptions', group_name: 'Current Liabilities', nature: 'LIABILITY', is_system: true },
    { account_code: '2100', account_name: 'Output Tax Payable', group_name: 'Duties & Taxes', nature: 'LIABILITY', is_system: true },
    { account_code: '2110', account_name: 'Catering / Tourism Levy (CTL) Payable', group_name: 'Duties & Taxes', nature: 'LIABILITY', is_system: false },
    { account_code: '2200', account_name: 'Bank & Business Loans', group_name: 'Loans (Liability)', nature: 'LIABILITY', is_system: false },

    // EQUITY
    { account_code: '3001', account_name: 'Proprietor / Owner Capital', group_name: 'Capital Account', nature: 'EQUITY', is_system: true },
    { account_code: '3010', account_name: 'Owner Drawings / Withdrawals', group_name: 'Capital Account', nature: 'EQUITY', is_system: false },
    { account_code: '3100', account_name: 'Retained Earnings', group_name: 'Retained Earnings', nature: 'EQUITY', is_system: true },

    // REVENUE
    { account_code: '4001', account_name: 'Retail Sales Revenue', group_name: 'Sales Income', nature: 'REVENUE', is_system: true },
    { account_code: '4010', account_name: 'Delivery & Shipping Charges Income', group_name: 'Direct Income', nature: 'REVENUE', is_system: false },
    { account_code: '4020', account_name: 'Discounts & Service Income', group_name: 'Indirect Income', nature: 'REVENUE', is_system: false },

    // EXPENSES
    { account_code: '5001', account_name: 'Purchases (Cost of Goods Sold)', group_name: 'Direct Expenses', nature: 'EXPENSE', is_system: true },
    { account_code: '5010', account_name: 'Freight & Inward Transport', group_name: 'Direct Expenses', nature: 'EXPENSE', is_system: false },
    { account_code: '5100', account_name: 'Shop & Office Rent', group_name: 'Rent & Utilities', nature: 'EXPENSE', is_system: false },
    { account_code: '5110', account_name: 'Electricity & Water Utilities', group_name: 'Rent & Utilities', nature: 'EXPENSE', is_system: false },
    { account_code: '5200', account_name: 'Staff Salaries & Wages', group_name: 'Salaries & Wages', nature: 'EXPENSE', is_system: false },
    { account_code: '5300', account_name: 'Packaging & Printing Materials', group_name: 'Indirect Expenses', nature: 'EXPENSE', is_system: false },
    { account_code: '5400', account_name: 'Repairs & Maintenance', group_name: 'Indirect Expenses', nature: 'EXPENSE', is_system: false },
    { account_code: '5500', account_name: 'Bank Charges & Payment Gateway Fees', group_name: 'Indirect Expenses', nature: 'EXPENSE', is_system: false },
];

/**
 * Get all accounts in Chart of Accounts for current outlet
 */
exports.getAccounts = async (req: any, res: any) => {
    try {
        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);
        const { search, nature, group, active_only } = req.query;

        const whereClause: any = {
            outlet_id: scope.outlet_id
        };

        if (active_only === 'true' || active_only === true) {
            whereClause.is_active = true;
        }

        if (nature && nature.toUpperCase() !== 'ALL') {
            whereClause.nature = nature.toUpperCase();
        }

        if (group && group.trim().isNotEmpty) {
            whereClause.group_name = group.trim();
        }

        if (search && search.trim().length > 0) {
            whereClause[Op.or] = [
                { account_name: { [Op.iLike]: `%${search.trim()}%` } },
                { account_code: { [Op.iLike]: `%${search.trim()}%` } },
                { group_name: { [Op.iLike]: `%${search.trim()}%` } }
            ];
        }

        let accounts = await req.propertyDb.models.chart_of_accounts.findAll({
            where: whereClause,
            order: [
                ['nature', 'ASC'],
                ['group_name', 'ASC'],
                ['account_name', 'ASC']
            ],
            raw: true
        });

        // If no accounts exist yet for this outlet, auto-seed defaults
        if (accounts.length === 0 && (!search && !nature && !group)) {
            console.log(`[COA] Auto-seeding default Chart of Accounts for outlet #${scope.outlet_id}...`);
            const seeds = DEFAULT_COA_SEEDS.map(s => ({
                ...s,
                outlet_id: scope.outlet_id,
                opening_debit: 0.00,
                opening_credit: 0.00,
                current_balance: 0.00,
                is_active: true
            }));
            await req.propertyDb.models.chart_of_accounts.bulkCreate(seeds);
            accounts = await req.propertyDb.models.chart_of_accounts.findAll({
                where: whereClause,
                order: [['nature', 'ASC'], ['group_name', 'ASC'], ['account_name', 'ASC']],
                raw: true
            });
        }

        return res.json({
            success: true,
            count: accounts.length,
            data: accounts
        });
    } catch (err) {
        console.error('Error fetching Chart of Accounts:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

/**
 * Directly create a new account in Chart of Accounts
 */
exports.createAccount = async (req, res) => {
    try {
        const reqOutlet = req.body.outlet_id || req.query.outlet_id;
        const scope = await resolveOutletScope(req, reqOutlet);
        const {
            account_name,
            account_code,
            group_name,
            nature,
            opening_debit,
            opening_credit
        } = req.body;

        if (!account_name || !account_name.trim()) {
            return res.status(400).json({ success: false, message: 'Account Name is required.' });
        }

        if (!nature || !['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'].includes(nature.toUpperCase())) {
            return res.status(400).json({
                success: false,
                message: 'Valid Nature is required (ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE).'
            });
        }

        const validGroup = (group_name && group_name.trim()) ? group_name.trim() : 'General';
        const debit = parseFloat(opening_debit) || 0.0;
        const credit = parseFloat(opening_credit) || 0.0;
        const netBal = (nature.toUpperCase() === 'ASSET' || nature.toUpperCase() === 'EXPENSE')
            ? (debit - credit)
            : (credit - debit);

        const newAccount = await req.propertyDb.models.chart_of_accounts.create({
            outlet_id: scope.outlet_id,
            account_code: (account_code && account_code.trim()) ? account_code.trim() : null,
            account_name: account_name.trim(),
            group_name: validGroup,
            nature: nature.toUpperCase(),
            opening_debit: debit,
            opening_credit: credit,
            current_balance: netBal,
            is_system: false,
            is_active: true
        });

        console.log(`[COA] Created new account "${newAccount.account_name}" (#${newAccount.id}) for outlet #${scope.outlet_id}`);

        return res.status(201).json({
            success: true,
            message: `Account "${newAccount.account_name}" added to Chart of Accounts successfully!`,
            data: newAccount
        });
    } catch (err) {
        console.error('Error creating Chart of Accounts entry:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

/**
 * Update an existing account in Chart of Accounts
 */
exports.updateAccount = async (req, res) => {
    try {
        const { id } = req.params;
        const reqOutlet = req.body.outlet_id || req.query.outlet_id;
        const scope = await resolveOutletScope(req, reqOutlet);
        const {
            account_name,
            account_code,
            group_name,
            nature,
            opening_debit,
            opening_credit,
            is_active
        } = req.body;

        const account = await req.propertyDb.models.chart_of_accounts.findOne({
            where: { id, outlet_id: scope.outlet_id }
        });

        if (!account) {
            return res.status(404).json({ success: false, message: 'Account not found.' });
        }

        const updates: any = {};
        if (account_name && account_name.trim()) updates.account_name = account_name.trim();
        if (account_code !== undefined) updates.account_code = account_code ? account_code.trim() : null;
        if (group_name && group_name.trim()) updates.group_name = group_name.trim();
        if (nature && ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'].includes(nature.toUpperCase())) {
            updates.nature = nature.toUpperCase();
        }
        if (opening_debit !== undefined) updates.opening_debit = parseFloat(opening_debit) || 0.0;
        if (opening_credit !== undefined) updates.opening_credit = parseFloat(opening_credit) || 0.0;
        if (is_active !== undefined) updates.is_active = Boolean(is_active);

        await account.update(updates);

        return res.json({
            success: true,
            message: `Account "${account.account_name}" updated successfully!`,
            data: account
        });
    } catch (err) {
        console.error('Error updating Chart of Accounts entry:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

/**
 * Toggle active status of an account
 */
exports.toggleActiveAccount = async (req, res) => {
    try {
        const { id } = req.params;
        const reqOutlet = req.body.outlet_id || req.query.outlet_id;
        const scope = await resolveOutletScope(req, reqOutlet);

        const account = await req.propertyDb.models.chart_of_accounts.findOne({
            where: { id, outlet_id: scope.outlet_id }
        });

        if (!account) {
            return res.status(404).json({ success: false, message: 'Account not found.' });
        }

        const newStatus = !account.is_active;
        await account.update({ is_active: newStatus });

        return res.json({
            success: true,
            message: `Account "${account.account_name}" is now ${newStatus ? 'Active' : 'Inactive'}.`,
            is_active: newStatus
        });
    } catch (err) {
        console.error('Error toggling account status:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

/**
 * Delete a custom account from Chart of Accounts
 */
exports.deleteAccount = async (req, res) => {
    try {
        const { id } = req.params;
        const reqOutlet = req.query.outlet_id;
        const scope = await resolveOutletScope(req, reqOutlet);

        const account = await req.propertyDb.models.chart_of_accounts.findOne({
            where: { id, outlet_id: scope.outlet_id }
        });

        if (!account) {
            return res.status(404).json({ success: false, message: 'Account not found.' });
        }

        if (account.is_system) {
            return res.status(400).json({
                success: false,
                message: 'Cannot delete system core accounts. You can mark it inactive instead.'
            });
        }

        // Check if account has posted vouchers
        if (req.propertyDb.models.voucher_lines) {
            const hasVouchers = await req.propertyDb.models.voucher_lines.count({
                where: { account_id: id }
            });
            if (hasVouchers > 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Cannot delete account with existing transactions. Mark it inactive instead.'
                });
            }
        }

        await account.destroy();

        return res.json({
            success: true,
            message: `Account "${account.account_name}" deleted successfully!`
        });
    } catch (err) {
        console.error('Error deleting account:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

/**
 * Seed default Master Chart of Accounts for outlet
 */
exports.seedDefaultAccounts = async (req, res) => {
    try {
        const reqOutlet = req.body.outlet_id || req.query.outlet_id;
        const scope = await resolveOutletScope(req, reqOutlet);

        for (const s of DEFAULT_COA_SEEDS) {
            const exists = await req.propertyDb.models.chart_of_accounts.findOne({
                where: {
                    outlet_id: scope.outlet_id,
                    account_name: s.account_name
                }
            });
            if (!exists) {
                await req.propertyDb.models.chart_of_accounts.create({
                    ...s,
                    outlet_id: scope.outlet_id,
                    opening_debit: 0.00,
                    opening_credit: 0.00,
                    current_balance: 0.00,
                    is_active: true
                });
            }
        }

        return res.json({
            success: true,
            message: 'Default Chart of Accounts seeded successfully!'
        });
    } catch (err) {
        console.error('Error seeding default accounts:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};


module.exports = exports;
export default exports;
