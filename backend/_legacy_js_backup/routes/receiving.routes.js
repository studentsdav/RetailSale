const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/inventory/receiving.controller');
const numberingCtrl = require('../controllers/inventory/receivingNumbering.controller');

router.use(auth, license('INVENTORY'));

router.get('/next-grn', numberingCtrl.getNextGrnNo);
router.get('/by-date', ctrl.getReceivingByDate);
router.get('/:id', ctrl.getReceivingDetails);
router.put('/:id', ctrl.modifyReceiving);
router.post('/', ctrl.createReceiving);
router.get('/', ctrl.listReceiving);
// router.get('/:id', ctrl.getReceiving);
router.put('/item/:id', ctrl.updateReceivingItem);
router.delete('/item/:id', ctrl.deleteReceivingItem);
router.post('/:id/cancel', ctrl.cancelReceiving);

module.exports = router;
