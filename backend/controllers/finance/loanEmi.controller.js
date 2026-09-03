const { createLedgerEntry } = require('../../services/cashLedger.service');

// Get all Loans & Fixed Assets Summary dynamically from Database
exports.getLoansAndAssets = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        
        let loans = [];
        let assets = [];

        if (req.propertyDb.models.business_loans) {
            loans = await req.propertyDb.models.business_loans.findAll({
                where: { outlet_id },
                order: [['id', 'DESC']]
            });
        }

        if (req.propertyDb.models.capital_assets) {
            assets = await req.propertyDb.models.capital_assets.findAll({
                where: { outlet_id },
                order: [['id', 'DESC']]
            });
        }

        res.json({
            success: true,
            data: { loans, assets }
        });
    } catch (error) {
        console.error('getLoansAndAssets error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
};

// Create a new Business Loan
exports.createLoan = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const { loan_name, lender_name, principal_amount, interest_rate, tenure_months, monthly_emi, remaining_principal, notes } = req.body;

        if (!loan_name || !principal_amount) {
            return res.status(400).json({ success: false, message: 'Loan name and principal amount are required' });
        }

        const pAmount = Number(principal_amount) || 0;
        const emi = Number(monthly_emi) || 0;
        const rem = remaining_principal !== undefined ? Number(remaining_principal) : pAmount;

        const loan = await req.propertyDb.models.business_loans.create({
            outlet_id,
            loan_name: String(loan_name).trim(),
            lender_name: lender_name ? String(lender_name).trim() : null,
            principal_amount: pAmount,
            interest_rate: Number(interest_rate) || 0,
            tenure_months: Number(tenure_months) || 12,
            monthly_emi: emi,
            remaining_principal: rem,
            status: rem <= 0 ? 'CLOSED' : 'ACTIVE',
            notes: notes ? String(notes).trim() : null,
            created_by
        });

        res.json({ success: true, message: 'Business Loan created successfully', data: loan });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// Delete a Business Loan
exports.deleteLoan = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const loan = await req.propertyDb.models.business_loans.findOne({ where: { id, outlet_id } });
        if (!loan) {
            return res.status(404).json({ success: false, message: 'Business loan not found' });
        }

        await loan.destroy();
        res.json({ success: true, message: 'Business loan deleted' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// Create a new Capital Asset
exports.createCapitalAsset = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const { asset_name, asset_category, purchase_date, purchase_cost, current_value, notes } = req.body;

        if (!asset_name || !purchase_cost) {
            return res.status(400).json({ success: false, message: 'Asset name and purchase cost are required' });
        }

        const cost = Number(purchase_cost) || 0;
        const currVal = current_value !== undefined ? Number(current_value) : cost;

        const asset = await req.propertyDb.models.capital_assets.create({
            outlet_id,
            asset_name: String(asset_name).trim(),
            asset_category: asset_category || 'FIXED_ASSET',
            purchase_date: purchase_date || new Date().toISOString().split('T')[0],
            purchase_cost: cost,
            current_value: currVal,
            notes: notes ? String(notes).trim() : null,
            created_by
        });

        res.json({ success: true, message: 'Capital Asset created successfully', data: asset });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// Delete a Capital Asset
exports.deleteCapitalAsset = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const asset = await req.propertyDb.models.capital_assets.findOne({ where: { id, outlet_id } });
        if (!asset) {
            return res.status(404).json({ success: false, message: 'Capital asset not found' });
        }

        await asset.destroy();
        res.json({ success: true, message: 'Capital asset deleted' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// Record Loan EMI Installment Payment with Principal & Interest Split
exports.payLoanEmi = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const { loan_id, loan_name, total_emi_amount, principal_amount, interest_amount, payment_mode, txn_date, narration } = req.body;

        const emiTotal = Number(total_emi_amount) || 0;
        const principalPart = Number(principal_amount) || 0;
        const interestPart = Number(interest_amount) || 0;
        const pMode = payment_mode || 'BANK_TRANSFER';
        const dateStr = txn_date || new Date().toISOString().split('T')[0];

        if (emiTotal <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid EMI amount' });
        }

        // 1. If loan_id is provided or loan matches, update remaining_principal
        let targetLoan = null;
        if (loan_id) {
            targetLoan = await req.propertyDb.models.business_loans.findOne({
                where: { id: loan_id, outlet_id },
                transaction: t
            });
        } else if (loan_name) {
            targetLoan = await req.propertyDb.models.business_loans.findOne({
                where: { outlet_id, loan_name },
                transaction: t
            });
        }

        if (targetLoan && principalPart > 0) {
            const newRemaining = Math.max(0, Number(targetLoan.remaining_principal) - principalPart);
            await targetLoan.update({
                remaining_principal: newRemaining,
                status: newRemaining <= 0 ? 'CLOSED' : 'ACTIVE'
            }, { transaction: t });
        }

        // 2. Post Double-Entry Payment Voucher (PV) for Loan EMI
        const count = await req.propertyDb.models.accounting_vouchers.count({
            where: { outlet_id, voucher_type: 'PAYMENT' },
            transaction: t
        });
        const autoNo = `PV-EMI-${String(count + 1).padStart(4, '0')}`;

        const header = await req.propertyDb.models.accounting_vouchers.create({
            outlet_id,
            voucher_no: autoNo,
            voucher_type: 'PAYMENT',
            voucher_date: dateStr,
            payment_mode: pMode,
            reference_no: `EMI-${loan_name || targetLoan?.loan_name || 'LOAN'}`,
            narration: narration || `Monthly EMI Payment for ${loan_name || targetLoan?.loan_name || 'Loan'} (Principal: ₹${principalPart}, Interest: ₹${interestPart})`,
            total_debit: emiTotal,
            total_credit: emiTotal,
            status: 'POSTED',
            created_by
        }, { transaction: t });

        // Double Entry Lines
        await req.propertyDb.models.voucher_lines.bulkCreate([
            {
                voucher_id: header.id,
                line_type: 'DEBIT',
                account_name: `${loan_name || targetLoan?.loan_name || 'Loan'} (Loan Liability A/c)`,
                account_type: 'LIABILITY',
                debit_amount: principalPart,
                credit_amount: 0,
                particulars: 'Principal Loan Repayment'
            },
            {
                voucher_id: header.id,
                line_type: 'DEBIT',
                account_name: 'Loan Interest Expense A/c',
                account_type: 'EXPENSE',
                debit_amount: interestPart,
                credit_amount: 0,
                particulars: 'Monthly Interest Charge'
            },
            {
                voucher_id: header.id,
                line_type: 'CREDIT',
                account_name: pMode === 'CASH' ? 'Main Cash Drawer' : 'Bank Account',
                account_type: pMode === 'CASH' ? 'CASH' : 'BANK',
                debit_amount: 0,
                credit_amount: emiTotal,
                particulars: 'Bank/Cash Outflow for EMI'
            }
        ], { transaction: t });

        // Update Cash/Bank Ledger
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: dateStr,
            transaction_type: 'EXPENSE',
            reference_type: 'LOAN_EMI',
            reference_id: header.id,
            reference_no: autoNo,
            party_name: loan_name || targetLoan?.loan_name || 'Business Loan',
            payment_method: pMode,
            amount_out: emiTotal,
            notes: narration || `EMI Payment for ${loan_name || targetLoan?.loan_name || 'Loan'}`,
            created_by,
            transaction: t
        });

        await t.commit();

        res.json({
            success: true,
            message: `EMI Payment of ₹${emiTotal} recorded successfully! Posted Voucher #${autoNo}`,
            voucher_no: autoNo
        });
    } catch (error) {
        await t.rollback();
        console.error('payLoanEmi error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
};
