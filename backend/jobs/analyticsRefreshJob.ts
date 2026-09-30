import cron from 'node-cron';
const { refreshAllAnalytics } = require('../services/analytics.service');

export function startAnalyticsRefreshJob(db: any): void {
  if (!db) return;

  console.log('Initializing analytics refresh cron: 30 2 * * *');
  cron.schedule('30 2 * * *', async () => {
    try {
      await refreshAllAnalytics(db);
      console.log('[ANALYTICS] Nightly refresh complete');
    } catch (error: any) {
      console.error(`[ANALYTICS] Nightly refresh failed: ${error.message}`);
    }
  });
}

module.exports = { startAnalyticsRefreshJob };
