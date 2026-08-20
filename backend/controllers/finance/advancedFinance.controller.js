const { Op, Sequelize } = require('sequelize');
const {
    createLedgerEntry,
    updateLedgerEntry,
    getOpeningBalanceForDate,
    upsertOpeningBalance,
    roundAmount,
    dateKey,
    startOfDay,
    recalculateLedgerBalances
} = require('../../services/cashLedger.service');
const {
    refreshSaleOutstanding,
    getRepaymentTotal,
    resolvePaymentStatus
} = require('../../services/salesFinance.service');

function parseDateOnly(value, fallback = null) {
    if (!value) return fallback;
    let date;
    if (typeof value === 'string') {
        const trimmed = value.trim();
        const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
        if (match) {
            date = new Date(
                Number(match[1]),
                Number(match[2]) - 1,
                Number(match[3])
            );
        } else {
            date = new Date(trimmed);
        }
    } else {
        date = new Date(value);
    }
    if (Number.isNaN(date.getTime())) return fallback;
    date.setHours(0, 0, 0, 0);
    return date;
}

function endOfDay(value) {
    const date = parseDateOnly(value, new Date());
    date.setHours(23, 59, 59, 999);
    return date;
}

function toAmount(value) {
    return roundAmount(value);
}

function buildCustomerMatch(search) {
    if (!search) return null;
    const cleanPhone = String(search).replace(/\D/g, '').trim();
    const last10 = cleanPhone.length > 10 ? cleanPhone.slice(-10) : cleanPhone;

    const orConditions = [
        { customer_name: { [Op.iLike]: `%${search}%` } },
        { customer_gstin: { [Op.iLike]: `%${search}%` } }
    ];

    if (last10.length >= 7) {
        orConditions.push({
            customer_phone: {
                [Op.or]: [
                    { [Op.iLike]: `%${search}%` },
                    { [Op.in]: [last10, `91${last10}`, `+91${last10}`, `0${last10}`] }
                ]
            }
        });
    } else {
        orConditions.push({ customer_phone: { [Op.iLike]: `%${search}%` } });
    }

    return { [Op.or]: orConditions };
}

function normalizeCustomerIdentity(payload = {}) {
    return {
        customer_name: String(payload.customer_name || '').trim(),
        customer_phone: String(payload.customer_phone || '').trim(),
        customer_gstin: String(payload.customer_gstin || '').trim().toUpperCase()
    };
}

function buildCustomerExactMatch(identity = {}) {
    if (identity.customer_phone) {
        return { customer_phone: identity.customer_phone };
    }
    if (identity.customer_gstin) {
        return { customer_gstin: identity.customer_gstin };
    }
    if (identity.customer_name) {
        return { customer_name: identity.customer_name };
    }
    return null;
}

function ensureCustomerIdentity(identity = {}) {
    if (!identity.customer_phone && !identity.customer_gstin && !identity.customer_name) {
        throw new Error('Customer selection is required to store or use advance balance');
    }
}

function buildCustomerKey(sale) {
    const phone = String(sale.customer_phone || '').trim();
    const gstin = String(sale.customer_gstin || '').trim().toUpperCase();
    const name = String(sale.customer_name || '').trim().toLowerCase();
    return phone || gstin || name || `walkin-${sale.id}`;
}

function getCustomerLabel(sale) {
    return String(sale.customer_name || sale.customer_phone || 'Walk-in Customer').trim() || 'Walk-in Customer';
}

function getCustomerLabelFromIdentity(identity = {}) {
    return String(identity.customer_name || identity.customer_phone || 'Walk-in Customer').trim() || 'Walk-in Customer';
}

function formatIncomeNotes(source, note) {
    const cleanedSource = String(source || '').trim();
    const cleanedNote = String(note || '').trim();
    if (!cleanedSource && !cleanedNote) return null;
    if (!cleanedNote) return `SOURCE:${cleanedSource}`;
    return `SOURCE:${cleanedSource}\nNOTE:${cleanedNote}`;
}

async function findLinkedLedgerEntry(db, outlet_id, reference_type, reference_id, transaction) {
    return db.models.cash_ledger.findOne({
        where: { outlet_id, reference_type, reference_id },
        transaction
    });
}

function calculateExpenseAmounts({ amount, isTaxInclusive, taxes = [], deductions = [] }) {
    const totalTaxPercent = taxes.reduce((sum, t) => sum + Number(t.tax_percentage || t.tax_percent || 0), 0);

    let baseAmount = 0;
    let totalTaxAmount = 0;

    if (isTaxInclusive) {
        baseAmount = amount / (1 + (totalTaxPercent / 100));
        totalTaxAmount = amount - baseAmount;
    } else {
        baseAmount = amount;
        totalTaxAmount = baseAmount * (totalTaxPercent / 100);
    }

    baseAmount = Math.round(baseAmount * 100) / 100;
    totalTaxAmount = Math.round(totalTaxAmount * 100) / 100;

    let calculatedTaxes = [];
    if (totalTaxPercent > 0) {
        let remainingTax = totalTaxAmount;
        taxes.forEach((tax, index) => {
            let taxAmt = 0;
            const percent = Number(tax.tax_percentage || tax.tax_percent || 0);
            if (index === taxes.length - 1) {
                taxAmt = remainingTax;
            } else {
                taxAmt = Math.round((totalTaxAmount * (percent / totalTaxPercent)) * 100) / 100;
                remainingTax -= taxAmt;
            }
            calculatedTaxes.push({
                tax_name: tax.tax_name,
                tax_percentage: percent,
                tax_amount: taxAmt
            });
        });
    }

    let totalDeductionAmount = 0;
    const calculatedDeductions = deductions.map((ded) => {
        const percent = Number(ded.deduction_percentage || ded.deduction_percent || 0);
        const dedAmt = Math.round((baseAmount * (percent / 100)) * 100) / 100;
        totalDeductionAmount += dedAmt;
        return {
            deduction_type: ded.deduction_type || ded.deduction_name || 'Other',
            deduction_percentage: percent,
            deduction_amount: dedAmt
        };
    });

    totalDeductionAmount = Math.round(totalDeductionAmount * 100) / 100;

    const grossAmount = isTaxInclusive ? amount : (baseAmount + totalTaxAmount);
    const netPayableAmount = Math.round((grossAmount - totalDeductionAmount) * 100) / 100;

    return {
        base_amount: baseAmount,
        total_tax_amount: totalTaxAmount,
        total_deduction_amount: totalDeductionAmount,
        net_payable_amount: netPayableAmount,
        taxes: calculatedTaxes,
        deductions: calculatedDeductions
    };
}

async function ensureExpenseDuplicateFree({ req, payment_date, category_id, net_payable_amount, invoice_ref_no, expense_note = null, vendor_id = null, excludeId = null, transaction }) {
    const where = {
        outlet_id: req.user.outlet_id,
        payment_date,
        category_id,
        net_payable_amount: toAmount(net_payable_amount)
    };

    if (invoice_ref_no) {
        where.invoice_ref_no = invoice_ref_no;
    } else {
        where.vendor_id = vendor_id || null;
        where.expense_note = expense_note || null;
        where.invoice_ref_no = null;
    }

    if (excludeId) where.id = { [Op.ne]: excludeId };

    const existing = await req.propertyDb.models.expenses.findOne({ where, transaction });
    if (existing) throw new Error('Duplicate expense entry already exists for the same date, category, amount, vendor and note');
}

async function ensureRepaymentDuplicateFree({ req, sale_id, payment_date, amount, payment_mode, reference_no, excludeId = null, transaction }) {
    const where = {
        outlet_id: req.user.outlet_id,
        sale_id,
        payment_date,
        amount: toAmount(amount),
        payment_mode,
        reference_no: reference_no || null
    };

    if (excludeId) where.id = { [Op.ne]: excludeId };

    const existing = await req.propertyDb.models.customer_repayments.findOne({ where, transaction });
    if (existing) throw new Error('Duplicate repayment entry already exists');
}

function isWaiveOffMode(paymentMode) {
    const mode = String(paymentMode || '').trim().toUpperCase();
    return mode === 'WAIVEOFF' || mode === 'WRITEOFF' || mode === 'WRITE_OFF' || mode === 'WAIVE_OFF';
}

async function getSaleOrFail(req, saleId, transaction) {
    const sale = await req.propertyDb.models.sales_headers.findOne({
        where: {
            id: saleId,
            outlet_id: req.user.outlet_id,
            is_deleted: false,
            is_latest: true,
            status: 'COMPLETED'
        },
        transaction
    });

    if (!sale) throw new Error('Credit bill not found');
    return sale;
}

function buildLedgerWhere(outlet_id, query) {
    const where = { outlet_id };
    const fromDate = parseDateOnly(query.from_date);
    const toDate = parseDateOnly(query.to_date);
    const type = String(query.type || '').trim().toUpperCase();
    const paymentMethod = String(query.payment_method || '')
        .trim()
        .toUpperCase();
    const search = String(query.search || '').trim();

    if (fromDate || toDate) {
        where.txn_date = {};
        if (fromDate) where.txn_date[Op.gte] = dateKey(fromDate);
        if (toDate) where.txn_date[Op.lte] = dateKey(toDate);
    }

    if (paymentMethod && paymentMethod !== 'ALL') where.payment_method = paymentMethod;

    const conditions = [];

    if (type && type !== 'ALL') {
        if (type === 'SUBSCRIPTION') {
            conditions.push({
                [Op.or]: [
                    { transaction_type: { [Op.in]: ['SUBSCRIPTION_SETTLEMENT', 'SUBSCRIPTION_SETTLEMENT_PARTIAL', 'SUBSCRIPTION_SETTLEMENT_CREDIT', 'SUBSCRIPTION_SETTLEMENT_REFUND'] } },
                    {
                        transaction_type: 'CUSTOMER_ADVANCE',
                        reference_type: 'SUBSCRIPTION'
                    }
                ]
            });
        } else if (type === 'OUTSTANDING') {
            conditions.push({
                [Op.or]: [
                    { transaction_type: { [Op.in]: ['SALE_CREDIT', 'SUBSCRIPTION_SETTLEMENT_CREDIT', 'SUBSCRIPTION_SETTLEMENT_PARTIAL'] } },
                    { notes: { [Op.iLike]: '%outstanding%' } }
                ]
            });
        } else {
            where.transaction_type = type;
        }
    }

    if (search) {
        conditions.push({
            [Op.or]: [
                { reference_no: { [Op.iLike]: `%${search}%` } },
                { party_name: { [Op.iLike]: `%${search}%` } },
                { notes: { [Op.iLike]: `%${search}%` } }
            ]
        });
    }

    if (conditions.length > 0) {
        where[Op.and] = conditions;
    }

    return where;
}

function buildDailyLedgerGroups(entries, openingMap, startingOpening) {
    const groups = [];
    let current = null;
    let carry = startingOpening;

    for (const entry of entries) {
        const key = dateKey(entry.txn_date);
        if (!current || current.date !== key) {
            if (current) {
                current.closing_balance = current.entries[current.entries.length - 1].balance;
                carry = current.closing_balance;
                groups.push(current);
            }

            current = {
                date: key,
                opening_balance: openingMap.get(key) ?? carry,
                closing_balance: openingMap.get(key) ?? carry,
                entries: []
            };
        }

        current.entries.push({
            id: entry.id,
            txn_date: entry.txn_date,
            transaction_type: entry.transaction_type,
            reference_type: entry.reference_type,
            reference_id: entry.reference_id,
            reference_no: entry.reference_no,
            party_name: entry.party_name,
            payment_method: entry.payment_method,
            amount_in: toAmount(entry.amount_in),
            amount_out: toAmount(entry.amount_out),
            adjustment_amount: toAmount(entry.adjustment_amount),
            balance: toAmount(entry.balance),
            notes: entry.notes || ''
        });
    }

    if (current) {
        current.closing_balance = current.entries[current.entries.length - 1].balance;
        groups.push(current);
    }

    return groups;
}

function serializeLedgerEntry(entry) {
    return {
        id: entry.id,
        txn_date: dateKey(entry.txn_date),
        transaction_type: entry.transaction_type,
        reference_type: entry.reference_type,
        reference_id: entry.reference_id,
        reference_no: entry.reference_no,
        party_name: entry.party_name,
        payment_method: entry.payment_method,
        amount_in: toAmount(entry.amount_in),
        amount_out: toAmount(entry.amount_out),
        adjustment_amount: toAmount(entry.adjustment_amount),
        balance: toAmount(entry.balance),
        notes: entry.notes || ''
    };
}

exports.createIncome = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const income_date = dateKey(req.body.income_date || new Date());
        const source = String(req.body.source || req.body.category || '').trim();
        const amount = toAmount(req.body.amount);
        const party_name = String(req.body.party_name || req.body.received_from || '').trim() || null;
        const payment_method = String(req.body.payment_mode || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no || '').trim() || null;
        const note = String(req.body.note || '').trim() || null;

        if (!source) throw new Error('Income source is required');
        if (amount <= 0) throw new Error('Income amount must be greater than 0');

        const entry = await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: income_date,
            transaction_type: 'INCOME',
            reference_type: 'INCOME',
            reference_no,
            party_name: party_name || source,
            payment_method,
            amount_in: amount,
            notes: formatIncomeNotes(source, note),
            created_by: req.user.id,
            transaction: t
        });

        await t.commit();
        res.json({ success: true, data: entry });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.updateIncome = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const entry = await req.propertyDb.models.cash_ledger.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id,
                transaction_type: 'INCOME'
            },
            transaction: t
        });

        if (!entry) throw new Error('Income entry not found');

        const income_date = dateKey(req.body.income_date || entry.txn_date);
        const source = String(req.body.source || req.body.category || '').trim();
        const amount = toAmount(req.body.amount ?? entry.amount_in);
        const party_name = String(req.body.party_name || req.body.received_from || '').trim() || null;
        const payment_method = String(req.body.payment_mode || entry.payment_method || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no ?? entry.reference_no ?? '').trim() || null;
        const note = String(req.body.note ?? entry.notes ?? '').trim() || null;

        if (!source) throw new Error('Income source is required');
        if (amount <= 0) throw new Error('Income amount must be greater than 0');

        await updateLedgerEntry({
            db: req.propertyDb,
            entryId: entry.id,
            outlet_id: req.user.outlet_id,
            values: {
                txn_date: income_date,
                reference_type: 'INCOME',
                reference_no,
                party_name: party_name || source,
                payment_method,
                amount_in: amount,
                amount_out: 0,
                adjustment_amount: 0,
                notes: formatIncomeNotes(source, note)
            },
            transaction: t
        });

        await t.commit();
        res.json({ success: true });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getIncomeReport = async (req, res) => {
    try {
        const where = {
            outlet_id: req.user.outlet_id,
            transaction_type: 'INCOME'
        };
        if (req.query.from_date || req.query.to_date) {
            where.txn_date = {};
            if (req.query.from_date) where.txn_date[Op.gte] = dateKey(req.query.from_date);
            if (req.query.to_date) where.txn_date[Op.lte] = dateKey(req.query.to_date);
        }
        if (req.query.search) {
            where[Op.or] = [
                { reference_no: { [Op.iLike]: `%${req.query.search}%` } },
                { party_name: { [Op.iLike]: `%${req.query.search}%` } },
                { notes: { [Op.iLike]: `%${req.query.search}%` } }
            ];
        }

        const data = await req.propertyDb.models.cash_ledger.findAll({
            where,
            order: [['txn_date', 'DESC'], ['id', 'DESC']]
        });

        const totalAmount = data.reduce((sum, entry) => sum + toAmount(entry.amount_in), 0);
        res.json({
            success: true,
            summary: { totalAmount, totalCount: data.length },
            data: data.map(serializeLedgerEntry)
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createWithdrawal = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const withdrawal_date = dateKey(
            req.body.withdrawal_date || req.body.txn_date || new Date()
        );
        const purpose = String(req.body.purpose || req.body.category || '').trim();
        const amount = toAmount(req.body.amount);
        const payment_method = String(req.body.payment_mode || 'CASH')
            .trim()
            .toUpperCase();
        const reference_no = String(req.body.reference_no || '').trim() || null;
        const note = String(req.body.note || '').trim() || null;

        if (!purpose) throw new Error('Withdrawal purpose is required');
        if (amount <= 0) throw new Error('Withdrawal amount must be greater than 0');

        const entry = await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: withdrawal_date,
            transaction_type: 'WITHDRAWAL',
            reference_type: 'WITHDRAWAL',
            reference_no,
            party_name: purpose,
            payment_method,
            amount_out: amount,
            notes: note,
            created_by: req.user.id,
            transaction: t
        });

        await t.commit();
        res.json({ success: true, data: entry });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.updateWithdrawal = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const entry = await req.propertyDb.models.cash_ledger.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id,
                transaction_type: 'WITHDRAWAL'
            },
            transaction: t
        });

        if (!entry) throw new Error('Withdrawal entry not found');

        const withdrawal_date = dateKey(req.body.withdrawal_date || entry.txn_date);
        const purpose = String(
            req.body.purpose || req.body.category || entry.party_name || ''
        ).trim();
        const amount = toAmount(req.body.amount ?? entry.amount_out);
        const payment_method = String(
            req.body.payment_mode || entry.payment_method || 'CASH'
        )
            .trim()
            .toUpperCase();
        const reference_no = String(
            req.body.reference_no ?? entry.reference_no ?? ''
        ).trim() || null;
        const note = String(req.body.note ?? entry.notes ?? '').trim() || null;

        if (!purpose) throw new Error('Withdrawal purpose is required');
        if (amount <= 0) throw new Error('Withdrawal amount must be greater than 0');

        await updateLedgerEntry({
            db: req.propertyDb,
            entryId: entry.id,
            outlet_id: req.user.outlet_id,
            values: {
                txn_date: withdrawal_date,
                reference_type: 'WITHDRAWAL',
                reference_no,
                party_name: purpose,
                payment_method,
                amount_in: 0,
                amount_out: amount,
                adjustment_amount: 0,
                notes: note
            },
            transaction: t
        });

        await t.commit();
        res.json({ success: true });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getWithdrawalReport = async (req, res) => {
    try {
        const where = {
            outlet_id: req.user.outlet_id,
            transaction_type: 'WITHDRAWAL'
        };
        if (req.query.from_date || req.query.to_date) {
            where.txn_date = {};
            if (req.query.from_date) where.txn_date[Op.gte] = dateKey(req.query.from_date);
            if (req.query.to_date) where.txn_date[Op.lte] = dateKey(req.query.to_date);
        }
        if (req.query.search) {
            where[Op.or] = [
                { reference_no: { [Op.iLike]: `%${req.query.search}%` } },
                { party_name: { [Op.iLike]: `%${req.query.search}%` } },
                { notes: { [Op.iLike]: `%${req.query.search}%` } }
            ];
        }

        const data = await req.propertyDb.models.cash_ledger.findAll({
            where,
            order: [['txn_date', 'DESC'], ['id', 'DESC']]
        });

        const totalAmount = data.reduce((sum, entry) => sum + toAmount(entry.amount_out), 0);
        res.json({
            success: true,
            summary: { totalAmount, totalCount: data.length },
            data: data.map(serializeLedgerEntry)
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createExpense = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const amount = toAmount(req.body.amount);
        const is_tax_inclusive = req.body.is_tax_inclusive === true || req.body.is_tax_inclusive === 'true';
        const taxes = req.body.taxes || [];
        const deductions = req.body.deductions || [];
        const vendor_id = req.body.vendor_id ? Number(req.body.vendor_id) : null;
        const category_id = req.body.category_id;
        const invoice_ref_no = req.body.invoice_ref_no ? String(req.body.invoice_ref_no).trim() : null;
        const payment_date = dateKey(req.body.payment_date || new Date());
        const payment_method = String(req.body.payment_method || req.body.payment_mode || 'CASH').trim();
        const expense_note = req.body.expense_note || req.body.note || null;
        const status = req.body.status || 'Paid';

        if (!category_id) throw new Error('Category is required');
        if (amount <= 0) throw new Error('Amount must be greater than 0');

        const categoryRow = await req.propertyDb.models.expense_categories.findOne({
            where: { id: category_id, outlet_id: req.user.outlet_id },
            transaction: t
        });
        if (!categoryRow) throw new Error('Category not found');

        const {
            base_amount,
            total_tax_amount,
            total_deduction_amount,
            net_payable_amount,
            taxes: calculatedTaxes,
            deductions: calculatedDeductions
        } = calculateExpenseAmounts({ amount, isTaxInclusive: is_tax_inclusive, taxes, deductions });

        await ensureExpenseDuplicateFree({ 
            req, 
            payment_date, 
            category_id, 
            net_payable_amount, 
            invoice_ref_no, 
            expense_note,
            vendor_id,
            transaction: t 
        });

        const expense = await req.propertyDb.models.expenses.create({
            outlet_id: req.user.outlet_id,
            vendor_id,
            category_id,
            invoice_ref_no,
            payment_date,
            payment_method,
            is_tax_inclusive,
            base_amount,
            total_tax_amount,
            total_deduction_amount,
            net_payable_amount,
            expense_note,
            status,
            created_by: req.user.id
        }, { transaction: t });

        if (calculatedTaxes.length > 0) {
            await req.propertyDb.models.expense_taxes.bulkCreate(
                calculatedTaxes.map(tax => ({
                    expense_id: expense.id,
                    tax_name: tax.tax_name,
                    tax_percentage: tax.tax_percentage,
                    tax_amount: tax.tax_amount
                })),
                { transaction: t }
            );
        }

        if (calculatedDeductions.length > 0) {
            await req.propertyDb.models.expense_deductions.bulkCreate(
                calculatedDeductions.map(ded => ({
                    expense_id: expense.id,
                    deduction_type: ded.deduction_type,
                    deduction_percentage: ded.deduction_percentage,
                    deduction_amount: ded.deduction_amount
                })),
                { transaction: t }
            );
        }

        if (status === 'Paid') {
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: payment_date,
                transaction_type: 'EXPENSE',
                reference_type: 'EXPENSE',
                reference_id: expense.id,
                reference_no: invoice_ref_no || `EXP-${expense.id.slice(0, 8)}`,
                party_name: categoryRow.category_name,
                payment_method: payment_method,
                amount_out: net_payable_amount,
                notes: expense_note,
                created_by: req.user.id,
                transaction: t
            });
        }

        await t.commit();
        res.json({ success: true, data: expense });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.updateExpense = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const expense = await req.propertyDb.models.expenses.findOne({
            where: { id: req.params.id, outlet_id: req.user.outlet_id },
            transaction: t
        });

        if (!expense) throw new Error('Expense entry not found');

        const amount = toAmount(req.body.amount ?? (expense.is_tax_inclusive ? (Number(expense.base_amount) + Number(expense.total_tax_amount)) : expense.base_amount));
        const is_tax_inclusive = req.body.is_tax_inclusive !== undefined ? (req.body.is_tax_inclusive === true || req.body.is_tax_inclusive === 'true') : expense.is_tax_inclusive;
        const taxes = req.body.taxes || [];
        const deductions = req.body.deductions || [];
        const vendor_id = req.body.vendor_id !== undefined ? (req.body.vendor_id ? Number(req.body.vendor_id) : null) : expense.vendor_id;
        const category_id = req.body.category_id || expense.category_id;
        const invoice_ref_no = req.body.invoice_ref_no !== undefined ? String(req.body.invoice_ref_no).trim() : expense.invoice_ref_no;
        const payment_date = dateKey(req.body.payment_date || expense.payment_date);
        const payment_method = req.body.payment_method || req.body.payment_mode || expense.payment_method;
        const expense_note = req.body.expense_note !== undefined ? req.body.expense_note : expense.expense_note;
        const status = req.body.status || expense.status;

        const categoryRow = await req.propertyDb.models.expense_categories.findOne({
            where: { id: category_id, outlet_id: req.user.outlet_id },
            transaction: t
        });
        if (!categoryRow) throw new Error('Category not found');

        const {
            base_amount,
            total_tax_amount,
            total_deduction_amount,
            net_payable_amount,
            taxes: calculatedTaxes,
            deductions: calculatedDeductions
        } = calculateExpenseAmounts({ amount, isTaxInclusive: is_tax_inclusive, taxes, deductions });

        await ensureExpenseDuplicateFree({ 
            req, 
            payment_date, 
            category_id, 
            net_payable_amount, 
            invoice_ref_no, 
            expense_note,
            vendor_id,
            excludeId: expense.id,
            transaction: t 
        });

        await expense.update({
            vendor_id,
            category_id,
            invoice_ref_no,
            payment_date,
            payment_method,
            is_tax_inclusive,
            base_amount,
            total_tax_amount,
            total_deduction_amount,
            net_payable_amount,
            expense_note,
            status
        }, { transaction: t });

        await req.propertyDb.models.expense_taxes.destroy({
            where: { expense_id: expense.id },
            transaction: t
        });
        await req.propertyDb.models.expense_deductions.destroy({
            where: { expense_id: expense.id },
            transaction: t
        });

        if (calculatedTaxes.length > 0) {
            await req.propertyDb.models.expense_taxes.bulkCreate(
                calculatedTaxes.map(tax => ({
                    expense_id: expense.id,
                    tax_name: tax.tax_name,
                    tax_percentage: tax.tax_percentage,
                    tax_amount: tax.tax_amount
                })),
                { transaction: t }
            );
        }

        if (calculatedDeductions.length > 0) {
            await req.propertyDb.models.expense_deductions.bulkCreate(
                calculatedDeductions.map(ded => ({
                    expense_id: expense.id,
                    deduction_type: ded.deduction_type,
                    deduction_percentage: ded.deduction_percentage,
                    deduction_amount: ded.deduction_amount
                })),
                { transaction: t }
            );
        }

        const ledgerEntry = await findLinkedLedgerEntry(req.propertyDb, req.user.outlet_id, 'EXPENSE', expense.id, t);
        if (status === 'Paid') {
            if (ledgerEntry) {
                await updateLedgerEntry({
                    db: req.propertyDb,
                    entryId: ledgerEntry.id,
                    outlet_id: req.user.outlet_id,
                    values: {
                        txn_date: payment_date,
                        party_name: categoryRow.category_name,
                        payment_method: payment_method,
                        amount_out: net_payable_amount,
                        notes: expense_note
                    },
                    transaction: t
                });
            } else {
                await createLedgerEntry({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    txn_date: payment_date,
                    transaction_type: 'EXPENSE',
                    reference_type: 'EXPENSE',
                    reference_id: expense.id,
                    reference_no: invoice_ref_no || `EXP-${expense.id.slice(0, 8)}`,
                    party_name: categoryRow.category_name,
                    payment_method: payment_method,
                    amount_out: net_payable_amount,
                    notes: expense_note,
                    created_by: req.user.id,
                    transaction: t
                });
            }
        } else {
            if (ledgerEntry) {
                await ledgerEntry.destroy({ transaction: t });
                await recalculateLedgerBalances({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    fromDate: ledgerEntry.txn_date,
                    transaction: t
                });
            }
        }

        await t.commit();
        res.json({ success: true, data: expense });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.createRepayment = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const sale_id = Number(req.body.sale_id);
        const payment_date = dateKey(req.body.payment_date || new Date());
        const amount = toAmount(req.body.amount);
        const payment_mode = String(req.body.payment_mode || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no || '').trim() || null;
        const note = String(req.body.note || '').trim() || null;

        if (!Number.isFinite(sale_id) || sale_id <= 0) throw new Error('Sale id is required');
        if (amount <= 0) throw new Error('Repayment amount must be greater than 0');

        const sale = await getSaleOrFail(req, sale_id, t);
        const waiveOff = isWaiveOffMode(payment_mode);

        const repaymentTotal = await getRepaymentTotal({ db: req.propertyDb, sale_id, transaction: t });
        const initialPaid = toAmount(sale.initial_amount_paid ?? sale.amount_paid);
        const available = Math.max(0, toAmount(sale.net_amount) - initialPaid - repaymentTotal);

        // Always auto-adjust excess payment against other outstanding bills first, then advance
        const adjustExtra = true;

        let currentBillRepayment = null;
        let balance = 0;

        if (amount > available + 0.009 && adjustExtra) {
            const applyToCurrent = available;
            let extraAmount = roundAmount(amount - applyToCurrent);

            if (applyToCurrent > 0) {
                await ensureRepaymentDuplicateFree({ req, sale_id, payment_date, amount: applyToCurrent, payment_mode, reference_no, transaction: t });

                currentBillRepayment = await req.propertyDb.models.customer_repayments.create({
                    outlet_id: req.user.outlet_id,
                    sale_id,
                    payment_date,
                    amount: applyToCurrent,
                    payment_mode,
                    reference_no,
                    note,
                    created_by: req.user.id,
                    updated_by: req.user.id
                }, { transaction: t });

                await createLedgerEntry({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    txn_date: payment_date,
                    transaction_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                    reference_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                    reference_id: currentBillRepayment.id,
                    reference_no: sale.sale_no,
                    party_name: getCustomerLabel(sale),
                    payment_method: payment_mode,
                    amount_in: waiveOff ? 0 : applyToCurrent,
                    amount_out: waiveOff ? applyToCurrent : 0,
                    notes: note || (waiveOff
                        ? `Waive off applied for ${sale.sale_no}`
                        : `Repayment received for ${sale.sale_no}`),
                    created_by: req.user.id,
                    transaction: t
                });

                balance = await refreshSaleOutstanding({ db: req.propertyDb, sale, transaction: t });
            } else {
                balance = 0;
            }

            // Find details of the customer to match other credit bills
            const customer_phone = sale.customer_phone;
            const customer_name = sale.customer_name;
            const customer_gstin = sale.customer_gstin;

            const orConditions = [];
            if (customer_phone) orConditions.push({ customer_phone: String(customer_phone).trim() });
            if (customer_gstin) orConditions.push({ customer_gstin: String(customer_gstin).trim().toUpperCase() });
            if (customer_name) orConditions.push({ customer_name: String(customer_name).trim() });

            let otherSales = [];
            if (orConditions.length > 0) {
                otherSales = await req.propertyDb.models.sales_headers.findAll({
                    where: {
                        id: { [Op.ne]: sale_id },
                        outlet_id: req.user.outlet_id,
                        status: 'COMPLETED',
                        is_latest: true,
                        is_deleted: false,
                        balance_due: { [Op.gt]: 0 },
                        [Op.or]: orConditions
                    },
                    order: [['sale_date', 'ASC'], ['id', 'ASC']],
                    transaction: t
                });
            }

            const otherRepaymentsCreated = [];
            for (const otherSale of otherSales) {
                if (extraAmount <= 0) break;

                const otherOutstanding = toAmount(otherSale.balance_due);
                if (otherOutstanding <= 0) continue;

                // Exclude delivery orders that are not credit payment
                if (otherSale.order_type === 'DELIVERY' && otherSale.payment_mode !== 'CREDIT') {
                    continue;
                }

                const applyAmount = Math.min(extraAmount, otherOutstanding);

                await ensureRepaymentDuplicateFree({
                    req,
                    sale_id: otherSale.id,
                    payment_date,
                    amount: applyAmount,
                    payment_mode,
                    reference_no,
                    transaction: t
                });

                const otherRepayment = await req.propertyDb.models.customer_repayments.create({
                    outlet_id: req.user.outlet_id,
                    sale_id: otherSale.id,
                    payment_date,
                    amount: applyAmount,
                    payment_mode,
                    reference_no,
                    note: note || `Excess repayment adjusted from ${sale.sale_no}`,
                    created_by: req.user.id,
                    updated_by: req.user.id
                }, { transaction: t });

                otherRepaymentsCreated.push(otherRepayment);

                await createLedgerEntry({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    txn_date: payment_date,
                    transaction_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                    reference_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                    reference_id: otherRepayment.id,
                    reference_no: otherSale.sale_no,
                    party_name: getCustomerLabel(otherSale),
                    payment_method: payment_mode,
                    amount_in: waiveOff ? 0 : applyAmount,
                    amount_out: waiveOff ? applyAmount : 0,
                    notes: note || (waiveOff
                        ? `Waive off applied for ${otherSale.sale_no}`
                        : `Excess repayment adjusted from ${sale.sale_no} for ${otherSale.sale_no}`),
                    created_by: req.user.id,
                    transaction: t
                });

                await refreshSaleOutstanding({ db: req.propertyDb, sale: otherSale, transaction: t });
                extraAmount = roundAmount(extraAmount - applyAmount);
            }

            let advanceCreated = null;
            if (extraAmount > 0) {
                const identity = {
                    customer_name: customer_name || null,
                    customer_phone: customer_phone || null,
                    customer_gstin: customer_gstin || null
                };

                advanceCreated = await req.propertyDb.models.customer_advances.create({
                    outlet_id: req.user.outlet_id,
                    source_sale_id: null,
                    customer_name: identity.customer_name,
                    customer_phone: identity.customer_phone,
                    customer_gstin: identity.customer_gstin,
                    advance_date: payment_date,
                    original_amount: extraAmount,
                    available_amount: extraAmount,
                    payment_mode,
                    reference_no,
                    note: note || `Excess repayment surplus from ${sale.sale_no}`,
                    created_by: req.user.id,
                    updated_by: req.user.id
                }, { transaction: t });

                await createLedgerEntry({
                    db: req.propertyDb,
                    outlet_id: req.user.outlet_id,
                    txn_date: payment_date,
                    transaction_type: 'CUSTOMER_ADVANCE',
                    reference_type: 'ADVANCE',
                    reference_id: advanceCreated.id,
                    reference_no,
                    party_name: getCustomerLabelFromIdentity(identity),
                    payment_method: payment_mode,
                    amount_in: extraAmount,
                    notes: note || `Excess repayment surplus from ${sale.sale_no} received from ${getCustomerLabelFromIdentity(identity)}`,
                    created_by: req.user.id,
                    transaction: t
                });
            }

            await t.commit();
            res.json({
                success: true,
                data: {
                    repayment: currentBillRepayment || (otherRepaymentsCreated.length > 0 ? otherRepaymentsCreated[0] : null),
                    balance,
                    adjusted_other_bills_count: otherRepaymentsCreated.length,
                    excess_advance: advanceCreated
                }
            });
        } else {
            await ensureRepaymentDuplicateFree({ req, sale_id, payment_date, amount, payment_mode, reference_no, transaction: t });

            const repayment = await req.propertyDb.models.customer_repayments.create({
                outlet_id: req.user.outlet_id,
                sale_id,
                payment_date,
                amount,
                payment_mode,
                reference_no,
                note,
                created_by: req.user.id,
                updated_by: req.user.id
            }, { transaction: t });

            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: payment_date,
                transaction_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                reference_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                reference_id: repayment.id,
                reference_no: sale.sale_no,
                party_name: getCustomerLabel(sale),
                payment_method: payment_mode,
                amount_in: waiveOff ? 0 : amount,
                amount_out: waiveOff ? amount : 0,
                notes: note || (waiveOff
                    ? `Waive off applied for ${sale.sale_no}`
                    : `Repayment received for ${sale.sale_no}`),
                created_by: req.user.id,
                transaction: t
            });

            balance = await refreshSaleOutstanding({ db: req.propertyDb, sale, transaction: t });
            await t.commit();
            res.json({ success: true, data: { repayment, balance } });
        }
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.updateRepayment = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const repayment = await req.propertyDb.models.customer_repayments.findOne({
            where: { id: req.params.id, outlet_id: req.user.outlet_id },
            transaction: t
        });

        if (!repayment) throw new Error('Repayment entry not found');

        const sale = await getSaleOrFail(req, repayment.sale_id, t);
        const payment_date = dateKey(req.body.payment_date || repayment.payment_date);
        const amount = toAmount(req.body.amount ?? repayment.amount);
        const payment_mode = String(req.body.payment_mode || repayment.payment_mode || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no ?? repayment.reference_no ?? '').trim() || null;
        const note = String(req.body.note ?? repayment.note ?? '').trim() || null;
        const waiveOff = isWaiveOffMode(payment_mode);

        await ensureRepaymentDuplicateFree({ req, sale_id: repayment.sale_id, payment_date, amount, payment_mode, reference_no, excludeId: repayment.id, transaction: t });
        const repaymentTotal = await getRepaymentTotal({ db: req.propertyDb, sale_id: repayment.sale_id, exclude_repayment_id: repayment.id, transaction: t });
        const initialPaid = toAmount(sale.initial_amount_paid ?? sale.amount_paid);
        const available = Math.max(0, toAmount(sale.net_amount) - initialPaid - repaymentTotal);
        if (amount > available + 0.009) throw new Error(`Repayment exceeds outstanding balance. Available amount is ${available.toFixed(2)}`);

        await repayment.update({ payment_date, amount, payment_mode, reference_no, note, updated_by: req.user.id }, { transaction: t });

        const ledgerEntry =
            await findLinkedLedgerEntry(req.propertyDb, req.user.outlet_id, waiveOff ? 'WAIVE_OFF' : 'REPAYMENT', repayment.id, t) ||
            await findLinkedLedgerEntry(req.propertyDb, req.user.outlet_id, waiveOff ? 'REPAYMENT' : 'WAIVE_OFF', repayment.id, t);
        if (ledgerEntry) {
            await updateLedgerEntry({
                db: req.propertyDb,
                entryId: ledgerEntry.id,
                outlet_id: req.user.outlet_id,
                values: {
                    txn_date: payment_date,
                    transaction_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                    reference_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                    reference_no: sale.sale_no,
                    party_name: getCustomerLabel(sale),
                    payment_method: payment_mode,
                    amount_in: waiveOff ? 0 : amount,
                    amount_out: waiveOff ? amount : 0,
                    notes: note || (waiveOff
                        ? `Waive off applied for ${sale.sale_no}`
                        : `Repayment received for ${sale.sale_no}`),
                },
                transaction: t
            });
        }

        const balance = await refreshSaleOutstanding({ db: req.propertyDb, sale, transaction: t });
        await t.commit();
        res.json({ success: true, data: { repayment, balance } });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.createAdvance = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const identity = normalizeCustomerIdentity(req.body);
        ensureCustomerIdentity(identity);

        const advance_date = dateKey(req.body.advance_date || new Date());
        const amount = toAmount(req.body.amount);
        const payment_mode = String(req.body.payment_mode || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no || '').trim() || null;
        const note = String(req.body.note || '').trim() || null;
        const source_sale_id = Number(req.body.source_sale_id) || null;

        if (amount <= 0) throw new Error('Advance amount must be greater than 0');

        const advance = await req.propertyDb.models.customer_advances.create({
            outlet_id: req.user.outlet_id,
            source_sale_id,
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_gstin: identity.customer_gstin || null,
            advance_date,
            original_amount: amount,
            available_amount: amount,
            payment_mode,
            reference_no,
            note,
            created_by: req.user.id,
            updated_by: req.user.id
        }, { transaction: t });

        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: advance_date,
            transaction_type: 'CUSTOMER_ADVANCE',
            reference_type: 'ADVANCE',
            reference_id: advance.id,
            reference_no,
            party_name: getCustomerLabelFromIdentity(identity),
            payment_method: payment_mode,
            amount_in: amount,
            notes: note || `Advance received from ${getCustomerLabelFromIdentity(identity)}`,
            created_by: req.user.id,
            transaction: t
        });

        await t.commit();
        res.json({ success: true, data: advance });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.updateAdvance = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const advance = await req.propertyDb.models.customer_advances.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });

        if (!advance) throw new Error('Advance entry not found');

        const identity = normalizeCustomerIdentity({
            customer_name: req.body.customer_name ?? advance.customer_name,
            customer_phone: req.body.customer_phone ?? advance.customer_phone,
            customer_gstin: req.body.customer_gstin ?? advance.customer_gstin
        });
        ensureCustomerIdentity(identity);

        const advance_date = dateKey(req.body.advance_date || advance.advance_date || new Date());
        const amount = toAmount(req.body.amount ?? advance.original_amount);
        const payment_mode = String(req.body.payment_mode || advance.payment_mode || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no ?? advance.reference_no ?? '').trim() || null;
        const note = String(req.body.note ?? advance.note ?? '').trim() || null;

        if (amount <= 0) throw new Error('Advance amount must be greater than 0');

        const utilized = Math.max(
            0,
            toAmount(advance.original_amount) - toAmount(advance.available_amount)
        );
        if (amount + 0.009 < utilized) {
            throw new Error(`Advance amount cannot be less than already used amount ${utilized.toFixed(2)}`);
        }

        const available_amount = toAmount(amount - utilized);

        await advance.update({
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_gstin: identity.customer_gstin || null,
            advance_date,
            original_amount: amount,
            available_amount,
            payment_mode,
            reference_no,
            note,
            updated_by: req.user.id
        }, { transaction: t });

        const ledgerEntry = await findLinkedLedgerEntry(
            req.propertyDb,
            req.user.outlet_id,
            'ADVANCE',
            advance.id,
            t
        );
        if (ledgerEntry) {
            await updateLedgerEntry({
                db: req.propertyDb,
                entryId: ledgerEntry.id,
                outlet_id: req.user.outlet_id,
                values: {
                    txn_date: advance_date,
                    reference_type: 'ADVANCE',
                    reference_no,
                    party_name: getCustomerLabelFromIdentity(identity),
                    payment_method: payment_mode,
                    amount_in: amount,
                    amount_out: 0,
                    adjustment_amount: 0,
                    notes: note || `Advance received from ${getCustomerLabelFromIdentity(identity)}`
                },
                transaction: t
            });
        }

        await t.commit();
        res.json({ success: true, data: advance });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.refundAdvance = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const advance = await req.propertyDb.models.customer_advances.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });

        if (!advance) throw new Error('Advance entry not found');

        const amount = toAmount(req.body.amount);
        const payment_mode = String(req.body.payment_mode || 'CASH').trim().toUpperCase();
        const reference_no = String(req.body.reference_no || '').trim() || null;
        const note = String(req.body.note || '').trim() || null;

        if (amount <= 0) throw new Error('Refund amount must be greater than 0');
        if (amount > toAmount(advance.available_amount)) {
            throw new Error(`Refund amount cannot exceed available advance of ${advance.available_amount}`);
        }

        const newAvailable = toAmount(advance.available_amount - amount);

        await advance.update({
            available_amount: newAvailable,
            updated_by: req.user.id
        }, { transaction: t });

        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: dateKey(new Date()),
            transaction_type: 'CUSTOMER_ADVANCE_REFUND',
            reference_type: 'ADVANCE',
            reference_id: advance.id,
            reference_no,
            party_name: advance.customer_name || 'Customer',
            payment_method: payment_mode,
            amount_out: amount,
            notes: note || `Advance refund to ${advance.customer_name}`,
            created_by: req.user.id,
            transaction: t
        });

        // Append refund details directly to the advance note!
        const refundNote = `(Refunded Rs. ${amount.toFixed(2)})`;
        const updatedNote = advance.note 
            ? `${advance.note} ${refundNote}`.trim()
            : refundNote;

        await advance.update({
            note: updatedNote,
            updated_by: req.user.id
        }, { transaction: t });

        await t.commit();
        res.json({ success: true, data: advance });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.applyAdvance = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const identity = normalizeCustomerIdentity(req.body);
        ensureCustomerIdentity(identity);

        const sale_id = Number(req.body.sale_id);
        const payment_date = dateKey(req.body.payment_date || new Date());
        const amount = toAmount(req.body.amount);
        const payment_mode = String(req.body.payment_mode || 'ADVANCE').trim().toUpperCase();
        const reference_no = String(req.body.reference_no || '').trim() || null;
        const note = String(req.body.note || '').trim() || null;

        if (!Number.isFinite(sale_id) || sale_id <= 0) throw new Error('Sale id is required');
        if (amount <= 0) throw new Error('Advance apply amount must be greater than 0');

        const sale = await getSaleOrFail(req, sale_id, t);
        const where = {
            outlet_id: req.user.outlet_id,
            available_amount: { [Op.gt]: 0 },
            ...(buildCustomerExactMatch(identity) || {})
        };
        const advances = await req.propertyDb.models.customer_advances.findAll({
            where,
            order: [['advance_date', 'ASC'], ['id', 'ASC']],
            transaction: t
        });

        const available = advances.reduce(
            (sum, advance) => sum + toAmount(advance.available_amount),
            0
        );
        if (amount > available + 0.009) {
            throw new Error(`Advance exceeds available balance. Available amount is ${available.toFixed(2)}`);
        }

        let remaining = amount;
        for (const advance of advances) {
            if (remaining <= 0.009) break;
            const currentAvailable = toAmount(advance.available_amount);
            const used = remaining > currentAvailable ? currentAvailable : remaining;
            await advance.update({
                available_amount: Math.max(0, toAmount(currentAvailable - used)),
                updated_by: req.user.id
            }, { transaction: t });
            remaining = toAmount(remaining - used);
        }

        await req.propertyDb.models.customer_repayments.create({
            outlet_id: req.user.outlet_id,
            sale_id,
            payment_date,
            amount,
            payment_mode,
            reference_no,
            note: note || `Advance applied on ${sale.sale_no}`,
            created_by: req.user.id,
            updated_by: req.user.id
        }, { transaction: t });

        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            txn_date: payment_date,
            transaction_type: 'ADVANCE_APPLY',
            reference_type: 'SALE',
            reference_id: sale.id,
            reference_no: sale.sale_no,
            party_name: getCustomerLabel(sale),
            payment_method: payment_mode,
            adjustment_amount: amount,
            notes: note || `Advance adjusted against ${sale.sale_no}`,
            created_by: req.user.id,
            transaction: t
        });

        const balance = await refreshSaleOutstanding({ db: req.propertyDb, sale, transaction: t });
        await t.commit();
        res.json({ success: true, data: { balance, applied_amount: amount } });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.listRepayments = async (req, res) => {
    try {
        const where = { outlet_id: req.user.outlet_id };
        if (req.query.sale_id) where.sale_id = Number(req.query.sale_id);
        if (req.query.from_date || req.query.to_date) {
            where.payment_date = {};
            if (req.query.from_date) where.payment_date[Op.gte] = dateKey(req.query.from_date);
            if (req.query.to_date) where.payment_date[Op.lte] = dateKey(req.query.to_date);
        }

        const data = await req.propertyDb.models.customer_repayments.findAll({
            where,
            include: [{
                model: req.propertyDb.models.sales_headers,
                as: 'sale',
                attributes: ['id', 'sale_no', 'customer_name', 'customer_phone', 'net_amount', 'amount_paid', 'balance_due']
            }],
            order: [['payment_date', 'DESC'], ['id', 'DESC']]
        });

        res.json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.setOpeningBalance = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const balance_date = dateKey(req.body.balance_date || new Date());
        const opening_balance = toAmount(req.body.opening_balance);
        const note = String(req.body.note || '').trim() || null;

        const openingRow = await upsertOpeningBalance({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            balance_date,
            opening_balance,
            note,
            user_id: req.user.id,
            transaction: t
        });

        const existingLedgerEntry = await findLinkedLedgerEntry(
            req.propertyDb,
            req.user.outlet_id,
            'OPENING_DEPOSIT',
            openingRow.id,
            t
        );

        const ledgerValues = {
            txn_date: balance_date,
            reference_type: 'OPENING_DEPOSIT',
            reference_id: openingRow.id,
            reference_no: `OPN-${balance_date}`,
            party_name: 'Business Deposit',
            payment_method: 'CASH',
            amount_in: opening_balance,
            amount_out: 0,
            adjustment_amount: 0,
            notes: note || `Opening deposit added on ${balance_date}`
        };

        if (existingLedgerEntry) {
            await updateLedgerEntry({
                db: req.propertyDb,
                entryId: existingLedgerEntry.id,
                outlet_id: req.user.outlet_id,
                values: ledgerValues,
                transaction: t
            });
        } else {
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                transaction_type: 'OPENING_DEPOSIT',
                created_by: req.user.id,
                transaction: t,
                ...ledgerValues
            });
        }

        await t.commit();
        res.json({ success: true, data: { balance_date, opening_balance, note } });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getOpeningBalances = async (req, res) => {
    try {
        const where = { outlet_id: req.user.outlet_id };
        if (req.query.date) {
            where.balance_date = dateKey(req.query.date);
        } else if (req.query.from_date || req.query.to_date) {
            where.balance_date = {};
            if (req.query.from_date) where.balance_date[Op.gte] = dateKey(req.query.from_date);
            if (req.query.to_date) where.balance_date[Op.lte] = dateKey(req.query.to_date);
        }

        const rows = await req.propertyDb.models.daily_opening_balances.findAll({
            where,
            order: [['balance_date', 'DESC'], ['id', 'DESC']]
        });

        const targetDate = req.query.date || req.query.from_date || new Date();
        const carriedOpening = await getOpeningBalanceForDate({
            db: req.propertyDb,
            outlet_id: req.user.outlet_id,
            balanceDate: targetDate
        });

        res.json({ success: true, summary: { carried_opening_balance: carriedOpening }, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getExpenseReport = async (req, res) => {
    try {
        console.log("--- getExpenseReport Hit ---");
        const [info] = await req.propertyDb.query("SELECT current_database(), current_schema(), current_user");
        console.log("Database Info from HTTP Server:", info[0]);
        console.log("req.user:", req.user);
        console.log("req.query:", req.query);
        const where = { outlet_id: req.user.outlet_id };
        if (req.query.id) {
            where.id = req.query.id;
        }
        if (req.query.from_date || req.query.to_date) {
            where.payment_date = {};
            if (req.query.from_date) where.payment_date[Op.gte] = req.query.from_date;
            if (req.query.to_date) where.payment_date[Op.lte] = req.query.to_date;
        }
        if (req.query.category_id) {
            where.category_id = req.query.category_id;
        }
        if (req.query.category) {
            where['$category.category_name$'] = { [Op.iLike]: `%${req.query.category}%` };
        }

        console.log("getExpenseReport query where:", where);

        const data = await req.propertyDb.models.expenses.findAll({
            where,
            include: [
                { model: req.propertyDb.models.expense_taxes, as: 'taxes', required: false },
                { model: req.propertyDb.models.expense_deductions, as: 'deductions', required: false },
                { model: req.propertyDb.models.expense_categories, as: 'category', required: false },
                { model: req.propertyDb.models.supplier_master, as: 'vendor', required: false }
            ],
            order: [['payment_date', 'DESC'], ['created_at', 'DESC']],
            logging: (sql) => console.log("SQL QUERY:", sql)
        });

        console.log("getExpenseReport query returned count:", data.length);

        const totalAmount = data.reduce((sum, entry) => sum + Number(entry.net_payable_amount || 0), 0);
        res.json({ 
            success: true, 
            summary: { 
                totalAmount: Math.round(totalAmount * 100) / 100, 
                totalCount: data.length 
            }, 
            data 
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteExpense = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const expense = await req.propertyDb.models.expenses.findOne({
            where: { id: req.params.id, outlet_id: req.user.outlet_id },
            transaction: t
        });
        if (!expense) throw new Error('Expense not found');

        const ledgerEntry = await findLinkedLedgerEntry(req.propertyDb, req.user.outlet_id, 'EXPENSE', expense.id, t);
        if (ledgerEntry) {
            await ledgerEntry.destroy({ transaction: t });
            await recalculateLedgerBalances({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                fromDate: ledgerEntry.txn_date,
                transaction: t
            });
        }

        await expense.destroy({ transaction: t });

        await t.commit();
        res.json({ success: true });
    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getExpenseCategories = async (req, res) => {
    try {
        const categories = await req.propertyDb.models.expense_categories.findAll({
            where: { outlet_id: req.user.outlet_id, is_active: true },
            order: [['category_name', 'ASC']]
        });
        res.json({ success: true, data: categories });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createExpenseCategory = async (req, res) => {
    try {
        const category_name = String(req.body.category_name || '').trim();
        if (!category_name) throw new Error('Category name is required');

        const [category, created] = await req.propertyDb.models.expense_categories.findOrCreate({
            where: {
                outlet_id: req.user.outlet_id,
                category_name: Sequelize.where(
                    Sequelize.fn('lower', Sequelize.col('category_name')),
                    category_name.toLowerCase()
                )
            },
            defaults: {
                outlet_id: req.user.outlet_id,
                user_id: req.user.id,
                category_name,
                is_active: true
            }
        });

        if (!created && !category.is_active) {
            await category.update({ is_active: true });
        }

        res.json({ success: true, data: category });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getTaxesMaster = async (req, res) => {
    try {
        const taxes = await req.propertyDb.models.taxes_master.findAll({
            where: { outlet_id: req.user.outlet_id },
            order: [['tax_name', 'ASC']]
        });
        res.json({ success: true, data: taxes });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createTaxesMaster = async (req, res) => {
    try {
        const tax_name = String(req.body.tax_name || '').trim();
        const default_rate = Number(req.body.default_rate || 0);
        if (!tax_name) throw new Error('Tax name is required');

        const [tax, created] = await req.propertyDb.models.taxes_master.findOrCreate({
            where: {
                outlet_id: req.user.outlet_id,
                tax_name: Sequelize.where(
                    Sequelize.fn('lower', Sequelize.col('tax_name')),
                    tax_name.toLowerCase()
                )
            },
            defaults: {
                outlet_id: req.user.outlet_id,
                tax_name,
                default_rate,
                is_editable: true
            }
        });

        if (!created) {
            await tax.update({ default_rate });
        }

        res.json({ success: true, data: tax });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getExpenseAnalytics = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const allOutlets = req.query.all_outlets === 'true' && req.user.role === 'ADMIN';

        const where = {};
        if (!allOutlets) {
            where.outlet_id = outlet_id;
        }

        if (req.query.from_date || req.query.to_date) {
            where.payment_date = {};
            if (req.query.from_date) where.payment_date[Op.gte] = req.query.from_date;
            if (req.query.to_date) where.payment_date[Op.lte] = req.query.to_date;
        }

        const expenses = await req.propertyDb.models.expenses.findAll({
            where,
            include: [
                { model: req.propertyDb.models.expense_taxes, as: 'taxes', required: false },
                { model: req.propertyDb.models.expense_deductions, as: 'deductions', required: false },
                { model: req.propertyDb.models.expense_categories, as: 'category', required: false },
                { model: req.propertyDb.models.supplier_master, as: 'vendor', required: false }
            ],
            bypassOutletFilter: allOutlets
        });

        let totalInputTaxPaid = 0;
        let totalTdsDeducted = 0;
        let totalTcsCollected = 0;

        const taxBreakdown = {};
        const categoryBreakdown = {};
        const vendorSpend = {};

        expenses.forEach(exp => {
            if (exp.taxes) {
                exp.taxes.forEach(t => {
                    const name = t.tax_name || 'Other';
                    const amount = Number(t.tax_amount || 0);
                    totalInputTaxPaid += amount;
                    taxBreakdown[name] = (taxBreakdown[name] || 0) + amount;
                });
            }

            if (exp.deductions) {
                exp.deductions.forEach(d => {
                    const amount = Number(d.deduction_amount || 0);
                    if (d.deduction_type === 'TDS') {
                        totalTdsDeducted += amount;
                    } else if (d.deduction_type === 'TCS') {
                        totalTcsCollected += amount;
                    }
                });
            }

            const catName = exp.category ? exp.category.category_name : 'Uncategorized';
            categoryBreakdown[catName] = (categoryBreakdown[catName] || 0) + Number(exp.base_amount || 0);

            let vendorName = exp.vendor ? exp.vendor.supplier_name : 'Direct Cash';
            if (!exp.vendor && exp.expense_note) {
                if (exp.expense_note.startsWith('Paid To: ')) {
                    vendorName = exp.expense_note.split(' | ')[0].substring(9);
                } else if (exp.expense_note.startsWith('Paid To Staff: ')) {
                    vendorName = exp.expense_note.split(' | ')[0].substring(15);
                }
            }
            vendorSpend[vendorName] = (vendorSpend[vendorName] || 0) + Number(exp.net_payable_amount || 0);
        });

        const taxPieData = Object.keys(taxBreakdown).map(name => ({
            name,
            value: Math.round(taxBreakdown[name] * 100) / 100
        }));

        const categoryBarData = Object.keys(categoryBreakdown).map(name => ({
            category: name,
            amount: Math.round(categoryBreakdown[name] * 100) / 100
        })).sort((a, b) => b.amount - a.amount);

        const allVendorsSpend = Object.keys(vendorSpend).map(name => ({
            vendor: name,
            amount: Math.round(vendorSpend[name] * 100) / 100
        })).sort((a, b) => b.amount - a.amount);

        res.json({
            success: true,
            summary: {
                totalInputTaxPaid: Math.round(totalInputTaxPaid * 100) / 100,
                totalTdsDeducted: Math.round(totalTdsDeducted * 100) / 100,
                totalTcsCollected: Math.round(totalTcsCollected * 100) / 100,
                totalSpend: Math.round(expenses.reduce((sum, e) => sum + Number(e.net_payable_amount), 0) * 100) / 100
            },
            taxBreakdown: taxPieData,
            categoryBreakdown: categoryBarData,
            vendorSpend: allVendorsSpend,
            expenses: expenses
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getLedgerReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const where = buildLedgerWhere(outlet_id, req.query);
        const fromDate = parseDateOnly(req.query.from_date, new Date());
        const toDate = parseDateOnly(req.query.to_date, fromDate);

        const entries = await req.propertyDb.models.cash_ledger.findAll({
            where,
            order: [['txn_date', 'ASC'], ['id', 'ASC']]
        });

        let openingBalance = await getOpeningBalanceForDate({
            db: req.propertyDb,
            outlet_id,
            balanceDate: fromDate
        });

        const depositTotal = entries
            .filter((entry) => String(entry.transaction_type || '').toUpperCase() === 'OPENING_DEPOSIT')
            .reduce((sum, entry) => sum + toAmount(entry.amount_in), 0);
        const totalIn = entries.reduce((sum, entry) => {
            if (String(entry.transaction_type || '').toUpperCase() === 'OPENING_DEPOSIT') {
                return sum;
            }
            return sum + toAmount(entry.amount_in);
        }, 0);
        const totalOut = entries.reduce((sum, entry) => sum + toAmount(entry.amount_out), 0);
        const closingBalance = entries.length > 0 ? toAmount(entries[entries.length - 1].balance) : openingBalance;
        const paymentMethodSummary = entries.reduce((acc, entry) => {
            const key = String(entry.payment_method || 'UNKNOWN').trim().toUpperCase() || 'UNKNOWN';
            if (!acc[key]) {
                acc[key] = {
                    payment_method: key,
                    amount_in: 0,
                    amount_out: 0,
                    count: 0
                };
            }
            acc[key].amount_in += toAmount(entry.amount_in);
            acc[key].amount_out += toAmount(entry.amount_out);
            acc[key].count += 1;
            return acc;
        }, {});

        const openingRows = await req.propertyDb.models.daily_opening_balances.findAll({
            where: {
                outlet_id,
                balance_date: { [Op.between]: [dateKey(fromDate), dateKey(toDate)] }
            },
            order: [['balance_date', 'ASC']]
        });
        const daily = buildDailyLedgerGroups(entries, new Map(), openingBalance)
            .map((group) => ({
                ...group,
                date: dateKey(group.date),
                entries: group.entries.map((entry) => ({
                    ...entry,
                    txn_date: dateKey(entry.txn_date)
                }))
            }))
            .reverse();

        res.json({
            success: true,
            summary: { openingBalance, depositTotal, totalIn, totalOut, closingBalance },
            payment_method_summary: Object.values(paymentMethodSummary),
            daily,
            openings: openingRows,
            data: entries.map(serializeLedgerEntry)
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getPaymentFlowReport = async (req, res) => {
    try {
        const where = buildLedgerWhere(req.user.outlet_id, req.query);
        delete where[Op.or];
        const data = await req.propertyDb.models.cash_ledger.findAll({
            where,
            attributes: [
                'transaction_type',
                [Sequelize.fn('SUM', Sequelize.col('amount_in')), 'total_in'],
                [Sequelize.fn('SUM', Sequelize.col('amount_out')), 'total_out']
            ],
            group: ['transaction_type'],
            order: [['transaction_type', 'ASC']]
        });
        res.json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getCreditReport = async (req, res) => {
    try {
        const where = {
            outlet_id: req.user.outlet_id,
            status: 'COMPLETED',
            is_latest: true,
            is_deleted: false
        };
        const customerMatch = buildCustomerMatch(String(req.query.customer || req.query.search || '').trim());
        if (customerMatch) Object.assign(where, customerMatch);

        const sales = await req.propertyDb.models.sales_headers.findAll({
            where,
            include: [{ model: req.propertyDb.models.customer_repayments, as: 'repayments', required: false }],
            order: [['sale_date', 'DESC'], ['id', 'DESC']]
        });
        const advanceWhere = {
            outlet_id: req.user.outlet_id
        };
        const customerAdvanceMatch = buildCustomerMatch(String(req.query.customer || req.query.search || '').trim());
        if (customerAdvanceMatch) Object.assign(advanceWhere, customerAdvanceMatch);
        const advances = await req.propertyDb.models.customer_advances.findAll({
            where: advanceWhere,
            order: [['advance_date', 'ASC'], ['id', 'ASC']]
        });

        const customers = new Map();
        let totalOutstanding = 0;
        let totalCreditBills = 0;
        let totalAdvance = 0;

        for (const sale of sales) {
            const initialPaid = toAmount(sale.initial_amount_paid ?? sale.amount_paid);
            const repaymentTotal = (sale.repayments || []).reduce((sum, payment) => sum + toAmount(payment.amount), 0);
            const totalPaid = toAmount(initialPaid + repaymentTotal);
            const balanceDue = Math.max(0, toAmount(sale.net_amount) - totalPaid);
            const isCreditBill = balanceDue > 0.009;
            if (!isCreditBill) continue;

            // Exclude delivery orders that are not credit payment
            if (sale.order_type === 'DELIVERY' && sale.payment_mode !== 'CREDIT') {
                continue;
            }

            totalCreditBills += 1;
            totalOutstanding += balanceDue;
            const key = buildCustomerKey(sale);
            if (!customers.has(key)) {
                customers.set(key, {
                    customer_name: getCustomerLabel(sale),
                    customer_phone: sale.customer_phone || '',
                    customer_gstin: sale.customer_gstin || '',
                    customer_address: sale.customer_address || '',
                    total_outstanding: 0,
                    total_advance: 0,
                    bills: [],
                    advances: []
                });
            }

            const customer = customers.get(key);
            if (!customer.customer_address && sale.customer_address) {
                customer.customer_address = sale.customer_address;
            }
            customer.total_outstanding = roundAmount(customer.total_outstanding + balanceDue);
            customer.bills.push({
                sale_id: sale.id,
                bill_no: sale.sale_no,
                bill_date: sale.sale_date,
                amount: toAmount(sale.net_amount),
                initial_paid: initialPaid,
                repayment_total: repaymentTotal,
                total_paid: totalPaid,
                outstanding: balanceDue,
                payment_status: resolvePaymentStatus(totalPaid, toAmount(sale.net_amount), sale.payment_mode),
                payments: (sale.repayments || []).map((payment) => ({
                    id: payment.id,
                    payment_date: payment.payment_date,
                    amount: toAmount(payment.amount),
                    payment_mode: payment.payment_mode,
                    reference_no: payment.reference_no || '',
                    note: payment.note || ''
                }))
            });
        }

        for (const advance of advances) {
            const key = buildCustomerKey(advance);
            if (!customers.has(key)) {
                customers.set(key, {
                    customer_name: getCustomerLabel(advance),
                    customer_phone: advance.customer_phone || '',
                    customer_gstin: advance.customer_gstin || '',
                    customer_address: '',
                    total_outstanding: 0,
                    total_advance: 0,
                    bills: [],
                    advances: []
                });
            }
            const customer = customers.get(key);
            const availableAmount = toAmount(advance.available_amount);
            customer.total_advance = roundAmount((customer.total_advance || 0) + availableAmount);
            customer.advances.push({
                id: advance.id,
                advance_date: advance.advance_date,
                source_sale_id: advance.source_sale_id,
                original_amount: toAmount(advance.original_amount),
                available_amount: availableAmount,
                payment_mode: advance.payment_mode,
                reference_no: advance.reference_no || '',
                note: advance.note || ''
            });
            totalAdvance += availableAmount;
        }

        for (const customer of customers.values()) {
            customer.total_advance = roundAmount(customer.total_advance || 0);
            customer.advances = Array.isArray(customer.advances) ? customer.advances : [];
        }

        const resultCustomers = Array.from(customers.values()).filter(
            (c) => c.total_outstanding > 0.009 || c.total_advance > 0.009
        );

        res.json({
            success: true,
            summary: {
                total_customers: resultCustomers.length,
                total_credit_bills: resultCustomers.reduce((sum, c) => sum + c.bills.length, 0),
                total_outstanding: roundAmount(resultCustomers.reduce((sum, c) => sum + c.total_outstanding, 0)),
                total_advance: roundAmount(resultCustomers.reduce((sum, c) => sum + c.total_advance, 0))
            },
            data: resultCustomers
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getDeliveryReport = async (req, res) => {
    try {
        const where = {
            outlet_id: req.user.outlet_id,
            status: 'COMPLETED',
            is_latest: true,
            is_deleted: false
        };
        if (req.query.from_date || req.query.to_date) {
            where.sale_date = {};
            if (req.query.from_date) where.sale_date[Op.gte] = parseDateOnly(req.query.from_date);
            if (req.query.to_date) where.sale_date[Op.lte] = endOfDay(req.query.to_date);
        }
        if (req.query.search) {
            where[Op.or] = [
                { sale_no: { [Op.iLike]: `%${req.query.search}%` } },
                { customer_name: { [Op.iLike]: `%${req.query.search}%` } },
                { customer_phone: { [Op.iLike]: `%${req.query.search}%` } }
            ];
        }

        const sales = await req.propertyDb.models.sales_headers.findAll({ where, order: [['sale_date', 'DESC'], ['id', 'DESC']] });
        const data = sales
            .map((sale) => ({
                sale_id: sale.id,
                date: sale.sale_date,
                bill_no: sale.sale_no,
                customer_name: getCustomerLabel(sale),
                customer_phone: sale.customer_phone || '',
                // net_amount already includes round_off_amount - do not subtract again
                amount: toAmount(sale.net_amount),
                paid_amount: toAmount(sale.amount_paid),
                outstanding: toAmount(sale.balance_due),
                payment_mode: String(sale.payment_mode || '').trim().toUpperCase(),
                payment_status: resolvePaymentStatus(sale.amount_paid, toAmount(sale.net_amount), sale.payment_mode)
            }))
            .filter((row) => !req.query.status || row.payment_status === String(req.query.status).toUpperCase());

        res.json({
            success: true,
            summary: {
                total_orders: data.length,
                total_amount: roundAmount(data.reduce((sum, row) => sum + row.amount, 0)),
                total_outstanding: roundAmount(data.reduce((sum, row) => sum + row.outstanding, 0))
            },
            data
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getExpiryReport = async (req, res) => {
    try {
        const alertDays = Number(req.query.alert_days || 7);
        const status = String(req.query.status || 'ALL').trim().toUpperCase();
        const search = String(req.query.search || '').trim().toLowerCase();

        const stockRows = await req.propertyDb.models.stock_ledger.findAll({
            where: { outlet_id: req.user.outlet_id },
            attributes: [
                'item_code',
                [Sequelize.literal('SUM(COALESCE(qty_in,0) - COALESCE(qty_out,0))'), 'stock_qty']
            ],
            group: ['item_code'],
            raw: true
        });

        const positiveStock = new Map();
        for (const row of stockRows) {
            const qty = toAmount(row.stock_qty);
            if (qty > 0) {
                positiveStock.set(String(row.item_code || ''), qty);
            }
        }

        const itemCodes = Array.from(positiveStock.keys());
        if (itemCodes.length === 0) {
            return res.json({
                success: true,
                summary: {
                    total_items: 0,
                    expired_count: 0,
                    near_expiry_count: 0
                },
                data: []
            });
        }

        const rows = await req.propertyDb.models.goods_receipt_items.findAll({
            where: {
                expiry_date: { [Op.ne]: null },
                item_code: { [Op.in]: itemCodes }
            },
            include: [{
                model: req.propertyDb.models.goods_receipts,
                as: 'grn',
                where: { outlet_id: req.user.outlet_id },
                attributes: ['grn_no', 'receipt_date']
            }],
            order: [['item_code', 'ASC'], ['id', 'DESC']]
        });

        const latestByItem = new Map();
        for (const row of rows) {
            const key = String(row.item_code || '');
            if (!latestByItem.has(key)) {
                latestByItem.set(key, row);
            }
        }

        const today = startOfDay(new Date());
        const data = Array.from(latestByItem.values())
            .map((row) => {
                const expiryDate = parseDateOnly(row.expiry_date);
                const daysLeft = Math.floor((expiryDate - today) / (1000 * 60 * 60 * 24));
                const expiryState = daysLeft < 0 ? 'EXPIRED' : daysLeft <= alertDays ? 'NEAR_EXPIRY' : 'SAFE';
                return {
                    id: row.id,
                    item_code: row.item_code,
                    item_name: row.item_name,
                    qty: positiveStock.get(String(row.item_code || '')) ?? 0,
                    unit: row.unit || '',
                    expiry_date: row.expiry_date,
                    days_left: daysLeft,
                    status: expiryState,
                    grn_no: row.grn?.grn_no || '',
                    receipt_date: row.grn?.receipt_date || null
                };
            })
            .filter((row) => !search || row.item_name.toLowerCase().includes(search) || row.item_code.toLowerCase().includes(search))
            .filter((row) => status === 'ALL' || row.status === status);

        res.json({
            success: true,
            summary: {
                total_items: data.length,
                expired_count: data.filter((row) => row.status === 'EXPIRED').length,
                near_expiry_count: data.filter((row) => row.status === 'NEAR_EXPIRY').length
            },
            data
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.adjustBulkRepayment = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const { customer_name, customer_phone, customer_gstin, payment_date, payment_mode, reference_no, note } = req.body;
        const totalAmount = toAmount(req.body.amount);
        const paymentDate = dateKey(payment_date || new Date());
        const paymentMode = String(payment_mode || 'CASH').trim().toUpperCase();
        const referenceNo = String(reference_no || '').trim() || null;
        const repaymentNote = String(note || '').trim() || null;

        if (totalAmount <= 0) {
            throw new Error('Repayment amount must be greater than 0');
        }

        if (!customer_phone && !customer_gstin && !customer_name) {
            throw new Error('Customer identification (phone, GSTIN, or name) is required');
        }

        const orConditions = [];
        if (customer_phone) orConditions.push({ customer_phone: String(customer_phone).trim() });
        if (customer_gstin) orConditions.push({ customer_gstin: String(customer_gstin).trim().toUpperCase() });
        if (customer_name) orConditions.push({ customer_name: String(customer_name).trim() });

        const sales = await req.propertyDb.models.sales_headers.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                status: 'COMPLETED',
                is_latest: true,
                is_deleted: false,
                balance_due: { [Op.gt]: 0 },
                [Op.or]: orConditions
            },
            order: [['sale_date', 'ASC'], ['id', 'ASC']],
            transaction: t
        });

        let remainingAmount = totalAmount;
        const repaymentsCreated = [];

        for (const sale of sales) {
            if (remainingAmount <= 0) break;

            const outstanding = toAmount(sale.balance_due);
            if (outstanding <= 0) continue;

            // Exclude delivery orders that are not credit payment
            if (sale.order_type === 'DELIVERY' && sale.payment_mode !== 'CREDIT') {
                continue;
            }

            const applyAmount = Math.min(remainingAmount, outstanding);

            await ensureRepaymentDuplicateFree({
                req,
                sale_id: sale.id,
                payment_date: paymentDate,
                amount: applyAmount,
                payment_mode: paymentMode,
                reference_no: referenceNo,
                transaction: t
            });

            const waiveOff = isWaiveOffMode(paymentMode);

            const repayment = await req.propertyDb.models.customer_repayments.create({
                outlet_id: req.user.outlet_id,
                sale_id: sale.id,
                payment_date: paymentDate,
                amount: applyAmount,
                payment_mode: paymentMode,
                reference_no: referenceNo,
                note: repaymentNote,
                created_by: req.user.id,
                updated_by: req.user.id
            }, { transaction: t });

            repaymentsCreated.push(repayment);

            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: paymentDate,
                transaction_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                reference_type: waiveOff ? 'WAIVE_OFF' : 'REPAYMENT',
                reference_id: repayment.id,
                reference_no: sale.sale_no,
                party_name: getCustomerLabel(sale),
                payment_method: paymentMode,
                amount_in: waiveOff ? 0 : applyAmount,
                amount_out: waiveOff ? applyAmount : 0,
                notes: repaymentNote || (waiveOff
                    ? `Waive off applied for ${sale.sale_no}`
                    : `Bulk repayment received for ${sale.sale_no}`),
                created_by: req.user.id,
                transaction: t
            });

            await refreshSaleOutstanding({ db: req.propertyDb, sale, transaction: t });

            remainingAmount = roundAmount(remainingAmount - applyAmount);
        }

        let advanceCreated = null;
        if (remainingAmount > 0) {
            const identity = {
                customer_name: customer_name || null,
                customer_phone: customer_phone || null,
                customer_gstin: customer_gstin || null
            };

            advanceCreated = await req.propertyDb.models.customer_advances.create({
                outlet_id: req.user.outlet_id,
                source_sale_id: null,
                customer_name: identity.customer_name,
                customer_phone: identity.customer_phone,
                customer_gstin: identity.customer_gstin,
                advance_date: paymentDate,
                original_amount: remainingAmount,
                available_amount: remainingAmount,
                payment_mode: paymentMode,
                reference_no: referenceNo,
                note: repaymentNote || 'Excess bulk repayment auto-advance',
                created_by: req.user.id,
                updated_by: req.user.id
            }, { transaction: t });

            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: req.user.outlet_id,
                txn_date: paymentDate,
                transaction_type: 'CUSTOMER_ADVANCE',
                reference_type: 'ADVANCE',
                reference_id: advanceCreated.id,
                reference_no: referenceNo,
                party_name: getCustomerLabelFromIdentity(identity),
                payment_method: paymentMode,
                amount_in: remainingAmount,
                notes: repaymentNote || `Excess bulk repayment auto-advance received from ${getCustomerLabelFromIdentity(identity)}`,
                created_by: req.user.id,
                transaction: t
            });
        }

        await t.commit();
        res.json({
            success: true,
            message: `Bulk repayment of ${totalAmount.toFixed(2)} processed successfully.`,
            settled_bills_count: repaymentsCreated.length,
            repayments: repaymentsCreated,
            excess_advance: advanceCreated
        });

    } catch (error) {
        await t.rollback();
        res.status(400).json({ success: false, error: error.message });
    }
};

exports.getRecurringExpenses = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 1;
        const items = await req.propertyDb.models.recurring_expenses.findAll({
            where: { outlet_id },
            order: [['id', 'DESC']]
        });
        res.json({ success: true, data: items });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};

exports.createRecurringExpense = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 1;
        const { description, amount, frequency, expense_category_id, start_date, end_date, next_generation_date } = req.body;
        
        const todayStr = new Date().toISOString().split('T')[0];
        const record = await req.propertyDb.models.recurring_expenses.create({
            outlet_id,
            description,
            amount: parseFloat(amount) || 0,
            frequency: frequency || 'MONTHLY',
            expense_category_id: expense_category_id || null,
            start_date: start_date || todayStr,
            end_date: end_date || null,
            next_generation_date: next_generation_date || start_date || todayStr,
            is_active: true
        });

        res.json({ success: true, data: record });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};

exports.updateRecurringExpense = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 1;
        const { id } = req.params;
        const record = await req.propertyDb.models.recurring_expenses.findOne({ where: { id, outlet_id } });
        if (!record) return res.status(404).json({ success: false, message: 'Recurring expense not found' });

        await record.update(req.body);
        res.json({ success: true, data: record });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};

exports.deleteRecurringExpense = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 1;
        const { id } = req.params;
        await req.propertyDb.models.recurring_expenses.destroy({ where: { id, outlet_id } });
        res.json({ success: true, message: 'Deleted successfully' });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};

