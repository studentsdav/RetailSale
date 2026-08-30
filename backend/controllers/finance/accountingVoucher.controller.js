const { Op } = require('sequelize');
const { createLedgerEntry } = require('../../services/cashLedger.service');
const { getNextNumber } = require('../../services/numbering.service');

exports.createVoucher = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const created_by = req.user.id;
        const { voucher_type, voucher_date, payment_mode, bank_account_id, reference_no, narration, lines } = req.body;

        if (!['CONTRA', 'PAYMENT', 'RECEIPT', 'JOURNAL', 'SALES', 'PURCHASE'].includes(voucher_type)) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid voucher type' });
        }

        if (!Array.isArray(lines) || lines.length === 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Voucher lines are required' });
        }

        let totalDebit = 0;
        let totalCredit = 0;

        lines.forEach(line => {
            totalDebit += Number(line.debit_amount || 0);
            totalCredit += Number(line.credit_amount || 0);
        });

        totalDebit = Number(totalDebit.toFixed(2));
        totalCredit = Number(totalCredit.toFixed(2));

        if (Math.abs(totalDebit - totalCredit) > 0.01) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: `Voucher is unbalanced. Total Debit: ₹${totalDebit}, Total Credit: ₹${totalCredit}`
            });
        }

        let autoNo;
        try {
            autoNo = await getNextNumber(req.propertyDb, outlet_id, voucher_type);
        } catch (_) {
            const prefixMap = { CONTRA: 'CN', PAYMENT: 'PV', RECEIPT: 'RV', JOURNAL: 'JV', SALES: 'SV', PURCHASE: 'PV' };
            const count = await req.propertyDb.models.accounting_vouchers.count({ where: { outlet_id, voucher_type }, transaction: t });
            autoNo = `${prefixMap[voucher_type] || 'VC'}-${String(count + 1).padStart(4, '0')}`;
        }

        const vDate = voucher_date || new Date().toISOString().split('T')[0];

        const header = await req.propertyDb.models.accounting_vouchers.create({
            outlet_id,
            voucher_no: autoNo,
            voucher_type,
            voucher_date: vDate,
            payment_mode: payment_mode || 'CASH',
            bank_account_id: bank_account_id ? Number(bank_account_id) : null,
            reference_no: reference_no ? String(reference_no).trim() : null,
            narration: narration ? String(narration).trim() : null,
            total_debit: totalDebit,
            total_credit: totalCredit,
            status: 'POSTED',
            created_by
        }, { transaction: t });

        const detailRows = lines.map(line => ({
            voucher_id: header.id,
            line_type: line.line_type || (Number(line.debit_amount || 0) > 0 ? 'DEBIT' : 'CREDIT'),
            account_id: line.account_id ? Number(line.account_id) : null,
            account_name: String(line.account_name || 'General Ledger').trim(),
            account_type: line.account_type || 'GENERAL',
            debit_amount: Number(line.debit_amount || 0),
            credit_amount: Number(line.credit_amount || 0),
            particulars: line.particulars ? String(line.particulars).trim() : null
        }));

        await req.propertyDb.models.voucher_lines.bulkCreate(detailRows, { transaction: t });

        // Update Cash Ledger if cash involved
        if (payment_mode === 'CASH' || lines.some(l => l.account_name.toLowerCase().includes('cash'))) {
            let amountIn = 0;
            let amountOut = 0;

            if (voucher_type === 'RECEIPT' || voucher_type === 'SALES') {
                amountIn = totalDebit;
            } else if (voucher_type === 'PAYMENT' || voucher_type === 'PURCHASE') {
                amountOut = totalCredit;
            } else if (voucher_type === 'CONTRA') {
                // Cash Deposit to Bank => Cash Out
                const isCashToBank = lines.some(l => l.line_type === 'CREDIT' && l.account_name.toLowerCase().includes('cash'));
                if (isCashToBank) {
                    amountOut = totalDebit;
                } else {
                    amountIn = totalDebit;
                }
            }

            if (amountIn > 0 || amountOut > 0) {
                await createLedgerEntry({
                    db: req.propertyDb,
                    outlet_id,
                    txn_date: vDate,
                    transaction_type: `VOUCHER_${voucher_type}`,
                    reference_type: 'VOUCHER',
                    reference_id: header.id,
                    reference_no: header.voucher_no,
                    party_name: narration || `${voucher_type} Entry`,
                    payment_method: 'CASH',
                    amount_in: amountIn,
                    amount_out: amountOut,
                    notes: narration,
                    created_by,
                    transaction: t
                });
            }
        }

        // Update Bank Balance if bank account selected
        if (bank_account_id) {
            const bankAcc = await req.propertyDb.models.bank_accounts.findOne({
                where: { id: bank_account_id, outlet_id },
                transaction: t
            });

            if (bankAcc) {
                let delta = 0;
                if (voucher_type === 'RECEIPT' || voucher_type === 'SALES') {
                    delta = totalDebit;
                } else if (voucher_type === 'PAYMENT' || voucher_type === 'PURCHASE') {
                    delta = -totalCredit;
                } else if (voucher_type === 'CONTRA') {
                    // Deposit to bank => bank increases (+)
                    delta = totalDebit;
                }
                const newBal = Number(bankAcc.current_balance) + delta;
                await bankAcc.update({ current_balance: newBal }, { transaction: t });
            }
        }

        await t.commit();

        res.json({
            success: true,
            data: {
                ...header.toJSON(),
                lines: detailRows
            }
        });

    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getVouchers = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { voucher_type, from_date, to_date, search } = req.query;
        const where = { outlet_id };

        if (voucher_type && voucher_type !== 'ALL') {
            where.voucher_type = voucher_type;
        }
        if (from_date && to_date) {
            where.voucher_date = { [Op.between]: [from_date, to_date] };
        }
        if (search) {
            where[Op.or] = [
                { voucher_no: { [Op.iLike]: `%${search}%` } },
                { reference_no: { [Op.iLike]: `%${search}%` } },
                { narration: { [Op.iLike]: `%${search}%` } }
            ];
        }

        let vouchers = await req.propertyDb.models.accounting_vouchers.findAll({
            where,
            order: [['voucher_date', 'DESC'], ['id', 'DESC']]
        });

        const list = vouchers.map(v => v.toJSON());
        const existingVNoSet = new Set(list.map(v => v.voucher_no));

        // If querying SALES or ALL, fallback to include Sales Headers
        if (!voucher_type || voucher_type === 'SALES' || voucher_type === 'ALL') {
            try {
                const sales = await req.propertyDb.models.sales_headers.findAll({
                    where: {
                        outlet_id,
                        is_latest: true,
                        is_deleted: false,
                        status: 'COMPLETED'
                    },
                    order: [['sale_date', 'DESC'], ['id', 'DESC']],
                    limit: 100
                });
                for (const s of sales) {
                    const vNo = s.sale_no.startsWith('SV-') ? s.sale_no : `SV-${s.sale_no}`;
                    if (!existingVNoSet.has(vNo) && !existingVNoSet.has(s.sale_no)) {
                        list.push({
                            id: s.id,
                            outlet_id: s.outlet_id,
                            voucher_no: vNo,
                            voucher_type: 'SALES',
                            voucher_date: s.sale_date,
                            total_debit: Number(s.net_amount || 0),
                            total_credit: Number(s.net_amount || 0),
                            narration: `POS Sale to ${s.customer_name || s.customer_phone || 'Walk-in Customer'}`,
                            payment_mode: s.payment_mode || 'CASH',
                            reference_no: s.sale_no,
                            status: 'POSTED',
                            lines: []
                        });
                    }
                }
            } catch (sErr) {
                console.error('Error fetching fallback sales vouchers:', sErr);
            }
        }

        // If querying PURCHASE or ALL, fallback to include Goods Receipts
        if (!voucher_type || voucher_type === 'PURCHASE' || voucher_type === 'ALL') {
            try {
                const grns = await req.propertyDb.models.goods_receipts.findAll({
                    where: { outlet_id },
                    order: [['receipt_date', 'DESC'], ['id', 'DESC']],
                    limit: 100
                });
                for (const g of grns) {
                    const vNo = g.grn_no.startsWith('PV-') ? g.grn_no : `PV-${g.grn_no}`;
                    if (!existingVNoSet.has(vNo) && !existingVNoSet.has(g.grn_no)) {
                        list.push({
                            id: g.id,
                            outlet_id: g.outlet_id,
                            voucher_no: vNo,
                            voucher_type: 'PURCHASE',
                            voucher_date: g.receipt_date,
                            total_debit: Number(g.total_amount || 0),
                            total_credit: Number(g.total_amount || 0),
                            narration: `Purchase GRN #${g.grn_no} (Bill #${g.supplier_bill_no || 'N/A'})`,
                            payment_mode: 'CREDIT',
                            reference_no: g.grn_no,
                            status: 'POSTED',
                            lines: []
                        });
                    }
                }
            } catch (gErr) {
                console.error('Error fetching fallback purchase vouchers:', gErr);
            }
        }

        // Sort combined list descending by date and id
        list.sort((a, b) => {
            const dA = new Date(a.voucher_date).getTime();
            const dB = new Date(b.voucher_date).getTime();
            if (dB !== dA) return dB - dA;
            return (b.id || 0) - (a.id || 0);
        });

        res.json({ success: true, data: list });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getVoucherById = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const header = await req.propertyDb.models.accounting_vouchers.findOne({
            where: { id, outlet_id }
        });

        if (!header) {
            return res.status(404).json({ success: false, message: 'Voucher not found' });
        }

        const lines = await req.propertyDb.models.voucher_lines.findAll({
            where: { voucher_id: header.id }
        });

        res.json({
            success: true,
            data: {
                ...header.toJSON(),
                lines
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
