const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const advancedCtrl = require('../controllers/finance/advancedFinance.controller');

router.use(auth, license('REPORTS'));

router.post('/expenses', advancedCtrl.createExpense);
router.put('/expenses/:id', advancedCtrl.updateExpense);
router.get('/expenses', advancedCtrl.getExpenseReport);
router.post('/income', advancedCtrl.createIncome);
router.put('/income/:id', advancedCtrl.updateIncome);
router.get('/income', advancedCtrl.getIncomeReport);
router.post('/withdrawals', advancedCtrl.createWithdrawal);
router.put('/withdrawals/:id', advancedCtrl.updateWithdrawal);
router.get('/withdrawals', advancedCtrl.getWithdrawalReport);
router.get('/ledger', advancedCtrl.getLedgerReport);
router.post('/repayments', advancedCtrl.createRepayment);
router.post('/repayments/bulk-adjust', advancedCtrl.adjustBulkRepayment);
router.put('/repayments/:id', advancedCtrl.updateRepayment);
router.post('/advances', advancedCtrl.createAdvance);
router.put('/advances/:id', advancedCtrl.updateAdvance);
router.post('/advances/apply', advancedCtrl.applyAdvance);
router.get('/repayments', advancedCtrl.listRepayments);
router.post('/opening-balance', advancedCtrl.setOpeningBalance);
router.get('/opening-balance', advancedCtrl.getOpeningBalances);
router.get('/credit-report', advancedCtrl.getCreditReport);
router.get('/delivery-report', advancedCtrl.getDeliveryReport);
router.get('/expiry-report', advancedCtrl.getExpiryReport);
router.get('/payment-flow', advancedCtrl.getPaymentFlowReport);

module.exports = router;
