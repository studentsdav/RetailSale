const router = require('express').Router();
const ctrl = require('../controllers/auth/login.controller');

router.post('/login', ctrl.login);

module.exports = router;
