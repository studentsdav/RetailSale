function toNumber(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function roundAmount(value) {
    return Number(toNumber(value).toFixed(2));
}

async function calculateCommissionFields(db, saleSource, baseAmount, netAmount, transaction = null) {
    let commission_rate = 0;
    let gst_rate_on_commission = 0;
    let tds_rate = 0;
    let tcs_rate = 0;

    if (saleSource) {
        const sourceSettings = await db.models.sale_sources.findOne({
            where: { name: saleSource, is_active: true },
            transaction
        });
        if (sourceSettings) {
            commission_rate = toNumber(sourceSettings.commission_rate);
            gst_rate_on_commission = toNumber(sourceSettings.gst_rate_on_commission);
            tds_rate = toNumber(sourceSettings.tds_rate);
            tcs_rate = toNumber(sourceSettings.tcs_rate);
        }
    }

    // Base rate for calculations (taxable amount before GST)
    const base = baseAmount > 0 ? baseAmount : netAmount;

    const commission_amount = roundAmount(base * (commission_rate / 100));
    const commission_tax_amount = roundAmount(commission_amount * (gst_rate_on_commission / 100));
    const tcs_amount = roundAmount(base * (tcs_rate / 100));
    const tds_amount = roundAmount(base * (tds_rate / 100));
    const net_payout = roundAmount(netAmount);

    return {
        commission_rate,
        gst_rate_on_commission,
        tds_rate,
        tcs_rate,
        commission_amount,
        commission_tax_amount,
        tcs_amount,
        tds_amount,
        net_payout
    };
}

module.exports = { calculateCommissionFields };
