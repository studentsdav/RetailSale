const express = require('express');
const router = express.Router();
const notifyCtrl = require('../controllers/inventory/systemnotification.controller');
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');

router.use(auth, license('INVENTORY'));


router.get('/', notifyCtrl.getNotifications);
router.put('/:id/read', notifyCtrl.markNotificationRead);

module.exports = router;