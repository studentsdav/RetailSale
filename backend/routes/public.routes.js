const router = require('express').Router();
const ctrl = require('../controllers/public/propertyInfo.controller');
const { verifyOutletForRecovery, executeFullSystemRecovery, requestRecoveryOtp,
    verifyRecoveryOtp, verifyAndRecoverConfig, triggerAutoReinstall } = require('../controllers/public/recoveryController');
const outletCtrl = require('../controllers/public/outlet.controller');
const { checkSystemUpdate } = require('../controllers/public/updateController');
const { requestPasswordResetOtp, resetPasswordWithOtp, recoverUsername } = require('../modules/passwordRecoveryController');
const { requestSetupOtp, verifySetupOtp } = require('../modules/verificationController');

router.post('/outlet/check', outletCtrl.checkOutlet);
router.post('/outlet', outletCtrl.createOutlet);
// router.post('/create-admin', outletCtrl.createAdmin);
router.get('/property-info', ctrl.getPropertyInfo);
router.get('/outlets', async (req, res) => {
    try {
        const outlets = await req.propertyDb.models.outlets.findAll({
            where: { is_active: true },
            attributes: ['id', 'outlet_code', 'outlet_name']
        });
        res.json({ success: true, data: outlets });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
router.post('/recovery/verify-pin', verifyOutletForRecovery);
router.post('/recovery/execute', executeFullSystemRecovery);
router.post('/recovery/request-otp', requestRecoveryOtp);
router.post('/recovery/verify-otp', verifyRecoveryOtp);
router.post('/system/check-update', checkSystemUpdate);
router.post('/emergency-reset/recover-username', recoverUsername);
router.post('/emergency-reset/request-otp', requestPasswordResetOtp);
router.post('/emergency-reset/verify-and-reset', resetPasswordWithOtp);
router.post('/setup/request-otp', requestSetupOtp);
router.post('/setup/verify-otp', verifySetupOtp);
router.post('/verify-and-download', verifyAndRecoverConfig);
router.post('/trigger-reinstall', triggerAutoReinstall);

// Expose public sales invoice PDF downloads for Meta's servers
const publicSalesCtrl = require('../controllers/public/publicSales.controller');
router.get('/sales/:id/pdf', publicSalesCtrl.getInvoicePdfPublic);

module.exports = router;
