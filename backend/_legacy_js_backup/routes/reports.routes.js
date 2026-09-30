const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');

const dashboard = require('../controllers/report/dashboard.controller');
const stockIn = require('../controllers/report/stockInReport.controller');
const stockOut = require('../controllers/report/stockReport.controller');
const stockTransfer = require('../controllers/report/stockTransferReport.controller');
const balance = require('../controllers/report/stockBalance.controller');
const damage = require('../controllers/report/damageReport.controller');
const closing = require('../controllers/report/closingReport.controller');
const purCtrl = require('../controllers/inventory/purchaseOrder.controller');
const returnCtrl = require('../controllers/report/returnReport.controller');
const requestCtrl = require('../controllers/report/requestReport.controller');
const dmgCtrl = require('../controllers/report/damageReportsummery.controller');
const salesCtrl = require('../controllers/report/salesReport.controller');
const schemeCtrl = require('../controllers/report/schemeReport.controller');
const loyaltyCtrl = require('../controllers/report/loyaltyReport.controller');
const supplierReportCtrl = require('../controllers/report/supplierReport.controller');
const commissionCtrl = require('../controllers/report/commissionReport.controller');




router.use(auth, license('REPORTS'));


router.get('/inventory-dashboard', dashboard.inventoryDashboard);
router.get('/purchase-orders', purCtrl.getPurchaseOrderReport);
router.get('/return', returnCtrl.getReturnReport);
router.get('/request', requestCtrl.getRequestReport);
router.get('/sales', salesCtrl.getSalesReport);
router.get('/scheme', schemeCtrl.getSchemeReport);
router.get('/scheme-report', schemeCtrl.getSchemeReport);
router.get('/scheme-cycle-detail', schemeCtrl.getSchemeCycleDetail);
router.get('/loyalty/master', loyaltyCtrl.getLoyaltyMasterReport);
router.get('/loyalty/ledger', loyaltyCtrl.getCustomerLoyaltyLedger);
router.get('/stock-in', stockIn.getStockInReport);
router.get('/stock-out', stockOut.getStockOutReport);
router.get('/stock-transfer', stockTransfer.getStockTransferReport);
router.get('/stock-balance', balance.getStockBalance);
router.get('/damage', damage.getDamageReport);
router.get('/closing', closing.getClosingReport);
router.get('/dmgsummery', dmgCtrl.getDamageReport);
router.get('/supplier-payments', supplierReportCtrl.getSupplierPaymentsReport);
router.get('/commission', commissionCtrl.getCommissionReport);


module.exports = router;
