const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');

const supplierCtrl = require('../controllers/supplier/supplierMaster.controller');
const billCtrl = require('../controllers/supplier/supplierPayment.controller');

router.use(auth, license('SUPPLIER'));

router.post('/', supplierCtrl.createSupplier);
router.get('/', supplierCtrl.getSuppliers);
//router.get('/:id', supplierCtrl.getSupplierById);
router.put('/:id', supplierCtrl.updateSupplier);
router.delete('/:id', supplierCtrl.deleteSupplier);

router.get('/bills/list', billCtrl.getSupplierBills);
router.post('/bills/pay', billCtrl.paySupplierBill);
router.get('/bills/:billId/payments', billCtrl.getBillPayments);

module.exports = router;
