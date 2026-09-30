import express from 'express';
const router = express.Router();
const taxGroupCtrl = require('../controllers/settings/taxGroup.controller');

router.get('/', taxGroupCtrl.getTaxGroups);
router.post('/', taxGroupCtrl.createTaxGroup);
router.put('/:id', taxGroupCtrl.updateTaxGroup);
router.delete('/:id', taxGroupCtrl.deleteTaxGroup);

module.exports = router;
export default router;
