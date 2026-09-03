const { Op, Sequelize } = require('sequelize');
const { createLedgerEntry } = require('../../services/cashLedger.service');

exports.createExpense = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        let expense_date = req.body.expense_date;
        if (!expense_date) {
            const d = new Date();
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            expense_date = `${y}-${m}-${day}`;
        }
        const category = String(req.body.category || '').trim();
        const amount = Number(req.body.amount) || 0;
        const note = String(req.body.note || '').trim() || null;

        if (!category) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Category is required' });
        }

        if (amount <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Amount must be greater than 0' });
        }

        const expense = await req.propertyDb.models.expense_entries.create({
            outlet_id,
            expense_date,
            category,
            amount,
            note,
            created_by
        }, { transaction: t });

        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: expense_date,
            transaction_type: 'EXPENSE',
            reference_type: 'EXPENSE',
            reference_id: expense.id,
            reference_no: `EXP-${expense.id}`,
            party_name: category,
            payment_method: 'CASH',
            amount_out: amount,
            notes: note,
            created_by,
            transaction: t
        });

        // Auto-Post Double-Entry Payment Voucher (PV)
        try {
            const count = await req.propertyDb.models.accounting_vouchers.count({
                where: { outlet_id, voucher_type: 'PAYMENT' },
                transaction: t
            });
            const autoNo = `PV-${String(count + 1).padStart(4, '0')}`;

            const header = await req.propertyDb.models.accounting_vouchers.create({
                outlet_id,
                voucher_no: autoNo,
                voucher_type: 'PAYMENT',
                voucher_date: expense_date,
                payment_mode: 'CASH',
                reference_no: `EXP-${expense.id}`,
                narration: `Auto Payment Voucher for ${category}: ${note || 'Expense Entry'}`,
                total_debit: amount,
                total_credit: amount,
                status: 'POSTED',
                created_by
            }, { transaction: t });

            await req.propertyDb.models.voucher_lines.bulkCreate([
                {
                    voucher_id: header.id,
                    line_type: 'DEBIT',
                    account_name: `${category} Expense A/c`,
                    account_type: 'EXPENSE',
                    debit_amount: amount,
                    credit_amount: 0,
                    particulars: `Direct Expense: ${category}`
                },
                {
                    voucher_id: header.id,
                    line_type: 'CREDIT',
                    account_name: 'Main Cash Drawer',
                    account_type: 'CASH',
                    debit_amount: 0,
                    credit_amount: amount,
                    particulars: 'Cash Outflow for Expense'
                }
            ], { transaction: t });
        } catch (vErr) {
            console.error('Auto Voucher Posting Error:', vErr);
        }

        await t.commit();

        res.json({ success: true, data: expense });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getExpenseReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date, category } = req.query;
        const where = { outlet_id };

        if (from_date && to_date) {
            where.expense_date = { [Op.between]: [from_date, to_date] };
        }
        if (category) {
            where.category = category;
        }

        const data = await req.propertyDb.models.expense_entries.findAll({
            where,
            order: [['expense_date', 'DESC'], ['id', 'DESC']]
        });

        const totalAmount = data.reduce((sum, entry) => sum + Number(entry.amount || 0), 0);

        res.json({
            success: true,
            summary: { totalAmount },
            data
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getLedgerReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date, type } = req.query;
        const where = { outlet_id };

        if (from_date && to_date) {
            where.txn_date = {
                [Op.between]: [
                    new Date(`${from_date}T00:00:00.000Z`),
                    new Date(`${to_date}T23:59:59.999Z`)
                ]
            };
        }
        if (type) {
            where.transaction_type = type;
        }

        // Auto-cleanup any legacy duplicate SALE_DISCOUNT_EXPENSE entries created for SUBSCRIPTION bills
        const duplicateSubDiscountEntries = await req.propertyDb.models.cash_ledger.findAll({
            where: {
                outlet_id,
                transaction_type: 'SALE_DISCOUNT_EXPENSE',
                payment_method: 'SUBSCRIPTION'
            }
        });
        if (duplicateSubDiscountEntries.length > 0) {
            const { recalculateLedgerBalances } = require('../../services/cashLedger.service');
            for (const dup of duplicateSubDiscountEntries) {
                await dup.destroy();
            }
            await recalculateLedgerBalances({ db: req.propertyDb, outlet_id, fromDate: new Date(0) });
        }

        const entries = await req.propertyDb.models.cash_ledger.findAll({
            where,
            order: [['txn_date', 'ASC'], ['id', 'ASC']]
        });

        let openingBalance = 0;
        if (from_date) {
            const opening = await req.propertyDb.models.cash_ledger.findOne({
                where: {
                    outlet_id,
                    txn_date: {
                        [Op.lt]: new Date(`${from_date}T00:00:00.000Z`)
                    }
                },
                order: [['txn_date', 'DESC'], ['id', 'DESC']]
            });
            openingBalance = Number(opening?.balance) || 0;
        }

        const totalIn = entries.reduce((sum, entry) => sum + Number(entry.amount_in || 0), 0);
        const totalOut = entries.reduce((sum, entry) => sum + Number(entry.amount_out || 0), 0);
        const closingBalance = entries.length > 0
            ? Number(entries[entries.length - 1].balance || 0)
            : openingBalance;

        res.json({
            success: true,
            summary: {
                openingBalance,
                totalIn,
                totalOut,
                closingBalance
            },
            data: entries
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getPaymentFlowReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date } = req.query;
        const where = { outlet_id };

        if (from_date && to_date) {
            where.txn_date = {
                [Op.between]: [
                    new Date(`${from_date}T00:00:00.000Z`),
                    new Date(`${to_date}T23:59:59.999Z`)
                ]
            };
        }

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