const { Op, Sequelize } = require('sequelize');

exports.getTrialBalance = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        // Fetch custom accounts
        const customAccounts = await req.propertyDb.models.chart_of_accounts.findAll({
            where: { outlet_id, is_active: true }
        });

        // Compute system default balances
        const cashSummary = await req.propertyDb.models.cash_ledger.findOne({
            where: { outlet_id },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('amount_in')), 'total_in'],
                [Sequelize.fn('SUM', Sequelize.col('amount_out')), 'total_out']
            ],
            raw: true
        });

        const totalIn = Number(cashSummary?.total_in || 0);
        const totalOut = Number(cashSummary?.total_out || 0);
        const cashBalance = Math.max(0, totalIn - totalOut);

        const banks = await req.propertyDb.models.bank_accounts.findAll({
            where: { outlet_id, is_active: true }
        });
        const totalBankBalance = banks.reduce((sum, b) => sum + Number(b.current_balance || 0), 0);

        const salesSummary = await req.propertyDb.models.sales_headers.findOne({
            where: { outlet_id },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('net_amount')), 'total_sales']],
            raw: true
        });
        const totalSales = Number(salesSummary?.total_sales || 0);

        const grnSummary = await req.propertyDb.models.goods_receipts.findOne({
            where: { outlet_id },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total_purchases']],
            raw: true
        });
        const totalPurchases = Number(grnSummary?.total_purchases || 0);

        const expenseSummary = await req.propertyDb.models.expense_entries.findOne({
            where: { outlet_id },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('amount')), 'total_expenses']],
            raw: true
        });
        const totalExpenses = Number(expenseSummary?.total_expenses || 0);

        const rows = [
            { account_name: 'Main Cash Drawer', group_name: 'Current Assets', nature: 'ASSET', debit: cashBalance, credit: 0 },
            { account_name: 'Bank Accounts Total', group_name: 'Bank Accounts', nature: 'ASSET', debit: totalBankBalance, credit: 0 },
            { account_name: 'Purchases Account', group_name: 'Direct Expenses', nature: 'EXPENSE', debit: totalPurchases, credit: 0 },
            { account_name: 'Operating Expenses', group_name: 'Indirect Expenses', nature: 'EXPENSE', debit: totalExpenses, credit: 0 },
            { account_name: 'Sales Revenue Account', group_name: 'Sales Income', nature: 'REVENUE', debit: 0, credit: totalSales }
        ];

        customAccounts.forEach(acc => {
            const deb = Number(acc.opening_debit || 0) + (acc.nature === 'ASSET' || acc.nature === 'EXPENSE' ? Number(acc.current_balance || 0) : 0);
            const cred = Number(acc.opening_credit || 0) + (acc.nature === 'REVENUE' || acc.nature === 'LIABILITY' || acc.nature === 'EQUITY' ? Number(acc.current_balance || 0) : 0);
            rows.push({
                account_name: acc.account_name,
                group_name: acc.group_name,
                nature: acc.nature,
                debit: deb,
                credit: cred
            });
        });

        let totalDebit = rows.reduce((s, r) => s + r.debit, 0);
        let totalCredit = rows.reduce((s, r) => s + r.credit, 0);

        res.json({
            success: true,
            summary: {
                totalDebit: Number(totalDebit.toFixed(2)),
                totalCredit: Number(totalCredit.toFixed(2)),
                difference: Number(Math.abs(totalDebit - totalCredit).toFixed(2)),
                isBalanced: Math.abs(totalDebit - totalCredit) < 0.01
            },
            data: rows
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getProfitAndLoss = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const sales = await req.propertyDb.models.sales_headers.findOne({
            where: { outlet_id },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('net_amount')), 'sum']],
            raw: true
        });
        const totalRevenue = Number(sales?.sum || 0);

        const grn = await req.propertyDb.models.goods_receipts.findOne({
            where: { outlet_id },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('total_amount')), 'sum']],
            raw: true
        });
        const cogs = Number(grn?.sum || 0);

        const grossProfit = totalRevenue - cogs;

        const expenses = await req.propertyDb.models.expense_entries.findOne({
            where: { outlet_id },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('amount')), 'sum']],
            raw: true
        });
        const operatingExpenses = Number(expenses?.sum || 0);

        const netProfit = grossProfit - operatingExpenses;

        res.json({
            success: true,
            data: {
                tradingAccount: {
                    totalRevenue,
                    costOfGoodsSold: cogs,
                    grossProfit
                },
                profitAndLossAccount: {
                    grossProfit,
                    operatingExpenses,
                    netProfit
                }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getBalanceSheet = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const cashSummary = await req.propertyDb.models.cash_ledger.findOne({
            where: { outlet_id },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('amount_in')), 'total_in'],
                [Sequelize.fn('SUM', Sequelize.col('amount_out')), 'total_out']
            ],
            raw: true
        });
        const cashBalance = Math.max(0, Number(cashSummary?.total_in || 0) - Number(cashSummary?.total_out || 0));

        const banks = await req.propertyDb.models.bank_accounts.findAll({ where: { outlet_id, is_active: true } });
        const bankBalance = banks.reduce((sum, b) => sum + Number(b.current_balance || 0), 0);

        const totalAssets = cashBalance + bankBalance;
        const totalLiabilities = 0;
        const equity = totalAssets - totalLiabilities;

        res.json({
            success: true,
            data: {
                assets: [
                    { name: 'Cash in Hand', amount: cashBalance },
                    { name: 'Bank Balances', amount: bankBalance }
                ],
                liabilities: [],
                equity: [
                    { name: 'Retained Earnings / Equity', amount: equity }
                ],
                totals: {
                    totalAssets,
                    totalLiabilities,
                    totalEquity: equity
                }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getBankReconciliation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { bank_account_id } = req.query;

        const bank = bank_account_id ? await req.propertyDb.models.bank_accounts.findOne({ where: { id: bank_account_id, outlet_id } }) : null;

        const vouchers = await req.propertyDb.models.accounting_vouchers.findAll({
            where: {
                outlet_id,
                ...(bank_account_id ? { bank_account_id } : {})
            },
            order: [['voucher_date', 'DESC']]
        });

        res.json({
            success: true,
            bankAccount: bank,
            summary: {
                bookBalance: bank ? Number(bank.current_balance) : 0,
                unclearedCheques: 0,
                reconciledBalance: bank ? Number(bank.current_balance) : 0
            },
            data: vouchers
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
