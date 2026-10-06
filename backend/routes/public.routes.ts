import express, { Request, Response } from 'express';
const router = express.Router();
const ctrl = require('../controllers/public/propertyInfo.controller');
const {
  verifyOutletForRecovery,
  executeFullSystemRecovery,
  requestRecoveryOtp,
  verifyRecoveryOtp,
  verifyAndRecoverConfig,
  triggerAutoReinstall
} = require('../controllers/public/recoveryController');
const outletCtrl = require('../controllers/public/outlet.controller');
const { checkSystemUpdate } = require('../controllers/public/updateController');
const {
  requestPasswordResetOtp,
  resetPasswordWithOtp,
  recoverUsername
} = require('../modules/passwordRecoveryController');
const { requestSetupOtp, verifySetupOtp } = require('../modules/verificationController');

router.post('/outlet/check', outletCtrl.checkOutlet);
router.post('/outlet', outletCtrl.createOutlet);
router.put('/outlet/module', outletCtrl.updateOutletModule);
router.post('/outlet/module', outletCtrl.updateOutletModule);
router.get('/property-info', ctrl.getPropertyInfo);
router.get('/outlets', async (req: Request, res: Response) => {
  try {
    const { getLinkedOutletIds } = require('../utils/outletScopeHelper');
    const sessionOutletId = req.user?.outlet_id || req.query?.outlet_id;
    let where: any = { is_active: true };
    if (sessionOutletId) {
      const linkedIds = await getLinkedOutletIds(req, sessionOutletId);
      if (linkedIds.length > 0) {
        const { Op } = require('sequelize');
        where.id = { [Op.in]: linkedIds };
      }
    }
    const outlets = await req.propertyDb.models.outlets.findAll({
      where,
      attributes: ['id', 'outlet_code', 'outlet_name', 'parent_outlet_id', 'is_master'],
      bypassOutletFilter: true
    });
    return res.json({ success: true, data: outlets });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
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

// Tax Groups & Component Master API Endpoints
const taxGroupCtrl = require('../controllers/settings/taxGroup.controller');
router.get('/settings/tax-groups', taxGroupCtrl.getTaxGroups);
router.post('/settings/tax-groups', taxGroupCtrl.createTaxGroup);
router.put('/settings/tax-groups/:id', taxGroupCtrl.updateTaxGroup);
// 1-Click Cloud Migration Gateway
const migrationCtrl = require('../controllers/public/migration.controller');
router.get('/migration/ping', migrationCtrl.ping);
router.post('/migration/ping', migrationCtrl.ping);
router.post('/migration/export-bundle', migrationCtrl.exportBundle);
router.post('/migration/import-bundle', migrationCtrl.importBundle);
router.post('/migration/sync-online-to-offline', migrationCtrl.syncOnlineToOffline);

// Table QR Customer Self-Ordering Dining Endpoints
const diningCtrl = require('../controllers/restaurant/dining.controller');
router.get('/dining/table-info', diningCtrl.getTableDiningInfo);
router.post('/dining/request-otp', diningCtrl.requestCustomerDiningOtp);
router.post('/dining/verify-otp', diningCtrl.verifyCustomerDiningOtp);
router.post('/dining/register-profile', diningCtrl.registerCustomerDiningProfile);
router.post('/dining/place-order', diningCtrl.placeCustomerDiningOrder);
router.post('/dining/call-waiter', diningCtrl.callTableWaiter);

module.exports = router;
export default router;
