const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const ctrl = require('../controllers/auth/login.controller');

const { loginLimiter } = require('../middlewares/rateLimit.middleware');

router.post('/login', loginLimiter, ctrl.login);
router.post('/pin-login', loginLimiter, ctrl.pinLogin);
router.post('/switch-outlet', auth, ctrl.switchOutlet);
router.post('/supplier/request-otp', loginLimiter, ctrl.requestSupplierOtp);
router.post('/supplier/verify-otp', ctrl.verifySupplierOtp);

module.exports = router;
