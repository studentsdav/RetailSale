const { Op } = require('sequelize');

/**
 * Fetches active payment method names dynamically from payment_methods master table
 */
async function getAllActivePaymentMethods(db) {
    if (!db || !db.models || !db.models.payment_methods) return [];
    try {
        const list = await db.models.payment_methods.findAll({
            where: { is_active: true },
            attributes: ['name'],
            raw: true
        });
        return list.map(pm => String(pm.name).trim().toUpperCase());
    } catch (e) {
        console.error('Error fetching payment_methods master:', e);
        return [];
    }
}

/**
 * Async check using payment_methods master table
 */
async function isBankPaymentMethod({ db, method }) {
    if (!method) return false;
    const m = String(method).trim().toUpperCase();

    if (['CASH', 'CREDIT', 'DUE', 'WAIVE_OFF'].includes(m)) return false;

    if (db) {
        const masterMethods = await getAllActivePaymentMethods(db);
        if (masterMethods.length > 0) {
            const found = masterMethods.includes(m);
            if (found && !['CASH', 'CREDIT', 'DUE', 'WAIVE_OFF'].includes(m)) {
                return true;
            }
        }
    }

    return isBankPayment(method);
}

/**
 * Synchronous pattern check fallback
 */
function isBankPayment(method) {
    if (!method) return false;
    const m = String(method).trim().toUpperCase();
    if (m === 'CASH' || m === 'CREDIT' || m === 'DUE' || m === 'WAIVE_OFF') return false;
    return (
        ['CARD', 'UPI', 'BANK', 'BANK_TRANSFER', 'ONLINE', 'NETBANKING', 'CHEQUE', 'WALLET', 'POS_CARD', 'POS_UPI', 'RAZORPAY', 'STRIPE', 'PAYTM', 'PHONEPE', 'GPAY', 'SUBSCRIPTION'].includes(m) ||
        m.includes('BANK') || m.includes('CARD') || m.includes('UPI') || m.includes('ONLINE') || m.includes('TRANSFER') || m.includes('CHEQUE') || m.includes('PAY')
    );
}

async function getDefaultBankAccount({ db, outlet_id, transaction }) {
    let bank = await db.models.bank_accounts.findOne({
        where: { outlet_id, is_active: true, is_primary: true },
        transaction
    });

    if (!bank) {
        bank = await db.models.bank_accounts.findOne({
            where: { outlet_id, is_active: true },
            order: [['id', 'ASC']],
            transaction
        });
    }

    if (!bank) {
        bank = await db.models.bank_accounts.create({
            outlet_id,
            bank_name: 'Main Bank Account',
            account_name: 'Primary Bank Account (Card/UPI/Bank)',
            account_number: 'DEFAULT-BANK-01',
            account_type: 'CURRENT',
            opening_balance: 0,
            current_balance: 0,
            is_active: true
        }, { transaction });
    }
    return bank;
}

async function creditBankBalance({ db, outlet_id, amount, bankAccountId = null, transaction = undefined }) {
    const amt = Number(amount) || 0;
    if (amt <= 0) return;

    let bank;
    if (bankAccountId) {
        bank = await db.models.bank_accounts.findOne({ where: { id: bankAccountId, outlet_id }, transaction });
    }
    if (!bank) {
        bank = await getDefaultBankAccount({ db, outlet_id, transaction });
    }
    if (bank) {
        const newBalance = Number((Number(bank.current_balance || 0) + amt).toFixed(2));
        await bank.update({ current_balance: newBalance }, { transaction });
    }
    return bank;
}

async function debitBankBalance({ db, outlet_id, amount, bankAccountId = null, transaction = undefined }) {
    const amt = Number(amount) || 0;
    if (amt <= 0) return;

    let bank;
    if (bankAccountId) {
        bank = await db.models.bank_accounts.findOne({ where: { id: bankAccountId, outlet_id }, transaction });
    }
    if (!bank) {
        bank = await getDefaultBankAccount({ db, outlet_id, transaction });
    }
    if (bank) {
        const newBalance = Number((Number(bank.current_balance || 0) - amt).toFixed(2));
        await bank.update({ current_balance: newBalance }, { transaction });
    }
    return bank;
}

module.exports = {
    getAllActivePaymentMethods,
    isBankPayment,
    isBankPaymentMethod,
    getDefaultBankAccount,
    creditBankBalance,
    debitBankBalance
};
