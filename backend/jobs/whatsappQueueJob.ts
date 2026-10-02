const { processQueue } = require('../services/whatsappQueue.service');

let workerTimeout: NodeJS.Timeout | null = null;
let currentDb: any = null;
let isRunning = false;

export function wakeWhatsappQueue(): void {
  if (workerTimeout) {
    clearTimeout(workerTimeout);
    workerTimeout = null;
  }
  if (currentDb && !isRunning) {
    runWorker(currentDb);
  }
}

async function runWorker(db: any): Promise<void> {
  if (isRunning) {
    workerTimeout = setTimeout(() => runWorker(db), 3000);
    return;
  }

  isRunning = true;
  let processedCount = 0;
  try {
    processedCount = (await processQueue(db)) || 0;
  } catch (err: any) {
    console.error('[WHATSAPP WORKER ERROR]:', err.message);
  } finally {
    isRunning = false;
    // Process fast if messages were found; otherwise idle sleep for 30s
    const delay = processedCount > 0 ? 1500 : 30000;
    workerTimeout = setTimeout(() => runWorker(db), delay);
  }
}

/**
 * Initialize WhatsApp background message queue worker with adaptive backoff
 */
export function startWhatsappQueueJob(db: any): void {
  if (!db) return;
  currentDb = db;

  console.log('🛡️ [SYSTEM] Initializing WhatsApp Queue background worker with adaptive backoff...');
  runWorker(db);
}

module.exports = { startWhatsappQueueJob, wakeWhatsappQueue };
