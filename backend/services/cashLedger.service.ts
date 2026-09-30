import { Op } from 'sequelize';

export function roundAmount(value: any): number {
    return Number((Number(value) || 0).toFixed(2));
}

export function createLocalDate(year: number, month: number, day: number): Date {
    const date = new Date(year, month - 1, day);
    date.setHours(0, 0, 0, 0);
    return date;
}

export function parseDateValue(value: any): Date {
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

export function startOfDay(value: any): Date {
    const date = parseDateValue(value);
    if (Number.isNaN(date.getTime())) {
        const fallback = new Date();
        fallback.setHours(0, 0, 0, 0);
        return fallback;
    }
    date.setHours(0, 0, 0, 0);
    return date;
}

export function dateKey(value: any): string {
    const date = startOfDay(value);
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
}

export function addDays(value: any, days: number): Date {
    const next = startOfDay(value);
    next.setDate(next.getDate() + days);
    return next;
}

function entryDelta(entry: any): number {
    const type = String(entry.transaction_type || '').toUpperCase();
    if (type === 'SALE_CREDIT' || type === 'SUBSCRIPTION_SETTLEMENT_CREDIT' || type === 'SUBSCRIPTION_SETTLEMENT_PARTIAL') {
        return 0;
    }
    return roundAmount(entry.amount_in) - roundAmount(entry.amount_out) + roundAmount(entry.adjustment_amount);
}

async function getLatestManualOpeningBefore({
    db,
    outlet_id,
    beforeDate,
    transaction
}: any) {
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
}: any) {
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

export async function getOpeningBalanceForDate({
    db,
    outlet_id,
    balanceDate,
    transaction
}: any) {
    return resolveBalanceBeforeDate({
        db,
        outlet_id,
        beforeDate: balanceDate,
        transaction
    });
}

function buildOpeningMap(openings: any[]) {
    const map = new Map();
    for (const opening of openings) {
        map.set(dateKey(opening.balance_date), roundAmount(opening.opening_balance));
    }
    return map;
}

function applySkippedDayOverrides(openingMap: any, fromDay: any, toDay: any, currentBalance: any) {
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

export async function recalculateLedgerBalances({
    db,
    outlet_id,
    fromDate = new Date(),
    transaction = undefined
}: any) {
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

export async function updateLedgerEntry({
    db,
    entryId,
    outlet_id,
    values,
    transaction = undefined
}: any) {
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

export async function upsertOpeningBalance({
    db,
    outlet_id,
    balance_date,
    opening_balance,
    note = null,
    user_id = null,
    transaction = undefined
}: any) {
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

export async function createLedgerEntry({
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
}: any) {
    const normalizedTxnDate = dateKey(txn_date);

    // ── O(1) running balance ──────────────────────────────────────────────
    const lastEntry = await db.models.cash_ledger.findOne({
        where: { outlet_id },
        order: [['txn_date', 'DESC'], ['id', 'DESC']],
        attributes: ['balance', 'txn_date'],
        transaction
    });

    let runningBalance: number;
    if (lastEntry) {
        runningBalance = roundAmount(lastEntry.balance);
    } else {
        const opening = await getLatestManualOpeningBefore({
            db,
            outlet_id,
            beforeDate: normalizedTxnDate,
            transaction
        });
        runningBalance = roundAmount(opening?.opening_balance ?? 0);
    }

    const txnTypeStr = String(transaction_type || '').toUpperCase();
    const isCreditSaleTxn = txnTypeStr === 'SALE_CREDIT' || txnTypeStr === 'SUBSCRIPTION_SETTLEMENT_CREDIT' || txnTypeStr === 'SUBSCRIPTION_SETTLEMENT_PARTIAL';
    const delta = isCreditSaleTxn ? 0 : (roundAmount(amount_in) - roundAmount(amount_out) + roundAmount(adjustment_amount));
    const newBalance = roundAmount(runningBalance + delta);

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
        balance: newBalance,
        notes,
        created_by
    }, { transaction });

    return entry;
}

export async function batchCreateLedgerEntries({ db, outlet_id, entries, transaction }: {
    db: any;
    outlet_id: any;
    entries: any[];
    transaction?: any;
}) {
    if (!Array.isArray(entries) || entries.length === 0) return [];

    let _tL = Date.now();
    const lastEntry = await db.models.cash_ledger.findOne({
        where: { outlet_id },
        order: [['txn_date', 'DESC'], ['id', 'DESC']],
        attributes: ['balance', 'txn_date'],
        transaction
    });
    console.log(`[PERF-CL] cash_ledger.findOne: ${Date.now() - _tL}ms`);
    _tL = Date.now();

    let runningBalance: number;
    if (lastEntry) {
        runningBalance = roundAmount(lastEntry.balance);
    } else {
        const firstDate = entries[0].txn_date ?? new Date();
        const opening = await getLatestManualOpeningBefore({
            db,
            outlet_id,
            beforeDate: dateKey(firstDate),
            transaction
        });
        runningBalance = roundAmount(opening?.opening_balance ?? 0);
    }

    const rows = entries.map((e: any) => {
        const normalizedTxnDate = dateKey(e.txn_date ?? new Date());
        const delta = roundAmount(e.amount_in ?? 0) - roundAmount(e.amount_out ?? 0) + roundAmount(e.adjustment_amount ?? 0);
        runningBalance = roundAmount(runningBalance + delta);
        return {
            outlet_id,
            txn_date: normalizedTxnDate,
            transaction_type: e.transaction_type,
            reference_type: e.reference_type ?? null,
            reference_id: e.reference_id ?? null,
            reference_no: e.reference_no ?? null,
            party_name: e.party_name ?? null,
            payment_method: e.payment_method ?? null,
            amount_in: roundAmount(e.amount_in ?? 0),
            amount_out: roundAmount(e.amount_out ?? 0),
            adjustment_amount: roundAmount(e.adjustment_amount ?? 0),
            balance: runningBalance,
            notes: e.notes ?? null,
            created_by: e.created_by ?? null
        };
    });

    const created = await db.models.cash_ledger.bulkCreate(rows, {
        transaction,
        returning: false
    });
    console.log(`[PERF-CL] cash_ledger.bulkCreate(${rows.length}): ${Date.now() - _tL}ms`);

    return created;
}

export default {
    createLedgerEntry,
    batchCreateLedgerEntries,
    updateLedgerEntry,
    recalculateLedgerBalances,
    getOpeningBalanceForDate,
    upsertOpeningBalance,
    roundAmount,
    dateKey,
    startOfDay
};
