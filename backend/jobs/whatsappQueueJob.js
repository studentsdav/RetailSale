const { processQueue } = require('../services/whatsappQueue.service');

/**
 * Initialize WhatsApp background message queue worker
 */
function startWhatsappQueueJob(db) {
  if (!db) return;

  console.log('🛡️ [SYSTEM] Initializing WhatsApp Queue background worker...');

  let isRunning = false;

  async function runWorker() {
    if (isRunning) {
      setTimeout(runWorker, 2000);
      return;
    }

    isRunning = true;
    try {
      await processQueue(db);
    } catch (err) {
      console.error('[WHATSAPP WORKER ERROR]:', err.message);
    } finally {
      isRunning = false;
      setTimeout(runWorker, 2000);
    }
  }

  runWorker();
}

module.exports = { startWhatsappQueueJob };
