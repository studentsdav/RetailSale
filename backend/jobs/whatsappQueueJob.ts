const { processQueue } = require('../services/whatsappQueue.service');

/**
 * Initialize WhatsApp background message queue worker
 */
export function startWhatsappQueueJob(db: any): void {
  if (!db) return;

  console.log('🛡️ [SYSTEM] Initializing WhatsApp Queue background worker...');

  let isRunning = false;

  async function runWorker(): Promise<void> {
    if (isRunning) {
      setTimeout(runWorker, 2000);
      return;
    }

    isRunning = true;
    try {
      await processQueue(db);
    } catch (err: any) {
      console.error('[WHATSAPP WORKER ERROR]:', err.message);
    } finally {
      isRunning = false;
      setTimeout(runWorker, 2000);
    }
  }

  runWorker();
}

module.exports = { startWhatsappQueueJob };
