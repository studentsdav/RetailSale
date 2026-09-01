const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/user/userManagement.controller');

router.use(auth);

// Verification and OTP dispatch accessible by any logged-in staff
router.post('/supervisor-pin/verify', ctrl.verifySupervisorPin);
router.post('/supervisor-pin/send-otp', ctrl.sendSupervisorOtp);

// Admin-only management routes
router.use(license('ADMIN'));

router.get('/supervisor-pin', ctrl.getSupervisorPin);
router.put('/supervisor-pin', ctrl.updateSupervisorPin);

router.get('/:id/permissions', ctrl.getPermissions);
router.put('/:id/permissionsupdate', ctrl.updatePermissions);
router.get('/', ctrl.listUsers);
router.post('/', ctrl.createUser);
router.post('/check-username', ctrl.checkUsernameAvailability);
router.put('/:id', ctrl.updateUser);
router.put('/:id/status', ctrl.toggleStatus);
router.put('/:id/reset-password', ctrl.resetPassword);
router.post('/:username/change-password', ctrl.changePassword);


module.exports = router;
