const router = require('express').Router();

/**
 * GET /api/system/server-time
 *
 * NO authentication required — Flutter calls this at startup before login
 * to anchor its internal clock against the server (PostgreSQL) time.
 *
 * Returns:
 *   { success: true, serverTime: "<ISO8601>", source: "db"|"node" }
 */
router.get('/', async (req, res) => {
    try {
        // Prefer PostgreSQL time so it is independent of OS clock
        const db = req.db; // injected by dbMiddleware
        if (db) {
            const [[{ now }]] = await db.query('SELECT NOW() AS now');
            return res.json({
                success: true,
                serverTime: new Date(now).toISOString(),
                source: 'db',
            });
        }
    } catch (_) {
        // fall through to Node fallback
    }

    // Fallback: use Node's Date (still useful — at least it is the server OS time,
    // not the client OS time)
    res.json({
        success: true,
        serverTime: new Date().toISOString(),
        source: 'node',
    });
});

module.exports = router;
