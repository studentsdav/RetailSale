const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const mpesaCtrl = require('../controllers/payments/mpesa.controller');

// Public webhook callback
router.post('/callback', mpesaCtrl.handleCallback);

// Protected routes
router.use(auth);
router.get('/config', mpesaCtrl.getConfig);
router.post('/config', mpesaCtrl.saveConfig);
router.post('/stk-push', mpesaCtrl.initiateStkPush);
router.post('/stk-query', mpesaCtrl.queryStkStatus);

module.exports = router;
