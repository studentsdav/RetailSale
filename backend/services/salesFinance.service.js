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

    const isCreditMode = String(sale.payment_mode || '').trim().toUpperCase().includes('CREDIT');
    const initialPaid = (sale.initial_amount_paid !== null && sale.initial_amount_paid !== undefined && isCreditMode)
        ? roundAmount(sale.initial_amount_paid)
        : Math.max(0, roundAmount(sale.amount_paid) - repaymentTotal);
    const totalPaid = roundAmount(initialPaid + repaymentTotal);
    // net_amount already includes round_off_amount (net = subtotal + tax + charges + roundOff).
    // Do NOT subtract round_off_amount again — that was creating a phantom outstanding balance.
    const effectiveNet = roundAmount(sale.net_amount);
    const rawBalance = roundAmount(effectiveNet - totalPaid);
    const isCredit = String(sale.payment_mode || '').toUpperCase().includes('CREDIT');
    const balanceDue = (!isCredit && rawBalance <= 0.50) ? 0 : Math.max(0, rawBalance);
    const paymentStatus = resolvePaymentStatus(totalPaid, effectiveNet, sale.payment_mode);

    await sale.update({
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
    getRepaymentTotal,
    refreshSaleOutstanding
};