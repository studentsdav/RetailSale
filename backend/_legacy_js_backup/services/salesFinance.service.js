const { Op, fn, col } = require('sequelize');

function roundAmount(value) {
    return Number((Number(value) || 0).toFixed(2));
}

function resolvePaymentStatus(totalPaid, netAmount, paymentMode = '') {
    const mode = String(paymentMode || '').toUpperCase();
    if (mode.includes('SUBSCRIPTION')) return 'PAID';
    if (mode.includes('SCHEME')) return 'PAID';
    if (mode.includes('DISCOUNT')) return 'PAID';
    if (roundAmount(netAmount) <= 0) return 'PAID';
    if (roundAmount(totalPaid) <= 0) return 'UNPAID';
    if (roundAmount(totalPaid) >= roundAmount(netAmount)) return 'PAID';
    return 'PARTIAL';
}

function extractInitialPaid(sale) {
    if (sale.initial_amount_paid !== null && sale.initial_amount_paid !== undefined) {
        return roundAmount(sale.initial_amount_paid);
    }
    const ref = String(sale.payment_reference || '');
    if (ref.startsWith('POSPAY:')) {
        try {
            const raw = ref.slice(7);
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                return roundAmount(
                    parsed
                        .filter(l => String(l.method || l.payment_method || '').toUpperCase() !== 'CREDIT')
                        .reduce((sum, l) => sum + (Number(l.amount) || 0), 0)
                );
            }
        } catch (_) {}
    }
    return null;
}

async function getRepaymentTotal({
    db,
    sale_id,
    transaction = undefined,
    exclude_repayment_id = null
}) {
    const where = { sale_id };
    if (exclude_repayment_id) {
        where.id = { [Op.ne]: exclude_repayment_id };
    }

    const summary = await db.models.customer_repayments.findOne({
        where,
        attributes: [[fn('COALESCE', fn('SUM', col('amount')), 0), 'total']],
        raw: true,
        transaction
    });

    return roundAmount(summary?.total);
}

async function refreshSaleOutstanding({
    db,
    sale,
    transaction = undefined
}) {
    const repaymentTotal = await getRepaymentTotal({
        db,
        sale_id: sale.id,
        transaction
    });

    const parsedInitial = extractInitialPaid(sale);
    const initialPaid = parsedInitial !== null
        ? parsedInitial
        : Math.max(0, roundAmount(sale.amount_paid) - repaymentTotal);

    const totalPaid = roundAmount(initialPaid + repaymentTotal);
    // net_amount already includes round_off_amount (net = subtotal + tax + charges + roundOff).
    const effectiveNet = roundAmount(sale.net_amount);
    const rawBalance = roundAmount(effectiveNet - totalPaid);
    const isCredit = String(sale.payment_mode || '').toUpperCase().includes('CREDIT') ||
        String(sale.payment_reference || '').toUpperCase().includes('CREDIT') ||
        rawBalance > 0.009;
    const balanceDue = (!isCredit && rawBalance <= 0.50) ? 0 : Math.max(0, rawBalance);
    const paymentStatus = resolvePaymentStatus(totalPaid, effectiveNet, sale.payment_mode);

    await sale.update({
        initial_amount_paid: initialPaid,
        amount_paid: totalPaid,
        balance_due: balanceDue,
        payment_reference: sale.payment_reference,
        notes: sale.notes
    }, { transaction });

    return {
        totalPaid,
        balanceDue,
        paymentStatus,
        repaymentTotal,
        initialPaid
    };
}

module.exports = {
    roundAmount,
    resolvePaymentStatus,
    extractInitialPaid,
    getRepaymentTotal,
    refreshSaleOutstanding
};