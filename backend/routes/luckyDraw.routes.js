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
router.post('/campaigns/:id/pause', ctrl.pauseCampaign);
router.post('/campaigns/:id/resume', ctrl.resumeCampaign);
router.post('/campaigns/:id/stop', ctrl.stopCampaign);
router.get('/campaigns/:id/participants', ctrl.getCampaignParticipants);
router.get('/campaigns/:id/sales-trend', ctrl.getCampaignSalesTrend);

module.exports = router;
