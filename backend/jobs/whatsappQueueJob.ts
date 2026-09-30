const { processQueue } = require('../services/whatsappQueue.service');

/**
 * Initialize WhatsApp background message queue worker
 */
export function startWhatsappQueueJob(db: any): void {
  if (!db) return;

  console.log('🛡️ [SYSTEM] Initializing WhatsApp Queue background worker...');

  async function runWorker(): Promise<void> {
    try {
      await processQueue(db);
    } catch (err: any) {
      console.error('[WHATSAPP WORKER SYSTEM CRITICAL ERROR]:', err.message);
    }
    // Poll queue every 2 seconds recursively (safe and lightweight)
    setTimeout(runWorker, 2000);
  }

  runWorker();
}

module.exports = { startWhatsappQueueJob };
