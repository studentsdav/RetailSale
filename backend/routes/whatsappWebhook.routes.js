const router = require('express').Router();
const ctrl = require('../controllers/whatsapp/whatsappWebhook.controller');

// Public endpoints (no authentication middleware)
router.get('/', ctrl.verifyWebhook);
router.post('/', ctrl.receiveWebhook);

module.exports = router;
