const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const analyticsCtrl = require('../controllers/report/analytics.controller');

router.use(auth, license('REPORTS'));

router.get('/rfm-segments', analyticsCtrl.getRfmSegments);
router.get('/sales-trend', analyticsCtrl.getSalesTrend);
router.get('/market-basket', analyticsCtrl.getMarketBasket);
router.get('/top-customer-items', analyticsCtrl.getTopCustomerItems);

// Text-to-Query AI Analytics Engine Routes
router.post('/query', analyticsCtrl.executeNaturalLanguageQuery);
router.get('/export/csv', analyticsCtrl.exportQueryCsv);
router.get('/export/pdf', analyticsCtrl.exportQueryPdf);

module.exports = router;
