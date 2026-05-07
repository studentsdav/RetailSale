const { Op, fn, col } = require('sequelize');

function roundAmount(value) {
    return Number((Number(value) || 0).toFixed(2));
}

function resolvePaymentStatus(totalPaid, netAmount) {
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

    const initialPaid = roundAmount(sale.initial_amount_paid ?? sale.amount_paid);
    const totalPaid = roundAmount(initialPaid + repaymentTotal);
    const balanceDue = Math.max(0, roundAmount(sale.net_amount) - totalPaid);
    const paymentStatus = resolvePaymentStatus(totalPaid, sale.net_amount);

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