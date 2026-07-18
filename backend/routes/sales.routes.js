const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/sales/sales.controller');
const loyaltyCtrl = require('../controllers/sales/loyalty.controller');
const settingsCtrl = require('../controllers/sales/saleSettings.controller');
const commissionRulesCtrl = require('../controllers/sales/commissionRules.controller');
const { getSubscriptionDraftOrdersToday } = require('../jobs/subscriptionDeliveryJob');

router.use(auth, license('INVENTORY'));

// Commission Rules
router.get('/commission-rules', commissionRulesCtrl.listCommissionRules);
router.post('/commission-rules', commissionRulesCtrl.createCommissionRule);
router.put('/commission-rules/:id', commissionRulesCtrl.updateCommissionRule);
router.delete('/commission-rules/:id', commissionRulesCtrl.deleteCommissionRule);

// Sale Sources
router.get('/sources', settingsCtrl.listSaleSources);
router.post('/sources', settingsCtrl.createSaleSource);
router.put('/sources/:id', settingsCtrl.updateSaleSource);
router.delete('/sources/:id', settingsCtrl.deleteSaleSource);

// Payment Methods
router.get('/payment-methods', settingsCtrl.listPaymentMethods);
router.post('/payment-methods', settingsCtrl.createPaymentMethod);
router.put('/payment-methods/:id', settingsCtrl.updatePaymentMethod);
router.delete('/payment-methods/:id', settingsCtrl.deletePaymentMethod);

router.get('/next-sale-no', ctrl.getNextSaleNo);
router.get('/subscription-drafts-today', getSubscriptionDraftOrdersToday);
router.get('/customers', ctrl.listCustomers);
router.post('/customers', ctrl.createCustomer);
router.put('/customers/:id', ctrl.updateCustomer);
router.delete('/customers/:id', ctrl.deleteCustomer);
router.get('/vouchers', ctrl.listVouchers);
router.get('/loyalty/config', loyaltyCtrl.getConfig);
router.post('/loyalty/config', loyaltyCtrl.saveConfig);
router.get('/loyalty/customer-summary', loyaltyCtrl.getCustomerSummary);
router.get('/schemes', ctrl.listSchemes);
router.get('/schemes/:id/customers', ctrl.listSchemeCustomers);
router.post('/schemes/:id/customers', ctrl.createSchemeCustomer);
router.put('/schemes/:id/customers/:customerId', ctrl.updateSchemeCustomer);
router.get('/schemes/:id/progress', ctrl.getSchemeProgress);
router.get('/subscriptions', ctrl.listSubscriptions);
router.get('/subscriptions/customer', ctrl.listCustomerSubscriptions);
router.get('/subscriptions/:id/ledger', ctrl.getSubscriptionLedger);
router.get('/subscriptions/:id', ctrl.getSubscriptionDetails);
router.post('/subscriptions', ctrl.createSubscription);
router.post('/subscriptions/:id/final-settlement', ctrl.generateFinalSettlement);
router.delete('/subscriptions/:id', ctrl.deleteSubscription);
router.put('/subscriptions/:id/status', ctrl.updateSubscriptionStatus);
router.get('/item-advances', ctrl.listItemAdvances);
router.post('/item-advances', ctrl.createItemAdvance);
router.put('/item-advances/:id', ctrl.updateItemAdvance);
router.delete('/item-advances/:id', ctrl.deleteItemAdvance);
router.get('/item-advances/summary', ctrl.getItemAdvanceSummary);
router.get('/item-advances/ledger', ctrl.getItemAdvanceLedger);
router.post('/vouchers', ctrl.createVoucher);
router.put('/vouchers/:code', ctrl.updateVoucher);
router.delete('/vouchers/:code', ctrl.deleteVoucher);
router.post('/validate-voucher', ctrl.validateVoucher);
router.post('/schemes', ctrl.createScheme);
router.put('/schemes/:id', ctrl.updateScheme);
router.put('/:id/payment-mode', ctrl.updateSalePaymentMode);
router.put('/:id', ctrl.modifySale);
router.delete('/schemes/:id', ctrl.deleteScheme);
router.get('/refunds', ctrl.listRefunds);
router.post('/refunds/pay', ctrl.payRefund);
router.post('/return', ctrl.returnSale);
router.post('/', ctrl.createSale);
router.get('/', ctrl.listSales);
router.delete('/drafts/:id', ctrl.deleteDraft);
router.get('/:id', ctrl.getSaleDetails);

module.exports = router;
