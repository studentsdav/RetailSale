import express from 'express';
const router = express.Router();
const ctrl = require('../controllers/whatsapp/whatsappWebhook.controller');

// Public endpoints (no authentication middleware)
router.get('/', ctrl.verifyWebhook);
router.post('/', ctrl.receiveWebhook);

module.exports = router;
export default router;
