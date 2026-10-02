const { processQueue } = require('../services/whatsappQueue.service');

let workerTimeout = null;
let currentDb = null;
let isRunning = false;

function wakeWhatsappQueue() {
  if (workerTimeout) {
    clearTimeout(workerTimeout);
    workerTimeout = null;
  }
  if (currentDb && !isRunning) {
    runWorker(currentDb);
  }
}

async function runWorker(db) {
  if (isRunning) {
    workerTimeout = setTimeout(() => runWorker(db), 3000);
    return;
  }

  isRunning = true;
  let processedCount = 0;
  try {
    processedCount = (await processQueue(db)) || 0;
  } catch (err) {
    console.error('[WHATSAPP WORKER ERROR]:', err.message);
  } finally {
    isRunning = false;
    const delay = processedCount > 0 ? 1500 : 30000;
    workerTimeout = setTimeout(() => runWorker(db), delay);
  }
}

/**
 * Initialize WhatsApp background message queue worker with adaptive backoff
 */
function startWhatsappQueueJob(db) {
  if (!db) return;
  currentDb = db;

  console.log('🛡️ [SYSTEM] Initializing WhatsApp Queue background worker with adaptive backoff...');
  runWorker(db);
}

module.exports = { startWhatsappQueueJob, wakeWhatsappQueue };
