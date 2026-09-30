/**
 * Lightweight Distributed Lock using PostgreSQL Advisory Transaction Locks.
 * 
 * Benefits:
 * 1. Automatically releases upon transaction commit/end - no dangling connection pool locks.
 * 2. Works natively on single-instance and multi-instance cloud setups.
 */

const inProcessLocks = new Set();

function stringToLockId(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash |= 0;
    }
    return Math.abs(hash);
}

async function withDistributedLock(db, lockKey, action) {
    if (inProcessLocks.has(lockKey)) {
        return null;
    }

    inProcessLocks.add(lockKey);

    try {
        if (!db || typeof db.transaction !== 'function') {
            return await action();
        }

        return await db.transaction(async (t) => {
            const lockId = stringToLockId(lockKey);
            const [result] = await db.query(
                'SELECT pg_try_advisory_xact_lock(:lockId) AS acquired',
                {
                    replacements: { lockId },
                    transaction: t
                }
            );

            const isAcquired = Boolean(result && (result[0]?.acquired || result?.acquired));
            if (!isAcquired) {
                return null;
            }

            return await action();
        }).catch((err) => {
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
