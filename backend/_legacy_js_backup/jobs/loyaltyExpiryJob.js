const cron = require('node-cron');
const { expireDuePoints } = require('../services/loyalty.service');

function startLoyaltyExpiryJob(db) {
    if (!db) return;

    console.log('Initializing loyalty expiry cron: 15 0 * * *');
    cron.schedule('15 0 * * *', async () => {
        try {
            const result = await expireDuePoints(db, { batchSize: 500 });
            if ((result?.expired_rows || 0) > 0) {
                console.log(
                    `[LOYALTY] Expired rows: ${result.expired_rows}, expired points: ${result.expired_points}`
                );
            }
        } catch (error) {
            console.error(`[LOYALTY] Expiry cron failed: ${error.message}`);
        }
    });
}

module.exports = { startLoyaltyExpiryJob };
