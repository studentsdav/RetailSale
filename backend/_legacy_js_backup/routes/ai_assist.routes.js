const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const aiAssistCtrl = require('../controllers/ai_assist.controller');

router.use(auth);

// LYNX ASSIST AI Chat & Voice Assistant Endpoints
router.post('/chat', aiAssistCtrl.chatWithLynxAssist);
router.post('/voice-command', aiAssistCtrl.handleVoiceCommand);

module.exports = router;
