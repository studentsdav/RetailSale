import { Sequelize, Transaction } from 'sequelize';

/**
 * Lightweight Distributed Lock using PostgreSQL Advisory Transaction Locks.
 * 
 * Benefits:
 * 1. Automatically releases upon transaction commit/end - no dangling connection pool locks.
 * 2. Works natively on single-instance and multi-instance cloud setups.
 */

const inProcessLocks = new Set<string>();

function stringToLockId(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash |= 0;
    }
    return Math.abs(hash);
}

export async function withDistributedLock<T>(
    db: Sequelize,
    lockKey: string,
    action: () => Promise<T>
): Promise<T | null> {
    if (inProcessLocks.has(lockKey)) {
        return null;
    }

    inProcessLocks.add(lockKey);

    try {
        if (!db || typeof db.transaction !== 'function') {
            return await action();
        }

        return await db.transaction(async (t: Transaction) => {
            const lockId = stringToLockId(lockKey);
            const [result]: any = await db.query(
                'SELECT pg_try_advisory_xact_lock(:lockId) AS acquired',
                {
                    replacements: { lockId },
                    transaction: t
                }
            );

            const isAcquired = Boolean(result?.[0]?.acquired || result?.acquired);
            if (!isAcquired) {
                return null;
            }

            return await action();
        }).catch((err: any) => {
            console.warn(`[DISTRIBUTED_LOCK] Advisory lock bypassed for ${lockKey}: ${err.message}`);
            return action();
        });
    } finally {
        inProcessLocks.delete(lockKey);
    }
}

module.exports = {
    withDistributedLock
};
