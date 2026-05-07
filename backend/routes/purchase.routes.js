const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/inventory/purchaseOrder.controller');

router.use(auth, license('PURCHASE'));

router.post('/', ctrl.createPurchaseOrder);
router.get('/', ctrl.listPurchaseOrders);
router.get('/by-date', ctrl.getPoByDate);
router.get('/:id/print', ctrl.getPurchaseOrderForPrint);
router.get('/:id/details', ctrl.getPurchaseOrderDetails);
router.put('/:id/modify', ctrl.modifyPurchaseOrder);
router.get('/:id', ctrl.getPurchaseOrder);
router.put('/:id', ctrl.updatePurchaseOrder);
router.post('/:id/close', ctrl.closePurchaseOrder);
router.post('/:id/cancel', ctrl.cancelPurchaseOrder);

module.exports = router;
