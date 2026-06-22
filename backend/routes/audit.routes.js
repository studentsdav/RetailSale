const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/report/audit.controller');

router.use(auth, license('ADMIN'));

router.get('/', ctrl.auditReport);

module.exports = router;
