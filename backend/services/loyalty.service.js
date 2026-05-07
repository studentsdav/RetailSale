const { Op } = require('sequelize');

function toAmount(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function toWhole(value, fallback = 0) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(0, Math.floor(parsed));
}

function normalizeCustomerIdentity(payload = {}) {
    const phone = String(payload.customer_phone || payload.customerPhone || '')
        .replace(/\D/g, '')
        .trim();
    const gstin = String(payload.customer_gstin || payload.customerGstin || '')
        .trim()
        .toUpperCase();
    const name = String(payload.customer_name || payload.customerName || '').trim();
    return {
        customer_name: name,
        customer_phone: phone,
        customer_gstin: gstin
    };
}

function resolveCustomerKey(identity = {}) {
    if (identity.customer_phone) return `PHONE:${identity.customer_phone}`;
    if (identity.customer_gstin) return `GSTIN:${identity.customer_gstin}`;
    if (identity.customer_name) return `NAME:${identity.customer_name.toUpperCase()}`;
    return null;
}

function normalizeConfig(raw = null) {
    return {
        program_status: raw?.program_status === true,
        start_date: raw?.start_date || null,
        end_date: raw?.end_date || null,
        min_purchase_threshold: toAmount(raw?.min_purchase_threshold),
        earning_ratio: toAmount(raw?.earning_ratio, 1000),
        redemption_value: toAmount(raw?.redemption_value, 1),
        max_redeem_per_bill: toWhole(raw?.max_redeem_per_bill, 0),
        point_expiry_days: toWhole(raw?.point_expiry_days, 90)
    };
}

function dateOnly(value = new Date()) {
    const d = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(d.getTime())) return null;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function addDays(value, days) {
    const d = dateOnly(value) || new Date();
    d.setDate(d.getDate() + Number(days || 0));
    return d;
}

function isConfigActive(config, now = new Date()) {
    if (!config.program_status) return false;
    const current = dateOnly(now);
    if (!current) return false;
    const start = config.start_date ? dateOnly(config.start_date) : null;
    const end = config.end_date ? dateOnly(config.end_date) : null;
    if (start && current < start) return false;
    if (end && current > end) return false;
    return true;
}

async function getOutletConfig(db, outletId, transaction = undefined) {
    const row = await db.models.loyalty_master_config.findOne({
        where: { outlet_id: outletId },
        transaction
    });
    return normalizeConfig(row);
}

async function getCustomerBalanceByKey(db, outletId, customerKey, transaction = undefined) {
    if (!customerKey) return 0;

    const [rows] = await db.query(
        `
SELECT COALESCE(SUM(available_points), 0) AS balance
FROM customer_loyalty_ledger
WHERE outlet_id = :outlet_id
  AND customer_key = :customer_key
  AND transaction_type = 'EARNED'
  AND available_points > 0
  AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
        `,
        {
            replacements: {
                outlet_id: outletId,
                customer_key: customerKey
            },
            transaction
        }
    );
    return toWhole(rows?.[0]?.balance, 0);
}

async function getCustomerBalance(db, outletId, identity = {}, transaction = undefined) {
    const customerKey = resolveCustomerKey(identity);
    const available_points = await getCustomerBalanceByKey(
        db,
        outletId,
        customerKey,
        transaction
    );
    return { customer_key: customerKey, available_points };
}

async function applyLoyaltyOnCompletedSale({
    db,
    outlet_id,
    user_id,
    sale,
    header = {},
    transaction
}) {
    if (!sale || String(sale.status || '').toUpperCase() !== 'COMPLETED') {
        return { earned_points: 0, redeemed_points: 0, redemption_discount_amount: 0 };
    }

    const existingRows = await db.models.customer_loyalty_ledger.findAll({
        where: {
            outlet_id,
            sale_id: sale.id,
            transaction_type: { [Op.in]: ['EARNED', 'REDEEMED'] }
        },
        attributes: ['id'],
        transaction
    });
    if ((existingRows || []).length > 0) {
        return { earned_points: 0, redeemed_points: 0, redemption_discount_amount: 0 };
    }

    const config = await getOutletConfig(db, outlet_id, transaction);
    const active = isConfigActive(config, sale.sale_date || new Date());
    const identity = normalizeCustomerIdentity({
        customer_name: sale.customer_name || header.customer_name,
        customer_phone: sale.customer_phone || header.customer_phone,
        customer_gstin: sale.customer_gstin || header.customer_gstin
    });
    const customerKey = resolveCustomerKey(identity);

    let redeemedPoints = toWhole(header.loyalty_points_redeemed, 0);
    let redemptionDiscount = toAmount(header.loyalty_discount_amount, 0);

    if (!active) {
        if (redeemedPoints > 0 || redemptionDiscount > 0) {
            const err = new Error('Loyalty program is inactive for this billing date.');
            err.status = 400;
            throw err;
        }
        return { earned_points: 0, redeemed_points: 0, redemption_discount_amount: 0 };
    }

    if ((redeemedPoints > 0 || redemptionDiscount > 0) && !customerKey) {
        const err = new Error('Customer is required to redeem loyalty points.');
        err.status = 400;
        throw err;
    }

    const redemptionValue = config.redemption_value > 0 ? config.redemption_value : 1;
    const maxRedeemPerBill = config.max_redeem_per_bill > 0
        ? config.max_redeem_per_bill
        : Number.MAX_SAFE_INTEGER;

    if (redemptionDiscount > 0 && redeemedPoints <= 0) {
        redeemedPoints = toWhole(redemptionDiscount / redemptionValue, 0);
    }
    if (redeemedPoints > 0) {
        if (redeemedPoints > maxRedeemPerBill) {
            const err = new Error(`Redeem points cannot exceed ${maxRedeemPerBill} per bill.`);
            err.status = 400;
            throw err;
        }
        const availablePoints = await getCustomerBalanceByKey(
            db,
            outlet_id,
            customerKey,
            transaction
        );
        if (redeemedPoints > availablePoints) {
            const err = new Error('Redeem points exceed available loyalty balance.');
            err.status = 400;
            throw err;
        }

        const expectedDiscount = Number((redeemedPoints * redemptionValue).toFixed(2));
        if (Math.abs(expectedDiscount - redemptionDiscount) > 0.01) {
            const err = new Error(
                `Redeem discount mismatch. Expected ${expectedDiscount.toFixed(2)} for ${redeemedPoints} points.`
            );
            err.status = 400;
            throw err;
        }

        const sourceEarnRows = await db.models.customer_loyalty_ledger.findAll({
            where: {
                outlet_id,
                customer_key: customerKey,
                transaction_type: 'EARNED',
                available_points: { [Op.gt]: 0 },
                [Op.or]: [
                    { expiry_date: null },
                    { expiry_date: { [Op.gte]: dateOnly(sale.sale_date || new Date()) } }
                ]
            },
            order: [['expiry_date', 'ASC NULLS LAST'], ['id', 'ASC']],
            transaction,
            lock: transaction?.LOCK?.UPDATE
        });

        let remaining = redeemedPoints;
        const allocations = [];
        for (const row of sourceEarnRows) {
            if (remaining <= 0) break;
            const available = toWhole(row.available_points, 0);
            if (available <= 0) continue;
            const consumed = Math.min(remaining, available);
            remaining -= consumed;
            const nextAvailable = available - consumed;
            allocations.push({
                source_ledger_id: row.id,
                consumed_points: consumed
            });
            await row.update({ available_points: nextAvailable }, { transaction });
        }

        if (remaining > 0) {
            const err = new Error('Unable to consume loyalty points due to insufficient active balance.');
            err.status = 400;
            throw err;
        }

        const beforeBalance = await getCustomerBalanceByKey(db, outlet_id, customerKey, transaction);
        const afterBalance = Math.max(beforeBalance - redeemedPoints, 0);
        await db.models.customer_loyalty_ledger.create({
            outlet_id,
            customer_name: identity.customer_name || null,
            customer_phone: identity.customer_phone || null,
            customer_gstin: identity.customer_gstin || null,
            customer_key: customerKey,
            transaction_date: sale.sale_date || new Date(),
            transaction_type: 'REDEEMED',
            points_delta: -redeemedPoints,
            points_balance_after: afterBalance,
            bill_number: sale.sale_no,
            sale_id: sale.id,
            expiry_date: null,
            available_points: 0,
            meta: {
                redemption_value: redemptionValue,
                redemption_discount_amount: redemptionDiscount,
                allocations
            },
            created_by: user_id
        }, { transaction });
    } else {
        redemptionDiscount = 0;
    }

    let earnedPoints = 0;
    const finalBillAmount = toAmount(sale.net_amount, 0);
    const minThreshold = config.min_purchase_threshold > 0 ? config.min_purchase_threshold : 0;
    const earningRatio = config.earning_ratio > 0 ? config.earning_ratio : 1000;
    if (customerKey && finalBillAmount >= minThreshold) {
        earnedPoints = toWhole(Math.floor(finalBillAmount / earningRatio), 0);
        if (earnedPoints > 0) {
            const beforeBalance = await getCustomerBalanceByKey(
                db,
                outlet_id,
                customerKey,
                transaction
            );
            const expiryDate = addDays(sale.sale_date || new Date(), config.point_expiry_days || 0);
            await db.models.customer_loyalty_ledger.create({
                outlet_id,
                customer_name: identity.customer_name || null,
                customer_phone: identity.customer_phone || null,
                customer_gstin: identity.customer_gstin || null,
                customer_key: customerKey,
                transaction_date: sale.sale_date || new Date(),
                transaction_type: 'EARNED',
                points_delta: earnedPoints,
                points_balance_after: beforeBalance + earnedPoints,
                bill_number: sale.sale_no,
                sale_id: sale.id,
                expiry_date: expiryDate,
                available_points: earnedPoints,
                meta: {
                    min_purchase_threshold: minThreshold,
                    earning_ratio: earningRatio
                },
                created_by: user_id
            }, { transaction });
        }
    }

    return {
        earned_points: earnedPoints,
        redeemed_points: redeemedPoints,
        redemption_discount_amount: Number(redemptionDiscount.toFixed(2))
    };
}

async function expireDuePoints(db, { batchSize = 500 } = {}) {
    let totalExpiredRows = 0;
    let totalExpiredPoints = 0;

    while (true) {
        const transaction = await db.transaction();
        try {
            const [rows] = await db.query(
                `
SELECT id,
       outlet_id,
       customer_name,
       customer_phone,
       customer_gstin,
       customer_key,
       bill_number,
       sale_id,
       expiry_date,
       available_points
FROM customer_loyalty_ledger
WHERE transaction_type = 'EARNED'
  AND available_points > 0
  AND expiry_date IS NOT NULL
  AND expiry_date < CURRENT_DATE
ORDER BY expiry_date ASC, id ASC
LIMIT :limit
FOR UPDATE SKIP LOCKED
                `,
                {
                    replacements: { limit: batchSize },
                    transaction
                }
            );

            if (!rows || rows.length === 0) {
                await transaction.commit();
                break;
            }

            for (const row of rows) {
                const available = toWhole(row.available_points, 0);
                if (available <= 0) continue;

                await db.models.customer_loyalty_ledger.create({
                    outlet_id: row.outlet_id,
                    customer_name: row.customer_name || null,
                    customer_phone: row.customer_phone || null,
                    customer_gstin: row.customer_gstin || null,
                    customer_key: row.customer_key,
                    transaction_date: new Date(),
                    transaction_type: 'EXPIRED',
                    points_delta: -available,
                    points_balance_after: 0,
                    bill_number: row.bill_number || null,
                    sale_id: row.sale_id || null,
                    expiry_date: row.expiry_date || null,
                    available_points: 0,
                    source_ledger_id: row.id,
                    meta: {
                        reason: 'POINT_EXPIRY'
                    },
                    created_by: null
                }, { transaction });

                await db.models.customer_loyalty_ledger.update(
                    { available_points: 0 },
                    {
                        where: { id: row.id },
                        transaction
                    }
                );

                totalExpiredRows += 1;
                totalExpiredPoints += available;
            }

            await transaction.commit();
        } catch (error) {
            await transaction.rollback();
            throw error;
        }
    }

    return {
        expired_rows: totalExpiredRows,
        expired_points: totalExpiredPoints
    };
}

module.exports = {
    normalizeCustomerIdentity,
    resolveCustomerKey,
    normalizeConfig,
    isConfigActive,
    getOutletConfig,
    getCustomerBalance,
    getCustomerBalanceByKey,
    applyLoyaltyOnCompletedSale,
    expireDuePoints
};
