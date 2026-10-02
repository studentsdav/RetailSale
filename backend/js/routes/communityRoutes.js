const express = require('express');
const router = express.Router();
const communityCtrl = require('../controllers/communityController');

// Conversation & Channel routes
router.get('/conversations', communityCtrl.getConversations);

// Message routes
router.get('/messages', communityCtrl.getMessages);
router.post('/messages', communityCtrl.sendMessage);

// Message Deletion endpoints
router.post('/messages/delete-for-everyone', communityCtrl.deleteForEveryone);
router.post('/messages/delete-for-me', communityCtrl.deleteForMe);

module.exports = router;
