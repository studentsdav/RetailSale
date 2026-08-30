const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');

const bankCtrl = require('../controllers/finance/bankAccount.controller');
const voucherCtrl = require('../controllers/finance/accountingVoucher.controller');
const reportsCtrl = require('../controllers/finance/financialReports.controller');
const loanCtrl = require('../controllers/finance/loanEmi.controller');

router.use(auth, license('REPORTS'));

// Bank Accounts Master Endpoints
router.get('/banks', bankCtrl.getBankAccounts);
router.post('/banks', bankCtrl.createBankAccount);
router.put('/banks/:id', bankCtrl.updateBankAccount);

// Accounting Vouchers Endpoints
router.get('/vouchers', voucherCtrl.getVouchers);
router.get('/vouchers/:id', voucherCtrl.getVoucherById);
router.post('/vouchers', voucherCtrl.createVoucher);

// Loan, Asset & EMI Endpoints
router.get('/loans-assets', loanCtrl.getLoansAndAssets);
router.post('/loans/pay-emi', loanCtrl.payLoanEmi);

// Financial Statements Endpoints
router.get('/reports/trial-balance', reportsCtrl.getTrialBalance);
router.get('/reports/profit-loss', reportsCtrl.getProfitAndLoss);
router.get('/reports/balance-sheet', reportsCtrl.getBalanceSheet);
router.get('/reports/brs', reportsCtrl.getBankReconciliation);

module.exports = router;
