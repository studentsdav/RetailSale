const { Op, Sequelize } = require('sequelize');

/**
 * Calculates stock valuation (Closing Stock) for an outlet
 */
async function getClosingStockValuation(req, outlet_id) {
    try {
        const items = await req.propertyDb.models.item_master.findAll({
            where: { outlet_id, is_active: true },
            attributes: ['id', 'item_code', 'rate', 'retail_sale_price', 'mrp', 'opening_balance'],
            raw: true
        });

        if (!items || items.length === 0) return 0;

        const stockMovements = await req.propertyDb.models.stock_ledger.findAll({
            where: { outlet_id },
            attributes: [
                'item_code',
                [Sequelize.fn('SUM', Sequelize.literal('qty_in - qty_out')), 'net_qty']
            ],
            group: ['item_code'],
            raw: true
        });

        const stockMap = new Map();
        stockMovements.forEach(s => {
            stockMap.set(s.item_code, Number(s.net_qty || 0));
        });

        let totalValuation = 0;
        items.forEach(item => {
            const movementQty = stockMap.get(item.item_code) || 0;
            const openingQty = Number(item.opening_balance || 0);
            const currentQty = Math.max(0, openingQty + movementQty);
            const costPrice = Number(item.rate || item.retail_sale_price || item.mrp || 0);
            totalValuation += currentQty * costPrice;
        });

        return Number(totalValuation.toFixed(2));
    } catch (err) {
        console.error('Error calculating closing stock valuation:', err);
        return 0;
    }
}

/**
 * Calculates completed sales revenue and itemized COGS for an outlet
 */
async function getCompletedSalesMetrics(req, outlet_id) {
    try {
        const salesHeaderSummary = await req.propertyDb.models.sales_headers.findOne({
            where: { outlet_id, status: 'COMPLETED', is_deleted: false },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('net_amount')), 'total_net'],
                [Sequelize.fn('SUM', Sequelize.col('total_tax')), 'total_tax'],
                [Sequelize.fn('SUM', Sequelize.col('taxable_amount')), 'total_taxable'],
                [Sequelize.fn('SUM', Sequelize.col('total_discount')), 'total_discount']
            ],
            raw: true
        });

        const salesItems = await req.propertyDb.models.sales_items.findAll({
            include: [
                {
                    model: req.propertyDb.models.sales_headers,
                    as: 'sale',
                    where: { outlet_id, status: 'COMPLETED', is_deleted: false, is_latest: true },
                    attributes: []
                },
                {
                    model: req.propertyDb.models.item_master,
                    as: 'item',
                    attributes: ['rate', 'retail_sale_price']
                }
            ],
            raw: true,
            nest: true
        });

        let itemizedCogs = 0;
        let itemizedTaxableRevenue = 0;
        for (const si of salesItems || []) {
            const qty = Number(si.qty || 0);
            const costRate = Number(si.item?.rate || 0);
            itemizedCogs += qty * costRate;

            const lineTaxable = Number(si.taxable_amount || 0);
            const lineTax = Number(si.tax_amount || 0);
            const lineNet = Number(si.net_amount || 0);
            const taxable = lineTaxable > 0 ? lineTaxable : (lineNet > 0 ? Math.max(0, lineNet - lineTax) : Number(si.amount || 0));
            itemizedTaxableRevenue += taxable;
        }

        const rawNet = Number(salesHeaderSummary?.total_net || 0);
        const rawTax = Number(salesHeaderSummary?.total_tax || 0);
        const rawTaxable = Number(salesHeaderSummary?.total_taxable || 0);
        const salesDiscounts = Number(salesHeaderSummary?.total_discount || 0);

        const netSalesRevenue = itemizedTaxableRevenue > 0
            ? Number(itemizedTaxableRevenue.toFixed(2))
            : (rawTaxable > 0 ? Number(rawTaxable.toFixed(2)) : Number(Math.max(0, rawNet - rawTax - salesDiscounts).toFixed(2)));

        const grossSalesRevenue = Number((netSalesRevenue + salesDiscounts).toFixed(2));
        const totalOutputTax = Number(rawTax.toFixed(2));

        return {
            netSalesRevenue,
            grossSalesRevenue,
            salesDiscounts,
            totalOutputTax,
            itemizedCogs,
            rawSalesNet: rawNet
        };
    } catch (err) {
        console.error('Error in getCompletedSalesMetrics:', err);
        return {
            netSalesRevenue: 0,
            grossSalesRevenue: 0,
            salesDiscounts: 0,
            totalOutputTax: 0,
            itemizedCogs: 0,
            rawSalesNet: 0
        };
    }
}

/**
 * Aggregates all operating expenses from expenses table, expense_entries table, and cash_ledger
 */
async function getExpensesSummaryAndCategories(req, outlet_id) {
    let totalExpenses = 0;
    const categoryMap = new Map();
    const processedIds = new Set();

    // 1. Query expenses table (Modern Expense Master & Quick Entries)
    if (req.propertyDb.models.expenses) {
        try {
            const expList = await req.propertyDb.models.expenses.findAll({
                where: { outlet_id },
                include: [{
                    model: req.propertyDb.models.expense_categories,
                    as: 'category',
                    attributes: ['name']
                }],
                raw: true,
                nest: true
            });

            expList.forEach(e => {
                const amt = Number(e.net_payable_amount || e.base_amount || 0);
                let catName = e.category?.name || 'Shop Rent / Office Expenses';
                if (catName.toLowerCase().includes('office') || catName.toLowerCase().includes('rent')) {
                    catName = 'Shop Rent / Office Expenses';
                }
                if (amt > 0) {
                    totalExpenses += amt;
                    categoryMap.set(catName, (categoryMap.get(catName) || 0) + amt);
                    if (e.id) processedIds.add(String(e.id));
                }
            });
        } catch (err) {
            console.error('Error reading expenses table:', err);
        }
    }

    // 2. Query expense_entries table (Legacy / Quick Entries)
    if (req.propertyDb.models.expense_entries) {
        try {
            const legacyList = await req.propertyDb.models.expense_entries.findAll({
                where: { outlet_id },
                raw: true
            });

            legacyList.forEach(e => {
                const amt = Number(e.amount || 0);
                let catName = e.category || 'Shop Rent / Office Expenses';
                if (catName.toLowerCase().includes('office') || catName.toLowerCase().includes('rent')) {
                    catName = 'Shop Rent / Office Expenses';
                }
                if (amt > 0) {
                    totalExpenses += amt;
                    categoryMap.set(catName, (categoryMap.get(catName) || 0) + amt);
                    if (e.id) processedIds.add(String(e.id));
                }
            });
        } catch (err) {
            console.error('Error reading expense_entries table:', err);
        }
    }

    // 3. Query cash_ledger table for EXPENSE transactions (Cash/Bank Ledger Direct Expenses)
    if (req.propertyDb.models.cash_ledger) {
        try {
            const cashExpList = await req.propertyDb.models.cash_ledger.findAll({
                where: {
                    outlet_id,
                    transaction_type: 'EXPENSE'
                },
                raw: true
            });

            cashExpList.forEach(e => {
                const amt = Number(e.amount_out || 0);
                const isAlreadyProcessed = e.reference_id && processedIds.has(String(e.reference_id));
                
                if (amt > 0 && !isAlreadyProcessed) {
                    let catName = e.party_name ? String(e.party_name).trim() : 'Shop Rent / Office Expenses';
                    const lowerCat = catName.toLowerCase();
                    if (lowerCat.includes('office') || lowerCat.includes('rent')) {
                        catName = 'Shop Rent / Office Expenses';
                    } else if (lowerCat.includes('electricity') || lowerCat.includes('water')) {
                        catName = 'Electricity & Water Charges';
                    } else if (lowerCat.includes('salary') || lowerCat.includes('wages')) {
                        catName = 'Salaries & Wages';
                    } else if (lowerCat.includes('packaging') || lowerCat.includes('printing')) {
                        catName = 'Packaging & Printing Costs';
                    }

                    totalExpenses += amt;
                    categoryMap.set(catName, (categoryMap.get(catName) || 0) + amt);
                }
            });
        } catch (err) {
            console.error('Error reading cash_ledger expenses:', err);
        }
    }

    return { totalExpenses: Number(totalExpenses.toFixed(2)), categoryMap };
}

/**
 * Aggregates Direct / Indirect Income entries
 */
async function getIndirectIncomeTotal(req, outlet_id) {
    let totalIncome = 0;
    if (req.propertyDb.models.income_entries) {
        try {
            const inc = await req.propertyDb.models.income_entries.findOne({
                where: { outlet_id },
                attributes: [[Sequelize.fn('SUM', Sequelize.col('amount')), 'total_inc']],
                raw: true
            });
            totalIncome += Number(inc?.total_inc || 0);
        } catch (_) {}
    }

    try {
        const cashInc = await req.propertyDb.models.cash_ledger.findOne({
            where: { outlet_id, transaction_type: 'INCOME' },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('amount_in')), 'total_inc']],
            raw: true
        });
        totalIncome += Number(cashInc?.total_inc || 0);
    } catch (_) {}

    return Number(totalIncome.toFixed(2));
}

/**
 * Aggregates Owner Drawings / Withdrawals
 */
async function getOwnerWithdrawalsTotal(req, outlet_id) {
    let totalWithdrawals = 0;
    if (req.propertyDb.models.withdrawals) {
        try {
            const w = await req.propertyDb.models.withdrawals.findOne({
                where: { outlet_id },
                attributes: [[Sequelize.fn('SUM', Sequelize.col('amount')), 'total_w']],
                raw: true
            });
            totalWithdrawals += Number(w?.total_w || 0);
        } catch (_) {}
    }

    try {
        const cashW = await req.propertyDb.models.cash_ledger.findOne({
            where: { outlet_id, transaction_type: 'WITHDRAWAL' },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('amount_out')), 'total_w']],
            raw: true
        });
        totalWithdrawals += Number(cashW?.total_w || 0);
    } catch (_) {}

    return Number(totalWithdrawals.toFixed(2));
}

/**
 * Aggregates Customer Outstanding Dues (Sundry Debtors)
 */
async function getSundryDebtorsTotal(req, outlet_id) {
    let totalDues = 0;
    try {
        const s = await req.propertyDb.models.sales_headers.findOne({
            where: { outlet_id, status: 'COMPLETED' },
            attributes: [[Sequelize.fn('SUM', Sequelize.col('balance_due')), 'total_due']],
            raw: true
        });
        totalDues = Number(s?.total_due || 0);
    } catch (_) {}
    return Number(totalDues.toFixed(2));
}

/**
 * Aggregates Customer Advances / Subscriptions
 */
async function getCustomerAdvancesTotal(req, outlet_id) {
    let totalAdv = 0;
    if (req.propertyDb.models.customer_advances) {
        try {
            const adv = await req.propertyDb.models.customer_advances.findOne({
                where: { outlet_id },
                attributes: [[Sequelize.fn('SUM', Sequelize.col('available_amount')), 'total_adv']],
                raw: true
            });
            totalAdv = Number(adv?.total_adv || 0);
        } catch (_) {}
    }
    return Number(totalAdv.toFixed(2));
}

/**
 * Aggregates Capital Assets, Company Investments & Active Loans
 */
async function getCapitalAssetsAndLoansSummary(req, outlet_id) {
    let totalAssetsVal = 0;
    const assetGroupMap = new Map();
    let totalLoanLiabilities = 0;

    if (req.propertyDb.models.capital_assets) {
        try {
            const list = await req.propertyDb.models.capital_assets.findAll({
                where: { outlet_id },
                raw: true
            });
            list.forEach(a => {
                const val = Number(a.current_value || a.purchase_cost || 0);
                let catName = 'Infrastructure & Fixed Assets';
                if (a.asset_category === 'INVESTMENT_SHARES') catName = 'Investment in Other Companies / Shares';
                else if (a.asset_category === 'PROPERTY_REAL_ESTATE') catName = 'Property & Real Estate Investments';
                else if (a.asset_category === 'MACHINERY_EQUIPMENT') catName = 'Machinery & POS Equipment';
                else if (a.asset_category === 'VEHICLE') catName = 'Commercial Vehicles';
                else if (a.asset_category === 'COMPUTER_HARDWARE') catName = 'Computers & IT Hardware';

                totalAssetsVal += val;
                assetGroupMap.set(catName, (assetGroupMap.get(catName) || 0) + val);
            });
        } catch (_) {}
    }

    if (req.propertyDb.models.business_loans) {
        try {
            const loans = await req.propertyDb.models.business_loans.findAll({
                where: { outlet_id, status: 'ACTIVE' },
                raw: true
            });
            loans.forEach(l => {
                totalLoanLiabilities += Number(l.remaining_principal || 0);
            });
        } catch (_) {}
    }

    return { totalAssetsVal, assetGroupMap, totalLoanLiabilities: Number(totalLoanLiabilities.toFixed(2)) };
}

exports.getTrialBalance = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        // 1. Fetch custom accounts from Chart of Accounts
        const customAccounts = await req.propertyDb.models.chart_of_accounts.findAll({
            where: { outlet_id, is_active: true }
        });

        // 2. Cash Drawer Balance (Physical Cash ONLY)
        const cashSummary = await req.propertyDb.models.cash_ledger.findOne({
            where: {
                outlet_id,
                [Op.or]: [
                    { payment_method: 'CASH' },
                    { payment_method: null },
                    { transaction_type: 'SALE_CASH' }
                ]
            },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('amount_in')), 'total_in'],
                [Sequelize.fn('SUM', Sequelize.col('amount_out')), 'total_out']
            ],
            raw: true
        });
        const cashIn = Number(cashSummary?.total_in || 0);
        const cashOut = Number(cashSummary?.total_out || 0);
        const cashBalance = cashIn - cashOut;

        // 3. Bank Accounts Total
        const banks = await req.propertyDb.models.bank_accounts.findAll({
            where: { outlet_id, is_active: true }
        });
        const totalBankBalance = banks.reduce((sum, b) => sum + Number(b.current_balance || 0), 0);

        // 4. Sales Revenue & Output Tax
        const { netSalesRevenue, totalOutputTax } = await getCompletedSalesMetrics(req, outlet_id);

        // 5. Purchases (GRN) & Input GST Taxes
        const grnSummary = await req.propertyDb.models.goods_receipts.findOne({
            where: { outlet_id },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total_amount'],
                [Sequelize.fn('SUM', Sequelize.col('total_gst')), 'total_tax'],
                [Sequelize.fn('SUM', Sequelize.col('net_amount')), 'net_amount']
            ],
            raw: true
        });
        const totalGrnSubtotal = Number(grnSummary?.total_amount || 0);
        const totalInputTax = Number(grnSummary?.total_tax || 0);
        const totalGrnNet = Number(grnSummary?.net_amount || 0);
        const netPurchases = totalGrnSubtotal > 0 ? totalGrnSubtotal : Math.max(0, totalGrnNet - totalInputTax);

        // 6. Operating Expenses
        const { totalExpenses } = await getExpensesSummaryAndCategories(req, outlet_id);

        // 7. Customer & Supplier Balances
        const sundryDebtors = await getSundryDebtorsTotal(req, outlet_id);
        const customerAdvances = await getCustomerAdvancesTotal(req, outlet_id);

        let sundryCreditors = 0;
        try {
            const supplierBillsSummary = await req.propertyDb.models.supplier_bills.findOne({
                where: { outlet_id },
                attributes: [
                    [Sequelize.fn('SUM', Sequelize.literal('bill_amount - paid_amount')), 'total_payables']
                ],
                raw: true
            });
            sundryCreditors = Math.max(0, Number(supplierBillsSummary?.total_payables || 0));
        } catch (_) {}

        // 8. Capital Assets & Loans
        const { assetGroupMap, totalLoanLiabilities } = await getCapitalAssetsAndLoansSummary(req, outlet_id);

        // Build Exact Trial Balance Account Rows
        const rows = [
            {
                account_name: 'Main Cash Drawer',
                group_name: 'Current Assets',
                nature: 'ASSET',
                debit: cashBalance >= 0 ? Number(cashBalance.toFixed(2)) : 0,
                credit: cashBalance < 0 ? Number(Math.abs(cashBalance).toFixed(2)) : 0
            },
            {
                account_name: 'Bank Accounts Total',
                group_name: 'Bank Accounts',
                nature: 'ASSET',
                debit: totalBankBalance >= 0 ? Number(totalBankBalance.toFixed(2)) : 0,
                credit: totalBankBalance < 0 ? Number(Math.abs(totalBankBalance).toFixed(2)) : 0
            },
            {
                account_name: 'Purchases Account',
                group_name: 'Direct Expenses',
                nature: 'EXPENSE',
                debit: Number(netPurchases.toFixed(2)),
                credit: 0
            },
            {
                account_name: 'Input GST (ITC) Account',
                group_name: 'Duties & Taxes (Assets)',
                nature: 'ASSET',
                debit: Number(totalInputTax.toFixed(2)),
                credit: 0
            },
            {
                account_name: 'Sales Revenue Account',
                group_name: 'Sales Income',
                nature: 'REVENUE',
                debit: 0,
                credit: Number(netSalesRevenue.toFixed(2))
            },
            {
                account_name: 'Output GST Payable Account',
                group_name: 'Duties & Taxes (Liabilities)',
                nature: 'LIABILITY',
                debit: 0,
                credit: Number(totalOutputTax.toFixed(2))
            },
            {
                account_name: 'Operating Expenses Account',
                group_name: 'Indirect Expenses',
                nature: 'EXPENSE',
                debit: Number(totalExpenses.toFixed(2)),
                credit: 0
            }
        ];

        // Add Investments & Capital Assets to Trial Balance
        assetGroupMap.forEach((val, groupName) => {
            if (val > 0) {
                rows.push({
                    account_name: groupName,
                    group_name: 'Fixed Assets / Investments',
                    nature: 'ASSET',
                    debit: Number(val.toFixed(2)),
                    credit: 0
                });
            }
        });

        if (totalLoanLiabilities > 0) {
            rows.push({
                account_name: 'Bank / Business Loans Outstanding',
                group_name: 'Loans & Borrowings',
                nature: 'LIABILITY',
                debit: 0,
                credit: Number(totalLoanLiabilities.toFixed(2))
            });
        }

        if (sundryDebtors > 0) {
            rows.push({
                account_name: 'Sundry Debtors (Customer Dues)',
                group_name: 'Current Assets',
                nature: 'ASSET',
                debit: Number(sundryDebtors.toFixed(2)),
                credit: 0
            });
        }

        if (sundryCreditors > 0) {
            rows.push({
                account_name: 'Sundry Creditors (Vendor Dues)',
                group_name: 'Current Liabilities',
                nature: 'LIABILITY',
                debit: 0,
                credit: Number(sundryCreditors.toFixed(2))
            });
        }

        if (customerAdvances > 0) {
            rows.push({
                account_name: 'Customer Advances / Subscriptions',
                group_name: 'Current Liabilities',
                nature: 'LIABILITY',
                debit: 0,
                credit: Number(customerAdvances.toFixed(2))
            });
        }

        // Custom COA Accounts
        customAccounts.forEach(acc => {
            const deb = Number(acc.opening_debit || 0) + (acc.nature === 'ASSET' || acc.nature === 'EXPENSE' ? Number(acc.current_balance || 0) : 0);
            const cred = Number(acc.opening_credit || 0) + (acc.nature === 'REVENUE' || acc.nature === 'LIABILITY' || acc.nature === 'EQUITY' ? Number(acc.current_balance || 0) : 0);
            if (deb > 0 || cred > 0) {
                rows.push({
                    account_name: acc.account_name,
                    group_name: acc.group_name,
                    nature: acc.nature,
                    debit: Number(deb.toFixed(2)),
                    credit: Number(cred.toFixed(2))
                });
            }
        });

        // Compute Trial Balance Rule Equation
        let sumDebit = rows.reduce((s, r) => s + r.debit, 0);
        let sumCredit = rows.reduce((s, r) => s + r.credit, 0);

        const capitalDiff = sumDebit - sumCredit;
        const equityDebit = capitalDiff < 0 ? Number(Math.abs(capitalDiff).toFixed(2)) : 0;
        const equityCredit = capitalDiff >= 0 ? Number(capitalDiff.toFixed(2)) : 0;

        rows.push({
            account_name: 'Capital / Proprietor Equity Account',
            group_name: 'Capital Account',
            nature: 'EQUITY',
            debit: equityDebit,
            credit: equityCredit
        });

        const finalTotalDebit = Number((sumDebit + equityDebit).toFixed(2));
        const finalTotalCredit = Number((sumCredit + equityCredit).toFixed(2));

        res.json({
            success: true,
            summary: {
                totalDebit: finalTotalDebit,
                totalCredit: finalTotalCredit,
                difference: Number(Math.abs(finalTotalDebit - finalTotalCredit).toFixed(2)),
                isBalanced: Math.abs(finalTotalDebit - finalTotalCredit) < 0.01
            },
            data: rows
        });
    } catch (error) {
        console.error('getTrialBalance error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getProfitAndLoss = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        // Sales Revenue & COGS Metrics
        const { netSalesRevenue, grossSalesRevenue, salesDiscounts, itemizedCogs } = await getCompletedSalesMetrics(req, outlet_id);
        const salesRevenue = grossSalesRevenue;

        // Purchases (COGS)
        const grn = await req.propertyDb.models.goods_receipts.findOne({
            where: { outlet_id },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total_grn'],
                [Sequelize.fn('SUM', Sequelize.col('total_gst')), 'total_tax'],
                [Sequelize.fn('SUM', Sequelize.col('net_amount')), 'net_amount']
            ],
            raw: true
        });
        const grnSubTotal = Number(grn?.total_grn || 0);
        const grnTax = Number(grn?.total_tax || 0);
        const grnNet = Number(grn?.net_amount || 0);
        const purchasesNet = grnSubTotal > 0 ? grnSubTotal : Math.max(0, grnNet - grnTax);
        const openingStock = 0.00;
        const directFreight = 0.00;

        // Closing Stock Valuation
        const closingStockReal = await getClosingStockValuation(req, outlet_id);
        const cogs = itemizedCogs > 0 ? Number(itemizedCogs.toFixed(2)) : Number(Math.max(0, openingStock + purchasesNet + directFreight - closingStockReal).toFixed(2));
        const closingStock = itemizedCogs > 0 ? Number(Math.max(0, openingStock + purchasesNet + directFreight - cogs).toFixed(2)) : closingStockReal;
        const grossProfit = Number((netSalesRevenue - cogs).toFixed(2));

        // Operating Expenses Breakdown
        const { totalExpenses, categoryMap } = await getExpensesSummaryAndCategories(req, outlet_id);

        const defaultCategories = [
            'Shop Rent / Office Expenses',
            'Electricity & Water Charges',
            'Salaries & Wages',
            'Packaging & Printing Costs'
        ];

        const expenseBreakdown = defaultCategories.map(cat => ({
            category: cat,
            amount: Number((categoryMap.get(cat) || 0).toFixed(2))
        }));

        categoryMap.forEach((amt, catName) => {
            if (!defaultCategories.includes(catName)) {
                expenseBreakdown.push({
                    category: catName,
                    amount: Number(amt.toFixed(2))
                });
            }
        });

        const indirectIncome = await getIndirectIncomeTotal(req, outlet_id);
        const totalOperatingIncome = Number((grossProfit + indirectIncome).toFixed(2));
        const netProfit = Number((totalOperatingIncome - totalExpenses).toFixed(2));

        res.json({
            success: true,
            data: {
                tradingAccount: {
                    totalRevenue: Number(salesRevenue.toFixed(2)),
                    salesDiscounts: Number(salesDiscounts.toFixed(2)),
                    netSalesRevenue,
                    openingStock,
                    purchases: Number(purchasesNet.toFixed(2)),
                    directFreight,
                    closingStock,
                    costOfGoodsSold: cogs,
                    grossProfit
                },
                profitAndLossAccount: {
                    grossProfit,
                    indirectIncome,
                    totalOperatingIncome,
                    operatingExpenses: totalExpenses,
                    expenseBreakdown,
                    netProfit
                }
            }
        });
    } catch (error) {
        console.error('getProfitAndLoss error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getBalanceSheet = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        // Cash in Hand (Physical Cash ONLY)
        const cashSummary = await req.propertyDb.models.cash_ledger.findOne({
            where: {
                outlet_id,
                [Op.or]: [
                    { payment_method: 'CASH' },
                    { payment_method: null },
                    { transaction_type: 'SALE_CASH' }
                ]
            },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('amount_in')), 'total_in'],
                [Sequelize.fn('SUM', Sequelize.col('amount_out')), 'total_out']
            ],
            raw: true
        });
        const cashIn = Number(cashSummary?.total_in || 0);
        const cashOut = Number(cashSummary?.total_out || 0);
        const cashBalance = Math.max(0, cashIn - cashOut);

        // Bank Balances
        const banks = await req.propertyDb.models.bank_accounts.findAll({
            where: { outlet_id, is_active: true }
        });
        const bankBalance = banks.reduce((sum, b) => sum + Number(b.current_balance || 0), 0);

        // Sales & Output Tax
        const { netSalesRevenue: salesNet, totalOutputTax: outputGstPayable, itemizedCogs } = await getCompletedSalesMetrics(req, outlet_id);

        // GRN & Input Tax
        const grnSummary = await req.propertyDb.models.goods_receipts.findOne({
            where: { outlet_id },
            attributes: [
                [Sequelize.fn('SUM', Sequelize.col('total_gst')), 'total_input_tax'],
                [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total_grn'],
                [Sequelize.fn('SUM', Sequelize.col('net_amount')), 'net_amount']
            ],
            raw: true
        });
        const inputGstCredit = Number(grnSummary?.total_input_tax || 0);
        const grnSubTotal = Number(grnSummary?.total_grn || 0);
        const grnNet = Number(grnSummary?.net_amount || 0);
        const purchasesNet = grnSubTotal > 0 ? grnSubTotal : Math.max(0, grnNet - inputGstCredit);

        // Customer & Supplier Dues
        const sundryDebtors = await getSundryDebtorsTotal(req, outlet_id);
        const customerAdvances = await getCustomerAdvancesTotal(req, outlet_id);

        let sundryCreditors = 0;
        try {
            const supplierBillsSummary = await req.propertyDb.models.supplier_bills.findOne({
                where: { outlet_id },
                attributes: [
                    [Sequelize.fn('SUM', Sequelize.literal('bill_amount - paid_amount')), 'total_payables']
                ],
                raw: true
            });
            sundryCreditors = Math.max(0, Number(supplierBillsSummary?.total_payables || 0));
        } catch (_) {}

        // Closing Stock Valuation
        const closingStock = await getClosingStockValuation(req, outlet_id);

        // Expenses & Indirect Income
        const { totalExpenses } = await getExpensesSummaryAndCategories(req, outlet_id);
        const indirectIncome = await getIndirectIncomeTotal(req, outlet_id);

        // Net Profit Calculation
        const cogs = itemizedCogs > 0 ? itemizedCogs : Math.max(0, purchasesNet - closingStock);
        const grossProfit = salesNet - cogs;
        const totalOperatingIncome = Number((grossProfit + indirectIncome).toFixed(2));
        const netProfit = Number((totalOperatingIncome - totalExpenses).toFixed(2));

        // Capital Assets & Investments
        const { assetGroupMap, totalLoanLiabilities } = await getCapitalAssetsAndLoansSummary(req, outlet_id);

        const assets = [
            { name: 'Bank Balances', amount: Number(bankBalance.toFixed(2)) },
            { name: 'Cash in Hand', amount: Number(cashBalance.toFixed(2)) },
            { name: 'Closing Stock (Unsold Goods)', amount: Number(closingStock.toFixed(2)) },
            { name: 'Input GST Credit (ITC)', amount: Number(inputGstCredit.toFixed(2)) }
        ];

        assetGroupMap.forEach((val, catName) => {
            if (val > 0) {
                assets.push({ name: catName, amount: Number(val.toFixed(2)) });
            }
        });

        if (sundryDebtors > 0) {
            assets.push({ name: 'Sundry Debtors (Customer Dues)', amount: Number(sundryDebtors.toFixed(2)) });
        }

        const totalAssets = Number(assets.reduce((sum, a) => sum + a.amount, 0).toFixed(2));

        const liabilities = [
            { name: 'Output GST Payable', amount: Number(outputGstPayable.toFixed(2)) }
        ];

        if (totalLoanLiabilities > 0) {
            liabilities.push({ name: 'Bank / Business Loans Outstanding', amount: Number(totalLoanLiabilities.toFixed(2)) });
        }

        if (sundryCreditors > 0) {
            liabilities.push({ name: 'Sundry Creditors (Vendors)', amount: Number(sundryCreditors.toFixed(2)) });
        }

        if (customerAdvances > 0) {
            liabilities.push({ name: 'Customer Advances / Subscriptions', amount: Number(customerAdvances.toFixed(2)) });
        }

        const totalLiabilities = Number(liabilities.reduce((sum, l) => sum + l.amount, 0).toFixed(2));

        const ownerCapital = Number((totalAssets - totalLiabilities - netProfit).toFixed(2));

        const equity = [
            { name: "Owner's Capital Account", amount: ownerCapital },
            { name: 'Retained Earnings / P&L Balance', amount: netProfit }
        ];
        const totalEquity = Number((ownerCapital + netProfit).toFixed(2));

        res.json({
            success: true,
            data: {
                assets,
                liabilities,
                equity,
                totals: {
                    totalAssets,
                    totalLiabilities,
                    totalEquity
                }
            }
        });
    } catch (error) {
        console.error('getBalanceSheet error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getBankReconciliation = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { bank_account_id } = req.query;

        const bank = bank_account_id
            ? await req.propertyDb.models.bank_accounts.findOne({ where: { id: bank_account_id, outlet_id } })
            : await req.propertyDb.models.bank_accounts.findOne({ where: { outlet_id, is_active: true }, order: [['id', 'ASC']] });

        const vouchers = await req.propertyDb.models.accounting_vouchers.findAll({
            where: {
                outlet_id,
                ...(bank?.id ? { bank_account_id: bank.id } : {})
            },
            order: [['voucher_date', 'DESC'], ['id', 'DESC']]
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
