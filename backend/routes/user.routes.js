const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/user/userManagement.controller');

router.use(auth, license('ADMIN'));

router.get('/:id/permissions', ctrl.getPermissions);
router.put('/:id/permissionsupdate', ctrl.updatePermissions);
router.get('/', ctrl.listUsers);
router.post('/', ctrl.createUser);
router.put('/:id', ctrl.updateUser);
router.put('/:id/status', ctrl.toggleStatus);
router.put('/:id/reset-password', ctrl.resetPassword);
router.post('/:username/change-password', ctrl.changePassword);


module.exports = router;
