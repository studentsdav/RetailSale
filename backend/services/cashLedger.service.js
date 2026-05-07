

const { Op } = require('sequelize');

function roundAmount(value) {
    return Number((Number(value) || 0).toFixed(2));
}

function createLocalDate(year, month, day) {
    const date = new Date(year, month - 1, day);
    date.setHours(0, 0, 0, 0);
    return date;
}

function parseDateValue(value) {
    if (value instanceof Date) {
        return new Date(value.getTime());
    }

    if (typeof value === 'string') {
        const trimmed = value.trim();
        const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
        if (match) {
            return createLocalDate(
                Number(match[1]),
                Number(match[2]),
                Number(match[3])
            );
        }
    }

    return new Date(value);
}

function startOfDay(value) {
    const date = parseDateValue(value);
    if (Number.isNaN(date.getTime())) {
        const fallback = new Date();
        fallback.setHours(0, 0, 0, 0);
        return fallback;
    }
    date.setHours(0, 0, 0, 0);
    return date;
}

function dateKey(value) {
    const date = startOfDay(value);
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
}

function addDays(value, days) {
    const next = startOfDay(value);
    next.setDate(next.getDate() + days);
    return next;
}

function entryDelta(entry) {
    return roundAmount(entry.amount_in) - roundAmount(entry.amount_out) + roundAmount(entry.adjustment_amount);
}

async function getLatestManualOpeningBefore({
    db,
    outlet_id,
    beforeDate,
    transaction
}) {
    return db.models.daily_opening_balances.findOne({
        where: {
            outlet_id,
            balance_date: {
                [Op.lt]: dateKey(beforeDate)
            }
        },
        order: [['balance_date', 'DESC'], ['id', 'DESC']],
        transaction
    });
}

async function resolveBalanceBeforeDate({
    db,
    outlet_id,
    beforeDate,
    transaction
}) {
    const priorEntry = await db.models.cash_ledger.findOne({
        where: {
            outlet_id,
            txn_date: {
                [Op.lt]: dateKey(beforeDate)
            }
        },
        order: [['txn_date', 'DESC'], ['id', 'DESC']],
        transaction
    });

    if (priorEntry) {
        return roundAmount(priorEntry.balance);
    }

    const opening = await getLatestManualOpeningBefore({
        db,
        outlet_id,
        beforeDate,
        transaction
    });

    return roundAmount(opening?.opening_balance);
}

async function getOpeningBalanceForDate({
    db,
    outlet_id,
    balanceDate,
    transaction
}) {
    return resolveBalanceBeforeDate({
        db,
        outlet_id,
        beforeDate: balanceDate,
        transaction
    });
}

function buildOpeningMap(openings) {
    const map = new Map();
    for (const opening of openings) {
        map.set(dateKey(opening.balance_date), roundAmount(opening.opening_balance));
    }
    return map;
}

function applySkippedDayOverrides(openingMap, fromDay, toDay, currentBalance) {
    if (!fromDay || !toDay) return currentBalance;

    let pointer = addDays(fromDay, 1);
    let nextBalance = currentBalance;

    while (pointer <= toDay) {
        const override = openingMap.get(dateKey(pointer));
        if (override !== undefined) {
            nextBalance = override;
        }
        pointer = addDays(pointer, 1);
    }

    return nextBalance;
}

async function recalculateLedgerBalances({
    db,
    outlet_id,
    fromDate = new Date(),
    transaction = undefined
}) {
    const startDateKey = dateKey(fromDate);
    const entries = await db.models.cash_ledger.findAll({
        where: {
            outlet_id,
            txn_date: {
                [Op.gte]: startDateKey
            }
        },
        order: [['txn_date', 'ASC'], ['id', 'ASC']],
        transaction
    });

    if (entries.length === 0) {
        return;
    }

    let currentBalance = await resolveBalanceBeforeDate({
        db,
        outlet_id,
        beforeDate: startDateKey,
        transaction
    });

    for (const entry of entries) {
        currentBalance = roundAmount(currentBalance + entryDelta(entry));
        await entry.update({ balance: currentBalance }, { transaction });
    }
}

async function updateLedgerEntry({
    db,
    entryId,
    outlet_id,
    values,
    transaction = undefined
}) {
    const entry = await db.models.cash_ledger.findOne({
        where: {
            id: entryId,
            outlet_id
        },
        transaction
    });

    if (!entry) {
        throw new Error('Ledger entry not found');
    }

    const oldDate = startOfDay(entry.txn_date);
    const nextValues = {
        ...values
    };

    if (Object.prototype.hasOwnProperty.call(nextValues, 'amount_in')) {
        nextValues.amount_in = roundAmount(nextValues.amount_in);
    }
    if (Object.prototype.hasOwnProperty.call(nextValues, 'amount_out')) {
        nextValues.amount_out = roundAmount(nextValues.amount_out);
    }
    if (Object.prototype.hasOwnProperty.call(nextValues, 'adjustment_amount')) {
        nextValues.adjustment_amount = roundAmount(nextValues.adjustment_amount);
    }
    if (Object.prototype.hasOwnProperty.call(nextValues, 'txn_date')) {
        nextValues.txn_date = dateKey(nextValues.txn_date);
    }

    await entry.update(nextValues, { transaction });

    const updatedDate = startOfDay(entry.txn_date);
    const fromDate = oldDate < updatedDate ? oldDate : updatedDate;
    await recalculateLedgerBalances({
        db,
        outlet_id,
        fromDate,
        transaction
    });

    return entry.reload({ transaction });
}

async function upsertOpeningBalance({
    db,
    outlet_id,
    balance_date,
    opening_balance,
    note = null,
    user_id = null,
    transaction = undefined
}) {
    const key = dateKey(balance_date);
    const existing = await db.models.daily_opening_balances.findOne({
        where: {
            outlet_id,
            balance_date: key
        },
        transaction
    });

    let record = existing;

    if (existing) {
        await existing.update({
            opening_balance: roundAmount(opening_balance),
            note,
            updated_by: user_id
        }, { transaction });
    } else {
        record = await db.models.daily_opening_balances.create({
            outlet_id,
            balance_date: key,
            opening_balance: roundAmount(opening_balance),
            note,
            created_by: user_id,
            updated_by: user_id
        }, { transaction });
    }

    return record || existing;
}













async function createLedgerEntry({
    db,
    outlet_id,
    txn_date = new Date(),
    transaction_type,
    reference_type = null,
    reference_id = null,
    reference_no = null,
    party_name = null,
    payment_method = null,
    amount_in = 0,
    amount_out = 0,
    adjustment_amount = 0,
    notes = null,
    created_by = null,
    transaction = undefined
}) {
    const normalizedTxnDate = dateKey(txn_date);
    const entry = await db.models.cash_ledger.create({
        outlet_id,
        txn_date: normalizedTxnDate,
        transaction_type,
        reference_type,
        reference_id,
        reference_no,
        party_name,
        payment_method,
        amount_in: roundAmount(amount_in),
        amount_out: roundAmount(amount_out),
        adjustment_amount: roundAmount(adjustment_amount),
        balance: 0,
        notes,
        created_by
    }, { transaction });

    await recalculateLedgerBalances({
        db,
        outlet_id,
        fromDate: normalizedTxnDate,
        transaction
    });

    return entry.reload({ transaction });
}

module.exports = {
    createLedgerEntry,
    updateLedgerEntry,
    recalculateLedgerBalances,
    getOpeningBalanceForDate,
    upsertOpeningBalance,
    roundAmount,
    dateKey,
    startOfDay
};
