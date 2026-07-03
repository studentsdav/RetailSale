const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const ctrl = require('../controllers/whatsapp/whatsapp.controller');

// All private endpoints require authentication
router.use(auth);

// Configuration settings (only ADMIN role can modify config)
router.get('/config', ctrl.getConfig);
router.post('/config', (req, res, next) => {
    if (req.user?.role !== 'ADMIN') {
        return res.status(403).json({ success: false, message: 'Only administrators can modify WhatsApp settings configuration.' });
    }
    next();
}, ctrl.saveConfig);

router.post('/config/test', ctrl.testCredentials);

// Templates Manager
router.get('/templates', ctrl.listTemplates);
router.post('/templates/sync', ctrl.syncTemplates);
router.post('/templates', ctrl.createTemplate);
router.post('/templates/toggle-default', ctrl.toggleDefaultInvoiceTemplate);
router.post('/templates/delete', ctrl.deleteTemplate);

// Campaign Manager & Logs
router.get('/campaigns', ctrl.listCampaigns);
router.post('/campaigns', ctrl.launchCampaign);
router.get('/campaigns/audience', ctrl.getAudienceList);
router.get('/billing/dashboard', ctrl.getBillingDashboard);
router.get('/logs', ctrl.listLogs);

module.exports = router;
