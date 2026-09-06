const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const ctrl = require('../controllers/auth/login.controller');

router.post('/login', ctrl.login);
router.post('/switch-outlet', auth, ctrl.switchOutlet);
router.post('/supplier/request-otp', ctrl.requestSupplierOtp);
router.post('/supplier/verify-otp', ctrl.verifySupplierOtp);

module.exports = router;
