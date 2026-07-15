const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/sales/luckyDraw.controller');

router.use(auth, license('INVENTORY'));

router.get('/campaigns', ctrl.listCampaigns);
router.get('/campaigns/active', ctrl.getActiveCampaign);
router.post('/campaigns', ctrl.createCampaign);
router.get('/campaigns/:id/stats', ctrl.getDrawStats);
router.post('/campaigns/:id/draw', ctrl.drawWinner);
router.post('/campaigns/:id/complete', ctrl.completeCampaign);

module.exports = router;
