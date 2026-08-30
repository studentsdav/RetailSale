const { createLedgerEntry } = require('../../services/cashLedger.service');

// Get all Loans & Fixed Assets Summary
exports.getLoansAndAssets = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        
        // Mock / Initial DB structure for Loans & Assets
        const loans = [
            {
                id: 1,
                loan_name: 'HDFC Business Expansion Loan',
                lender_name: 'HDFC Bank',
                principal_amount: 500000.00,
                interest_rate: 10.5,
                tenure_months: 36,
                monthly_emi: 16254.00,
                remaining_principal: 420000.00,
                status: 'ACTIVE'
            }
        ];

        const assets = [
            {
                id: 1,
                asset_name: 'Store Infrastructure & Fitouts',
                asset_category: 'FIXED_ASSET',
                purchase_date: '2026-01-15',
                purchase_cost: 350000.00,
                current_value: 332500.00
            },
            {
                id: 2,
                asset_name: 'POS Billing Hardware & Computers',
                asset_category: 'MACHINERY_EQUIPMENT',
                purchase_date: '2026-02-10',
                purchase_cost: 120000.00,
                current_value: 114000.00
            }
        ];

        res.json({
            success: true,
            data: { loans, assets }
        });
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
        const { loan_name, total_emi_amount, principal_amount, interest_amount, payment_mode, txn_date, narration } = req.body;

        const emiTotal = Number(total_emi_amount) || 0;
        const principalPart = Number(principal_amount) || 0;
        const interestPart = Number(interest_amount) || 0;
        const pMode = payment_mode || 'BANK_TRANSFER';
        const dateStr = txn_date || new Date().toISOString().split('T')[0];

        if (emiTotal <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid EMI amount' });
        }

        // 1. Post Double-Entry Payment Voucher (PV) for Loan EMI
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
            reference_no: `EMI-${loan_name}`,
            narration: narration || `Monthly EMI Payment for ${loan_name} (Principal: ₹${principalPart}, Interest: ₹${interestPart})`,
            total_debit: emiTotal,
            total_credit: emiTotal,
            status: 'POSTED',
            created_by
        }, { transaction: t });

        // Double Entry Lines:
        // Dr: Loan Liability Account (Reduces Principal Liability)
        // Dr: Loan Interest Expense Account (Recorded as Expense)
        // Cr: Bank Account (Total EMI Payout)
        await req.propertyDb.models.voucher_lines.bulkCreate([
            {
                voucher_id: header.id,
                line_type: 'DEBIT',
                account_name: `${loan_name} (Loan Liability A/c)`,
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
                account_name: pMode === 'CASH' ? 'Main Cash Drawer' : 'HDFC Bank Current A/c',
                account_type: pMode === 'CASH' ? 'CASH' : 'BANK',
                debit_amount: 0,
                credit_amount: emiTotal,
                particulars: 'Bank Outflow for EMI'
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
            party_name: loan_name,
            payment_method: pMode,
            amount_out: emiTotal,
            notes: narration || `EMI Payment for ${loan_name}`,
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
        res.status(500).json({ success: false, error: error.message });
    }
};
